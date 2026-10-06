# Task: Three infrared roll-heights carry a right height beside a wrong scale (#91)

fly#89 sized infrared film as the 9-inch negative, so IR frames now reach the #54 `flying_height` check. 56 of the 3,825 IR frames fall outside `fly_height_ratio_band()`. They sit on three roll-heights. On every one of them, adjacent-frame spacing in `inst/extdata/infrared_film_frames.csv` fits the **reported** height and rejects nominal scale. The figures are printed by `data-raw/format_measure-infrared_film.R` and recomputed by `test-fly_footprint_infrared.R`:

| roll | frames | scale | flying_height | focal | ratio above sea level | r | overlap at nominal | overlap at reported |
|---|---|---|---|---|---|---|---|---|
| `bc5312` | 17 | 1:30000 | 3353 | 153 | 0.731 | 0.47 | 0.805 | 0.594 |
| `bci12` | 14 | 1:15840 | 3682 | 305 | 0.762 | 0.51 | 0.807 | 0.620 |
| `bci9` | 25 | 1:8000 | 5944 | 305 | 2.436 | 2.03 | 0.228 | 0.620 |

The window is 0.557 to 0.780. The logbook pages write each catalogued height: 11.0, 12.08 and 19.5 thousand feet. So each roll-height carries a right height beside a wrong `scale`, the defect fly#60 and fly#72 tabled for BW and colour.

Today all 56 are drawn at nominal scale, with or without a DEM. That is about 2x (`bc5312`, `bci12`) or 0.5x (`bci9`) the width the spacing supports. With a DEM the #54 check sends them to nominal; without one every film frame is nominal.

## Context

fly#89 sized infrared film as the 9-inch negative, which brought the IR frames into the #54
`flying_height` check. 56 of them fall outside `fly_height_ratio_band()`, on three
roll-heights: `bc5312` 3353 m 1:30000 153 mm (17 frames), `bci12` 3682 m 1:15840 305 mm (14)
and `bci9` 5944 m 1:8000 305 mm (25). Spacing fits the reported height and rejects nominal on
all three. The logbooks write the catalogued heights (11.0, 12.08 and 19.5 thousand feet). A
DEM caller therefore draws these frames at nominal scale, about 2x or 0.5x the width the
spacing supports.

What exploration established:

- **None of the three is reachable today.** `data-raw/height_calibrate-lower_tail_rolls.R`
  builds every set from `inst/extdata/flying_height_sweep.csv`. That sweep is BW/colour only,
  pinned there by #89, so no IR frame is in it.
- **No logbook height rows for these rolls.** `data-raw/flying_height_logbooks.csv` has none
  for them. `data-raw/infrared_film_logbooks.csv` transcribed the camera only. The heights in
  the issue were read by a #89 reviewer who could see the catalogue values. The six page
  images are cached under `data-raw/.cache/infrared_film/logbooks/`.
- **`inst/extdata/infrared_film_frames.csv` is a census.** It holds every IR frame, with
  `elev` (mean under the nominal 9-inch square, the sweep's method), `base` (fly#60's
  air-base rule) and `height_class`. Each of the three keys is entirely `outside_band`; the
  in-band frames on these rolls carry other keys.
- **`fly_footprint()` needs no code change.** The table lookup (`R/fly_footprint.R:1207-1234`)
  keys on roll, height, lens and scale, and does not read `tail`. A factor-1 row is applied to
  any out-of-band frame with `r_reported > 0`. As for every existing row, this changes only
  the DEM route; with no DEM, film is nominal.
- **Strata.** `bci9` has a ratio above sea level of 2.436, inside `near_upper`. `bc5312`
  (0.731) and `bci12` (0.762) are in band above sea level and leave it only through terrain.
- **Decisions taken at this gate:**
  - The new tail is called **`terrain`**.
  - Scope is **IR only**. 12 of the 2,500 BW/colour random frames are terrain-driven
    out-of-band too. They get a reported line and a follow-up issue.

## Phase 1: Pre-register the rule (committed before any IR roll-height is classified)

- [x] Write the populations into `findings.md`:
  - **IR census.** The `outside_band` frames of `infrared_film_frames.csv`.
  - **`near_upper`.** Ratio above sea level in (2, 3] goes to `near_upper`. Today that is
    `bci9`.
  - **`terrain`.** Ratio above sea level inside the band, ratio above ground outside it.
    Today that is `bc5312` and `bci12`.
  - **Anything else.** Any other combination stops the script rather than being assigned.
- [x] Write the rule into `findings.md`. It is #72's `near_upper` rule, unchanged, applied to
  both sets:
  - the logbook covers at least half the frames, and at least 90% of those name factor 1;
  - no legible logbook focal length contradicts the catalogue's;
  - spacing under the logbook height fits the window **and** spacing at nominal does not;
  - no legible logbook scale equals the catalogue's;
  - the sibling witness is not applied, because the scale is in dispute, not the height.
