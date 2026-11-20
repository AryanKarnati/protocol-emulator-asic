# silicon-ref: capturing real PIO behaviour on a Pico 2

**Status: untested on hardware.** No board has run this code yet. The host-side decoder
and its tests run on a PC (`python3 silicon-ref/test_trace.py`). `capture.py` has only
been dry-run against a mocked MicroPython API. Every register address and MicroPython
API call that has not been checked on a board is marked **[verify on hardware]**.

Purpose: DESIGN.md §17 V1. Run the same base-ISA program on a real RP2350 PIO and on
the team's model (`pgsim`), then compare the two pin traces cycle by cycle. The reference
is silicon, which no AI wrote (DESIGN.md §17.1).

## Files

| File | What it is |
| --- | --- |
| `capture.py` | MicroPython. Loads a program (pioasm `-o json`) on one PIO state machine and a sampler on a second SM of the same PIO block, DMAs the samples to RAM, writes a trace file. |
| `trace.py` | Pure Python 3. Reads and validates a trace, expands samples, prints or returns pin levels. Also writes the format, for tests. |
| `test_trace.py` | Host-side tests for `trace.py`. No hardware, no dependencies. |

## Set-up on the board

1. Build the program under test with the pioasm oracle (`sw/pgasm/oracle/build_pioasm.sh`)
   or pgasm, and write `pioasm -o json prog.pio prog.json` output to the Pico's flash
   (for example `/prog.json`). The JSON must contain the `programs` array.
2. Copy `capture.py` to the board.
3. Wire nothing extra for the common case. The sampler reads the same pads the program
   drives, through the PIO input path (loopback). Pins the program only reads can be
   driven from outside, but the sampled group must be contiguous (8 pins, see below).
4. Run from the MicroPython REPL:

```python
import capture
capture.run(
    program_json="/prog.json",
    program_name=None,                          # first program in the file
    pins=dict(out_base=0, out_count=1, set_base=0, set_count=1,
              sideset_base=0, in_base=0, jmp_pin=0),
    capture_base=0,                             # sample GPIO 0..7
    samples=40000,                              # multiple of 4
    out_path="/trace.jsonl",
)
```

Then copy `/trace.jsonl` to the PC and run `python3 silicon-ref/trace.py trace.jsonl --head 32`.

Supported program features: pioasm v0 programs, side-set (optional or not, pindirs or not),
wrap, clock divider, `.in`/`.out` shift settings from the JSON, `set`/`out`/side-set pin
bases given by the caller, FIFO join TX or RX. Not supported (raises `NotImplementedError`):
`origin` other than unset, `movStatus`, and every PIO v1 feature.

## How the two state machines start together

- The program under test runs on SM0 and the sampler on SM1 (both configurable). Both are
  configured and their PCs set (by writing `jmp <entry>` to `SMn_INSTR`) while disabled.
- The DMA channel is armed before either SM runs, so the RX FIFO is drained from the first word.
- Both SMs start with **one write** to `PIO0 CTRL` that sets both SM_ENABLE bits. Both start
  on the same sysclk edge. The header records `ctrl_before` and `ctrl_after`.
- **Fixed offset.** Sample `k` is the sampler's `in pins` on sysclk cycle `k` after the start
  write, so the offset between the two SMs is 0 cycles by construction. The program's cycle 0 is
  the same cycle. The sampler sees a pad change only after the input synchroniser delay and the
  PIO's own output path. Those delays are not subtracted in the file. They are measured by
  calibration (below). [verify on hardware]
- The sampler's clock divider is exactly 1.0 (`INT=1, FRAC=0`), so it samples every sysclk.
  The program under test may use any divider. Its cycle count is then not the same as sysclk,
  and the model must use the divider.
- The sampler stops with one CTRL write after the DMA has moved all words. It can run a few
  cycles more, but its RX FIFO then fills and it stalls, so no extra samples are kept.

## Sampler program and sample size

- Sampler program: one instruction, `in pins, 8`, wrapping onto itself (WRAP_TOP = WRAP_BOTTOM =
  its own address). Encoding 0x4008. pioasm 2.3.1 assembles `in pins, 8` to `4008`
  (checked with `pioasm -o hex`).
