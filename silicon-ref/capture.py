# silicon-ref/capture.py
#
# MicroPython capture script for a Raspberry Pi Pico 2 (RP2350). It runs one PIO
# state machine (the program under test) and a second state machine on the same PIO
# block that samples a group of pins on every system clock (a logic analyser).
#
# STATUS: UNTESTED ON HARDWARE. Written from the RP2350 register map (checked against
# pico-sdk 2.3.1, src/rp2350/hardware_regs) and the MicroPython rp2 port. Nothing here
# has run on a board yet. Every register address and API call that is not verified on
# the board is marked [verify on hardware]. A host-side mock test
# (silicon-ref/test_capture_mock.py) checks the register write sequence, not the silicon.
#
# Usage (on the board, with the pioasm JSON copied to flash):
#   import capture
#   capture.run(
#       program_json="/prog.json",           # pioasm -o json output
#       program_name=None,                   # None = first program in the file
#       pins=dict(out_base=0, out_count=1, set_base=0, sideset_base=0,
#                 in_base=0, jmp_pin=0),
#       capture_base=0,                      # first pin sampled by the capture SM
#       samples=40000,                       # multiple of 4 (samples per 32-bit word)
#       out_path="/trace.jsonl",
#   )
#
# Which settings come from the pioasm JSON and which must be passed: see README.md,
# section "Program configuration". Summary: the JSON gives wrap, entry point, side-set
# and (only when the source has .in/.out/.fifo directives) shift settings. The C SDK sets
# set-count, clock divider and shift settings in C, so those must be passed as arguments.
#
# Limits are documented in README.md. Summary: 8 pins give 4 samples per 32-bit word,
# so the capture SM pushes one word every 4 sysclk cycles. That is 37.5 Mword/s at
# 150 MHz sysclk, which one DMA channel should sustain [verify on hardware].

import json
import time

import machine
import rp2
import uctypes

# ---------------------------------------------------------------------------
# RP2350 register map [verify on hardware]
# Addresses and offsets are from pico-sdk 2.3.1, src/rp2350/hardware_regs/include/
# hardware/regs/{addressmap.h, pio.h, resets.h, io_bank0.h, pads_bank0.h, dreq.h}.
# ---------------------------------------------------------------------------
PIO0_BASE = 0x50200000            # addressmap.h PIO0_BASE [verify on hardware]
PIO_CTRL = 0x000                  # pio.h PIO_CTRL_OFFSET
CTRL_SM_ENABLE_LSB = 0            # PIO_CTRL_SM_ENABLE_LSB, bits [3:0]
CTRL_SM_RESTART_LSB = 4           # PIO_CTRL_SM_RESTART_LSB, bits [7:4] (self-clearing)
CTRL_CLKDIV_RESTART_LSB = 8       # PIO_CTRL_CLKDIV_RESTART_LSB, bits [11:8] (self-clearing)
PIO_FDEBUG = 0x008                # pio.h PIO_FDEBUG_OFFSET; RXSTALL [3:0], RXUNDER [11:8],
                                  # TXOVER [19:16], TXSTALL [27:24]; write 1 to clear
FDEBUG_CLEAR_ALL = 0x0F0F0F0F     # all four sticky fields, one nibble each
PIO_TXF0 = 0x010                  # pio.h PIO_TXF0_OFFSET; TXFn at +4*n
PIO_RXF0 = 0x020                  # pio.h PIO_RXF0_OFFSET; RXFn at +4*n
PIO_INSTR_MEM0 = 0x048            # pio.h PIO_INSTR_MEM0_OFFSET; 32 words at +4*n
SM0_CLKDIV = 0x0C8                # pio.h PIO_SM0_CLKDIV_OFFSET
SM0_EXECCTRL = 0x0CC              # pio.h PIO_SM0_EXECCTRL_OFFSET
SM0_SHIFTCTRL = 0x0D0             # pio.h PIO_SM0_SHIFTCTRL_OFFSET
SM0_INSTR = 0x0D8                 # pio.h PIO_SM0_INSTR_OFFSET; a write executes at once
SM0_PINCTRL = 0x0DC               # pio.h PIO_SM0_PINCTRL_OFFSET
SM_STRIDE = 0x18                  # SMn registers are SM0 + n * 0x18

SHIFTCTRL_FJOIN_RX = 1 << 31      # PIO_SM0_SHIFTCTRL_FJOIN_RX_LSB 31
SHIFTCTRL_FJOIN_TX = 1 << 30      # PIO_SM0_SHIFTCTRL_FJOIN_TX_LSB 30

