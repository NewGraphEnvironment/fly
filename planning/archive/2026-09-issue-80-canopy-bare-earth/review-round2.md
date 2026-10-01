# Code-check round 2 — fly#80 (`data-raw/dem_measure-canopy_height.R`, `tests/testthat/test-fly_footprint_canopy.R`)

I reviewed `git diff main...HEAD` and the untracked test, starting with the round-1 fixes in
bf20fd2. All probes ran from `scratchpad/rv2/` and read only the cached inputs. I made three
live VRI queries covering two frames. No repo file was edited except this one, and the
in-flight run was not touched.

These were checked and are not findings:
- **Seeding reproduces the cached probes.** Re-seeding before the LidarBC pick reproduces all
  150 cached probe windows exactly: each `lp` lon/lat is found in the new draw, at index 527 or
  below. The 612-frame sample reproduces too, as the author verified.
- **The epoch draw.** When the cap binds, `sample.int(nrow(ep), N_EPOCH)` is uniform, so
  weighting by `w` is right. `ep` follows `merge()` order (sorted by `airp_id`), so the draw is
  deterministic.
- **The back-projection algebra in `vri_one()`.** Run by hand on live VRI for frame 102164,
  `at()`, `h_now`, `c_then` (with `O <= py` and with `py < O <= cy`) and `unknown` all match
  Amendment 3. Every catalogue film year is 2011 or earlier, so `py > cy` never occurs.
- **Accounting.** Every `ep` frame yields one `ev` row and lands in one decade. Frames with
  `c_then` NA are excluded from the verdict and counted on the `epoch:` line.
- **The verdict lines.** Clauses 1, 2, 3 and the outcome ladder match Amendment 1.

## Findings

- **[bug] data-raw/dem_measure-canopy_height.R:829-830 — `vri_one()` crashes on a frame whose
  VRI has no age or height. The round-1 fix introduced this.**
  - **Mechanism.** When every polygon under a footprint has NA `PROJ_AGE_1` and
    `PROJ_HEIGHT_1`, bcdata returns both columns as **character**. Then
    `O <- yr - v$PROJ_AGE_1` fails with "non-numeric argument to binary operator".
  - **Reproduced** live on admitted frame 895494 (1986, `d_c` 3.0%): 24 polygons, all
    `BCLCS_LEVEL_2 == "T"`, every age and height NA.
  - **Why it is new.** The old code returned at `if (!any(tr))` before computing `O`. The fix
    removed that return to keep non-treed frames in the denominator.
  - **Effect.** Nothing catches the error inside the `lapply` at 852, so Stage 4 aborts. The
    per-frame cache never gets that frame, so every rerun dies at the same frame.
  - **Fix.** Coerce with `as.numeric()` before the arithmetic. That alone is not enough; see
    the next finding.

- **[bug] data-raw/dem_measure-canopy_height.R:818, 840-844, 861-863 — the round-1 denominator
  fix scores the frames it added as "DSM not worse", and many are cases where the DSM is
  worse.**
  - **What the code does.** `dsm_err = |c_then - c_now|` takes `c_now` from VRI, not from the
    DSM. Every polygon that is not `tr` counts as zero canopy in both epochs. For an all-non-tr
    frame that gives `dtm_err = dsm_err = 0`, so the frame counts as "not worse".
  - **Why that is wrong.** Every `ep` frame has `d_c >= 0.5%` by construction, so the DSM the
    package would size from sits at least 0.5% × agl above the DTM, about 9 m at 1,836 m. If
    VRI is right that the photo saw no canopy there, the DSM-sized frame is wrong by `d_c` and
    the DTM-sized one is right: the DSM **is** worse.
  - **Treed polygons with no height count as no canopy.** `tr` also needs a finite age and
    height, so a `T` polygon without them is scored as no canopy rather than as unknown.
    Frame 895494 is 100% `T`, with MRDEM `c30` 20.2 m, `c_fp` (`agl_dtm - agl_dsm`) 19.8 m
    and Meta 6.0 m. With the type crash fixed it would enter the denominator as 0 / 0, "DSM
    not worse". Amendment 3 says only a frame with no VRI, or with all its VRI area unknown,
    drops out. An unknown-height `T` polygon is unknown, not non-treed.
  - **Direction.** Both cases push toward RECOMMEND, which reverses the conservatism the
    round-1 note claimed for this denominator.
  - **VRI's `c_now` is not the DSM's canopy even on fully attributed stands.** On frame 102164
    (lidar-majority), the area-weighted VRI `c_now` is 25.5 m against the DSM's `c30` of
    13.3 m. One frame, so not a population figure.
  - **Suggested fix.** Take the DSM error from the shift the DSM sizing actually applied,
    `|c_fp - c_then|` with `c_fp = agl_dtm - agl_dsm` (already in `ms`). Treat `T` polygons
    with no age or height as `unknown`. This changes the clause-4 procedure, so it needs an
    Amendment 4 before any VRI result is read.

