(* Semantics and encoding for pgasm, following pioasm 2.3.1 pio_assembler.cpp, pio_types.h and
   parser.yy. Statements are processed one at a time in source order, as pioasm's grammar
   actions run, so the first error reported is the same one pioasm reports.

   Scope: PIO version 0 only. Anything that needs version 1 is rejected with an error. Polyglot
   extensions (in lcu, mov crc, set lcu, .page, .lcu) are not part of pioasm and are rejected
   too. The output writers are in pio_out.ml. *)

open Core
open Pio_lex
open Pio_parse

let err loc msg = raise (Error (loc, msg))

(* ---------- State ---------- *)

type sym =
  { name : string
  ; sloc : loc
  ; spub : bool
  ; is_label : bool
  ; mutable value : expr
  ; mutable resolving : bool
  }

type io =
  { ioloc : loc
  ; count : expr
  ; right : bool
  ; autop : bool
  ; thr : expr
  ; mutable fcount : int
  ; mutable fthr : int
  }

type prog =
  { pname : string
  ; ploc : loc option
  ; mutable pio_version : int
  ; mutable origin : expr option
  ; mutable sideset : (loc * expr) option
  ; mutable sideset_opt : bool
  ; mutable sideset_pindirs : bool
  ; mutable set_count : (loc * expr) option
  ; mutable in_io : io option
  ; mutable out_io : io option
  ; mutable wrap_target : (loc * expr) option
  ; mutable wrap : (loc * expr) option
  ; mutable fifo : string
  ; mutable clk_int : int
  ; mutable clk_frac : int
  ; mutable used_gpio : int
  ; symtab : sym String.Table.t
  ; mutable syms : sym list (** reverse declaration order *)
  ; mutable insts : inst list (** reverse order *)
  ; mutable ninst : int
  ; mutable code : (string * string) list (** reverse order *)
  ; mutable lang_opts : (string * (string * string)) list (** reverse order *)
  ; mutable sideset_bits : int (** specified bits plus the enable bit when optional *)
  ; mutable sideset_max : int
  ; mutable delay_max : int
  ; mutable mov_status : (int * expr * int * loc) option (** kind, n, param, location *)
  ; mutable mov_final : (int * int) option (** kind, final_n: set by finalize *)
  }

type st =
  { global : prog
  ; mutable progs : prog list (** reverse order *)
  }

let new_prog ~name ~loc ~version =
  { pname = name
  ; ploc = loc
  ; pio_version = version
  ; origin = None
  ; sideset = None
  ; sideset_opt = true
  ; sideset_pindirs = false
  ; set_count = None
  ; in_io = None
  ; out_io = None
  ; wrap_target = None
  ; wrap = None
  ; fifo = "txrx"
  ; clk_int = 1
  ; clk_frac = 0
  ; used_gpio = 0
  ; symtab = String.Table.create ()
  ; syms = []
  ; insts = []
  ; ninst = 0
  ; code = []
  ; lang_opts = []
  ; sideset_bits = 0
  ; sideset_max = 0
  ; delay_max = 31
  ; mov_status = None
  ; mov_final = None
  }
;;

let create () = { global = new_prog ~name:"" ~loc:None ~version:0; progs = [] }
let programs st = List.rev st.progs

(* ---------- Expression evaluation (C int semantics on 32 bits) ---------- *)

let wrap32 x = ((x land 0xFFFF_FFFF) lxor 0x8000_0000) - 0x8000_0000

let reverse32 x =
  let v = ref (x land 0xFFFF_FFFF) in
  let r = ref 0 in
  for _ = 1 to 32 do
    r := (!r lsl 1) lor (!v land 1);
    v := !v lsr 1
  done;
  !r
;;

let get_symbol st (p : prog option) name =
  match Hashtbl.find st.global.symtab name with
  | Some s -> Some s
  | None ->
    (match p with
     | Some p -> Hashtbl.find p.symtab name
     | None -> None)
;;

