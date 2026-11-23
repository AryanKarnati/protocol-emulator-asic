(* Block 3 checks of pgsim (engine.md 9: two IMEM pages, F7 on the fetch address; H8: host
   FDEBUG set). The expectations come from the contract, not from the model's output. *)

module Isa = Polyglot_isa.Isa
module C = Pgsim.Config

let enc = Isa.encode
let set_pins d = enc (Isa.Set { delay_side = 0; dest = Set_pins; data = d })
let jmp addr = enc (Isa.Jmp { delay_side = 0; cond = Isa.Always; addr })

(* WAIT 1 PIN 0: stalls while pin 0 is low. *)
let wait_pin0_low = enc (Isa.Wait { delay_side = 0; polarity = true; source = Wsrc_pin 0 })

let check name cond = if not cond then failwith ("FAILED: " ^ name)

let page_words page_a page_b =
  (* Page 0 at words 0..31, page 1 at 32..63. *)
  let t = Pgsim.create () in
  Pgsim.load_program t (page_a @ List.init (32 - List.length page_a) (fun _ -> 0));
  List.iteri (fun i w -> Pgsim.write_imem t (32 + i) w) page_b;
  t
;;

let run t n =
  for _ = 1 to n do
    ignore (Pgsim.step t)
  done
;;

let () =
  (* Fetch: the SM runs the page its EXT.PAGE selects, and dbg_instr shows that word. *)
  let t = page_words [ set_pins 0 ] [ set_pins 1 ] in
  Pgsim.set_config t 0 C.reset;
  Pgsim.set_enabled t 0 true;
  check "page 0 word at reset" ((Pgsim.debug t 0).Pgsim.instr = set_pins 0);
  Pgsim.set_page t 0 1;
  check "dbg_instr follows PAGE before the step" ((Pgsim.debug t 0).Pgsim.instr = set_pins 1);
  ignore (Pgsim.step t);
  check "page 1 executed" (t.Pgsim.pin_level land 1 = 1);
  (* PAGE changes mid-run and takes effect at the next fetch. The PC is kept, so the word at
     the same PC in the other page runs. *)
  let t = page_words [ jmp 1; set_pins 0 ] [ set_pins 1; set_pins 1 ] in
  Pgsim.set_config t 0 C.reset;
  Pgsim.set_enabled t 0 true;
  run t 1;
  check "page 0 jmp to 1 ran" ((Pgsim.debug t 0).Pgsim.pc = 1);
  Pgsim.set_page t 0 1;
  ignore (Pgsim.step t);
  check "page 1 word at PC 1 ran" (t.Pgsim.pin_level land 1 = 1);
  check "PC advanced inside page 1" ((Pgsim.debug t 0).Pgsim.pc = 2);
  (* F7 on the fetch address: a write to the word the SM fetches abandons the wait, and a
     write to the same PC in the other page does not. *)
  let t = page_words [ wait_pin0_low ] [] in
  Pgsim.set_config t 0 C.reset;
  Pgsim.set_enabled t 0 true;
  run t 2;
  check "waiting on page 0" ((Pgsim.debug t 0).Pgsim.stall = Pgsim.Stall_wait_pin);
  Pgsim.write_imem t 32 (set_pins 0);
  ignore (Pgsim.step t);
  check "write to page 1 at PC 0 does not touch page 0 wait"
    ((Pgsim.debug t 0).Pgsim.stall = Pgsim.Stall_wait_pin);
  Pgsim.write_imem t 0 (set_pins 0);
  ignore (Pgsim.step t);
  (* The write clears the stall (F7), then the SM re-attempts the new word (a set pins, not a
     wait) and completes it. *)
  check "write to the fetch address clears the wait" ((Pgsim.debug t 0).Pgsim.stall = Pgsim.No_stall);
  (* FDEBUG set (H8). *)
  let t = Pgsim.create () in
  Pgsim.step_ex ~host:[ Pgsim.Host_op.Fdebug_set 0x0000_0101 ] t |> ignore;
  check "fdebug_set sets RXSTALL0 and RXUNDER0"
    (Pgsim.fdebug t land 0x0000_0101 = 0x0000_0101);
  Pgsim.step_ex ~host:[ Pgsim.Host_op.Fdebug_clear 0x0000_0101; Pgsim.Host_op.Fdebug_set 0x0000_0001 ] t
  |> ignore;
  check "set wins over a clear in the same cycle" (Pgsim.fdebug t land 0x0000_0101 = 0x0000_0001);
  Pgsim.step_ex ~host:[ Pgsim.Host_op.Fdebug_clear 0x0000_0001 ] t |> ignore;
  check "clear alone clears" (Pgsim.fdebug t land 0x0000_0001 = 0);
  print_endline "block 3 pgsim checks: passed"
;;
