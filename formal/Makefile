# Formal proofs (SymbiYosys), the decoder check, and the mutant checks.
#
#   make -C formal all        everything below
#   make -C formal gen        the Verilog, including the debug netlists
#   make -C formal prove      all SymbiYosys proofs and covers
#   make -C formal decode     decoder: Cyclesim and Verilator enumeration, and its mutants
#   make -C formal mutants    all mutant checks (needs `make gen`)
#
# OPAM_EXEC runs dune inside the OCaml environment. Locally, set it to your switch, e.g.
#   make -C formal OPAM_EXEC="$$HOME/.local/bin/opam exec --switch=polyglot --"
# SBY and VERILATOR are the binaries (default: on PATH). PYTHON is python3.
#
# Several proofs run on a debug netlist: the generated Verilog plus extra output ports
# (tools/add_fifo_debug.py, tools/add_clkdiv_debug.py). The harnesses need internal state
# (storage words, pointers, phase). See PROPERTIES.md for the trade-off.

ROOT := ..
OPAM_EXEC ?= opam exec --
SBY ?= sby
VERILATOR ?= verilator
PYTHON ?= python3
export SBY

DUNE = cd $(ROOT) && $(OPAM_EXEC) dune

.PHONY: all gen prove decode mutants d5_slow clean

# The bounded D5 checks: manual only, not in CI. D1 (tick every cycle for 1/0, proven
# unbounded) already implies the 256-gap sum for 1/0, so this only adds evidence for the
# fractional divisor 1/255. Times: 1/0 about 594 s, 1/255 about 23 minutes and 1.2 GB.
d5_slow: gen
	$(SBY) -f clkdiv_d5.sby d5_1_0 -d build/d5_1_0
	$(SBY) -f clkdiv_d5.sby d5_1_255 -d build/d5_1_255

all: gen prove decode mutants

gen:
	mkdir -p build
	$(DUNE) build --root . --display=quiet ./formal/gen/gen_formal.exe ./hw/bin/gen_verilog.exe ./formal/decode/dump_expected.exe
	$(DUNE) exec --root . --display=quiet ./formal/gen/gen_formal.exe -- fifo_4x32 > $(CURDIR)/build/fifo_4x32.v
	$(DUNE) exec --root . --display=quiet ./formal/gen/gen_formal.exe -- clkdiv > $(CURDIR)/build/clkdiv.v
	$(DUNE) exec --root . --display=quiet ./formal/gen/gen_formal.exe -- clkdiv_dbg > $(CURDIR)/build/clkdiv_dbg.v
	$(DUNE) exec --root . --display=quiet ./formal/gen/gen_formal.exe -- fifo_join > $(CURDIR)/build/fifo_join.v
	$(DUNE) exec --root . --display=quiet ./hw/bin/gen_verilog.exe -- decode > $(CURDIR)/build/decode.v
	$(DUNE) exec --root . --display=quiet ./formal/decode/dump_expected.exe > $(CURDIR)/build/decode_expected.txt
	$(PYTHON) tools/add_fifo_debug.py build/fifo_4x32.v build/fifo_4x32_dbg.v
	$(PYTHON) tools/add_clkdiv_debug.py build/clkdiv.v build/clkdiv_dbg_b1.v
	$(PYTHON) tools/add_fifo_join_debug.py build/fifo_join.v build/fifo_join_dbg.v

prove: gen
	# Block 1 FIFO: flags by k-induction, the tracked token unbounded, covers.
	$(SBY) -f fifo.sby flags_prove -d build/fifo_flags_prove
	$(SBY) -f fifo_ind.sby prove -d build/fifo_ind_prove
	$(SBY) -f fifo.sby cover_all -d build/fifo_cover_all
	# Block 1 and block 2 divider: the unbounded R10 proof on each netlist, cross-checks, covers.
	$(SBY) -f clkdiv_dbg.sby prove -d build/clkdiv_dbg_prove
	$(SBY) -f clkdiv_dbg.sby prove_b1 -d build/clkdiv_dbg_prove_b1
	$(SBY) -f clkdiv_dbg.sby cover -d build/clkdiv_dbg_cover
	$(SBY) -f clkdiv_gap.sby prove -d build/clkdiv_gap
	$(SBY) -f clkdiv_d1.sby prove -d build/clkdiv_d1
	$(SBY) -f clkdiv.sby bmc_1_255 -d build/clkdiv_bmc_1_255
	$(SBY) -f clkdiv.sby cover_1_0 -d build/clkdiv_cover_1_0
	$(SBY) -f clkdiv.sby cover_1_255 -d build/clkdiv_cover_1_255
	# Block 2 FIFO join: flags, reset state and mid-run reset by k-induction; the tracked
	# token, unbounded, k = 2, on the debug netlist; covers.
	$(SBY) -f fifo_join.sby flags_prove -d build/fj_flags
	$(SBY) -f fifo_join.sby cover_all -d build/fj_cover_all
	$(SBY) -f fifo_join_ind.sby prove -d build/fj_ind

# The decoder: exhaustive Cyclesim test (dune test), then the generated Verilog through
# Verilator on the same table, then the decoder's own kill-checks.
decode: gen
	$(DUNE) test --root . formal/decode
	$(VERILATOR) --cc --exe --build -j 0 -Wno-fatal -Wno-lint -Wno-style \
	  --top-module decode -Mdir build/decode_obj build/decode.v decode/verilator/tb.cpp -o vdecode
	build/decode_obj/vdecode build/decode_expected.txt
	./decode/run_mutants.sh

mutants: gen
	./run_mutants.sh

clean:
	rm -rf build
