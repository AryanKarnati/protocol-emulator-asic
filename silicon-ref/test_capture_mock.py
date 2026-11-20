"""Host-side mock test for silicon-ref/capture.py. No hardware, no MicroPython.

    python3 silicon-ref/test_capture_mock.py      (plain run, no dependencies)
    python3 -m pytest silicon-ref/                (same tests under pytest, if installed)

It fakes the MicroPython modules capture.py imports (machine, rp2, time, uctypes), records
every register write and the DMA arm/close events in order, and checks the write order for
the ws2812 corpus program. This checks what capture.py asks the hardware to do. It does not
check the silicon. The expected values are worked out from the header bit positions cited in
capture.py. [verify on hardware]
"""

import os
import sys
import tempfile
import types

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

WS2812_JSON = os.path.join(HERE, "..", "sw", "pgasm", "test", "corpus", "pico-examples",
                           "pio", "ws2812", "ws2812.pio.json")

PIO0_BASE = 0x50200000
PIO_CTRL = PIO0_BASE + 0x000
PIO_FDEBUG = PIO0_BASE + 0x008
PIO_TXF0 = PIO0_BASE + 0x010
PIO_INSTR_MEM0 = PIO0_BASE + 0x048
SM0_BASE = PIO0_BASE + 0x0C8     # pio.h PIO_SM0_CLKDIV_OFFSET
SM_STRIDE = 0x18
SM_OFF = dict(clkdiv=0x00, execctrl=0x04, shiftctrl=0x08, instr=0x10, pinctrl=0x14)
RESETS_BASE = 0x40020000
RESETS_RESET = RESETS_BASE + 0x000
RESETS_RESET_DONE = RESETS_BASE + 0x008
ALIAS_SET = 0x2000
ALIAS_CLR = 0x3000
PADS_BANK0_BASE = 0x40038000
RESET_DMA = 1 << 2
RESET_PIO0 = 1 << 11
SM_RESTART_BITS = 0x0F0           # CTRL[7:4], self-clearing
CLKDIV_RESTART_BITS = 0xF00       # CTRL[11:8], self-clearing
EN_BOTH = 0x3
RESTART_WRITE = 0x330             # SM_RESTART for SM0 and SM1, CLKDIV_RESTART for SM0 and SM1
FJOIN_RX = 1 << 31

EVENTS = []                       # ordered: ("w", addr, value), ("dma_arm", v), ("dma_close",)


def sm_reg(n, name):
    return SM0_BASE + SM_STRIDE * n + SM_OFF[name]


class FakeMem:
    """Stands in for machine.mem32. Keeps register values and logs every write."""

    def __init__(self, resets_held=0):
        self.values = {RESETS_RESET: resets_held}
        self.log = []                 # (addr, value) for every write, in order

    def __getitem__(self, addr):
        if addr == RESETS_RESET_DONE:
            return (~self.values.get(RESETS_RESET, 0)) & 0x1FFFFFFF
        if addr == PIO_CTRL:
            return self.values.get(addr, 0) & ~(SM_RESTART_BITS | CLKDIV_RESTART_BITS)
        return self.values.get(addr, 0)

    def __setitem__(self, addr, value):
        self.log.append((addr, value))
        EVENTS.append(("w", addr, value))
        if RESETS_BASE + ALIAS_CLR <= addr < RESETS_BASE + ALIAS_CLR + 0x10:
            base = addr - ALIAS_CLR
            self.values[base] = self.values.get(base, 0) & ~value
        elif RESETS_BASE + ALIAS_SET <= addr < RESETS_BASE + ALIAS_SET + 0x10:
            base = addr - ALIAS_SET
            self.values[base] = self.values.get(base, 0) | value
        elif addr == PIO_CTRL:
            self.values[addr] = value & ~(SM_RESTART_BITS | CLKDIV_RESTART_BITS)
        elif addr == PIO_FDEBUG:
            self.values[addr] = self.values.get(addr, 0) & ~value   # write-1-to-clear
        else:
            self.values[addr] = value


class FakeDMA:
    instances = []
    busy_forever = False              # True forces the timeout path

    def __init__(self):
        self.armed = []
        self.closed = False
        self.config_args = None
        FakeDMA.instances.append(self)

    def pack_ctrl(self, **kw):
        return dict(kw)

    def config(self, read=None, write=None, count=None, ctrl=None, trigger=False):
        self.config_args = dict(read=read, write=write, count=count, ctrl=ctrl)

    def active(self, value=None):
        if value is None:
            return FakeDMA.busy_forever
        self.armed.append(value)
        EVENTS.append(("dma_arm", value))
        return None

    def close(self):
        self.closed = True
        EVENTS.append(("dma_close",))


class FakeClock:
    now = 0

    @classmethod
    def ticks_us(cls):
        cls.now += 1000 if FakeDMA.busy_forever else 0
        return cls.now

    @staticmethod
    def ticks_add(t, d):
        return t + d

    @staticmethod
    def ticks_diff(a, b):
        return a - b


