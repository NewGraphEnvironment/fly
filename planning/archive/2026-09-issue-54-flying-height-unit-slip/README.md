## Outcome

fly#54 reported two 2003 film frames that `fly_footprint(dem = )` drew 110 km across. Nothing
in fly was wrong: the catalogue's `FLYING_HEIGHT` is 3.28084² = 10.764 times too large on
1,589 film frames across 13 rolls (1974-2005), a feet-to-metres conversion applied the wrong
way round. 0.12.0 holds `flying_height - terrain` against `scale x focal_length` after the
first DEM pass: inside [1/1.6, 1.6] the height is used, outside it dividing by the factor is
tried and used where that lands inside, and otherwise the frame falls back to nominal scale.
A new `height_source` column records which (`reported` / `corrected_unit_slip` /
`implausible`), and the caller's `flying_height` is never overwritten. The issue proposed a
plausibility bound on `height_agl`; that could not have worked — slipped roll `bc78065`
reads 4,115 m, a legal altitude — so the check had to be relative. The user's call at the
plan gate was repair-and-flag rather than refuse, and both checks rather than one. The
durable write-up is the "held against the scale" section of
`inst/notes/terrain-correction.md`; fly keeps its findings in `inst/notes/`, so no
`research/` file was created.

Three follow-ups were filed rather than absorbed: #58 (what a partially DEM-covered footprint
costs — split out at the user's request), #59 (`fly_dem_sample()` off a `/vsicurl/` DEM took
583 s for two frames), #60 (~2,000 frames whose height is far too *small*, which three
remedies fit equally and none is applied). A defect note for the data custodian is drafted in
`draft_databc_note.md` and has **not** been sent.

## Measurement

- **Population:** all 1,670,471 centroids pulled by year; equal to the catalogue's own
  `numberMatched`. 1,437,147 usable film frames; 223,667 digital, none slipped (highest
  7,513 m).
- **Slipped:** 1,589 frames, 13 rolls, identified by `flying_height / (scale x focal)` > 9.
  r as published 10.01-15.83; divided by 10.764, **0.80-1.32, median 1.05**; read as plain
  feet, 3.02-4.71 and 0 of 1,589 in the band. Nothing between r 6.69 and 10.01.
- **Ordinary frames:** random 2,500 — median 1.03, 99.2% inside the band; 98.7% of all film
  population-weighted. So at most ~1.2% of film frames move from DEM sizing to nominal.
- **What set the upper edge:** a mass centred on r = 2, 209 of 223 sampled frames catalogued
  at 153 mm — a 305 mm lens recorded as 153, which the DEM route drew at twice its width.
- **Per frame, not per roll:** 1,208 clean frames share a slipped roll. Repair fires on 0 of
  2,733 other sampled out-of-band frames.
- **Real frames, end to end:** eight `bcc03006` frames 8.2-9.2 km wide and flagged, where the
  issue measured 110 km; eight `bcc03010` frames `identical()` to `main`.
- **What changed because of it:** the fix is a ratio check, not the bound the issue proposed;
  the ceiling moved from `height_agl` to `flying_height` so it is judged before a DEM window
  is built; the lower-tail "mirror" slip was measured and deliberately left alone.

Wrong turns kept in `findings.md` and the reviews: the "4.5 to 17.7 km" feet figure came from
a 150-frame exploration sample and did not survive the shipped data (0.82-22.7 km); a
paragraph describing the lower tail as "0.63 past 3 ... behind a gap six wide" was an
impression, not a measurement; `mclapply()` over a remote DEM aborted all 104 chunks while
its wrapper exited 0; the first end-to-end check never finished because of #59. The plan
review's two blockers (the residual `unusable` class; classifying before the second pass) and
`/code-check`'s two code regressions are in `review-1.md` and `review-round[1-3].md` — round 3
ended by enumerating 94 claims, not by a quiet round.

## Evidence

`inst/extdata/flying_height_sweep.csv` and `flying_height_population.csv` (shipped, read by
`tests/testthat/test-fly_footprint_height.R`); `data-raw/height_calibrate-flying_height_slip.R`
reproduces them and prints a producer line per quoted figure. Run logs are under the
gitignored `data-raw/.cache/logs/stage4*.log` and are not committed — the script is the record.

Closed by: PR for branch `54-fly-footprint-dem-returned-a-110-km-foot` (release commit 68bbc58)
