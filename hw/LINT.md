# Verilator lint, pio_block (block 2)

Command: `verilator --lint-only -Wall --top-module pio_block pio_block.v`, with the file
from `gen_verilog.exe -- pio_block`. Result: 33 warnings, 0 errors. Block 1 (`polyglot`)
gives 8 under the same flags.

## Unused bits and signals (UNUSEDSIGNAL)

| Warning | Source | Why it is acceptable |
| --- | --- | --- |
| `clkdiv0..3[7:0]` (4 warnings, `pio_block`) | `clkdiv` register bits 7:0 | Reserved in RP2040 PIO CLKDIV (datasheet 3.7, SM0_CLKDIV bits 7:0 "Reserved"). The engine takes INT [31:16] and FRAC [15:8] only. |
| `execctrl0`'s `[31,23:18,6:5]` (`sm`) | EXECCTRL bit 31 (EXEC_STALLED, read-only, ignored by contract), bits 23:18 (OUT_EN_SEL, INLINE_OUT_EN: block 2 ignores them, engine.md section 2), bits 6:5 (reserved, datasheet 3.7) | As listed. The bits are part of the RP2040 layout and are deliberately ignored. |
| `shiftctrl[31:30]`, `[15:0]` (`sm`) | Bits 31:30 are FJOIN_RX and FJOIN_TX, which `fifo_join` uses, not the engine. Bits 15:0 are reserved (datasheet 3.7). | Not used by the engine, by design. |
| `vdd` (3 warnings) | A Hardcaml constant `1'b1` that the Verilog backend emits in each module. Nothing reads it after simplification. | Emitted by the library, not from RTL logic. Removing it would mean changing the Hardcaml backend. |
| `_189` (`fifo_join`, 32-bit zero) | The zero constant that Hardcaml emits next to the last storage word, `word_7`, of the 8-word store in `fifo_join.ml`. Probably the default value of that register bank. It has no reader. | Constant with no logic. The word 7 register itself is used (`word_7_en`, `head` mux). |
| `_784` (`pio_block`, 16-bit zero) | The zero constant emitted next to `imem_31` (the last IMEM word) in `pio_block.ml`, probably the default value of the IMEM register bank. It has no reader. | As for `_189`. The IMEM words themselves are all read by the PC mux. |

These two constants are traced to the register bank they sit next to in the netlist. The exact Hardcaml call that produced them is not confirmed:
the evidence is their position beside the last register of each bank.

## Non-blocking assignment in combinational logic (COMBDLY, 21 warnings)

Hardcaml's Verilog backend writes multiplexers and selects as `always @(*)` blocks that
use `<=`. Each target is assigned once per block, so the simulation result is the same as
with `=`. The block 1 design has the same pattern. Rewriting it would mean changing the
generator, not the design.

## DECLFILENAME

The file holds the `decode` module first, then the others. Nothing depends on the file
name.
