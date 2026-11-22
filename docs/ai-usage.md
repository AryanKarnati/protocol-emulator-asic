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
| Assembler (`sw/pgasm`) | Haiku 5.5 (ISA & tools lane) | Sonnet checker: re-ran the corpus against the official `pioasm`; differential fuzzing of about 1,450 valid and 2,400 mutated programs; 207 hand-written probes; its own sweep of all 65,536 instruction words under 4 side-set configurations | Output was byte-identical on every valid program. **Fix needed:** 5 places where the two assemblers disagreed on what to accept (block comments, `0X`/`0B` prefixes, the U+2212 minus, `label: .word`, `.mov_status`), the text shown for `.word` of extension and v1 words, and a corpus test that would pass with an empty corpus. All fixed. The re-check found 0 disagreements apart from the documented `.pio_version 1` non-goal. |
| Capture script side-set fix and format fixture | Haiku 5.5 (ISA & tools lane) | Sonnet checker: compared against the `pioasm` JSON writer source and the RP2350 `pio.h`; independently decoded the fixture's PINCTRL and EXECCTRL | The pgsim checker found this bug: optional side-set double-counted the enable bit, so every `opt` program would have been captured wrongly. Two earlier capture reviews had missed it because their example program had no optional side-set. Fixed, and the re-check passed. |
| Golden model (`sw/pgsim`): base ISA, 4 SMs, CLI, VCD output, silicon trace comparison | Haiku 5.5 (Model & tests lane) | Sonnet checker. It re-derived 10 waveforms from the RP2040 datasheet before reading the model, then ran them through `pgsim`. Over three re-checks it mutated each CLI path and ran the suite about 75 times to find a flaky test. | The core execution matched every derived waveform. **Fix needed, 3 rounds:** (1) the trace loader read guessed key names and dropped initial state; side-set double-counted the enable bit; forced instructions applied their delay; autopull was missing on non-OUT cycles. (2) The divider phase after the entry jump was wrong; a forced IRQ instruction could deadlock an IRQ wait. (3) The stall reason was stale after a forced instruction, and a race in test start-up made a test flaky. All fixed. Nine behaviours the datasheet leaves open are listed in `sw/pgsim/README.md` for the Pico 2 (V1) to settle. |
| Datasheet page (`docs/info.md`) | Haiku 5.5 (Flow lane) | Reproduced the CI failure locally with tt-support-tools `--check-docs`; Sonnet checker compared the page with `gate.md` line by line | The CI failure was the template's placeholder text. Fixed; the page is accurate, with no invented features. |
| Gate design RTL (Hardcaml: clock divider, FIFO, top, `project.v`) | Haiku 5.5 (RTL lane) | Sonnet checker: ran the independently written cocotb test against the RTL; regenerated the Verilog and diffed it; Verilator lint; yosys `check -assert`; line-by-line review | **The independent test passed first time:** 13/13 by default and 15/15 with the long tests. **Fix needed:** a build warning under dune 3.17, and `--` signal names attached to the wrong nets because of operator precedence. Both fixed. |

## Hardcaml gate result

On commit `5893f9f`, GitHub Actions ran the Tiny Tapeout flow on the Hardcaml-generated Verilog:

- GDS: pass
- precheck: pass
- gate-level test (`gl_test`): pass
- RTL cocotb test: pass
- OCaml build, tests and regenerated-Verilog check: pass

The Hardcaml gate (PLAN.md block 1, DESIGN.md §19) has passed, so the RTL stays in Hardcaml. Two jobs failed, and neither is part of the gate:

- `docs` failed on the template's placeholder `info.md`. It is fixed in a later commit.
- `viewer` failed on publishing the layout viewer to GitHub Pages.

## Rulings the orchestrator made

On 2026-11-21 the owner delegated these five decisions to the orchestrator, with the instruction to do what gives the best chance of winning. All five were adopted as written below and folded into DESIGN.md v0.3 (§7, §8.2, §8.3, §9.1). The deciding reason was compatibility: Polyglot claims binary compatibility with RP2040 PIO version 0, so it follows the RP2040 datasheet wherever the datasheet speaks. It flags anything else as ILLEGAL rather than guessing. The block 2 contract ([engine.md](engine.md)) adopts `pgsim`'s 15 ambiguity choices as spec, each marked with the V1 capture that will check it.

