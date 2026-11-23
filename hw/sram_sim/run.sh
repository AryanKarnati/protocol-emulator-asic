#!/bin/sh
# Runs the SPI test of the SRAM trial top (chip.md 8.4) against the IHP SRAM macro model.
#
# The PDK files are not in this repository. They come from IHP-Open-PDK at the commit
# that flow/estimate.sh pins, e73adb4045731ddec21634146d536380057f6a26 (flow/SRAM.md gives
# the paths). Fetch the two files into a directory, and point SRAM_MODEL_DIR at it. The
# default is ~/.cache/polyglot/ihp/sram_e73adb4. The URL pattern is
#   https://raw.githubusercontent.com/IHP-GmbH/IHP-Open-PDK/<commit>/ihp-sg13g2/libs.ref/sg13g2_sram/verilog/<file>
# with the files RM_IHPSG13_1P_512x32_c2_bm_bist.v and RM_IHPSG13_1P_core_behavioral_bm_bist.v.
# Each file is checked against its sha256 before use.
#
# Usage: hw/sram_sim/run.sh [functional]
#   functional   compile the wrapper with +define+FUNCTIONAL (behavioural core, no specify)
#
# Needs iverilog and vvp on PATH, and dune with the polyglot switch on PATH, or the
# OPAM_EXEC prefix below. Prints the test result and returns non-zero on failure.

set -eu

root=$(cd "$(dirname "$0")/../.." && pwd)
model_dir=${SRAM_MODEL_DIR:-$HOME/.cache/polyglot/ihp/sram_e73adb4}
OPAM_EXEC=${OPAM_EXEC:-opam exec --switch=polyglot --}
build=${SRAM_SIM_BUILD:-${TMPDIR:-/tmp}/polyglot_sram_sim}
mkdir -p "$build"

wrapper_sha=2bec4b86c665f485e795da0321da2d8153947090e93d11555b19f222cbee7ed8
core_sha=d0a6258f8e9c93d1d5b1f78c0a1d66f30d28b1ad8037e5e07f53d1a4e3670b12
wrapper="$model_dir/RM_IHPSG13_1P_512x32_c2_bm_bist.v"
core="$model_dir/RM_IHPSG13_1P_core_behavioral_bm_bist.v"

for pair in "$wrapper:$wrapper_sha" "$core:$core_sha"; do
  f=${pair%%:*}
  want=${pair#*:}
  if [ ! -s "$f" ]; then
    echo "missing $f (set SRAM_MODEL_DIR; see flow/SRAM.md)" >&2
    exit 2
  fi
  got=$(sha256sum "$f" | awk '{print $1}')
  if [ "$got" != "$want" ]; then
    echo "$f: sha256 $got does not match the pinned $want" >&2
    exit 2
  fi
done

defines=""
if [ "${1:-}" = functional ]; then
  defines="-DFUNCTIONAL"
fi

(cd "$root" && $OPAM_EXEC dune build --root . --display=quiet ./hw/bin/gen_verilog.exe)
"$root/_build/default/hw/bin/gen_verilog.exe" top_sram > "$build/top_sram.v"

iverilog -g2005 $defines -o "$build/sim" \
  "$root/hw/sram_sim/tb_sram.v" "$build/top_sram.v" "$wrapper" "$core"
vvp -n "$build/sim" | tee "$build/log.txt"
grep -q 'RESULT PASS' "$build/log.txt"
