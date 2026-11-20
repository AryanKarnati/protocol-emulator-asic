# SPDX-License-Identifier: Apache-2.0
#
# cocotb test for the block 1 gate design, written from docs/gate.md only.
#
# Only top-level pins are used, so the same file runs on the RTL and on the
# gate-level netlist. Each cycle:
#   - inputs are driven just after the falling edge,
#   - outputs are sampled 4 ns later (still well before the rising edge),
#   - the command takes effect at the following rising edge.
# The Python reference model below (class Model) is the scoreboard. Every
# cycle, all outputs are compared with the model, except where the spec
# leaves behaviour open (the phase of the divider tick).

import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer

# Clock period: 1 / 60 MHz = 16.667 ns. cocotb needs an even period in ps, so use 16666 ps.
CLK_PERIOD_PS = 16666
SAMPLE_DELAY_PS = 4000  # after the falling edge, before the rising edge

CMD_NOP = 0b000
CMD_PUSH = 0b001
CMD_POP = 0b010
CMD_INT_LO = 0b011
CMD_INT_HI = 0b100
CMD_FRAC = 0b101
CMD_DIV_RESTART = 0b110
CMD_CLEAR_FLAGS = 0b111

XOR_CONST = 0x0123_4567

CYCLES = {"total": 0}  # simulated cycles, summed over all tests


def word_for(data):
    """W = {DATA,DATA,DATA,DATA} ^ 0x01234567."""
    return ((data * 0x0101_0101) ^ XOR_CONST) & 0xFFFF_FFFF


class Model:
    """Reference model of docs/gate.md. Commands act at the rising edge."""

    def __init__(self):
        self.reset()

    def reset(self):
        self.fifo = []  # index 0 is the head word
        self.overflow = 0
        self.underflow = 0
        self.div_int = 1
        self.div_frac = 0
        # TICK is only predictable while the divider is in its reset state,
        # or in the spec's INT=1/FRAC=0 case with no config write and no restart.
        self.tick_known = True

    def apply(self, cmd, data):
        if cmd == CMD_PUSH:
            if len(self.fifo) < 4:
                self.fifo.append(word_for(data))
            else:
                self.overflow = 1
        elif cmd == CMD_POP:
            if self.fifo:
                self.fifo.pop(0)
            else:
                self.underflow = 1
        elif cmd == CMD_INT_LO:
            self.div_int = (self.div_int & 0xFF00) | data
            self.tick_known = False
        elif cmd == CMD_INT_HI:
            self.div_int = (self.div_int & 0x00FF) | (data << 8)
            self.tick_known = False
        elif cmd == CMD_FRAC:
            self.div_frac = data
            self.tick_known = False
        elif cmd == CMD_DIV_RESTART:
            self.tick_known = False
        elif cmd == CMD_CLEAR_FLAGS:
            self.overflow = 0
            self.underflow = 0
        # NOP: nothing

    def head_byte(self, sel):
        if not self.fifo:
            return 0
        return (self.fifo[0] >> (8 * sel)) & 0xFF

    def status_no_tick(self):
        level = len(self.fifo)
        return ((level & 0x7) << 4) | ((level == 4) << 3) | ((level == 0) << 2) \
            | (self.overflow << 1) | self.underflow


