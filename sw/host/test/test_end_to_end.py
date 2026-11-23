"""End to end: the library through SimTransport to `pgsim chip-serve`, the whole-chip model.

Each test starts its own server, so the chip starts from reset. The programs are hand-encoded
PIO words (RP2040 encodings, as in chip.md section 9.1). Expected values come from chip.md and
the RP2040 datasheet, not from the model's output.

Words used:
  0x80A0 pull block          0x8020 push block
  0x6088 out pindirs, 8      0x6008 out pins, 8
  0x4001 in pins, 1          0x0000 jmp 0
  0xE005 set pins, 5
"""

import os

import pytest

import polyglot as pg

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
PGSIM = os.path.join(REPO, "_build", "default", "sw", "pgsim", "cli", "pgsim_cli.exe")

pytestmark = pytest.mark.skipif(not os.path.exists(PGSIM), reason="build pgsim first (dune build --root .)")

ECHO = [0x80A0, 0x8020]  # pull block; push block: every TX word comes back on RX
PINS8 = [0x80A0, 0x6088, 0x80A0, 0x6008, 0x0000]  # pindirs from one word, pins from the next
IDLE = [0x0000]  # jmp 0


@pytest.fixture
def chip():
    t = pg.SimTransport(pgsim=PGSIM)
    c = pg.Chip(t)
    try:
        yield c
    finally:
        t.close()


def run_and_wait(chip, cycles):
    chip._t.run(cycles)


def pads(chip):
    """(uo_out, uio_out, uio_oe) from the model's pads command."""
    return chip._t.pads()


def test_id_and_hwcfg(chip):
    assert chip.id() == 0x504C4754
    cfg = chip.hwcfg()
    assert cfg["num_sms"] == 4
    assert cfg["fifo_depth"] == 4
    assert cfg["imem_depth"] == 64
    assert cfg["lcu"] == 0


def test_status_after_reset(chip):
    # chip.md 9.3: TXNFULL is 1 for every SM with room, RXNEMPTY is 0. So STATUS = 0xF0.
    assert chip.status() == 0xF0


def test_check_replays_after_a_deselection(chip):
    prog = pg.Program(ECHO, name="echo")
    chip.load(prog, page=0)
    sm = chip.sm(0)
    sm.init(prog, freq=60000000)
    sm.active(1)
    assert chip.check() is False  # first call: SCRATCH is 0, so the design is (re)loaded
    assert chip.check() is True
    before = (chip.read(0x200 + 0x00, 1)[0], chip.read(0x200 + 0x04, 1)[0], chip.read(0x200 + 0x14, 1)[0])
    # A deselection loses the state. Simulate it by writing SCRATCH through the transport.
    chip.write(0x038, [0])
    assert chip.check() is False
    after = (chip.read(0x200 + 0x00, 1)[0], chip.read(0x200 + 0x04, 1)[0], chip.read(0x200 + 0x14, 1)[0])
    assert after == before
    # The replayed program still echoes: one word comes back into RX.
    sm.put(0xC0FFEE42)
    run_and_wait(chip, 60)
    assert sm.rx_fifo() == 1


def test_load_into_page_1_and_echo(chip):
    prog = pg.Program(ECHO, name="echo")
    h = chip.load(prog, page=1)
    assert h.start == 32
    sm = chip.sm(0)
    sm.init(h)
    assert sm.regs()["ext"] == 1  # EXT.PAGE selects page 1
    sm.active(1)
    sm.put(0x1234ABCD)
    run_and_wait(chip, 60)
    assert sm.rx_fifo() == 1  # the echo ran from page 1 (the value check is in test_get_returns_the_word)


def test_put_then_pins_seen_on_pads(chip):
    prog = pg.Program(PINS8, name="pins8")
    h = chip.load(prog, page=0)
    sm = chip.sm(1)
    sm.init(h, out_base=0, out_count=8)
    sm.active(1)
    sm.put(0xFF)  # pindirs: all eight uio pads out
    sm.put(0xA5)  # pins: 1010 0101
    run_and_wait(chip, 80)
    uo, uio_out, uio_oe = pads(chip)
    assert uio_oe & 0xFF == 0xFF
    assert uio_out & 0xFF == 0xA5


def test_init_sets_pin_levels_and_directions(chip):
    prog = pg.Program(IDLE, name="idle", set_init=[3, 3, 2])  # pins 0, 1 high; pin 2 low; all out
    sm = chip.sm(0)
    sm.init(prog, set_base=0)
    uo, uio_out, uio_oe = pads(chip)
    assert uio_oe & 7 == 7
    assert uio_out & 7 == 3


def test_exec_forces_an_instruction_onto_the_pins(chip):
    prog = pg.Program(IDLE, name="idle", set_init=[3, 3, 2])
    sm = chip.sm(0)
    sm.init(prog, set_base=0)
    sm.exec(0xE005)  # set pins, 5: pin 0 high, pin 1 low, pin 2 high
    run_and_wait(chip, 4)
    uo, uio_out, uio_oe = pads(chip)
    assert uio_out & 7 == 5


def test_tx_and_rx_fifo_levels(chip):
    prog = pg.Program(ECHO, name="echo")
    h = chip.load(prog)
    sm = chip.sm(2)
    sm.init(h)
    sm.put(1)
    sm.put(2)
    assert sm.tx_fifo() == 2 and sm.rx_fifo() == 0
    sm.active(1)
    run_and_wait(chip, 60)
    assert sm.tx_fifo() == 0 and sm.rx_fifo() == 2


# Model bug, reported to the Model & tests lane (not patched here). A read of RXFn through a read
# frame returns 0 while the RX FIFO holds the head word. chip.md 8.3 says the read returns the
# head word. The same frame path returns the right values for ID (0x504C4754) and SM0 CLKDIV
# (0x00010000), and FLEVEL and STATUS show the word is there, so only the RXF value is wrong.
RXF_BUG = "model bug: RXFn reads return 0 while RX holds the word (chip.md 8.3)"


@pytest.mark.xfail(strict=True, reason=RXF_BUG)
def test_get_returns_the_word(chip):
    prog = pg.Program(ECHO, name="echo")
    h = chip.load(prog)
    sm = chip.sm(0)
    sm.init(h)
    sm.active(1)
    sm.put(0x11223344)
    run_and_wait(chip, 60)
    assert sm.get() == 0x11223344


@pytest.mark.xfail(strict=True, reason=RXF_BUG)
def test_get_pops_in_order(chip):
    prog = pg.Program(ECHO, name="echo")
    h = chip.load(prog)
    sm = chip.sm(2)
    sm.init(h)
    sm.put(1)
    sm.put(2)
    sm.active(1)
    run_and_wait(chip, 60)
    assert sm.get() == 1
    assert sm.rx_fifo() == 1
    assert sm.get() == 2
    assert sm.rx_fifo() == 0


def test_restart_clears_the_shift_counters(chip):
    # RP2040 datasheet, PIO: on reset or CTRL_SM_RESTART the input shift counter is cleared to 0,
    # and the output shift counter is set to 32.
    prog = pg.Program([0x4001, 0x0000], name="shift")  # in pins, 1; jmp 0
    h = chip.load(prog)
    sm = chip.sm(3)
    sm.init(h)
    sm.active(1)
    run_and_wait(chip, 9)
    sm.active(0)
    isr_before = sm.regs()["cnt"] & 0x3F
    assert isr_before > 0
    sm.restart()
    cnt = sm.regs()["cnt"]
    assert cnt & 0x3F == 0  # ISR shift count
    assert (cnt >> 8) & 0x3F == 32  # OSR shift count
