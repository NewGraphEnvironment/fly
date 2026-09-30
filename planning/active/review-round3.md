# Code-check round 3 — fly#65 (review of the round-2 fixes, and the claim set)

Worked read-only on the repo. The tests ran on an rsync copy under the session scratchpad
(`NOT_CRAN=true`, `load_all`): `test-fly_footprint_coastal.R` passed 74 of 74. Figures were
recomputed from the staged `inst/extdata/dem_coastal_frames.csv` (scratchpad `r3.R`). The
producer for every log citation below is `data-raw/.cache/logs/dem_coastal_run4.log`.

## Mechanism

The hypothesis holds, but it has two parts, and the second one matters more.

1. **One interpretive paragraph, copied five times.** `findings.md` "Reading" was written
   when the rule's pooled verdicts came back. It contains "both are the same defect: a
   rectangle cannot place four edges over four different elevations, which is the
   per-corner ray-casting fly#10 defers" and "the sea is one more elevation…". It was
   copied into the note, NEWS, CLAUDE.md, the roxygen and the test header. Where a claim
   had no producer, this story filled the gap: "per-corner fixes it", "the sea adds
   nothing", "misregistration" and "canopy does not discriminate". Where a producer did
   exist, rewording changed its qualifier or denominator: "151 … that have sea", "6 of
   223,667" and "five times".
   Each review round then fixed the copy it was pointed at. R1's "181 m down to 14 m" is
   fixed in the note and CLAUDE.md and still stands in NEWS. R2's "with sea" versus "d > 0"
   conflation came back in the text that fixed it ("the 151 … that have sea").
2. **The safety net was asserted, not enumerated.** The note says the CSVs "ship so
   `test-fly_footprint_coastal.R` recomputes every figure below". The test header says
   "every figure the note and NEWS quote is asserted here". NEWS says the script
   "reproduces every figure". Each round's author therefore treated a prose figure as
   checked. Only table rows and a hand-picked set of scalars are checked.
   Mutation test: `2.38%` → `9.99%` and `0.5% of width` → `0.1%` in the copy left the file
   green (74/74). The LidarBC and TRIM figures come from a probe that no repo script runs.

The candidate set this mechanism implies is every figure, count, comparison and causal
claim in the four documents. The table below lists them all.

## Findings

- **[high — published claim wrong, verdict-sensitive]** `inst/notes/terrain-correction.md:1020–1023`.
  The note says the canopy offset "affects W and L alike and does not discriminate between
  them". A common offset shifts both *signed* errors by the same δ ≈ land_share · c / height_agl.
  But the metric is `|err|`, and W and L err on opposite sides: signed medians are W +0.12%
  and L −0.60%. A positive δ therefore moves W away from truth and L toward it.
  Recomputed per frame from the CSV (land_share = `land_t/area_t`, median 0.61):

  | canopy c | median(\|W\|−\|L\|) | verdict |
  |---|---|---|
  | 0 m | −0.00287 | W |
  | 10 m | −0.00175 | W |
  | 20 m | −0.00076 | W |
  | 30 m | +0.00012 | tied |
  | 60 m | +0.00201 | L |

  At the lower bound of the note's own 30–60 m, the area verdict is a tie. At the upper
  bound it reverses. So the headline "W is twice as close on area" (note, NEWS, CLAUDE.md,
  roxygen) holds only if the imaged surface is bare earth. This is a first-order estimate,
  and real coastal land is not all forest, but the claim as written is false.
  Fix: state that the area verdict is conditional on a bare-earth surface and that a mean
  land canopy of about 30 m removes it.
  Also: "at 2,400 m" is not the sample. The median `height_agl` of the 1,242 frames is
  5,268 m (range 717–13,687). The caveat is also not labelled as unmeasured, which was the
  condition for accepting it.