RESETS_BASE = 0x40020000          # addressmap.h RESETS_BASE [verify on hardware]
RESETS_RESET = 0x000              # resets.h RESETS_RESET_OFFSET; 1 = held in reset
RESETS_RESET_DONE = 0x008         # resets.h RESETS_RESET_DONE_OFFSET; 1 = out of reset
RESET_DMA = 1 << 2                # resets.h RESETS_RESET_DMA_BITS
RESET_PIO0 = 1 << 11              # resets.h RESETS_RESET_PIO0_BITS
REG_ALIAS_SET = 0x2000            # addressmap.h REG_ALIAS_SET_BITS (0x2 << 12)
REG_ALIAS_CLR = 0x3000            # addressmap.h REG_ALIAS_CLR_BITS (0x3 << 12)

IO_BANK0_BASE = 0x40028000        # addressmap.h IO_BANK0_BASE; GPIOn_CTRL at +4 + 8n, FUNCSEL [4:0]
PADS_BANK0_BASE = 0x40038000      # addressmap.h PADS_BANK0_BASE; GPIOn pad at +4 + 4n
PAD_OD_BIT = 1 << 7               # pads_bank0.h PADS_BANK0_GPIO0_OD_BITS (0x80), output disable
PAD_IE_BIT = 1 << 6               # pads_bank0.h PADS_BANK0_GPIO0_IE_BITS (0x40), input enable
PAD_ISO_BIT = 1 << 8              # pads_bank0.h PADS_BANK0_GPIO0_ISO_BITS (0x100), reset value 1
FUNCSEL_PIO0 = 6                  # rp2350/hardware_structs/io_bank0.h GPIO_FUNC_PIO0 = 6 (PIO2 = 8)
DREQ_PIO0_RX0 = 4                 # dreq.h DREQ_PIO0_RX0 = 4; RX1 = 5 (TX0 = 0)
EXECCTRL_OUT_STICKY = 1 << 17     # pio.h PIO_SM0_EXECCTRL_OUT_STICKY_BITS (bit 17) [verify on hardware]
SIO_BASE = 0xD0000000             # addressmap.h SIO_BASE (checked in pico-sdk 2.3.1 rp2350 headers)
SIO_GPIO_OUT_SET = 0x018          # sio.h SIO_GPIO_OUT_SET_OFFSET
SIO_GPIO_OUT_CLR = 0x020          # sio.h SIO_GPIO_OUT_CLR_OFFSET
SIO_GPIO_OE_SET = 0x038           # sio.h SIO_GPIO_OE_SET_OFFSET
FUNCSEL_SIO = 5                   # io_bank0.h GPIO_FUNC_SIO = 5

# SET instruction: opcode 111 in [15:13]; destination in [7:5] (pio_instructions.h
# pio_pins = 0, pio_pindirs = 4); 5-bit data in [4:0].
SET_OPCODE = 0xE000
SET_DEST_PINS = 0
SET_DEST_PINDIRS = 4

# In-instruction encoding: IN (opcode 010) source PINS (000), bit count N (0 = 32).
# pioasm 2.3.1 assembles `in pins, 8` to 0x4008 (checked with `pioasm -o hex`).
def in_pins_word(nbits):
    return 0x4000 | (nbits & 0x1F)


def _w(addr, value):
    machine.mem32[addr] = value & 0xFFFFFFFF


def _r(addr):
    return machine.mem32[addr]


def _sm_reg(sm, base_off):
    # base_off is the SM0 offset; SMn is SM0 + n * 0x18
    return PIO0_BASE + base_off + SM_STRIDE * sm


def _ensure_pio0_and_dma_out_of_reset():
    """Release PIO0 and DMA from reset if held, and wait for RESET_DONE.

    Uses the atomic CLR alias (REG_ALIAS_CLR_BITS) like the SDK's reset_unreset_block.
    A no-op when the blocks are already out of reset. [verify on hardware]
    """
    held = _r(RESETS_BASE + RESETS_RESET) & (RESET_PIO0 | RESET_DMA)
    if not held:
        return
    _w(RESETS_BASE + REG_ALIAS_CLR + RESETS_RESET, held)
    for _ in range(100000):
        if (_r(RESETS_BASE + RESETS_RESET_DONE) & held) == held:
            return
    raise RuntimeError("PIO0/DMA did not leave reset (RESETS_RESET_DONE stuck)")


def _load_pioasm_program(path, name):
    """Read one program from a pioasm -o json file. Returns the program dict."""
    with open(path) as f:
        doc = json.load(f)
    progs = doc["programs"]
    if name is None:
        return progs[0]
    for p in progs:
        if p["name"] == name:
            return p
    raise ValueError("program %r not found in %s" % (name, path))


