"""Register field packing against pico-sdk.

The oracle is the SDK itself, not this library: the bit positions are read from the SDK's
generated register header (hardware/regs/pio.h, RP2350), and the sm_config helpers of
hardware/pio.h are transcribed here as the formulas they compile to. The C helpers are
static inline functions in pio.h; compiling them needs the CMake-generated headers, which
this checkout does not have, so the formulas are copied and the bit positions come from the
header. test_helpers_match_pio_h checks that each transcribed helper still has the body the
SDK has.
"""

import os
import re

import pytest

import polyglot as pg
from fakechip import FakeChip
from test_chip import FakeTransport

SDK = os.path.expanduser("~/.cache/polyglot/pico-sdk")
REGS = os.path.join(SDK, "src/rp2350/hardware_regs/include/hardware/regs/pio.h")
PIO_H = os.path.join(SDK, "src/rp2_common/hardware_pio/include/hardware/pio.h")

needs_sdk = pytest.mark.skipif(not os.path.exists(REGS), reason="pico-sdk not in the cache")


def _header_values():
    vals = {}
    with open(REGS) as f:
        for line in f:
            m = re.match(r"#define (PIO_\w+)\s+_u\((0x[0-9a-fA-F]+|\d+)\)", line)
            if m:
                vals[m.group(1)] = int(m.group(2), 0)
    return vals


@pytest.fixture(scope="module")
def sdk():
    if not os.path.exists(REGS):
        pytest.skip("pico-sdk not in the cache")
    return _header_values()


def _field(sdk, name):
    """(lsb, width) of an SDK field, from its _LSB and _BITS macros."""
    lsb = sdk["PIO_SM0_%s_LSB" % name]
    bits = sdk["PIO_SM0_%s_BITS" % name]
    width = bin(bits).count("1")
    assert bits == ((1 << width) - 1) << lsb, "field %s is not contiguous" % name
    return lsb, width


# Library constant -> SDK field name (SM0 block; the other SMs are the same shifted).
FIELDS = {
    pg.CLKDIV_INT: "CLKDIV_INT",
    pg.CLKDIV_FRAC: "CLKDIV_FRAC",
    pg.EXECCTRL_SIDE_EN: "EXECCTRL_SIDE_EN",
    pg.EXECCTRL_SIDE_PINDIR: "EXECCTRL_SIDE_PINDIR",
    pg.EXECCTRL_JMP_PIN: "EXECCTRL_JMP_PIN",
    pg.EXECCTRL_OUT_EN_SEL: "EXECCTRL_OUT_EN_SEL",
    pg.EXECCTRL_INLINE_OUT_EN: "EXECCTRL_INLINE_OUT_EN",
    pg.EXECCTRL_OUT_STICKY: "EXECCTRL_OUT_STICKY",
    pg.EXECCTRL_WRAP_TOP: "EXECCTRL_WRAP_TOP",
    pg.EXECCTRL_WRAP_BOTTOM: "EXECCTRL_WRAP_BOTTOM",
    pg.SHIFTCTRL_FJOIN_RX: "SHIFTCTRL_FJOIN_RX",
    pg.SHIFTCTRL_FJOIN_TX: "SHIFTCTRL_FJOIN_TX",
    pg.SHIFTCTRL_PULL_THRESH: "SHIFTCTRL_PULL_THRESH",
    pg.SHIFTCTRL_PUSH_THRESH: "SHIFTCTRL_PUSH_THRESH",
    pg.SHIFTCTRL_OUT_SHIFTDIR: "SHIFTCTRL_OUT_SHIFTDIR",
    pg.SHIFTCTRL_IN_SHIFTDIR: "SHIFTCTRL_IN_SHIFTDIR",
    pg.SHIFTCTRL_AUTOPULL: "SHIFTCTRL_AUTOPULL",
    pg.SHIFTCTRL_AUTOPUSH: "SHIFTCTRL_AUTOPUSH",
    pg.PINCTRL_SIDESET_COUNT: "PINCTRL_SIDESET_COUNT",
    pg.PINCTRL_SET_COUNT: "PINCTRL_SET_COUNT",
    pg.PINCTRL_OUT_COUNT: "PINCTRL_OUT_COUNT",
    pg.PINCTRL_IN_BASE: "PINCTRL_IN_BASE",
    pg.PINCTRL_SIDESET_BASE: "PINCTRL_SIDESET_BASE",
    pg.PINCTRL_SET_BASE: "PINCTRL_SET_BASE",
    pg.PINCTRL_OUT_BASE: "PINCTRL_OUT_BASE",
}


