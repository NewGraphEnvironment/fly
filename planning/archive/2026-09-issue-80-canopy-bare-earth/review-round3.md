# Code-check round 3 — fly#80 (`data-raw/dem_measure-canopy_height.R`, `tests/testthat/test-fly_footprint_canopy.R`)

Scope: `git diff main...HEAD` and the untracked test, concentrating on HEAD's Stage 4 rewrite
(`vri_polys()`, `epoch_frame()`, `ev_at()`, `epoch_verdict()`).

How the probes ran:
- All probes ran from `scratchpad/rv3/` against the caches. The in-flight run (PID 24871,
  `canopy_full_frozen.R`) was not touched.
- `diff` shows the frozen copy's Stages 0–3 differ from HEAD only in seeding placement and the
  `ON_LAND` cache. `measure_canopy()` is byte-identical, so the frames it is writing are valid
  for HEAD.
- The smoke copy is identical to HEAD.
- Two live VRI queries (frames 1222772 and 294741) and one empty-ocean query.

## Verdict on Stage 4

Stage 4 counts each frame once and computes the verdict Amendment 4 states. No bug found.

### Each frame is counted exactly once

- `ep` takes its rows from `ms`, which `merge()` sorts by `airp_id`, an integer key, so row order
  does not depend on locale. `ms` has one row per `airp_id`: `smp` is drawn without replacement
  within disjoint strata, and the census asserts `!anyDuplicated(airp_id)`.
- The per-frame VRI cache is `<airp_id>.rds`.
- `EP$ids == ep$airp_id`.
- `ev_at()` takes `ms[ms$airp_id %in% EP$ids, ]`, and line 881 asserts the row count.
- Every census `photo_year` is finite (1963–2011, 0 NA), so each frame falls in exactly one
  decade.
- Line 976 splits the unknowns into three groups. They are disjoint (`vri_share == 0`;
  `vri_share > 0` with `c_now` NA; `c_now == 0`) and together cover every `!known` frame.
- When the cap binds, the subsample is uniform, so inclusion is constant and the design weights
  stay proportional. The draw is seeded right before it is made.

### The verdict computes what Amendment 4 states

- `r = c_then / c_now` is area-weighted over known area. Non-treed area enters both sums as 0 and
  cancels in `r`. A treed polygon with no age or height is unknown, and so is a stand with `O > cy`.
- A replaced stand (`py < O <= cy`) is neutral.
- A frame counts as worse when `dsm_worse = known & r < 0.5`. That is the right threshold:
  `|1 - r| > r` holds exactly when `r < 0.5`, and the comparison is unchanged by the sign of
  `c30`.
- A decade holds when it has at least 10 known frames, the known frames carry at least half the
  decade's weight, and the weighted share is under 0.10.
- `cy` is 2013 when `radar_share > 0.5` and 2018 otherwise. It is re-evaluated at ±3, and the
  central value decides.
- The outcome ladder matches Amendment 1.
- I ran `ev_at()` and `epoch_verdict()` from HEAD on the smoke cache, plus a synthetic frame with
  no VRI. Both ran cleanly, and the empty frame is classified unknown.

### The new code holds up on live data

- `PROJECTED_DATE` comes back as `Date` (`"2025-12-31"`), so `substr(…, 1, 4)` is the year.
- An empty bcdata result is a 0-row `bcdc_sf`, which the `nrow(v)` check handles.
- On both smoke frames the VRI area sums exactly to `area_fp`, so no polygons overlap.
- Non-`T` polygons that carry a height are `V`/`N` (shrub, `BCLCS_LEVEL_4 = SL`) at crown closure
  1–8%. Counting them as zero canopy is sound, and in any case they cancel in `r`.

## Mechanism

**What the earlier findings share: a value is used as what its name says, not as what produced
it.** Every quantity in this script carries context that is not in the variable:
- the instrument, surface, epoch and scale it measures;
- the sampling design its frequencies represent;
- the runtime type and shape its producer actually returns;
- the RNG state the run had reached.

Each earlier defect combined two values whose contexts happened to agree on the cases the author
had looked at: fully attributed stands, numeric columns, at least one row, a run from a cold
cache, frames whose class changed on both axes at once. The values were then treated as
commensurable everywhere.
- (a) Instrument, epoch and scale: R1 VRI heights at 2025; R2 VRI height against DSM canopy.
- (b) Type and shape: R2 bcdata's all-NA column as character; R2 `%in%` used where an elementwise
  comparison was needed; the `data.frame()` scalar beside zero-length columns.