_FIFO_FROM_JSON = {None: "none", "PIO_FIFO_JOIN_TX": "tx", "PIO_FIFO_JOIN_RX": "rx"}


def _pick(override, json_value, default):
    """Explicit argument wins, then the JSON value, then the PIO reset default."""
    if override is not None:
        return override
    if json_value is not None:
        return json_value
    return default


def _program_regs(p, pins, ov, offset=0):
    """Compute SM register values for the program under test.

    Precedence per setting: explicit argument (ov, a dict with None = not given), then the
    pioasm JSON, then the PIO reset value. Field positions are from pio.h:
    SM0_EXECCTRL, SM0_SHIFTCTRL, SM0_PINCTRL, SM0_CLKDIV.
    """
    if p.get("pioVersion", 0) != 0:
        raise NotImplementedError("pioVersion %r: only PIO v0 (RP2040 PIO) is handled" % p.get("pioVersion"))
    if p.get("origin", -1) not in (-1, 0):
        raise NotImplementedError("program origin must be 0 or unset (no relocation here)")
    if p.get("movStatus") is not None:
        raise NotImplementedError("movStatus (STATUS_SEL) not handled yet")

    # FIFO join: the JSON field is null unless the source sets .fifo; explicit arg wins.
    if p.get("fifoConfig") not in _FIFO_FROM_JSON:
        raise NotImplementedError("fifoConfig %r is PIO v1 or unhandled" % p.get("fifoConfig"))
    fifo = _pick(ov["fifo_join"], _FIFO_FROM_JSON[p.get("fifoConfig")], "none")
    if fifo not in ("none", "tx", "rx"):
        raise ValueError("fifo_join must be 'none', 'tx' or 'rx'")

    # Side-set: JSON object or null (null = no side-set). Explicit args override each field.
    # ss_total is the JSON `size`, which pioasm defines as the side-set bits INCLUDING the
    # enable bit when optional (json_output.cpp:159-162 writes sideset_bits_including_opt;
    # pio_types.h:307). It is also the SIDESET_COUNT field value (pio.h
    # PIO_SM0_PINCTRL_SIDESET_COUNT, "Inclusive of the enable bit, if present").
    # The data pins are ss_total minus the enable bit.
    ss_json = p.get("sideset") or {"size": 0, "optional": False, "pindirs": False}
    ss_total = _pick(ov["sideset_size"], ss_json["size"], 0)
    ss_opt = bool(_pick(ov["sideset_optional"], ss_json["optional"], False))
    ss_pindirs = bool(_pick(ov["sideset_pindirs"], ss_json["pindirs"], False))
    if not 0 <= ss_total <= 5:
        raise ValueError("side-set size (incl. enable bit) must be 0..5")
    if ss_opt and ss_total < 1:
        raise ValueError("optional side-set needs size >= 1 (the enable bit is part of size)")
    ss_data = ss_total - (1 if ss_opt else 0)     # side-set data pins
    ss_count = ss_total                           # SIDESET_COUNT, enable bit included

    # .in / .out settings: JSON object (only when the source has the directive) or null.
    inn = p.get("in") or {}
    outp = p.get("out") or {}
    in_right = bool(_pick(ov["in_shift_right"], inn.get("right"), True))
    out_right = bool(_pick(ov["out_shift_right"], outp.get("right"), True))
    autopush = bool(_pick(ov["autopush"], inn.get("autopush"), False))
    autopull = bool(_pick(ov["autopull"], outp.get("autopull"), False))
    push_thr = _pick(ov["push_thresh"], inn.get("threshold"), 32)
    pull_thr = _pick(ov["pull_thresh"], outp.get("threshold"), 32)
    for name, t in (("push_thresh", push_thr), ("pull_thresh", pull_thr)):
        if not 1 <= t <= 32:
            raise ValueError("%s must be 1..32 (32 is encoded as 0)" % name)

    set_count = _pick(ov["set_count"], p.get("setCount"), 5)     # PIO reset SET_COUNT = 5
    if not 0 <= set_count <= 5:
        raise ValueError("set_count must be 0..5")

    cd_json = p.get("clockDiv") or {"int": 1, "frac": 0}          # PIO reset divider 1.0
    cd_int, cd_frac = ov["clkdiv"] if ov["clkdiv"] is not None else (cd_json["int"], cd_json["frac"])
    if not 1 <= cd_int <= 65535 or not 0 <= cd_frac <= 255:
        raise ValueError("clkdiv: int 1..65535 (0 would mean 65536), frac 0..255")

    wrap_top = offset + p["wrap"]
    wrap_bottom = offset + p["wrapTarget"]
    execctrl = ((1 if ss_opt else 0) << 30) | ((1 if ss_pindirs else 0) << 29) \
        | ((pins["jmp_pin"] & 0x1F) << 24) | ((wrap_top & 0x1F) << 12) | ((wrap_bottom & 0x1F) << 7)
    shiftctrl = ((1 if fifo == "rx" else 0) << 31) | ((1 if fifo == "tx" else 0) << 30) \
        | ((pull_thr & 0x1F) << 25) | ((push_thr & 0x1F) << 20) \
        | ((1 if out_right else 0) << 19) | ((1 if in_right else 0) << 18) \
        | ((1 if autopull else 0) << 17) | ((1 if autopush else 0) << 16)
    out_count = pins["out_count"]
    pinctrl = (ss_count << 29) | (set_count << 26) | ((out_count & 0x3F) << 20) \
        | ((pins["in_base"] & 0x1F) << 15) | ((pins["sideset_base"] & 0x1F) << 10) \
        | ((pins["set_base"] & 0x1F) << 5) | (pins["out_base"] & 0x1F)
    clkdiv = ((cd_int & 0xFFFF) << 16) | ((cd_frac & 0xFF) << 8)
    return dict(clkdiv=clkdiv, execctrl=execctrl, shiftctrl=shiftctrl, pinctrl=pinctrl,
                fifo=fifo, set_count=set_count, ss_size=ss_total, ss_data=ss_data,
                ss_optional=ss_opt, ss_pindirs=ss_pindirs, in_right=in_right, out_right=out_right,
                autopush=autopush, autopull=autopull, push_thresh=push_thr,
                pull_thresh=pull_thr, clkdiv_int=cd_int, clkdiv_frac=cd_frac,
                pin_span=(pins["out_base"], out_count),
                set_span=(pins["set_base"], set_count),
                side_span=(pins["sideset_base"], ss_data))


