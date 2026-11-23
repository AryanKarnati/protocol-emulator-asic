"""Polyglot host library: drives the chip over the host link (docs/chip.md section 6).

Runs on MicroPython for the RP2350 (the demo board) and on CPython for tests. Nothing here
needs typing, dataclasses or any package outside the standard library of each interpreter.

Layers, bottom up:

- Frame functions (frame_write, frame_read, frame_parse_read, frame_status): byte-exact
  chip.md section 6.3 frames. No I/O.
- Transports: anything with xfer(bytes) -> bytes. PioSpiTransport drives the link with a
  PIO SPI master on the RP2350 (MicroPython only), through xfer_on_sm(). SimTransport speaks
  chip.md section 12 to `pgsim chip-serve` (CPython only).
- Program sources: pgasm JSON, pgasm -o python modules, and rp2.asm_pio program objects,
  all turned into a Program with program(), programs_from_json(), programs_from_python()
  or program_from_rp2().
- Chip: registers, IMEM loading with relocation, and the StateMachine objects from sm(n).
  check() re-reads ID and SCRATCH and replays the configuration after a deselection.
"""

CHIP_HZ = 60000000
SYSCLK_HZ = 120000000
ID_VALUE = 0x504C4754
PAGE_WORDS = 32
IMEM_WORDS = 64
NUM_SMS = 4
FIFO_DEPTH = 4

REG_ID = 0x000
REG_HWCFG = 0x004
REG_CTRL = 0x008
REG_FSTAT = 0x00C
REG_FDEBUG = 0x010
REG_FLEVEL = 0x014
REG_IRQ = 0x018
REG_IRQ_FORCE = 0x01C
REG_HOSTIRQ_EN = 0x020
REG_PAD_OD = 0x024
REG_INPUT_SYNC_BYPASS = 0x028
REG_PAD_IN = 0x02C
REG_PAD_OUT = 0x030
REG_PAD_OE = 0x034
REG_SCRATCH = 0x038
REG_TXF = 0x040
REG_RXF = 0x050
REG_DBG_CTRL = 0x060
REG_IMEM = 0x100
REG_SM = 0x200
SM_STRIDE = 0x40

SM_CLKDIV = 0x00
SM_EXECCTRL = 0x04
SM_SHIFTCTRL = 0x08
SM_ADDR = 0x0C
SM_INSTR = 0x10
SM_PINCTRL = 0x14
SM_EXT = 0x18
SM_DBG_X = 0x2C
SM_DBG_Y = 0x30
SM_DBG_ISR = 0x34
SM_DBG_OSR = 0x38
SM_DBG_CNT = 0x3C

# The read-write registers that config replay restores (chip.md 8.1). SCRATCH is handled
# separately (reload writes its nonce).
RW_SHADOW = (REG_HOSTIRQ_EN, REG_PAD_OD, REG_INPUT_SYNC_BYPASS)
SM_RW_SHADOW = (SM_CLKDIV, SM_EXECCTRL, SM_SHIFTCTRL, SM_PINCTRL, SM_EXT)

# Field layouts, RP2040 PIO layout (chip.md section 8.1, and the same on RP2350 for these
# fields). name: (lsb, width). The STATUS fields are the RP2040 ones: a single select bit
# (0 TX level, 1 RX level) and a 4-bit N (RP2040 regs/pio.h: STATUS_SEL at bit 4, STATUS_N [3:0]).
CLKDIV_INT = (16, 16)
CLKDIV_FRAC = (8, 8)
EXECCTRL_SIDE_EN = (30, 1)
EXECCTRL_SIDE_PINDIR = (29, 1)
EXECCTRL_JMP_PIN = (24, 5)
EXECCTRL_OUT_EN_SEL = (19, 5)
EXECCTRL_INLINE_OUT_EN = (18, 1)
EXECCTRL_OUT_STICKY = (17, 1)
EXECCTRL_WRAP_TOP = (12, 5)
EXECCTRL_WRAP_BOTTOM = (7, 5)
EXECCTRL_STATUS_SEL = (4, 1)
EXECCTRL_STATUS_N = (0, 4)
SHIFTCTRL_FJOIN_RX = (31, 1)
SHIFTCTRL_FJOIN_TX = (30, 1)
SHIFTCTRL_PULL_THRESH = (25, 5)
SHIFTCTRL_PUSH_THRESH = (20, 5)
SHIFTCTRL_OUT_SHIFTDIR = (19, 1)
SHIFTCTRL_IN_SHIFTDIR = (18, 1)
SHIFTCTRL_AUTOPULL = (17, 1)
SHIFTCTRL_AUTOPUSH = (16, 1)
PINCTRL_SIDESET_COUNT = (29, 3)
PINCTRL_SET_COUNT = (26, 3)
PINCTRL_OUT_COUNT = (20, 6)
PINCTRL_IN_BASE = (15, 5)
PINCTRL_SIDESET_BASE = (10, 5)
PINCTRL_SET_BASE = (5, 5)
PINCTRL_OUT_BASE = (0, 5)

# FDEBUG sticky flags of one SM (RP2040 layout): RXSTALL at bit n, RXUNDER at 8+n,
# TXOVER at 16+n, TXSTALL at 24+n. pio_sm_init clears these (pio.c, pio_sm_init).
FDEBUG_SM_FLAGS = (1 << 0) | (1 << 8) | (1 << 16) | (1 << 24)

# Instruction encodings used by the library.
SET_PINS = 0xE000
SET_PINDIRS = 0xE080
JMP_ALWAYS = 0x0000

# @rp2.asm_pio and PIO constants (values from MicroPython's rp2_pio.c).
PIO_SHIFT_LEFT = 0
PIO_SHIFT_RIGHT = 1
PIO_JOIN_NONE = 0
PIO_JOIN_TX = 1
PIO_JOIN_RX = 2


class ChipError(Exception):
    pass


def _field_mask(field):
    return ((1 << field[1]) - 1) << field[0]


def field_set(value, field, x):
    """Return value with the field replaced by x. x must fit the field."""
    lsb, width = field
    if x < 0 or x >= (1 << width):
        raise ValueError("field value %d does not fit in %d bits" % (x, width))
    return (value & ~_field_mask(field)) | (x << lsb)


def field_get(value, field):
    lsb, width = field
    return (value >> lsb) & ((1 << width) - 1)


def _set_like_rp2(value, field, arg):
    """rp2_pio.c asm_pio_override_shiftctrl: (arg << lsb) & bits, with the field cleared first."""
    mask = _field_mask(field)
    return (value & ~mask) | ((arg << field[0]) & mask)


