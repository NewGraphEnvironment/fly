# Review round 4: fly#80 prose and tests against their producers

Reviewer: subagent, 2026-09-30. Scope: `git diff main...HEAD` of inst/notes/terrain-correction.md,
NEWS.md, R/fly_footprint.R roxygen, CLAUDE.md, tests/testthat/test-fly_footprint_canopy.R and
test-fly_footprint_coastal.R. Producers: `data-raw/.cache/logs/canopy_final.log`,
`inst/extdata/dem_canopy_*.csv` (recomputed in R), `planning/active/findings.md`, and the script.

## Findings

- **[bug] NEWS.md:3** "1.2% of frames move more than 1%, **all of them in the fine band**". This is false.
  The shipped sample has **6 mid-band admitted frames with d > 1%** (weighted share of the mid band
  0.000185). The log prints that as `share over 1% 0.000`, which is rounding and not zero. By weight,
  99.5% of the over-1% mass is fine-band. Say "nearly all" or "99.5% by weight". The note's table
  (`0.0%`) is correct.
- **[bug] CLAUDE.md:265** "(1970s frames: 15%)" and **terrain-correction.md** "wrong on about one in
  seven 1970s frames". The denominator is mislabelled. 15.1% is the weighted share of the *known* 1970s
  frames **with d ≥ 0.5%** (weight 24,250 of the decade's 259,010 admitted weight). As a share of all
  1970s frames, the DSM-worse weight (3,243) is **1.3%**. The note's preceding clause ("most frames
  that matter") partly carries the qualifier. CLAUDE.md drops it completely.
- **[bug] terrain-correction.md, fly#80 section, "Over sea the DSM equals the DTM at every readable
  fly#65 site (mean difference 0.00 m)"**. `dem_canopy_sites.csv` / the log give Howe Sound
  **−0.03 m** (p95 |·| 0.48 m) and Roberts Bank **−0.01 m**. Four of the six readable sites are 0.00 m,
  not all six. The conclusion that follows, "so nothing in fly#65 depends on which surface is passed",
  is contradicted three sections later by the note's own measured row, which moves fly#65's
  median(|W|−|L|) from −0.00287 to −0.00127. What is surface-independent is the **sea** cells, not
  fly#65. NEWS.md:4 "Over sea the DSM equals the DTM" has the same issue in milder form.
- **[fragile] NEWS.md:3** "weighted back to the **1,437,124 DEM-eligible** ones" is a mislabel. The
  log gives 1,437,147 DEM-eligible film frames, and the fly#65 entry in the same file says 1,437,147.
  1,437,124 are the ones *with a canopy value*. Also, every percentile quoted is over the **594
  admitted** frames, which carry **1,425,189** (0.992) of the weight, not 1,437,124. The note's
  "(594 admitted, design-weighted to the 1,437,124 …)" makes the same slip: the 612 sum to 1,437,124
  and the 594 do not. The 0.8% excluded weight (11 implausible on both surfaces, 7
  `corrected_roll_table`) is nowhere in the prose.
- **[fragile] CLAUDE.md:231, R/fly_footprint.R:824, NEWS.md:5, note ("The canopy cannot reverse
  fly#65's area verdict")**. The first-order qualifier is dropped. The measured row is fly#65's
  first-order formula with a measured canopy substituted. It is not a re-run ray-cast, and the canopy
  is averaged under an axis-aligned square of W's area rather than the frame. The script labels that
  square, and the note does not. CLAUDE.md says "measured (fly#80), the canopy BC has does not". The
  roxygen says "The first holds under the canopy BC actually has" with no qualifier. Only the note's
  fly#65 intro edit says "to first order".
- **[fragile] note (fly#65 table prose and fly#80 "The fly#65 canopy table, measured") and
  NEWS.md:5**. The comparison is like-for-unlike. The uniform rows put `c` on **land cells only**
  (`c(1 − w)`), and the tie is near 30 m (26.7 m recomputed). `c_coastal` is the mean of DSM−DTM over
  the **whole** square, sea included, so "7.96 m coastal" set against "tie near 30 m" overstates the
  margin. At the coastal set's median sea fraction of 0.37, the land-equivalent canopy is a median
  **13.3 m**. That matches the measured row sitting on the 15 m row (−0.00127 vs −0.00122). The
  verdict (W closer) is computed correctly and stands. The figures put beside it are not the same
  quantity. "7.96 m coastal, 6.88 m inland" has the same problem: the coastal mean is diluted by sea,
  and on land coastal frames carry about twice the inland canopy.
- **[fragile] NEWS.md:4** "NRCan's own lidar mosaic covers **none** of those cells", and the note's
  "MRDEM took lidar ground **wherever** HRDEM had it". The producer is a 3,000-point sample (0 hits),
  so it supports "almost none", not "none". The script's own site output contains a counterexample.
  At Revelstoke (src1 0.975), HRDEM has ground on 87 cells and MRDEM's DTM sits **9.21 m** above it,
  so MRDEM did not take HRDEM's ground there. findings.md:130 itself calls it "the one site where
  newer lidar covers radar cells". The shipped data cannot tell whether those 87 cells are radar,
  blend or partial edge cells, so state the sample result rather than the universal.
- **[fragile] note, "First order holds … equals `d` to a median 3.0e-4"**, and NEWS.md:3. The figure
  is **unweighted** (log: "sample, unweighted"; weighted it is 1.7e-4) in a section where every other
  figure is weighted, and the prose does not say so. It is also absolute. Against a median `d` of
  1.7e-3 it is **9.6%** relative. The original rule's first-order test (median |r−p|/p < 10% on
  p ≥ 0.25%) recomputes to **9.3%**, which passes narrowly, and Amendment 1 dropped that clause.
  "Three checks, each of which had to hold" therefore has no pre-registered threshold for this check,
  and the third item ("the package today") is a report, not a check.
- **[fragile] note, "the mean of `DSM − DTM` under a frame … is a few metres"**. No producer line. The
  shipped sample gives a weighted median `c30` of **7.56 m** (95th 14.5 m), which is consistent with
  0.17% × 4,575 m ≈ 7.8 m. "A few" understates it.
- **[fragile] tests/testthat/test-fly_footprint_canopy.R:49–52**. The header enumerates which prose
  figures are not asserted "because no shipped table carries them". It omits the sea `diff_mean`
  claim. `dem_canopy_sites.csv` ships that column, and asserting it would fail (finding 3). Also
  unasserted though recomputable from shipped data: first-order 3.0e-4 (it recomputes to 2.99e-4,
  correct), "0 of 3,000" in the prose (only the versions etag is checked), "612", "594 admitted",
  "1,437,124", "Two of the 612" and "0.916" in the prose (each is checked against data, not against
  the text). The disclaimer "the prose is read only where a figure is matched" is honest. The
  enumeration is not complete.

No broken tests. Every assertion can fail (mutations below), and both row-count guards count what
their comments say.

## Claim table

| claim | location | producer | ✓/✗ | note |
|---|---|---|---|---|
| DSM shrinks frame, weighted median 0.17% | NEWS, note table, roxygen, CLAUDE.md | log `d_c … weighted: median 0.0017` | ✓ | weighted, admitted 594 |
| 95th 0.46% | same | log `95th 0.0046` | ✓ | |
| 1.2% of frames move > 1% | NEWS, note table | log `over 1% 0.012` | ✓ | weighted |
| "all of them in the fine band" | NEWS | sample CSV: 6 mid frames > 1% | ✗ | 99.5% by weight |
| 2.1% of fine frames over 1% | NEWS, roxygen, note | log `fine … share over 1% 0.021` | ✓ | fine = scale_n ≤ 15000 (`cut` right-closed), so "1:15000 or finer" / "to 1:15000" is right |
| 612 film frames | NEWS, note | log `sample: 612 frames in 12 strata` | ✓ | |
| weighted back to "1,437,124 DEM-eligible" | NEWS | log: 1,437,147 eligible; 1,437,124 with canopy value | ✗ | mislabel; admitted weight 1,425,189 |
| 594 admitted "design-weighted to 1,437,124" | note | log `admitted weight 1425189 of 1437124 (0.992)` | ✗ (fragile) | the 612 sum to 1,437,124, the 594 do not |
| first order to median 3.0e-4 | NEWS, note | log `first order (sample, unweighted) … 2.99e-04` | ✓ number / ✗ label | unweighted unstated; 9.6% relative |
| rectangle residual 2.89% vs 2.86% | NEWS, note | log `DTM 0.0286, DSM 0.0289` | ✓ | weighted; test recomputes |
| rule threshold 95th ≥ 1% | NEWS, note, CLAUDE.md | findings Amendment 1 clause 1 | ✓ | |
| 1% is half the ~2% per-corner cost | note | CLAUDE.md fly#58 entry | ✓ | not printed by this script (borrowed) |
| 88.3% radar | NEWS, note, CLAUDE.md (88%) | log `radar 0.883` | ✓ | 916 m coarse cells, nearest, on land tiles |
| 7.5% lidar, 0.4% blend | note | log `lidar 0.075, blend 0.004` | ✓ | |
| GLO-30 2011–2015 | note | findings (spec §7) | ✓ | spec, not printed |
| DTM on radar = DSM minus forest-removal model | NEWS, note, CLAUDE.md | spec quote in findings | ✓ | spec also names a settlement-removal model |
| HRDEM 0 of 3,000 on radar cells | note, CLAUDE.md | log `on MRDEM radar cells 0, lidar 2940, blend 60` | ✓ | |
| HRDEM "covers none of those cells" / MRDEM took lidar "wherever" | NEWS, note | sample only; Revelstoke hrdem_n 87, DTM−HRDEM 9.21 m | ✗ (fragile) | overgeneralised |
| 150 LidarBC tiles, 2019–2025 | NEWS, note | log `150 windows`, years 2019–2025 | ✓ | |
| MRDEM DSM−DTM median 7.75 m | NEWS, note | log | ✓ | test rebuilds |
| LidarBC canopy median 4.25 m | NEWS, note | log | ✓ | test rebuilds |
| MRDEM DTM − lidar ground −2.50 m | NEWS, note, CLAUDE.md (~2.5) | log | ✓ | test rebuilds |
| MRDEM DSM − lidar DSM +0.34 m | note | log | ✓ | |
| lidar DSM − MRDEM DTM 7.10 m | note | log | ✓ | |
| slope 0.916 in [0.67, 1.5] | NEWS, note, CLAUDE.md | log `INSTRUMENT VALID … 0.916` | ✓ | test recomputes |
| "the two cancel" | note, CLAUDE.md | dsm_resid +0.34 | ✓ | the DSM is right; canopy overstatement ≈ DTM low |
| harvest/fire bias slope low, not corrected | note | Amendment 2 | ✓ | stated before the probe (logs 16:12+ after the 09:34 commit) |
| sea DSM = DTM, mean diff 0.00 m at every readable site | NEWS, note | sites: Howe −0.032, Roberts −0.007 | ✗ | 4 of 6 |
| "nothing in fly#65 depends on which surface" | note | measured row changes fly#65's W−L | ✗ | holds for sea cells only |
| median nominal agl 4,575 m | note, CLAUDE.md | log `census nominal height … median 4575 m` | ✓ | over all 1,437,147 |
| 1% needs 46 m mean canopy | note, CLAUDE.md | log `needs a mean canopy of 46 m` | ✓ | |
| mean DSM−DTM under a frame "a few metres" | note | none; sample weighted median c30 7.56 m | ✗ (fragile) | no producer |
| flat control to 1e-12 | note | log 1.33e-12, −6.72e-13 | ✓ | |
| edge control 0/40 m, 1.4e-6 | note | log −1.41e-06 at 32 rays; script cc = 40 | ✓ | |
| gap shrinks fourfold with rays ×4 | note | log −3.12e-2 → −7.81e-3 (32 → 128) | ✓ | |
| package today: median 0.19% too wide, 95th 2.85% | note | log `+0.0019, 95th 0.0285` | ✓ | test recomputes |
| "almost all of it the relief residual" | note | rho_dtm 95th 2.86% vs today 2.85% | ✓ | |
| 2 of 612 change class, implausible → reported | NEWS, note | log `differs 2 (implausible -> reported: 2)` | ✓ | frames 849062, 1221287; also change terrain |
| frame scale bands 288 / 180 / 126 | note table | log n per band | ✓ | test rebuilds |
| scale band medians/95ths/shares | note table | log | ✓ | test rebuilds |
| 215 frames with d ≥ 0.5% | note | log `epoch: 215 frames` | ✓ | admitted frames |
| decade eligible/known 22/22, 73/67, 60/55, 56/55, 4/4 | note table | log epoch lines | ✓ | test rebuilds |
| DSM worse 7.3/15.1/2.3/1.5%, 2000s unresolved | note table | log | ✓ | weighted share of known eligible |
| "one in seven 1970s frames" | note | 15.1% of known d ≥ 0.5% 1970s frames | ✗ | 1.3% of all 1970s |
| "1970s frames: 15%" | CLAUDE.md | same | ✗ | denominator dropped |
| DSM worse iff canopy more than doubled (r < 0.5) | note, CLAUDE.md | Amendment 4 | ✓ | |
| ±3 years same decades | note | log `epoch at canopy year ±3` | ✓ | |
| fly#65 measured row −0.00127 / 2.27% / 3.20% | note table, NEWS | log last line | ✓ | coastal test rebuilds |
| bare-earth −0.00287 | NEWS | fly#65 table 0 m row | ✓ | |
| coastal median 7.96 m, inland 6.88 m | NEWS, note | log | ✓ number / ✗ comparison | frame mean incl. sea; land-equivalent 13.3 m |
| "tie near 30 m" | note | 30 m row +0.00014; recomputed root 26.7 m | ✓ | pre-existing |
| "the canopy BC has does not [reverse]" (measured) | CLAUDE.md, roxygen, NEWS | first-order, axis-aligned square | ✗ (fragile) | qualifier dropped |
| five amendments, all before their data existed | note, CLAUDE.md | commits and log mtimes | ✓ | full run stopped at stage 3 (canopy_full.log has no epoch lines) |
| three from code-check, two inside previous fix | CLAUDE.md | findings round tables; review-round3 F2 sits in Amendment 4 code | ✓ | |
| mechanism axes (scale, sampling design, type, RNG) | CLAUDE.md | findings line 340 | ✓ | |
| `mrdem-30-dsm.tif` on the DTM's grid | roxygen, note | script line 57; compareGeom on overviews | ✓ | |
| fns_from, ETag cache key, seeded draws, SMOKE/STOP, by-hand downloads | CLAUDE.md | script lines 32–52, 93–108, 135, 139–148, set.seed per draw | ✓ | |
| fly#82 is the parallax witness | note | `gh issue view 82` | ✓ | |

## Tests: can each assertion fail?

| assertion | mutation that turns it red |
|---|---|
| canopy L24 `expect_gt(0.63, band[1])` | narrow `fly_height_ratio_band()` above 0.63 (premise guard only) |
| L25 premise ratio below band | widen the band lower edge below 0.6137 |
| L29–30 ground reported / dem_agl | break the DEM route for in-band frames |
| L32–33 canopy not reported, nominal | drop the fly#54 band check, or classify after sizing |
| L41 both reported | band edge moved past ratio 1.05 |
| L43 side ratio = c/(agl−c), tol 1e-6 | size from c/agl first-order (1.3% relative, outside 1e-6) or mis-average the DEM |
| L92–93 612 / 594 rows | regenerate with a different sample or admission rule |
| L95 weighted 95th < 1% | any CSV where the 95th reaches 1% |
| L98 weights sum to census non-"none" | weights not N_h/n_h, or census bins changed |
| L101–102 two changed, both implausible on DTM | the class-change count or direction changes |
| L109–113 lidar 150 rows, slope 0.916 in band | regenerate probe; edit CSV |
| L116 hrdem etag string | rerun HRDEM count with a different result |
| L126–127 3 separators, 20 lines | add/remove a table or row (lidar 5 + scale 4 + decade 5 + 3 hdr + 3 sep = 20, verified) |
| L160 rows %in% section | edit any table cell, or regenerate the data |
| L167–179 prose matches | edit the 88.3/7.5/0.4, 2.89/2.86, 0.19/2.85 or 215 figures |
| L188 coastal rows = fly#65 admitted | ship a partial dem_canopy_coastal.csv |
| L199 W still closer | canopy large enough to flip the median |
| L203 7.96 / 6.88 in the prose | edit the prose or regenerate |
| coastal L278 36 lines | add or remove a row in any of the six tables (now 5 canopy rows) |
| coastal measured row | edit −0.00127 / 2.27% / 3.20%, or regenerate dem_canopy_coastal.csv |

Weakness, not a defect: the edge-frame test pins **reported → disputed** (the canopy pushes the frame
below the lower edge). Both sample frames that changed class went the **other** way
(implausible → reported on the DSM). The note's "The test pins that" holds for "a canopy can move a
frame across the band" and not for the observed direction.