def _set_pio_function(pin):
    """Route a pad to PIO0, clear pad isolation (ISO) and output disable (OD).

    ISO resets to 1 on RP2350 (pads_bank0.h PADS_BANK0_GPIO0_ISO_RESET = 1), and an isolated
    pad reads 0, so the trace would be flat. [verify on hardware]
    """
    ctrl_addr = IO_BANK0_BASE + 4 + 8 * pin
    v = _r(ctrl_addr)
    _w(ctrl_addr, (v & ~0x1F) | FUNCSEL_PIO0)
    pad_addr = PADS_BANK0_BASE + 4 + 4 * pin
    _w(pad_addr, _r(pad_addr) & ~(PAD_ISO_BIT | PAD_OD_BIT))


def _enable_input(pin):
    """Input enable for a sampled pin, with the same ISO and OD clearing as _set_pio_function."""
    pad_addr = PADS_BANK0_BASE + 4 + 4 * pin
    _w(pad_addr, (_r(pad_addr) | PAD_IE_BIT) & ~(PAD_ISO_BIT | PAD_OD_BIT))


def _flush_fifos(sm, shiftctrl):
    """Empty the RX and TX FIFOs of one SM. [verify on hardware]

    Same method as pico-sdk pio_sm_clear_fifos (pio.h): toggling FJOIN_RX clears both
    FIFOs. The SDK does the toggle with the XOR alias. Here it is two plain writes of the
    value the SM is about to run with, so the final FJOIN_RX setting is unchanged.
    """
    addr = _sm_reg(sm, SM0_SHIFTCTRL)
    _w(addr, shiftctrl ^ SHIFTCTRL_FJOIN_RX)
    _w(addr, shiftctrl)


def _exec_on_sm(sm, instr):
    """Execute one instruction on an SM through SMn_INSTR (pio.h pio_sm_exec). SM disabled."""
    _w(_sm_reg(sm, SM0_INSTR), instr)


def _set_pins_or_dirs(sm, levels, dest):
    """Drive `set pins` or `set pindirs` on a disabled SM, a few pins at a time.

    levels: dict pin -> 0 or 1. Pins are grouped into runs of up to 5 consecutive pins
    (SET_COUNT is at most 5). This does what the SDK's pio_sm_set_pins_with_mask and
    pio_sm_set_consecutive_pindirs do. PINCTRL is changed for each run and the caller
    rewrites the final PINCTRL afterwards. [verify on hardware]
    """
    pins_sorted = sorted(levels)
    run = []
    groups = []
    for p in pins_sorted:
        if run and (p != run[-1] + 1 or len(run) == 5):
            groups.append(run)
            run = []
        run.append(p)
    if run:
        groups.append(run)
    for g in groups:
        base = g[0]
        value = 0
        for i, p in enumerate(g):
            if levels[p] not in (0, 1):
                raise ValueError("pin level must be 0 or 1")
            value |= (levels[p] & 1) << i
        _w(_sm_reg(sm, SM0_PINCTRL), (len(g) << 26) | ((base & 0x1F) << 5))
        _exec_on_sm(sm, SET_OPCODE | (dest << 5) | value)


