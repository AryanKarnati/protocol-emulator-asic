# silicon-ref/v1: capture programs for the V1 items

DESIGN.md §17 V1, `sw/pgsim/README.md` ("V1: what the silicon capture must settle") and
`docs/engine.md` (contract, rule R4 for PULL under autopull). Each item has a program in
`v1_items.pio` (one `.program` per item, assembled by the official pioasm 2.3.1 into
`v1_items.pioasm.json`), a capture config `v1_<item>.config.json` (the arguments of `capture.run`),
and the outcome table below.

Assemble: `pioasm -o json v1_items.pio v1_items.pioasm.json`.
Mock run of all configs: `python3 silicon-ref/test_capture_mock.py` (`test_v1_*`) and the batch dry
run (`python3 silicon-ref/batch_capture.py --dry-run --groups v1`).

Nothing here has run on a board. "Model" means pgsim, run with the same register values as the
capture header. Where a row says "by reading the model", it was not run.

## Conventions

- Sample k is the pad level at sysclk cycle k after the enable write (silicon-ref README).
- A pgsim pad transition at cycle c is seen by the sampler at sample c + L, where L is the input
  latency (`trace_cmp --latency L`). A write at cycle c reaches the pad at c + 1 (ambiguity 1).
- Host actions (`host_actions`) run at a time MicroPython sets, with jitter of a few microseconds.
  Their landing cycle is read from the trace, through the pin they change. `trace_cmp` does not
  model host actions or host pins, so configs that use them (a, f_*) are compared by hand.

## The items

| Item | Config(s) | Question | Status |
| --- | --- | --- | --- |
| a | `v1_a_autopush` | Autopush into a full RX FIFO: stall before or after the shift? | runnable, host timed |
| b | `v1_b_pull_autopull` | PULL under autopull with one bit shifted out (count 1) | runnable |
| b2 | `v1_b2_pull_full` | PULL under autopull with count 0 (R4: no-op) | runnable |
| c | `v1_c_first_out` | Does the first OUT after reset stall once? | runnable |
| d | `v1_d_irq_wait` | WAIT on an IRQ flag, same SM | runnable; cross-SM design only (below) |
| e | `v1_e_calib` | Input and output latency L | runnable |
| f | `v1_f_delay`, `v1_f_sideset`, `v1_f_irq_wait` | Forced instructions: delay, side-set, IRQ wait | runnable, host timed |
| g | `v1_g_frac_div` | Divider phase after restart, clkdiv 2.5 | runnable |
| h | `v1_h_pull_stall` | TX write during a stalled PULL | not run: decided by a design ruling (below) |
| i | `v1_i_out_sticky_on`, `_off` | OUT_STICKY across a stalled side-set | runnable |

Not written: the autopull count after a forced instruction (needs the forced instruction counted by
the autopull rule, plus the same host-timed forced write as f).

## b and b2. PULL under autopull: which rule silicon follows

Two programs separate the three readings of the PULL rule.

- b (`v1_b_pull_autopull`): `pull; out; pull; out` x4, autopull at threshold 32, TX words
  0x00000002 and 0xFFFFFFFE. The second PULL runs with one bit shifted out (count 1). Pin 0 bits of
  the five OUTs are read.
- b2 (`v1_b2_pull_full`): `pull; pull; out` x5, autopull at threshold 32, TX words 0x0000000A (bits
  0..4 = 0,1,0,1,0) and 0x0000001F (1,1,1,1,1). The second PULL runs with count 0, nothing shifted.

Three rules, and the bits each one predicts (pin 0, five OUTs):

| Rule | b | b2 |
| --- | --- | --- |
| R4 (no-op only at count 0) | 0,0,1,1,1 | 0,1,0,1,0 |
| Old pgsim (no-op while count < threshold) | 0,1,0,0,0 | 0,1,0,1,0 |
| PULL always consumes | 0,0,1,1,1 | 1,1,1,1,1 |

