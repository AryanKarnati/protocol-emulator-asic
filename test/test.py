# SPDX-License-Identifier: Apache-2.0
#
# cocotb test for the block 1 gate design, written from docs/gate.md only.
#
# Only top-level pins are used, so the same file runs on the RTL and on the
# gate-level netlist. Each cycle:
#   - inputs are driven just after the falling edge (ena, rst_n release too),
#   - outputs are sampled 4 ns later, still well before the rising edge,
#   - a command takes effect at the following rising edge.
# The Python reference model (class Model) is the scoreboard. Every cycle, all
# outputs are compared with it, except where the spec leaves behaviour open.
#
# Edge numbering after reset release: the first rising edge after rst_n goes high
# is edge 1. Commands are ignored at edges 1 and 2 and run from edge 3.
#
# Default tests run in a few tens of thousands of cycles. Set POLYGLOT_LONG=1 to
# also run the tests that need ~65k cycles per tick (INT=0 and INT=300).

import os
import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer

# 1 / 60 MHz = 16.667 ns. cocotb needs an even period in ps, so use 16666 ps.
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
LONG = os.environ.get("POLYGLOT_LONG") == "1"

CYCLES = {"total": 0}  # simulated clock cycles, all tests


def cycle_no():
    return CYCLES["total"]


def check(cond, msg):
    """Assertion that names the cycle number."""
    if not cond:
        raise AssertionError(f"cycle {cycle_no()}: {msg}")


def read_logic(sig, name):
    """Read a signal as an int. Fail with the name, cycle and raw value if X or Z."""
    raw = sig.value
    if not raw.is_resolvable:
        raise AssertionError(f"cycle {cycle_no()}: {name} is not resolvable, raw value {raw}")
    return int(raw)


def word_for(data):
    """W = {DATA,DATA,DATA,DATA} ^ 0x01234567."""
    return ((data * 0x0101_0101) ^ XOR_CONST) & 0xFFFF_FFFF


def pack(cmd, sel, view, hi):
    return (hi << 6) | (view << 5) | (sel << 3) | cmd


