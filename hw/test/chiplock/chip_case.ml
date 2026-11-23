(* A chip lockstep case: the pin trace of the whole chip (docs/chip.md 5, 9.1 and 11), one entry
   per cycle. A case is only a pin sequence, so it is self-contained: any pin sequence has a
   defined result (chip.md 5), and the host operations that produced it are not needed to run it.

   [ui] is ui_in, [uio] the external level of each uio pad (the chip derives uio_in from it and
   its own uio_out and uio_oe, chip.md 9.2), and [rst] asserts reset for that cycle (chip.md 10).
   During a reset cycle nothing is compared. *)

type cyc =
  { ui : int
  ; uio : int
  ; rst : bool
  }

type t =
  { num_sms : int
  ; cycles : cyc array
  }

let format_name = "polyglot-chip-case"

let to_json (c : t) : Yojson.Safe.t =
  `Assoc
    [ "format", `String format_name
    ; "version", `Int 1
    ; "num_sms", `Int c.num_sms
    ; ( "cycles"
      , `List
          (Array.to_list c.cycles
           |> List.map (fun y -> `List [ `Int y.ui; `Int y.uio; `Bool y.rst ])) )
    ]
;;

let of_json (j : Yojson.Safe.t) : t =
  let open Yojson.Safe.Util in
  if member "format" j <> `String format_name then failwith "not a chip case file";
  let cyc = function
    | `List [ `Int ui; `Int uio; `Bool rst ] -> { ui; uio; rst }
    | _ -> failwith "bad cycle entry"
  in
  { num_sms = to_int (member "num_sms" j)
  ; cycles = to_list (member "cycles" j) |> List.map cyc |> Array.of_list
  }
;;

let write_file path c =
  let oc = open_out path in
  output_string oc (Yojson.Safe.pretty_to_string (to_json c));
  output_char oc '\n';
  close_out oc
;;

let read_file path = of_json (Yojson.Safe.from_file path)

(* Keep the pin levels inside their widths and the SM count valid. *)
let normalise (c : t) : t =
  { num_sms = max 1 (min 4 c.num_sms)
  ; cycles = Array.map (fun y -> { y with ui = y.ui land 0xFF; uio = y.uio land 0xFF }) c.cycles
  }
;;
