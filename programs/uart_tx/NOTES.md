# uart_tx: 8n1 UART transmit

## Source

- `uart_tx.pio`: unmodified copy of `pio/uart_tx/uart_tx.pio` from raspberrypi/pico-examples,
  tag `sdk-2.3.1` (commit `0d62f75bafc2c8120d3276c3343d1a9195e909e9`, as recorded in
  `sw/pgasm/test/corpus/MANIFEST.md`). BSD-3-Clause header kept; licence text in
  `programs/LICENSE.pico-examples.TXT`.
- `uart_tx.pioasm.json`: official pioasm 2.3.1 output, `pioasm -o json uart_tx.pio uart_tx.pioasm.json`
  (oracle built from pico-sdk tag `2.3.1`).
- `uart_tx.json`: pgasm output, `pgasm uart_tx.pio > uart_tx.json`. Must equal `uart_tx.pioasm.json`.

## Fixed configuration (`uart_tx.config.json`)

| Setting | Value | Why |
| --- | --- | --- |
| Clock divider | 2.0 (`clkdiv` 0x00020000) | Shows the divider: one PIO tick is two sysclk cycles |
| PINCTRL | 0x44100000 | SIDESET_COUNT 2 (one data pin plus the enable bit), SET_COUNT 1, OUT_COUNT 1, all bases 0 |
| SHIFTCTRL | reset (0x000c0000) | OUT shifts right, no autopull. Matches the C SDK's `sm_config_set_out_shift(&c, true, false, 32)` |
| EXECCTRL | from the JSON | Wrap, and SIDE_EN from `optional` |
| Output pin | GPIO 0 | OUT pin and side-set pin, as in the C SDK init |

Stimulus, as passed to `pgsim_cli`:

- `--init-instr e001` (`set pins, 1`): line high before the run, as the C SDK does.
- `--init-instr e081` (`set pindirs, 1`): pin 0 is an output.
- `--tx 0xa5 --tx 0x5a`: two bytes in the TX FIFO before enable.
- `--cycles 400`, `--trace`: one line per sysclk cycle, `cycle pad` (pads in hex), and a summary.

## What the trace should show

One frame is 10 bits = 10 x 8 PIO ticks = 160 sysclk cycles at divider 2. A bit is 8 ticks = 16 cycles.
A frame is: start bit (low), eight data bits LSB first, then the stop bit (high). The stop bit of
frame N is the `pull` of frame N+1, so it is driven by the instruction `pull side 1 [7]`.

Expected edges, read from `uart_tx.trace` (pin 0 level, cycle ranges inclusive):

| Frame | Bit | Cycles | Level | Value of bit |
| --- | --- | --- | --- | --- |
| 0xa5 | start | 18-33 | 0 | |
| | b0 | 34-49 | 1 | 1 |
| | b1 | 50-65 | 0 | 0 |
| | b2 | 66-81 | 1 | 1 |
| | b3 | 82-97 | 0 | 0 |
| | b4 | 98-113 | 0 | 0 |
| | b5 | 114-129 | 1 | 1 |
| | b6 | 130-145 | 0 | 0 |
| | b7 | 146-161 | 1 | 1 |
| | stop | 162-177 | 1 | |
| 0x5a | start | 178-193 | 0 | |
| | b0 | 194-209 | 0 | 0 |
| | b1 | 210-225 | 1 | 1 |
| | b2 | 226-241 | 0 | 0 |
| | b3 | 242-257 | 1 | 1 |
| | b4 | 258-273 | 1 | 1 |
| | b5 | 274-289 | 0 | 0 |
| | b6 | 290-305 | 1 | 1 |
| | b7 | 306-321 | 0 | 0 |
| | stop | 322-end | 1 | stalls: TX empty, pin stays high |

Read-back: 0xa5 is 1010 0101, so LSB first is 1,0,1,0,0,1,0,1. 0x5a is 0101 1010, so LSB first is
0,1,0,1,1,0,1,0. Both match the table. Frame starts are 160 cycles apart (18 and 178).

Checked by hand against `uart_tx.trace`: the transitions at 18, 34, 50, 66, 82, 114, 130, 146, 178,
210, 226, 242, 274, 290, 306 and 322 are the only ones, and no bit is shorter than 16 cycles.

**Depends on the model, not only the frame.** The first PIO tick is at cycle 2 in pgsim's divider
phase (the first `pull` runs at cycles 2-17, the start bit begins at 18). The 16-cycle bit length and
the bit values do not depend on that phase. The absolute cycle of the first tick does, and it is
V1 item g. The silicon run settles it.

## Host script

TODO(block 3): the MicroPython host script that sends these bytes to a real board waits for the
block 3 host library (`sw/host/`). There is no script here yet.