class Bench:
    """Drives one cycle at a time and checks every output against the model."""

    def __init__(self, dut, seed):
        self.dut = dut
        self.model = Model()
        self.rng = random.Random(seed)

    def pack(self, cmd, sel, view, hi):
        return (hi << 6) | (view << 5) | (sel << 3) | cmd

    async def cycle(self, cmd=CMD_NOP, data=None, sel=0, view=0, ena=1, check=True):
        """One clock cycle. Returns the raw sampled uo_out as an int, and the TICK bit."""
        dut = self.dut
        if data is None:
            data = self.rng.randrange(256)  # DATA is ignored unless the command uses it
        hi = self.rng.randrange(4)  # ui_in[7:6] must be ignored

        await FallingEdge(dut.clk)
        dut.ui_in.value = self.pack(cmd, sel, view, hi)
        dut.uio_in.value = data
        dut.ena.value = ena
        await Timer(SAMPLE_DELAY_PS, unit="ps")

        uo = int(dut.uo_out.value)
        uio_oe = int(dut.uio_oe.value)
        uio_out = int(dut.uio_out.value)
        CYCLES["total"] += 1

        if check:
            self._check(uo, uio_oe, uio_out, view, sel)

        await RisingEdge(dut.clk)  # the command takes effect here
        self.model.apply(cmd, data)
        return uo

    def _check(self, uo, uio_oe, uio_out, view, sel):
        m = self.model
        assert uio_oe == 0x00, f"uio_oe = {uio_oe:#04x}, expected 0x00"
        assert uio_out == 0x00, f"uio_out = {uio_out:#04x}, expected 0x00"
        if view == 0:
            exp = m.head_byte(sel)
            assert uo == exp, (
                f"uo_out (head byte, sel={sel}) = {uo:#04x}, expected {exp:#04x}; "
                f"fifo={[hex(w) for w in m.fifo]}"
            )
        else:
            exp = m.status_no_tick()
            got = uo & 0x7F
            assert got == exp, (
                f"STATUS (without TICK) = {got:#04x}, expected {exp:#04x}; "
                f"fifo depth={len(m.fifo)} ovf={m.overflow} unf={m.underflow}"
            )
            if m.tick_known:
                assert uo & 0x80, f"TICK = 0 but spec says TICK = 1 here; STATUS={uo:#04x}"

    async def idle(self, n, view=1):
        for _ in range(n):
            await self.cycle(CMD_NOP, view=view)

    async def push(self, data, **kw):
        await self.cycle(CMD_PUSH, data=data, **kw)

    async def pop(self, **kw):
        await self.cycle(CMD_POP, **kw)

    async def status(self):
        return await self.cycle(CMD_NOP, view=1)

    async def load_int(self, value):
        """Load INT (16 bits) with INT_LO and INT_HI. No restart."""
        await self.cycle(CMD_INT_LO, data=value & 0xFF)
        await self.cycle(CMD_INT_HI, data=(value >> 8) & 0xFF)

    async def load_frac(self, value):
        await self.cycle(CMD_FRAC, data=value)

    async def restart(self):
        """DIV_RESTART. Returns nothing; ticks are observed from the next cycle on."""
        await self.cycle(CMD_DIV_RESTART)


async def start(dut, seed=1):
    """Start the clock, reset, and return a Bench that is in the reset state."""
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_PS, unit="ps").start())
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    for _ in range(5):
        await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    dut.rst_n.value = 1
    bench = Bench(dut, seed)
    # The release goes through a 2-FF synchronizer. Idle cycles are checked too.
    await bench.idle(4)
    return bench


async def collect_gaps(bench, n_ticks, max_cycles):
    """After a DIV_RESTART, record the cycle index of each TICK (from the cycle after
    the restart) until n_ticks ticks are seen. Returns the list of tick indices.
    Ticks are only compared with each other, never with the restart cycle, since
    the phase of the first tick is not specified."""
    ticks = []
    for i in range(max_cycles):
        uo = await bench.cycle(CMD_NOP, view=1)
        if uo & 0x80:
            ticks.append(i)
            if len(ticks) >= n_ticks:
                return ticks
    raise AssertionError(f"only {len(ticks)} ticks in {max_cycles} cycles, wanted {n_ticks}")


def assert_gaps_in(ticks, lo, hi):
    gaps = [b - a for a, b in zip(ticks, ticks[1:])]
    bad = [(k, g) for k, g in enumerate(gaps) if not (lo <= g <= hi)]
    assert not bad, f"tick gaps outside [{lo}, {hi}] at (index, gap): {bad[:8]}"
    return gaps


def assert_256_windows(ticks, total):
    """Every window of 256 consecutive gaps sums to `total` cycles.
    A window of 256 gaps spans ticks[i] .. ticks[i+256]."""
    n = 0
    for i in range(len(ticks) - 256):
        span = ticks[i + 256] - ticks[i]
        assert span == total, f"256-gap window at tick {i} spans {span} cycles, expected {total}"
        n += 1
    assert n > 0, "not enough ticks for a 256-gap window"
    return n


def log_cycles(dut, name, before):
    dut._log.info(f"{name}: {CYCLES['total'] - before} cycles")