1. **`in status` (IN source 101).** The official `pioasm` assembles it, but DESIGN.md §9.1 and the RP2040 datasheet list it as reserved. `pgasm` stays byte-compatible with `pioasm`. The chip and the model treat it as reserved: it executes as a NOP and sets `ILLEGAL`. V1 on the Pico 2 will show what silicon does.
2. **WAIT irq index bit 3, IRQ bit 7 and IRQ index bit 3** are treated as reserved. These bits are RP2350 PIO v1's PREV and NEXT encodings, and `pioasm` never emits them for version 0. V1 will show what silicon does.
3. **The three Polyglot extension slots** (IN source 100, MOV source 100, SET destination 011) are still unused in RP2350 PIO v1, according to `pioasm` 2.3.1's disassembler and the SDK's enums. The RP2350 datasheet itself has not been checked yet.
4. **Host-forced instructions (`SMn_INSTR`) run immediately**, ignoring the clock divider and their own delay field, as RP2040 datasheet §3.5.7 says. DESIGN.md §8.2 says "on the next tick", and should be reworded to match.
5. **`DBG_CNT.stall_reason` encoding.** DESIGN.md §7 names the field but gives no encoding. pgsim uses 0 none, 1 TX empty, 2 RX full, 3 autopull, 4 WAIT gpio, 5 WAIT pin, 6 WAIT irq, 7 IRQ wait. The RTL should adopt the same encoding in block 3.

## Block 2 log

| Task | Worker | What checked it | What the check found |
| --- | --- | --- | --- |
| Block 2 contract (`docs/engine.md`) and the rulings in DESIGN v0.3 | Orchestrator (Opus 5.5), with the owner's go-ahead to decide | The workers who built from it. Each reported its own questions, without seeing the other's code. | 12 questions so far, including: forced instructions using up a tick, absent SMs, OUT_STICKY as one record, and abandoning a stalled instruction on a forced jump. Each was answered in the contract before the code it affects was checked. The Pico 2 prep checker found that R4 (PULL under autopull) did not follow the datasheet's definition of a full OSR. Fixed in the contract. |
| `pgasm -o python` and `-o c-sdk` | Haiku 5.5 (ISA & tools lane) | Sonnet checker: regenerated every expected file with official `pioasm`; differential fuzzing of about 6,000 programs in 4 formats; 162 code-block shapes; mutants of the output code | No output difference anywhere. **Fix needed:** two older lexer bugs in `% … {` code blocks, which changed all output formats, and tests that guarded the new formats only on the 26-file corpus. Fixed: the edge cases and the 65,536-word sweep now cover all formats, and every output-code mutant fails the tests. The re-check passed. |
| RP2350 check of the three extension encodings | Haiku 5.5 (ISA & tools lane) | The orchestrator re-read the quoted datasheet lines | All three are still reserved in PIO version 1 (RP2350 datasheet §11.4.4.2, §11.4.10.2, §11.4.12.2). DESIGN §9.1 is updated. |
| `programs/` library (UART TX, WS2812) and the Pico 2 V1 prep (`silicon-ref/v1/`, batch runner, checklist) | Haiku 5.5 (ISA & tools lane) | Sonnet checker: decoded both traces with its own script against the pico-examples source and the datasheet; mutated traces and JSON to prove the tests are live; for each V1 experiment, worked out whether silicon would really tell the hypotheses apart; checked the register addresses against the RP2350 headers and the mpremote source | `programs/` passed. **Fix needed** in the V1 prep: a MicroPython `json.dump` call that would crash on the board; two README copy commands that put files in the wrong place; no guard against filling the flash; IRQ flags left set from one capture to the next; host pins left isolated. The check also found that contract ruling R4 did not follow the datasheet's definition of a full OSR. Fixed, with a new experiment (b2) that separates three readings of the PULL rule. One question (h) cannot be settled by silicon and is decided by ruling. The re-check passed. |
| Block 2 engine RTL: decoder, joinable FIFOs, state machine, 1–4 engine block (`hw/`) | Haiku 5.5 (RTL lane) | Sonnet checker on the RTL side of the firewall. It read the code rule by rule against the datasheet and contract, and wrote 66 directed Cyclesim tests. It compared the simulated circuit with the generated Verilog in Verilator (480,000 random cycles, 1 and 4 engines). It also ran lint and yosys. | **Fix needed:** `MOV x, STATUS` compared the wrong FIFO (STATUS_SEL inverted). The worker's own tests had already caught a swapped multiplexer in the IRQ index. The four rule changes made during the block (R4, R11, F6, OUT_STICKY) were applied. The longest path runs from the divider into the FIFO level, about 9.6 ns at the slow corner before layout. All fixed. The re-check passed, and the simulated circuit equals the Verilog (0 mismatches). Lockstep against `pgsim` is in progress. |
