"""SimTransport speaks chip.md section 12 to `pgsim chip-serve`.

The real server is the Model & tests lane's. These tests run SimTransport against a stand-in
script that follows the same line protocol, so the transport's parsing and error paths are
checked now. Once `pgsim chip-serve` is on main, test_sim_real (below) runs the real one.
"""

import os
import stat
import sys

import pytest

import polyglot as pg

FAKE = """#!{python}
import sys
for line in sys.stdin:
    p = line.split()
    if not p:
        continue
    if p[0] == 'xfer':
        data = bytes.fromhex(p[1])
        sys.stdout.write('ok ' + bytes(b ^ 0xFF for b in data).hex() + '\\n')
    elif p[0] == 'run':
        sys.stdout.write('ok\\n')
    elif p[0] == 'pads':
        sys.stdout.write('ok 01 02 03\\n')
    elif p[0] == 'cycle':
        sys.stdout.write('ok 7\\n')
    elif p[0] == 'ext':
        sys.stdout.write('err no external pads in this stand-in\\n')
    elif p[0] == 'quit':
        break
    else:
        sys.stdout.write('err unknown command\\n')
    sys.stdout.flush()
"""


@pytest.fixture
def fake_server(tmp_path):
    path = tmp_path / "fake-pgsim"
    path.write_text(FAKE.format(python=sys.executable))
    path.chmod(path.stat().st_mode | stat.S_IEXEC)
    return str(path)


def test_xfer_round_trip(fake_server):
    t = pg.SimTransport(pgsim=fake_server)
    try:
        assert t.xfer(b"\x01\x02\xff") == b"\xfe\xfd\x00"
        assert t.xfer(bytes([0x80, 0, 0, 0, 0, 0, 0, 0])) == bytes([0x7F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF])
    finally:
        t.close()


def test_pads_cycle_run(fake_server):
    t = pg.SimTransport(pgsim=fake_server)
    try:
        assert t.pads() == (1, 2, 3)
        assert t.cycle() == 7
        t.run(10)
    finally:
        t.close()


def test_err_replies_raise(fake_server):
    t = pg.SimTransport(pgsim=fake_server)
    try:
        with pytest.raises(pg.ChipError):
            t.ext(0x1F, 0)
    finally:
        t.close()


def test_chip_on_top_of_sim_transport(fake_server):
    # The chip API builds the frame; SimTransport moves it. The stand-in inverts the bytes,
    # so the reply to a one-byte status frame is 0xFF.
    chip = pg.Chip(pg.SimTransport(pgsim=fake_server))
    try:
        assert chip.status() == 0xFF
    finally:
        chip._t.close()


def test_missing_server_is_an_error(tmp_path):
    with pytest.raises(OSError):
        pg.SimTransport(pgsim=str(tmp_path / "no-such-pgsim"))


