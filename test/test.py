# SPDX-License-Identifier: Apache-2.0
#
# cocotb tests of the block 3 chip (docs/chip.md), through the top-level pins only.
#
# The host is a cocotbext-spi SpiMaster in mode 0, MSB first. Nothing in this file
# comes from the Python model (pgsim) or the RTL. Expected values come from chip.md,
# engine.md, DESIGN.md and the RP2040 datasheet (section 3.7 layouts). PIO programs are
# assembled with the official pioasm (2.3.1); the words are listed next to each program.
# The same file runs on the RTL and on the gate-level netlist (GATES=yes).
#
# Timing. clk is 60 MHz (16666 ps, as in the template). Two SCK rates are used:
#   clk/8 (SCK half period 4 cycles): the default for most tests;
#   clk/4 (half period 2 cycles, the H-SCK minimum): with CS_N high for 2 cycles between
#     frames (the H-CS minimum). These tests check MISO timing at the limit.
# Every pin change is made at a falling edge of clk, and so is every SCK edge, so no pin
# changes in the same step as a rising edge. CS_N falls, then the first SCK rise follows
# 1.5 SCK periods later (library behaviour; this is the only CS setup control).
#
# GATES=yes runs a short subset (GL_SUBSET below). The full suite runs in RTL CI.

import os

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge, Timer
from cocotbext.spi import SpiBus, SpiConfig, SpiMaster

CLK_PERIOD_PS = 16666
GATES = os.environ.get("GATES") == "yes"
GL_SUBSET = {
    "test_id_hwcfg",
    "test_scratch_write_read",
    "test_program_runs",
    "test_rx_burst_clk4",
    "test_reset_mid_frame",
    "test_reset_mid_program",
}

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


# Reset values (chip.md 8.1, engine.md R0)
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


# PIO programs (pioasm 2.3.1). Words are the assembled instructions.
#   PINSDEMO: set pins, 1 [1]; set pins, 30 [1]; set pins, 21 [1]        wrap 0..2
#   PULLDRIVE: pull block; out pins, 6                                    wrap 0..1
#   LOOPBACK: pull block; mov isr, osr; push block                        wrap 0..2
#   IN_PINS5: in pins, 5; push block; jmp 2                              (jmp 2 spins)
#   WAIT_PIN: wait 1 pin 0; set pins, 21; jmp 2
PINSDEMO = [0xE101, 0xE11E, 0xE115]
PULLDRIVE = [0x80A0, 0x6006]
LOOPBACK = [0x80A0, 0xA0C7, 0x8020]
IN_PINS5 = [0x4005, 0x8020, 0x0002]
WAIT_PIN = [0x20A0, 0xE015, 0x0002]  # wait 1 pin 0 is 0x20A0 (source PIN)
# Forced instructions (pioasm 2.3.1)
SET_PINDIRS_1 = 0xE081
SET_PINS_1 = 0xE001
SET_PINS_0 = 0xE000
SET_PINDIRS_0 = 0xE080
SET_X_21 = 0xE035
SET_Y_9 = 0xE049
SET_PINS_21 = 0xE015
IN_X_5 = 0x4025  # in x, 5
OUT_X_5 = 0x6025  # out x, 5
PULL_BLOCK = 0x80A0
WAIT_PIN0_HIGH = 0x20A0  # wait 1 pin 0

# Pin-walk programs (pioasm 2.3.1; the words were checked against the assembler output)
#   UI_IN_PINS5: in pins, 5; jmp 1 (spin)          reads pins 16..20 = ui_in[4:0] (IN_BASE 16)
#   UIO_IN_PINS8: in pins, 8; jmp 1 (spin)         reads pins 0..7 = uio_in (IN_BASE 0)
#   UIO_OUT_PROG: pull; out pindirs, 8; pull; out pins, 8; jmp 0
MOV_ISR_NULL = 0xA0C3  # mov isr, null
UI_IN_PINS5 = [0x4005, 0x0001]
UIO_IN_PINS8 = [0x4008, 0x0001]
UIO_OUT_PROG = [0x80A0, 0x6088, 0x80A0, 0x6008, 0x0000]

# PINCTRL values (RP2040 layout, datasheet table 395)
PINCTRL_SET_BASE8 = PINCTRL_RESET | (8 << 5)  # SET pins 8..12 = uo_out[4:0]
PINCTRL_OUT8_6 = PINCTRL_RESET | (6 << 20) | 8  # OUT pins 8..13 = uo_out[5:0]
PINCTRL_SET14 = (1 << 26) | (14 << 5)  # SET pin 14 = uo_out[6] (HOST_IRQ off)
PINCTRL_SET0_1 = 1 << 26  # SET pin 0 = uio[0]
PINCTRL_IN16_SET8 = PINCTRL_SET_BASE8 | (16 << 15)  # IN_BASE 16 = ext_ui[0]


