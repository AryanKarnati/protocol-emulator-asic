"""Closed-loop co-simulation of the PIO SPI master with the whole-chip model (sw/host/cosim).

The library's Chip API and xfer_on_sm run against pgsim's master at 120 MHz and the chip model at
60 MHz, wired pad to pad. Each case sets the H (SCK phase in chip cycles), the host cost per FIFO
call (system cycles, which makes the host fast or slow), the clock phase of the chip, and the board
delays on each path, in system cycles. The MISO input bypasses its synchroniser (the library does).

Needs the plant built: dune build --root . (sw/host/cosim/cosim.exe). Skips without it.
"""

import pytest

import polyglot as pg
from cosim.plant import Plant, SimStateMachine, CosimTransport, rp2_regs, EXE
from conftest import load_rp2

MISO_BYPASS = 1 << 24  # GPIO 40 at gpio_base 16 (pio.c lines 362-370)

needs_plant = pytest.mark.skipif(
    not __import__("os").path.exists(EXE), reason="build the co-simulation first (dune build --root .)"
)


def _run(h, cost, phase, dsck, dmiso):
    rp2 = load_rp2()
    prog = pg.spi_master_program(rp2, h)
    regs = rp2_regs(prog, 2, 16, in_base=40, out_base=23, set_base=22, sideset_base=22)
    plant = Plant(prog[0], regs, phase=phase, dsck=dsck, dmiso=dmiso, bypass=MISO_BYPASS)
    try:
        chip = pg.Chip(CosimTransport(SimStateMachine(plant, cost)))
        assert chip.id() == 0x504C4754
        chip.write(0x038, [0x11223344])
        assert chip.read(0x038, 1) == [0x11223344]
        chip.write(0x038, [0xA5A5F00F])
        assert chip.read(0x038, 1) == [0xA5A5F00F]
    finally:
        plant.close()


@needs_plant
@pytest.mark.parametrize("h", [2, 3, 4, 5, 6])
@pytest.mark.parametrize("cost", [20, 1000])
@pytest.mark.parametrize("phase", [0, 1])
def test_chip_over_the_loop_at_each_h_host_cost_and_phase(h, cost, phase):
    _run(h, cost, phase, 0, 0)


@needs_plant
@pytest.mark.parametrize("h,dsck,dmiso", [(2, 0, 2), (2, 2, 0), (3, 2, 2), (3, 3, 3), (6, 3, 3)])
def test_board_delay_margin(h, dsck, dmiso):
    # The margins the README quotes. H = 2 is the tightest: 2 system cycles of round-trip margin
    # each way is what passes; H = 3 and above pass 3 cycles each way.
    _run(h, 20, 0, dsck, dmiso)
