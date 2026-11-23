# SPDX-License-Identifier: Apache-2.0
#
# cocotb tests of the block 3 chip (docs/chip.md), through the top-level pins only.
#
# The host is a cocotbext-spi SpiMaster in mode 0, MSB first. Nothing in this file
# comes from the Python model (pgsim) or the RTL. Expected values come from chip.md,
# engine.md, DESIGN.md and the RP2040 datasheet (section 3.7 layouts), and the PIO
# programs are assembled with the official pioasm (2.3.1). The same file runs on the
# RTL and on the gate-level netlist (GATES=yes).
#
# Timing. clk is 60 MHz (16666 ps, as in the template). SCK is 1/8 of clk, so each SCK
# half period is 4 clk cycles (chip.md 6.6 asks for at least 2). Every pin change is
# made at a falling edge of clk, and so is every SCK edge, so no pin changes in the same
# step as a rising edge. CS_N falls, then the first SCK rise follows 1.5 SCK periods
# later, which is 12 cycles (chip.md 6.6 asks for at least 3). Between frames CS_N is
# high for at least 4 cycles, and each master's frame spacing is 0.
#
# Expected values that depend on timing (for example the spacing of pin steps) are
# computed from the contract, not measured and then copied.

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge, Timer
from cocotbext.spi import SpiBus, SpiConfig, SpiMaster

CLK_PERIOD_PS = 16666
SCK_PERIOD_PS = 8 * CLK_PERIOD_PS  # SCK half period = 4 clk cycles
SCK_FREQ_HZ = 1e12 / SCK_PERIOD_PS
CS_HIGH_CYCLES = 4  # CS_N high between frames, at least the 4 cycles of chip.md 6.6

# ---------------------------------------------------------------------------
# Register map (chip.md 8.1)
# ---------------------------------------------------------------------------
A_ID = 0x000
A_HWCFG = 0x004
A_CTRL = 0x008
A_FSTAT = 0x00C
A_FDEBUG = 0x010
A_FLEVEL = 0x014
A_IRQ = 0x018
A_IRQ_FORCE = 0x01C
A_HOSTIRQ_EN = 0x020
A_PAD_OD = 0x024
A_SYNC_BYPASS = 0x028
A_PAD_IN = 0x02C
A_PAD_OUT = 0x030
A_PAD_OE = 0x034
A_SCRATCH = 0x038
A_DBG_CTRL = 0x060

# Per-SM offsets from 0x200 + 0x40 n (chip.md 8.1)
O_CLKDIV = 0x00
O_EXECCTRL = 0x04
O_SHIFTCTRL = 0x08
O_ADDR = 0x0C
O_INSTR = 0x10
O_PINCTRL = 0x14
O_EXT = 0x18
O_LCU = 0x1C
O_DBG_X = 0x2C
O_DBG_Y = 0x30
O_DBG_ISR = 0x34
O_DBG_OSR = 0x38
O_DBG_CNT = 0x3C


def txf(n):
    return 0x040 + 4 * n


def rxf(n):
    return 0x050 + 4 * n


def imem(k):
    return 0x100 + 4 * k


def sm(n, off):
    return 0x200 + 0x40 * n + off


# chip.md 8.1 and 8.2 reset values (SM registers and the others)
ID_VALUE = 0x504C4754
HWCFG_VALUE = 0x1040_0404  # FIFO depth 4, 4 SMs, IMEM depth 64, no LCU, no SRAM, version 1
STATUS_RESET = 0xF0  # TXNFULL[3:0] = 1 (TX empty), RXNEMPTY[3:0] = 0
FSTAT_RESET = 0x0F00_0F00  # TXEMPTY and RXEMPTY for 4 SMs
CLKDIV_RESET = 0x0001_0000
EXECCTRL_RESET = 0x0001_F000
SHIFTCTRL_RESET = 0x000C_0000
PINCTRL_RESET = 0x1400_0000
DBG_CNT_RESET = 32 << 8  # OSR count 32 (engine.md R0)


def wrap(top, bottom=0):
    return (top << 12) | (bottom << 7)


# PIO programs. Assembled with pioasm 2.3.1 (the official tool).
#   pinsdemo:  set pins, 1 [1]; set pins, 30 [1]; set pins, 21 [1]     (wrap 0..2)
#   pulldrive: pull block; out pins, 6                                  (wrap 0..1)
#   loopback:  pull block; mov isr, osr; push block                     (wrap 0..2)
PINSDEMO = [0xE101, 0xE11E, 0xE115]
PULLDRIVE = [0x80A0, 0x6006]
LOOPBACK = [0x80A0, 0xA0C7, 0x8020]
# Forced instructions (pioasm 2.3.1): set pindirs,1 / set pins,1 / set pins,0 /
# set pindirs,0 / set x,21 / set y,9
SET_PINDIRS_1 = 0xE081
SET_PINS_1 = 0xE001
SET_PINS_0 = 0xE000
SET_PINDIRS_0 = 0xE080
SET_X_21 = 0xE035
SET_Y_9 = 0xE049

