#!/usr/bin/env bash
# Expected outputs for the edge cases in sw/pgasm/test/edge, from the official pioasm
# (build_pioasm.sh), as make_corpus.sh does for the corpus.
#
# For each <name>.pio in test/edge:
#   - with <name>.pio.oracle-error: pioasm must reject it (the marker must be right);
#   - without it: pioasm must accept it, and this writes
#       <name>.pio.json        (pioasm -v 0 -o json)
#       <name>.pio.python.py   (pioasm -v 0 -o python)
#       <name>.pio.c-sdk.h     (pioasm -v 0 -o c-sdk)
# The stderr of pioasm is not kept. The corpus is -v 1 for v1 files; the edge cases are all
# assembled with -v 0, which is the default.
#
# Idempotent: rewrites the outputs of accepted cases. Caches live under ~/.cache/polyglot/.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EDGE_DIR="$(cd "${SCRIPT_DIR}/../test/edge" && pwd)"
PIOASM="$("${SCRIPT_DIR}/build_pioasm.sh")"

cd "${EDGE_DIR}"
accepted=0
rejected=0
for src in *.pio; do
    if [ -e "${src}.oracle-error" ]; then
        if "${PIOASM}" -v 0 -o json "${src}" /dev/null 2>/dev/null; then
            echo "error: ${src} has an oracle-error marker, but pioasm accepts it" >&2
            exit 1
        fi
        rejected=$((rejected + 1))
        continue
    fi
    for fmt in json python c-sdk; do
        case "${fmt}" in
            json) out="${src}.json" ;;
            python) out="${src}.python.py" ;;
            c-sdk) out="${src}.c-sdk.h" ;;
        esac
        if ! "${PIOASM}" -v 0 -o "${fmt}" "${src}" "${out}" 2>/dev/null; then
            echo "error: pioasm rejects ${src} (add ${src}.oracle-error if that is intended)" >&2
            exit 1
        fi
    done
    accepted=$((accepted + 1))
done
echo "edge: ${accepted} accepted, ${rejected} rejected (markers checked)" >&2