let rec eval st (p : prog) (e : expr) : int =
  match e with
  | Lit n -> n
  | Name (l, n) ->
    (match get_symbol st (Some p) n with
     | None -> err l (sprintf "undefined symbol '%s'" n)
     | Some sym ->
       if sym.resolving
       then err l (sprintf "circular dependency in definition of '%s'" n);
       sym.resolving <- true;
       let v =
         try eval st p sym.value with
         | ex ->
           sym.resolving <- false;
           raise ex
       in
       sym.resolving <- false;
       v)
  | Bin (op, a, b) ->
    let x = eval st p a in
    let y = eval st p b in
    (match op with
     | Add -> wrap32 (x + y)
     | Sub -> wrap32 (x - y)
     | Mul -> wrap32 (x * y)
     | Div ->
       if y = 0 then err (expr_loc a) "division by zero";
       x / y
     | And -> x land y
     | Or -> x lor y
     | Xor -> x lxor y
     | Shl -> wrap32 (x lsl (y land 31))
     | Shr -> x asr (y land 31))
  | Neg a -> wrap32 (-eval st p a)
  | Rev a -> wrap32 (reverse32 (eval st p a))

and expr_loc = function
  | Name (l, _) -> l
  | Bin (_, a, _) | Neg a | Rev a -> expr_loc a
  | Lit _ -> { file = "?"; line = 0; col = 0 }
;;

(* ---------- Symbols and program lookup ---------- *)

let loc_str = loc_to_string

