"""Pin-count defaults, per source (see polyglot._count for the references).

- rp2 objects: a base with no init list gets count 0 (rp2_pio.c line 209, asm_pio_get_pins
  lines 238-257, sm_config_set_out_pins / sm_config_set_set_pins lines 693-703). A list gets
  its length.
- pgasm JSON and Program objects: pio_get_default_sm_config() leaves PINCTRL at 0 (pio.h
  lines 780-790), so the counts are 0.
"""

import pytest

import polyglot as pg
from conftest import load_rp2
from test_chip import make

PINCTRL = 0x200 + 0x14


@pytest.fixture
def rp2():
    return load_rp2()


def _pc(fake):
    return fake.regs[PINCTRL]


def test_program_with_nothing_specified_counts_0():
    fake, chip = make()
    chip.sm(0).init(pg.Program([0xE001], name="bare"), out_base=5, set_base=6)
    pc = _pc(fake)
    assert (pc >> 20) & 0x3F == 0  # OUT_COUNT
    assert (pc >> 26) & 0x7 == 0  # SET_COUNT
    assert pc & 0x1F == 5 and (pc >> 5) & 0x1F == 6


def test_explicit_counts_win():
    fake, chip = make()
    chip.sm(0).init(pg.Program([0xE001], name="c"), out_base=5, out_count=8, set_base=6, set_count=3)
    pc = _pc(fake)
    assert (pc >> 20) & 0x3F == 8
    assert (pc >> 26) & 0x7 == 3


def test_no_base_writes_no_count():
    fake, chip = make()
    chip.sm(0).init(pg.Program([0xE001], name="n"))
    assert _pc(fake) == 0


def test_rp2_base_without_init_list_counts_0(rp2):
    @rp2.asm_pio()
    def nothing():
        out(pins, 1)
        set(pins, 1)

    fake, chip = make()
    chip.sm(0).init(pg.program_from_rp2(nothing, name="nothing"), out_base=5, set_base=6)
    pc = _pc(fake)
    assert (pc >> 20) & 0x3F == 0
    assert (pc >> 26) & 0x7 == 0


def test_rp2_init_lists_give_their_lengths(rp2):
    PIO = rp2.PIO

    @rp2.asm_pio(out_init=PIO.OUT_LOW, set_init=[PIO.OUT_LOW, PIO.OUT_HIGH, PIO.OUT_LOW])
    def listed():
        out(pins, 1)
        set(pins, 1)

    fake, chip = make()
    chip.sm(0).init(pg.program_from_rp2(listed, name="listed"), out_base=5, set_base=6)
    pc = _pc(fake)
    assert (pc >> 20) & 0x3F == 1  # a single-int init is one pin
    assert (pc >> 26) & 0x7 == 3  # a three-entry list is three pins


def test_json_with_nothing_counts_0():
    doc = {
        "programs": [
            {"name": "j", "pioVersion": 0, "wrapTarget": 0, "wrap": 0, "instructions": [{"hex": "e001"}]}
        ]
    }
    fake, chip = make()
    chip.sm(0).init(pg.programs_from_json(doc)["j"], out_base=5, set_base=6)
    pc = _pc(fake)
    assert (pc >> 20) & 0x3F == 0 and (pc >> 26) & 0x7 == 0
