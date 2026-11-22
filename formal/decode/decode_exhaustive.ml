(* Exhaustive equivalence of Polyglot_hw.Decode (Cyclesim) to the ISA reference.

   The decoder is combinational, and its inputs are 16 bits of instruction plus the valid
   side-set configurations (11 of them). Trying every case is therefore a complete proof
   for the RTL, not a sample. engine.md section 4. *)

open Hardcaml

let () =
  let sim = Cyclesim.create (Polyglot_hw.Decode.circuit ()) in
  let instr = Cyclesim.in_port sim "instr" in
  let sc = Cyclesim.in_port sim "sideset_count" in
  let side_en = Cyclesim.in_port sim "side_en" in
  let out name = !(Cyclesim.out_port sim name) |> Bits.to_int in
  let bit name = out name = 1 in
  let fails = ref 0 in
  let checked = ref 0 in
  List.iter
    (fun (count, enable) ->
       for w = 0 to 0xFFFF do
         instr := Bits.of_int ~width:16 w;
         sc := Bits.of_int ~width:3 count;
         side_en := Bits.of_int ~width:1 (if enable then 1 else 0);
         Cyclesim.cycle sim;
         let got : Decode_ref.expected =
           { legal = bit "legal"
           ; is_jmp = bit "is_jmp"
           ; is_wait = bit "is_wait"
           ; is_in = bit "is_in"
           ; is_out = bit "is_out"
           ; is_push = bit "is_push"
           ; is_pull = bit "is_pull"
           ; is_mov = bit "is_mov"
           ; is_irq = bit "is_irq"
           ; is_set = bit "is_set"
           ; uses_lcu = bit "uses_lcu"
           ; side_valid = bit "side_valid"
           ; side_value = out "side_value"
           ; delay = out "delay"
           ; bit_count = out "bit_count"
           }
         in
         let exp = Decode_ref.expected ~instr:w ~count ~enable in
         incr checked;
         match Decode_ref.diffs ~got exp with
         | [] -> ()
         | names ->
           incr fails;
           if !fails <= 10
           then
             Printf.printf
               "MISMATCH word=%04x count=%d enable=%b: %s\n  rtl: %s\n  ref: %s\n"
               w
               count
               enable
               (String.concat ", " names)
               (Decode_ref.to_string got)
               (Decode_ref.to_string exp)
       done)
    Decode_ref.configs;
  Printf.printf "decode exhaustive: %d cases checked, %d mismatches\n" !checked !fails;
  if !fails > 0 then exit 1
;;
