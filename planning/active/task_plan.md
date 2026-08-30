# Task: Georeference digital frames — the corner mapping assumes a square, axis-aligned footprint (#38)

## Context

fly#32 gave digital frames footprints. `fly_georef()` cannot use them: it excludes every
non-square footprint with a warning (`R/fly_georef.R:135-143`), so the whole post-2010
catalogue is sizeable but not georeferenceable.

`georef_one()` (`R/fly_georef.R:223`) maps image corners onto footprint corners
positionally, then cyclically shifts that mapping by `bearing_to_rotation()` — a
90-degree quantization of the flight bearing, fitted against north-up 9x9 film negatives.
A digital footprint breaks it twice: the ring is **already** rotated onto the flight line
by `fly_rectangles()`, so the bearing would be counted a second time; and on a 1.56:1
rectangle a wrong-by-90 mapping puts a portrait image in a landscape quad.

The issue defers rather than guesses because "nothing in the test suite looks at pixels,
so a wrong warp would pass every assertion." That is true of the *last* bit only. Most of
the answer is derivable from geometry the repo already has, and this plan separates the
two so the imagery step has one question to answer instead of eight.

### What exploration established (measured this session)

**The ring order is in the rectangle's own frame.** `fly_rectangles()`
(`R/fly_footprint.R:124`) emits `v1=(-hc,-ha) rear-left, v2=(hc,-ha) rear-right,
v3=(hc,ha) front-right, v4=(-hc,ha) front-left`, where local `+y` is the heading and
local `+x` is 90 degrees clockwise of it. Bearing rotation is applied only when
`hc != ha` and the bearing is finite. So the ring means the same thing whether or not it
was rotated — which is why one constant can serve both the rotated and the
`axis_aligned_no_bearing` non-square cases.

**Rotation 90/270 are the aspect-consistent candidates, not 0/180.** `georef_one()` builds
`fp_corners = [front-left, front-right, rear-right, rear-left]` and maps pixel
`[TL, TR, BR, BL]` onto it. Rotations 0 and 180 send image *width* to the **cross**-track
edge; 90 and 270 send image *width* to the **along**-track edge. Both bundled digital
cameras deliver **portrait** thumbnails whose long axis is the image *height*:

| camera | thumbnail | sensor px (cross x along) | footprint (m) | ratio |
|---|---|---|---|---|
| Leica DMC II (`121201_2011`) | 884 x 972 | 15552 x 14144 | 4666 x 4243 | 1.100 |
| UltraCam Eagle M3 (`20814295_2018`) | 1063 x 1654 | 26460 x 17004 | 3175 x 2040 | 1.556 |

Image height is the long axis and equals `px_cross`, the axis the format table assumes is
across-track. So the image's long axis must land on the footprint's long edge, which
selects {90, 270} and rejects {0, 180}. **That is settled by geometry — no imagery.**

**One bit remains, and it needs pixels.** 90 vs 270 differ by 180 degrees about the
footprint centre; a rectangle is symmetric under that, so no geometric invariant can tell
them apart.

**A second, larger assumption rides along.** `data-raw/make_camera_formats.R:211,241,261`
sets `px_cross = max(dims)`, `px_along = min(dims)` — it *assumes* the long sensor axis is
across-track. `test-fly_camera_format.R:119` asserts the footprint follows that assumption,
not that the assumption is true. If it is wrong, the ground quad itself is rotated 90
degrees and **no corner mapping repairs it** — #32's footprints would be wrong. The same
orthophoto QA settles it, so this plan checks it explicitly rather than inheriting it.

**The bundled fixture can reach the failure mode, unevenly.** A wrong-by-90 mapping
distorts by `ratio^2`: 2.42x on the UltraCam, only 1.21x on the DMC II. Frames 19-24 are
the diagnostic ones; that gets stated in the test rather than left to luck.

### Decisions taken

- **The orthophoto QA lives in the private catalogue repo.** Its pixels are "Access Only"
  and licence-restricted, so they never enter fly as fixtures. fly receives the measured
  constant, a note, and invariants that need no reference imagery. No fly file names that
  repo, its endpoint or its database.
- **A user `rotation` column keeps overriding, for square and non-square alike.**
  Consistent with today's documented behaviour. The carried-column hazard — a film-era
  rotation column applied to a digital batch — gets documented, not guarded.

---

## Phase 1: Make the corner mapping testable without GDAL

- [x] Extract GCP construction from `georef_one()` into a pure internal
      `fly_georef_gcps(ncol_px, nrow_px, coords, rotation)` returning the pixel->ground
      correspondence. No GDAL, no file I/O, no `sf::gdal_utils()`.
- [x] Rewrite `georef_one()` to call it; everything else in that function unchanged.
- [x] `tests/testthat/test-fly_georef_gcps.R`: film GCP output identical at all four
      rotations to the pre-change implementation, pulled with
      `git show HEAD:R/fly_georef.R` (not reconstructed from memory).
