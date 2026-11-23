(* Prints Verilog to stdout.

   With no argument: the block 1 Tiny Tapeout top, module polyglot, and its submodules.
   With one argument, for the block 2 modules (engine.md section 8):
   - decode: the decoder alone;
   - pio_block: the block with 4 engines;
   - pio_block1: the block with 1 engine.
   Each prints the module with all of its submodules.
   Block 3 (chip.md section 3):
   - hostlink: the SPI host link alone;
   - chip: the chip with 4 engines, 64 words and the debug ports. *)

open Hardcaml

let usage () =
  prerr_endline "usage: gen_verilog [decode | pio_block | pio_block1 | hostlink | chip | top_sram]";
  exit 2
;;

let () =
  match Sys.argv with
  | [| _ |] ->
    let circuit, database = Polyglot_hw.Top.circuit ~sram:false () in
    Rtl.print ~database Rtl.Language.Verilog circuit
  | [| _; "top_sram" |] ->
    let circuit, database = Polyglot_hw.Top.circuit ~sram:true () in
    Rtl.print ~database Rtl.Language.Verilog circuit
  | [| _; "decode" |] ->
    Rtl.print Rtl.Language.Verilog (Polyglot_hw.Decode.circuit ())
  | [| _; "pio_block" |] ->
    let circuit, database = Polyglot_hw.Pio_block.circuit_with_database ~num_sms:4 ~imem_depth:64 in
    Rtl.print ~database Rtl.Language.Verilog circuit
  | [| _; "pio_block1" |] ->
    let circuit, database = Polyglot_hw.Pio_block.circuit_with_database ~num_sms:1 ~imem_depth:64 in
    Rtl.print ~database Rtl.Language.Verilog circuit
  | [| _; "hostlink" |] -> Rtl.print Rtl.Language.Verilog (Polyglot_hw.Hostlink.circuit ())
  | [| _; "chip" |] ->
    let circuit, database =
      Polyglot_hw.Chip.circuit_with_database ~num_sms:4 ~imem_depth:64 ~sram:false
    in
    Rtl.print ~database Rtl.Language.Verilog circuit
  | _ -> usage ()
;;
