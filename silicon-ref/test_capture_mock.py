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
PAD_RESET = 0x116                 # pads_bank0.h PADS_BANK0_GPIO0_RESET
PAD_ISO = 1 << 8                  # pads_bank0.h PADS_BANK0_GPIO0_ISO_BITS
PAD_OD = 1 << 7                   # PADS_BANK0_GPIO0_OD_BITS
PAD_IE = 1 << 6                   # PADS_BANK0_GPIO0_IE_BITS
PAD_OTHER = 0x16                  # reset bits that must survive: DRIVE, PDE, SCHMITT
RESET_DMA = 1 << 2
RESET_PIO0 = 1 << 11
SM_RESTART_BITS = 0x0F0           # CTRL[7:4], self-clearing
CLKDIV_RESTART_BITS = 0xF00       # CTRL[11:8], self-clearing
EN_BOTH = 0x3
RESTART_WRITE = 0x330             # SM_RESTART for SM0 and SM1, CLKDIV_RESTART for SM0 and SM1
FJOIN_RX = 1 << 31

EVENTS = []                       # ordered: ("w", addr, value), ("dma_arm", v), ("dma_close",)
BUFFERS = {}                      # fake address -> bytearray, for uctypes.addressof
SYNTH = None                      # optional fn(word_index) -> 32-bit RX word, else zeros


def sm_reg(n, name):
    return SM0_BASE + SM_STRIDE * n + SM_OFF[name]


class FakeMem:
    """Stands in for machine.mem32. Keeps register values and logs every write."""

    def __init__(self, resets_held=0):
        self.values = {RESETS_RESET: resets_held}
        # Pads start at their reset value (pads_bank0.h PADS_BANK0_GPIO0_RESET = 0x116:
        # ISO 0x100 = 1, DRIVE 0x10 = 1, PDE 0x4 = 1, SCHMITT 0x2 = 1, others 0).
        for n in range(30):
            self.values[PADS_BANK0_BASE + 4 + 4 * n] = PAD_RESET
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
        if value and self.config_args and SYNTH is not None:
            # Fill the destination buffer with synthetic RX words (the fixture generator only).
            buf = BUFFERS[self.config_args["write"]]
            for i in range(self.config_args["count"]):
                buf[4 * i:4 * i + 4] = (SYNTH(i) & 0xFFFFFFFF).to_bytes(4, "little")
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


def _addressof(buf):
    addr = 0x20001000 + 0x1000 * len(BUFFERS)
    BUFFERS[addr] = buf
    return addr


def _install_fakes(resets_held=0, synth=None):
    """Install fake MicroPython modules, reset the shared state, return (capture, mem)."""
    global SYNTH
    SYNTH = synth
    BUFFERS.clear()
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
    uctypes.addressof = _addressof
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
    # pads 0..7: FUNCSEL = PIO0 (6); the pad write clears ISO and OD (0x116 -> 0x016)
    (0x40028004, 0x00000006), (0x40038004, 0x00000016),
    (0x4002800c, 0x00000006), (0x40038008, 0x00000016),
    (0x40028014, 0x00000006), (0x4003800c, 0x00000016),
    (0x4002801c, 0x00000006), (0x40038010, 0x00000016),
    (0x40028024, 0x00000006), (0x40038014, 0x00000016),
    (0x4002802c, 0x00000006), (0x40038018, 0x00000016),
    (0x40028034, 0x00000006), (0x4003801c, 0x00000016),
    (0x4002803c, 0x00000006), (0x40038020, 0x00000016),
    # sampled pads: input enable (bit 6) added (0x016 -> 0x056)
    (0x40038004, 0x00000056), (0x40038008, 0x00000056),
    (0x4003800c, 0x00000056), (0x40038010, 0x00000056),
    (0x40038014, 0x00000056), (0x40038018, 0x00000056),
    (0x4003801c, 0x00000056), (0x40038020, 0x00000056),
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
    """The pad starts at PAD_RESET (ISO = 1). The first pad write must clear ISO and OD and
    keep the other reset bits, and the IE write must set only bit 6 on top of that."""
    _, mem = _run_ws2812()
    assert PAD_RESET & PAD_ISO, "reset value must have ISO set, or this test proves nothing"
    for pin in range(0, 8):
        pad = PADS_BANK0_BASE + 4 + 4 * pin
        writes = _writes_to(mem, pad)
        assert len(writes) == 2, "GPIO %d: one ISO/OD clear, one IE write" % pin
        cleared, enabled = writes
        assert cleared & PAD_ISO == 0, "ISO must be cleared on GPIO %d" % pin
        assert cleared & PAD_OD == 0, "OD must be cleared on GPIO %d" % pin
        assert cleared & 0xFF == PAD_OTHER, "other reset bits must survive on GPIO %d" % pin
        assert enabled & PAD_IE, "IE must be set on sampled GPIO %d" % pin
        assert enabled & PAD_ISO == 0 and enabled & PAD_OD == 0
        assert enabled == (PAD_OTHER | PAD_IE), "GPIO %d: only IE added to the cleared pad" % pin


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


