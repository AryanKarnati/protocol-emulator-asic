(* Tests for polyglot_isa. Run with: opam exec --switch=polyglot -- dune test --root . *)

open Core
open Polyglot_isa

let failures = ref 0

let check name cond =
  if not cond
  then (
    incr failures;
    printf "FAIL: %s\n" name)
;;

(* 1. Exhaustive: every 16-bit word is total and round-trips. *)
let test_exhaustive () =
  let illegal = ref 0 in
  for w = 0 to 0xFFFF do
    let t = Isa.decode w in
    if not (Isa.is_legal t) then Int.incr illegal;
    if Isa.encode t <> w
    then (
      incr failures;
      printf "FAIL: encode (decode 0x%04x) = 0x%04x\n" w (Isa.encode t))
  done;
  (* 23040 Illegal words, plus the 1024 words with IN source 101 (in status), which are
     decoded to In_status but are not legal in version 0 (see Isa.is_legal). *)
  check "illegal count is 23040 + 1024" (!illegal = 23040 + 1024);
  printf "exhaustive: 65536 words round-trip; %d not legal in version 0\n" !illegal
;;

(* 2. Hand-checked encodings. Each word comes from the pioasm 2.3.1 assembler (oracle) for
   the instruction text in the comment. *)
let known =
  let open Isa in
  [ 0xC007, Irq { delay_side = 0; clear = false; wait = false; index = 7; rel = false } (* irq set 7 *)
  ; 0xC013, Irq { delay_side = 0; clear = false; wait = false; index = 3; rel = true } (* irq set 3 rel *)
  ; 0xC021, Irq { delay_side = 0; clear = false; wait = true; index = 1; rel = false } (* irq wait 1 *)
  ; 0x209F, Wait { delay_side = 0; polarity = true; source = Wsrc_gpio 31 } (* wait 1 gpio 31 *)
  ; 0x20D3, Wait { delay_side = 0; polarity = true; source = Wsrc_irq { index = 3; rel = true } }
  ; 0x20A3, Wait { delay_side = 0; polarity = true; source = Wsrc_pin 3 } (* wait 1 pin 3 *)
  ; 0x4020, In { delay_side = 0; source = In_x; bit_count = 32 } (* in x, 32 *)
  ; 0x4065, In { delay_side = 0; source = In_null; bit_count = 5 } (* in null, 5 *)
  ; 0x40A5, In { delay_side = 0; source = In_status; bit_count = 5 } (* in status, 5 *)
  ; 0x6080, Out { delay_side = 0; dest = Out_pindirs; bit_count = 32 } (* out pindirs, 32 *)
  ; 0x60E8, Out { delay_side = 0; dest = Out_exec; bit_count = 8 } (* out exec, 8 *)
  ; 0x8060, Push { delay_side = 0; if_full = true; block = true } (* push iffull block *)
  ; 0x8020, Push { delay_side = 0; if_full = false; block = true } (* push *)
  ; 0x80C0, Pull { delay_side = 0; if_empty = true; block = false } (* pull ifempty noblock *)
  ; 0x80A0, Pull { delay_side = 0; if_empty = false; block = true } (* pull *)
  ; 0xA025, Mov { delay_side = 0; dest = Mov_x; op = Op_none; source = Ms_status } (* mov x, status *)
  ; 0xA02D, Mov { delay_side = 0; dest = Mov_x; op = Op_invert; source = Ms_status } (* mov x, ~status *)
  ; 0xA081, Mov { delay_side = 0; dest = Mov_exec; op = Op_none; source = Ms_x } (* mov exec, x *)
  ; 0xA0C7, Mov { delay_side = 0; dest = Mov_isr; op = Op_none; source = Ms_osr } (* mov isr, osr *)
  ; 0xA0E6, Mov { delay_side = 0; dest = Mov_osr; op = Op_none; source = Ms_isr } (* mov osr, isr *)
  ; 0xE03F, Set { delay_side = 0; dest = Set_x; data = 31 } (* set x, 31 *)
  ; 0xE083, Set { delay_side = 0; dest = Set_pindirs; data = 3 } (* set pindirs, 3 *)
  ; 0x008C, Jmp { delay_side = 0; cond = Y_dec; addr = 12 } (* jmp y--, 12 *)
  ; 0x0003, Jmp { delay_side = 0; cond = Always; addr = 3 } (* jmp 3 *)
  (* Polyglot extensions (DESIGN.md 9.2). pioasm does not assemble these; the words follow the
     encoding table in DESIGN.md 9.1, and to_string is checked in test_to_string. *)
  ; 0x4088, In { delay_side = 0; source = In_lcu; bit_count = 8 } (* in lcu, 8 *)
  ; 0xA024, Mov { delay_side = 0; dest = Mov_x; op = Op_none; source = Ms_crc } (* mov x, crc *)
  ; 0xA02C, Mov { delay_side = 0; dest = Mov_x; op = Op_invert; source = Ms_crc } (* mov x, ~crc *)
  ; 0xE070, Set { delay_side = 0; dest = Set_lcu; data = 16 } (* set lcu, 16 *)
  ]