# ---------------------------------------------------------------------------
# Host: a cocotbext-spi master on the pins that tb.v exposes
# ---------------------------------------------------------------------------
def spi_config(word_width, sck_half):
    period_ps = 2 * sck_half * CLK_PERIOD_PS
    return SpiConfig(
        word_width=word_width,
        sclk_freq=1e12 / period_ps,
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
    """SPI frames to the chip. Keeps the last frame for failure messages.

    sck_half: SCK half period in clk cycles (4 = clk/8, 2 = clk/4, the minimum).
    cs_high: clk cycles of CS_N high after each frame (2 is the H-CS minimum).
    edge_fn: optional. Called at the start of each frame to record start_edge.
    """

    def __init__(self, dut, sck_half=4, cs_high=4):
        self.dut = dut
        self.clk = dut.clk
        self.sck_half = sck_half
        self.cs_high = cs_high
        self.bus = SpiBus(
            entity=dut,
            sclk_name="spi_sck",
            mosi_name="spi_mosi",
            miso_name="spi_miso",
            cs_name="spi_cs_n",
        )
        self.bytes_master = SpiMaster(self.bus, spi_config(8, sck_half))
        self._bit_masters = {}
        self.last = (b"", b"")
        self.edge_fn = None
        self.start_edge = None
        self.rises = []  # edge numbers of SCK rises, if watch_sck was called

    def watch_sck(self, pads):
        """Record the edge number of every SCK rise (bit k of a frame is rise k)."""
        async def run():
            while True:
                await RisingEdge(self.dut.spi_sck)
                self.rises.append(pads.edge)

        cocotb.start_soon(run())

    def _bit_master(self, nbits):
        if nbits not in self._bit_masters:
            self._bit_masters[nbits] = SpiMaster(self.bus, spi_config(nbits, self.sck_half))
        return self._bit_masters[nbits]

    async def frame(self, tx):
        """One frame: CS_N low for all of tx, MISO bytes returned."""
        await FallingEdge(self.clk)
        if self.edge_fn is not None:
            self.start_edge = self.edge_fn()
        self.bytes_master.write_nowait(bytes(tx), burst=True)
        await self.bytes_master.wait()
        rx = bytes(self.bytes_master.read_nowait())
        self.last = (bytes(tx), rx)
        await ClockCycles(self.clk, self.cs_high)
        return rx

    async def bit_frame(self, nbits, value):
        """A frame of nbits bits (not a multiple of 8 in general), MSB first."""
        m = self._bit_master(nbits)
        await FallingEdge(self.clk)
        if self.edge_fn is not None:
            self.start_edge = self.edge_fn()
        m.write_nowait([value], burst=False)
        await m.wait()
        m.read_nowait()
        self.last = (value.to_bytes((nbits + 7) // 8, "big"), b"")
        await ClockCycles(self.clk, self.cs_high)

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


def chip_test(fn):
    """A cocotb test that the GATES=yes subset (GL_SUBSET) keeps."""
    return cocotb.test(skip=GATES and fn.__name__ not in GL_SUBSET)(fn)


async def set_reset(dut, value):
    await FallingEdge(dut.clk)
    dut.rst_n.value = value


async def start(dut, sck_half=4, cs_high=4, clock=True):
    """Reset, release, and return a Link. clock=False when a clock already runs."""
    if clock:
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_PS, unit="ps").start())
    dut.ena.value = 1
    dut.spi_sck.value = 0
    dut.spi_mosi.value = 0
    dut.spi_cs_n.value = 1
    dut.ext_ui.value = 0
    dut.ext_uio.value = 0xFF  # pads pulled up
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    link = Link(dut, sck_half, cs_high)
    await set_reset(dut, 1)
    await ClockCycles(dut.clk, 8)  # rst_n release goes through two flops
    return link


class Pads:
    """Samples uo_out at every falling edge. edge = rising edges so far, so sample k
    is the state after rising edge k (relative to this Pads' start)."""

    def __init__(self, dut):
        self.dut = dut
        self.samples = []  # (edge index, uo_out)
        self.edge = 0
        self.stopped = False
        cocotb.start_soon(self._run())

    def stop(self):
        self.stopped = True

    async def _run(self):
        while not self.stopped:
            await FallingEdge(self.dut.clk)
            self.samples.append((self.edge, int(self.dut.uo_out.value)))
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


def check_cycle(what, vals, cycle):
    """vals must be cycle repeated (starting at its first element)."""
    want = [cycle[i % len(cycle)] for i in range(len(vals))]
    if list(vals) != want:
        raise AssertionError(f"{what}: pin steps {vals}, expected the cycle {cycle} repeated")


def check_gaps(what, edges, gap):
    gaps = [b - a for a, b in zip(edges, edges[1:])]
    if any(g != gap for g in gaps):
        raise AssertionError(f"{what}: gaps between pin steps {gaps}, expected all {gap}")


async def settle(dut, cycles=3):
    await ClockCycles(dut.clk, cycles)


async def uo_bit(dut, bit):
    await FallingEdge(dut.clk)
    return (int(dut.uo_out.value) >> bit) & 1


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


async def assert_reset(dut, cycles):
    await set_reset(dut, 0)
    await ClockCycles(dut.clk, cycles)
    await set_reset(dut, 1)


# ---------------------------------------------------------------------------
# 1. Identity, status, scratch
# ---------------------------------------------------------------------------
@chip_test
async def test_id_hwcfg(dut):
    link = await start(dut)
    st, (idv,) = await link.read(A_ID)
    check(link, "ID", idv, ID_VALUE)
    check(link, "STATUS with ID read (reset)", st, STATUS_RESET)
    check(link, "HWCFG", await link.reg(A_HWCFG), HWCFG_VALUE)


@chip_test
async def test_id_clk4(dut):
    """clk/4 SCK (half period 2 cycles) with CS_N high for 2 cycles between frames."""
    link = await start(dut, sck_half=2, cs_high=2)
    st, (idv,) = await link.read(A_ID)
    check(link, "ID at clk/4", idv, ID_VALUE)
    check(link, "STATUS at clk/4", st, STATUS_RESET)
    check(link, "HWCFG at clk/4", await link.reg(A_HWCFG), HWCFG_VALUE)
    await link.write(A_SCRATCH, 0x0F0F_1234)
    check(link, "SCRATCH at clk/4", await link.reg(A_SCRATCH), 0x0F0F_1234)


@chip_test
async def test_status_one_byte(dut):
    link = await start(dut)
    st = await link.status()
    check(link, "1-byte frame STATUS (reset)", st, STATUS_RESET)
    check(link, "1-byte frame returns one byte", len(link.last[1]), 1)


@chip_test
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


@chip_test
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
# 2. Addressing (chip.md 6.3, 8.1)
# ---------------------------------------------------------------------------
@chip_test
async def test_addressing(dut):
    link = await start(dut)
    # F = 0 burst read across registers: ID, HWCFG, CTRL.
    rx = await link.frame(hdr(0x80, A_ID) + bytes(1 + 12))
    words = [int.from_bytes(rx[4 + 4 * m : 8 + 4 * m], "big") for m in range(3)]
    check_list(link, "F=0 burst read of ID, HWCFG, CTRL", words, [ID_VALUE, HWCFG_VALUE, 0])
    # Address wrap: 0xFFFC is unmapped (reads 0), the next word address is 0x0000 (ID).
    st, words = await link.read(0xFFFC, n=2)
    check_list(link, "read at 0xFFFC, n=2 (word 1 wraps to ID)", words, [0, ID_VALUE])
    # ADDR[1:0] is ignored.
    for a in [0x001, 0x002, 0x003]:
        check(link, f"ADDR {a:#05x} reads ID", (await link.read(a))[1][0], ID_VALUE)
    # CMD[5:0] is ignored: read with CMD = 0xBF (R = 1, F = 0), then write with CMD = 0x3F.
    rx = await link.frame(hdr(0xBF, A_ID) + bytes(5))  # header, dummy byte, one word
    check(link, "CMD[5:0] set on a read: ID", int.from_bytes(rx[4:8], "big"), ID_VALUE)
    await link.frame(hdr(0x3F, A_SCRATCH) + be_words([0x0BAD_C0DE]))
    check(link, "CMD[5:0] set on a write: SCRATCH", await link.reg(A_SCRATCH), 0x0BAD_C0DE)
    # F = 0 multi-word write walking three RW registers, then read back each one.
    await link.write(0x020, 0x0ABC, 0x55, 0x12_3456)
    check(link, "HOSTIRQ_EN after the walk", await link.reg(0x020), 0x0ABC)
    check(link, "PAD_OD after the walk", await link.reg(0x024), 0x55)
    check(link, "SYNC_BYPASS after the walk", await link.reg(0x028), 0x12_3456)
    for a in [0x020, 0x024, 0x028]:
        await link.write(a, 0)


@chip_test
async def test_reset_values(dut):
    link = await start(dut)
    await check_reset_values(link, full=True)


# ---------------------------------------------------------------------------
# 3. Register masks, unmapped addresses, read-only and write-only registers
# ---------------------------------------------------------------------------
@chip_test
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

    # IMEM is write-only: a write is stored (a program can run from it) and reads 0.
    await link.write(imem(5), 0xFFFF_FFFF)
    check(link, "IMEM[5] reads 0 after a write", await link.reg(imem(5)), 0)

    # Unmapped and write-only registers: reads 0, writes ignored.
    for addr in [0x0FC, A_DBG_CTRL, sm(0, O_LCU), sm(0, O_LCU + 0x0C), 0x300, 0x3FC]:
        await link.write(addr, 0xFFFF_FFFF)
        check(link, f"unmapped/absent {addr:#05x} reads 0", await link.reg(addr), 0)
    for addr in [A_IRQ_FORCE, txf(0), imem(0)]:
        check(link, f"write-only {addr:#05x} reads 0", await link.reg(addr), 0)


# ---------------------------------------------------------------------------
# 4. Forced instructions and debug reads
# ---------------------------------------------------------------------------
@chip_test
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
    # in x, 5: ISR = X << 27 (shift right, new bits at the top), ISR count 5, OSR count 32.
    await link.write(sm(0, O_INSTR), IN_X_5)
    await settle(dut)
    check(link, "DBG_ISR after in x, 5", await link.reg(sm(0, O_DBG_ISR)), 21 << 27)
    check(link, "DBG_CNT after in x, 5 (OSR 32, ISR 5)", await link.reg(sm(0, O_DBG_CNT)), 0x2005)
    # pull block with one TX word: OSR = the word, OSR count 0.
    await link.write(txf(0), 0x0BAD_F00D)
    await link.write(sm(0, O_INSTR), PULL_BLOCK)
    await settle(dut)
    check(link, "DBG_OSR after pull block", await link.reg(sm(0, O_DBG_OSR)), 0x0BAD_F00D)
    check(link, "DBG_CNT after pull (OSR 0, ISR 5)", await link.reg(sm(0, O_DBG_CNT)), 0x0005)
    check(link, "EXECCTRL bit 31 after completed forced instructions",
          await link.reg(sm(0, O_EXECCTRL)) >> 31, 0)


@chip_test
async def test_exec_stalled(dut):
    """A forced wait on a pin that is low stalls (EXEC_STALLED = 1, engine.md F4) and
    completes when the pin goes high."""
    link = await start(dut)
    await link.write(sm(0, O_PINCTRL), PINCTRL_IN16_SET8)  # IN_BASE 16: wait pin 0 = ext_ui[0]
    dut.ext_ui.value = 0
    await link.write(sm(0, O_INSTR), WAIT_PIN0_HIGH)
    await ClockCycles(dut.clk, 10)
    check(link, "EXECCTRL bit 31 while the forced wait stalls",
          await link.reg(sm(0, O_EXECCTRL)) >> 31, 1)
    dut.ext_ui.value = 0x01
    await ClockCycles(dut.clk, 10)
    check(link, "EXECCTRL bit 31 after the forced wait completes",
          await link.reg(sm(0, O_EXECCTRL)) >> 31, 0)


# ---------------------------------------------------------------------------
# 5. Programs: IMEM load, run, pins
# ---------------------------------------------------------------------------
@chip_test
async def test_program_runs(dut):
    """Load a program through SPI, run it, and see pins on uo_out[4:0]. Then stop it."""
    link = await start(dut)
    pads = Pads(dut)
    link.edge_fn = lambda: pads.edge
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
    check_cycle("uo_out[4:0] while running", vals[1:], [1, 30, 21])
    if len(vals) < 10:
        raise AssertionError(f"only {len(vals)} pin steps in 90 cycles")
    # Each instruction takes two ticks (its own and the delay of 1). At INT = 2 that is four
    # cycles between steps.
    check_gaps("uo_out[4:0] while running", [e for e, _ in t[1:]], 4)
    if any(uo & 0x20 for _, uo in pads.samples[first:]):
        raise AssertionError("uo_out[5] changed, but only 5 pins are set")

    # CTRL.SM_ENABLE = 0: the pins hold, and no more steps.
    await link.write(A_CTRL, 0x0)
    hold = pads.edge
    await ClockCycles(dut.clk, 40)
    later = steps(pads, hold, 0, 0x1F)
    if len(later) > 1:
        raise AssertionError(f"pins still stepping after SM_ENABLE = 0: {later}")
    # ADDR is the PC, which is one of the three instructions, and INSTR reads that word.
    pc = await link.reg(sm(0, O_ADDR))
    check(link, "ADDR is in 0..2", int(pc <= 2), 1)
    check(link, "INSTR reads IMEM[ADDR]", await link.reg(sm(0, O_INSTR)), PINSDEMO[pc])
    pads.stop()


@chip_test
async def test_program_in_page_1(dut):
    """EXT.PAGE selects IMEM words 32..63 (engine.md 9). Page 0 holds a decoy."""
    link = await start(dut)
    pads = Pads(dut)
    link.edge_fn = lambda: pads.edge
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
    t = steps(pads, first, 0, 0x1F)
    vals = [v for _, v in t]
    check(link, "pins before the first instruction", vals[0], 0)
    check_cycle("page 1 program pins", vals[1:], [1, 30, 21])
    if len(vals) < 9:
        raise AssertionError(f"page 1 program ran only {len(vals) - 1} steps")
    # INT 1 and delay 1: two cycles between steps.
    check_gaps("page 1 program pins", [e for e, _ in t[1:]], 2)
    pads.stop()


@chip_test
async def test_tx_pull_and_drive(dut):
    """TX words are pulled by a program and driven on uo_out[5:0]. Checks FIFO flags,
    STATUS (TX full, 0xE0) and the pad levels after the drain."""
    link = await start(dut)
    pads = Pads(dut)
    link.edge_fn = lambda: pads.edge
    await link.write(imem(0), *PULLDRIVE)
    await link.write(sm(0, O_CLKDIV), 0x0001_0000)
    await link.write(sm(0, O_EXECCTRL), wrap(1))
    await link.write(sm(0, O_PINCTRL), PINCTRL_OUT8_6)

    # Five words into TX0 with the SM disabled: four fit, the fifth is dropped.
    w = [0x5A5A_5A15, 0xFFFF_FF2A, 0x1234_567F, 0x0000_0041, 0x0000_000B]
    await link.write(txf(0), *w, fixed=True)
    st, (f,) = await link.read(A_FSTAT)
    check(link, "FSTAT after 5 pushes (TX0 full, not empty)", f, 0x0E01_0F00)
    check(link, "STATUS in the FSTAT frame: TX0 full (TXNFULL0 = 0)", st, 0xE0)
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
    check_gaps("uo_out[5:0] while draining", [e for e, _ in t[1:]], 2)

    # The program stalls on an empty TX FIFO, and that sets TXSTALL0 (bit 24).
    check(link, "FDEBUG: TXSTALL0 after the drain", await link.reg(A_FDEBUG), 0x0100_0000)
    check(link, "FSTAT after the drain: TX0 empty", await link.reg(A_FSTAT), FSTAT_RESET)
    check(link, "PAD_OUT after the drain: pins 8..13 = 1", await link.reg(A_PAD_OUT), 0x100)
    check(link, "PAD_OE: no pin is an output", await link.reg(A_PAD_OE), 0)
    check(link, "pins hold the last word", pads.samples[-1][1] & 0x3F, 0x01)
    pads.stop()


@chip_test
async def test_rx_loopback_burst(dut):
    """A program pushes RX words. A burst read with F = 1 drains them, then FSTAT, FLEVEL,
    FDEBUG and STATUS are checked. A burst longer than the FIFO reads 0 and sets RXUNDER0."""
    link = await start(dut)
    await link.write(imem(0), *LOOPBACK)
    await link.write(sm(0, O_CLKDIV), 0x0001_0000)
    await link.write(sm(0, O_EXECCTRL), wrap(2))

    first_batch = [0x1122_3344, 0x5566_7788, 0x99AA_BBCC, 0xDDEE_FF00]
    await link.write(txf(0), *first_batch, fixed=True)
    await link.write(A_CTRL, 0x1)
    await settle(dut, 40)

    # RX0 full with 4 words, TX0 empty, the program stalled on pull (TXSTALL0 set).
    st, (f,) = await link.read(A_FSTAT)
    check(link, "FSTAT with RX0 full", f, 0x0F00_0E01)
    check(link, "STATUS in the FSTAT frame: RXNEMPTY0 with TX not full", st, 0xF1)
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


@chip_test
async def test_rx_burst_clk4(dut):
    """The RX loopback burst at clk/4 with CS_N high for 2 cycles between frames. A 2-cycle
    MISO delay fails here (chip.md 6.5, 6.6)."""
    link = await start(dut, sck_half=2, cs_high=2)
    await link.write(imem(0), *LOOPBACK)
    await link.write(sm(0, O_CLKDIV), 0x0001_0000)
    await link.write(sm(0, O_EXECCTRL), wrap(2))
    batch = [0xA1B2_C3D4, 0x0BAD_F00D, 0x1357_9BDF, 0xFEDC_BA98]
    await link.write(txf(0), *batch, fixed=True)
    await link.write(A_CTRL, 0x1)
    await settle(dut, 40)
    st, words = await link.read(rxf(0), n=4, fixed=True)
    check(link, "STATUS at the start of the clk/4 burst", st, 0xF1)
    check_list(link, "clk/4 RX burst of 4 words", words, batch)
    check(link, "FSTAT after the clk/4 burst: RX0 empty", await link.reg(A_FSTAT), FSTAT_RESET)


@chip_test
async def test_rx_stall_full(dut):
    """A blocking push into a full RX FIFO stalls and sets RXSTALL0 (bit 0). The stalled
    push completes after the host pops a word (R7, H2)."""
    link = await start(dut)
    await link.write(imem(0), *LOOPBACK)
    await link.write(sm(0, O_CLKDIV), 0x0001_0000)
    await link.write(sm(0, O_EXECCTRL), wrap(2))
    batch = [0x0000_0011, 0x0000_0022, 0x0000_0033, 0x0000_0044]
    await link.write(txf(0), *batch, fixed=True)
    await link.write(A_CTRL, 0x1)
    await settle(dut, 40)
    check(link, "FDEBUG with RX0 full: TXSTALL0 only", await link.reg(A_FDEBUG), 0x0100_0000)
    # The fifth word: the program pulls it, and its push finds RX0 full.
    await link.write(txf(0), 0x5555_AAAA)
    await settle(dut, 20)
    st, (f,) = await link.read(A_FSTAT)
    check(link, "FSTAT with RX0 full and the push stalled", f, 0x0F00_0E01)
    check(link, "FDEBUG: RXSTALL0 set by the blocked push", await link.reg(A_FDEBUG), 0x0100_0001)
    # Pop one word: the stalled push then completes, so RX0 holds the fifth word.
    st, words = await link.read(rxf(0), n=4, fixed=True)
    check_list(link, "RX burst of the first four words", words, batch)
    check(link, "FLEVEL after the stalled push completes: RX0 level 1", await link.reg(A_FLEVEL), 0x10)
    check(link, "FDEBUG: RXSTALL0 stays set (sticky)", await link.reg(A_FDEBUG), 0x0100_0001)
    st, words = await link.read(rxf(0))
    check(link, "fifth word", words[0], 0x5555_AAAA)


@chip_test
async def test_sm_each_loopback(dut):
    """SMs 1 to 3 run the same loopback program with their own TX and RX FIFOs, configuration,
    CTRL enable bit, FSTAT, FLEVEL, FDEBUG, STATUS and HOST_IRQ source (RXNEMPTY1)."""
    link = await start(dut)
    await link.write(imem(0), *LOOPBACK)
    words = {1: [0x1111_0001, 0x1111_0002, 0x1111_0003, 0x1111_0004],
             2: [0x2222_0001, 0x2222_0002, 0x2222_0003, 0x2222_0004],
             3: [0x3333_0001, 0x3333_0002, 0x3333_0003, 0x3333_0004]}
    for n in (1, 2, 3):
        await link.write(sm(n, O_CLKDIV), 0x0001_0000)
        await link.write(sm(n, O_EXECCTRL), wrap(2))
        await link.write(txf(n), *words[n], fixed=True)
    await link.write(A_HOSTIRQ_EN, 0x020)  # RXNEMPTY1 only
    await link.write(A_CTRL, 0x0E)
    check(link, "CTRL readback: SM1..3 enabled", await link.reg(A_CTRL), 0x0E)
    await settle(dut, 40)

    st, (f,) = await link.read(A_FSTAT)
    check(link, "FSTAT: TX empty for SM0..3, RX0 empty, RX1..3 full", f, 0x0F00_010E)
    check(link, "STATUS: TXNFULL 1111, RXNEMPTY1..3", st, 0xFE)
    check(link, "FLEVEL: RX level 4 for SM1..3 (TX 0)", await link.reg(A_FLEVEL), 0x4040_4000)
    check(link, "FDEBUG: TXSTALL1..3", await link.reg(A_FDEBUG), 0x0E00_0000)
    check(link, "HOST_IRQ = RXNEMPTY1 (uo_out[6] = 1)", await uo_bit(dut, 6), 1)

    for n in (1, 2, 3):
        st, got = await link.read(rxf(n), n=4, fixed=True)
        check_list(link, f"SM{n} RX burst of its 4 words", got, words[n])
    check(link, "FSTAT after the bursts: all RX empty", await link.reg(A_FSTAT), FSTAT_RESET)
    check(link, "HOST_IRQ after RX1 is empty (uo_out[6] = 0)", await uo_bit(dut, 6), 0)
    check(link, "CTRL readback before disabling", await link.reg(A_CTRL), 0x0E)
    await link.write(A_CTRL, 0x0)
    check(link, "CTRL readback after disabling", await link.reg(A_CTRL), 0)


# ---------------------------------------------------------------------------
# 6. Pads, pins and HOST_IRQ
# ---------------------------------------------------------------------------
@chip_test
async def test_pad_in_pads_out(dut):
    """PAD_IN is the raw pad levels in the cycle of the read: uio_in, uo_out, ui_in. Here
    ui_in = {CS_N, MOSI, SCK, ext_ui} with CS_N low and SCK high at the read, MOSI low (the
    dummy byte), so PAD_IN[23:16] = 0x20 | ext_ui. The read happens in SCK's high phase
    (clk/8 gives 4 high cycles). PAD_OUT and PAD_OE follow the pins."""
    link = await start(dut)
    await link.write(sm(0, O_PINCTRL), PINCTRL_SET_BASE8)
    await link.write(sm(0, O_INSTR), SET_PINS_21)  # pins 8..12 = 21, SM disabled
    await settle(dut)
    dut.ext_ui.value = 0x13
    dut.ext_uio.value = 0xA5
    await settle(dut)
    check(link, "PAD_OUT: pins 8..12 = 21", await link.reg(A_PAD_OUT), 21 << 8)
    check(link, "PAD_OE: no pin is an output", await link.reg(A_PAD_OE), 0)
    check(link, "PAD_IN with CS_N low, SCK high, MOSI low",
          await link.reg(A_PAD_IN), ((0x20 | 0x13) << 16) | (21 << 8) | 0xA5)
    dut.ext_ui.value = 0
    dut.ext_uio.value = 0xFF


@chip_test
async def test_in_pins_sync(dut):
    """A program reads ext_ui through IN_BASE: in pins, 5 gives ISR = pins[4:0] << 27
    (engine.md 6, datasheet 3.5.4). Synchronised input (INPUT_SYNC_BYPASS = 0)."""
    await _in_pins_run(dut, bypass=0)


@chip_test
async def test_in_pins_bypass(dut):
    """The same read with INPUT_SYNC_BYPASS set for pins 16..23: same value."""
    await _in_pins_run(dut, bypass=0xFF_FFFF)


async def _in_pins_run(dut, bypass):
    link = await start(dut)
    dut.ext_ui.value = 0x13
    await link.write(A_SYNC_BYPASS, bypass)
    await link.write(imem(0), *IN_PINS5)
    await link.write(sm(0, O_PINCTRL), PINCTRL_IN16_SET8)
    await link.write(A_CTRL, 0x1)
    await settle(dut, 30)
    check(link, "FLEVEL: one word in RX0", await link.reg(A_FLEVEL), 0x10)
    check(link, "RX0 word = ext_ui[4:0] << 27", (await link.read(rxf(0)))[1][0], 0x13 << 27)
    await link.write(A_CTRL, 0x0)
    await link.write(A_SYNC_BYPASS, 0)
    dut.ext_ui.value = 0


@chip_test
async def test_wait_pin_program(dut):
    """wait 1 pin 0 on ext_ui[0] (IN_BASE 16): the program waits, then drives pins."""
    link = await start(dut)
    pads = Pads(dut)
    dut.ext_ui.value = 0
    await link.write(imem(0), *WAIT_PIN)
    await link.write(sm(0, O_PINCTRL), PINCTRL_IN16_SET8)
    await link.write(A_CTRL, 0x1)
    await ClockCycles(dut.clk, 40)
    # Still waiting: no change on uo_out[4:0] over the next 20 cycles.
    first = pads.edge
    await ClockCycles(dut.clk, 20)
    pending = steps(pads, first, 0, 0x1F)
    if len(pending) != 1:
        raise AssertionError(f"uo_out[4:0] changed while wait 1 pin 0 is pending: {pending}")
    dut.ext_ui.value = 0x01
    await ClockCycles(dut.clk, 20)
    vals = [v for _, v in steps(pads, first, 0, 0x1F)]
    if 0x15 not in vals:
        raise AssertionError(f"after wait 1 pin 0 passes, uo_out[4:0] steps {vals}, expected 21")
    pads.stop()
    await link.write(A_CTRL, 0x0)
    dut.ext_ui.value = 0


@chip_test
async def test_open_drain(dut):
    """PAD_OD on uio[0] (engine.md 9.2 and chip.md 9.2). PAD_OE and PAD_OUT follow pindirs
    and pins."""
    link = await start(dut)
    await link.write(sm(0, O_PINCTRL), PINCTRL_SET0_1)  # SET pin 0 only, which is uio[0]

    async def pads_now():
        await FallingEdge(dut.clk)
        return int(dut.uio_out.value), int(dut.uio_oe.value), int(dut.uo_out.value)

    async def pad_in_low_byte():
        return (await link.read(A_PAD_IN))[1][0] & 0xFF

    # PAD_OD = 0: a driven 1 is a push-pull 1.
    await link.write(sm(0, O_INSTR), SET_PINDIRS_1)
    await link.write(sm(0, O_INSTR), SET_PINS_1)
    await settle(dut)
    out, oe, _ = await pads_now()
    check(link, "uio_out[0] driven 1, PAD_OD = 0", out & 1, 1)
    check(link, "uio_oe[0] = 1, PAD_OD = 0", oe & 1, 1)
    check(link, "PAD_OE bit 0 (pindirs output)", await link.reg(A_PAD_OE), 0x01)
    check(link, "PAD_OUT bit 0 (level 1)", await link.reg(A_PAD_OUT), 0x01)

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
    check(link, "PAD_IN[7:0] shows the uio input levels", await pad_in_low_byte(), 0xFE)
    dut.ext_uio.value = 0xFF


@chip_test
async def test_host_irq(dut):
    """HOST_IRQ on uo_out[6]: HOSTIRQ_EN = 0 gives pins_out[14], otherwise the OR of the
    enabled sources (chip.md 9.2 and 9.3)."""
    link = await start(dut)
    await link.write(sm(0, O_PINCTRL), PINCTRL_SET14)  # SET pin 14 = uo_out[6]
    await link.write(sm(0, O_INSTR), SET_PINS_1)  # pins_out[14] = 1
    await settle(dut)

    async def uo6():
        return await uo_bit(dut, 6)

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

    # irq[3] as the source (not irq[0]).
    await link.write(A_HOSTIRQ_EN, 0x008)
    await link.write(A_IRQ_FORCE, 0x08)
    await settle(dut)
    check(link, "HOSTIRQ_EN = irq[3], flag set: uo_out[6] = 1", await uo6(), 1)
    await link.write(A_IRQ, 0x08)
    await settle(dut)
    check(link, "HOSTIRQ_EN = irq[3], flag clear: uo_out[6] = 0", await uo6(), 0)

    # TXNFULL0 as the source: TX empty gives 1, TX full gives 0.
    await link.write(A_HOSTIRQ_EN, 0x100)
    await settle(dut)
    check(link, "HOSTIRQ_EN = TXNFULL0, TX empty: uo_out[6] = 1", await uo6(), 1)
    await link.write(txf(0), 1, 2, 3, 4, fixed=True)
    await settle(dut)
    check(link, "HOSTIRQ_EN = TXNFULL0, TX full: uo_out[6] = 0 (pins_out[14] = 1 is masked)",
          await uo6(), 0)

    # TXNFULL3 as the source (SM3's TX FIFO, not SM0's).
    await link.write(A_HOSTIRQ_EN, 0x800)
    await settle(dut)
    check(link, "HOSTIRQ_EN = TXNFULL3, TX3 empty: uo_out[6] = 1", await uo6(), 1)
    await link.write(txf(3), 1, 2, 3, 4, fixed=True)
    await settle(dut)
    check(link, "HOSTIRQ_EN = TXNFULL3, TX3 full: uo_out[6] = 0", await uo6(), 0)

    await link.write(A_HOSTIRQ_EN, 0x000)
    await settle(dut)
    check(link, "HOSTIRQ_EN = 0 again: uo_out[6] = pins_out[14]", await uo6(), 1)
    check(link, "PAD_OUT bit 14", (await link.reg(A_PAD_OUT)) >> 14 & 1, 1)
    await FallingEdge(dut.clk)
    check(link, "uo_out[7] (MISO) is 0 between frames", (int(dut.uo_out.value) >> 7) & 1, 0)


@chip_test
async def test_sm_restart_and_fjoin(dut):
    """SM_RESTART sets the OSR count back to 32 (DBG_CNT); a SHIFTCTRL FJOIN change flushes
    both FIFOs (chip.md 8.2) and the capacities follow FJOIN."""
    link = await start(dut)
    await link.write(txf(0), 0x1234_5678)
    await link.write(sm(0, O_INSTR), PULL_BLOCK)
    await link.write(sm(0, O_INSTR), OUT_X_5)
    await settle(dut)
    check(link, "DBG_CNT after pull and out 5 (OSR count 5)", await link.reg(sm(0, O_DBG_CNT)), 0x0500)
    await link.write(A_CTRL, 0x10)  # SM_RESTART for SM0, SM disabled
    await settle(dut)
    check(link, "DBG_CNT after SM_RESTART (OSR count 32)", await link.reg(sm(0, O_DBG_CNT)), DBG_CNT_RESET)

    # FJOIN_TX: TX capacity 8, RX capacity 0 (both reads full and empty). FIFOs are flushed.
    await link.write(txf(0), 0xAAAA_0001, 0xAAAA_0002, fixed=True)
    check(link, "FLEVEL before the FJOIN change: TX0 level 2", await link.reg(A_FLEVEL), 0x2)
    await link.write(sm(0, O_SHIFTCTRL), SHIFTCTRL_RESET | 0x4000_0000)
    check(link, "FLEVEL after the FJOIN change: flushed", await link.reg(A_FLEVEL), 0)
    check(link, "FSTAT after FJOIN_TX: SM0 TX empty, RX0 empty and full",
          await link.reg(A_FSTAT), 0x0F00_0F01)
    await link.write(sm(0, O_SHIFTCTRL), SHIFTCTRL_RESET)
    check(link, "FSTAT after FJOIN back to 0: reset value", await link.reg(A_FSTAT), FSTAT_RESET)


@chip_test
async def test_clkdiv_restart(dut):
    """CLKDIV_RESTART sets the divider phase to 0 (engine.md R10, H4). The phase is not in
    the register map, so the effect is read from the pin steps of a program at INT = 3.

    Two runs from reset. Run B has a 1-byte frame before the restart. Both start the
    divider at the same point, so a restart at edge E puts the tick grid on E mod 3. The
    grid before the restart is the same in both runs. After the restart, the difference
    of the grids must equal the difference of the restart edges, mod 3."""
    results = {}
    for label, extra in [("A", False), ("B", True)]:
        link = await start(dut, clock=(label == "A"))
        pads = Pads(dut)
        link.edge_fn = lambda p=pads: p.edge
        link.watch_sck(pads)
        await link.write(imem(0), *PINSDEMO)
        await link.write(sm(0, O_CLKDIV), 0x0003_0000)  # INT 3
        await link.write(sm(0, O_EXECCTRL), wrap(2))
        await link.write(sm(0, O_PINCTRL), PINCTRL_SET_BASE8)
        await link.write(A_CTRL, 0x1)  # enable, no restart
        await ClockCycles(dut.clk, 30)
        if extra:
            await link.status()  # 84 edges, a multiple of 3, so one idle cycle as well
            await ClockCycles(dut.clk, 1)
        n0 = len(link.rises)
        await link.write(A_CTRL, 0x101)  # SM0 enabled, CLKDIV_RESTART for SM0
        restart_edge = link.start_edge
        await ClockCycles(dut.clk, 60)
        all_steps = steps(pads, 0, 0, 0x1F)[1:]  # [0] is the reset value, not a step
        # The restart takes effect in the cycle bit 55 of the CTRL write is clocked
        # (chip.md 8.2): the RISE is 2 cycles after SCK rises (chip.md 6.5). The
        # margin of 10 cycles covers the edge numbering.
        effect = link.rises[n0 + 55] + 2
        pre = {e % 3 for e, _ in all_steps if e < effect}
        post = {e % 3 for e, _ in all_steps if e >= effect + 10}
        if len(pre) != 1 or len(post) != 1:
            raise AssertionError(f"run {label}: tick grid not one phase: pre {pre}, post {post}; "
                                 f"restart edge {restart_edge}, steps {all_steps}")
        results[label] = (restart_edge, pre.pop(), post.pop())
        pads.stop()
    ea, pre_a, post_a = results["A"]
    eb, pre_b, post_b = results["B"]
    if pre_a != pre_b:
        raise AssertionError(f"grid before the restart differs: A {pre_a}, B {pre_b}")
    delta = eb - ea
    if delta % 3 == 0:
        raise AssertionError(f"prefix frame is {delta} edges, a multiple of 3: test cannot tell")
    want = delta % 3
    got = (post_b - post_a) % 3
    if got != want:
        raise AssertionError(
            f"tick grid after CLKDIV_RESTART: post-restart phase differs by {got} mod 3, "
            f"expected {want} (restart edges A {ea}, B {eb}, grids pre {pre_a}, "
            f"post A {post_a}, post B {post_b})")


# ---------------------------------------------------------------------------
# 7. Multi-SM: the lanes in SMs 1 to 3 are checked above; SM0 pins are in the tests above.
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# 7. Pin walks: each pin on its own, one at a time (walking one and walking zero)
# ---------------------------------------------------------------------------
@chip_test
async def test_ui_in_walk(dut):
    """Each ui_in[4:0] bit on its own, seen by a program through in pins, 5 (IN_BASE 16).
    The program runs in once per forced jmp 0; the ISR is cleared first, so DBG_ISR
    shows exactly the 5 bits read: ISR = ui_in[4:0] << 27."""
    link = await start(dut)
    await link.write(imem(0), *UI_IN_PINS5)
    await link.write(sm(0, O_PINCTRL), PINCTRL_IN16_SET8)
    await link.write(A_CTRL, 0x1)
    walk = [1 << i for i in range(5)] + [0x1F ^ (1 << i) for i in range(5)]
    for v in walk:
        dut.ext_ui.value = v
        await link.write(sm(0, O_INSTR), MOV_ISR_NULL)  # ISR = 0
        await link.write(sm(0, O_INSTR), 0x0000)  # forced jmp 0: the in runs next
        await ClockCycles(dut.clk, 10)
        check(link, f"DBG_ISR after in pins,5 with ui_in[4:0] = {v:#04x}",
              await link.reg(sm(0, O_DBG_ISR)), v << 27)
    await link.write(A_CTRL, 0x0)
    dut.ext_ui.value = 0


@chip_test
async def test_uio_in_walk(dut):
    """Each uio_in[7:0] bit on its own (pads that the chip does not drive), seen through
    in pins, 8 (IN_BASE 0). ISR = uio_in << 24."""
    link = await start(dut)
    await link.write(imem(0), *UIO_IN_PINS8)
    await link.write(A_CTRL, 0x1)
    walk = [1 << i for i in range(8)] + [0xFF ^ (1 << i) for i in range(8)]
    for v in walk:
        dut.ext_uio.value = v
        await link.write(sm(0, O_INSTR), MOV_ISR_NULL)
        await link.write(sm(0, O_INSTR), 0x0000)
        await ClockCycles(dut.clk, 10)
        check(link, f"DBG_ISR after in pins,8 with uio_in = {v:#04x}",
              await link.reg(sm(0, O_DBG_ISR)), v << 24)
    await link.write(A_CTRL, 0x0)
    dut.ext_uio.value = 0xFF


@chip_test
async def test_uio_out_walk(dut):
    """Each uio_out[7:0] bit on its own, driven by a program: out pindirs, 8 (all pads
    outputs) and out pins, 8 with OUT_COUNT 8. The pad levels are checked on the pins."""
    link = await start(dut)
    await link.write(imem(0), *UIO_OUT_PROG)
    await link.write(sm(0, O_PINCTRL), PINCTRL_RESET | (8 << 20))  # OUT_COUNT 8, OUT_BASE 0
    await link.write(A_CTRL, 0x1)

    async def pads_uio():
        await FallingEdge(dut.clk)
        return int(dut.uio_out.value), int(dut.uio_oe.value)

    walk = [1 << i for i in range(8)] + [0xFF ^ (1 << i) for i in range(8)]
    for v in walk:
        await link.write(txf(0), 0xFF, v, fixed=True)  # pindirs = all output, then pins = v
        await ClockCycles(dut.clk, 20)
        out, oe = await pads_uio()
        if out != v or oe != 0xFF:
            raise AssertionError(f"uio pads with pins {v:#04x}: uio_out {out:#04x}, "
                                 f"uio_oe {oe:#04x}, expected {v:#04x} and 0xff")
    await link.write(A_CTRL, 0x0)


@chip_test
async def test_uo_out_walk(dut):
    """Each uo_out[5:0] bit on its own, driven by out pins, 6 (OUT_BASE 8, OUT_COUNT 6)."""
    link = await start(dut)
    await link.write(imem(0), *PULLDRIVE)
    await link.write(sm(0, O_CLKDIV), 0x0001_0000)
    await link.write(sm(0, O_EXECCTRL), wrap(1))
    await link.write(sm(0, O_PINCTRL), PINCTRL_OUT8_6)
    await link.write(A_CTRL, 0x1)
    walk = [1 << i for i in range(6)] + [0x3F ^ (1 << i) for i in range(6)]
    for v in walk:
        await link.write(txf(0), v, fixed=True)
        await ClockCycles(dut.clk, 10)
        await FallingEdge(dut.clk)
        got = int(dut.uo_out.value) & 0x3F
        if got != v:
            raise AssertionError(f"uo_out[5:0] with the word {v:#04x}: got {got:#04x}")
    await link.write(A_CTRL, 0x0)


# ---------------------------------------------------------------------------
# 8. Reset (chip.md 10)
# ---------------------------------------------------------------------------
@chip_test
async def test_reset_mid_frame(dut):
    """rst_n goes low in the middle of a write frame, after the word's last bit (bit 55) has
    been clocked, and the frame ends during reset. Reset clears SCRATCH, so the value is 0,
    neither the frame's word nor the value before the frame."""
    link = await start(dut)
    await link.write(A_SCRATCH, 0x1234_5678)
    # 3 header bytes, the word, then one extra byte: the frame is still running when reset
    # falls at bit 60, after bit 55.
    tx = hdr(0x00, A_SCRATCH) + be_words([0xDEAD_BEEF]) + bytes([0x00])
    await FallingEdge(dut.clk)
    link.bytes_master.write_nowait(tx, burst=True)
    # Wait for the SCK rise of bit 60 (rise k delivers bit k). Bit 55 has been clocked, so
    # the word is complete. Byte boundaries add cycles, so count rises, not cycles.
    for _ in range(61):
        await RisingEdge(dut.spi_sck)
    await set_reset(dut, 0)
    await link.bytes_master.wait()
    link.bytes_master.read_nowait()
    link.last = (tx, b"")
    await ClockCycles(dut.clk, 2 * 4)  # CS_N high for 4 cycles before release (H-RST)
    await set_reset(dut, 1)
    await ClockCycles(dut.clk, 8)

    st, (idv,) = await link.read(A_ID)
    check(link, "ID after reset in mid-frame", idv, ID_VALUE)
    check(link, "STATUS after reset in mid-frame", st, STATUS_RESET)
    check(link, "SCRATCH after reset in mid-frame: reset value, not the frame's word",
          await link.reg(A_SCRATCH), 0)
    await link.write(A_SCRATCH, 0xCAFE_BABE)
    check(link, "SCRATCH writes work after reset", await link.reg(A_SCRATCH), 0xCAFE_BABE)


@chip_test
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
    if len(steps(pads, 0, 0, 0x1F)) < 4:
        raise AssertionError("the program did not run before the reset")

    # Reset between clock edges, while the program runs.
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
    pads.stop()

    await check_reset_values(link, full=False)

    # IMEM is not reset: reconfigure what reset cleared, enable, and the program runs.
    pads = Pads(dut)
    await link.write(sm(0, O_EXECCTRL), wrap(2))
    await link.write(sm(0, O_PINCTRL), PINCTRL_SET_BASE8)
    first = pads.edge
    await link.write(A_CTRL, 0x1)
    await ClockCycles(dut.clk, 30)
    vals = [v for _, v in steps(pads, first, 0, 0x1F)]
    check_cycle("program in IMEM after the reset", vals[1:], [1, 30, 21])
    if len(vals) < 6:
        raise AssertionError("IMEM program did not run after reset")
    pads.stop()