def clkdiv_word(div_int, div_frac=0):
    """CLKDIV for an integer and 8-bit fraction, pico-sdk sm_config_set_clkdiv_int_frac8.

    div_int 65536 is written as 0, the divisor the hardware reads as 65536 (pio.c line 1108 note).
    """
    if div_int < 0 or div_int > 0x10000:
        raise ValueError("clkdiv integer part out of range")
    if div_frac < 0 or div_frac > 0xFF:
        raise ValueError("clkdiv fraction out of range")
    if div_int == 0 and div_frac != 0:
        raise ValueError("clkdiv 0 with a fraction is not allowed")
    return ((div_int & 0xFFFF) << 16) | (div_frac << 8)


def _u32(w):
    if w < 0 or w > 0xFFFFFFFF:
        raise ValueError("word %d does not fit in 32 bits" % w)
    return w.to_bytes(4, "big")


def _check_addr(addr):
    if addr < 0 or addr > 0xFFFC or (addr & 3):
        raise ValueError("address 0x%x must be word aligned and below 0x10000" % addr)


# ---------------------------------------------------------------------------
# Frame layer (chip.md section 6.3). These are pure functions: no I/O.
# ---------------------------------------------------------------------------

CMD_READ = 0x80
CMD_FIXED = 0x40


def frame_write(addr, words, fixed=False):
    """Bytes of a write frame: command, ADDR, then each word MSB first."""
    _check_addr(addr)
    out = bytearray()
    out.append(CMD_FIXED if fixed else 0)
    out.append((addr >> 8) & 0xFF)
    out.append(addr & 0xFF)
    for w in words:
        out += _u32(w)
    return bytes(out)


def frame_read(addr, n, fixed=False):
    """Bytes of a read frame: command, ADDR, the dummy byte, then 4n bytes that clock data out."""
    _check_addr(addr)
    if n < 1:
        raise ValueError("read needs at least one word")
    out = bytearray(4 + 4 * n)
    out[0] = CMD_READ | (CMD_FIXED if fixed else 0)
    out[1] = (addr >> 8) & 0xFF
    out[2] = addr & 0xFF
    return bytes(out)


def frame_parse_read(reply, n):
    """The n words of a read frame, from the MISO bytes of its reply (dummy byte skipped)."""
    if len(reply) != 4 + 4 * n:
        raise ValueError("read reply has %d bytes, expected %d" % (len(reply), 4 + 4 * n))
    words = []
    for m in range(n):
        o = 4 + 4 * m
        words.append((reply[o] << 24) | (reply[o + 1] << 16) | (reply[o + 2] << 8) | reply[o + 3])
    return words


def frame_status():
    """A one-byte frame. Its MISO byte is STATUS (chip.md section 9.3)."""
    return bytes([0])


def status_fields(status):
    """Decode the STATUS byte: RXNEMPTY[3:0] in bits 3:0, TXNFULL[3:0] in bits 7:4."""
    return {
        "rx_nonempty": [(status >> i) & 1 for i in range(4)],
        "tx_nonfull": [(status >> (4 + i)) & 1 for i in range(4)],
    }


# ---------------------------------------------------------------------------
# Program objects
# ---------------------------------------------------------------------------


class Program(object):
    """A PIO program, as the chip loads it. Words are relative to instruction 0.

    wrap_target and wrap are relative. side_count is the SIDESET_COUNT field and includes the
    enable bit when side_opt is set (pgsim README, configuration precedence). shiftctrl holds
    the SHIFTCTRL bits of the program: shift directions, autopush/autopull, thresholds and the
    FIFO join. status_sel and status_n are the EXECCTRL MOV STATUS fields (RP2040 layout).
    clkdiv is (int, frac) or None; it is the program's own divider, used when init() gets no
    freq or clkdiv. The three *_init lists use the rp2 encoding: value = (direction << 1) | level,
    one entry per pin from the base.
    """

    def __init__(
        self,
        words,
        name="",
        wrap_target=0,
        wrap=None,
        side_count=0,
        side_opt=False,
        side_pindir=False,
        shiftctrl=0x000C0000,
        origin=-1,
        out_init=None,
        set_init=None,
        sideset_init=None,
        status_sel=0,
        status_n=0,
        clkdiv=None,
    ):
        if not words:
            raise ValueError("a program needs at least one instruction")
        if len(words) > PAGE_WORDS:
            raise ValueError("a program has at most %d instructions" % PAGE_WORDS)
        self.words = [w & 0xFFFF for w in words]
        self.name = name
        if wrap is None:
            wrap = len(self.words) - 1
        if wrap < 0 or wrap >= len(self.words) or wrap_target < 0 or wrap_target >= len(self.words):
            raise ValueError("wrap addresses outside the program")
        self.wrap_target = wrap_target
        self.wrap = wrap
        self.side_count = side_count
        self.side_opt = bool(side_opt)
        self.side_pindir = bool(side_pindir)
        self.shiftctrl = shiftctrl
        self.origin = origin
        self.out_init = out_init
        self.set_init = set_init
        self.sideset_init = sideset_init
        self.status_sel = status_sel
        self.status_n = status_n
        self.clkdiv = clkdiv

    def __len__(self):
        return len(self.words)


def _rp2_pins(value_list):
    """rp2 init list (or a single int) to (pin count, dir mask, value mask)."""
    if value_list is None:
        return 0, 0, 0
    if isinstance(value_list, int):
        value_list = [value_list]
    dirs = 0
    vals = 0
    for i, v in enumerate(value_list):
        dirs |= ((v >> 1) & 1) << i
        vals |= (v & 1) << i
    return len(value_list), dirs, vals


def program_from_rp2(obj, name=""):
    """Convert a @rp2.asm_pio program object (the 9-field list MicroPython builds).

    Fields: [0] instruction array, [1..3] fixed offsets per PIO (-1 means any; set by an earlier
    load, so they are not a request for placement), [4] EXECCTRL, [5] SHIFTCTRL, [6] out init,
    [7] set init, [8] sideset init. The layouts are the RP2040 ones, which are ours. The wrap
    fields are relative. The side-set count is the length of the sideset init list, plus one
    enable bit when SIDE_EN is set, as rp2_pio.c computes it. SHIFTCTRL is taken whole, FIFO
    join included, as rp2_pio.c does (config.shiftctrl = prog[PROG_SHIFTCTRL], line 681).
    """
    if not isinstance(obj, list) or len(obj) != 9:
        raise ValueError("not an rp2.asm_pio program object")
    words = list(obj[0])
    execctrl = obj[4]
    side_opt = (execctrl >> 30) & 1
    side_pindir = (execctrl >> 29) & 1
    wrap_target = (execctrl >> 7) & 0x1F
    wrap = (execctrl >> 12) & 0x1F
    side_pins, _, _ = _rp2_pins(obj[8])
    side_count = side_pins + side_opt if side_pins else 0
    return Program(
        words,
        name=name,
        wrap_target=wrap_target,
        wrap=wrap,
        side_count=side_count,
        side_opt=side_opt,
        side_pindir=side_pindir,
        shiftctrl=obj[5],
        origin=-1,
        out_init=obj[6],
        set_init=obj[7],
        sideset_init=obj[8],
        status_sel=(execctrl >> 4) & 1,
        status_n=execctrl & 0xF,
    )


# pioasm's c-sdk default config (sw/pgasm/src/pio_out.ml) applies these from the program's own
# directives: sm_config_set_fifo_join, sm_config_set_mov_status and sm_config_set_clkdiv_int_frac.
_FIFO_JOIN_NAMES = {"PIO_FIFO_JOIN_TX": PIO_JOIN_TX, "PIO_FIFO_JOIN_RX": PIO_JOIN_RX}


def program_from_pgasm_json(prog):
    """One program object of pgasm -o json (pioasm's JSON), a dict from json.loads.

    Applies what <prog>_program_get_default_config() applies: the wrap, side-set, shift settings
    (.in/.out), fifoConfig (FIFO join), movStatus (MOV STATUS select and N) and clockDiv.
    STATUS_IRQ_SET and the PIO version 1 FIFO joins are RP2350-only and are rejected.
    """
    if prog.get("pioVersion", 0) != 0:
        raise ValueError("program %s is PIO version %s; the chip runs version 0" % (prog.get("name"), prog.get("pioVersion")))
    words = [int(i["hex"], 16) for i in prog["instructions"]]
    side = prog.get("sideset")
    side_count = side["size"] if side else 0
    side_opt = bool(side["optional"]) if side else False
    side_pindir = bool(side["pindirs"]) if side else False
    shiftctrl = 0x000C0000  # pio_get_default_sm_config: both shifts right, thresholds 32
    shift_in = prog.get("in")
    if shift_in:
        shiftctrl = _set_like_rp2(shiftctrl, SHIFTCTRL_IN_SHIFTDIR, 1 if shift_in["right"] else 0)
        shiftctrl = _set_like_rp2(shiftctrl, SHIFTCTRL_AUTOPUSH, 1 if shift_in["autopush"] else 0)
        shiftctrl = _set_like_rp2(shiftctrl, SHIFTCTRL_PUSH_THRESH, shift_in["threshold"] & 0x1F)
    shift_out = prog.get("out")
    if shift_out:
        shiftctrl = _set_like_rp2(shiftctrl, SHIFTCTRL_OUT_SHIFTDIR, 1 if shift_out["right"] else 0)
        shiftctrl = _set_like_rp2(shiftctrl, SHIFTCTRL_AUTOPULL, 1 if shift_out["autopull"] else 0)
        shiftctrl = _set_like_rp2(shiftctrl, SHIFTCTRL_PULL_THRESH, shift_out["threshold"] & 0x1F)
    fifo = prog.get("fifoConfig")
    if fifo:
        if fifo not in _FIFO_JOIN_NAMES:
            raise ValueError("fifoConfig %s is not a version 0 join" % fifo)
        join = _FIFO_JOIN_NAMES[fifo]
        shiftctrl = _set_like_rp2(shiftctrl, SHIFTCTRL_FJOIN_TX, 1 if join == PIO_JOIN_TX else 0)
        shiftctrl = _set_like_rp2(shiftctrl, SHIFTCTRL_FJOIN_RX, 1 if join == PIO_JOIN_RX else 0)
    status_sel = 0
    status_n = 0
    mov = prog.get("movStatus")
    if mov:
        kind = mov["type"]
        if kind == "STATUS_TX_LESSTHAN":
            status_sel = 0
        elif kind == "STATUS_RX_LESSTHAN":
            status_sel = 1
        else:
            raise ValueError("%s is RP2350-only; the chip has the RP2040 MOV STATUS" % kind)
        status_n = mov["n"]
    clk = prog.get("clockDiv")
    clkdiv = (clk["int"], clk["frac"]) if clk else None
    return Program(
        words,
        name=prog.get("name", ""),
        wrap_target=prog["wrapTarget"],
        wrap=prog["wrap"],
        side_count=side_count,
        side_opt=side_opt,
        side_pindir=side_pindir,
        shiftctrl=shiftctrl,
        origin=prog.get("origin", -1),
        status_sel=status_sel,
        status_n=status_n,
        clkdiv=clkdiv,
    )


def programs_from_json(source):
    """All programs of a pgasm -o json file: a JSON string or an already parsed dict."""
    import json

    data = json.loads(source) if isinstance(source, str) else source
    out = {}
    for p in data["programs"]:
        prog = program_from_pgasm_json(p)
        out[prog.name] = prog
    return out


def _rp2_programs_in(namespace):
    out = {}
    for key in namespace:
        val = namespace[key]
        if isinstance(val, list) and len(val) == 9 and not key.startswith("_"):
            out[key] = program_from_rp2(val, name=key)
    return out


def programs_from_python(source, name_hint="pgasm"):
    """All @rp2.asm_pio programs in a pgasm -o python module (source text).

    The module is executed with the device's own rp2 module (or the CPython stub that the
    tests install), so the programs come from the real assembler, not from a copy of it.
    """
    ns = {"__name__": name_hint}
    exec(source, ns)
    progs = _rp2_programs_in(ns)
    if not progs:
        raise ValueError("no @rp2.asm_pio program in the module")
    return progs


def program(source, name=None):
    """One program from any supported source.

    source: a Program, an rp2 program object (list), a pgasm JSON string or dict, or the text
    of a pgasm -o python module. With several programs in the source, name picks one.
    """
    if isinstance(source, Program):
        return source
    if isinstance(source, list):
        return program_from_rp2(source, name=name or "")
    if isinstance(source, dict):
        progs = programs_from_json(source)
    elif isinstance(source, str) and source.lstrip().startswith("{"):
        progs = programs_from_json(source)
    elif isinstance(source, str):
        progs = programs_from_python(source)
    else:
        raise ValueError("unsupported program source")
    if name is None:
        if len(progs) != 1:
            raise ValueError("source has %d programs; pass name=" % len(progs))
        return list(progs.values())[0]
    if name not in progs:
        raise ValueError("no program named %s" % name)
    return progs[name]