- (c) Design: R1 drawing proportional to weight and then weighting again; R1 unweighted medians;
  R1 the denominator drop.
- (d) Run state, the same shape again: R1's single top-level seed.

All three candidate mechanisms are confirmed as real. They are one mechanism seen along three
axes.

### (a) Quantities from different instruments, scales or epochs combined — every site

| line | combination | safe? |
|---|---|---|
| 233 | sea `s - a` (MRDEM DSM − DTM) | yes: one grid, asserted at 150 |
| 266 | `meta_mean`: Meta cm/100, a different epoch | yes: reported beside the others, not combined with them; not decisive (Amendment 1) |
| 269–271 | HRDEM DSM − HRDEM DTM; MRDEM DTM − HRDEM DTM | yes: both CGVD2013, 3979 → 3979 average (no rotation) |
| 359–386 | LidarBC (UTM, 1 m, 2019–25) against MRDEM (3979, 30 m, radar 2011–15) | yes for clause 3. Datum is CGVD2013 per the STAC; 2 of 150 windows are 2019–20 and could be CGVD28, a sub-metre offset against a ~7.75 m median, so it is lost in a slope. Epoch gap stated in Amendment 2 (biased low). The UTM→LCC average warp weights a slightly mis-rotated pixel set per cell, but the per-window means are over ~2,690 cells and only the tile edge differs. |
| 484 | census `cd - ct` | yes: same window and size, `compareGeom` asserted |
| 510 | `p_census = c / (scale × focal)` | yes: labelled "nominal agl"; used only to stratify (Amendment 1) |
| 651 | `e_t = H − agl_dtm`, ray-cast start | yes: fly_footprint's own mean of the same surface |
| 665–668 | `c30` under `gt` (cell centres) | yes: the same DSM − DTM grid; the window snaps out |
| 677–678 | `T_dtm` from `W_dtm` on the DTM; `T_dsm` from `W_dsm` on the DSM | yes: each ring is cast from its own surface's start elevation |
| 705, 1002 | `c_coastal` (mean over finite cells, axis-aligned square) used as `c·(1 − sea_frac)` in #65's formula | yes within a bound. Over readable sea DSM = DTM (Stage 1, mean 0.00), so a mean over all cells already carries the land share. Where sea is nodata it is skipped and the shift is overstated by `1/(1 − nodata share)`. #65's `admitted` requires `dem_coverage ≥ 0.95`, so that is ≤ 5%. The square-vs-rotated difference is stated. |
| 897–901 | census calibration `p_census / p30`, where nominal agl ≠ `agl_dtm` | yes as published: diagnostic only, and the ratio includes the #9 datum offset by construction. No verdict reads it (Amendment 1). |
| 904 | identity `d_c` against `c30 / agl_dsm` | yes: labelled as an instrument diagnostic, unweighted |
| 946 | first order | yes: `(1+today)/(1+rho_dtm)` is exactly `sqrt(T_dtm/T_dsm)` |
| 950 | slope `imaged_over_dtm` on `mrdem_canopy` | yes: per window, both on the same MRDEM cells |
| 855–864, 877 | **VRI ratio `r` applied to the DSM's `c30`** (Amendment 4) | Yes for scale: only a ratio crosses instruments, and inside one stand `r` depends only on age, since `h` cancels. **Fragile for area:** `r` comes from the frame's *known treed* area, while `c30` covers the whole footprint, and no minimum fraction is required. See F2. |
| 870 | `cy` by `radar_share` majority | stated assumption, with ±3 sensitivity (accepted) |
| 999–1003 | #65 `elev_l`, `d`, `k65` | yes: reproduces #65's formula and selection. `n_sea > 0` is implied by `d > 0`, since `mean_land == mean_all` when there is no sea. |

### (b) Type or shape assumed from the happy path — every site

| line | assumption | safe? |
|---|---|---|
| 119–120 | header present | yes: `%\|\|%` (defined before the first call), and `[[` on a list gives NULL |
| 130 | status is character `"200"` | yes: `c()` coerces |
| 232–237, 262–271 | all-NA windows | yes: `median(numeric(0))` NA, `mean` NaN, `q()` na.rm; printed, not asserted |
| 177/182 | Meta tiles: none, one, several | yes: NULL, a single tile, and `do.call(merge)` are all handled |
| 349 | `properties$datetime` exists | yes: a NULL errors inside `tryCatch` and is counted as a failure (cache already built) |
| 363, 371 | empty or small window | yes: returns NULL |
| 426–430 | zero windows | yes: refuses below 30 (round-1 fix) |
| 459 | `scale` like `"1:15000"` | yes: `suppressWarnings(as.numeric)`, then `is.finite` |
| 494–506 | summed-area lookups out of range | yes on today's census: `box()` is evaluated for every frame through `ifelse`. An index past `nrow` would error, but the cached census ran. |
| **535–538** | **`na_bin` when no frame has NA `p_census`** | **No. `aggregate()` on zero rows raises "no rows to aggregate" before the `if (nrow(na_bin))` guard runs. Reproduced. See F1.** |
| 604 | stratum of size 1 | yes: `sample.int`, not `sample` |
| 608 | `table[name]` indexing | yes |
| 643–648 | empty footprint geometry | yes: `st_is_empty`, `%in%` on NA |
| 669–670 | zero extracted cells | yes for admitted frames, whose coverage is ≥ 0.95 |
| 721 | `as.character(airp_id)` for cache names | yes: the same coercion on both the write side (745) and the read side |
| 740, 753 | row-binding per-frame lists | yes: every field is length 1 with a stable type |
| 777–778 | `mapply(identical, …)` | yes: elementwise and NA-safe; `ms` is never empty |
| 805–811 | bcdata empty result | yes: a 0-row `bcdc_sf` (live probe) |
| 816–828 | all-NA or character columns; zero rows | yes: explicit `as.numeric()`. `mk()` builds every column at `length(a)`. `PROJECTED_DATE` is `Date` (live probe). |
| 828 | `BCLCS_LEVEL_2` NA | yes: `%in%` gives FALSE, so the polygon counts as non-treed and cancels in `r`. That is not the "unknown" Amendment 4 means; see F2. |
| 846–864 | `epoch_frame` on 0 rows; all unknown; `c_now == 0` | yes, all three return NA `r`. The one NaN route, known area summing to 0 m² which reaches `if (NaN > 0)`, needs every known polygon to touch the square only on a line. Coordinates would have to coincide exactly, so it is not reachable in practice. |
| 871–874 | `vapply(numeric(6))` names | yes: taken from the first call, and every call returns the same named `out` |
| 766–771 `wq` | empty input, zero weights, NA weights | yes: returns NA, and zero-weight items never land on the quantile when p > 0 |
| 963–970 | a decade with 0 known frames | yes: `sh` NA, so the decade does not hold; `sprintf("%.1f", NA)` prints `NA` |
| 1019 | `sig()` | yes: doubles only |

### (c) Sample against population weighting — every site

| line | figure | safe? |
|---|---|---|
| 309 | `SRC_SHARE`: share of coarse cells | yes as a diagnostic. LCC 3979 is conformal rather than equal-area, so cell areas vary by a few percent across BC. |
| 522–529, 531 | census figures, `cen_bin` | yes: the census *is* the population, so unweighted is correct |
| 601–608 | stratified draw, `w = N_h / n_h` | yes. The pool excludes the 23 frames with NA `p_census`, and these are reported. |
| 614 | weight sum | yes |
| 894 | admitted weight share | yes: weighted, and the estimand becomes the admitted subpopulation, as stated |
| 899–901 | calibration | weighted |
| 904, 946 | identity, first order | unweighted and labelled as instrument diagnostics (accepted) |
| 907–927 | `d_c` overall, by scale, by decade, by source | weighted |
| 929 | Meta ratio | weighted |
| 939–945 | `rho`, `today` | weighted |
| 950 | lidar slope | unweighted over random radar points. That is the rule's own estimand: area-representative of radar land. |
| 798–800 | epoch cap | uniform, so weights stay valid. Projected eligible frames: 85 of 173 done, so about 300 of 612, under the cap of 400 and unlikely to bind. If it did bind it would cut a decade's *count* toward the n ≥ 10 floor. |
| 962–965 | the decade gate | the count is unweighted, correctly, since it is a sample-size floor. `kw` and `sh` are weighted. |
| 979–981 | epoch medians | weighted |
| 1006–1011 | #65 table | unweighted, matching #65's own published table (accepted) |
| (d) 329, 390, 602, 799 | every RNG draw | seeded where it happens (round-1 fix) |

