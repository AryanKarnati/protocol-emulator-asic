#!/usr/bin/env python3
"""Pure-Python decoder and writer for silicon-ref trace files (JSON lines).

No hardware is needed. The file format is documented in silicon-ref/README.md.

    python3 silicon-ref/trace.py FILE [--head N] [--pin J ...]

prints a summary and the first N samples, and the level of each requested capture pin.
"""

import argparse
import json
import sys

FORMAT = "polyglot-pio-silicon-trace"
VERSION = 1
WORD_BITS = 32


class TraceError(ValueError):
    """The trace is malformed, incomplete or does not match its header."""


def decode_words(words, bits_per_sample=8):
    """Expand 32-bit words into samples. Sample k of a word is bits [k*b +: b], k = 0 first.

    The capture SM uses `in pins, 8` with IN shift right and autopush at 32 bits, so the
    first sample of each word is in the low byte (see README, "Sample order").
    """
    if WORD_BITS % bits_per_sample:
        raise TraceError("bits_per_sample %d does not divide 32" % bits_per_sample)
    per_word = WORD_BITS // bits_per_sample
    mask = (1 << bits_per_sample) - 1
    samples = []
    for w in words:
        if not 0 <= w < (1 << WORD_BITS):
            raise TraceError("word out of range: %r" % (w,))
        for k in range(per_word):
            samples.append((w >> (k * bits_per_sample)) & mask)
    return samples


def encode_samples(samples, bits_per_sample=8):
    """Inverse of decode_words. len(samples) must be a multiple of samples per word."""
    per_word = WORD_BITS // bits_per_sample
    if len(samples) % per_word:
        raise TraceError("sample count must be a multiple of %d" % per_word)
    mask = (1 << bits_per_sample) - 1
    words = []
    for i in range(0, len(samples), per_word):
        w = 0
        for k in range(per_word):
            s = samples[i + k]
            if not 0 <= s <= mask:
                raise TraceError("sample %r does not fit in %d bits" % (s, bits_per_sample))
            w |= s << (k * bits_per_sample)
        words.append(w)
    return words


class Trace:
    def __init__(self, header, words, samples, footer):
        self.header = header
        self.words = words
        self.samples = samples
        self.footer = footer

    @property
    def pins_base(self):
        return self.header["capture"]["pins_base"]

    @property
    def pins_count(self):
        return self.header["capture"]["pins_count"]

    def pin_levels(self, pin):
        """Level (0/1) of capture pin `pin` (0 = pins_base) for every sample."""
        if not 0 <= pin < self.pins_count:
            raise ValueError("pin index %d outside 0..%d" % (pin, self.pins_count - 1))
        return [(s >> pin) & 1 for s in self.samples]

    def sample_time_s(self, index):
        """Time of sample `index` from the start write, in seconds (sample k = cycle k)."""
        return index / float(self.header["sysclk_hz"])

    def warnings(self):
        out = []
        if self.footer.get("rxstall_capture"):
            out.append("capture SM RXSTALL flag set: a stall may have delayed samples, "
                       "or it may be the expected stall after the last DMA read (README)")
        return out


def read_trace(source):
    """Read and validate a trace. `source` is a path or an iterable of lines."""
    if isinstance(source, str):
        with open(source) as f:
            lines = f.readlines()
    else:
        lines = list(source)
    records = []
    for n, line in enumerate(lines, 1):
        if not line.strip():
            continue
        try:
            records.append(json.loads(line))
        except ValueError as e:
            raise TraceError("line %d is not JSON: %s" % (n, e))
    if not records:
        raise TraceError("empty trace")

    header = records[0]
    if header.get("record") != "header":
        raise TraceError("first record must be the header")
    if header.get("format") != FORMAT:
        raise TraceError("unknown format %r" % header.get("format"))
    if header.get("version") != VERSION:
        raise TraceError("unsupported version %r" % header.get("version"))
    cap = header.get("capture") or {}
    bits = cap.get("bits_per_sample")
    if not isinstance(bits, int):
        raise TraceError("header.capture.bits_per_sample missing")
    if not header.get("sysclk_hz"):
        raise TraceError("header.sysclk_hz missing")

    words = []
    footer = None
    next_word = 0
    for rec in records[1:]:
        kind = rec.get("record")
        if footer is not None:
            raise TraceError("records after the footer")
        if kind == "words":
            if rec.get("first_word") != next_word:
                raise TraceError("word block starts at %r, expected %d (gap or reorder)"
                                 % (rec.get("first_word"), next_word))
            block = [int(w, 16) for w in rec["words"]]
            words.extend(block)
            next_word += len(block)
        elif kind == "footer":
            footer = rec
        else:
            raise TraceError("unknown record type %r" % kind)
    if footer is None:
        raise TraceError("no footer: the capture did not complete")
    if footer.get("complete") is not True:
        raise TraceError("footer says the capture is not complete")
    if footer.get("words_total") != len(words):
        raise TraceError("footer words_total %r but %d words read"
                         % (footer.get("words_total"), len(words)))
    samples = decode_words(words, bits)
    if footer.get("samples_total") != len(samples):
        raise TraceError("footer samples_total %r but %d samples decoded"
                         % (footer.get("samples_total"), len(samples)))
    if cap.get("samples_per_word") != WORD_BITS // bits:
        raise TraceError("header samples_per_word does not match bits_per_sample")
    return Trace(header, words, samples, footer)


def write_trace(path, header, samples, rxstall_capture=False, words_per_line=256):
    """Write a trace in the documented format. Used by the self-test and for synthetic data."""
    bits = header["capture"]["bits_per_sample"]
    words = encode_samples(samples, bits)
    with open(path, "w") as f:
        f.write(json.dumps(dict(header, record="header")) + "\n")
        for first in range(0, len(words), words_per_line):
            block = words[first:first + words_per_line]
            f.write(json.dumps({"record": "words", "first_word": first,
                                "words": ["0x%08x" % w for w in block]}) + "\n")
        f.write(json.dumps({"record": "footer", "words_total": len(words),
                            "samples_total": len(samples), "fdebug": "0x00000000",
                            "rxstall_capture": rxstall_capture, "complete": True}) + "\n")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("file")
    ap.add_argument("--head", type=int, default=16, help="samples to print")
    ap.add_argument("--pin", type=int, action="append", default=[],
                    help="capture pin index to show as a level string (repeatable)")
    args = ap.parse_args(argv)
    try:
        tr = read_trace(args.file)
    except (TraceError, OSError) as e:
        print("error: %s" % e, file=sys.stderr)
        return 1
    h = tr.header
    print("program: %s (pio_version %s, %d words)" % (h["program"]["name"],
          h["program"]["pio_version"], len(h["program"]["words"])))
    print("sysclk: %s Hz, capture pins %d..%d, samples: %d"
          % (h["sysclk_hz"], tr.pins_base, tr.pins_base + tr.pins_count - 1, len(tr.samples)))
    for w in tr.warnings():
        print("warning: %s" % w)
    for i, s in enumerate(tr.samples[:args.head]):
        print("%6d  0x%02x  %s" % (i, s, format(s, "08b")))
    for pin in args.pin:
        levels = tr.pin_levels(pin)
        print("pin %d (GPIO %d): %s" % (pin, tr.pins_base + pin,
              "".join(str(b) for b in levels[:args.head * 4])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
