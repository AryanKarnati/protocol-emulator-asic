(* Directed lockstep cases: scenarios that random generation has not reached.

   restart_clears_latch_irq: SM_RESTART clears the latched instruction's IRQ wait (H3).
     A forced IRQ-with-wait (index 3) stalls and sets flag 3. A restart clears the latch,
     and a host clear drops flag 3. Then the program's OUT EXEC latches the same IRQ-with-wait
     word. On its first attempt it must set flag 3 and stall (R15). If the old wait slot had
     survived the restart, the EXEC would complete at once and flag 3 would stay 0. *)

module Isa = Polyglot_isa.Isa

let enc = Isa.encode

let restart_clears_latch_irq () : Case.t =
  let irq_wait3 = enc (Isa.Irq { delay_side = 0; clear = false; wait = true; index = 3; rel = false }) in
  let pull = enc (Isa.Pull { delay_side = 0; if_empty = false; block = true }) in
  let out_exec = enc (Isa.Out { delay_side = 0; dest = Out_exec; bit_count = 16 }) in
  let imem = Array.make 32 0 in
  imem.(0) <- pull;
  imem.(1) <- out_exec;
  Case.normalise
    { Case.num_sms = 1
    ; imem
    ; initial = Array.make 4 Case.default_cfg
    ; initial_sync = 0
    ; cycles = 20
    ; events =
        [ 0, Case.Sm_enable 1
        ; 0, Case.Instr_write (0, irq_wait3)
        ; 2, Case.Sm_restart 1
        ; 3, Case.Irq_clear 0xFF
        ; 5, Case.Tx_push (0, irq_wait3) (* OUT shifts right by default: the low 16 bits *)
        ]
    }
;;

let all = [ "restart_clears_latch_irq", restart_clears_latch_irq ]
