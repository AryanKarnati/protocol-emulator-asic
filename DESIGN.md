# Polyglot: Design Specification

**Polyglot** is a working name. The chip is an entry for the Jane Street × Tiny Tapeout Protocol Emulator ASIC competition (see [COMPETITION.md](COMPETITION.md)).

|                  |                                                                       |
| ---------------- | --------------------------------------------------------------------- |
| **Process**      | IHP 130nm CMOS5L (Tiny Tapeout March 2027 shuttle)                    |
| **Area**         | 8x4 tiles = 1724.16 × 710.64 µm (1.225 mm²)                           |
| **Clock**        | 60 MHz target. 50 MHz fallback, which loses 10BASE-T (see §13).       |
| **Status**       | Design baseline v0.3, 2026-11-21 (block 1 rulings folded in). This is the reference for the RTL, the model, the toolchain and the tests. |
| **Built with**   | Hardcaml (OCaml) for the RTL, OCaml for the tools and tests, MicroPython on the host. AI tools write all the code under human direction (§17.1). |

The document has two parts:

- **Part I** compares three architectures (one CPU and two non-CPU designs) and explains the choice.
- **Part II** specifies the chosen design closely enough to start writing RTL.

Items marked **[verify]** come from a single or secondary source. Check them against the primary document before relying on them.

---

## Part I: Choosing an architecture

### 1. What drives the design

| Constraint | Value | Consequence |
| --- | --- | --- |
| Area | 8x4 tiles = 1.225 mm². The template places at 60% target density. | Realistically about 0.6–0.7 mm² of cells and macros, roughly 20–25K standard cells. |
| Clock | The demo board's RP2350 generates `clk`, and 60 MHz is confirmed to work. I/O is estimated at about 66 MHz max output and about 10 ns round trip. | At 60 MHz, USB low-speed is exactly 40 cycles per bit and 10BASE-T is exactly 6 cycles per bit (3 per Manchester half-bit). |
| Pins | 8 in, 8 out, 8 bidirectional, plus `clk` and `rst_n`. 3.3 V, digital only, no analog. | The host link has to share these 24 pins. Open-drain is done through output-enable, differential signalling uses pin pairs, and there are no analog front-ends. |
| State | Nothing is known at power-up, and everything is lost when the design is deselected. | Programs are always loaded over a host link after reset, and the host library must make loading idempotent. |
| Host | The demo board's RP2350 is wired to every project pin: `ui_in`→GPIO17–24, `uio`→GPIO25–32, `uo_out`→GPIO33–40. | The RP2350 is the program loader, the data source and sink, and the test partner. |
| Schedule | About 8.5 weeks to January 18, 2027. | Use small, replicated blocks, reuse existing ecosystems, and tier the scope. |
| Judging | Reprogrammability for protocols nobody planned for comes first. Then the protocols shown, unique capability, and verification. The write-up is "weighted heavily." | Favour ecosystem compatibility, generic (not protocol-specific) hardware primitives, and verification from day one. |

Protocol timing at 60 MHz (16.67 ns per cycle), from the research notes:

| Protocol | Cycles per bit | Hard part |
| --- | --- | --- |
| UART 115200 / 3 Mbaud | 520.8 / 20 | Fractional baud rates |
| SPI target | SCK ≤ about 7.5 MHz with 2-FF synchronizers | Synchronizer latency |
| I2C 100k / 400k | 600 / 150 | Open-drain, START/STOP detection, clock stretching |
| WS2812 | 75 (T0H 24, T1H 48) | Cycle-exact pulse widths |
| CAN 500k | 120 | Stuffing after 5 identical bits, CRC15, resynchronisation |
| USB 1.1 low-speed | 40 | NRZI, stuffing after six 1s, CRC5 and CRC16. Reply within about 6.5–7.5 bit times (about 5 µs) **[verify, USB 2.0 §7.1.18]** |
| 10BASE-T | 6 (half-bit = 3) | Manchester at line rate, CRC32, link pulses every 16 ms. RX needs an analog front-end. |

### 2. Three candidate architectures

#### A. "Metronome": a deterministic RISC-V CPU (the CPU option)

This is a TI-PRU-style microcontroller whose timing is fully predictable. Pins are registers, and every instruction has a fixed, documented latency.

- **Core:** RV32E, 2-stage (fetch from SRAM, execute), no caches. Fixed latencies: ALU and I/O 1 cycle, load/store 2, taken branch 2.
- **Memory:** 2 KB instruction SRAM (`RM_IHPSG13_1P_512x32`, 0.080 mm²) and 1 KB data SRAM (`1P_256x32`, 0.049 mm²).
- **Custom I/O instructions** (RISC-V custom-0 opcode, reachable from GCC with `.insn`):
  - `pin.out` / `pin.oe`: masked write of outputs or output-enables.
  - `pin.in`: read the pins.
  - `pin.wait mask, value`: stall until the pins match, with a timeout.
  - `cyc.wait t`: stall until the cycle counter reaches *t* ("output at time T", as on XMOS).
  - `crc.step`: a programmable LFSR step.
  - Two serializer ports with NRZI/Manchester for line-rate traffic.
- **Toolchain:** stock xPack `riscv-none-elf-gcc` with `-march=rv32e -mabi=ilp32e`, so programs can be written in C.
- **Area:** about 6–10K cells for the core plus about 3K for ports and pins, plus 0.13 mm² of SRAM. It fits.
- **Strengths:** C programming and arbitrary decision logic. USB enumeration could run entirely on-chip.
- **Weaknesses:**
  - One thread means one timing-critical protocol at a time.
  - Bit timing depends on counting instructions in software.
  - 10BASE-T (6 cycles per bit) is impossible in software, so it needs semi-fixed serializer ports anyway.
  - A CPU is the most common route, so it scores low on novelty.
  - Verifying a RISC-V core (riscv-formal, arch tests) is a project in itself.

#### B. "Polyglot": four PIO-compatible engines with a Line Coding Unit (non-CPU)

Four small state machines whose base instruction set is **binary-compatible with RP2040 PIO**, sharing a 64-instruction memory. Each engine gets a **Line Coding Unit (LCU)**: generic, configurable hardware for CRC (any polynomial up to 32 bits), bit stuffing, NRZI, Manchester, differential drive, and a clock-recovery sampler. These are the pieces a CPU normally has to supply for USB, Ethernet or CAN, so with them the engines can speak those protocols on their own.

- **Strengths:**
  - Cycle-exact by construction.
  - Up to 4 protocols at once.
  - Line-rate USB and 10BASE-T.
  - Runs existing, unmodified PIO programs written for a different chip, which is direct evidence for the main judging question.
  - One small engine replicated 4 times makes verification tractable.
- **Weaknesses:**
  - Packet-level decisions are limited. They're handled with engine cooperation and the host, as described in §14.
  - The PIO-like space is crowded, so the novelty has to come from the LCU, the compatibility story and the verification.
- **Area:** about 0.45–0.6 mm². See §15.

#### C. "Fabric": an embedded FPGA (non-CPU)

An island-style LUT4 fabric generated with FABulous, which is the only open eFPGA generator with IHP SG13G2 silicon history. The "program" is Verilog compiled to a bitstream with Yosys and nextpnr, then loaded through a hard SPI port.

- **Capacity:**
  - Published IHP FABulous numbers are about 0.045–0.060 mm² per 8-LUT tile, or about 9,400 µm² per LUT4+FF including routing. That comes from a single self-reported source.
  - That works out to **about 100–150 LUT4+FF** in 1.225 mm² after configuration and I/O overhead.
  - The TT IHP "Tiny FABulous FPGA" fits 168 LUT4s, but it needs 45 tiles, more than our 32.
- **Speed:** the Greyhound IHP fabric reports post-PnR STA of 69/51/32 MHz at the fast/typical/slow corners. 60 MHz is out of reach.
- **Need** (LUT counts are unverified estimates):

  | Protocol | LUT4s needed |
  | --- | --- |
  | UART | about 50–100 |
  | SPI | about 50–80 |
  | I2C | about 100–150 |
  | USB low-speed (serial interface engine) | about 300–600 |

  So it fits about one simple protocol, and USB and Ethernet don't fit at all.
- **Strengths:** the most general per gate, highly novel, and the protocol truly lives in the bitstream.
- **Weaknesses:**
  - Capacity and speed are too low for the stretch goals.
  - It depends on forked toolchains.
  - No TT FABulous design has reported silicon results yet.
  - STA through programmable routing needs loop-breaking constraints.
  - Verification covers both the fabric and the toolchain.

### 3. Comparison and decision

Scores are 1 to 5, where 5 is best.

