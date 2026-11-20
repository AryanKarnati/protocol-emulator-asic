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
