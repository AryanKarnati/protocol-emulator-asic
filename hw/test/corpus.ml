(* Corpus cases: every program in the pioasm JSON corpus (sw/pgasm/test/corpus), run in
   lockstep with the configuration that [Pioasm_json.apply_to_config] gives it, and with
   fixed-seed stimulus: TX words, changing input pins, RX pops and IRQ clears. *)

let config_of_program (p : Pioasm_json.program) : Case.sm_cfg =
  let c = Pioasm_json.apply_to_config p Pgsim.Config.reset in
  { Case.clkdiv = Pgsim.Config.clkdiv_register c
  ; execctrl = Pgsim.Config.execctrl_register c
  ; shiftctrl = Pgsim.Config.shiftctrl_register c
  ; pinctrl = Pgsim.Config.pinctrl_register c
  }
;;

(* The program names in one pioasm JSON file, in file order. *)
let program_names file =
  let module U = Yojson.Safe.Util in
  Yojson.Safe.from_file file
  |> U.member "programs"
  |> U.to_list
  |> List.map (fun p -> p |> U.member "name" |> U.to_string)
;;

(* Stimulus for one program, from a fixed seed so that every run is the same. *)
let stimulus ~seed ~cycles : (int * Case.event) list =
  let rng = Random.State.make [| seed |] in
  let r n = Random.State.int rng n in
  let r32 () = Random.State.bits rng lor (Random.State.bits rng lsl 30) land 0xFFFF_FFFF in
  let events = ref [ 0, Case.Sm_enable 1 ] in
  let add c e = events := (c, e) :: !events in
  (* A few TX words at the start, then one more every so often. *)
  for k = 0 to 7 do
    add k (Case.Tx_push (0, r32 ()))
  done;
  let c = ref 8 in
  while !c < cycles do
    (match r 6 with
     | 0 -> add !c (Case.Ext_pins (r32 ()))
     | 1 -> add !c (Case.Tx_push (0, r32 ()))
     | 2 -> add !c (Case.Rx_pop 0)
     | 3 -> add !c (Case.Irq_clear (r 256))
     | _ -> ());
    c := !c + 1 + r 9
  done;
  !events
;;

(* Every .json file under [dir], recursively, in sorted order. *)
let rec json_files dir =
  Sys.readdir dir
  |> Array.to_list
  |> List.sort compare
  |> List.concat_map (fun entry ->
    let path = Filename.concat dir entry in
    if Sys.is_directory path
    then json_files path
    else if Filename.check_suffix path ".json"
    then [ path ]
    else [])
;;

(* [(name, case)] for every program in every file of [dir]. *)
let cases ?(cycles = 3000) ?(seed = 7) ~dir () : (string * Case.t) list =
  let files = json_files dir in
  List.concat_map
    (fun path ->
      List.map
        (fun name ->
          let p = Pioasm_json.load ~which:name path in
          let cfg = config_of_program p in
          let imem = Array.make 32 0 in
          List.iteri (fun i w -> if i < 32 then imem.(i) <- w) p.Pioasm_json.words;
          let case =
            Case.normalise
              { Case.num_sms = 4
              ; imem
              ; initial = [| cfg; Case.default_cfg; Case.default_cfg; Case.default_cfg |]
              ; initial_sync = 0
              ; cycles
              ; events = stimulus ~seed:(seed + Hashtbl.hash name) ~cycles
              }
          in
          name, case)
        (program_names path))
    files
;;
