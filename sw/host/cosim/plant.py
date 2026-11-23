"""Closed-loop co-simulation of the host library's PIO SPI master (CPython, tests only).

The plant (cosim.exe, sw/host/cosim/cosim.ml) runs the master program in pgsim at the RP2350
system clock and the whole-chip model at 60 MHz, wired pad to pad, with a clock phase and board
delays. SimStateMachine exposes the rp2.StateMachine methods that polyglot.xfer_on_sm uses, and
charges every call a host cost in system cycles. So the library's own xfer loop runs against the
closed loop, at any host speed, and CosimTransport puts the Chip API on top of it.
"""

import os
import subprocess

SYSCLK_HZ = 120000000
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
EXE = os.path.join(REPO, "_build", "default", "sw", "host", "cosim", "cosim.exe")


def rp2_regs(obj, freq_div_int, gpio_base, in_base=None, out_base=None, set_base=None, sideset_base=None):
    """Port of rp2_pio.c rp2_state_machine_init_helper for the pins the link uses.

    Returns (clkdiv, execctrl, shiftctrl, pinctrl). Lines cited are rp2_pio.c's, at the pinned
    commit (sw/host/test/vendor/README.txt).
    """
    execctrl = obj[4]  # rp2_pio.c line 681 (config.execctrl)
    shiftctrl = obj[5]  # line 682
    pinctrl = 0
    if in_base is not None:
        pinctrl |= (in_base - gpio_base) << 15  # line 691 (sm_config_set_in_pins)

    def count(prog_pins):
        if prog_pins is None:
            return 0
        return 1 if isinstance(prog_pins, int) else len(prog_pins)

    if out_base is not None:
        pinctrl |= ((out_base - gpio_base) | (count(obj[6]) << 20))  # lines 693-697
    if set_base is not None:
        pinctrl |= (((set_base - gpio_base) << 5) | (count(obj[7]) << 26))  # lines 700-703
    if sideset_base is not None:
        cnt = count(obj[8])
        if (execctrl >> 30) & 1:
            cnt += 1  # lines 716-720: SIDE_EN counts
        pinctrl |= (cnt << 29) | ((sideset_base - gpio_base) << 10)  # lines 714-723
    return (freq_div_int << 16, execctrl, shiftctrl, pinctrl)


class Plant(object):
    """One cosim.exe process. Methods are the plant's commands; each returns the reply."""

    def __init__(self, words, regs, phase=0, dsck=0, dmiso=0, bypass=0, trace=False):
        if not os.path.exists(EXE):
            raise RuntimeError("build the co-simulation first: dune build --root . (sw/host/cosim)")
        clkdiv, execctrl, shiftctrl, pinctrl = regs
        cmd = [
            EXE,
            "--words", ",".join(str(w) for w in words),
            "--clkdiv", str(clkdiv),
            "--execctrl", str(execctrl),
            "--shiftctrl", str(shiftctrl),
            "--pinctrl", str(pinctrl),
            "--phase", str(phase),
            "--dsck", str(dsck),
            "--dmiso", str(dmiso),
            "--bypass", str(bypass),
        ]
        if trace:
            cmd += ["--trace", "1"]
        self._p = subprocess.Popen(
            cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, universal_newlines=True, bufsize=1
        )

    def _cmd(self, text):
        self._p.stdin.write(text + "\n")
        self._p.stdin.flush()
        reply = self._p.stdout.readline().strip()
        if not reply.startswith("ok"):
            raise RuntimeError("plant: %s -> %s" % (text, reply))
        return reply[2:].strip()

    def adv(self, n):
        self._cmd("adv %d" % n)

    def tx(self, word):
        return self._cmd("tx %d" % word) == "1"

    def rx(self):
        return int(self._cmd("rx"))

    def lvl(self):
        tx, rx = self._cmd("lvl").split()
        return int(tx), int(rx)

    def cyc(self):
        return int(self._cmd("cyc"))

    def log(self):
        self._p.stdin.write("log\n")
        self._p.stdin.flush()
        rows = []
        while True:
            line = self._p.stdout.readline().strip()
            if line == "ok":
                return rows
            cyc, sck, cs, mosi, miso = (int(x) for x in line.split())
            rows.append((cyc, sck, cs, mosi, miso))

    def close(self):
        try:
            self._p.stdin.write("quit\n")
            self._p.stdin.flush()
        except (OSError, ValueError):
            pass
        self._p.wait()


class SimStateMachine(object):
    """The rp2.StateMachine methods that the library's xfer loop uses, on the plant.

    Each call performs its operation and then advances the plant by `cost` system cycles, the
    host's API cost. now() is the simulated time in microseconds, so the library's timeout runs
    on simulated time.
    """

    def __init__(self, plant, cost):
        self._p = plant
        self._cost = cost

    def _after(self):
        self._p.adv(self._cost)

    def put(self, value):
        ok = self._p.tx(value)
        self._after()
        if not ok:
            raise RuntimeError("TX FIFO full: the library must check tx_fifo() first")

    def get(self):
        v = self._p.rx()
        self._after()
        return v if v >= 0 else 0

    def tx_fifo(self):
        tx, _ = self._p.lvl()
        self._after()
        return tx

    def rx_fifo(self):
        _, rx = self._p.lvl()
        self._after()
        return rx

    def now(self):
        return self._p.cyc() * 1000000 // SYSCLK_HZ

    @staticmethod
    def diff(a, b):
        return a - b


class CosimTransport(object):
    """xfer(bytes) on the closed loop, through the library's xfer_on_sm."""

    def __init__(self, sm, timeout_us=10**9):
        import polyglot

        self._sm = sm
        self._timeout = timeout_us
        self._xfer = polyglot.xfer_on_sm
        self._clock = (sm.now, sm.diff)

    def xfer(self, data):
        return self._xfer(self._sm, data, self._timeout, self._clock)