| Criterion | A: CPU | **B: Polyglot** | C: eFPGA |
| --- | :-: | :-: | :-: |
| Reprogrammable for unplanned protocols (main criterion) | 4 | **5** | 3 |
| Line-rate protocols (USB LS, 10BASE-T) | 2 | **5** | 1 |
| Concurrent protocols | 1 | **5** | 1 |
| Novelty in this competition | 2 | **4** | 4 |
| Area and timing risk | 3 | **4** | 1 |
| Toolchain effort | 5 | **4** | 2 |
| Verification tractability | 3 | **5** | 2 |
| Schedule risk (8.5 weeks) | 3 | **4** | 1 |

**Decision: build B, Polyglot.** It is the only option that runs all the required protocols and both stretch protocols at line rate, several at once, inside the area. It also gives two things the other entries can't easily match:

1. **Programs from another chip run unmodified.** The base ISA is binary-compatible with RP2040 PIO. Third-party PIO programs (from pico-examples, the MicroPython docs, and the community) that we never designed for will run as-is. That is the strongest available answer to "can it support protocols it wasn't designed for?"
2. **A golden model checked against real silicon.** The RP2350 on the demo board, or on a $5 Pico 2, contains real PIO hardware. We validate our Python golden model against it before tape-out. After tape-out, the RP2350 is a cycle-accurate reference running right next to our chip. Few hobby ASICs can make that verification claim.

Ideas borrowed from the other options:

- **From A:** the PRU-style cycle-exact contract and full debug access (halt, step, register readback).
- **From XMOS:** the RX clock-recovery sampler runs on its own timebase, separate from the instruction stream.
- **From C:** per-pin configurability (open-drain, synchronizer bypass).

**Rejected hybrid (B plus an on-chip CPU, as PRISM does).** It would double the verification and toolchain surface in an 8.5-week schedule. The RP2350 host is our CPU for slow-path decisions, and §14 shows the fast paths that have to run on-chip.

**Field note:** public entries found so far are mostly PIO-inspired engines with their own ISAs, or small RISC cores. PRISM (a state table plus a TinyQV CPU) also has CRC, stuffing and Manchester units. The write-up therefore leads with binary compatibility, verification against silicon, and the LCU's generic, composable primitives, not with "PIO-like" alone.

---

## Part II: The Polyglot design

### 4. Overview

![Polyglot top-level block diagram](docs/img/polyglot-top.svg)

<details>
<summary>Text version of the diagram</summary>

```
                 tt_um_aryankarnati_polyglot  (single clock domain: clk)
   ┌──────────────────────────────────────────────────────────────────────────────┐
   │  ui_in[5..7] ─► ┌────────────┐  32-bit   ┌─────────────────────────────┐     │
   │  (SCK,MOSI,CS)  │ Host link  │ reg bus   │ Register block               │     │
   │  uo_out[7] ◄─── │ SPI target │◄─────────►│  global ctrl / IRQ / pads    │     │
   │  (MISO)         └────────────┘           │  IMEM 64x16 (2 pages x 32)   │     │
   │                                          │  per-SM config + LCU config  │     │
   │                                          └──────┬───────────┬──────────┘     │
   │        TX/RX FIFO words ▲                       │ 4 read    │ config         │
   │                         ▼                       ▼ ports     ▼                │
   │  ┌─────────────────┐   ┌──────────────────────────────────────────────┐      │
   │  │ Elastic FIFO     │◄─►│ SM0: PIO core + clkdiv + FIFOs ── LCU0       │      │
   │  │ SRAM 512x32      │   │ SM1: ...                       ── LCU1       │      │
   │  │ (Tier 1, gated)  │   │ SM2: ...                       ── LCU2       │      │
   │  └─────────────────┘   │ SM3: ...                       ── LCU3       │      │
   │                         └───────────────▲─────────┬───────────────────┘      │
   │                        8 IRQ flags ──► HOST_IRQ   │ out/oe per pin (priority)│
   │                                          in[31:0] │                          │
   │                                 ┌────────────────┴─────────────────┐         │
   │                                 │ Pin block: 24 pads + 8 virtual,  │◄──────► uio[7:0]
   │                                 │ 2-FF sync, open-drain, readback  │───────► uo_out[6:0]
   │                                 └──────────────────────────────────┘◄────── ui_in[4:0]
   └──────────────────────────────────────────────────────────────────────────────┘
```

</details>

| Parameter | Value |
| --- | --- |
| Engines (state machines, "SMs") | 4, identical |
| Instruction memory | 64 × 16 bits, shared, in 2 pages of 32 |
| FIFOs | Per SM: 4 TX and 4 RX words of 32 bits, joinable to 8 in one direction. Optional SRAM elastic depth. |
| IRQ flags | 8 shared. Any of them can drive the `HOST_IRQ` pin. |
| Pins seen by programs | 24 physical (0–23) and 8 virtual (24–31) |
| Line Coding Unit | One per SM |
| Host link | SPI mode 0, SCK ≤ `clk`/4 (15 MHz at 60 MHz, 10 MHz nominal) |
| Clock | One domain. Each SM has a 16.8 fractional clock-enable divider. |

**Design principles**

1. **The protocol lives in the program.** No logic anywhere is specific to one protocol. LCU features are parameterised: any CRC polynomial up to 32 bits, any stuffing length, three line codes.
2. **Base ISA binary-compatible with RP2040 PIO (version 0).** Extensions use only encodings that RP2040 reserves, plus extra configuration, and never change the meaning of an existing instruction.
3. **Determinism.** Each instruction takes exactly 1 + *delay* engine-clock ticks unless it stalls on a documented condition (§8.3).
4. **One clock domain.** The host SPI is oversampled, so there's no clock-domain crossing beyond input synchronizers.
5. **Everything is observable.** Every architectural register can be read, and engines can be halted, stepped and force-fed instructions through the host link.

### 5. Pins

The host link uses the bottom row of the input and output Pmod headers (bits 5–7). That leaves bits 0–3 of every header free for 6-pin protocol Pmods. It also keeps clear the TT-recommended UART pins (`ui_in[3]` RX, `uo_out[4]` TX), so a UART program can talk to a PC through the demo board.

| Pad | Direction | Program pin # | RP2350 GPIO | Use |
| --- | --- | --- | --- | --- |
| `uio[0..7]` | bidirectional | 0–7 | 25–32 | Protocol I/O. PINDIRS drives `uio_oe`. Open-drain can be set per pin. |
| `uo_out[0..5]` | output | 8–13 | 33–38 | Protocol outputs |
| `uo_out[6]` | output | 14 | 39 | `HOST_IRQ` when `HOSTIRQ_EN≠0`, otherwise a protocol output |
| `uo_out[7]` | output | 15 | 40 | `HOST_MISO` (reserved) |
| `ui_in[0..4]` | input | 16–20 | 17–21 | Protocol inputs |
| `ui_in[5]` | input | 21 | 22 | `HOST_SCK` (programs can read it) |
| `ui_in[6]` | input | 22 | 23 | `HOST_MOSI` (programs can read it) |
| `ui_in[7]` | input | 23 | 24 | `HOST_CS_N` (programs can read it) |
| (none) | virtual | 24–31 | (none) | LCU status for the reading SM (§10.4) |

That leaves 19 dedicated protocol pins, or 20 with `HOST_IRQ` released.

- **Reading output-only pins (8–15)** returns the value currently being driven, which is useful for loopback.
- **Writing input-only pins (16–23)** has no effect.
- **`uo_out` pins are always driven.** PINDIRS has no effect on them.
- **USB D+/D−, I2C and other bidirectional signals** must use `uio`.

### 6. Host link

The host link is an SPI target with CPOL=0, CPHA=0, MSB first. `SCK`, `MOSI` and `CS_N` pass through 2-FF synchronizers and are edge-detected in the `clk` domain, so **SCK must be ≤ `clk`/4**. Use 10 MHz nominally and 15 MHz at most. MISO changes after the falling edge of SCK. Raising `CS_N` aborts any frame cleanly.

Frame formats:

```
WRITE:  CS↓  [CMD=0b0F00_0000] [ADDR15:8] [ADDR7:0] [D31:24][D23:16][D15:8][D7:0] ...  CS↑
READ:   CS↓  [CMD=0b1F00_0000] [ADDR15:8] [ADDR7:0] [dummy] → [D31:24]...[D7:0] ...   CS↑
        CMD bit7 = read; bit6 F = fixed address (no auto-increment; used for FIFOs)
        MISO during the CMD byte = STATUS = {TXNFULL[3:0], RXNEMPTY[3:0]}
```

