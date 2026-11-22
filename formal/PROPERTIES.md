# Formal properties, blocks 1 and 2

Sources: DESIGN.md section 17, `docs/gate.md` (block 1), and `docs/engine.md` sections 2 to 5,
and rules R10 and H1 to H9 (block 2). The properties are written from those documents and the
`.mli` port interfaces. The properties and harnesses were written by the proof lane, except
where a row says the checker wrote the harness. The checker's harnesses and mutants were
adapted into this directory and are credited on each row.

Disclosure, for review:

- **Block 1.** The divider and FIFO RTL bodies were read before the first properties were
  written, against the brief. The block 1 bounded harnesses are kept as extra evidence.
- **Block 2.** The `.ml` sources were not opened. The generated Verilog was read to choose
  kill-check mutants. The mutants do not affect the properties.
- **R10 is not an independent source.** `docs/engine.md` R10 was written after the block 1 RTL
  was seen, and it describes that same algorithm. So the reference used by the divider proofs
  is not AI-independent. It matches the spec text and the datasheet, but the owner should weigh
  it as a project reference, not an outside one.

Two kinds of harness are used, and each row says which:

- **Debug netlist.** The proof reads storage words, pointers or phase, which are not ports of
  the module. A script adds output ports to the generated Verilog (`tools/add_*_debug.py`). The
  logic is unchanged. This is a trade-off: the proof is not "ports only". The ports-only checks
  (flags, reset state, outputs) are on the base netlist.
- **Ports only.** The harness reads just the module's ports.

Regenerate and check everything with `make -C formal all`. The end-to-end time is in the
"Runtime" section.

## Block 1 FIFO (`fifo_4x32`)

| ID | Sentence | Status | How it is checked |
| --- | --- | --- | --- |
| F1 | LEVEL is the number of accepted pushes minus accepted pops since the last reset. | Proven, unbounded, k-induction, k = 4 | Ports only (`fifo_harness.v`, `fifo.sby flags_prove`). Covers: `full`, `push_dropped`, `pop_empty`, push-and-pop on full and on empty (`cover_all`). Mutants `push_when_full`, `level_no_decrement`, `pop_ignores_empty`, `x_pop_at_empty_with_push`, `x_push_at_full_with_pop` killed. |
| F2 | FULL is high exactly when LEVEL is 4, and EMPTY exactly when LEVEL is 0. | Proven, unbounded, k = 4 | Ports only. Mutant `full_at_three` killed. |
| F3 | PUSH_DROPPED is high exactly when a push comes while the FIFO is full, and POP_EMPTY is high exactly when a pop comes while it is empty. | Proven, unbounded, k = 4 | Ports only. Mutants `no_overflow_flag`, `no_underflow_flag` killed. |
| R1 | While rst_n is low, LEVEL is 0, EMPTY is 1 and FULL is 0. This holds in the first step and in a reset in the middle of a run. | Proven, unbounded, k = 4 | Ports only, `rst_req` is a free input. Cover: reset with LEVEL nonzero reached. |
| F4 | When the FIFO is not empty, HEAD equals the tracked value tv exactly when the head is the token (ordinal tk). So the token leaves in order, is not lost, and is not duplicated. | Proven, unbounded, k-induction, k = 2 | Debug netlist (`tools/add_fifo_debug.py`, `fifo_ind_harness.v`, written by the checker, adapted). Auxiliary invariants: pointers equal the push and pop counts mod 4, LEVEL is their difference, and each queued slot holds tv exactly when its ordinal is tk. Mutants `head_mux_swapped`, `rd_pointer_skips`, `wr_pointer_skips`, `word0_never_written`, `x_head_slot3_reads_2`, `x_slot3_data_corrupt` killed. |

The tracked token is an arbitrary fixed ordinal tk and value tv (anyconst). Every other accepted
push carries a value different from tv.

## Block 1 clock divider (`clkdiv`)

The reference is engine.md R10 (see the note in Section "K1").

