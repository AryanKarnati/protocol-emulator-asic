#!/usr/bin/env bash
# Build the golden corpus for pgasm from raspberrypi/pico-examples, using the
# official pioasm from build_pioasm.sh as the oracle (DESIGN.md sections 16, 17.1).
#
# For every .pio file in pico-examples at the pinned tag this script:
#   - copies the source into sw/pgasm/test/corpus/pico-examples/<relative path>
#   - writes <file>.pio.json      (pioasm -o json: all programs, config, instructions)
#   - writes <file>.pio.c-sdk.h   (pioasm -o c-sdk: wrap, side-set, clock config)
#   - writes <file>.pio.python.py (pioasm -o python: MicroPython source)
#   - writes <file>.pio.<prog>.hex, one per program, one 16-bit word per line
#     (for single-program files this is checked byte-for-byte against pioasm -o hex;
#     pioasm refuses -o hex for multi-program files, so those are derived from the JSON)
# It also copies the pico-examples licence and writes corpus/MANIFEST.md.
#
# The PIO version is detected per file (see MANIFEST.md). Output is generated with
# -v 0 unless the file needs PIO version 1, in which case -v 1 is used.
#
# Idempotent: the corpus directory is regenerated from scratch on each run.
# Caches live under ~/.cache/polyglot/ only.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
CORPUS_DIR="${REPO_ROOT}/sw/pgasm/test/corpus"
DEST="${CORPUS_DIR}/pico-examples"
MANIFEST="${CORPUS_DIR}/MANIFEST.md"

CACHE_DIR="${HOME}/.cache/polyglot"
EX_DIR="${CACHE_DIR}/pico-examples"
# Pinned to match the SDK tag used by build_pioasm.sh (pico-examples names its tags sdk-<ver>).
EX_TAG="sdk-2.3.1"
EX_COMMIT="0d62f75bafc2c8120d3276c3343d1a9195e909e9"
EX_URL="https://github.com/raspberrypi/pico-examples.git"

