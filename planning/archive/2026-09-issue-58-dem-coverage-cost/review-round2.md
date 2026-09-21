# Review round 2 — fly#58 (`dem_elev_sd` + partial-coverage measurement)

Scope: the round-1 fixes plus the rest of the diff. Every published figure was
recomputed from `inst/extdata/dem_coverage_{sweep,targets,population}.csv` with
`Rscript`, not read. The new test file runs green (`FAIL 0 ERROR 0 SKIP 0 PASS 81`,
`NOT_CRAN=true testthat::test_file()`), `test-fly_footprint.R` runs green (276 pass),
and `devtools::document()` leaves `man/fly_footprint.Rd` byte-identical.

## Findings

- **[bug]** `data-raw/dem_calibrate-coverage_error.R:883` — **fix 3 landed in one of
  two callers.** The arms loop (line ~984) gained `sw$footprint_terrain %in% "dem_agl"`,
  but `mask <- native[native$mech == "na_mask", ]` — which feeds the note's *headline*
  error table, the relief-quartile table and the DEM-vs-nominal table — did not. The
  note and the test both apply the `dem_agl` filter; the script that reproduces them
  does not. All 873 `no_dem_coverage` runs sit at `dem_coverage == 0`, so only the
  lowest band moves, and it moves a lot. Re-running the reproducer prints:

  | table | script prints | note publishes (`:340`, `:477`) |
  |---|---|---|
  | signed error, lowest band | n=2380, median −0.423%, 5–95% −13.338%..+6.687%, **max 23.563% → 25.290%** | n=1,507, median −0.008%, −7.296%..+5.487%, max 23.563% |
  | DEM vs nominal, 0–0.20 | n=2380, med dem 2.341%, med nom 5.680%, worse 229 (**9.6%**) | 1.491% / 5.755% / 229 of 1,507 (**15.2%**) |

  The 23.563% max is the number the roxygen (`R/fly_footprint.R:~699`), the warning
  text (`:1141`) and the threshold comment (`:184`) all quote as "24%" / "23.6%"; the
  reproducer says 25.290%. And note:341 asserts "the 873 … are counted separately
  below, **not mixed in here**", which is false of the script as it stands. Fix is one
  line — add the filter to `mask` (or define `mask` off a `native_sized` helper) — but
  it has to be *made*, because the note's claim that the script reproduces it is
  currently untrue for three figures.
  Scoped: the **0.95 floor table** (`:448`) is unaffected — I recomputed it both ways
  and every row is identical, because no coverage-0 run reaches 0.85. So the threshold
  argument itself is safe.

- **[bug]** `inst/notes/terrain-correction.md:438-439` — two published numbers disagree
  with the shipped artifact, and this is the pair that justifies shipping `covered_sd`
  rather than `covered_grad`:

  | claim | recomputed |
  |---|---|
  | "`covered_sd` at rho 0.39 to 0.59" | 0.385 .. 0.594 ✓ |
  | "`covered_grad` at **0.27 to 0.51**" | 0.266 .. **0.589** |
  | "`sd` is the better of the two in **four** bands of six" | **five** of six |

  Per-band, on the same held-out set and the same bins the test uses
  (`c(0,.2,.4,.6,.8,.95,1.01)`, the bins that reproduce the `sd` range exactly):
  `sd` 0.438 0.513 0.544 0.594 0.474 0.385 vs `grad` 0.505 0.474 0.500 **0.589** 0.451
  0.266. I swept six plausible binnings (6-band, 8-band, `mask` vs `dem_agl`, with and
  without the `dem_coverage > 0` filter) and none produces a `grad` max near 0.51 or an
  `sd` win rate of 4/6. `covered_grad` is non-negative by construction
  (`sqrt(cf[2]^2 + cf[3]^2)`), so signed vs absolute is not the explanation.

  **Nothing can catch this.** There is no within-band rho block anywhere in
  `data-raw/dem_calibrate-coverage_error.R` (the script computes only the *pooled* rhos
  at `:951-963`), and the test recomputes `within_sd` and never `within_grad`. So the
  `grad` half of the comparison has no producer and no guard, and the error runs in the
  direction that flatters the shipped decision — `grad`'s best band beats `sd`'s second
  best, which the published range hides.

