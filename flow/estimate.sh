#!/bin/sh
# Pre-layout area and timing estimate for pio_block1, pio_block and the Tiny Tapeout top.
# See flow/README.md for what the numbers do and do not mean.
#
# Usage: flow/estimate.sh            (from anywhere; uses the cached IHP liberty files)
#
# Environment:
#   CORNER           slow (default) or typ. The liberty file for the corner.
#   POLYGLOT_CACHE   cache root (default ~/.cache/polyglot). Liberty files go in $POLYGLOT_CACHE/ihp.
#   IHP_PDK_COMMIT   IHP-Open-PDK commit to fetch the liberty files from when they are missing.
#                    Defaults to the pinned commit in this script. Each liberty file is
#                    checked against its pinned sha256 whether it was cached or fetched.
#   OPAM_EXEC        command prefix for dune (default "opam exec --").
#   SYNTH_ONLY=1     skip the timing run.
#
# Needs yosys (with the abc pass) and dune with the polyglot switch on PATH.

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
build="$root/flow/build"
mkdir -p "$build"

CORNER=${CORNER:-slow}
case "$CORNER" in
  slow) lib_name=sg13g2_stdcell_slow_1p08V_125C.lib ;;
  typ) lib_name=sg13g2_stdcell_typ_1p20V_25C.lib ;;
  *) echo "CORNER must be slow or typ" >&2; exit 2 ;;
esac

cache=${POLYGLOT_CACHE:-$HOME/.cache/polyglot}/ihp
lib="$cache/$lib_name"
pdk_path="ihp-sg13g2/libs.ref/sg13g2_stdcell/lib/$lib_name"
OPAM_EXEC=${OPAM_EXEC:-opam exec --}

# IHP-Open-PDK main as of the pin (api.github.com/repos/IHP-GmbH/IHP-Open-PDK/commits/main).
# The sha256 values are of the liberty files at that commit. Override IHP_PDK_COMMIT only
# together with the matching checksums.
IHP_PDK_COMMIT=${IHP_PDK_COMMIT:-e73adb4045731ddec21634146d536380057f6a26}
case "$lib_name" in
  sg13g2_stdcell_slow_1p08V_125C.lib)
    lib_sha256=1ac6a0301184b3a8aa1a4a01910967f624c8e869517777f529985f11f04588c3 ;;
  sg13g2_stdcell_typ_1p20V_25C.lib)
    lib_sha256=7677a8918689f452e80405ad16a83e744709342574f2aedcc507c2758986b396 ;;
esac

if [ ! -s "$lib" ]; then
  mkdir -p "$cache"
  echo "fetching $lib_name from IHP-Open-PDK $IHP_PDK_COMMIT"
  curl -fsSL -o "$lib" "https://raw.githubusercontent.com/IHP-GmbH/IHP-Open-PDK/$IHP_PDK_COMMIT/$pdk_path"
fi

# The file in use must be the pinned one. A cached copy from another commit is refused.
got_sha256=$(sha256sum "$lib" | awk '{print $1}')
if [ "$got_sha256" != "$lib_sha256" ]; then
  echo "$lib: sha256 $got_sha256 does not match the pinned $lib_sha256" >&2
  echo "delete it to fetch the pinned copy, or fix the cache" >&2
  exit 2
fi
echo "liberty: $lib_name sha256 $got_sha256 (IHP-Open-PDK $IHP_PDK_COMMIT)"

# Verilog for the two block 2 modules, from the generator (engine.md section 8).
(cd "$root" && $OPAM_EXEC dune build --root . --display=quiet ./hw/bin/gen_verilog.exe)
(cd "$root" && $OPAM_EXEC dune exec --root . --display=quiet ./hw/bin/gen_verilog.exe -- pio_block1) \
  > "$build/est_pio_block1.v"
(cd "$root" && $OPAM_EXEC dune exec --root . --display=quiet ./hw/bin/gen_verilog.exe -- pio_block) \
  > "$build/est_pio_block.v"

# The ABC script for the timing run, one command per line (yosys reads it with -script).
# Same commands as the orchestrator's string, with spaces in place of the ';' and ',' used
# there. The {D} placeholder is the delay target that yosys substitutes.
cat > "$build/abc_timing.script" <<'EOF'
strash
ifraig
scorr
dc2
dretime
strash
&get -n
&dch -f
&nf {D}
&put
buffer
upsize {D}
dnsize {D}
stime -p
EOF

# run_flow NAME TOP FILES...: area and flop count (synth at D=15000), then the critical
# path (synth at D=16000 with the timing script). Results go to $build/NAME.*.
run_flow() {
  name=$1
  top=$2
  shift 2
  area_log="$build/$name.area.log"
  time_log="$build/$name.timing.log"

  yosys -q -l "$area_log" -p "read_verilog $*; synth -top $top -flatten; dfflibmap -liberty $lib; abc -liberty $lib -D 15000; opt_clean; stat -liberty $lib" >/dev/null 2>&1 || true
  if ! grep -q "Chip area for module" "$area_log"; then
    echo "$name: the area run failed, see $area_log" >&2
    exit 1
  fi
  area_um2=$(grep "Chip area for module" "$area_log" | tail -n 1 | awk '{print $NF}')
  flops=$(awk '/sg13g2_s?df/ {n += $1} END {print n+0}' "$area_log")

  if [ "${SYNTH_ONLY:-0}" != 1 ]; then
    yosys -q -l "$time_log" -p "read_verilog $*; synth -top $top -flatten; dfflibmap -liberty $lib; abc -liberty $lib -D 16000 -script $build/abc_timing.script; opt_clean" >/dev/null 2>&1 || true
    if ! grep -q "stime\|Start-point" "$time_log"; then
      echo "$name: the timing run failed, see $time_log" >&2
      exit 1
    fi
    delay_ps=$(grep "Delay =" "$time_log" | tail -n 1 | sed 's/.*Delay = *\([0-9.]*\) ps.*/\1/')
    start=$(grep "Start-point" "$time_log" | tail -n 1 | sed 's/.*Start-point = \(.*\)\.  End-point.*/\1/')
    end=$(grep "Start-point" "$time_log" | tail -n 1 | sed 's/.*End-point = \(.*\)\./\1/')
  else
    delay_ps=n/a
    start=n/a
    end=n/a
  fi

  area_mm2=$(awk -v a="$area_um2" 'BEGIN {printf "%.4f", a / 1000000}')
  if [ "$delay_ps" = n/a ]; then
    delay_ns=n/a
  else
    delay_ns=$(awk -v d="$delay_ps" 'BEGIN {printf "%.2f", d / 1000}')
  fi
  printf '%-14s  area %s mm2 (%s um2)  flops %s  delay %s ns  (%s -> %s)\n' \
    "$name" "$area_mm2" "$area_um2" "$flops" "$delay_ns" "$start" "$end"
}

echo "corner: $CORNER ($lib_name), no wire load, pre-layout"
run_flow pio_block1 pio_block "$build/est_pio_block1.v"
run_flow pio_block pio_block "$build/est_pio_block.v"
run_flow tt_top tt_um_aryankarnati_polyglot "$root/src/project.v" "$root/src/polyglot.v"
