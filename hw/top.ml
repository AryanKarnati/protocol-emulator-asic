(* Block 1 gate design, as specified in docs/gate.md. Module name: polyglot. *)

(* Alias our own FIFO before opening Hardcaml, whose Fifo module would shadow it. *)
module Fifo_hw = Fifo.Make (struct
    let width = 32
    let depth = 4
  end)

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

(* Command codes (ui_in[2:0]) *)
let cmd_push = 1
let cmd_pop = 2
let cmd_int_lo = 3
let cmd_int_hi = 4
let cmd_frac = 5
let cmd_div_restart = 6
let cmd_clear_flags = 7

let create (scope : Scope.t) (i : _ I.t) =
  (* Reset: async assert on rst_n, release through a 2-flop synchronizer.
     [core_rst_n] is low until the second flop has seen a high input. Commands sampled
     at the first two rising edges after release therefore hit reset and are ignored. *)
  let sync_spec =
    Reg_spec.override
      (Reg_spec.create () ~clock:i.clk)
      ~reset:i.rst_n
      ~reset_edge:Edge.Falling
      ~reset_to:gnd
  in
  let sync1 = reg sync_spec vdd -- "rst_sync1" in
  let core_rst_n = reg sync_spec sync1 -- "core_rst_n" in
  let core_spec ~reset_to =
    Reg_spec.override
      (Reg_spec.create () ~clock:i.clk)
      ~reset:core_rst_n
      ~reset_edge:Edge.Falling
      ~reset_to
  in
  (* Command decode. Every command is qualified by [core_rst_n]. *)
  let cmd = select i.ui_in 2 0 -- "cmd" in
  let byte_sel = select i.ui_in 4 3 -- "byte_sel" in
  let view = select i.ui_in 5 5 -- "view" in
  let is_cmd code = (core_rst_n &: (cmd ==: of_int ~width:3 code)) in
  let do_push = is_cmd cmd_push -- "do_push" in
  let do_pop = is_cmd cmd_pop -- "do_pop" in
  let wr_int_lo = is_cmd cmd_int_lo -- "wr_int_lo" in
  let wr_int_hi = is_cmd cmd_int_hi -- "wr_int_hi" in
  let wr_frac = is_cmd cmd_frac -- "wr_frac" in
  let div_restart = is_cmd cmd_div_restart -- "div_restart" in
  let clear_flags = is_cmd cmd_clear_flags -- "clear_flags" in
  (* FIFO push word: {DATA x4} XOR 0x0123_4567 *)
  let push_word =
    (concat_msb [ i.uio_in; i.uio_in; i.uio_in; i.uio_in ]
     ^: of_int ~width:32 0x0123_4567)
    -- "push_word"
  in
  let fifo =
    Fifo_hw.hierarchical
      scope
      { Fifo_hw.I.clk = i.clk
      ; rst_n = core_rst_n
      ; push = do_push
      ; pop = do_pop
      ; data_in = push_word
      }
  in
  (* Divider configuration: INT resets to 1, FRAC to 0. Writes do not restart. *)
  let int_lo_q =
    reg (core_spec ~reset_to:(of_int ~width:8 1)) ~enable:wr_int_lo i.uio_in
    -- "int_lo_q"
  in
  let int_hi_q =
    reg (core_spec ~reset_to:(zero 8)) ~enable:wr_int_hi i.uio_in -- "int_hi_q"
  in
  let frac_q =
    reg (core_spec ~reset_to:(zero 8)) ~enable:wr_frac i.uio_in -- "frac_q"
  in
  let clkdiv =
    Clkdiv.hierarchical
      scope
      { Clkdiv.I.clk = i.clk
      ; rst_n = core_rst_n
      ; int_ = concat_msb [ int_hi_q; int_lo_q ] -- "div_int"
      ; frac = frac_q
      ; restart = div_restart
      }
  in
  (* Sticky flags. Set by a dropped push or a refused pop, cleared by CLEAR_FLAGS. *)
  let overflow = wire 1 in
  let overflow_q =
    reg (core_spec ~reset_to:gnd) ((overflow &: ~:clear_flags) |: fifo.push_dropped)
    -- "overflow_q"
  in
  overflow <== overflow_q;
  let underflow = wire 1 in
  let underflow_q =
    reg (core_spec ~reset_to:gnd) ((underflow &: ~:clear_flags) |: fifo.pop_empty)
    -- "underflow_q"
  in
  underflow <== underflow_q;
  (* STATUS byte (VIEW = 1). LEVEL is 3 bits wide, as gate.md requires. The FIFO depth
     is 4, so LEVEL fits. *)
  let status =
    concat_msb
      [ clkdiv.tick
      ; uresize fifo.level 3
      ; fifo.full
      ; fifo.empty
      ; overflow_q
      ; underflow_q
      ]
    -- "status"
  in
  (* FIFO head byte (VIEW = 0), 0x00 when empty *)
  let head_byte =
    mux
      byte_sel
      [ select fifo.head 7 0
      ; select fifo.head 15 8
      ; select fifo.head 23 16
      ; select fifo.head 31 24
      ]
    -- "head_byte"
  in
  let data_view = mux2 fifo.empty (zero 8) head_byte -- "data_view" in
  { O.uo_out = mux2 view status data_view -- "uo_out"
  ; uio_out = zero 8
  ; uio_oe = zero 8
  }
;;

module Circuit_io = Circuit.With_interface (I) (O)

(* The top-level circuit, and the database holding its submodules (clkdiv, fifo_4x32). *)
let circuit () =
  let scope = Scope.create () in
  let circuit = Circuit_io.create_exn ~name:"polyglot" (create scope) in
  circuit, Scope.circuit_database scope
;;
