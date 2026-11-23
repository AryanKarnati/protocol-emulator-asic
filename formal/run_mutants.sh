#!/bin/sh
# Mutant check for the formal proofs.
#
# Each formal/mutants/<family>__<name>.sed is a one-line sed script that breaks a generated
# netlist in formal/build/. The families and the proof tasks that must catch them:
#   fifo__*       block 1 FIFO: flags (fifo.sby flags_prove) and tracked token
#                 (fifo_ind.sby prove, on the debug netlist)
#   clkdiv__*     block 1 divider: the unbounded R10 proof on its debug netlist
#                 (clkdiv_dbg.sby prove_b1)
#   clkdiv_dbg__* block 2 divider: the unbounded R10 proof (clkdiv_dbg.sby prove)
#   fifo_join__* block 2 FIFO join: flags (fifo_join.sby flags_prove) and tracked token
#                 (fifo_join.sby token_bmc)
#
# A mutant is KILLED when one of its tasks reports a failed assertion ("Assert failed" in
# the log). A solver or witness error is not a kill. A sed script that does not change the
# source is a bad mutant. Any mutant that is not killed, or is bad, makes this script exit
# non-zero. ONLY=prefix runs the mutants whose name starts with it.
#
# The sed scripts depend on the generated net names (for example `assign _30 = ~ full_0;`).
# If a net name changes, the bad-mutant guard reports it.
#
# Needs sby and the solvers on PATH (SBY overrides the binary). Generate the netlists first
# (make gen).

set -eu

here=$(cd "$(dirname "$0")" && pwd)
cd "$here"

SBY=${SBY:-sby}
status=0

# Replace the DUT file in a copy of a task file, so the mutant is read instead.
#   mk_sby SRC_SBY DUT_PATTERN DUT_READ_NAME MUTANT_PATH OUT_SBY
mk_sby() {
  sed -e "s#$2#$4#" \
      -e "s#read_verilog -formal $3#read_verilog -formal $(basename "$4")#" \
      "$1" > "$5"
}

run_task() {
  # run_task SBY_FILE TASK DIR NAME
  log_dir="$3/$2"
  rm -rf "$log_dir"
  "$SBY" -f "$1" "$2" -d "$log_dir" >/dev/null 2>&1 || true
  if [ -f "$log_dir/logfile.txt" ] && grep -q "Assert failed" "$log_dir/logfile.txt"; then
    return 0
  fi
  return 1
}

# run_task_clean SBY_FILE TASK DIR NAME: a kill only if the log has a failed assertion and a
# clean engine FAIL ("DONE (FAIL"). Used by the host-link families.
run_task_clean() {
  log_dir="$3/$2"
  rm -rf "$log_dir"
  "$SBY" -f "$1" "$2" -d "$log_dir" >/dev/null 2>&1 || true
  if [ -f "$log_dir/logfile.txt" ] && grep -q "Assert failed" "$log_dir/logfile.txt" \
     && grep -q "DONE (FAIL" "$log_dir/logfile.txt"; then
    return 0
  fi
  return 1
}

for sedf in mutants/*.sed; do
  name=$(basename "$sedf" .sed)
  case "$name" in
    ${ONLY:-}*) ;;
    *) continue ;;
  esac
  family=${name%%__*}
  dir=build/mutants/$name
  rm -rf "$dir"
  mkdir -p "$dir"

  case "$family" in
    fifo)
      src=build/fifo_4x32.v
      ;;
    clkdiv)
      src=build/clkdiv.v
      ;;
    clkdiv_dbg)
      src=build/clkdiv_dbg.v
      ;;
    fifo_join)
      src=build/fifo_join.v
      ;;
    hostlink|hostlink_deep)
      src=build/hostlink.v
      ;;
    *)
      echo "unknown mutant family in $name" >&2
      exit 2
      ;;
  esac

  sed -f "$sedf" "$src" > "$dir/mutant.v"
  if cmp -s "$src" "$dir/mutant.v"; then
    echo "SURVIVED $name: sed did not change the source (bad mutant)"
    status=1
    continue
  fi

  killed=""
  case "$family" in
    fifo)
      # Flags on the base netlist; the token property on the debug netlist.
      mk_sby fifo.sby 'build/fifo_4x32.v' fifo_4x32.v "$dir/mutant.v" "$dir/flags.sby"
      if run_task "$dir/flags.sby" flags_prove "$dir" "$name"; then killed=flags_prove; fi
      if [ -z "$killed" ]; then
        python3 tools/add_fifo_debug.py "$dir/mutant.v" "$dir/mutant_dbg.v"
        mk_sby fifo_ind.sby 'build/fifo_4x32_dbg.v' fifo_4x32_dbg.v "$dir/mutant_dbg.v" "$dir/token.sby"
        if run_task "$dir/token.sby" prove "$dir" "$name"; then killed=token; fi
      fi
      ;;
    clkdiv)
      # Block 1 divider: unbounded R10 proof on the debug form of the mutant.
      python3 tools/add_clkdiv_debug.py "$dir/mutant.v" "$dir/mutant_dbg.v"
      mk_sby clkdiv_dbg.sby 'build/clkdiv_dbg_b1.v' clkdiv_dbg_b1.v "$dir/mutant_dbg.v" "$dir/r10.sby"
      if run_task "$dir/r10.sby" prove_b1 "$dir" "$name"; then killed=prove_b1; fi
      ;;
    clkdiv_dbg)
      # Block 2 divider: unbounded R10 proof.
      mk_sby clkdiv_dbg.sby 'build/clkdiv_dbg.v' clkdiv_dbg.v "$dir/mutant.v" "$dir/r10.sby"
      if run_task "$dir/r10.sby" prove "$dir" "$name"; then killed=prove; fi
      ;;
    fifo_join)
      mk_sby fifo_join.sby 'build/fifo_join.v' fifo_join.v "$dir/mutant.v" "$dir/join.sby"
      if run_task "$dir/join.sby" flags_prove "$dir" "$name"; then killed=flags_prove; fi
      # The token kill-check uses a witness-writing engine (boolector) at a small depth.
      if [ -z "$killed" ] && run_task "$dir/join.sby" token_kill "$dir" "$name"; then killed=token_kill; fi
      ;;
    hostlink|hostlink_deep)
      # A host-link kill needs a clean FAIL: the task log has "DONE (FAIL" and "Assert failed".
      # boolector sometimes ends with "Engine terminated without status" after a real failure
      # (seen on cs_stuck_high), so a boolector ERROR is retried with z3. Only a FAIL counts.
      if [ "$family" = hostlink ]; then task=bmc; else task=bmc_deep; fi
      mk_sby hostlink.sby 'build/hostlink.v' hostlink.v "$dir/mutant.v" "$dir/hostlink.sby"
      if run_task_clean "$dir/hostlink.sby" "$task" "$dir" "$name"; then killed=$task; fi
      if [ -z "$killed" ] && grep -q "terminated without status" "$dir/$task/logfile.txt" 2>/dev/null; then
        sed 's/smtbmc boolector/smtbmc z3/' "$dir/hostlink.sby" > "$dir/hostlink_z3.sby"
        if run_task_clean "$dir/hostlink_z3.sby" "$task" "$dir" "$name"; then killed="$task-z3"; fi
      fi
      ;;
  esac

  if [ -n "$killed" ]; then
    echo "KILLED   $name (by $killed)"
  else
    echo "SURVIVED $name"
    status=1
  fi
done

exit $status
