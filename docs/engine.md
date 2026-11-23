# Block 2 contract: the PIO engine and its block

This contract fixes what the block 2 RTL builds and what the lockstep harness compares. It plays the same role for block 2 that [gate.md](gate.md) played for block 1.

- The **RTL lane** builds `hw/decode.ml`, `hw/sm.ml` and `hw/pio_block.ml` from it.
- The **Model & tests lane** builds the lockstep harness from it, and changes `pgsim` wherever `pgsim` differs from it.
- The **Flow & proofs lane** uses §4 for the decoder equivalence proof.

## 1. Sources, in order

1. This document: the interface (§3, §4), the cycle conventions (§5) and the rulings (§6). The rulings only settle points where the datasheet is silent or ambiguous.
2. The RP2040 datasheet, chapter 3 (PIO): `~/.cache/polyglot/rp2040.txt`, with the PDF in the same folder. Sections 3.2 to 3.5 give the behaviour, and section 3.7 gives the register layouts. Every instruction's behaviour comes from here. Read the pseudocode in §3.5.4 for autopush and autopull.
3. [DESIGN.md](../DESIGN.md) §7 to §9 and §13.

If this document seems to contradict the datasheet, stop and report it to the orchestrator. Do not pick one.

## 2. Scope

**In block 2:**

- The decoder.
- One engine (SM). This covers all nine instructions, delay, side-set (including `SIDE_PINDIR`), every stall, autopush and autopull, `!OSRE`, `STATUS`, `OUT_STICKY`, `OUT/MOV EXEC`, and forced instructions.
- The block, with `num_sms` engines (an elaboration parameter, 1 to 4). It contains:
  - the instruction memory: 32 × 16 in block 2, and 64 × 16 in two pages from block 3 (§9);
  - the 8 IRQ flags;
  - the pin output registers, with a level and a direction for each of 32 pins;
  - the input registers and synchronisers;
  - each SM's TX and RX FIFOs (4 words each, or one of 8 when joined) and clock divider.

**Not in block 2:**

- The host link and the register block. In block 2 the testbench drives the block's configuration and host ports directly.
- The 64-word IMEM and `EXT.PAGE`. Block 3 adds them (§9).
- Pad types, open-drain and `HOST_IRQ`.
- The LCU.
- `DBG_CTRL` HALT and STEP.
- `INLINE_OUT_EN` and `OUT_EN_SEL` (EXECCTRL bits 23:18). Both lanes treat them as 0, and the generator never sets them. They are on the compatibility backlog for block 4.
- The RP2350-only fields.

The Tiny Tapeout top (`src/project.v`, `hw/top.ml`) stays as the block 1 gate design until block 3, when [chip.md](chip.md) §3 replaces it.

## 3. `pio_block` ports

Port names are the Verilog names. The lockstep harness drives Cyclesim by these names, so they must match exactly. A `[@length 4]` list field such as `clkdiv` must come out as `clkdiv0` … `clkdiv3`. If ppx_hardcaml names list ports differently, use separate fields instead.

`hw/pio_block.mli` exposes `val circuit : num_sms:int -> Hardcaml.Circuit.t`. This is the circuit the lockstep harness simulates, and it must behave exactly like the Verilog that `gen_verilog` prints.

Ports exist for 4 SMs whatever `num_sms` is. For an SM `i ≥ num_sms` there is no logic: its outputs are 0, and inputs aimed at it are ignored. Every port in this table must also exist in the Cyclesim simulation for every `num_sms` and IMEM depth, including inputs the circuit ignores, such as `ext` at depth 32. Cyclesim drops inputs nothing reads, so the RTL must keep them on purpose.

**Inputs**

