#!/bin/sh
# Runs sby and appends its wall time to $TIMES_LOG (default build/times.log). Used as
# SBY=... by the Makefile and run_mutants.sh, to time each proof and mutant task.
# The exit status of sby is passed through.

log=${TIMES_LOG:-build/times.log}
mkdir -p "$(dirname "$log")"
start=$(date +%s)
sby "$@"
rc=$?
end=$(date +%s)
echo "$((end - start))s rc=$rc sby $*" >> "$log"
exit $rc
