# silicon-ref/v1: capture programs for the V1 items

DESIGN.md §17 V1 and `sw/pgsim/README.md` ("V1: what the silicon capture must settle"). Each item
has a program (in `v1_items.pio`, one `.program` per item, assembled with the official pioasm 2.3.1
into `v1_items.pioasm.json`), a capture config `v1_<item>.config.json` (arguments of `capture.run`),
and the outcome table below.

Assemble: `pioasm -o json v1_items.pio v1_items.pioasm.json`.
Dry run of one config under the mock: `python3 silicon-ref/test_capture_mock.py`
(the V1 configs are run by `test_v1_*` and by the batch dry run).

Everything here is [verify on hardware]. The model's predictions below were run with pgsim
(`predict` runs, same configs, same register values as the capture header), except where a row says
"by reading the model".

## Conventions

- Sample k is the pad level at sysclk cycle k after the enable write (silicon-ref README). Pad
  level at pgsim cycle c is compared with sample c + L, where L is the input latency
  (`trace_cmp --latency L`).
- In the tables, "pad rise at cycle c" means a pgsim pad transition, so a write at cycle c is seen
  at c+1 on the pad (sw/pgsim/README.md, ambiguity 1).
- Host actions (`host_actions`) happen at a time set by MicroPython, about a microsecond of jitter.
  Their landing cycle must be read from the trace, through the pin that they change. `trace_cmp` does
  not model host actions or host pins, so for configs that use them (a, f_*) compare by hand, as the
  tables say.

## The items

| Item | Config | Program | Question | Runnable |
| --- | --- | --- | --- | --- |
| a | `v1_a_autopush` | `v1_a_autopush` | Autopush into a full RX FIFO: stall before or after the shift? | yes |
| b | `v1_b_pull_autopull` | `v1_b_pull_autopull` | Does PULL under autopull consume a TX word when the OSR is not empty? | yes |
| c | `v1_c_first_out` | `v1_c_first_out` | Does the first OUT after reset stall once? | yes |
| d | `v1_d_irq_wait` | `v1_d_irq_wait` | When does a flag set become visible to WAIT? (same SM only) | yes |
| e | `v1_e_calib` | `v1_e_calib` | Input and output latency L | yes |
| f | `v1_f_delay`, `v1_f_sideset`, `v1_f_irq_wait` | same | Forced instructions: delay, side-set, IRQ wait | yes, host timed |
| g | `v1_g_frac_div` | `v1_g_frac_div` | Divider phase after restart, clkdiv 2.5 | yes |
| h | `v1_h_pull_stall` | `v1_h_pull_stall` | PULL completion when TX is written during the stall | **no** (see h) |
| i | `v1_i_out_sticky_on`, `_off` | `v1_i_out_sticky` | OUT_STICKY across a stalled side-set | yes |

Item (autopull count after a forced instruction) is not written. It needs the forced instruction
counted in the autopull rule, and the same host-timed forced write as f.

## a. Autopush order

Program: five `in pins, 1` with autopush at threshold 1. The RX FIFO is 4 deep, so the fifth IN
finds it full. The host sets pin 1 high at about 20 us and reads the RX FIFO at about 60 us. A marker
(`set pins, 1`, pin 2) follows the IN.

The fifth pushed word is the sample taken by the IN. Stall-then-shift reads the pin when the stall
ends (after the host sets pin 1 high), so the word has bit 31 set. Shift-then-stall reads the pin on
the first attempt (before 20 us), so bit 31 is clear.

| Outcome (`rx_words[4]` in the header, bit 31) | Meaning |
| --- | --- |
| 0x80000000 | The IN samples its pin when the stall ends: stall-then-shift. This is the model (by reading the model: `In_pins` is read on the completing attempt). |
| 0x00000000 | The IN samples on the first attempt: shift-then-stall. The model must change (ambiguity 5), and the RX push order must follow the shift. |
| anything else | The word is not a single sampled bit: the IN shifted more than once during the stall, which neither model allows. |

The first four words must be 0 (pin 1 is low until about 20 us). The marker on pin 2 comes after the
host read, so it shows the stall length, not the shift order.

## b. PULL under autopull

