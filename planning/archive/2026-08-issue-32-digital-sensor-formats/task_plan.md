# Task: Establish sensor widths for digital frames and ship them as format defaults (#32)

## Problem

`fly_footprint()` sizes each frame from its `media` value and returns an empty geometry
for anything it cannot resolve (#30). That made the gap honest but did not close it:
every `Digital - Colour` frame still has no footprint — **223,667 of 1,670,471 frames
(13.4%)** provincially. The package is quietly film-only for anything after ~2010.

What was missing is one number per camera — the sensor width — which is not in
`AIMG_PHOTO_CENTROIDS_SP`. Exploration established it is recoverable from
`CAMERA_CALIBRATION_URL`, and turned up two things that change the shape of the work:
the catalogue's `SCALE` is not the true image scale for digital frames (sizing from it
gives 34% of true width), and digital sensors are not square (aspect 1.10 to 1.80).

Full plan: `~/.claude/plans/federated-mixing-wilkes.md`

## Phase 1: Camera format table

- [x] `data-raw/make_camera_formats.R` — fetch the 18 calibration zips, extract per vendor
- [x] `inst/extdata/camera_formats.csv` — calibration rows + focal-length fallback rows
- [x] Record source PDF and retrieval date per row (snapshot, not contract)
- [x] Tests: key uniqueness, key_type domain, source_pdf present on calibration rows
- [x] Drift guard: CSV key set matches what the generator discovers; prove the alarm fires

## Phase 2: QA on the transcribed numbers

- [x] B — `px x pitch == stated image size`, both axes, all rows
- [x] C — report focal vs catalogue `FOCAL_LENGTH` within 1 mm
- [x] D — plausibility bounds (width 80-170 mm, aspect 1.0-2.0, pitch 3-13 um)
- [x] E — independent second extraction diffed against the CSV (double entry)
- [x] F — implied ground elevation `H - (GSD/pitch)*focal` is a plausible BC elevation
- [x] Disposition: ship `dmc100039_2006` with its focal note; withhold `72914123_2019`

## Phase 3: Resolver and non-square footprints

- [x] `fly_camera_format()` internal resolver, keyed on `camera_calibration_url`
- [x] `fly_rectangles()` gains a second half-dimension and optional rotation
- [x] Rotate non-square footprints to the flight line via `fly_bearing()`
- [x] Tests: film output unchanged; rotation swaps bbox and preserves area
- [x] Restore the square-only version and confirm the non-square test goes red

## Phase 4: Wire into `fly_footprint()`

- [x] Sizing precedence: film scale / `px x GSD` / `width x AGL/focal` / unknown
- [x] `SCALE` never used for a digital frame
- [x] New `width_source` column; `footprint_basis` gains inferred values
- [x] `format_size` accepts width or width x height; roxygen example corrected
- [x] Warning text names refused vs inferred counts
- [x] Tests: `centroid_shapes()` sweep, zero-row, all-unresolved, downstream consumers

## Phase 5: Fixtures and verification

- [x] `inst/testdata/photo_centroids_digital.gpkg` — real frames, two aspect ratios
- [x] G — the two sizing routes agree within 2% (the issue's own acceptance criterion)
- [x] H — warn when implied AGL exceeds `flying_height`
- [x] Digital fixture in `setup.R` covering every resolver branch
- [x] Vignette, `NEWS.md`, correct the `CLAUDE.md` claim about digital frames in the AOI

## Validation

- [x] Tests pass
- [x] `/code-check` clean on each commit
- [x] PWF checkboxes match landed work
- [x] `/planning-archive` on completion
