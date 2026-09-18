# Review round 1 — fly#54 (`flying_height` checks), branch vs main

Reviewer: fresh-eyes subagent, read-only. Working tree reviewed (it carries staged edits past `8ebf0c2`).
Probes ran against a scratch copy; nothing in the repo was modified except this file.

## What was checked and held (so it is not re-done)

- Full suite, `NOT_CRAN=true devtools::test()`: `FAIL 0 | WARN 0 | SKIP 0 | PASS 1817`.
- `devtools::document()` in a scratch copy: `man/` byte-identical to the committed one, NAMESPACE unchanged.
- **Restore-the-bug, 10 mutations of `R/fly_footprint.R`, each run through `test-fly_footprint_height.R`
  with the mutated package loaded — every one went red** (asserted the replace matched exactly once):
  second pass not withheld (1 fail, the grid-size test); over-ceiling frame seeded (1, same test);
  digital compared against `scale` (6); `!implausible` dropped from `unusable` (1); `"implausible"` wiped on
  empty geometry (4); below-terrain line removed (1); `unsized_digital` un-gated (1); repair without the band
  test (7); ceiling arm dropped (5); `agl <- fh - elev` (6). No vacuous assertion found in the new test file.
- NA poisoning: none reachable. `disputed`, `slipped`, `implausible`, `over_ceiling`, `corrected`, `repaired`
  are all built from `is.finite()` / `%in%` / `in_band()` guards ahead of every comparison. Probed by running:
  NA and 0 `focal_length`, NA `flying_height`, unparseable / NA / `"1:0"` `scale`, no `media` column, a digital
  medium named in `format_size`, integer and character `flying_height`, zero rows with `dem`, missing
  `flying_height` column (still the pre-existing clear error). No error, no NA index, invariant
  (`has_height == !is.na(height_agl) == terrain %in% "dem_agl"`) held in every case.
- Numbers recomputed from the shipped CSVs and the local cache and found correct: 1,589 slipped / 13 rolls /
  the roll-year list / 1,054 in 2003; raw r 10.01–15.83; repaired 0.80–1.32, median 1.05; random median 1.03,
  2.5–97.5% 0.81–1.25, 99.2% in band; gap 6.69–10.01; 2,733 other out-of-band, repair fires on 0; lower tail
  726 / 729 / 799; 14,630 m and 7,513 m of 223,667; 1,670,471 centroids; 1,437,147 usable film; 1,208 unslipped
  frames on slipped rolls; `bc78065` 4,115 m at 1:2000, `bc78078` 9,449 m at 1:6000; 1:35000 frames 102–118 km.

## Findings

- **[severity: fragile — reporting regression, verified by running on main and on the branch]**
  `R/fly_footprint.R:1076` + `:1126` — a **camera-table digital frame with terrain at or above the aircraft now
  comes back with no footprint and no warning that says so**. Line 1076 labels it `"implausible"`; line 1126
  (`unsized_digital <- from_table & no_geom & !(height_source %in% "implausible")`) then suppresses the
  "known recording format but no way to size it, so they have no footprint" warning for it. The justifying
  comment ("has already been reported by the warning that says what was wrong") is true for the *ceiling /
  ratio* route, whose warning says "a frame with no reported scale to fall back on has no footprint" — but this
  frame is in the `unusable` class, and the only warning it gets ends **"Sized from nominal scale instead"**,
  which is false for it (geometry is empty). Probe: `height_fixture()[c(1, 8), ]` with `flying_height = c(100, 100)`
  over `flat_dem()`. main: two warnings (unusable + "no way to size it … no footprint"). Branch: only the
  unusable one. Fix is to key the suppression on the `implausible` logical (the frames the implausible warning
  actually counted), not on the `height_source` string, which line 1076 also writes for `unusable` rows.