;;

let test_known () =
  List.iter known ~f:(fun (w, expected) ->
    let got = Isa.decode w in
    if not (Isa.equal got expected)
    then (
      incr failures;
      printf "FAIL: decode 0x%04x = %s\n" w (Sexp.to_string (Isa.sexp_of_t got)));
    if Isa.encode expected <> w
    then (
      incr failures;
      printf "FAIL: encode %s <> 0x%04x\n" (Sexp.to_string (Isa.sexp_of_t expected)) w));
  printf "known encodings: %d checked\n" (List.length known)
;;

(* Reserved words in version 0 must come back as Illegal, not as a guess. *)
let test_reserved () =
  let illegal w = match Isa.decode w with Isa.Illegal _ -> true | _ -> false in
  check "mov dst 011 (pindirs, v1) is illegal" (illegal 0xA061);
  check "mov op 11 is illegal" (illegal 0xA01F);
  check "set dst 101 is illegal" (illegal 0xE0A0);
  check "wait src 11 (jmppin, v1) is illegal" (illegal 0x20E0);
  check "irq with bit 7 set is illegal" (illegal 0xC087);
  check "irq prev (bit 3, v1) is illegal" (illegal 0xC009);
  check "push with bits 4:0 set (mov rxfifo, v1) is illegal" (illegal 0x8010);
  check "in src 100 is LCU, not illegal" (not (illegal 0x4080));
  (* IN source 101: pioasm assembles `in status`, DESIGN.md 9.1 says reserved. The decoded
     form stays In_status so it can be printed, but the legality predicate says reserved. *)
  check "in src 101 decodes to In_status" (Isa.equal (Isa.decode 0x40A5) (Isa.In { delay_side = 0; source = Isa.In_status; bit_count = 5 }));
  check "in src 101 is not legal in v0" (not (Isa.is_legal (Isa.decode 0x40A5)));
  check "in status prints as pioasm does" (String.equal (Isa.to_string (Isa.decode 0x40A5)) "in     status, 5");
  check "in lcu is legal" (Isa.is_legal (Isa.decode 0x4080));
  check "reserved mov dst 011 is not legal" (not (Isa.is_legal (Isa.decode 0xA061)));
  check "mov src 100 is CRC, not illegal" (not (illegal 0xA024));
  check "set dst 011 is LCU, not illegal" (not (illegal 0xE060));
  (* Complete reserved set, version 0 (see the comment on Isa.decode). One word per class. *)
  check "WAIT irq with index bit 3 (prev/next, beyond 9.1) is illegal" (illegal 0x20C8);
  check "MOV op 11 is illegal" (illegal 0xA018);
  check "SET dst 110 is illegal" (illegal 0xE0C0);
  check "SET dst 111 is illegal" (illegal 0xE0E0);
  check "IRQ bit 7 (beyond 9.1, pending V1) is illegal" (illegal 0xC087);
  check "IRQ index bit 3 (beyond 9.1, pending V1) is illegal" (illegal 0xC009)
;;

(* 3. Side-set and delay split/join. *)
let test_side () =
  let open Isa.Side in
  (* count 2 without enable: side = top 2 bits, delay = low 3 bits *)
  let cfg = { count = 2; enable = false } in
  check "side no-enable split" (equal_split (split cfg 0b11_101) { side = Some 3; delay = 5 });
  check "side no-enable join" (join cfg { side = Some 3; delay = 5 } = 0b11_101);
  (* count 2 with enable: bit 4 is the enable, one data bit, two delay bits *)
  let cfg = { count = 2; enable = true } in
  check
    "side enable present"
    (equal_split (split cfg 0b11_001) { side = Some 1; delay = 1 });
  check
    "side enable absent"
    (equal_split (split cfg 0b00_011) { side = None; delay = 3 });
  check "side enable join" (join cfg { side = Some 1; delay = 1 } = 0b11_001);
  check "side enable join absent" (join cfg { side = None; delay = 3 } = 0b00_011);
  (* no side-set: all five bits are delay *)
  check
    "no side-set"
    (equal_split (split none 31) { side = None; delay = 31 });
  (match join none { side = Some 1; delay = 0 } with
   | _ -> check "join with side and no side-set raises" false
   | exception _ -> ())
;;

(* 4. Oracle comparison: every instruction in the pico-examples corpus decodes to a
   non-illegal instruction, re-encodes to the same word, and disassembles to the text
   pioasm 2.3.1 wrote into its JSON. *)
