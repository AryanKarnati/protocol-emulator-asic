"""The Chip and StateMachine API, against the register-file fake (fakechip.py)."""

import pytest

import polyglot as pg
from fakechip import FakeChip, ID

IMEM_LO = 0x100
IMEM_HI = 0x100 + 4 * 64


class RecordingTransport(object):
    """Records each frame and returns queued replies (or zeros of the right length)."""

    def __init__(self, replies=None):
        self.sent = []
        self.replies = list(replies or [])

    def xfer(self, data):
        self.sent.append(bytes(data))
        if self.replies:
            return self.replies.pop(0)
        return bytes(len(data))


class FakeTransport(object):
    def __init__(self, fake):
        self.fake = fake
        self.sent = []

    def xfer(self, data):
        self.sent.append(bytes(data))
        return self.fake.xfer(data)


def make(fake=None):
    fake = fake or FakeChip()
    return fake, pg.Chip(FakeTransport(fake))


def sm_reg(n, off):
    return 0x200 + 0x40 * n + off


def simple_prog(name="p"):
    # set pins, 1 ; set pins, 0 ; jmp 0: a three-instruction loop.
    return pg.Program([0xE001, 0xE000, 0x0000], name=name)


def imem_writes(fake):
    return [w for w in fake.writes if IMEM_LO <= w[0] < IMEM_HI]


def test_id_and_hwcfg():
    fake, chip = make()
    assert chip.id() == ID
    cfg = chip.hwcfg()
    assert cfg["fifo_depth"] == 4
    assert cfg["num_sms"] == 4
    assert cfg["imem_depth"] == 64
    assert cfg["lcu"] == 0
    assert cfg["version"] == 1


def test_load_writes_relocated_words_to_imem():
    fake, chip = make()
    prog = pg.Program([0xE001, 0x0002, 0x0000], name="x")  # jmp 2 and jmp 0
    h = chip.load(prog, page=0, offset=5)
    assert h.offset == 5 and h.page == 0
    assert [fake.imem[i] for i in (5, 6, 7)] == [0xE001, 0x0002 + 5, 0x0000 + 5]


def test_load_page_one_adds_32():
    fake, chip = make()
    h = chip.load(simple_prog(), page=1, offset=0)
    assert h.start == 32
    assert fake.imem[32] == 0xE001


def test_load_first_fit_then_full_page():
    fake, chip = make()
    a = chip.load(pg.Program([0xE001] * 20, name="a"))
    b = chip.load(pg.Program([0xE001] * 12, name="b"))
    assert a.offset == 0
    assert b.offset == 20
    with pytest.raises(MemoryError):
        chip.load(pg.Program([0xE001], name="c"), page=0)
    # Page 1 is still free.
    assert chip.load(pg.Program([0xE001], name="d"), page=1).start == 32


def test_load_rejects_overlap_and_overrun():
    fake, chip = make()
    chip.load(pg.Program([0xE001] * 5, name="e"), page=0, offset=0)
    with pytest.raises(ValueError):
        chip.load(pg.Program([0xE001] * 5, name="f"), page=0, offset=3)
    with pytest.raises(ValueError):
        chip.load(pg.Program([0xE001] * 5, name="g"), page=0, offset=30)


def test_load_page_one_needs_64_words():
    fake, chip = make()
    fake.regs[0x004] = 4 | (4 << 8) | (32 << 16) | (1 << 28)  # IMEM depth 32
    with pytest.raises(ValueError):
        chip.load(simple_prog(), page=1)


def test_program_origin_is_used_as_offset():
    fake, chip = make()
    p = pg.Program([0xE001, 0x0000], name="o", origin=9)
    assert chip.load(p).offset == 9


def test_sm_init_sets_clkdiv_execctrl_shiftctrl_pinctrl_and_entry():
    fake, chip = make()
    prog = pg.Program(
        [0xE001, 0x0002, 0x0000],
        name="w",
        wrap_target=0,
        wrap=2,
        side_count=1,
        side_opt=False,
        shiftctrl=0x000C0000,
    )
    chip.load(prog, offset=4)
    chip.sm(1).init(prog, freq=60000000, in_base=24, out_base=23, set_base=22, sideset_base=21)
    base = sm_reg(1, 0)
    assert fake.regs[base + 0x00] == 0x00010000  # CLKDIV: freq equal to the chip clock
    ex = fake.regs[base + 0x04]
    assert (ex >> 12) & 0x1F == 2 + 4  # WRAP_TOP = wrap + offset
    assert (ex >> 7) & 0x1F == 0 + 4  # WRAP_BOTTOM = wrap_target + offset
    pc = fake.regs[base + 0x14]
    assert (pc >> 29) & 7 == 1  # SIDESET_COUNT
    assert (pc >> 10) & 0x1F == 21  # SIDESET_BASE
    assert (pc >> 15) & 0x1F == 24  # IN_BASE
    assert (pc >> 5) & 0x1F == 22  # SET_BASE
    assert (pc >> 26) & 7 == 0  # SET_COUNT: no init list, so 0 (pio_get_default_sm_config)
    assert pc & 0x1F == 23  # OUT_BASE
    assert (pc >> 20) & 0x3F == 0  # OUT_COUNT: no init list, so 0
    assert fake.regs[base + 0x18] == 0  # EXT: page 0
    assert (1, 0x0004) in fake.instr  # entry: forced JMP to the offset
    assert fake.regs[0x008] & 0xF == 0  # not enabled by init


