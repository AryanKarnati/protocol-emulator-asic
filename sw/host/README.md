# polyglot: the MicroPython host library

`polyglot.py` drives the Polyglot chip over the host link (chip.md section 6). The demo board's
RP2350 runs it. It loads programs into the chip's instruction memory, configures and runs the four
state machines, moves FIFO data, and checks that the chip is still configured.

The same file imports under CPython, so the tests in `test/` run on a PC against a register-file
fake, against `pgasm` and `pgsim`, and (once `pgsim chip-serve` is on main) against the simulated
chip.

Status: the frame layer, the chip API, the program loaders and the PIO master are tested on a PC.
Nothing here has run on a board yet. The pin map and the RP2350 PIO setup are checked against
the datasheet and the demo board documentation, not on hardware (see "Board checks" below).

## Files

| File | What it is |
| --- | --- |
| `polyglot.py` | The library. MicroPython (RP2350) and CPython. |
| `test/` | pytest tests, `conftest.py`, the register-file fake `fakechip.py`, the vendored `rp2.py` |
| `../../programs/spi_master.pio` | The PIO SPI master as pgasm source (10 MHz). `polyglot.py` builds the 15 MHz variant from `@rp2.asm_pio`. |

## Install on the board

1. Flash MicroPython for the RP2350 (the Tiny Tapeout demo board runs MicroPython with the TT SDK,
   which includes the `rp2` module used here).
2. Copy the library to the board. With `mpremote` (from the repo root):

   ```
   mpremote cp sw/host/polyglot.py :polyglot.py
   ```

3. Set the system clock to 120 MHz. The link needs it: the PIO clock is 60 MHz, the chip clock.

   ```python
   import machine
   machine.freq(120_000_000)
   ```

The library needs only `rp2`, `machine`, `json`, `binascii` and `urandom` (or `random` on a PC),
all standard in MicroPython.

## Quick start

```python
import machine
machine.freq(120_000_000)

import polyglot as pg

link = pg.PioSpiTransport(sck_hz=10_000_000)  # the RP2350 is the SPI master
chip = pg.Chip(link)

print(hex(chip.id()))           # 0x504c4754, "PLGT"
print(chip.hwcfg())             # FIFO depth, SM count, IMEM depth, ...
chip.check()                    # ID and SCRATCH nonce; reloads the design if either is wrong

prog = pg.program(open("prog.json").read())  # any supported source, see "Programs"
h = chip.load(prog, page=0)     # relocated into IMEM; returns a handle

sm = chip.sm(0)
sm.init(h, freq=10_000_000, in_base=5, out_base=3, set_base=2, sideset_base=1)
sm.active(1)

sm.put(0x12345678)              # TX FIFO push
print(hex(sm.get()))            # RX FIFO pop (an empty FIFO reads 0 and sets RXUNDER)
print(sm.regs())                # the SM registers and DBG_* state
```

`pg.Chip` talks only through `transport.xfer(bytes) -> bytes`, so the same code runs on the board
(`PioSpiTransport`) and on a PC (`SimTransport`, see below).

## Board pins

`PioSpiTransport` uses the demo board's bottom Pmod row (DESIGN section 5):

| Signal | Chip pad | RP2350 GPIO | Use in the library |
| --- | --- | --- | --- |
| SCK | `ui_in[5]` | 22 | side-set pin and SET base of the PIO master |
| MOSI | `ui_in[6]` | 23 | OUT base |
| CS_N | `ui_in[7]` | 24 | SET bit 2 (SET group of 3, pins 22 to 24) |
| MISO | `uo_out[7]` | 40 | IN base |

Checked against the Tiny Tapeout MicroPython firmware, `src/ttboard/pins/gpio_map_dbv3.py`
(`GPIOMapTTDBv3`, the map the firmware uses by default, read from `main` on 2026-11-22): `UI_IN0..7`
are GPIO 17 to 24, `UIO0..7` are 25 to 32, `UO_OUT0..7` are 33 to 40, the project clock is GPIO 16
and the project reset is GPIO 14. The pins above match. The firmware's older `GPIOMapTTDBv3Alpha`
puts `ui_in` on GPIO 12 to 19, so a board with that revision needs other pin numbers (pass `sck=`
and `miso=`, and the CS_N and MOSI pins must follow SCK, so this is not a configuration the library
supports as it stands).

