(* Prints the Verilog for module polyglot, and its submodules, to stdout. *)

open Hardcaml

let () =
  let circuit, database = Polyglot_hw.Top.circuit () in
  Rtl.print ~database Rtl.Language.Verilog circuit
;;
