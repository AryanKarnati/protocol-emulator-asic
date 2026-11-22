(* Experiment: does Cyclesim honour a register's reset while the reset is low and the circuit
   is clocked? A register with reset value 0x55, reset while rst_n is low (Falling), with its
   D input held at 0xAA. Initial value is 0. *)
open Hardcaml

let () =
  let open Signal in
  let clock = input "clock" 1 in
  let rst_n = input "rst_n" 1 in
  let d = input "d" 8 in
  let spec =
    (* Variant B: active-high reset built from ~rst_n, rising edge. *)
    Reg_spec.override (Reg_spec.create ~reset:(~: rst_n) () ~clock)
      ~reset_edge:Rising ~reset_to:(of_int ~width:8 0x55)
  in
  let q = reg spec ~enable:vdd d in
  let circuit = Circuit.create_exn ~name:"reset_probe" [ output "q" q ] in
  let sim = Cyclesim.create circuit in
  let rst = Cyclesim.in_port sim "rst_n" in
  let din = Cyclesim.in_port sim "d" in
  let qo = Cyclesim.out_port ~clock_edge:Side.Before sim "q" in
  let show tag = Printf.printf "%-34s q=0x%02x\n" tag (Bits.to_int !qo) in
  Cyclesim.reset sim;
  Cyclesim.cycle_before_clock_edge sim;
  show "after Cyclesim.reset";
  let edge () =
    Cyclesim.cycle_before_clock_edge sim;
    Cyclesim.cycle_at_clock_edge sim;
    Cyclesim.cycle_after_clock_edge sim
  in
  din := Bits.of_int ~width:8 0xAA;
  rst := Bits.of_int ~width:1 1;
  Cyclesim.cycle_before_clock_edge sim;
  show "rst_n=1, before first edge";
  edge ();
  Cyclesim.cycle_before_clock_edge sim;
  show "rst_n=1, after one edge (d=0xAA)";
  rst := Bits.of_int ~width:1 0;
  Cyclesim.cycle_before_clock_edge sim;
  show "rst_n=0, before any edge";
  edge ();
  Cyclesim.cycle_before_clock_edge sim;
  show "rst_n=0, after 1 clocked edge";
  edge ();
  Cyclesim.cycle_before_clock_edge sim;
  show "rst_n=0, after 2 clocked edges";
  rst := Bits.of_int ~width:1 1;
  edge ();
  Cyclesim.cycle_before_clock_edge sim;
  show "rst_n=1, after one edge"