| Port | Bits | Kind | Meaning |
| --- | --- | --- | --- |
| `clock` | 1 | | |
| `rst_n` | 1 | | Asynchronous, active low. The parent synchronises its release. |
| `sm_enable` | 4 | level | CTRL.SM_ENABLE |
| `clkdiv0`…`3` | 32 | level | SMn_CLKDIV, RP2040 layout: INT [31:16], FRAC [15:8] |
| `execctrl0`…`3` | 32 | level | SMn_EXECCTRL, RP2040 layout. Bit 31 (EXEC_STALLED) is read-only and ignored here. Bits 23:18 are ignored in block 2. |
| `shiftctrl0`…`3` | 32 | level | SMn_SHIFTCTRL, RP2040 layout |
| `pinctrl0`…`3` | 32 | level | SMn_PINCTRL, RP2040 layout |
| `sync_bypass` | 32 | level | INPUT_SYNC_BYPASS |
| `pins_in` | 32 | level | Raw level of each pad |
| `sm_restart` | 4 | pulse | CTRL.SM_RESTART |
| `clkdiv_restart` | 4 | pulse | CTRL.CLKDIV_RESTART |
| `fifo_flush` | 4 | pulse | Empty both FIFOs of the SM. Block 3's register block raises it when FJOIN changes (datasheet §3.7: "FIFOs are flushed when this bit is changed"). |
| `irq_clear` | 8 | pulse | IRQ register, write 1 to clear |
| `irq_force` | 8 | pulse | IRQ_FORCE |
| `fdebug_clear` | 32 | pulse | FDEBUG, write 1 to clear, in the layout below |
| `txf_push`, `txf_sm` [2], `txf_data` [32] | | pulse | Host push to TX FIFO `txf_sm` |
| `rxf_pop`, `rxf_sm` [2] | | pulse | Host pop from RX FIFO `rxf_sm` |
| `instr_write`, `instr_sm` [2], `instr_data` [16] | | pulse | Host write to SMn_INSTR |
| `imem_write`, `imem_addr` [6], `imem_data` [16] | | pulse | Instruction memory write. With IMEM depth 32, bit 5 is ignored. (Block 3: was 5 bits.) |
| `ext0`…`3` | 32 | level | SMn_EXT. Bit 0 is PAGE. Other bits are ignored. With IMEM depth 32 the whole word is ignored. (Block 3.) |
| `fdebug_set` | 32 | pulse | Sets FDEBUG flags, in the `fdebug` layout (H8). Bits outside that layout ([7:4], [15:12], [23:20]) and bits of absent SMs are ignored. The register block uses it for RXUNDER (chip.md §8.3). (Block 3.) |

**Outputs**

| Port | Bits | Meaning |
| --- | --- | --- |
| `pins_out` | 32 | Output level register of each pin |
| `pins_oe` | 32 | Direction register of each pin (1 = output) |
| `irq` | 8 | IRQ flags |
| `rxf_data` | 32 | Combinational. The head of RX FIFO `rxf_sm`, or 0 if it is empty. From block 3 this holds in every cycle, whether or not a pop is presented, because the register block reads the head before it pops (chip.md §8.3). |
| `fstat` | 32 | RP2040 FSTAT: TXEMPTY [27:24], TXFULL [19:16], RXEMPTY [11:8], RXFULL [3:0] |
| `flevel` | 32 | RP2040 FLEVEL: for SM n, TX level in [8n+3:8n] and RX level in [8n+7:8n+4] |
| `fdebug` | 32 | RP2040 FDEBUG: TXSTALL [27:24], TXOVER [19:16], RXUNDER [11:8], RXSTALL [3:0]. Polyglot adds ILLEGAL in [31:28]. All sticky. |
| `dbg_pc0`…`3` | 5 | PC |
| `dbg_x0`…`3`, `dbg_y0`…`3`, `dbg_isr0`…`3`, `dbg_osr0`…`3` | 32 | X, Y, ISR, OSR |
| `dbg_cnt0`…`3` | 32 | DBG_CNT (DESIGN §7): ISR count [5:0], OSR count [13:8], delay [20:16], stall reason [27:24], all other bits 0 |
| `dbg_exec_stalled0`…`3` | 1 | EXECCTRL.EXEC_STALLED (§6, F4) |
| `dbg_phase0`…`3` | 25 | Clock divider phase register, in units of 1/256 cycle (§6, R10) |
| `dbg_instr0`…`3` | 16 | Combinational. The IMEM word at the SM's fetch address (§9) in this cycle, whatever the SM is doing. `SMn_INSTR` reads it. (Block 3.) |

A FIFO that is disabled because the other one is joined (datasheet §3.7 FJOIN) has capacity 0. It reads as both full and empty, with level 0. Capacity is always a function of the FJOIN inputs in the current cycle. It is not state, and reset does not change it.

For an SM `i ≥ num_sms`, every bit that belongs to it in `fstat`, `flevel` and `fdebug` is 0. So is each of its `dbg_*` outputs.

These are outside this contract, and the generator never produces them:

- both FJOIN bits set;
- INT = 0 with FRAC ≠ 0;
- an IMEM write while `rst_n` is low;
- a change to FJOIN unless the SM is disabled and both its FIFOs are empty.

## 4. `decode` ports (for the equivalence proof)