(* pioasm's get_current_program: the program that a directive or instruction applies to. *)
let current_prog st loc req ~before ~disallow_global : prog =
  match st.progs with
  | [] ->
    if disallow_global then err loc (req ^ " is invalid outside of a program") else st.global
  | p :: _ ->
    if before && p.ninst > 0 then err loc (req ^ " must precede any program instructions");
    p
;;

let add_symbol st (p : prog) (s : sym) =
  match get_symbol st (Some p) s.name with
  | Some existing ->
    let msg =
      if Bool.( <> ) s.is_label existing.is_label
      then
        sprintf
          "'%s' was already defined as a %s at %s"
          s.name
          (if existing.is_label then "label" else "value")
          (loc_str existing.sloc)
      else if s.is_label
      then sprintf "label '%s' was already defined at %s" s.name (loc_str existing.sloc)
      else sprintf "'%s' was already defined at %s" s.name (loc_str existing.sloc)
    in
    err s.sloc msg
  | None ->
    Hashtbl.set p.symtab ~key:s.name ~data:s;
    p.syms <- s :: p.syms
;;

(* ---------- Instruction validation (pioasm check_version and pre_validate) ---------- *)

let need_v1 (p : prog) loc feature =
  if p.pio_version < 1
  then err loc (sprintf "PIO version 1 is required for '%s'" feature)
;;

let check_inst_version (p : prog) (i : inst) =
  match i.kind with
  | K_wait (_, W_jmppin _) -> need_v1 p i.iloc "wait jmppin"
  | K_wait (_, W_irq (_, 1)) | K_irq (_, _, 1) -> need_v1 p i.iloc "irq prev"
  | K_wait (_, W_irq (_, 3)) | K_irq (_, _, 3) -> need_v1 p i.iloc "irq next"
  | K_mov (M_pindirs, _, _) -> need_v1 p i.iloc "mov pindirs"
  | K_mov (M_rxfifo _, _, _) | K_mov (_, _, S_rxfifo _) -> need_v1 p i.iloc "mov rxfifo[], "
  | _ -> ()
;;

let add_instruction (p : prog) (i : inst) =
  check_inst_version p i;
  if p.ninst >= 32
  then
    err
      i.iloc
      "program instruction limit of 32 instruction(s) exceeded";
  (match p.sideset, p.sideset_opt, i.sideset with
   | Some (sl, _), false, None ->
     err
       i.iloc
       (sprintf
          "instruction requires 'side' to specify side set value for the instruction because \
           non optional sideset was specified for the program at %s"
          (loc_str sl))
   | _ -> ());
  (match i.kind with
   | K_push _ ->
     if not (List.mem [ "rx"; "txrx" ] p.fifo ~equal:String.equal)
     then
       err
         i.iloc
         "FIFO must be configured for 'txrx' or 'rx' to use this instruction"
   | _ -> ());
  p.insts <- i :: p.insts;
  p.ninst <- p.ninst + 1
;;

(* ---------- Directives ---------- *)

let process_dir st (d : dir) =
  match d with
  | D_program (l, name) ->
    if List.exists st.progs ~f:(fun p -> String.equal p.pname name)
    then err l (sprintf "program %s already exists" name);
    let p = new_prog ~name ~loc:(Some l) ~version:st.global.pio_version in
    st.progs <- p :: st.progs
  | D_define (_, sd, e) ->
    let p = current_prog st sd.sloc ".define" ~before:false ~disallow_global:false in
    add_symbol
      st
      p
      { name = sd.sname
      ; sloc = sd.sloc
      ; spub = sd.spublic
      ; is_label = false
      ; value = e
      ; resolving = false
      }
  | D_origin (l, e) ->
    let p = current_prog st l ".origin" ~before:true ~disallow_global:true in
    p.origin <- Some e
  | D_pio_version (l, v) ->
    if v < 0 || v > 1
    then err l "only PIO versions 0 (rp2040) and 1 (rp2350) are supported";
    let p = current_prog st l ".pio_version" ~before:true ~disallow_global:false in
    p.pio_version <- v
  | D_side_set (l, v, opt, pindirs) ->
    let p = current_prog st l ".side_set" ~before:true ~disallow_global:true in
    p.sideset <- Some (l, v);
    p.sideset_opt <- opt;
    p.sideset_pindirs <- pindirs
  | D_in (l, count, right, autop, thr) ->
    let p = current_prog st l ".in" ~before:true ~disallow_global:true in
    p.in_io
    <- Some { ioloc = l; count; right; autop; thr; fcount = -1; fthr = -1 }
  | D_out (l, count, right, autop, thr) ->
    let p = current_prog st l ".out" ~before:true ~disallow_global:true in
    p.out_io
    <- Some { ioloc = l; count; right; autop; thr; fcount = -1; fthr = -1 }
  | D_set (l, v) ->
    let p = current_prog st l ".set" ~before:true ~disallow_global:true in
    p.set_count <- Some (l, v)
  | D_wrap_target l ->
    let p = current_prog st l ".wrap_target" ~before:false ~disallow_global:true in
    (match p.wrap_target with
     | Some (old, _) ->
       err l (sprintf ".wrap_target was already specified at %s" (loc_str old))
     | None -> p.wrap_target <- Some (l, Lit p.ninst))
  | D_wrap l ->
    let p = current_prog st l ".wrap" ~before:false ~disallow_global:true in
    (match p.wrap with
     | Some (old, _) -> err l (sprintf ".wrap was already specified at %s" (loc_str old))
     | None ->
       if p.ninst = 0
       then err l ".wrap cannot be placed before the first program instruction";
       p.wrap <- Some (l, Lit (p.ninst - 1)))
  | D_lang_opt (l, lang, name, value) ->
    let p = current_prog st l ".lang_opt" ~before:false ~disallow_global:true in
    p.lang_opts <- (lang, (name, value)) :: p.lang_opts
  | D_clock_div (l, f) ->
    let p = current_prog st l ".clock_div" ~before:false ~disallow_global:true in
    if Float.( < ) f 1.0 || Float.( >= ) f 65536.0
    then err l "clock divider must be between 1 and 65535";
    let int_part = Int.of_float f land 0xFFFF in
    p.clk_int <- int_part;
    if int_part = 0
    then p.clk_frac <- 0
    else
      (* pioasm subtracts the previous fraction here; reproduced as written *)
      p.clk_frac <- Int.of_float ((f -. Float.of_int p.clk_frac) *. 256.0) land 0xFF
  | D_fifo (l, name) ->
    let p = current_prog st l ".fifo" ~before:true ~disallow_global:true in
    (match name with
     | "txput" -> need_v1 p l "txput"
     | "txget" -> need_v1 p l "rxput" (* pioasm's own wording for txget *)
     | "putget" -> need_v1 p l "putget"
     | _ -> ());
    p.fifo <- name
  | D_mov_status (l, ms) ->
    let p = current_prog st l ".mov_status" ~before:true ~disallow_global:true in
    p.mov_status <- Some (ms.ms_kind, ms.ms_n, ms.ms_param, l)
;;

(* ---------- Source statements ---------- *)

let dir_loc = function
  | D_program (l, _)
  | D_define (l, _, _)
  | D_origin (l, _)
  | D_pio_version (l, _)
  | D_side_set (l, _, _, _)
  | D_in (l, _, _, _, _)
  | D_out (l, _, _, _, _)
  | D_set (l, _)
  | D_wrap_target l
  | D_wrap l
  | D_lang_opt (l, _, _, _)
  | D_clock_div (l, _)
  | D_fifo (l, _)
  | D_mov_status (l, _) -> l
;;

let process_line st (line : line) =
  (match line.label with
   | None -> ()
   | Some sd ->
     let req = match line.body with B_inst _ -> "instruction" | _ -> "label" in
     let p = current_prog st sd.sloc req ~before:false ~disallow_global:true in
     add_symbol
       st
       p
       { name = sd.sname
       ; sloc = sd.sloc
       ; spub = sd.spublic
       ; is_label = true
       ; value = Lit p.ninst
       ; resolving = false
       });
  match line.body with
  | B_none -> ()
  | B_dir d -> process_dir st d
  | B_inst i ->
    let p = current_prog st i.iloc "instruction" ~before:false ~disallow_global:true in
    add_instruction p i

let process_code st (loc : loc) (lang : string) (contents : string) =
  let p = current_prog st loc "code block" ~before:false ~disallow_global:false in
  p.code <- (lang, contents) :: p.code
;;

(* ---------- Finalisation (pioasm program::finalize) ---------- *)

let finalize st (p : prog) =
  (match p.mov_status with
   | None -> ()
   | Some (kind, e, param, l) ->
     let n = eval st p e in
     if kind = 2
     then (
       if n > 7 then err l "irq number should be >= 0 and <= 7";
       p.mov_final <- Some (kind, (param * 8) + n))
     else (
       if n > 31 then err l "fido depth should be >= 0 and <= 31";
       p.mov_final <- Some (kind, n)));
  if p.pio_version = 1
  then
    err
      (Option.value p.ploc ~default:{ file = "?"; line = 0; col = 0 })
      (sprintf "PIO version 1 is not supported by pgasm yet (program %s)" p.pname);
  (match p.in_io with
   | None -> ()
   | Some io ->
     io.fcount <- eval st p io.count;
     if io.fcount <> 32
     then err io.ioloc "in pin count must be 32 for PIO version 0";
     io.fthr <- eval st p io.thr;
     if io.fthr < 1 || io.fthr > 32 then err io.ioloc "threshold should be >= 1 and <= 32");
  (match p.out_io with
   | None -> ()
   | Some io ->
     io.fcount <- eval st p io.count;
     if io.fcount < 0 || io.fcount > 32
     then err io.ioloc "out pin count should be >= 0 and <= 32";
     io.fthr <- eval st p io.thr;
     if io.fthr < 1 || io.fthr > 32 then err io.ioloc "threshold should be >= 1 and <= 32");
  (match p.set_count with
   | None -> ()
   | Some (l, e) ->
     let n = eval st p e in
     if n < 0 || n > 5 then err l "set pin count should be >= 0 and <= 5");
  match p.sideset with
  | Some (l, e) ->
    let bits = eval st p e in
    if bits < 0 then err l "number of side set bits must be positive";
    p.sideset_max <- (1 lsl bits) - 1;
    let incl = if p.sideset_opt then bits + 1 else bits in
    p.sideset_bits <- incl;
    if incl > 5
    then
      err
        l
        (if p.sideset_opt
         then "maximum number of side set bits with optional is 4"
         else "maximum number of side set bits is 5");
    p.delay_max <- (1 lsl (5 - incl)) - 1
  | None ->
    p.sideset_max <- 0;
    p.delay_max <- 31
;;

(* ---------- Encoding (pioasm raw_encode and instruction::encode) ---------- *)

let jmp_cond_code = function
  | Always -> 0
  | Not_x -> 1
  | X_dec -> 2
  | Not_y -> 3
  | Y_dec -> 4
  | X_ne_y -> 5
  | Pin_cond -> 6
  | Not_osre -> 7
;;

let in_src_code = function
  | I_pins -> 0
  | I_x -> 1
  | I_y -> 2
  | I_null -> 3
  | I_status -> 5
  | I_isr -> 6
  | I_osr -> 7
;;

let out_dst_code = function
  | O_pins -> 0
  | O_x -> 1
  | O_y -> 2
  | O_null -> 3
  | O_pindirs -> 4
  | O_pc -> 5
  | O_isr -> 6
  | O_exec -> 7
;;

let mov_dst_code = function
  | M_pins -> 0
  | M_x -> 1
  | M_y -> 2
  | M_exec -> 4
  | M_pc -> 5
  | M_isr -> 6
  | M_osr -> 7
  | M_pindirs | M_rxfifo _ -> assert false (* rejected by check_inst_version *)
;;

let mov_src_code = function
  | S_pins -> 0
  | S_x -> 1
  | S_y -> 2
  | S_null -> 3
  | S_status -> 5
  | S_isr -> 6
  | S_osr -> 7
  | S_rxfifo _ -> assert false
;;

let mov_op_code = function
  | Op_none -> 0
  | Op_invert -> 1
  | Op_reverse -> 2
;;

let set_dst_code = function
  | T_pins -> 0
  | T_x -> 1
  | T_y -> 2
  | T_pindirs -> 4
;;

(* Raw (type, arg1, arg2) as pioasm's raw_encode produces it. *)
let raw_encode st (p : prog) (i : inst) : int * int * int =
  let ev e = eval st p e in
  match i.kind with
  | K_nop -> 5, 2, 2 (* mov y, y *)
  | K_mov (dst, op, src) ->
    5, mov_dst_code dst, mov_src_code src lor (mov_op_code op lsl 3)
  | K_jmp (cond, target) ->
    let dest = ev target in
    (* a literal target has no location of its own: report the instruction *)
    let tloc =
      match target with
      | Lit _ -> i.iloc
      | _ -> expr_loc target
    in
    if dest < 0 then err tloc "jmp target address must be positive";
    if dest >= p.ninst
    then
      err
        tloc
        (sprintf "jmp target address %d is beyond the end of the program" dest);
    0, jmp_cond_code cond, dest
  | K_wait (pol_e, src) ->
    let pol = ev pol_e in
    if pol > 1 || pol < 0 then err (expr_loc pol_e) "'wait' polarity must be 0 or 1";
    (match src with
     | W_irq (e, itype) ->
       let n = ev e in
       if n > 7 || n < 0 then err (expr_loc e) "irq number must be must be >= 0 and <= 7";
       1, (pol lsl 2) lor 2, n lor (itype lsl 3)
     | W_gpio e ->
       let n = ev e in
       if n > 31 || n < 0
       then
         err
           (expr_loc e)
           "absolute GPIO number must be must be >= 0 and <= 31";
       let bitmap = 1 lsl (n lsr 4) in
       if bitmap = 4 && p.used_gpio land 1 <> 0
       then err (expr_loc e) "absolute GPIO number must be must be >= 0 and <= 31 as a GPIO number <16 has already been used";
       if bitmap = 1 && p.used_gpio land 4 <> 0
       then err (expr_loc e) "absolute GPIO number must be must be >= 16 and <= 47 as a GPIO number >32 has already been used";
       p.used_gpio <- p.used_gpio lor bitmap;
       1, (pol lsl 2) lor 0, n
     | W_pin e ->
       let n = ev e in
       if n > 31 || n < 0 then err (expr_loc e) "pin number must be must be >= 0 and <= 31";
       1, (pol lsl 2) lor 1, n
     | W_jmppin _ -> assert false (* rejected by check_inst_version *))
  | K_in (src, count) ->
    let v = ev count in
    if v < 1 || v > 32 then err (expr_loc count) "'in' bit count must be >= 1 and <= 32";
    2, in_src_code src, v land 0x1f
  | K_out (dst, count) ->
    let v = ev count in
    if v < 1 || v > 32 then err (expr_loc count) "'out' bit count must be >= 1 and <= 32";
    3, out_dst_code dst, v land 0x1f
  | K_push (iffull, block) ->
    4, (if block then 1 else 0) lor (if iffull then 2 else 0), 0
  | K_pull (ifempty, block) ->
    4, (if block then 1 else 0) lor (if ifempty then 2 else 0) lor 4, 0
  | K_irq (m, e, itype) ->
    let n = ev e in
    if n > 7 || n < 0 then err (expr_loc e) "irq number must be must be >= 0 and <= 7";
    let mcode =
      match m with
      | Irq_set -> 0
      | Irq_set_wait -> 1
      | Irq_clear -> 2
    in
    6, mcode, n lor (itype lsl 3)
  | K_set (dst, e) ->
    let v = ev e in
    if v < 0 || v > 31 then err (expr_loc e) "'set' bit count must be >= 0 and <= 31";
    7, set_dst_code dst, v
  | K_word _ -> assert false
;;

let encode_inst st (p : prog) (i : inst) : int =
  match i.kind with
  | K_word e ->
    let v = eval st p e in
    if v < 0 || v > 0xFFFF then err (expr_loc e) ".word value must be a positive 16 bit value";
    v
  | _ ->
    let typ, arg1, arg2 = raw_encode st p i in
    let delay =
      match i.delay with
      | None -> 0
      | Some e ->
        let d = eval st p e in
        if d < 0 then err (expr_loc e) "instruction delay must be positive";
        if d > p.delay_max
        then
          if p.delay_max = 31
          then err (expr_loc e) "instruction delay must be <= 31"
          else
            err
              (expr_loc e)
              (sprintf
                 "the instruction delay limit is %d because of the side set specified at %s"
                 p.delay_max
                 (match p.sideset with
                  | Some (l, _) -> loc_str l
                  | None -> "?"));
        d
    in
    let side =
      match i.sideset with
      | None -> 0
      | Some e ->
        let v = eval st p e in
        if v < 0 then err (expr_loc e) "side set value must be >=0";
        if v > p.sideset_max
        then
          err
            (expr_loc e)
            (sprintf
               "the maximum side set value is %d based on the configuration specified at %s"
               p.sideset_max
               (match p.sideset with
                | Some (l, _) -> loc_str l
                | None -> "?"));
        let s = v lsl (5 - p.sideset_bits) in
        if p.sideset_opt then s lor 0x10 else s
    in
    (typ lsl 13) lor ((delay lor side) lsl 8) lor (arg1 lsl 5) lor (arg2 land 0x1F)
    lor ((arg2 lsr 5) lsl 16)
;;

(* ---------- Output record ---------- *)

type out_prog =
  { name : string
  ; version : int
  ; wrap_target : int
  ; wrap : int
  ; origin : int
  ; used_gpio : int
  ; public_syms : (string * int) list
  ; public_labels : (string * int) list
  ; in_ : (int * bool * bool * int) option
  ; out_ : (int * bool * bool * int) option
  ; set_count : int option
  ; sideset : (int * bool * bool) option
  ; mov_status : (int * int) option (** kind, final_n *)
  ; fifo : string option
  ; clock : (int * int) option
  ; words : int list
  ; texts : string list
  ; code : (string * string list) list
  ; lang_opts : (string * (string * string) list) list
  }

(* Groups (key, value) pairs by key, keys in ascending order, values in insertion order. *)
let group_sorted (pairs : (string * 'a) list) : (string * 'a list) list =
  let keys = List.dedup_and_sort ~compare:String.compare (List.map pairs ~f:fst) in
  List.map keys ~f:(fun k ->
    k, List.filter_map pairs ~f:(fun (k', v) -> if String.equal k k' then Some v else None))
;;

let compile_prog st (p : prog) : out_prog =
  finalize st p;
  let insts = List.rev p.insts in
  let words = List.map insts ~f:(fun i -> encode_inst st p i) in
  let wrap =
    match p.wrap with
    | Some (_, e) -> eval st p e
    | None -> Int.max (p.ninst - 1) 0
  in
  let wrap_target =
    match p.wrap_target with
    | Some (l, e) ->
      let v = eval st p e in
      if v >= p.ninst
      then err l ".wrap_target cannot be placed after the last program instruction";
      v
    | None -> 0
  in
  let origin =
    match p.origin with
    | Some e -> eval st p e
    | None -> -1
  in
  let io_out = function
    | None -> None
    | Some io -> Some (io.fcount, io.right, io.autop, io.fthr)
  in
  let public = List.rev p.syms |> List.filter ~f:(fun s -> s.spub) in
  let syms_of want_label =
    List.filter_map public ~f:(fun s ->
      if Bool.equal s.is_label want_label then Some (s.name, eval st p s.value) else None)
  in
  let code = List.rev p.code in
  let lang_opts = List.rev p.lang_opts in
  { name = p.pname
  ; version = p.pio_version
  ; wrap_target
  ; wrap
  ; origin
  ; used_gpio = p.used_gpio
  ; public_syms = syms_of false
  ; public_labels = syms_of true
  ; in_ = io_out p.in_io
  ; out_ = io_out p.out_io
  ; set_count =
      (match p.set_count with
       | None -> None
       | Some (_, e) -> Some (eval st p e))
  ; sideset =
      (match p.sideset with
       | None -> None
       | Some _ -> Some (p.sideset_bits, p.sideset_opt, p.sideset_pindirs))
  ; mov_status = p.mov_final
  ; fifo = (if String.equal p.fifo "txrx" then None else Some p.fifo)
  ; clock = (if p.clk_int <> 1 || p.clk_frac <> 0 then Some (p.clk_int, p.clk_frac) else None)
  ; words
  ; texts =
      (* pioasm's disassembler: side-set bits are 0 when no .side_set was given *)
      List.map words ~f:(fun w ->
        Pio_disasm.disassemble
          w
          ~sideset_bits:(if Option.is_none p.sideset then 0 else p.sideset_bits)
          ~sideset_opt:p.sideset_opt)
  ; code = group_sorted code
  ; lang_opts =
      group_sorted lang_opts
  }
;;

(* Parse and assemble a whole file. Raises [Pio_lex.Error] on the first error. *)
let assemble ~file (text : string) : out_prog list * (string * int) list =
  let st = create () in
  Pio_source.iter_events ~file text ~f:(function
    | Pio_source.Line (_, line) -> process_line st line
    | Pio_source.Code (loc, lang, contents) -> process_code st loc lang contents);
  let progs = programs st in
  if List.is_empty progs then Stdlib.prerr_endline "warning: input contained no programs";
  let global_syms =
    List.rev st.global.syms
    |> List.filter ~f:(fun s -> s.spub)
    |> List.map ~f:(fun s -> s.name, eval st st.global s.value)
  in
  List.map progs ~f:(compile_prog st), global_syms
;;
