#!/usr/bin/env python3
"""Exhaustive word sweep: every 16-bit word, through the official pioasm and through pgasm.

Program k (0..2047) holds the words 32k .. 32k+31 as `.word` lines. Chunk c (0..255) is
programs 8c .. 8c+7, that is 256 words. For each chunk and each output format (json, python,
c-sdk) this script concatenates what `pioasm -v 0 -o <format>` writes for its programs, takes
the MD5, and writes one line "<chunk> <json md5> <python md5> <c-sdk md5>" to
sw/pgasm/test/word_sweep.md5. The dune test in sw/pgasm/test computes the same MD5s from
pgasm's output and compares.

The script also checks that pgasm's output equals pioasm's for every program in every format
(it uses the pgasm binary if it is built), so a mismatch is reported here as well.

Usage: python3 sw/pgasm/oracle/word_sweep.py [--pgasm PATH]
Work files go under ~/.cache/polyglot/word-sweep/.
"""
import argparse
import hashlib
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT_MD5 = os.path.join(REPO, "sw", "pgasm", "test", "word_sweep.md5")
PIOASM = os.path.join(os.path.expanduser("~"), ".cache", "polyglot", "pioasm-build", "pioasm")
WORK = os.path.join(os.path.expanduser("~"), ".cache", "polyglot", "word-sweep")

PROGRAMS = 2048
PER_CHUNK = 8
CHUNKS = PROGRAMS // PER_CHUNK
FORMATS = ["json", "python", "c-sdk"]


def source(k):
    lines = [f".program w{k:04d}\n"]
    lines += [f"    .word 0x{32 * k + j:04x}\n" for j in range(32)]
    return "".join(lines)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pgasm", default=os.path.join(REPO, "_build", "default", "sw", "pgasm", "bin", "pgasm.exe"))
    args = ap.parse_args()
    os.makedirs(WORK, exist_ok=True)
    chunk_lines = []
    mismatches = 0
    for c in range(CHUNKS):
        hashes = {fmt: hashlib.md5() for fmt in FORMATS}
        for k in range(c * PER_CHUNK, (c + 1) * PER_CHUNK):
            src = os.path.join(WORK, f"w{k:04d}.pio")
            with open(src, "w", encoding="utf-8") as f:
                f.write(source(k))
            for fmt in FORMATS:
                ora = subprocess.run([PIOASM, "-v", "0", "-o", fmt, src, "-"], capture_output=True)
                if ora.returncode != 0:
                    sys.exit(f"pioasm rejected program {k} ({fmt}): {ora.stderr.decode()[:200]}")
                if os.path.exists(args.pgasm):
                    pg = subprocess.run([args.pgasm, "-o", fmt, src], capture_output=True)
                    if pg.stdout != ora.stdout:
                        mismatches += 1
                        print(f"MISMATCH program {k} ({fmt}): {pg.stderr.decode()[:200]}")
                hashes[fmt].update(ora.stdout)
        chunk_lines.append(f"{c} " + " ".join(hashes[fmt].hexdigest() for fmt in FORMATS))
    with open(OUT_MD5, "w") as f:
        f.write("\n".join(chunk_lines) + "\n")
    print(f"wrote {OUT_MD5}: {CHUNKS} chunks x {len(FORMATS)} formats, {PROGRAMS * 32} words")
    if mismatches:
        sys.exit(f"{mismatches} outputs differ from pioasm")
    print("pgasm agrees with pioasm on every program" if os.path.exists(args.pgasm) else "pgasm binary not built; hashes only")


if __name__ == "__main__":
    main()
