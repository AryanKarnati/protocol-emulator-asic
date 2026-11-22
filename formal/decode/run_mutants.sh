#!/bin/sh
# Kill-check for the Verilog decoder equivalence. Each formal/decode/mutants/*.sed breaks
# formal/build/decode.v by one hand-written edit. The Verilator exhaustive run must then
# report a mismatch (exit status 1). A mutant that is not killed, or that does not apply,
# makes this script exit non-zero.
#
# Needs verilator and a C++ compiler; decode.v and decode_expected.txt come from
# `make -C formal decode`.

set -eu

here=$(cd "$(dirname "$0")" && pwd)
build="$here/../build"
status=0

for sedf in "$here"/mutants/*.sed; do
  name=$(basename "$sedf" .sed)
  dir="$build/decode_mut_$name"
  rm -rf "$dir"
  mkdir -p "$dir"
  sed -f "$sedf" "$build/decode.v" > "$dir/decode.v"
  if cmp -s "$build/decode.v" "$dir/decode.v"; then
    echo "SURVIVED $name: the edit did not apply (bad mutant)"
    status=1
    continue
  fi
  (cd "$dir" && verilator --cc --exe --build -j 0 -Wno-fatal -Wno-lint -Wno-style \
      --top-module decode -Mdir obj decode.v "$here/verilator/tb.cpp" -o vdecode >/dev/null 2>&1)
  if "$dir/obj/vdecode" "$build/decode_expected.txt" >"$dir/run.log" 2>&1; then
    echo "SURVIVED $name: the exhaustive check passed"
    status=1
  else
    echo "KILLED   $name ($(grep -c MISMATCH "$dir/run.log") printed mismatches; see $dir/run.log)"
  fi
done

exit $status
