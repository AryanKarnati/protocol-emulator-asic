(* The lockstep runner: drives a reference and a DUT with the same inputs, compares every
   port of engine.md section 7 every cycle, and stops at the first difference. *)

type failure =
  { cycle : int (** global cycle, the load phase included *)
  ; port : string
  ; reference : int
  ; dut : int
  ; history : (int * (string * int) list) list
    (** up to 16 cycles before the failing one, oldest first, with the compared values *)
  ; dut_name : string
  }

type outcome =
  | Pass of { cycles : int }
  | Fail of failure

let history_len = 16

(* Run [case] (normalised by the caller, see [Case.normalise]) on both. *)
let run ~(reference : Dut.port_dut) ~(dut : Dut.port_dut) (case : Case.t) : outcome =
  let inputs = Case.dense case in
  let rst = Ports.idle ~rst_n:false in
  ignore (reference.cycle rst);
  ignore (dut.cycle rst);
  let hist = Queue.create () in
  let result = ref None in
  let n = ref 0 in
  let total = Array.length inputs in
  (* The loop runs one compare past the last cycle: the state after the last clock edge is
     compared too (engine.md 5). Inputs are only driven for cycles below [total]. *)
  while Option.is_none !result && !n <= total do
    (* Nothing is compared while rst_n is low (engine.md 5). The outputs of a cycle are read
       with that cycle's inputs applied (FIFO capacity follows FJOIN, and rxf_data follows
       rxf_sm), with pins_in not yet set: pins_in does not affect the register outputs. *)
    (* The final compare (after the last cycle) uses the last cycle's configuration. *)
    let inp0 =
      if !n < total then inputs.(!n) else { inputs.(total - 1) with Ports.rst_n = true }
    in
    let r = reference.regs inp0 in
    let d = dut.regs inp0 in
    let rf = Ports.fields r in
    let df = Ports.fields d in
    let pairs = if inp0.Ports.rst_n then List.combine rf df else [] in
    (match List.find_opt (fun ((_, a), (_, b)) -> a <> b) pairs with
     | Some ((name, a), (_, b)) ->
       result
       := Some
            (Fail
               { cycle = !n
               ; port = name
               ; reference = a
               ; dut = b
               ; history = List.of_seq (Queue.to_seq hist)
               ; dut_name = dut.name
               })
     | None when !n = total -> incr n
     | None ->
       let pins_in =
         Ports.pins_in_of ~pins_out:d.Ports.pins_out ~pins_oe:d.Ports.pins_oe
           ~ext:inputs.(!n).Ports.pins_ext
       in
       let inp = { (inputs.(!n)) with Ports.pins_in } in
       if Queue.length hist = history_len then ignore (Queue.pop hist);
       Queue.push (!n, rf) hist;
       (* rxf_data was compared with the other ports above (every cycle, engine.md 7). *)
       ignore (reference.cycle inp);
       ignore (dut.cycle inp);
       incr n)
  done;
  match !result with
  | Some f -> f
  | None -> Pass { cycles = total }
;;

let describe_cycle n =
  if n < Case.load_cycles
  then Printf.sprintf "cycle %d (load phase)" n
  else Printf.sprintf "cycle %d (run cycle %d)" n (n - Case.load_cycles)
;;

let report (f : failure) : string =
  let b = Buffer.create 1024 in
  let p fmt = Printf.bprintf b fmt in
  p "MISMATCH at %s, port %s\n" (describe_cycle f.cycle) f.port;
  p "  reference (pgsim)   = 0x%x\n" f.reference;
  p "  dut (%s) = 0x%x\n" f.dut_name f.dut;
  p "previous %d cycles (compared ports, hex):\n" (List.length f.history);
  List.iter
    (fun (c, fields) ->
      p "  %4d:" c;
      List.iter (fun (name, v) -> p " %s=%x" name v) fields;
      p "\n")
    f.history;
  Buffer.contents b
;;
