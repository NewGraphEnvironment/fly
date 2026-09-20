# Task: fly_dem_sample() over a /vsicurl/ DEM took 583 s for two frames (#59)

`fly_footprint(dem = )` documents MRDEM-30 over `/vsicurl/` as "a good default" that needs
no download. Measured 2026-09-18 while verifying fly#54, **two ordinary 1:15000 frames took
583 s** that way — and 1.3 s for eight frames against a local crop of the same raster.
`Rprof` puts all of it in `terra::extract()` inside `fly_dem_sample()`, and almost none of it
is CPU (61 s sampled of 583 s wall), so it is waiting on the network.

The issue is explicit that 583 s is an **upper bound** — that run shared bandwidth with the
fly#54 calibration sweep, six workers against the same S3 object — and that the first step is
to time the forms alone. Plan-mode measurement did that; the numbers are in `findings.md`.

## Phase 1: Close the remaining measurements

- [x] Count HTTP requests per form with `CPL_CURL_VERBOSE=YES`, so the finding is "N requests
      against M" and not only a wall-clock ratio
- [x] Confirm `terra::align(ext, dem)` is unchanged by cropping, and that `terra::crop()` to an
      extent overhanging the DEM returns only the overlap — so beyond-extent ground still yields
      **no row**, not an NA row, which is wrong form 1 in the note
- [x] Establish what the current code does when a frame returns **zero** cells: `split()` drops
      that ID, so `per_frame` is shorter than `nrow(in_dem)` and `elev[ok] <- vapply(...)`
      misaligns. Determine whether that is reachable today *before* changing anything near it —
      if it is, it is a separate defect and gets its own issue rather than being folded in
- [x] Record each number in `findings.md` with its date and the link state

## Phase 2: Read through a per-frame window

- [x] Restructure `fly_dem_sample()` so numerator and denominator share **one per-frame loop** —
      the denominator loop at `R/fly_footprint.R:265-270` already iterates per frame, and the
      elevation/numerator work moves into it: crop `dem` to
      `terra::ext(fly_dem_grid(dem, in_dem[i, ]))`, extract the frame against that window, take
      `mean(na.rm = TRUE)` and `sum(!is.na(...))` from the same values
- [x] Guard the frame that does not overlap the DEM at all — `terra::crop()` errors on
      non-overlapping extents where `terra::extract()` returned an empty result. That frame must
      still come back `elev = NA`, `got = 0`
- [x] Keep `fly_dem_grid()` as the single definition of a frame's window, so the
      bounded-allocation invariant has one place to be asserted and the crop cannot drift from
      the counting grid
- [x] Leave the call sites at `R/fly_footprint.R:916` and `:972` untouched — internal only, no
      signature change, so every caller forwarding `dem` gets it for free
- [ ] `/code-check` before the commit

## Phase 3: Tests that can actually fail, then say what was measured

- [x] **Coverage is unchanged.** Pin `dem_coverage`, `height_agl` and `footprint_terrain` from
      the bundled fixture *before* the change and assert the new code reproduces them exactly
- [x] **Allocation stays bounded.** Extend the mocked-`fly_dem_grid` test at
      `tests/testthat/test-fly_footprint.R:579` to bound the **cropped window** too, and prove it
      fires — restore a union-extent crop and watch it go red
- [x] Re-run the note's axes: 30 m and 900 m resolution, anisotropic cells, a geographic CRS
      (`test-fly_footprint.R:464`), a truncating extent (`:402`), frames far apart (`:579`)
- [x] `test-fly_footprint_height.R:113` — no DEM window is built from a height that fails the
      fly#54 checks. The refactor moves where windows are built, so this is the test most likely
      to be silently weakened
- [x] Full suite green; `NOT_CRAN=true` on any single-file re-run
- [x] New section in `inst/notes/terrain-correction.md` — why the read is windowed, the request
      counts and timings, why cropping was chosen over `fun = mean`, why the union is refused
- [x] Roxygen at `R/fly_footprint.R:598-626`: say the DEM is read through per-frame windows so a
      remote COG is practical, and keep the existing `sqrt(2)` buffer advice
- [x] Reconcile the issue body — the "extracted four times" claim and the 583 s bandwidth
      confound — per `feature-workflow.md`, bodies get edited, not appended to
- [ ] NEWS entry and version bump as the **final** commit of the branch

## Validation

- [ ] Tests pass
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
