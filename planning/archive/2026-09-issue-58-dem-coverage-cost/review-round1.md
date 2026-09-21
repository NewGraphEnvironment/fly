# Review round 1 — fly#58 (partial DEM coverage, `dem_elev_sd`)

Reviewer: code-check subagent. Verdict: **4 findings** (2 bug, 1 bug/data-loss, 2 fragile).

Everything checked mechanically. Baselines run before writing anything:

- `test-fly_footprint_coverage.R` — FAIL 0 ERROR 0 SKIP 0 PASS 72
- `test-fly_footprint.R` 276 pass, `test-fly_footprint_height.R` 118 pass,
  `test-fly_camera_format.R` 75 pass, `test-fly_coverage.R` 8 pass. No regressions.
- Every figure in the new `inst/notes/terrain-correction.md` section was recomputed from
  the three shipped CSVs. All of the error tables, floor tables, ratio tables, predictor
  rhos, gain ratios, mechanism-agreement figures and the `4.97 * sd` bound reproduce
  exactly. The exceptions are in findings 2 and 3.

`fly_dem_sample()`'s shape change is correct. Both return paths and the `vapply`
`numeric(4)` agree; `spread` is `NA` exactly where `got <= 1`; `spread[is.nan()]` mirrors
`elev`; the three other callers (`test-fly_footprint.R:720,744,745`,
`test-fly_camera_format.R:289`) all index by name and are unaffected.
`spread <- ifelse(corrected, second$spread, first$spread)` reads off the same pass as
`covered` on the line above, `dem_elev_sd[dem_eligible] <-` and `dem_elev_sd[no_geom] <-`
mirror `dem_coverage` line for line, and on the bundled fixture **0 rows** have a non-NA
`dem_coverage` with an NA `dem_elev_sd`. `fly_reported_cols()` was updated. No branch on
`half_cross`/`half_along` was introduced.

---

## Findings

### 1. **[bug]** `man/fly_footprint.Rd:268-280` — generated docs are stale; six published numbers disagree with both the roxygen and the shipped CSVs

`devtools::document()` was not re-run after the roxygen was finalised. The `.Rd` carries an
earlier draft of the same paragraph — same sentences, different numbers:

| claim | `R/fly_footprint.R:703-707` | `man/fly_footprint.Rd:271-275` | recomputed from CSV |
|---|---|---|---|
| median at 80-90% | 0.18% | **0.03%** | 0.178% |
| median at 60-80% | 0.34% | **0.33%** | 0.335% |
| median below 20% | 1.5% | **2.3%** | 1.491% |
| worst case | 24% | **25%** | 23.563% |
| spread at fixed coverage | 13 to 52x | **9 to 40x** | 12.96 to 52.03x |
| high- vs low-spread gain | 2.3 to 4.1x | **2 to 5x** | 2.28 to 4.07x |

The roxygen is right on all six; the `.Rd` is wrong on all six. This is the file that
becomes `?fly_footprint` and the pkgdown reference page, so the wrong set is the one users
read. `0.03%` is in fact the 0.95-0.99 band's median, and `2.3%` is not a value any band
takes — this is not rounding, it is a superseded draft.

Fix: `devtools::document()` and commit the result. `man/` is never hand-edited
(`r-packages.md`), so nothing else is needed.

### 2. **[bug]** `inst/notes/terrain-correction.md:340` and `:492` — "9,600 native `na_mask` runs" is the wrong denominator, and it contradicts the table immediately beneath it

There are **7,680** native `na_mask` runs (120 targets x 8 dirs x 8 cuts), of which
**7,616** have a usable reference. 9,600 is the `na_mask` total across *all four* arms
(7,680 + 3 x 640) — the word "native" and the count come from two different populations.

It is self-contradicting on the page: line 340 introduces the band table with "Over the
9,600 native `na_mask` runs whose frame the DEM still sized — the 873 that lost their
terrain entirely are ... counted separately", which invites 9,600 − 873 = 8,727, while the
table below it sums to **6,743** (= 7,616 − 873). Line 492 turns the same error into a
rate: 873/9,600 = 9.1% where the measured rate is 873/7,616 = **11.5%**.

873 itself is correct and the test pins it (`expect_identical(sum(flipped), 873L)`) — only
the denominator is wrong, and nothing in the suite reads it. Verified:

```
native na_mask rows (all targets): 7680   ref_ok: 7616
  dem_agl: 6743   no_dem_coverage: 873   other: 0
runs per arm x mech: native 7680/1920, coarse 640, geographic 640, anisotropic 640
```

