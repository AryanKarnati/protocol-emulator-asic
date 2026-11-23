(* The chip mutants, by name: each is the whole-chip model with one source edit (see the dune rules
   of the mutant directories). The harness must catch every one against the RTL chip. *)

open Polyglot_chiplock

let models : (string * (module Chip_lockstep.MODEL)) list =
  [ "miso_early", (module Pgsim_mut_chip_miso_early.Chip)
  ; "commit_at_read", (module Pgsim_mut_chip_commit_at_read.Chip)
  ; "pad_od_polarity", (module Pgsim_mut_chip_pad_od_polarity.Chip)
  ; "status_swapped", (module Pgsim_mut_chip_status_swapped.Chip)
  ; "fixed_increments", (module Pgsim_mut_chip_fixed_increments.Chip)
  ]
;;