| ID | Sentence | Status | How it is checked |
| --- | --- | --- | --- |
| R10 | For every INT, every FRAC and every history of INT, FRAC, restart and reset, the phase and TICK equal the reference accumulator in every cycle. In reset, the phase is 0 and TICK is (256 >= D). | Proven, unbounded, k-induction, k = 1 | Harness `clkdiv_dbg_harness.v`, on the debug netlist of the block 1 divider (`tools/add_clkdiv_debug.py`, task `prove_b1`). The invariant is phase equality. Mutants `tick_inverted`, `no_subtract_on_tick`, `phase_step_128`, `restart_ignored`, `tick_one_cycle_late`, `x_restart_phase1`, `x_phase_24bit`, `x_int0_is_2p23`, `x_int_hi_ignored`, `x_drop_remainder_frac_lo` killed. |
| D1 | With INT = 1 and FRAC = 0, TICK is 1 in every cycle. | Proven: by arithmetic from R10 (phase stays 0). Also proven directly for any history, by k-induction, k = 2 (checker's `clkdiv_d1_harness.v`, phase below 2^24) | See rows R10 and "Checker's cross-checks". |
| D2 | After a restart, the first tick comes at cycle INT + 1 or earlier. | Proven, unbounded, for all fixed INT and FRAC including INT = 0 (checker's `clkdiv_gap_harness.v`, k = 3) | Sanity check only. Under R10 the first tick is at cycle ceil(Dq/256) - 1, which is INT or less, so the direct check's antecedent (no tick yet, cycle INT + 1) never holds. It is kept as a documented sanity check, not as evidence. |
| D3 | After a restart, every gap between consecutive ticks is INT or INT + 1. | Proven, unbounded, for all fixed INT and FRAC (`clkdiv_gap_harness.v`, k = 3) | Ghost counters g and B, with A == B + 256 g. Cover: gap INT + 1 with FRAC != 0 reached (`clkdiv.sby cover_1_255`). |
| D4 | With FRAC = 0, every gap after a restart is exactly INT. | Proven, unbounded, for all fixed INT (`clkdiv_gap_harness.v`, k = 3) | Cover: gap with FRAC = 0 reached (`cover_1_0`). |
| D5 | After a restart, any 256 consecutive gaps sum to 256 x INT + FRAC. | Argued, not checked. See the note below. | Arithmetic from R10. The harnesses have no direct check of the 256-gap sum. A cover shows 256 ticks are reached (`cover_1_0`, step 258), so the window is not vacuous. |

**D5 argument.** Let Dq = 256 INT + FRAC. R10 gives 0 <= P < Dq in every cycle, so in cycle c the
number of ticks so far is N_c = floor(256 c / Dq). Then N_{c + Dq} = N_c + 256, because
256 (c + Dq) / Dq = 256 c / Dq + 256. So any Dq consecutive cycles contain exactly 256 ticks, and
the gap sum over any 256 consecutive gaps is Dq. This is a mathematical argument over the
unbounded R10 proof, and it is not checked by a harness.

**K1 (the closed form).** K1 is the statement that, after a restart, N_c = floor(256 c / Dq) and
TICK = (256 (c + 1) >= (N + 1) Dq). It is exactly R10 (engine.md R10: "This applies datasheet
section 3.5.5 exactly", with D = 256 INT + FRAC, S = P + 256, tick = (S >= D), P = S - D on a
tick). So K1 is not a strategy choice. The spec pins this schedule. The gap properties D2 to D4
are its consequences. K1 is written after seeing the RTL, and it is not AI-independent (see the
disclosure above). The bounded checks in `clkdiv_harness.v` (formal/clkdiv.sby) are kept as
extra evidence only: symbolic INT 1..2 is not run any more, and the fixed divisor 1/255 is
checked to depth 300.

## Block 2 decoder (`decode`, engine.md section 4)

| ID | Sentence | Status | How it is checked |
| --- | --- | --- | --- |
| DEC1 | For every 16-bit word and every valid side-set configuration (count 0 to 5, enable only with count 1 or more), every output of `decode` equals the ISA reference. | Proven, exhaustive: all 720,896 cases | `dune test formal/decode` on the Cyclesim circuit, and Verilator on the generated Verilog (`decode/verilator/tb.cpp`). Mutants `side_valid_ignores_enable`, `bit_count_drops_out`, `is_set_ignores_legal` killed. |

The enumeration is complete, not a sample: the decoder is combinational, and every input in its
contract is tried.

## Block 2 divider with phase output (`clkdiv_dbg`, engine.md R10)

| ID | Sentence | Status | How it is checked |
| --- | --- | --- | --- |
| DIV2 | For every divisor, every change of divisor in the middle of a run, every restart pattern and every reset in the middle of a run, `dbg_phase` equals the R10 reference and TICK equals the reference tick; in reset, the phase is 0 and TICK is (256 >= D). | Proven, unbounded, k = 1 | `clkdiv_dbg_harness.v`, on the generated netlist (`clkdiv_dbg.sby prove`). Same invariant as R10 above. Mutants `restart_ignored`, `tick_one_cycle_late`, `phase_step_128` (block 2 names) killed. |

D1 to D5 for block 2 follow from DIV2 in the same way as for block 1.

## Block 2 FIFO join (`fifo_join`, engine.md sections 2, 3 and 5)

One anyconst fixes the join mode for the run: none, TX joined, or RX joined. Both joined is
outside the contract. Capacities: not joined, TX 4 and RX 4; joined TX, TX 8 and RX 0; joined RX,
TX 0 and RX 8.

| ID | Sentence | Status | How it is checked |
| --- | --- | --- | --- |
| FJ1 | LEVEL is the accepted pushes minus the accepted pops since the last flush (F1 analogue). | Proven, unbounded, k-induction, k = 4, all three modes | Ports only (`fifo_join_harness.v`, `fifo_join.sby flags_prove`). |
| FJ2 | FULL is high exactly when LEVEL equals the capacity, and EMPTY exactly when LEVEL is 0 (F2 analogue). A capacity-0 FIFO reads as full and empty with LEVEL 0. | Proven, unbounded, k = 4 | Ports only. |
| FJ3 | TX_DROPPED is high exactly when a host TX push comes while the TX FIFO is full at the start of the cycle (H1). RX_UNDERFLOW is high exactly when a host RX pop comes while the RX FIFO is empty at the start (H2). | Proven, unbounded, k = 4 | Ports only. Mutants `tx_dropped_without_full`, `underflow_masked_by_push` killed. |
| FJ4 | After a flush, both FIFOs are empty (H6). | Proven, unbounded, k = 4 | Ports only. Mutant `rx_flush_keeps_level` killed. |
| FJ5 | When a FIFO is non-empty, its head equals the tracked value tv exactly when the head is the token (F1 to F4 analogue, TX and RX). | Bounded: BMC to depth 20, abc bmc3, PASS. The unbounded attempt is OPEN. | Ports only, with `-DTOKEN`. The unbounded attempt (`fifo_join_ind_harness.v`, debug netlist) is not part of `make -C formal`: every join mode fails k-induction at the slot check, and the counterexample has an arbitrary queued word equal to tv. The strengthening that rules this out has not been found. Kill-checks: `tx_wrap_to_slot_one`, `rx_head_reads_other_half`, `tx_head_index_one_swapped` killed by a boolector run at depth 8 (`token_kill`), which writes a witness. |

Why FJ5 is bounded: the induction step needs an invariant about the storage contents, and that
invariant is not found. The bound is depth 20, which gives at least two full wraps of the 8-entry
ring. This is not the reachable-state diameter, which was not computed.

## Checker's cross-checks (credited)

Written by the checker, adapted into this directory, and run as part of `make -C formal`:

- `fifo_ind_harness.v`, `fifo_ind.sby` (F4), with the debug netlist.
- `clkdiv_gap_harness.v`, `clkdiv_gap.sby` (D2, D3, D4).
- `clkdiv_d1_harness.v`, `clkdiv_d1.sby` (D1).
- Mutants in `formal/mutants/`: `fifo__x_*` (4), `clkdiv__x_*` (5).

## Reset

The reset state is checked for the block 1 FIFO (R1) and the divider (R10). Block 2 FIFO join
checks run from the first step after reset only. Reset state and mid-run reset are not yet
checked for `fifo_join`.

## Runtime

See the table in the final report of the run. The timed run writes `formal/build/times.log`.

## Reproduce

```
make -C formal all                 # gen, all proofs and covers, decode, all mutants
make -C formal prove               # proofs and covers only
make -C formal decode              # decoder: Cyclesim and Verilator, and its mutants
make -C formal mutants             # mutant checks only
```

Mutant files are `formal/mutants/<family>__<name>.sed`. `run_mutants.sh` applies each one to its
generated netlist and expects a task to report "Assert failed". A sed script that does not change
the source is a bad mutant and fails the run.