# PINCTRL values (RP2040 layout, datasheet table 395)
PINCTRL_SET_BASE8 = PINCTRL_RESET | (8 << 5)  # SET pins 8..12 = uo_out[4:0]
PINCTRL_OUT8_6 = PINCTRL_RESET | (6 << 20) | 8  # OUT pins 8..13 = uo_out[5:0]
PINCTRL_SET14 = (1 << 26) | (14 << 5)  # SET pin 14 = uo_out[6] (HOST_IRQ off)
PINCTRL_SET0_1 = 1 << 26  # SET pin 0 = uio[0]

# ---------------------------------------------------------------------------
# Host: a cocotbext-spi master on the pins that tb.v exposes
# ---------------------------------------------------------------------------
def spi_config(word_width):
    return SpiConfig(
        word_width=word_width,
        sclk_freq=SCK_FREQ_HZ,
        cpol=False,
        cpha=False,
        msb_first=True,
        frame_spacing_ns=0,
        data_output_idle=0,
        cs_active_low=True,
    )


def hdr(cmd, addr):
    return bytes([cmd, (addr >> 8) & 0xFF, addr & 0xFF])


def be_words(words):
    return b"".join((w & 0xFFFF_FFFF).to_bytes(4, "big") for w in words)


class Link:
    """SPI frames to the chip. Keeps the last frame for failure messages."""

    def __init__(self, dut):
        self.dut = dut
        self.clk = dut.clk
        self.bus = SpiBus(
            entity=dut,
            sclk_name="spi_sck",
            mosi_name="spi_mosi",
            miso_name="spi_miso",
            cs_name="spi_cs_n",
        )
        self.bytes_master = SpiMaster(self.bus, spi_config(8))
        self._bit_masters = {}
        self.last = (b"", b"")

    def _bit_master(self, nbits):
        if nbits not in self._bit_masters:
            self._bit_masters[nbits] = SpiMaster(self.bus, spi_config(nbits))
        return self._bit_masters[nbits]

    async def frame(self, tx):
        """One byte frame: CS_N low for all of tx, MISO bytes returned."""
        await FallingEdge(self.clk)
        self.bytes_master.write_nowait(tx, burst=True)
        await self.bytes_master.wait()
        rx = bytes(self.bytes_master.read_nowait())
        self.last = (bytes(tx), rx)
        await ClockCycles(self.clk, CS_HIGH_CYCLES)
        return rx

    async def bit_frame(self, nbits, value):
        """A frame of nbits bits (not a multiple of 8 in general), MSB first."""
        m = self._bit_master(nbits)
        await FallingEdge(self.clk)
        m.write_nowait([value], burst=False)
        await m.wait()
        m.read_nowait()
        self.last = (value.to_bytes((nbits + 7) // 8, "big"), b"")
        await ClockCycles(self.clk, CS_HIGH_CYCLES)

    async def write(self, addr, *words, fixed=False):
        await self.frame(hdr(0x40 if fixed else 0x00, addr) + be_words(words))

    async def read(self, addr, n=1, fixed=False):
        """Returns (STATUS byte, [word 0 .. word n-1])."""
        rx = await self.frame(hdr(0xC0 if fixed else 0x80, addr) + bytes(1 + 4 * n))
        words = [int.from_bytes(rx[4 + 4 * m : 8 + 4 * m], "big") for m in range(n)]
        return rx[0], words

    async def reg(self, addr):
        return (await self.read(addr))[1][0]

    async def status(self):
        """1-byte frame: the command byte alone. MISO shows STATUS during it."""
        rx = await self.frame(bytes([0x00]))
        return rx[0]


def check(link, what, got, want):
    if got != want:
        tx, rx = link.last
        raise AssertionError(
            f"{what}: got {got:#010x}, expected {want:#010x}; "
            f"last frame tx={tx.hex()} rx={rx.hex()}"
        )


def check_list(link, what, got, want):
    if list(got) != list(want):
        tx, rx = link.last
        raise AssertionError(
            f"{what}: got {[hex(x) for x in got]}, expected {[hex(x) for x in want]}; "
            f"last frame tx={tx.hex()} rx={rx.hex()}"
        )


async def set_reset(dut, value):
    await FallingEdge(dut.clk)
    dut.rst_n.value = value


async def start(dut):
    """Start the clock, reset, release, and return a Link."""
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_PS, unit="ps").start())
    dut.ena.value = 1
    dut.spi_sck.value = 0
    dut.spi_mosi.value = 0
    dut.spi_cs_n.value = 1
    dut.ext_ui.value = 0
    dut.ext_uio.value = 0xFF  # pads pulled up
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    link = Link(dut)
    await set_reset(dut, 1)
    await ClockCycles(dut.clk, 8)  # rst_n release goes through two flops
    return link


