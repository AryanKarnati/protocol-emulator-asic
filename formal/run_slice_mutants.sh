#!/bin/sh
# Kill-checks for the unbounded host-link slices (hostlink_slice_*.sby, abc pdr).
#
# Each formal/mutants/hostlink_slice__<name>.sed is a one-line sed script that changes one
# net of build/hostlink.v (gen_verilog hostlink). The mutant is killed by a slice when that
# slice's abc pdr run returns FAIL ("returned FAIL" in its log). A PDR counterexample has no
# "Assert failed" line, so the FAIL status is the kill criterion here. A mutant that is not
# killed, or a sed script that changes nothing, makes this script exit non-zero.
#
# The candidate slices for each mutant are listed below; they are run in order until one
# returns FAIL. ONLY=prefix restricts the mutants.
#
# Needs make gen (build/hostlink.v) and sby + abc on PATH.

set -eu

here=$(cd "$(dirname "$0")" && pwd)
cd "$here"

SBY=${SBY:-sby}
status=0

# mutant name -> candidate slices (run in order; the first FAIL kills)
candidates() {
  case "$1" in
    A1_step5)        echo "addr_inc" ;;
    A2_F_ignored)    echo "addr_f1 addr_inc" ;;
    A3_F_bit2)       echo "addr_f1 addr_inc" ;;
    B_end_no_zero)   echo "miso rst" ;;
    C_commit_bit31)  echo "ctrl" ;;
    D1_write_bit54)  echo "ctrl" ;;
    D2_wdata_drop)   echo "data" ;;
    E_shift_in_1)    echo "miso" ;;
    G_wrap_sat)      echo "addr_inc" ;;
    H_miso_early)    echo "l1 l2 miso" ;;
    I_rst_sr)        echo "rst miso" ;;
    *) echo "unknown mutant $1" >&2; exit 2 ;;
  esac
}

for sedf in mutants/hostlink_slice__*.sed; do
  name=$(basename "$sedf" .sed)
  name=${name#hostlink_slice__}
  case "$name" in
    ${ONLY:-}*) ;;
    *) continue ;;
  esac
  dir=build/slice_mut/$name
  rm -rf "$dir"
  mkdir -p "$dir"
  sed -f "$sedf" build/hostlink.v > "$dir/hostlink.v"
  if cmp -s build/hostlink.v "$dir/hostlink.v"; then
    echo "SURVIVED $name: sed did not change the netlist (bad mutant)"
    status=1
    continue
  fi

  killed=""
  for slice in $(candidates "$name"); do
    task_sby="$dir/slice_$slice.sby"
    sed -e "s#build/hostlink.v#$dir/hostlink.v#" \
        -e "s#^hostlink_pos_slice.v\$#$here/hostlink_pos_slice.v#" \
        "hostlink_slice_$slice.sby" > "$task_sby"
    log_dir="$dir/$slice"
    rm -rf "$log_dir"
    "$SBY" -f "$task_sby" pdr -d "$log_dir" >/dev/null 2>&1 || true
    if [ -f "$log_dir/logfile.txt" ] && grep -q "returned FAIL" "$log_dir/logfile.txt"; then
      killed=$slice
      break
    fi
  done

  if [ -n "$killed" ]; then
    echo "KILLED   $name (by slice $killed)"
  else
    echo "SURVIVED $name: no candidate slice returned FAIL"
    status=1
  fi
done

exit $status
