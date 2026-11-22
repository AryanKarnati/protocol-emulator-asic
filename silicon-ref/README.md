# silicon-ref: capturing real PIO behaviour on a Pico 2

**Status: untested on hardware.** No board has run this code yet. The host-side decoder
and its tests run on a PC (`python3 silicon-ref/test_trace.py`). `capture.py` is checked on
a PC by `test_capture_mock.py`, which fakes the MicroPython modules and asserts the exact
register write sequence for one program. That shows what the script asks the hardware to
do. It does not show what the silicon does. Every register address and MicroPython API call
that has not been checked on a board is marked **[verify on hardware]**.

Purpose: DESIGN.md §17 V1. Run the same base-ISA program on a real RP2350 PIO and on
the team's model (`pgsim`), then compare the two pin traces cycle by cycle. The reference
is silicon, which no AI wrote (DESIGN.md §17.1).

## Files

| File | What it is |
| --- | --- |
| `capture.py` | MicroPython. Loads a program (pioasm `-o json`) on one PIO state machine and a sampler on a second SM of the same PIO block, DMAs the samples to RAM, writes a trace file. |
| `trace.py` | Pure Python 3. Reads and validates a trace, expands samples, prints or returns pin levels. Also writes the format, for tests. |
| `test_trace.py` | Host-side tests for `trace.py`. No hardware, no dependencies. |
| `test_capture_mock.py` | Host-side test for `capture.py`. Fakes `machine`, `rp2`, `time` and `uctypes`, and checks the register write order for the ws2812 corpus program. Also covers OUT_STICKY, host actions, and the batch dry run. No hardware. |
| `batch_capture.py` | MicroPython. Runs every job of a manifest with `capture.run`, one trace per job, and a `summary.json`. Also `--dry-run` on a PC, through the mock. |
| `make_batch.py` | PC, plain Python. Builds the manifest (every corpus program and every V1 config) and stages the board tree in `board_stage/` (git-ignored). |
| `v1/` | V1 capture programs (`v1_items.pio`, official pioasm JSON), capture configs, and `README.md` with the outcome-to-meaning tables. |
| `traces/` | Where the host copies traces from the board. Empty in git. |

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
    pins=dict(out_base=0, out_count=1, set_base=0, sideset_base=0,
              in_base=0, jmp_pin=0),
    capture_base=0,                             # sample GPIO 0..7
    samples=40000,                              # multiple of 4
    out_path="/trace.jsonl",
    # settings the JSON does not carry (see "Program configuration"); defaults are
    # the PIO reset values unless the program's JSON gives them
    set_count=5, clkdiv=(1, 0),
)
```

Then copy `/trace.jsonl` to the PC and run `python3 silicon-ref/trace.py trace.jsonl --head 32`.

## Program configuration: what comes from the JSON and what you pass

The pioasm JSON (`pioasm -o json`) does not carry most of the PIO configuration. The C SDK sets
it in C code (`pio_sm_config_set_*`), so pico-examples' JSON has it null. This was checked on
all 36 programs in `sw/pgasm/test/corpus` (pioasm 2.3.1): `in`, `out`, `setCount`,
`fifoConfig` and `clockDiv` are `null` in every one. The `pioasm` JSON schema is
`tools/pioasm/json_output_schema.json` in pico-sdk 2.3.1.

| Setting | From the JSON | Must be passed | If neither | Argument |
| --- | --- | --- | --- | --- |
| Instructions, wrap, wrap target | yes (`instructions`, `wrap`, `wrapTarget`) | no | n/a | |
| Entry point | `publicLabels.entry_point` if present | no | instruction 0 | |
| PIO version | `pioVersion` must be 0 | no | error if not 0 | |
| Side-set size, optional, pindirs | `sideset` (null = no side-set). `size` is the bits **including** the enable bit when `optional` (pioasm `json_output.cpp:159-162`, `sideset_bits_including_opt`) | only to override | 0 bits | `sideset_size`, `sideset_optional`, `sideset_pindirs` |

Side-set convention, used in both the JSON and the arguments: `sideset_size` is the JSON `size`.
It includes the enable bit when `sideset_optional` is true. SIDESET_COUNT in PINCTRL is this
value (`pio.h` `PIO_SM0_PINCTRL_SIDESET_COUNT`, "inclusive of the enable bit"). The data pins are
`size - 1` when optional, and they start at `sideset_base`. `.side_set 1 opt` gives size 2, one data
pin. `.side_set 1` gives size 1, one data pin. The trace header records `sideset_size` and
`sideset_data_pins`.
| Shift direction (IN, OUT) | `in.right`, `out.right`, only if the source has `.in`/`.out` | to override | right | `in_shift_right`, `out_shift_right` |
| Autopush, autopull | `in.autopush`, `out.autopull` (same condition) | to override | off | `autopush`, `autopull` |
| Push and pull thresholds | `in.threshold`, `out.threshold` (same condition) | to override | 32 | `push_thresh`, `pull_thresh` |
| FIFO join | `fifoConfig` (only with `.fifo`) | to override | none | `fifo_join` = `"none"`, `"tx"` or `"rx"` |
| SET count | `setCount` (null in corpus) | **yes** for any program that sets pins | 5 | `set_count` |

When `setCount` is null and `set_count` is not passed, the default 5 applies. That routes
`set_base..set_base+4` to PIO0, so those pads get the PIO function, even if the program only sets
fewer pins or none. That changes the pads' function only. A pad with PIO0 function is not driven
unless PIO sets its direction to output (the reset direction is input), so these pads are not driven
by the default alone. Pass `set_count=0` (or the real count) to keep them out of PIO. The mock tests
for `uart_tx` and `i2c` pass `set_count=0` for this reason.
| Clock divider | `clockDiv` (null in corpus) | **yes** unless the divider is 1.0 | 1.0 | `clkdiv=(int, frac)` |
| OUT, SET, side-set, IN base pins and OUT count, JMP pin | never | **yes** | n/a | `pins` dict (`out_base`, `out_count`, `set_base`, `sideset_base`, `in_base`, `jmp_pin`) |
| Initial pin levels and directions | never | only if the program needs them | pins as reset | `init_levels`, `init_dirs` |
| TX FIFO contents at start | never | only if the program reads its TX FIFO | empty | `tx_words` |

Each explicit argument wins over the JSON, and the JSON wins over the reset value. The header of
the trace records the values used (`program.config`, `program.init`), so a trace can be read
without the source.

## How the two state machines start together

- The program under test runs on SM0 and the sampler on SM1 (both configurable). Both are
  configured, flushed, and their PCs set while disabled.
- Both SMs start with **one write** to `PIO0 CTRL` that sets both SM_ENABLE bits. Both start
  on the same sysclk edge. The header records `ctrl_before` and `ctrl_after`.
- Order of writes in `run()` (checked by `test_capture_mock.py`):
  1. PIO0 and DMA are taken out of reset if held (RESETS, atomic CLR alias, wait for RESET_DONE).
  2. Both SMs disabled. FDEBUG sticky flags cleared.
  3. Instruction memory: program at 0, sampler instruction after it.
  4. CLKDIV, EXECCTRL, SHIFTCTRL, PINCTRL for both SMs.
  5. FIFO flush of both SMs: FJOIN_RX toggled twice, the same method as the SDK's
     `pio_sm_clear_fifos` (`pio.h`). A run never reads a word left over from an earlier run.
  6. Pads: PIO function, ISO and OD cleared, input enable on the sampled pins.
  7. `init_dirs`, then `init_levels`, through `SMn_INSTR` `set pindirs` / `set pins` with the SM
     disabled. As the SDK does (`pio_sm_set_consecutive_pindirs`). PINCTRL is restored after.
  8. `tx_words` written to the program SM's TX FIFO.
  9. `jmp <entry>` and `jmp <sampler>` written to `SMn_INSTR` to set the PCs.
  10. DMA channel armed for the sampler's RX FIFO.
  11. SM_RESTART and CLKDIV_RESTART for both SMs, still disabled. Done last, after all
      configuration and the jmp, immediately before the enable.
  12. The single enable write.
- The DMA channel is released in a `finally` block (`dma.close()`), on success and on timeout.
  Both SMs are stopped in the same `finally`.
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

## Pads and pins

- For every pin the program drives (out, set, side-set, and any `init_levels`/`init_dirs` pin) and
  every sampled pin, `capture.py` sets the PIO0 function and clears **ISO** and **OD**. ISO is
  pad isolation. It resets to 1 on RP2350, and an isolated pad reads 0, so without this the trace
  is flat. Bit positions are from `pads_bank0.h` (`PADS_BANK0_GPIO0_ISO_BITS` = 0x100,
  `PADS_BANK0_GPIO0_OD_BITS` = 0x80). [verify on hardware]
- Input enable (IE, bit 6) is set on the sampled group and on the pins the program reads through
  `jmp_pin` and `in_base`. The other pins of an `in` range are not enabled. A program that reads
  a wider range must have those pins enabled by hand, which is not written. [verify on hardware]

## Limits of the arguments

- `tx_words`: at most 4 words (8 with `fifo_join="tx"`). The CPU writes them to the TX FIFO
  before enable. A longer stream would need TX DMA, which is not written. Words beyond the FIFO
  depth are rejected before any register write.
- `init_levels`, `init_dirs`: pins 0..31 on PIO0 (GPIO base 0). Each `set` covers up to 5 pins in
  a run of consecutive pins. The SM must be disabled while they run (they are run before enable).
- `fifo_join`, `set_count`, `clkdiv` and side-set values are range-checked in `capture.py`. A bad
  value raises `ValueError` before any register write.
- Not supported (raises `NotImplementedError`): `origin` other than unset, `movStatus`, and every
  PIO v1 feature (`pioVersion` other than 0, `fifoConfig` for TXPUT/TXGET/PUTGET).

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
     SHIFTCTRL, PINCTRL), `pins` (the caller's pin bases), `config` (the resolved settings: clock
     divider, FIFO join, set count, side-set, shift and threshold values), and `init` (levels,
     directions and TX words written before enable).
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

### Format contract fixture (for pgsim's trace loader)

`testdata/uart_tx_example.jsonl` is the format contract for pgsim's trace loader. The loader should
read this file and get the same header fields, sample count and sample values. The file is:

- **Header**: built by `capture.run()` itself, run under the mock (`test_capture_mock.py`), so its
  fields and key order are the real ones. The program is corpus `uart_tx` (`.side_set 1 opt`):
  `sideset_size` 2 (enable bit included), `sideset_data_pins` 1, `registers` as the
  capture code computes them (PINCTRL `0x40100400`). `program.init` is non-empty:
  `tx_words` `["0x000000a5", "0x0000005a"]`, `levels` `{"0": 1, "1": 1}`, `dirs` `{"0": 1, "1": 1}`.
  `program.entry` is `0`, because uart_tx has no `entry_point` label.
- **Samples**: 1280 samples (320 words) of deterministic synthetic RX data, written by
  `trace.write_trace`. These are not captured from a pin. They exist to test the format.
- **Footer**: `complete: true`, `words_total` 320, `samples_total` 1280.
- **`program.source`** is rewritten to the repo-relative corpus path, not the workstation path.
  That is the only edit to the header.

The fixture is generated and checked by the mock suite. `test_fixture_is_current_and_has_init_and_entry`
regenerates it and compares it byte for byte with the committed file. If `capture.py`'s header
changes, regenerate with `python3 silicon-ref/test_capture_mock.py --write-fixture`, and review the
diff. A pgsim loader that does not read this file correctly does not match the format.

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
in `src/rp2350/hardware_regs/include/hardware/regs/` unless a row says otherwise. Each one still
needs a check on the board: **[verify on hardware]**. Section numbers in the RP2350 datasheet are
not cited here because they were not checked.

| Item | Address or offset | Field and source |
| --- | --- | --- |
| PIO0 base | `0x50200000` | `addressmap.h` `PIO0_BASE`. [verify on hardware] |
| CTRL | `PIO0 + 0x000` | `pio.h` `PIO_CTRL_OFFSET`. SM_ENABLE [3:0] (`CTRL_SM_ENABLE_LSB` 0), SM_RESTART [7:4] (LSB 4), CLKDIV_RESTART [11:8] (LSB 8). Restart bits are self-clearing (SC). [verify on hardware] |
| FDEBUG | `PIO0 + 0x008` | `pio.h` `PIO_FDEBUG_OFFSET`. RXSTALL [3:0], RXUNDER [11:8], TXOVER [19:16], TXSTALL [27:24]. Write 1 to clear; `capture.py` clears with 0x0F0F0F0F. [verify on hardware] |
| TXF0 | `PIO0 + 0x010` | `pio.h` `PIO_TXF0_OFFSET`. TXFn at +4n. Used for `tx_words`. [verify on hardware] |
| RXF0 / RXF1 | `PIO0 + 0x020` / `+ 0x024` | `pio.h` `PIO_RXF0_OFFSET`. RX FIFO of SM0 / SM1. [verify on hardware] |
| INSTR_MEM0 | `PIO0 + 0x048 + 4*n` | `pio.h` `PIO_INSTR_MEM0_OFFSET`. 32 instruction words. [verify on hardware] |
| SM0_CLKDIV | `PIO0 + 0x0c8` | `pio.h` `PIO_SM0_CLKDIV_OFFSET`. INT [31:16], FRAC [15:8]. SMn is at `+ 0x18*n`. [verify on hardware] |
| SM0_EXECCTRL | `PIO0 + 0x0cc` | `pio.h` `PIO_SM0_EXECCTRL_OFFSET`. SIDE_EN [30], SIDE_PINDIR [29], JMP_PIN [28:24], WRAP_TOP [16:12], WRAP_BOTTOM [11:7], OUT_STICKY [17] (never set here), STATUS_SEL [6:5], STATUS_N [4:0]. [verify on hardware] |
| SM0_SHIFTCTRL | `PIO0 + 0x0d0` | `pio.h` `PIO_SM0_SHIFTCTRL_OFFSET`. FJOIN_RX [31], FJOIN_TX [30], PULL_THRESH [29:25], PUSH_THRESH [24:20], OUT_SHIFTDIR [19], IN_SHIFTDIR [18], AUTOPULL [17], AUTOPUSH [16]. [verify on hardware] |
| SM0_INSTR | `PIO0 + 0x0d8` | `pio.h` `PIO_SM0_INSTR_OFFSET`. A write executes at once (the SDK's `pio_sm_exec`, `pio.h`). Used for `jmp <entry>`, `set pins`, `set pindirs`. [verify on hardware] |
| SM0_PINCTRL | `PIO0 + 0x0dc` | `pio.h` `PIO_SM0_PINCTRL_OFFSET`. SIDESET_COUNT [31:29] (includes the enable bit), SET_COUNT [28:26], OUT_COUNT [25:20], IN_BASE [19:15], SIDESET_BASE [14:10], SET_BASE [9:5], OUT_BASE [4:0]. [verify on hardware] |
| SET instruction | `0xE000 \| (dest << 5) \| data` | Opcode 111. Destination 0 = pins, 4 = pindirs (`pio_instructions.h`, `pio_pins`, `pio_pindirs`). [verify on hardware] |
| IO_BANK0 base | `0x40028000` | `addressmap.h` `IO_BANK0_BASE`. GPIOn_CTRL at `+4+8n`, FUNCSEL [4:0]. PIO0 = 6 (`rp2350/hardware_structs/include/hardware/structs/io_bank0.h`, `GPIO_FUNC_PIO0`). PIO2 = 8. [verify on hardware] |
| PADS_BANK0 base | `0x40038000` | `addressmap.h` `PADS_BANK0_BASE`. GPIOn pad at `+4+4n`. IE = bit 6 (`PADS_BANK0_GPIO0_IE_BITS`, 0x40). OD = bit 7 (`PADS_BANK0_GPIO0_OD_BITS`, 0x80). **ISO = bit 8** (`PADS_BANK0_GPIO0_ISO_BITS`, 0x100; reset value 1, `PADS_BANK0_GPIO0_ISO_RESET`). [verify on hardware] |
| RESETS base | `0x40020000` | `addressmap.h` `RESETS_BASE`. RESET at `+0x000` (`RESETS_RESET_OFFSET`, 1 = held), RESET_DONE at `+0x008` (`RESETS_RESET_DONE_OFFSET`). PIO0 = bit 11 (`RESETS_RESET_PIO0_BITS`), DMA = bit 2 (`RESETS_RESET_DMA_BITS`). Atomic clear is the `REG_ALIAS_CLR_BITS` (0x3 << 12) alias, `+0x3000`. [verify on hardware] |
| DREQ | RX0 = 4, RX1 = 5 | `dreq.h` `DREQ_PIO0_RX0`, `DREQ_PIO0_RX1`. The sampler uses `4 + sm`. [verify on hardware] |

Also [verify on hardware]: the MicroPython `rp2.DMA` API used in `capture.py`
(`pack_ctrl(size, inc_read, inc_write, treq_sel, irq_quiet, enable)`, `config(read, write,
count, ctrl)`, `active()`, `close()`; see the MicroPython `rp2.DMA` page) and `machine.mem32`
as a 32-bit read and write. `close()` releases the channel and the DMA object cannot be used
afterwards. The version of MicroPython on the board must be recorded with the trace.

## Tests

```
python3 silicon-ref/test_trace.py          # 11 tests, plain Python, no dependencies
python3 silicon-ref/test_capture_mock.py   # 20 tests, plain Python, mocked MicroPython
python3 silicon-ref/batch_capture.py --dry-run   # the whole batch under the mock (see "Batch")
python3 silicon-ref/test_capture_mock.py --write-fixture   # regenerate testdata/ (review the diff)
python3 -m pytest silicon-ref/             # the same tests under pytest, if installed
```

`test_trace.py` covers: the sample byte order and an independent ISR model of `in pins, 8`; file
round trip; pin levels; the warning path; and rejection of a missing or reordered word block, a
missing footer, a word count mismatch, an unknown format or version, and an incomplete capture.

`test_capture_mock.py` covers: the exact register write sequence for the ws2812 program (51 writes);
the single enable write coming straight after the restart; configuration and PC writes before the
restart; the pads, which start at the reset value 0x116 (`pads_bank0.h`), having ISO and OD cleared
(0x116 to 0x016) and IE added (0x056), so the other reset bits are kept; the FJOIN_RX flush before
the DMA is armed; a repeated run issuing the same writes; PIO0 and DMA taken out of reset; the DMA
closed and both SMs stopped on timeout; `tx_words` rejected before any write; and the override
path. The override path is a second program run (`tx_words=[1, 2]`, `init_dirs={0:1}`,
`init_levels={0:1,1:0,3:1}`, `fifo_join="tx"`, `out_shift_right=False`, `autopull=True`,
`pull_thresh=24`, `clkdiv=(2,128)`). Its key register values are checked explicitly, and its full
write sequence (59 writes) is frozen. The expected values are derived from the header bit positions
and are [verify on hardware]. The mock models the reset alias, write-1-to-clear of FDEBUG and the
pad reset value. It does not model the reset values of other registers, and it does not show on
silicon that the pad bits are preserved.

The optional side-set test (`uart_tx`, `.side_set 1 opt`) checks that the enable bit is counted once:
SIDESET_COUNT is 2, the side-set span is one data pin, and only that pin is routed. The fixture test
checks that `testdata/uart_tx_example.jsonl` is still what `capture.py` and `trace.write_trace`
produce, and that `trace.read_trace` loads it with `program.init` and `program.entry` present.

Neither test file covers silicon behaviour, which needs the calibration run.

## Host actions, OUT_STICKY and host pins (added for V1)

- `out_sticky=True` sets EXECCTRL bit 17 (OUT_STICKY) on the program SM. The header records
  `config.out_sticky` only when it is set, so the fixture bytes do not change.
- `host_pins=[(pin, level), ...]` drives those pins from the CPU through SIO (FUNCSEL 5, output
  enabled, SIO GPIO_OUT_SET and GPIO_OUT_CLR at 0x018 and 0x020, GPIO_OE_SET at 0x038; offsets checked
  in pico-sdk 2.3.1 `sio.h`, rp2350). The PIO still reads them as inputs, so they can be the source
  of an IN or a WAIT. They must not be pins the program drives.
- `host_actions=[(after_us, (kind, ...)), ...]`, done during the run, `after_us` after the enable write:
  - `("gpio", pin, level)`: set a host pin;
  - `("rx", n)`: read n words of the program SM's RX FIFO (recorded in `host.rx_words`);
  - `("tx", word)`: write the program SM's TX FIFO;
  - `("instr", hex_word)`: write SMx_INSTR for the program SM (a forced instruction).
  The header records the actions in `host.actions`, what was done in `host.log`, and the RX words.
  Timing is MicroPython's, so it is microseconds. An action that is still due when the DMA finishes
  raises `RuntimeError`, so it cannot be dropped silently. The landing cycle of an action must come
  from the trace (the pin it changes), not from `after_us`. `trace_cmp` (`sw/pgsim`) does not model
  host actions or host pins, so compare those traces by hand.

## Batch (every corpus program and every V1 config)

`make_batch.py` builds `manifest.json` and stages the board tree. `batch_capture.py` runs it on the
board. The job list is 36 corpus programs and 13 V1 configs. 12 V1 configs are runnable; `v1_h_pull_stall`
is marked `runnable: false` and skipped (see `v1/README.md`). Corpus jobs use a generic smoke setting
(pin 0 out, set count 0, clock divider 1.0, 4000 samples), so they are a first capture, not a checked
reference.

On the board, `run_batch` takes `groups` (`['v1']` or `['corpus']`), writes `summary.json` after every
job, removes the partial trace of a failed job, calls `gc.collect()` between jobs, and stops before a job
when free space is below `min_free_bytes` (default 300000), recording why in `summary.stopped`.

Dry run on the PC (the mock, no hardware):

```
python3 silicon-ref/make_batch.py                    # stages silicon-ref/board_stage/
python3 silicon-ref/batch_capture.py --dry-run       # 47 ok, 1 failed, 1 skipped (as of this commit)
python3 silicon-ref/batch_capture.py --dry-run --groups v1   # 12 ok, 1 skipped
```

The one failure is `corpus__pio__quadrature_encoder_substep__...`. Its 32 instructions plus the
capture instruction do not fit the 32-word instruction memory. `capture.py` rejects it (ValueError)
and the batch goes on. This is a documented known failure, not fixed. The fix would be the sampler on
PIO1 with both blocks started in one write (RP2350 `CTRL_NEXTPREV_SM_ENABLE`), which is not written.

The mock dry run checks the register writes and the trace format. It does not check the silicon.

## When the Pico 2 arrives

Status: nothing below has been run on a board. Work through it once. The [verify on hardware] items
are what the first run must confirm.

1. **Flash MicroPython first, on Windows.** The Pico 2 is an RP2350, so the BOOTSEL drive is called
   `RP2350`, not `RPI-RP2`. Hold BOOTSEL while plugging in, then copy the MicroPython UF2 to that
   drive. Use the RPI_PICO2 build from micropython.org (the Pico 2 build), not the Pico (RP2040)
   build. Doing this from Windows, before the board is attached to WSL, is simpler. The board reboots
   by itself. [verify on hardware: the UF2 file name, and that the build has `rp2.DMA`]
2. **Attach the Pico 2 to WSL2 (usbipd, Windows, admin PowerShell).**
   ```
   usbipd list                          # find the BUSID of the Raspberry Pi device (vendor 2e8a)
   usbipd bind --busid <BUSID>          # once per device
   usbipd attach --wsl --busid <BUSID>  # each time it is plugged in
   ```
   In WSL: `lsusb | grep -i 2e8a` should show the board, and `/dev/ttyACM0` should exist. If
   mpremote cannot open the port, add your user to `dialout` (`sudo usermod -aG dialout $USER`) and
   log in again.
3. **Install mpremote** (in WSL): `pip install mpremote`. Check the MicroPython version:
   `mpremote connect auto exec "import sys; print(sys.version)"`. Write the version in the record (step 8).
4. **Stage and copy the files, explicitly.** `mpremote fs cp -r` on a whole directory is not used,
   because a recursive copy into an existing destination nests the folder. Copy each file:
   ```
   python3 silicon-ref/make_batch.py
   mpremote connect auto fs cp silicon-ref/board_stage/capture.py :capture.py
   mpremote connect auto fs cp silicon-ref/board_stage/batch_capture.py :batch_capture.py
   mpremote connect auto fs cp silicon-ref/board_stage/manifest.json :manifest.json
   mpremote connect auto fs mkdir :prog
   mpremote connect auto fs mkdir :prog/v1
   mpremote connect auto fs mkdir :prog/corpus
   mpremote connect auto fs cp silicon-ref/board_stage/prog/v1/v1_items.pioasm.json :prog/v1/v1_items.pioasm.json
   mpremote connect auto fs cp silicon-ref/board_stage/prog/corpus/*.json :prog/corpus/   # only if the shell expands the glob
   ```
   If the shell does not expand the glob, copy the corpus files one by one (the manifest lists them).
   Check the free flash first: `mpremote connect auto exec "import os; print(os.statvfs('/'))"`.
   Free space is `f_frsize * f_bavail`. Each V1 trace is about 140 KB and the whole V1 run is about 1.7 MB.
5. **Calibrate first (V1 item e).** One capture, run by hand:
   ```
   mpremote connect auto exec "import capture; capture.run(program_json='/prog/v1/v1_items.pioasm.json', program_name='v1_e_calib', pins=dict(out_base=0,out_count=0,set_base=0,sideset_base=0,in_base=0,jmp_pin=0), capture_base=0, samples=40000, out_path='/calib.jsonl', set_count=1, clkdiv=(1,0), init_dirs={0:1}, init_levels={0:0})"
   mpremote connect auto fs cp :calib.jsonl silicon-ref/traces/calib.jsonl
   python3 silicon-ref/trace.py silicon-ref/traces/calib.jsonl --head 16 --pin 0
   ```
   The first rise of pin 0 is at sample `1 + L`, so `L` is that sample minus 1. Record it in
   `silicon-ref/v1/README.md` (item e). Do not use the value 3 unless the trace shows it.
6. **Run the V1 group first, on its own.** It is small, so it can be fetched and deleted before the
   corpus run:
   ```
   mpremote connect auto exec "import capture, batch_capture; print(batch_capture.run_batch(capture, '/manifest.json', '', '/traces', groups=['v1']))"
   ```
   Expect 12 `ok` and 1 `skipped` (`v1__v1_h_pull_stall`, by design). Any `failed` entry must be
   written up. If `exec` times out, put the same call in a one-line file and run it with
   `mpremote connect auto run <file>`.
7. **Fetch V1 and free the flash:**
   ```
   mpremote connect auto fs cp -r :traces silicon-ref/
   mpremote connect auto fs rm -r :traces
   ```
   `silicon-ref/traces/` then holds `v1__*.jsonl` and `summary.json`. Then run the corpus group
   (same call with `groups=['corpus']`), fetch it the same way, and delete it.
   The corpus group has 36 runnable corpus jobs: 35 expected ok, and 1 expected to fail, `corpus__pio__quadrature_encoder_substep__...`,
   which does not fit IMEM. Corpus traces use a generic smoke setting, so they are not a checked
   reference yet.
8. **Compare with the model** (V1 traces without host actions or host pins). Build the tool once:
   ```
   ~/.local/bin/opam exec --switch=polyglot -- dune build --root . ./sw/pgsim/tools/trace_cmp.exe
   ./_build/default/sw/pgsim/tools/trace_cmp.exe --latency L silicon-ref/traces/v1__v1_g_frac_div.jsonl
   ```
   `L` is from step 5. Exit 0 means no mismatch in the compared samples. Exit 1 prints the first
   mismatch (sample, pin, silicon and model values). Exit 2 means the trace was rejected. Run it on
   `v1__v1_b_pull_autopull`, `v1__v1_b2_pull_full`, `v1__v1_c_first_out`, `v1__v1_d_irq_wait`,
   `v1__v1_e_calib`, `v1__v1_g_frac_div`, `v1__v1_i_out_sticky_on`, `v1__v1_i_out_sticky_off`, and the
   corpus traces. Traces with host actions (`v1__v1_a_autopush`, `v1__v1_f_*`) are read by hand, as
   `silicon-ref/v1/README.md` says. `trace_cmp` does not model their host writes.
9. **Record the result** in `silicon-ref/v1/README.md` for each item: the trace file, the MicroPython
   version (step 3), `L`, and which row of the table matched.