def test_sm_init_clkdiv_from_freq_and_clkdiv():
    fake, chip = make()
    p = simple_prog()
    chip.sm(0).init(p, freq=30000000)
    assert fake.regs[sm_reg(0, 0)] == 0x00020000  # 60 MHz / 30 MHz = 2
    chip.sm(0).init(p, clkdiv=1.5)
    assert fake.regs[sm_reg(0, 0)] == 0x00018000  # 1 + 128/256


def test_sm_init_divider_ranges():
    fake, chip = make()
    with pytest.raises(ValueError):
        chip.sm(0).init(simple_prog(), freq=0)
    with pytest.raises(ValueError):
        chip.sm(0).init(simple_prog(), freq=1)  # divider over 65536
    with pytest.raises(ValueError):
        chip.sm(0).init(simple_prog(), clkdiv=0.5)


def test_sm_init_fifo_join_flushes_and_sets_the_bit():
    fake, chip = make()
    chip.sm(2).init(simple_prog(), fifo_join=pg.PIO_JOIN_TX)
    sc = [v for (a, v) in fake.writes if a == sm_reg(2, 0x08)]
    # A flushing write (FJOIN_TX changed), then the final value with FJOIN_TX set.
    assert sc[-1] & (1 << 30)
    assert sc[-2] & (1 << 30) == 0


def test_sm_init_pin_levels_and_directions_use_forced_set():
    fake, chip = make()
    # rp2 encoding: value = (dir << 1) | level. OUT_HIGH = 3 and OUT_LOW = 2, on pins 5 and 6.
    prog = pg.Program([0xE001], name="pins", set_init=[3, 2])
    chip.sm(0).init(prog, set_base=5)
    # The jump to the entry (offset 0), then pins (5 high, 6 low), then directions (both out).
    assert [i for (sm, i) in fake.instr if sm == 0] == [0x0000, 0xE001, 0xE000, 0xE081, 0xE081]
    # Each forced SET runs with PINCTRL pointing at one pin, with SET_COUNT 1.
    seen = []
    for (a, v) in fake.writes:
        if a == sm_reg(0, 0x14) and (v >> 26) & 7 == 1 and (v >> 20) & 0x3F == 0:
            seen.append((v >> 5) & 0x1F)
    assert 5 in seen and 6 in seen


def test_sm_active_restart_exec_and_regs():
    fake, chip = make()
    sm = chip.sm(3)
    sm.active(1)
    assert fake.regs[0x008] == 0x8
    assert sm.active() is True
    sm.restart()
    assert fake.regs[0x008] == 0x8  # the pulse is not kept, the enable bit is
    assert sm.active() is True
    sm.active(0)
    assert fake.regs[0x008] == 0
    sm.exec(0xE081)
    assert fake.instr[-1] == (3, 0xE081)
    regs = sm.regs()
    assert set(regs) >= {"clkdiv", "execctrl", "shiftctrl", "addr", "pinctrl", "ext", "x", "y", "isr", "osr"}


def test_sm_put_get_and_fifo_levels():
    fake, chip = make()
    # FLEVEL: TX n at 8n+3:8n, RX n at 8n+7:8n+4.
    fake.regs[0x014] = 3 | (1 << 4) | (2 << 8) | (4 << 12)
    sm0 = chip.sm(0)
    sm1 = chip.sm(1)
    assert sm0.tx_fifo() == 3 and sm0.rx_fifo() == 1
    assert sm1.tx_fifo() == 2 and sm1.rx_fifo() == 4
    sm0.put(0xAABBCCDD)
    assert fake.tx[-1] == (0, 0xAABBCCDD)
    fake.regs[0x050] = 0x12345678
    assert sm0.get() == 0x12345678


def test_halt_and_step_are_not_implemented():
    fake, chip = make()
    with pytest.raises(NotImplementedError):
        chip.halt()
    with pytest.raises(NotImplementedError):
        chip.step()
    with pytest.raises(NotImplementedError):
        chip.sm(0).halt()
    with pytest.raises(NotImplementedError):
        chip.sm(0).step()


def test_check_reloads_after_deselection_and_passes_when_good():
    fake, chip = make()
    prog = simple_prog()
    chip.load(prog, offset=0)
    chip.sm(0).init(prog, freq=60000000, in_base=24, out_base=23, set_base=22, sideset_base=21)
    chip.sm(0).active(1)
    # SCRATCH reads 0, which is not the nonce, so the design is loaded again.
    assert chip.check() is False
    assert fake.regs[0x038] == chip._nonce
    snap_imem = dict(fake.imem)
    snap_regs = dict(fake.regs)
    assert chip.check() is True
    # Deselection: the chip loses everything. check() must put it all back.
    fake.reset()
    assert chip.check() is False
    assert fake.imem == snap_imem
    for addr in (sm_reg(0, 0), sm_reg(0, 4), sm_reg(0, 0x14), 0x038):
        assert fake.regs[addr] == snap_regs[addr]
    assert fake.regs[0x008] & 1 == 1  # enabled again, after the config
    assert chip.check() is True


def test_check_with_wrong_id_reloads():
    fake, chip = make()
    fake.regs[0x000] = 0x12345678
    assert chip.check() is False
    assert fake.regs[0x038] == chip._nonce


def test_sm_index_range():
    fake, chip = make()
    with pytest.raises(ValueError):
        chip.sm(4)
    assert chip.sm(2) is chip.sm(2)


def test_init_with_handle_or_same_object_does_not_load_again():
    fake, chip = make()
    prog = simple_prog()
    h = chip.load(prog)
    before = len(imem_writes(fake))
    chip.sm(0).init(h)
    chip.sm(1).init(prog)
    assert len(imem_writes(fake)) == before
