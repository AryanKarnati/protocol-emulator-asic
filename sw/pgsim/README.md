# pgsim: golden model of the PIO block (block 1, base ISA)

`pgsim.ml` / `pgsim.mli` model one RP2040-style PIO block: four state machines, one shared
instruction memory, the device-level IRQ flags and pad priority. One call to `Pgsim.step`
is one system clock cycle. The source is RP2040 datasheet section 3 (PIO), downloaded to
`~/.cache/polyglot/rp2040-datasheet.pdf`. Comments in the code cite the section for each
rule. Where the datasheet is silent or ambiguous, the code says `AMBIGUITY` and the choice
is listed below.

The model is written from the datasheet and the team's contract (`docs/gate.md`,
DESIGN.md), not from RTL. Block 2 compares it with the RTL and with silicon.

## Files

| File | What it is |
| --- | --- |
| `pgsim.ml`, `pgsim.mli` | The model, and the interface block 2 locks to |
| `pioasm_json.ml` | Loader for pioasm JSON (corpus format), and `apply_to_config` |
| `vcd.ml` | VCD writer: pads, pad OE, per-SM pc, x, y, isr, osr, stall code |
| `silicon_trace.ml` | Loads a silicon trace (capture.py header) and compares it with the model |
| `cli/pgsim_cli.ml` | Runner, executable `pgsim_cli` |
| `tools/trace_cmp.ml` | `trace_cmp --latency L TRACE.jsonl`, cycle-by-cycle comparison |
| `test/test_pgsim.ml` | Expect tests, `dune test --root .` |

## Interface summary

- `Pgsim.create`, `load_program`, `set_config` (RP2040 register layout via
  `Config.of_registers` and the `*_register` encoders), `set_enabled`, `step`.
- Host operations: `write_tx`, `read_rx`, `write_instr` (SMx_INSTR), `sm_restart`,
  `clkdiv_restart`, `clear_irq`.
- Observation: `pads` returns `(level, oe)` at the start of the cycle. `debug` returns the
  per-SM view: pc, x, y, isr and osr with their counts, FIFO contents and levels, delay,
  divider accumulator, stall reason, enable, illegal, pending latch (EXEC or host), IRQ
  wait, side-set state (for the instruction and for a forced one), OUT_STICKY state, and
  the four FDEBUG flags.
- `stall_code` maps each stall to the DESIGN §7 `DBG_CNT.stall_reason` code: 0 none, 1
  tx_empty, 2 rx_full, 3 autopull, 4 wait_gpio, 5 wait_pin, 6 wait_irq, 7 irq_wait. DESIGN §7
  names the field but does not give the encoding. This is a choice for the owner to confirm.

## Ambiguity choices

Each item gives the datasheet text (RP2040 datasheet section 3, paraphrased where marked),
then the choice in the model.

1. **Pad and input latency.** §3.5.6.1: "when bypassing synchronisers, a two-cycle delay ...
   when synchronisers are engaged, a four-cycle delay". §3.5.6.3: the synchroniser "adds two
   cycles of latency to input sampling". The stage is not given. *Choice:* a write in cycle
   c is on the pad in cycle c+1. IN, JMP PIN, WAIT GPIO and WAIT PIN see the pad from one
   cycle back when the pin is in `INPUT_SYNC_BYPASS`, and from three cycles back otherwise.
   The `trace_cmp --latency` for the Pico 2 is therefore expected to be about 3.
2. **!OSRE.** §3.4.2.2: "!OSRE compares the bits shifted out since the last PULL with the
   shift count threshold". *Choice:* the OSR is empty when its count is at or above the
   pull threshold, as for autopull.
3. **PULL under autopull.** §3.5.4.2: "it becomes a no-op if the OSR is full". *Choice:* the
   OSR is full while its count is below the threshold. With autopull a PULL is then a no-op,
   and otherwise it pulls from TX, or stalls, or copies X when non-blocking.
4. **OUT refill stall.** §3.5.4.2 pseudocode: when the count is at threshold and TX is not
   empty, the OUT pulls, then stalls (`stall` after the `if`). *Choice:* the stall happens
   on the refill cycle too, and the OUT runs on the next cycle.
