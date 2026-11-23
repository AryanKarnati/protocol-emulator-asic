# Polyglot tests

The cocotb testbench for the Tiny Tapeout project. `tb.v` instantiates `tt_um_aryankarnati_polyglot` (in `src/project.v`). The RTL simulation also compiles `src/polyglot.v`, which is generated from `hw/`.

`test.py` tests the block 3 chip as [docs/chip.md](../docs/chip.md) specifies it, through the top-level pins only. The host is a `cocotbext-spi` SPI master (mode 0, MSB first, pinned in `requirements.txt`), so the framing is not written by the project's own code. The PIO programs are assembled with the official pioasm, and their words are in `test.py`. `tb.v` exposes the SPI pins as plain regs, and resolves the uio pads (open-drain and pull-ups).

`GATES=yes make` runs a short subset (`GL_SUBSET` in `test.py`: ID and HWCFG, SCRATCH, one program run, one RX burst at clk/4, and the two reset tests). The full suite runs at RTL only, in CI.

`pio_block_reset/` is a cocotb test of the generated `pio_block`, run on its own (see `.github/workflows/pio_reset.yaml`).

## Setup

Install the Python packages:

```sh
pip install -r requirements.txt
```

Install Icarus Verilog (`iverilog` and `vvp`).

If you use the OSS CAD Suite, use wrappers for `iverilog` and `vvp` that don't set `PYTHONHOME`, and put them first on `PATH`. The suite's own environment can break cocotb's Python.

## RTL simulation

```sh
make -B
```

This writes `results.xml` and `tb.fst`. Check the results with:

```sh
python -m cocotb_tools.check_results results.xml
```

## Gate-level simulation

First harden the design. Copy the post-PnR netlist `runs/wokwi/results/final/verilog/gl/tt_um_aryankarnati_polyglot.v` to `test/gate_level_netlist.v`, then run:

```sh
make -B GATES=yes
```

The `PDK_ROOT` variable must point at the PDK install. CI copies the netlist from the GDS job itself.

## Waveforms

The simulation writes `tb.fst`. View it with GTKWave:

```sh
gtkwave tb.fst tb.gtkw
```

Or with Surfer:

```sh
surfer tb.fst
```

To write VCD instead of FST, run `make -B FST=` and change `$dumpfile` in `tb.v` to `tb.vcd`.
