# silicon-ref/capture.py
#
# MicroPython capture script for a Raspberry Pi Pico 2 (RP2350). It runs one PIO
# state machine (the program under test) and a second state machine on the same PIO
# block that samples a group of pins on every system clock (a logic analyser).
#
# STATUS: UNTESTED ON HARDWARE. Written from the RP2350 register map (checked against
# pico-sdk 2.3.1, src/rp2350/hardware_regs) and the MicroPython rp2 port. Nothing here
# has run on a board yet. Every register address and API call that is not verified on
# the board is marked [verify on hardware].
#
# Usage (on the board, with the pioasm JSON copied to flash):
#   import capture
#   capture.run(
#       program_json="/prog.json",           # pioasm -o json output
#       program_name=None,                   # None = first program in the file
#       pins=dict(out_base=0, out_count=1, set_base=0, set_count=1,
#                 sideset_base=0, in_base=0, jmp_pin=0),
#       capture_base=0,                      # first pin sampled by the capture SM
#       samples=40000,                       # multiple of 4 (samples per 32-bit word)
#       out_path="/trace.jsonl",
#   )
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
# hardware/regs/{addressmap.h, pio.h, io_bank0.h, pads_bank0.h, dreq.h}.
# ---------------------------------------------------------------------------
PIO0_BASE = 0x50200000            # addressmap.h PIO0_BASE [verify on hardware]
PIO_CTRL = 0x000                  # pio.h PIO_CTRL_OFFSET; SM_ENABLE [3:0], SM_RESTART [7:4], CLKDIV_RESTART [11:8]
PIO_FDEBUG = 0x008                # RXSTALL [3:0], write-1-to-clear
PIO_RXF0 = 0x020                  # RXF0..RXF3 are the RX FIFOs of SM0..SM3 (RXF1 = 0x024)
PIO_INSTR_MEM0 = 0x048            # instruction memory, 32 words at +4*n
SM0_CLKDIV = 0x0C8                # SMn registers at SM0_* + 0x18*n (SM1_CLKDIV = 0x0E0)
SM_STRIDE = 0x18
SM0_EXECCTRL = 0x0CC
SM0_SHIFTCTRL = 0x0D0
SM0_INSTR = 0x0D8                 # writing here executes the instruction immediately
SM0_PINCTRL = 0x0DC
CTRL_SM_RESTART_LSB = 4
CTRL_CLKDIV_RESTART_LSB = 8

IO_BANK0_BASE = 0x40028000        # addressmap.h IO_BANK0_BASE; GPIOn_CTRL at +4 + 8n, FUNCSEL [4:0]
PADS_BANK0_BASE = 0x40038000      # addressmap.h PADS_BANK0_BASE; GPIOn pad at +4 + 4n, IE = bit 6
PAD_IE_BIT = 1 << 6
FUNCSEL_PIO0 = 6                  # io_bank0.h GPIO_FUNC_PIO0 = 6 (PIO2 = 8 on RP2350)
DREQ_PIO0_RX0 = 4                 # dreq.h DREQ_PIO0_RX0 = 4; RX1 = 5 (TX0 = 0)

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