OVERRIDE_ARGS = dict(
    tx_words=[1, 2],
    init_dirs={0: 1},
    init_levels={0: 1, 1: 0, 3: 1},
    fifo_join="tx",
    out_shift_right=False,
    autopull=True,
    pull_thresh=24,
    clkdiv=(2, 128),
)

# Full write log for the ws2812 program with OVERRIDE_ARGS. Frozen from the first review run,
# after the explicit value checks in test_override_path_values pass. [verify on hardware]
EXPECTED_OVERRIDE_LOG = [
    # OVERRIDE_ARGS: clkdiv 2.128, SHIFTCTRL TX join, out left, autopull, pull 24, set pindirs,
    # set pins, 2 TX words, pads with ISO cleared (0x016) and IE (0x056)
    (0x50200000, 0x00000000),
    (0x50200008, 0x0f0f0f0f),
    (0x50200048, 0x00006321),
    (0x5020004c, 0x00001223),
    (0x50200050, 0x00001200),
    (0x50200054, 0x0000a242),
    (0x50200058, 0x00004008),
    (0x502000c8, 0x00028000),
    (0x502000cc, 0x00003000),
    (0x502000d0, 0x70060000),
    (0x502000dc, 0x34100000),
    (0x502000e0, 0x00010000),
    (0x502000e4, 0x00004200),
    (0x502000e8, 0x000d0000),
    (0x502000f4, 0x00000000),
    (0x502000d0, 0xf0060000),
    (0x502000d0, 0x70060000),
    (0x502000e8, 0x800d0000),
    (0x502000e8, 0x000d0000),
    (0x40028004, 0x00000006),
    (0x40038004, 0x00000016),
    (0x4002800c, 0x00000006),
    (0x40038008, 0x00000016),
    (0x40028014, 0x00000006),
    (0x4003800c, 0x00000016),
    (0x4002801c, 0x00000006),
    (0x40038010, 0x00000016),
    (0x40028024, 0x00000006),
    (0x40038014, 0x00000016),
    (0x4002802c, 0x00000006),
    (0x40038018, 0x00000016),
    (0x40028034, 0x00000006),
    (0x4003801c, 0x00000016),
    (0x4002803c, 0x00000006),
    (0x40038020, 0x00000016),
    (0x40038004, 0x00000056),
    (0x40038008, 0x00000056),
    (0x4003800c, 0x00000056),
    (0x40038010, 0x00000056),
    (0x40038014, 0x00000056),
    (0x40038018, 0x00000056),
    (0x4003801c, 0x00000056),
    (0x40038020, 0x00000056),
    (0x502000dc, 0x04000000),
    (0x502000d8, 0x0000e081),
    (0x502000dc, 0x08000000),
    (0x502000d8, 0x0000e001),
    (0x502000dc, 0x04000060),
    (0x502000d8, 0x0000e001),
    (0x502000dc, 0x34100000),
    (0x50200010, 0x00000001),
    (0x50200010, 0x00000002),
    (0x502000d8, 0x00000000),
    (0x502000f0, 0x00000004),
    (0x50200000, 0x00000330),
    (0x50200000, 0x00000003),
    (0x50200000, 0x00000000),
    (0x50200000, 0x00000000),
    (0x50200008, 0x00000000),
]


