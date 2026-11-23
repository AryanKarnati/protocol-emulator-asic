(* Prints Verilog to stdout.

   With no argument: the block 1 Tiny Tapeout top, module polyglot, and its submodules.
   With one argument, for the block 2 modules (engine.md section 8):
   - decode: the decoder alone;
   - pio_block: the block with 4 engines;
   - pio_block1: the block with 1 engine.
   Each prints the module with all of its submodules.
   Block 3 (chip.md section 3):
   - hostlink: the SPI host link alone;
   - chip: the chip with 4 engines, 64 words and the debug ports;
   - top_sram: the Tiny Tapeout top with the SRAM trial window (chip.md 8.4).
   - top [--num-sms N] [--imem-depth D]: the Tiny Tapeout top with N engines (1 to 4) and
     an instruction memory of D words (32 or 64). Defaults 4 and 64. LCU and SRAM are absent.
     With no options it prints the same Verilog as the no-argument form. *)

open Hardcaml

let usage () =
  prerr_endline "usage: gen_verilog [decode | pio_block | pio_block1 | hostlink | chip | top_sram | top [--num-sms N] [--imem-depth D]]";
  exit 2
;;

(* The options of the [top] subcommand: --num-sms N and --imem-depth D, in either order,
   each given at most once. *)
let top_options args =
  let num_sms = ref 4 and imem_depth = ref 64 in
  let rec go = function
    | [] -> ()
    | "--num-sms" :: n :: rest ->
      num_sms := (match int_of_string_opt n with Some v -> v | None -> usage ());
      go rest
    | "--imem-depth" :: d :: rest ->
      imem_depth := (match int_of_string_opt d with Some v -> v | None -> usage ());
      go rest
    | _ -> usage ()
  in
  go args;
  if !num_sms < 1 || !num_sms > 4 || (!imem_depth <> 32 && !imem_depth <> 64)
  then (
    prerr_endline "gen_verilog top: --num-sms must be 1 to 4, --imem-depth 32 or 64";
    exit 2);
  !num_sms, !imem_depth
;;

let () =
  match Sys.argv with
  | [| _ |] ->
    let circuit, database = Polyglot_hw.Top.circuit ~sram:false () in
    Rtl.print ~database Rtl.Language.Verilog circuit
  | _ when Array.length Sys.argv >= 2 && Sys.argv.(1) = "top" ->
    let num_sms, imem_depth =
      top_options (List.tl (List.tl (Array.to_list Sys.argv)))
    in
    let circuit, database = Polyglot_hw.Top.circuit ~num_sms ~imem_depth ~sram:false () in
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