# ---------------------------------------------------------------------------
# 1. Reset state
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_reset_state(dut):
    before = CYCLES["total"]
    b = await start(dut, seed=11)

    # STATUS: TICK=1, LEVEL=0, EMPTY=1, no flags = 0x84 with TICK as bit 7.
    for _ in range(20):
        s = await b.status()
        assert s == 0x84, f"reset STATUS = {s:#04x}, expected 0x84 (TICK=1, EMPTY=1)"

    # Head view is 0 when empty, for every BYTE_SEL.
    for sel in range(4):
        v = await b.cycle(CMD_NOP, view=0, sel=sel)
        assert v == 0x00, f"empty head byte sel={sel} = {v:#04x}"

    # uio pins are all inputs and drive 0.
    await b.cycle(CMD_NOP, view=0)
    dut_oe = int(dut.uio_oe.value)
    dut_out = int(dut.uio_out.value)
    assert dut_oe == 0 and dut_out == 0, f"uio_oe={dut_oe:#04x} uio_out={dut_out:#04x}"

    log_cycles(dut, "test_reset_state", before)


# ---------------------------------------------------------------------------
# 2. Push / pop ordering, data word, and LEVEL
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_push_pop_order(dut):
    before = CYCLES["total"]
    b = await start(dut, seed=22)

    # The word formula, checked against one hand-computed value:
    # 0x5A5A5A5A ^ 0x01234567 = 0x5B791F3D.
    assert word_for(0x5A) == 0x5B791F3D, "model word formula is wrong"

    datas = [0x5A, 0x00, 0xFF, 0x3C]
    levels = []
    for d in datas:
        await b.push(d)
        levels.append((await b.status()) >> 4 & 0x7)
    assert levels == [1, 2, 3, 4], f"LEVEL after each push = {levels}"

    # Head word shows through all four BYTE_SELs.
    head = word_for(datas[0])
    for sel in range(4):
        v = await b.cycle(CMD_NOP, view=0, sel=sel)
        exp = (head >> (8 * sel)) & 0xFF
        assert v == exp, f"head sel={sel}: {v:#04x}, expected {exp:#04x}"

    # Pops return words in push order. LEVEL drops after each pop.
    for k, d in enumerate(datas):
        head = word_for(d)
        for sel in range(4):
            v = await b.cycle(CMD_NOP, view=0, sel=sel)
            assert v == (head >> (8 * sel)) & 0xFF, f"word {k} sel {sel} mismatch"
        await b.pop()
        lvl = (await b.status()) >> 4 & 0x7
        assert lvl == len(datas) - k - 1, f"LEVEL after pop {k} = {lvl}"

    # Interleaved push/pop keeps FIFO order.
    await b.push(0x11)
    await b.push(0x22)
    await b.pop()
    await b.push(0x33)
    await b.pop()
    await b.pop()
    await b.idle(3)
    s = await b.status()
    assert s == 0x84, f"empty again but STATUS = {s:#04x}"

    log_cycles(dut, "test_push_pop_order", before)