def test_override_path_values():
    """Each argument reaches its register as the header bit positions in capture.py say."""
    _, mem = _run_ws2812(**OVERRIDE_ARGS)
    last = lambda addr: _writes_to(mem, addr)[-1]  # noqa: E731
    # clkdiv (2, 128): INT [31:16] = 2, FRAC [15:8] = 128
    assert last(sm_reg(0, "clkdiv")) == 0x00028000
    # SHIFTCTRL: FJOIN_TX [30] | PULL_THRESH 24 [29:25] | IN right [18] | AUTOPULL [17]
    # OUT right is off, so bit 19 is clear. The FJOIN_RX flush keeps FJOIN_TX set.
    assert last(sm_reg(0, "shiftctrl")) == 0x70060000
    # FIFO preload: two words pushed to TXF0 (a FIFO port, so the same address each time)
    txf = [v for a, v in mem.log if a == PIO_TXF0]
    assert txf == [1, 2]
    # set pindirs (0xE080 | value) on group [0]; set pins on groups [0,1] and [3]
    # PINCTRL SET_COUNT [28:26] and SET_BASE [9:5] are written before each set
    instr = [(i, v) for i, (a, v) in enumerate(mem.log) if a == sm_reg(0, "instr")]
    pinctrl = [v for a, v in mem.log if a == sm_reg(0, "pinctrl")]
    assert [v for _, v in instr][:3] == [0xE081, 0xE001, 0xE001], "set instructions"
    assert pinctrl[1:4] == [0x04000000, 0x08000000, 0x04000060], \
        "PINCTRL for each set group, after the config write"
    # PINCTRL restored after the sets, before the PCs are set
    assert pinctrl[4] == 0x34100000
    # all TX preload and set writes happen before the restart
    restart = mem.log.index((PIO_CTRL, RESTART_WRITE))
    assert max(i for i, (a, _) in enumerate(mem.log) if a == PIO_TXF0) < restart
    if EXPECTED_OVERRIDE_LOG is None:
        raise AssertionError("EXPECTED_OVERRIDE_LOG not set; actual log:\n" + "\n".join(
            "(0x%08x, 0x%08x)" % w for w in mem.log))


def test_override_path_write_sequence_is_exact():
    _, mem = _run_ws2812(**OVERRIDE_ARGS)
    assert EXPECTED_OVERRIDE_LOG is not None, "EXPECTED_OVERRIDE_LOG not frozen yet"
    assert mem.log == EXPECTED_OVERRIDE_LOG, "override write sequence differs"


UART_JSON = os.path.join(HERE, "..", "sw", "pgasm", "test", "corpus", "pico-examples",
                         "pio", "uart_tx", "uart_tx.pio.json")


def test_optional_sideset_uart_tx_counts_enable_bit_once():
    """uart_tx is `.side_set 1 opt`: pioasm JSON size = 2 (enable bit included), one data pin.

    SIDESET_COUNT (PINCTRL[31:29]) must be the JSON size, 2, not 3. The side-set pin span
    must be one pin (pin 1). The set span is empty (set_count 0), and capture is on pins 8..15,
    so the only program pads touched are 0 (out), 1 (side-set) and 8..15 (sampled).
    """
    capture, mem = _install_fakes()
    d = tempfile.mkdtemp()
    out = os.path.join(d, "t.jsonl")
    capture.run(program_json=UART_JSON, program_name="uart_tx",
                pins=dict(out_base=0, out_count=1, set_base=0, sideset_base=1,
                          in_base=0, jmp_pin=0),
                capture_base=8, samples=8, out_path=out, set_count=0)
    pinctrl = _writes_to(mem, sm_reg(0, "pinctrl"))[0]
    assert (pinctrl >> 29) & 0x7 == 2, "SIDESET_COUNT must be the JSON size 2 (enable bit included)"
    assert (pinctrl >> 26) & 0x7 == 0, "set count 0"
    execctrl = _writes_to(mem, sm_reg(0, "execctrl"))[0]
    assert execctrl & (1 << 30), "SIDE_EN (optional side-set) must be set"
    assert execctrl & (1 << 29) == 0, "side-set drives pins, not pindirs"
    # pads routed to PIO0 (IO_BANK0 FUNCSEL writes): GPIO n at 0x40028004 + 8n
    funcsel_pins = {(a - 0x40028004) // 8 for a, v in mem.log
                    if 0x40028004 <= a < 0x40028004 + 8 * 32 and v & 0x1F == 6}
    assert funcsel_pins == {0, 1} | set(range(8, 16)), \
        "side-set span must be one pin (1), not two (1 and 2)"
    import json as _json
    with open(out) as f:
        header = _json.loads(f.readline())
    cfg = header["program"]["config"]
    assert cfg["sideset_size"] == 2 and cfg["sideset_data_pins"] == 1
    assert cfg["sideset_optional"] is True


