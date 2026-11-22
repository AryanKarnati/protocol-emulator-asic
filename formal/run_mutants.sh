#!/bin/sh
# Mutant check for the block 1 proofs.
#
# Each formal/mutants/<module>__<name>.sed is a one-line sed script that breaks the
# generated Verilog in formal/build/. A mutant is KILLED when one of its proof tasks
# reports a failed assertion ("Assert failed" in the log). A solver or witness error is
# not a kill. Any mutant that is not killed makes this script exit non-zero.
#
# The tasks and depths match fifo.sby and clkdiv.sby. Needs sby, yosys and the solvers on
# PATH (SBY overrides the binary). Generate the Verilog first (`make gen`).

set -eu

here=$(cd "$(dirname "$0")" && pwd)
cd "$here"

SBY=${SBY:-sby}
status=0

for sedf in mutants/*.sed; do
  name=$(basename "$sedf" .sed)
  mod=${name%%__*}
  case "$mod" in
    fifo)
      src=build/fifo_4x32.v
      tasks="flags_prove token_bmc"
      ;;
    clkdiv)
      src=build/clkdiv.v
      tasks="bmc_sym bmc_1_0 bmc_1_255 bmc_2_85"
      ;;
    *)
      echo "unknown module in mutant name: $name" >&2
      exit 2
      ;;
  esac

  dir=build/mutants/$name
  rm -rf "$dir"
  mkdir -p "$dir"
  sed -f "$sedf" "$src" > "$dir/mutant.v"
  if cmp -s "$src" "$dir/mutant.v"; then
    echo "SURVIVED $name: sed did not change the source (bad mutant)"
    status=1
    continue
  fi

  sby_file="$dir/mutant.sby"
  if [ "$mod" = fifo ]; then
    cat > "$sby_file" <<EOF
[tasks]
flags_prove
token_bmc

[options]
flags_prove: mode prove
flags_prove: depth 4
token_bmc: mode bmc
token_bmc: depth 40

[engines]
flags_prove: smtbmc z3
token_bmc: smtbmc boolector

[script]
flags_prove: read_verilog -formal fifo_harness.v
token_bmc: read_verilog -formal -DTOKEN fifo_harness.v
read_verilog -formal mutant.v
prep -top fifo_harness

[files]
$dir/mutant.v
fifo_harness.v
EOF
  else
    cat > "$sby_file" <<EOF
[tasks]
bmc_sym
bmc_1_0
bmc_1_255
bmc_2_85

[options]
bmc_sym: mode bmc
bmc_sym: depth 24
bmc_1_0: mode bmc
bmc_1_0: depth 300
bmc_1_255: mode bmc
bmc_1_255: depth 300
bmc_2_85: mode bmc
bmc_2_85: depth 300

[engines]
smtbmc boolector

[script]
bmc_sym: read_verilog -formal clkdiv_harness.v
bmc_1_0: read_verilog -formal -DFIXED_INT=1 -DFIXED_FRAC=0 clkdiv_harness.v
bmc_1_255: read_verilog -formal -DFIXED_INT=1 -DFIXED_FRAC=255 clkdiv_harness.v
bmc_2_85: read_verilog -formal -DFIXED_INT=2 -DFIXED_FRAC=85 clkdiv_harness.v
read_verilog -formal mutant.v
prep -top clkdiv_harness

[files]
$dir/mutant.v
clkdiv_harness.v
EOF
  fi

  killed=""
  for task in $tasks; do
    log_dir="$dir/$task"
    rm -rf "$log_dir"
    "$SBY" -f "$sby_file" "$task" -d "$log_dir" >/dev/null 2>&1 || true
    if [ -f "$log_dir/logfile.txt" ] && grep -q "Assert failed" "$log_dir/logfile.txt"; then
      killed="$task"
      break
    fi
  done

  if [ -n "$killed" ]; then
    echo "KILLED   $name (by task $killed)"
  else
    echo "SURVIVED $name"
    status=1
  fi
done

exit $status