class Model:
    """Reference model of docs/gate.md. Commands act at rising edges."""

    def __init__(self):
        self.reset()

    def reset(self):
        self.fifo = []  # index 0 is the head word
        self.overflow = 0
        self.underflow = 0
        self.div_int = 1
        self.div_frac = 0
        self.ignore_edges = 0  # rising edges still to ignore after reset release

    def release(self):
        self.ignore_edges = 2

    def tick_known(self):
        # Property 1: with INT=1 and FRAC=0, TICK is 1 in every cycle, whatever
        # writes or restarts came before.
        return self.div_int == 1 and self.div_frac == 0

    def apply(self, cmd, data):
        if self.ignore_edges > 0:
            self.ignore_edges -= 1
            return
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
        elif cmd == CMD_INT_HI:
            self.div_int = (self.div_int & 0x00FF) | (data << 8)
        elif cmd == CMD_FRAC:
            self.div_frac = data
        elif cmd == CMD_CLEAR_FLAGS:
            self.overflow = 0
            self.underflow = 0
        # NOP and DIV_RESTART: nothing to model here (ticks are checked by property)

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

    async def cycle(self, cmd=CMD_NOP, data=None, sel=0, view=0, ena=None,
                    release=False, in_reset=False):
        """One clock cycle. Returns the sampled uo_out as an int.

        release: drive rst_n high at this falling edge. The next rising edge is edge 1.
        in_reset: rst_n is low, so no command acts and the model stays in reset.
        """
        dut = self.dut
        if data is None:
            data = self.rng.randrange(256)  # DATA is ignored unless the command uses it
        if ena is None:
            ena = self.rng.randrange(2)  # ena is ignored
        hi = self.rng.randrange(4)  # ui_in[7:6] are ignored

        await FallingEdge(dut.clk)
        if release:
            dut.rst_n.value = 1
            self.model.release()
        dut.ui_in.value = pack(cmd, sel, view, hi)
        dut.uio_in.value = data
        dut.ena.value = ena
        await Timer(SAMPLE_DELAY_PS, unit="ps")

        uo = read_logic(dut.uo_out, "uo_out")
        uio_oe = read_logic(dut.uio_oe, "uio_oe")
        uio_out = read_logic(dut.uio_out, "uio_out")
        CYCLES["total"] += 1
        self._check(uo, uio_oe, uio_out, view, sel)

        await RisingEdge(dut.clk)  # the command takes effect here, if it is not ignored
        if not in_reset:
            self.model.apply(cmd, data)
        return uo

    def _check(self, uo, uio_oe, uio_out, view, sel):
        m = self.model
        check(uio_oe == 0x00, f"uio_oe = {uio_oe:#04x}, expected 0x00")
        check(uio_out == 0x00, f"uio_out = {uio_out:#04x}, expected 0x00")
        if view == 0:
            exp = m.head_byte(sel)
            check(uo == exp, f"uo_out (head byte, sel={sel}) = {uo:#04x}, expected {exp:#04x}; "
                             f"fifo={[hex(w) for w in m.fifo]}")
        else:
            exp = m.status_no_tick()
            got = uo & 0x7F
            check(got == exp, f"STATUS without TICK = {got:#04x}, expected {exp:#04x}; "
                              f"depth={len(m.fifo)} ovf={m.overflow} unf={m.underflow}")
            if m.tick_known():
                check(uo & 0x80, f"TICK = 0 but spec says TICK = 1 for INT=1, FRAC=0; STATUS={uo:#04x}")

    async def idle(self, n, view=1):
        for _ in range(n):
            await self.cycle(CMD_NOP, view=view)

    async def push(self, data, view=1):
        await self.cycle(CMD_PUSH, data=data, view=view)

    async def pop(self, view=1):
        await self.cycle(CMD_POP, view=view)

    async def status(self):
        return await self.cycle(CMD_NOP, view=1)

    async def head(self, sel=0):
        return await self.cycle(CMD_NOP, view=0, sel=sel)

    async def load_int(self, value):
        """Load INT with INT_LO then INT_HI. No restart."""
        await self.cycle(CMD_INT_LO, data=value & 0xFF)
        await self.cycle(CMD_INT_HI, data=(value >> 8) & 0xFF)

    async def load_frac(self, value):
        await self.cycle(CMD_FRAC, data=value)


async def start(dut, seed=1):
    """Reset, release, and return a Bench whose next command is at edge 3.

    rst_n is released at a falling edge, so that edge is edge 1. Edge 2 is a NOP.
    """
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_PS, unit="ps").start())
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    for _ in range(5):
        await RisingEdge(dut.clk)
    b = Bench(dut, seed)
    b.model.reset()
    await b.cycle(CMD_NOP, view=1, release=True)  # edge 1 (ignored)
    await b.cycle(CMD_NOP, view=1)  # edge 2 (ignored)
    return b


async def enter_reset(b, dut, hold_cycles):
    """Assert rst_n between edges, check the reset outputs at once, then hold it."""
    await FallingEdge(dut.clk)
    dut.rst_n.value = 0
    b.model.reset()
    dut.ui_in.value = pack(CMD_PUSH, 0, 0, 0)  # PUSH on the pins, must have no effect
    dut.uio_in.value = 0x5C
    await Timer(1000, unit="ps")
    head = read_logic(dut.uo_out, "uo_out")
    check(head == 0x00, f"under reset, head view = {head:#04x}, expected 0x00")
    dut.ui_in.value = pack(CMD_PUSH, 0, 1, 0)
    await Timer(1000, unit="ps")
    st = read_logic(dut.uo_out, "uo_out")
    check(st == 0x84, f"under reset, STATUS = {st:#04x}, expected reset value 0x84")
    for _ in range(hold_cycles):
        s = await b.cycle(CMD_PUSH, data=0x6B, view=1, in_reset=True)
        check(s == 0x84, f"still in reset, STATUS = {s:#04x}, expected 0x84")