5. **Autopush IN order.** §3.5.4.1 pseudocode: the shift happens, then the stall if RX is
   full. Re-executing the IN would shift twice. *Choice:* check for a full RX FIFO before
   shifting, so the IN stalls with no state change. **V1 item a.**
6. **Non-blocking PUSH into a full RX FIFO.** §3.4.6.2: "The ISR is still cleared to
   all-zeroes, and the FDEBUG_RXSTALL flag is set". The count clear is not stated.
   *Choice:* the ISR count is cleared too.
7. **OUT PC and MOV PC and wrap.** §3.4.5.2: "OUT PC behaves as an unconditional jump". The
   wrap rule in §3.5.2 names "the current instruction is a JMP". *Choice:* OUT PC and MOV PC
   set the PC without the wrap rule, as jumps do.
8. **Forced instruction (SMx_INSTR) timing.** §3.2.2 and §3.5.7: forced instructions
   "execute immediately, ignoring the state machine clock divider", and "Delay cycles are
   ignored on instructions written to the INSTR register". DESIGN.md §8.2 says "on the next
   tick". *Choice:* the datasheet. A forced instruction runs in the next system cycle,
   ignores the divider and the enable, ignores its own delay, and does not change a pending
   delay of the interrupted instruction. While it is latched it blocks the SM's normal
   execution. **The DESIGN §8.2 wording conflicts with this and is logged for the owner.**
9. **IRQ visibility and set against clear.** §3.2.7: "When a flag is both set and cleared
   on the same cycle, the set takes precedence and the clear is ignored". §3.4.9.3: "results
   in it being set". *Choice:* set wins. WAIT and IRQ read the flags as they were at the
   start of the cycle, so a set is visible one cycle later. The datasheet does not say when
   a set becomes visible. **V1 item d.**
10. **Divider phase.** §3.5.5: "a steady state division rate of n + f/256", with the
    fractional part spread by an accumulator. The phase after enable or restart is not
    given. *Choice:* the same accumulator as `docs/gate.md`, so the first tick after a
    restart falls where that contract puts it. **V1 item g.**
11. **Side-set on a stall.** §3.2.4 note: "Side-set is not affected by stalls, and always
    takes place on the first cycle of the attached instruction." *Choice:* applied once, on
    the first attempt, including when the instruction then stalls. It is not repeated on
    later stalled cycles.
12. **WAIT IRQ index bit 3.** The datasheet index is "the 3 LSBs" plus the MSB rel flag, and
    bit 3 is not described. *Choice:* taken from the isa library, where bit 3 is reserved,
    so the word is illegal and runs as a NOP that sets ILLEGAL.
13. **Reserved words.** The datasheet does not say what the delay and side-set bits of a
    reserved word do. *Choice:* the word runs as a NOP that keeps its delay and side-set
    field, and sets the sticky ILLEGAL flag. The ILLEGAL flag is a model addition
    (DESIGN.md §9.1).
14. **IN source 100 and 101 (lcu and status).** §3.4.4.2 marks 100 and 101 "Reserved".
    *Choice:* with `Isa.is_legal` false for `in status`, the word is a NOP with ILLEGAL. `in
    lcu` raises "LCU not modelled until block 5".
15. **WAIT IRQ with polarity 1 clears the flag.** §3.4.3.2: "If Polarity is 1, the selected
    IRQ flag is cleared by the state machine upon the wait condition being met." *Choice:*
    the clear happens in the cycle the condition is seen, with the same set-over-clear rule
    as item 9.

## V1: what the silicon capture must settle

Each item says what capture would decide it. V1 uses the Pico 2 (RP2350), so the RP2350
layout differences apply (see below).

- **a. Autopush order.** Capture an IN with autopush into a full RX FIFO and compare the
  ISR and the stall timing with a stall-then-shift model and a shift-then-stall model.
- **b. PULL under autopull.** Capture a PULL executed while the OSR still holds unshifted
  data, with TX non-empty, and see whether the TX word is consumed.