def relocate(words, offset):
    """pio_add_program's rule: every JMP (opcode 000) target gets the offset added.

    The chip has its own pins, so the RP2350 gpio_base XOR for wait gpio (pio.c, add_program_at_offset)
    is not applied.
    """
    out = []
    for w in words:
        if (w >> 13) == 0:
            out.append((w + offset) & 0xFFFF)
        else:
            out.append(w)
    return out


# ---------------------------------------------------------------------------
# Chip and state machines
# ---------------------------------------------------------------------------


class Loaded(object):
    """A program in IMEM: which page and offset it sits at, and its relocated words.

    source is the object the caller passed to load(), so a later init() with the same object
    finds this copy instead of loading it again. start is the IMEM index of the first instruction.
    """

    def __init__(self, prog, page, offset, words, source):
        self.program = prog
        self.page = page
        self.offset = offset
        self.words = words
        self.source = source
        self.start = page * PAGE_WORDS + offset


def _rand32():
    try:
        import urandom as rnd
    except ImportError:
        import random as rnd
    return rnd.getrandbits(32)


class Chip(object):
    """The chip behind a transport. transport.xfer(bytes) -> bytes is the only I/O.

    Every write of a read-write register is recorded, so reload() can put the configuration back
    after a deselection. Pulses (CTRL restart bits, IRQ clear, TX pushes, INSTR) are not recorded.
    """

    def __init__(self, transport):
        self._t = transport
        self._nonce = _rand32() | 1
        self._configured = False  # the nonce is in SCRATCH, so a later check() sees it
        self._shadow = {}  # RW register address -> last value written
        self._imem = {}  # IMEM index -> word, as written
        self._loaded = []
        self._used = [0, 0]
        self._sm_force = {}  # SM index -> replay items for forced instructions, in order
        self._sms = {}
        self._ctrl_enable = 0

    # -- frame layer -------------------------------------------------------

    def write(self, addr, words, fixed=False):
        self._t.xfer(frame_write(addr, words, fixed))
        for m in range(len(words)):
            a = addr if fixed else addr + 4 * m
            if a in RW_SHADOW or _is_sm_rw(a):
                self._shadow[a] = words[m] & 0xFFFFFFFF

    def read(self, addr, n=1, fixed=False):
        reply = self._t.xfer(frame_read(addr, n, fixed))
        return frame_parse_read(reply, n)

    def status(self):
        return self._t.xfer(frame_status())[0]

    # -- register helpers --------------------------------------------------

    def _reg_read(self, addr):
        return self.read(addr, 1)[0]

    def _reg_write(self, addr, value):
        self.write(addr, [value])

    def _ctrl_write(self, pulses=0):
        """Write CTRL: the enable bits, plus pulse bits (not kept)."""
        self.write(REG_CTRL, [self._ctrl_enable | pulses])

    def _ensure_configured(self):
        """Write the nonce on the first configuration, so check() can tell this design is present."""
        if not self._configured:
            self.write(REG_SCRATCH, [self._nonce])
            self._configured = True

    # -- chip API ----------------------------------------------------------

    def id(self):
        return self._reg_read(REG_ID)

    def hwcfg(self):
        v = self._reg_read(REG_HWCFG)
        return {
            "fifo_depth": v & 0x3F,
            "num_sms": (v >> 8) & 0xF,
            "imem_depth": (v >> 16) & 0x7F,
            "lcu": (v >> 24) & 1,
            "sram": (v >> 25) & 1,
            "version": (v >> 28) & 0xF,
            "raw": v,
        }

    def check(self):
        """Re-read ID and SCRATCH. If either is wrong, reload the design (DESIGN section 13).

        Returns True when the design was present, False when it was reloaded. A chip that
        has never been configured by this object is reloaded too, so check() returns False.
        """
        if self.id() != ID_VALUE or self._reg_read(REG_SCRATCH) != self._nonce:
            self.reload()
            return False
        return True

    def reload(self):
        """Write the nonce and replay the configuration this object has written."""
        self.write(REG_SCRATCH, [self._nonce])
        self._configured = True
        for addr in self._shadow:
            self.write(addr, [self._shadow[addr]])
        # IMEM goes out in bursts of consecutive indices.
        idx = sorted(self._imem)
        i = 0
        while i < len(idx):
            j = i
            while j + 1 < len(idx) and idx[j + 1] == idx[j] + 1:
                j += 1
            run = []
            for m in range(i, j + 1):
                run.append(self._imem[idx[m]])
            self.write(REG_IMEM + 4 * idx[i], run)
            i = j + 1
        for n in sorted(self._sm_force):
            for item in self._sm_force[n]:
                self._replay(n, item)
        self._ctrl_write()

    def halt(self):
        raise NotImplementedError("halt needs DBG_CTRL (chip.md section 2 puts it in block 4)")

    def step(self):
        raise NotImplementedError("step needs DBG_CTRL (chip.md section 2 puts it in block 4)")

    def fifo_levels(self, n):
        """(tx level, rx level) of SM n, from FLEVEL (RP2040 layout)."""
        v = self._reg_read(REG_FLEVEL)
        return ((v >> (8 * n)) & 0xF, (v >> (8 * n + 4)) & 0xF)

    def load(self, source, page=None, offset=None, name=None):
        """Place a program in IMEM and return a Loaded handle.

        The program goes in one 32-word page. page=None tries page 0, then page 1. offset=None
        takes the highest free run that fits, as pico-sdk's find_offset_for_program does (pio.c,
        lines 66-82). A program with an origin (fixed placement) uses that offset.
        """
        if isinstance(source, Loaded):
            return source
        prog = program(source, name=name)
        n = len(prog.words)
        if offset is None and prog.origin >= 0:
            offset = prog.origin
        pages = [page] if page is not None else [0, 1]
        last = None
        for pg in pages:
            if pg < 0 or pg * PAGE_WORDS >= IMEM_WORDS:
                raise ValueError("no such page")
            if pg == 1 and self._imem_depth() < 64:
                if page is None:
                    continue
                raise ValueError("this chip has one page")
            off = offset if offset is not None else self._find_offset(pg, n)
            if off is None:
                continue
            if off < 0 or off + n > PAGE_WORDS:
                raise ValueError("program does not fit at offset %d" % off)
            mask = ((1 << n) - 1) << off
            if self._used[pg] & mask:
                if page is not None:
                    raise ValueError("instruction memory in use at page %d offset %d" % (pg, off))
                last = off
                continue
            return self._place(prog, source, pg, off)
        if last is not None and offset is not None:
            raise ValueError("instruction memory in use at offset %d in either page" % offset)
        raise MemoryError("no room for %d instructions" % n)

    def _place(self, prog, source, page, offset):
        self._ensure_configured()
        n = len(prog.words)
        words = relocate(prog.words, offset)
        base = page * PAGE_WORDS + offset
        for i in range(n):
            self._imem[base + i] = words[i]
        self.write(REG_IMEM + 4 * base, words)
        self._used[page] |= ((1 << n) - 1) << offset
        handle = Loaded(prog, page, offset, words, source)
        self._loaded.append(handle)
        return handle

    def _imem_depth(self):
        return self.hwcfg()["imem_depth"]

    def _find_offset(self, page, n):
        """The highest offset where n instructions fit in the page, or None."""
        for off in range(PAGE_WORDS - n, -1, -1):
            if not (self._used[page] & (((1 << n) - 1) << off)):
                return off
        return None

    def _loaded_for(self, prog, page=None):
        if isinstance(prog, Loaded):
            return prog
        for h in self._loaded:
            if h.source is prog or h.program is prog:
                return h
        return self.load(prog, page=page)

    def sm(self, n):
        if n < 0 or n >= NUM_SMS:
            raise ValueError("SM index must be 0 to %d" % (NUM_SMS - 1))
        if n not in self._sms:
            self._sms[n] = StateMachine(self, n)
        return self._sms[n]

    # -- replay (the configuration reload() restores) -----------------------

    def _replay(self, n, item):
        kind = item[0]
        if kind == "jmp":
            self._reg_force(n, JMP_ALWAYS | item[1])
        elif kind == "pins":
            self._force_masked(n, SET_PINS, item[1], item[2])
        elif kind == "pindirs":
            self._force_masked(n, SET_PINDIRS, item[1], item[2])

    def _remember(self, n, item):
        self._sm_force.setdefault(n, []).append(item)

    def _reg_force(self, n, instr):
        self.write(REG_SM + SM_STRIDE * n + SM_INSTR, [instr & 0xFFFF])

    def _force_masked(self, n, dest_instr, values, mask):
        """pico-sdk pio_sm_set_pins_with_mask and pio_sm_set_pindirs_with_mask: one forced SET per pin."""
        base = REG_SM + SM_STRIDE * n
        pinctrl = self._shadow.get(base + SM_PINCTRL, 0)
        execctrl = self._shadow.get(base + SM_EXECCTRL, 0)
        self.write(base + SM_EXECCTRL, [execctrl & ~(1 << EXECCTRL_OUT_STICKY[0])])
        for pin in range(32):
            if (mask >> pin) & 1:
                self.write(base + SM_PINCTRL, [(1 << PINCTRL_SET_COUNT[0]) | (pin << PINCTRL_SET_BASE[0])])
                self._reg_force(n, dest_instr | ((values >> pin) & 1))
        self.write(base + SM_PINCTRL, [pinctrl])
        self.write(base + SM_EXECCTRL, [execctrl])