`decode` is a purely combinational module. The engine uses it, and the Flow lane proves it equal to `Isa.decode`.

| Input | Bits | Meaning |
| --- | --- | --- |
| `instr` | 16 | Instruction word |
| `sideset_count` | 3 | PINCTRL.SIDESET_COUNT, 0 to 5. It includes the enable bit when `side_en` is set. |
| `side_en` | 1 | EXECCTRL.SIDE_EN |

| Output | Bits | Must equal |
| --- | --- | --- |
| `legal` | 1 | `Isa.is_legal (Isa.decode instr)` |
| `is_jmp` `is_wait` `is_in` `is_out` `is_push` `is_pull` `is_mov` `is_irq` `is_set` | 1 each | The constructor of `Isa.decode instr`. All are 0 when `legal` is 0. |
| `uses_lcu` | 1 | The word is `In_lcu`, `Ms_crc` or `Set_lcu` |
| `side_valid`, `side_value` [5], `delay` [5] | | `Isa.Side.split {count; enable} (bits 12:8)`. Defined for every word, illegal ones included. `side_value` is compared only when `side_valid` is 1. |
| `bit_count` | 6 | 1 to 32 for a legal IN or OUT, otherwise 0 |

The equivalence holds for every 16-bit word and every valid side-set configuration: count 0 to 5, and enable only with count ≥ 1. The engine may slice other fields (condition, source, destination, index and so on) straight from the instruction bits.

## 5. Cycle conventions

**Numbering.** Cycle 0 is the first cycle in which `rst_n` is high.

**Reset in simulation.** Hardcaml's Cyclesim does not apply the asynchronous `rst_n` at clock edges. It resets registers only through `Cyclesim.reset`. So the lockstep harness resets the RTL with `Cyclesim.reset` and resets `pgsim` at the same point, and the path through the `rst_n` pin is checked in Verilog simulation. During `rst_n` low the outputs are not compared.

- During cycle k, the register outputs hold the state after k clock edges since reset. That is `pgsim`'s state after k calls to `step`.
- Every register resets to the value in §6, R0.

**Levels** (configuration, `sm_enable`, `sync_bypass`, `pins_in`) are used in the cycle they are presented. In `pgsim` they are the configuration, enable and external pad levels for `step` k.

**Pulses** (host operations) presented in cycle k are judged against the state at the start of cycle k. They take effect at the end of cycle k, together with everything the SMs do in cycle k. `pgsim` must offer the same thing: host operations that run alongside `step` k, judged against the state before the step and applied with it.

- **H1. TX push.** If the TX FIFO is full at the start of the cycle, the word is dropped and TXOVER is set, even if the SM pops in the same cycle. Otherwise the word joins the tail, after any SM pop in that cycle. The SM sees it from cycle k+1.
- **H2. RX pop.** If the RX FIFO is empty at the start of the cycle, `rxf_data` is 0 and RXUNDER is set, even if the SM pushes in the same cycle. Otherwise `rxf_data` is the head word, and it leaves the FIFO at the end of the cycle. The SM sees the freed space from cycle k+1.
- **H3. SM_RESTART.** At the end of the cycle the restart clears what the datasheet's CTRL.SM_RESTART text lists, overriding anything the SM did to those items in cycle k:
  - ISR count → 0, OSR count → 32, ISR → 0, delay → 0;
  - both IRQ wait states;
  - the instruction latch (EXEC or forced);
  - the OUT_STICKY write;
  - both stall reasons and both side-set-done flags.

  PC, OSR contents, X and Y keep whatever cycle k left in them. Pin writes made in cycle k still happen. If `instr_write` comes in the same cycle, the restart applies first and the new instruction is latched after it.
- **H4. CLKDIV_RESTART.** The phase becomes 0 at the end of the cycle. Any tick already due in cycle k still happens.
- **H5. IRQ.** At the end of a cycle:

  `irq_next = (irq & ~(SM clears | irq_clear)) | SM sets | irq_force`

  A set always beats a clear in the same cycle (datasheet §3.2.7).
