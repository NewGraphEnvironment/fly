# Findings — Bearing rotation for diagonal flight lines, film half (#26)

## Exploration, 2026-09-02 (pre-baseline)

### The bundled test data reaches the failure mode

`inst/testdata/photo_centroids.gpkg` — 20 frames, all 1968 film — contains the roll the
issue names:

| roll | frames | bearings |
|---|---|---|
| bc5282 | 10 | 224.9, 226.5, 228.1, 230.0 x3, 231.6, ... |
| bc5306 | 8 | mixed, incl. 50.5, 59.8, 69.3 |
| bc5300 | 1 | NA (single-frame roll) |
| bc5301 | 1 | NA (single-frame roll) |

So the diagonal film case is reproducible from bundled data plus public thumbnails.
`bc5300` / `bc5301` are single-frame rolls, which means the no-bearing fallback path is
also exercised by the fixture rather than being hypothetical.

### Where the mechanism already is

`fly_rectangles()` (R/fly_footprint.R:264) already applies continuous rotation. It is
gated on `!isTRUE(all.equal(hc, ha))` — squareness — so film never reaches it.
`fly_footprint()` similarly gates the `fly_bearing()` call on `any(non_square)`.

### Why squareness stops being the right predicate

`fly_georef()` branches on `fly_is_square()`. That works today only because squareness
and "was not rotated" coincide. Rotating film breaks the coincidence, so the branch has
to move to the fact it was always standing in for — whether a bearing was applied.
`fly_is_square()`'s own comment says as much: it rejects "is it axis-aligned" as a proxy
for "was it rotated". The same reasoning now rejects squareness.

### Why the constant must be measured

`inst/notes/georeferencing.md` records that the aspect invariant "cannot separate 270
from 90 — they differ by 180 degrees about the centre and a rectangle is symmetric under
that. It is also vacuous on square film." For a **square** footprint it is vacuous
against all four rotations, so nothing in the suite can catch a wrong film constant.
Only adjacent-frame overlap correlation and FWA lake darkness can, and both need real
thumbnails, so both live in `data-raw/`.

Exterior orientation (route 1 of #38) is unavailable: 1968 film has no
`patb_georef_url`.

## Issue context

## Problem

`fly_georef(rotation = "auto")` derives rotation from flight bearing using `floor((bearing + 91) / 90) * 90 %% 360`. This works for E-W flight lines (~90°/~270° bearings) but fails for diagonal flights (~230°, ~45°, etc.).

Two photos at bearing ~230° needed opposite rotations:
- bc5282_233 (1968): correct rotation = 0
- bcd19503_522 (2019): correct rotation = 180

Same bearing, different eras → camera/scanner orientation difference that 90° quantization can't capture.

## Proposed Solution

Rotate the footprint polygon by the flight bearing instead of shuffling pixel corners in a north-up box. This allows continuous rotation, not just 90° increments.

Requires changes to `fly_footprint()` to accept a bearing and produce a rotated rectangle.

### Status update, 2026-08-30 — the mechanism now exists (#32, v0.6.0)

`fly_rectangles()` takes `half_cross`, `half_along` and a `bearing`, and applies
continuous rotation about the centroid. `fly_footprint()` computes the bearing via
`fly_bearing()` and threads it through both DEM sampling passes as well as the returned
geometry. So the change this issue asks for has been built.

**It is deliberately applied only where the recording format is non-square** — i.e. to
digital frames. Film stays square and axis-aligned, so film output is byte-identical to
before, which is what kept #32 from moving every existing footprint.

That splits this issue's two failing cases:

- `bcd19503_522` (2019, digital) — covered by #38, which is where the corner mapping for
  a pre-rotated non-square footprint gets established against real imagery.
- `bc5282_233` (1968, **film**) — still open, and still exactly as described above. A
  square footprint is unchanged by rotation, so rotating it cannot by itself fix a
  wrong-by-180 corner mapping; what is needed is for `fly_georef()` to stop quantizing
  the bearing to 90 degrees.

**So what remains here is the film half**, and it is a decision rather than a build: the
rotation machinery is in place, and applying it to film would change existing film
output. The workaround below is still the current answer.

## Workaround

Set a `rotation` column on `photos_sf` for affected rolls:
```r
photos$rotation <- dplyr::case_when(
  photos$film_roll == "bc5282" ~ 0L,
  photos$film_roll == "bcd19503" ~ 180L,
  .default = NA  # fall through to auto
)
```

## Context

Discovered while calibrating auto-rotation (#25). Affects ~diagonal flights which are a minority of the dataset.


