"""The PIO SPI master, simulated in pgsim at the RP2350 clock (120 MHz), against chip.md section 6.6.

pgsim runs the program with the SM clock divided by 2, so one PIO tick is one chip cycle
(60 MHz). The pads are sampled every 2 system cycles, which is one chip cycle. The pin map
is the demo board's: SCK = pad 6 (GPIO 22), MOSI = pad 7 (GPIO 23), CS_N = pad 8 (GPIO 24),
with pads numbered from GPIO 16 (the PIO gpio_base).

The checks, from chip.md section 6.6 and the library's own margins:
- SCK high and low phases inside a frame are exactly H chip cycles (H = 3 at 10 MHz,
  H = 2 at 15 MHz). The minimum in 6.6 is 2.
- CS_N falls to the first SCK rise by at least 4 chip cycles, and stays high at least 4
  between frames.
- MOSI and CS_N change only while SCK is low. MOSI changes on the falling edge or one cycle
  after it.
- The bytes sent come out MSB first, one per data word, and the header is not clocked.
- The RX FIFO gets one word per byte (autopush at 8 bits).
"""

import os
import re
import subprocess

import pytest

import polyglot as pg
from test_programs import pio_text_for_half, REPO

PGASM = os.path.join(REPO, "_build", "default", "sw", "pgasm", "bin", "pgasm.exe")
PGSIM = os.path.join(REPO, "_build", "default", "sw", "pgsim", "cli", "pgsim_cli.exe")
needs_tools = pytest.mark.skipif(
    not (os.path.exists(PGASM) and os.path.exists(PGSIM)),
    reason="build pgasm and pgsim first (dune build --root .)",
)

SCK_PAD = 6  # GPIO 22
MOSI_PAD = 7  # GPIO 23
CS_PAD = 8  # GPIO 24
MISO_PAD = 24  # GPIO 40

# SM configuration of the SPI master (the same values polyglot's init writes on the RP2350).
CLKDIV = 0x00020000  # clkdiv 2: one tick is two system cycles
EXECCTRL = 0x0001F000  # wrap 0..31, SIDE_EN 0
SHIFTCTRL = 0x10830000  # shift left both ways, autopush and autopull, thresholds 8
PINCTRL = (
    (1 << 29)  # SIDESET_COUNT 1 (SCK)
    | (3 << 26)  # SET_COUNT 3 (SCK, MOSI, CS_N)
    | (1 << 20)  # OUT_COUNT 1 (MOSI)
    | (24 << 15)  # IN_BASE 24 (MISO, GPIO 40)
    | (6 << 10)  # SIDESET_BASE 6 (SCK)
    | (6 << 5)  # SET_BASE 6
    | 7  # OUT_BASE 7 (MOSI)
)
INIT_PINDIRS = 0xE087  # set pindirs, 7: SCK, MOSI and CS_N are outputs
INIT_CS_HIGH = 0xE004  # set pins, 4: CS_N high, SCK and MOSI low


def run_pgsim(tmp_path, h, tx_now, tx_later):
    """Run pgsim: tx_now are pushed before cycle 0, tx_later is (cycle, word) pairs."""
    pio = tmp_path / ("spi_h%d.pio" % h)
    pio.write_text(pio_text_for_half(h))
    pj = tmp_path / ("spi_h%d.json" % h)
    subprocess.check_call([PGASM, "-o", "json", str(pio), str(pj)])
    cfg = tmp_path / ("cfg_h%d.json" % h)
    cfg.write_text(
        '{"clkdiv": "0x%08x", "execctrl": "0x%08x", "shiftctrl": "0x%08x", "pinctrl": "0x%08x"}'
        % (CLKDIV, EXECCTRL, SHIFTCTRL, PINCTRL)
    )
    args = [
        PGSIM,
        "--program", str(pj),
        "--config", str(cfg),
        "--init-instr", "%04x" % INIT_PINDIRS,
        "--init-instr", "%04x" % INIT_CS_HIGH,
        "--pins", "0:0x%08x" % (1 << MISO_PAD),  # MISO held high, so every RX word is 0xFF
        "--trace",
        "--cycles", "2400",
    ]
    for w in tx_now:
        args += ["--tx", "0x%08x" % w]
    for cycle, w in tx_later:
        args += ["--at", "%d:tx:0:0x%08x" % (cycle, w)]
    res = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
    assert res.returncode == 0, res.stderr
    return res.stdout


def parse_trace(text):
    pads = []
    summary = None
    for line in text.splitlines():
        parts = line.split()
        if len(parts) == 2 and parts[0].isdigit():
            pads.append((int(parts[0]), int(parts[1], 16)))
        elif line.startswith("sm0 "):
            summary = line
    return pads, summary


def sampled(pads):
    """The 60 MHz samples: every second system cycle, starting at cycle 0."""
    by_cycle = dict(pads)
    last = max(by_cycle)
    return [by_cycle[c] for c in range(0, last + 1, 2)]


def runs(seq):
    """(level, length, start) for each run of equal values."""
    out = []
    start = 0
    for i in range(1, len(seq) + 1):
        if i == len(seq) or seq[i] != seq[start]:
            out.append((seq[start], i - start, start))
            start = i
    return out


def frames_from(cs):
    """(start, end) sample indices of each CS_N-low frame."""
    out = []
    start = None
    for i, v in enumerate(cs):
        if v == 0 and start is None:
            start = i
        if v == 1 and start is not None:
            out.append((start, i))
            start = None
    if start is not None:
        out.append((start, len(cs)))
    return out


