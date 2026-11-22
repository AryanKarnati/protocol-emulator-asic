(* Output writers. The JSON layout reproduces pioasm 2.3.1's json_output.cpp byte for byte,
   including the tab indentation and the order of fields. [pioASMVersion] is the version
   of pioasm whose output format pgasm reproduces. *)

open Core
open Pio_asm

let format_version = "2.3.1"

let json_escape s =
  let b = Buffer.create (String.length s + 8) in
  String.iter s ~f:(fun c ->
    match c with
    | '"' -> Buffer.add_string b "\\\""
    | '\\' -> Buffer.add_string b "\\\\"
    | '\b' -> Buffer.add_string b "\\b"
    | '\012' -> Buffer.add_string b "\\f"
    | '\n' -> Buffer.add_string b "\\n"
    | '\r' -> Buffer.add_string b "\\r"
    | '\t' -> Buffer.add_string b "\\t"
    | c when Char.to_int c < 0x20 || Char.to_int c = 0x7F ->
      Buffer.add_string b (sprintf "\\u%04x" (Char.to_int c))
    | c -> Buffer.add_char b c);
  Buffer.contents b
;;

let bool_s b = if b then "true" else "false"

(* "publicSymbols" / "publicLabels" block. [prefix] is the indentation of the block. *)
let symbols_block b ~prefix ~key (entries : (string * int) list) =
  Buffer.add_string b (sprintf "%s\"%s\": {\n" prefix key);
  Buffer.add_string
    b
    (String.concat
       ~sep:",\n"
       (List.map entries ~f:(fun (n, v) ->
          sprintf "%s\t\"%s\": %d" prefix (json_escape n) v)));
  if not (List.is_empty entries) then Buffer.add_char b '\n';
  Buffer.add_string b (sprintf "%s},\n" prefix)
;;