def _is_sm_rw(addr):
    if addr < REG_SM or addr >= REG_SM + SM_STRIDE * NUM_SMS:
        return False
    return ((addr - REG_SM) % SM_STRIDE) in SM_RW_SHADOW


class StateMachine(object):
    """One PIO state machine on the chip. The methods follow MicroPython's rp2.StateMachine."""

    def __init__(self, chip, n):
        self._c = chip
        self.n = n
        self._base = REG_SM + SM_STRIDE * n

    def _wr(self, off, value):
        self._c._reg_write(self._base + off, value)

    def _rd(self, off):
        return self._c._reg_read(self._base + off)

    def init(
        self,
        prog=None,
        freq=None,
        clkdiv=None,
        in_base=None,
        out_base=None,
        set_base=None,
        jmp_pin=None,
        sideset_base=None,
        in_shiftdir=None,
        out_shiftdir=None,
        push_thresh=None,
        pull_thresh=None,
        autopush=None,
        autopull=None,
        fifo_join=None,
        out_count=None,
        set_count=None,
        page=None,
    ):
        """Configure the SM for a program and pins, as rp2.StateMachine.init does.

        freq is in Hz, relative to the chip clock (60 MHz); see _divider. clkdiv is the divider as a
        float. Pins are chip pin numbers 0 to 31. Pin levels and directions from the program's
        init lists are applied with forced SET instructions, in pico-sdk's order. out_count and
        set_count default to the program's init list length, or 0 (see _count). Returns the
        Loaded handle. The SM is left disabled; active(1) starts it.
        """
        c = self._c
        h = c._loaded_for(prog, page)
        p = h.program
        n = self.n
        off = h.offset
        base = self._base
        c._ensure_configured()

        if freq is None and clkdiv is None and p.clkdiv is not None:
            div = clkdiv_word(p.clkdiv[0], p.clkdiv[1])
        else:
            div = _divider(freq, clkdiv)
        ex = (
            (1 << 30 if p.side_opt else 0)
            | (1 << 29 if p.side_pindir else 0)
            | ((p.wrap + off) << EXECCTRL_WRAP_TOP[0])
            | ((p.wrap_target + off) << EXECCTRL_WRAP_BOTTOM[0])
            | (p.status_sel << EXECCTRL_STATUS_SEL[0])
            | p.status_n
        )
        if jmp_pin is not None:
            ex = field_set(ex, EXECCTRL_JMP_PIN, jmp_pin & 31)
        sc = p.shiftctrl
        if in_shiftdir is not None:
            sc = _set_like_rp2(sc, SHIFTCTRL_IN_SHIFTDIR, in_shiftdir)
        if out_shiftdir is not None:
            sc = _set_like_rp2(sc, SHIFTCTRL_OUT_SHIFTDIR, out_shiftdir)
        if push_thresh is not None:
            sc = _set_like_rp2(sc, SHIFTCTRL_PUSH_THRESH, push_thresh)
        if pull_thresh is not None:
            sc = _set_like_rp2(sc, SHIFTCTRL_PULL_THRESH, pull_thresh)
        if autopush is not None:
            sc = field_set(sc, SHIFTCTRL_AUTOPUSH, 1 if autopush else 0)
        if autopull is not None:
            sc = field_set(sc, SHIFTCTRL_AUTOPULL, 1 if autopull else 0)
        if fifo_join is not None:
            if fifo_join not in (PIO_JOIN_NONE, PIO_JOIN_TX, PIO_JOIN_RX):
                raise ValueError("fifo_join must be JOIN_NONE, JOIN_TX or JOIN_RX")
            sc = field_set(sc & ~(3 << 30), SHIFTCTRL_FJOIN_TX, 1 if fifo_join == PIO_JOIN_TX else 0)
            sc = field_set(sc, SHIFTCTRL_FJOIN_RX, 1 if fifo_join == PIO_JOIN_RX else 0)

        out_n, out_dirs, out_vals = _rp2_pins(p.out_init)
        set_n, set_dirs, set_vals = _rp2_pins(p.set_init)
        side_pins, side_dirs, side_vals = _rp2_pins(p.sideset_init)
        pc = 0
        if p.side_count and sideset_base is not None:
            pc = field_set(pc, PINCTRL_SIDESET_COUNT, p.side_count)
            pc = field_set(pc, PINCTRL_SIDESET_BASE, sideset_base & 31)
        if out_base is not None:
            pc = field_set(pc, PINCTRL_OUT_BASE, out_base & 31)
            pc = field_set(pc, PINCTRL_OUT_COUNT, _count(out_count, out_n))
        if set_base is not None:
            pc = field_set(pc, PINCTRL_SET_BASE, set_base & 31)
            pc = field_set(pc, PINCTRL_SET_COUNT, _count(set_count, set_n))
        if in_base is not None:
            pc = field_set(pc, PINCTRL_IN_BASE, in_base & 31)

        # pico-sdk pio_sm_init: disable, set the config, clear the FIFOs (a FJOIN change flushes
        # them), restart, clkdiv restart, clear this SM's sticky FDEBUG flags, jump to the entry.
        join = field_get(sc, SHIFTCTRL_FJOIN_TX) | (field_get(sc, SHIFTCTRL_FJOIN_RX) << 1)
        c._ctrl_enable &= ~(1 << n)
        c._ctrl_write()
        c._reg_write(base + SM_SHIFTCTRL, (sc & ~(3 << 30)) | (0 if join else (1 << 30)))
        c._reg_write(base + SM_SHIFTCTRL, sc)
        c._ctrl_write(pulses=(1 << (4 + n)) | (1 << (8 + n)))
        c._reg_write(base + SM_CLKDIV, div)
        c._reg_write(base + SM_EXECCTRL, ex)
        c._reg_write(base + SM_PINCTRL, pc)
        c._reg_write(base + SM_EXT, h.page)
        c._reg_write(REG_FDEBUG, FDEBUG_SM_FLAGS << n)
        c._sm_force[n] = []
        c._reg_force(n, JMP_ALWAYS | off)
        c._remember(n, ("jmp", off))
        if out_base is not None and out_n:
            self._pins_init(out_base, out_n, out_vals, out_dirs)
        if set_base is not None and set_n:
            self._pins_init(set_base, set_n, set_vals, set_dirs)
        if sideset_base is not None and side_pins:
            self._pins_init(sideset_base, side_pins, side_vals, side_dirs)
        return h

    def _pins_init(self, base, count, vals, dirs):
        """Pin levels then directions for count pins from base, as pico-sdk does."""
        mask = ((1 << count) - 1) << base
        vals_at = vals << base
        dirs_at = dirs << base
        self._c._force_masked(self.n, SET_PINS, vals_at, mask)
        self._c._remember(self.n, ("pins", vals_at, mask))
        self._c._force_masked(self.n, SET_PINDIRS, dirs_at, mask)
        self._c._remember(self.n, ("pindirs", dirs_at, mask))

    def active(self, on=None):
        c = self._c
        if on is None:
            return bool((c._ctrl_enable >> self.n) & 1)
        if on:
            c._ctrl_enable |= 1 << self.n
        else:
            c._ctrl_enable &= ~(1 << self.n)
        c._ctrl_write()
        return None

    def restart(self):
        self._c._ctrl_write(pulses=1 << (4 + self.n))

    def exec(self, instr):
        self._c._reg_force(self.n, instr)

    def put(self, value):
        self._c.write(REG_TXF + 4 * self.n, [value])

    def get(self):
        """Pop one RX word. A read frame, so it does not block: an empty FIFO reads 0 and sets RXUNDER."""
        return self._c.read(REG_RXF + 4 * self.n, 1)[0]

    def rx_fifo(self):
        return self._c.fifo_levels(self.n)[1]

    def tx_fifo(self):
        return self._c.fifo_levels(self.n)[0]

    def regs(self):
        b = self._base
        return {
            "clkdiv": self._c._reg_read(b + SM_CLKDIV),
            "execctrl": self._c._reg_read(b + SM_EXECCTRL),
            "shiftctrl": self._c._reg_read(b + SM_SHIFTCTRL),
            "addr": self._c._reg_read(b + SM_ADDR),
            "pinctrl": self._c._reg_read(b + SM_PINCTRL),
            "ext": self._c._reg_read(b + SM_EXT),
            "x": self._c._reg_read(b + SM_DBG_X),
            "y": self._c._reg_read(b + SM_DBG_Y),
            "isr": self._c._reg_read(b + SM_DBG_ISR),
            "osr": self._c._reg_read(b + SM_DBG_OSR),
            "cnt": self._c._reg_read(b + SM_DBG_CNT),
        }

    def halt(self):
        raise NotImplementedError("halt needs DBG_CTRL (chip.md section 2 puts it in block 4)")

    def step(self):
        raise NotImplementedError("step needs DBG_CTRL (chip.md section 2 puts it in block 4)")


