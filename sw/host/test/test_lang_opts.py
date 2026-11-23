"""The .lang_opt python line for a list init is written without spaces inside the list, and both
pioasm and pgasm accept it and print the same Python. Skips without the built tools."""

import os
import subprocess

import pytest

from test_programs import REPO

PGASM = os.path.join(REPO, "_build", "default", "sw", "pgasm", "bin", "pgasm.exe")
PIOASM = os.path.expanduser("~/.cache/polyglot/pioasm-build/pioasm")
SPI_PIO = os.path.join(REPO, "programs", "spi_master.pio")


@pytest.mark.skipif(not (os.path.exists(PGASM) and os.path.exists(PIOASM)), reason="pgasm and pioasm needed")
def test_set_init_lang_option_is_identical_in_pioasm_and_pgasm(tmp_path):
    a = tmp_path / "pioasm.py"
    b = tmp_path / "pgasm.py"
    subprocess.check_call([PIOASM, "-o", "python", SPI_PIO, str(a)])
    subprocess.check_call([PGASM, "-o", "python", SPI_PIO, str(b)])
    assert a.read_bytes() == b.read_bytes()
    text = a.read_text()
    assert "set_init=[rp2.PIO.OUT_LOW,rp2.PIO.OUT_LOW,rp2.PIO.OUT_HIGH]" in text


@pytest.mark.skipif(not os.path.exists(PGASM), reason="build pgasm first")
def test_committed_program_file_is_the_generator_text(tmp_path):
    import pio_gen

    text = open(SPI_PIO).read()
    body = text[text.index(".program spi_master"):]
    # The file's comments and blank lines are not instructions; compare the non-comment lines.
    def code(s):
        out = []
        for line in s.splitlines():
            line = line.split(";", 1)[0].rstrip()
            if line.strip():
                out.append(line.strip())
        return out

    assert code(body) == code(pio_gen.pio_text(3))