- **H6. FIFO flush.** Both FIFOs are empty at the end of the cycle, overriding host and SM FIFO activity in that cycle. A word an SM popped in that cycle still reaches its OSR. The flush empties only the storage. TXOVER, RXUNDER, TXSTALL and RXSTALL still follow H1, H2, R5 and R7 in that cycle, and the SM's instruction completes or stalls exactly as it would without the flush.
- **H7. INSTR write.** The instruction is latched at the end of the cycle and runs from cycle k+1 (F1). It overwrites any latched instruction, EXEC or forced (datasheet §3.5.7 caution). If a stalled forced instruction is being retried in cycle k, that retry still runs in cycle k, and the new write replaces the latch at the end of the cycle.
- **H8. FDEBUG clear.** `flag_next = (flag & ~fdebug_clear) | SM sets in cycle k | fdebug_set`, so a set wins.
- **H9. IMEM write.** The new word can be fetched from cycle k+1.

## 6. Rulings

Each ruling cites the datasheet text it settles. Items marked V1 are to be checked against Pico 2 silicon.

**R0. Reset.** These follow DESIGN §13 and datasheet §3.2.3.3.

- PC 0; X, Y, ISR and OSR 0; ISR count 0; OSR count 32; delay 0.
- Both stall reasons 0; no latched instruction; no IRQ wait.
- Side-set-done flags 0; sticky write empty.
- FIFOs empty; divider phase 0; IRQ flags 0; FDEBUG 0.
- `pins_out` and `pins_oe` 0; input registers 0.
- IMEM is not reset.

**R1. Pin and input timing.** This is datasheet §3.5.6: "two-cycle delay" bypassed, "four-cycle delay" synchronised.

- An SM write in cycle k shows on `pins_out`/`pins_oe` in cycle k+1.
- Every pin passes through one input register, and synchronised pins through two more. An instruction in cycle k sees the first register's output when the pin's `sync_bypass` bit is set, and the third register's output otherwise. A level on `pins_in` in cycle k is therefore seen in cycle k+1 (bypassed) or k+3 (synchronised).
- The testbench drives `pins_in = (pins_out & pins_oe) | (external & ~pins_oe)`, the same pad rule `pgsim` uses.

**R2. Output priority.** This is datasheet §3.5.6.1.

- Level and direction are handled separately for each pin.
- Within one SM, side-set beats an OUT, SET or MOV write to the same pin.
- Across SMs, the highest-numbered SM wins.
- A pin nobody writes keeps its value.

**OUT_STICKY.** With OUT_STICKY set, an enabled SM re-asserts its most recent OUT, SET or MOV pin write in every cycle in which it makes no new one (datasheet §3.7: "the most recent OUT/SET"). The record is one write, whether to levels or to directions, kept as masks. A new write replaces the whole record. So a `set pindirs` after an `out pins` leaves only the direction write sticky. A pin write here means any completed `out pins`, `out pindirs`, `set pins`, `set pindirs` or `mov pins`. It replaces the record even when its pin count (OUT_COUNT or SET_COUNT) is 0. The record is then empty, and nothing is re-asserted until the next such write. Side-set writes are not OUT, SET or MOV writes. They never change the record. The re-asserted record counts as an OUT/SET/MOV write for R2, so a side-set write to the same pin in the same cycle beats it. It stops on SM_RESTART, and is not asserted while the SM is disabled. Writes by forced instructions count as new writes, and are recorded whether or not the SM is enabled. The record always tracks the most recent pin write, whether or not OUT_STICKY is set. OUT_STICKY controls only the re-assertion. So turning OUT_STICKY on, while the SM is disabled, and then enabling re-asserts the last write made before. **V1 item i.**

**R3. `!OSRE`** is true when OSR count < PULL_THRESH (datasheet §3.4.2.2). A threshold field of 0 means 32, for both thresholds.

**R4. PULL with autopull.** The PULL is a no-op when the OSR is full, which means OSR count = 0. Otherwise it behaves like a normal PULL, with IfEmpty and Block as usual. The datasheet defines "full" as a count of 0 (the §3.5.4 table "OSR Count (0=full)", and §3.4.8.2 "reset to 0, i.e. full"), and §3.5.4.2 says a PULL under autopull "becomes a no-op if the OSR is full". An OSR that is partly shifted out is not full, so a PULL then loads a fresh word, or stalls on an empty FIFO. This replaces the block 1 reading ("no-op while count < threshold"). **V1 items b and b2.**

**R5. OUT with autopull.** This follows the §3.5.4.2 pseudocode.

- When OSR count ≥ PULL_THRESH as the OUT executes:
  - If the TX FIFO is not empty, the OSR is refilled (count 0) and the OUT stalls on that tick with reason 3. It runs on its next tick.
  - If the TX FIFO is empty, the OUT stalls with reason 3 and sets TXSTALL.
