# ws2812: WS2812 LED serial output

## Source

- `ws2812.pio`: unmodified copy of `pio/ws2812/ws2812.pio` from raspberrypi/pico-examples, tag
  `sdk-2.3.1` (commit `0d62f75bafc2c8120d3276c3343d1a9195e909e9`, see `sw/pgasm/test/corpus/MANIFEST.md`).
  BSD-3-Clause header kept; licence text in `programs/LICENSE.pico-examples.TXT`. The file has two
  programs. This directory tests `ws2812`, the first one.
- `ws2812.pioasm.json`: official pioasm 2.3.1 output for the whole file (both programs).
- `ws2812.json`: pgasm output for the whole file. Must equal `ws2812.pioasm.json`.

## Fixed configuration (`ws2812.config.json`)

| Setting | Value | Why |
| --- | --- | --- |
| Clock divider | 2.0 (`clkdiv` 0x00020000) | One bit is 10 ticks = 20 sysclk cycles |
| PINCTRL | 0x24000000 | SIDESET_COUNT 1 (not optional), SET_COUNT 1 (for `set pindirs`), OUT_COUNT 0 (the program uses OUT X, not pins), bases 0 |
| SHIFTCTRL | 0x70060000 | FJOIN_TX (C SDK `PIO_FIFO_JOIN_TX`), autopull on, pull threshold 24, OUT shifts left (MSB first), IN right. From `sm_config_set_out_shift(&c, false, true, 24)` and `sm_config_set_fifo_join` |
| EXECCTRL | from the JSON | Wrap and wrap target, SIDE_EN 0 (not optional) |
| Side-set pin | GPIO 0 | `sm_config_set_sideset_pins` |

Stimulus, as passed to `pgsim_cli`:

- `--init-instr e081` (`set pindirs, 1`): pin 0 is an output, as `pio_sm_set_consecutive_pindirs` does.
- `--tx 0xa55a0f00 --tx 0x00008100`: two pixels, each shifted into the top 24 bits of a word (the C SDK
  does `pixel << 8`). Pixel 1 is GRB 0xA55A0F. Pixel 2 is GRB 0x000081. The low 8 bits are discarded.
- `--cycles 1000`, `--trace`: one line per sysclk cycle.

## What the trace should show

Each bit is 10 PIO ticks (`out` 4 ticks, then `jmp` plus delay, 3 ticks, and so on) = 20 cycles.

- A `1` bit: high for 6 ticks (12 cycles), then low for 4 ticks (8 cycles).
- A `0` bit: high for 3 ticks (6 cycles), then low for 7 ticks (14 cycles).

Bit k of the 48 bits starts at cycle 4 + 20k, and its rising edge is at 12 + 20k. The bit values are
MSB first from each word, bits 31..8, so the 48 bits are the 24 bits of pixel 1 then the 24 bits of pixel 2.

Checked by hand against `ws2812.trace`:

- Bits 0-7 of pixel 1 (1,0,1,0,0,1,0,1): rising edges at 12, 32, 52, 72, 92, 112, 132, 152 (the
  high length of 12 is a `1`, 6 is a `0`). Bits 8-15 (0,1,0,1,1,0,1,0) follow at 172 through 312.
  Bits 16-23 (0,0,0,0,1,1,1,1) are 0x0F, the low byte of pixel 1 in GRB.
- The 24-bit boundary (k = 24, pixel 2 bit 31) is 20 cycles after k = 23, with no gap. The autopull
  refill does not stretch the bit in the model.
- Pixel 2 is 0x000081, so its 24 bits are sixteen 0s then 1000 0001. Bits k = 24 to 39 are short
  pulses (6 cycles high, rising edges at 492, 512, ..., 792). Bit k = 40 (rising edge at 812) is long,
  bit k = 47 (rising edge at 952) is long, and the pin is low again at 964. Nothing follows.
- After bit 47 the autopull stalls (TX empty) with the pin low. The final stall reason in the trace
  summary is `autopull`.

Read back the pixel bits from the trace with an independent check (not committed): sampling each bit
at its start gives 1010 0101 0101 1010 0000 1111 0000 0000 0000 0000 1000 0001, the same as the words.

**Depends on the model, not only the bit timing.** The first OUT is at cycle 4, which depends on the
divider phase (the first tick) and on whether the first OUT stalls for autopull (V1 items c and g).
The bit lengths (12 and 6 high cycles, 20 per bit) do not depend on that.

## Host script

TODO(block 3): a MicroPython host script that loads `ws2812` on a board and sends pixels waits for the
block 3 host library (`sw/host/`). There is no script here yet.
