(* The host link: an SPI mode 0 target, oversampled in the clk domain (docs/chip.md
   sections 6 and 7). It knows nothing about registers. The register block answers the
   bus read combinationally from [bus_addr], and the link puts the answer on MISO.

   Pin flops (section 6.1): SCK and CS_N have three flops, s1 to s3, and MOSI has two,
   because its third flop has no use. Each reset to its idle level.

   Frame position (section 6.3): [cnt] counts bits. In the header (bits 0 to 23) it is the
   bit index. From bit 24 on, [in_body] is set and [cnt] is the bit index minus 24, mod
   32. Then the word events are at cnt 31 (write access, bit 55 + 32m), cnt 7 (read access,
   bit 31 + 32m) and cnt 8 (commit, bit 32 + 32m). A frame has no length limit, so [cnt]
   wraps. *)

open Hardcaml
open Signal

module I = struct
  type 'a t =
    { clock : 'a
    ; rst_n : 'a
    ; sck : 'a
    ; mosi : 'a
    ; cs_n : 'a
    ; status : 'a [@bits 8]
    ; rdata : 'a [@bits 32]
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { miso : 'a
    ; bus_write : 'a
    ; bus_read : 'a
    ; bus_commit : 'a
    ; bus_addr : 'a [@bits 16]
    ; bus_wdata : 'a [@bits 32]
    }
  [@@deriving hardcaml]
end

let create (i : _ I.t) =
  let plain = Reg_spec.create () ~clock:i.clock in
  let synced idle =
    Reg_spec.override plain ~reset:i.rst_n ~reset_edge:Edge.Falling ~reset_to:idle
  in
  (* Synchronisers (6.1). p2 and p3 are the signals of cycle t, p(t-2) and p(t-3). *)
  let sck2 = reg (synced gnd) (reg (synced gnd) i.sck) in
  let sck3 = reg (synced gnd) sck2 in
  let cs2 = reg (synced vdd) (reg (synced vdd) i.cs_n) in
  let cs3 = reg (synced vdd) cs2 in
  let mosi2 = reg (synced gnd) (reg (synced gnd) i.mosi) in
  (* Events (6.2). *)
  let start = (~:cs2) &: cs3 in
  let frame_end = cs2 &: ~:cs3 in
  let rise = sck2 &: ~:sck3 &: ~:cs2 &: ~:cs3 in
  (* Frame state. Every wire is driven below. *)
  let in_body_w = wire 1 in
  let cnt_w = wire 5 in
  let hdr_last = (~:(in_body_w)) &: (cnt_w ==:. 23) in
  let cnt_d =
    mux2 start (zero 5) (mux2 rise (mux2 hdr_last (zero 5) (cnt_w +:. 1)) cnt_w)
  in
  let cnt = reg (synced (zero 5)) cnt_d in
  cnt_w <== cnt;
  let in_body_d = (~:start) &: (in_body_w |: (rise &: (cnt_w ==:. 23))) in
  let in_body = reg (synced gnd) in_body_d in
  in_body_w <== in_body;
  (* Command bits (6.3): R is bit 0 and F is bit 1. *)
  let r_q = reg plain ~enable:(rise &: ~:in_body &: (cnt ==:. 0)) mosi2 in
  let f_q = reg plain ~enable:(rise &: ~:in_body &: (cnt ==:. 1)) mosi2 in
  (* The last 32 MOSI bits. At a write access, the word is these 31 bits and this cycle's
     bit, so the write data is the next value of the register. *)
  let rxsr_w = wire 32 in
  let rx_next = concat_msb [ select rxsr_w 30 0; mosi2 ] in
  let rxsr = reg plain ~enable:rise rx_next in
  rxsr_w <== rxsr;
  (* Bus address (6.4). It holds ADDR when the header ends, then steps by 4 after each
     word unless F is set. The step lands at the end of the word's last event, so the
     address stays addr_m through that event. *)
  let addr_w = wire 16 in
  let hdr_end = rise &: hdr_last in
  let word_end =
    rise &: in_body &: (mux2 r_q (cnt ==:. 8) (cnt ==:. 31)) &: ~:f_q
  in
  let addr_load = concat_msb [ select rx_next 15 2; zero 2 ] in
  let addr_d = mux2 hdr_end addr_load (mux2 word_end (addr_w +:. 4) addr_w) in
  let addr = reg plain ~enable:vdd addr_d in
  addr_w <== addr;
  (* Bus pulses (6.4), all in the cycle of the RISE that delivers the bit. *)
  let bus_write = rise &: in_body &: ~:r_q &: (cnt ==:. 31) in
  let bus_read = rise &: in_body &: r_q &: (cnt ==:. 7) in
  let bus_commit = rise &: in_body &: r_q &: (cnt ==:. 8) in
  (* MISO (6.5). The shift register changes only at the events the table lists. *)
  let sr_w = wire 32 in
  let sr_d =
    mux2
      start
      (concat_msb [ i.status; zero 24 ])
      (mux2
         frame_end
         (zero 32)
         (mux2 rise (mux2 bus_read i.rdata (sll sr_w 1)) sr_w))
  in
  let sr = reg (synced (zero 32)) sr_d in
  sr_w <== sr;
  { O.miso = select sr 31 31
  ; bus_write
  ; bus_read
  ; bus_commit
  ; bus_addr = addr
  ; bus_wdata = rx_next
  }
;;

let circuit () =
  let module C = Circuit.With_interface (I) (O) in
  C.create_exn ~name:"hostlink" create
;;