def check_waveform(text, h, expect_frames):
    """Check the waveform and return (report, summary line). expect_frames: list of byte lists."""
    pads, summary = parse_trace(text)
    s = sampled(pads)
    sck = [(v >> SCK_PAD) & 1 for v in s]
    mosi = [(v >> MOSI_PAD) & 1 for v in s]
    cs = [(v >> CS_PAD) & 1 for v in s]
    report = {}

    # CS_N changes only while SCK is low; MOSI changes only while SCK is low.
    for i in range(1, len(s)):
        if cs[i] != cs[i - 1]:
            assert sck[i] == 0 and sck[i - 1] == 0, "CS_N changes while SCK is high (sample %d)" % i
        if mosi[i] != mosi[i - 1]:
            assert sck[i] == 0, "MOSI changes while SCK is high (sample %d)" % i

    # A MOSI change in a low phase that began with a falling edge must be on that edge
    # (same sample) or one sample after it. A change in a low phase that began with CS_N
    # falling (no SCK edge) has no edge to measure from, and is allowed.
    falls = [i for i in range(1, len(s)) if sck[i - 1] == 1 and sck[i] == 0]
    cs_edges = [i for i in range(1, len(s)) if cs[i] != cs[i - 1]]
    offsets = []
    for i in range(1, len(s)):
        if mosi[i] != mosi[i - 1] and cs[i] == cs[i - 1]:
            # The low phase that contains sample i began at the last falling edge or the
            # last CS_N edge, whichever is later.
            last_fall = max([f for f in falls if f <= i] or [-1])
            last_cs = max([c for c in cs_edges if c <= i] or [-1])
            if last_fall > last_cs:
                margin = i - last_fall
                assert margin <= 1, "MOSI changes %d samples after the falling edge" % margin
                offsets.append(margin)
    report["mosi_offset_after_fall"] = sorted(set(offsets))

    fr = frames_from(cs)
    assert len(fr) == len(expect_frames), (fr, len(expect_frames))
    report["cs_to_first_rise"] = []
    high_lens = []
    low_lens = []
    for (a, b), data in zip(fr, expect_frames):
        rises = [i for i in range(a + 1, b) if sck[i - 1] == 0 and sck[i] == 1]
        assert rises, "frame with no SCK"
        report["cs_to_first_rise"].append(rises[0] - a)
        assert rises[0] - a >= 4, "CS_N falls %d cycles before the first SCK rise" % (rises[0] - a)
        assert len(rises) == 8 * len(data), (len(rises), data)
        # Every phase from the first rise to the last rise: high and low must be exactly h.
        for lvl, length, start in runs(sck[a:b]):
            absolute = start + a
            if lvl == 1 and rises[0] <= absolute <= rises[-1]:
                high_lens.append(length)
            if lvl == 0 and rises[0] < absolute and absolute + length <= rises[-1]:
                low_lens.append(length)
        bits = [mosi[i] for i in rises]
        got = []
        for k in range(0, len(bits), 8):
            v = 0
            for bit in bits[k : k + 8]:
                v = (v << 1) | bit
            got.append(v)
        assert got == list(data), "decoded %s, sent %s" % ([hex(x) for x in got], [hex(x) for x in data])
    gaps = [c - b for (a, b), (c, d) in zip(fr, fr[1:])]
    report["cs_high_between_frames"] = gaps
    assert all(g >= 4 for g in gaps), gaps
    report["sck_high"] = sorted(set(high_lens))
    report["sck_low"] = sorted(set(low_lens))
    assert report["sck_high"] == [h], report
    assert report["sck_low"] == [h], report
    return report, summary


def rx_level(summary):
    m = re.search(r"rx=(\d+)", summary or "")
    return int(m.group(1)) if m else None


@needs_tools
@pytest.mark.parametrize("h,rate_hz", [(3, 10000000), (2, 15000000)])
def test_spi_master_waveform_meets_chip_md_6_6(tmp_path, h, rate_hz):
    # Frame A: header 2 (N-1), then 0xA5 0x3C 0x0F. Frame B, 1200 cycles later: header 0, then 0x80.
    text = run_pgsim(
        tmp_path,
        h,
        tx_now=[2, 0xA5000000, 0x3C000000, 0x0F000000],
        tx_later=[(1200, 0), (1200, 0x80000000)],
    )
    report, summary = check_waveform(text, h, [[0xA5, 0x3C, 0x0F], [0x80]])
    assert 60000000 // (2 * h) == rate_hz
    assert pg.half_period(rate_hz) == h
    # One RX word per byte: four bytes in total, so the RX FIFO holds four.
    assert rx_level(summary) == 4, summary


@needs_tools
def test_margins_for_the_report(tmp_path):
    """CS setup, CS hold and the MOSI offset at 10 MHz, for the report."""
    text = run_pgsim(tmp_path, 3, tx_now=[1, 0x5A000000, 0xC3000000], tx_later=[])
    report, _ = check_waveform(text, 3, [[0x5A, 0xC3]])
    assert min(report["cs_to_first_rise"]) >= 4
    assert max(report["mosi_offset_after_fall"]) <= 1


def test_half_period_rounds_up_and_limits_the_range():
    assert pg.half_period(10000000) == 3
    assert pg.half_period(15000000) == 2
    assert pg.half_period(14000000) == 3  # never faster than asked: 60/28 rounds up to 3
    assert pg.half_period(1875000) == 16
    with pytest.raises(ValueError):
        pg.half_period(16000000)
    with pytest.raises(ValueError):
        pg.half_period(1500000)
    with pytest.raises(ValueError):
        pg.half_period(0)
