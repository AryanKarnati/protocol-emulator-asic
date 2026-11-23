"""Program sources: @rp2.asm_pio (MicroPython's own assembler), pgasm JSON and pgasm -o python.

The SPI master is the cross-check: pgasm assembles programs/spi_master.pio, and the rp2.py
path builds the same program from the closure in polyglot.spi_master_program. The two must
agree word for word, for H = 3 (10 MHz) and H = 2 (15 MHz, the same text with the delays
rewritten). The pgasm binary is the repo's own build (dune build --root .).
"""

import os
import re
import subprocess

import pytest

import polyglot as pg
from conftest import load_rp2

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
PGASM = os.path.join(REPO, "_build", "default", "sw", "pgasm", "bin", "pgasm.exe")
SPI_PIO = os.path.join(REPO, "programs", "spi_master.pio")

needs_pgasm = pytest.mark.skipif(not os.path.exists(PGASM), reason="build pgasm first (dune build --root .)")


def pio_text_for_half(h):
    """The SPI master as pioasm text for half period h (test/pio_gen.py)."""
    import pio_gen

    return pio_gen.pio_text(h)


def pgasm_json(pio_path, tmp_path):
    out = str(tmp_path / "prog.json")
    subprocess.check_call([PGASM, "-o", "json", pio_path, out])
    return open(out).read()


@pytest.fixture
def rp2():
    return load_rp2()


@needs_pgasm
def test_committed_spi_program_is_the_h3_closure(rp2, tmp_path):
    prog = pg.spi_master_program(rp2, 3)
    p_rp2 = pg.program_from_rp2(prog, name="spi_master")
    p_json = pg.programs_from_json(pgasm_json(SPI_PIO, tmp_path))["spi_master"]
    assert p_rp2.words == p_json.words
    assert len(p_rp2.words) == 32
    assert p_rp2.wrap_target == p_json.wrap_target == 0
    assert p_rp2.wrap == p_json.wrap == 31
    assert p_rp2.side_count == p_json.side_count == 1
    assert p_rp2.shiftctrl == p_json.shiftctrl == 0x10830000


@needs_pgasm
@pytest.mark.parametrize("h", [2, 3, 4, 5, 6])
def test_rp2_closure_matches_pgasm_for_each_half_period(rp2, tmp_path, h):
    text = pio_text_for_half(h)
    pio = tmp_path / ("spi_h%d.pio" % h)
    pio.write_text(text)
    p_json = pg.programs_from_json(pgasm_json(str(pio), tmp_path))["spi_master"]
    p_rp2 = pg.program_from_rp2(pg.spi_master_program(rp2, h), name="spi_master")
    assert p_rp2.words == p_json.words


@needs_pgasm
def test_pgasm_python_output_runs_under_rp2_and_gives_the_same_program(rp2, tmp_path):
    out = tmp_path / "spi.py"
    subprocess.check_call([PGASM, "-o", "python", SPI_PIO, str(out)])
    progs = pg.programs_from_python(open(str(out)).read())
    assert list(progs) == ["spi_master"]
    p_py = progs["spi_master"]
    p_rp2 = pg.program_from_rp2(pg.spi_master_program(rp2, 3), name="spi_master")
    assert p_py.words == p_rp2.words
    assert p_py.wrap == p_rp2.wrap and p_py.side_count == p_rp2.side_count
    assert p_py.shiftctrl == p_rp2.shiftctrl


@needs_pgasm
def test_source_dispatch_json_and_python(rp2, tmp_path):
    j = pgasm_json(SPI_PIO, tmp_path)
    a = pg.program(j)
    assert a.name == "spi_master"
    out = tmp_path / "spi.py"
    subprocess.check_call([PGASM, "-o", "python", SPI_PIO, str(out)])
    b = pg.program(open(str(out)).read())
    assert a.words == b.words
    assert pg.program(a) is a


