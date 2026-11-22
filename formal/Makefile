# Block 1 formal proofs (SymbiYosys) on the Hardcaml-generated Verilog.
#
#   make -C formal            regenerate the Verilog, run every proof, run every mutant
#   make -C formal prove      proofs and covers only
#   make -C formal mutants    mutant checks only (needs the Verilog from `make gen`)
#
# OPAM_EXEC runs dune inside the OCaml environment. Locally, set it to your switch, e.g.
#   make -C formal OPAM_EXEC="$$HOME/.local/bin/opam exec --switch=polyglot --"
# SBY is the sby binary (default: sby on PATH).

ROOT := ..
OPAM_EXEC ?= opam exec --
SBY ?= sby
export SBY

.PHONY: all gen prove mutants clean

all: gen prove mutants

gen:
	mkdir -p build
	cd $(ROOT) && $(OPAM_EXEC) dune build --root . --display=quiet ./formal/gen/gen_formal.exe
	cd $(ROOT) && $(OPAM_EXEC) dune exec --root . --display=quiet ./formal/gen/gen_formal.exe -- fifo_4x32 > $(CURDIR)/build/fifo_4x32.v
	cd $(ROOT) && $(OPAM_EXEC) dune exec --root . --display=quiet ./formal/gen/gen_formal.exe -- clkdiv > $(CURDIR)/build/clkdiv.v

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

mutants: gen
	./run_mutants.sh

clean:
	rm -rf build