"Old pgsim" is block 1 pgsim as it stands (sw/pgsim ambiguity 3). Block 1 pgsim is being moved to
R4 in parallel, so this row will change. The rows above are the rules, not the current pgsim output.

Reading the capture:

| b bits | b2 bits | Meaning |
| --- | --- | --- |
| 0,0,1,1,1 | 0,1,0,1,0 | R4. The count-1 PULL takes word 1, and the count-0 PULL is a no-op. |
| 0,1,0,0,0 | 0,1,0,1,0 | Old pgsim: the PULL is a no-op while count < threshold. Block 1 pgsim is then right, and R4 must change at count 1. |
| 0,0,1,1,1 | 1,1,1,1,1 | PULL always consumes. R4 is wrong at count 0: a PULL with nothing shifted takes the next word. |
| anything else | anything else | Neither. Re-check the header and the TX FIFO state. |

Together, b and b2 settle both sides of the rule: b2 gives count 0, b gives count 1.

## c. First OUT after reset

Program: `out pins, 1` alone, autopull at threshold 32, one TX word 0x00000001, clock divider 1.0.

Model (run): the first pin 0 rise is at pad cycle 2, one tick after the no-stall start at pad cycle
1. The extra tick is the autopull refill of the empty OSR (ambiguity 4).

Measure L from item e (`L = first_rise_sample(e) - 1`). Then:

| Rise sample of c, minus L | Meaning |
| --- | --- |
| 2 | The first OUT stalls once (model). |
| 1 | No stall: the OSR counts as holding data after reset. The model must change. |
| more than 2 | The refill takes more than one tick. |

## d. WAIT and IRQ visibility, same SM (runnable), and the cross-SM design (not written)

Program: `irq clear 0; set pins, 0; irq set 0; wait 1 irq 0; set pins, 1`, clock divider 1.0.
Model (run): pad low for 3 cycles and high for 2, period 5, so the wait passes in the cycle after
the set.

| Pad-low cycles per round | Meaning |
| --- | --- |
| 3 | The flag is visible one cycle after the set (model). |
| 4 | Visible two cycles after the set. Ambiguity 9 must change. |
| 2 | Visible in the cycle of the set. Not expected. |

Same-SM visibility may differ from visibility across SMs, which is the question V1 asks. The
cross-SM variant is not run. Design, for when `capture.py` can load a helper SM:

- SM0 (program under test): `set pins, 0; wait 1 irq 0; set pins, 1`.
- Helper SM2, in IMEM after the sampler: `nop [k]; irq set 0`. (A side-set on the helper, as
  `irq set 0 side 1`, would mark its cycle on a pin. Optional.)
- One enable write starts SM0, the helper and the sampler (the enable mask gains bit 2). The header
  records the helper.
- Sweep k. The set lands in the cycle the wait is entered when the wait entry cycle equals the
  helper's set cycle. The pad-low length for each k is the answer. The model for each k comes from
  pgsim with two SMs (not yet in the CLI).

