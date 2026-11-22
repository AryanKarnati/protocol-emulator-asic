(* The comparator must pass the pgsim DUT and must catch every faulty variant. The RTL
   checks are in hw/test/rtl/tests (they are not part of this test). *)
open Polyglot_lockstep

let run ~dut_of (case : Case.t) =
  let num_sms = case.Case.num_sms in
  let reference =
    Dut.pgsim (module Pgsim : Dut.PGSIM) ~name:"pgsim-ref" ~pads_from_pins_in:false ~num_sms
  in
  Lockstep.run ~reference ~dut:(dut_of ~num_sms) case
;;

let pgsim_dut ~num_sms =
  Dut.pgsim (module Pgsim : Dut.PGSIM) ~name:"pgsim" ~pads_from_pins_in:true ~num_sms
;;

let check name = function
  | Lockstep.Pass _ -> ()
  | Lockstep.Fail f -> failwith (name ^ ": unexpected mismatch\n" ^ Lockstep.report f)
;;

(* Class A (engine.md 3): FIFO capacity follows the FJOIN input of the current cycle, and a
   mid-run reset does not change it. In the first cycle after a reset with FJOIN_TX set, SM0's
   TX reads capacity 0: both TXEMPTY and TXFULL. *)
let fjoin_after_reset () =
  let check what cond = if not cond then failwith ("FAILED: " ^ what) in
  let d = Dut.pgsim (module Pgsim : Dut.PGSIM) ~name:"p" ~pads_from_pins_in:true ~num_sms:1 in
  ignore (d.Dut.cycle (Ports.idle ~rst_n:false));
  let inp fjoin_tx =
    let i = Ports.idle ~rst_n:true in
    { i with Ports.shiftctrl = [| (if fjoin_tx then 0x4000_0000 else 0) lor 0x000C_0000; 0; 0; 0 |];
             pinctrl = Array.make 4 0x1400_0000; clkdiv = Array.make 4 0x10000; execctrl = Array.make 4 0x1F000 }
  in
  let o = d.Dut.regs (inp true) in
  (* FJOIN_TX: TX has 8 entries, RX has capacity 0, so RX reads both RXEMPTY and RXFULL. *)
  check "fjoin_tx: SM0 RX reads capacity 0 (RXEMPTY and RXFULL) in the first cycle after reset"
    (o.Ports.fstat land (1 lsl 8) <> 0 && o.Ports.fstat land 1 <> 0);
  ignore (d.Dut.cycle (inp true));
  let o = d.Dut.regs (inp false) in
  check "no join: SM0 RX capacity 4 (RXFULL clear)" (o.Ports.fstat land 1 = 0)
;;

let () =
  fjoin_after_reset ();
  let c = Gen.generate_one ~seed:3 5 in
  assert (Case.of_text (Case.to_text c) = c);
  for i = 0 to 299 do
    check "gen" (run ~dut_of:pgsim_dut (Gen.generate_one ~seed:11 i))
  done;
  List.iter
    (fun (_, c) -> check "corpus" (run ~dut_of:pgsim_dut c))
    (Corpus.cases ~cycles:1000 ~dir:"../../../sw/pgasm/test/corpus" ());
  (* Directed cases: the reference passes, and the directed case catches the restart mutant
     that random cases missed. *)
  List.iter
    (fun (name, mk) ->
      let c = mk () in
      check ("directed " ^ name) (run ~dut_of:pgsim_dut c);
      match run ~dut_of:(fun ~num_sms -> Option.get (Polyglot_mutant_duts.Mutant_duts.make "x_restart_keeps_latch_irq" ~num_sms)) c with
      | Lockstep.Fail _ -> ()
      | Lockstep.Pass _ -> failwith ("directed case does not catch the restart mutant: " ^ name))
    Directed.all;
  List.iter
    (fun name ->
      let dut_of ~num_sms =
        match Polyglot_mutant_duts.Mutant_duts.make name ~num_sms with
        | Some d -> d
        | None -> failwith ("no mutant " ^ name)
      in
      let caught = ref false in
      let i = ref 0 in
      while (not !caught) && !i < 1500 do
        (match run ~dut_of (Gen.generate_one ~seed:1 !i) with
         | Lockstep.Fail _ -> caught := true
         | Lockstep.Pass _ -> ());
        incr i
      done;
      if not !caught then failwith ("mutant not caught: " ^ name))
    (List.filter (fun n -> n <> "x_restart_keeps_latch_irq") Polyglot_mutant_duts.Mutant_duts.names);
  print_endline "lockstep: pgsim passes, all mutants caught"
;;
