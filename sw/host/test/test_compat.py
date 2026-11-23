"""Compatibility with rp2.StateMachine, pio_sm_init and pioasm's default config.

Each rule cites its source: rp2_pio.c (the pinned MicroPython commit, vendor/README.txt), pio.c and
pio.h (pico-sdk), and pgasm's c-sdk writer (sw/pgasm/src/pio_out.ml).
"""

import pytest

import polyglot as pg
from conftest import load_rp2
from test_chip import make

EXECCTRL = 0x204
SHIFTCTRL = 0x208
CLKDIV = 0x200
FDEBUG = 0x010


@pytest.fixture
def rp2():
    return load_rp2()


def test_host_writes_are_shadowed_and_replayed():
    # HOSTIRQ_EN, PAD_OD and INPUT_SYNC_BYPASS are RW registers; reload() must restore them.
    fake, chip = make()
    chip.write(0x020, [0x3F])
    chip.write(0x024, [0x0F])
    chip.write(0x028, [0x12])
    fake.reset()
    assert chip.check() is False
    assert fake.regs[0x020] == 0x3F
    assert fake.regs[0x024] == 0x0F
    assert fake.regs[0x028] == 0x12


def test_init_clears_this_sms_sticky_fdebug_flags():
    # pio.c pio_sm_init: pio->fdebug = (TXOVER | RXUNDER | TXSTALL | RXSTALL) << sm.
    fake, chip = make()
    chip.sm(2).init(pg.Program([0xE001], name="f"))
    assert (FDEBUG, (pg.FDEBUG_SM_FLAGS << 2)) in fake.writes


def test_rp2_shiftctrl_is_taken_whole_including_the_fifo_join(rp2):
    # rp2_pio.c line 681: config.shiftctrl = prog[PROG_SHIFTCTRL], with the FJOIN bits.
    PIO = rp2.PIO

    @rp2.asm_pio(fifo_join=PIO.JOIN_RX)
    def rxjoin():
        set(pins, 1)

    p = pg.program_from_rp2(rxjoin, name="rxjoin")
    assert (p.shiftctrl >> 31) & 1 == 1
    fake, chip = make()
    chip.sm(1).init(p)
    assert fake.regs[0x200 + 0x40 + 0x08] >> 31 == 1


def test_rp2_fixed_offset_field_is_not_an_origin(rp2):
    # rp2_pio.c stores the loaded offset in prog[1..3] after a load. It is not a placement request.
    @rp2.asm_pio()
    def anywhere():
        set(pins, 1)

    anywhere[1] = 5  # as if an earlier load had set it
    p = pg.program_from_rp2(anywhere, name="anywhere")
    assert p.origin == -1
    fake, chip = make()
    assert chip.load(p).offset == 31  # highest run, not 5


def test_pgasm_json_fifo_join_mov_status_and_clkdiv_apply():
    # pioasm's c-sdk default config (pio_out.ml): sm_config_set_fifo_join, sm_config_set_mov_status,
    # sm_config_set_clkdiv_int_frac, all from the program's own directives.
    doc = {
        "programs": [
            {
                "name": "pgcfg",
                "pioVersion": 0,
                "wrapTarget": 0,
                "wrap": 0,
                "instructions": [{"hex": "e001"}],
                "fifoConfig": "PIO_FIFO_JOIN_RX",
                "movStatus": {"type": "STATUS_RX_LESSTHAN", "n": 3},
                "clockDiv": {"int": 2, "frac": 128},
            }
        ]
    }
    p = pg.programs_from_json(doc)["pgcfg"]
    assert (p.shiftctrl >> 31) & 1 == 1 and (p.shiftctrl >> 30) & 1 == 0
    assert p.status_sel == 1 and p.status_n == 3
    assert p.clkdiv == (2, 128)
    fake, chip = make()
    chip.sm(0).init(p, out_base=5)  # no freq or clkdiv: the program's divider
    assert fake.regs[CLKDIV] == 0x00028000
    ex = fake.regs[EXECCTRL]
    assert (ex >> 4) & 1 == 1 and ex & 0xF == 3


def test_pgasm_json_status_irq_set_is_rp2350_only():
    doc = {
        "programs": [
            {
                "name": "irq",
                "pioVersion": 0,
                "wrapTarget": 0,
                "wrap": 0,
                "instructions": [{"hex": "e001"}],
                "movStatus": {"type": "STATUS_IRQ_SET", "n": 1},
            }
        ]
    }
    with pytest.raises(ValueError):
        pg.programs_from_json(doc)


def test_pgasm_json_tx_join_and_status_tx():
    doc = {
        "programs": [
            {
                "name": "tx",
                "pioVersion": 0,
                "wrapTarget": 0,
                "wrap": 0,
                "instructions": [{"hex": "e001"}],
                "fifoConfig": "PIO_FIFO_JOIN_TX",
                "movStatus": {"type": "STATUS_TX_LESSTHAN", "n": 0},
            }
        ]
    }
    p = pg.programs_from_json(doc)["tx"]
    assert (p.shiftctrl >> 30) & 1 == 1 and p.status_sel == 0
