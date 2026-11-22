#!/usr/bin/env python3
"""Add debug outputs to a generated fifo_4x32.v, for the tracked-token induction proof.

Adds ports w0, w1, w2, w3 (the four storage words), rdp and wrp (the read and write
pointers, the registers rd_ptr_q and wr_ptr_q) to module fifo_4x32. The FIFO's behaviour is
unchanged: the new ports are only read by the harness.

This is a trade-off. The token proof needs the storage and pointers, which are not ports of
the module. So the proof in fifo_ind_harness.v uses this debug netlist, not the ports alone.
The harness is still checked against the spec-level properties, and the base netlist
(without these ports) is what the flags proof and the cover tasks check.

Usage: add_fifo_debug.py IN.v OUT.v
"""

import sys


def patch(text: str) -> str:
    port_end = "    pop_empty\n);"
    if text.count(port_end) != 1:
        raise SystemExit("add_fifo_debug: port list not found exactly once")
    text = text.replace(
        port_end,
        "    pop_empty,\n    w0,\n    w1,\n    w2,\n    w3,\n    rdp,\n    wrp\n);",
    )
    decls = (
        "    output [31:0] w0;\n"
        "    output [31:0] w1;\n"
        "    output [31:0] w2;\n"
        "    output [31:0] w3;\n"
        "    output [1:0] rdp;\n"
        "    output [1:0] wrp;\n"
    )
    assigns = (
        "    assign w0 = word_0;\n"
        "    assign w1 = word_1;\n"
        "    assign w2 = word_2;\n"
        "    assign w3 = word_3;\n"
        "    assign rdp = rd_ptr_q;\n"
        "    assign wrp = wr_ptr_q;\n"
    )
    if text.count("endmodule") != 1:
        raise SystemExit("add_fifo_debug: endmodule not found exactly once")
    text = text.replace("endmodule", decls + assigns + "endmodule")
    return text


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: add_fifo_debug.py IN.v OUT.v")
    with open(sys.argv[1]) as f:
        src = f.read()
    with open(sys.argv[2], "w") as f:
        f.write(patch(src))


if __name__ == "__main__":
    main()
