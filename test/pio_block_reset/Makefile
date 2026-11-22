# cocotb + Icarus reset check for the generated pio_block Verilog (block 2).
#
# The Verilog is generated, not committed (engine.md 8):
#   dune exec --root . hw/bin/gen_verilog.exe -- pio_block > $(PIO_VERILOG)
# Run with the cocotb venv and the Icarus wrapper on PATH:
#   PIO_VERILOG=/path/to/pio_block.v PATH=$HOME/.local/venvs/cocotb/bin:$HOME/.local/polyglot-bin:$PATH make
PIO_VERILOG ?= pio_block.v

SIM ?= icarus
TOPLEVEL_LANG ?= verilog
VERILOG_SOURCES = $(PIO_VERILOG)
TOPLEVEL = pio_block
MODULE = test
COCOTB_TEST_MODULES ?= test

include $(shell cocotb-config --makefiles)/Makefile.sim