### 3. **[bug — silent data loss]** `data-raw/dem_calibrate-coverage_error.R:992-1005` — the two-table split discards each robustness arm's own reference, on a stated premise that is false

```r
# ... Every per-target fact — the frame's attributes and its
# full-coverage reference — is constant across that target's 96 runs ...
targets_out <- sweep[!duplicated(sweep$airp_id), c(..., "ref_ok", "ref_agl", "ref_area",
                     "ref_elev", "ref_sd", "ref_range", "ref_grad", "ref_n", ...)]
```

The `ref_*` columns are **not** constant across a target's runs. `sweep_target()` computes
them from `fly_footprint(pts, dem = full)` where `full` is the *arm's* DEM, so the coarse,
geographic and anisotropic arms each carry their own reference. `!duplicated()` keeps the
first row, which is always `sweep_mask` (native), so the arm rows' references are
overwritten with the native ones and are unrecoverable from the shipped artifact.

Measured against the still-present `data-raw/.cache/dem_coverage/*.rds`:

```
targets whose ref_area differs across arms:  39 of 120   (coarse: up to 1.37% relative)
targets whose ref_sd   differs across arms:  40
targets whose ref_n    differs across arms:  40
shipped targets.csv == native ref_area: TRUE   == native ref_n: TRUE
coarse-arm targets where shipped ref_n != the coarse arm's own ref_n: 40 of 40
   e.g. airp_id 38998: shipped 6023 cells, coarse arm's own reference 6 cells
```

`ref_area` up to 1.37% off is the same order as the arm medians being reported (~0.7%), so
this is not cosmetic. It happens not to change a verdict here only because `ref_ok` agrees
across arms on all 120 targets — luck, not design, and nothing asserts it.

**The consequence is already visible as a note/script disagreement.** The script's own
`pub()` producer line for the arms (which uses each arm's own reference, and does not
filter to `dem_agl`) prints numbers the note does not publish:

| arm, median abs error below 0.8 coverage | script producer line | note line 543 / test `arm_median()` |
|---|---|---|
| coarse | 0.696% | **0.686%** |
| geographic | 0.585% | **0.591%** |
| anisotropic | 0.677% | **0.681%** |
| native | 1.075% | **0.777%** |