- IN shifts right, with autopush at 32 bits. Every cycle one 8-bit sample enters the ISR,
  so one 32-bit word is pushed every 4 cycles.
- **Why 8 pins.** A 4-deep RX FIFO gives 16 cycles of slack for the DMA to take each word. At
  8 pins the DMA request rate is sysclk/4, so at the default 150 MHz sysclk the word rate is
  37.5 Mword/s (150 MB/s), and one DMA channel should keep up. [verify on hardware]
- Limits: 16 pins gives 2 samples per word, so 75 Mword/s at 150 MHz, which is about the DMA
  limit and is untested. Making the sampler's RX FIFO 8 deep (FJOIN_RX on the sampler SM, which
  is allowed because the sampler never uses its TX FIFO) doubles the slack. Not done yet.
- RAM: the buffer is 1 byte per sample. The RP2350 has 520 KB of SRAM, so a capture is limited to
  roughly 200k samples of 8 pins. Longer runs need streaming to flash or SD, which is not written.
- The FDEBUG RXSTALL bit of the sampler SM is recorded in the footer. The sampler keeps running
  until the stop write, so its FIFO fills and it stalls after the last DMA read. That stall is
  expected. The footer's `rxstall_capture` is therefore a warning, not proof of loss, and it
  cannot tell an early stall from the expected one. Proof of no loss needs the calibration run.

## Trace format (JSON lines, UTF-8)

One JSON object per line. Records are in this order.