- **[medium — unmeasured cause stated as fact, and contradicted by the note's own S]**
  `terrain-correction.md:1001–1005`, `NEWS.md:3` ("So the edge error is the rectangle's,
  which per-corner ray-casting would fix everywhere, not the sea's"), `CLAUDE.md:220–221`
  ("the edge error is the per-corner ray-casting fly#10 defers"), `R/fly_footprint.R:818`
  (milder).
  The note says the land-edge error exists because "a rectangle cannot put four edges over
  four different elevations", and that ray-casting "fixes the coastal edge along with every
  other one". No per-corner geometry was measured. S *does* put each side at its own
  elevation, and it removes only 16% of W's median edge error (4.43% → 3.71%). The 95th
  percentile is no better at high sea fraction (S 18.5% against W 20.8% in (0.75, 1]).
  Per-corner ray-casting yields a quadrilateral with straight edges, while the reference
  is a 128-point ring, so the residual along each edge is out of reach of both. What was
  measured is that W's pooled coastal 95th is under inland. Say that. Drop the attribution,
  or measure it with `per_edge = 1`.

- **[medium — causal gloss contradicted within the data]** `CLAUDE.md:219–221` ("so the sea
  adds nothing a rectangle does not already get wrong") and `terrain-correction.md:1003–1004`
  ("not a failure of its own").
  The rule's pooled test passes, and that verdict stands. The gloss does not. W's land-edge
  95th rises steadily with sea fraction:

  | sea fraction | n | W land-edge 95th |
  |---|---|---|
  | [0, 0.1] | 185 | 13.69% |
  | (0.1, 0.25] | 232 | 13.75% |
  | (0.25, 0.5] | 370 | 15.07% |
  | (0.5, 0.75] | 255 | 15.78% |
  | (0.75, 1] | 200 | 20.81% |

  Against 15.87% inland, the last band is 4.9 points over, which is past the +2 threshold
  within that band. The pooled comparison is also confounded by relief: median
  `dem_elev_sd` is 81 m coastal against 113 m inland. So "not worse than inland" does not
  isolate the sea's contribution. Report the pooled rule result, and disclose the tail by
  band or drop the "adds nothing" inference.

- **[medium — verification claim false]** `terrain-correction.md:873–875` ("Everything here
  is reproduced by `data-raw/dem_measure-coastal_water.R` … recomputes every figure below"),
  `test-fly_footprint_coastal.R:54` ("Every figure the note and NEWS quote is asserted
  here"), and `NEWS.md:5` ("reproduces every figure").
  Figures the note or NEWS publishes that the test does not assert, though each is
  derivable from the CSVs:
  - 2.38% and 14.77% (sensitivity);
  - 151;
  - the signed-error ranges −0.14%…+0.27% and 0.3%…0.7%;
  - 697 m and 0.5%;
  - 1,440×;
  - c052 9.95 m;
  - the "half … under 0.09".

  Not derivable from the CSVs: the control figures (1e-12, 2.6e-4, 6.4e-5, 3.1%, 0.78%)
  and spacing (−0.006, 0.0063).
  Not produced by any repo script at all: LidarBC 75% / 92% / −2.533 m and TRIM 503. They
  come from a probe run in a session scratchpad (findings.md G4).
  The mutation above confirms that two prose figures can change with the suite green. The
  fly#58 section's guard is framed as "a figure cannot be published here without being
  checked". This section claims the same and does not deliver it. Either assert the
  CSV-derivable figures, or narrow both sentences to "every table row and the counts".

- **[low-medium — wrong denominator]** `terrain-correction.md:1029` and
  `data-raw/dem_measure-coastal_water.R:308`. "fly#58 found 6 of 223,667 digital frames
  DEM-sized at all." fly#58's table (note line 580) is of the 173 digital *candidates*,
  meaning those that could reach nodata. Of those, 167 are sized from GSD and 6 by DEM.
  The DEM-sized count over all 223,667 was never measured. Write "6 of fly#58's 173 digital
  candidates", or drop the figure.

- **[low — arithmetic wrong]** `terrain-correction.md:924`. "the 2.6e-4 is five times under
  the 0.34% median error". 0.0034 / 2.56e-4 = 13.3×, and like for like the gap is larger
  still: 2.56e-4 of area is 1.28e-4 linear, so 27×. The error is in the conservative
  direction, but the number has no producer.

- **[low — R1 finding still in NEWS]** `NEWS.md:4`. "Its median runs from 181 m down to 14 m
  as the sea fraction rises." The band medians are 164.2, 180.6, 115.3, 53.3 and 13.9 m,
  which is not monotone from 181. The note and CLAUDE.md were fixed ("14–181 m"); NEWS was
  not.

- **[low — R2's conflation reintroduced in its own fix]** `terrain-correction.md:969`. "the
  151 excluded coastal frames that have sea". All 152 coastal `outside_not_sea` frames have
  sea (`n_sea > 0` is part of the test). 151 have `d > 0`. The 152nd, airp 1444863, has
  43,998 sea cells and d = −9.4e-5.

- **[low — stated as a property of 1 m tiles, measured on a derived grid]**
  `terrain-correction.md:892–893` and `NEWS.md:4`. "Two 1 m tiles over Howe Sound are 75%
  and 92% nodata over sea." Per findings.md G4, these shares were measured after
  aggregating to 20 m with any-NA → NA, which inflates nodata relative to the 1 m cells.
  "The rest reads a flat −2.533 m" comes from a median; flatness was not shown.

- **[low — conditional dropped]** `CLAUDE.md:230`. "and warns about interior nodata" is
  unconditional. The warning fires only under 0.95 coverage, as the note, NEWS and roxygen
  all say.

- **[low — overgeneralised]** `terrain-correction.md:958–959`. "run `c052` carries a flat
  9.95 m surface outside the polygon". Only 3 of c052's 10 frames do (1501404–06, outside
  median 9.94–9.95 m). 1501407, also excluded, sits at 0.016 m, and the other six are
  admitted or have no sea. The medians do not show flatness.

- **[low — count unreconciled]** `terrain-correction.md:949–951`. "180 coastal runs of ten
  consecutive frames … plus 60 inland control runs: 2,334 frames". That is 240 × 10 = 2,400.
  66 frames were dropped as drawn into two runs (script line 378), and 13 runs hold 2–9
  frames. The accounting list that follows, "every one is accounted for once", starts from
  2,334, so a reader cannot close the gap to 2,400.

- **[low — stale code comment]** `data-raw/dem_measure-coastal_water.R:652–653`. "since that
  test caught shoreline misregistration more than land borders". This is the cause R2
  retracted, and it contradicts the fix at 563–567.

- **[low — stale test comment]** `test-fly_footprint_coastal.R:7–8`. "neither is off by more
  than the per-corner cost every inland frame already carries" repeats R1's "neither"
  (L's coastal 95th area error is 3.30% against 3.18% inland) and the unmeasured per-corner
  attribution.

- **[informational]** findings.md says the Phase 1 probe is "reproduced as Stage 1". The
  run4 site figures differ from the Phase 1 table:

  | figure | Phase 1 | run4 |
  |---|---|---|
  | Strait of Georgia range | 0.074..0.205 | 0.094..0.195 |
  | Boundary Bay range | −1.87..1.07 | −1.195..0.066 |
  | Roberts Bank exact zeros | 1 | 0 |
  | Howe Sound land median | 293 | 239.5 |

  The windows or the method differ. The note quotes run4 and is consistent with it.

## Round-2 code fixes

- The script's cache guard (`setequal` on `airp_id`, `nrow`, `!anyDuplicated`) is correct.
  It still does not detect *code* drift in `measure_frame()` under an unchanged selection.
  That is not live: nothing in `measure_frame`, `raycast`, `cells_under` or `densify` has
  changed since 606b1d1, and run4 re-measured 0 of 240.
- The partition `stopifnot`, `no_land`, `rays_failed` (now including a non-finite `area_t`),
  control 3 (median 0.021 m) and the step gate at 128 rays (6.4e-5 < 1e-4) are all correct.
  The pub lines match the note.
- The test's 15-line pin fires: adding a row gives "actual 16", verified by mutation. The
  accounting and five-group assertions are sound, and NA fails loudly.
- The new lines 244 and 247 in the test file exceed the 120-character lint limit. That is
  style only.

## Enumeration table

"Producer" is a run4 log line, a test assertion (T) recomputing from the CSVs, a Phase 1
or G4 finding (P1), fly#58 (F58), or reasoning (R, with whether it is labelled).
**✗** means wrong or stated as measured when it is not.

### (a) Note — fly#65 section and the fly#58 Ocean bullet

| # | claim | producer | ok? |
|---|---|---|---|
| a1 | Ocean: 40,000 Hecate cells 0.098–0.189 m, no exact zeros | F58 (pre-existing) | ✓ |
| a2 | Ocean: coverage-1 case removing cells cannot produce | R (definitional) | ✓ |
| a3 | Ocean: "fly#65 found it is not one; averaging is better for area" | log area verdict | ✓, but see a45 (canopy) |
| a4 | fly#58 recorded sea at ~0.14 m | F58 range, median ~0.14 | ✓ |
| a5 | Premise "turned over"; averaging worse for area, L better only for the edge | log rules 2 and 3 | ✓ (bare-earth conditional, a45) |
| a6 | "by less than an inland frame already misses its own edges" | log 15.05 vs 15.87 | ✓ pooled |
| a7 | "No code changed" | git | ✓ |
| a8 | "Everything here is reproduced by the script … recomputes every figure below" | — | **✗** (LidarBC/TRIM not scripted; many prose figures untested) |
| a9 | Nine 3 km windows split by the terrestrial polygon | script Stage 1 (1500 m square buffer) | ✓ |
| a10 | Near sites: median 0.137–0.138, range 0.094..0.195, 0 zeros | log sites; T row | ✓ |
| a11 | Shore sites: median 0.026–0.073, down to −1.5 m, 0 zeros | log; T row | ✓ (Howe's 78 m max omitted, not claimed) |
| a12 | QC Sound and west Haida: all nodata | log; T | ✓ |
| a13 | Near-shore sea within a few tenths of CGVD2013 zero, "where the sea is" | medians; R unlabelled | ✓ (reasoning, benign) |
| a14 | Open water further out is nodata, fly#58's case | log a12 | ✓ |
| a15 | 14.8% of Roberts Bank land < 1 m | log in_band 0.148; T | ✓ |
| a16 | LidarBC two 1 m tiles 75% / 92% nodata over sea | P1 (G4), at 20 m any-NA | **✗** (derived grid; not scripted) |
| a17 | rest reads a flat −2.533 m | P1 median | **✗** flatness not shown (low) |
| a18 | LidarBC averages roughly land only; coverage < 1; warns under 0.95 | R from code (warning text, R/fly_footprint.R:1402) | ✓ |
| a19 | Same frame sized one way on MRDEM, the other on LidarBC | R | ✓ |
| a20 | TRIM WCS 503 | P1 | ✓ (not scripted) |
| a21 | Rule fixed before any coastal frame, replaced before any measured | findings Amendment 2 | ✓ |
| a22 | Spacing measures when the shutter fired; regulator has nothing to track over water | R, unlabelled | reasoning (design rationale; not a figure) |
| a23 | 128 points, 32 per edge; walks down from window max; bisection | script 184–243 | ✓ |
| a24 | Ridge occludes valley | R from algorithm | ✓ |
| a25 | Level DEM reproduced to 1e-12 | log 1.23e-12 | ✓ (order) |
| a26 | Step reproduced within 2.6e-4 | log −2.56e-4 | ✓ |
| a27 | Analytic 2a²((H−e)²+H²); W smaller by exactly a²e² | algebra | ✓ (verified) |
| a28 | 2.6e-4 over pre-registered 1e-4; 6.4e-5 at 128; gap 3.1% → 0.78% | log | ✓ |
| a29 | "2.6e-4 is five times under the 0.34% median" | — | **✗** 13× (27× linear) |
| a30 | W / L / S definitions; S not shipped | script | ✓ |
| a31 | Area → fly_coverage/fly_overlap; edge → fly_filter/fly_select | R (package design) | ✓ |
| a32 | Linear error and edge metric definitions | script 555–559, 476–479 | ✓ |
| a33 | 1D, shore under centroid: W exact total, L exact land edge | R, labelled "in one dimension" | ✓ (checked) |
| a34 | 95,222 of 1,437,147 (6.63%) | log; T | ✓ |
| a35 | About 1,440× the 66 | 95,222 / 66 = 1,443; F58 66 | ✓ (untested) |
| a36 | 180 coastal runs of ten, 12 strata, 60 inland, 2,334 frames | log | **✗** low: 2,400 − 66 dedup unexplained |
| a37 | 30 not eligible: 13 roll table, 17 implausible | log | ✓ |
| a38 | 157 with >10% outside > 2 m or any nodata; 152 coastal | log; T | ✓ |
| a39 | Half under 0.09 m; 42 > 0.5; 10 > 5 | log 0.09 / 42 / 28 / 10; T; exact 49.7% < 0.09 | ✓ |
| a40 | run c052 carries a flat 9.95 m surface | CSV (3 frames) | **✗** low: 3 of 10 frames; flatness unshown |
| a41 | "No single cause was measured" | — | ✓ |
| a42 | 23 no land cell; 0 rays nodata; 2,124 admitted | log; T | ✓ |
| a43 | Five groups 1,242 / 1 / 64 / 225 / 592; 138 and 59 rolls | log; T | ✓ |
| a44 | The one frame's sea higher than land, so L wider | CSV 1444862 | ✓ |
| a45 | 151 excluded coastal "that have sea"; no verdict moves; 2.38% / 14.77% | log | **✗** low (152 have sea; 151 have d > 0); figures ✓ but untested |
| a46 | Candidate table (8 figures) | log; T rows | ✓ |
| a47 | Area CI −0.0029 [−0.0036, −0.0023]; edge +0.0032 [+0.0024, +0.0043] | log run4 = run2 | ✓ (bootstrap accepted) |
| a48 | S equals W on area to first order; nearly matches L on edge | log −0.00000; 3.71 vs 3.67 | ✓ (reasoning checked: equal-area triangles) |
| a49 | L too small by a median 0.3–0.7%, whatever the sea fraction | log bands −0.29…−0.72 | ✓ (untested) |
| a50 | W signed −0.14% to +0.27% | log bands | ✓ (untested) |
| a51 | d 95th 3.2%; 38% of frames with sea > 1% | log 0.0318, 0.382; T | ✓ ("with sea" means d > 0, as R2) |
| a52 | Percentile table 2.16 / 3.18, 15.05 / 15.87 | log; T | ✓ |
| a53 | Neither excess reaches the 1%-of-width threshold | log PREMISE FALSE | ✓ |
| a54 | Edge error is the datum-offset defect: a rectangle cannot put four edges over four elevations | R, unlabelled | **✗** S contradicts (−16% only) |
| a55 | "The sea is one more elevation…, not a failure of its own" | R | **✗** edge 95th 20.8% at sea > 0.75 |
| a56 | "If ray-casting ships, it fixes the coastal edge…; nothing narrower would" | R, unlabelled | **✗** unmeasured; L and S are narrower and do improve it |
| a57 | dem_coverage and dem_shortfall_m cannot see the sea | R + T (half-sea fixture coverage 1) | ✓ |
| a58 | Synthetic step gives ~250 m | T 240–260 | ✓ |
| a59 | Medians 164 / 181 / … 14 against 113; "separates nothing" | log; T | ✓ figures; "separates nothing" read from medians (benign) |
| a60 | Land polygon is the flag; no column stands in | R | ✓ |
| a61 | Canopy 30–60 m worth 1–2.5% of width at 2,400 m | R, unlabelled | **✗** unlabelled; 2,400 m is not the sample (median 5,268) |
| a62 | Canopy "affects W and L alike, does not discriminate" | R | **✗ high**: 30 m ties, 60 m reverses the area verdict |
| a63 | Ray-cast shares MRDEM; tilt absent from all | R, labelled as a limit | ✓ |
| a64 | Tides ±3.5 m | R, unlabelled | **✗** low: acceptance condition (labelled) not met |
| a65 | At most 0.5% at 697 m; zero-mean | log (min height_agl 697.04); 3.5 / 697 = 0.502% | ✓ (rounding) |
| a66 | fly#58 found 6 of 223,667 digital DEM-sized | F58 table | **✗** 6 of 173 candidates |
| a67 | Spacing slope −0.006; W predicts 0, L +0.4; sd 0.0063 | log; findings rule (≈ 1 − p₀) | ✓ (disclaimed) |
| a68 | 95,222 counted; verdicts on 1,242 drawn by stratum | log | ✓ (medians unweighted; stated as a sample) |

### (b) NEWS.md top three bullets

| # | claim | producer | ok? |
|---|---|---|---|
| b1 | v0.14.0 said the mean is dragged toward sea level | F58 text | ✓ |
| b2 | MRDEM carries that sea at about 0.14 m, not nodata | log near sites | ✓ |
| b3 | Over water that is the surface the photo images | R | ✓ (bare earth on land: a62) |
| b4 | Ray-cast over 1,242 coastal of 2,124 admitted, in 180 + 60 runs | log; T | ✓ |
| b5 | Twice as close on area: 0.34% vs 0.67% median | log; T | ✓ (canopy-conditional, a62) |
| b6 | L misplaces 3.7% of land against 4.4% | log; T | ✓ |
| b7 | Not worse coastal than inland: 2.16 vs 3.18; 15.1 vs 15.9 | log; T | ✓ pooled |
| b8 | "So the edge error is the rectangle's, which per-corner ray-casting would fix everywhere, not the sea's" | R | **✗** (a54–a56) |
| b9 | 95,222 of 1,437,147 (6.63%) | log; T | ✓ |
| b10 | Two LidarBC tiles 75% / 92% nodata | P1 (20 m any-NA) | **✗** (a16) |
| b11 | Mean roughly land-only; warns under 95% | R from code | ✓ |
| b12 | dem_elev_sd "runs from 181 m down to 14 m as the sea fraction rises", 113 inland | log (164.2, 180.6, …) | **✗** not monotone (R1, unfixed here) |
| b13 | Script "reproduces every figure"; suite recomputes | — | **✗** LidarBC and TRIM not scripted |
| b14 | Note records why spacing was dropped before any frame measured | findings Amendment 2 | ✓ |

### (c) CLAUDE.md — fly#65 Key Decision, fly#58 sentence, Architecture entry

| # | claim | producer | ok? |
|---|---|---|---|
| c1 | fly#58 sentence: coverage-1 case the sweep cannot generate; fly#65 found it is not a failure | F58; log | ✓ |
| c2 | Sea at ~0.14 m; "dragged toward sea level" quote | log; F58 | ✓ |
| c3 | Over water the imaged surface is the sea | R | ✓ |
| c4 | 1,242 frames; W beats L on area 0.34 vs 0.67 (median unnamed) | log; T | ✓ |
| c5 | L beats W on edge 3.7 vs 4.4% of land area | log; T | ✓ |
| c6 | W coastal under inland at the 95th on both metrics | log; T | ✓ |
| c7 | "so the sea adds nothing a rectangle does not already get wrong" | R | **✗** (a55) |
| c8 | "the edge error is the per-corner ray-casting fly#10 defers" | R | **✗** (a54) |
| c9 | Instrument changed before any frame measured | findings | ✓ |
| c10 | Spacing measures shutter timing; regulator has nothing to track | R | reasoning (a22) |
| c11 | Flat and step controls converge | log | ✓ |
| c12 | Verdict depends on consumer (area vs edge) | R + log | ✓ |
| c13 | LidarBC mostly nodata over sea; sized ≈L "and warns about interior nodata" | P1; R | **✗** low: the warning is conditional (< 0.95) |
| c14 | dem_elev_sd 14–181 against 113 | log; T | ✓ |
| c15 | 14.8% of delta land < 1 m | log; T | ✓ |
| c16 | Architecture: script ray-casts, scores W / L / S, ships three CSVs the test recomputes; SMOKE writes nothing | script | ✓ (the "recomputes" scope: a8) |

### (d) Roxygen (`R/fly_footprint.R:811–821`, `man/fly_footprint.Rd`)

| # | claim | producer | ok? |
|---|---|---|---|
| d1 | Sized from land and sea together, "right for area" | log | ✓ bare-earth conditional (a62) |
| d2 | Sea at about 0.14 m, not nodata; dem_coverage stays near 1 | log; T | ✓ |
| d3 | 1,242 frames; twice as close, 0.34 vs 0.67 of width (median unnamed) | log; T | ✓ |
| d4 | Land-only places the edge better, 3.7 vs 4.4 | log; T | ✓ |
| d5 | Package's edge error no worse than inland | log pooled | ✓ |
| d6 | "The rectangle is the limit there, not the sea" | R | **✗** low-medium (a54/a55, milder wording) |
| d7 | LidarBC mostly nodata; sized mostly from land; warns under 95% | P1; R | ✓ |
