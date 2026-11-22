#!/usr/bin/env python3
"""Make a block 1 divider netlist (module clkdiv, tick only) into the debug form.

The block 1 divider has no phase output, but the unbounded R10 proof needs it. This script
renames the module to clkdiv_dbg, adds an output phase, and drives it from phase_q, the
phase register. The logic is unchanged. The debug form is only used by the proof harness
(clkdiv_dbg_harness.v), so the block 1 divider gets the same unbounded proof as the block
2 one, with the same tick logic.

Usage: add_clkdiv_debug.py IN.v OUT.v
"""

import sys


def patch(text: str) -> str:
    if text.count("module clkdiv (") != 1:
        raise SystemExit("add_clkdiv_debug: module header not found exactly once")
    text = text.replace("module clkdiv (", "module clkdiv_dbg (", 1)
    port_end = "    tick\n);"
    if text.count(port_end) != 1:
        raise SystemExit("add_clkdiv_debug: port list not found exactly once")
    text = text.replace(port_end, "    tick,\n    phase\n);", 1)
    if text.count("output tick;") != 1:
        raise SystemExit("add_clkdiv_debug: output tick declaration not found")
    text = text.replace("output tick;", "output tick;\n    output [24:0] phase;", 1)
    if text.count("endmodule") != 1:
        raise SystemExit("add_clkdiv_debug: endmodule not found exactly once")
    text = text.replace("endmodule", "    assign phase = phase_q;\n\nendmodule", 1)
    return text


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: add_clkdiv_debug.py IN.v OUT.v")
    with open(sys.argv[1]) as f:
        src = f.read()
    with open(sys.argv[2], "w") as f:
        f.write(patch(src))


if __name__ == "__main__":
    main()
