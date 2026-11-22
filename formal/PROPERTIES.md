# Formal properties, blocks 1 and 2

Blocks 1 and 2 are listed separately. Block 1 (the 4 x 32 FIFO and the 16.8 divider) is in
the first two sections. Block 2 (the decoder, `fifo_join`, and the divider with its phase
output) follows.

Sources: DESIGN.md section 17, `docs/gate.md` (block 1), and `docs/engine.md` sections 2 to 5
and rules R10 (block 2). The properties are written from those documents and the `.mli`
port interfaces. Disclosure: in block 1 the divider and FIFO RTL bodies were read before the
properties were written, against the brief. The block 2 properties were written from the
contract and the `.mli` files. The block 2 `.ml` sources were not opened. The generated
Verilog was read to pick the kill-check mutants, which do not affect the properties. The
block 2 harnesses read only the DUT ports. SVA here means the
Verilog `assert` and `cover` statements in the harness files, which SymbiYosys checks.

Regenerate and check everything with `make -C formal` (see `formal/Makefile`).

## FIFO (`fifo_4x32`)

| ID | Sentence | Status | Non-vacuity |
| --- | --- | --- | --- |
| F1 | LEVEL is the number of accepted pushes minus accepted pops. | Proven, k-induction, k = 4 | Covers `full`, `pop_empty`, `push && pop && full`, `push && pop && empty` reached (`cover_all`). Mutants `push_when_full`, `level_no_decrement`, `pop_ignores_empty` killed. |
| F2 | FULL is high exactly when LEVEL is 4, and EMPTY exactly when LEVEL is 0. | Proven, k-induction, k = 4 | Cover `full` reached. Mutant `full_at_three` killed. |
| F3 | PUSH_DROPPED is high exactly when push is high and the FIFO is full; POP_EMPTY is high exactly when pop is high and the FIFO is empty. | Proven, k-induction, k = 4 | Covers `push_dropped`, `pop_empty` reached. Mutants `no_overflow_flag`, `no_underflow_flag` killed. |
| F4 | When LEVEL is not 0, HEAD equals the tracked value exactly when the head word is the tracked token (accepted push number tk). | Bounded: BMC to depth 40 | Cover `acc_pop && npop == tk` reached (`cover_all`). Mutants `head_mux_swapped`, `rd_pointer_skips`, `wr_pointer_skips`, `word0_never_written` killed. |

F4 uses an arbitrary, fixed token: an ordinal tk (anyconst) and a value tv (anyconst). Every
other accepted push carries a value different from tv. So "HEAD equals tv" means "the
token is at the head". This gives order, no loss, and no duplication. Depth 40 is not
an unbounded proof: the ring pointers wrap at depth 4, and 40 operations wrap them
about ten times.

## Clock divider (`clkdiv`)

Dq = 256 x INT + FRAC. INT and FRAC are arbitrary but fixed for a run. Each run uses
one of: INT in 1..2 with any FRAC (symbolic, depth 24), or one fixed divisor (depth
300). See the note on the bounds below the table.

| ID | Sentence | Status | Non-vacuity |
| --- | --- | --- | --- |
| D1 | With INT = 1 and FRAC = 0, TICK is 1 in every cycle. | Bounded: depth 24 (symbolic), depth 300 (fixed 1/0) | Divisor (1,0) runs to depth 300. |
| D2 | After a restart, the first tick comes at cycle INT + 1 or earlier. | Bounded (see note: implied by K1, and vacuous as a direct check) | Cover: first tick at cycle INT with FRAC != 0, reached (`cover_1_255`). |
| D3 | After a restart, every gap between consecutive ticks is INT or INT + 1. | Bounded | Cover: gap INT + 1 with FRAC != 0 reached (`cover_1_255`). |
| D4 | With FRAC = 0, every gap after a restart is exactly INT. | Bounded | Cover: gap with FRAC = 0 reached (`cover_1_0`). |
| D5 | After a restart, any 256 consecutive gaps sum to 256 x INT + FRAC. | Bounded, and derived from K1 (see below) | Cover: 256 ticks since a restart reached (`cover_1_0`, step 258). Only divisor (1,0) reaches 256 ticks inside depth 300. |
| K1 | Auxiliary (stronger than the spec): after a restart, in cycle c, TICK = 1 iff 256 x (c + 1) >= (N + 1) x Dq, where N is the number of ticks since the restart. Equivalently N = floor(256 c / Dq). | Bounded, same depths as D1 to D5 | Restart cover reached (`cover_1_255`). Mutants `tick_inverted`, `no_subtract_on_tick`, `phase_step_128`, `restart_ignored`, `tick_one_cycle_late` killed. |

