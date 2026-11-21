## How it works

This is the block 1 bring-up design. It is not the Polyglot protocol engine. It exists to check the flow end to end: Hardcaml to Verilog, then Tiny Tapeout GDS, precheck and gate-level simulation. The four protocol engines replace it in a later block.

The design has three parts:

- a clock divider with an integer and 8-bit fractional divisor, `INT` and `FRAC`;
- a 4-entry FIFO of 32-bit words;
- a command decoder. Each rising edge, `CMD` on `ui_in[2:0]` is executed.

`DATA` on `uio_in` supplies the value for `PUSH`, `INT_LO`, `INT_HI` and `FRAC`. `uo_out` shows either one byte of the FIFO head word, chosen by `BYTE_SEL`, or a status byte, chosen by `VIEW`. All `uio` pins are inputs.

Commands:

| `CMD` | Name | Effect |
| --- | --- | --- |
| 0 | NOP | None |
| 1 | PUSH | Push `{DATA x4} ^ 0x01234567`. Sets OVERFLOW if the FIFO is full. |
| 2 | POP | Remove the head word. Sets UNDERFLOW if the FIFO is empty. |
| 3 | INT_LO | `INT[7:0]` := `DATA` |
| 4 | INT_HI | `INT[15:8]` := `DATA` |
| 5 | FRAC | `FRAC` := `DATA` |
| 6 | DIV_RESTART | Restart the divider phase |
| 7 | CLEAR_FLAGS | Clear OVERFLOW and UNDERFLOW |

The status byte (`VIEW` = 1) has `TICK` in bit 7, the FIFO level in bits 6:4, FULL in bit 3, EMPTY in bit 2, and the sticky OVERFLOW and UNDERFLOW flags in bits 1 and 0.

Reset is asynchronous. After reset the FIFO is empty, both flags are 0, and the divider is `INT` = 1, `FRAC` = 0, so `TICK` is high every cycle.

The full pin contract is in `docs/gate.md`.

## How to test

The cocotb tests in `test/` drive these pins and check the outputs. Run them with `make -B` in `test/`. See `test/README.md`.

To check the physical flow, the Tiny Tapeout GitHub actions build the GDS, run precheck and run gate-level tests on every push.

## External hardware

None. The block 1 design needs no external parts. The later Polyglot design uses the Tiny Tapeout demo board and Pico 2 for silicon checks.