- Addresses are byte addresses and must be word-aligned. Bursts auto-increment by 4 unless F is set.
- Reading `RXFn` pops that FIFO. Reading an empty FIFO returns 0 and sets `RXUNDER`.
- Writing to a full `TXFn` drops the word and sets `TXOVER`. This matches PIO behaviour.
- A one-byte transaction returns the STATUS byte, which is the cheapest way to poll.

**Throughput:** at 10 MHz SCK a 64-word burst carries about 1.2 MB/s of payload. At 15 MHz it carries about 1.8 MB/s.

### 7. Register map

All registers are 32 bits. Registers marked "PIO layout" use the same bitfields as the RP2040 PIO register of the same name **[verify, RP2040 datasheet §3.7]**, so pico-sdk-style configuration helpers map one-to-one.

| Address | Name | Access | Description |
| --- | --- | --- | --- |
| 0x000 | `ID` | R | Constant `0x504C4754` ("PLGT") |
| 0x004 | `HWCFG` | R | Version, number of SMs, IMEM depth, LCU present, SRAM words |
| 0x008 | `CTRL` | RW | `[3:0]` SM_ENABLE. `[7:4]` SM_RESTART (write 1, self-clearing). `[11:8]` CLKDIV_RESTART (write 1). |
| 0x00C | `FSTAT` | R | FIFO full and empty flags (PIO layout) |
| 0x010 | `FDEBUG` | RW1C | TXSTALL, TXOVER, RXUNDER, RXSTALL, ILLEGAL (sticky flags) |
| 0x014 | `FLEVEL` | R | FIFO levels (PIO layout) |
| 0x018 | `IRQ` | RW1C | 8 IRQ flags |
| 0x01C | `IRQ_FORCE` | W | Set IRQ flags |
| 0x020 | `HOSTIRQ_EN` | RW | Mask of {IRQ0–3, RXNEMPTY0–3, TXNFULL0–3}. Any set bit claims `uo_out[6]`. |
| 0x024 | `PAD_OD` | RW | Open-drain enable for `uio[7:0]` |
| 0x028 | `INPUT_SYNC_BYPASS` | RW | Per-pin synchronizer bypass for pins 0–23 |
| 0x02C | `PAD_IN` / `PAD_OUT` / `PAD_OE` | R | Raw pad state, for debug. These are three consecutive registers. |
| 0x038 | `SCRATCH` | RW | Host writes a nonce after loading. A changed value means the design was deselected or reset, so reload. |
| 0x040–0x04C | `TXF0–3` | W | TX FIFO push |
| 0x050–0x05C | `RXF0–3` | R | RX FIFO pop |
| 0x060 | `DBG_CTRL` | RW | `[3:0]` HALT. `[7:4]` STEP (write 1: run one instruction on a halted SM). |
| 0x080–0x0FF | `EFIFO_*` | RW | Elastic FIFO base and size per FIFO (Tier 1, §12) |
| 0x100–0x1FC | `IMEM[0..63]` | RW | One instruction in bits [15:0] of each word |
| 0x200 + 0x40·n | SMn block | | Per-engine registers, listed below |
| 0x400–0xBFC | `SRAM` | RW | Elastic FIFO SRAM window (Tier 1) |

Per-SM block, with offsets from 0x200 + 0x40·n:

| Offset | Name | Description |
| --- | --- | --- |
| +0x00 | `CLKDIV` | INT[31:16], FRAC[15:8] (PIO layout) |
| +0x04 | `EXECCTRL` | PIO layout: SIDE_EN, SIDE_PINDIR, JMP_PIN, OUT_EN_SEL, INLINE_OUT_EN, OUT_STICKY, WRAP_TOP, WRAP_BOTTOM, STATUS_SEL, STATUS_N |
| +0x08 | `SHIFTCTRL` | PIO layout: FJOIN_RX/TX, PULL/PUSH_THRESH, OUT/IN_SHIFTDIR, AUTOPULL, AUTOPUSH |
| +0x0C | `ADDR` | Current PC (read-only) |
| +0x10 | `INSTR` | Write executes the instruction immediately. Read returns the current instruction. |
| +0x14 | `PINCTRL` | PIO layout: SIDESET_COUNT, SET_COUNT, OUT_COUNT, IN_BASE, SIDESET_BASE, SET_BASE, OUT_BASE |
| +0x18 | `EXT` | `[0]` PAGE (which 32-instruction page this SM runs). The rest is reserved. |
| +0x1C | `LCU_CFG` | §10.1 |
| +0x20 | `LCU_POLY` | CRC polynomial in hardware form (§10.2) |
| +0x24 | `LCU_RXCFG` | `[4:0]` RX_PIN. `[27:8]` PERIOD (cycles per bit, 16.4 fixed-point). |
| +0x28 | `LCU_CRC` | Current CRC value (read/write) |
| +0x2C–0x38 | `DBG_X`, `DBG_Y`, `DBG_ISR`, `DBG_OSR` | Architectural state (read-only) |
| +0x3C | `DBG_CNT` | Read-only. `[5:0]` ISR shift count (0–32). `[13:8]` OSR shift count (0–32). `[20:16]` delay ticks still to run. `[27:24]` stall reason: 0 none, 1 TX empty (blocking `PULL`), 2 RX full (blocking `PUSH` or autopush), 3 autopull (`OUT` waiting for TX data), 4 `WAIT gpio`, 5 `WAIT pin`, 6 `WAIT irq`, 7 `IRQ wait` (waiting for its flag to clear), 8 `IN LCU` (§10.3), 9–15 reserved. |

### 8. Engine (state machine)

#### 8.1 State and resources (per SM)

| Item | Bits | Notes |
| --- | --- | --- |
| X, Y | 32 + 32 | Scratch registers |
| ISR, OSR | 32 + 32 | Input and output shift registers, with 6-bit shift counters |
| PC | 5 | Plus the PAGE bit from `EXT` |
| Delay counter | 5 | |
| Clock divider | 16.8 config + accumulator | Produces one enable tick per divided period, as PIO does |
| FIFOs | 2 × 4 × 32 | Joinable to 8 in one direction |
| Config | about 80 | EXECCTRL, SHIFTCTRL, PINCTRL, EXT |
| LCU | about 170 | §10 |

#### 8.2 Execution model

- An SM advances only on its clock-divider enable tick.
- On each tick the SM reads `IMEM[{PAGE, PC}]` combinationally from the flop array and executes it in that cycle.
- PC wraps from WRAP_TOP back to WRAP_BOTTOM.
- **Side-set** takes effect on the first tick of an instruction, even when the instruction stalls. This is PIO semantics.
- **Delay** cycles start only after the instruction completes. They never run while a stalled instruction is waiting.
- **Output priority** across SMs follows PIO: when several SMs write the same pin in the same cycle, the highest-numbered SM wins. The side-set, OUT/SET and pin-direction priority rules within one SM follow RP2040 datasheet §3.5.6 **[verify]**.
- **`OUT EXEC` / `MOV EXEC`** run the given instruction on the SM's next tick. The delay field of the `OUT` or `MOV` itself is ignored, and the executed instruction's own delay applies (RP2040 datasheet §3.4.5.2, §3.4.8.2). This is the technique pico-examples I2C uses.
- **Host writes to `INSTR`** run the instruction in the next system clock cycle, ignoring the clock divider, `SM_ENABLE` and the instruction's own delay field. The PC does not advance unless the instruction writes it. A forced instruction that stalls is latched and retried until it completes, and `EXECCTRL.EXEC_STALLED` shows this (RP2040 datasheet §3.5.7). Host setup code uses this to set pins and jump while the SM is disabled.

#### 8.3 Stall conditions

These are the only cases where an instruction takes more than 1 + delay ticks:

- **Blocking FIFO operations:** `PULL block` with an empty TX FIFO, `PUSH block` with a full RX FIFO.
- **Autopull and autopush:** `OUT` when autopull has hit its threshold and the TX FIFO is empty; `IN` or `IN LCU` when autopush has hit its threshold and the RX FIFO is full.
- **WAIT:** `WAIT` until its condition holds; `IRQ wait` until the flag clears.
- **`IN LCU, n`:** until the LCU has at least *n* decoded bits (§10.3).
- **Host debug:** HALT.

The `DBG_CNT.stall_reason` field (§7) reports which condition is active. HALT and a disabled SM are not stall reasons: the field keeps the value from the last attempt.

### 9. Instruction set

#### 9.1 Encoding (16-bit, RP2040 PIO version 0) **[verify against RP2040 datasheet §3.4]**