def _stop_both(ctrl_addr, en_mask):
    _w(ctrl_addr, _r(ctrl_addr) & ~en_mask)


def _do_host_action(act, program_sm, host_log, rx_reads):
    """One CPU action from run(host_actions). Logged, so the header records what was done."""
    kind = act[0]
    if kind == "gpio":
        _w(SIO_BASE + (SIO_GPIO_OUT_SET if act[2] else SIO_GPIO_OUT_CLR), 1 << (act[1] & 31))
    elif kind == "rx":
        for _ in range(act[1]):
            rx_reads.append(_r(PIO0_BASE + PIO_RXF0 + 4 * program_sm))
    elif kind == "tx":
        _w(PIO0_BASE + PIO_TXF0 + 4 * program_sm, act[1] & 0xFFFFFFFF)
    elif kind == "instr":
        _w(_sm_reg(program_sm, SM0_INSTR), act[1] & 0xFFFF)
    else:
        raise ValueError("unknown host action %r" % (kind,))
    host_log.append(list(act))


def run(program_json, program_name, pins, capture_base, samples, out_path,
        capture_sm=1, program_sm=0, sysclk_hz=None, dma_timeout_ms=5000,
        # --- explicit settings (None = take the pioasm JSON value, else the PIO reset value)
        in_shift_right=None, out_shift_right=None, autopush=None, autopull=None,
        push_thresh=None, pull_thresh=None, fifo_join=None, set_count=None,
        sideset_size=None, sideset_optional=None, sideset_pindirs=None, clkdiv=None,
        # --- initial state of the program under test, applied before enable
        tx_words=None, init_levels=None, init_dirs=None,
        # --- OUT_STICKY (EXECCTRL bit 17) on the program under test
        out_sticky=False,
        # --- pins driven by the CPU through SIO instead of PIO: list of (pin, level).
        # PIO still reads them as inputs. Used with host_actions.
        host_pins=None,
        # --- CPU actions during the run, each at `after_us` after the enable write:
        #   (after_us, ("gpio", pin, level))   set a host_pins pin
        #   (after_us, ("rx", n))              read n words of the program SM's RX FIFO
        #   (after_us, ("tx", word))           write one word to the program SM's TX FIFO
        #   (after_us, ("instr", hex_word))    write SMx_INSTR for the program SM (forced)
        # Timing is set by MicroPython, so it is microseconds, not cycles. The landing cycle of
        # an action must be read from the trace (its effect on a pin), not from this list.
        host_actions=None):
    """Load the program under test on program_sm and the capture program on capture_sm,
    capture `samples` pin samples (8 pins), and write a trace file to out_path.

    fifo_join: "none", "tx" or "rx" (joins the program SM's FIFOs; the capture SM is always
        unjoined). clkdiv: (int, frac) tuple. set_count: 0..5.
    sideset_size: the JSON `sideset.size` convention, which INCLUDES the enable bit when
        sideset_optional is true. So `.side_set 1 opt` is sideset_size=2, sideset_optional=True.
        Data pins = sideset_size - (1 if sideset_optional else 0). Do not add the bit yourself.
    tx_words: up to 4 words (8 with fifo_join "tx") written to the program SM's TX FIFO
        by the CPU before enable. Longer streams need TX DMA, which is not written.
    init_levels / init_dirs: dict pin -> 0/1, applied with `set pins` / `set pindirs`.
        Pins used here must be in the program's pin range (out/set/sideset) to be useful.
    """
    if samples % 4 != 0:
        raise ValueError("samples must be a multiple of 4 (4 samples per 32-bit word)")
    if program_sm == capture_sm:
        raise ValueError("use two different state machines")
    n_words = samples // 4
    buf = bytearray(4 * n_words)        # 1 byte per sample; RAM bound, see README

    prog = _load_pioasm_program(program_json, program_name)
    words = [int(i["hex"], 16) for i in prog["instructions"]]
    cap_word = in_pins_word(8)
    if len(words) + 1 > 32:
        raise ValueError("program does not leave room for the capture instruction")
    cap_off = len(words)                 # capture program placed right after the program
    # Program under test is loaded at offset 0. Its entry point is the first instruction
    # unless the file names one through a label (pioasm publicLabels, e.g. entry_point).
    entry = prog.get("publicLabels", {}).get("entry_point", 0)

    ov = dict(in_shift_right=in_shift_right, out_shift_right=out_shift_right,
              autopush=autopush, autopull=autopull, push_thresh=push_thresh,
              pull_thresh=pull_thresh, fifo_join=fifo_join, set_count=set_count,
              sideset_size=sideset_size, sideset_optional=sideset_optional,
              sideset_pindirs=sideset_pindirs, clkdiv=clkdiv)
    pr = _program_regs(prog, pins, ov)
    pr["entry"] = entry
    if entry >= len(words):
        raise ValueError("entry point %d is outside the program" % entry)
    if out_sticky:
        pr["execctrl"] |= EXECCTRL_OUT_STICKY

    tx_words = list(tx_words or [])
    tx_limit = 8 if pr["fifo"] == "tx" else 4
    if len(tx_words) > tx_limit:
        raise ValueError("tx_words: at most %d words fit the TX FIFO (fifo_join=%r)"
                         % (tx_limit, pr["fifo"]))
    for w in tx_words:
        if not 0 <= w <= 0xFFFFFFFF:
            raise ValueError("tx_words must be 32-bit values")
    init_levels = dict(init_levels or {})
    init_dirs = dict(init_dirs or {})

    pin_set = set()
    for base, n in (pr["pin_span"], pr["set_span"], pr["side_span"]):
        for p in range(base, base + n):
            pin_set.add(p & 31)
    cap_pins = [(capture_base + j) & 31 for j in range(8)]
    # Initial pin levels and directions also touch the pads, so they are driven by the PIO.
    pin_set |= set(init_levels) | set(init_dirs)
    host_pins = [(int(p) & 31, int(v) & 1) for p, v in (host_pins or [])]
    host_set = {p for p, _ in host_pins}
    if host_set & pin_set:
        raise ValueError("host_pins %s overlap pins the program drives" % sorted(host_set & pin_set))
    host_actions = sorted(host_actions or [], key=lambda a: a[0])
    for _, act in host_actions:
        if act[0] == "gpio" and (act[1] & 31) not in host_set:
            raise ValueError("gpio action on pin %d, which is not in host_pins" % act[1])
    pin_set -= host_set

    cap_execctrl = ((cap_off & 0x1F) << 12) | ((cap_off & 0x1F) << 7)
    cap_shiftctrl = (1 << 19) | (1 << 18) | (1 << 16)     # out right, in right, autopush, thresh 32
    cap_pinctrl = ((capture_base & 0x1F) << 15)
    cap_clkdiv = 1 << 16                                  # INT 1, FRAC 0: samples every sysclk

    en_mask = (1 << program_sm) | (1 << capture_sm)
    ctrl_addr = PIO0_BASE + PIO_CTRL
    if sysclk_hz is None:
        sysclk_hz = machine.freq()

    # 1. PIO0 and DMA out of reset (RESETS). No-op when they already are.
    _ensure_pio0_and_dma_out_of_reset()
    # 2. Both SMs disabled. The restart happens later, after all configuration.
    _stop_both(ctrl_addr, en_mask)
    _w(PIO0_BASE + PIO_FDEBUG, FDEBUG_CLEAR_ALL)
    # 3. Instruction memory: program at 0, capture instruction after it.
    for i, w in enumerate(words):
        _w(PIO0_BASE + PIO_INSTR_MEM0 + 4 * i, w)
    _w(PIO0_BASE + PIO_INSTR_MEM0 + 4 * cap_off, cap_word)
    # 4. Per-SM configuration (SMs disabled).
    _w(_sm_reg(program_sm, SM0_CLKDIV), pr["clkdiv"])
    _w(_sm_reg(program_sm, SM0_EXECCTRL), pr["execctrl"])
    _w(_sm_reg(program_sm, SM0_SHIFTCTRL), pr["shiftctrl"])
    _w(_sm_reg(program_sm, SM0_PINCTRL), pr["pinctrl"])
    _w(_sm_reg(capture_sm, SM0_CLKDIV), cap_clkdiv)
    _w(_sm_reg(capture_sm, SM0_EXECCTRL), cap_execctrl)
    _w(_sm_reg(capture_sm, SM0_SHIFTCTRL), cap_shiftctrl)
    _w(_sm_reg(capture_sm, SM0_PINCTRL), cap_pinctrl)
    # 5. Empty both SMs' FIFOs, so a repeated run never DMAs words from an earlier run.
    _flush_fifos(program_sm, pr["shiftctrl"])
    _flush_fifos(capture_sm, cap_shiftctrl)
    # 6. Pads: PIO function, ISO and OD cleared; input enable on the sampled pins and on the
    # pins the program reads through jmp_pin and in_base (the rest of an `in` range is not
    # enabled; see README).
    for p in sorted(pin_set | (set(cap_pins) - host_set)):
        _set_pio_function(p)
    for p in sorted(set(cap_pins) | {pins["jmp_pin"] & 31, pins["in_base"] & 31}):
        _enable_input(p)
    # Host-driven pins: SIO function, output enabled, level set before the run. Input enable
    # is already set above, so the PIO input path sees them.
    for p, v in host_pins:
        _w(IO_BANK0_BASE + 4 + 8 * p, (_r(IO_BANK0_BASE + 4 + 8 * p) & ~0x1F) | FUNCSEL_SIO)
        _w(SIO_BASE + (SIO_GPIO_OUT_SET if v else SIO_GPIO_OUT_CLR), 1 << p)
        _w(SIO_BASE + SIO_GPIO_OE_SET, 1 << p)
    # 7. Initial pin directions and levels, through SMn_INSTR `set` (SMs disabled).
    _set_pins_or_dirs(program_sm, init_dirs, SET_DEST_PINDIRS)
    _set_pins_or_dirs(program_sm, init_levels, SET_DEST_PINS)
    _w(_sm_reg(program_sm, SM0_PINCTRL), pr["pinctrl"])   # undo the temporary PINCTRL
    # 8. TX FIFO preload (CPU writes, before enable).
    for w in tx_words:
        _w(PIO0_BASE + PIO_TXF0 + 4 * program_sm, w)
    # 9. Program counters: `jmp <addr>` written to SMn_INSTR (JMP = 000 00000 000 addr).
    _exec_on_sm(program_sm, pr["entry"] & 0x1F)
    _exec_on_sm(capture_sm, cap_off & 0x1F)

    # 10. DMA: RX FIFO of the capture SM to buf, one 32-bit word per request. Armed before
    # the SMs start, after the FIFO flush, so the first word is from this run.
    # DREQ for the RX FIFO of SM n is DREQ_PIO0_RX0 + n (dreq.h: RX0 = 4, RX1 = 5).
    treq = DREQ_PIO0_RX0 + capture_sm
    dma = rp2.DMA()
    fdebug = 0
    host_log = []                          # (after_us, action) as it was done
    rx_reads = []                          # words read from the program SM's RX FIFO
    try:
        ctrl_dma = dma.pack_ctrl(size=2, inc_read=False, inc_write=True, treq_sel=treq,
                                 irq_quiet=True, enable=True)   # [verify on hardware: MicroPython API]
        dma.config(read=PIO0_BASE + PIO_RXF0 + 4 * capture_sm,
                   write=uctypes.addressof(buf), count=n_words, ctrl=ctrl_dma)
        dma.active(1)

        # 11. Restart both SMs and their clock dividers, still disabled. SM_RESTART and
        # CLKDIV_RESTART are self-clearing. This is after all configuration and the jmp.
        restart = (1 << (CTRL_SM_RESTART_LSB + program_sm)) \
            | (1 << (CTRL_SM_RESTART_LSB + capture_sm)) \
            | (1 << (CTRL_CLKDIV_RESTART_LSB + program_sm)) \
            | (1 << (CTRL_CLKDIV_RESTART_LSB + capture_sm))
        _w(ctrl_addr, (_r(ctrl_addr) & ~en_mask) | restart)
        ctrl_before = _r(ctrl_addr) & ~en_mask          # SM_ENABLE bits are still 0 here
        ctrl_after = ctrl_before | en_mask

        # 12. The single enable write starts both SMs on the same sysclk edge.
        t0 = time.ticks_us()
        _w(ctrl_addr, ctrl_after)

        deadline = time.ticks_add(t0, dma_timeout_ms * 1000)
        pending = list(host_actions)
        while True:
            now_rel = time.ticks_diff(time.ticks_us(), t0)
            while pending and pending[0][0] <= now_rel:
                _do_host_action(pending.pop(0)[1], program_sm, host_log, rx_reads)
            if not dma.active():
                break
            if time.ticks_diff(deadline, time.ticks_us()) < 0:
                raise RuntimeError("DMA did not finish: RX FIFO drain too slow or wiring/config error")
        if pending:
            raise RuntimeError("capture ended before host action at %s us; raise samples"
                               % pending[0][0])

        # Stop both SMs with one write, then read the sticky stall flags.
        _stop_both(ctrl_addr, en_mask)
        fdebug = _r(PIO0_BASE + PIO_FDEBUG)
    finally:
        # Leave the board in a known state on every path, including the timeout.
        _stop_both(ctrl_addr, en_mask)
        dma.active(0)
        dma.close()                                    # releases the DMA channel

    rxstall_capture = bool((fdebug >> capture_sm) & 1)
    _w(PIO0_BASE + PIO_FDEBUG, fdebug & FDEBUG_CLEAR_ALL)   # write-1-to-clear what we read

    header = {
        "record": "header",
        "format": "polyglot-pio-silicon-trace",
        "version": 1,
        "device": "Raspberry Pi Pico 2 (RP2350)",
        "sysclk_hz": sysclk_hz,
        "pio": {"block": 0, "base": "0x%08x" % PIO0_BASE},
        "program": {
            "name": prog["name"],
            "source": program_json,
            "pio_version": prog.get("pioVersion", 0),
            "offset": 0,
            "entry": pr["entry"],
            "words": ["0x%04x" % w for w in words],
            "registers": {"clkdiv": "0x%08x" % pr["clkdiv"], "execctrl": "0x%08x" % pr["execctrl"],
                          "shiftctrl": "0x%08x" % pr["shiftctrl"], "pinctrl": "0x%08x" % pr["pinctrl"]},
            "pins": pins,
            "config": {
                "clkdiv": "%d.%d" % (pr["clkdiv_int"], pr["clkdiv_frac"]),
                "fifo_join": pr["fifo"],
                "set_count": pr["set_count"],
                "sideset_size": pr["ss_size"],          # JSON size: includes the enable bit
                "sideset_data_pins": pr["ss_data"],
                "sideset_optional": pr["ss_optional"],
                "sideset_pindirs": pr["ss_pindirs"],
                "in_shift_right": pr["in_right"],
                "out_shift_right": pr["out_right"],
                "autopush": pr["autopush"],
                "autopull": pr["autopull"],
                "push_thresh": pr["push_thresh"],
                "pull_thresh": pr["pull_thresh"],
            },
            "init": {
                "levels": {str(k): v for k, v in sorted(init_levels.items())},
                "dirs": {str(k): v for k, v in sorted(init_dirs.items())},
                "tx_words": ["0x%08x" % w for w in tx_words],
            },
        },
        "capture": {
            "sm": capture_sm,
            "offset": cap_off,
            "word": "0x%04x" % cap_word,
            "pins_base": capture_base,
            "pins_count": 8,
            "bits_per_sample": 8,
            "samples_per_word": 4,
            "clkdiv": "1.0",
            "fifo_read_addr": "0x%08x" % (PIO0_BASE + PIO_RXF0 + 4 * capture_sm),
            "dreq": treq,
        },
        "start": {
            "method": "one write to PIO0 CTRL (SM_ENABLE bits for both SMs)",
            "ctrl_before": "0x%08x" % ctrl_before,
            "ctrl_after": "0x%08x" % ctrl_after,
            "sample0_cycle": 0,
            "program_to_capture_offset_cycles": 0,
            "note": "Same write starts both SMs. Sample k is the capture SM's read on sysclk "
                    "cycle k after the start write. Input synchroniser latency is not "
                    "subtracted here; calibrate it (README). [verify on hardware]",
        },
    }
    # Optional fields. They appear only when the option is used, so the format fixture
    # (testdata/uart_tx_example.jsonl) keeps its bytes.
    if out_sticky:
        header["program"]["config"]["out_sticky"] = True
    if host_pins:
        header["host"] = {"pins": [[p, v] for p, v in host_pins]}
    if host_actions:
        header.setdefault("host", {})["actions"] = [[a[0]] + list(a[1]) for a in host_actions]
        header["host"]["log"] = host_log
        header["host"]["rx_words"] = ["0x%08x" % w for w in rx_reads]
    with open(out_path, "w") as f:
        f.write(json.dumps(header) + "\n")
        chunk = 256
        for first in range(0, n_words, chunk):
            ws = []
            for i in range(first, min(first + chunk, n_words)):
                w = buf[4 * i] | (buf[4 * i + 1] << 8) | (buf[4 * i + 2] << 16) | (buf[4 * i + 3] << 24)
                ws.append("0x%08x" % w)
            f.write(json.dumps({"record": "words", "first_word": first, "words": ws}) + "\n")
        f.write(json.dumps({"record": "footer", "words_total": n_words, "samples_total": samples,
                            "fdebug": "0x%08x" % fdebug, "rxstall_capture": rxstall_capture,
                            "complete": True}) + "\n")
    return out_path
