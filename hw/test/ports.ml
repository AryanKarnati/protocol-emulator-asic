(* The pio_block ports of docs/engine.md section 3, as OCaml values. A DUT sees one
   [inputs] record per cycle and returns [outputs] (the register outputs of the cycle, and
   the combinational rxf_data). Names in [fields] are the Verilog port names. *)

type inputs =
  { rst_n : bool
  ; sm_enable : int (** 4 bits, level *)
  ; clkdiv : int array (** 4 x 32, level, RP2040 layout *)
  ; execctrl : int array
  ; shiftctrl : int array
  ; pinctrl : int array
  ; sync_bypass : int (** 32 bits, level *)
  ; pins_ext : int (** external pad levels, the stimulus (pgsim's [ext]) *)
  ; pins_in : int (** the [pins_in] port: pins_out/oe with the external level elsewhere *)
  ; sm_restart : int (** 4 bits, pulse *)
  ; clkdiv_restart : int (** 4 bits, pulse *)
  ; fifo_flush : int (** 4 bits, pulse *)
  ; irq_clear : int (** 8 bits, pulse *)
  ; irq_force : int (** 8 bits, pulse *)
  ; fdebug_clear : int (** 32 bits, pulse, RP2040 FDEBUG layout *)
  ; txf_push : (int * int) option (** (sm, data), at most one per cycle *)
  ; rxf_pop : int option (** sm, at most one per cycle *)
  ; instr_write : (int * int) option (** (sm, data) *)
  ; imem_write : (int * int) option (** (addr, data) *)
  }

type outputs =
  { pins_out : int
  ; pins_oe : int
  ; irq : int
  ; fstat : int
  ; flevel : int
  ; fdebug : int
  ; pc : int array (** 5 bits each *)
  ; x : int array
  ; y : int array
  ; isr : int array
  ; osr : int array
  ; cnt : int array (** DBG_CNT *)
  ; exec_stalled : int array
  ; phase : int array (** 25 bits: the divider phase in 1/256 cycle *)
  ; rxf_data : int (** combinational, meaningful in a cycle with [rxf_pop] *)
  }

let idle ~rst_n =
  { rst_n
  ; sm_enable = 0
  ; clkdiv = Array.make 4 0
  ; execctrl = Array.make 4 0
  ; shiftctrl = Array.make 4 0
  ; pinctrl = Array.make 4 0
  ; sync_bypass = 0
  ; pins_ext = 0
  ; pins_in = 0
  ; sm_restart = 0
  ; clkdiv_restart = 0
  ; fifo_flush = 0
  ; irq_clear = 0
  ; irq_force = 0
  ; fdebug_clear = 0
  ; txf_push = None
  ; rxf_pop = None
  ; instr_write = None
  ; imem_write = None
  }
;;

(* Pads as the testbench drives pins_in (engine.md R1). [regs] are the register outputs of
   the cycle, and [ext] the external level. *)
let pins_in_of ~pins_out ~pins_oe ~ext = (pins_out land pins_oe) lor (ext land lnot pins_oe)

(* Bits of the RP2040 FSTAT, FLEVEL and FDEBUG layouts that belong to SM [i]. *)
let fstat_bits i = (1 lsl i) lor (1 lsl (8 + i)) lor (1 lsl (16 + i)) lor (1 lsl (24 + i))
let fdebug_bits i = fstat_bits i lor (1 lsl (28 + i))
let flevel_bits i = 0xFF lsl (8 * i)

let sm_mask ~num_sms f =
  let m = ref 0 in
  for i = 0 to num_sms - 1 do
    m := !m lor f i
  done;
  !m
;;

(* Every port in the order the reports use. [rxf_data] is compared separately. *)
let fields (o : outputs) : (string * int) list =
  let per name a = List.init 4 (fun i -> Printf.sprintf "%s%d" name i, a.(i)) in
  [ "pins_out", o.pins_out; "pins_oe", o.pins_oe; "irq", o.irq; "fstat", o.fstat
  ; "flevel", o.flevel; "fdebug", o.fdebug
  ]
  @ per "dbg_pc" o.pc
  @ per "dbg_x" o.x
  @ per "dbg_y" o.y
  @ per "dbg_isr" o.isr
  @ per "dbg_osr" o.osr
  @ per "dbg_cnt" o.cnt
  @ per "dbg_exec_stalled" o.exec_stalled
  @ per "dbg_phase" o.phase
;;

let zero_outputs =
  { pins_out = 0
  ; pins_oe = 0
  ; irq = 0
  ; fstat = 0
  ; flevel = 0
  ; fdebug = 0
  ; pc = Array.make 4 0
  ; x = Array.make 4 0
  ; y = Array.make 4 0
  ; isr = Array.make 4 0
  ; osr = Array.make 4 0
  ; cnt = Array.make 4 0
  ; exec_stalled = Array.make 4 0
  ; phase = Array.make 4 0
  ; rxf_data = 0
  }
;;