class Pads:
    """Samples uo_out at every falling edge. Sample k is the state after rising edge k."""

    def __init__(self, dut):
        self.dut = dut
        self.samples = []  # (edge index, uo_out)
        self.edge = 0
        cocotb.start_soon(self._run())

    async def _run(self):
        while True:
            await FallingEdge(self.dut.clk)
            self.samples.append((self.edge, int(self.dut.uo_out.value)))
            await RisingEdge(self.dut.clk)
            self.edge += 1


def steps(pads, first_edge, shift, mask):
    """The value changes of (uo_out >> shift) & mask from first_edge on.
    Returns [(edge, value)]. The first entry is the value at first_edge."""
    out = []
    prev = None
    for edge, uo in pads.samples:
        if edge < first_edge:
            continue
        v = (uo >> shift) & mask
        if v != prev:
            out.append((edge, v))
            prev = v
    return out


def check_cycle(link, what, vals, cycle):
    """vals must be cycle repeated (starting at its first element)."""
    want = [cycle[i % len(cycle)] for i in range(len(vals))]
    if list(vals) != want:
        raise AssertionError(f"{what}: pin steps {vals}, expected the cycle {cycle} repeated")


async def settle(dut, cycles=3):
    await ClockCycles(dut.clk, cycles)


async def assert_reset(dut, cycles):
    """rst_n low for the given cycles, asserted and released at falling edges."""
    await set_reset(dut, 0)
    await ClockCycles(dut.clk, cycles)
    await set_reset(dut, 1)


async def check_reset_values(link, full):
    """Every reset value of chip.md 8 and engine.md R0 that the host can read."""
    st, (idv,) = await link.read(A_ID)
    check(link, "STATUS after reset", st, STATUS_RESET)
    check(link, "ID", idv, ID_VALUE)
    checks = [
        (A_CTRL, 0),
        (A_FSTAT, FSTAT_RESET),
        (A_FDEBUG, 0),
        (A_FLEVEL, 0),
        (A_IRQ, 0),
        (A_IRQ_FORCE, 0),
        (A_HOSTIRQ_EN, 0),
        (A_PAD_OD, 0),
        (A_SYNC_BYPASS, 0),
        (A_PAD_OUT, 0),
        (A_PAD_OE, 0),
        (A_SCRATCH, 0),
        (A_DBG_CTRL, 0),
        (sm(0, O_CLKDIV), CLKDIV_RESET),
        (sm(0, O_EXECCTRL), EXECCTRL_RESET),
        (sm(0, O_PINCTRL), PINCTRL_RESET),
        (sm(0, O_ADDR), 0),
        (sm(0, O_EXT), 0),
        (sm(0, O_DBG_CNT), DBG_CNT_RESET),
        (sm(0, O_DBG_X), 0),
        (sm(0, O_DBG_Y), 0),
        (sm(0, O_DBG_ISR), 0),
        (sm(0, O_DBG_OSR), 0),
    ]
    if full:
        checks += [(A_HWCFG, HWCFG_VALUE), (sm(0, O_SHIFTCTRL), SHIFTCTRL_RESET)]
        for n in range(1, 4):
            checks += [
                (sm(n, O_CLKDIV), CLKDIV_RESET),
                (sm(n, O_EXECCTRL), EXECCTRL_RESET),
                (sm(n, O_SHIFTCTRL), SHIFTCTRL_RESET),
                (sm(n, O_PINCTRL), PINCTRL_RESET),
                (sm(n, O_DBG_CNT), DBG_CNT_RESET),
            ]
    for addr, want in checks:
        check(link, f"reset value of {addr:#05x}", await link.reg(addr), want)


# ---------------------------------------------------------------------------
# 1. Identity, status, scratch
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_id_hwcfg(dut):
    link = await start(dut)
    st, (idv,) = await link.read(A_ID)
    check(link, "ID", idv, ID_VALUE)
    check(link, "STATUS with ID read (reset)", st, STATUS_RESET)
    check(link, "HWCFG", await link.reg(A_HWCFG), HWCFG_VALUE)


@cocotb.test()
async def test_status_one_byte(dut):
    link = await start(dut)
    st = await link.status()
    check(link, "1-byte frame STATUS (reset)", st, STATUS_RESET)
    check(link, "1-byte frame returns one byte", len(link.last[1]), 1)


@cocotb.test()
async def test_scratch_write_read(dut):
    link = await start(dut)
    for v in [0x5A5A_5A5A, 0xDEAD_BEEF, 0x0000_0000, 0x0123_4567]:
        await link.write(A_SCRATCH, v)
        check(link, f"SCRATCH after writing {v:#010x}", await link.reg(A_SCRATCH), v)
    # Two words in one frame with F = 0: the second goes to SCRATCH + 4 (unmapped, ignored).
    await link.write(A_SCRATCH, 0x1111_2222, 0x3333_4444)
    check(link, "SCRATCH after two words F=0", await link.reg(A_SCRATCH), 0x1111_2222)
    # F = 1: each word goes to SCRATCH in turn, so the last one stays.
    await link.write(A_SCRATCH, 0x5555_6666, 0x7777_8888, fixed=True)
    check(link, "SCRATCH after two words F=1", await link.reg(A_SCRATCH), 0x7777_8888)


@cocotb.test()
async def test_write_cut_mid_word(dut):
    """A write frame that CS_N ends mid-word has no effect (chip.md 6.4)."""
    link = await start(dut)
    await link.write(A_SCRATCH, 0x1234_5678)
    check(link, "SCRATCH before the cut frame", await link.reg(A_SCRATCH), 0x1234_5678)

    # Command 0x00 (write, F = 0), ADDR SCRATCH, then 31 of the 32 data bits: 55 bits.
    nbits = 8 + 16 + 31
    value = (0x00 << 47) | (A_SCRATCH << 31) | (0xDEAD_BEEF >> 1)
    await link.bit_frame(nbits, value)
    check(link, "SCRATCH after a frame cut one bit before the word's end",
          await link.reg(A_SCRATCH), 0x1234_5678)

    # Command 0x40 (write, F = 1): word 0 completes at bit 55, word 1 is cut after 20 bits.
    # Word 0 is written, word 1 is not.
    nbits = 8 + 16 + 32 + 20
    value = (((0x40 << 16) | A_SCRATCH) << 52) | (0xCAFE_F00D << 20) | (0x0BAD_BEEF >> 12)
    await link.bit_frame(nbits, value)
    check(link, "SCRATCH after a cut in the second word (F = 1)",
          await link.reg(A_SCRATCH), 0xCAFE_F00D)


# ---------------------------------------------------------------------------
# 2. Register masks, unmapped addresses, read-only registers
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_rw_masks_and_unmapped(dut):
    link = await start(dut)
    # RW registers store only their write mask (chip.md 8.1). Each row: address, write,
    # read-back, reset value to restore.
    rows = [
        (A_SCRATCH, 0xFFFF_FFFF, 0xFFFF_FFFF, 0),
        (A_HOSTIRQ_EN, 0xFFFF_FFFF, 0x0000_0FFF, 0),
        (A_PAD_OD, 0xFFFF_FFFF, 0x0000_00FF, 0),
        (A_SYNC_BYPASS, 0xFFFF_FFFF, 0x00FF_FFFF, 0),
        (sm(0, O_CLKDIV), 0xFFFF_FFFF, 0xFFFF_FF00, CLKDIV_RESET),
        (sm(0, O_EXECCTRL), 0xFFFF_FFFF, 0x7FFF_FF9F, EXECCTRL_RESET),
        (sm(0, O_SHIFTCTRL), 0x3FFF_0000, 0x3FFF_0000, SHIFTCTRL_RESET),
        (sm(0, O_PINCTRL), 0xA5A5_A5A5, 0xA5A5_A5A5, PINCTRL_RESET),
        (sm(0, O_EXT), 0xFFFF_FFFF, 0x0000_0001, 0),
    ]
    for addr, wr, want, restore in rows:
        await link.write(addr, wr)
        check(link, f"read-back of {addr:#05x} after writing {wr:#010x}", await link.reg(addr), want)
        await link.write(addr, restore)
        check(link, f"{addr:#05x} restored", await link.reg(addr), restore)

    # CTRL: only SM_ENABLE is stored. The restart bits read 0 (no SM is enabled here).
    await link.write(A_CTRL, 0x0000_00F0)
    check(link, "CTRL restart bits read 0", await link.reg(A_CTRL), 0)

    # Write-1-to-clear FDEBUG, no flags set: reads 0 and stays 0.
    await link.write(A_FDEBUG, 0xFFFF_FFFF)
    check(link, "FDEBUG after clearing an empty flag set", await link.reg(A_FDEBUG), 0)

    # Unmapped and write-only registers: reads 0, writes ignored.
    for addr in [0x0FC, A_DBG_CTRL, sm(0, O_LCU), sm(0, O_LCU + 0x0C), 0x300, 0x3FC]:
        await link.write(addr, 0xFFFF_FFFF)
        check(link, f"unmapped/absent {addr:#05x} reads 0", await link.reg(addr), 0)
    for addr in [A_IRQ_FORCE, txf(0), rxf(0), imem(0)]:
        check(link, f"write-only {addr:#05x} reads 0", await link.reg(addr), 0)


