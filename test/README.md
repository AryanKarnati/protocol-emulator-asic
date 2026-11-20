# Polyglot tests

The cocotb testbench for the Tiny Tapeout project. `tb.v` instantiates `tt_um_aryankarnati_polyglot` (in `src/project.v`). The RTL simulation also compiles `src/polyglot.v`, which is generated from `hw/`.

`test.py` tests the block 1 gate design, as specified in [docs/gate.md](../docs/gate.md). It is not the final test suite; block 3 replaces it with the real host link.

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
