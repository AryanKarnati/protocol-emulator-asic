# Jane Street × Tiny Tapeout: Protocol Emulator ASIC Competition

Summary compiled 2026-11-19 from:

- Competition page: https://tinytapeout.com/competitions/jane-street-tt-protocol-emulator/
- Jane Street announcement and FAQ: https://blog.janestreet.com/protocol-emulator-asic-competition/ (posted Sep 10, 2026, updated Nov 9, 2026)

The two sources agree on everything. Check them again for changes before relying on any detail here.

## The goal

Design an open-source, general-purpose **programmable protocol emulator**: a small processor whose instructions read pins, drive pins and count clock cycles. Each protocol is a program you load into the chip, not a fixed circuit.

The main question in judging is whether someone can write a new program after the chip is made and get it to speak a protocol you never planned for. A chip with fixed UART, SPI and I2C blocks "misses the point."

## Key facts

| | |
|---|---|
| **Deadline** | January 18, 2027. No time of day or timezone is given. |
| **Winners announced** | Early February 2027 |
| **Fabrication** | Tiny Tapeout March 2027 shuttle, IHP 130nm CMOS5L, "subject to foundry schedule" |
| **Area** | 8x4 tiles (32 tiles, about 1.0 mm²). Rough budget is about 1K logic cells per tile. |
| **Designs fabricated** | About 4 |
| **Prize** | No cash. Jane Street pays to fabricate the winners, and you get your chip on a Tiny Tapeout demo board. |
| **Teams** | Solo or team, no size limit, one entry per team. Students and professionals can both enter. Teams are strongly recommended. |
| **Contact** | asic-competition@janestreet.com |

## What the chip must do

- **Be reprogrammable after it's made.** This is the one hard requirement. You can use a CPU, an embedded FPGA, several engines sharing a pipeline, or something else.
- **Load programs in a way you design.** The microcontroller on the demo board (an RP2350) is the obvious host, but any documented host is allowed.
- **Run UART, SPI and I2C** as programs. Suggested settings are common UART baud rates, SPI modes 0–3, and I2C at 100 and 400 kHz. There are no fixed speed requirements.
- **Stretch goals:** low-speed USB or 10 Mbit Ethernet. For those, the more of the protocol work (line coding, CRC, clock recovery) the chip does itself, the better. The blog also suggests JTAG, SWD, PS/2 and CAN.
- **Optional extras:** running several protocols at once and supporting both controller and target roles are "a plus but not required." The RP2040's PIO blocks and TI Sitara's PRU are named as inspiration.

## Technical constraints

- **Pins:** 24 digital: 8 inputs, 8 outputs and 8 bidirectional, plus clock and `rst_n`. There are no analog pads, and I/O is 3.3V. Pull-ups or level shifters have to go on a Pmod add-on board.
- **Timing:** about 10 ns round trip through the pads and pin mux, and about 66 MHz maximum output. These are estimates because no CMOS5L chips have come back yet. The RP2350 supplies the clock, and 60 MHz is confirmed to work. There is no target clock frequency.
- **Reset:** flip-flops don't start at 0, so the design must use `rst_n` to reach a known state.
- **State is lost when your design is deselected,** because it gets powered down. The program has to be reloaded every time.
- **Memory:** IHP SRAM macros are allowed, including more than one, as long as everything fits and passes precheck. They save area compared with flip-flops for instruction memory.
- **Analog inside the design** (for example a PLL) is fine if it passes precheck.
- **Flow:** start from [`TinyTapeout/ttihp-verilog-template`](https://github.com/TinyTapeout/ttihp-verilog-template) (its main branch already targets CMOS5L) and set the tiles to 8x4 in `info.yaml`. If the build passes the 6-hour GitHub Actions limit, harden locally and use the custom GDS action. The design still has to pass precheck. Don't use your own GDS flow.
- **Synthesis advice:** run synthesis early, check the area of the mapped cells, leave room for clock-tree buffers and routing, then run full place and route to check timing.

## What to submit

1. A public repo with the RTL, tests, and a GDS and precheck that pass in the Tiny Tapeout flow. You can work in a private repo and make it public when you submit.
2. Documentation of the architecture and instruction set.
3. An assembler or toolchain (or a bitstream flow), plus example programs for each protocol you support.
4. A write-up of how you verified the design. It's "weighted heavily," and it must say how you used any AI tools.
5. Gate-level simulation is strongly recommended. A video or demo is optional.

A clean run through the Tiny Tapeout flow and precheck is all the sign-off expected. After the deadline, Jane Street will work with winners on small non-functional fixes, such as re-hardening for a newer flow.

The final submission form isn't published yet. It will be added to the Jane Street blog post closer to the deadline.

## How it's judged

There is no fixed weighting.

- **Main question:** can the chip be reprogrammed for protocols it wasn't designed for?
- **Also considered:** which protocols you demonstrate, anything new your architecture makes possible, and how you built and verified it. Jane Street is interested in formal methods, constrained random testing, AI-assisted verification and different HDLs.
- A design with fewer protocols but a strong architecture and verification can still compete.

## Next steps

- [ ] **Sign up** (it doesn't commit you to anything, and no confirmation email is sent): [sign-up form](https://docs.google.com/forms/d/e/1FAIpQLSeF7fq756MegxZRQxotBwUJYZx-cL9MrGjxV0z4uD_J0sADxQ/viewform)
- [ ] **Join the Tiny Tapeout Discord** (#competitions channel) if you want teammates: https://discord.gg/rMmn8kXJng
- [ ] **Set up this repo from `ttihp-verilog-template`** and get a trivial design through the GDS and precheck steps early, before the real design exists.
- [ ] **Design the instruction set** around pin operations and cycle-exact timing, then build the assembler and simulator.
- [ ] **Run synthesis early and often** to stay inside the 32-tile budget.
- [ ] **Write verification and the write-up as you go,** since the write-up carries so much weight.
- [ ] **Submit by January 18, 2027.**

## Not stated anywhere

- The deadline's time of day and timezone.
- Whether you can write the design in a language other than Verilog, such as Hardcaml. It's probably fine if it compiles to Verilog, but that's unconfirmed.
- Which open-source license is required.
- Any country exclusions. Tiny Tapeout says it "ships worldwide"; email them if you're unsure.

Jane Street won't review individual designs before the deadline. Send questions to asic-competition@janestreet.com.

## Useful links

- Verilog template: https://github.com/TinyTapeout/ttihp-verilog-template
- Analog template (shows the custom GDS action setup): https://github.com/TinyTapeout/ttihp-analog-template
- Local hardening guide: https://tinytapeout.com/guides/local-hardening/
- Demo board spec: https://tinytapeout.com/specs/pcb-etr/
- Pinouts: https://tinytapeout.com/specs/pinouts/
- FPGA vs. ASIC: https://tinytapeout.com/hdl/fpga_vs_asic/
- SRAM example design: https://www.tinytapeout.com/chips/ttihp0p2/tt_um_urish_sram_test
- IHP SRAM macro walkthrough (CMOS5L, LibreLane): https://kdp1965.github.io/ihp-um-janestreet-prism/ihp_sram_macro.html
- Tiny Tapeout FAQ: https://tinytapeout.com/faq/
- Hardcaml: https://hardcaml.org/