| Instruction | 15:13 | 12:8 | 7:5 | 4:0 |
| --- | --- | --- | --- | --- |
| JMP | 000 | delay/side-set | condition | address (within page) |
| WAIT | 001 | delay/side-set | polarity(7), source(6:5) | index |
| IN | 010 | delay/side-set | source | bit count (0 = 32) |
| OUT | 011 | delay/side-set | destination | bit count (0 = 32) |
| PUSH | 100 | delay/side-set | 0, IfFull, Block | 00000 |
| PULL | 100 | delay/side-set | 1, IfEmpty, Block | 00000 |
| MOV | 101 | delay/side-set | destination | op(4:3), source(2:0) |
| IRQ | 110 | delay/side-set | 0, Clr, Wait | index (bit 4 = REL) |
| SET | 111 | delay/side-set | destination | 5-bit data |

Bits 12:8 are split between side-set and delay according to SIDESET_COUNT and SIDE_EN, exactly as in PIO.

Field values. Extensions are in **bold**:

| Field | Values |
| --- | --- |
| JMP condition | 000 always, 001 `!X`, 010 `X--`, 011 `!Y`, 100 `Y--`, 101 `X!=Y`, 110 `PIN`, 111 `!OSRE` |
| WAIT source | 00 GPIO (absolute), 01 PIN (relative to IN_BASE), 10 IRQ, 11 reserved |
| IN source | 000 PINS, 001 X, 010 Y, 011 NULL, **100 LCU**, 101 reserved (official `pioasm` assembles `in status` to it), 110 ISR, 111 OSR |
| OUT destination | 000 PINS, 001 X, 010 Y, 011 NULL, 100 PINDIRS, 101 PC, 110 ISR, 111 EXEC |
| MOV destination | 000 PINS, 001 X, 010 Y, 011 reserved, 100 EXEC, 101 PC, 110 ISR, 111 OSR |
| MOV op | 00 none, 01 invert, 10 bit-reverse, 11 reserved |
| MOV source | 000 PINS, 001 X, 010 Y, 011 NULL, **100 CRC**, 101 STATUS, 110 ISR, 111 OSR |
| SET destination | 000 PINS, 001 X, 010 Y, **011 LCU**, 100 PINDIRS, 101–111 reserved |

Any other reserved encoding executes as a NOP and sets the sticky `FDEBUG.ILLEGAL` flag. The NOP keeps the word's delay and side-set field. Reserved words include:

- IN source 101, even though the official `pioasm` assembles `in status` to it. `pgasm` stays byte-compatible with `pioasm`, and the chip flags the word.
- WAIT IRQ index bit 3, IRQ index bit 3 and IRQ bit 7. RP2350 PIO version 1 gives these bits meanings (PREV and NEXT), and `pioasm` never sets them for version 0.
- Every other RP2350 PIO version 1 encoding: WAIT JMPPIN, MOV PINDIRS and the RX FIFO MOVs. Polyglot is binary-compatible with version 0 only, so version 1 programs fail loudly instead of running wrongly.
- The three extension encodings (IN 100, MOV source 100, SET 011) when the LCU is absent: in blocks 2 to 4, or in a build with `LCU present` off.

The three extension encodings are still reserved in RP2350 PIO version 1 (checked 2026-11-21 against the RP2350 datasheet: §11.4.4.2 IN source 100, §11.4.10.2 MOV source 100 and §11.4.12.2 SET destination 011 all read "Reserved"). Programs written for either PIO version can therefore never contain them by accident.

#### 9.2 Extensions

There are only three new instructions, plus the virtual pins. Existing PIO programs are unaffected.

| Syntax | Encoding | Semantics |
| --- | --- | --- |
| `in lcu, n` | IN, source 100 | Shift *n* decoded bits from the LCU receive path into ISR, honouring IN_SHIFTDIR and autopush. Stalls until *n* bits are available. |
| `mov dst, crc` / `mov dst, ~crc` | MOV, source 100 | Read the LCU CRC register (§10.2). The invert op gives the "final XOR with all ones" for free. |
| `set lcu, imm5` | SET, destination 011 | LCU control. `[0]` CRC_EN, `[1]` STUFF_EN, `[2]` TXCODE_EN (coded `OUT PINS`), `[3]` RX_EN, `[4]` CLR (a pulse: reset CRC to its initial value, clear the stuffing run, NRZI and Manchester state, RX staging and the error flag). |
| `wait 1 gpio 24..27`, `jmp pin` with JMP_PIN 24–27, `in pins` | Existing encodings | Read LCU status as virtual pins (§10.4) |

#### 9.3 Instruction memory

`IMEM` is 64 × 16 bits held in flops, with 4 combinational read ports and one write port (host only).

- Each SM executes inside one 32-instruction page selected by `EXT.PAGE`, so the 5-bit JMP, WRAP and PC fields work unchanged.
- PIO programs are relocatable. The loader places each program inside a page and adds the offset to its JMP targets, exactly as pico-sdk's `pio_add_program` does.

### 10. Line Coding Unit (LCU)

Each SM has its own LCU. It sits between the SM's shift registers and the pins, and it does the bit-level work a CPU normally does in software.

![One engine and its Line Coding Unit](docs/img/polyglot-engine.svg)

The program decides when a bit moves, and the LCU decides how it looks on the wire.

- The CRC taps data bits before stuffing on TX and after unstuffing on RX, so stuff bits never reach it.
- `set pins`, side-set and multi-bit `out pins` bypass the LCU.
- The RX chain runs on `clk`, not the SM's divider.

```
TX:  OSR bit ─► [CRC accumulate] ─► [stuff insert] ─► [NRZI | Manchester | NRZ] ─► [diff pair] ─► OUT_BASE(+1)
RX:  RX_PIN ─► sync ─► [edge-resync DPLL / Manchester decoder] ─► [NRZI decode] ─► [unstuff] ─► [CRC] ─► staging ─► IN LCU
                         └─► SE0 / IDLE / ERR / BITRDY ─► virtual pins 24–27
```

#### 10.1 `LCU_CFG`

| Bits | Field | Meaning |
| --- | --- | --- |
| 1:0 | TX_CODE | 0 NRZ, 1 NRZI, 2 Manchester |
| 2 | NRZI_ONES | 0 = toggle on 0 (USB), 1 = toggle on 1 |
| 3 | MANCH_INV | 0 = IEEE 802.3 (1 is a low→high mid-bit transition), 1 = G.E. Thomas |
| 4 | TX_DIFF | Pin OUT_BASE+1 is driven with the complement of OUT_BASE |
| 7:5 | STUFF_N | Insert a stuff bit after N bits (0 = off). USB uses 6, CAN and HDLC use 5. |
| 8 | STUFF_SAME | 0 = count runs of 1s (USB, HDLC). 1 = count runs of identical bits (CAN). |
| 10:9 | RX_CODE | Same encoding as TX_CODE |
| 11 | RX_SE0_EN | Also watch RX_PIN+1 for SE0 (both lines low) |
| 12 | CRC_DIR | 0 = accumulate TX bits, 1 = accumulate RX bits |
| 17:13 | CRC_WIDTH−1 | CRC width minus 1, covering widths 1–32 |
| 18 | CRC_REFLECT | 1 = LSB-first (reflected) form |
| 19 | CRC_INIT_ONES | Initial value: 0 = all zeros, 1 = all ones (within the width) |
| 20 | RX_RESYNC | Re-phase the DPLL on every input edge |
| 23:21 | IDLE_BITS | IDLE asserts after (IDLE_BITS+1) × 2 bit periods with no edge |

#### 10.2 CRC

The CRC is a serial LFSR that processes one bit per data bit consumed (TX) or delivered (RX), and only while CRC_EN is set. Stuff bits are never included.

- **Reflected form:** `fb = d ^ crc[0]`, then `crc = (crc >> 1) ^ (fb ? POLY : 0)`. POLY holds the reflected polynomial, right-aligned (for example `0xA001` for CRC16-USB).
- **Normal form:** `fb = d ^ crc[31]`, then `crc = (crc << 1) ^ (fb ? POLY : 0)`. POLY holds the polynomial left-aligned (for example `0x4599 << 17` for CAN CRC15).
- The width mask keeps bits outside the window at zero.
- The toolchain computes the hardware form of POLY from the familiar parameters (polynomial, width, reflect, init), so the hardware stays minimal.
- `mov osr, ~crc` followed by shifting out *width* bits transmits the FCS in the right bit order for USB and Ethernet.
- Receivers check the CRC by comparing it with the protocol's residual held in Y: `mov x, crc` then `jmp x!=y`.

