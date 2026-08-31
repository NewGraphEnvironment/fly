# Findings — Georeference digital frames: the corner mapping assumes a square, axis-aligned footprint (#38)

## Issue context

## Problem

`fly_georef()` excludes non-square footprints, so the digital frames #32 just gave
footprints to cannot be georeferenced.

`georef_one()` maps image corners onto footprint corners **positionally**
(`R/fly_georef.R`, `# fly_footprint builds: BL, BR, TR, TL, BL`) and then shifts that
mapping by `bearing_to_rotation()`, a 90-degree quantization of the flight bearing. That
scheme was calibrated against north-up 9x9 negatives, where the footprint is square and
axis-aligned.

A digital footprint breaks both assumptions:

- It is **already rotated** onto the flight line by `fly_footprint()`, so its ring
  carries the bearing. Applying `bearing_to_rotation()` on top counts it twice.
- It is **not square** — 1.10:1 to 1.80:1. On a square, a wrong-by-90 corner mapping is
  harmless. On a 1.76:1 rectangle it maps a landscape image onto a portrait quad and the
  warp squashes it.

## Why it was deferred rather than guessed

The right corner mapping for a pre-rotated rectangle depends on camera mounting relative
to flight direction. That is precisely what `bearing_to_rotation()` was empirically
fitted to, and it cannot be re-derived without imagery to check the result against —
nothing in the test suite looks at pixels, so a wrong warp would pass every assertion.

Digital frames had no footprint at all before #32, so excluding them is the same
coverage as before rather than a regression. It is now explicit and warned about instead
of silent.

## Proposed approach

1. Fetch a handful of real digital thumbnails via `fly_fetch()` for frames whose
   footprint is known — the bundled `inst/testdata/photo_centroids_digital.gpkg` has
   `thumbnail_image_url` populated for two cameras.
2. Establish the correct pixel-corner to footprint-corner mapping for a footprint
   already rotated onto its flight line. Likely a constant, since the rotation is
   already in the ring — but that must be measured, not assumed.
3. Check the result **visually**, and pin whatever invariant the check establishes
   (a landscape image must not land in a portrait quad; a known ground feature must
   land where it belongs).
4. Remove the exclusion in `fly_georef()` and the `fly_is_square()` guard it uses.

## Value

**If we do it:** the whole post-2010 catalogue becomes georeferenceable, not just
sizeable.

**If we never do:** digital frames get footprints, coverage and selection but no
georeferenced output — visibly excluded with a warning rather than silently wrong, which
is the important half.

Follows #32


---

## Measurements taken 2026-08-30 during plan-mode exploration

### The ring order is in the rectangle's own frame

`fly_rectangles()` (`R/fly_footprint.R:124`) emits, in local coordinates:

| vertex | local | flight-relative |
|---|---|---|
| `coords[1]` | `(-hc, -ha)` | rear-left |
| `coords[2]` | `( hc, -ha)` | rear-right |
| `coords[3]` | `( hc,  ha)` | front-right |
| `coords[4]` | `(-hc,  ha)` | front-left |

Local `+y` is the heading, local `+x` is 90 degrees clockwise of it. Confirmed by
expanding the rotation: `rot <- matrix(c(cos, sin, -sin, cos), nrow = 2)` fills
column-wise, so `xy %*% rot` sends row vector `(0, 1)` to `(sin b, cos b)` — the heading
itself, matching the comment at `R/fly_footprint.R:140-142`.

Rotation is applied only when `hc != ha` **and** the bearing is finite. So the ring means
the same thing whether or not it was rotated, which is why one constant can serve both
the bearing-rotated and the `axis_aligned_no_bearing` non-square cases.

### Rotation 90/270 are the aspect-consistent candidates, not 0/180

`georef_one()` builds `fp_corners = [coords4, coords3, coords2, coords1]`
= `[front-left, front-right, rear-right, rear-left]` and maps pixel `[TL, TR, BR, BL]`
onto it, cyclically shifted by `rotation %/% 90`.

| rotation | image WIDTH lands on |
|---|---|
| 0 | cross-track edge |
| 90 | along-track edge |
| 180 | cross-track edge |
| 270 | along-track edge |

### Both bundled digital cameras deliver PORTRAIT thumbnails

Fetched 2026-08-30 from `openmaps.gov.bc.ca`:

| camera | calib key | thumbnail px | sensor px (cross x along) | footprint m | ratio |
|---|---|---|---|---|---|
| Leica DMC II | `121201_2011` | 884 x 972 | 15552 x 14144 | 4666 x 4243 | 1.100 |
| UltraCam Eagle M3 | `20814295_2018` | 1063 x 1654 | 26460 x 17004 | 3175 x 2040 | 1.556 |

The DMC II thumbnail's EXIF carries the source TIFF dimensions — `width=14144,
height=15552` — so the full-resolution frame is portrait too and the thumbnail is not
rotated relative to it.

In both, image **height** is the long axis and equals `px_cross`, the axis
`data-raw/make_camera_formats.R` assumes is across-track. So the image's long axis must
land on the footprint's long edge: **{90, 270} accepted, {0, 180} rejected, by geometry
alone.**

### One bit remains and needs pixels

90 and 270 differ by 180 degrees about the footprint centre. A rectangle is symmetric
under that, so no geometric invariant distinguishes them.

### A second assumption rides along

`data-raw/make_camera_formats.R:211,241,261` sets `px_cross = max(dims)`,
`px_along = min(dims)` — it assumes the long sensor axis is across-track.
`tests/testthat/test-fly_camera_format.R:119` asserts the footprint *follows* that
assumption, not that the assumption is true. If it is wrong the ground quad itself is
rotated 90 degrees and no corner mapping repairs it — that would reopen #32.

### The bundled fixture reaches the failure mode, unevenly

A wrong-by-90 mapping distorts by `ratio^2`: **2.42x** on the UltraCam (frames 19-24),
only **1.21x** on the DMC II (frames 1-18). The UltraCam frames are what make the aspect
invariant discriminating.

### Bundled digital bearings

Frames 1-18 (`bcd13304/5/6`, 2013): ~270.2-271.3 degrees.
Frames 19-24 (`bcd19503`, 2019): ~342.6-343.1 degrees.

## Ground truth for the imagery half

BC orthophoto imagery, catalogued in a private sibling repo. Joins to the airphoto
catalogue on `BCGS_TILE` + `PHOTO_YEAR`. The provincial collection is "Access Only" and
sold to the public, so ortho pixels must **not** be bundled into fly as test data
regardless of reachability. The QA runs there and produces a constant; the constant comes
back to fly, the imagery never does.

No file in this repo names that repo, its endpoint or its database.

## Errors Encountered

| Error | Resolution |
|-------|------------|