# ---------------------------------------------------------------------------
# 3. Reset values over SPI
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_reset_values(dut):
    link = await start(dut)
    await check_reset_values(link, full=True)


# ---------------------------------------------------------------------------
# 4. Forced instructions and debug reads
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_forced_instructions(dut):
    link = await start(dut)
    # A forced instruction runs even with the SM disabled (engine.md F1).
    await link.write(sm(0, O_INSTR), SET_X_21)
    await settle(dut)
    check(link, "DBG_X after forced set x, 21", await link.reg(sm(0, O_DBG_X)), 21)
    await link.write(sm(0, O_INSTR), SET_Y_9)
    await settle(dut)
    check(link, "DBG_Y after forced set y, 9", await link.reg(sm(0, O_DBG_Y)), 9)
    check(link, "DBG_X unchanged", await link.reg(sm(0, O_DBG_X)), 21)
    # EXEC_STALLED is 0 when the forced instruction completed.
    check(link, "EXECCTRL bit 31 after a completed forced instruction",
          await link.reg(sm(0, O_EXECCTRL)) >> 31, 0)


# ---------------------------------------------------------------------------
# 5. IMEM, SM run, pins
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_program_runs(dut):
    """Load a program through SPI, run it, and see pins on uo_out[4:0]. Then stop it."""
    link = await start(dut)
    pads = Pads(dut)
    await link.write(imem(0), *PINSDEMO)  # one frame, F = 0: words 0..2
    await link.write(sm(0, O_CLKDIV), 0x0002_0000)  # INT 2: one tick every 2 cycles
    await link.write(sm(0, O_EXECCTRL), wrap(2))
    await link.write(sm(0, O_PINCTRL), PINCTRL_SET_BASE8)
    check(link, "INSTR0 reads IMEM[PC = 0] before enabling", await link.reg(sm(0, O_INSTR)), PINSDEMO[0])
    check(link, "ADDR0 (dbg_pc) = 0 before enabling", await link.reg(sm(0, O_ADDR)), 0)

    first = pads.edge
    await link.write(A_CTRL, 0x1)
    await ClockCycles(dut.clk, 90)
    t = steps(pads, first, 0, 0x1F)
    vals = [v for _, v in t]
    check(link, "pins before the first instruction", vals[0], 0)
    check_cycle(link, "uo_out[4:0] while running", vals[1:], [1, 30, 21])
    if len(vals) < 10:
        raise AssertionError(f"only {len(vals)} pin steps in 90 cycles")
    # Each instruction takes two ticks (its own and the delay of 1). At INT = 2 that is four
    # cycles between steps.
    edges = [e for e, _ in t[1:]]
    gaps = [b - a for a, b in zip(edges, edges[1:])]
    if any(g != 4 for g in gaps):
        raise AssertionError(f"gaps between pin steps {gaps}, expected all 4 (INT = 2, delay 1)")
    # uo_out[5] is not a SET pin here (SET_COUNT 5).
    if any(uo & 0x20 for _, uo in pads.samples[first:]):
        raise AssertionError("uo_out[5] changed, but only 5 pins are set")

    # CTRL.SM_ENABLE = 0: the pins hold, and no more steps.
    await link.write(A_CTRL, 0x0)
    hold = pads.edge
    await ClockCycles(dut.clk, 40)
    later = steps(pads, hold, 0, 0x1F)
    if len(later) > 1:
        raise AssertionError(f"pins still stepping after SM_ENABLE = 0: {later}")


@cocotb.test()
async def test_program_in_page_1(dut):
    """EXT.PAGE selects IMEM words 32..63 (engine.md 9). Page 0 holds a decoy."""
    link = await start(dut)
    pads = Pads(dut)
    # Page 0 decoy: set pins, 31 (E11F) in words 0..2, so any use of page 0 shows as 31.
    await link.write(imem(0), 0xE11F, 0xE11F, 0xE11F)
    await link.write(imem(32), *PINSDEMO)
    await link.write(sm(0, O_CLKDIV), 0x0001_0000)
    await link.write(sm(0, O_EXECCTRL), wrap(2))
    await link.write(sm(0, O_PINCTRL), PINCTRL_SET_BASE8)
    await link.write(sm(0, O_EXT), 1)
    check(link, "EXT0 readback", await link.reg(sm(0, O_EXT)), 1)
    check(link, "INSTR0 reads page 1 word 0", await link.reg(sm(0, O_INSTR)), PINSDEMO[0])
    first = pads.edge
    await link.write(A_CTRL, 0x1)
    await ClockCycles(dut.clk, 60)
    vals = [v for _, v in steps(pads, first, 0, 0x1F)]
    check(link, "pins before the first instruction", vals[0], 0)
    check_cycle(link, "page 1 program pins", vals[1:], [1, 30, 21])
    if len(vals) < 9:
        raise AssertionError(f"page 1 program ran only {len(vals) - 1} steps")


