# Progress — Resolve inferred_format from the camera named in a frame's PAT-B file (#50)

## Session 2026-09-06

- Plan-mode exploration: read `R/fly_camera_format.R`, `R/fly_footprint.R`,
  `R/fly_fetch.R`, `inst/extdata/camera_formats.csv`, `inst/notes/camera-formats.md`,
  `data-raw/make_camera_formats.R`, `tests/testthat/setup.R`
- Measured two live PAT-B archives while planning — schemas recorded in `findings.md`.
  One of the issue's two reported data defects is not a defect
- Three forks put to the user and answered: new exported `fly_camera_patb()` for the
  network read; `footprint_basis` stays the media value; fix the label and the generator
- Created branch `50-resolve-inferred-format-from-patb-camera` off main (origin current)
- Scaffolded PWF baseline with approved phases
- Next: Phase 1 — measure the third schema and the population