@needs_sdk
def test_field_positions_match_sdk(sdk):
    for lib_field, sdk_name in FIELDS.items():
        assert (lib_field[0], lib_field[1]) == _field(sdk, sdk_name), sdk_name


REGS40 = os.path.join(SDK, "src/rp2040/hardware_regs/include/hardware/regs/pio.h")


def _rp2040_values():
    vals = {}
    with open(REGS40) as f:
        for line in f:
            m = re.match(r"#define (PIO_\w+)\s+_u\((0x[0-9a-fA-F]+|\d+)\)", line)
            if m:
                vals[m.group(1)] = int(m.group(2), 0)
    return vals


@pytest.fixture(scope="module")
def sdk40():
    if not os.path.exists(REGS40):
        pytest.skip("pico-sdk RP2040 headers not in the cache")
    return _rp2040_values()


@needs_sdk
def test_mov_status_fields_are_the_rp2040_layout(sdk40):
    # chip.md 8.1 uses the RP2040 EXECCTRL: STATUS_SEL is bit 4, STATUS_N is [3:0].
    assert sdk40["PIO_SM0_EXECCTRL_STATUS_SEL_LSB"] == 4
    assert sdk40["PIO_SM0_EXECCTRL_STATUS_SEL_BITS"] == 0x10
    assert sdk40["PIO_SM0_EXECCTRL_STATUS_N_LSB"] == 0
    assert sdk40["PIO_SM0_EXECCTRL_STATUS_N_BITS"] == 0x0F
    assert sdk40["PIO_SM0_EXECCTRL_BITS"] == 0xFFFFFF9F  # the writable bits chip.md calls 0x7FFFFF9F
    assert pg.EXECCTRL_STATUS_SEL == (4, 1)
    assert pg.EXECCTRL_STATUS_N == (0, 4)


@needs_sdk
def test_fdebug_sm_flags_match_rp2040_layout(sdk40):
    # pio_sm_init clears TXOVER, RXUNDER, TXSTALL and RXSTALL for its SM: pio.h's pio.c, pio_sm_init.
    assert sdk40["PIO_FDEBUG_RXSTALL_LSB"] == 0
    assert sdk40["PIO_FDEBUG_RXUNDER_LSB"] == 8
    assert sdk40["PIO_FDEBUG_TXOVER_LSB"] == 16
    assert sdk40["PIO_FDEBUG_TXSTALL_LSB"] == 24
    assert pg.FDEBUG_SM_FLAGS == (1 << 0) | (1 << 8) | (1 << 16) | (1 << 24)


@needs_sdk
def test_reset_values_are_chip_md_table(sdk):
    # chip.md section 8.1 reset column, which is the SDK's RP2040/RP2350 reset.
    assert sdk["PIO_SM0_CLKDIV_RESET"] == 0x00010000
    assert sdk["PIO_SM0_EXECCTRL_RESET"] == 0x0001F000
    assert sdk["PIO_SM0_SHIFTCTRL_RESET"] == 0x000C0000
    assert sdk["PIO_SM0_PINCTRL_RESET"] == 0x14000000


