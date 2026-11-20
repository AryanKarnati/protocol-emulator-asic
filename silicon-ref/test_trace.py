"""Host-side self-test for silicon-ref/trace.py. Runs without hardware.

    python3 -m pytest silicon-ref/          (if pytest is installed)
    python3 silicon-ref/test_trace.py       (plain run, no dependencies)
"""

import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import trace as tr  # noqa: E402  (silicon-ref/trace.py)


def _header(samples_per_word=4, bits=8, sysclk_hz=150_000_000, pins_base=0, pins_count=8):
    return {
        "record": "header",
        "format": tr.FORMAT,
        "version": tr.VERSION,
        "device": "test",
        "sysclk_hz": sysclk_hz,
        "program": {"name": "toggle", "pio_version": 0, "words": ["0xe001"]},
        "capture": {"sm": 1, "pins_base": pins_base, "pins_count": pins_count,
                    "bits_per_sample": bits, "samples_per_word": samples_per_word},
    }


def test_word_byte_order():
    # First sample is in the low byte: 0x04030201 -> 1, 2, 3, 4.
    assert tr.decode_words([0x04030201]) == [1, 2, 3, 4]


def test_isr_model_matches_decoder():
    """Independent model of `in pins, 8` with IN shift right and autopush at 32 bits.

    Each IN puts the new 8 bits at the top of ISR and shifts the rest down, so the
    first sample ends in bits 7:0 once four samples are in. The decoder must agree.
    """
    samples = [0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x01, 0xFE, 0xA5, 0x5A]
    isr, count, pushed = 0, 0, []
    for s in samples:
        isr = (isr >> 8) | (s << 24)
        count += 8
        if count >= 32:
            pushed.append(isr & 0xFFFFFFFF)
            isr, count = 0, 0
    assert len(pushed) == 3
    assert tr.decode_words(pushed) == samples


def test_encode_decode_roundtrip():
    samples = [(i * 37) & 0xFF for i in range(64)]
    assert tr.decode_words(tr.encode_samples(samples)) == samples


def test_encode_rejects_bad_length_and_range():
    for bad in ([1, 2, 3], ):
        try:
            tr.encode_samples(bad)
        except tr.TraceError:
            pass
        else:
            raise AssertionError("length check missing")
    try:
        tr.encode_samples([256, 0, 0, 0])
    except tr.TraceError:
        pass
    else:
        raise AssertionError("range check missing")


def test_file_roundtrip_and_pin_levels():
    samples = [0b0000_0001, 0b0000_0000, 0b0000_0011, 0b0000_0010] * 4
    with tempfile.TemporaryDirectory() as d:
        path = os.path.join(d, "t.jsonl")
        tr.write_trace(path, _header(), samples)
        t = tr.read_trace(path)
    assert t.samples == samples
    assert t.pin_levels(0) == [1, 0, 1, 0] * 4
    assert t.pin_levels(1) == [0, 0, 1, 1] * 4
    assert abs(t.sample_time_s(150) - 1e-6) < 1e-12
    assert t.warnings() == []


def test_rxstall_flag_is_a_warning_not_an_error():
    with tempfile.TemporaryDirectory() as d:
        path = os.path.join(d, "t.jsonl")
        tr.write_trace(path, _header(), [0] * 8, rxstall_capture=True)
        t = tr.read_trace(path)
    assert len(t.warnings()) == 1


def _lines_for(samples):
    with tempfile.TemporaryDirectory() as d:
        path = os.path.join(d, "t.jsonl")
        tr.write_trace(path, _header(), samples, words_per_line=2)
        with open(path) as f:
            return f.read().splitlines()


def _expect_error(lines, fragment):
    try:
        tr.read_trace(lines)
    except tr.TraceError as e:
        assert fragment in str(e), (fragment, str(e))
        return
    raise AssertionError("expected TraceError containing %r" % fragment)


def test_missing_word_block_is_detected():
    lines = _lines_for(list(range(32)))           # 8 words in 4 blocks of 2
    del lines[2]                                   # drop the second word block (lines[1] is block 0)
    _expect_error(lines, "gap or reorder")


def test_missing_footer_is_detected():
    lines = _lines_for([1, 2, 3, 4])
    _expect_error(lines[:-1], "no footer")


def test_truncated_word_count_is_detected():
    lines = _lines_for(list(range(16)))
    # Shorten the last block so the footer's word total no longer matches.
    import json
    last = json.loads(lines[-2])
    last["words"] = last["words"][:-1]
    lines[-2] = json.dumps(last)
    _expect_error(lines, "words_total")


def test_wrong_format_and_version_rejected():
    import json
    lines = _lines_for([1, 2, 3, 4])
    h = json.loads(lines[0])
    h["format"] = "something-else"
    _expect_error([json.dumps(h)] + lines[1:], "unknown format")
    h["format"] = tr.FORMAT
    h["version"] = 99
    _expect_error([json.dumps(h)] + lines[1:], "unsupported version")


def test_incomplete_capture_rejected():
    import json
    lines = _lines_for([1, 2, 3, 4])
    f = json.loads(lines[-1])
    f["complete"] = False
    _expect_error(lines[:-1] + [json.dumps(f)], "not complete")


def run_all():
    names = [n for n in sorted(globals()) if n.startswith("test_")]
    for n in names:
        globals()[n]()
        print("ok   %s" % n)
    print("%d tests passed" % len(names))


if __name__ == "__main__":
    run_all()