- An OUT whose shift brings the count to PULL_THRESH or past it refills the OSR in the same cycle if TX is not empty. The shifted OSR value is then replaced.
- On any enabled tick that is not an OUT (a delay tick or a stalled tick included), OSR count ≥ PULL_THRESH with TX not empty refills the OSR. Forced-instruction cycles and disabled cycles do not refill. **V1 items c and f.**

**R6. IN with autopush.** An IN whose new count (saturating at 32) would reach PUSH_THRESH while the RX FIFO is full stalls with no state change. It sets RXSTALL, with stall reason 2. Otherwise it shifts, and if the count reached the threshold it pushes the ISR and clears the ISR and its count in the same cycle. **V1 item a.**

**R7. Non-blocking PUSH** into a full RX FIFO drops the data, sets RXSTALL, and clears both the ISR and its count (datasheet §3.4.6.2). A blocking PUSH into a full FIFO stalls and sets RXSTALL. A blocking PULL from an empty FIFO stalls and sets TXSTALL.

**R8. OUT PC and MOV PC** set the PC without the wrap rule, as JMP does (datasheet §3.4.5.2, §3.5.2).

**R9. IRQ timing.** WAIT IRQ and the IRQ instruction read the flags as they were at the start of the cycle, so a set is seen one cycle later. A set and a clear of the same flag in one cycle leave it set (§3.2.7). **V1 item d.**

**R10. Divider.** This applies datasheet §3.5.5 exactly, the same as the block 1 divider.

- D = 256·INT + FRAC, where INT = 0 means 65536.
- Each cycle: S = P + 256, `tick` = (S ≥ D), and P becomes S − D on a tick, otherwise S.
- The divider runs whether or not the SM is enabled. P resets to 0, and CLKDIV_RESTART sets it to 0. `dbg_phase` is P.
- **V1 item g.**

**R11. Side-set** applies once, on the instruction's first attempt, even if the instruction stalls (§3.2.4 note). It is not repeated on later stalled attempts. The IMEM instruction and the latched instruction each keep their own side-set-done flag, the same split as F3 and F5. A latched instruction is a forced (INSTR) or EXEC one. A new INSTR write, or an OUT/MOV EXEC completing, clears the latch's flag. So a latched instruction never changes the flag of the IMEM instruction it interrupts, and a stalled IMEM instruction's flag never suppresses the latched instruction's side-set.

**R12. Reserved words** run as a NOP and set ILLEGAL. The NOP keeps its delay and side-set field. The list is in DESIGN §9.1, and in block 2 it includes the three LCU extension encodings.

**R13. WAIT 1 IRQ** clears its flag in the cycle the condition is seen. That clear goes through H5, so a set in the same cycle wins (§3.4.3.2).

**R14. IRQ index.** For WAIT IRQ and IRQ, with REL set (bit 4), the flag is `(index & 4) | ((index + sm) & 3)`. Bit 3 set makes the word reserved (R12).

**R15. IRQ with wait** sets the flag on its first attempt, then stalls with reason 7 until the flag reads 0. Clear takes priority over wait when both bits are set (datasheet §3.4.9.2).

**Forced and EXEC instructions** (datasheet §3.5.7, §3.4.5.2):

- **F1. Forced instructions.** An instruction written to INSTR in cycle k is attempted in cycle k+1, whatever the divider, `sm_enable` or a pending delay. If it stalls, it stays latched and is retried every cycle.
  - Every cycle with a forced attempt replaces the SM's normal activity for that cycle. This covers the first attempt and every retry. In such a cycle there is no delay countdown, no EXEC or IMEM attempt, and no autopull refill.
  - The divider keeps running, so a tick that falls in such a cycle is used up. For example, a forced instruction that lands during a delay makes the delay end one tick later if that cycle was a tick. **V1 item f.**
  - The instruction's own delay field is ignored, and it never changes the delay counter.
  - It changes the PC only if it writes the PC (JMP, OUT PC, MOV PC). Otherwise the PC stays where it was.
