(* The faulty DUTs by name. Each is pgsim with one source edit, built as a port-level DUT. *)

let names =
  [ "delay_off_by_one"
  ; "sideset_loses_to_out"
  ; "autopull_no_refill_non_out"
  ; "irq_clear_beats_set"
  ; "input_latency_2"
  ; "host_push_same_cycle"
  ; "x_forced_refills"
  ; "x_forced_counts_delay"
  ; "x_autopush_gt"
  ; "x_pin_prio_reversed"
  ; "x_div_gt"
  ; "x_status_le"
  ; "x_irq_rel_add7"
  ; "x_restart_keeps_latch_irq"
  ]
;;

let make name ~num_sms : Polyglot_lockstep.Dut.port_dut option =
  let port (module P : Polyglot_lockstep.Dut.PGSIM) =
    Some
      (Polyglot_lockstep.Dut.pgsim
         (module P)
         ~name:("mut-" ^ name)
         ~pads_from_pins_in:true
         ~num_sms)
  in
  match name with
  | "delay_off_by_one" -> port (module Pgsim_mut_delay_off_by_one.Pgsim)
  | "sideset_loses_to_out" -> port (module Pgsim_mut_sideset_loses_to_out.Pgsim)
  | "autopull_no_refill_non_out" -> port (module Pgsim_mut_autopull_no_refill_non_out.Pgsim)
  | "irq_clear_beats_set" -> port (module Pgsim_mut_irq_clear_beats_set.Pgsim)
  | "input_latency_2" -> port (module Pgsim_mut_input_latency_2.Pgsim)
  | "host_push_same_cycle" -> port (module Pgsim_mut_host_push_same_cycle.Pgsim)
  | "x_forced_refills" -> port (module Pgsim_mut_x_forced_refills.Pgsim)
  | "x_forced_counts_delay" -> port (module Pgsim_mut_x_forced_counts_delay.Pgsim)
  | "x_autopush_gt" -> port (module Pgsim_mut_x_autopush_gt.Pgsim)
  | "x_pin_prio_reversed" -> port (module Pgsim_mut_x_pin_prio_reversed.Pgsim)
  | "x_div_gt" -> port (module Pgsim_mut_x_div_gt.Pgsim)
  | "x_status_le" -> port (module Pgsim_mut_x_status_le.Pgsim)
  | "x_irq_rel_add7" -> port (module Pgsim_mut_x_irq_rel_add7.Pgsim)
  | "x_restart_keeps_latch_irq" -> port (module Pgsim_mut_x_restart_keeps_latch_irq.Pgsim)
  | _ -> None
;;
