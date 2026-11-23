## How it works

Polyglot is four RP2040-PIO-compatible protocol engines on one chip. Each engine runs a
program from a shared 64 x 16 instruction memory, and drives and samples the protocol pins
directly. A host sets everything up over a 4-wire SPI mode 0 link (SCK, MOSI, MISO, CS_N).

The chip has three parts:

- **Host link.** An SPI target. A frame is a command byte, a 16-bit address and then 32-bit
  data words. Reads and writes go to the register block. Each access is one bus transfer.
- **Registers.** Chip ID and status, the control register that enables the engines, the
  interrupt flags, the pad registers, the 4-entry TX and RX FIFOs of each engine, and the
  instruction memory. The register map is in `docs/chip.md` §8.
- **Engines.** Four state machines with PIO-compatible instructions, clock dividers, FIFOs,
  and IRQ flags. Each engine can drive any protocol pin.

`HOST_IRQ` on `uo_out[6]` goes high when an enabled interrupt source is active. Its sources
are the TX-not-full and RX-not-empty flags of each engine and the four engine IRQ flags.

## Pinout

| Pad | Name | Meaning |
| --- | --- | --- |
| `uio[0..7]` | P0 to P7 | Protocol I/O. Open-drain can be set per pin. |
| `uo_out[0..5]` | P8 to P13 | Protocol outputs |
| `uo_out[6]` | HOST_IRQ / P14 | `HOST_IRQ` while the host enables it, otherwise a protocol output |
| `uo_out[7]` | MISO | Host link data to the host |
| `ui_in[0..4]` | P16 to P20 | Protocol inputs |
| `ui_in[5]` | SCK | Host link clock |
| `ui_in[6]` | MOSI | Host link data from the host |
| `ui_in[7]` | CS_N | Host link chip select, active low |

Programs see the pins by their program numbers: P0 to P7 on `uio`, P8 to P15 on `uo_out`,
and P16 to P23 on `ui_in`. Program pins 21 to 23 are the host link pins, and programs can read them.

## How to test

The cocotb tests in `test/` drive the Verilog top. The host link tests use a `cocotbext-spi`
master. Run them with `make -B` in `test/`. See `test/README.md`.

The Tiny Tapeout GitHub actions build the GDS, run precheck and run gate-level tests on every push.
Hardening metrics (utilisation, area, slack and violation counts) are printed as annotations on the
`gds` job.

## External hardware

The design needs no external parts for the host link. The Tiny Tapeout demo board with a
Raspberry Pi Pico 2 (RP2350) drives the host link at up to 15 MHz. Protocol devices go on the
Pmod headers.