def _count(requested, from_init):
    """Pin count: the explicit argument, else the program's init list length, else 0.

    0 is what pico-sdk's pio_get_default_sm_config() leaves in PINCTRL (pio.h, lines 780-790),
    and what MicroPython's rp2_pio.c gives a base with no init list (ASM_PIO_CONFIG_DEFAULT,
    rp2_pio.c line 209, count 0; asm_pio_get_pins, lines 238-257; sm_config_set_out_pins and
    sm_config_set_set_pins with that count, lines 693-703).
    """
    if requested is not None:
        if requested < 0 or requested > 32:
            raise ValueError("pin count out of range")
        return requested
    return from_init


def _divider(freq, clkdiv):
    """CLKDIV word from freq (Hz, relative to the chip clock) or clkdiv (a float).

    freq as rp2_pio.c reads it (lines 653-672): freq < 0 (the default) means clkdiv 1; freq == 0
    writes a zero divider; otherwise div = chip clock * 256 / freq must be in [256, 65536 * 256],
    and INT is div / 256 truncated to 16 bits, so a divisor of 65536 is written as 0.
    clkdiv is rounded to the nearest 1/256, as pico-sdk does (PICO_CLKDIV_ROUND_NEAREST is 1 on RP2350).
    """
    if freq is not None:
        if freq < 0:
            return clkdiv_word(1, 0)
        if freq == 0:
            return clkdiv_word(0, 0)
        div256 = (CHIP_HZ * 256) // freq
        if div256 < 256 or div256 > 65536 * 256:
            raise ValueError("freq out of range")
        return clkdiv_word((div256 >> 8) & 0xFFFF, div256 & 0xFF)
    if clkdiv is not None:
        div256 = int(clkdiv * 512 + 1) // 2  # floor(256 * clkdiv + 0.5), no float literal
        if div256 < 256 or div256 > 65536 * 256:
            raise ValueError("clkdiv out of range")
        return clkdiv_word((div256 >> 8) & 0xFFFF, div256 & 0xFF)
    return clkdiv_word(1, 0)


# ---------------------------------------------------------------------------
# The PIO SPI master (the host side, RP2350)
# ---------------------------------------------------------------------------

SCK_MAX_HZ = 15000000
SCK_MIN_HALF = 2
SCK_MAX_HALF = 16


def half_period(sck_hz):
    """Chip cycles per SCK phase for a requested SCK rate. Rounds up, so the rate never exceeds it."""
    if sck_hz <= 0 or sck_hz > SCK_MAX_HZ:
        raise ValueError("SCK must be above 0 and at most 15 MHz")
    h = (CHIP_HZ + 2 * sck_hz - 1) // (2 * sck_hz)
    if h < SCK_MIN_HALF or h > SCK_MAX_HALF:
        raise ValueError("SCK %d Hz is outside what the PIO master supports (1.875 to 15 MHz)" % sck_hz)
    return h


SAMPLE_LOW_MAX_H = 4  # MISO sampled at tick h (low phase) for h up to this, at tick 1 above


def spi_master_program(rp2, h):
    """The PIO SPI master (mode 0, MSB first) as a @rp2.asm_pio program object, a 9-field list.

    One PIO tick is one chip cycle (the SM clock is 60 MHz). Each SCK phase is h ticks.
    The SET group is SCK, MOSI and CS_N on consecutive pins (SET base = SCK, count 3), so
    `set pins, 0` lowers CS_N and `set pins, 4` raises it.

    Frame: a header word N-1 (pulled while CS_N is high, and loaded into Y with `out y, 32`),
    then N data words, each with the byte in bits 31:24. Y counts the bytes after the first.

    MISO is sampled once per bit. For H = 2 to 4 the sample is at tick H, the first tick of the
    SCK-low phase. For H = 5 and 6 it is at tick 1, the second SCK-high tick. The closed-loop
    co-simulation (sw/host/cosim) chose these from its sweep: the MISO window is about 4 chip
    cycles at H = 2 and the sample has to sit in its centre, while at H = 5 and 6 the window lies
    earlier in the bit. The MISO input synchroniser is bypassed (see PioSpiTransport). The last
    bit's rise tests Y with `jmp y--`, so a byte boundary costs no extra tick.

    The program is one 32-instruction page. programs/spi_master.pio is the same text for h = 3.
    """
    PIO = rp2.PIO
    # The assembler clears the module globals while it runs the body, so the choice is made here.
    low = h <= SAMPLE_LOW_MAX_H

    @rp2.asm_pio(
        sideset_init=PIO.OUT_LOW,
        out_init=PIO.OUT_LOW,
        set_init=[PIO.OUT_LOW, PIO.OUT_LOW, PIO.OUT_HIGH],
        out_shiftdir=PIO.SHIFT_LEFT,
        in_shiftdir=PIO.SHIFT_LEFT,
        autopull=True,
        pull_thresh=8,
        autopush=True,
        push_thresh=8,
    )
    def spi_master():
        # Instruction 0 is the entry point (rp2 restarts at the program offset), so the frame
        # start comes first. Frame start: pull N-1, out y, 32 loads Y and empties the OSR, CS_N
        # low, then bit 7 of the first byte, then jump into the loop at R7.
        label("frame")
        pull(block).side(0)
        out(y, 32).side(0)
        set(pins, 0).side(0)[3]
        out(pins, 1).side(0)[h - 2]
        jmp("R7").side(0)
        if low:
            # MISO is sampled at tick h, the first tick of the SCK-low phase. Used for H = 2 to 4,
            # where the MISO window is short and this is the centre of it.
            label("L0")
            in_(pins, 1).side(0)
            label("L1")
            out(pins, 1).side(0)[h - 2]
            label("R7")
            nop().side(1)[h - 1]
            for _ in (0, 1, 2, 3, 4, 5):
                in_(pins, 1).side(0)
                out(pins, 1).side(0)[h - 2]
                nop().side(1)[h - 1]
            in_(pins, 1).side(0)
            out(pins, 1).side(0)[h - 2]
            label("R0")
            jmp(y_dec, "L0").side(1)[h - 1]
            in_(pins, 1).side(0)
            set(pins, 4).side(0)
            jmp("frame").side(0)
        else:
            # MISO is sampled at tick 1, the second high tick. Used for H = 5 and 6, where the
            # window lies earlier in the bit (see SAMPLE_LOW_MAX_H).
            label("L0")
            in_(pins, 1).side(1)[h - 2]
            label("L1")
            out(pins, 1).side(0)[h - 1]
            label("R7")
            nop().side(1)
            for _ in (0, 1, 2, 3, 4, 5):
                in_(pins, 1).side(1)[h - 2]
                out(pins, 1).side(0)[h - 1]
                nop().side(1)
            in_(pins, 1).side(1)[h - 2]
            out(pins, 1).side(0)[h - 1]
            label("R0")
            jmp(y_dec, "L0").side(1)
            in_(pins, 1).side(1)[h - 2]
            set(pins, 4).side(0)
            jmp("frame").side(0)

    return spi_master


def _import_rp2():
    import rp2

    return rp2


def _pio_pad_claim(gpio):
    """Give a GPIO to PIO0 and make it an input (raw RP2350 registers; see the README).

    PADS_BANK0 (base 0x40038000, GPIO n at offset 0x04 + 4n): clear ISO (bit 8), set IE (bit 6).
    IO_BANK0 (base 0x40028000, GPIO n control at offset 0x04 + 8n): FUNCSEL (bits 4:0) = 6, PIO0.
    """
    from machine import mem32

    pad = 0x40038000 + 4 + 4 * gpio
    mem32[pad] = (mem32[pad] & ~0x100) | 0x40
    ctrl = 0x40028000 + 4 + 8 * gpio
    mem32[ctrl] = (mem32[ctrl] & ~0x1F) | 6


PIO_BASE = (0x50200000, 0x50300000, 0x50400000)  # RP2350 PIO0, PIO1, PIO2 (regs/addressmap.h)
PIO_INPUT_SYNC_BYPASS = 0x038  # regs/pio.h, PIO_INPUT_SYNC_BYPASS_OFFSET