# ---------------------------------------------------------------------------
# 3. FULL, OVERFLOW, UNDERFLOW, CLEAR_FLAGS, NOP, ignored bits
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_full_and_flags(dut):
    before = CYCLES["total"]
    b = await start(dut, seed=33)

    # POP on empty sets UNDERFLOW.
    await b.pop()
    s = await b.status()
    assert s == 0x84 | 0x01, f"after POP on empty STATUS = {s:#04x}, expected 0x85"

    # NOP changes nothing.
    for _ in range(5):
        await b.cycle(CMD_NOP)
    assert (await b.status()) == 0x85, "NOP changed STATUS"

    # Clear flags.
    await b.cycle(CMD_CLEAR_FLAGS)
    assert (await b.status()) == 0x84, "CLEAR_FLAGS did not clear UNDERFLOW"

    # Fill to FULL at 4 words.
    words = [0x10, 0x20, 0x30, 0x40]
    for d in words:
        await b.push(d)
    s = await b.status()
    assert s == 0x80 | (4 << 4) | 0x08, f"FULL STATUS = {s:#04x}, expected 0xC8"

    # 5th push: dropped, OVERFLOW set, FIFO unchanged.
    await b.push(0x99)
    s = await b.status()
    assert s == 0xC8 | 0x02, f"after overflow STATUS = {s:#04x}, expected 0xCA"
    v = await b.cycle(CMD_NOP, view=0, sel=0)
    assert v == word_for(0x10) & 0xFF, "head changed by overflowing push"

    # Another POP on empty while FULL is impossible, so test UNDERFLOW together with
    # OVERFLOW: drain the FIFO, then pop once more.
    for _ in range(4):
        await b.pop()
    s = await b.status()
    assert s == 0x84 | 0x02, f"drained with OVERFLOW set, STATUS = {s:#04x}, expected 0x86"
    await b.pop()
    s = await b.status()
    assert s == 0x84 | 0x03, f"both flags set, STATUS = {s:#04x}, expected 0x87"

    # NOP and data/ignored-bit noise keep both flags.
    await b.idle(4)
    assert (await b.status()) == 0x87, "flags changed without CLEAR_FLAGS"

    # CLEAR_FLAGS clears both.
    await b.cycle(CMD_CLEAR_FLAGS)
    assert (await b.status()) == 0x84, "CLEAR_FLAGS did not clear both flags"

    # Sticky: a flag stays set across many clocks until cleared.
    await b.pop()
    await b.idle(30)
    assert (await b.status()) == 0x85, "UNDERFLOW was not sticky"
    await b.cycle(CMD_CLEAR_FLAGS)

    log_cycles(dut, "test_full_and_flags", before)


# ---------------------------------------------------------------------------
# 4. Divider with FRAC = 0
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_divider_frac0(dut):
    before = CYCLES["total"]
    b = await start(dut, seed=44)

    # INT = 1: TICK is 1 in every cycle.
    await b.load_int(1)
    await b.load_frac(0)
    await b.restart()
    ticks = await collect_gaps(b, 40, 80)
    assert_gaps_in(ticks, 1, 1)

    # INT = 3: ticks exactly 3 cycles apart.
    await b.load_int(3)
    await b.restart()
    ticks = await collect_gaps(b, 12, 60)
    gaps = assert_gaps_in(ticks, 3, 3)
    assert len(gaps) >= 10

    # INT = 0x0102 = 258, using INT_HI. Check a handful of gaps only.
    await b.cycle(CMD_INT_LO, data=0x02)
    await b.cycle(CMD_INT_HI, data=0x01)
    await b.load_frac(0)
    await b.restart()
    ticks = await collect_gaps(b, 4, 258 * 6)
    assert_gaps_in(ticks, 258, 258)

    log_cycles(dut, "test_divider_frac0", before)


# ---------------------------------------------------------------------------
# 5. Divider with FRAC != 0
# ---------------------------------------------------------------------------
async def run_fractional(b, int_v, frac, n_ticks):
    await b.load_int(int_v)
    await b.load_frac(frac)
    await b.restart()
    # 256-gap windows need at least 257 ticks. Use n_ticks >= 257.
    max_cycles = (int_v + 1) * (n_ticks + 2) + 16
    ticks = await collect_gaps(b, n_ticks, max_cycles)
    assert_gaps_in(ticks, int_v, int_v + 1)
    total = 256 * int_v + frac
    windows = assert_256_windows(ticks, total)
    b.dut._log.info(
        f"INT={int_v} FRAC={frac:#04x}: {len(ticks)} ticks, {windows} windows of 256 gaps, "
        f"each summing to {total}"
    )


@cocotb.test()
async def test_divider_frac_2_5(dut):
    before = CYCLES["total"]
    b = await start(dut, seed=55)
    await run_fractional(b, 2, 0x80, 300)  # 2.5
    log_cycles(dut, "test_divider_frac_2_5", before)


@cocotb.test()
async def test_divider_frac_1_25(dut):
    before = CYCLES["total"]
    b = await start(dut, seed=66)
    await run_fractional(b, 1, 0x40, 300)  # 1.25
    log_cycles(dut, "test_divider_frac_1_25", before)


