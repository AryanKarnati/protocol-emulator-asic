# pgasm

Assembler for pioasm syntax, PIO version 0 (RP2040). Its output is byte-identical to pioasm 2.3.1
for the golden corpus, and for an exhaustive sweep of all 65536 words.

Usage: `pgasm [-o json|hex|python|c-sdk] [--program NAME] INPUT [OUTPUT]`

- `INPUT` and `OUTPUT` may be `-` for stdin and stdout. `OUTPUT` defaults to stdout, so
  `pgasm -o c-sdk blink.pio` prints the header, and `pgasm -o python blink.pio blink.py` writes a file.
- `-o json` (the default here) is pgasm's own format, the pioasm JSON. `-o hex` writes one 16-bit word per line
  and needs a single program or `--program NAME`.
- `-o python` is pioasm's MicroPython output (`-o python`), and `-o c-sdk` is pioasm's C header
  (`-o c-sdk`). Both match pioasm 2.3.1 byte for byte, including the comments, blank lines,
  `% python { }` and `% c-sdk { }` passthrough blocks, `.lang_opt` arguments, wrap and side-set
  configuration, and the warning pioasm prints on stderr for a `.lang_opt` of the output's own
  language.
- pioasm's own default is `-o c-sdk` when `-o` is left out. pgasm keeps `json`, so existing scripts
  do not change. Pass `-o c-sdk` for pioasm's behaviour.

Not implemented: `pioasm`'s options `-v`, `-p`, `--version` and `-?`/`--help`, and the other
pioasm output formats (ada, go).

Non-goal: `.pio_version 1` (RP2350) and the PIO version 1 instructions. No block plans them yet.
pgasm rejects them with its own error ("PIO version 1 is not supported by pgasm yet"). `pioasm -v 0` accepts `.pio_version 1`, so this is the one known accept/reject difference.

Not implemented (rejected with an error): the Polyglot extensions (`in lcu`, `mov … crc`, `set lcu`,
`.page`, `.lcu`).

Tests: `dune test --root .` runs the corpus (JSON, hex, c-sdk and python outputs, all compared byte
for byte), the edge cases and the word sweep. The corpus and the expected outputs are made by
`oracle/make_corpus.sh`, from the official pioasm built by `oracle/build_pioasm.sh`. The word
sweep's expected values are in `test/word_sweep.md5`, made by `oracle/word_sweep.py`.
