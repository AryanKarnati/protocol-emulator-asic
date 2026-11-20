# pgasm

Assembler for pioasm syntax, PIO version 0 (RP2040). Its JSON and hex output is byte-identical
to pioasm 2.3.1 for the golden corpus and for an exhaustive sweep of all 65536 words.

Non-goal: `.pio_version 1` (RP2350) and the PIO version 1 instructions. No block plans them yet.
pgasm rejects them with its own error ("PIO version 1 is not supported by pgasm yet"). `pioasm -v 0` accepts `.pio_version 1`, so this is the one known accept/reject difference.

Not implemented (rejected with an error): the c-sdk and python output formats, and the Polyglot
extensions (`in lcu`, `mov … crc`, `set lcu`, `.page`, `.lcu`).

Tests: `dune test --root .` runs the corpus, the edge cases and the word sweep. The word sweep's
expected values are in `test/word_sweep.md5`, made by `oracle/word_sweep.py`.
