(* The Tiny Tapeout top, module polyglot (docs/chip.md section 10): the reset synchroniser,
   and chip with 4 SMs and a 64-word IMEM. Only the Tiny Tapeout ports are here. The dbg_*
   ports of chip are not connected. *)

open Hardcaml
open Signal

module I = struct
  type 'a t =
    { clk : 'a
    ; rst_n : 'a
    ; ui_in : 'a [@bits 8]
    ; uio_in : 'a [@bits 8]
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { uo_out : 'a [@bits 8]
    ; uio_out : 'a [@bits 8]
    ; uio_oe : 'a [@bits 8]
    }
  [@@deriving hardcaml]
end

let create (scope : Scope.t) (i : _ I.t) =
  (* Reset: rst_n asserts asynchronously and is released through two flops (chip.md 10).
     [core_rst_n] is the chip's reset. *)
  let sync_spec =
    Reg_spec.override
      (Reg_spec.create () ~clock:i.clk)
      ~reset:i.rst_n
      ~reset_edge:Edge.Falling
      ~reset_to:gnd
  in
  let sync1 = reg sync_spec vdd -- "rst_sync1" in
  let core_rst_n = reg sync_spec sync1 -- "core_rst_n" in
  let chip =
    Chip.create
      ~num_sms:4
      ~imem_depth:64
      scope
      { Chip.I.clock = i.clk; rst_n = core_rst_n; ui_in = i.ui_in; uio_in = i.uio_in }
  in
  { O.uo_out = chip.uo_out; uio_out = chip.uio_out; uio_oe = chip.uio_oe }
;;

module Circuit_io = Circuit.With_interface (I) (O)

(* The top-level circuit, and the database of its submodules. *)
let circuit () =
  let scope = Scope.create () in
  let circuit = Circuit_io.create_exn ~name:"polyglot" (create scope) in
  circuit, Scope.circuit_database scope
;;
