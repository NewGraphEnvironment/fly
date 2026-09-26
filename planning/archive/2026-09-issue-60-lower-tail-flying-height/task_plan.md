# Task: ~2,000 film frames carry a FLYING_HEIGHT far too small, and three remedies fit equally (#60)

fly#54 found the catalogue's `FLYING_HEIGHT` 10.764 times too large on 1,589 film frames and
repairs it. The same sweep found **1,963 film frames whose `FLYING_HEIGHT` is under half what
their `SCALE x FOCAL_LENGTH` implies** (1,962 of them terrain-sampled; the figures below are over
those), and about 7,400 under 0.9. Those are deliberately
**not** repaired: `fly_footprint(dem = )` marks them `height_source = "implausible"` and sizes
them from nominal scale.

They are not repaired because three different remedies each explain a comparable share and
the terrain cannot choose between them. Over MRDEM-30, of the 1,962:

| remedy | frames it brings inside [1/1.6, 1.6] | reading |
|---|---|---|
| x 10.764 | 726 | the fly#54 slip, run the other way |
| x 10 | 729 | a dropped digit in a height in feet — 609 m is 2,000 ft |
| x 2 | 799 (a different set of rolls) | a 153 mm lens catalogued as 305 — 519 of the 799 are catalogued at 305, but 280 are at 153, which this reading cannot explain |

Nor does 10.764 sort this tail the way it sorts the upper one: it scatters the 1,962 from
-0.70 to 5.38, leaving 130 still below the band and 1,106 above it, where the forward repair
puts all 1,589 at 0.80-1.32 with nothing between 6.69 and 10.01. Examples: `bc79122` 640 m at 1:20000 / 305 mm,
`bc7584`, `bc7675`, `bc81013`, `bc77032`; and at 0.500 `bc80001`, `bcc162`, `bc79209`.
`bc7280` reads 60 m and `bc5598` 2 m, which nothing explains.

The mirror of the x2 case is on the high side too: a mass centred on r = 2, where 209 of the
223 frames sampled beyond r 1.8 are catalogued at 153 mm — a 305 recorded as 153.

## Context

#54 repaired the ×10.764 slip and left 1,962 lower-tail film frames `"implausible"` because
×10.764, ×10 and ×2 each brought a comparable share into the band. Exploration showed the unit
of evidence is the **roll**, not the frame: the 1,962 frames sit on **42 rolls**, nearly every
roll carries **one** `flying_height` that is a round number of feet (609 m = 2,000 ft,
7,620 m = 25,000 ft), and the implied factor `k = (scale·f + elev) / H` is tight per roll
(IQR mostly <3%) but lands on 2.00 (bc79209, bc80001, bc5697, bc81026), near 10 (bc7675,
bc5655, bc7835) and on 2.2–9 for many rolls that none of the three remedies explains
(bc7717 2.33, bc79067 3.21, bc81013 8.69). The pooled table in the issue hid all of this.

User decision (plan gate): if evidence separates rolls, ship a **per-roll table keyed on
`film_roll` + recorded `flying_height`**, with an excluded list carrying a reason for every
roll left alone; `fly_footprint()` consults it. If nothing separates, ship measurement + note.

Three instruments, each independent of the fields in dispute, all public:
1. **Round-feet / per-roll factor** — from the sweep CSV and centroid cache.
2. **Adjacent-frame spacing** — cache (`data-raw/.cache/centroids/`, x/y/frame for 1.67M
   frames) gives air base B between frames one number apart; true along-track width ≈ B/(1−p),
   p ≈ 0.6 by design. Separates ×2 from ×10 and a wrong `scale` from a wrong height; cannot
   separate ×10 from ×10.764 (7.6%) — stated as a bound.
3. **Logbook scans** at `flight_log_url` (JPG pages, e.g. `thumbs/logbooks/1968/roll_pages/bc5282_1.jpg`)
   — read the stated altitude by eye for the 42 rolls.