def test_pgasm_json_rejects_pio_version_1():
    doc = {
        "programs": [
            {
                "name": "v1",
                "pioVersion": 1,
                "wrapTarget": 0,
                "wrap": 0,
                "instructions": [{"hex": "e001"}],
            }
        ]
    }
    with pytest.raises(ValueError):
        pg.programs_from_json(doc)


def test_json_without_in_out_keeps_the_right_shift_default():
    doc = {
        "programs": [
            {
                "name": "plain",
                "pioVersion": 0,
                "wrapTarget": 0,
                "wrap": 0,
                "instructions": [{"hex": "e001"}],
                "sideset": None,
                "in": None,
                "out": None,
            }
        ]
    }
    p = pg.programs_from_json(doc)["plain"]
    assert p.shiftctrl == 0x000C0000  # pico default: both shifts right, thresholds 32


def test_json_optional_sideset_and_pindirs_bits():
    doc = {
        "programs": [
            {
                "name": "side",
                "pioVersion": 0,
                "wrapTarget": 0,
                "wrap": 1,
                "instructions": [{"hex": "e001"}, {"hex": "e000"}],
                "sideset": {"size": 2, "optional": True, "pindirs": True},
            }
        ]
    }
    p = pg.programs_from_json(doc)["side"]
    assert p.side_count == 2 and p.side_opt and p.side_pindir


def test_python_module_without_programs_is_an_error():
    with pytest.raises(ValueError):
        pg.programs_from_python("x = 1\n")


def test_program_name_selection():
    doc = {
        "programs": [
            {"name": "a", "pioVersion": 0, "wrapTarget": 0, "wrap": 0, "instructions": [{"hex": "e001"}]},
            {"name": "b", "pioVersion": 0, "wrapTarget": 0, "wrap": 0, "instructions": [{"hex": "e000"}]},
        ]
    }
    with pytest.raises(ValueError):
        pg.program(doc)
    assert pg.program(doc, name="b").words == [0xE000]


def test_rp2_side_opt_bit_and_count(rp2):
    PIO = rp2.PIO

    @rp2.asm_pio(sideset_init=PIO.OUT_LOW)
    def partial():
        set(pins, 1).side(1)
        nop()  # no side-set here, so SIDE_EN is set by the assembler

    p = pg.program_from_rp2(partial, name="partial")
    assert p.side_opt is True
    assert p.side_count == 2  # one pin plus the enable bit
    # With the enable bit, the side value sits at bit 11 and the enable at bit 12.
    assert p.words == [0xE001 | (1 << 12) | (1 << 11), 0xA042]


def test_rp2_sideset_list_count(rp2):
    PIO = rp2.PIO

    @rp2.asm_pio(sideset_init=[PIO.OUT_LOW, PIO.OUT_HIGH], set_init=PIO.OUT_HIGH)
    def two():
        set(pins, 1).side(2)

    p = pg.program_from_rp2(two, name="two")
    assert p.side_count == 2 and not p.side_opt
    # Two side-set pins: the side value sits at bit 11 with no enable bit.
    assert p.words == [0xE001 | (2 << 11)]


def test_relocate_adds_offset_to_jumps_only():
    words = [
        0xE001,  # set pins, 1
        0x0000,  # jmp 0
        0x00A3,  # jmp !osre? (condition 111 in bits 7:5, target 3)
        0x2080,  # wait 1 gpio 0 (not a JMP): untouched
        0x6001,  # out pins, 1: untouched
        0x0004,  # jmp 4
    ]
    out = pg.relocate(words, 9)
    assert out[0] == 0xE001
    assert out[1] == 0x0009
    assert out[2] == 0x00A3 + 9
    assert out[3] == 0x2080
    assert out[4] == 0x6001
    assert out[5] == 0x000D


def test_relocate_leaves_condition_bits_alone():
    # JMP condition 101 (x != y) in bits 7:5, target 19: the offset changes the target only.
    w = (0b101 << 5) | 19
    assert pg.relocate([w], 4) == [(0b101 << 5) | 23]
