rp2.py: MicroPython's ports/rp2/modules/rp2.py, copied unchanged.

Source:  https://github.com/micropython/micropython
Commit:  1c8e39768802b47f80e91924a00cc9bbd6ce7bf5 (master, 2026-11-21)
Path:    ports/rp2/modules/rp2.py
Licence: MIT (Copyright (c) 2020-2021 Damien P. George), see the file header.

The tests load it under CPython with small stubs for _rp2, micropython and machine
(sw/host/test/conftest.py), so the program objects come from MicroPython's own assembler.
The RP2350 build uses the same file.