FIXTURE_PATH = os.path.join(HERE, "testdata", "uart_tx_example.jsonl")
FIXTURE_SOURCE = "sw/pgasm/test/corpus/pico-examples/pio/uart_tx/uart_tx.pio.json"
FIXTURE_SAMPLES = 1280            # 320 synthetic 32-bit words


def _synth_word(i):
    """Deterministic pseudo-random 32-bit RX word i (a fixed integer hash, no randomness)."""
    x = (i * 0x9E3779B1 + 0x7F4A7C15) & 0xFFFFFFFF
    x ^= x >> 15
    x = (x * 0x85EBCA6B) & 0xFFFFFFFF
    x ^= x >> 13
    return x


def make_fixture(out_path):
    """Format-contract fixture for pgsim's trace loader.

    The header is the one capture.run() builds (run under the mock, with the uart_tx program:
    tx_words, init levels and dirs, side-set on pin 1). The synthetic RX words come from the mock
    DMA. The file is written by trace.write_trace. Only program.source is rewritten, to the
    repo-relative corpus path, so no workstation path is committed.
    """
    import trace as tr
    capture, _ = _install_fakes(synth=_synth_word)
    raw = os.path.join(tempfile.mkdtemp(), "raw.jsonl")
    capture.run(program_json=UART_JSON, program_name="uart_tx",
                pins=dict(out_base=0, out_count=1, set_base=0, sideset_base=1,
                          in_base=0, jmp_pin=0),
                capture_base=0, samples=FIXTURE_SAMPLES, out_path=raw, set_count=0,
                tx_words=[0xA5, 0x5A], init_dirs={0: 1, 1: 1}, init_levels={0: 1, 1: 1})
    t = tr.read_trace(raw)
    header = t.header
    header["program"]["source"] = FIXTURE_SOURCE
    tr.write_trace(out_path, header, t.samples,
                   rxstall_capture=bool(t.footer.get("rxstall_capture")))
    return out_path


def test_fixture_is_current_and_has_init_and_entry():
    import trace as tr
    fresh = make_fixture(os.path.join(tempfile.mkdtemp(), "f.jsonl"))
    with open(fresh, "rb") as a, open(FIXTURE_PATH, "rb") as b:
        assert a.read() == b.read(), \
            "fixture is stale; regenerate with: python3 silicon-ref/test_capture_mock.py --write-fixture"
    t = tr.read_trace(FIXTURE_PATH)
    prog = t.header["program"]
    assert prog["init"]["tx_words"] == ["0x000000a5", "0x0000005a"]
    assert prog["init"]["levels"] == {"0": 1, "1": 1}
    assert prog["init"]["dirs"] == {"0": 1, "1": 1}
    assert "entry" in prog and prog["entry"] == 0, "uart_tx has no entry_point label, so entry 0"
    assert prog["config"]["sideset_size"] == 2 and prog["config"]["sideset_data_pins"] == 1
    assert len(t.samples) == FIXTURE_SAMPLES, "fixture carries 1280 samples (320 words)"
    assert t.footer["complete"] is True and t.footer["words_total"] == FIXTURE_SAMPLES // 4


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
    if "--write-fixture" in sys.argv:
        os.makedirs(os.path.dirname(FIXTURE_PATH), exist_ok=True)
        print("wrote", make_fixture(FIXTURE_PATH))
        sys.exit(0)
    sys.exit(1 if run_all() else 0)
