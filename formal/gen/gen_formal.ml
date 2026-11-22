(* Prints standalone Verilog for one block 1 module under proof.
   Usage: gen_formal.exe (fifo_4x32 | clkdiv)
   The module is flat (no submodules), so each file is a single SBY top. *)

open Hardcaml

module Fifo4 = Polyglot_hw.Fifo.Make (struct
    let width = 32
    let depth = 4
  end)

module Fifo_io = Circuit.With_interface (Fifo4.I) (Fifo4.O)
module Clkdiv_io = Circuit.With_interface (Polyglot_hw.Clkdiv.I) (Polyglot_hw.Clkdiv.O)

module Clkdiv_dbg_io =
  Circuit.With_interface (Polyglot_hw.Clkdiv.I) (Polyglot_hw.Clkdiv.O_dbg)

module Fifo_join_io = Circuit.With_interface (Polyglot_hw.Fifo_join.I) (Polyglot_hw.Fifo_join.O)

let () =
  let scope = Scope.create () in
  let circuit =
    match Sys.argv with
    | [| _; "fifo_4x32" |] -> Fifo_io.create_exn ~name:"fifo_4x32" (Fifo4.create scope)
    | [| _; "clkdiv" |] ->
      Clkdiv_io.create_exn ~name:"clkdiv" (Polyglot_hw.Clkdiv.create scope)
    | [| _; "clkdiv_dbg" |] ->
      Clkdiv_dbg_io.create_exn ~name:"clkdiv_dbg" (Polyglot_hw.Clkdiv.create_dbg scope)
    | [| _; "fifo_join" |] ->
      Fifo_join_io.create_exn ~name:"fifo_join" (Polyglot_hw.Fifo_join.create scope)
    | _ ->
      prerr_endline "usage: gen_formal.exe (fifo_4x32 | clkdiv | clkdiv_dbg | fifo_join)";
      exit 2
  in
  Rtl.print Rtl.Language.Verilog circuit
;;