@needs_sdk
def test_fifo_level_layout_matches_sdk(sdk):
    # FLEVEL: TX n at bits 8n..8n+3, RX n at 8n+4..8n+7.
    for n in range(4):
        assert sdk["PIO_FLEVEL_TX%d_LSB" % n] == 8 * n
        assert sdk["PIO_FLEVEL_RX%d_LSB" % n] == 8 * n + 4
    fake = FakeChip()
    from polyglot import Chip

    chip = Chip(FakeTransport(fake))
    fake.regs[0x014] = 0x7A5C3E21
    for n in range(4):
        tx = (0x7A5C3E21 >> (8 * n)) & 0xF
        rx = (0x7A5C3E21 >> (8 * n + 4)) & 0xF
        assert chip.fifo_levels(n) == (tx, rx)


# --- the sm_config helpers of pio.h, as formulas over the SDK fields -------------------


def _set(value, sdk, name, x):
    lsb, width = _field(sdk, name)
    assert 0 <= x < (1 << width), (name, x)
    mask = ((1 << width) - 1) << lsb
    return (value & ~mask) | (x << lsb)


def sdk_clkdiv_int_frac8(c, sdk, div_int, div_frac8):
    # sm_config_set_clkdiv_int_frac8
    return (div_frac8 << _field(sdk, "CLKDIV_FRAC")[0]) | (div_int << _field(sdk, "CLKDIV_INT")[0])


def sdk_wrap(ex, sdk, wrap_target, wrap):
    # sm_config_set_wrap: clears TOP and BOTTOM (the _BITS masks), then sets both
    mask = sdk["PIO_SM0_EXECCTRL_WRAP_TOP_BITS"] | sdk["PIO_SM0_EXECCTRL_WRAP_BOTTOM_BITS"]
    lsb_b = _field(sdk, "EXECCTRL_WRAP_BOTTOM")[0]
    lsb_t = _field(sdk, "EXECCTRL_WRAP_TOP")[0]
    return (ex & ~mask) | (wrap_target << lsb_b) | (wrap << lsb_t)


def sdk_sideset(pc, ex, sdk, bit_count, optional, pindirs):
    # sm_config_set_sideset
    pc = _set(pc, sdk, "PINCTRL_SIDESET_COUNT", bit_count)
    ex = _set(ex, sdk, "EXECCTRL_SIDE_EN", 1 if optional else 0)
    ex = _set(ex, sdk, "EXECCTRL_SIDE_PINDIR", 1 if pindirs else 0)
    return pc, ex


def sdk_pin_base(pc, sdk, name, base):
    return _set(pc, sdk, name, base)


def sdk_shift(sc, sdk, prefix, right, autox, thresh):
    # sm_config_set_in_shift / sm_config_set_out_shift
    if prefix == "IN":
        sc = _set(sc, sdk, "SHIFTCTRL_IN_SHIFTDIR", 1 if right else 0)
        sc = _set(sc, sdk, "SHIFTCTRL_AUTOPUSH", 1 if autox else 0)
        sc = _set(sc, sdk, "SHIFTCTRL_PUSH_THRESH", thresh & 0x1F)
    else:
        sc = _set(sc, sdk, "SHIFTCTRL_OUT_SHIFTDIR", 1 if right else 0)
        sc = _set(sc, sdk, "SHIFTCTRL_AUTOPULL", 1 if autox else 0)
        sc = _set(sc, sdk, "SHIFTCTRL_PULL_THRESH", thresh & 0x1F)
    return sc


@needs_sdk
def test_helpers_match_pio_h(sdk):
    """The transcribed bodies still appear in pio.h, so a change there shows up here."""
    text = open(PIO_H).read()
    for needle in (
        "(((uint)div_frac8) << PIO_SM0_CLKDIV_FRAC_LSB) |",
        "(wrap_target << PIO_SM0_EXECCTRL_WRAP_BOTTOM_LSB) |",
        "(wrap << PIO_SM0_EXECCTRL_WRAP_TOP_LSB);",
        "(bool_to_bit(shift_right) << PIO_SM0_SHIFTCTRL_IN_SHIFTDIR_LSB) |",
        "((pull_threshold & 0x1fu) << PIO_SM0_SHIFTCTRL_PULL_THRESH_LSB);",
        "(bit_count << PIO_SM0_PINCTRL_SIDESET_COUNT_LSB);",
    ):
        assert needle in text, needle