def _install_fakes(resets_held=0):
    """Install fake MicroPython modules, reset the shared state, return (capture, mem)."""
    mem = FakeMem(resets_held)
    machine = types.ModuleType("machine")
    machine.mem32 = mem
    machine.freq = lambda: 150000000
    rp2 = types.ModuleType("rp2")
    rp2.DMA = FakeDMA
    time = types.ModuleType("time")
    time.ticks_us = FakeClock.ticks_us
    time.ticks_add = FakeClock.ticks_add
    time.ticks_diff = FakeClock.ticks_diff
    uctypes = types.ModuleType("uctypes")
    uctypes.addressof = lambda b: 0x20001000
    sys.modules["machine"] = machine
    sys.modules["rp2"] = rp2
    sys.modules["time"] = time
    sys.modules["uctypes"] = uctypes
    FakeDMA.instances = []
    FakeDMA.busy_forever = False
    FakeClock.now = 0
    del EVENTS[:]
    if "capture" in sys.modules:
        del sys.modules["capture"]
    import capture  # noqa: E402  (silicon-ref/capture.py, after the fakes are in place)
    return capture, mem


PINS = dict(out_base=0, out_count=1, set_base=0, sideset_base=0, in_base=0, jmp_pin=0)


def _run_ws2812(resets_held=0, **kw):
    capture, mem = _install_fakes(resets_held)
    d = tempfile.mkdtemp()
    args = dict(program_json=WS2812_JSON, program_name="ws2812", pins=PINS, capture_base=0,
                samples=8, out_path=os.path.join(d, "t.jsonl"))
    args.update(kw)
    capture.run(**args)
    return capture, mem


def _writes_to(mem, addr):
    return [v for a, v in mem.log if a == addr]


# The exact register write sequence for the ws2812 program (first program, samples=8,
# PINS as above). Filled in from the first review run and checked field by field against
# the header bit positions in capture.py. [verify on hardware]
EXPECTED_LOG = [
    # PIO0 CTRL off, FDEBUG clear, instruction memory (ws2812 at 0..3, `in pins, 8` at 4)
    (0x50200000, 0x00000000), (0x50200008, 0x0f0f0f0f),
    (0x50200048, 0x00006321), (0x5020004c, 0x00001223), (0x50200050, 0x00001200),
    (0x50200054, 0x0000a242), (0x50200058, 0x00004008),
    # SM0 (program): CLKDIV 1.0, EXECCTRL wrap 3..0, SHIFTCTRL out/in right, PINCTRL side 1,
    # set 5, out 1. SM1 (capture): CLKDIV 1.0, EXECCTRL wrap 4..4, SHIFTCTRL in right + autopush
    (0x502000c8, 0x00010000), (0x502000cc, 0x00003000), (0x502000d0, 0x000c0000),
    (0x502000dc, 0x34100000),
    (0x502000e0, 0x00010000), (0x502000e4, 0x00004200), (0x502000e8, 0x000d0000),
    (0x502000f4, 0x00000000),
    # FIFO flush: FJOIN_RX (bit 31) toggled, then restored, on SM0 then SM1
    (0x502000d0, 0x800c0000), (0x502000d0, 0x000c0000),
    (0x502000e8, 0x800d0000), (0x502000e8, 0x000d0000),
    # pads 0..7: FUNCSEL = PIO0 (6), then ISO and OD cleared (mock pads start at 0)
    (0x40028004, 0x00000006), (0x40038004, 0x00000000),
    (0x4002800c, 0x00000006), (0x40038008, 0x00000000),
    (0x40028014, 0x00000006), (0x4003800c, 0x00000000),
    (0x4002801c, 0x00000006), (0x40038010, 0x00000000),
    (0x40028024, 0x00000006), (0x40038014, 0x00000000),
    (0x4002802c, 0x00000006), (0x40038018, 0x00000000),
    (0x40028034, 0x00000006), (0x4003801c, 0x00000000),
    (0x4002803c, 0x00000006), (0x40038020, 0x00000000),
    # sampled pads: input enable (bit 6) set
    (0x40038004, 0x00000040), (0x40038008, 0x00000040),
    (0x4003800c, 0x00000040), (0x40038010, 0x00000040),
    (0x40038014, 0x00000040), (0x40038018, 0x00000040),
    (0x4003801c, 0x00000040), (0x40038020, 0x00000040),
    # SM0 PINCTRL restored, PCs set by jmp via SMn_INSTR (SM0 -> 0, SM1 -> 4)
    (0x502000dc, 0x34100000), (0x502000d8, 0x00000000), (0x502000f0, 0x00000004),
    # restart of both SMs and clock dividers (both disabled), then the single enable
    (0x50200000, 0x00000330), (0x50200000, 0x00000003),
    # stop (normal path), stop (finally), FDEBUG read-back cleared
    (0x50200000, 0x00000000), (0x50200000, 0x00000000), (0x50200008, 0x00000000),
]


