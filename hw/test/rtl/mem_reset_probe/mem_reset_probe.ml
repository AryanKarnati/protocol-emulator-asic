(* Experiment: does Cyclesim.reset clear a memory or a register that has no reset spec? Both
   are written with 0x55 before the reset (the IMEM analogue: state the chip keeps across
   rst_n, because IMEM is not reset, engine.md R0). Read back after Cyclesim.reset. *)
open Hardcaml

let () =
  let open Signal in
  let clock = input "clock" 1 in
  let we = input "we" 1 in
  let wa = input "wa" 2 in
  let wd = input "wd" 8 in
  let ra = input "ra" 2 in
  let write_port = { Write_port.write_clock = clock; write_enable = we; write_address = wa; write_data = wd } in
  let mem_out = (multiport_memory 4 ~write_ports:[| write_port |] ~read_addresses:[| ra |]).(0) in
  let plain = reg (Reg_spec.create ~clock ()) ~enable:we wd in
  let circuit = Circuit.create_exn ~name:"mem_reset_probe" [ output "mem" mem_out; output "plain" plain ] in
  let sim = Cyclesim.create circuit in
  let set name w v = Cyclesim.in_port sim name := Bits.of_int ~width:w v in
  let out name = Bits.to_int !(Cyclesim.out_port ~clock_edge:Side.Before sim name) in
  let edge () =
    Cyclesim.cycle_before_clock_edge sim;
    Cyclesim.cycle_at_clock_edge sim;
    Cyclesim.cycle_after_clock_edge sim
  in
  (* write 0x55 at address 1 and to the plain register *)
  set "we" 1 1; set "wa" 2 1; set "wd" 8 0x55; set "ra" 2 1;
  edge ();
  set "we" 1 0;
  Cyclesim.cycle_before_clock_edge sim;
  Printf.printf "before reset: mem[1]=0x%02x plain=0x%02x\n" (set "ra" 2 1; Cyclesim.cycle_before_clock_edge sim; out "mem") (out "plain");
  Cyclesim.reset sim;
  Cyclesim.cycle_before_clock_edge sim;
  Printf.printf "after Cyclesim.reset: mem[1]=0x%02x plain=0x%02x\n" (out "mem") (out "plain")