### Notes on the divider bounds (read these before the review)

- **K1 is stronger than the spec.** Restart sets the phase to zero, so the first tick is
  at cycle ceil(Dq/256) - 1 and the tick schedule is fixed. The gate spec only bounds the
  first tick (D2) and says exact phase is checked later by V1 (DESIGN.md section 17). K1
  pins the phase. It is a proof strategy, and the owner should decide whether this is an
  intended property. D2 to D5 are proven by arithmetic from K1 (for example, the ticks at
  cycles ceil((m+1) Dq/256) - 1 give the 256-gap identity with Dq exactly).
- **D2 as a direct check is vacuous.** Under K1 the first tick always comes at cycle
  INT or earlier, so the antecedent "no tick yet and cycle = INT + 1" never holds. The
  check is kept, since it is still correct, but it proves nothing new. Its real content
  is the closed form.
- **Bounds.** The proof is bounded, not unbounded. Symbolic INT in 1..2 is checked to 24
  cycles. Three fixed divisors (1/0, 1/255, 2/85) are checked to 300 cycles. Within 300
  cycles, divisor (1,255) reaches about 150 ticks and (2,85) about 100, so D5 is fully
  exercised only for (1,0). The k-induction step is not used for the divider: K1 is not
  inductive without the DUT's internal phase, and the harness is kept free of internals.
  Symbolic INT and FRAC at depth 100 or more was too slow with both abc bmc3 and
  boolector (about 6 to 30 s per step and rising), so the fixed-divisor runs were used.
  Covering all 2 x 256 divisors and the full 800-cycle window is not done.
- INT = 0 (meaning 65536) is not checked. FRAC != 0 with INT = 0 is unspecified by the spec.

## Block 2 decoder (`decode`, engine.md section 4)

| ID | Sentence | Status | Non-vacuity |
| --- | --- | --- | --- |
| DEC1 | For every 16-bit word and every valid side-set configuration (count 0 to 5, enable only with count 1 or more), every output of `decode` equals the ISA reference. | Proven by exhaustive enumeration of all 720,896 cases, on the Cyclesim circuit (`dune test`, `formal/decode/`) and on the generated Verilog (Verilator, `formal/decode/verilator/`). | The reference fields are not constant: legal and illegal words, every instruction kind and LCU words all occur, and the kill-checks below show each output is compared. |

Kill-checks on the generated Verilog, run by `formal/decode/run_mutants.sh`: `side_valid_ignores_enable`,
`bit_count_drops_out`, `is_set_ignores_legal`. Each one makes the Verilator run report mismatches.

The enumeration is complete, not a sample: the decoder is combinational, and every input
combination in its contract is tried.

## Block 2 clock divider, unbounded (`clkdiv_dbg`, engine.md R10)

The harness keeps a reference accumulator P_ref, written from R10 alone, with the same inputs.
Each cycle: S = P_ref + 256; tick_ref = (S >= D); P_ref becomes S - D on a tick, else S;
restart and reset set it to 0. D = 256 x INT + FRAC, with INT = 0 meaning 65536.

| ID | Sentence | Status | Non-vacuity |
| --- | --- | --- | --- |
| DIV2 | For every divisor and every restart pattern, in every cycle after reset, `dbg_phase` equals the reference phase and `tick` equals the reference tick. | Proven, unbounded, by k-induction with k = 1. The invariant is phase equality, which is inductive by itself. | Covers: tick, no tick, restart with nonzero phase, INT = 0, and phase above D after the divisor is lowered, all reached (`clkdiv_dbg.sby cover`). Mutants `restart_ignored`, `tick_one_cycle_late`, `phase_step_128` killed. |

### D1 to D5, as properties of the reference

These are the block 1 properties. They are argued here for the reference, and DIV2 transfers
them to the block 2 divider for every divisor. Let Dq = 256 x INT + FRAC, with INT at least 1.
Let P_c be the phase in cycle c after a restart. The invariant 0 <= P_c < Dq holds. It holds
at c = 0 (P = 0), and each cycle keeps it: a tick gives P + 256 - Dq, which is in [0, 256); no
tick gives P + 256 < Dq. Writing N_c for the ticks in cycles 0 to c - 1, P_c = 256 c - Dq N_c, so
N_c = floor(256 c / Dq), and the m-th tick (from 0) is at cycle t_m = ceil((m+1) Dq / 256) - 1.

- **D1** (INT = 1, FRAC = 0): Dq = 256, so P stays 0, S = 256 >= 256 in every cycle, and TICK is
  1 in every cycle. Also true before any restart.