def _program_regs(p, pins, offset, sm_entry):
    """Compute SM register values for the program under test.

    Field positions: pio.h SM0_EXECCTRL, SM0_SHIFTCTRL, SM0_PINCTRL, SM0_CLKDIV.
    SIDESET_COUNT includes the enable bit when side-set is optional, as pio.h
    documents for PINCTRL and as pioasm's c-sdk output does (sideset_bits_including_opt).
    """
    if p.get("origin", -1) not in (-1, 0):
        raise NotImplementedError("program origin must be 0 or unset (no relocation here)")
    if p.get("movStatus") is not None:
        raise NotImplementedError("movStatus (STATUS_SEL) not handled yet")
    fifo = p.get("fifoConfig")
    if fifo not in (None, "PIO_FIFO_JOIN_TX", "PIO_FIFO_JOIN_RX"):
        raise NotImplementedError("fifoConfig %r is PIO v1 or unhandled" % fifo)

    ss = p.get("sideset") or {"size": 0, "optional": False, "pindirs": False}
    ss_count = ss["size"] + (1 if ss["optional"] else 0)
    if ss_count > 5:
        raise ValueError("side-set too wide")

    inn = p.get("in") or {}
    outp = p.get("out") or {}
    in_right = inn.get("right", True)          # PIO reset: shift right
    out_right = outp.get("right", True)
    autopush = inn.get("autopush", False)
    autopull = outp.get("autopull", False)
    in_thr = inn.get("threshold", 32) & 0x1F   # 0 encodes 32
    out_thr = outp.get("threshold", 32) & 0x1F

    wrap_top = offset + p["wrap"]
    wrap_bottom = offset + p["wrapTarget"]
    execctrl = ((1 if ss["optional"] else 0) << 30) | ((1 if ss["pindirs"] else 0) << 29) \
        | ((pins["jmp_pin"] & 0x1F) << 24) | ((wrap_top & 0x1F) << 12) | ((wrap_bottom & 0x1F) << 7)
    shiftctrl = ((1 if fifo == "PIO_FIFO_JOIN_RX" else 0) << 31) \
        | ((1 if fifo == "PIO_FIFO_JOIN_TX" else 0) << 30) \
        | (out_thr << 25) | (in_thr << 20) \
        | ((1 if out_right else 0) << 19) | ((1 if in_right else 0) << 18) \
        | ((1 if autopull else 0) << 17) | ((1 if autopush else 0) << 16)
    set_count = p["setCount"] if p.get("setCount") is not None else 5
    out_count = pins["out_count"]
    pinctrl = (ss_count << 29) | ((set_count & 7) << 26) | ((out_count & 0x3F) << 20) \
        | ((pins["in_base"] & 0x1F) << 15) | ((pins["sideset_base"] & 0x1F) << 10) \
        | ((pins["set_base"] & 0x1F) << 5) | (pins["out_base"] & 0x1F)
    cd = p.get("clockDiv") or {"int": 1, "frac": 0}
    clkdiv = ((cd["int"] & 0xFFFF) << 16) | ((cd["frac"] & 0xFF) << 8)
    return dict(clkdiv=clkdiv, execctrl=execctrl, shiftctrl=shiftctrl, pinctrl=pinctrl,
                entry=offset + sm_entry, pin_span=(pins["out_base"], out_count),
                set_span=(pins["set_base"], set_count),
                side_span=(pins["sideset_base"], ss["size"]))


def _set_pio_function(pin):
    ctrl_addr = IO_BANK0_BASE + 4 + 8 * pin
    v = _r(ctrl_addr)
    _w(ctrl_addr, (v & ~0x1F) | FUNCSEL_PIO0)


def _enable_input(pin):
    pad_addr = PADS_BANK0_BASE + 4 + 4 * pin
    _w(pad_addr, (_r(pad_addr) | PAD_IE_BIT) & ~0x80)   # IE on, OD off [verify on hardware]


