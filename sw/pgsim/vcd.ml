(* VCD writer for pgsim runs. One timestep per system clock cycle (timescale 1 ns).
   Signals: the 32 pad levels, the 32 pad output enables, and for each SM its PC, X, Y,
   ISR, OSR, and the stall reason as a 3-bit code. Only changes are written. *)

type signal =
  { id : string
  ; width : int
  ; name : string
  }

let id_of n =
  (* Printable identifiers from '!' (33) upwards, as VCD requires. *)
  let rec go n acc =
    let acc = Char.chr (33 + (n mod 90)) :: acc in
    if n < 90 then String.of_seq (List.to_seq acc) else go ((n / 90) - 1) acc
  in
  go n []
;;

let bin width v =
  String.init width (fun i -> if (v lsr (width - 1 - i)) land 1 = 1 then '1' else '0')
;;

let stall_code = function
  | Pgsim.No_stall -> 0
  | Pgsim.Stall_tx_empty -> 1
  | Pgsim.Stall_rx_full -> 2
  | Pgsim.Stall_autopull -> 3
  | Pgsim.Stall_wait -> 4
  | Pgsim.Stall_irq -> 5
;;

(* [step_fn c] runs cycle [c] and returns the pad levels for that cycle. *)
let run ~path ~cycles (t : Pgsim.t) (step_fn : int -> int) =
  let oc = open_out path in
  let next = ref 0 in
  let sigs = ref [] in
  let add name width =
    let s = { id = id_of !next; width; name } in
    incr next;
    sigs := s :: !sigs;
    s
  in
  let pad = add "pad" 32 in
  let oe = add "pad_oe" 32 in
  let per_sm =
    Array.init 4 (fun i ->
      let p = Printf.sprintf "sm%d." i in
      [| add (p ^ "pc") 5
       ; add (p ^ "x") 32
       ; add (p ^ "y") 32
       ; add (p ^ "isr") 32
       ; add (p ^ "osr") 32
       ; add (p ^ "stall") 3
      |])
  in
  Printf.fprintf oc "$timescale 1 ns $end\n$scope module pgsim $end\n";
  List.iter
    (fun s -> Printf.fprintf oc "$var wire %d %s %s $end\n" s.width s.id s.name)
    (List.rev !sigs);
  Printf.fprintf oc "$upscope $end\n$enddefinitions $end\n";
  let last = Hashtbl.create 64 in
  let emit s v =
    let str = bin s.width v in
    if Hashtbl.find_opt last s.id <> Some str
    then (
      Hashtbl.replace last s.id str;
      Printf.fprintf oc "b%s %s\n" str s.id)
  in
  for c = 0 to cycles - 1 do
    Printf.fprintf oc "#%d\n" c;
    let padv = step_fn c in
    emit pad padv;
    emit oe t.Pgsim.pin_dir;
    Array.iteri
      (fun i s ->
        let d = Pgsim.debug t i in
        emit s.(0) d.Pgsim.pc;
        emit s.(1) d.Pgsim.x;
        emit s.(2) d.Pgsim.y;
        emit s.(3) d.Pgsim.isr;
        emit s.(4) d.Pgsim.osr;
        emit s.(5) (stall_code d.Pgsim.stall))
      per_sm
  done;
  close_out oc
;;
