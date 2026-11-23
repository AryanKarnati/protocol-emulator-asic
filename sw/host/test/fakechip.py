"""A register-file stand-in for the chip, driven only by bytes on the link.

It decodes frames by chip.md section 6.3 on its own (it does not use polyglot's frame
functions), keeps every register value as written, and models just enough for the library's
tests: IMEM, the SM registers, TX pushes and INSTR writes are logged. Reads of unknown
addresses return 0. It is not the chip model (that is pgsim); it checks the byte layout.
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))

ID = 0x504C4754
IMEM_BASE = 0x100
IMEM_END = IMEM_BASE + 4 * 64


class FakeChip(object):
    def __init__(self):
        self.reset()

    def reset(self):
        """Power-on state: what a deselection leaves behind (SCRATCH 0, no config)."""
        self.regs = {0x000: ID, 0x004: 4 | (4 << 8) | (64 << 16) | (1 << 28)}
        self.imem = {}
        self.writes = []  # (addr, value) in arrival order, for every word written
        self.tx = []
        self.instr = []  # (sm, instr) for each INSTR write
        self.frames = 0
        self.status_byte = 0

    def xfer(self, data):
        self.frames += 1
        data = bytes(data)
        if len(data) == 1:
            return bytes([self.status_byte])
        cmd = data[0]
        addr = (data[1] << 8) | data[2]
        if cmd & 0x80:
            n = (len(data) - 4) // 4
            reply = bytearray(len(data))
            for m in range(n):
                a = addr if (cmd & 0x40) else addr + 4 * m
                v = self.read(a)
                o = 4 + 4 * m
                reply[o:o + 4] = v.to_bytes(4, "big")
            return bytes(reply)
        body = data[3:]
        if len(body) % 4:
            raise ValueError("write body is not whole words")
        for m in range(len(body) // 4):
            a = addr if (cmd & 0x40) else addr + 4 * m
            v = int.from_bytes(body[4 * m:4 * m + 4], "big")
            self.write(a, v)
        return bytes(len(data))

    def read(self, a):
        return self.regs.get(a, 0)

    def write(self, a, v):
        self.writes.append((a, v))
        if IMEM_BASE <= a < IMEM_END:
            self.imem[(a - IMEM_BASE) // 4] = v & 0xFFFF
            return
        if 0x040 <= a < 0x050:
            self.tx.append(((a - 0x040) // 4, v))
            return
        if a >= 0x200 and ((a - 0x200) & 0x3F) == 0x10:
            self.instr.append(((a - 0x200) >> 6, v & 0xFFFF))
            return
        if a == 0x008:
            # CTRL: the SM_ENABLE bits are stored; the restart and clkdiv-restart pulses are not.
            self.regs[a] = v & 0xF
            return
        if a in (0x010, 0x018, 0x01C):
            return
        self.regs[a] = v
