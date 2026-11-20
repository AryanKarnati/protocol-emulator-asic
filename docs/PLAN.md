# Polyglot build plan

The work from now to the January 18, 2027 deadline, in eight blocks of about a week. Inside each block, four AI sessions and the person directing them work in parallel lanes. The lanes meet at handoffs, and each block ends at a check before the next one starts.

This plan carries out the schedule in [DESIGN.md §19](../DESIGN.md#19-schedule-and-scope-tiers) and the AI workflow rules in [§17.1](../DESIGN.md#171-built-by-ai-keeping-the-checks-independent). If the two disagree, DESIGN.md wins.

## Lanes

| Lane | Who | Owns | Checked against | Never reads |
| --- | --- | --- | --- | --- |
| **RTL** | AI session | The circuits in `hw/`, `src/project.v`, and the generated `src/polyglot.v` | Lockstep with `pgsim`, the proofs, the Tiny Tapeout flow | `sw/pgsim/`, `hw/test/`, `test/`. It sees only the failing cases CI reports. |
| **Model & tests** | AI session | `sw/pgsim/`, `hw/test/`, `test/` | RP2350 PIO silicon, cocotbext link partners, sigrok decoders | The circuit bodies in `hw/`. It uses their port interfaces only. |
| **ISA & tools** | AI session | `isa/`, `sw/pgasm/`, `sw/host/`, `programs/`, `silicon-ref/` | Official `pioasm`, byte for byte, and the Pico 2 | No limit. Its output is checked against outside references. |
| **Flow & proofs** | AI session | `info.yaml`, CI, `src/config.json`, `formal/`, mutation and coverage runs | The TT flow and precheck, SymbiYosys, hardcaml_verify, mcy | No limit, but properties are written from DESIGN.md, not from the RTL. |
| **You** | The person directing | Sign-up, the Pico 2, email to the organisers, the submission. Decides every gate, every spec change, the Tier 2 scope and the freeze. Reviews the wording of every formal property and the final docs. | | |

RTL and Model & tests are firewalled from each other, so a misreading of the spec in one can't be copied into the other.

### Rules for every lane

- One lane per session, each in its own git worktree. Work merges to `main` only when CI is green.
- RTL and Model & tests never read each other's code. Both build from DESIGN.md and share only `isa/`, which is checked byte for byte against official `pioasm`.
- A lane that finds a gap in the spec stops and asks. Only the person directing changes DESIGN.md.
- Every session logs its task, model, what checked the result and what was found in `docs/ai-usage.md`.

## At a glance

| Block | Dates | RTL | Model & tests | ISA & tools | Flow & proofs | You | Ends with |
| --- | --- | --- | --- | --- | --- | --- | --- |
| [1. Foundations](#block-1-foundations) | Nov 19–25 | Clock divider, FIFO, pad wrapper | `pgsim` for the base ISA | `isa/` first, then `pgasm` | Template, CI, Hardcaml gate | Sign up, Pico 2, email | **Hardcaml gate** (gate), Nov 25 |
| [2. One engine](#block-2-one-engine) | Nov 26–Dec 2 | State machine core | Lockstep harness, Quickcheck | Silicon captures on the Pico 2 | Decoder equivalence, FIFO proofs | Connect Pico 2, review proofs | Exit check, Dec 2 |
| [3. Whole chip](#block-3-whole-chip) | Dec 3–9 | Host link, IMEM, pins, 4-SM top | Whole-chip model | MicroPython host library | First full hardening | Area, timing and SRAM calls | **Area, timing and SRAM gate** (gate), Dec 9 |
| [4. Tier 0 protocols](#block-4-tier-0-protocols) | Dec 10–16 | Fix queue, timing fixes | cocotbext and sigrok tests | Tier 0 protocol programs | Proofs and GL in CI, mutation run | Review proofs and mutation report | **Tier 0 complete** (milestone), Dec 16 |
| [5. Line Coding Unit](#block-5-line-coding-unit) | Dec 17–23 | Line Coding Unit | LCU model, CRC catalogue | `pgasm` LCU extensions | LCU proofs, re-harden | Review LCU proofs | Exit check, Dec 23 |
| [6. Showcase protocols](#block-6-showcase-protocols) | Dec 24–30 | Coverage fixes, 60 MHz at all corners | Coverage closure | USB LS and 10BASE-T programs | USB and Ethernet checks, nightly runs | Tier 2 call | **Feature freeze** (milestone), Dec 31 |
| [7. Freeze and sign-off](#block-7-freeze-and-sign-off) | Dec 31–Jan 6 | Fixes only | Full regression, kill mutants | Third-party program demos | Corners, GL, precheck | Declare the freeze | Sign-off, Jan 6 |
| [8. Write-up and submit](#block-8-write-up-and-submit) | Jan 7–18 | Architecture doc | Verification write-up | ISA reference, programming guide | Final GDS, AI-usage log | Review, publish, submit | **Submit** (milestone), Jan 18 |

Gates are go or no-go calls. Milestones mark a scope boundary. Exit checks are the conditions for moving to the next block.

## Block by block

### Block 1: Foundations

*Week 1 · Nov 19–25 · Tier 0*

Prove the toolchain end to end, and define the instruction set once so every tool shares it.

**RTL**

- Clock divider (INT.FRAC) and synchronous FIFO in Hardcaml, written against the pinned release
- `gen_verilog.exe` writes `src/polyglot.v` with readable signal names
- Hand-written `src/project.v` mapping the §5 pins

**Model & tests**

- `pgsim` for the base ISA: PC, X, Y, ISR, OSR, shift counters, side-set, delays, stalls, IRQs
- Autopush, autopull and FIFO levels
- Command-line runner that writes VCD
- Trace compare tool for V1: model against silicon

**ISA & tools**

- `isa/`: one variant type with `encode` and `decode`, done first
- `pgasm`: pioasm syntax to hex and JSON
- Byte-identical to official `pioasm` on every pico-examples program
- `silicon-ref/` capture script: one SM runs the program, a second samples the pins every cycle

**Flow & proofs**

- Merge the IHP template; set `info.yaml` to 8x4, 60 MHz and the top module
- `dune-project` and opam lock with Hardcaml pinned, its source checked out as the API reference
- CI: build, `dune test`, regenerate Verilog and fail on any diff, then TT GDS, precheck and GL
- Run the gate design through the flow

**You**

- Sign up for the competition
- Order the Pico 2 and install usbipd-win on Windows
- Email the organisers: deadline time zone, Hardcaml-generated Verilog, AI-built entry
- Make the Hardcaml gate call on Nov 25

**Handoffs**

- ISA & tools → RTL, Model & tests: `isa/` types with `encode` and `decode` (by Nov 21)
- RTL → Flow & proofs: Gate design: clock divider, FIFO and pad wrapper (by Nov 23)
- You → ISA & tools: The Pico 2, once it arrives

**Ends with: Hardcaml gate, Nov 25** (gate). Hardcaml-generated Verilog passes GDS, precheck and GL in CI, and `pgasm` matches `pioasm`. If the Hardcaml part fails, the RTL lane switches to Verilog. Everything in OCaml stays, and lockstep drives Verilator instead of Cyclesim.

### Block 2: One engine

*Week 2 · Nov 26–Dec 2 · Tier 0*

One state machine in RTL running cycle for cycle with the model, and the model matching real PIO silicon.

**RTL**

- State machine core: fetch, decode through `isa/`, all nine instructions
- Delay, side-set, stall logic, autopush and autopull, EXEC
- Integrate the FIFOs and clock divider

**Model & tests**

- Lockstep harness: Cyclesim and `pgsim` in one process, state compared every cycle
- Quickcheck generator for legal programs and stimulus, with shrinking
- hardcaml_waveterm expect tests

**ISA & tools**

- Run pico-examples and random programs on the Pico 2; store the traces in `silicon-ref/`
- `pgasm` output as a MicroPython module
- `programs/` layout: `.pio`, host script, expected trace and test for each protocol

**Flow & proofs**

- hardcaml_verify: the RTL decoder equals `isa/decode`
- SymbiYosys properties for the FIFO and clock divider
- Constrain at 15 ns; harden one SM for an early timing number

**You**

- Plug in the Pico 2 and attach it to WSL with usbipd
- Review the FIFO and clock-divider property wording

**Handoffs**

- ISA & tools → Model & tests: Silicon traces from the Pico 2, for V1
- Model & tests → RTL: Failing cases as shrunk programs, never model code
- Flow & proofs → You: FIFO and clock-divider property wording to review

**Ends with: Exit check, Dec 2** (exit check). V1: `pgsim` matches the Pico 2 on pico-examples. V2: one SM runs in lockstep with `pgsim` on pico-examples and 10,000 random programs. The decoder equivalence is proven.

### Block 3: Whole chip

*Week 3 · Dec 3–9 · Tier 0*

Put the four engines, host link, instruction memory and pins together, and harden the whole chip once.

**RTL**

- Host link: SPI mode 0 target on a 32-bit register bus
- Register map and IRQ flags, with HOST_IRQ on `uo_out[6]`
- IMEM: 64×16 in two pages, with four read ports
- Pin block with open-drain; the 4-SM top with its four parameters

**Model & tests**

- Whole-chip `pgsim`: registers, host-link frames, pins, IRQs
- Top-level lockstep, driven through the host link
- Host-link edge cases: CS dropped mid-frame, back-to-back frames

**ISA & tools**

- MicroPython `polyglot` library: `Chip.load`, `put`, `get`, `exec`, `halt`, `step`, register dump
- Host link driven by an RP2350 PIO at up to 15 MHz
- Accept `@rp2.asm_pio` program objects (check the format first)

**Flow & proofs**

- First full hardening of the 4-SM top: area and slow-corner timing
- Trial SRAM macro (1P_512x32), following the known-good walkthrough
- Host-link properties in SymbiYosys

**You**

- Area and timing call, from the hardening report
- SRAM call: keep or drop the elastic FIFOs

**Handoffs**

- RTL → Flow & proofs: The complete 4-SM top, for hardening (by Dec 6)
- Model & tests → RTL: Top-level lockstep failures
- Flow & proofs → You: Area and timing report for the gate (Dec 9)

**Ends with: Area, timing and SRAM gate, Dec 9** (gate). Go ahead if utilisation is at most 55% and slow-corner slack is at least 0 at 60 MHz. If not, in this order: drop the SRAM, pipeline the IMEM read, cut to 3 SMs. You also decide whether the elastic FIFOs stay.

### Block 4: Tier 0 protocols

*Week 4 · Dec 10–16 · Tier 0*

Every Tier 0 protocol works against code that nobody on this project wrote.

**RTL**

- Work the fix queue from the other lanes
- Timing fixes from the first hardening
- Debug path: halt, single step, register read-back

**Model & tests**

- cocotb tests on the generated Verilog, with cocotbext-uart, -spi and -i2c at the other end of the link
- sigrok-cli decodes of simulation VCDs
- Protocol tests added to CI

**ISA & tools**

- UART TX and RX; SPI controller (modes 0–3) and target
- I2C controller and target, WS2812, logic analyser
- Expected traces from `pgsim` and a host script for each

**Flow & proofs**

- FIFO, clock-divider and host-link proofs running in CI
- GL regression subset in CI (`GATES=yes`)
- First mutation run with mcy; record the kill rate

**You**

- Review the host-link property wording
- Read the mutation report and pick which surviving mutants need tests

**Handoffs**

- ISA & tools → Model & tests: Protocol programs with expected traces
- Model & tests, Flow & proofs → RTL: Failures for the fix queue
- Flow & proofs → Model & tests, You: Mutation report with the surviving mutants

**Ends with: Tier 0 complete, Dec 16** (milestone). UART, SPI, I2C, WS2812 and logic-analyser programs pass against cocotbext and sigrok. FIFO, clock-divider and host-link proofs and the GL regression are green in CI. The first mutation kill rate is recorded.

### Block 5: Line Coding Unit

*Week 5 · Dec 17–23 · Tier 1*

The LCU in RTL and in the model, with every CRC setting checked against published values.

**RTL**

- CRC LFSR up to 32 bits, bit stuffing, NRZ, NRZI, Manchester, differential pair
- DPLL receive and virtual pins 24–27
- Elastic FIFO streamer, if the SRAM gate passed

**Model & tests**

- LCU in `pgsim`; LCU settings added to the Quickcheck generator
- CRC tests against `zlib.crc32` and the reveng catalogue check values

**ISA & tools**

- `pgasm` extensions: `in lcu`, `mov …, crc`, `set lcu`, `.page`, `.lcu`
- `.lcu` parameters converted to register values
- ISA reference for the extensions

**Flow & proofs**

- LCU properties: stuffing run bound, decode(encode(x)) = x, serial CRC equals combinational CRC
- Re-harden with the LCU, and the SRAM if kept

**You**

- Review the LCU property wording

**Handoffs**

- ISA & tools → Model & tests: `pgasm` with LCU extensions, for LCU test programs
- RTL → Flow & proofs: The LCU, for re-hardening
- Flow & proofs → You: LCU property wording to review

**Ends with: Exit check, Dec 23** (exit check). The LCU runs in lockstep. Every CRC setting in §10.2 matches its catalogue check value. LCU properties are proven, and timing still closes with the LCU in.

### Block 6: Showcase protocols

*Week 6, holidays · Dec 24–30 · Tier 1*

USB low-speed device and 10BASE-T transmit working in simulation, and the coverage targets met.

**RTL**

- Fixes for coverage holes that turn out to be bugs
- Timing toward 60 MHz at every corner; pipeline the IMEM read if needed

**Model & tests**

- Functional coverage bins: opcode × field × stall reason × configuration
- Verilator line and toggle coverage; directed tests for the holes

**ISA & tools**

- USB LS device on three SMs: data receiver, token receiver, transmitter
- USB enumeration on the host in MicroPython
- 10BASE-T TX with link pulses, plus a frame builder

**Flow & proofs**

- USB checks with sigrok decoders; Ethernet checks with `zlib.crc32` and a frame parser
- Nightly long lockstep runs on Verilator

**You**

- Tier 2 call: CAN, 10BASE-T RX, a demo video, or none

**Handoffs**

- ISA & tools → Flow & proofs: USB and 10BASE-T programs for the protocol checks
- Model & tests → RTL: Coverage holes that turn out to be bugs
- Flow & proofs → You: Status for the Tier 2 call

**Ends with: Feature freeze, Dec 31** (milestone). The USB device answers SETUP, IN and OUT tokens in simulation with clean sigrok decodes. 10BASE-T frames pass `zlib.crc32` and the frame parser. Coverage reaches 100% of opcode and field bins and at least 95% toggle in the SM and LCU.

### Block 7: Freeze and sign-off

*Week 7 · Dec 31–Jan 6 · Freeze*

No new features. Fix what fails, close timing everywhere and sign the chip off.

**RTL**

- Fixes only, each with a failing test first
- Timing closure at every corner

**Model & tests**

- Full regression and long Quickcheck runs
- Tests that kill or explain every surviving mutant

**ISA & tools**

- Freeze the program library
- Run third-party PIO programs unmodified, ones nobody here has read
- Programs the chip wasn’t designed around: JTAG, SWD, PS/2, 1-Wire, DMX512

**Flow & proofs**

- Full mutation run
- Full GL regression and precheck at every corner
- Tag the frozen GDS

**You**

- Declare the feature freeze on Dec 31
- Confirm the final Tier 1 scope

**Handoffs**

- You → All AI lanes: Freeze declared (Dec 31)
- Flow & proofs → Model & tests: Surviving mutants from the full run
- RTL, Model & tests, ISA & tools → Flow & proofs: A frozen `main` for the sign-off runs

**Ends with: Sign-off, Jan 6** (exit check). Timing closes at every corner. The full GL regression and precheck are green. Every surviving mutant is killed or explained. The frozen GDS is tagged.

### Block 8: Write-up and submit

*Week 8 and buffer · Jan 7–18 · Docs*

A write-up that answers “why should anyone trust an AI-designed chip?” with evidence, then the submission.

**RTL**

- Architecture doc: block diagrams, microarchitecture, parameters

**Model & tests**

- Verification write-up: V1–V7 evidence, coverage numbers, kill rate
- The independence argument from §17.1, backed by that evidence

**ISA & tools**

- ISA reference and programming guide for `pgasm`, `pgsim` and the host library
- `docs/info.md`, the Tiny Tapeout datasheet page

**Flow & proofs**

- Final hardening on the final commit
- Compile `docs/ai-usage.md`

**You**

- Read every doc and approve it
- Make the repo public
- Submit before Jan 18, in the organisers’ time zone

**Handoffs**

- All AI lanes → You: Doc drafts for review (by Jan 13)
- Flow & proofs → You: GDS and precheck green on the final commit

**Ends with: Submit, Jan 18** (milestone). The repo is public. GDS and precheck are green on the submitted commit. The write-up covers architecture, ISA, verification and AI use. The form is sent before the deadline in the organisers’ time zone.

## Changes from the original §19 schedule

Two items start earlier so no lane waits:

- The clock divider and FIFO are built in block 1, where they are the design that goes through the Hardcaml gate.
- Their formal proofs move from week 4 to block 2.

If the Hardcaml gate fails, only the RTL lane changes language. The other lanes carry on unchanged.
