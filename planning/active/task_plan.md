# Task: Ship measured per-roll film rotations as a table, once there are enough rolls to key it correctly (#53)

## What changes if we do it

Film becomes georeferenceable without the caller doing their own calibration. #26 established that the corner mapping is **flight-relative but per-roll**, and measured two rolls:

| roll | year | rotation | margin |
|---|---|---|---|
| bc5282 | 1968 | 0 | 0.089 |
| bc83062 | 1983 | 90 | 0.135, 0.196, 0.152 (three legs) |

Shipping those as `inst/extdata/film_rotations.csv`, keyed on `film_roll` and consulted by `fly_georef()` before the refusal fires, would make those two rolls work out of the box and give later measurements somewhere to land.

**Decisions taken at the gate (user):**
- Key is **`film_roll` only** — a measured roll ships; nothing is inferred for an unmeasured one.
- **No roll is silently dropped**: ship a state for *every* film roll in the catalogue, and export
  a calibrator so any unshipped roll has a measured route out.
- Campaign: **~4 rolls per series × 5-year cell** (~27 cells, ~100 rolls, ~3,000 thumbnails).

Exploration facts that shape the plan:
- Cached centroids (`data-raw/.cache/centroids/`, 1.67M rows): **1,446,804 film frames on ~6,700
  rolls, 1963-2010s**, five series with distinct eras — `bc` 1960-89, `bcb` 1990-2005, `bcc`
  1965-2010, `bcf`/`bci` a handful. Focal 153 and 305 both common; BW and colour.
- The harness exists in `data-raw/georef_calibrate-corner_mapping.R`: `georef_at()` + `pair_r()`
  (section 2), `film_leg()` + premises (section 4). It moves into `R/` so the shipped table and a
  user's own calibration are produced by **one** implementation.
- Only thumbnails are public, so every verdict is for the **thumbnail** delivery; a full-res scan's
  orientation is unwitnessed and must be said so.
- The verdict is a composite with `fly_rectangles()`' vertex convention (vertex 1 at
  `bearing + 225`, pinned in `test-fly_camera_format.R`); the table is void if that changes.
- `test-fly_georef_digital.R` "mixed batch" asserts bc5282 231/232 are **refused**; shipping
  bc5282 flips that, so refusal needs an unmeasured-roll fixture.
- Reader pattern to copy: `fly_height_roll_table()` (`R/fly_footprint.R:280`). terra is in
  Suggests and stays there (guarded with `requireNamespace()`).

## Phase 1: Pre-register the rule (committed before any thumbnail is read)
- [x] Write into `findings.md` and commit:
  - **Leg**: ≥ 6 frames consecutive by `frame_number` on one roll, all with finite
    `footprint_bearing` from `fly_footprint()`, bearing spread ≤ 10°, not cardinal (median
    distance from a multiple of 90 ≥ 15°, the section-4 premise).
  - **Leg verdict**: `which.max` of mean adjacent-pair overlap correlation over rotations
    0/90/180/270 at 25 m, stretch-guard refusals excluded (a refusal is not a low score);
    margin = best − runner-up.
  - **Roll verdict (ships)**: ≥ 2 legs on different lines (bearings ≥ 30° apart; reverse legs
    count — they are the sharpest flight-relative vs geographic test) agree, each margin ≥ 0.05.
  - **Roll states**, never folded: `shipped` · `legs_disagree` · `one_leg_only` ·
    `margin_under_floor` · `thumbnails_unavailable` · `no_qualifying_leg` (from the cache: e.g.
    cardinal-only or short runs) · `not_sampled`.
  - **Sample**: eligibility (≥ 2 qualifying legs) decided from the cache alone; k = 4 per
    series × 5-year cell, fixed seed; bc5282 and bc83062 forced in.
  - **Positive control** first: digital must return 270 through the same code or nothing runs.

## Phase 2: Calibrator in the package — `fly_rotation_calibrate()`
- [ ] Tests first (`test-fly_rotation_calibrate.R`): leg finder on synthetic centroids (cardinal,
  short, gapped, turning, reverse legs); roll rule as a pure function over leg scores, every state
  reached; end-to-end with the scorer mocked (no network); refuses digital / non-POINT input;
  errors naming terra when absent.
- [ ] `R/fly_rotation_calibrate.R` — takes centroids (one or more rolls, catalogue columns), finds
  legs, fetches thumbnails via `fly_fetch()`, warps via `georef_one()` at four rotations, scores
  overlap, applies the rule. Returns one row per roll: `film_roll, rotation, state, legs,
  bearings, margins`. `rotation` is NA unless `state == "shipped"`, so it joins straight onto
  `photos_sf$rotation`. Internal helpers for leg finding and the rule, so the script and the test
  call the same ones. Example with `@examplesIf` network guard.

## Phase 3: Campaign script and the ledger
- [ ] `data-raw/georef_calibrate-film_rotations.R` — positive control → legs from cache → stratified
  draw → `fly_rotation_calibrate()` per roll (PSOCK, thumbnails cached under gitignored
  `data-raw/.cache/film_rotations/`) → write CSVs. `pkgload::load_all()`, seeded, refuses to write
  if any roll errored. `FLY_FILMROT_SMOKE=1` reruns #26's four legs and writes nothing.
- [ ] Ships:
  - `inst/extdata/film_rotations.csv` — shipped rolls: `film_roll, rotation, photo_year, series,
    focal_length, media, legs, bearings, frames, margins, method, measured`
  - `inst/extdata/film_rotations_excluded.csv` — **every other film roll in the catalogue**
    (~6,600 rows) with `state` and `retrieved`, so an unlisted roll can only mean "added to the
    catalogue after the snapshot"
  - `inst/extdata/film_rotations_legs.csv` — every scored leg with all four scores, so the test
    recomputes both tables from it rather than trusting them
- [ ] Run it; record the per-stratum tabulation (series, era, focal, media): does any stratum hold
  one value throughout, does any roll disagree with itself. Findings, not a wider rule.

## Phase 4: `fly_georef()` consults the table
- [ ] Tests first: table integrity (values in {0,90,180,270}, unique key, shipped ∩ excluded = ∅,
  shipped ∪ excluded = every film roll in the snapshot, both recomputed from `_legs.csv`);
  bc5282 231/232 now get the table's value; an unmeasured roll is still refused and its warning
  names its state and `fly_rotation_calibrate()`; user column overrides the table and `NA` falls
  through to it; the table never reaches a non-square frame; restore-the-bug on the lookup.
- [ ] `fly_film_rotation_table()` internal reader; lookup before the refusal; precedence user
  column > table > refusal; warning text driven by the ledger instead of the hard-coded
  "0 for bc5282 / 90 for bc83062".

## Phase 5: Documentation
- [ ] `fly_georef()` **Rotation** section; `fly_rotation_calibrate()` roxygen; `_pkgdown.yml`
  reference entry; `devtools::document()`
- [ ] `inst/notes/georeferencing.md`: new section — rule, sample, result by stratum, why the key is
  the roll, what it cannot witness (full-res scans, unsampled rolls, the vertex convention)
- [ ] `NEWS.md`; `CLAUDE.md` Key Decisions + Architecture lines
- [ ] `lintr::lint_package()`, `NOT_CRAN=true` full `devtools::test()`, `pkgdown::check_pkgdown()`

## Validation
- [ ] Tests pass
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion

