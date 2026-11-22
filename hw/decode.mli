(** Combinational decoder for the block 2 engine (docs/engine.md section 4).

    Equivalence to the reference ISA library: for every 16-bit word and every valid
    side-set configuration (count 0 to 5, enable only with count >= 1):
    - [legal] = [Isa.is_legal (Isa.decode instr)];
    - each [is_*] output is 1 exactly when the constructor of [Isa.decode instr] is that
      instruction, and all are 0 when [legal] is 0;
    - [uses_lcu] is 1 exactly for [In_lcu], [Ms_crc] or [Set_lcu];
    - [side_valid], [side_value] and [delay] are [Isa.Side.split] of bits 12:8, where
      [side_value] is 0 whenever [side_valid] is 0 (the split then has no value);
    - [bit_count] is 1 to 32 for a legal IN or OUT, otherwise 0.

    The module is purely combinational. *)

open Hardcaml

module I : sig
  type 'a t =
    { instr : 'a
    ; sideset_count : 'a
    ; side_en : 'a
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t =
    { legal : 'a
    ; is_jmp : 'a
    ; is_wait : 'a
    ; is_in : 'a
    ; is_out : 'a
    ; is_push : 'a
    ; is_pull : 'a
    ; is_mov : 'a
    ; is_irq : 'a
    ; is_set : 'a
    ; uses_lcu : 'a
    ; side_valid : 'a
    ; side_value : 'a
    ; delay : 'a
    ; bit_count : 'a
    }
  [@@deriving hardcaml]
end

(** Flat instantiation: the logic is inlined into the parent. *)
val create : Scope.t -> Signal.t I.t -> Signal.t O.t

(** Hierarchical instantiation: the decoder appears as module [decode]. *)
val hierarchical : Scope.t -> Signal.t I.t -> Signal.t O.t

(** The decoder alone, with circuit name [decode]. *)
val circuit : unit -> Circuit.t