`capture.py` loads one program SM and one sampler SM, so this needs a loader change (a second
program's IMEM placement, PINCTRL, EXECCTRL, jmp and enable mask). That is not written.

## e. Calibration (input latency)

Program: square wave on pin 0, 8 cycles high and 8 low, clock divider 1.0. Model: first pad rise at
cycle 1, so the first rise sample is `1 + L`.

| First rise sample | Meaning |
| --- | --- |
| 4 | L = 3, as the model's input synchroniser predicts (ambiguity 1). |
| other | L is that value minus 1. Use it with `trace_cmp --latency`. Do not use 3. |

Run this first. Every other comparison needs its L.

## f. Forced instructions

The programs and host actions are in `v1_items.pio` and the configs. Pin 1 (f_delay, f_irq_wait)
is written low by every program instruction, so a forced `set pins, 2` (pin 0 low, pin 1 high) shows
its landing as a rise on pin 1. The next program instruction makes pin 1 fall.

Every comparison below uses the baseline from the same trace: the instruction boundaries before the
forced write, which show the program's schedule. The forced write's landing cycle is read from the
trace (its pin change), not from the host time.

### f_sideset (side-set and a repeated side-set)

Program: `set pins, 0 side 0; wait 1 pin 5 side 1; set pins, 0`, with `.side_set 1 opt`. Pin 5 is
host-driven (low at start, high at about 30 us). The forced `set pins, 2` lands at about 10 us: pin 0
low, pin 1 high.

Model (run): without the forced write, pin 0 rises at cycle 2, the first stalled attempt. With the
forced write at cycle 10: pin 0 falls at 11 with the forced write, and stays low (side-set is not
repeated).

| Baseline, before the forced write | Meaning |
| --- | --- |
| pin 0 high from the first stalled attempt (model: cycle 2) | Side-set is applied on the first attempt. |
| pin 0 low until the wait completes | Side-set is applied only at completion. The model must change (ambiguity 11). |

| After the forced write | Meaning |
| --- | --- |
| pin 0 stays low until pin 5 goes high | Side-set is not repeated on stalled cycles (model). |
| pin 0 goes high again while the wait is still stalled | Side-set is repeated. The model must change. |

### f_delay (does the pending delay continue?)

Program: `set pins, 1 [31]; set pins, 0 [31]`, set count 2. Each instruction is 32 cycles, so the
baseline boundaries are the pin 0 edges at 32-cycle spacing (the trace's own grid). The forced
`set pins, 2` lands during one of them (host time about 20 us).

Model (run, forced write at cycle 40): the baseline boundaries are at 1, 33, 65, 97. With the forced
write, pin 1 rises at 41, and the next boundary is at 66, one cycle later than the baseline grid
(65). So the model keeps the pending delay, but the forced cycle moves the next boundary by one.
Ambiguity 8 says it should not; the pgsim owner must check this.

Silicon comparison, from one trace:

1. Take the boundary grid from the pin 0 edges before the landing (the phase, and the 32-cycle
   spacing).
2. Find the first boundary after the landing (the pin 0 edge, or the pin 1 fall).
3. Compare it with the grid extended forward.

| Result | Meaning |
| --- | --- |
| The first boundary after the landing is on the extended grid, no shift | The forced cycle costs nothing. The model's +1 is wrong. |
| It is one cycle later than the grid (the model's result) | The delay continues and the forced cycle costs one cycle. Model agrees. |
| It is at the landing plus one, off the grid | The delay is cancelled. Ambiguity 8 holds the other way; the model must change. |
| It is at the landing plus about 32 (one full instruction after the landing) | The delay restarted at the landing, not continued. The model must change. |

To re-run pgsim at the observed landing `L_f` (the pgsim cycle, which is the pad rise sample minus L,
minus 1), with the registers from the trace header:

```
python3 -c "import json,sys; h=json.loads(open('TRACE.jsonl').readline())['program']['registers']; \
  json.dump({k:h[k] for k in ('clkdiv','execctrl','shiftctrl','pinctrl')}, open('fd.cfg.json','w'))"
./_build/default/sw/pgsim/cli/pgsim_cli.exe --program silicon-ref/v1/v1_items.pioasm.json \
  --name v1_f_delay --config fd.cfg.json --init-instr e083 --cycles 120 \
  --at L_f:instr:0:E002 --trace
```

Compare the pgsim pad edges with the silicon pin 0 and pin 1 edges, shifted by L.

### f_irq_wait (does the wait survive a forced set?)

Program: `set pins, 0; wait 1 irq 0; set pins, 0`. Forced `set pins, 2` at about 10 us (pin 1
high), forced `irq set 0` at about 30 us (ends the wait).

| Result | Meaning |
| --- | --- |
| Pin 1 stays high from the forced set, and falls only after the forced IRQ | The wait survives the forced set (model, by reading block 1 pgsim). |
| Pin 1 falls at the forced set, or the wait never completes | The forced set cancels the wait. The model must change. |

## g. Divider phase after restart

Program: `set pins, 1; set pins, 0`, which toggles pin 0 on every PIO tick. Clock divider 2.5
(`clkdiv` (2, 128)). Model (run): rises at pad cycles 3, 8, 13, 18, ..., falls at 5, 10, 15, ...,
intervals alternating 2 and 3.

| Edge pattern | Meaning |
| --- | --- |
| Same as the model | Phase after restart matches the model (ambiguity 10). |
| The whole pattern shifted by one cycle | The first tick is at a different cycle. |
| Intervals differ, for example 2, 2, 3 | The fractional accumulator does not match the model. |

## h. TX write during a stalled PULL: decided by a design ruling, not by silicon

Program: `pull block; set pins, 1; set pins, 0`. The question is whether a TX write that lands
during a stalled blocking PULL completes the PULL in its own cycle or the next one.

This is ruled by design, because silicon cannot observe the TX landing cycle. The host's TX write is a
bus write through the SIO-versus-PIO path, and its landing cycle relative to the PIO's sampling cycle is
not visible on any pin. The PULL's completion is visible, but the write's landing is not, so the trace
cannot tell the two cases apart. The config is kept with `"runnable": false`, and
the batch skips it. The model completes the PULL in the cycle after the write (sw/pgsim/README.md,
V1 item h). That is the design ruling, not a silicon result.

## i. OUT_STICKY across a stalled side-set

Program: `pull; out pins, 1; wait 1 pin 5 side 0; set pins, 1`, `.side_set 1 opt`. OUT writes pin 0
high. The stalled wait sets pin 0 low on its first attempt. Pin 5 is held low by the PIO, so the
wait stalls.

Block 1 pgsim (run): with OUT_STICKY, pin 0 rises at 2, falls at 3, and rises again at 4 (re-asserted each
stalled cycle). Without it: rise at 2, fall at 3, stays low.

| Pin 0 during the stall, `_on` | Pin 0 during the stall, `_off` | Meaning |
| --- | --- | --- |
| high again from 4 | low | OUT_STICKY re-asserts over side-set, as the model says. |
| low | low | OUT_STICKY does not re-assert over side-set. The model must change. |
| low | high | Not expected. Re-check the configs. |

## Block 1 pgsim predictions (same register values as the capture header)

These are the current block 1 pgsim outputs, which follow the old PULL rule for b and b2 until pgsim moves to R4.

| Config | Pgsim edges (pad cycle, pin, new level) |
| --- | --- |
| b | (4, 0, 1), (5, 0, 0): old rule. R4 gives 0,0,1,1,1 instead (see b and b2). |
| b2 | (4, 0, 1), (5, 0, 0), (6, 0, 1), (7, 0, 0): 0,1,0,1,0, the same under R4 and the old rule |
| c | (2, 0, 1), (3, 0, 0) |
| d | low at 2, high at 5, low at 7, high at 10, ... (period 5) |
| e | rise at 1, fall at 9, rise at 17, fall at 25, ... |
| f_sideset baseline | (2, 0, 1) |
| f_sideset, forced set at 10 | (2, 0, 1), (11, 0, 0), (11, 1, 1) |
| f_delay baseline | (1, 0, 1), (33, 0, 0), (65, 0, 1), (97, 0, 0) |
| f_delay, forced set at 40 | (1, 0, 1), (33, 0, 0), (41, 1, 1), (66, 0, 1), (66, 1, 0), (98, 0, 0) |
| g | rise 3, fall 5, rise 8, fall 10, rise 13, fall 15, ... |
| i (on) | (2, 0, 1), (3, 0, 0), (4, 0, 1) |
| i (off) | (2, 0, 1), (3, 0, 0) |

a and f_irq_wait depend on the host landing, so their predictions are not in this table.
