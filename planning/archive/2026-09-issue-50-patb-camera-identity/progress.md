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
- Phase 1: measured the whole population (41,249 frames, 7 archives, 3 schemas) against
  the live catalogue; issue body rewritten; plan review folded in (22 findings)
- Phase 2: camera label read from the serial, generator fixed, invariant pinned. Commit
  `64adb17`
- Phase 3: serial and name resolution in `fly_camera_format()`, `patb_gsd` and the
  generalised refusal carry in `fly_footprint()`. Commit `93dcf33`
- Phase 4: `fly_camera_patb()`, offline fixtures for all three schemas plus the real 404
  body, `fly_fetch()` zero-byte guard
- Phase 5: notes, roxygen, vignette, CLAUDE.md decision, NEWS, version 0.10.0; follow-up
  issue fly#54 filed for the DEM film blow-up
- Live validation: 372 of 636 sampled frames sized, at exactly the predicted widths —
  5,193 m Xp, 4,329 m X, 5,002 m Eagle; the rest refused with a named reason
- `/code-check` ran 3 rounds. Round 2 found two real correctness bugs (an NA `match()`
  handing a frame another's camera, and a tied digit run resolving by position); both
  fixed and each proven by restoring the defect
- Next: archive the PWF and open the PR