The PIO needs `gpio_base = 16` to reach GPIO 40 (MicroPython's `PIO.gpio_base`, which the library
sets). SCK, MOSI and CS_N must stay consecutive, because the master drives them with one SET group.

## API reference

### Frame functions (no I/O)

- `frame_write(addr, words, fixed=False) -> bytes`: the write frame of chip.md 6.3.
- `frame_read(addr, n, fixed=False) -> bytes`: the read frame, with its dummy byte and the 4n clock bytes.
- `frame_parse_read(reply, n) -> [int]`: the n words from a read reply (the dummy byte is skipped).
- `frame_status() -> bytes`: the one-byte STATUS frame.
- `status_fields(status) -> dict`: decodes STATUS into `rx_nonempty` and `tx_nonfull` (four bits each).

### Chip

- `Chip(transport)`: no I/O until you call a method.
- `write(addr, words, fixed=False)`, `read(addr, n=1, fixed=False) -> [int]`, `status() -> int`:
  the frame layer. Addresses must be word aligned.
- `id() -> int`, `hwcfg() -> dict` (`fifo_depth`, `num_sms`, `imem_depth`, `lcu`, `sram`, `version`, `raw`).
- `check() -> bool`: reads ID and SCRATCH. If either is wrong (a deselection loses all state), it
  writes a new SCRATCH nonce and replays the configuration this object wrote (IMEM, SM registers,
  pin setup, enables). Returns True when nothing had to be reloaded.