Program: `pull`, `out`, `pull`, `out` x4 with autopull at threshold 32. TX words: 0x00000002 and
0xFFFFFFFE.

| Pin 0 bits, first 5 OUTs | Meaning |
| --- | --- |
| 0, 1, 0, 0, 0 | The second PULL is a no-op because the OSR is not empty (model, ambiguity 3). Pgsim predicts a rise at pad cycle 4 and a fall at 5. |
| 0, 0, 1, 1, 1 | The second PULL consumed TX word 1 and dropped the rest of the OSR. The model must change. |
| anything else | Not explained by either. Re-check the header and the TX FIFO state. |

## c. First OUT after reset

Program: `out pins, 1` alone, autopull at threshold 32, one TX word 0x00000001. Clock divider 1.0.

Pgsim predicts the first rise at pad cycle 2, one tick later than a no-stall start (pad cycle 1). The
extra tick is the autopull refill of the empty OSR (ambiguity 4, the OUT refill stall).

Measure L from item e (`L = rise_sample(e) - 1`). Then:

| Rise sample of c, minus L | Meaning |
| --- | --- |
| 2 | The first OUT stalls once (model). |
| 1 | No stall: the OSR counts as holding data after reset. The model must change for V1 item c. |
| more than 2 | The refill takes more than one tick. |

## d. WAIT and IRQ visibility (same SM)

Program: `irq clear 0; set pins, 0; irq set 0; wait 1 irq 0; set pins, 1`, clock divider 1.0.
This is the same-SM variant. The task asked for a flag raised by another SM. That needs a second
program SM, which `capture.run` does not load, so it is not done. Visibility in the same SM may
differ from visibility across SMs.

Pgsim predicts pad low for 3 cycles (wait passes at the next cycle) and high for 2, period 5.

| Pad-low cycles per round | Meaning |
| --- | --- |
| 3 | The flag is visible one cycle after the set (model). |
| 4 | Visible two cycles after the set. The model must change (ambiguity 9). |
| 2 | Visible in the cycle of the set. Not expected from the datasheet. |

## e. Calibration (input latency)

Program: square wave on pin 0, 8 cycles high and 8 low, clock divider 1.0. Pgsim predicts the first
pad rise at cycle 1, so the sample of the first rise is `1 + L`.

| First rise sample | Meaning |
| --- | --- |
| 4 | L = 3, as the model's input synchroniser predicts (sw/pgsim/README.md ambiguity 1). Use `--latency 3` with the other traces. |
| other | L is that value minus 1. Use it with `trace_cmp --latency`. Do not use 3. |

Run this first. Every other comparison needs its L.

## f. Forced instructions

Three programs. Each has one or two host actions (`instr`, or `gpio` for the wait pin).

Pin 1 (the marker, in f_delay and f_irq_wait) is written low by every program instruction, so a
forced `set pins, 2` (pin 0 low, pin 1 high) shows its landing as a rise on pin 1. The next program
instruction then makes pin 1 fall, which marks when the program ran again.

- **f_delay.** The program has two instructions, each with a delay of 31 (32 cycles). The forced
  `set pins, 2` lands during one of them. Pgsim run (forced `set pins, 2` at cycle 40, config as
  above): pin 1 falls at cycle 66. Without the forced instruction the fall is at cycle 65. So the
  model keeps the pending delay, but the forced cycle costs the next boundary one cycle. That is
  not what ambiguity 8 says, and it is logged for the pgsim owner to check. If the delay were
  cancelled, the fall would come at about the landing cycle (41).
- **f_sideset.** The program waits for pin 5 with side-set 1 on pin 0. The forced `set pins, 2` at
  about 10 us drives pin 0 low during the stall. Model: side-set is applied once, on the first attempt
  (ambiguity 11), so pin 0 stays low. If side-set is repeated, pin 0 goes high again while the wait is
  still stalled. The host sets pin 5 at about 30 us, which ends the wait.
- **f_irq_wait.** The program waits on IRQ 0. A forced `set pins, 2` at about 10 us sets pin 1 high
  during the stall. A forced `irq set 0` at about 30 us ends the wait. Model: the wait survives the
  forced set, so pin 1 falls only after the forced IRQ.