let rec walk dir =
  Stdlib.Sys.readdir dir
  |> Array.to_list
  |> List.sort ~compare:String.compare
  |> List.concat_map ~f:(fun name ->
    let path = Filename.concat dir name in
    if Stdlib.Sys.is_directory path
    then walk path
    else if String.is_suffix path ~suffix:".pio.json"
    then [ path ]
    else [])
;;

let test_corpus () =
  let root = "../../sw/pgasm/test/corpus/pico-examples" in
  let files = walk root in
  let n_prog = ref 0 in
  let n_instr = ref 0 in
  let n_text_ok = ref 0 in
  List.iter files ~f:(fun file ->
    let json = Yojson.Safe.from_file file in
    let open Yojson.Safe.Util in
    List.iter (json |> member "programs" |> to_list) ~f:(fun prog ->
      Int.incr n_prog;
      let side =
        match member "sideset" prog with
        | `Null -> Isa.Side.none
        | s ->
          let size = s |> member "size" |> to_int in
          let optional = s |> member "optional" |> to_bool in
          (* JSON size already counts the enable bit (i2c: .side_set 1 opt -> size 2) *)
          { Isa.Side.count = size; enable = optional }
      in
      List.iter (prog |> member "instructions" |> to_list) ~f:(fun ins ->
        Int.incr n_instr;
        let word = Int.of_string ("0x" ^ (ins |> member "hex" |> to_string)) in
        let text = ins |> member "instruction" |> to_string in
        let t = Isa.decode word in
        if not (Isa.is_legal t)
        then (
          incr failures;
          printf "FAIL: %s: 0x%04x is not legal in v0\n" file word);
        if Isa.encode t <> word
        then (
          incr failures;
          printf "FAIL: %s: re-encode 0x%04x\n" file word);
        let got = Isa.to_string ~side t in
        if String.equal got text
        then Int.incr n_text_ok
        else (
          incr failures;
          printf "FAIL: %s: text %S, pioasm %S\n" file got text))));
  check "corpus has 26 .pio files" (List.length files = 26);
  check "corpus has 36 programs" (!n_prog = 36);
  check "corpus has 280 instructions" (!n_instr = 280);
  printf
    "corpus: %d programs, %d instructions; text matches pioasm for %d\n"
    !n_prog
    !n_instr
    !n_text_ok
;;

(* 4b. Disassembly text for the extensions and for reserved words. *)
let test_to_string () =
  let cases =
    [ 0x4088, "in     lcu, 8"
    ; 0xA024, "mov    x, crc"
    ; 0xA02C, "mov    x, ~crc"
    ; 0xE070, "set    lcu, 16"
    ; 0x40A5, "in     status, 5"
    ; 0xC007, "irq    nowait 7" (* pioasm prints IRQ set as nowait *)
    ; 0xFFFF, ".word 0xffff"
    ]
  in
  List.iter cases ~f:(fun (w, expected) ->
    let got = Isa.to_string (Isa.decode w) in
    check (sprintf "to_string 0x%04x = %S (got %S)" w expected got) (String.equal got expected))
;;

(* 4c. is_legal: false exactly for reserved words and for IN source 101. *)
let test_is_legal () =
  check "legal: mov x, y" (Isa.is_legal (Isa.decode 0xA021));
  check "legal: in lcu" (Isa.is_legal (Isa.decode 0x4088));
  check "legal: mov x, crc" (Isa.is_legal (Isa.decode 0xA024));
  check "legal: set lcu" (Isa.is_legal (Isa.decode 0xE070));
  check "not legal: in status (IN 101)" (not (Isa.is_legal (Isa.decode 0x40A5)));
  check "not legal: reserved SET 101" (not (Isa.is_legal (Isa.decode 0xE0A0)));
  check "not legal: Illegal 0xFFFF" (not (Isa.is_legal (Isa.Illegal 0xFFFF)));
  check
    "in status decodes to In_status, not Illegal"
    (match Isa.decode 0x40A5 with
     | Isa.In { source = Isa.In_status; _ } -> true
     | _ -> false)
;;

(* 4d. Accessors agree with the raw field for all 65536 words and all 32 delay values. *)
let test_accessors () =
  for w = 0 to 0xFFFF do
    let t = Isa.decode w in
    let ds = (w lsr 8) land 31 in
    if Isa.delay_side t <> ds
    then (
      incr failures;
      printf "FAIL: delay_side 0x%04x\n" w);
    for d = 0 to 31 do
      let changed = Isa.with_delay_side t d in
      let expected = (w land lnot (31 lsl 8)) lor (d lsl 8) in
      if Isa.encode changed <> expected || Isa.delay_side changed <> d
      then (
        incr failures;
        printf "FAIL: with_delay_side 0x%04x %d\n" w d)
    done
  done;
  printf "accessors: 65536 words x 32 delay values\n"
;;

(* 4e. Encoding Illegal is only allowed for reserved words; decode refuses out-of-range
   words. *)
let raises f =
  match f () with
  | _ -> false
  | exception _ -> true
;;

let test_guards () =
  check "encode (Illegal 0x4088) raises: not reserved" (raises (fun () -> Isa.encode (Isa.Illegal 0x4088)));
  check "encode (Illegal 0xE0A0) ok" (Isa.encode (Isa.Illegal 0xE0A0) = 0xE0A0);
  check "decode 0x10000 raises" (raises (fun () -> Isa.decode 0x10000));
  check "decode -1 raises" (raises (fun () -> Isa.decode (-1)))
;;

(* 4f. Quickcheck: every 16-bit word round-trips through decode and encode. *)
let test_quickcheck_words () =
  Quickcheck.test
    (Int.gen_incl 0 0xFFFF)
    ~trials:65_536
    ~sexp_of:Int.sexp_of_t
    ~f:(fun w ->
      if Isa.encode (Isa.decode w) <> w
      then (
        incr failures;
        printf "FAIL: encode (decode 0x%04x)\n" w));
  printf "quickcheck: random words round-trip through decode and encode\n"
;;

(* 5. Quickcheck: random well-formed instructions round-trip. *)
let gen_t : Isa.t Quickcheck.Generator.t =
  let open Quickcheck.Generator.Let_syntax in
  let ds = Int.gen_incl 0 31 in
  let bool = Quickcheck.Generator.bool in
  let of_list l = Quickcheck.Generator.of_list l in
  Quickcheck.Generator.union
    [ (let%bind delay_side = ds in
       let%bind cond = of_list Isa.all_of_jmp_cond in
       let%map addr = Int.gen_incl 0 31 in
       Isa.Jmp { delay_side; cond; addr })
    ; (let%bind delay_side = ds in
       let%bind polarity = bool in
       let%map source =
         Quickcheck.Generator.union
           [ Quickcheck.Generator.map (Int.gen_incl 0 31) ~f:(fun n -> Isa.Wsrc_gpio n)
           ; Quickcheck.Generator.map (Int.gen_incl 0 31) ~f:(fun n -> Isa.Wsrc_pin n)
           ; (let%map index = Int.gen_incl 0 7
              and rel = bool in
              Isa.Wsrc_irq { index; rel })
           ]
       in
       Isa.Wait { delay_side; polarity; source })
    ; (let%bind delay_side = ds in
       let%bind source = of_list Isa.all_of_in_source in
       let%map bit_count = Int.gen_incl 1 32 in
       Isa.In { delay_side; source; bit_count })
    ; (let%bind delay_side = ds in
       let%bind dest = of_list Isa.all_of_out_dest in
       let%map bit_count = Int.gen_incl 1 32 in
       Isa.Out { delay_side; dest; bit_count })
    ; (let%bind delay_side = ds in
       let%bind if_full = bool in
       let%map block = bool in
       Isa.Push { delay_side; if_full; block })
    ; (let%bind delay_side = ds in
       let%bind if_empty = bool in
       let%map block = bool in
       Isa.Pull { delay_side; if_empty; block })
    ; (let%bind delay_side = ds in
       let%bind dest = of_list Isa.all_of_mov_dest in
       let%bind op = of_list Isa.all_of_mov_op in
       let%map source = of_list Isa.all_of_mov_source in
       Isa.Mov { delay_side; dest; op; source })
    ; (let%bind delay_side = ds in
       let%bind clear = bool in
       let%bind wait = bool in
       let%bind rel = bool in
       let%map index = Int.gen_incl 0 7 in
       Isa.Irq { delay_side; clear; wait; index; rel })
    ; (let%bind delay_side = ds in
       let%bind dest = of_list Isa.all_of_set_dest in
       let%map data = Int.gen_incl 0 31 in
       Isa.Set { delay_side; dest; data })
    ]
;;

let test_quickcheck () =
  Quickcheck.test gen_t ~trials:20_000 ~sexp_of:Isa.sexp_of_t ~f:(fun t ->
    if not (Isa.equal (Isa.decode (Isa.encode t)) t)
    then (
      incr failures;
      printf "FAIL: decode (encode %s)\n" (Sexp.to_string (Isa.sexp_of_t t))));
  printf "quickcheck: 20000 random instructions round-trip\n"
;;

let () =
  test_exhaustive ();
  test_known ();
  test_reserved ();
  test_side ();
  test_corpus ();
  test_to_string ();
  test_is_legal ();
  test_accessors ();
  test_guards ();
  test_quickcheck_words ();
  test_quickcheck ();
  if !failures > 0
  then (
    printf "%d failure(s)\n" !failures;
    exit 1)
  else printf "all isa tests passed\n"
;;