- **[fragile]** `tests/testthat/test-fly_footprint_coverage.R:53-55` — the premise
  assertion written specifically to pin fix 3 **cannot fail**:

  ```r
  # The references are genuinely per arm, which is why the key needs both columns.
  ref_n <- x$targets$ref_n[x$targets$arm %in% c("native", "coarse")]
  expect_gt(length(unique(ref_n)), 1)
  ```

  `ref_n` varies frame to frame: the native rows *alone* already hold 120 distinct
  values, so the assertion is satisfied with the two arms sharing one reference. It
  tests "different frames have different cell counts", not "different arms do". A
  regression that kept 240 rows keyed on `(airp_id, arm)` but filled every arm's
  `ref_*` from the native run — the exact defect fix 3 repaired, minus the row-count
  change — passes this and every other assertion in the file. The discriminating form
  compares the same frame across arms:

  ```r
  m <- merge(x$targets[x$targets$arm == "coarse",   c("airp_id", "ref_n")],
             x$targets[x$targets$arm == "native",   c("airp_id", "ref_n")],
             by = "airp_id", suffixes = c("_c", "_n"))
  expect_identical(nrow(m), 40L)
  expect_true(all(m$ref_n_c != m$ref_n_n))   # 40 of 40, measured
  ```
  (Measured: `ref_n` differs on 40/40 and `ref_area` on 39/40 for each of the three
  arms; the note's `90,692` vs `101` example is airp_id 215166 and checks out.)

- **[fragile]** `tests/testthat/test-fly_footprint_coverage.R:218` —
  `expect_equal(a$share_removed, b$share_removed, tolerance = 1e-6)` under the comment
  "The treatment itself is identical: the same geometric share is removed either way".
  It is identical *by construction*: `share` is computed once per grid row at
  `data-raw/...R:695` and the `mech` branch is taken after it, so both rows carry the
  same double. The assertion presents a construction invariant as a measured property
  and can never fail (max diff recomputes to exactly 0). Harmless on its own; worth a
  comment saying so, or replacing with something the harness could actually get wrong.

- **[fragile]** `tests/testthat/test-fly_footprint_coverage.R:8` — stale header comment
  survived fix 3: *"The sweep ships as two tables that join on `airp_id`"*. It
  contradicts the comment at line 52 and the `merge(..., by = c("airp_id", "arm"))` at
  line 54, fifteen lines below it. Same class as round-1 finding 5, in the file the fix
  was written into.

- **[fragile]** `data-raw/dem_calibrate-coverage_error.R:869` — the note's flip figure
  has no producer line. The script prints `classification flips: 1096 of 11344 (9.66%)`
  (it runs over `sw`, i.e. every arm), while the note (`:496`) publishes "873 of the
  7,616 usable native `na_mask` runs … (11.5%)". The note's number is correct — I
  recomputed 873/7616 = 11.46%, and the test pins both — but a reader checking the note
  against the reproducer's output finds a different pair and no way to get from one to
  the other. Round-1 fix 2 corrected the denominator in the prose without giving the
  script a line that emits it.

- **[fragile]** `inst/notes/terrain-correction.md:321` — *"`dem_coverage_sweep.csv`,
  `dem_coverage_targets.csv` and `dem_coverage_population.csv` ship so the suite
  recomputes every figure here."* Four figures in the section are in no shipped
  artifact and are recomputed by nothing: the digital row of the population table
  (`223,667` total and `6` DEM-sized, `:289` — only the `173` candidate count is in
  `dem_coverage_population.csv`), the "1982-1996 at 1:10000 to 1:70000" range (`:294`),
  the within-band rho ranges (`:438`, which is finding 2), and the determinism claim
  (`:501`). Either narrow the sentence or add the two digital counts to the population
  table, which is cheap — the finder already computed them.

- **[fragile]** `R/fly_footprint.R:183` and `:186` — two different statistics are both
  called "the median" in adjacent sentences of one comment block: "a median 0.34% at
  0.6-0.8 coverage and 1.49% under 0.2" (median **absolute** error) and "the median
  error stays under 0.05% to 0.8" (median **signed** error). Both are true — I
  recomputed 0.335%/1.491% and +0.036%/−0.008% — but read together they look like a
  contradiction, and 0.34% > 0.05% is the first thing a reader checks. Same collision
  between the roxygen (`:697-699`, "a median 0.18% … at 80-90% coverage") and the
  note's headline table (`:342`, which publishes `+0.020%` for that band). One word
  ("absolute") in each place closes it.

## Verified clean

Recorded so a later round does not re-derive it.

- **Fix 3, the substance.** The harness always computed per-arm references —
  `sweep_target(dem_arm =)` builds `fp0`, `area_ref` and `covered_stats()` against the
  arm's own raster — so only the shipped table was collapsed, and it is now keyed
  correctly. `merge(runs, targets, by = c("airp_id","arm"))` returns exactly 11,520
  rows; every run finds its reference; `anyDuplicated` is 0. The republished arm medians
  reproduce: coarse **0.6959%**, geographic **0.5853%**, anisotropic **0.6774%**, native
  **0.7772%**. The test is the only other consumer (`grep` across `R/`, `tests/`,
  `data-raw/`, `inst/`, `vignettes/`) and it joins on both keys.
- **Fix 1.** `devtools::document()` leaves `man/fly_footprint.Rd` byte-identical
  (`cmp` clean); `NAMESPACE` unchanged.
- **Fix 2.** 7,616 usable native `na_mask` runs (7,680 native `na_mask` total, 119×64
  after the one excluded target); 873 flips, 11.46%; all 873 are `no_dem_coverage` at
  `dem_coverage == 0`; none is `implausible`.
- **Fix 4.** All four premise assertions hold against the real data and are not
  hardcoded-right-for-the-wrong-reason: `sum(!is.na(dem)) == 8L` (8 bands populated),
  `sum(!is.na(ratio)) == 8L`, `sum(!is.na(within_sd)) == 6L` (band sizes
  499/328/327/297/435/373, all over the 30 guard), `sum(!is.na(gain)) == 4L`. The
  `gain` values are 2.276 / 3.157 / 2.629 / 4.074 — the note's "2.3 / 3.2 / 2.6 / 4.1"
  and the `> 2` / `< 4.5` bounds both hold with room.
- **Everything else the note, roxygen, `.Rd` and warning publish reproduces exactly.**
  Headline error table (all 8 bands, n / median / 5–95% / max); the 0.95 floor table
  (0.175 / 0.794 / 0.794 / 0.794 / 1.221 / 1.280 / 2.520); the DEM-vs-nominal rows; the
  13.0–52.0x spread ratios and the "13 to 52 times" prose; the pooled predictor rhos
  (0.717 / 0.185 / 0.152 / 0.480 / 0.801); the analytic identity (n = 10,248, max
  deviation 3.7e-06 against the rounded table, consistent with the stated 1.6e-13 at
  full precision); the mechanism control (1,856 matched, 1,633 both-`dem_agl`, max
  0.4256%, 99th 0.1127%, median 0.0031%, three disagreements all at
  `share_removed > 0.99`, overall max 14.79%); the population census (66 / 26 / 87 /
  2,975 / 1,437,147 / 113 / 173).
- **`fly_dem_sample()` return shape.** Both early return and normal return now carry
  three vectors; `vapply(..., numeric(4))` is indexed by name so the added `spread =`
  element is order-independent; `USE.NAMES` is left at its default so the rownames the
  indexing needs survive. All four callers (`R/fly_footprint.R:1022`, `:1078`,
  `test-fly_footprint.R:720/744/745`, `test-fly_camera_format.R:289`) read by `$` and
  are unaffected by the added field.
- **`dem_elev_sd` plumbing.** `spread` is gated identically to `covered` (`ifelse(corrected,
  second$spread, first$spread)`), assigned under the same `dem_eligible` mask, and
  NA'd under the same `no_geom` mask. `sd` of a constant `flat_dem()` surface is exactly
  0 (elev 700 is exactly representable and `n*700/n` is exact), so the
  `== 0 | is.na()` assertion is not float-fragile. `fly_reported_cols()` order matches
  the `attrs$` assignment order.
- **`write_if_changed()` per-column quoting.** No factor columns exist in any of the
  three frames (`is.character()` would miss one, and `write.csv` writes factor labels
  unquoted under `quote = FALSE`), so the guard covers everything present today. An
  all-NA character column yields `NA` from `any(grepl(...))`, which `which()` drops —
  correct, since bare `NA` needs no quoting. Round-tripping all three files through
  `read.csv` gives the expected types and no column shift.
