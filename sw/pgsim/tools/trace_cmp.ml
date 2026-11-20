(* trace_cmp: compare a silicon trace with pgsim, cycle by cycle.

   trace_cmp --latency L TRACE.jsonl

   L is the calibrated input/output latency in sysclk cycles (silicon-ref README,
   "Calibration"). It has no default. Samples before L have no pgsim counterpart and are
   printed, not skipped silently. Exit 0 if every compared sample matches, 1 on the
   first mismatch (printed with its sample index, capture pin and GPIO), 2 on error. *)

let () =
  let latency = ref None in
  let file = ref None in
  Arg.parse
    [ "--latency", Arg.Int (fun n -> latency := Some n), "L calibrated latency in cycles" ]
    (fun f -> file := Some f)
    "trace_cmp --latency L TRACE.jsonl";
  match !file, !latency with
  | Some f, Some l ->
    (try
       let r = Silicon_trace.compare_files ~latency:l f in
       if r.Silicon_trace.skipped_head <> []
       then
         Printf.printf
           "not compared: the first %d samples (before latency %d), values %s\n"
           (List.length r.Silicon_trace.skipped_head) l
           (String.concat " " (List.map (Printf.sprintf "%02x") r.Silicon_trace.skipped_head));
       Printf.printf "samples %d, compared %d (latency %d)\n" r.Silicon_trace.samples
         r.Silicon_trace.compared l;
       match r.Silicon_trace.first_mismatch with
       | None ->
         print_endline "no mismatch";
         exit 0
       | Some m ->
         Printf.printf
           "first mismatch: sample %d, pin %d (pins_base+%d): silicon %d, pgsim %d\n"
           m.Silicon_trace.sample m.Silicon_trace.pin m.Silicon_trace.pin
           m.Silicon_trace.silicon m.Silicon_trace.model;
         exit 1
     with
     | Failure msg | Sys_error msg ->
       prerr_endline ("error: " ^ msg);
       exit 2)
  | _ ->
    prerr_endline "usage: trace_cmp --latency L TRACE.jsonl";
    exit 2
;;
