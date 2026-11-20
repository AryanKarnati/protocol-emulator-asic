# protocol-emulator-asic

**Polyglot** is an entry for the Jane Street × Tiny Tapeout Protocol Emulator ASIC competition. It puts four engines whose instruction set is binary-compatible with RP2040 PIO on IHP 130 nm. Each engine has its own Line Coding Unit, which handles CRC, bit stuffing and line codes. The RTL is planned in Hardcaml, and the tools and tests in OCaml.

![Polyglot top-level block diagram](docs/img/polyglot-top.svg)

- [COMPETITION.md](COMPETITION.md): rules, deadline and judging.
- [DESIGN.md](DESIGN.md): the three architectures considered, and the full Polyglot specification.
- [docs/PLAN.md](docs/PLAN.md): the build plan, in eight blocks with parallel work lanes.

Status: design baseline v0.2 and build plan. No RTL yet.