let program_block b (p : out_prog) =
  let t = "\t\t\t" in
  Buffer.add_string b "\t\t{\n";
  Buffer.add_string b (sprintf "%s\"name\": \"%s\",\n" t (json_escape p.name));
  Buffer.add_string b (sprintf "%s\"pioVersion\": %d,\n" t p.version);
  Buffer.add_string b (sprintf "%s\"wrapTarget\": %d,\n" t p.wrap_target);
  Buffer.add_string b (sprintf "%s\"wrap\": %d,\n" t p.wrap);
  Buffer.add_string b (sprintf "%s\"origin\": %d,\n" t p.origin);
  Buffer.add_string b (sprintf "%s\"usedGPIORanges\": %d,\n" t p.used_gpio);
  symbols_block b ~prefix:t ~key:"publicSymbols" p.public_syms;
  symbols_block b ~prefix:t ~key:"publicLabels" p.public_labels;
  (match p.in_ with
   | Some (c, r, a, th) ->
     Buffer.add_string
       b
       (sprintf
          "%s\"in\": {\"pinCount\": %d, \"right\": %s, \"autopush\": %s, \"threshold\": %d},\n"
          t
          c
          (bool_s r)
          (bool_s a)
          th)
   | None -> Buffer.add_string b (sprintf "%s\"in\": null,\n" t));
  (match p.out_ with
   | Some (c, r, a, th) ->
     Buffer.add_string
       b
       (sprintf
          "%s\"out\": {\"pinCount\": %d, \"right\": %s, \"autopull\": %s, \"threshold\": %d},\n"
          t
          c
          (bool_s r)
          (bool_s a)
          th)
   | None -> Buffer.add_string b (sprintf "%s\"out\": null,\n" t));
  (match p.set_count with
   | Some n -> Buffer.add_string b (sprintf "%s\"setCount\": %d,\n" t n)
   | None -> Buffer.add_string b (sprintf "%s\"setCount\": null,\n" t));
  (match p.sideset with
   | Some (bits, opt, pd) ->
     Buffer.add_string
       b
       (sprintf
          "%s\"sideset\": {\"size\": %d, \"optional\": %s, \"pindirs\": %s},\n"
          t
          bits
          (bool_s opt)
          (bool_s pd))
   | None -> Buffer.add_string b (sprintf "%s\"sideset\": null,\n" t));
  (match p.mov_status with
   | Some (kind, n) ->
     let name =
       match kind with
       | 0 -> "STATUS_TX_LESSTHAN"
       | 1 -> "STATUS_RX_LESSTHAN"
       | _ -> "STATUS_IRQ_SET"
     in
     Buffer.add_string b (sprintf "%s\"movStatus\": {\"type\": \"%s\", \"n\": %d},\n" t name n)
   | None -> Buffer.add_string b (sprintf "%s\"movStatus\": null,\n" t));
  (match p.fifo with
   | Some f ->
     let name =
       match f with
       | "tx" -> "PIO_FIFO_JOIN_TX"
       | "rx" -> "PIO_FIFO_JOIN_RX"
       | "txput" -> "PIO_FIFO_JOIN_TXPUT"
       | "txget" -> "PIO_FIFO_JOIN_TXGET"
       | "putget" -> "PIO_FIFO_JOIN_PUTGET"
       | _ -> "?"
     in
     Buffer.add_string b (sprintf "%s\"fifoConfig\": \"%s\",\n" t name)
   | None -> Buffer.add_string b (sprintf "%s\"fifoConfig\": null,\n" t));
  (match p.clock with
   | Some (i, f) -> Buffer.add_string b (sprintf "%s\"clockDiv\": {\"int\": %d, \"frac\": %d},\n" t i f)
   | None -> Buffer.add_string b (sprintf "%s\"clockDiv\": null,\n" t));
  Buffer.add_string b (sprintf "%s\"instructions\": [\n" t);
  Buffer.add_string
    b
    (String.concat
       ~sep:",\n"
       (List.map2_exn p.words p.texts ~f:(fun w text ->
          sprintf "%s\t{\"hex\": \"%04X\", \"instruction\": \"%s\"}" t w (json_escape text))));
  Buffer.add_string b "\n";
  Buffer.add_string b (sprintf "%s],\n" t);
  Buffer.add_string b (sprintf "%s\"codeBlocks\": [\n" t);
  let blocks =
    List.concat_map p.code ~f:(fun (lang, contents) ->
      List.map contents ~f:(fun c ->
        sprintf
          "%s\t{\n%s\t\t\"lang\": \"%s\",\n%s\t\t\"contents\": \"%s\"\n%s\t}"
          t
          t
          (json_escape lang)
          t
          (json_escape c)
          t))
  in
  Buffer.add_string b (String.concat ~sep:",\n" blocks);
  Buffer.add_string b (sprintf "\n%s],\n" t);
  Buffer.add_string b (sprintf "%s\"langOpts\": [\n" t);
  let opts =
    List.concat_map p.lang_opts ~f:(fun (lang, pairs) ->
      List.map pairs ~f:(fun (name, value) ->
        sprintf
          "%s\t{\n%s\t\t\"lang\": \"%s\",\n%s\t\t\"name\": \"%s\",\n%s\t\t\"value\": \"%s\"\n%s\t}"
          t
          t
          (json_escape lang)
          t
          (json_escape name)
          t
          (json_escape value)
          t))
  in
  Buffer.add_string b (String.concat ~sep:",\n" opts);
  Buffer.add_string b (sprintf "\n%s]\n" t);
  Buffer.add_string b "\t\t}"
;;

let to_json (progs : out_prog list) (global_syms : (string * int) list) : string =
  let b = Buffer.create 4096 in
  Buffer.add_string b "{\n";
  Buffer.add_string b (sprintf "\t\"pioASMVersion\": \"%s\",\n" format_version);
  symbols_block b ~prefix:"\t" ~key:"publicSymbols" global_syms;
  Buffer.add_string b "\t\"programs\": [\n";
  Buffer.add_string b (String.concat ~sep:",\n" (List.map progs ~f:(fun p ->
    let pb = Buffer.create 1024 in
    program_block pb p;
    Buffer.contents pb)));
  Buffer.add_string b "\n\t]\n}\n";
  Buffer.contents b
;;