@cocotb.test()
async def test_tx_pull_and_drive(dut):
    """TX words are pulled by a program and driven on uo_out[5:0]. Checks FIFO flags."""
    link = await start(dut)
    pads = Pads(dut)
    await link.write(imem(0), *PULLDRIVE)
    await link.write(sm(0, O_CLKDIV), 0x0001_0000)
    await link.write(sm(0, O_EXECCTRL), wrap(1))
    await link.write(sm(0, O_PINCTRL), PINCTRL_OUT8_6)

    # Five words into TX0 with the SM disabled: four fit, the fifth is dropped.
    w = [0x5A5A_5A15, 0xFFFF_FF2A, 0x1234_567F, 0x0000_0041, 0x0000_000B]
    await link.write(txf(0), *w, fixed=True)
    check(link, "FSTAT after 5 pushes (TX0 full, not empty)", await link.reg(A_FSTAT), 0x0E01_0F00)
    check(link, "FLEVEL: TX0 level 4", await link.reg(A_FLEVEL), 0x4)
    check(link, "FDEBUG: TXOVER0 after the fifth push", await link.reg(A_FDEBUG), 0x0001_0000)
    await link.write(A_FDEBUG, 0x0001_0000)
    check(link, "FDEBUG after clearing TXOVER0", await link.reg(A_FDEBUG), 0)

    first = pads.edge
    await link.write(A_CTRL, 0x1)
    await ClockCycles(dut.clk, 30)
    t = steps(pads, first, 0, 0x3F)
    vals = [v for _, v in t]
    check(link, "pins before the first pull", vals[0], 0)
    check_list(link, "uo_out[5:0] values, one per pushed word (low 6 bits)", vals[1:],
               [0x15, 0x2A, 0x3F, 0x01])
    edges = [e for e, _ in t[1:]]
    gaps = [b - a for a, b in zip(edges, edges[1:])]
    if any(g != 2 for g in gaps):
        raise AssertionError(f"gaps between pin steps {gaps}, expected all 2 (pull, out)")

    # The program stalls on an empty TX FIFO, and that sets TXSTALL0 (bit 24).
    check(link, "FDEBUG: TXSTALL0 after the drain", await link.reg(A_FDEBUG), 0x0100_0000)
    check(link, "FSTAT after the drain: TX0 empty", await link.reg(A_FSTAT), FSTAT_RESET)
    check(link, "pins hold the last word", pads.samples[-1][1] & 0x3F, 0x01)


@cocotb.test()
async def test_rx_loopback_burst(dut):
    """A program pushes RX words. A burst read with F = 1 drains them, then FSTAT, FLEVEL
    and FDEBUG are checked. A burst longer than the FIFO reads 0 and sets RXUNDER0."""
    link = await start(dut)
    await link.write(imem(0), *LOOPBACK)
    await link.write(sm(0, O_CLKDIV), 0x0001_0000)
    await link.write(sm(0, O_EXECCTRL), wrap(2))

    first_batch = [0x1122_3344, 0x5566_7788, 0x99AA_BBCC, 0xDDEE_FF00]
    await link.write(txf(0), *first_batch, fixed=True)
    await link.write(A_CTRL, 0x1)
    await settle(dut, 40)

    # RX0 full with 4 words, TX0 empty, the program stalled on pull (TXSTALL0 set).
    check(link, "FSTAT with RX0 full", await link.reg(A_FSTAT), 0x0F00_0E01)
    check(link, "FLEVEL: RX0 level 4", await link.reg(A_FLEVEL), 0x40)
    check(link, "FDEBUG: TXSTALL0 only", await link.reg(A_FDEBUG), 0x0100_0000)
    st = await link.status()
    check(link, "STATUS with RX0 not empty (TX not full, RXNEMPTY0)", st, 0xF1)

    st, words = await link.read(rxf(0), n=4, fixed=True)
    check(link, "STATUS at the start of the burst", st, 0xF1)
    check_list(link, "RX burst of 4 words", words, first_batch)
    check(link, "FSTAT after the burst: RX0 empty", await link.reg(A_FSTAT), FSTAT_RESET)
    check(link, "FLEVEL after the burst", await link.reg(A_FLEVEL), 0)
    check(link, "FDEBUG after the burst (no RXUNDER)", await link.reg(A_FDEBUG), 0x0100_0000)

    # Second batch: five words in one burst. The fifth read finds RX0 empty.
    second_batch = [0x0102_0304, 0x0506_0708, 0x090A_0B0C, 0x0D0E_0F10]
    await link.write(txf(0), *second_batch, fixed=True)
    await settle(dut, 40)
    st, words = await link.read(rxf(0), n=5, fixed=True)
    check_list(link, "RX burst of 5 words (the fifth from an empty FIFO)", words,
               second_batch + [0])
    check(link, "FDEBUG: RXUNDER0 set by the empty read",
          await link.reg(A_FDEBUG), 0x0100_0100)
    await link.write(A_FDEBUG, 0x0000_0100)  # RW1C
    check(link, "FDEBUG after clearing RXUNDER0", await link.reg(A_FDEBUG), 0x0100_0000)