The note's four figures are the *shipped-CSV* recomputation, not the script's output — so
"`data-raw/dem_calibrate-coverage_error.R` reproduces all of it" (note line 377) is not
true for this row, and `test-fly_footprint_coverage.R:837-840` asserts the note's numbers
against the artifact that produced them rather than against the script. (The native gap is
a second, separable cause: the script's arm loop does not filter `footprint_terrain ==
"dem_agl"` while the note and the test do.)

Either carry the arm's reference — key `targets_out` on `(airp_id, arm)` rather than
`airp_id` alone, which costs 120 extra rows — or drop the arm rows' `ref_*` from the join
and state that the arms are scored against the native reference. What must not stay is a
comment asserting a constancy the data contradicts, since the next person will trust it.

### 4. **[fragile]** `tests/testthat/test-fly_footprint_coverage.R:168`, `:178-179`, `:301`, `:207` — four assertions pass on an empty subset

`min(x, na.rm = TRUE)` on an all-`NA` vector is `Inf` and `max(x, na.rm = TRUE)` is `-Inf`
(measured on R 4.5; warning only, no error), so every one of these passes vacuously if the
`tapply` guard returns `NA_real_` for every band:

```r
:168  expect_gt(min(within_sd, na.rm = TRUE), 0.38)    # guard: if (length(i) < 30) NA_real_
:178  expect_gt(min(gain,      na.rm = TRUE), 2)       # guard: if (length(i) < 40) NA_real_
:179  expect_lt(max(gain,      na.rm = TRUE), 4.5)
```

The `gain` pair matters most: it is the **only** test of the headline claim the whole
column exists for — "frames above the median spread sit 2 to 4 times further out", which is
restated in the warning text at `R/fly_footprint.R:1181`, in the roxygen, and in the note.
Unlike the ratio test at `:146-147`, which is shielded by five `expect_equal()` calls on
named levels immediately above it, nothing else pins these. A change to the sweep that
thinned any band below the guard would leave the suite green with the claim untested.

Two more of the same shape:

- `:301` `expect_true(all(flat$dem_elev_sd[sized] == 0 | is.na(flat$dem_elev_sd[sized])))`
  — the `| is.na()` arm is satisfied by an all-`NA` column, which is the one outcome that
  would mean `dem_elev_sd` had stopped being computed. Over `flat_dem()` the values are
  exactly `0`, so the disjunction buys nothing and costs the assertion its teeth.
- `:207` `expect_true(all(a$share_removed[disagree] > 0.99))` — `all(logical(0))` is `TRUE`,
  and `expect_lt(length(disagree), 5)` on the line above admits 0.

One line each fixes all four: `expect_identical(sum(!is.na(gain)), 4L)` /
`expect_identical(sum(!is.na(within_sd)), 6L)` beside them, `== 0` without the `is.na`
arm at `:301`, and `expect_identical(length(disagree), 3L)` at `:207` (the note states 3,
and 3 is what the artifact gives).

### 5. **[fragile]** `R/fly_footprint.R:334` and `:951` — two inline comments carry superseded figures that contradict the roxygen in the same file

```
:334   # ... come back 2.0 to 5.4 times further from the full-coverage answer ...
:951   # ... the measured error spans 9 to 40 times between frames.
```

Measured from the shipped CSV: the gain is **2.28 to 4.07x** (roxygen `:707` says 2.3 to
4.1 — correct) and the spread is **12.96 to 52.03x** (roxygen `:705-706` says 13 to 52 —
correct). `:951` is the same stale "9 to 40" that finding 1 found in the `.Rd`, so the two
have a common ancestor. No binning of the artifact reproduces either number as a valid
alternative statistic — I tried max/median and p95/median over both the note's bins and the
four-band split, pooled and per-arm.

Related and much smaller: the warning text at `:1181` says "2 to 4 times further out"
against a measured maximum of 4.07x. Defensible as a stated range; worth matching the note's
"2 to 4.1" only because the rest of the cluster is being touched anyway.

---

## Checked and clean

- **Column NA parity.** `dem_elev_sd` is set and cleared on exactly the lines
  `dem_coverage` is (`:1198`/`:1199`, `:1238`/`:1241`). On the bundled fixture, 0 of 20
  rows have `dem_coverage` non-NA with `dem_elev_sd` NA.
- **`fly_dem_sample()` early return.** Both `return()` paths carry all three vectors; the
  `!any(ok)` path returns three `NA_real_` vectors of `length(rects)`.
- **`write_if_changed()` quoting.** `write.csv` does not ignore `quote` (unlike `sep`,
  `dec`, `col.names`), and a numeric `quote` is column indices. The population table's
  `coverage_bin` is column 4 and is quoted in the shipped file; `any(grepl())` returning
  `NA` on an all-NA character column is dropped by `which()`, which is the safe direction.
  Verified against the shipped bytes.
- **`match()` on a pasted key** (`:210`). Both sides are unique within their subset (7,616
  and 1,856 distinct keys for 7,616 and 1,856 rows), no `NA` in `airp_id`/`dir`/`cut_u`, and
  all 1,856 match. No phantom pairing.
- **`tapply` over `cut()`.** No band is empty and no `dem_coverage` is `NA` in any subset
  used, so no row is silently dropped and no level is `NA`: the eight band counts sum to
  6,743 = `nrow(native_sized())` exactly. The `h` subsets guard the `0` boundary with
  `dem_coverage > 0` before `cut(..., c(0, ...))`, which is the right call.
- **Premise assertions.** `nrow(runs) == 11520`, `nrow(targets) == 120`,
  `sum(ref_ok) == 119`, the excluded target named by id, every run joining to a target, and
  the arm/mech/dir/cut level sets — all present and all reproduce.
- **Note figures that reproduce exactly**: every cell of the 8-row band table (median, 5-95%,
  max abs), all seven coverage-floor rows, the five ratio rows, the four nominal-comparison
  rows plus `229`/`15.2%`, all five predictor rhos including the `0.801` gradient product,
  the within-band 0.39-0.59 sd range, all four gain rows with their n's, `10,248` runs for
  the analytic identity, `1,633`/`0.43%`/`14.79%` for the mechanism control, the `4.97`
  bound's `95.3%` and `89.4%`, and every population count (`1,437,147`, `113`, `173`, `66`,
  `26`, `2,975`).

## Not flagged, noted once

`inst/notes/terrain-correction.md:377` claims the three CSVs "ship so the suite recomputes
every figure here". Several do not appear in any artifact and cannot be recomputed — the
digital population's `223,667` and its `6` DEM-sized frames, the 5-95% percentile columns,
and the planar-extrapolation row. The figures are plausible and this is an over-claim rather
than a wrong number, but the sentence is the kind of completeness claim this repo's
conventions say to bound rather than assert.