- **F2. EXEC instructions.** `OUT EXEC` and `MOV EXEC` complete in their own cycle, ignore their own delay field, and latch the new instruction. That instruction runs on the SM's next enabled tick, uses its own delay, and does not advance the PC unless it writes it. It can stall and be retried on later ticks like any instruction.
- **F3. Stall reasons.** The engine keeps two:
  - The **IMEM reason** is written only by attempts of IMEM instructions (the stall's code on a stall, 0 on completion), and cleared by F6.
  - The **latch reason** is written only by attempts of latched (EXEC or forced) instructions, in the same way. A new INSTR write sets it to 0.
  - `DBG_CNT.stall_reason` shows the latch reason while it is non-zero, and the IMEM reason otherwise. So when a forced instruction completes, the IMEM reason shows in the same cycle.
  - The codes are in DESIGN §7. Codes 1 to 3 also cover the autopush and autopull stalls in R5 and R6.
- **F4. `EXEC_STALLED`** is 1 while a forced (INSTR) instruction is latched and its latest attempt stalled. It is 0 for EXEC-latched instructions.
- **F6. Abandoning the IMEM instruction.** Suppose a latched instruction (forced or EXEC) writes the PC: a taken JMP, OUT PC or MOV PC. Then the IMEM instruction that was in progress is abandoned. At the end of that cycle its side-set-done flag, its IRQ wait state and the IMEM stall reason are cleared, so the instruction at the new PC starts fresh. The delay counter is not touched (F1). This is how host code breaks an SM out of a stalled `wait` or `pull` with a forced `jmp`. **V1 item f.**
- **F7. Rewriting the word at the PC.** An IMEM write (H9) to the address equal to an SM's fetch address (§9: `{PAGE, PC}` with IMEM depth 64) abandons that SM's IMEM instruction as in F6. At the end of the write cycle its side-set-done flag, its IRQ wait state and the IMEM stall reason are cleared. This overrides anything the SM's own attempt in that cycle did to those three items. The SM then attempts the new word fresh. The address is compared with the PC at the start of the cycle, the delay counter is untouched, and the written value does not matter. Programs never rewrite a running instruction. The rule only makes the behaviour defined.
- **F5. IRQ wait states.** IMEM and latched instructions each have their own IRQ wait state, so a forced IRQ never takes over the wait of an IMEM IRQ instruction. Completing a latched instruction, or a new INSTR write, clears the latched one.

**Delay counter.** When an instruction completes on a tick with delay d, `DBG_CNT.delay` becomes d. Each later enabled tick with delay > 0 decrements it and executes nothing else. The next instruction is attempted on the first enabled tick on which delay is 0.

## 7. What the lockstep compares, every cycle

These are compared for each SM `i < num_sms`:

- `dbg_pc`, `dbg_x`, `dbg_y`, `dbg_isr`, `dbg_osr`, `dbg_cnt` (all four fields), `dbg_exec_stalled`, `dbg_phase`.

These are compared for the whole block:

- `pins_out`, `pins_oe`, `irq`, `fstat`, `flevel`, `fdebug`.
- `rxf_data` in every cycle (block 3; block 2 compared it only in cycles that present `rxf_pop`).
- `dbg_instr` for each SM `i < num_sms` (block 3).

A run fails on the first difference. The report gives the cycle, the port, both values, and the shrunk program, configuration and stimulus that reproduce it. Failures go to the RTL lane as shrunk cases, never as model code.

## 8. Generated Verilog

`hw/bin/gen_verilog.exe` with no argument prints the Tiny Tapeout top, as it does now. Called with `decode`, `pio_block` or `pio_block1`, it prints that module alone. `pio_block` has 4 SMs and `pio_block1` has 1, both with IMEM depth 64. These outputs feed Verilator lint, synthesis estimates and the proofs. Do not commit them. Block 3 adds `chip` and `hostlink` (chip.md §3).

## 9. Block 3: the 64-word instruction memory

- `pio_block` takes an IMEM depth of 32 or 64. `hw/pio_block.mli` keeps `val circuit : num_sms:int -> Hardcaml.Circuit.t`, now with depth 64, and adds `val circuit_with : num_sms:int -> imem_depth:int -> Hardcaml.Circuit.t`.
- With depth 64, SM n fetches `IMEM[{PAGE_n, PC_n}]`, where PAGE_n is bit 0 of `ext`n in the current cycle. PC, JMP targets, WRAP_TOP and WRAP_BOTTOM stay 5 bits and work inside the page (DESIGN §9.3). A change of PAGE takes effect on the next fetch, and changes nothing else.
- With depth 32, SM n fetches `IMEM[PC_n]`, and `ext`n and `imem_addr`[5] are ignored.
- The fetch address is what F7 compares with the write address, and what `dbg_instr` shows.
- IMEM is not reset (R0). It is write-only from the host (chip.md §8.1), so it needs only the engines' four read ports.
- With PAGE 0 and the program in words 0 to 31, a depth-64 block behaves exactly like the block 2 block. The block 2 corpus and generator still apply.
