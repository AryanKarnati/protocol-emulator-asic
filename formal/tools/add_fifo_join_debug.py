#!/usr/bin/env python3
"""Add debug outputs to a generated fifo_join.v, for the tracked-token induction proof.

Adds ports w0..w7 (the eight storage words), txrd and txwr (the TX read and write
pointers, tx_rd_q and tx_wr_q), rxrd and rxwr (rx_rd_q and rx_wr_q) and rxbase (rx_base,
where the RX half starts: 0 when RX is joined, otherwise 4). The FIFO's behaviour is
unchanged: the harness only reads the new ports.

This is a trade-off. The token proof needs the storage and the pointers, which are not
ports of the module. So fifo_join_ind_harness.v uses this debug netlist, not the ports
alone. The flags proof and the cover tasks use the base netlist.

Usage: add_fifo_join_debug.py IN.v OUT.v
"""

import sys


def patch(text: str) -> str:
    port_end = "    rx_underflow\n);"
    if text.count(port_end) != 1:
        raise SystemExit("add_fifo_join_debug: port list not found exactly once")
    names = [f"w{i}" for i in range(8)] + ["txrd", "txwr", "rxrd", "rxwr", "rxbase"]
    text = text.replace(
        port_end,
        "    rx_underflow,\n" + ",\n".join("    " + n for n in names) + "\n);",
    )
    decls = "".join(f"    output [31:0] w{i};\n" for i in range(8))
    decls += (
        "    output [2:0] txrd;\n"
        "    output [2:0] txwr;\n"
        "    output [2:0] rxrd;\n"
        "    output [2:0] rxwr;\n"
        "    output [2:0] rxbase;\n"
    )
    assigns = "".join(f"    assign w{i} = word_{i};\n" for i in range(8))
    assigns += (
        "    assign txrd = tx_rd_q;\n"
        "    assign txwr = tx_wr_q;\n"
        "    assign rxrd = rx_rd_q;\n"
        "    assign rxwr = rx_wr_q;\n"
        "    assign rxbase = rx_base;\n"
    )
    if text.count("endmodule") != 1:
        raise SystemExit("add_fifo_join_debug: endmodule not found exactly once")
    text = text.replace("endmodule", decls + assigns + "endmodule")
    return text


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: add_fifo_join_debug.py IN.v OUT.v")
    with open(sys.argv[1]) as f:
        src = f.read()
    with open(sys.argv[2], "w") as f:
        f.write(patch(src))


if __name__ == "__main__":
    main()