(* One 16-bit word per line, lowercase, as pioasm's hex output. *)
let to_hex (p : out_prog) : string =
  String.concat (List.map p.words ~f:(fun w -> sprintf "%04x\n" w))
;;

(* ---------- pioasm's python and c-sdk outputs ---------- *)

(* Both writers print the same header block, with their own comment syntax. *)
let banner b ~comment msg =
  let dashes = String.make (String.length msg) '-' in
  Buffer.add_string b (sprintf "%s %s %s\n" comment dashes comment);
  Buffer.add_string b (sprintf "%s %s %s\n" comment msg comment);
  Buffer.add_string b (sprintf "%s %s %s\n" comment dashes comment);
  Buffer.add_string b "\n"
;;

let autogenerated = "This file is autogenerated by pioasm version " ^ format_version ^ "; do not edit!"

(* Jump targets of a program, as the python writer finds them: the 3-bit opcode of the
   16-bit word is 0 and the target is the low 5 bits. *)
let jump_targets (p : out_prog) : int list =
  List.filter_map p.words ~f:(fun w ->
    let w = w land 0xFFFF in
    if w lsr 13 = 0 then Some (w land 0x1F) else None)
  |> List.dedup_and_sort ~compare:Int.compare
;;

(* Code blocks of [lang] in pioasm's order. pioasm prints a blank line for every language that
   has a block, and writes the contents of the blocks whose language is exactly [lang]. *)
let code_blocks b (p : out_prog) ~lang =
  List.iter p.code ~f:(fun (l, contents) ->
    Buffer.add_string b "\n";
    if String.equal l lang
    then List.iter contents ~f:(fun c -> Buffer.add_string b (c ^ "\n")))
;;

(* Lang options whose language starts with [lang], written as "name=value" in key order. *)
let lang_opt_args (p : out_prog) ~lang : string =
  List.concat_map p.lang_opts ~f:(fun (l, pairs) ->
    if String.is_prefix l ~prefix:lang then pairs else [])
  |> List.map ~f:(fun (n, v) -> n ^ "=" ^ v)
  |> String.concat ~sep:", "
;;

let to_python (progs : out_prog list) (global_syms : (string * int) list) : string =
  let b = Buffer.create 4096 in
  banner b ~comment:"#" autogenerated;
  Buffer.add_string b "import rp2\n";
  Buffer.add_string b "from machine import Pin\n";
  let symbols ~prefix values labels =
    List.iter values ~f:(fun (n, v) -> Buffer.add_string b (sprintf "%s%s = %d\n" prefix n v));
    if not (List.is_empty values) then Buffer.add_string b "\n";
    List.iter labels ~f:(fun (n, v) ->
      Buffer.add_string b (sprintf "%soffset_%s = %d\n" prefix n v));
    if not (List.is_empty labels) then Buffer.add_string b "\n"
  in
  symbols ~prefix:"" global_syms [];
  List.iter progs ~f:(fun p ->
    banner b ~comment:"#" p.name;
    symbols ~prefix:(p.name ^ "_") p.public_syms p.public_labels;
    Buffer.add_string b (sprintf "@rp2.asm_pio(%s)\n" (lang_opt_args p ~lang:"python"));
    Buffer.add_string b (sprintf "def %s():\n" p.name);
    let labels = jump_targets p in
    List.iteri p.words ~f:(fun i w ->
      if i = p.wrap_target then Buffer.add_string b "    wrap_target()\n";
      if List.mem labels i ~equal:Int.equal
      then Buffer.add_string b (sprintf "    label(\"%d\")\n" i);
      let text =
        Pio_py_disasm.disassemble
          ~labels
          ~sideset_bits:(match p.sideset with None -> 0 | Some (bits, _, _) -> bits)
          ~sideset_opt:(match p.sideset with None -> false | Some (_, opt, _) -> opt)
          w
      in
      Buffer.add_string b (sprintf "    %s # %d\n" text i);
      if i = p.wrap then Buffer.add_string b "    wrap()\n");
    Buffer.add_string b "\n";
    code_blocks b p ~lang:"python";
    Buffer.add_string b "\n");
  Buffer.contents b
;;

let to_c_sdk (progs : out_prog list) (global_syms : (string * int) list) : string =
  let b = Buffer.create 4096 in
  let add = Buffer.add_string b in
  banner b ~comment:"//" autogenerated;
  add "#pragma once\n\n";
  add "#if !PICO_NO_HARDWARE\n#include \"hardware/pio.h\"\n#endif\n\n";
  add "#ifdef __cpp_constexpr\n#define __pio_const constexpr\n#else\n#define __pio_const const\n#endif\n\n";
  let symbols ~prefix values labels =
    List.iter values ~f:(fun (n, v) -> add (sprintf "#define %s%s %d\n" prefix n v));
    if not (List.is_empty values) then add "\n";
    List.iter labels ~f:(fun (n, v) -> add (sprintf "#define %soffset_%s %du\n" prefix n v));
    if not (List.is_empty labels) then add "\n"
  in
  symbols ~prefix:"" global_syms [];
  List.iter progs ~f:(fun p ->
    banner b ~comment:"//" p.name;
    let prefix = p.name ^ "_" in
    add (sprintf "#define %swrap_target %d\n" prefix p.wrap_target);
    add (sprintf "#define %swrap %d\n" prefix p.wrap);
    add (sprintf "#define %spio_version %d\n" prefix p.version);
    add "\n";
    symbols ~prefix p.public_syms p.public_labels;
    add (sprintf "static __pio_const uint16_t %sprogram_instructions[] = {\n" prefix);
    List.iteri p.words ~f:(fun i w ->
      if i = p.wrap_target then add "            //     .wrap_target\n";
      add (sprintf "    0x%04x, // %2d: %s\n" (w land 0xFFFF) i (List.nth_exn p.texts i));
      if i = p.wrap then add "            //     .wrap\n");
    add "};\n\n";
    add "#if !PICO_NO_HARDWARE\n";
    add (sprintf "static __pio_const struct pio_program %sprogram = {\n" prefix);
    add (sprintf "    .instructions = %sprogram_instructions,\n" prefix);
    add (sprintf "    .length = %d,\n" (List.length p.words));
    add (sprintf "    .origin = %d,\n" p.origin);
    add (sprintf "    .pio_version = %spio_version,\n" prefix);
    add "#if PICO_PIO_VERSION > 0\n";
    add (sprintf "    .used_gpio_ranges = 0x%x\n" p.used_gpio);
    add "#endif\n";
    add "};\n\n";
    add (sprintf "static inline pio_sm_config %sprogram_get_default_config(uint offset) {\n" prefix);
    add "    pio_sm_config c = pio_get_default_sm_config();\n";
    add (sprintf "    sm_config_set_wrap(&c, offset + %swrap_target, offset + %swrap);\n" prefix prefix);
    (match p.in_ with
     | Some (count, right, autop, thr) ->
       add (sprintf "    sm_config_set_in_pin_count(&c, %d);\n" count);
       add (sprintf "    sm_config_set_in_shift(&c, %d, %d, %d);\n" (Bool.to_int right) (Bool.to_int autop) thr)
     | None -> ());
    (match p.out_ with
     | Some (count, right, autop, thr) ->
       add (sprintf "    sm_config_set_out_pin_count(&c, %d);\n" count);
       add (sprintf "    sm_config_set_out_shift(&c, %d, %d, %d);\n" (Bool.to_int right) (Bool.to_int autop) thr)
     | None -> ());
    (match p.set_count with
     | Some n -> add (sprintf "    sm_config_set_set_pin_count(&c, %d);\n" n)
     | None -> ());
    (match p.sideset with
     | Some (bits, opt, pindirs) ->
       add
         (sprintf
            "    sm_config_set_sideset(&c, %d, %s, %s);\n"
            bits
            (if opt then "true" else "false")
            (if pindirs then "true" else "false"))
     | None -> ());
    (match p.mov_status with
     | Some (kind, n) ->
       let ty =
         match kind with
         | 0 -> "STATUS_TX_LESSTHAN"
         | 1 -> "STATUS_RX_LESSTHAN"
         | _ -> "STATUS_IRQ_SET"
       in
       add (sprintf "    sm_config_set_mov_status(&c, %s, %d);\n" ty n)
     | None -> ());
    (match p.fifo with
     | None -> ()
     | Some f ->
       let ty =
         match f with
         | "tx" -> "PIO_FIFO_JOIN_TX"
         | "rx" -> "PIO_FIFO_JOIN_RX"
         | "txput" -> "PIO_FIFO_JOIN_TXPUT"
         | "txget" -> "PIO_FIFO_JOIN_TXGET"
         | _ -> "PIO_FIFO_JOIN_PUTGET"
       in
       add (sprintf "    sm_config_set_fifo_join(&c, %s);\n" ty));
    (match p.clock with
     | Some (i, f) -> add (sprintf "    sm_config_set_clkdiv_int_frac(&c, %d, %d);\n" i f)
     | None -> ());
    add "    return c;\n}\n";
    code_blocks b p ~lang:"c-sdk";
    add "#endif\n\n");
  Buffer.contents b
;;