1. **Header** (`"record": "header"`):
   - `format`: `"polyglot-pio-silicon-trace"`, `version`: `1`.
   - `device`, `sysclk_hz`.
   - `pio`: `{"block": 0, "base": "0x50200000"}`.
   - `program`: `name`, `pio_version`, `offset` (always 0), `entry`, `words` (the 16-bit
     instruction words as `"0x%04x"`), `registers` (the values written to CLKDIV, EXECCTRL,
     SHIFTCTRL, PINCTRL), and `pins` (the caller's pin bases).
   - `capture`: `sm`, `offset` (the sampler's instruction address), `word`, `pins_base`,
     `pins_count` (8), `bits_per_sample` (8), `samples_per_word` (4), `clkdiv`, `fifo_read_addr`,
     `dreq`.
   - `start`: `method`, `ctrl_before`, `ctrl_after`, `sample0_cycle` (0),
     `program_to_capture_offset_cycles` (0), and a `note`.
2. **Word blocks** (`"record": "words"`): `first_word` (index of the first 32-bit word) and
   `words` (up to 256 hex strings `"0x%08x"`). Word `w` holds samples `4w` to `4w+3`. Blocks are
   contiguous, with no gaps or reordering.
3. **Footer** (`"record": "footer"`): `words_total`, `samples_total`, `fdebug` (value read after
   the run), `rxstall_capture` (bool), and `complete: true`. A file with no footer or with
   `complete` false is an incomplete capture and is rejected.

### Sample order

Sample `k` = `(word[k // 4] >> (8 * (k % 4))) & 0xFF`. Bit `j` of a sample is the level of
GPIO `pins_base + j`. This follows from IN shift right: the first sample of a word ends in bits
7:0. `trace.py` implements this, and `test_trace.py` checks it against an independent model of
the ISR.

Sample `k` is read on sysclk cycle `k` after the start write. Time = `k / sysclk_hz`.

## Calibration (do this first, on the board)

Before any comparison with `pgsim`, measure the input latency:

1. Program under test: a free-running square wave on GPIO 0, e.g. `set pins, 1 [7]` then
   `set pins, 0 [7]` with a wrap, at clkdiv 1.
2. Capture 1000 samples. The transitions in the trace should fall every 16 cycles.
3. Measure the offset between the program's first transition and the first observed edge.
   That offset is the input and output latency. Record it in the header or in `trace.py` as a
   constant, and do not guess it.
4. Repeat with clkdiv 2 and 3, to confirm the sampler and the program share the same timebase.

Until the calibration is run, the claim "sample k is sysclk cycle k" is unverified.

## Register addresses

All addresses are from the pico-sdk 2.3.1 register headers, checked against the RP2350 headers
in `src/rp2350/hardware_regs/include/hardware/regs/`. Each one still needs a check on the
board: **[verify on hardware]**. Section numbers in the RP2350 datasheet are not cited here
because they were not checked.

| Item | Address or offset | Field and source |
| --- | --- | --- |
| PIO0 base | `0x50200000` | `addressmap.h` `PIO0_BASE`. [verify on hardware] |
| CTRL | `PIO0 + 0x000` | `pio.h` `PIO_CTRL_OFFSET`. SM_ENABLE [3:0], SM_RESTART [7:4], CLKDIV_RESTART [11:8]. [verify on hardware] |
| FDEBUG | `PIO0 + 0x008` | RXSTALL [3:0], write 1 to clear. [verify on hardware] |
| RXF0 / RXF1 | `PIO0 + 0x020` / `+ 0x024` | RX FIFO of SM0 / SM1 (one per SM). [verify on hardware] |
| INSTR_MEM0 | `PIO0 + 0x048 + 4*n` | 32 instruction words. [verify on hardware] |
| SM0_CLKDIV | `PIO0 + 0x0c8` | INT [31:16], FRAC [15:8]. SMn is at `+ 0x18*n`. [verify on hardware] |
| SM0_EXECCTRL | `PIO0 + 0x0cc` | SIDE_EN [30], SIDE_PINDIR [29], JMP_PIN [28:24], WRAP_TOP [16:12], WRAP_BOTTOM [11:7], STATUS_SEL [6:5], STATUS_N [4:0]. [verify on hardware] |
| SM0_SHIFTCTRL | `PIO0 + 0x0d0` | FJOIN_RX [31], FJOIN_TX [30], PULL_THRESH [29:25], PUSH_THRESH [24:20], OUT_SHIFTDIR [19], IN_SHIFTDIR [18], AUTOPULL [17], AUTOPUSH [16]. [verify on hardware] |
| SM0_INSTR | `PIO0 + 0x0d8` | Writing executes an instruction at once. Used for `jmp <entry>`. [verify on hardware] |
| SM0_PINCTRL | `PIO0 + 0x0dc` | SIDESET_COUNT [31:29] (includes the enable bit), SET_COUNT [28:26], OUT_COUNT [25:20], IN_BASE [19:15], SIDESET_BASE [14:10], SET_BASE [9:5], OUT_BASE [4:0]. [verify on hardware] |
| IO_BANK0 base | `0x40028000` | `addressmap.h`. GPIOn_CTRL at `+4+8n`, FUNCSEL [4:0]. PIO0 = 6 (`io_bank0.h` `GPIO_FUNC_PIO0`). PIO2 = 8. [verify on hardware] |
| PADS_BANK0 base | `0x40038000` | `addressmap.h`. GPIOn pad at `+4+4n`. IE = bit 6, OD = bit 7. [verify on hardware] |
| DREQ | RX0 = 4, RX1 = 5 | `dreq.h` `DREQ_PIO0_RX0`, `DREQ_PIO0_RX1`. The sampler uses `4 + sm`. [verify on hardware] |
| RESETS | `0x40020000`, PIO0 bit `0x800` | `resets.h` `RESETS_RESET_PIO0`. `capture.py` assumes PIO0 is already out of reset (assumed, not checked). It does not write RESETS. [verify on hardware] |

Also [verify on hardware]: the MicroPython `rp2.DMA` API used in `capture.py`
(`pack_ctrl(size, inc_read, inc_write, treq_sel, irq_quiet, enable)`, `config(read, write,
count, ctrl)`, `active()`) and `machine.mem32` as a 32-bit read and write. The version of
MicroPython on the board must be recorded with the trace.

## Tests

```
python3 silicon-ref/test_trace.py      # 11 tests, plain Python, no dependencies
python3 -m pytest silicon-ref/          # same tests under pytest, if installed
```

The tests cover: the sample byte order and an independent ISR model of `in pins, 8`; file
round trip; pin levels; the warning path; and rejection of a missing or reordered word block,
a missing footer, a word count mismatch, an unknown format or version, and an incomplete
capture. They do not cover silicon behaviour, which needs the calibration run.