- **[severity: fragile — mislabel + false warning text, verified by running]**
  `R/fly_footprint.R:945-946, 978` — the ceiling arm of `implausible` is not gated on the first pass having
  found terrain, and `uncovered` excludes `implausible`, so **a frame the DEM does not cover whose
  `flying_height` is over 16,000 m is no longer `"no_dem_coverage"`**. It comes back
  `footprint_terrain = "nominal_scale"`, `dem_coverage = 0`, `height_source = "implausible"`, under a warning
  saying the height "cannot be reconciled … and no single correction explains it". Probe: fixture row 2 (the
  slipped twin, 28,288 m) moved to -120, 50. That is exactly the slipped population — all 1,054 of the 2003
  frames read ~75 km — so with a DEM cropped to an AOI, the off-DEM slipped frames are told no correction
  explains them when the correction simply could not be tested; extend the DEM and the same frame becomes
  `"corrected_unit_slip"`. It contradicts two documented statements: `"no_dem_coverage"` = "`dem` supplied but
  does not cover the frame", and `height_source` `NA` = "one the DEM does not cover". On main this frame was
  `no_dem_coverage` with the "fall outside the DEM's coverage" warning. Geometry is the same either way
  (nominal), so this is labels and message only — but `footprint_terrain == "no_dem_coverage"` is the documented
  way to find frames needing a bigger DEM.

- **[severity: doc claim measurably false, verified by recomputing from `flying_height_sweep.csv`]**
  `R/fly_footprint.R:184` (constant comment) and `inst/notes/terrain-correction.md` ("Reading the value as plain
  feet instead misses the terrain by 4.5 to 17.7 km") — over the shipped 1,589 slipped frames,
  `flying_height * 0.3048 - elev - scale x focal_length` runs **0.82 to 22.7 km**, not 4.5 to 17.7. The quoted
  range is from the plan-mode sample (`task_plan.md:35`: 150 frames, all with `flying_height > 15,000`), a
  population that by construction excludes the low-altitude slips (`bc78065` at 4,115 m) the same note calls
  load-bearing. The comment attaches it to "all 1,589", and the note says the data-raw script "reproduces all of
  it" — the script computes no feet hypothesis at all. The conclusion survives and has a stronger form from the
  shipped data: read as feet, r is 3.02–4.71 on the 1,589 and **0 of 1,589** land in the band.

- **[severity: doc claims slightly off, verified by recomputing — low]** `inst/notes/terrain-correction.md` /
  `R/fly_footprint.R:190`:
  - "The next mass out is at r 1.8–2.3, and 209 of 223 sampled frames in it are catalogued at 153 mm" — 209 of
    223 is the `near_upper` set at **r > 1.8** (max 2.53). Inside 1.8–2.3 it is 201 of 212 (`near_upper`), or
    241 of 252 over every non-slipped sampled frame. Same ~95%, different population than stated.
  - "1,962 frames read under half their nominal height" — the population CSV gives **1,963** at
    `ratio_asl <= 0.5`; 1,962 is the `lower_tail` *set*, one short because one such frame had already been drawn
    into `random` (the script's `!film$airp_id %in% sets$airp_id`). The 726/729/799 are over the 1,962.
  - "a random 2,500 of the catalogue's 1.44 million film frames put 99.2% inside this band" — the 2,500 are
    drawn from `ratio_asl <= 2` (1,419,822 frames), not from all 1.44 M. Weighting the three strata from the
    shipped CSVs gives about **98.7%** population-wide (58% of `near_upper` in band, 5 of 2,094 `upper_tail`).
    The roxygen's "as 99% of frames do" still rounds true; the constant comment's wording does not describe the
    draw.

## Not flagged (checked, accepted or pre-existing)

- Below-terrain film frame warned as `unusable` but labelled `"implausible"` — stated accepted tradeoff.
- `scale = "1:0"` reaching `uncovered` with a zero-size window, negative `focal_length`, factor
  `flying_height` — pre-existing or not reachable from catalogue data.
- `no media column` treats digital rows as film and refuses row 8 — documented as assumed film.
- `diff` is a shell function wrapping `git diff` on this machine; `command diff` was used for the man-page check.
