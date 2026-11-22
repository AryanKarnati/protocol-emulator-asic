(* Prints the reference table for every (word, side-set configuration) case, one line each,
   for the Verilator run on the generated Verilog. Fields are decimal, in this order:
   instr count enable legal is_jmp is_wait is_in is_out is_push is_pull is_mov is_irq
   is_set uses_lcu side_valid side_value delay bit_count *)

let () =
  List.iter
    (fun (count, enable) ->
       for w = 0 to 0xFFFF do
         let e = Decode_ref.expected ~instr:w ~count ~enable in
         let b x = if x then 1 else 0 in
         Printf.printf
           "%d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d\n"
           w
           count
           (b enable)
           (b e.legal)
           (b e.is_jmp)
           (b e.is_wait)
           (b e.is_in)
           (b e.is_out)
           (b e.is_push)
           (b e.is_pull)
           (b e.is_mov)
           (b e.is_irq)
           (b e.is_set)
           (b e.uses_lcu)
           (b e.side_valid)
           e.side_value
           e.delay
           e.bit_count
       done)
    Decode_ref.configs
;;
