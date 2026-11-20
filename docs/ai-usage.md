# AI usage log

DESIGN.md §17.1 requires this log. AI tools write all the code in this project under human direction. For each piece of work, this file records:

- the tool and model;
- the task;
- what checked the result;
- what the check found.

Git commit trailers also record AI co-authorship.

## How block 1 was run

- **Orchestrator:** Claude Opus 5.5 in Claude Code, directed by the project owner. It split the work into lanes ([PLAN.md](PLAN.md)), wrote the gate design contract ([gate.md](gate.md)), made rulings where the spec was silent, and merged work only after a check passed.
- **Workers:** Claude Haiku 5.5 subagents, one per lane. Each worked in its own git worktree.
- **Checkers:** Claude Sonnet 5.5 subagents. They read and ran things only, and reported to the orchestrator. Fixes went back to the worker that wrote the code.
- **Firewall:** the RTL worker and the test worker built from the same written contract and never read each other's code.

## Block 1 log

| Task | Worker | What checked it | What the check found |
| --- | --- | --- | --- |
| Gate design contract (`docs/gate.md`) and later clarifications | Orchestrator (Opus 5.5) | The two workers who built from it. Each reported its ambiguities independently. | 12 ambiguities, including reset release timing, first-tick counting, and `TICK` across a restart. Each was resolved in the contract before the RTL was checked. |
| Tiny Tapeout template merge, `info.yaml`, OCaml skeleton, CI | Haiku 5.5 (Flow lane) | Sonnet checker: diffed against the upstream template, YAML and JSON parses, `iverilog` compile of `tb.v` against a stub | Pass. Should-fixes: an unpinned compiler in CI, and a stale test README. Both fixed in part 2. |
| opam lock file, dune 3.17, compiler pin, `.gitignore` | Haiku 5.5 (Flow lane) | Sonnet checker: `opam install --locked --dry-run`, setup-ocaml docs | Pass |
| Official `pioasm` build and the pico-examples golden corpus | Haiku 5.5 (ISA & tools lane) | Sonnet checker: re-ran the official `pioasm` 2.3.1 on all 26 files and compared outputs byte for byte; counted `.pio` files upstream | Pass. 26 files, 36 programs, no PIO v1 programs. |
| Pico 2 capture script (`silicon-ref/`) | Haiku 5.5 (ISA & tools lane); fixes by a second Haiku 5.5 worker | Sonnet checker: reviewed against the RP2350 register headers in pico-sdk 2.3.1, then independently decoded 33 of the 51 expected register writes | **Fix needed:** pads were left isolated, which would give a flat trace; stale FIFO data leaked into the next capture; DMA channels were never released; and the docs claimed a dry run that had no test behind it. All fixed, and the re-check passed. Still untested on hardware. |
| Instruction set library (`isa/`) | Haiku 5.5 (ISA & tools lane) | Sonnet checker: compared 1321 words with pico-sdk's `pio_encode_*` functions and 74 instruction forms with the official `pioasm`; injected 5 bugs | 0 encoding mismatches; all 5 injected bugs caught. **Fix needed:** there was no single legality predicate (a common-mode risk), plus missing accessors and test guards. Fixed, and the re-check passed. |
| Gate design cocotb test (`test/test.py`) | Haiku 5.5 (Model & tests lane) | Sonnet checker: mapped every spec rule to a test and wrote 7 mutants of its own | Pass, but 2 of the checker's 7 mutants escaped (`TICK` dropped after a restart, and an `INT_LO` write clearing the high byte), and several rules had no test. Fixed: 13 default tests and 2 long tests, and all 9 mutants are now caught. |
| Gate design RTL (Hardcaml: clock divider, FIFO, top, `project.v`) | Haiku 5.5 (RTL lane) | Sonnet checker: ran the independently written cocotb test against the RTL; regenerated the Verilog and diffed it; Verilator lint; yosys `check -assert`; line-by-line review | **The independent test passed first time:** 13/13 by default and 15/15 with the long tests. **Fix needed:** a build warning under dune 3.17, and `--` signal names attached to the wrong nets because of operator precedence. Both fixed. |

## Rulings the orchestrator made

These are pending the project owner's approval, since only the owner changes DESIGN.md.

1. **`in status` (IN source 101).** The official `pioasm` assembles it, but DESIGN.md §9.1 and the RP2040 datasheet list it as reserved. `pgasm` stays byte-compatible with `pioasm`. The chip and the model treat it as reserved: it executes as a NOP and sets `ILLEGAL`. V1 on the Pico 2 will show what silicon does.
2. **WAIT irq index bit 3, IRQ bit 7 and IRQ index bit 3** are treated as reserved. These bits are RP2350 PIO v1's PREV and NEXT encodings, and `pioasm` never emits them for version 0. V1 will show what silicon does.
3. **The three Polyglot extension slots** (IN source 100, MOV source 100, SET destination 011) are still unused in RP2350 PIO v1, according to `pioasm` 2.3.1's disassembler and the SDK's enums. The RP2350 datasheet itself has not been checked yet.
