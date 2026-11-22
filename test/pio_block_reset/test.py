"""Verilog-level reset check for the pio_block (block 2), under Icarus with cocotb.

The expected values are written here from docs/engine.md, not from the lockstep model:

  R0 (section 6): PC 0; X, Y, ISR, OSR 0; ISR count 0; OSR count 32; delay 0; both stall
  reasons 0; no latched instruction; no IRQ wait; side-set flags 0; sticky write empty;
  FIFOs empty; divider phase 0; IRQ flags 0; FDEBUG 0; pins_out and pins_oe 0; input
  registers 0. IMEM is not reset.

  Section 3: FSTAT is TXEMPTY [27:24], TXFULL [19:16], RXEMPTY [11:8], RXFULL [3:0]. FLEVEL
  is zero. FDEBUG is zero, with ILLEGAL in [31:28]. DBG_CNT (DESIGN 7) is ISR count [5:0],
  OSR count [13:8], delay [20:16], stall reason [27:24]. A FIFO of capacity 0 reads both full
  and empty. The configuration is the RP2040 reset (DESIGN 13: PIO defaults), so FJOIN is 0 and
  every FIFO has capacity 4.

The test runs a short program, asserts rst_n low for two clock cycles in the middle of the run,
and checks every output during the low period, and in cycle 0 after the release (the first
cycle with rst_n high, before any clock edge). The reset is asynchronous in the RTL, so rst_n
is driven low between clock edges as well as on them.
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ReadOnly, RisingEdge, Timer

N_SM = 4

# Port-level constants (engine.md section 3, R0, DESIGN 7 and 13).
FSTAT_R0 = (0x0 << 24) | (0x0 << 16) | (0xF << 8) | 0x0  # placeholder, rebuilt below
FSTAT_R0 = sum((1 << (24 + i)) | (1 << (8 + i)) for i in range(N_SM))  # TXEMPTY and RXEMPTY, all SMs
DBG_CNT_R0 = 32 << 8  # OSR count 32 (R0), ISR count 0, delay 0, no stall
PHASE_R0 = 0
CLKDIV_RESET = 0x0001_0000  # INT 1, FRAC 0
EXECCTRL_RESET = 0x0001_F000
SHIFTCTRL_RESET = 0x000C_0000  # FJOIN 0, shift right, thresholds 32
PINCTRL_RESET = 0x1400_0000  # SET_COUNT 5


def per_sm(name, value):
    return [(f"{name}{i}", value) for i in range(N_SM)]


def r0_outputs():
    """Every compared output and its R0 value."""
    outs = [
        ("pins_out", 0),
        ("pins_oe", 0),
        ("irq", 0),
        ("fstat", FSTAT_R0),
        ("flevel", 0),
        ("fdebug", 0),
    ]
    for name, v in [
        ("dbg_pc", 0),
        ("dbg_x", 0),
        ("dbg_y", 0),
        ("dbg_isr", 0),
        ("dbg_osr", 0),
        ("dbg_cnt", DBG_CNT_R0),
        ("dbg_exec_stalled", 0),
        ("dbg_phase", PHASE_R0),
    ]:
        outs += per_sm(name, v)
    return outs


async def check_r0(dut, where):
    await ReadOnly()
    bad = []
    for name, want in r0_outputs():
        got = int(getattr(dut, name).value)
        if got != want:
            bad.append(f"{name}: got 0x{got:x}, R0 0x{want:x}")
    assert not bad, f"{where}: " + "; ".join(bad)
    dut._log.info("%s: all %d outputs at R0", where, len(r0_outputs()))


def drive_idle(dut):
    dut.sm_enable.value = 0
    dut.sync_bypass.value = 0
    dut.pins_in.value = 0
    dut.sm_restart.value = 0
    dut.clkdiv_restart.value = 0
    dut.fifo_flush.value = 0
    dut.irq_clear.value = 0
    dut.irq_force.value = 0
    dut.fdebug_clear.value = 0
    dut.txf_push.value = 0
    dut.rxf_pop.value = 0
    dut.instr_write.value = 0
    dut.imem_write.value = 0
    for i in range(N_SM):
        getattr(dut, f"clkdiv{i}").value = CLKDIV_RESET
        getattr(dut, f"execctrl{i}").value = EXECCTRL_RESET
        getattr(dut, f"shiftctrl{i}").value = SHIFTCTRL_RESET
        getattr(dut, f"pinctrl{i}").value = PINCTRL_RESET


async def imem_write(dut, addr, data):
    dut.imem_write.value = 1
    dut.imem_addr.value = addr
    dut.imem_data.value = data
    await RisingEdge(dut.clock)
    dut.imem_write.value = 0


@cocotb.test()
async def reset_mid_run(dut):
    cocotb.start_soon(Clock(dut.clock, 10, unit="ns").start())
    drive_idle(dut)

    # Initial reset: rst_n low for two clock cycles, then released just after a rising edge.
    dut.rst_n.value = 0
    await RisingEdge(dut.clock)
    await RisingEdge(dut.clock)
    dut.rst_n.value = 1
    await Timer(1, unit="ns")
    await check_r0(dut, "cycle 0 after the initial release")

    # Program: SET PINS 1; SET PINS 0; JMP 0. IMEM is not reset, so it is written here.
    await imem_write(dut, 0, 0xE001)
    await imem_write(dut, 1, 0xE000)
    await imem_write(dut, 2, 0x0000)

    # Run SM0.
    dut.sm_enable.value = 0x1
    for _ in range(20):
        await RisingEdge(dut.clock)
    await ReadOnly()
    running = int(dut.pins_oe.value)
    dut._log.info("before the reset: pins_oe 0x%x, fstat 0x%x", running, int(dut.fstat.value))
    await Timer(1, unit="ns")  # leave ReadOnly before driving

    # Mid-run reset: rst_n low for two clock cycles, asserted between clock edges.
    await RisingEdge(dut.clock)
    await Timer(3, unit="ns")
    dut.rst_n.value = 0
    await Timer(1, unit="ns")
    await check_r0(dut, "during rst_n low (first cycle)")
    await RisingEdge(dut.clock)
    await Timer(1, unit="ns")
    await check_r0(dut, "during rst_n low (second cycle)")
    await RisingEdge(dut.clock)
    await Timer(1, unit="ns")
    # Release just after a rising edge, so the next edge is the first clock edge after reset.
    dut.rst_n.value = 1
    await Timer(1, unit="ns")
    await check_r0(dut, "cycle 0 after the release")