async def collect_ticks(b, n_ticks, max_cycles, int_eff):
    """After a DIV_RESTART, return the cycle indices (from the cycle just after the
    restart edge, index 0) of the first n_ticks ticks.

    Checks that the first tick is within INT+1 cycles of the restart."""
    ticks = []
    for i in range(max_cycles):
        s = await b.cycle(CMD_NOP, view=1)
        if s & 0x80:
            ticks.append(i)
            if len(ticks) >= n_ticks:
                break
    check(len(ticks) >= n_ticks, f"only {len(ticks)} ticks in {max_cycles} cycles, wanted {n_ticks}")
    check(ticks[0] <= int_eff + 1, f"first tick at index {ticks[0]}, must be <= INT+1 = {int_eff + 1}")
    return ticks


def gaps_after_first(ticks, lo, hi):
    """Drop the first tick (its phase is not specified), then check every gap is in [lo, hi].
    Returns the remaining tick list."""
    t = ticks[1:]
    gaps = [b - a for a, b in zip(t, t[1:])]
    bad = [(k, g) for k, g in enumerate(gaps) if not (lo <= g <= hi)]
    check(not bad, f"tick gaps outside [{lo}, {hi}] at (index, gap): {bad[:8]}")
    check(len(gaps) >= 1, "not enough ticks to measure a gap")
    return t


def check_256_windows(t, total):
    """Every window of 256 consecutive gaps (ticks t[i] .. t[i+256]) sums to `total`."""
    n = 0
    for i in range(len(t) - 256):
        span = t[i + 256] - t[i]
        check(span == total, f"256-gap window at tick {i} spans {span} cycles, expected {total}")
        n += 1
    check(n > 0, "not enough ticks for a 256-gap window")
    return n


async def run_fractional(b, int_v, frac, n_ticks):
    """Load INT and FRAC, restart, and check the fractional-divider properties."""
    await b.load_int(int_v)
    await b.load_frac(frac)
    await b.cycle(CMD_DIV_RESTART, view=1)
    int_eff = int_v if int_v else 65536
    max_cycles = (int_eff + 1) * (n_ticks + 2) + 16
    ticks = await collect_ticks(b, n_ticks, max_cycles, int_eff)
    t = gaps_after_first(ticks, int_v, int_v + 1)
    total = 256 * int_v + frac
    windows = check_256_windows(t, total)
    b.dut._log.info(f"INT={int_v} FRAC={frac:#04x}: {len(ticks)} ticks, {windows} windows "
                    f"of 256 gaps each summing to {total}")


# ---------------------------------------------------------------------------
# 1. Reset state
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_reset_state(dut):
    b = await start(dut, seed=11)

    # STATUS: TICK=1, LEVEL=0, EMPTY=1, no flags = 0x84.
    for _ in range(20):
        s = await b.status()
        check(s == 0x84, f"reset STATUS = {s:#04x}, expected 0x84 (TICK=1, EMPTY=1)")

    # Head view is 0 when empty, for every BYTE_SEL.
    for sel in range(4):
        v = await b.head(sel)
        check(v == 0x00, f"empty head byte sel={sel} = {v:#04x}")

    # uio pins are all inputs and drive 0.
    await b.cycle(CMD_NOP, view=0)
    oe = read_logic(dut.uio_oe, "uio_oe")
    out = read_logic(dut.uio_out, "uio_out")
    check(oe == 0 and out == 0, f"uio_oe={oe:#04x} uio_out={out:#04x}, expected both 0")


# ---------------------------------------------------------------------------
# 1b. Reset release: commands ignored at edges 1 and 2, run from edge 3
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_reset_release_edges(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_PS, unit="ps").start())
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    for _ in range(5):
        await RisingEdge(dut.clk)
    b = Bench(dut, seed=12)
    b.model.reset()

    # Release at a falling edge. Each cycle's sample shows the state after the
    # previous rising edge, so:
    #   r0: before edge 1      r1: after edge 1      r2: after edge 2      r3: after edge 3
    r0 = await b.cycle(CMD_PUSH, data=0x42, view=1, release=True)  # PUSH at edge 1
    r1 = await b.cycle(CMD_PUSH, data=0x43, view=1)                # PUSH at edge 2
    r2 = await b.cycle(CMD_PUSH, data=0x44, view=1)                # PUSH at edge 3
    r3 = await b.cycle(CMD_NOP, view=1)
    check(r0 == 0x84, f"before edge 1 STATUS = {r0:#04x}, expected 0x84")
    check(r1 == 0x84, f"after edge 1 (PUSH ignored) STATUS = {r1:#04x}, expected 0x84, LEVEL 0")
    check(r2 == 0x84, f"after edge 2 (PUSH ignored) STATUS = {r2:#04x}, expected 0x84, LEVEL 0")
    check(r3 == 0x90, f"after edge 3 (PUSH runs) STATUS = {r3:#04x}, expected 0x90, LEVEL 1")
    v = await b.head(0)
    check(v == word_for(0x44) & 0xFF, f"head after edge 3 = {v:#04x}, expected word for DATA 0x44")
    await b.idle(3)
    s = await b.status()
    check(s == 0x90, f"after idle, STATUS = {s:#04x}, expected 0x90 (LEVEL 1, TICK 1)")


