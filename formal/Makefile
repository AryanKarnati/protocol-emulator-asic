# Formal proofs (SymbiYosys) and the decoder check, on the Hardcaml-generated Verilog.
#
#   make -C formal            regenerate the Verilog, run every proof and check, run every mutant
#   make -C formal prove      SymbiYosys proofs and covers only
#   make -C formal decode     decoder: Cyclesim and Verilator enumeration, and its mutants
#   make -C formal mutants    all mutant checks (needs the Verilog from `make gen`)
#
# OPAM_EXEC runs dune inside the OCaml environment. Locally, set it to your switch, e.g.
#   make -C formal OPAM_EXEC="$$HOME/.local/bin/opam exec --switch=polyglot --"
# SBY is the sby binary (default: sby on PATH). VERILATOR is the verilator binary.

ROOT := ..
OPAM_EXEC ?= opam exec --
SBY ?= sby
VERILATOR ?= verilator
export SBY

DUNE = cd $(ROOT) && $(OPAM_EXEC) dune

.PHONY: all gen prove decode mutants clean

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

prove: gen
	$(SBY) -f fifo.sby flags_prove -d build/fifo_flags_prove
	$(SBY) -f fifo.sby token_bmc -d build/fifo_token_bmc
	$(SBY) -f fifo.sby cover_all -d build/fifo_cover_all
	$(SBY) -f clkdiv.sby bmc_sym -d build/clkdiv_bmc_sym
	$(SBY) -f clkdiv.sby bmc_1_0 -d build/clkdiv_bmc_1_0
	$(SBY) -f clkdiv.sby bmc_1_255 -d build/clkdiv_bmc_1_255
	$(SBY) -f clkdiv.sby bmc_2_85 -d build/clkdiv_bmc_2_85
	$(SBY) -f clkdiv.sby cover_1_0 -d build/clkdiv_cover_1_0
	$(SBY) -f clkdiv.sby cover_1_255 -d build/clkdiv_cover_1_255
	$(SBY) -f clkdiv_dbg.sby prove -d build/clkdiv_dbg_prove
	$(SBY) -f clkdiv_dbg.sby cover -d build/clkdiv_dbg_cover
	$(SBY) -f fifo_join.sby flags_prove -d build/fj_flags
	$(SBY) -f fifo_join.sby token_bmc -d build/fj_token_bmc
	$(SBY) -f fifo_join.sby cover_all -d build/fj_cover_all

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
