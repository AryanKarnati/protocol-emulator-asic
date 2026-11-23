# Block 3 contract: the whole chip

This contract fixes what block 3 builds: the host link, the register block, the 64-word instruction memory, the pin block and the four-engine top. It also fixes what the top-level lockstep compares. It plays the same role for block 3 that [engine.md](engine.md) played for block 2.

- The **RTL lane** builds `hw/hostlink.ml`, `hw/regs.ml`, `hw/pins.ml`, `hw/chip.ml` and the new `hw/top.ml` from it, and changes `hw/pio_block.ml` as [engine.md §3](engine.md#3-pio_block-ports) now says.
- The **Model & tests lane** builds the whole-chip `pgsim`, the top-level lockstep and the cocotb tests of the top from it.
- The **Flow & proofs lane** writes the host-link properties from §6 and §7, and hardens the top.
- The **ISA & tools lane** builds the MicroPython host library from §6, §8 and §12.

## 1. Sources, in order

1. This document, then [engine.md](engine.md) for everything inside `pio_block`.
2. The RP2040 datasheet, chapter 3: `~/.cache/polyglot/rp2040.txt`. Section 3.7 gives the register layouts that §8 calls "RP2040 layout".
3. [DESIGN.md](../DESIGN.md) §5 to §7, §9.3, §11 and §13.

If this document seems to contradict the datasheet or DESIGN.md, stop and report it to the orchestrator. Do not pick one.

## 2. Scope

**In block 3:**

- The host link: an SPI mode 0 target, oversampled in the `clk` domain (§6).
- The register block: every register in §8.
- The 64 × 16 instruction memory in two pages, and `EXT.PAGE`.
- The pin block: the 32-bit input vector, open-drain on `uio`, `HOST_IRQ` and `MISO` (§9).
- The top: four engines, and the Tiny Tapeout wrapper with the reset synchroniser (§10).

**Not in block 3:**

- `DBG_CTRL` HALT and STEP. They are block 4 work. In block 3 `DBG_CTRL` reads 0 and ignores writes.
- The LCU. Its registers read 0 and ignore writes, virtual pins 24 to 31 read 0, and its three instruction encodings stay reserved (engine.md R12).
- The elastic FIFOs and `EFIFO_*` (Tier 1). Those addresses read 0 and ignore writes.
- `INLINE_OUT_EN` and `OUT_EN_SEL`. They are stored and read back, but have no effect (engine.md §2).

**Trial only:** the SRAM window (§8.4). It is built behind the `sram` parameter for the block 3 SRAM gate. It is not in the lockstep.

## 3. Structure and parameters

The circuits take the four parameters of DESIGN §18: number of SMs (1 to 4), IMEM depth (32 or 64), LCU present (always false in block 3) and SRAM present.

| File | Module | Role |
| --- | --- | --- |
| `hw/hostlink.ml` | `hostlink` | SPI target to bus (§6, §7) |
| `hw/regs.ml` | `regs` | Register block (§8) |
| `hw/pins.ml` | `pins` | Pad mapping (§9) |
| `hw/pio_block.ml` | `pio_block` | Engines, IMEM, FIFOs, IRQs, pin registers (engine.md) |
| `hw/chip.ml` | `chip` | All of the above. The circuit the top-level lockstep simulates. |
| `hw/top.ml` | `polyglot` | Reset synchroniser and `chip` with 4 SMs and 64 words. It has the Tiny Tapeout ports only. |

`src/project.v` does not change. It still maps the pads to module `polyglot`.

`hw/chip.mli` exposes:

```ocaml
val circuit : num_sms:int -> imem_depth:int -> Hardcaml.Circuit.t
```

This is the circuit with LCU and SRAM absent. It must behave exactly like the Verilog that `gen_verilog chip` prints.

`hw/bin/gen_verilog.exe` keeps its current subcommands and adds:

- `chip`: `chip` with 4 SMs, 64 words and the debug ports;
- `hostlink`: `hostlink` alone, for the proofs.

With no argument it prints the new Tiny Tapeout top. That output is the committed `src/polyglot.v`, and it replaces the block 1 gate design.

## 4. `chip` ports

Port names are the Verilog names, and the lockstep drives Cyclesim by them.

**Inputs**

| Port | Bits | Meaning |
| --- | --- | --- |
| `clock` | 1 | |
| `rst_n` | 1 | Asynchronous, active low. The parent (`top.ml`) synchronises its release (§10). |
| `ui_in` | 8 | Tiny Tapeout dedicated inputs |
| `uio_in` | 8 | Tiny Tapeout bidirectional pads, input path |

**Outputs**

| Port | Bits | Meaning |
| --- | --- | --- |
| `uo_out` | 8 | §9 |
| `uio_out` | 8 | §9 |
| `uio_oe` | 8 | §9 |
| `dbg_pins_out`, `dbg_pins_oe`, `dbg_irq`, `dbg_fstat`, `dbg_flevel`, `dbg_fdebug` | | `pio_block`'s `pins_out`, `pins_oe`, `irq`, `fstat`, `flevel` and `fdebug` |
| `dbg_pc0`…`3`, `dbg_x0`…`3`, `dbg_y0`…`3`, `dbg_isr0`…`3`, `dbg_osr0`…`3`, `dbg_cnt0`…`3`, `dbg_exec_stalled0`…`3`, `dbg_phase0`…`3`, `dbg_instr0`…`3` | | `pio_block`'s ports of the same names |
| `dbg_bus_write`, `dbg_bus_read`, `dbg_bus_commit` | 1 each | The host link's bus pulses (§6.4) |
| `dbg_bus_addr` | 16 | Byte address of the access, bits [1:0] = 0. Meaningful in a cycle with one of the three pulses. |
| `dbg_bus_wdata` | 32 | Write data. Meaningful in a `dbg_bus_write` cycle. |
| `dbg_bus_rdata` | 32 | The value the read returns. Meaningful in a `dbg_bus_read` cycle. |

The debug ports exist only on `chip`. `top.ml` leaves them unconnected.

## 5. Cycle conventions

These are engine.md §5, unchanged: cycle 0 is the first cycle after reset, register outputs in cycle k hold the state after k clock edges, levels are used in the cycle they are presented, and pulses presented in cycle k are judged against the state at the start of cycle k and applied at its end (H1 to H9).

At the chip level the pulses and levels that reach `pio_block` come from the register block (§8). The lockstep resets `chip` with `Cyclesim.reset`, as in block 2. The `rst_n` path is checked in Verilog by cocotb (§10).

**Pin cycles.** "SCK is 1 in cycle c" means `ui_in[5]` is 1 in the cycle-c input. Write `sck(c)`, `mosi(c)` and `cs_n(c)` for `ui_in[5]`, `ui_in[6]` and `ui_in[7]` in cycle c. Every pin sequence has a defined result. §6.6 lists what a host must do for the transfer to carry the data it intends.

## 6. Host link

### 6.1 Synchronisers

Each of SCK, MOSI and CS_N goes through three flops, s1 to s3. s1 takes the pin and s2 takes s1, which makes the 2-FF synchroniser. s3 takes s2, for edge detection. So in cycle t:

- `p1(t) = p(t−1)`, `p2(t) = p(t−2)`, `p3(t) = p(t−3)`.
- Before reset release every flop holds the idle value: SCK 0, MOSI 0, CS_N 1. For t − n < 0, `p(t−n)` is that idle value.

These flops are separate from the input synchronisers in `pio_block`. Programs still see pins 21 to 23 through their own input path (engine.md R1).

### 6.2 Events

In cycle t:

| Event | Condition |
| --- | --- |
| `START(t)` | `cs_n2(t) = 0` and `cs_n3(t) = 1` |
| `END(t)` | `cs_n2(t) = 1` and `cs_n3(t) = 0` |
| `RISE(t)` | `sck2(t) = 1`, `sck3(t) = 0`, `cs_n2(t) = 0` and `cs_n3(t) = 0` |

A rise counts only when the synchronised CS_N has been low for at least one cycle already. So `RISE` never happens in the same cycle as `START` or `END`. The bit a `RISE` delivers is `mosi2(t)`.

A **frame** runs from a `START` to the next `END`. Its bits are numbered from 0 in the order of the `RISE`s inside it. A frame has no length limit.

### 6.3 Frame layout

Bits 0 to 7 are the command byte, MSB first. Bit 0 is CMD[7], R: 1 means read. Bit 1 is CMD[6], F: 1 means fixed address. CMD[5:0] are ignored.

Bits 8 to 23 are ADDR[15:0], MSB first. `addr_m`, the address of data word m (m = 0, 1, …), is ADDR when F = 1. Otherwise it is (ADDR + 4m) mod 2^16. ADDR[1:0] are ignored, so every access uses `addr_m` with bits [1:0] cleared.

**Write frame (R = 0).** Data word m is bits 24 + 32m to 55 + 32m, MSB first.

**Read frame (R = 1).** Bits 24 to 31 are a dummy byte, and MOSI is ignored from bit 24 on. Data word m goes out on MISO as bits 32 + 32m to 63 + 32m, MSB first.

### 6.4 Bus accesses

The host link does at most one of the following in a cycle. In each case `dbg_bus_addr = addr_m`.

- **Write**, in the cycle of the `RISE` that delivers bit 55 + 32m of a write frame. `dbg_bus_write` = 1, and `dbg_bus_wdata` is word m: the 31 earlier bits followed by this cycle's `mosi2(t)`. The register block applies the write in that cycle (§8.2).
- **Read**, in the cycle of the `RISE` that delivers bit 31 + 32m of a read frame. `dbg_bus_read` = 1. The register block returns the value of `addr_m` against the state at the start of the cycle (§8.3). That value is `dbg_bus_rdata`, and it is the word MISO sends next.
- **Commit**, in the cycle of the `RISE` that delivers bit 32 + 32m of a read frame, the first bit of word m. `dbg_bus_commit` = 1. Only an `RXFn` read acts on a commit (§8.3).

A frame that ends before a word's last bit does not write that word. A read word is consumed at its commit, so a frame that ends after the read but before the commit leaves the RX FIFO as it was. The host has to clock the first bit of word m + 1 before word m + 1 is popped, even though its MSB is already on MISO. This is why a burst read of an RX FIFO never loses a word at the end of the burst.

### 6.5 MISO

MISO is `uo_out[7]`. It is the MSB of a 32-bit shift register that changes only at the end of these cycles:

| Cycle | Shift register from the next cycle |
| --- | --- |
| `START(t)` | `{STATUS(t), 24'b0}`, where STATUS(t) is the §9.3 STATUS byte in cycle t |
| `RISE(t)` with a read access | the read value |
| any other `RISE(t)` | shifted left by one, with 0 shifted in |
| `END(t)` | 0 |

So MISO carries STATUS during the command byte, 0 during the address and dummy bytes, the read words in a read frame, and 0 in a write frame from bit 8 on. It is 0 between frames.

**Timing at the pin.** MISO changes only in the cycle right after a `START`, `RISE` or `END`, and is cleared by reset. Each of those events comes two cycles after the pin edge that causes it. So for a counted rise of SCK in pin cycle c (`sck(c) = 1`, `sck(c−1) = 0`), the `RISE` is in cycle c + 2 and MISO shows the next bit from cycle c + 3.

**Hold.** MISO can change in cycle c + 1 or c + 2 only if SCK rose, or CS_N changed, in pin cycle c − 2 or c − 1. A host that follows §6.6 never does that. So under §6.6, MISO holds its value for the two cycles after every sampling edge.

This replaces DESIGN §6's "MISO changes after the falling edge of SCK". With a 2-FF synchroniser, a falling-edge update arrives after the next rising edge once SCK is faster than about `clk`/8, so it cannot reach the 15 MHz DESIGN promises.

### 6.6 What the host must do

The cycle model above defines every pin sequence. For the host to read and write what it intends, it must also:

- **H-SCK.** Keep each SCK high phase and low phase at least 2 cycles while CS_N is low, so the period is at least 4 cycles. That is SCK ≤ `clk`/4, 15 MHz at 60 MHz.
- **H-CS.** Change CS_N only while SCK is low. Leave at least 3 cycles from CS_N falling to the first SCK rise, and keep CS_N high for at least 2 cycles between frames. STATUS bit 7 reaches MISO in the third cycle after CS_N falls, so with exactly 3 cycles it arrives in the cycle the host samples it.
- **H-RST.** Keep CS_N high while `rst_n` is low and for at least 4 cycles after it rises. A frame that is in progress when reset is released is still defined by §6.1 and §6.2, but its bits are not the host's.
- **H-MOSI.** Change MOSI only while SCK is low, and not in the cycle SCK rises.
- **Sampling.** Sample MISO in the cycle that raises SCK, or up to 2 cycles later. By §6.5, with H-SCK and H-CS kept, the bit is on MISO from at least the cycle before the rise until 2 cycles after it. A real host should sample about 1 cycle after its rise, which centres the sample in that window at 15 MHz. The §12 library does this.

A real host adds margin for pad and board delay: at least 4 cycles of CS setup and of CS_N high time, and MOSI changed on the falling edge of SCK. The library in §12 does this.

## 7. `hostlink` ports (for the proofs)

`hostlink` holds §6.1 to §6.5. It knows nothing about registers.

| Input | Bits | Meaning |
| --- | --- | --- |
| `clock`, `rst_n` | 1 each | `rst_n` is the chip's synchronised reset |
| `sck`, `mosi`, `cs_n` | 1 each | Raw pins (`ui_in[5]`, `[6]`, `[7]`) |
| `status` | 8 | STATUS (§9.3), used in a `START` cycle |
| `rdata` | 32 | The read value, used in a `bus_read` cycle. The register block drives it combinationally from `bus_addr`. |

| Output | Bits | Meaning |
| --- | --- | --- |
| `miso` | 1 | §6.5 |
| `bus_write`, `bus_read`, `bus_commit` | 1 each | §6.4 |
| `bus_addr` | 16 | §6.4 |
| `bus_wdata` | 32 | §6.4 |

The `chip` debug ports `dbg_bus_*` are these outputs. `dbg_bus_rdata` is `rdata`.

While `rst_n` is low, every `hostlink` flop holds its reset value. So `miso` is 0 and no bus pulse is raised, whatever the pins do.

## 8. Register map

### 8.1 Addresses

All addresses are byte addresses. Anything not listed reads 0 and ignores writes. "RP2040 layout" means the field layout of the RP2040 register of the same name (datasheet §3.7). RW registers store only the bits in their write mask, and every other bit reads 0.

| Address | Name | Access | Reset | Write mask or meaning |
| --- | --- | --- | --- | --- |
| 0x000 | `ID` | R | `0x504C4754` | |
| 0x004 | `HWCFG` | R | see below | |
| 0x008 | `CTRL` | RW | 0 | [3:0] SM_ENABLE (RW). [7:4] SM_RESTART and [11:8] CLKDIV_RESTART: write 1 for a pulse, read 0. |
| 0x00C | `FSTAT` | R | | `pio_block.fstat` |
| 0x010 | `FDEBUG` | RW1C | | `pio_block.fdebug` |
| 0x014 | `FLEVEL` | R | | `pio_block.flevel` |
| 0x018 | `IRQ` | RW1C | | [7:0] `pio_block.irq` |
| 0x01C | `IRQ_FORCE` | W | | [7:0]. Reads 0. |
| 0x020 | `HOSTIRQ_EN` | RW | 0 | [11:0] (§9.3) |
| 0x024 | `PAD_OD` | RW | 0 | [7:0] (§9.2) |
| 0x028 | `INPUT_SYNC_BYPASS` | RW | 0 | [23:0] |
| 0x02C | `PAD_IN` | R | | `{8'b0, ui_in, uo_out, uio_in}`, the raw pad levels in the cycle of the read |
| 0x030 | `PAD_OUT` | R | | `pio_block.pins_out` |
| 0x034 | `PAD_OE` | R | | `pio_block.pins_oe` |
| 0x038 | `SCRATCH` | RW | 0 | [31:0] |
| 0x040 + 4n | `TXFn` | W | | Push to TX FIFO n. Reads 0. |
| 0x050 + 4n | `RXFn` | R | | Pop RX FIFO n (§8.3) |
| 0x060 | `DBG_CTRL` | | | Block 4. Reads 0, ignores writes. |
| 0x100 + 4k | `IMEM[k]` | W | not reset | [15:0]. Write-only, as RP2040 `INSTR_MEM`. Reads 0. k < IMEM depth. |
| 0x200 + 0x40n | SMn block | | | Below |
| 0x400 to 0xBFC | `SRAM` | RW | not reset | §8.4. Unmapped when SRAM is absent. |

Per-SM block, offsets from 0x200 + 0x40n:

| Offset | Name | Access | Reset | Write mask or meaning |
| --- | --- | --- | --- | --- |
| +0x00 | `CLKDIV` | RW | `0x00010000` | `0xFFFFFF00` (RP2040 layout) |
| +0x04 | `EXECCTRL` | RW | `0x0001F000` | `0x7FFFFF9F` (RP2040 layout). Bit 31 reads `dbg_exec_stalled`n. |
| +0x08 | `SHIFTCTRL` | RW | `0x000C0000` | `0xFFFF0000` (RP2040 layout) |
| +0x0C | `ADDR` | R | | [4:0] `dbg_pc`n |
| +0x10 | `INSTR` | RW | | Write: [15:0] is a forced instruction. Read: [15:0] `dbg_instr`n, the word at the PC (RP2040 `SMx_INSTR`). |
| +0x14 | `PINCTRL` | RW | `0x14000000` | `0xFFFFFFFF` (RP2040 layout) |
| +0x18 | `EXT` | RW | 0 | [0] PAGE. With IMEM depth 32 the mask is 0. |
| +0x1C to +0x28 | `LCU_*` | | | Block 5. Read 0, ignore writes. |
| +0x2C | `DBG_X` | R | | `dbg_x`n |
| +0x30 | `DBG_Y` | R | | `dbg_y`n |
| +0x34 | `DBG_ISR` | R | | `dbg_isr`n |
| +0x38 | `DBG_OSR` | R | | `dbg_osr`n |
| +0x3C | `DBG_CNT` | R | | `dbg_cnt`n |

`HWCFG` = [5:0] FIFO depth 4, [11:8] number of SMs, [22:16] IMEM depth, [24] LCU present (0), [25] SRAM present, [31:28] version 1. Every other bit is 0.

**Absent SMs** (n ≥ number of SMs): the SMn block reads 0 and ignores writes. So do their bits in `CTRL`, `TXFn` and `RXFn`. Their bits in `FSTAT`, `FLEVEL`, `FDEBUG`, STATUS and the `HOST_IRQ` sources are 0.

### 8.2 Writes

A bus write in cycle t, to address a with data w:

- **RW registers** take `w & mask` at the end of cycle t. `pio_block` sees the new level from cycle t + 1.
- **Pulses** are presented to `pio_block` in cycle t itself, and engine.md H1 to H9 apply:

| Write to | Pulse in cycle t |
| --- | --- |
| `CTRL` | `sm_restart` = w[7:4], `clkdiv_restart` = w[11:8] |
| `FDEBUG` | `fdebug_clear` = w |
| `IRQ` | `irq_clear` = w[7:0] |
| `IRQ_FORCE` | `irq_force` = w[7:0] |
| `TXFn` | `txf_push`, `txf_sm` = n, `txf_data` = w |
| `IMEM[k]` | `imem_write`, `imem_addr` = k, `imem_data` = w[15:0] |
| SMn `INSTR` | `instr_write`, `instr_sm` = n, `instr_data` = w[15:0] |
| SMn `SHIFTCTRL` | `fifo_flush`[n] if w[31:30] differs from the stored FJOIN bits |

A `CTRL` write therefore restarts in cycle t and enables from cycle t + 1. A `SHIFTCTRL` write that changes FJOIN flushes both FIFOs at the end of cycle t, and the new capacity applies from cycle t + 1. The FIFOs are empty when it does, whether or not the SM is enabled. That makes an FJOIN change defined at the chip level, so it is no longer outside the contract.

**Still outside the contract** at the chip level, and never generated: both FJOIN bits set, and `CLKDIV` with INT = 0 and FRAC ≠ 0.

### 8.3 Reads

A bus read in cycle t returns the value of the register in cycle t, before anything that happens at the end of cycle t. The values are as §8.1 lists. `pio_block` outputs are read in the same cycle.

**`RXFn`.**

- At the read in cycle t, the value is `pio_block.rxf_data` with `rxf_sm` = n: the head word, or 0 if the FIFO is empty. Nothing changes in that cycle. The register block records whether FIFO n was empty (`fstat` RXEMPTY[n] = 1 in cycle t).
- At the commit of the same word in cycle t′:
  - If the FIFO was not empty at the read, the register block presents `rxf_pop` with `rxf_sm` = n in cycle t′. The head is the word the host is receiving, because only the host pops RX FIFOs and nothing else touches the head between the read and the commit.
  - If it was empty, the register block presents `fdebug_set` with RXUNDER[n] in cycle t′ and pops nothing.
- A frame that ends between the read and the commit does neither.

An absent SM's `RXFn` reads 0 and sets nothing.

### 8.4 SRAM window (trial, `sram` = true only)

0x400 + 4j (j = 0 to 511) is word j of the IHP SRAM macro, whose Verilog module is `RM_IHPSG13_1P_512x32_c2_bm_bist` (see `flow/SRAM.md`). A write in cycle t is seen by reads from cycle t + 1. A word that was never written reads an unspecified value. There is no other use of the macro in block 3. This window is not in the lockstep. cocotb checks it against the macro's own Verilog model.

## 9. Pins

### 9.1 Input vector

`pio_block.pins_in` = `{8'b0, ui_in, uo_out, uio_in}`. Pins 0 to 7 are `uio_in`, 8 to 15 are this cycle's `uo_out` (DESIGN §5: reading an output-only pin returns what is driven), 16 to 23 are `ui_in`, and the virtual pins 24 to 31 are 0.

`pio_block.sync_bypass` = `{8'b0, INPUT_SYNC_BYPASS[23:0]}`.

### 9.2 Outputs

| Pad | Value |
| --- | --- |
| `uio_out[i]` | `PAD_OD[i] ? 0 : pins_out[i]` |
| `uio_oe[i]` | `pins_oe[i] & ~(PAD_OD[i] & pins_out[i])` |
| `uo_out[5:0]` | `pins_out[13:8]` |
| `uo_out[6]` | `HOST_IRQ` while `HOSTIRQ_EN` ≠ 0, otherwise `pins_out[14]` |
| `uo_out[7]` | MISO (§6.5) |

`pins_out[15]` and `pins_oe[15:8]` reach no pad. With open-drain, a program writes 0 to pull low and 1 to release.

The lockstep testbench drives each `uio_in[i]` as `uio_oe[i] ? uio_out[i] : external[i]`, which is the pad rule of engine.md R1 at the chip level.

### 9.3 STATUS and `HOST_IRQ`

In cycle t, with `fstat` from cycle t:

- `RXNEMPTY[n]` = NOT RXEMPTY[n], and `TXNFULL[n]` = NOT TXFULL[n]. Both are 0 for an absent SM. A FIFO with capacity 0 reads full and empty (engine.md §3), so both are 0 for it too.
- STATUS = `{TXNFULL[3:0], RXNEMPTY[3:0]}`, so bit 7 is TXNFULL[3].
- The `HOST_IRQ` sources are `{TXNFULL[3:0], RXNEMPTY[3:0], irq[3:0]}`, which is bits [11:8], [7:4] and [3:0] of `HOSTIRQ_EN`.
- `HOST_IRQ` = OR over i of (`HOSTIRQ_EN[i]` AND source i), active high, in the same cycle.

Every chip output is a function of register state in the same cycle. There is no combinational path from an input pin to an output pin.

## 10. Reset and the Tiny Tapeout top

- `top.ml` keeps the block 1 reset synchroniser: `rst_n` asserts asynchronously and is released through two flops. Its output is `chip.rst_n`. `ena` is ignored.
- At reset every register in §8 takes its listed reset value, `pio_block` resets as engine.md R0 says, and the host link is idle with its synchronisers at the idle values (§6.1). IMEM and the SRAM are not reset.
- cocotb checks the `rst_n` path on the Verilog: reset in the middle of a frame and in the middle of a running program, then a clean frame.

## 11. What the top-level lockstep compares

Every cycle, for `chip` against the whole-chip `pgsim`:

- `uo_out`, `uio_out`, `uio_oe`;
- every `dbg_*` port of `pio_block` that §4 lists, for each SM i < number of SMs, and for the whole block, as engine.md §7 says;
- `dbg_bus_write`, `dbg_bus_read` and `dbg_bus_commit`; `dbg_bus_addr` in any cycle with one of them; `dbg_bus_wdata` in a write cycle; `dbg_bus_rdata` in a read cycle.

A run fails on the first difference. The report gives the cycle, the port, both values, and the shrunk frames, program and pin stimulus that reproduce it. Failures go to the RTL lane as case files, never as model code.

**What the generator must cover:**

- writes and reads of every register in §8.1, with F = 0 and F = 1;
- IMEM loads to both pages, and `EXT.PAGE` changes;
- TX bursts and RX burst reads, including reads of empty FIFOs and FIFOs that fill or drain during the frame;
- frames cut off at random bits, 1-byte STATUS polls, back-to-back frames with the minimum gap, and pin sequences that break §6.6 (the result is still defined);
- SCK periods from 4 cycles up, with uneven high and low phases;
- the 36 corpus programs, loaded and started through the host link;
- external levels on every input pad, open-drain on and off, and `HOSTIRQ_EN` on and off.

## 12. Simulation server (Model & tests lane to ISA & tools lane)

The Model & tests lane provides `pgsim chip-serve`, so the host library can be tested against the whole-chip model before there is a board. It reads one command per line on stdin and writes one reply line per command on stdout:

| Command | Reply | Effect |
| --- | --- | --- |
| `xfer HEX` | `ok HEX` | One frame: CS_N low, the bytes MSB first, CS_N high. The reply is the MISO bytes, one per byte sent. |
| `run N` | `ok` | N cycles with CS_N high |
| `ext UI UIO` | `ok` | External levels: `ui_in[4:0]` from UI, and the external level of each `uio` pad from UIO, both in hex |
| `pads` | `ok UO UIOOUT UIOOE` | This cycle's `uo_out`, `uio_out` and `uio_oe`, in hex |
| `cycle` | `ok N` | The current cycle number |
| `quit` | | Exit |

Options: `--num-sms N` (default 4), `--sck-half H` (SCK high and low phases in cycles, default 3), `--cs-setup S` (default 4), `--cs-gap G` (default 4). Anything else gets the reply `err` and a reason.

## 13. Exit checks for block 3

1. **Top-level lockstep:** `chip` with 4 SMs matches the whole-chip `pgsim` on the corpus and on at least 2,000 random host-link cases, with 0 mismatches. The block 2 `pio_block` lockstep still passes with the new ports.
2. **Independent SPI check:** a cocotb test drives the Verilog top through a `cocotbext-spi` master, which no AI wrote. It reads `ID`, writes and reads back `SCRATCH`, loads and runs a program, and moves FIFO data. The same test runs at gate level in CI.
3. **Host-link proofs:** the §6 properties are proven on `gen_verilog hostlink`.
4. **Hardening:** the top passes GDS, precheck and gate-level simulation in CI. The report gives utilisation and slow-corner slack at 16.67 ns for the gate.
5. **SRAM trial:** the result of hardening with the macro (pass or fail, area, timing), for the SRAM call.