# ---------------------------------------------------------------------------
# 2. Push / pop ordering, data word, LEVEL
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_push_pop_order(dut):
    b = await start(dut, seed=22)

    # Hand-computed: 0x5A5A5A5A ^ 0x01234567 = 0x5B791F3D.
    check(word_for(0x5A) == 0x5B791F3D, "model word formula is wrong")

    datas = [0x5A, 0x00, 0xFF, 0x3C]
    levels = []
    for d in datas:
        await b.push(d)
        levels.append(((await b.status()) >> 4) & 0x7)
    check(levels == [1, 2, 3, 4], f"LEVEL after each push = {levels}")

    # Head word shows through all four BYTE_SELs.
    head = word_for(datas[0])
    for sel in range(4):
        v = await b.head(sel)
        check(v == (head >> (8 * sel)) & 0xFF, f"head sel={sel}: {v:#04x}")

    # Pops return words in push order. LEVEL drops after each pop.
    for k, d in enumerate(datas):
        head = word_for(d)
        for sel in range(4):
            v = await b.head(sel)
            check(v == (head >> (8 * sel)) & 0xFF, f"word {k} sel {sel} mismatch")
        await b.pop()
        lvl = ((await b.status()) >> 4) & 0x7
        check(lvl == len(datas) - k - 1, f"LEVEL after pop {k} = {lvl}")

    # Interleaved push/pop keeps FIFO order.
    await b.push(0x11)
    await b.push(0x22)
    await b.pop()
    await b.push(0x33)
    await b.pop()
    await b.pop()
    s = await b.status()
    check(s == 0x84, f"empty again but STATUS = {s:#04x}")


# ---------------------------------------------------------------------------
# 3. FULL, OVERFLOW, UNDERFLOW, CLEAR_FLAGS, NOP
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_full_and_flags(dut):
    b = await start(dut, seed=33)

    # POP on empty sets UNDERFLOW.
    await b.pop()
    s = await b.status()
    check(s == 0x85, f"after POP on empty STATUS = {s:#04x}, expected 0x85")

    # NOP changes nothing.
    await b.idle(5)
    check((await b.status()) == 0x85, "NOP changed STATUS")

    # CLEAR_FLAGS clears UNDERFLOW.
    await b.cycle(CMD_CLEAR_FLAGS, view=1)
    check((await b.status()) == 0x84, "CLEAR_FLAGS did not clear UNDERFLOW")

    # Fill to FULL at 4 words.
    for d in [0x10, 0x20, 0x30, 0x40]:
        await b.push(d)
    s = await b.status()
    check(s == 0xC8, f"FULL STATUS = {s:#04x}, expected 0xC8")

    # 5th push: dropped, OVERFLOW set, FIFO unchanged.
    await b.push(0x99)
    s = await b.status()
    check(s == 0xCA, f"after overflow STATUS = {s:#04x}, expected 0xCA")
    v = await b.head(0)
    check(v == word_for(0x10) & 0xFF, "head changed by overflowing push")

    # Drain with OVERFLOW set, then UNDERFLOW as well.
    for _ in range(4):
        await b.pop()
    s = await b.status()
    check(s == 0x86, f"drained with OVERFLOW set, STATUS = {s:#04x}, expected 0x86")
    await b.pop()
    s = await b.status()
    check(s == 0x87, f"both flags set, STATUS = {s:#04x}, expected 0x87")

    # Flags stay set through NOPs.
    await b.idle(4)
    check((await b.status()) == 0x87, "flags changed without CLEAR_FLAGS")

    # CLEAR_FLAGS clears both.
    await b.cycle(CMD_CLEAR_FLAGS, view=1)
    check((await b.status()) == 0x84, "CLEAR_FLAGS did not clear both flags")

    # Sticky: UNDERFLOW stays set across many clocks until cleared.
    await b.pop()
    await b.idle(30)
    check((await b.status()) == 0x85, "UNDERFLOW was not sticky")
    await b.cycle(CMD_CLEAR_FLAGS, view=1)


