(* Loader for pioasm -o json output (the corpus format). Only the fields pgsim uses. *)

type program =
  { name : string
  ; words : int list (* 16-bit instruction words, in order *)
  ; wrap_target : int
  ; wrap : int
  ; sideset : (int * bool * bool) option (* size, optional (enable bit), pindirs *)
  }

let parse_program (j : Yojson.Safe.t) : program =
  let open Yojson.Safe.Util in
  let name = j |> member "name" |> to_string in
  let instrs = j |> member "instructions" |> to_list in
  let words =
    List.map (fun i -> int_of_string ("0x" ^ (i |> member "hex" |> to_string))) instrs
  in
  let sideset =
    match j |> member "sideset" with
    | `Null -> None
    | s ->
      Some
        ( s |> member "size" |> to_int
        , s |> member "optional" |> to_bool
        , s |> member "pindirs" |> to_bool )
  in
  { name
  ; words
  ; wrap_target = j |> member "wrapTarget" |> to_int
  ; wrap = j |> member "wrap" |> to_int
  ; sideset
  }
;;

(* Read a pioasm JSON file. [which] selects a program by name; default is the first. *)
let load ?which path : program =
  let json = Yojson.Safe.from_file path in
  let progs = Yojson.Safe.Util.(json |> member "programs" |> to_list) in
  let chosen =
    match which, progs with
    | None, p :: _ -> p
    | Some n, ps ->
      (match
         List.find_opt (fun p -> Yojson.Safe.Util.(p |> member "name" |> to_string) = n) ps
       with
       | Some p -> p
       | None -> failwith (Printf.sprintf "no program %S in %s" n path))
    | None, [] -> failwith (Printf.sprintf "no programs in %s" path)
  in
  parse_program chosen
;;

(* Apply what the program's JSON says to a configuration (wrap and side-set). pioasm's
   "sideset.size" already includes the enable bit: `.side_set 1 opt` gives size 2, which is
   SIDESET_COUNT (datasheet 3.5.1, pico-sdk pio_sm_config). "optional" is SIDE_EN. The JSON
   has no OUT, SET or IN pins, so those keep the base configuration. *)
let apply_to_config (p : program) (base : Pgsim.Config.t) : Pgsim.Config.t =
  let c = { base with Pgsim.Config.wrap_top = p.wrap; wrap_bottom = p.wrap_target } in
  match p.sideset with
  | None -> c
  | Some (size, optional, pindirs) ->
    { c with
      Pgsim.Config.sideset_count = size
    ; side_en = optional
    ; side_pindir = pindirs
    }
;;