| Use | Width | POLY (hardware form) | Reflect | Init | Final XOR (in program) |
| --- | --- | --- | --- | --- | --- |
| USB token CRC5 | 5 | `0x14` | yes | ones | invert |
| USB data CRC16 | 16 | `0xA001` | yes | ones | invert |
| Ethernet CRC32 | 32 | `0xEDB88320` | yes | ones | invert |
| CAN CRC15 | 15 | `0x4599 << 17` | no | zeros | none |
| SD card CRC7 | 7 | `0x09 << 25` | no | zeros | none |

#### 10.3 TX and RX behaviour

**TX** applies when TXCODE_EN is set and the instruction is `OUT PINS, 1`. Multi-bit `OUT PINS` is always raw.

- **Stuffing:** if a stuff bit is due, the OUT emits it (the complement of the run value) through the line coder. It consumes no OSR bit, and the shift counter doesn't advance.
- **Manchester:** each data bit takes two `OUT` executions. The first emits the first half-bit by peeking at the OSR without shifting. The second emits the second half and consumes the bit. The program's delay field sets the half-bit time: at 60 MHz, `out pins, 1 [2]` gives 3 cycles = 50 ns.
- **Raw writes:** `SET PINS` and side-set always bypass the LCU. Use them for USB SE0 or Ethernet TP_IDL.

**RX** runs on the system clock, independent of the SM's divider, once RX_EN is set.