# ---------------------------------------------------------------------------
# 4. Divider with FRAC = 0
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_divider_frac0(dut):
    b = await start(dut, seed=44)

    # INT = 1: first tick at index 0, then every cycle.
    await b.load_int(1)
    await b.load_frac(0)
    await b.cycle(CMD_DIV_RESTART, view=1)
    ticks = await collect_ticks(b, 40, 80, int_eff=1)
    check(ticks[0] == 0, f"INT=1: first tick at index {ticks[0]}, expected 0")
    gaps_after_first(ticks, 1, 1)

    # INT = 3: ticks exactly 3 cycles apart.
    await b.load_int(3)
    await b.cycle(CMD_DIV_RESTART, view=1)
    ticks = await collect_ticks(b, 12, 60, int_eff=3)
    t = gaps_after_first(ticks, 3, 3)
    check(len(t) >= 10, f"INT=3: only {len(t)} ticks checked")

    # INT = 0x0102 = 258, loaded with INT_LO then INT_HI. A handful of gaps only.
    await b.cycle(CMD_INT_LO, data=0x02)
    await b.cycle(CMD_INT_HI, data=0x01)
    await b.load_frac(0)
    await b.cycle(CMD_DIV_RESTART, view=1)
    ticks = await collect_ticks(b, 4, 258 * 6, int_eff=258)
    gaps_after_first(ticks, 258, 258)


# ---------------------------------------------------------------------------
# 4b. TICK is 1 at INT=1, FRAC=0 at all times, including after restarts
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_tick_int1_always(dut):
    b = await start(dut, seed=45)
    await b.cycle(CMD_INT_LO, data=1, view=1)
    await b.cycle(CMD_INT_HI, data=0, view=1)
    await b.cycle(CMD_FRAC, data=0, view=1)
    await b.cycle(CMD_DIV_RESTART, view=1)
    ticks = await collect_ticks(b, 30, 40, int_eff=1)
    check(ticks == list(range(30)), f"INT=1 FRAC=0 after restart: tick indices {ticks[:10]}...")
    for _ in range(30):
        s = await b.status()
        check(s & 0x80, "INT=1 FRAC=0: TICK was 0 with no restart pending")
    await b.cycle(CMD_DIV_RESTART, view=1)
    for _ in range(30):
        s = await b.status()
        check(s & 0x80, "INT=1 FRAC=0: TICK was 0 on the cycle after a second restart")


# ---------------------------------------------------------------------------
# 4c. Each byte of INT is independent
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_int_byte_independence(dut):
    b = await start(dut, seed=46)

    # INT_HI first, then INT_LO. A mutant that clears INT[15:8] on INT_LO shows as 3.
    await b.cycle(CMD_INT_HI, data=0x01)
    await b.cycle(CMD_INT_LO, data=0x03)
    await b.load_frac(0)
    await b.cycle(CMD_DIV_RESTART, view=1)
    ticks = await collect_ticks(b, 4, 259 * 5, int_eff=259)
    gaps_after_first(ticks, 259, 259)

    # INT_LO first, then INT_HI. A mutant that clears INT[7:0] on INT_HI shows as 256.
    await b.cycle(CMD_INT_LO, data=0x05)
    await b.cycle(CMD_INT_HI, data=0x02)
    await b.cycle(CMD_DIV_RESTART, view=1)
    ticks = await collect_ticks(b, 4, 517 * 5, int_eff=517)
    gaps_after_first(ticks, 517, 517)


