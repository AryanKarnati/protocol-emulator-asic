# SRAM macro research: `RM_IHPSG13_1P_512x32`

Research for the block 3 SRAM call (DESIGN §12, PLAN block 3, chip.md §8.4). No hardening was run.
Sources are pinned by commit. The walkthrough details in §3 came through a summarising fetch and
still need checking against the page before any config is used.

## 1. Availability for the CI PDK (answer first)

**Yes, the macro is in the `ihp-sg13cmos5l` PDK tree, not only `ihp-sg13g2`.**

At both IHP-Open-PDK commits in play, `ihp-sg13cmos5l/libs.ref/sg13cmos5l_sram` is a **symlink** to
`../../ihp-sg13g2/libs.ref/sg13g2_sram`, so the CMOS5L PDK gets the same files, with the same blob
hash (`39b7bae9a81ac42304e3dc37b2c77f5d723f325a`):

- `e73adb4045731ddec21634146d536380057f6a26` (the commit pinned in `flow/estimate.sh`). Symlink
  verified via the GitHub contents API.
- `2bbec755dc67ca3db0261c3d6163e15735d66710` (the commit the walkthrough says Tiny Tapeout's precheck
  pins). Symlink verified, and the 512x32 LEF is present.

The DRC deck the walkthrough names is present at e73adb4: `ihp-sg13cmos5l/libs.tech/klayout/tech/drc/ihp-sg13cmos5l.drc`.

**Not verified:** which IHP-Open-PDK commit `tt-gds-action@ttihp27a` with LibreLane `3.1.0.dev4`
actually installs for `ihp-sg13cmos5l`. The action does not pin it in `tt-support-tools`. Both commits
above contain the macro, so the answer holds for either. The cell-level check is the first CI run with
the macro in `MACROS`.

**Shuttle use:** the walkthrough is a Jane Street TT CMOS5L project that uses this macro
(`ihp-um-janestreet-prism`). The DESIGN appendix cites `urish/ttihp-sram-test`, which I did not read.
So a TT IHP shuttle can use it. The first real test is the hardening run.

## 2. Exact module, ports and tie-offs

Source: `ihp-sg13g2/libs.ref/sg13g2_sram/verilog/RM_IHPSG13_1P_512x32_c2_bm_bist.v` at e73adb4.

**The module name is `RM_IHPSG13_1P_512x32_c2_bm_bist`.** DESIGN §12, chip.md §8.4 and the block 3
PLAN text say `RM_IHPSG13_1P_512x32`. That name does not exist in the PDK (no file or module has it).
chip.md §8.4 and DESIGN §12 now use the full name (main 6c4d48b).

```verilog
module RM_IHPSG13_1P_512x32_c2_bm_bist (
    A_CLK, A_MEN, A_WEN, A_REN, A_ADDR[8:0], A_DIN[31:0], A_DLY, A_DOUT[31:0], A_BM[31:0],
    A_BIST_CLK, A_BIST_EN, A_BIST_MEN, A_BIST_WEN, A_BIST_REN, A_BIST_ADDR[8:0],
    A_BIST_DIN[31:0], A_BIST_BM[31:0]);
```

| Port | Dir | Width | Use in block 3 |
| --- | --- | --- | --- |
| `A_CLK` | in | 1 | the `clk` |
| `A_MEN` | in | 1 | macro enable: 1 for a read or write |
| `A_WEN` | in | 1 | write enable (with `A_MEN`) |
| `A_REN` | in | 1 | read enable (with `A_MEN`) |
| `A_ADDR` | in | 9 | word address, `j` of chip.md §8.4 |
| `A_DIN` | in | 32 | write data |
| `A_BM` | in | 32 | **write mask, 1 = write that bit** (core model: `memory <= (mem & ~BM) \| (DIN & BM)`). Tie to all ones for full-word writes. |
| `A_DLY` | in | 1 | **tie to `1'b1`.** The model prints an error and `$stop`s in simulation if it is not 1. |
| `A_DOUT` | out | 32 | read data, registered (1-cycle read latency) |
| `A_BIST_*` | in | | **tie off:** `A_BIST_CLK = 0`, `A_BIST_EN = 0`, `A_BIST_MEN = 0`, `A_BIST_WEN = 0`, `A_BIST_REN = 0`, `A_BIST_ADDR = 9'h0`, `A_BIST_DIN = 32'h0`, `A_BIST_BM = 32'h0` |

BIST enable selects `A_BIST_BM` over `A_BM` inside the core model, so `A_BIST_EN = 0` is what makes
`A_BM` the mask. `A_BM` is not a BIST pin, so it must not be tied off to zero. A zero mask would make
every write a no-op.

## 3. Physical files, config and walkthrough settings

The walkthrough is Ken Pettit's IHP SRAM integration page:
https://kdp1965.github.io/ihp-um-janestreet-prism/ihp_sram_macro.html

