# Formal properties, blocks 1 and 2

Sources: DESIGN.md section 17, `docs/gate.md` (block 1), and `docs/engine.md` sections 2 to 5,
and rules R10 and H1 to H9 (block 2). The properties are written from those documents and the
`.mli` port interfaces. The proof lane wrote the properties and most harnesses. Where a row
says the checker wrote the harness, the checker's file was adapted into this directory, with
its header noting that. The checker's mutants are in `formal/mutants/`.

## Disclosure

- **Block 1.** The divider and FIFO RTL bodies were read before the first properties were
  written, against the brief. The block 1 bounded harnesses are kept as extra evidence.
- **Block 2.** The `.ml` sources were not opened. The generated Verilog was read to choose
  kill-check mutants. The mutants do not affect the properties.
- **R10 is not an independent source.** `docs/engine.md` R10 was written after the block 1 RTL
  was seen, and it describes that same algorithm. The divider reference is therefore not
  AI-independent. It matches the spec text and the datasheet, but the owner should weigh it as a
  project reference, not an outside one.
- **Decoder reference.** `Decode_ref` (`formal/decode/decode_ref.ml`) is project code, written
  for this proof, built on `Polyglot_isa`. `Polyglot_isa` is itself checked against the official
  pioasm, not against an outside reference. So the decoder reference is project code over a
  project library, checked at the bottom by pioasm.

## How the harnesses see the design

- **Ports only.** The harness reads just the module's ports.
- **Debug netlist.** Some proofs read storage words, pointers or phase, which are not ports. A
  script adds output ports to the generated Verilog (`tools/add_*_debug.py`). The logic is
  unchanged. This is a trade-off: those proofs are not "ports only". Each row says which kind.

Regenerate and check everything with `make -C formal all`. The timing is in the Runtime section.

## Block 1 FIFO (`fifo_4x32`)

| ID | Sentence | Status | How it is checked |
| --- | --- | --- | --- |
| F1 | LEVEL is the number of accepted pushes minus accepted pops since the last reset. | Proven, unbounded, k-induction, k = 4 | Ports only (`fifo_harness.v`, `fifo.sby flags_prove`). Covers: `full`, `push_dropped`, `pop_empty`, push-and-pop on full and on empty (`cover_all`). Mutants `push_when_full`, `level_no_decrement`, `pop_ignores_empty`, `x_pop_at_empty_with_push`, `x_push_at_full_with_pop` killed by `flags_prove`. |
| F2 | FULL is high exactly when LEVEL is 4, and EMPTY exactly when LEVEL is 0. | Proven, unbounded, k = 4 | Ports only. Mutant `full_at_three` killed by `flags_prove`. |
| F3 | PUSH_DROPPED is high exactly when a push comes while the FIFO is full, and POP_EMPTY is high exactly when a pop comes while it is empty. | Proven, unbounded, k = 4 | Ports only. Mutants `no_overflow_flag`, `no_underflow_flag` killed by `flags_prove`. |
| R1 | While rst_n is low, LEVEL is 0, EMPTY is 1 and FULL is 0. This holds in the first step and in a reset in the middle of a run. | Proven, unbounded, k = 4 | Ports only, with `rst_req` a free input. Cover: reset with words in the FIFO reached. |
| F4 | When the FIFO is not empty, HEAD equals the tracked value tv exactly when the head is the token (ordinal tk). So the token leaves in order, is not lost, and is not duplicated. | Proven, unbounded, k-induction, k = 2 | Debug netlist (`tools/add_fifo_debug.py`, `fifo_ind_harness.v`, written by the checker, adapted). Auxiliary invariants: pointers equal the push and pop counts mod 4, LEVEL is their difference, and each queued slot holds tv exactly when its ordinal is tk. Mutants `head_mux_swapped`, `rd_pointer_skips`, `wr_pointer_skips`, `word0_never_written`, `x_head_slot3_reads_2`, `x_slot3_data_corrupt` killed by the token proof. |

The tracked token is an arbitrary fixed ordinal tk and value tv (anyconst). Every other accepted
push carries a value different from tv.

## Block 1 clock divider (`clkdiv`)

The reference is engine.md R10 (see K1 below).