- [x] Put the helper at the top of `R/fly_georef.R` or its own file — never between a
      roxygen block and the function it documents (the fly#30 `@export` rebind).

**Verify:** `devtools::test()` green; the film-parity test asserts equality against bytes
pulled from git, and fails if the extraction changed any coordinate.

## Phase 2: Pin the aspect invariant (the half needing no imagery)

- [x] Assert: the GCP mapping sends the image's long pixel axis onto the footprint's long
      ground edge. Concretely, ground distance between the width-pair GCPs divided by
      ground distance between the height-pair GCPs equals `ncol_px / nrow_px`.
- [x] Run it over the bundled digital frames, **both** cameras, from
      `inst/testdata/photo_centroids_digital.gpkg` via `digital_fixture()` /
      `tests/testthat/setup.R`.
- [x] Assert the invariant **fails** at the rotations it must reject. A test that only
      ever passes is decoration.
- [x] State in a comment that the invariant is vacuous on square film (ratio 1) and weak
      on the DMC II (1.21x) — the UltraCam frames are what makes it discriminating.

**Verify:** the invariant passes for {90, 270} and fails for {0, 180}, both asserted; and
the DMC II / UltraCam distortion factors are recorded so a future fixture change that
drops the UltraCam is visible.

## Phase 3: Establish the constant  [DONE — re-scoped by measurement]

The plan assumed licence-restricted orthophotos were the only route. They are not, and
the route that works is better: the catalogue publishes per-frame exterior orientation
through `patb_georef_url`, and consecutive frames overlap enough to check each other.
All three measurements below use public data, so the derivation lives in fly.

- [x] (a) Is the long sensor axis actually across-track? Guarded rather than assumed —
      `parse_vexcel()` reads the manufacturer's own `long track`/`cross track` labels,
      and Phase 4's isotropy guard refuses any frame whose delivered aspect disagrees
      with its footprint
- [x] (b) Which rotation is correct? **270**, for both cameras
- [x] Exterior orientation from PATB: the Eagle's mount is rigid to 0.18 deg (MAD 0.47,
      n=6839, 32 compass bins), reflection excluded at 14.1% against 98.7%
- [x] Adjacent-frame overlap correlation — needs no reference imagery at all:
      270 wins on both cameras (+0.616 / +0.659 against <= +0.43)
- [x] FWA lake darkness as an outside opinion: 270 darkest on both frames tested,
      water 442 m and 1684 m off-centre so the test could discriminate
- [x] Recorded per camera. They agree, so the constant is global — **not** a
      `camera_formats.csv` column
- [x] `data-raw/georef_calibrate-corner_mapping.R` reproduces all three
- [x] No imagery, licence-restricted or otherwise, enters the package

## Phase 4: Land the constant and remove the exclusion

- [ ] `fly_georef()` applies the constant to non-square footprints and does **not** apply
      `bearing_to_rotation()` to them — the ring already carries the bearing.
- [ ] Branch on `fly_is_square()` (`R/fly_footprint.R:165`), computed for every row before
      the per-row loop. Never on `half_cross`/`half_along`, which are NA by construction
      until a sizing route fills them (CLAUDE.md, fly#32's three-round trap).
- [ ] Keep the `rotation`-column override for non-square frames; document the
      carried-column hazard in `@param rotation`.
- [ ] Delete the exclusion block (`R/fly_georef.R:122-143`) and the `rotated[fp_idx[1]]`
      skip (`:190`). Keep `fly_is_square()` itself — `test-fly_camera_format.R:266` uses it.
- [ ] Keep the empty-geometry skip (`:195`) and `fly_warn_unsized()` (`:120`) untouched;
      they cover a different exclusion.
- [ ] Rewrite the **Rotation** `@details` section (`:38-65`), which currently documents
      only the film scheme, and the `@param rotation` text that says `"auto"` applies
      everywhere.

**Verify:** digital frames produce GeoTIFFs; a mixed film+digital batch gives film the
bearing rotation and digital the constant, asserted per row; no non-square warning fires;
`test-fly_georef.R`'s existing eight tests still pass unchanged.

## Phase 5: Notes, docs, release

- [ ] `inst/notes/georeferencing.md`, companion to `terrain-correction.md` and
      `camera-formats.md`: the ring-order contract, why the bearing must not be applied
      twice, what the QA measured and against what, and what the aspect invariant can and
      cannot catch. Ground truth referenced obliquely — no repo, endpoint or database named.
- [ ] Update CLAUDE.md: the Key Decisions entry for #30 and the NEWS line
      "`fly_georef()` excludes rotated footprints" are both now stale.
- [ ] `devtools::document()` — **read its output**. `Writing '<unexpected>.Rd'` or a
      falling `grep -c "^export(" NAMESPACE` is the fly#30 rebind.
- [ ] `lintr::lint_package()` against the `HEAD` baseline, not against zero.
- [ ] NEWS entry; version 0.6.0 -> 0.7.0 as the **final** commit of the branch.

## Validation

- [ ] `devtools::test()` passes
- [ ] `/code-check` clean on each commit
- [ ] No fly file names the private ortho repo, its endpoint, or its database:
      `git diff main --stat` reviewed, plus a grep of the branch diff for the repo name
- [x] Restore-the-bug check on the Phase 2 invariant: it goes red against the rejected
      rotations, patched in **both** `asNamespace("fly")` and
      `as.environment("package:fly")`, with a printed value proving the patch took
- [ ] PWF checkboxes match landed work; `/planning-archive` on completion

## Open, deliberately not decided yet

- **One constant or one per camera** — Phase 3 measures it. If per-camera, it belongs in
  `camera_formats.csv` beside the sensor dimensions, not hardcoded in `fly_georef()`.
- **What happens if Phase 3(a) refutes the across-track assumption.** Then #32's
  footprints are rotated 90 degrees wrong and that is a bigger issue than this one; stop
  and reopen #32 rather than compensating for it in the corner mapping.
- **fly#37** (`fly_footprint()` handed its own output) is untouched by this work.
