# programs/: protocol program library

One directory per protocol (DESIGN.md §16, §18). Each holds:

| File | What it is |
| --- | --- |
| `<name>.pio` | PIO source, unmodified from its upstream file (licence header kept) |
| `<name>.pioasm.json` | JSON written by the official pioasm 2.3.1 from `<name>.pio` (the oracle) |
| `<name>.json` | JSON written by pgasm from `<name>.pio`. The test requires it to equal `<name>.pioasm.json` |
| `<name>.config.json` | Fixed register configuration for pgsim (clock divider, pins, shift settings) |
| `<name>.trace` | Expected trace: pgsim `--trace` output, one line per sysclk cycle |
| `NOTES.md` | Source and tag, the stimulus, what the trace should show, and the hand check |
| `dune` | The tests (below) |

`LICENSE.pico-examples.TXT` is the upstream licence (BSD-3-Clause) for the pico-examples programs.

## Programs

| Directory | Upstream | Notes |
| --- | --- | --- |
| `uart_tx/` | `pico-examples/pio/uart_tx/uart_tx.pio`, tag `sdk-2.3.1` | 8n1 transmit, two bytes |
| `ws2812/` | `pico-examples/pio/ws2812/ws2812.pio`, tag `sdk-2.3.1` | LED bit stream, two pixels. The file's second program, `ws2812_parallel`, is not tested yet |

The upstream commit is `0d62f75bafc2c8120d3276c3343d1a9195e909e9` (see `sw/pgasm/test/corpus/MANIFEST.md`).

## Tests

`dune test --root .` runs, for each program:

1. pgasm assembles `<name>.pio`, and the output equals `<name>.json`.
2. `<name>.json` equals `<name>.pioasm.json`, the official pioasm 2.3.1 output.
3. pgsim (`sw/pgsim/cli/pgsim_cli.exe`), with `<name>.config.json` and the stimulus in `NOTES.md`,
   gives output equal to `<name>.trace`.

The official pioasm is not run during the tests. Its output is committed as `<name>.pioasm.json`.
To regenerate it, run `~/.cache/polyglot/pioasm-build/pioasm -o json <name>.pio <name>.pioasm.json`.

To update an expected file after a deliberate change, copy the new output from
`_build/default/programs/<name>/<name>.actual.trace` (or `.actual.json`) over the committed file, and
review the diff by hand against NOTES.md.

## Host scripts: TODO (block 3)

TODO(block 3): each program should have a MicroPython host script that loads it on a board and
drives its pins or FIFOs. Those scripts depend on the block 3 host library (`sw/host/`), which does
not exist yet. No script is written here. Until block 3 lands, these directories have no host side.