- **[bug] Stale epoch cache: the in-flight run will poison it, and the fixed script will then
  print a stale OUTCOME (data-raw/dem_measure-canopy_height.R:786-790, 859, 984).**
  - **The in-flight run is pre-fix code.** `scratchpad/canopy_full_frozen.R` (md5 `1fee8c89…`,
    started 19:27:48, PID 24871) predates bf20fd2. `diff` against HEAD shows the old PPS draw
    (`N_EPOCH` 250, `prob = ep$weight`), the old 2025-height algebra and the early return. The
    run has no `FLY_CANOPY_STOP` (its env carries only `FLY_DEM_CALIB_WORKERS=4`).
  - **What it will write.** Left alone, it will:
    - write `data-raw/.cache/dem_canopy/epoch_d2eaafb5.rds` with the round-1 defects;
    - write all seven `inst/extdata/dem_canopy_*.csv` into the working tree, the epoch CSV
      included.
  - **What the fixed script then does.** `EPOCH` is keyed only on `VKEY`, so the next run of
    the HEAD script skips Stage 4. It reads the old `ev` and prints an `EPOCH HOLDS` /
    `OUTCOME` line from the old draw and algebra. Only then does it fail at line 984 with
    "undefined columns selected", because the old `ev` has no `unknown_share`. The verdict
    line reaches the log before the crash.
  - **Same flaw in the per-frame cache.** `epoch_frames_<VKEY>/<airp_id>.rds` is not keyed on
    the algorithm either, so the fix for the two findings above would silently reuse frames
    computed before it.
  - **Fix.** Stop the run after Stage 3, or delete `epoch_d2eaafb5.rds` and revert the CSVs
    once it finishes. Put an algorithm tag (for example `"a3"`) in both epoch cache paths.

- **[bug, low] data-raw/dem_measure-canopy_height.R:777-778 — `class_changed` uses set
  membership, not an elementwise comparison.** `!(ms$fp_dtm_height %in% ms$fp_dsm_height)`
  asks whether frame i's DTM class appears anywhere among **all** frames' DSM classes. Most
  frames are "reported" on the DSM, so a `reported -> corrected_*` change that keeps
  `dem_agl` on both surfaces is never counted. Toy check:
  `!(c("reported","corrected_slip") %in% c("corrected_slip","reported"))` gives
  `FALSE FALSE`, although both changed. The published "classification differs between
  surfaces" count, which Amendment 1 requires, and its breakdown table both undercount. On
  the 111 frames done so far the count happens to agree, because the one change also flipped
  the terrain. Use `ms$fp_dtm_height != ms$fp_dsm_height`, with the NA case handled.

- **[fragile] data-raw/dem_measure-canopy_height.R:941-953 — one decade of a handful of frames
  can decide the OUTCOME.** RECOMMEND needs clause 4 to hold for just one decade, and nothing
  sets a minimum n. The sample holds 41 frames from the 2000s and 2 from the 2010s. Only 5 of
  the 2000s frames are in `p >= 0.5%` strata, and 1 had reached `ep` among the frames done so
  far. A 2000s decade of 2–6 eligible frames with zero "DSM worse" would publish RECOMMEND A
  DSM. This follows the pre-registered rule literally, so it needs an amendment (a minimum n,
  or pooled eras) or an explicit n beside the verdict. A silent change would not do.

- **[fragile] data-raw/dem_measure-canopy_height.R:822 — `cy = 2018` on lidar frames is the
  national HRDEM median, not "the epoch of the lidar project" that Amendment 1 assigns to
  lidar cells.**
  - 58 of the 66 eligible frames seen so far are lidar-majority, so this constant sets `cy`
    for most of clause 4.
  - Under the linear model a polygon tips to "DSM worse" when `O > 2·py - cy`, so each year of
    error in `cy` moves that threshold by a year.
  - Either record the constant as an amendment, or source the project year.

- **[fragile, low] data-raw/dem_measure-canopy_height.R:906-909 — the "lidar-majority" label
  is wrong.** `!rad` means "not radar-majority", which takes in blend-majority and mixed
  frames, yet the line prints it as lidar-majority. It is also inconsistent with line 822,
  which uses `lidar_share > .5`. Only the label of the published figure is wrong.

The test file (`tests/testthat/test-fly_footprint_canopy.R`) has no findings.

/Users/airvine/Projects/repo/fly/planning/active/review-round2.md
