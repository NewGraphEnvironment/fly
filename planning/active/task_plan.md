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
- [x] Write into `findings.md` and commit (6e25af5). Amended 2026-10-02 after the plan review and
  the control thumbnails, before any campaign thumbnail — six numbered amendments in
  `findings.md`. The rule as it now stands:
  - **Leg**: ≥ 6 frames joined by adjacent-by-number steps, each within 10° of the leg's first
    step and within ×1.5 of its median spacing; **any bearing** (cardinal legs qualify, measured);
    central 11 scored; at most 6 legs per roll, longest first.
  - **Leg verdict**: best mean pair correlation at 25 m over rotations 0/90/180/270 under
    `fly_georef()` defaults; **decisive** when a one-sided sign test (p ≤ 0.05) beats each scored
    rival; stretch-guard refusals do not compete.
  - **Roll states** (first match): `legs_disagree` · `shipped` (≥ 2 decisive legs agree, two
    **≥ 90°** apart) · `single_direction` · `one_decisive_leg` · `no_decisive_leg` ·
    `thumbnails_unavailable` · `legs_unscorable` · `no_qualifying_leg`; ledger adds
    `one_qualifying_leg`, `not_sampled` with a `measured` flag.
  - **Sample**: eligible = ≥ 2 qualifying legs ≥ 90° apart (from the cache); 4 per series ×
    5-year cell, `set.seed(53)`; bc5282 and bc83062 forced in.
  - **Controls**: digital 270 decisive; #26's existing legs reproduce their direction.

## Phase 2: Calibrator in the package — `fly_rotation_calibrate()`
- [x] Tests first (`test-fly_rotation_calibrate.R`): leg finder on synthetic centroids (cardinal,
  short, gapped, turning, reverse legs); roll rule as a pure function over leg scores, every state
  reached; end-to-end with the scorer mocked (no network); refuses digital / non-POINT input;
  errors naming terra when absent; every caller shape (plain, tibble, grouped, `bcdc_sf`); the
  scorer's statuses with GDAL mocked.
- [x] `R/fly_rotation_calibrate.R` — legs, scoring, rule; returns per roll `film_roll, rotation,
  state, legs_found, legs_qualifying` and list-columns `legs` (with `segment`) and `pairs`.

## Phase 3: Campaign script and the ledger
- [ ] `data-raw/georef_calibrate-film_rotations.R` — positive control → legs from cache → stratified
  draw → `fly_rotation_calibrate()` per roll (PSOCK, thumbnails cached under gitignored
  `data-raw/.cache/film_rotations/`) → write CSVs. `pkgload::load_all()`, seeded, refuses to write
  if any roll errored. `FLY_FILMROT_SMOKE=1` reruns #26's four legs and writes nothing.
- [ ] Ships:
  - `inst/extdata/film_rotations.csv` — shipped rolls: `film_roll, rotation, photo_year, series,
    focal_length, media, legs, bearings, frames, margins, method, measured`
  - `inst/extdata/film_rotations_excluded.csv` — **every other film roll in the catalogue**
    (`film_roll, measured, state, retrieved`), so an unlisted film roll can only mean "added to
    the catalogue after the snapshot"
  - `inst/extdata/film_rotations_legs.csv` and `_pairs.csv` — every leg and every scored pair, so
    the test recomputes verdicts and states rather than trusting them
  - `inst/extdata/film_rotations_population.csv` — rolls per series × bin (all / eligible /
    drawn), so the ledger's coverage is testable without the gitignored cache
- [ ] Run it; record the per-stratum tabulation (series, era, focal, media): does any stratum hold
  one value throughout, does any roll disagree with itself, do one roll's segments (missions)
  agree. Findings, not a wider rule.

## Phase 4: `fly_georef()` consults the table
- [ ] Leg-end bearing (plan review G1): `fly_bearing()` gives a line's last frame the azimuth of
  the turn to the next line. Refused today; with a table it would be written rotated onto the
  turn. File an issue, fix in `fly_bearing()` (forward step much longer than the backward one →
  take the backward bearing), test it.
- [ ] Tests first: table integrity (values in {0,90,180,270}, unique key, shipped ∩ excluded = ∅,
  coverage against `_population.csv`, verdicts and states recomputed from `_pairs.csv` /
  `_legs.csv`); bc5282 231/232 now get the table's value; an unmeasured roll is still refused and
  its warning names its state and `fly_rotation_calibrate()`; a rotated square frame that is not
  film is refused as such, not as "added after the snapshot"; user column overrides the table
  (tested with a value that differs from the table's) and `NA` falls through to it; the table
  never reaches a non-square frame; restore-the-bug on the lookup.
- [ ] Update `test-fly_georef.R` "a rotated film frame is refused" (network) and the override
  tests that set 0.
- [ ] `fly_film_rotation_table()` internal reader; lookup before the refusal; precedence user
  column > table > refusal (the scalar `rotation` argument never reaches a rotated frame);
  warning text driven by the ledger instead of the hard-coded "0 for bc5282 / 90 for bc83062".

## Phase 5: Documentation
- [ ] `fly_georef()` **Rotation** section; `fly_rotation_calibrate()` roxygen; `_pkgdown.yml`
  reference entry; `devtools::document()`
- [ ] `inst/notes/georeferencing.md`: new section — rule and amendments, sample, result by
  stratum and segment, why the key is the roll, what it cannot witness (full-res scans, mirrored
  scans, unsampled rolls, the vertex convention); correct #26's leg table (108-118 is not a leg,
  152-162 flies 251°) here, in `fly_georef()` roxygen, CLAUDE.md and the corner-mapping script
- [ ] README line on flight-line rotation; `bcdata` to Suggests (used in the example)
- [ ] `NEWS.md`; `CLAUDE.md` Key Decisions + Architecture lines
- [ ] `lintr::lint_package()`, `NOT_CRAN=true` full `devtools::test()`, `pkgdown::check_pkgdown()`

## Validation
- [ ] Tests pass
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion

