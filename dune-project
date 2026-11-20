(lang dune 3.17)
(generate_opam_files true)

(package
 (name polyglot)
 (allow_empty)
 (synopsis "Four RP2040-PIO-compatible protocol engines with line coding units")
 (depends
  ocaml
  dune
  hardcaml
  ppx_hardcaml
  hardcaml_waveterm
  core
  core_unix
  ppx_jane
  ppx_expect
  yojson))
