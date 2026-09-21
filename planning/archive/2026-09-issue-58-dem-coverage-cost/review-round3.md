# fly#58 — review round 3: the mechanism, and its closed enumeration

Round 3 brief: name the mechanism behind rounds 1 and 2, enumerate every place it reaches,
and show for each whether it sits above or below its source of truth. Plus: check what the
earlier rounds' fixes could have broken.

Everything below was **recomputed from the shipped artifacts**
(`inst/extdata/dem_coverage_{sweep,targets,population}.csv`), not read off the prose.
Scripts in the session scratchpad (`rc3_a.R`, `rc3_b.R`, `rc3_c.R`).

Baseline facts established first, so nothing here rests on a broken probe:

- `man/` is **byte-identical** to a fresh `roxygen2::roxygenise()` run in a copy of the
  package (round 1's fix holds, and no *other* `.Rd` is stale either).
- `NOT_CRAN=true devtools::test(filter="footprint")` → **FAIL 0, PASS 1328, SKIP 0**.
  The new file alone: PASS 86.
- Every table the note publishes reproduces exactly, **except one number** (finding 1).

---

## Mechanism

The hypothesis in the brief — *"a quantity is stated in more than one place and nothing
binds the copies"* — is right about the symptom and one level too coarse about the cause.
The redundancy is deliberate and mostly *is* bound: roxygen → `.Rd` is bound by
`document()`, and the shipped CSVs bind the note to the sweep. What is unbound is narrower
and completely enumerable:

> **The binder set was built by walking the TEST file, not by walking the PROSE.**
> Every figure that someone thought to assert is pinned. The note's claims are a strict
> superset of the test's assertions, and *nothing enumerates the difference*. So a
> published number is correct exactly as long as the person who wrote it was right — which
> is the state the shipped artifacts were supposed to end.

That is the first half. The second half is the one rounds 1 and 2 both actually tripped on:

> **A population is defined by an inline filter expression, once per consumer.** There are
> **ten** such expressions in the script and **seven** in the test for six distinct
> populations. Nothing names a population, so "the same population" is a property that has
> to be re-established by hand at each of the seventeen sites — and a fix applied at one
> site is invisible at the next.

Round 1(3) was this on the *join key* (`airp_id` vs `airp_id`+`arm`). Round 2(A) was this on
the *filter* (`dem_agl` applied to the arms loop and not to `mask`). Round 3 finds two more
instances of exactly that, below.

### Enumeration A — every population-defining filter in the diff (closed set, 17)

| # | site | expression | rows | agrees with |
|---|---|---|---|---|
| S1 | script:853 | `sweep[sweep$ref_ok, ]` | 11,344 | T1 ✓ |
| S2 | script:872 | `sw[arm=="native" & mech=="na_mask"]` | 7,616 | T6 ✓ |
| S3 | script:876 | `sw$flipped` — **no arm/mech filter** | 1,096 | **✗ see finding 2** |
| S4 | script:883 | `sw[!flipped & finite(err) & finite(err_analytic)]` | 10,248 | T3 ✓ |
| S5 | script:886 | `sw[arm=="native"]` | (feeds S6) | — |
| S6 | script:893 | `native[mech=="na_mask" & terrain %in% "dem_agl"]` | 6,743 | T2 ✓ |
| S7 | script:934 | `sweep[ref_ok & native & id %in% extent_crop]` | 1,856 matched | T7 ✓ |
| S8 | script:958 | `mask[holdout & finite(err) & covered_n > 0]` | 2,259 | T4 **coincidentally** — finding 5 |
| S9 | script:993 | `mask[finite(covered_planar) & finite(covered_mean)]` | producer only | — |
| S10 | script:1010 | `sw[arm & na_mask & cov<0.8 & dem_agl & finite(err)]` | per arm | T5 ✓ |
| T1 | test:37–38 | `merge(...); d[d$ref_ok, ]` | 11,344 | = S1 |
| T2 | test:50–52 | `native_sized()` | 6,743 | = S6 |
| T3 | test:302–303 | `joined[dem_agl & reported]` | 10,248 | = S4 |
| T4 | test:885 | `n[holdout & dem_coverage>0 & finite(covered_grad)]` | 2,259 | ≈ S8 |
| T5 | test:965–966 | `joined[arm & na_mask & dem_agl & cov<0.8]` | per arm | = S10 |
| T6 | test:979 | `joined[native & na_mask]` | 7,616 | = S2 |
| T7 | test:941–945 | `joined[native]`, matched on id/dir/cut_u | 1,856 | = S7 |

**16 of 17 agree. S3 does not** (finding 2), and S8/T4 agree only on today's data (finding 5).

### Enumeration B — every published quantity, with binding status

Extracted mechanically (every numeric literal on an added diff line in
`R/fly_footprint.R`, `man/fly_footprint.Rd`, `inst/notes/terrain-correction.md`,
`data-raw/dem_calibrate-coverage_error.R`, `tests/…/test-fly_footprint_coverage.R`), then
each recomputed. Classes:
**P** = pinned (a test asserts it; a regeneration that moves it goes red);
**P\*** = pinned jointly (falls out of two pinned quantities);
**D** = derivable from a shipped CSV, nothing checks it;
**F** = free-floating (not recomputable from the shipped artifacts at all).

| quantity | value | stated in | status | recomputed |
|---|---|---|---|---|
| sweep rows | 11,520 | Rcmt, rox, Rd, warn, note, script | **P** | 11,520 ✓ |
| target frames | 120 | Rcmt, rox, Rd, note×2 | **P** | 120 ✓ |
| target rows (frame×arm) | 240 | test only | **P** | 240 ✓ |
| usable native na_mask runs | 7,616 | note×2 | **P** | 7,616 ✓ |
| … of which DEM-sized | 6,743 | note | **P\*** (band n's sum) | 6,743 ✓ |
| classification flips | 873 (11.5%) | note, script | **P** | 873 ✓ |
| excluded target | 1154997 | note | **P** | ✓ (all 4 arms) |
| strata / holdout | 12 / 40 of 120 | note, test | **P** | ✓ |
| worst abs err ≥0.95 / ≥0.94 / ≥0.92 | 0.794 / 0.794 / 1.221 | Rcmt, note | **P** | ✓ |
| worst abs err by 0.85 | 2.520 | Rcmt, note | **D** | 2.5197 |
| floor-table n's | 402/1021/1166/1289/1529/1718/2151 | note | **D** | all ✓ |
| headline band n's | 402/764/552/662/922/968/966/1507 | note | **D** | all ✓ |
| headline signed medians (8) | −0.000 … +0.038 | note | **D** | all ✓ |
| headline 5–95% bounds (16) | −7.296 … +5.487 | note | **D** | all ✓ |
| headline max abs (8) | 0.175 … 23.563 | note | **D** (5 are **P\***) | all ✓ |
| median SIGNED err < 0.05% to 0.8 | 0.05 | Rcmt, note | **D** | max 0.0377% ✓ |
| median abs err, 60–80% | 0.34 / 0.335 | Rcmt, rox, Rd, **warn**, note | **D** | 0.3345 ✓ |
| median abs err, 80–90% | 0.18 / 0.178 | rox, Rd, note | **D** | 0.1782 ✓ |
| median abs err, <20% | 1.49 / 1.5 / 1.491 | Rcmt, rox, Rd, warn, note | **P** | 1.4914 ✓ |
| max abs err | 23.6 / 24 / 23.563 | Rcmt, rox, Rd, warn, note | **P\*** | 23.5631 ✓ |
| DEM-vs-nominal medians | 0.032/4.467, 0.178/7.807, 0.632/5.755 | note | **D** | all ✓ |
| … lowest band | 1.491 / 5.755 / 229 / 15.2% | note | **P** | ✓ |
| … "worse on" counts | 0, 7 (1.1%), 62 (6.4%) | note | **D** | all ✓ |
| spread ratio per band (5) | 15.8/13.0/16.6/14.1/25.1 | note | **P** | ✓ |
| spread range | 13 to 52 | Rcmt×2, rox, Rd, note | **P** (bounded 12.9/52.5) | 12.96 / 52.03 |
| pooled rho: coverage / range / sd | 0.717 / 0.152 / 0.185 | note | **P** | ✓ (coverage is **−**0.717) |
| pooled rho: grad / grad×loss | 0.480 / 0.801 | note | **D** | ✓ |
| within-band rho, 12 cells | +0.438 … +0.266 | note | **D** | all ✓ |
| within-band grad range | 0.27 to 0.59 | note | **P** (both ends) | 0.266 / 0.589 ✓ |
| within-band **sd** range | 0.39 to 0.59 | note | **half-P** — finding 4 | 0.385 / 0.594 |
| "sd better in five of six" | 5 of 6 | note, script | **P** | ✓ |
| gain-table cells (16) | 0.719/479 … 0.026/187 | note | **D** | all ✓ |
| gain ratios | 2.3 / 3.2 / 2.6 / 4.1 | Rcmt×2, rox, Rd, note (**warn**: "2 to 4") | **D**, only bounded (>2, <4.5) | 2.28/3.16/2.63/4.07 ✓ |
| calibrated bound | 4.97 / 95.3% / 6.1× / 89.4% | note | **D**, no producer, no test | 95.3 / 6.08 / 89.4 ✓ |
| mech agreement, matched | 1,856 / 1,633 | note | **P** (>1800, >1600) | ✓ |
| mech agreement max | 14.79% (all) / 0.43% (both) | note | **P** for 0.43 (<0.005); **D** for 14.79 | ✓ |
| mech agreement p99 / median | 0.11% / 0.003% | note | **D** | 0.1127 / 0.0031 ✓ |
| arm medians | 0.696 / 0.585 / 0.677 / 0.777 | note | **P** | ✓ |
| arms "zero classification flips" | 0 | note, script | **now true by construction** — finding 3 | ✓ |
| per-arm reference differs | 39 of 40 (area), 40 of 40 (n) | script cmt | **D** (test pins n-differs only) | ✓ per arm |
| ref_n example | 90,692 vs 101 | note, script cmt | **D** | frame 215166 ✓ |
| film DEM-eligible | 1,437,147 | note | **P** | ✓ |
| edge candidates film / digital | 113 / 173 | note | **P** | ✓ |
| edge DEM-sized / under 0.95 | 87 / 66 | note | 87 **D**, 66 **P** | 87 ✓, 66 ✓ |
| off the DEM entirely | 26 | note | **P** | ✓ |
| random control | 3,000 / 2,975 / 0 short | note | **P** | 2975+25=3000 ✓ |
| rate | 0.005% | note | **P** (<1e-4) | 0.00459% ✓ |
| bundled frame coverage | 99.96% | Rcmt | **D** (fixture) | 99.9639%, 1 frame ✓ |
| artifact sizes | 1.5 MB / 3.5 MB; 395 KB / 156 KB | note, script cmt | **D** | 1,526,819 / 394,942 / 156,376 ✓ |
| **geometric→achieved mapping** | **0.30 → 0.215** | note | **F, and WRONG** | **0.295** — finding 1 |
| analytic agreement | 1.6e-13 over 10,248 | note | 10,248 **D**; 1.6e-13 **F** | 10,248 ✓; 3.7e-06 on the rounded table |
| digital population | 223,667 of 1,670,471 | rox, Rd, note | **F** | not in any shipped table |
| affected-frame span | 1982–1996, 1:10000–1:70000 | note | **F** (declared) | — |
| ocean probe | 40,000 / 0.098 / 0.189 | note | **F** (declared) | — |
| digital route split | 6 / 167 | note | **F** (declared) | arithmetic ✓ |
| determinism check | 40 targets, byte-identical | note | **F** (declared) | — |
| issue's own figure | 18 of 416, 47% | note | **F** (declared not to reproduce) | — |
| coarse overview | 1833 m | note | **F** | — |

**Closed-set summary.** 4 quantities are free-floating and *declared* as such (the note
names four). **4 more are free-floating and not declared**: `0.215`, `1.6e-13`, `223,667`,
`1833 m`. Roughly 60 are derivable-but-unchecked. About 30 are pinned.

---

## Findings

- **[bug] `inst/notes/terrain-correction.md`:329–330 — "A 0.30 geometric target comes back
  as 0.215 achieved" does not reproduce, under any reading, and it is the paragraph's only
  evidence.**

  `share_removed` is `st_area(st_difference(nom_d, keep)) / area_nom` — the share of the
  *nominal* footprint removed, computed before any DEM read (script:695–697). Recomputed
  over native `na_mask` `dem_agl` runs:

  | reading of "a 0.30 geometric target" | n | median achieved `dem_coverage` |
  |---|---|---|
  | geometric coverage 0.30 (`share_removed ≈ 0.70`) | 222 | **0.295** |
  | `share_removed = 0.30` | 234 | 0.702 |
  | `cut_u = 0.30` | — | no such `cut_u` (grid is .05 .12 .22 .35 .50 .65 .80 .92) |

  Restricting to rows within ±0.01 of a 0.30 geometric target (n=64), achieved runs
  **0.252 to 0.324, median 0.301** — **no run at 0.215**, and no `(dir, cut_u)` cell in the
  whole 64-cell grid has a median achieved coverage near 0.215.

  The claim the sentence supports is that the feedback loop is large enough that achieved
  coverage cannot be the treatment variable. The measured feedback is
  `median(geometric − achieved) = 0.0001`, p90 `0.051`, max `0.284`. So the sentence
  overstates the typical effect by ~850x. **The methodological choice is still right** —
  treatment must be pre-DEM — but its stated magnitude is not a measurement.

  It has **no producer line** in `data-raw/dem_calibrate-coverage_error.R` (the `cut_u`
  mapping block at script:947–952 prints share and achieved per `cut_u`, and never this
  pair) and **no test assertion**. Fix: replace with a figure the `cut_u` producer actually
  prints, e.g. *"a `cut_u` of 0.65 removes a median 0.817 of the footprint and comes back
  as 0.166 achieved; the mapping is within 0.01 at the median and 0.05 at the 90th
  percentile"* — and add the assertion, since this is the one number in the section with no
  binder of any kind.

- **[fragile] `data-raw/dem_calibrate-coverage_error.R`:876 — round 2's own fix landed in
  one of two adjacent lines.** Line 873 was corrected to report flips over `nat_usable`
  (873 of 7,616, 11.5%). The `flipped to:` line immediately beneath it still reads
  `sw$flipped` — every arm and both mechanisms — and prints **`no_dem_coverage 1096`**
  under a headline that just said 873. Same defect, same block, one line down. It is
  enumeration-A row S3, the only one of seventeen that disagrees. Use `nat_usable$flipped`.

- **[fragile] `data-raw/dem_calibrate-coverage_error.R`:1013 — the arms table's `flips`
  column can no longer be non-zero, so the note's "with zero classification flips" is now
  reproduced by a column that cannot report anything else.** Round 2 added
  `sw$footprint_terrain %in% "dem_agl"` to that loop. In the shipped sweep **0 of 10,248**
  `dem_agl` rows have `height_source != "reported"`, so `flipped` is identically `FALSE`
  on the filtered population and `sum(z$flipped)` is 0 by construction.

  I checked whether the note's claim survives: it does — before the filter, the three arms
  were `flips = 0` and native was 873, so the arms genuinely had none. The claim is true;
  the *reproducer* for it is now decoration. Either count flips before the filter
  (`sum(sw[arm & na_mask & cov<0.8, ]$flipped)`) or drop the column and say in the note
  that the arms' population excludes total-loss runs by construction.

- **[fragile] `tests/testthat/test-fly_footprint_coverage.R`:911 vs 917–918 — the pair that
  round 2 found is pinned asymmetrically.** `within_grad` gets both ends
  (`round(min,2)==0.27`, `round(max,2)==0.59`); its companion claim in the note —
  "`covered_sd` at rho 0.39 to 0.59" — gets only `expect_gt(min(within_sd), 0.38)`.
  So `max(within_sd)` (0.594, published as 0.59) has **no** assertion, and the lower bound
  0.38 does not pin the published 0.39 (the value is 0.385, and 0.384 would keep the test
  green while making the prose wrong). Round 2's finding was that this exact sentence had
  no binder; the fix bound the half that had been wrong. Mirror the two assertions.

- **[fragile] script:958 vs test:885 — the held-out population is spelled two different
  ways and agrees only on today's data.** Script: `holdout & is.finite(err) & covered_n > 0`.
  Test: `holdout & dem_coverage > 0 & is.finite(covered_grad)`. Both give n=2,259 over 40
  targets today, row-for-row identical — but over the full `dem_agl` population they
  differ: **6 rows** have `covered_n > 0` with `covered_grad` `NA` (1–3 cells; e.g.
  1243708/NW/0.80, 781945/N/0.92) and **3 rows** have `dem_coverage > 0` with
  `covered_n == 0`. All nine happen to sit in the training third. If one lands in the
  holdout after any re-seed, `stats::cor` (default `use = "everything"`) returns `NA` for
  that band, so the script's `min(r_sd)` producer line prints `NA` while the test —
  excluding the row — still prints a number and stays green. Spell the population once
  (a `held_out()` helper beside `native_sized()`, with the script importing the same
  predicate in a comment) rather than twice.

- **[fragile] note:322–324 — "Four are **not** recomputable from the shipped tables" is
  itself an unbound count, and it undercounts by at least two.** Also not recomputable:
  the `1.6e-13` analytic-agreement figure (the shipped table is rounded to 3 dp, so it
  recomputes to **3.7e-06**; the test's comment says so at line 806–807, the note does not)
  and the digital population `223,667` (nothing in `dem_coverage_population.csv` carries
  it — only `digital_edge_candidates_total = 173`). `1833 m` is a third. Either widen the
  sentence or state the recomputable value beside the full-precision one.

- **[fragile] note:600–604 — the calibrated-bound paragraph is the largest block in the
  section with no producer line and no assertion.** `4.97`, `95.3%`, `6.1×`, `89.4%`. All
  four recompute exactly (95.3%, 6.08, 89.4% — I verified), which is the point: they are
  derivable, so a producer line and one `expect_equal` cost nothing, and the paragraph is
  the one arguing *against* shipping something. The four gain ratios (2.3/3.2/2.6/4.1,
  restated in two R comments, roxygen, the `.Rd` and the warning as "2 to 4") are in the
  same state — bounded by `>2` / `<4.5`, which admits 2.05 and 4.49.

- **[fragile] `R/fly_footprint.R`:483–485 (and `man/fly_footprint.Rd`:39–43) — `dem_elev_sd`
  is documented with no `NA` rule, directly after `dem_coverage`'s explicit one.**
  The `@return` says `dem_coverage` is "`0` where it covered none, `NA` only where there is
  no footprint", then gives `dem_elev_sd` as "the standard deviation in metres of the DEM
  values under that footprint" with no qualification. The two differ: a `no_dem_coverage`
  frame has `dem_coverage == 0` and `dem_elev_sd == NA`, a `gsd_scaled` frame has both
  `NA`, and a footprint over **one** cell has `dem_coverage > 0` and `dem_elev_sd == NA`
  (`fly_dem_sample()` line 340 guards on `> 1L`). The shipped sweep contains 33 such rows,
  so it is reachable. A caller reading the pair as the prose invites will treat "spread
  unknown" as "no footprint".

- **[fragile] note:566–571 — the pooled predictor table prints `dem_coverage | 0.717`
  where the value is **−0.717**,** while the within-band table twenty lines below prints
  explicit signs (`+0.438`). The script's own producer prints `%+.3f`, i.e. `−0.717`, and
  the test wraps that one row in `abs()` and leaves the others bare. The table is defensible
  as magnitudes, but it is the only row in the section whose sign is silently dropped, and
  the mixed convention invites reading coverage and `covered_grad` as the same direction.

## Not findings (checked and clean)

- `man/` regenerates byte-identical — round 1(1) holds across the whole package.
- The targets/runs split keys on `airp_id` + `arm` everywhere (script:307, test:737);
  `ref_area` differs on 39 of 40 and `ref_n` on 40 of 40 per arm, so the key is
  load-bearing and correct — round 1(3) holds.
- Every headline, floor, DEM-vs-nominal, spread, within-band, gain, arm and population
  figure in the note reproduces from the shipped CSVs (see Enumeration B).
- `write_if_changed()`'s per-column quoting is correct: `needs` resolves to column 4
  (`coverage_bin`) for the population table and to nothing for sweep/targets, and the
  shipped files show exactly that. (It tests `is.character()` only, so a factor column
  would bypass it — no factor columns exist here.)
- `fly_dem_sample()` gains `spread` by name, both call sites (`first`, `second`) read by
  name, and `spread` mirrors `covered` exactly at line 1120 — the returned rectangle's pass
  in both cases. `NA` handling matches `elev`'s.
- Round 1(4)'s all-NA `tapply` vacuity is closed with `expect_identical(sum(!is.na(.)), …)`
  premises at four sites (test:844, 873, 909–910, 932); each is the right count.
- No other test or the vignette asserts an exact column set, so adding `dem_elev_sd` breaks
  nothing; `fly_reported_cols()` is updated.
- `p$footprint_terrain == "dem_agl"` in the population tests does not produce `NA` index
  rows, because `p$set == "edge"` is already `FALSE` on the three `NA`-terrain total rows
  and `FALSE & NA` is `FALSE`.