- `reload()`: the replay on its own.
- `load(source, page=0, offset=None, name=None) -> Loaded`: places a program in one 32-word page.
  `offset=None` takes the first free run that fits (or the program's `origin`). The JMP targets are
  relocated as pico-sdk's `pio_add_program` does. Raises `MemoryError` if the page is full.
  `Loaded` has `.page`, `.offset`, `.start` (the IMEM index), `.words` and `.program`.
- `fifo_levels(n) -> (tx, rx)`: from FLEVEL.
- `sm(n) -> StateMachine`, n = 0 to 3.
- `halt()`, `step()`: raise `NotImplementedError`. DBG_CTRL is block 4 work (chip.md section 2).

### StateMachine (modelled on MicroPython's `rp2.StateMachine`)

- `init(prog=None, freq=None, clkdiv=None, in_base=None, out_base=None, set_base=None, jmp_pin=None,
  sideset_base=None, in_shiftdir=None, out_shiftdir=None, push_thresh=None, pull_thresh=None,
  autopush=None, autopull=None, fifo_join=None, out_count=None, set_count=None, page=None) -> Loaded`:
  - `prog` is a `Loaded` handle, a `Program`, or any source `Chip.load` accepts. It is loaded first
    if it is not in IMEM yet (in `page`, default 0).
  - `freq` is in Hz relative to the chip clock (60 MHz). `clkdiv` is the divider as a float.
  - Pins are chip pad numbers 0 to 31. Pin directions and levels from the program's
    `set_init`, `out_init` and `sideset_init` are applied with forced `set pins` and `set pindirs`
    instructions, as pico-sdk does.
  - `out_count` and `set_count` default to the length of the program's init list, or to one pin.
    MicroPython's `rp2` uses the init list length alone (zero when there is none). The one-pin default
    is a deliberate difference, so `out pins, n` needs `out_count=n`.
  - `fifo_join` takes `PIO_JOIN_NONE`, `PIO_JOIN_TX` or `PIO_JOIN_RX`. Changing it flushes both FIFOs.
  - The SM is left disabled. `active(1)` starts it.
- `active(on=None)`: reads or sets the SM_ENABLE bit.
- `restart()`: SM_RESTART pulse.
- `exec(instr)`: one forced instruction (SMn_INSTR).
- `put(value)`, `get() -> int`: TX push, and RX pop (a read frame, so the chip's commit rule applies).
- `tx_fifo()`, `rx_fifo()`: FIFO levels from FLEVEL.
- `regs() -> dict`: CLKDIV, EXECCTRL, SHIFTCTRL, ADDR, PINCTRL, EXT, and DBG_X, Y, ISR, OSR, CNT.
- `halt()`, `step()`: raise `NotImplementedError`.

Constants: `PIO_SHIFT_LEFT`, `PIO_SHIFT_RIGHT`, `PIO_JOIN_NONE`, `PIO_JOIN_TX`, `PIO_JOIN_RX`,
`CHIP_HZ` (60 MHz), `ID_VALUE`.

### Programs

`pg.program(source, name=None) -> Program` accepts:

- a `Program` (already built);
- an rp2 program object: the list that `@rp2.asm_pio` returns (`program_from_rp2`);
- pgasm `-o json` text or a parsed dict (`programs_from_json`; `pioVersion` must be 0);
- the text of a pgasm `-o python` module (`programs_from_python`). It is executed with `rp2`, so the
  objects come from MicroPython's own assembler.

If the source has several programs, pass `name=`. A `Program` has `words`, `wrap_target`, `wrap`,
`side_count` (the SIDESET_COUNT field, with the enable bit), `side_opt`, `side_pindir`,
`shiftctrl`, `origin` and the three init lists.

The rp2 conversion takes the wrap fields and the side-set enable from EXECCTRL and the side-set count
from the side-set init list, as rp2_pio.c does. A program's `set_init`, `out_init` and
`sideset_init` apply at `init`.

Relocation (`relocate(words, offset)`) adds the offset to every JMP target and leaves every other
word alone. It does not apply the RP2350 `gpio_base` XOR that pico-sdk does for `wait gpio`: the
chip has its own pins, with no gpio base.

### Transports

- `PioSpiTransport(sck_hz=10_000_000, sm_id=0, sck=22, miso=40, sysclk_hz=120_000_000, pio_id=0)`
  (MicroPython only). Drives the link with an `rp2.StateMachine`. The SCK rate is rounded up to a
  whole number of chip cycles per phase, so the rate never exceeds `sck_hz`. 15 MHz is the maximum
  (2 chip cycles per phase, the minimum in chip.md 6.6); 1.875 MHz is the minimum. Each frame is a
  header word with the byte count and then one word per byte, and the master returns one MISO byte per
  byte sent. `xfer(bytes) -> bytes`, `close()`.
- `SimTransport(pgsim="pgsim", num_sms=4, sck_half=3, cs_setup=4, cs_gap=4)` (CPython only). Starts
  `pgsim chip-serve` and speaks chip.md section 12. `xfer`, `run(cycles)`, `ext(ui, uio)`,
  `pads() -> (uo, uio_out, uio_oe)`, `cycle()`, `close()`. An `err` reply raises `ChipError`.

`half_period(sck_hz)` gives the chip cycles per SCK phase for a requested rate.

## Board checks still to do

- The RP2350 MicroPython build: `rp2.PIO.gpio_base` and the `rp2.asm_pio` keyword arguments used by
  the library (`autopush`, `pull_thresh`, `set_init` as a list). They match the MicroPython source at
  commit `1c8e397` (see `test/vendor/README.txt`), but the board build is not yet checked.
- The pad registers the library writes for GPIO 40 (`_pio_pad_claim`): the IO_BANK0 FUNCSEL (PIO0 = 6)
  and the PADS_BANK0 ISO and IE bits. The offsets come from the SDK's RP2350 headers.
- Timing on the wire: the scope trace of SCK, MOSI and CS_N at 10 MHz and at 15 MHz, against chip.md 6.6.

## Tests

```
cd sw/host
python3 -m pytest test          # needs pytest; the venv in ~/.cache/polyglot has it
```

The test groups:

- `test_frames.py`: frame bytes against chip.md 6.3, byte for byte.
- `test_regs.py`: field positions and the `sm_config` helper formulas, with the bit positions read from
  the pico-sdk RP2350 `regs/pio.h`.
- `test_chip.py`: the chip API against `fakechip.py` (IMEM, relocation, pages, init writes, pin
  init, `check()` and the deselection replay).
- `test_programs.py`: `@rp2.asm_pio` (MicroPython's `rp2.py`, vendored and run under CPython with stubs),
  pgasm JSON and pgasm `-o python`, cross-checked word for word.
- `test_spi_pgsim.py`: the PIO SPI master in `pgsim` at the RP2350 clock, sampled at 60 MHz, checked
  against chip.md 6.6 at 10 MHz and at 15 MHz.
- `test_sim_transport.py`: `SimTransport` against a stand-in server, and the real `chip-serve` when
  pgsim has it.

The `pgasm` and `pgsim` tests need `dune build --root .` first. They skip if the binaries are missing.