@needs_sdk
def test_library_helpers_match_sdk_formulas(sdk):
    # clkdiv: INT 2, FRAC 0x80
    assert pg.clkdiv_word(2, 0x80) == sdk_clkdiv_int_frac8(0, sdk, 2, 0x80)
    assert pg.clkdiv_word(0xFFFF, 0xFF) == sdk_clkdiv_int_frac8(0, sdk, 0xFFFF, 0xFF)
    # wrap: target 3, top 17
    ex = sdk_wrap(0, sdk, 3, 17)
    lib = pg.field_set(pg.field_set(0, pg.EXECCTRL_WRAP_BOTTOM, 3), pg.EXECCTRL_WRAP_TOP, 17)
    assert lib == ex


@needs_sdk
def test_init_packing_matches_sdk(sdk):
    """Chip init writes exactly what pio.h's helpers would put in the SM registers."""
    fake = FakeChip()
    chip = pg.Chip(FakeTransport(fake))
    prog = pg.Program(
        [0xE001, 0x0003, 0x6001, 0x0000],
        name="sdkcheck",
        wrap_target=1,
        wrap=3,
        side_count=2,
        side_opt=True,
        side_pindir=True,
        shiftctrl=0x000C0000,
    )
    h = chip.load(prog, offset=8)
    n = 2
    chip.sm(n).init(
        prog,
        clkdiv=2.5,
        in_base=3,
        out_base=12,
        set_base=20,
        jmp_pin=17,
        sideset_base=6,
        in_shiftdir=pg.PIO_SHIFT_LEFT,
        out_shiftdir=pg.PIO_SHIFT_RIGHT,
        push_thresh=16,
        pull_thresh=7,
        autopush=True,
        autopull=False,
        fifo_join=pg.PIO_JOIN_RX,
        out_count=8,
        set_count=3,
    )
    base = 0x200 + 0x40 * n
    got_div = fake.regs[base + 0x00]
    got_ex = fake.regs[base + 0x04]
    got_sc = fake.regs[base + 0x08]
    got_pc = fake.regs[base + 0x14]

    # Expected: the helper calls of the SDK, applied in the order the library uses (start
    # from 0 for PINCTRL and EXECCTRL, from the program's SHIFTCTRL for SHIFTCTRL).
    off = h.offset
    div = sdk_clkdiv_int_frac8(0, sdk, 2, 128)
    ex = 0
    pc = 0
    ex = sdk_wrap(ex, sdk, 1 + off, 3 + off)
    pc, ex = sdk_sideset(pc, ex, sdk, 2, True, True)
    ex = _set(ex, sdk, "EXECCTRL_JMP_PIN", 17)
    pc = sdk_pin_base(pc, sdk, "PINCTRL_OUT_BASE", 12)
    pc = _set(pc, sdk, "PINCTRL_OUT_COUNT", 8)
    pc = sdk_pin_base(pc, sdk, "PINCTRL_SET_BASE", 20)
    pc = _set(pc, sdk, "PINCTRL_SET_COUNT", 3)
    pc = sdk_pin_base(pc, sdk, "PINCTRL_IN_BASE", 3)
    pc = sdk_pin_base(pc, sdk, "PINCTRL_SIDESET_BASE", 6)
    sc = 0x000C0000
    sc = sdk_shift(sc, sdk, "IN", False, True, 16)
    sc = sdk_shift(sc, sdk, "OUT", True, False, 7)
    sc = _set(sc, sdk, "SHIFTCTRL_FJOIN_RX", 1)
    sc = _set(sc, sdk, "SHIFTCTRL_FJOIN_TX", 0)

    assert got_div == div
    assert got_ex == ex
    assert got_pc == pc
    assert got_sc == sc