**Paths** (relative to `$PDK_ROOT/$PDK/`, pinned at e73adb4):

- LEF: `ihp-sg13g2/libs.ref/sg13g2_sram/lef/RM_IHPSG13_1P_512x32_c2_bm_bist.lef`
  (reached as `libs.ref/sg13cmos5l_sram/lef/...` on CMOS5L). Verified: `SIZE 416.64 BY 191.34`, pins on Metal2 and Metal4.
- GDS: `libs.ref/sg13cmos5l_sram/gds/RM_IHPSG13_1P_512x32_c2_bm_bist.gds` (walkthrough; file existence in the g2 listing at e73adb4 not checked separately).
- Liberty, slow: `libs.ref/sg13cmos5l_sram/lib/RM_IHPSG13_1P_512x32_c2_bm_bist_slow_1p08V_125C.lib`. Verified in the g2 tree at e73adb4.
  Typical: `..._typ_1p20V_25C.lib`. Fast: `..._fast_1p32V_m55C.lib`.
- Verilog model: `ihp-sg13g2/libs.ref/sg13g2_sram/verilog/RM_IHPSG13_1P_512x32_c2_bm_bist.v` (plus `RM_IHPSG13_1P_core_behavioral_bm_bist.v`).
- CDL: `libs.ref/sg13cmos5l_sram/cdl/RM_IHPSG13_1P_512x32_c2_bm_bist.cdl` (walkthrough).

**`config.json`, as the walkthrough gives it (not checked against the page text):**

- `MACROS` entry key `RM_IHPSG13_1P_512x32_c2_bm_bist` with `gds`, `lef`, `spice` (CDL) and the three
  `lib` corner files mapped to `nom_typ_1p20V_25C`, `nom_fast_1p32V_m40C` and `nom_slow_1p08V_125C`.
  The walkthrough's `nom_fast_1p32V_m40C` key points at the `m55C` file, which is a naming mismatch the
  recipe should look at, not copy.
- Placement: `"location": [x, y]` and `"orientation"` fixed. The walkthrough's values
  (`[3.36, 3.78]`, `"FS"`) are for its own floorplan, not for the 8x4 die. The 8x4 die is
  1724.16 × 710.64 µm (DESIGN Appendix A), so the position must be chosen fresh.
- PDN, Metal4 only: `FP_PDN_MULTILAYER: 0`, `FP_PDN_VWIDTH: 2.1`, `FP_PDN_VSPACING: 3.52`,
  `FP_PDN_VPITCH: 44.96`, `FP_PDN_VOFFSET: 6.15`. The current `config.json` has `FP_PDN_VPITCH: 50.0`
  and `FP_PDN_VWIDTH: 2.1`, so the pitch and offset must be changed together with the macro position.
- Routing obstructions on Metal2, Metal3 and Metal4 over the macro box.
- Supply: two `PDN_MACRO_CONNECTIONS` lines per instance, mapping `VDD!` and `VDDARRAY!` to `VPWR`/`VGND`,
  with `VSS!` to `VGND`.
- Halo: `FP_MACRO_HORIZONTAL_HALO: 2` (µm).
- Checks: `RUN_KLAYOUT_DRC: 1` with `pdk_dir::libs.tech/klayout/tech/drc/ihp-sg13cmos5l.drc`. The template
  sets `RUN_KLAYOUT_DRC: 0` and `RUN_KLAYOUT_XOR: 0`, so these change. Magic DRC off and illegal-overlap
  error off (the walkthrough accepts 22 overlaps on VDD columns).

**Unverified:** every walkthrough config value in this section came through a summarising fetch, not the page text, and none was checked against a primary source. The file list, the module name and the liberty corners were checked against the IHP-Open-PDK commits.

**Open items on this section:** the walkthrough says the PDK's SRAM is "as the Tiny Tapeout precheck
expects". I did not confirm that. Its exact `config.json` text needs a direct check before the RTL or
flow lane copies any of it.

## 4. Timing and area

**Access (slow corner, verified from the liberty):** `A_DOUT` `rising_edge` from `A_CLK`:

- cell rise: 6.38 ns at the smallest input slew and load; 6.55 ns at 0.0064 pF load and 0.0288 ns slew;
  up to 6.69 ns at the heaviest index. Fall is 0.05 to 0.1 ns less.
- So the slow-corner access is **about 6.4 ns** at realistic loads. DESIGN §12's "6.45 ns worst-case"
  is a fair figure.
- Typical corner (verified): 3.81 ns rise, 3.75 ns fall. Matches DESIGN's "3.85 ns typical".

**Area (verified from LEF):** `416.64 × 191.34 µm` = 79,720 µm².

| Measure | µm² | Share of the 8x4 die (1,225,257 µm²) |
| --- | --- | --- |
| macro | 79,720 | 6.51% |
| macro with a 2 µm halo each side (420.64 × 195.34) | 82,168 | 6.71% |