- **c. The first OUT after reset.** The OSR count resets to 32, so the first OUT with
  autopull and a TX word stalls once. Capture the cycle count of that first OUT.
- **d. IRQ visibility, and set against clear in one cycle.** Two SMs, one raising a flag and
  one clearing it in the same cycle, plus a WAIT on the flag in the next cycle. Capture
  which cycle the wait completes in.
- **e. Pad and synchroniser latency.** Calibrate with the sampler, as silicon-ref's README
  says. Expected `trace_cmp --latency` about 3 with the synchroniser on (item 1).
- **f. Forced instruction interactions.** Force a set pins during a delay, during a side-set
  stall, and during an IRQ wait. Capture whether the delay continues, whether the side-set
  is repeated, and whether the wait survives. Also whether a forced instruction counts as a
  non-OUT cycle for the autopull rule (datasheet 3.5.4.2). The model does not count it.
- **g. Divider phase after a restart.** Restart the divider at a known point with a
  fractional divisor, and capture the first tick.
- **h. TX write visibility to a stalled PULL.** Write the TX FIFO in the cycle a blocking
  PULL is stalled on, and capture the cycle the PULL completes in. The model completes it
  on the next cycle.
- **i. OUT_STICKY.** Capture a program that sets OUT_STICKY and then stops writing pins. The
  model re-asserts the last OUT or SET write each enabled cycle, until SM_RESTART. Silicon
  behaviour across a stall or a side-set is unknown.

Also on the V1 list: whether delay cycles, a disabled SM, and forced-instruction cycles count
as non-OUT cycles for autopull. The model counts enabled, ticked, non-OUT cycles, including
delay and stalled cycles, and does not count disabled or forced cycles.

## Not modelled

- LCU instructions (`in lcu`, `mov ..., crc`, `set lcu`). They raise.
- `INLINE_OUT_EN` and `OUT_EN_SEL`: **ignored**. `Config.of_registers` drops them. A program
  that depends on them will not match.
- `EXT` and `PAGE`, the 64-word IMEM, and any other PIO version (`pioVersion` other than 0).
- Output-only and input-only pad rules (DESIGN §5, block 3). The model has one pad
  level and one OE per pin, with no pad-type restrictions.
- Host IRQ set (only write-1-to-clear is modelled), host reads of FSTAT pin direction, and
  the host link.
- RP2350-only features: `FJOIN_RX_PUT/GET` (SHIFTCTRL 15:14), `STATUS_SEL` = IRQ, STATUS_N
  above 15, the PIO version 1 instructions (MOV PINDIRS, PREV/NEXT, MOV RXFIFO, JMP PIN
  wait, and so on). `silicon_trace` fails loudly on these.
- `movStatus` in the pioasm JSON, and `fifoConfig` for PIO v1 TXPUT/TXGET/PUTGET.
- `INT = 0` (divisor 65536) is modelled but not tested.

## RP2350 register layout

The traces come from a Pico 2 (RP2350). The header registers are in the RP2350 layout, which
differs from RP2040 in EXECCTRL STATUS_SEL (bits 6:5, values 0 TXLEVEL, 1 RXLEVEL, 2 IRQ) and
STATUS_N (bits 4:0). `Silicon_trace.rp2350_execctrl_to_rp2040` converts those fields and
fails on IRQ or N above 15. SHIFTCTRL, PINCTRL, CLKDIV, the CTRL restart bits and every other
EXECCTRL field have the same positions in both, checked against the RP2350 `pio.h` in the
pico-sdk cache.

## Findings for other lanes

- `silicon-ref/capture.py` computes SIDESET_COUNT as `size + optional`. pioasm's JSON `size`
  already includes the enable bit (uart_tx with `.side_set 1 opt` gives `size: 2`). The
  fixture's pinctrl 0x40100400 has SIDESET_COUNT 2, which is the correct value. The
  capture.py formula gives 3 for that program, so the capture script is wrong here.
- DESIGN.md §8.2 says forced instructions run "on the next tick". The datasheet says
  "immediately, ignoring the clock divider" (item 8).
- DESIGN.md §7 names `DBG_CNT.stall_reason` without an encoding (see Interface summary).