# ---------------------------------------------------------------------------
# 6. INT/FRAC loaded without DIV_RESTART, then restarted
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_load_without_restart(dut):
    before = CYCLES["total"]
    b = await start(dut, seed=77)

    # Change the divisor several times with no restart. Behaviour in this window is
    # not asserted (the scoreboard still checks FIFO and flags).
    await b.load_int(5)
    await b.load_frac(0x40)
    await b.idle(40, view=1)
    await b.load_int(6)
    await b.load_frac(0x10)
    await b.idle(15, view=1)

    # Once restarted, the bounds and the 256-gap window apply to the new divisor.
    await b.restart()
    await run_fractional(b, 6, 0x10, 260)
    log_cycles(dut, "test_load_without_restart", before)


# ---------------------------------------------------------------------------
# 7. Reset in the middle of activity
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_reset_mid_activity(dut):
    before = CYCLES["total"]
    b = await start(dut, seed=88)

    # Build up activity: divider changed, FIFO partly filled, both flags set.
    await b.load_int(5)
    await b.load_frac(0x40)
    await b.restart()
    await b.idle(20)
    for d in [0xA1, 0xA2, 0xA3]:
        await b.push(d)
    for _ in range(3):
        await b.push(0xEE)  # the 4th push fills, the 5th and later set OVERFLOW
    await b.pop()
    await b.pop()
    await b.pop()
    await b.pop()
    await b.pop()  # underflow
    # Drained, with OVERFLOW and UNDERFLOW both set. TICK is not predicted here.
    s = await b.status()
    assert s & 0x7F == 0x07, f"setup STATUS (without TICK) = {s:#04x}, expected 0x07"

    # Assert reset asynchronously, mid-cycle (just after the falling edge, no clock edge).
    # PUSH with VIEW=0 is on the pins: it must have no effect under reset.
    await FallingEdge(dut.clk)
    dut.rst_n.value = 0
    dut.ui_in.value = 0b0000_0001  # PUSH, VIEW=0, BYTE_SEL=0
    dut.uio_in.value = 0x5C
    await Timer(1000, unit="ps")
    b.model.reset()
    uo = int(dut.uo_out.value)
    assert uo == 0x00, f"under reset head view = {uo:#04x}, expected 0x00"
    dut.ui_in.value = 0b0010_0000  # VIEW=1, NOP
    await Timer(1000, unit="ps")
    uo = int(dut.uo_out.value)
    assert uo == 0x84, f"under reset STATUS = {uo:#04x}, expected reset value 0x84"
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    dut.ui_in.value = 0b0010_0000
    await Timer(SAMPLE_DELAY_PS, unit="ps")
    uo = int(dut.uo_out.value)
    CYCLES["total"] += 1
    assert uo == 0x84, f"still in reset, STATUS = {uo:#04x}, expected 0x84"
    await RisingEdge(dut.clk)

    # Hold reset for a few cycles, then release. Afterwards, everything is the reset state.
    for _ in range(3):
        await FallingEdge(dut.clk)
        await Timer(SAMPLE_DELAY_PS, unit="ps")
        uo = int(dut.uo_out.value)
        CYCLES["total"] += 1
        assert uo == 0x84, f"during reset STATUS = {uo:#04x}"
        await RisingEdge(dut.clk)

    await FallingEdge(dut.clk)
    dut.rst_n.value = 1
    b.model.reset()
    await b.idle(4)  # synchronizer release
    for _ in range(20):
        s = await b.status()
        assert s == 0x84, f"after reset STATUS = {s:#04x}, expected 0x84"
    for sel in range(4):
        v = await b.cycle(CMD_NOP, view=0, sel=sel)
        assert v == 0x00, f"after reset head byte sel={sel} = {v:#04x}"

    log_cycles(dut, "test_reset_mid_activity", before)


# ---------------------------------------------------------------------------
# 8. Random FIFO traffic with the scoreboard, and ena toggling (ignored)
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_random_fifo(dut):
    before = CYCLES["total"]
    b = await start(dut, seed=99)
    rng = random.Random(4321)
    cmds = [CMD_NOP, CMD_PUSH, CMD_PUSH, CMD_POP, CMD_POP, CMD_CLEAR_FLAGS]
    for _ in range(1500):
        cmd = rng.choice(cmds)
        sel = rng.randrange(4)
        view = rng.randrange(2)
        ena = rng.randrange(2)  # ena is ignored
        await b.cycle(cmd, sel=sel, view=view, ena=ena)
    log_cycles(dut, "test_random_fifo", before)
    dut._log.info(f"total simulated cycles so far: {CYCLES['total']}")