| Result | Meaning |
| --- | --- |
| f_delay: pin 1 falls at the landing cycle plus one (about 41 for a landing at 40) | The delay is cancelled. The model must change. |
| f_delay: pin 1 falls at the schedule (65 for the landing at 40 in the pgsim run) | The forced cycle costs nothing. The model's extra cycle (66) must change. |
| f_delay: pin 1 falls at 66 (pgsim) | The delay continues and the forced cycle costs one cycle (model). |
| f_sideset: pin 0 stays low during the stall | Side-set is applied once (model). |
| f_sideset: pin 0 goes high again during the stall | Side-set is repeated on stalled cycles. The model must change. |
| f_irq_wait: pin 1 falls after the forced IRQ | The wait survives the forced set (model). |
| f_irq_wait: pin 1 falls at the forced set, or never | The forced set cancels the wait. The model must change. |

The landing cycle of a forced instruction is the cycle of its pin change in the trace. Use that
cycle, not the host time, to check the first two rows. Compare pgsim with `--at CYCLE:instr:0:E002`
set to the landing cycle.

## g. Divider phase after restart

Program: `set pins, 1; set pins, 0`, which toggles pin 0 on every PIO tick. Clock divider 2.5
(`clkdiv` (2, 128)). Pgsim predicts the rises at pad cycles 3, 8, 13, 18, ..., and the falls at
5, 10, 15, ..., so the tick intervals alternate 2 and 3 cycles.

| Interval pattern of the edges | Meaning |
| --- | --- |
| Same as pgsim (3, 5, 8, 10, 13, ...) | Phase after restart matches the model (ambiguity 10, the same accumulator as docs/gate.md). |
| The whole pattern shifted by one cycle | The first tick is at a different cycle. The model's phase is wrong by one. |
| The intervals differ, for example 2, 2, 3 | The fractional accumulator does not match the model. |

## h. TX write during a stalled PULL: not decidable

Program: `pull block; set pins, 1; set pins, 0`. The host writes TX at about 20 us (`tx` action).

This cannot be decided with this harness. The TX write lands at a time set by MicroPython, and its
landing is not visible on any pin. The pad shows when the PULL completed, not when the word arrived,
so the question ("completes in the cycle of the write or the next") cannot be read from the trace.
The config is kept with `"runnable": false`, and the batch skips it.

What would decide it: a TX write whose cycle is known, such as a DMA chained to a PIO-paced request
with a calibrated delay, plus a marker on a pin in the same cycle. Neither is written.

## i. OUT_STICKY across a stalled side-set

Program: `pull; out pins, 1; wait 1 pin 5 side 0; set pins, 1` with `.side_set 1 opt`. The OUT writes
pin 0 high. The stalled wait sets pin 0 low on its first attempt (side-set). Pin 5 is held low by the
PIO, so the wait stalls.

Pgsim predicts (with OUT_STICKY): pin 0 rises at cycle 2, falls at 3 (side-set), and rises again at
4 (the OUT re-asserted every stalled cycle). Without OUT_STICKY: rise at 2, fall at 3, and it stays low.

| Pin 0 during the stall, `_on` config | Pin 0 during the stall, `_off` config | Meaning |
| --- | --- | --- |
| high again from 4 | low | OUT_STICKY re-asserts the last OUT over side-set, as the model says. |
| low | low | OUT_STICKY does not re-assert over side-set. The model must change (`sw/pgsim` item i). |
| low | high | Not expected. Re-check the configs. |

## Model predictions run with pgsim (same register values as the capture header)

| Config | Pgsim edges (pad cycle, pin, new level) |
| --- | --- |
| b | (4, 0, 1), (5, 0, 0) |
| c | (2, 0, 1), (3, 0, 0) |
| d | low at 2, high at 5, low at 7, high at 10, ... (period 5) |
| e | rise at 1, fall at 9, rise at 17, fall at 25, ... |
| g | rise 3, fall 5, rise 8, fall 10, rise 13, fall 15, ... |
| i (on) | rise 2, fall 3, rise 4 |
| i (off) | rise 2, fall 3 |

Predictions for a and f depend on the host landing, so they are not in this table.