- [x] Audit every rule step for a BW/colour assumption and record a verdict for each:
  - **9-inch `FORMAT_M`:** settled for IR by #89.
  - **Window:** comes from BW/colour random frames. #89's W1 already holds 27 of the 32 IR
    rolls to it.
  - **Focal tolerance:** 6" and 12" are written on these pages.
  - **Scale regex:** a scale on `bci9` sheet 2 covers finals 101-128, not frames 12-36.
  - **Logbook height units.**
  - **Key formatting.**
  - **Disjoint-strata assertion:** `terrain` is disjoint by construction.

  Any amendment is labelled as such.
- [x] Record what each outcome would mean, including a refusal: a row that fails ships in
  `_excluded.csv` with the reason that fired.

## Phase 2: Blind logbook transcription

- [x] Spawn one transcriber (general-purpose, told not to spawn). It gets the six cached page
  images and the `flying_height_logbooks.csv` schema, and nothing about the catalogue's
  height, scale or lens. It is told not to read the issue, `inst/extdata/`, `planning/` or
  the notes.
- [x] Append its rows to `data-raw/flying_height_logbooks.csv`, with `control = FALSE`. Check
  the frame ranges against the roll's catalogue frame numbers before using them.
- [x] Record in `findings.md` that this reader was blind and that #89's reviewer was not.
  List any disagreement between the two readings.

## Phase 3: Generator

- [ ] In `height_calibrate-lower_tail_rolls.R`, after the existing controls:
  - read the IR census;
  - recompute `base` from `f1` and assert it equals the shipped `base` (to 0.1 m);
  - derive `f_m`, `nominal_agl`, `r`, `p_nominal` and `p_reported` as Stage 2 does;
  - split into the two sets, and stop on any frame neither set takes.
- [ ] Logbook fetching:
  - add the IR rolls to `want`, so `fetch_logbooks()` caches their pages under
    `data-raw/.cache/logbooks/`;
  - `near_v <- settle(rbind(near, ir_near), ...)`;
  - add `terr_v <- settle(ir_terrain, named = 1, tail = "terrain")`.
- [ ] Stage 5 changes:
  - `nu_row` becomes `tail %in% c("near_upper", "terrain")`, covering both the
    spacing-rejects-nominal condition and the scale veto;
  - the sibling skip and the "nominal scale still applies" suffix cover `terrain`;
  - the frame-count reconciliation and the disjoint-key `stopifnot` include the IR frames;
  - the comment on disjoint tails explains why `terrain` is disjoint.
- [ ] Print the BW/colour random-sample count of terrain-driven out-of-band frames, as a
  reported line, not a gate.
- [ ] Update the header comment (fly#91 paragraph), then run the script and regenerate
  `flying_height_rolls.csv` and `_excluded.csv`.
- [ ] Diff the CSVs. Only IR rows may appear, and every BW/colour row must be byte-identical.
- [ ] Commit the log under `data-raw/logs/` per convention.

## Phase 4: Tests

- [ ] `test-fly_footprint_height_rolls.R`:
  - the tail sets become four values;
  - the recompute builds `near_upper` as sweep plus IR, and `terrain` from
    `infrared_film_frames.csv`;
  - a `terrain` scale-wrong row must sit below `band[1]`;
  - pin the three IR rows: key, factor 1, `scale_wrong`, logbook witness, and `height_m`
    equal to the logbook's feet times 0.3048.
- [ ] Add a `fly_footprint()` test. Fixture frames keyed to the three IR rows, over a flat
  DEM, must return `height_source == "corrected_roll_table"` and a width from `height_m`,
  not nominal. A control frame differing only in scale must stay nominal.
- [ ] `test-fly_footprint_infrared.R`: update the fly#91 comment, and assert that the three
  out-of-band keys are now tabled.
- [ ] Prove the guards fire, in a scratch copy:
  - drop `terrain` from `nu_row` and check spacing rejection still holds;
  - remove one IR row from the table and check the fixture test fails;
  - mislabel the tail and check the set test fails.
- [ ] Run `devtools::test()` and `lintr`.

## Phase 5: Docs

- [ ] `R/fly_footprint.R`: add `terrain` to the roll-table comment block, and to roxygen
  wherever the tails are listed. Then run `devtools::document()`.
- [ ] `inst/notes/terrain-correction.md`: add a fly#91 subsection. Its table is built from the
  producer lines, with the BW/colour terrain-driven population stated as unmeasured.
- [ ] `inst/notes/camera-formats.md`: replace "Until fly#91 tables them..." with the measured
  outcome.
- [ ] `CLAUDE.md`: update the #89 Key Decision bullet, and the Architecture line for the
  generator to say it now reads the IR census.

## Phase 6: Close-out

- [ ] File the follow-up issue for the BW/colour terrain-driven stratum, with the count and
  the method. Link it from the note.
- [ ] `/code-check` before each commit, then `/planning-archive` and `/gh-pr-push`.

## Validation

- [ ] Tests pass
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion

## Verification

- Generator run: the controls still pass (90/105/14 split, logbook controls, sibling
  controls), the reconciliation `stopifnot`s hold, and the CSV diff contains IR rows only.
- `Rscript -e 'devtools::test()'`, with a FAIL/PASS grep.
- The fixture test shows the width change on the DEM route.
