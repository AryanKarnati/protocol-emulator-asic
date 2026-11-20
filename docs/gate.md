# Block 1 gate design (temporary)

This is the pin-level contract for the design that goes through the **Hardcaml gate** at the end of block 1 ([PLAN.md](PLAN.md), [DESIGN.md §19](../DESIGN.md#19-schedule-and-scope-tiers)). It exists only to prove that Hardcaml-generated Verilog passes GDS, precheck and gate-level simulation. Block 3 replaces it with the real host link.

The RTL lane builds the design from this file. The Model & tests lane writes the cocotb test from this file. Neither reads the other's code.

## Structure

- `src/project.v` (hand-written) is `tt_um_aryankarnati_polyglot`. It maps pads to the ports of the generated module and does nothing else.
- `src/polyglot.v` (generated from `hw/`) is module `polyglot`. In block 1 it holds:
  - a reset synchronizer (DESIGN.md §13);
  - one clock divider (16.8 fractional, DESIGN.md §8.1);
  - one FIFO, 4 entries of 32 bits;
  - the command decoder below.

## Pins

| Pin | Direction | Name | Meaning |
| --- | --- | --- | --- |
| `ui_in[2:0]` | in | `CMD` | Command, executed at every rising edge of `clk` |
| `ui_in[4:3]` | in | `BYTE_SEL` | Which byte of the FIFO head word to show |
| `ui_in[5]` | in | `VIEW` | 0: show the FIFO head byte. 1: show `STATUS`. |
| `ui_in[7:6]` | in | (none) | Ignored |
| `uio_in[7:0]` | in | `DATA` | Data for `PUSH`, `INT_LO`, `INT_HI` and `FRAC` |
| `uio_oe[7:0]` | out | | Always `0x00`. All `uio` pins are inputs. |
| `uio_out[7:0]` | out | | Always `0x00` |
| `uo_out[7:0]` | out | | `VIEW`=0: byte `BYTE_SEL` of the FIFO head word, or `0x00` when the FIFO is empty. `VIEW`=1: `STATUS`. |

- Inputs are sampled directly at the rising edge, with no synchronizers. Testbenches must change inputs away from the rising edge, for example just after the falling edge.
- `ena` is ignored.
- `BYTE_SEL` = 0 selects bits 7:0, 1 selects 15:8, 2 selects 23:16, 3 selects 31:24.

## Commands

| `CMD` | Name | Effect at the rising edge |
| --- | --- | --- |
| `000` | `NOP` | Nothing |
| `001` | `PUSH` | If the FIFO is not full, push `W = {DATA, DATA, DATA, DATA} ^ 32'h0123_4567`. If it is full, drop the word and set `OVERFLOW`. |
| `010` | `POP` | If the FIFO is not empty, remove the head word. If it is empty, set `UNDERFLOW`. |
| `011` | `INT_LO` | Divider `INT[7:0] := DATA` |
| `100` | `INT_HI` | Divider `INT[15:8] := DATA` |
| `101` | `FRAC` | Divider `FRAC := DATA` |
| `110` | `DIV_RESTART` | Restart the divider's phase, as `CTRL.CLKDIV_RESTART` does |
| `111` | `CLEAR_FLAGS` | `OVERFLOW := 0` and `UNDERFLOW := 0` |

Writing `INT` or `FRAC` does not restart the divider. Tests load the divisor, then send `DIV_RESTART`.

## `STATUS` byte (`VIEW` = 1)

| Bit | Name | Meaning |
| --- | --- | --- |
| 7 | `TICK` | The divider's enable output in the current cycle |
| 6:4 | `LEVEL` | Number of words in the FIFO, 0 to 4 |
| 3 | `FULL` | `LEVEL` = 4 |
| 2 | `EMPTY` | `LEVEL` = 0 |
| 1 | `OVERFLOW` | Sticky: a `PUSH` hit a full FIFO |
| 0 | `UNDERFLOW` | Sticky: a `POP` hit an empty FIFO |

## Reset

`rst_n` low resets the design asynchronously; release goes through a 2-FF synchronizer (DESIGN.md §13). After reset:

- the FIFO is empty and both flags are 0;
- the divider is `INT` = 1, `FRAC` = 0, so `TICK` is 1 in every cycle.

## Clock divider behaviour

Let the divisor be D = `INT` + `FRAC`/256. `INT` = 0 means 65536, and `FRAC` must then be 0, as on the RP2040.

Tests may rely on these properties, which match the formal property in DESIGN.md §17:

1. With `FRAC` = 0, ticks are exactly `INT` cycles apart. With `INT` = 1 and `FRAC` = 0, `TICK` is 1 in every cycle.
2. With `FRAC` ≠ 0, the gap between consecutive ticks is always `INT` or `INT` + 1 cycles.
3. After `DIV_RESTART`, any 256 consecutive gaps add up to exactly 256 × `INT` + `FRAC` cycles.

The cycle on which the first tick appears after `DIV_RESTART` is not specified, and tests must not depend on it. Exact phase matching with RP2040 silicon is checked later, by V1.
