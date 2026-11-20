#!/usr/bin/env python3
"""Exhaustive word sweep: every 16-bit word, through the official pioasm and through pgasm.

Program k (0..2047) holds the words 32k .. 32k+31 as `.word` lines. Chunk c (0..255) is
programs 8c .. 8c+7, that is 256 words. For each chunk this script concatenates the JSON that
`pioasm -v 0 -o json` writes for its programs, takes the MD5, and writes one line
"<chunk> <md5>" to sw/pgasm/test/word_sweep.md5. The dune test in sw/pgasm/test computes the
same MD5 from pgasm's output and compares.

The script also checks that pgasm's JSON equals pioasm's for every program (it uses the pgasm
binary if it is built), so a mismatch is reported here as well.

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


def source(k):
    lines = [f".program w{k:04d}\n"]
    lines += [f"    .word 0x{32 * k + j:04x}\n" for j in range(32)]
    return "".join(lines)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pgasm", default=os.path.join(REPO, "_build", "default", "sw", "pgasm", "bin", "pgasm.exe"))
    args = ap.parse_args()
    os.makedirs(WORK, exist_ok=True)
    chunk_hashes = []
    mismatches = 0
    for c in range(CHUNKS):
        h = hashlib.md5()
        for k in range(c * PER_CHUNK, (c + 1) * PER_CHUNK):
            src = os.path.join(WORK, f"w{k:04d}.pio")
            with open(src, "w", encoding="utf-8") as f:
                f.write(source(k))
            ora = subprocess.run([PIOASM, "-v", "0", "-o", "json", src, "-"], capture_output=True)
            if ora.returncode != 0:
                sys.exit(f"pioasm rejected program {k}: {ora.stderr.decode()[:200]}")
            if os.path.exists(args.pgasm):
                pg = subprocess.run([args.pgasm, "-o", "json", src], capture_output=True)
                if pg.stdout != ora.stdout:
                    mismatches += 1
                    print(f"MISMATCH program {k}: {pg.stderr.decode()[:200]}")
            h.update(ora.stdout)
        chunk_hashes.append(f"{c} {h.hexdigest()}")
    with open(OUT_MD5, "w") as f:
        f.write("\n".join(chunk_hashes) + "\n")
    print(f"wrote {OUT_MD5}: {CHUNKS} chunks, {PROGRAMS * 32} words")
    if mismatches:
        sys.exit(f"{mismatches} programs differ from pioasm")
    print("pgasm agrees with pioasm on every program" if os.path.exists(args.pgasm) else "pgasm binary not built; hashes only")


if __name__ == "__main__":
    main()
