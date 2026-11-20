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
  Buffer.add_string b (sprintf "%s\"movStatus\": null,\n" t);
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
