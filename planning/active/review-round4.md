# Code-check round 4 — fly#65 (terminate by enumeration)

I worked read-only on the repo. The tests ran on an rsync copy under the session scratchpad
(`NOT_CRAN=true`, `load_all`, `test_file`). Baseline for `test-fly_footprint_coastal.R` is
95 passed, 0 failed, 0 errors. Figures were recomputed from the staged
`inst/extdata/dem_coastal_frames.csv` (scratchpad `r4.R`). Every log citation below is
`data-raw/.cache/logs/dem_coastal_run5.log`.

## Result in one paragraph

Every number in the fly#65 note section, the NEWS bullets, CLAUDE.md, the roxygen and the
test header matches a run5 log line, the shipped CSV, fly#58's table, or arithmetic on
those. **No published figure is wrong.** The remaining defects are of two other kinds:

- **Qualifiers were dropped in the summaries.** "The land-edge error grows on mostly-sea
  frames" holds only at the 95th percentile; the median falls. "The sea does not make W
  worse than inland" holds only pooled; matched on relief, the land-edge margin is gone.
- **A coverage claim is still wider than its guard.** 18 prose-figure mutations to the note
  left the suite green, including round 3's own `2.38%` mutation.

## Findings

- **[medium] The median falls where the summaries say the error "grows".**
  Sites: `inst/notes/terrain-correction.md:873–874` ("the land-edge error grows on frames
  that are mostly sea"), `CLAUDE.md:221` ("W's land-edge error grows on mostly-sea
  frames"), `R/fly_footprint.R:816` and `man/fly_footprint.Rd:322` ("the second worsens on
  mostly-sea frames"), `tests/testthat/test-fly_footprint_coastal.R:7`.
  - Log `sea … edge W` lines give W's **median** land-edge error by sea band as 4.96, 4.88,
    4.41, 3.97 and 3.91%. It **falls**. Only the 95th rises: 13.69 to 20.81%.
  - Only NEWS carries the qualifier ("20.81% at the 95th percentile").
  - The roxygen and the test header are wrong in a second way. "the second" grammatically
    refers to "the land-only mean places the land edge better", and L's advantage **grows**
    with sea fraction. The median of `edge_W − edge_L` by band is 0.0000, 0.0004, 0.0038,
    0.0088 and 0.0153.
  - Fix: say "W's land-edge error at the 95th percentile rises on mostly-sea frames"
    everywhere, and name W, not "the second".

- **[medium] The relief confound is stated as "part of" the margin, and the shipped data put it
  at all of the land-edge margin.** Sites: `terrain-correction.md:1027` ("Taken as a whole, the
  sea does not make W worse than it is inland") and `:1043–1044` ("so part of the pooled margin
  is relief rather than sea"), `NEWS.md:3` ("asked whether the sea makes the package's error
  worse than inland, and it does not"), and the test title at `test-fly_footprint_coastal.R:201`.
  "Part of" is an inference with no producer.
  - **Reweighted:** inland frames reweighted to the coastal `dem_elev_sd` distribution
    (5 common bins) give a land-edge 95th of **15.06%**, against coastal **15.05%**. The
    pooled margin of −0.82 points goes to zero. On area, 2.95% against 2.16%, so area keeps
    most of its margin.
  - **Within common relief bins** (sd 0–25, 25–50, 50–100, 100–200 and over 200 m), the
    coastal land-edge 95th sits over inland by +9.0, +2.1, +5.8, +5.8 and −5.3 points.
    That is past the +2 threshold in the four bins holding 957 of the 1,242 frames. The
    pooled pass rests on the highest-relief bin.
  - **The pooled rule's verdict stands** as pre-registered. The NEWS wording "it does not"
    and the note's "the sea does not make W worse" go further than the evidence: they are
    causal readings of a confounded pool.
  - **Caveat on my own figures.** They are post hoc. The edge metric's denominator is land
    area, which differs in kind between coastal and inland frames, but that is equally true
    of the pooled test.
  - Fix: report "the pooled test passed", and either print the relief-reweighted figure or
    label "part of" as not measured.

- **[medium] The note says the test rebuilds its counts, but no prose figure in the note is read
  by the test.** Sites: `terrain-correction.md:879–881` ("rebuilds every table in this section
  and the counts from them") and `test-fly_footprint_coastal.R:55–57` ("its counts and prose
  figures asserted, at the precision printed. Not asserted: the bootstrap intervals … and the
  LidarBC/TRIM probe").
  - **What the test does.** It asserts CSV-derived values against **its own hardcoded
    literals**. It reads the note only for table rows and table-line counts, so a prose
    figure in the note can drift with the suite green.
  - **Mutation test** on the copy, all applied at once: "13 were DEM-sized"→14, "17"→16,
    `1e-12`→`1e-6`, `2.6e-4`→`9.6e-4`, "Nine"→"Eight", "20.8%"→"25.8%", "−0.006"→"+0.3",
    "81 m"→"31 m", "4.43% to 3.71%"→"5.43% to 2.71%", "0.71%"→"0.91%", "164 m and 181 m"→"64
    m and 81 m", both signed-median ranges, "2.38% … 14.77%"→"2.98% … 16.77%", "(697 m)"→"(297
    m)", "95,222"→"85,222". The same run also changed the QC table row to "**half nodata**" and
    the band table header to "W area 90th | W land edge median". Result: **95 passed, 0
    failed.**
  - Round 3's `2.38%`→`9.99%` mutation therefore still passes.
  - **Not asserted anywhere, not even against the CSV:** the 13/17 split of the 30 (both
    derivable from `height_source`/`footprint_terrain`), the nine sites (`nrow(sites)`), and
    every control figure (1e-12, 2.6e-4, 1.3e-4, 26×, 6.4e-5, 3.1% and 0.78%, which are not
    in the CSVs). The test header's list of what is not asserted omits all of these.
  - **Not rebuilt from the note:** the QC table row. The assertion at `:312–313` checks the
    sites CSV against itself and never reads the note. The five table headers are not
    rebuilt either.
  - Fix: either grep the note section for each formatted prose figure, as the rows already
    are, or narrow both sentences to "rebuilds every table row; counts are asserted against
    the CSV at the value the note prints, not read from the note". List the control figures
    among the things not asserted.

- **[low-medium] NEWS labels the canopy condition as measured.** `NEWS.md:4`: "Two conditions on
  that, **measured** and recorded rather than acted on. A canopy can reverse the area verdict…"
  - The canopy table is a first-order approximation. The note says so: "an approximation,
    not a re-run ray-cast". Its blind-spot list adds that no canopy-height model was used.
  - The bullet says "to first order" two sentences later, but it opens by calling the
    condition measured.
  - Fix: "one measured, one estimated to first order".

- **[low] "It separates nothing" and "flag none of this" are unmeasured, and the band now named as
  the exposure contradicts them.** Sites: `terrain-correction.md:1061–1064`, `NEWS.md:4`
  ("`dem_elev_sd` flag[s] none of this"), `test-fly_footprint_coastal.R:40–43` ("so it does not
  separate a coastal frame from a rugged inland one"), and the test title at `:236`.
  - No classifier was run. The assertions pin five medians, so none of them can fail on
    "does not separate".
  - In the sea > 0.75 band (where the note puts the 20.8% edge 95th), `dem_elev_sd` has a
    median of 13.9 m and an interquartile range of 4.2–25.1 m. Inland frames have a 5th
    percentile of 14.6 m and a median of 112.8 m. So half the mostly-sea frames sit under
    the inland 5th percentile.
  - Low sd does not identify the sea: flat inland land would also trip it. But "nothing" is
    stated as a finding, and "a rugged inland one" misdescribes the frames at issue.
  - Fix: "not tested as a flag; by band medians it overlaps inland except on mostly-sea
    frames".

- **[low] The canopy table is extended to a comparison it did not compute.**
  `terrain-correction.md:1021–1023`: "The coastal-against-inland comparison below survives
  every row".
  - The comparison below has an area row and a land-edge row. The canopy reconstruction
    (script `canopy()`, test `:290–299`) computes area only.
  - Fix: say "the area comparison".

- **[low] `w` is undefined in the published formula.** `terrain-correction.md:1011`: "the true
  footprint shrinks by `(agl − c(1 − w)) / agl`".
  - The script comment (`dem_measure-coastal_water.R:670–671`) defines `w` as the sea
    fraction of the returned rectangle's cells and says "linear size". The note says neither.

- **[low] "W and L err in opposite directions" holds pooled, not per band.** Site:
  `terrain-correction.md:1008–1009`.
  - Pooled signed medians are W +0.12% and L −0.60%, recomputed from the CSV; no log line
    prints them.
  - In the two lowest sea bands W's signed median is also negative (−0.14% and −0.04%;
    63% and 52% of frames negative). The canopy table, the producer of the verdict, is
    unaffected.

- **[low] Qualifiers are dropped on LidarBC in NEWS, CLAUDE.md and the roxygen.**
  `NEWS.md:5`, `CLAUDE.md:235` and `R/fly_footprint.R:816–817` all say "LidarBC is mostly
  nodata over sea".
  - The evidence (findings G4, and the note at `:899–901`) is **two tiles in Howe Sound,
    aggregated to 20 m with any-NA → NA**.
  - The note scopes it; the three summaries generalise it to the dataset.

- **[low] One window's figure is stated as general.** `CLAUDE.md:236`: "14.8% of delta land
  reads under 1 m".
  - It is one 3 km window, Roberts Bank's 1,362 land cells. The note has it right
    ("Roberts Bank's *land* cells").

- **[low] A test comment is contradicted by the assertion on the next line.**
  `test-fly_footprint_coastal.R:223`: "W within a quarter percent".
  - Line 227 asserts W's band range as −0.14% to **+0.27%**, which is over a quarter
    percent.

- **[low] Stale test comment.** `test-fly_footprint_coastal.R:255–256`: "three tables … A fourth
  fails here".
  - The assertion below it is `5L` separators, and the comment beneath it says 5 tables.

- **[low] One assertion is redundant.** `test-fly_footprint_coastal.R:121`:
  `180L * 10L + 60L * 10L - nrow(m) == 66L`.
  - With `nrow(m) == 2334L` asserted at `:92`, this cannot fail independently, and it does
    not test the claim "66 drawn twice".
  - The CSV can support that claim. The recompute gives 13 runs under 10 frames, short by
    exactly 66, and no run over 10. That matches the dedup at script `:378`, since every
    run is built as 10 consecutive frames (`OFFSETS -4:5`, `full`).
  - Fix: assert `max(table(run_id)) == 10` and `sum(10 - table(run_id)) == 66`.

- **[informational] The fly#58 sentence in CLAUDE.md drops "for area on bare earth".**
  `CLAUDE.md:211`: "fly#65 found it is not one". The note's Ocean bullet qualifies it;
  L beats W on the land edge.

## Checked and correct (not findings)

- **Sampling:** every run is drawn as ten consecutive frames, so 2,400 draws minus 66
  duplicates gives 2,334. It reconciles with the 13 short runs.
- **The 151:** it has `d > 0` under both filters. Paired verdicts with them back are area
  −0.0024 (W) and edge +0.0022 (L), so no verdict moves. The log prints only unpaired
  medians, but the recompute confirms.
- **c052:** per-frame outside medians are 9.944, 9.950 and 9.949 m. The test asserts the
  median of the three to 2 dp. 1501407 is at 0.016 m and is not counted.
- **Canopy:** the reconstructions in the test and the script are the same formula.
  Inland is taken as all land. The +0.00014 tie at 30 m and +0.00220 at 60 m reproduce.
- **Relief within each population:** coastal and inland 95ths both rise with relief. That
  is consistent with the note's direction, just not its magnitude (see finding 2).

## Enumeration table

Producer codes:

- **L**: a run5 log line.
- **T**: a test assertion that recomputes the figure from the CSVs and would fail on
  drift **of the CSV**. None of them reads the note's prose.
- **TR**: a test row that rebuilds a table line and would fail on drift **of the note**.
- **P**: planning findings.
- **F58**: the note's fly#58 table.
- **K**: a code constant.
- **A**: arithmetic on the above.
- **R**: reasoning, with whether it is labelled.

✗ marks a finding.

### (a) Note — fly#65 section (865–1085) and the fly#58 Ocean bullet (820–824)

| # | claim | producer | labelled if R? | ok? |
|---|---|---|---|---|
| a1 | Ocean: 40,000 Hecate cells 0.098–0.189 m, no exact zeros | F58 (fly#58's own window; run5's Hecate window is 0.105..0.17) | — | ✓ |
| a2 | coverage-1 case removing cells cannot produce | R (definitional) | n/a | ✓ |
| a3 | fly#65 found it is not one; on bare earth averaging is better for area | L area verdict | — | ✓ qualified |
| a4 | fly#58 recorded sea at ~0.14 m | L near-site medians 0.137–0.138 | — | ✓ |
| a5 | Over water the imaged surface is the sea | R | obvious | ✓ |
| a6 | W better for area, L for land edge (ray-cast on bare earth) | L paired medians | — | ✓ |
| a7 | area verdict depends on bare earth | canopy table (L) | first-order, labelled below | ✓ |
| a8 | "the land-edge error grows on frames that are mostly sea" | L band 95th only | — | **✗** median falls |
| a9 | No code changed; the rule said no remedy | git; L PREMISE FALSE | — | ✓ |
| a10 | Every figure below printed by the script and greppable | — | — | ✓ loosely; 1.3e-4, 26×, 1,440, 2,400, 66, 0.5%, 2,000 are arithmetic/constants, all verified |
| a11 | test rebuilds every table and the counts | TR (tables); counts are T only | — | **✗** counts not read from the note; 13/17 and "nine" not asserted |
| a12 | Nine 3 km windows | L (9 site lines); K 1500 m buffer | — | ✓ (not asserted) |
| a13 | Near sites median 0.137–0.138, range 0.094..0.195, 0 zeros | L; TR | — | ✓ |
| a14 | Shore sites median 0.026–0.073, down to −1.5 m, 0 zeros | L; TR | — | ✓ |
| a15 | QC Sound, west Haida all nodata | L; T (CSV only) | — | ✓; row not TR (finding) |
| a16 | near-shore sea within a few tenths of zero | L medians | benign R | ✓ |
| a17 | open water further out is nodata | L | — | ✓ |
| a18 | 14.8% of Roberts Bank land under 1 m | L in_band 0.148 (\|z\|<1, K BAND_M=1); T | — | ✓ |
| a19 | LidarBC two 1 m tiles, 20 m any-NA, 75% / 92% | P (G4 75.2 / 91.9) | not re-run, stated | ✓ |
| a20 | remaining sea median −2.533 m | P | — | ✓ |
| a21 | on LidarBC it averages mostly land; coverage < 1; warns under 0.95 | R from code (R/fly_footprint.R:1400) + P | — | ✓ |
| a22 | same frame one way on MRDEM, nearer the other on LidarBC | R | hedged ("nearer") | ✓ |
| a23 | TRIM WCS 503 | P | stated as probe | ✓ |
| a24 | rule fixed, then replaced before any frame measured | P (amendments) | — | ✓ |
| a25 | spacing measures shutter timing; regulator has nothing to track over water | R | design rationale (accepted) | ✓ |
| a26 | 128 points, 32 per edge; walk down from window max; bisection | K script `densify`/`raycast` | — | ✓ |
| a27 | ridge occludes valley | R from algorithm | — | ✓ |
| a28 | level DEM to 1e-12 | L 1.23e-12 | — | ✓ (not asserted) |
| a29 | analytic 2a²((H−e)²+H²), W smaller by a²e² | algebra (script :259) | — | ✓ |
| a30 | 32/edge is the density every frame was measured at | K `densify(per_edge = 32)` default in `measure_frame` | — | ✓ |
| a31 | 2.6e-4 over the pre-set 1e-4 | L −2.56e-4 | — | ✓ |
| a32 | ~1.3e-4 linear, 26× under 0.34% | A 2.56e-4/2 = 1.28e-4; 0.0034/1.28e-4 = 26.6 | — | ✓ |
| a33 | 128/edge: 6.4e-5; Jensen gap 3.1% → 0.78% | L | — | ✓ |
| a34 | W / L / S definitions; S not shipped | script `measure_frame` | — | ✓ |
| a35 | area → coverage/overlap; edge → filter/select | R (package design) | — | ✓ |
| a36 | metric definitions | script :556–559, :476–479 | — | ✓ |
| a37 | 1-D: W exact for length, L for land edge | R | labelled "in one dimension" | ✓ |
| a38 | 95,222 of 1,437,147 (6.63%) | L; T | — | ✓ (prose not TR) |
| a39 | centroid within nominal half-diagonal of FWA coastline | script :323 | — | ✓ |
| a40 | ~1,440× the 66 | A 1,442.8; T (round −1) | — | ✓ |
| a41 | 180 coastal runs of ten, 12 strata, 60 inland | L; T run counts; K OFFSETS | — | ✓ |
| a42 | 2,400 draws; 66 drawn twice; 2,334 | L 2334; A; CSV (13 short runs, shortfall 66) | — | ✓ (T at :121 is redundant) |
| a43 | 30 not eligible: 13 roll table, 17 implausible | L; T (30 only) | — | ✓; 13/17 not asserted |
| a44 | 157 with >10% outside > 2 m or any nodata | L; script :568; T | — | ✓ |
| a45 | 152 coastal | L; T | — | ✓ |
| a46 | half under 0.09 m; 42 > 0.5; 10 > 5 | L; T (49.7% < 0.09) | — | ✓ |
| a47 | three frames of c052 at a median of 9.95 m | CSV 9.944 / 9.950 / 9.949; T | — | ✓ |
| a48 | no single cause measured | — | — | ✓ |
| a49 | 23 no land; none nodata; 2,124 admitted | L; T | — | ✓ |
| a50 | five groups 1,242 / 1 / 64 / 225 / 592; 138 and 59 rolls | L; T | — | ✓ |
| a51 | 151 of the 152 have d > 0 | CSV; T | — | ✓ |
| a52 | putting them back changes no verdict; 2.38% / 14.77% | L (95ths, unpaired medians); T (95ths); paired recomputed −0.0024 / +0.0022 | — | ✓ |
| a53 | d 0.71% / 3.18% / 8.48%; 38.2% > 1% | L; T | — | ✓ |
| a54 | candidate table (8 figures) | L; TR | — | ✓ |
| a55 | 2,000 roll-bootstrap resamples | K N_BOOT = 2000 | — | ✓ |
| a56 | area −0.0029 [−0.0036, −0.0023] | L | — | ✓ (accepted, not asserted) |
| a57 | edge +0.0032 [+0.0024, +0.0043] | L | — | ✓ |
| a58 | S equals W on area to first order | L −0.00000; CSV −2.9e-7 | R reason given | ✓ |
| a59 | S cuts 4.43 → 3.71; "misses most of what W misses" | L; A 84% | — | ✓ |
| a60 | L signed −0.29% to −0.72% at every sea fraction | L; T | — | ✓ |
| a61 | W signed −0.14% to +0.27% | L; T | — | ✓ |
| a62 | MRDEM is a DTM | external fact | — | ✓ |
| a63 | W and L err in opposite directions | CSV pooled +0.12 / −0.60 | — | **✗ low** pooled only; bands 1–2 same sign |
| a64 | canopy moves both toward too wide by the same amount | R (first-order) | labelled first-order | ✓ |
| a65 | formula (agl − c(1 − w))/agl | script :670–675 | labelled approximation | **✗ low** w undefined, "linear" missing |
| a66 | canopy table (4 rows × 3) | L; TR | first-order, labelled | ✓ |
| a67 | W closer on bare / short veg, tie near 30 m, L under tall forest | L | — | ✓ |
| a68 | coastal-vs-inland comparison survives every row | L (area only) | — | **✗ low** edge row not computed |
| a69 | "because an inland frame is all land and takes the full shift" | R | reasoning; consistent with script | ✓ |
| a70 | property of DTM sizing, reaches every forested frame | R | unlabelled; fly#80 filed | ✓ (reasoning, not a figure) |
| a71 | "Taken as a whole, the sea does not make W worse than inland" | L pooled | — | **✗ medium** causal reading of a relief-confounded pool; edge margin is 0 at matched relief |
| a72 | pooled table 2.16 / 3.18, 15.05 / 15.87 | L; TR | — | ✓ |
| a73 | neither reaches the threshold of 1% of width | L PREMISE FALSE; K +0.01 / +0.02 | — | ✓ |
| a74 | edge 95th 13.7% → 20.8% (n = 200), past inland 15.9% | L; TR (band table) | post hoc, labelled | ✓ figures |
| a75 | "share taken of a small amount of land" | R (definitional) | — | ✓ |
| a76 | W area 95th falls to 0.64% | L; TR | — | ✓ |
| a77 | coastal sd median 81 vs 113 inland | L; T | — | ✓ |
| a78 | "so part of the pooled margin is relief" | none | unlabelled | **✗ medium** measured: all of the edge margin, some of the area margin |
| a79 | band table (5 × 3) | L; TR | — | ✓ (header not TR) |
| a80 | dem_coverage and dem_shortfall_m cannot see the sea | R + T (half-sea fixture coverage 1) | — | ✓ |
| a81 | synthetic step gives ~250 m | T 240–260 | — | ✓ |
| a82 | sd medians 164 / 181 → 14 against 113 | L; T | — | ✓ |
| a83 | "It separates nothing" | none (medians only) | unlabelled | **✗ low** |
| a84 | land polygon is the flag; no column stands in | R | — | ✓ (contingent on a83) |
| a85 | ray-cast shares MRDEM; tilt absent from all | R | labelled limit | ✓ |
| a86 | tides ±3.5 m; ≤ 0.5% at 697 m; zero-mean | L 697; A 0.502% | labelled "not measured" | ✓ |
| a87 | 6 of fly#58's 173 digital candidates DEM-sized | F58 (:580, :583) | — | ✓ |
| a88 | spacing slope −0.006; W 0, L +0.4; sd 0.0063 | L; P (:84) | disclaimed | ✓ |
| a89 | 95,222 counted; verdicts on 1,242 by stratum; median agl 5,268 m | L; T | — | ✓ (inland 592 also carry the verdicts; minor) |

### (b) NEWS.md, top three bullets

| # | claim | producer | ok? |
|---|---|---|---|
| b1 | v0.14.0 said MRDEM drags the mean "toward sea level" | F58 text | ✓ |
| b2 | MRDEM carries the sea at about 0.14 m, not nodata | L near sites | ✓ (shore sites 0.03–0.07; headline figure matches fly#58) |
| b3 | over water it is the surface the photo images | R | ✓ |
| b4 | ray-cast on bare earth, 1,242 coastal frames | L; T | ✓ |
| b5 | area 0.34% against 0.67% of width, median | L; T | ✓ |
| b6 | land edge 3.67% against 4.43% | L; T | ✓ |
| b7 | rule asked whether the sea makes it worse than inland, "and it does not": 2.16 / 3.18, 15.05 / 15.87 | L pooled | **✗ medium** (a71, a78); "pooled" missing |
| b8 | so no remedy warranted | L PREMISE | ✓ |
| b9 | 95,222 of 1,437,147 (6.63%) | L; T | ✓ |
| b10 | "Two conditions … measured and recorded" | canopy is first-order | **✗ low-medium** canopy not measured |
| b11 | uniform 30 m ties, 60 m favours L; first order | L | ✓ |
| b12 | property of DTM sizing anywhere, fly#80 | R | ✓ |
| b13 | land-edge error grows on mostly-sea frames: 20.81% at the 95th where sea > 3/4 | L | ✓ (95th stated) |
| b14 | dem_coverage, dem_shortfall_m, dem_elev_sd flag none of this | R | **✗ low** (a83) |
| b15 | LidarBC mostly nodata over sea | P (2 tiles, 20 m any-NA) | **✗ low** scope dropped |
| b16 | sized nearer L; warns under 95% | R from code | ✓ |
| b17 | script prints every figure above | L | ✓ (95% is a package constant) |
| b18 | ships three CSVs; the suite rebuilds the note's tables from them | TR | ✓ |
| b19 | note explains why spacing was dropped before any frame measured | P; note | ✓ |

### (c) CLAUDE.md — fly#65 entry, the fly#58 entry's last sentence, Architecture

| # | claim | producer | ok? |
|---|---|---|---|
| c1 | fly#58: coverage-1 case the sweep cannot generate; fly#65 found it is not a failure | F58; L | ✓ (informational: "for area on bare earth" dropped) |
| c2 | sea at ~0.14 m; fly#58's quote | L; F58 | ✓ |
| c3 | over water the imaged surface is the sea | R | ✓ |
| c4 | on bare earth W beats L on area; L beats W on the land edge | L | ✓ |
| c5 | pre-registered test passed, so nothing changed | L | ✓ (reported as the test; "pooled" absent but not causal) |
| c6 | canopy can reverse the area verdict; a DTM effect everywhere, fly#80 | L first-order | ✓ ("can") |
| c7 | "W's land-edge error grows on mostly-sea frames" | L 95th only | **✗ medium** median falls |
| c8 | instrument changed before any frame; spacing is shutter timing | P; R | ✓ (accepted) |
| c9 | flat and step controls converge | L | ✓ (accepted) |
| c10 | two answers, one per consumer | R + L | ✓ |
| c11 | three review rounds each found story-written prose | review-round1–3 | ✓ |
| c12 | note's tables rebuilt row by row by the test and counted | TR; line pin | ✓ (tables only; QC row and headers are counted, not rebuilt) |
| c13 | LidarBC mostly nodata over sea; ≈L; under 0.95 warns | P; R | **✗ low** scope dropped (b15) |
| c14 | "14.8% of delta land reads under 1 m" | L (one Roberts Bank window) | **✗ low** generalised |
| c15 | Architecture: ray-casts, scores W / L / S, ships three CSVs the test recomputes; SMOKE writes nothing | script | ✓ |

### (d) Roxygen `R/fly_footprint.R:811–818` (and `man/fly_footprint.Rd:317–324`, identical)

| # | claim | producer | ok? |
|---|---|---|---|
| d1 | sea at about 0.14 m, not nodata; mean takes in the sea; dem_coverage near 1 | L; T fixture | ✓ |
| d2 | on bare earth closer on area than the land-only mean | L | ✓ |
| d3 | land-only places the land edge better | L | ✓ |
| d4 | a canopy can reverse the first | L first-order | ✓ |
| d5 | "the second worsens on mostly-sea frames" | L 95th of W | **✗ medium** wrong referent (L's advantage grows) and median falls |
| d6 | LidarBC mostly nodata over sea; sized nearer land-only there | P | **✗ low** scope (b15) |

### (e) Test file header and comments (`test-fly_footprint_coastal.R`)

| # | claim | producer | ok? |
|---|---|---|---|
| e1 | :3 MRDEM carries the sea at ~0.14 m | L; T | ✓ |
| e2 | :4–5 fly#65 filed on the premise that W is an error | issue | ✓ |
| e3 | :5–6 on bare earth W better for area, L for the land edge | L; T | ✓ |
| e4 | :7 "the second worsens on mostly-sea frames" | — | **✗ medium** (d5) |
| e5 | :7–8 rule found no remedy warranted | L; T | ✓ |
| e6 | :9–10 tables rebuilt row by row at the end | TR | ✓ (not the QC row or headers) |
| e7 | :40–43 sd runs 14 to 181 against 113, "so it does not separate a coastal frame from a rugged inland one" | L; T medians | **✗ low** (a83) |
| e8 | :55–57 "its counts and prose figures asserted … Not asserted: bootstrap, LidarBC/TRIM" | — | **✗ medium** controls, 13/17 and nine not asserted; nothing asserted against the note's prose |
| e9 | :107–108 half at sea level, dozens not | T | ✓ |
| e10 | :120 2,400 drawn, 66 twice | T (tautological) | ✓ claim; **✗ low** assertion redundant |
| e11 | :122 three frames of c052 raised | T | ✓ |
| e12 | :201 test title "the sea does not make a coastal frame worse than an inland one" | T pooled | **✗** (a71; title only) |
| e13 | :223 "W within a quarter percent" | T :227 asserts +0.27% | **✗ low** |
| e14 | :236 test title "dem_elev_sd does not separate…" | T medians | **✗ low** the title cannot fail on its claim |
| e15 | :255–256 "three tables … A fourth fails" | T asserts 5 | **✗ low** stale |
| e16 | :259 5 headers, 5 separators, 18 rows (3/4/4/2/5) | T 28 | ✓ |
| e17 | :289 first-order canopy formula | script | ✓ matches |

## Test-code defects and whether each new assertion can fail

- **Canopy row rebuilder (`:290–299`):** the same formula as the script's `canopy()`, and the
  typographic minus is handled. It can fail on drift of the note or the CSV. ✓
- **Band row rebuilder (`:300–308`):** `lab` is hardcoded to the five levels, and it can fail
  on either. ✓ The header row is not rebuilt, so "95th" → "90th" in the header passed.
- **Sensitivity (`:215–222`):** 151 and both 95ths can fail on CSV drift. The paired "no
  verdict moves" is not asserted, but I recomputed it and it holds.
- **c052 (`:123–125`):** can fail on the count and on the 2-dp median. ✓
- **QC row (`:312–313`):** checks the CSV against itself, never reads the note, and repeats
  `:162–164`. It cannot fail on the note.
- **`:121`:** redundant with `:92` (see findings).
- **The 28-line pin:** fires on an added or removed row. It does not fire on an edited
  header or on an edited QC row.
