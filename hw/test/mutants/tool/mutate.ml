(* mutate SRC DST OLD NEW [OLD NEW ...]: copy SRC to DST with each OLD replaced by NEW.
   Every OLD must occur exactly once in SRC, or the tool fails, so a mutant can never
   silently differ from the model by more or less than the intended edit. *)

let read path = In_channel.with_open_bin path In_channel.input_all

let occurrences s sub =
  let n = String.length sub in
  let rec go i acc =
    if i + n > String.length s
    then acc
    else if String.sub s i n = sub
    then go (i + n) (acc + 1)
    else go (i + 1) acc
  in
  go 0 0
;;

let replace_once s old repl =
  let n = String.length old in
  let rec find i =
    if i + n > String.length s
    then failwith "mutate: text not found"
    else if String.sub s i n = old
    then i
    else find (i + 1)
  in
  let i = find 0 in
  String.sub s 0 i ^ repl ^ String.sub s (i + n) (String.length s - i - n)
;;

let () =
  match Array.to_list Sys.argv with
  | _ :: src :: dst :: pairs ->
    let rec apply s = function
      | [] -> s
      | old :: repl :: rest ->
        let c = occurrences s old in
        if c <> 1
        then (
          Printf.eprintf "mutate: %S occurs %d times, expected 1\n" old c;
          exit 2);
        apply (replace_once s old repl) rest
      | [ _ ] ->
        prerr_endline "mutate: odd number of OLD/NEW arguments";
        exit 2
    in
    let out = apply (read src) pairs in
    Out_channel.with_open_bin dst (fun oc -> output_string oc out)
  | _ ->
    prerr_endline "usage: mutate SRC DST OLD NEW [OLD NEW ...]";
    exit 2
;;