# ---------------------------------------------------------------------------
# 5. Divider with FRAC != 0
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_divider_frac_2_5(dut):
    b = await start(dut, seed=55)
    await run_fractional(b, 2, 0x80, 300)  # 2.5


@cocotb.test()
async def test_divider_frac_1_25(dut):
    b = await start(dut, seed=66)
    await run_fractional(b, 1, 0x40, 300)  # 1.25


@cocotb.test()
async def test_divider_frac_extremes(dut):
    b = await start(dut, seed=67)
    await run_fractional(b, 3, 0x01, 300)  # smallest non-zero FRAC
    await run_fractional(b, 3, 0xFF, 300)  # largest FRAC


# ---------------------------------------------------------------------------
# 6. INT/FRAC loaded without DIV_RESTART, then restarted
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_load_without_restart(dut):
    b = await start(dut, seed=77)

    # Change the divisor several times with no restart. Tick spacing here is not
    # asserted. The FIFO and flags are still checked.
    await b.load_int(5)
    await b.load_frac(0x40)
    await b.idle(40, view=1)
    await b.load_int(6)
    await b.load_frac(0x10)
    await b.idle(15, view=1)

    # After a restart, the bounds and the 256-gap window apply to the new divisor.
    await run_fractional(b, 6, 0x10, 260)


# ---------------------------------------------------------------------------
# 7. Reset in the middle of activity
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_reset_mid_activity(dut):
    b = await start(dut, seed=88)

    # Build activity: divider changed, FIFO partly filled, both flags set.
    await b.load_int(5)
    await b.load_frac(0x40)
    await b.cycle(CMD_DIV_RESTART, view=1)
    await b.idle(20)
    for d in [0xA1, 0xA2, 0xA3]:
        await b.push(d)
    for _ in range(3):
        await b.push(0xEE)  # the 4th fills the FIFO, the 5th and 6th set OVERFLOW
    for _ in range(5):
        await b.pop()  # 4 pops drain, the 5th sets UNDERFLOW
    s = await b.status()
    check(s & 0x7F == 0x07, f"setup STATUS without TICK = {s & 0x7F:#04x}, expected 0x07")

    # Reset asserted mid-cycle, held for a few cycles, then released.
    await enter_reset(b, dut, hold_cycles=3)
    await b.cycle(CMD_NOP, view=1, release=True)  # edge 1 (reset still ignored)
    await b.idle(1)  # edge 2
    for _ in range(20):
        s = await b.status()
        check(s == 0x84, f"after reset STATUS = {s:#04x}, expected 0x84")
    for sel in range(4):
        v = await b.head(sel)
        check(v == 0x00, f"after reset head byte sel={sel} = {v:#04x}")


# ---------------------------------------------------------------------------
# 8. Random FIFO traffic with the scoreboard (ena and noise pins random)
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_random_fifo(dut):
    b = await start(dut, seed=99)
    rng = random.Random(4321)
    cmds = [CMD_NOP, CMD_PUSH, CMD_PUSH, CMD_POP, CMD_POP, CMD_CLEAR_FLAGS]
    for _ in range(1500):
        await b.cycle(rng.choice(cmds), sel=rng.randrange(4), view=rng.randrange(2))


# ---------------------------------------------------------------------------
# Long tests: opt-in with POLYGLOT_LONG=1 (each needs ~65k cycles per tick)
# ---------------------------------------------------------------------------
@cocotb.test(skip=not LONG)
async def test_long_int0_is_65536(dut):
    b = await start(dut, seed=101)
    await b.load_int(0)
    await b.load_frac(0)
    await b.cycle(CMD_DIV_RESTART, view=1)
    ticks = await collect_ticks(b, 3, 3 * 65537 + 16, int_eff=65536)
    t = gaps_after_first(ticks, 65536, 65536)
    check(len(t) >= 2, "need two ticks after the first")


@cocotb.test(skip=not LONG)
async def test_long_int300_frac(dut):
    b = await start(dut, seed=102)
    await run_fractional(b, 0x012C, 0x80, 258)  # INT=300, FRAC=2.5 in 1/256 units, 256 gaps