@cocotb.test()
async def test_open_drain(dut):
    """PAD_OD on uio[0] (engine.md 9.2 and chip.md 9.2)."""
    link = await start(dut)
    await link.write(sm(0, O_PINCTRL), PINCTRL_SET0_1)  # SET pin 0 only, which is uio[0]

    async def pads_now():
        await FallingEdge(dut.clk)
        return int(dut.uio_out.value), int(dut.uio_oe.value), int(dut.uo_out.value)

    async def pad_in_low_byte():
        return (await link.read(0x02C))[1][0] & 0xFF

    # PAD_OD = 0: a driven 1 is a push-pull 1.
    await link.write(sm(0, O_INSTR), SET_PINDIRS_1)
    await link.write(sm(0, O_INSTR), SET_PINS_1)
    await settle(dut)
    out, oe, _ = await pads_now()
    check(link, "uio_out[0] driven 1, PAD_OD = 0", out & 1, 1)
    check(link, "uio_oe[0] = 1, PAD_OD = 0", oe & 1, 1)

    # PAD_OD = 1: a driven 0 pulls low, and a 1 releases the pad.
    await link.write(A_PAD_OD, 0x01)
    await link.write(sm(0, O_INSTR), SET_PINS_0)
    await settle(dut)
    out, oe, _ = await pads_now()
    check(link, "uio_out[0] with PAD_OD and level 0", out & 1, 0)
    check(link, "uio_oe[0] with PAD_OD and level 0 (drive low)", oe & 1, 1)
    check(link, "PAD_IN[0] reads the low pad", await pad_in_low_byte() & 1, 0)

    await link.write(sm(0, O_INSTR), SET_PINS_1)
    await settle(dut)
    out, oe, _ = await pads_now()
    check(link, "uio_out[0] with PAD_OD and level 1", out & 1, 0)
    check(link, "uio_oe[0] with PAD_OD and level 1 (released)", oe & 1, 0)
    check(link, "PAD_IN[0] reads the pulled-up pad", await pad_in_low_byte() & 1, 1)

    # PAD_OD = 0 again, level 1: the pad is driven high.
    await link.write(A_PAD_OD, 0x00)
    await settle(dut)
    out, oe, _ = await pads_now()
    check(link, "uio_out[0] with PAD_OD cleared, level 1", out & 1, 1)
    check(link, "uio_oe[0] with PAD_OD cleared, level 1", oe & 1, 1)

    # Input only (pindirs 0): the pad shows the external level.
    await link.write(sm(0, O_INSTR), SET_PINDIRS_0)
    dut.ext_uio.value = 0xFE
    await settle(dut)
    out, oe, _ = await pads_now()
    check(link, "uio_oe[0] with pindirs 0", oe & 1, 0)
    check(link, "PAD_IN[0] shows the external 0", await pad_in_low_byte() & 1, 0)
    dut.ext_uio.value = 0xFF


@cocotb.test()
async def test_host_irq(dut):
    """HOST_IRQ on uo_out[6]: HOSTIRQ_EN = 0 gives pins_out[14], otherwise the OR of the
    enabled sources (chip.md 9.2 and 9.3)."""
    link = await start(dut)
    await link.write(sm(0, O_PINCTRL), PINCTRL_SET14)  # SET pin 14 = uo_out[6]
    await link.write(sm(0, O_INSTR), SET_PINS_1)  # pins_out[14] = 1
    await settle(dut)

    async def uo6():
        await FallingEdge(dut.clk)
        return (int(dut.uo_out.value) >> 6) & 1

    check(link, "HOSTIRQ_EN = 0: uo_out[6] is pins_out[14]", await uo6(), 1)

    await link.write(A_HOSTIRQ_EN, 0x001)  # irq[0] only; irq[0] is clear
    await settle(dut)
    check(link, "HOSTIRQ_EN = irq[0], flag clear: uo_out[6] = HOST_IRQ = 0", await uo6(), 0)

    await link.write(A_IRQ_FORCE, 0x01)
    await settle(dut)
    check(link, "IRQ after IRQ_FORCE", await link.reg(A_IRQ), 0x01)
    check(link, "HOSTIRQ_EN = irq[0], flag set: uo_out[6] = 1", await uo6(), 1)

    await link.write(A_IRQ, 0x01)  # RW1C
    await settle(dut)
    check(link, "IRQ after clearing", await link.reg(A_IRQ), 0)
    check(link, "uo_out[6] after the flag clears", await uo6(), 0)

    # TXNFULL0 as the source: TX empty gives 1, TX full gives 0.
    await link.write(A_HOSTIRQ_EN, 0x100)
    await settle(dut)
    check(link, "HOSTIRQ_EN = TXNFULL0, TX empty: uo_out[6] = 1", await uo6(), 1)
    await link.write(txf(0), 1, 2, 3, 4, fixed=True)
    await settle(dut)
    check(link, "HOSTIRQ_EN = TXNFULL0, TX full: uo_out[6] = 0 (pins_out[14] = 1 is masked)",
          await uo6(), 0)

    await link.write(A_HOSTIRQ_EN, 0x000)
    await settle(dut)
    check(link, "HOSTIRQ_EN = 0 again: uo_out[6] = pins_out[14]", await uo6(), 1)
    check(link, "PAD_OUT bit 14", (await link.reg(A_PAD_OUT)) >> 14 & 1, 1)
    await FallingEdge(dut.clk)
    check(link, "uo_out[7] (MISO) is 0 between frames", (int(dut.uo_out.value) >> 7) & 1, 0)


