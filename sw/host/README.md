# polyglot: the MicroPython host library

`polyglot.py` drives the Polyglot chip over the host link (chip.md section 6). The demo board's
RP2350 runs it. It loads programs into instruction memory, configures and runs the four state
machines, moves FIFO data, and checks that the chip is still configured.

The same file imports under CPython, so the tests in `test/` run on a PC: against a register-file
fake, against `pgasm` and `pgsim`, against the whole-chip model through `pgsim chip-serve`, and
against a closed-loop co-simulation of the RP2350's PIO master and the chip (`cosim/`).

Status: nothing here has run on a board yet. The frame layer, chip logic, program conversion, the
PIO master's waveform and its closed loop with the chip model are tested on a PC. Hardware items
are listed under "Bring-up" and "Board checks still to do".

## Files

| File | What it is |
| --- | --- |
| `polyglot.py` | The library. MicroPython (RP2350) and CPython. |
| `cosim/cosim.ml`, `cosim/plant.py` | The closed loop: pgsim's PIO master at 120 MHz wired pad to pad to the chip model at 60 MHz (dune executable and the Python side). |
| `test/` | pytest tests, `conftest.py`, the register-file fake `fakechip.py`, the vendored `rp2.py`, the PIO text generator `pio_gen.py` |
| `../../programs/spi_master.pio` | The PIO SPI master as pgasm source (H = 3). `polyglot.spi_master_program` builds H = 2 to 6 from `@rp2.asm_pio`, and `test/pio_gen.py` writes the same text. |

## Install on the board

1. Flash MicroPython for the RP2350B (see "RP2350B" below). The Tiny Tapeout demo board runs
   MicroPython with the TT SDK, which includes the `rp2` module used here.
2. Copy the library to the board. With `mpremote` (from the repo root):

   ```
   mpremote cp sw/host/polyglot.py :polyglot.py
   ```

3. Set the system clock to 120 MHz. The link needs it: the PIO clock is 60 MHz, the chip clock.

   ```python
   import machine
   machine.freq(120_000_000)
   ```

The library needs only `rp2`, `machine`, `json`, `binascii`, `time` and `urandom` (or `random` on a
PC), all standard in MicroPython.

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
h = chip.load(prog)             # relocated into IMEM (page 0, then 1); returns a handle

sm = chip.sm(0)
sm.init(h, freq=10_000_000, in_base=5, out_base=3, set_base=2, sideset_base=1)
sm.active(1)

