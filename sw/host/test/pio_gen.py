"""The PIO SPI master as pioasm source, for half period h.

This is the text of polyglot.spi_master_program (the @rp2.asm_pio closure), instruction for
instruction. The tests assemble it with pgasm and pioasm and compare the words with the rp2
path. programs/spi_master.pio is this text at h = 3, with its header comments.
"""

LANG_OPTS = [
    ".lang_opt python sideset_init = rp2.PIO.OUT_LOW",
    ".lang_opt python out_init = rp2.PIO.OUT_LOW",
    ".lang_opt python set_init = [rp2.PIO.OUT_LOW,rp2.PIO.OUT_LOW,rp2.PIO.OUT_HIGH]",
    ".lang_opt python in_shiftdir = rp2.PIO.SHIFT_LEFT",
    ".lang_opt python out_shiftdir = rp2.PIO.SHIFT_LEFT",
    ".lang_opt python autopush = True",
    ".lang_opt python push_thresh = 8",
    ".lang_opt python autopull = True",
    ".lang_opt python pull_thresh = 8",
]


from polyglot import SAMPLE_LOW_MAX_H


def _d(n):
    return " [%d]" % n if n else ""


def pio_text(h):
    """pioasm source for half period h (2 to 16)."""
    if h < 2:
        raise ValueError("h must be at least 2")
    lines = [
        ".program spi_master",
        ".side_set 1",
        ".in 32 left auto 8",
        ".out 32 left auto 8",
    ]
    lines.extend(LANG_OPTS)
    lines.append("frame:")
    lines.append("    pull block side 0")
    lines.append("    out y, 32 side 0")
    lines.append("    set pins, 0 side 0%s" % _d(3))
    lines.append("    out pins, 1 side 0%s" % _d(h - 2))
    lines.append("    jmp R7 side 0")
    if h <= SAMPLE_LOW_MAX_H:
        # Sample at tick h, the first low tick (polyglot.spi_master_program, the low branch).
        lines.append("L0:")
        lines.append("    in pins, 1 side 0")
        lines.append("L1:")
        lines.append("    out pins, 1 side 0%s" % _d(h - 2))
        lines.append("R7:")
        lines.append("    nop side 1%s" % _d(h - 1))
        for _ in range(6):
            lines.append("    in pins, 1 side 0")
            lines.append("    out pins, 1 side 0%s" % _d(h - 2))
            lines.append("    nop side 1%s" % _d(h - 1))
        lines.append("    in pins, 1 side 0")
        lines.append("    out pins, 1 side 0%s" % _d(h - 2))
        lines.append("R0:")
        lines.append("    jmp y--, L0 side 1%s" % _d(h - 1))
        lines.append("    in pins, 1 side 0")
        lines.append("    set pins, 4 side 0")
        lines.append("    jmp frame side 0")
    else:
        # Sample at tick 1 (polyglot.spi_master_program, the high branch).
        lines.append("L0:")
        lines.append("    in pins, 1 side 1%s" % _d(h - 2))
        lines.append("L1:")
        lines.append("    out pins, 1 side 0%s" % _d(h - 1))
        lines.append("R7:")
        lines.append("    nop side 1")
        for _ in range(6):
            lines.append("    in pins, 1 side 1%s" % _d(h - 2))
            lines.append("    out pins, 1 side 0%s" % _d(h - 1))
            lines.append("    nop side 1")
        lines.append("    in pins, 1 side 1%s" % _d(h - 2))
        lines.append("    out pins, 1 side 0%s" % _d(h - 1))
        lines.append("R0:")
        lines.append("    jmp y--, L0 side 1")
        lines.append("    in pins, 1 side 1%s" % _d(h - 2))
        lines.append("    set pins, 4 side 0")
        lines.append("    jmp frame side 0")
    return "\n".join(lines) + "\n"
