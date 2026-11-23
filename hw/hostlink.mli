(** The host link: an SPI mode 0 target (docs/chip.md sections 6 and 7).

    The link has no knowledge of registers. [rdata] is the value the register block
    returns for [bus_addr] in the same cycle. It must be combinational from [bus_addr]
    (the register block does that), because a read pulse puts it on MISO.

    All bus pulses are functions of the link's registers, so they never depend on the
    pins of the cycle in which they are presented. *)

open Hardcaml

module I : sig
  type 'a t =
    { clock : 'a
    ; rst_n : 'a
    ; sck : 'a
    ; mosi : 'a
    ; cs_n : 'a
    ; status : 'a
    ; rdata : 'a
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t =
    { miso : 'a
    ; bus_write : 'a
    ; bus_read : 'a
    ; bus_commit : 'a
    ; bus_addr : 'a
    ; bus_wdata : 'a
    }
  [@@deriving hardcaml]
end

(** The link. [status] is 8 bits and [rdata] 32 bits, as chip.md section 7 gives. *)
val create : Signal.t I.t -> Signal.t O.t

(** The link alone, as a circuit named [hostlink] (for [gen_verilog hostlink]). *)
val circuit : unit -> Circuit.t