## Findings

- **[fragile] data-raw/dem_measure-canopy_height.R:535–538 — the `na_bin` step fails when the
  census has no NA `p_census`, and the guard written for that case is dead code.**
  - `stats::aggregate(list(n = rep(1L, 0)), list(...zero-length...), length)` raises
    `no rows to aggregate`. Reproduced.
  - So `if (nrow(na_bin))` can never see the empty case. Stage 2's binning runs on every run;
    it is not cached.
  - Today's census has 23 NA frames, so this does not fire. It will fire if MRDEM is
    regenerated (a new `VKEY` and a new census) and every frame lands on coarse data. The run
    would abort at Stage 2 with nothing published, so it fails loud.
  - Fix: build `na_bin` only `if (any(is.na(census$p_census)))`.

- **[fragile] data-raw/dem_measure-canopy_height.R:851–865, 876, 962–964 — a frame counts as
  "known" however little of its canopy VRI dates, and the decade gate counts frames, not area.**
  - **What the code does.** `r` is computed over the frame's known treed area only. Unknown
    treed area (no age or height) and unreported polygons (`BCLCS_LEVEL_2` NA, scored as zero
    in both epochs) drop out of `r`. Yet the frame still counts fully toward the n ≥ 10 floor,
    the 50% known-weight test and the share.
  - **Measured on smoke frame 294741 (1993, lidar, `c30` 6.6 m, `d_c` 1.1%).** The footprint is
    80.6% treed, but only 22% of it is known-treed. 58.6% of its VRI area is unknown. Its
    `r = 0.688` and its weight (16,457) come from about a quarter of its canopy.
  - Frames near the BC border have the same exposure: VRI covers only BC, and `vri_share` is
    reported but never gated.
  - **It matches Amendment 4 to the letter.** Amendment 4 calls a frame unknown only when *all*
    its VRI area is unknown. So this is not a deviation from the rule, and it cannot be
    "fixed" in code without an Amendment 5 written before any VRI result is read.
  - **Why it matters.** If the unattributed polygons are not a random subset of the treed ones
    (for example, managed land whose attribution lags disturbance), the decade share is biased
    in an unknown direction. The 50% known-weight gate, which reads as a safeguard, passes
    anyway.
  - At minimum, publish the weighted median of the known-treed share of the footprint beside
    each decade's verdict. Better: pre-register a threshold on it (for example, a frame is known
    only if its known area is at least half its treed area).

## Checked, not findings

- **The test file passes** (8 expectations, with `NOT_CRAN=true`). Its comment says
  "c / agl ... is 1.7e-3 away in relative terms". Measured on `height_fixture()[1, ]`
  (agl 1928 m) it is **1.31e-2** relative (1.70e-4 absolute). The 1e-6 tolerance still
  separates the two forms by four orders of magnitude, so the assertion is sound and only the
  number in the comment is wrong.
- **The ±3 canopy-year verdicts cannot be rebuilt from shipped data.** `dem_canopy_epoch.csv`
  holds only the central values, and the raw polygons are not shipped. The central verdict can
  be rebuilt by joining `out_e` to `out_s` (`weight`, `decade`). The ±3 lines are sensitivity
  only, not a decision input.
- **`raycast()` takes 3005 rings and a 3979 window**, and `sf_project`s internally, so the CRS
  mix in `measure_canopy` is handled.
- **A single-row `fly_footprint()` has no bearing,** so `gt` is axis-aligned. That makes the VRI
  square in `vri_polys()` the same footprint `c30` was read under.
- **Replaced stands (`py < O <= cy`) are scored neutral,** which lowers `r` relative to the
  likely truth: a pre-harvest stand was probably taller than its regrowth. So the neutral rule
  leans *against* RECOMMEND, not toward it.

## Clean otherwise

Apart from the two fragile items above, I found nothing in the Stage 4 rewrite or elsewhere in
the diff that fails or publishes a wrong number.