The core is the die less the margins, so the share of the core is a little higher than these. The
margins were not computed. DESIGN §15's SRAM budget is "0.10 mm²" including the streamer, so the macro
alone is within it.

Timing budget: 6.4 ns access in a 16.67 ns cycle leaves about 10 ns for the address/mux and the
streamer path. Setup and hold on `A_ADDR`/`A_DIN`/`A_WEN` to `A_CLK` are in the liberty but were not
extracted here.

## 5. Recipe for the RTL lane (block 3 trial only)

The macro is trial only (chip.md §8.4), behind the `sram` parameter, and it is not in the lockstep.

```ocaml
(* In hw/regs.ml or a small hw/sram.ml, only when sram = true. Names are checked: *)
let sram ~clock ~enable ~write ~read ~addr ~wdata ~wmask =
  let outs =
    Hardcaml.Instantiation.create ~instance:"i_sram" ()
    ~name:"RM_IHPSG13_1P_512x32_c2_bm_bist"
    ~inputs:[
      "A_CLK", clock;
      "A_MEN", enable;
      "A_WEN", write;
      "A_REN", read;                  (* write and read must not both be high *)
      "A_ADDR", addr;                 (* 9 bits *)
      "A_DIN", wdata;                 (* 32 bits *)
      "A_BM", wmask;                  (* 32 bits; ones for a full-word write *)
      "A_DLY", vdd;                   (* constant 1 *)
      "A_BIST_CLK", gnd;
      "A_BIST_EN", gnd;
      "A_BIST_MEN", gnd;
      "A_BIST_WEN", gnd;
      "A_BIST_REN", gnd;
      "A_BIST_ADDR", zero 9;
      "A_BIST_DIN", zero 32;
      "A_BIST_BM", zero 32;
    ]
    ~outputs:[ "A_DOUT", 32 ]
  in
  Map.find_exn outs "A_DOUT"
```

- `Instantiation.create` takes `?instance`, `~name`, `~inputs` and `~outputs` (checked against the installed
  `hardcaml/instantiation.mli`). The code above is a sketch: the labelled-argument order, the `A_REN`
  choice and the `Map.find` need the RTL lane to check. The `A_REN` write-or-read choice is the RTL
  lane's to make, but a write and a read must not both be enabled in the same cycle.
- The Hardcaml `Instantiation` output is a plain module instance. For the Verilator/lockstep circuit,
  `sram = false` keeps it out. For `gen_verilog` with `sram = true`, the module has no definition in
  `src/`, so the macro comes from the PDK at hardening.
- The `A_DLY` pin must be `1`. The model `$stop`s otherwise.
- The read address, enable and data timing must follow §8.4: a write in cycle t is seen by reads from
  cycle t + 1, and the read is registered, so `A_DOUT` is valid one edge after the request.

## 6. Trial plan

1. **Baseline first.** Harden the 4-SM top with `sram = false`. Record utilisation, slow-corner setup slack
   at 16.67 ns and the GDS result, with the metrics step. This is the no-SRAM gate.
2. **SRAM trial.** A second branch with `sram = true`, the `MACROS` entry, a fixed placement, the PDN and
   obstruction settings from §3, the `ihp-sg13cmos5l` DRC deck, and `A_DLY` and BIST tied off as in §2.
   Check: the macro is placed inside the die with the halo clear; PDN connects; the KLayout DRC passes;
   precheck passes; gate-level sim with the macro's behavioural model.
3. **Decide.** Pass if the trial's utilisation stays at or below 55%, its slow-corner setup slack at
   16.67 ns is at least 0, and it passes precheck (DESIGN §12: drop it if it does not pass precheck by
   the end of week 3). If it fails, drop it, which is the first step in the PLAN fallback order.
4. **Record** the area, timing and pass/fail for the SRAM call (PLAN block 3, chip.md §13.5).

## Sources

- IHP-Open-PDK at e73adb4045731ddec21634146d536380057f6a26: `ihp-sg13g2/libs.ref/sg13g2_sram/{lef,lib,verilog}/`,
  `ihp-sg13cmos5l/libs.ref/sg13cmos5l_sram` (symlink), `ihp-sg13cmos5l/libs.tech/klayout/tech/drc/ihp-sg13cmos5l.drc`.
- IHP-Open-PDK at 2bbec755dc67ca3db0261c3d6163e15735d66710: `sg13cmos5l_sram` symlink and the 512x32 LEF.
- Walkthrough: https://kdp1965.github.io/ihp-um-janestreet-prism/ihp_sram_macro.html (summarised, not checked line by line).
- `~/.cache/polyglot/tt-support-tools/tech.py` (`IHPCmos5lTech`, `tt_corner`), and `.github/workflows/test-harden.yaml`.
- DESIGN.md §12, §13, §15, Appendix A and B; docs/chip.md §8.4, §13.
- Hardcaml `instantiation.mli` from `~/.opam/polyglot`.
