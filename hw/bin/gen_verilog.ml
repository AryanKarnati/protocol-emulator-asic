(* Prints Verilog to stdout.

   With no argument: the block 1 Tiny Tapeout top, module polyglot, and its submodules.
   With one argument, for the block 2 modules (engine.md section 8):
   - decode: the decoder alone;
   - pio_block: the block with 4 engines;
   - pio_block1: the block with 1 engine.
   Each prints the module with all of its submodules. *)

open Hardcaml

let usage () =
  prerr_endline "usage: gen_verilog [decode | pio_block | pio_block1]";
  exit 2
;;

let () =
  match Sys.argv with
  | [| _ |] ->
    let circuit, database = Polyglot_hw.Top.circuit () in
    Rtl.print ~database Rtl.Language.Verilog circuit
  | [| _; "decode" |] ->
    Rtl.print Rtl.Language.Verilog (Polyglot_hw.Decode.circuit ())
  | [| _; "pio_block" |] ->
    let circuit, database = Polyglot_hw.Pio_block.circuit_with_database ~num_sms:4 ~imem_depth:64 in
    Rtl.print ~database Rtl.Language.Verilog circuit
  | [| _; "pio_block1" |] ->
    let circuit, database = Polyglot_hw.Pio_block.circuit_with_database ~num_sms:1 ~imem_depth:64 in
    Rtl.print ~database Rtl.Language.Verilog circuit
  | _ -> usage ()
;;