SDK_TAG="$(sed -n 's/^PICO_SDK_TAG="\([^"]*\)"$/\1/p' "${SCRIPT_DIR}/build_pioasm.sh")"
SDK_COMMIT="$(sed -n 's/^PICO_SDK_COMMIT="\([^"]*\)"$/\1/p' "${SCRIPT_DIR}/build_pioasm.sh")"
if [ "${EX_TAG}" != "sdk-${SDK_TAG}" ]; then
    echo "error: pico-examples tag ${EX_TAG} does not match SDK tag ${SDK_TAG}" >&2
    exit 1
fi

# 1. Clone pico-examples at the pinned tag (idempotent).
mkdir -p "${CACHE_DIR}"
if [ -d "${EX_DIR}/.git" ] && [ "$(git -C "${EX_DIR}" rev-parse HEAD)" = "${EX_COMMIT}" ]; then
    echo "pico-examples ${EX_TAG} already cloned at ${EX_DIR}" >&2
else
    rm -rf "${EX_DIR}"
    git clone --depth 1 --branch "${EX_TAG}" "${EX_URL}" "${EX_DIR}" >&2
    got="$(git -C "${EX_DIR}" rev-parse HEAD)"
    if [ "${got}" != "${EX_COMMIT}" ]; then
        echo "error: tag ${EX_TAG} resolves to ${got}, expected ${EX_COMMIT}" >&2
        exit 1
    fi
fi

# 2. Build (or reuse) the official pioasm.
PIOASM="$("${SCRIPT_DIR}/build_pioasm.sh")"
PIOASM_VERSION="$("${PIOASM}" --version | sed 's/^pioasm version: //')"

WORK="$(mktemp -d "${CACHE_DIR}/corpus-work.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT
RECORDS="${WORK}/records.tsv"
: > "${RECORDS}"

# Converts the JSON from pioasm into per-program hex files (one 4-digit hex word per line),
# and checks single-program output against pioasm -o hex when a direct hex file is given.
# Prints "<program name>\t<pio version>" for each program.
derive_hex() {
    python3 -I - "$1" "$2" "$3" <<'PY'
import json, os, sys
json_path, out_prefix, direct_hex = sys.argv[1], sys.argv[2], sys.argv[3]
with open(json_path) as f:
    doc = json.load(f)
for prog in doc["programs"]:
    name = prog["name"]
    words = [ins["hex"].lower() for ins in prog["instructions"]]
    for w in words:
        assert len(w) == 4, (json_path, name, w)
    out = f"{out_prefix}.{name}.hex"
    with open(out, "w") as f:
        f.write("".join(w + "\n" for w in words))
    if len(doc["programs"]) == 1 and direct_hex and direct_hex != "-":
        with open(direct_hex) as f:
            direct = f.read()
        with open(out) as f:
            derived = f.read()
        if direct != derived:
            sys.exit(f"error: derived hex differs from pioasm -o hex for {json_path}")
    print(f"{name}\t{prog['pioVersion']}")
PY
}

# 3. Copy sources and generate expected outputs.
rm -rf "${DEST}"
mkdir -p "${DEST}"
cp "${EX_DIR}/LICENSE.TXT" "${DEST}/LICENSE.TXT"

cd "${EX_DIR}"
mapfile -t PIO_FILES < <(find . -name '*.pio' -type f | sed 's|^\./||' | LC_ALL=C sort)
if [ "${#PIO_FILES[@]}" -eq 0 ]; then
    echo "error: no .pio files found in ${EX_DIR}" >&2
    exit 1
fi

for rel in "${PIO_FILES[@]}"; do
    mkdir -p "${DEST}/$(dirname "${rel}")"
    cp "${EX_DIR}/${rel}" "${DEST}/${rel}"
    src="${DEST}/${rel}"

    # Detection (a): explicit '.pio_version 1' directive in the source.
    declared_v1="no"
    if grep -qE '^[[:space:]]*\.pio_version[[:space:]]+1([[:space:]]|$)' "${src}"; then
        declared_v1="yes"
    fi

    # Detection (b): pioasm with default version 0 rejects a PIO v1-only construct.
    # pioasm gates these with check_version(1, ...): mov pindirs, mov rxfifo[],
    # wait jmppin, irq prev/next, .fifo txput/txget/putget.
    feature_v1="no"
    if "${PIOASM}" -v 0 -o json "${src}" "${WORK}/probe.json" 2>"${WORK}/probe.err"; then
        :
    elif grep -q "PIO version 1 is required" "${WORK}/probe.err"; then
        feature_v1="yes"
        "${PIOASM}" -v 1 -o json "${src}" "${WORK}/probe1.json" 2>"${WORK}/probe1.err" || {
            echo "error: ${rel} needs PIO v1 but does not assemble with -v 1" >&2
            cat "${WORK}/probe1.err" >&2
            exit 1
        }
    else
        echo "error: pioasm -v 0 rejected ${rel}:" >&2
        cat "${WORK}/probe.err" >&2
        exit 1
    fi

    uses_v1="no"
    if [ "${declared_v1}" = "yes" ] || [ "${feature_v1}" = "yes" ]; then
        uses_v1="yes"
    fi
    gen_ver=0
    if [ "${feature_v1}" = "yes" ]; then gen_ver=1; fi

    base="${src}"
    "${PIOASM}" -v "${gen_ver}" -o json "${src}" "${base}.json"
    "${PIOASM}" -v "${gen_ver}" -o c-sdk "${src}" "${base}.c-sdk.h"
    "${PIOASM}" -v "${gen_ver}" -o python "${src}" "${base}.python.py"

    # Single-program files: also keep pioasm's own -o hex output as the cross-check.
    direct="-"
    if [ "$(python3 -I -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["programs"]))' "${base}.json")" = "1" ]; then
        direct="${WORK}/direct.hex"
        "${PIOASM}" -v "${gen_ver}" -o hex "${src}" "${direct}"
    fi
    progs="$(derive_hex "${base}.json" "${base}" "${direct}")"

    nprog="$(printf '%s\n' "${progs}" | wc -l)"
    names="$(printf '%s\n' "${progs}" | cut -f1 | paste -sd, -)"
    versions="$(printf '%s\n' "${progs}" | cut -f2 | paste -sd, -)"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "${rel}" "${nprog}" "${names}" "${versions}" "${declared_v1}" "${feature_v1}" "${uses_v1}" "${gen_ver}" \
        >> "${RECORDS}"
done

# 4. Manifest.
python3 -I - "${RECORDS}" "${MANIFEST}" "${SDK_TAG}" "${SDK_COMMIT}" "${EX_TAG}" "${EX_COMMIT}" "${PIOASM_VERSION}" <<'PY'
import sys
records_path, out_path, sdk_tag, sdk_commit, ex_tag, ex_commit, pioasm_ver = sys.argv[1:8]
rows = [line.rstrip("\n").split("\t") for line in open(records_path) if line.strip()]
n_files = len(rows)
n_progs = sum(int(r[1]) for r in rows)
n_v1 = sum(1 for r in rows if r[6] == "yes")
n_v1_progs = 0
for r in rows:
    if r[6] == "yes":
        n_v1_progs += int(r[1])
lines = []
w = lines.append
w("# Golden corpus manifest")
w("")
w("Generated by `sw/pgasm/oracle/make_corpus.sh`. Do not edit by hand.")
w("")
w("## Sources and oracle")
w("")
w("| Item | Tag | Commit |")
w("| --- | --- | --- |")
w(f"| raspberrypi/pico-sdk (pioasm source) | `{sdk_tag}` | `{sdk_commit}` |")
w(f"| raspberrypi/pico-examples (`.pio` sources) | `{ex_tag}` | `{ex_commit}` |")
w("")
w(f"- Oracle: `pioasm` built from the pico-sdk tag above with cmake (`-DPIOASM_VERSION_STRING={sdk_tag}`). `pioasm --version` reports `{pioasm_ver}`.")
w("- Licence: `pico-examples/LICENSE.TXT` (BSD-3-Clause, copied unchanged from pico-examples).")
w("")
w("## pioasm options used")
w("")
w("- `pioasm -v <0|1> -o json <file.pio> <file.pio.json>` (all programs, instructions as 4-digit hex, pioVersion, wrap, side-set, clock divider, FIFO config)")
w("- `pioasm -v <0|1> -o c-sdk <file.pio> <file.pio.c-sdk.h>` (wrap, side-set and clock config as the C SDK sees them)")
w("- `pioasm -v <0|1> -o python <file.pio> <file.pio.python.py>` (MicroPython source: `@rp2.asm_pio` arguments, `wrap_target()`/`wrap()` and numeric labels)")
w("- `pioasm -v <0|1> -o hex <file.pio> <out>`: run only for single-program files, as a cross-check. pioasm refuses `-o hex` for multi-program input.")
w("- Multi-program files get `<file.pio>.<program>.hex`, derived from the JSON `instructions[].hex` values (one word per line, lowercase, 4 digits, the same layout as `-o hex`). The script checks that this derivation equals pioasm's own `-o hex` for every single-program file.")
w("- `-v 0` (the pioasm default) is used unless a file needs PIO version 1, which then gets `-v 1` (see detection below). No other options are passed.")
w("")
w("## PIO version detection")
w("")
w("A file **uses PIO v1** if either:")
w("")
w("1. it contains a `.pio_version 1` directive (`declared`), or")
w("2. `pioasm -v 0` rejects it with `PIO version 1 is required for '...'` (`feature`). pioasm gates `mov pindirs`, `mov rxfifo[...]`, `wait ... jmppin`, `irq prev`/`irq next`, and `.fifo txput`/`txget`/`putget` this way.")
w("")
w("Files that do not use v1 are assembled as PIO v0 (RP2040), which is Polyglot's base. v1 files are kept in the corpus but tracked separately.")
w("")
w("## Summary")
w("")
w(f"- `.pio` files: {n_files}")
w(f"- Programs: {n_progs}")
w(f"- Files that use PIO v1: {n_v1} (programs: {n_v1_progs})")
w(f"- Files pioasm rejected: 0 (the script stops on any rejection)")
if n_v1 == 0:
    w(f"- pico-examples sdk-{sdk_tag} contains no PIO v1 `.pio` files: confirmed by assembling all {n_files} with `pioasm -v 0` (pioasm {pioasm_ver}, all {n_files} accepted).")
w("")
w("## Per file")
w("")
w("| File | Programs | Program names | Program pioVersion | `.pio_version 1` declared | v1 feature (`-v 0` rejects) | Uses PIO v1 | Generated with `-v` |")
w("| --- | ---: | --- | --- | --- | --- | --- | ---: |")
for r in rows:
    rel, nprog, names, vers, decl, feat, uses, gv = r
    w(f"| `pico-examples/{rel}` | {nprog} | {names.replace(',', ', ')} | {vers.replace(',', ', ')} | {decl} | {feat} | {uses} | {gv} |")
w("")
open(out_path, "w").write("\n".join(lines) + "\n")
print(f"files={n_files} programs={n_progs} v1_files={n_v1} v1_programs={n_v1_progs}")
PY

echo "corpus written to ${DEST}" >&2
echo "manifest written to ${MANIFEST}" >&2
