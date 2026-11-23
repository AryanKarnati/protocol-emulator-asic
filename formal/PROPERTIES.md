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

**For owner review.** The sentences below are what the proofs check. They come from `docs/chip.md`
6.1 to 6.6 and 7. Each property is checked on the generated `gen_verilog hostlink` netlist, from
reset, with ports only.

**Provenance and disclosures.**
- The first monitor (`hostlink_harness.v`, the b-form) was written from chip.md only, before
  `hw/hostlink.ml` was read.
- After the properties were written, `hw/hostlink.ml` was read (permitted by the orchestrator) to
  name the internal state the unbounded proofs need. Those proofs use a position-form monitor
  (`hostlink_pos_slice.v`, written by the Sonnet checker from the same chip.md text). Two lemmas
  tie the position-form to the b-form and the closed-form address to the incremental one.
- The b-form monitor's R, F and ADDR latches are guarded by `!big`, so a 2^19 wrap of the bit
  counter cannot re-latch them.
- The reset is modelled as asynchronous (L6), following chip.md 7 and 10.

**Plain status.**

| Property | Status | Depth or method | Run |
| --- | --- | --- | --- |
| RST: while `rst_n` is low, `miso`, `bus_write`, `bus_read`, `bus_commit` are 0 | Proven, unbounded | abc pdr, from reset | `hostlink_slice_rst.sby` |
| MISO (monitor shift register; 0 between frames) | Proven, unbounded | abc pdr | `hostlink_slice_miso.sby` |
| L1: MISO changes only in the cycle after START, RISE or END, and reset clears it | Proven, unbounded | abc pdr | `hostlink_slice_l1.sby` |
| L2: hold rule for a counted rise, under the chip.md 6.6 obligations (H-SCK, H-CS, H-RST) | Proven, unbounded | abc pdr | `hostlink_slice_l2.sby` |
| CTRL: `bus_write`, `bus_read`, `bus_commit` equal the monitor's pulses every cycle, at most one per cycle, a write only in a frame and not in a read frame | Proven, unbounded | abc pdr | `hostlink_slice_ctrl.sby` |
| DATA: `bus_wdata` equals the 32-bit word (31 earlier bits and this bit) at each write pulse | Proven, unbounded | abc pdr | `hostlink_slice_data.sby` |
| ADDR: `bus_addr` (bits [1:0] = 0) equals the incremental address (F = 1: ADDR) at each pulse | Proven, unbounded (F = 0 and F = 1 together) | abc pdr | `hostlink_slice_addr_inc.sby`; F = 1 alone: `hostlink_slice_addr_f1.sby` |
| Lemma A: the closed-form address (ADDR + 4m, F = 0; ADDR, F = 1) equals the incremental address at every pulse | Proven, unbounded | k-induction, depth 4 | `hostlink_lemma_addr.sby` |
| Lemma P: the b-form monitor's pulses equal the position-form monitor's | Proven, unbounded | k-induction, depth 4 | `hostlink_lemma_pos.sby` |
| BMC cross-check of the b-form monitor against the DUT: L1, L2, L4, L6 and pulses | No failure to depth 72 (read side) | bounded BMC | `hostlink.sby bmc` |
| Write side of L3 and L5 (first write word at cycle 114) | No failure to depth 115 (manual, unverified in CI) | bounded BMC | manual only |
| Reachability (covers) | 184 cycles; the second write word is reached at step 178 | cover | `hostlink.sby cover` |
| Negative: L2 without the §6.6 obligations | Fails at step 4, as expected | bounded BMC | `hostlink_miso_uncond.sby` |

Monitor state needed by the unbounded slices: 6-bit position `pos` (0 to 55, wrapping 55 to 24),
word counters `mw` and `mc`, and the latched R, F and ADDR at positions 0, 1 and 23. The address
invariant uses the incremental register `am` (ADDR[15:2] then +4 after each word unless F is set).

**What is not proven, and where it goes.**
- The b-form BMC to 72 checks word 0 only. It does not check the address progression, F, or the
  wrap. Those are checked by ADDR and the lemmas, unbounded.
- The write-side BMC to 115 is the deepest bounded check that ran (it covers the first write word
  at cycle 114). It is a manual run; no CI job runs it, and the run is not reproducible in less than
  about 3.5 hours.
- Deep write-side mutants (`hostlink_deep__*`, 2 of them): no result.
- Block 4 (PLAN block 4: "Formal on the host link, with all proofs running in CI") covers the
  remaining items: running the deep BMC in CI, the deep mutants, and the cover at depth 184 in CI.

**Mutants.**
- Slice mutants (`formal/mutants/hostlink_slice__*.sed`, 11). Each is killed by a named slice
  returning FAIL under abc pdr; `formal/run_slice_mutants.sh` runs them. Kills: A1 (step 5 of
  the address increment) by addr_inc; A2 (F ignored) by addr_f1; A3 (F latched at bit 2) by
  addr_f1; B (MISO end does not zero) by miso; C (commit at bit 31) by ctrl; D1 (write at bit 54)
  by ctrl; D2 (wdata bit 0 dropped) by data; E (shift in a 1) by miso; G (address wrap saturates)
  by addr_inc; H (MISO taken from a different net) by l1; I (reset value of the shift register) by rst.
- Default DUT mutants (`formal/mutants/hostlink__*.sed`, 7): killed by bounded BMC to 72.
- Deep write-side mutants (`formal/mutants/hostlink_deep__*.sed`, 2): no result.

**Modelling choices.** The b-form bit counter is 19 bits and wraps; the wrap cannot change the
properties because the word index enters only mod 2^14 and the phase only mod 32. Pins before
cycle 0 and during reset are treated as idle (chip.md 6.1).

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