def test_write_sequence_is_exact():
    _, mem = _run_ws2812()
    if EXPECTED_LOG is None:
        raise AssertionError("EXPECTED_LOG not set; actual log:\n" + "\n".join(
            "(0x%08x, 0x%08x)" % w for w in mem.log))
    assert mem.log == EXPECTED_LOG, "write sequence differs"


def test_enable_is_one_write_right_after_restart():
    _, mem = _run_ws2812()
    enables = [i for i, (a, v) in enumerate(mem.log) if a == PIO_CTRL and v & EN_BOTH]
    assert len(enables) == 1, "exactly one write may set both SM_ENABLE bits"
    e = enables[0]
    prev_addr, prev_val = mem.log[e - 1]
    assert prev_addr == PIO_CTRL and prev_val == RESTART_WRITE, \
        "the write just before the enable must be the restart, with both SMs disabled"


def test_config_and_pc_writes_all_before_restart():
    _, mem = _run_ws2812()
    restart = mem.log.index((PIO_CTRL, RESTART_WRITE))
    cfg_addrs = {sm_reg(n, name) for n in (0, 1) for name in SM_OFF}
    cfg_writes = [i for i, (a, _) in enumerate(mem.log) if a in cfg_addrs]
    assert cfg_writes and max(cfg_writes) < restart


def test_iso_and_od_cleared_on_driven_and_sampled_pins():
    _, mem = _run_ws2812()
    for pin in range(0, 8):
        pad = PADS_BANK0_BASE + 4 + 4 * pin
        last = _writes_to(mem, pad)[-1]
        assert last & (1 << 8) == 0, "ISO must be cleared on GPIO %d" % pin
        assert last & (1 << 7) == 0, "OD must be cleared on GPIO %d" % pin
        assert last & (1 << 6), "IE must be set on sampled GPIO %d" % pin


def test_fifos_flushed_by_fjoin_rx_toggle_before_dma_arm():
    """Each SM's SHIFTCTRL ends with (value ^ FJOIN_RX, value) before the DMA is armed."""
    _run_ws2812()
    arm = EVENTS.index(("dma_arm", 1))
    for n in (0, 1):
        addr = sm_reg(n, "shiftctrl")
        before_arm = [e[2] for e in EVENTS[:arm] if e[0] == "w" and e[1] == addr]
        assert len(before_arm) >= 3, "config write plus two flush writes for SM%d" % n
        assert before_arm[-2] == before_arm[-1] ^ FJOIN_RX, \
            "SM%d: FJOIN_RX must be toggled, then restored, before DMA arm" % n
        assert before_arm[-1] & FJOIN_RX == 0, "capture and ws2812 are unjoined here"


def test_repeated_run_writes_same_sequence():
    _, mem1 = _run_ws2812()
    first = list(mem1.log)
    _, mem2 = _run_ws2812()
    assert mem2.log == first, "a second run must issue the same writes as the first"


def test_pio0_and_dma_released_from_reset():
    _, mem = _run_ws2812(resets_held=RESET_PIO0 | RESET_DMA)
    clr = [v for a, v in mem.log if a == RESETS_BASE + ALIAS_CLR + 0x0]
    assert clr == [RESET_PIO0 | RESET_DMA], "PIO0 and DMA must be cleared from RESETS"


def test_dma_closed_and_sms_stopped_on_timeout():
    capture, mem = _install_fakes()
    FakeDMA.busy_forever = True
    d = tempfile.mkdtemp()
    try:
        capture.run(program_json=WS2812_JSON, program_name="ws2812", pins=PINS, capture_base=0,
                    samples=8, out_path=os.path.join(d, "t.jsonl"), dma_timeout_ms=1)
    except RuntimeError:
        pass
    else:
        raise AssertionError("timeout must raise RuntimeError")
    assert FakeDMA.instances[-1].closed, "DMA channel must be released on timeout"
    assert EVENTS[-1] == ("dma_close",), "dma close must be the last event"
    assert _writes_to(mem, PIO_CTRL)[-1] & EN_BOTH == 0, "both SMs must be stopped"


def test_tx_words_limit_checked_before_any_write():
    capture, mem = _install_fakes()
    d = tempfile.mkdtemp()
    try:
        capture.run(program_json=WS2812_JSON, program_name="ws2812", pins=PINS, capture_base=0,
                    samples=8, out_path=os.path.join(d, "t.jsonl"), tx_words=[1, 2, 3, 4, 5])
    except ValueError:
        pass
    else:
        raise AssertionError("5 TX words must be rejected without fifo_join='tx'")
    assert mem.log == [], "validation must fail before any register write"


TESTS = [v for k, v in sorted(globals().items()) if k.startswith("test_") and callable(v)]


def run_all():
    failed = 0
    for t in TESTS:
        try:
            t()
        except AssertionError as e:
            failed += 1
            print("FAIL %s: %s" % (t.__name__, e))
        else:
            print("ok   %s" % t.__name__)
    print("%d tests, %d failed" % (len(TESTS), failed))
    return failed


if __name__ == "__main__":
    sys.exit(1 if run_all() else 0)
