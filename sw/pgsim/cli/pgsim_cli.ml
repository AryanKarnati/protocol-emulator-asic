let () =
  if Array.length Sys.argv > 1 && Sys.argv.(1) = "chip-serve"
  then exit (Chip_serve.main (Array.sub Sys.argv 1 (Array.length Sys.argv - 1)))
  else exit (Runner.main Sys.argv)