- **D2** (first tick): t_0 = ceil(Dq / 256) - 1, which is INT for FRAC != 0 and INT - 1 for
  FRAC = 0. Both are at most INT + 1.
- **D3** (gaps): t_{m+1} - t_m = ceil((m+2) Dq/256) - ceil((m+1) Dq/256). Consecutive ceilings
  of x and x + Dq/256 differ by floor(Dq/256) or ceil(Dq/256), which are INT and INT + 1.
- **D4** (FRAC = 0): Dq/256 = INT is an integer, so every gap is exactly INT.
- **D5** (256-gap window): t_{m+256} - t_m = ceil((m+257) Dq/256) - ceil((m+1) Dq/256). The
  shift by 256 adds exactly Dq/256 x 256 = Dq, an integer, so the difference is exactly Dq.

Bounded evidence for D1 to D5 on the block 1 divider (`formal/clkdiv.sby`) is kept and still
passes: symbolic INT in 1..2 to depth 24, and fixed divisors 1/0, 1/255 and 2/85 to depth 300.
The 256-tick window is reached only for 1/0 inside depth 300.

## Block 2 FIFO join (`fifo_join`, engine.md sections 2, 3 and 5)

One anyconst chooses the join mode for the run: none, TX joined, or RX joined. Both at once is
outside the contract. Capacities: not joined, TX 4 and RX 4; `join_tx`, TX 8 and RX 0;
`join_rx`, TX 0 and RX 8. Counters: `tx_np`/`tx_nq` count accepted host pushes and SM pops of
the TX FIFO; `rx_np`/`rx_nq` count SM pushes and host pops of RX. A flush sets the pop counter
to the push counter, so a flush empties the FIFO and drops any tracked token in it.

| ID | Sentence | Status | Non-vacuity |
| --- | --- | --- | --- |
| FJ1 | Each LEVEL is the accepted pushes minus the accepted pops since the last flush (F1 analogue). | Proven, k-induction, k = 4, all three modes | Covers: `join_tx`, `join_rx`, no join, `tx_dropped`, `rx_underflow`, both push-and-pop-on-full/empty cases, and a flush with a non-empty FIFO, all reached (`fifo_join.sby cover_all`). |
| FJ2 | FULL is high exactly when LEVEL equals the capacity, and EMPTY exactly when LEVEL is 0 (F2 analogue). A capacity-0 FIFO reads as both full and empty with LEVEL 0. | Proven, k-induction, k = 4 | Capacity-0 case is a branch of the same properties, reached in the join modes. |
| FJ3 | TX_DROPPED is high exactly when a host TX push comes while the TX FIFO is full at the start of the cycle (H1). RX_UNDERFLOW is high exactly when a host RX pop comes while the RX FIFO is empty at the start (H2). | Proven, k-induction, k = 4 | Covers `host_tx_push && tx_full && sm_tx_pop`, `host_rx_pop && rx_empty && sm_rx_push`, `tx_dropped`, `rx_underflow`. Kill-checks `tx_dropped_without_full`, `underflow_masked_by_push`. |
| FJ4 | After a flush, both FIFOs are empty (H6). | Proven, k-induction, k = 4 | Covers `flush && level != 0`. Kill-check `rx_flush_keeps_level` (RX level not cleared by flush). |
| FJ5 | Tracked token, TX (host pushes, SM pops) and RX (SM pushes, host pops): when the FIFO is non-empty, the head equals the token exactly when the head is the token (F1 to F4 analogue). The head is judged at the start of the cycle (H2). | Bounded: BMC to depth 20 (abc bmc3), PASS. Not 1-inductive; no auxiliary invariant was found without reading internals. | Covers `acc_pop && tx_nq == tk` and `acc_rx_pop && rx_nq == tk`, for the same runs. |

Why FJ5 is bounded: the token property needs the ring pointers to be consistent with the
counters, and that is an internal invariant. The harness must not look inside the DUT, so the
induction has no such hypothesis, and the property is not 1-inductive. The ring has 8 entries,
so depth 20 gives at least two full wraps of the pointers, which is where the ring
conditions first repeat. This is a bound, not the reachable-state diameter. The diameter was not
computed.

## Reproduce

```
make -C formal                     # gen, all proofs and covers, all mutants
make -C formal prove               # proofs and covers only
make -C formal mutants             # mutant checks only
```

Mutant files are `formal/mutants/<module>__<name>.sed`. `run_mutants.sh` applies each
one to the generated Verilog and expects at least one task to report "Assert failed".