## Phase 1: Instruments and their controls (data-raw only)
- [x] `data-raw/height_calibrate-lower_tail_rolls.R` (loads source via `pkgload::load_all()`, reads the #54 cache + sweep; no refetch of what is cached)
- [x] Per-roll table: n, distinct heights, H in ft, roundness of H·k in ft for k ∈ {1, 2, 10, 10.764}, median/IQR of k
- [x] Spacing: implied forward overlap per roll under nominal, reported and each remedy, using only frames adjacent by frame number (same rule as `fly_bearing()`), reusing `fly_bearing()`'s adjacency logic rather than re-deriving it
- [x] Spacing **positive controls before reading the lower tail**: random in-band set (expect ~60% under reported), #54 slipped set after ÷10.764 (known answer), near_upper r≈2 mass (expect nominal ~60%, DEM route wrong); print them first and stop if the controls fail
- [x] Fetch `flight_log_url` for the 42 rolls via WFS (`bcdata::filter`, not constructed paths); cache JPGs under gitignored `data-raw/.cache/logbooks/`; include 3–4 control rolls (random + #54 slipped) to establish what the logbook altitude means (ASL/AGL, ft/m)
- [x] Read logbook pages; record roll, page, stated altitude, units, reader note in a transcription CSV

## Phase 2: Verdict per roll
- [x] Classify each of the 42 rolls: factor supported by ≥2 independent instruments → correction row; otherwise excluded with reason (disagree / unreadable log / no adjacent frames / unexplained factor)
- [x] Ship `inst/extdata/flying_height_rolls.csv` (film_roll, flying_height, factor, cause, evidence columns per instrument) and `flying_height_rolls_excluded.csv` (film_roll, flying_height, reason)
- [x] Re-check against the full population: a roll+height key must match only the lower-tail frames it was measured on (count frames the key would touch in the cache vs frames measured)
- [x] If no roll reaches two instruments: skip Phase 3, go to Phase 4 as measurement-only

## Phase 3: `fly_footprint()` consults the table (tests first)
- [x] Failing tests in `tests/testthat/test-fly_footprint_height.R`: a fixture row on a tabled roll+height is sized from the corrected height with `height_source == "corrected_roll_table"`; same roll at a different height is untouched; an excluded roll stays `"implausible"`; the table-corrected frame is classified before the second DEM pass (assert on the grids, as #54's test does)
- [x] Table constants read by internal `fly_height_roll_table()` in `R/fly_footprint.R`; applied where `slipped` is computed (~line 1082), only to frames still `disputed` and only where the corrected r lands in band
- [x] Exclude the new class from `unusable` by name (CLAUDE.md gotcha: `unusable` is a residual)
- [x] Warning reports table-corrected count once; roxygen for `height_source` documents the new value
- [x] Test reads the shipped CSV and recomputes each row's factor from `flying_height_sweep.csv` so the table is checked against data, not trusted; restore-the-bug proof for each new assertion
- [x] `centroid_shapes()` sweep covers the new column path (tibble / bcdc_sf)

## Phase 4: Record
- [x] `inst/notes/terrain-correction.md`: replace "three remedies the terrain cannot tell apart" with the per-roll finding, each instrument's control result, and its bound (spacing cannot split 10 from 10.764)
- [x] CLAUDE.md Key Decisions entry; Architecture line for the new script/CSVs
- [x] Edit #60 body with the per-roll finding (not a comment); file follow-ups for unexplained rolls and for the near_upper 305-as-153 mass if not handled
- [x] NEWS.md + version bump as the final commit

## Validation

- [x] Tests pass (`devtools::test()`; `NOT_CRAN=true` for single-file reruns)
- [x] `/code-check` clean on each commit
- [x] PWF checkboxes match landed work
- [x] `/planning-archive` on completion

## Critical files
`R/fly_footprint.R` (lines ~200–230 constants, ~1060–1130 classification, ~1282 height_source),
`data-raw/height_calibrate-flying_height_slip.R` (cache + sweep pattern, PSOCK for remote reads),
`R/fly_bearing.R` (adjacency rule), `tests/testthat/setup.R` (`height_fixture()`),
`inst/extdata/flying_height_sweep.csv`, `inst/notes/terrain-correction.md`.
