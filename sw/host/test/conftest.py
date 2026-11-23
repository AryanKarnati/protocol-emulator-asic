"""Test setup: put sw/host on the path and load MicroPython's real rp2.py under CPython.

rp2.py imports _rp2 (the C half of the module), micropython.const and array. The stubs below
provide only what rp2.py and the pgasm python output use. The assembler itself is the
vendored file, unchanged.
"""

import importlib.util
import os
import sys
import types

HERE = os.path.dirname(os.path.abspath(__file__))
HOST = os.path.dirname(HERE)
sys.path.insert(0, HOST)


def _stub_modules():
    if "micropython" not in sys.modules:
        mp = types.ModuleType("micropython")
        mp.const = lambda x: x
        sys.modules["micropython"] = mp

    if "_rp2" not in sys.modules:
        rp = types.ModuleType("_rp2")

        class PIO(object):
            SHIFT_LEFT = 0
            SHIFT_RIGHT = 1
            JOIN_NONE = 0
            JOIN_TX = 1
            JOIN_RX = 2
            IN_LOW = 0
            IN_HIGH = 1
            OUT_LOW = 2
            OUT_HIGH = 3

        rp.PIO = PIO
        sys.modules["_rp2"] = rp

    if "machine" not in sys.modules:
        mc = types.ModuleType("machine")

        class Pin(object):
            IN = 0
            OUT = 1

            def __init__(self, *args, **kwargs):
                pass

        mc.Pin = Pin
        sys.modules["machine"] = mc


def load_rp2():
    """Import the vendored rp2.py as module 'rp2' and return it (idempotent)."""
    if "rp2" in sys.modules and getattr(sys.modules["rp2"], "__file__", "").endswith("rp2.py"):
        return sys.modules["rp2"]
    _stub_modules()
    path = os.path.join(HERE, "vendor", "rp2.py")
    spec = importlib.util.spec_from_file_location("rp2", path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["rp2"] = mod
    spec.loader.exec_module(mod)
    return mod


_stub_modules()