| ID | Sentence | Status | How it is checked |
| --- | --- | --- | --- |
| R10 | For every INT, every FRAC and every history of INT, FRAC, restart and reset, the phase and TICK equal the reference accumulator in every cycle. In reset, the phase is 0 and TICK is (256 >= D). | Proven, unbounded, k-induction, k = 1 | Harness `clkdiv_dbg_harness.v`, run on the debug form of the block 1 divider (`tools/add_clkdiv_debug.py`, task `prove_b1`) and on the block 2 netlist (`prove`). The invariant is phase equality. Mutants `tick_inverted`, `no_subtract_on_tick`, `phase_step_128`, `restart_ignored`, `tick_one_cycle_late`, `x_restart_phase1`, `x_phase_24bit`, `x_int0_is_2p23`, `x_int_hi_ignored`, `x_drop_remainder_frac_lo` killed by `prove_b1`. |
| D1 | With INT = 1 and FRAC = 0, TICK is 1 in every cycle. | Checked on the block 2 netlist (checker's `clkdiv_gap` and `clkdiv_d1`, unbounded). For block 1 it follows from the R10 equality. | Checker's `clkdiv_d1_harness.v` (k = 2, any history, phase below 2^24). |
| D2 | After a restart, the first tick comes at cycle INT + 1 or earlier. | Checked on the block 2 netlist, unbounded, for all fixed INT and FRAC including INT = 0 (checker's `clkdiv_gap_harness.v`, k = 3). For block 1 it follows from the R10 equality. | Sanity check only. Under R10 the first tick is at cycle ceil(Dq/256) - 1, which is INT or less, so the direct check's antecedent (no tick yet, cycle INT + 1) never holds. |
| D3 | After a restart, every gap between consecutive ticks is INT or INT + 1. | Checked on the block 2 netlist, unbounded, for all fixed INT and FRAC (`clkdiv_gap`, k = 3). For block 1, from the R10 equality. | Ghost counters g and B, with A == B + 256 g. Cover: gap INT + 1 with FRAC != 0 reached (`cover_1_255`). |
| D4 | With FRAC = 0, every gap after a restart is exactly INT. | Checked on the block 2 netlist, unbounded, for all fixed INT (`clkdiv_gap`, k = 3). For block 1, from the R10 equality. | Cover: gap with FRAC = 0 reached (`cover_1_0`). |
| D5 | After a restart, any 256 consecutive gaps sum to 256 x INT + FRAC. | Argued, plus bounded direct checks (manual only, not in CI). | Argument below. Bounded direct check (`clkdiv_d5.sby`, run by `make -C formal d5_slow`): divisor 1/0 to depth 300, PASS (abc bmc3, about 594 s); divisor 1/255 to depth 540 (about 23 minutes, 1.2 GB), which was not completed in the last run, so it has no result yet. Bounded, not unbounded. |

**D5 argument.** Let Dq = 256 INT + FRAC. R10 gives 0 <= P < Dq in every cycle, so in cycle c the
number of ticks so far is N_c = floor(256 c / Dq). Then N_{c + Dq} = N_c + 256, because
256 (c + Dq) / Dq = 256 c / Dq + 256. So any Dq consecutive cycles contain exactly 256 ticks, and
the gap sum over any 256 consecutive gaps is Dq. The argument is sound, and the unbounded form is
not checked: an attempt at a ghost-counter induction did not close, because of a variable multiply.

**Why the D5 bounded checks are manual only.** For divisor 1/0, D1 (TICK is 1 in every cycle,
unbounded) already implies that 256 gaps sum to 256, so the 1/0 bounded run adds almost nothing,
and it costs about 594 s in CI. The 1/255 run costs about 23 minutes and 1.2 GB. Both are kept
for `make -C formal d5_slow` as evidence for the fractional case, and neither is part of
`make -C formal prove` or the CI jobs.

**K1 (the closed form).** K1 is the statement that, after a restart, N_c = floor(256 c / Dq) and
TICK = (256 (c + 1) >= (N + 1) Dq). It is exactly R10 (engine.md R10: "This applies datasheet
section 3.5.5 exactly", with D = 256 INT + FRAC, S = P + 256, tick = (S >= D), P = S - D on a
tick). So K1 is not a strategy choice. The spec pins this schedule. The gap properties D2 to D4
are its consequences. K1 is written after seeing the RTL, and it is not AI-independent (see the
disclosure above). The bounded checks in `clkdiv_harness.v` (`clkdiv.sby`) are kept as extra
evidence only: the fixed divisor 1/255 is checked to depth 300.

## Block 2 decoder (`decode`, engine.md section 4)

| ID | Sentence | Status | How it is checked |
| --- | --- | --- | --- |
| DEC1 | For every 16-bit word and every valid side-set configuration (count 0 to 5, enable only with count 1 or more), every output of `decode` equals the ISA reference. | Proven, exhaustive: all 720,896 cases | `dune test formal/decode` on the Cyclesim circuit, and Verilator on the generated Verilog (`decode/verilator/tb.cpp`). The reference is `Decode_ref`, project code over `Polyglot_isa` (see the disclosure). Mutants `side_valid_ignores_enable`, `bit_count_drops_out`, `is_set_ignores_legal` killed by the Verilator run. |

The enumeration is complete, not a sample: the decoder is combinational, and every input in its
contract is tried.

## Block 2 divider with phase output (`clkdiv_dbg`, engine.md R10)

| ID | Sentence | Status | How it is checked |
| --- | --- | --- | --- |
| DIV2 | For every divisor, every change of divisor in the middle of a run, every restart pattern and every reset in the middle of a run, `dbg_phase` equals the R10 reference and TICK equals the reference tick; in reset, the phase is 0 and TICK is (256 >= D). | Proven, unbounded, k = 1 | `clkdiv_dbg_harness.v` on the generated netlist (`clkdiv_dbg.sby prove`). Same invariant as R10. Mutants `restart_ignored`, `tick_one_cycle_late`, `phase_step_128` (block 2 names) killed by `prove`. |

D1 to D5 for block 2 are the rows above, checked on this netlist.

## Block 2 FIFO join (`fifo_join`, engine.md sections 2, 3 and 5)

One anyconst fixes the join mode for the run: none, TX joined, or RX joined. Both joined is
outside the contract. Capacities: not joined, TX 4 and RX 4; joined TX, TX 8 and RX 0; joined RX,
TX 0 and RX 8.

| ID | Sentence | Status | How it is checked |
| --- | --- | --- | --- |
| FJ1 | LEVEL is the accepted pushes minus the accepted pops since the last flush (F1 analogue). | Proven, unbounded, k-induction, k = 4, all three modes | Ports only (`fifo_join_harness.v`, `fifo_join.sby flags_prove`). The reset-state harness is the checker's (`fifo_join_rst_harness.v`, adapted and renamed). |
| FJ2 | FULL is high exactly when LEVEL equals the capacity, and EMPTY exactly when LEVEL is 0. A capacity-0 FIFO reads as full and empty with LEVEL 0. | Proven, unbounded, k = 4 | Ports only. |
| FJ3 | TX_DROPPED is high exactly when a host TX push comes while the TX FIFO is full at the start of the cycle (H1). RX_UNDERFLOW is high exactly when a host RX pop comes while the RX FIFO is empty at the start (H2). | Proven, unbounded, k = 4 | Ports only. Mutants `tx_dropped_without_full` and `underflow_masked_by_push` are killed by `flags_prove`, which is this row's check, not FJ5. |
| FJ4 | After a flush, both FIFOs are empty (H6). | Proven, unbounded, k = 4 | Ports only. Mutant `rx_flush_keeps_level` killed by `flags_prove`. |
| R1 (join) | While rst_n is low, both FIFOs read empty with LEVEL 0. Holds in the first step and after a reset in the middle of a run. | Proven, unbounded, k = 4 | `fifo_join_harness.v`, with `rst_req` a free input. |
| FJ5 | When a FIFO is non-empty, its head equals the tracked value tv exactly when the head is the token (F1 to F4 analogue, TX and RX). | Proven, unbounded, k-induction, k = 2 | Debug netlist (`tools/add_fifo_join_debug.py`). Harness `fifo_join_ind_harness.v`, written by the checker, adapted into this directory. The two count invariants it needs are `tx_level <= cap_tx` (and RX), and the exact 8-bit difference `{4'b0, level} == np - nq`, not only the mod-16 form. Kill-checks: `tx_wrap_to_slot_one`, `rx_head_reads_other_half`, `tx_head_index_one_swapped`, killed by a boolector run at depth 8 (`token_kill`), which writes a witness. |

## Checker's cross-checks (credited)

Written by the checker, adapted into this directory, and run as part of `make -C formal all`:

- `fifo_ind_harness.v`, `fifo_ind.sby` (F4), with the debug netlist.
- `fifo_join_ind_harness.v`, `fifo_join_ind.sby` (FJ5), with the join debug netlist.
- `fifo_join_harness.v` (FJ1 to FJ4, R1 for the join), with the reset-state checks.
- `clkdiv_gap_harness.v`, `clkdiv_gap.sby` (D2, D3, D4).
- `clkdiv_d1_harness.v`, `clkdiv_d1.sby` (D1).
- Mutants in `formal/mutants/`: `fifo__x_*` (4), `clkdiv__x_*` (5).

## Reset

Checked:

- block 1 FIFO: R1, the reset state, including a reset in the middle of a run (`fifo_harness.v`).
- block 1 and block 2 divider: the reset phase and TICK in reset (R10 and DIV2).
- block 2 FIFO join: R1, the reset state, including a reset in the middle of a run
  (`fifo_join_harness.v`).

Not checked: the reset state of the block 2 top-level and of the `pio_block` integration. Those
are block 3 items.

## Runtime

See the final report for the wall times of the clean run, per task, from `formal/build/times.log`.

## Host link (block 3, `hostlink`, chip.md sections 6 and 7)

**For owner review.** These are the English sentences the proofs check. The sentences come from
`docs/chip.md` 6.1 to 6.6 and 7. The harness (`hostlink_harness.v`) holds a reference monitor
that follows those sections cycle by cycle. The monitor is written from the contract only, and
`hw/hostlink.ml` was not read to write it. The DUT is `gen_verilog hostlink` (the RTL lane's
module, branch 7e30824).

Status on the real module, from the runs in this session:

| Check | Depth / result |
| --- | --- |
| `bmc` (`hostlink.sby`) | 72 cycles, PASS. Covers the header, the first read word and its commit. |
| `cover` (`hostlink.sby`) | 184 cycles, PASS. Reaches the first and second write words and the read commit. |
| `prove` (k-induction, k up to 8) | UNKNOWN. The step case fails on the bus-pulse equality (line 192). See the disclosure below. |
| `hostlink_miso_uncond.sby` (L2 without the host obligations) | FAIL at step 4, as expected. |
| Mutants (`formal/mutants/hostlink__*`, 7) | 7 of 7 killed by `bmc` (72 cycles). Kills: a missing commit, a commit one cycle late, a read one cycle early, MISO from bit 30, inverted MOSI, CS_N stuck high, and a wrong STATUS bit. |
| Write-side mutants (`formal/mutants/hostlink_deep__*`, 2) | Not run to a result. `bmc` to 72 cannot reach the first write word (cycle 114). The deep runs were stopped (see the deep BMC row below). Manual target: `make -C formal hostlink_deep`. |
| `bmc_deep` (184 cycles, real module) | Stopped at step 115 after about 3.5 hours. No assertion failed through step 115, which includes the first write word (cycle 114). Not completed to 184, so no result is claimed for cycles 116 to 184. Manual only: `cd formal && sby -f hostlink.sby bmc_deep`. Not in CI. |

### Block 3 status (accepted by the orchestrator)

Plain statement of what is established for the host link at the end of block 3.

- **Proven, unbounded:** none of L1 to L6. The k-induction proof and the IC3/PDR run (`abc pdr`) did not close.
- **Bounded, no failure, real `gen_verilog hostlink`:**
  - L1 (exact MISO rule), L2 (hold rule under the §6.6 assumptions), L4 (MISO equals the model), L6 (reset): BMC to 72 cycles.
  - L3 (bus pulses, address, data) and L5 (one pulse per cycle, no partial write), read side: BMC to 72 cycles.
  - L3 and L5, write side: BMC to 115 cycles, no assertion failure. This covers the first write word (bit 55, cycle 114). Cycles 116 and later are not checked.
  - Cover (reachability only): 184 cycles, reaches the first and second write words and the first read commit.
- **Negative check, expected to fail:** L2 without the §6.6 assumptions fails at step 4.
- **Mutants:** 7 of 7 default host-link mutants killed by BMC to 72. 2 deep write-side mutants: no result (the runs were stopped).
- **Not done in block 3:** the unbounded write-side proof, and the debug-netlist invariants that would close it.
- **Planned for block 4:** "Formal on the host link, with all proofs running in CI" (PLAN block 4). That work covers the unbounded proofs for L3 and L5 through debug-netlist invariants with the address mapping, the deep mutant runs, and making the proofs run in CI.

| ID | Sentence | How it is checked |
| --- | --- | --- |
| L1 | MISO changes only in the cycle right after a START, RISE or END, and reset clears it. | Unconditional. `bmc` to 72 on the real module. Unbounded: not closed. |
| L2 | For a counted rise of SCK in pin cycle c, MISO is unchanged in cycles c, c+1 and c+2, provided the host follows chip.md 6.6 around the rise: SCK low in cycle c-2 (H-SCK), CS_N does not change in cycles c-2 or c-1 (H-CS), and rst_n is high in cycles c to c+2 (H-RST). | `bmc` to 72 with the three host conditions as explicit antecedents. The same property without them (`hostlink_miso_uncond.sby`) fails, which shows the obligations are needed. |
| L3 | Every cycle, the bus pulses `bus_write`, `bus_read` and `bus_commit` equal the monitor's, which follows chip.md 6.4 bit by bit. The addresses `bus_addr` (with bits [1:0] = 0) and the data `bus_wdata` equal the monitor's values in the cycles that have a pulse. | `bmc` to 72 covers the read pulse and commit. Write pulses start at cycle 114, so the write-side part is checked only by `bmc_deep` (184 cycles, nightly and mutant runs). |
| L4 | Every cycle, `miso` equals the monitor's shift register (chip.md 6.5), and it is 0 between frames. | `bmc` to 72. |
| L5 | At most one bus pulse is raised per cycle, and a write pulse only occurs inside a frame with its word complete. | `bmc` to 72 for the one-pulse part. The write part needs `bmc_deep`. |
| L6 | While `rst_n` is low, `miso` is 0 and no bus pulse is raised. | `bmc` to 72. chip.md 7 states this (C2). |

****Engine attempts on the unbounded proof and the deep BMC (this pass).** `hostlink_pdr.sby` runs `abc pdr` on the `prove` task with no helper invariants. It did not converge: after about 3 minutes it had reached 400 frames and was still adding frames, so I stopped it. `hostlink_yices.sby` runs the 184-cycle BMC with `smtbmc yices`: it reached step 45 with no failure, and then the steps slowed sharply, so I stopped it. The boolector deep run reached step 115 with no failure before it was stopped. Deepest write-side result so far: no assertion failed through step 115, which covers the first write word. Neither engine closed the L3 or L5 write-side properties.

The cherry-pick of `eaa73fd` (the early-failure diagnostics in `flow/metrics_notice.py`) is on this branch as `a101a23`.

**Helper-invariant attempt (not closed).** To close the unbounded proof I read `hw/hostlink.ml` after the properties were written (disclosed, as the coordinator allowed). The internal state that the invariants would tie to the monitor is: the pin flops `sck2`, `sck3`, `cs2`, `cs3`, `mosi2` (and their first stages); `cnt` (5 bit, the phase after bit 24); `in_body`; the command bits `r_q` and `f_q`; `rxsr` (31 bits); `addr` (16 bits, which loads ADDR at the header end and steps by 4 after each word unless F is set); and `sr` (32 bits). The monitor keeps `ADDR+4m` in a different form, so the address invariant needs a mapping from the stepping register to the monitor's word index. The invariants were not implemented: that needs a debug netlist to expose these nets. The bounded results above are the result.

**cs_stuck_high (step 3).** The first run ended with `DONE (ERROR)`. The log had `Assert failed` at step 4, `Status: FAILED`, then "Engine terminated without status". A rerun with the same boolector engine gave `Status returned by engine: FAIL` and `DONE (FAIL)`, and a z3 run also gave a clean FAIL. So the ERROR did not reproduce; the cause looks like an intermittent sby/boolector status issue, and its root cause was not found. The runner now counts a kill only when the log has both `Assert failed` and `DONE (FAIL`. If boolector ends with "terminated without status", it retries with z3.

Disclosure on the unbounded proof.** The k-induction step starts from an arbitrary state. The
monitor and the DUT are then unrelated, so the bus-pulse equality fails in the step case. This is
a limit of the method, not a counterexample from reset: the BMC from reset passes. To close the
proof, the invariants would have to tie the monitor registers to the DUT registers, which needs a
debug netlist (as blocks 1 and 2 did). Not done.

**Modelling choices.** The bit counter is 19 bits and wraps. The wrap cannot change any property:
the word index enters only as m mod 2^14, and the phase only as b mod 32 (see the header of
`hostlink_harness.v`). Pins before cycle 0, and pins during reset, are treated as idle (chip.md
6.1). The reset is modelled as asynchronous (L6), following chip.md 10 and 7. If the RTL used a
synchronous reset, L6 would fail, and the owner would have to decide which reading of chip.md 7
holds.

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