sm.put(0x12345678)              # TX FIFO push
print(hex(sm.get()))            # RX FIFO pop: a read frame, so it never blocks (empty reads 0)
print(sm.regs())               # the SM registers and DBG_* state
```

`pg.Chip` talks only through `transport.xfer(bytes) -> bytes`, so the same code runs on the board
(`PioSpiTransport`) and on a PC (`SimTransport`, see below).

## Bring-up

Order matters on the demo board. Work through these before the first `chip.id()`:

1. **System clock.** `machine.freq(120_000_000)` before creating the transport. The transport refuses
   any other sysclk.
2. **Project clock, 60 MHz on GPIO 16.** The chip's clock comes from the demo board, not from this
   library. The DESIGN (section 13) says the RP2350 divides its 120 MHz sysclk by two with PWM, and the
   TT SDK's `clock_project_PWM` does that on the demo board. Start it before the reset is released.
3. **Claim the pins before reset.** The TT firmware drives `ui_in` (GPIO 17 to 24) from its own pin
   logic until something else claims those pins. `PioSpiTransport` claims SCK (22), MOSI (23) and CS_N
   (24) when it runs `rp2.StateMachine(...)` (the RP2 init sets the PIO function on pins it drives), and
   MISO (40) through the registers below. So create the transport before the chip's reset is released.
4. **CS_N high through reset.** chip.md H-RST (section 6.6): hold CS_N (GPIO 24) high while `rst_n` is
   low and for at least 4 cycles after it rises. The SM's init sets CS_N high (`set_init` ends with
   OUT_HIGH), and the SM stays disabled until `active(1)`, so the pad stays high from init.
   Release the project reset (GPIO 14 on the demo board) only after step 3.
5. **Check.** `chip.id()` returns `0x504C4754`. If not, check the clock (step 2) and the reset (step 4)
   before the pins.

### RP2350B

GPIO 40 needs an RP2350B. The RP2350A has GPIO 0 to 29 only, and GPIO 30 to 47 are present only in
the QFN-80 (RP2350B) package (RP2350 datasheet, GPIO chapter: "GPIOs 30 through 47 are available only in QFN-80
(RP2350B)"). The demo board's RP2350 must be the B part for `uo_out[7]`
(MISO) to be reachable at all.

### Why registers for the pad claim, not `machine.Pin`

`machine.Pin(40, Pin.IN)` configures the pad as an SIO input. It does not select the PIO function
(FUNCSEL 6), so the PIO would not see MISO. MicroPython has no other Python-level way to select a
function, so the library writes the three registers listed under "Board checks". The alternative
is to leave the pad as SIO and read MISO in software, which cannot run at 15 MHz.

## Board pins

`PioSpiTransport` uses the demo board's bottom Pmod row (DESIGN section 5):

| Signal | Chip pad | RP2350 GPIO | Use in the library |
| --- | --- | --- | --- |
| SCK | `ui_in[5]` | 22 | side-set pin and SET base of the PIO master |
| MOSI | `ui_in[6]` | 23 | OUT base |
| CS_N | `ui_in[7]` | 24 | SET bit 2 (SET group of 3, pins 22 to 24) |
| MISO | `uo_out[7]` | 40 | IN base, input synchroniser bypassed |

Checked against the Tiny Tapeout MicroPython firmware, `src/ttboard/pins/gpio_map_dbv3.py`
(`GPIOMapTTDBv3`, the map the firmware uses by default, read from `main` on 2026-11-22): `UI_IN0..7`
are GPIO 17 to 24, `UIO0..7` are 25 to 32, `UO_OUT0..7` are 33 to 40, the project clock is GPIO 16
and the project reset is GPIO 14. The pins above match. The firmware's older `GPIOMapTTDBv3Alpha`
puts `ui_in` on GPIO 12 to 19, so a board with that revision needs other pin numbers.

**Constraint: SCK, MOSI and CS_N must be consecutive pins, in that order.** `PioSpiTransport(sck=s)`
takes MOSI as `s + 1` and CS_N as `s + 2`, because the master drives all three with one SET group of
three pins. A board whose pins are not consecutive needs a different master program, and the library
does not have one. On the demo board they are 22, 23 and 24.

**MISO input synchroniser bypassed.** `PioSpiTransport` sets the bypass bit for MISO, so the PIO reads
the pad one system cycle late instead of three. The MISO window is only four chip cycles at 15 MHz,
and the synchroniser's latency puts the sample outside it. Without the bypass, H = 2 fails at every
phase and delay the co-simulation tried.

The PIO needs `gpio_base = 16` to reach GPIO 40 (MicroPython's `PIO.gpio_base`, which the library
sets).

## Timing: the sample point and the margins

The master samples MISO at tick H, the first SCK-low tick, for H = 2 to 4, and at tick 1 (the second
SCK-high tick) for H = 5 and 6 (`polyglot.SAMPLE_LOW_MAX_H`). The MISO bit for a rise is valid from
three cycles after the previous rise to two cycles after this one (chip.md 6.5). Relative to this
rise, that is from 2H - 3 cycles before it to 2 cycles after, so the window starts earlier in the bit
as H grows. At H = 2 the window is four cycles wide and the sample has to sit in its middle; at H = 5
and 6 a sample late in the bit is past the window's end. Hence the sample moves with H.

The closed-loop co-simulation (`cosim/`) runs the library's own `xfer` loop against pgsim's master and
the chip model, with a host cost per FIFO call, a clock phase and board delays on each path. The
margins below are the board delay, in system cycles (8.3 ns each), each path can take with the chip
still reading correctly (both clock phases, host costs 20 and 1000 cycles, and ID, write and
read-back passing):

| H | SCK (MHz) | Passes | Fails | Reading |
| --- | --- | --- | --- | --- |
| 2 | 15 | (0,0) (0,1) (0,2) (1,0) (2,0) | (2,2) (3,3) | two cycles on one path; the round trip of four fails |
| 3 | 10 | all tried, to (3,3) | none | three cycles each way |
| 4 | 7.5 | all tried, to (3,3) | none | three cycles each way |
| 5 | 6 | all tried, to (3,3) | none | three cycles each way |
| 6 | 5 | all tried, to (3,3) | none | three cycles each way |

`(dsck, dmiso)`: delay on the pins-to-chip path and on the chip-to-pins path. The default 10 MHz has
margin. 15 MHz (H = 2) does not: it survives two system cycles on one path (about 17 ns) and not a
round trip of four. Use it only on a short, direct board path. The sweep did not try an odd
round trip such as (1,1) at H = 2.

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
  the frame layer. Addresses must be word aligned. Every write to a read-write register (HOSTIRQ_EN,
  PAD_OD, INPUT_SYNC_BYPASS, and each SM's CLKDIV, EXECCTRL, SHIFTCTRL, PINCTRL, EXT) is recorded for
  `reload()`.
- `id() -> int`, `hwcfg() -> dict` (`fifo_depth`, `num_sms`, `imem_depth`, `lcu`, `sram`, `version`, `raw`).
- `check() -> bool`: reads ID and SCRATCH. If either is wrong (a deselection loses all state), it
  writes a new SCRATCH nonce and replays the recorded configuration (IMEM, SM registers, pin setup,
  enables). Returns True when the design was present. The nonce is written with the first
  configuration (the first `load` or `init`), so a configured chip passes `check()`.
- `reload()`: the replay on its own.
- `load(source, page=None, offset=None, name=None) -> Loaded`: places a program in one 32-word page.
  `page=None` tries page 0, then page 1. `offset=None` takes the highest free run that fits, as
  pico-sdk's `find_offset_for_program` does (`pio.c`, lines 66 to 82). A program with an origin uses
  that offset. Raises `MemoryError` when nothing fits. `Loaded` has `.page`, `.offset`, `.start` (the
  IMEM index), `.words` and `.program`.
- `fifo_levels(n) -> (tx, rx)`: from FLEVEL.
- `sm(n) -> StateMachine`, n = 0 to 3.
- `halt()`, `step()`: raise `NotImplementedError`. DBG_CTRL is block 4 work (chip.md section 2).

### StateMachine (modelled on MicroPython's `rp2.StateMachine`)

- `init(prog=None, freq=None, clkdiv=None, in_base=None, out_base=None, set_base=None, jmp_pin=None,
  sideset_base=None, in_shiftdir=None, out_shiftdir=None, push_thresh=None, pull_thresh=None,
  autopush=None, autopull=None, fifo_join=None, out_count=None, set_count=None, page=None) -> Loaded`:
  - `prog` is a `Loaded` handle, a `Program`, or any source `Chip.load` accepts. It is loaded first
    if it is not in IMEM yet.
  - `freq` as `rp2_pio.c` reads it (lines 653 to 672), relative to the chip clock (60 MHz): `freq`
    below 0 (the default) means clkdiv 1, and 0 writes a zero divider. Otherwise the divider is
    60 MHz x 256 / freq, which must lie in [256, 65536 x 256], and INT is that divider's integer part
    truncated to 16 bits (so a divisor of 65536 reads as 0). `clkdiv` is a float, rounded to the
    nearest 1/256 as pico-sdk does (`PICO_CLKDIV_ROUND_NEAREST` is 1 on RP2350). With neither, the
    program's own clock divider (pgasm `clockDiv`) applies, else 1.
  - `in_shiftdir`, `out_shiftdir`, `push_thresh`, `pull_thresh` are applied as `rp2_pio.c` does
    (`(arg << lsb) & bits`, lines 231 to 233), so a value the field can't hold is masked, not rejected.
  - Pins are chip pad numbers 0 to 31. Pin levels and directions from the program's init lists are
    applied with forced SET instructions, in pico-sdk's order.
  - `out_count` and `set_count` default to the program's init list length, or to 0: pico-sdk's
    `pio_get_default_sm_config()` leaves PINCTRL at 0 (`pio.h`, lines 780 to 790), and `rp2_pio.c`
    gives a base with no init list count 0 (`ASM_PIO_CONFIG_DEFAULT` line 209; `asm_pio_get_pins`
    lines 238 to 257; the count calls at lines 693 to 703). `out pins, n` needs `out_count=n` or an
    `out_init` list of length n.
  - `fifo_join` takes `PIO_JOIN_NONE`, `PIO_JOIN_TX` or `PIO_JOIN_RX`. Changing it flushes both FIFOs.
    Without it, the program's join applies (rp2 keeps SHIFTCTRL whole, `rp2_pio.c` line 681).
  - Like `pio_sm_init` (`pio.c`), `init` also clears this SM's four sticky FDEBUG flags (TXOVER,
    RXUNDER, TXSTALL, RXSTALL).
  - The SM is left disabled. `active(1)` starts it.
- `active(on=None)`: reads or sets the SM_ENABLE bit.
- `restart()`: SM_RESTART pulse. It clears the input shift counter to 0 and the output shift counter
  to 32 (RP2040 datasheet, PIO: "On PIO reset, or the assertion of CTRL_SM_RESTART ...").
- `exec(instr)`: one forced instruction (SMn_INSTR).
- `put(value)`: TX push.
- `get() -> int`: RX pop, a read frame. It does not block. An empty FIFO reads 0 and sets RXUNDER, as
  the hardware does. Check `rx_fifo()` first if you need to tell an empty read from a zero word.
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

If the source has several programs, pass `name=`.

What each source keeps (the same as pioasm's `<prog>_program_get_default_config()` for JSON, and
rp2_pio.c for rp2 objects):

- **rp2 objects**: wrap fields from EXECCTRL, the side-set count from the side-set init list (plus the
  enable bit), SHIFTCTRL whole (FIFO join included), the MOV STATUS fields from EXECCTRL (bit 4 and
  [3:0], the RP2040 layout), and the three init lists. Element [1] (the fixed offset) is not a request
  for placement, since it is set by an earlier load.
- **pgasm JSON**: wrap, side-set, `.in`/`.out` shift settings, `fifoConfig` (FIFO join: TX or RX),
  `movStatus` (`STATUS_TX_LESSTHAN` or `STATUS_RX_LESSTHAN` with N), `clockDiv`, and `origin`.
  `STATUS_IRQ_SET` and the version 1 joins are RP2350-only and are rejected.

`relocate(words, offset)` adds the offset to every JMP target and leaves every other word alone.
The RP2350 `gpio_base` XOR for `wait gpio` (`pio.c`, `add_program_at_offset`) is not applied: the chip
has its own pins.

### Transports

- `PioSpiTransport(sck_hz=10_000_000, sm_id=0, sck=22, miso=40, sysclk_hz=120_000_000, pio_id=0)`
  (MicroPython only). Drives the link with an `rp2.StateMachine`, sets the MISO bypass, and claims
  the pins (see "Bring-up"). The SCK rate is rounded up to a whole number of chip cycles per phase, so
  the rate never exceeds `sck_hz`. 15 MHz is the maximum (2 chip cycles per phase, the minimum in chip.md
  6.6); 1.875 MHz is the minimum. `xfer(bytes, timeout_us=100000) -> bytes`, `close()`.
- `xfer_on_sm(sm, data, timeout_us, clock=None) -> bytes`: the frame loop the transport uses, usable on
  any object with `put`, `get`, `tx_fifo` and `rx_fifo`. It pops RX whenever RX has a word and refills TX
  only when RX is empty. The RX FIFO is 4 deep and the master's autopush stalls with SCK high when it
  is full, so popping first keeps MISO correct at any host speed. On a timeout, or if the caller is
  interrupted, the frame is completed with zero bytes, so CS_N goes high and RX is left empty, and then
  `OSError` is raised (or the interrupt is re-raised).
- `SimTransport(pgsim="pgsim", num_sms=4, sck_half=3, cs_setup=4, cs_gap=4)` (CPython only). Starts
  `pgsim chip-serve` and speaks chip.md section 12. `xfer`, `run(cycles)`, `ext(ui, uio)`,
  `pads() -> (uo_out, uio_out, uio_oe)`, `cycle()`, `close()`. An `err` reply raises `ChipError`.

`half_period(sck_hz)` gives the chip cycles per SCK phase for a requested rate.

## Board checks still to do

The owner checks these on a Pico 2 (RP2350B) or the demo board before the first real frame.

- **The raw register writes of the pad claim**, in `_pio_pad_claim(40)` and `_pio_bypass_pin`. Addresses
  come from the SDK's RP2350 headers (`hardware/regs/io_bank0.h`, `pads_bank0.h`, `pio.h`,
  `addressmap.h`), and the bit positions too:
  1. **Pad control**, `PADS_BANK0` base `0x40038000`, GPIO 40 at offset `0x04 + 4*40`, so **address
     `0x400380A4`**. The library clears bit 8 (ISO, `0x100`) and sets bit 6 (IE, `0x40`), keeping the
     other bits as read. Clearing ISO matters on RP2350, where pads are isolated after reset.
  2. **Function select**, `IO_BANK0` base `0x40028000`, GPIO 40 control at offset `0x04 + 8*40`, so
     **address `0x40028144`**. The library replaces bits 4:0 (FUNCSEL) with 6, which is PIO0 in the
     RP2350 function table. `GPIO_FUNC_PIO0` is 6 (`hardware/structs/io_bank0.h`).
  3. **Input synchroniser bypass**, PIO0 base `0x50200000` plus `INPUT_SYNC_BYPASS` at `0x038`, so
     **address `0x50200038`**. The bit for GPIO 40 is `40 - gpio_base = 24` (`pio.c` lines 362 to 370), so
     the library sets bit 24 with a read-modify-write. The register is per GPIO relative to the base.
  4. **The GPIO base**: the call `rp2.PIO(0).gpio_base(16)` (`rp2_pio.c` around line 415). Not a register
     write, but it sets the PIO's GPIO window, so GPIO 40 is reachable.
- **The RP2350 MicroPython build.** `rp2.PIO.gpio_base`, the `rp2.asm_pio` keyword arguments the library
  uses (`autopush`, `pull_thresh`, `set_init` as a list), and `out(y, 32)` in the program. They match the
  MicroPython source at commit `1c8e397` (see `test/vendor/README.txt`), but the board build is not yet
  checked.
- **Timing on the wire.** The scope trace of SCK, MOSI, CS_N and MISO at 10 MHz and 15 MHz, against chip.md
  6.6, and the margins above with the real board path in place of the model's delays.
- **The clock and reset order** of "Bring-up", steps 2 to 4.

## Tests

```
cd sw/host
python3 -m pytest test          # needs pytest; the venv in ~/.cache/polyglot has it
```

`dune build --root .` first, for the pgasm, pgsim and co-simulation tests. They skip if the binaries are
missing. The test groups:

- `test_frames.py`: frame bytes against chip.md 6.3, byte for byte.
- `test_regs.py`: field positions and the `sm_config` helper formulas, with the bit positions read from the
  pico-sdk RP2350 `regs/pio.h`. The mov-status fields and the FDEBUG flags are checked against the RP2040
  header, since the chip uses the RP2040 layout.
- `test_chip.py`: the chip API against `fakechip.py` (IMEM, relocation, pages and highest-first placement,
  init writes, pin init, `check()`, `freq` and `clkdiv` edges, shift arguments).
- `test_compat.py`: rp2 and pgasm compatibility (shadowed host writes, FDEBUG on init, whole SHIFTCTRL,
  the fixed-offset field, fifoConfig, movStatus, clockDiv).
- `test_defaults.py`: the pin-count defaults for each program source, with the references cited.
- `test_programs.py`: `@rp2.asm_pio` (MicroPython's `rp2.py`, vendored and run under CPython with stubs),
  pgasm JSON and pgasm `-o python`, cross-checked word for word, for H = 2 to 6.
- `test_lang_opts.py`: the `set_init` lang option accepted by pioasm and pgasm with identical output; the
  committed program file equals the generator.
- `test_xfer.py`: the frame loop against a FIFO model: read-first order, RX never overflows, timeout,
  interrupt, and the header value N-1.
- `test_spi_pgsim.py`: the PIO SPI master in `pgsim` at the RP2350 clock, sampled at 60 MHz, checked
  against chip.md 6.6 at 10 MHz and 15 MHz.
- `test_cosim.py`: the library's `Chip` over the closed loop with the chip model: H = 2 to 6, host costs 20
  and 1000 cycles, both clock phases, and the board-delay margins above.
- `test_sim_transport.py`: `SimTransport` against a stand-in server (the protocol and error paths).
- `test_end_to_end.py`: the library through `SimTransport` to the real `pgsim chip-serve`: ID and HWCFG,
  STATUS after reset, `check()` replaying after a SCRATCH write, a program loaded into page 1, `init` and
  `active`, `put` observed on the pads, `init` pin levels, `exec` (a forced `set pins`), TX and RX levels,
  `get` values, and `restart` clearing the shift counters.

The echo program in `test_end_to_end.py` is `pull block; out isr, 32; push block` (0x80A0, 0x60C0, 0x8020):
`push` pushes the ISR, so the word must be shifted in first.

## The co-simulation

`cosim/cosim.exe` runs pgsim's master at the RP2350 system clock and the whole-chip model at 60 MHz, wired
pad to pad (SCK, MOSI, CS_N into `ui_in`, MISO back into pad 24), with a chip clock phase, board delays
`dsck` and `dmiso` in system cycles, and the MISO bypass. `plant.py` wraps it and gives a `StateMachine`
whose calls advance the plant by a host cost, so the library's `xfer_on_sm` runs against the loop. The
sample tick in the master program was chosen with it, and it is the regression for any change to the
program.