- **NRZ and NRZI:** a phase accumulator (PERIOD in 16.4 fixed point, in cycles per bit) samples at mid-bit. With RX_RESYNC, every input edge resets the phase. Stuffing guarantees edges (USB: at least one every 7 bits; CAN: every 6), which covers the ±1.5% tolerance of USB low-speed.
- **Manchester:** an edge more than ¾·PERIOD after the last accepted mid-bit edge (or the first edge after arming) counts as a new mid-bit edge. It emits bit = level after the edge, XOR MANCH_INV, and re-phases. Edges in between are boundary edges and are ignored. If no mid-bit edge arrives within 1¼·PERIOD, that's a code violation: it sets ERR and IDLE, which signals end of frame. The 10BASE-T preamble (`1010…`) has only mid-bit edges, so lock-on is clean. At PERIOD = 6 the margin is ±1.5 cycles (±25 ns).
- **Decode chain:** NRZI decode, then unstuff (a bit after N-run is dropped, and if it isn't the complement, ERR is set), then CRC, then a 32-bit staging register. `IN LCU, n` takes bits from the staging register.

#### 10.4 Virtual pins

Each SM sees its own LCU's status on pins 24–31:

| Pin | Signal |
| --- | --- |
| 24 | SE0: RX_PIN and RX_PIN+1 both low (synchronized). USB end of packet. |
| 25 | BITRDY: staging holds at least 1 decoded bit |
| 26 | ERR: sticky stuffing error or Manchester code violation, cleared by `set lcu` with CLR |
| 27 | IDLE: no RX edge for the IDLE_BITS window. End of frame for 10BASE-T and CAN. |
| 28–31 | Reserved, read 0 |

### 11. Pin block

- **Per pad:** one output-value flop and one output-enable flop, shared by all SMs. Writes follow PIO priority. Reset values are value 0 and enable 0, so every `uio` starts as an input.
- **Open-drain** (`PAD_OD[i]`, `uio` only): `uio_out[i]=0` and `uio_oe[i] = oe & ~value`. A program sets PINDIRS once and then writes 0 to pull low or 1 to release. Pico-examples-style PINDIRS open-drain also works with `PAD_OD=0`.
- **Inputs:** a 2-FF synchronizer per pad, which `INPUT_SYNC_BYPASS` can skip (PIO feature). The 32-bit input vector is `{virtual[7:0], ui_in, uo_out readback, uio_in}`.
- **Host pins:** `uo_out[7]` is always MISO. `uo_out[6]` is HOST_IRQ while `HOSTIRQ_EN≠0`.

### 12. Elastic FIFOs with SRAM (Tier 1, behind a decision gate)

One `RM_IHPSG13_1P_512x32` macro (2 KB, 416.64 × 191.34 µm, 3.85 ns typical and 6.45 ns worst-case access) backs the 8 FIFOs as ring buffers. Each ring's base and size are set in `EFIFO_*`.

- A streamer refills each SM's 4-word register TX FIFO from its ring, and drains RX FIFOs into their rings, using round-robin access to the single port.
- The host's `TXF`/`RXF` accesses go to the rings.
- Engines only ever touch the register FIFOs, so **SM timing is unchanged**. The FIFOs just get deeper.
- **Why it matters:** a full 1518-byte Ethernet frame (or a set of USB descriptors) can be loaded first and then sent at line rate. Without it, 10BASE-T TX depends on the host streaming at ≥1.25 MB/s, which needs SCK ≥ about 12 MHz sustained.
- **Integration:** follow Ken Pettit's IHP SRAM walkthrough (Appendix B): tie `A_DLY=1` and the BIST pins off, add a `MACROS` entry in config.json with a fixed location, use Metal4-only PDN stripes aligned to the macro, add routing obstructions on Metal2–4, connect two supply pairs, and use the KLayout DRC deck.
- **Gate:** if the macro doesn't pass precheck by the end of week 3, drop it and keep the 4+4 register FIFOs.

### 13. Reset, clocking and deselection

- **Reset:** `rst_n` is asserted asynchronously and released through a 2-FF synchronizer. After reset, every SM is disabled, FIFOs are empty, configuration is at PIO defaults (clkdiv 1, wrap 0–31, shift right, threshold 32), and all pads are inputs. IMEM is not reset; it's garbage until loaded.
- **Clock:** `info.yaml` sets `clock_hz: 60000000`.
  - Run synthesis and STA at a 15 ns period during development to expose problems early, and sign off at 16.67 ns at every corner.
  - The template default is 20 ns, so `config.json` has to be edited.
  - **Clock fallback:** at 50 MHz everything works except 10BASE-T. A Manchester half-bit would be 2.5 cycles, which isn't an integer. 40 MHz restores exact 10BASE-T (2 cycles per half-bit) but USB low-speed becomes fractional.
- **Generating the clock:** on the RP2350, set `sysclk` to 120 MHz and divide by 2 with PWM for an exact 60 MHz.
- **`ena`:** ignored. Deselection powers the design down, so all state is lost. The host library re-checks `ID` and `SCRATCH` before use and reloads if either doesn't match.

### 14. Protocol implementation plan

| Protocol | SMs | LCU | Instructions (estimate) | Pins | Notes |
| --- | --- | --- | --- | --- | --- |
| UART TX / RX | 1 / 1 | — | 4 / 8 | 1 out / 1 in | pico-examples programs, unmodified |
| SPI controller, modes 0–3 | 1 | — | 3–4 | SCK, MOSI out, MISO in | pico-examples `spi_cpha0/1`, unmodified |
| SPI target | 1–2 | — | about 8 | SCK, CS, MOSI in, MISO out | SCK ≤ 7.5 MHz synced, about 15 MHz with sync bypass |
| I2C controller | 1 | — | about 30 | SDA, SCL on `uio` | pico-examples `i2c.pio` with the host using EXEC, or a simpler open-drain version |
| I2C target | 1–2 | — | about 20 | SDA, SCL on `uio` | START/STOP through `WAIT`. **Clock-stretches while the host prepares data**, which hides host-link latency inside the protocol rules. |
| WS2812 | 1 | — | 4 | 1 out | pico-examples, unmodified |
| Logic analyser / replay | 1 | — | 2 | any | `in pins, n` with autopush: capture and replay any protocol |
| **USB 1.1 LS device** (Tier 1) | 3 | NRZI, STUFF 6, CRC16 and CRC5, DPLL period 40, SE0 | about 45 | D+, D− on `uio` + 1.5k pull-up on D− | See below |
| **10BASE-T TX** (Tier 1) | 1 | Manchester, DIFF, CRC32 | about 15 | TD+, TD− + resistors and magnetics (Pico-10BASE-T style) | See below |
| CAN 2.0A (Tier 2) | 2 | STUFF 5 same, CRC15, DPLL | about 30 | TX, RX through a transceiver Pmod | Arbitration: compare the TX bit with the RX pin every bit |
| 10BASE-T RX (Tier 2) | 1 | Manchester decoder, CRC32 | about 10 | 1 in | Needs an external comparator front-end |
| JTAG, SWD, PS/2, 1-Wire, DMX512 | 1 | — | small | — | Pure programs; good "not designed for" demos |

**Running protocols at the same time**

Each SM runs independently with its own clock divider, so up to four protocols run at once. Four things limit the mix:

- **Engines.** Most protocols need one. A full-duplex UART needs two (TX and RX), CAN needs two, and USB needs three.
- **Instruction memory.** There are 64 instructions in two pages of 32, and each SM runs from one page. SMs can share one copy of a program, so four UART transmitters on four pins use 4 instructions in total.
- **Pins.** There are 19 physical protocol pins (§5).
- **Host link.** About 1.2–1.8 MB/s (§6), shared by every SM.

| Example mix | SMs | Instructions (estimate) |
| --- | --- | --- |
| UART TX + UART RX + SPI controller + I2C controller | 4 | about 46 of 64 |
| USB LS device + UART TX for debug output | 4 | about 49 |
| 10BASE-T TX + UART TX/RX + WS2812 | 4 | about 31 |
| 4 × UART TX on different pins | 4 | 4 (one shared copy) |

**USB low-speed device, fast paths on-chip and slow path on the host**

- **SM0, data receiver.** LCU set for NRZI, stuffing 6 and CRC16. It decodes packets into the RX FIFO and checks the CRC16 residual.
- **SM1, token receiver.** It runs the same receive program on the same pins, with its LCU set for CRC5. It checks the PID, compares the address with Y, checks the CRC5, and raises an IRQ that says "token for me", with its type.
  - Using two LCUs on one input to get two CRC profiles is a deliberate showcase of how the units compose.
- **SM2, transmitter.** On "OUT/SETUP data OK" it sends ACK. On an IN token it sends a DATA packet if the host has already staged one in the TX FIFO (with the CRC16 appended by the LCU), and NAK otherwise. Each reply is followed by EOP (SE0 for 2 bits, then J).
- **The RP2350 host** handles enumeration, descriptors and data toggles at its own pace. NAK-and-retry is normal USB flow control, so host latency never breaks timing.

**10BASE-T TX**

- Preamble and SFD are sent with CRC off, then the frame with CRC_EN, then `mov osr, ~crc` and 32 bits.
- TP_IDL is driven with `set pins`. Normal link pulses (100 ns every 16 ms) come from an X countdown loop in the same SM while it's idle.
- Demo: Wireshark on a PC shows UDP frames sent by the chip.

### 15. Area and timing budget

These are estimates from IHP cell areas (Appendix A). The real numbers come from the week-3 hardening run.

| Block | Flops | Other cells | Area (mm²) |
| --- | --- | --- | --- |
| SM core × 4 (registers, shifters, divider, config, FIFOs) | 4 × 550 | 4 × 2,500 | 0.22 |
| LCU × 4 | 4 × 170 | 4 × 600 | 0.07 |
| IMEM 64×16 + 4 read ports | 1,024 | about 2,000 (mux trees) | 0.09 |
| Host link, registers, IRQ | 400 | 1,500 | 0.04 |
| Pin block | 100 | 400 | 0.01 |
| SRAM macro + streamer (Tier 1) | 100 | 800 | 0.10 |
| **Total** | **about 4,300** | **about 18,000** | **about 0.53** |

That's about 43% of the 1.225 mm² 8x4 area, which leaves headroom under the template's 60% placement density for clock-tree buffers, hold fixing and routing.

**Critical paths (estimates):**

- **Instruction path:** PC flop → IMEM 64:1 mux (6 levels) → decode → shifter or pin rotate (5 levels) → ISR/OSR or pad register. About 25 gate levels, roughly 5–8 ns at the slow corner.
- **SRAM path (Tier 1):** 6.45 ns worst-case access plus the streamer mux, which fits 16.67 ns.

**Decision gate at the end of week 3:**

- **Proceed if** utilization is ≤ 55% and slow-corner slack is ≥ 0 at 60 MHz.
- **Otherwise,** in this order: drop the SRAM, then pipeline the IMEM read, then cut to 3 SMs.

### 16. Implementation languages and toolchain

Everything except the host library and the Tiny Tapeout CI tests is written in OCaml.

- Jane Street maintains Hardcaml and lists "different HDLs" among its judging interests.
- OCaml's type checker catches width and API mistakes at compile time. That matters when AI tools write the code (§17.1).

| Layer | Language |
| --- | --- |
| Chip RTL | Hardcaml, generating Verilog |
| ISA definition, assembler, golden model, main verification | OCaml |
| Protocol programs | PIO assembly, unchanged, so existing PIO programs still run |
| Host library on the demo board | MicroPython |
| Tiny Tapeout CI and gate-level tests | cocotb (Python), as the template expects |

| Tool | What | How |
| --- | --- | --- |
| `isa/` | Instruction set, defined once | An OCaml variant type covers every instruction and comes with `encode` and `decode`. The assembler, the model, the RTL decoder and the tests all use it, so they can't disagree about an encoding. |
| `hw/` | RTL | <ul><li>Hardcaml circuits take four parameters: number of SMs, IMEM depth, LCU present and SRAM present. The week-3 fallbacks (§15) are therefore parameter changes.</li><li>`hw/bin/gen_verilog.exe` writes `src/polyglot.v`.</li><li>A small hand-written `src/project.v` maps the `tt_um_*` ports.</li><li>CI regenerates the Verilog and fails if it differs from the committed file.</li></ul> |
| `pgasm` | Assembler | <ul><li>Written in OCaml. It accepts pioasm syntax and adds `in lcu`, `mov …, crc`, `set lcu`, `.page` and `.lcu`. `.lcu` takes CRC, stuffing and line-code parameters and converts them to register values.</li><li>Outputs JSON (code plus configuration), hex, and a MicroPython module.</li><li>Regression test: its output must be byte-identical to the official `pioasm` for every pico-examples program.</li></ul> |
| `pgsim` | Golden model | <ul><li>A cycle-accurate OCaml model of the whole chip at register level, including the LCU, FIFOs, pins and IRQs.</li><li>It runs in the same process as Hardcaml's Cyclesim for lockstep comparison (§17).</li><li>A command-line front end runs a program with pin and FIFO stimulus, then prints waveforms or writes VCD. Programs can be developed with no hardware.</li></ul> |
| `polyglot` (MicroPython) | Host library on the RP2350 | SPI host link driven by an RP2350 PIO state machine (any pins, up to 15 MHz). `Chip.load(prog, sm, pins…, freq=)`, `sm.put()`/`get()`, `exec`, `halt`/`step`, register dump. **Accepts programs from MicroPython's `@rp2.asm_pio` decorator** **[verify the program object format in week 1]**, so moving an existing MicroPython PIO script onto Polyglot is a one-line change. Extension instructions go in with `word()`. |
| `programs/` | Program library | One directory per protocol: `.pio` source, host script, expected trace, and the test that checks it. |

The opam lock file pins Hardcaml to one release. That release's source is kept checked out locally as the reference for its API.

### 17. Verification plan

The write-up is weighted heavily, so verification is designed in from the start rather than added at the end.

| Layer | Method | What it proves |
| --- | --- | --- |
| **V1. Golden model against silicon** | Run base-ISA programs (pico-examples plus randomly generated programs) on a real RP2350 PIO, which a Pico 2 board provides. A second SM samples pins at sysclk as a logic analyser. Compare the traces with `pgsim` cycle by cycle. | The reference model matches real PIO silicon, before our chip exists |
| **V2. RTL against model, in lockstep** | <ul><li>Hardcaml's Cyclesim and `pgsim` run in one OCaml process. On every cycle they compare each SM's PC, X, Y, ISR, OSR, shift counts, FIFO levels and stall reason, and each pad's value and output-enable.</li><li>Quickcheck generates constrained-random legal programs, configurations, and FIFO and pin stimulus. It shrinks any failure to a minimal program.</li><li>Short runs go in CI. Long runs use Verilator on the generated Verilog.</li><li>Expect tests hold waveforms printed by hardcaml_waveterm, so any change in behaviour shows up as a diff in review.</li></ul> | RTL equals the model, and therefore real PIO, for the base ISA. Extensions are covered by the model's spec. |
| **V3. Formal** | <ul><li>Block-level properties, listed below.</li><li>hardcaml_verify (SAT-based) checks combinational equivalence, for example the RTL decoder against `isa/decode`, and the serial CRC against a combinational reference.</li><li>SymbiYosys checks sequential properties on the generated Verilog.</li></ul> | Properties that hold for all inputs, not just sampled ones |
| **V4. Protocol level** | <ul><li>cocotbext-uart, cocotbext-spi and cocotbext-i2c act as link partners on the generated Verilog.</li><li>sigrok protocol decoders (`sigrok-cli` on simulation VCDs) cover UART, SPI, I2C, USB, CAN, 1-Wire, JTAG, SWD and PS/2.</li><li>`zlib.crc32` and a frame parser cover Ethernet.</li></ul> | Each program interoperates with code somebody else wrote |
| **V5. Gate level** | The TT `gl_test`, plus a regression subset on the post-PnR netlist (sg13cmos5l cell models and the SRAM behavioural model) | Synthesis and PnR didn't change behaviour. Reset reaches a known state. |
| **V6. Coverage** | Functional coverage bins collected in the OCaml testbench (opcode × field × stall reason × configuration), plus Verilator line and toggle coverage on the generated Verilog. Targets: 100% of opcode and field bins, ≥95% toggle coverage in the SM and LCU. | Tests exercise the design space |
| **V7. Mutation testing** | Single faults are injected into the generated Verilog (flipped conditions, off-by-one counters, swapped muxes; YosysHQ's mcy can generate them), then the suite is rerun. Report the kill rate. This is Tier 0 because the tests are written by AI. | The tests are sensitive, not just passing |
| **V8. Post-silicon** | microcotb hardware-in-the-loop tests on the demo board. Differential runs: the same program on the RP2350's PIO and on Polyglot, with traces compared. | The chip matches its reference on real hardware |

Formal properties (V3) are proven in one of two ways:

- With `sby` on the generated Verilog, using `prove` where possible and bounded model checking otherwise.
- With hardcaml_verify, where the property is combinational.

The properties are:

- **FIFO:** order is preserved and nothing is lost or duplicated (tracked-token proof). Flags are consistent with the level.
- **Clock divider:** ticks are spaced at the integer part or the integer part + 1, and the long-run average equals INT.FRAC.
- **Host link:** writing then reading an RW register returns the written value. Deasserting CS mid-frame leaves no side effect beyond completed words. MISO is stable while SCK is high.
- **SM:** per-instruction pre/post-condition assertions (for example, `jmp x--` branches if and only if X≠0 before it, and X then decrements). Without a stall, PC advances after exactly delay+1 ticks. Side-set applies on the first tick.
- **LCU:**
  - With STUFF_EN, the coded line never carries more than N run bits.
  - Loopback identity: decode(encode(x)) = x for NRZI, Manchester and stuffing.
  - The serial CRC equals a combinational reference CRC over k bits (k ≤ 16).

#### 17.1 Built by AI: keeping the checks independent

AI tools write all the code in this project under human direction: the RTL, model, assembler, tests and documentation.

- The rules don't limit AI use, but the write-up has to say how AI tools were used.
- Jane Street lists AI-assisted verification as an interest.
- So the write-up should centre on the question "why should anyone trust an AI-designed chip?" and answer it with evidence.

The main risk is a common-mode error. If the same misunderstanding of the spec gets into the RTL, the model and the tests, every comparison between them passes. So every layer is checked against at least one reference that no AI wrote:

| Reference (not AI-written) | What it checks |
| --- | --- |
| RP2350 PIO silicon | The base-ISA behaviour of `pgsim` (V1), and of the chip after tape-out (V8) |
| Raspberry Pi's official `pioasm` | Every `pgasm` encoding, byte for byte |
| cocotbext-uart, -spi and -i2c | The UART, SPI and I2C programs |
| sigrok protocol decoders | Every protocol they can decode |
| `zlib.crc32` and the check values in the published CRC catalogue (reveng) | Every CRC configuration in §10.2 |
| SymbiYosys, hardcaml_verify, Verilator, the Tiny Tapeout flow | Proofs, coverage and sign-off. AI writes their inputs but not the checkers themselves. |

Workflow rules:

- **Separate sessions.** One AI session writes the RTL and another writes the model and tests. Each works from this document, not from the other's code, so a misreading in one isn't copied into the other.
- **CI decides.** A change is accepted only when CI passes. An AI's claim that something works doesn't count on its own.
- **Mutation testing is Tier 0** (V7). It measures whether the AI-written tests actually catch injected bugs.
- **Humans own the decisions:**
  - changes to this spec;
  - the week-3 gate;
  - the wording of every formal property, which is short enough to review;
  - hardware bring-up;
  - the submission.
- **Log everything.** For each piece of work, `docs/ai-usage.md` records the tool and model used, the task, what checked the result, and what was found. Git commit trailers record AI co-authorship.

### 18. Repository layout

```
info.yaml                 # tiles "8x4", clock_hz 60000000, top tt_um_aryankarnati_polyglot
dune-project  polyglot.opam  polyglot.opam.locked   # Hardcaml pinned here
isa/                      # OCaml: instruction type, encode, decode
hw/                       # Hardcaml RTL
  sm.ml  lcu.ml  hostlink.ml  regs.ml  imem.ml  pins.ml  fifo.ml  clkdiv.ml  efifo.ml  top.ml
  bin/gen_verilog.ml      # writes src/polyglot.v
  test/                   # expect tests, lockstep against pgsim, Quickcheck
src/
  project.v               # hand-written tt_um_* wrapper: pad mapping only
  polyglot.v              # GENERATED from hw/; never edited by hand
  config.json             # CLOCK_PERIOD, density, SRAM MACROS (Tier 1)
test/                     # cocotb (template layout; GL via GATES=yes) + cocotbext protocol tests
formal/                   # *.sby + properties, hardcaml_verify checks
sw/pgasm/  sw/pgsim/      # OCaml assembler and golden model
sw/host/                  # MicroPython host library
programs/                 # protocol programs + expected traces
silicon-ref/              # RP2350 PIO trace capture for V1/V8 (MicroPython)
docs/                     # PLAN.md, info.md, architecture, ISA, verification write-up, ai-usage.md
```

### 19. Schedule and scope tiers

| Tier | Scope | Rule |
| --- | --- | --- |
| **0 (must ship)** | 4 SMs, base ISA, IMEM, host link, pins with open-drain, debug. UART, SPI and I2C (controller and target), WS2812 and logic-analyser programs. V1–V7. GDS, precheck and GL passing at ≥50 MHz. | Never at risk |
| **1 (should)** | LCU, plus USB LS device and 10BASE-T TX in simulation. SRAM elastic FIFOs. 60 MHz closure. | Behind gates |
| **2 (could)** | CAN, 10BASE-T RX, FPGA demo video, formal miter against a separate spec engine | Only with slack |

| Week | Dates | Deliverables |
| --- | --- | --- |
| 1 | Nov 19–25 | <ul><li>Merge the IHP template and set 8x4, the name and 60 MHz.</li><li>Set up the OCaml project with Hardcaml pinned. Write the clock divider and FIFO in Hardcaml and get them green through GDS, precheck and GL (**Hardcaml gate**, below).</li><li>Write the `isa/` types, `pgsim` for the base ISA, and `pgasm` matching pioasm byte for byte.</li><li>First RP2350 trace capture (V1).</li><li>Human tasks: sign up, order a Pico 2, and email the organisers (§20 open questions).</li></ul> |
| 2 | Nov 26–Dec 2 | SM in Hardcaml, integrated with the FIFOs and clkdiv. Lockstep harness against `pgsim` and the Quickcheck program generator. V1 passing on pico-examples. Formal on FIFO and clkdiv. |
| 3 | Dec 3–9 | Host link, registers, IMEM, pins, 4-SM top. **First full hardening: area and timing gate. SRAM gate.** |
| 4 | Dec 10–16 | UART, SPI and I2C programs passing against cocotbext models. Formal on the host link, with all proofs running in CI. GL regression in CI. First mutation-testing run. |
| 5 | Dec 17–23 | LCU RTL, model and formal properties. Elastic FIFO if it passed the gate. |
| 6 | Dec 24–30 | USB LS and 10BASE-T TX programs in simulation. Coverage push. (Holiday buffer.) |
| 7 | Dec 31–Jan 6 | **Feature freeze.** Timing closure at all corners. Mutation testing. Full GL regression. |
| 8 | Jan 7–13 | Docs: architecture, ISA, verification write-up, `docs/info.md`. Final hardening. Optional demo video. |
| — | Jan 14–18 | Buffer. Make the repo public, then submit. |

**Hardcaml gate (end of week 1):** if a Hardcaml-generated design isn't through GDS, precheck and GL by Nov 25, the RTL is written directly in Verilog instead.

- The OCaml ISA, assembler, model and tests stay.
- The lockstep harness drives the Verilog through Verilator instead of Cyclesim.

[docs/PLAN.md](docs/PLAN.md) breaks this schedule into parallel lanes, one per AI session plus one for the person directing, with the handoffs between them and the check that ends each week.

### 20. Risks and open questions

| Risk | Mitigation |
| --- | --- |
| Timing closure at the slow corner for 60 MHz | Constrain at 15 ns from week 2. Can pipeline the IMEM read. 50 MHz fallback (Tier 0 still fully works). |
| SRAM macro integration or precheck problems | Tier 1 only, with a gate in week 3. Follow the known-good walkthrough. Floorplan space is reserved either way. |
| Corner cases in PIO compatibility (autopull/autopush timing, stall plus side-set, EXEC) | V1 checks the model against real silicon, and V2 checks the RTL against the model. Differences are documented. |
| USB and Ethernet electrical margins | USB LS: 3.3 V GPIO with series resistors and a switchable 1.5k pull-up. 10BASE-T TX: resistor network plus magnetics, as in Pico-10BASE-T. RX needs a comparator Pmod (Tier 2). |
| Host-link bandwidth for line-rate TX | Elastic FIFOs, or SCK ≥ 12 MHz streaming from an RP2350 PIO with DMA |
| Perceived as "another PIO clone" | Lead with binary compatibility, verification against silicon, and the LCU's generic, composable primitives (§3). Demo third-party programs we never looked at. |
| Licences | ISA reimplemented from public documentation. No Raspberry Pi RTL used. Keep upstream licences on bundled example programs (pico-examples is BSD-3). Hardcaml is MIT-licensed. |
| AI tools write Hardcaml less fluently than Verilog and may invent APIs | Pin one Hardcaml release and keep its source locally as the reference. The OCaml compiler rejects invented APIs immediately. Hardcaml gate at the end of week 1 (§19). |
| The same AI misunderstanding ends up in the RTL, the model and the tests | References no AI wrote, separate sessions, and mutation testing (§17.1) |
| Generated Verilog is hard to read when debugging gate-level or timing problems | Name signals in Hardcaml so the names survive into the Verilog, and keep the module hierarchy |
| Judges may weigh a fully AI-built entry differently | Disclose fully and make the trust argument the centre of the write-up (§17.1). Ask the organisers (question 2). |

Open questions for the team:

1. The final name and top module. `tt_um_aryankarnati_polyglot` is a placeholder.
2. Is Hardcaml-generated Verilog acceptable? Does a fully AI-built entry need anything beyond the disclosure the rules ask for? Ask both in the same email as question 4.
3. Hardware on hand.
   - **A Pico 2 is being ordered for V1.** Polyglot isn't fabricated until the March 2027 shuttle, so the Pico 2 is the only real PIO hardware available before submission. It's also the one reference for PIO behaviour that no AI wrote (§17.1). An original Pico (RP2040) or a TT demo board would also work. On a WSL2 development machine it needs usbipd-win to reach Linux.
   - **Is there an FPGA board for early bring-up?** The template's iCE40UP5K is too small for 4 SMs, but a build parameterised to 2 SMs might fit.
4. Confirm the deadline time and timezone with the organisers (asic-competition@janestreet.com).

---

## Appendix A: Platform facts (from research, 2026-11-19)

**Tiny Tapeout IHP template and flow**

- `info.yaml`: `yaml_version: 6`. Valid `tiles` values include `"8x4"`. The top module must start with `tt_um_`. Pinout keys are `ui[0..7]`, `uo[0..7]`, `uio[0..7]`.
- Ports: `ui_in[7:0]`, `uo_out[7:0]`, `uio_in[7:0]`, `uio_out[7:0]`, `uio_oe[7:0]` (1 = output), `ena`, `clk`, `rst_n`.
- Template `src/config.json`: `CLOCK_PERIOD: 20`, `PL_TARGET_DENSITY_PCT: 60`, CTS on.
- CI: `TinyTapeout/tt-gds-action@ttihp27a` with `pdk: ihp-sg13cmos5l` (LibreLane 3.1.0.dev4), followed by the `precheck`, `gl_test` and `viewer` actions.
- Tests: cocotb 2.0.1, pytest 8.4.2, Icarus. GL runs with `GATES=yes` using the sg13cmos5l cell models.
- Tile sizes: 1x1 = 202.08 × 154.98 µm. **8x4 = 1724.16 × 710.64 µm.**
- CMOS5L stack: Metal1–4 plus TopMetal1. Per the SRAM walkthrough, tiles route on Metal2–4 and the PDN is on Metal4.

**SG13G2 / CMOS5L standard cells** (the two LEFs are identical; row height 3.78 µm)

| Cell | Area (µm²) |
| --- | --- |
| inv_1 | 5.44 |
| nand2_1 | 7.26 |
| xor2_1 | 14.52 |
| mux2_1 | 18.14 |
| dfrbp_1 (flop with reset) | 52.62 |
| dfrbpq_1 | 48.99 |
| dlhq_1 (latch) | 30.85 |

Typical-corner timing: flop clock-to-Q about 0.16–0.22 ns; nand2 about 23–87 ps.

**SRAM** (`libs.ref/sg13cmos5l_sram` is a symlink to the G2 set)

| Macro | Size (µm) | Area (µm²) |
| --- | --- | --- |
| 1P_512x32 | 416.64 × 191.34 | 79,720 |
| 1P_256x32 | 416.64 × 118.78 | 49,489 |
| 1P_64x16 | 236.80 × 64.36 | 15,240 |

- Dual-port (2P) macros also exist.
- The 1P_512x32 interface: `A_CLK`, `A_MEN`, `A_WEN`, `A_REN`, `A_ADDR`, `A_DIN`, `A_BM` (bit mask), `A_DLY` (tie to 1), `A_DOUT`. The `A_BIST_*` pins are tied off. Read latency is 1 cycle.

**Demo board**

- RP2350 running MicroPython with the TT SDK.
- Pin wiring: reset on GPIO14, clock on GPIO16, `ui_in` on GPIO17–24, `uio` on GPIO25–32, `uo_out` on GPIO33–40.
- Three Pmods carry all project I/O (in, bidir, out).
- SDK calls: `clock_project_PWM(f)`, `reset_project()`, and modes `RPMode.ASIC_RP_CONTROL` and others.

## Appendix B: References

**Competition**
- https://tinytapeout.com/competitions/jane-street-tt-protocol-emulator/
- https://blog.janestreet.com/protocol-emulator-asic-competition/

**Tiny Tapeout template, flow and board**
- Template: https://github.com/TinyTapeout/ttihp-verilog-template
- Tile sizes: https://raw.githubusercontent.com/TinyTapeout/tt-support-tools/main/tech/ihp-sg13cmos5l/tile_sizes.yaml
- Demo board: https://github.com/TinyTapeout/tt-demo-pcb
- MicroPython SDK: https://github.com/TinyTapeout/tt-micropython-firmware
- Local hardening guide: https://tinytapeout.com/guides/local-hardening/

**IHP process and SRAM**
- PDK SRAM macros: https://github.com/IHP-GmbH/IHP-Open-PDK/tree/main/ihp-sg13g2/libs.ref/sg13g2_sram
- SRAM integration walkthrough: https://kdp1965.github.io/ihp-um-janestreet-prism/ihp_sram_macro.html
- TT SRAM example: https://github.com/urish/ttihp-sram-test

**PIO and its ecosystem**
- pico-sdk PIO headers: https://github.com/raspberrypi/pico-sdk/tree/master/src/rp2_common/hardware_pio
- RP2040 datasheet §3 (PIO), RP2350 datasheet §11

**Protocol references implemented on PIO and microcontrollers**
- Pico-PIO-USB: https://github.com/sekigon-gonnoc/Pico-PIO-USB
- Pico-10BASE-T: https://github.com/kingyoPiyo/Pico-10BASE-T
- V-USB: https://www.obdev.at/blog/implementing-usb-1-1-in-firmware

**Verification tools**
- cocotb: https://www.cocotb.org/2026/09/01/cocotb-2.1
- cocotbext-uart, -i2c, -eth: https://github.com/alexforencich
- SymbiYosys: https://symbiyosys.readthedocs.io/
- mcy (mutation cover with Yosys): https://github.com/YosysHQ/mcy
- sigrok protocol decoders: https://sigrok.org/wiki/Protocol_decoders

**Hardcaml and OCaml**
- Hardcaml: https://github.com/janestreet/hardcaml
- hardcaml_waveterm, hardcaml_step_testbench, hardcaml_verify: https://github.com/janestreet
- A Tiny Tapeout project built with Hardcaml (unofficial): https://github.com/matthewelse/tt

**Alternatives considered**
- FABulous: https://github.com/FPGA-Research/FABulous
- Tiny FABulous FPGA (IHP): https://github.com/mole99/tt-fabulous-ihp-26a
- Greyhound IHP: https://github.com/mole99/greyhound-ihp
- TinyQV: https://github.com/MichaelBell/tinyQV
- PRISM: https://github.com/kdp1965/ihp-um-janestreet-prism