def _pio_bypass_pin(pio_id, gpio, gpio_base=16):
    """Bypass the input synchroniser of one pin (pio.c line 362-370: the bit is GPIO - gpio_base).

    The bypass cuts the MISO input latency from 3 system cycles to 1 (pgsim's input model, and
    the RP2040 datasheet 3.5.6). The closed-loop co-simulation needs it for 15 MHz (README).
    """
    from machine import mem32

    reg = PIO_BASE[pio_id] + PIO_INPUT_SYNC_BYPASS
    bit = 1 << (gpio - gpio_base)
    mem32[reg] = mem32[reg] | bit


def _clock():
    """(now, diff) in microseconds: MicroPython's ticks, or monotonic time on CPython."""
    try:
        import time

        return time.ticks_us, time.ticks_diff
    except AttributeError:
        import time

        return (lambda: int(time.monotonic() * 1000000)), (lambda a, b: a - b)


def _put_item(sm, data, st):
    """Push the next TX word: the header (the count), then bytes; zeros once the frame is aborted."""
    if st[0] == 0:
        sm.put(len(data) - 1)  # the master counts the bytes after the first
    else:
        i = st[0] - 1
        b = 0 if (st[2] or i >= len(data)) else data[i]
        sm.put(b << 24)
    st[0] += 1


def _finish_frame(sm, data, out, st):
    """Complete the frame with zero bytes so CS_N goes high and RX ends empty."""
    if st[0] == 0:
        return  # nothing was sent, so no frame is running
    st[2] = True
    spins = 0
    while len(out) < len(data) and spins < 1000000:
        spins += 1
        if sm.rx_fifo() > 0:
            out.append(sm.get() & 0xFF)
        elif st[0] <= len(data) and sm.tx_fifo() < FIFO_DEPTH:
            _put_item(sm, data, st)


def xfer_on_sm(sm, data, timeout_us=100000, clock=None):
    """Move one frame through a PIO SPI master: an rp2 StateMachine, or any object with the same
    put, get, tx_fifo and rx_fifo methods. Returns the MISO bytes, one per byte sent.

    The loop reads RX first. Whenever RX has a word it is popped; the TX FIFO is refilled only
    when RX is empty. The RX FIFO holds 4 words, and the master's autopush stalls with SCK high
    when it is full, so popping first keeps MISO correct at any host speed. TX is never more than
    4 words ahead of the master, so the frame cannot stall on an empty TX except briefly.

    On timeout, or if the caller is interrupted, the frame is completed with zero bytes, so CS_N
    goes high and RX is left empty. Then OSError is raised (or the interrupt is re-raised).
    clock is (now, diff) for tests; the default is the MicroPython tick functions.
    """
    n = len(data)
    if n == 0:
        return b""
    now, diff = clock if clock is not None else _clock()
    out = bytearray()
    st = [0, now(), False]  # items pushed (0 is the header), start time, aborted
    try:
        while len(out) < n:
            if not st[2] and diff(now(), st[1]) > timeout_us:
                _finish_frame(sm, data, out, st)
                raise OSError("SPI frame timed out; CS_N released")
            if sm.rx_fifo() > 0:
                out.append(sm.get() & 0xFF)
            elif st[0] <= n and sm.tx_fifo() < FIFO_DEPTH:
                _put_item(sm, data, st)
    except BaseException:
        _finish_frame(sm, data, out, st)
        raise
    return bytes(out)


class PioSpiTransport(object):
    """The link from an RP2350, with a PIO state machine as SPI master (MicroPython only).

    Pins: SCK, MOSI and CS_N must be consecutive (the SET group), as on the demo board
    (GPIO 22, 23, 24 = ui_in[5..7]). MISO is GPIO 40 (uo_out[7]) and needs an RP2350B.
    The PIO needs gpio_base 16 to reach GPIO 40. Clock: the RP2350 sysclk must be 120 MHz
    (DESIGN section 13).
    """

    def __init__(self, sck_hz=10000000, sm_id=0, sck=22, miso=40, sysclk_hz=SYSCLK_HZ, pio_id=0):
        rp2 = _import_rp2()
        import machine

        if machine.freq() != sysclk_hz:
            raise ValueError("sysclk is %d Hz; the link needs %d" % (machine.freq(), sysclk_hz))
        h = half_period(sck_hz)
        self.half = h
        self.sck_hz = CHIP_HZ // (2 * h)
        pio = rp2.PIO(pio_id)
        pio.gpio_base(16)
        _pio_bypass_pin(pio_id, miso)
        prog = spi_master_program(rp2, h)
        self.sm = rp2.StateMachine(
            pio_id * 4 + sm_id,
            prog,
            freq=CHIP_HZ,
            in_base=miso,
            out_base=sck + 1,
            set_base=sck,
            sideset_base=sck,
        )
        _pio_pad_claim(miso)
        self.sm.active(1)

    def xfer(self, data, timeout_us=100000):
        return xfer_on_sm(self.sm, data, timeout_us)

    def close(self):
        self.sm.active(0)


class SimTransport(object):
    """Speaks chip.md section 12 to `pgsim chip-serve` (CPython only)."""

    def __init__(self, pgsim="pgsim", num_sms=4, sck_half=3, cs_setup=4, cs_gap=4):
        import subprocess

        cmd = [
            pgsim,
            "chip-serve",
            "--num-sms",
            str(num_sms),
            "--sck-half",
            str(sck_half),
            "--cs-setup",
            str(cs_setup),
            "--cs-gap",
            str(cs_gap),
        ]
        self._p = subprocess.Popen(
            cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            universal_newlines=True,
            bufsize=1,
        )

    def _line(self, text):
        if self._p.poll() is not None:
            raise ChipError("chip-serve has exited")
        self._p.stdin.write(text + "\n")
        self._p.stdin.flush()
        reply = self._p.stdout.readline()
        if not reply:
            raise ChipError("chip-serve closed its output")
        reply = reply.strip()
        if reply.startswith("err"):
            raise ChipError(reply)
        return reply

    def xfer(self, data):
        import binascii

        reply = self._line("xfer " + binascii.hexlify(data).decode())
        parts = reply.split()
        if len(parts) != 2 or parts[0] != "ok":
            raise ChipError("bad xfer reply: " + reply)
        return binascii.unhexlify(parts[1])

    def run(self, cycles):
        self._line("run %d" % cycles)

    def ext(self, ui, uio):
        self._line("ext %x %x" % (ui, uio))

    def pads(self):
        parts = self._line("pads").split()
        return int(parts[1], 16), int(parts[2], 16), int(parts[3], 16)

    def cycle(self):
        return int(self._line("cycle").split()[1])

    def close(self):
        if self._p.poll() is None:
            try:
                self._p.stdin.write("quit\n")
                self._p.stdin.flush()
            except (OSError, ValueError):
                pass
            self._p.wait()
