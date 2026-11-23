(* The pin block (docs/chip.md section 9): the pad mapping in both directions, STATUS and
   HOST_IRQ. Nothing here is registered. Every output is a function of register state in
   the same cycle, so there is no path from an input pad to an output pad. *)

open Hardcaml
open Signal

module I = struct
  type 'a t =
    { ui_in : 'a [@bits 8]
    ; uio_in : 'a [@bits 8]
    ; pins_out : 'a [@bits 32]
    ; pins_oe : 'a [@bits 32]
    ; pad_od : 'a [@bits 8]
    ; sync_bypass : 'a [@bits 24]
    ; hostirq_en : 'a [@bits 12]
    ; irq : 'a [@bits 8]
    ; fstat : 'a [@bits 32]
    ; miso : 'a
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { uo_out : 'a [@bits 8]
    ; uio_out : 'a [@bits 8]
    ; uio_oe : 'a [@bits 8]
    ; pins_in : 'a [@bits 32]
    ; sync_bypass32 : 'a [@bits 32]
    ; status : 'a [@bits 8]
    ; host_irq : 'a
    }
  [@@deriving hardcaml]
end

let bitof x k = select x k k

(* 1 if any bit of [x] is set. *)
let any x = x <>:. 0

let create ~num_sms (i : _ I.t) =
  if num_sms < 1 || num_sms > 4
  then invalid_arg (Printf.sprintf "pins: num_sms must be 1 to 4, got %d" num_sms);
  let present k = k < num_sms in
  (* STATUS and HOST_IRQ sources (9.3). FSTAT has TXFULL in [19:16] and RXEMPTY in
     [11:8]. An absent SM has 0 in FSTAT, so it must be gated here or it would read as
     "not full" and "not empty". Both NOT terms are 0 for an absent SM. *)
  let txnfull = List.init 4 (fun k -> if present k then ~:(bitof i.fstat (16 + k)) else gnd) in
  let rxnempty = List.init 4 (fun k -> if present k then ~:(bitof i.fstat (8 + k)) else gnd) in
  (* STATUS = {TXNFULL[3:0], RXNEMPTY[3:0]}, so bit 7 is TXNFULL[3]. *)
  let status = concat_msb (List.rev txnfull @ List.rev rxnempty) in
  (* HOST_IRQ sources, LSB first: {TXNFULL[3:0], RXNEMPTY[3:0], irq[3:0]}. Source i is
     bit i of HOSTIRQ_EN. *)
  let sources = List.init 4 (bitof i.irq) @ rxnempty @ txnfull in
  let host_irq = any (i.hostirq_en &: concat_msb (List.rev sources)) in
  (* uo_out (9.2). uo_out[6] is HOST_IRQ while any HOSTIRQ_EN bit is set. *)
  let uo6 = mux2 (any i.hostirq_en) host_irq (bitof i.pins_out 14) in
  let uo_out = concat_msb [ i.miso; uo6; select i.pins_out 13 8 ] in
  (* uio (9.2): PAD_OD drives 0 in place of the value, and releases the pad. *)
  let pins_out_lo = select i.pins_out 7 0 in
  let uio_out = pins_out_lo &: ~:(i.pad_od) in
  let uio_oe = select i.pins_oe 7 0 &: ~:(i.pad_od &: pins_out_lo) in
  (* Input vector (9.1). Pins 8 to 15 are this cycle's uo_out. *)
  let pins_in = concat_msb [ zero 8; i.ui_in; uo_out; i.uio_in ] in
  { O.uo_out
  ; uio_out
  ; uio_oe
  ; pins_in
  ; sync_bypass32 = concat_msb [ zero 8; i.sync_bypass ]
  ; status
  ; host_irq
  }
;;
