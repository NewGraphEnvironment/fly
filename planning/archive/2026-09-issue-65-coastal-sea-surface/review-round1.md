# Code-check round 1 — fly#65 branch (coastal water measurement)

Reviewed: data-raw/dem_measure-coastal_water.R, tests/testthat/test-fly_footprint_coastal.R,
inst/extdata/dem_coastal_*.csv, NEWS.md top entry, CLAUDE.md fly#65 entries,
inst/notes/terrain-correction.md (fly#65 section + fly#58 "blind to" bullet), roxygen in
R/fly_footprint.R, against planning/active/findings.md (Decision rule, Amendments,
Amendment 2) and data-raw/.cache/logs/dem_coastal_run2.log. Numbers were recomputed from the
shipped CSVs (and, for coordinates, from data-raw/.cache/dem_coastal/selection.rds) in the
scratchpad. The coastal test file was run in a temp copy of the repo: FAIL 0, PASS 56.

## Verified correct (no finding)

- raycast(): the descent, the "z >= e" hit test, bisection direction (lo = underground,
  hi = air), final scaling, and the sf_project/extract column all check out. A wrong column
  would have failed the flat control.
- densify(): drops the closing vertex and gives 4 x per_edge points. fly_rectangles() returns
  4 vertices plus a copied fifth, centred on the centroid, so `centre = c(row$x, row$y)` is the
  right scaling origin.
- S corners: `moved[k-1] + moved[k] - centre` is the intersection of the two shifted sides of a
  centred rectangle. The midpoint direction is normal to its side, and this holds for any
  vertex order or rotation. `sweep(mids) * s_side` recycles row-wise as intended.
- CRS handling: the ray math and areas are in 3005 (equal-area), and extraction is in the
  DEM's CRS. The windows use `align(snap = "out")`.
- `d`, `lin()`, the edge metrics, the bootstrap (by roll, `use.names = FALSE`), the verdict
  indexing and the premise thresholds all match Amendment 2.
- Every figure in NEWS, CLAUDE.md, the roxygen and the note that is also in the log
  reproduces from the CSVs. The exceptions are listed below.

## Findings

- **[bug — published claim wrong] inst/notes/terrain-correction.md:947 (and findings.md "Result")**
  The note says "157 were excluded as over a land border". They are not land-border frames.
  All 157 were excluded by the `n_outside_high > 0.10 * outside` arm (script line 559), and
  none by the nodata arm. 152 are coastal-set, coastal-flag frames. 140 of 157 have an FWA
  coastline within 3 km, and their outside cells have a median `sea_median` of 0.09 m. Their
  coordinates run x 540k–1,230k and y 409k–1,036k (BC Albers), which is the BC coast (only 1
  sits near Washington). The ~33 in the northwest need their own look before any is called
  Alaska. They also span every stratum and roll. What trips them is the shoreline
  misregistration between the polygon and the DEM that the Phase 1 probe already recorded
  (Howe Sound "sea" cells reaching 78 m). The median sea fraction among them is only 3.7%,
  so 10% of a thin sea sliver reading above 2 m is enough. The rule is implemented as
  Amendment 2 wrote it. The label published for its result is wrong, though, and it
  describes 7% of the sample as something else.
  The verdicts do not move: with the 151 excluded coastal frames that have d > 0 added back,
  coastal W area 95th goes from 2.16% to 2.38% and edge 95th from 15.05% to 14.77%. Both stay
  under inland (3.18% / 15.87%), and the W/L medians keep their ordering. Fix the wording to
  something like "excluded because more than 10% of their outside-polygon cells read above
  2 m, mostly shoreline misregistration, not a land border", and say the verdicts are
  unchanged with them included.

- **[bug — uncounted exclusion] data-raw/dem_measure-coastal_water.R:444, 560–564; note line ~946**
  Amendment 2 says "Every exclusion is counted." 23 eligible frames have no land cell under
  the polygon (`n_sea == n_cells`, `mean_land` NA). `measure_frame()` returns early for them
  (line 444) with `rays_bad = 0`, so they are neither `land_border` nor `rays_failed`. They
  fail `admitted` only through `is.finite(area_t)/is.finite(mean_land)`, and the pub line at
  563 has no term for them. The log's own arithmetic shows the gap: 2,304 eligible − 157 −
  0 = 2,147, not 2,124. 7 of the 23 carry the coastal flag. The note also skips the 30
  frames that are not eligible (13 `corrected_roll_table`, 17 `implausible`/`nominal_scale`),
  so a reader sees 2,334 sampled, 157 excluded and 2,124 admitted, and the numbers do not sum.
  Add an "all sea, no land cell" count to the pub line and the note. The verdicts are
  unaffected, since L is undefined on these frames.

- **[bug — pre-registered threshold loosened, undisclosed] data-raw/dem_measure-coastal_water.R:285**
  Amendment 2 fixes the step control as "T's area equals the analytic ... to 1e-4 relative".
  The script stops only at `abs(sc[1]) > 1e-3`. The measured value is −2.56e-4 at 32 rays, which
  **fails** the pre-registered 1e-4 and passes only because of the tenfold looser threshold.
  findings.md ("Smoke run") discloses only that the Jensen-gap test was replaced by a
  convergence test. It says nothing about the area threshold. The note (line ~916) quotes
  "within 2.6e-4" with no threshold, so nothing published shows it was missed. Either
  disclose the change beside the gap one (the same corner-cutting cause applies: 6.4e-5 at
  128 rays passes 1e-4) or gate on the 128-ray figure.

- **[bug — pre-registered control not implemented] data-raw/dem_measure-coastal_water.R (Stage 5)**
  Amendment 1 item 2 replaced control 3 with "median |mean_all − W| under 1 m over admitted
  frames, **or the script stops**". Amendment 2 does not withdraw it, and the script header
  names "Amendments" as binding. No such check exists. It matters because L is built as
  `e_w + (mean_land − mean_all)` on the premise that the returned rectangle's cells are close
  to the ones the package sized from. It would pass today: from the CSV, the median is 0.021 m,
  the 95th 1.50 m and the max 9.12 m. It is still a stop condition the rule promises and the
  code lacks.

- **[bug — published number wrong] inst/notes/terrain-correction.md:1003–1004**
  The note says "Tides ... ±3.5 m ... That is ≤0.3% of width at the lowest height admitted."
  The lowest `height_agl` admitted is 697 m (717 m among the 1,242 coastal frames), and
  3.5 / 717 = 0.49%. ≤0.3% needs a height_agl of at least 1,167 m. It should read ≤0.5%, or
  be scaled by sea fraction, which bounds the mean shift, and say so.

- **[minor — published wording vs data]**
  - Note (~line 970), "38% of coastal frames differ by more than 1%": the share is 38.2% of
    coastal frames *with sea in them* (d > 0). Over all 1,307 admitted coastal frames it is
    36.3%, and the 95th is 3.15% rather than 3.18% (both round to 3.2%). Rule 1 says "over
    coastal frames", so say "with sea".
  - NEWS / note / CLAUDE.md: "`dem_elev_sd` median runs from 181 m down to 14 m as the sea
    fraction rises". The lowest-sea band [0, 0.1] is 164.2 m and the peak of 180.6 m is in
    (0.1, 0.25], so the medians are not monotone from 181. Say "14–181 m" (as CLAUDE.md does)
    or "falls from ~165–181 m".
  - NEWS: "Neither is worse on a coastal frame than on an inland one" is followed only by W's
    numbers. If "neither" means W and L, it is false on area: L's coastal 95th |area err| is
    3.30% against the inland 3.18% (L equals W inland). It is under the 1% threshold, but the
    sentence claims it outright. The roxygen's "neither is worse than an inland frame's own
    edges" is true (L edge 95th 12.8%).
  - Note: "In one dimension, W is exact for total length and L is exact for the land-side
    edge." The L half is right. W is exact for total length only when the shoreline passes
    through nadir. With the shore at offset x0 ≠ 0, W's half-width solves
    `2h² − a(2H − e)h + a·e·x0 = 0`, which differs from the true a(2H − e)/2. This is
    presented as the intuition behind the result, so qualify it.

- **[fragile] data-raw/dem_measure-coastal_water.R:294–298, 506, 538–540**
  The per-run cache is keyed by `run_id` only (c001…, i001…), and the assembly check is
  `setequal(run_id)`. If `selection.rds` is deleted or the sampling code changes, a new
  selection reuses the same IDs, and stale `runs/*.rds` from the old selection or old
  `measure_frame()` code are silently merged into the published CSVs. The shipped result is
  unaffected: run2 logged "runs to measure: 240 of 240". A cheap guard would be
  `stopifnot(setequal(m$airp_id, runs$airp_id))`, or clearing RUNS_DIR whenever the selection
  is rebuilt.

## Tests

test-fly_footprint_coastal.R: 56 passing in a temp copy. The assertions can fail. The
half-sea `height_agl` check separates W from L by 250 m at a relative tolerance of 1e-3
(about 2 m). The table assertions pin rounded published figures recomputed from the CSVs.
No checklist trap applies: `system.file()` is used, not a relative path; there are no
`info =` arguments on expect_gt/lt; and the logical columns read back as logical under
`na = ""`.