# ---------------------------------------------------------------------------
# 6. Reset (chip.md 10)
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_reset_mid_frame(dut):
    """rst_n goes low in the middle of a write frame, and the frame ends during reset.
    The write must not happen, and the reset state must hold for a clean frame."""
    link = await start(dut)
    await link.write(A_SCRATCH, 0x1234_5678)

    tx = hdr(0x00, A_SCRATCH) + be_words([0xDEAD_BEEF])
    await FallingEdge(dut.clk)
    link.bytes_master.write_nowait(tx, burst=True)
    # The first SCK rise is 12 cycles after CS_N falls, and bits come every 8 cycles.
    await ClockCycles(dut.clk, 12 + 8 * 40 + 3)
    await set_reset(dut, 0)
    await link.bytes_master.wait()
    link.bytes_master.read_nowait()
    await ClockCycles(dut.clk, 2 * CS_HIGH_CYCLES)
    await set_reset(dut, 1)
    await ClockCycles(dut.clk, 8)

    st, (idv,) = await link.read(A_ID)
    check(link, "ID after reset in mid-frame", idv, ID_VALUE)
    check(link, "STATUS after reset in mid-frame", st, STATUS_RESET)
    check(link, "SCRATCH after reset in mid-frame: reset value, not the frame's word",
          await link.reg(A_SCRATCH), 0)
    await link.write(A_SCRATCH, 0xCAFE_BABE)
    check(link, "SCRATCH writes work after reset", await link.reg(A_SCRATCH), 0xCAFE_BABE)


@cocotb.test()
async def test_reset_mid_program(dut):
    """rst_n goes low between clock edges while a program runs. The pins go to 0 at once,
    the SM stops, the reset values hold, and IMEM survives (it is not reset)."""
    link = await start(dut)
    pads = Pads(dut)
    await link.write(imem(0), *PINSDEMO)
    await link.write(sm(0, O_CLKDIV), 0x0001_0000)
    await link.write(sm(0, O_EXECCTRL), wrap(2))
    await link.write(sm(0, O_PINCTRL), PINCTRL_SET_BASE8)
    await link.write(A_CTRL, 0x1)
    await ClockCycles(dut.clk, 30)
    if pads.samples[-1][1] & 0x1F == 0:
        raise AssertionError("no pin steps before the reset, so the test would prove nothing")

    await RisingEdge(dut.clk)
    await Timer(3, unit="ns")
    dut.rst_n.value = 0
    await Timer(4, unit="ns")
    if int(dut.uo_out.value) & 0xFF != 0:
        raise AssertionError(f"during rst_n low, uo_out = {int(dut.uo_out.value):#04x}, expected 0")
    await ClockCycles(dut.clk, 3)
    await set_reset(dut, 1)
    await ClockCycles(dut.clk, 8)
    after = pads.edge
    await ClockCycles(dut.clk, 40)
    if steps(pads, after, 0, 0x1F)[1:]:
        raise AssertionError("the SM ran after reset, but SM_ENABLE resets to 0")

    await check_reset_values(link, full=False)

    # IMEM is not reset: reconfigure what reset cleared, enable, and the program runs.
    await link.write(sm(0, O_EXECCTRL), wrap(2))
    await link.write(sm(0, O_PINCTRL), PINCTRL_SET_BASE8)
    first = pads.edge
    await link.write(A_CTRL, 0x1)
    await ClockCycles(dut.clk, 30)
    vals = [v for _, v in steps(pads, first, 0, 0x1F)]
    check_cycle(link, "program in IMEM after the reset", vals[1:], [1, 30, 21])
    if len(vals) < 6:
        raise AssertionError("IMEM program did not run after reset")
