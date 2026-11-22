# Block 1 formal properties

Scope: the 4 x 32 FIFO (`hw/fifo.ml`) and the 16.8 clock divider (`hw/clkdiv.ml`), as
Hardcaml-generated Verilog (`formal/build/`). Sources: DESIGN.md section 17 and
`docs/gate.md`. The properties are written from those documents and the `.mli` port
interfaces, not from the RTL bodies. SVA here means the Verilog `assert` and `cover`
statements in `fifo_harness.v` and `clkdiv_harness.v`, which SymbiYosys checks.

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

## Reproduce

```
make -C formal                     # gen, all proofs and covers, all mutants
make -C formal prove               # proofs and covers only
make -C formal mutants             # mutant checks only
```

Mutant files are `formal/mutants/<module>__<name>.sed`. `run_mutants.sh` applies each
one to the generated Verilog and expects at least one task to report "Assert failed".
