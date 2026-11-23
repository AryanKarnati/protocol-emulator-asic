# Verilator lint, pio_block (block 3)

Command: `verilator --lint-only -Wall --top-module pio_block pio_block.v`, with the file
from `gen_verilog.exe -- pio_block` (IMEM depth 64). Result: 38 warnings, 0 errors. (Verilator
prints "Exiting due to 38 warning(s)" because `-Wall` warnings are fatal. That line is the
summary, not an error.) Block 2 gave 33 under the same flags. The 5 new warnings are the
block 3 ports, listed below. The depth-32 build (`circuit_with ~imem_depth:32`, not a
`gen_verilog` target) gives 36, with 4 engines: the same list, except that `ext0..3` are
unused in bits [31:8] only (the absent-engine sink keeps the ports alive, see below), and
`imem_addr[5]` is unused in full. Block 1 (`polyglot`) gives 8 under the same flags.

## Unused bits and signals (UNUSEDSIGNAL)

| Warning | Source | Why it is acceptable |
| --- | --- | --- |
| `clkdiv0..3[7:0]` (4 warnings, `pio_block`) | `clkdiv` register bits 7:0 | Reserved in RP2040 PIO CLKDIV (datasheet 3.7, SM0_CLKDIV bits 7:0 "Reserved"). The engine takes INT [31:16] and FRAC [15:8] only. |
| `execctrl0`'s `[31,23:18,6:5]` (`sm`) | EXECCTRL bit 31 (EXEC_STALLED, read-only, ignored by contract), bits 23:18 (OUT_EN_SEL, INLINE_OUT_EN: block 2 ignores them, engine.md section 2), bits 6:5 (reserved, datasheet 3.7) | As listed. The bits are part of the RP2040 layout and are deliberately ignored. |
| `shiftctrl[31:30]`, `[15:0]` (`sm`) | Bits 31:30 are FJOIN_RX and FJOIN_TX, which `fifo_join` uses, not the engine. Bits 15:0 are reserved (datasheet 3.7). | Not used by the engine, by design. |
| `ext0..3[31:1]` (4 warnings, depth 64; `[31:8]` at depth 32) | EXT bits above bit 0 (block 3). Only bit 0 (PAGE) is used at depth 64, and nothing at depth 32. | engine.md section 3: "Other bits are ignored." The ports are kept by the absent-engine sink (`pio_block.ml`), which is ORed into `irq` as a constant 0, so that every port survives in Cyclesim for every `num_sms` and depth. At depth 32 the sink reaches only `irq[7:0]`, so bits [31:8] are unused. |
| `imem_addr[5]` (depth 32 only) | The write address bit that depth 32 ignores (engine.md section 3, 9). | As listed. |
| `fdebug_set[23:20,15:12,7:4]` (`pio_block`) | The reserved FDEBUG bits, which have no SM. `fdebug_set` is ANDed with the defined bits of each engine that exists (`pio_block.ml`). | Not in the FDEBUG layout (engine.md section 3), so a set there is ignored. Recorded as a choice in the block 3 report. |
| `vdd` (3 warnings) | A Hardcaml constant `1'b1` that the Verilog backend emits in each module. Nothing reads it after simplification. | Emitted by the library, not from RTL logic. Removing it would mean changing the Hardcaml backend. |
| `_189` (`fifo_join`, 32-bit zero) | The zero constant that Hardcaml emits next to the last storage word, `word_7`, of the 8-word store in `fifo_join.ml`. Probably the default value of that register bank. It has no reader. | Constant with no logic. The word 7 register itself is used (`word_7_en`, `head` mux). |
| `_1027` (`pio_block`, 16-bit zero) | The zero constant emitted next to `imem_63` (the last IMEM word) in `pio_block.ml`, probably the default value of the IMEM register bank. It has no reader. (Block 2 had the same constant beside `imem_31`, as `_784`.) | As for `_189`. The IMEM words themselves are all read by the fetch mux. |
| `execctrl`, `shiftctrl`, `clkdiv` and `vdd` warnings above | Unchanged. | Unchanged. |

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