def run(program_json, program_name, pins, capture_base, samples, out_path,
        capture_sm=1, program_sm=0, sysclk_hz=None, dma_timeout_ms=5000):
    """Load the program under test on program_sm and the capture program on capture_sm,
    capture `samples` pin samples (8 pins), and write a trace file to out_path.
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
    entry_rel = 0
    if "entry_point" in prog.get("publicLabels", {}):
        entry_rel = prog["publicLabels"]["entry_point"]

    pr = _program_regs(prog, pins, 0, entry_rel)
    pin_set = set()
    for base, n in (pr["pin_span"], pr["set_span"], pr["side_span"]):
        for p in range(base, base + n):
            pin_set.add(p & 31)
    cap_pins = [(capture_base + j) & 31 for j in range(8)]

    en_mask = (1 << program_sm) | (1 << capture_sm)
    if sysclk_hz is None:
        sysclk_hz = machine.freq()

    # Stop both SMs and restart them so PC, shift registers and clock dividers are clean.
    _w(PIO0_BASE + PIO_CTRL, _r(PIO0_BASE + PIO_CTRL) & ~en_mask)
    _w(PIO0_BASE + PIO_CTRL, (1 << (CTRL_SM_RESTART_LSB + program_sm))
       | (1 << (CTRL_SM_RESTART_LSB + capture_sm))
       | (1 << (CTRL_CLKDIV_RESTART_LSB + program_sm))
       | (1 << (CTRL_CLKDIV_RESTART_LSB + capture_sm)))
    _w(PIO0_BASE + PIO_FDEBUG, 0xF)      # clear sticky stall flags (write 1 to clear)

    # Instruction memory: program at 0, capture instruction after it.
    for i, w in enumerate(words):
        _w(PIO0_BASE + PIO_INSTR_MEM0 + 4 * i, w)
    _w(PIO0_BASE + PIO_INSTR_MEM0 + 4 * cap_off, cap_word)

    # Program under test on program_sm.
    _w(_sm_reg(program_sm, SM0_CLKDIV), pr["clkdiv"])
    _w(_sm_reg(program_sm, SM0_EXECCTRL), pr["execctrl"])
    _w(_sm_reg(program_sm, SM0_SHIFTCTRL), pr["shiftctrl"])
    _w(_sm_reg(program_sm, SM0_PINCTRL), pr["pinctrl"])

    # Capture SM: clkdiv 1.0 so it samples every sysclk; IN_BASE = first captured pin;
    # wrap onto itself so one `in pins, 8` runs every cycle; autopush at 32 bits.
    cap_execctrl = ((cap_off & 0x1F) << 12) | ((cap_off & 0x1F) << 7)
    cap_shiftctrl = (1 << 19) | (1 << 18) | (1 << 16)     # out right (reset), in right, autopush, thresh 32
    cap_pinctrl = ((capture_base & 0x1F) << 15)
    _w(_sm_reg(capture_sm, SM0_CLKDIV), 1 << 16)           # INT 1, FRAC 0
    _w(_sm_reg(capture_sm, SM0_EXECCTRL), cap_execctrl)
    _w(_sm_reg(capture_sm, SM0_SHIFTCTRL), cap_shiftctrl)
    _w(_sm_reg(capture_sm, SM0_PINCTRL), cap_pinctrl)

    # Set each SM's PC by writing `jmp <addr>` to SMn_INSTR (JMP always = 000 00000 000 addr).
    _w(_sm_reg(program_sm, SM0_INSTR), pr["entry"] & 0x1F)
    _w(_sm_reg(capture_sm, SM0_INSTR), cap_off & 0x1F)

    # GPIO: PIO0 function on every pin the program drives and on the captured pins;
    # input enable on the captured pins.
    for p in sorted(pin_set | set(cap_pins)):
        _set_pio_function(p)
    for p in cap_pins:
        _enable_input(p)

    # DMA: RX FIFO of the capture SM to buf, one 32-bit word per request. Armed before
    # the SMs start, so the FIFO never fills before the first read.
    # DREQ for the RX FIFO of SM n is DREQ_PIO0_RX0 + n (dreq.h: RX0 = 4, RX1 = 5).
    treq = DREQ_PIO0_RX0 + capture_sm
    dma = rp2.DMA()
    ctrl_dma = dma.pack_ctrl(size=2, inc_read=False, inc_write=True, treq_sel=treq,
                             irq_quiet=True, enable=True)   # [verify on hardware: MicroPython API]
    dma.config(read=PIO0_BASE + PIO_RXF0 + 4 * capture_sm,
               write=uctypes.addressof(buf), count=n_words, ctrl=ctrl_dma)
    dma.active(1)

    # Start both SMs with one CTRL write. Both start on the same sysclk edge.
    ctrl_before = _r(PIO0_BASE + PIO_CTRL)
    ctrl_after = ctrl_before | en_mask
    t0 = time.ticks_us()
    _w(PIO0_BASE + PIO_CTRL, ctrl_after)

    deadline = time.ticks_add(t0, dma_timeout_ms * 1000)
    while dma.active():
        if time.ticks_diff(deadline, time.ticks_us()) < 0:
            # Stop both SMs before failing so the board is left in a known state.
            _w(PIO0_BASE + PIO_CTRL, _r(PIO0_BASE + PIO_CTRL) & ~en_mask)
            raise RuntimeError("DMA did not finish: RX FIFO drain too slow or wiring/config error")

    # Stop both SMs with one write, then read the stall flags.
    _w(PIO0_BASE + PIO_CTRL, _r(PIO0_BASE + PIO_CTRL) & ~en_mask)
    fdebug = _r(PIO0_BASE + PIO_FDEBUG)
    rxstall_capture = bool((fdebug >> capture_sm) & 1)
    _w(PIO0_BASE + PIO_FDEBUG, fdebug & 0xF)              # write-1-to-clear

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
