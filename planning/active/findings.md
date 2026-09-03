# Findings — Bearing rotation for diagonal flight lines, film half (#26)

## Exploration, 2026-09-02 (pre-baseline)

### The bundled test data reaches the failure mode

`inst/testdata/photo_centroids.gpkg` — 20 frames, all 1968 film — contains the roll the
issue names:

| roll | frames | bearings, pre-guard |
|---|---|---|
| bc5282 | 10 | 226.5, 318.2, 59.8, 50.5, 69.3, 231.6, 230.0 x4 |
| bc5306 | 8 | 180.4, 180.0, 228.1, 359.9 x2, 0.1, 224.9 x2 |
| bc5300 | 1 | NA (single-frame roll) |
| bc5301 | 1 | NA (single-frame roll) |

**Corrected 2026-09-02** — an earlier version of this table had the two rolls swapped,
which mattered because Phase 1 picks a roll to measure on. Caught by the plan review
(G9) and re-measured. The real split is that bc5282 carries the diagonals *and* the
sparse overlap, while bc5306 carries the overlap *and* the cardinal headings.

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



## Phase 1 measurement — the film corner mapping (2026-09-02)

### Positive control, run first

Digital through the same harness: **270 at +0.713**, against 90 at +0.425. That
reproduces #38's finding, so the harness can find a known answer. Rotations 0 and 180
do not appear because `georef_one()`'s stretch guard *refuses* them on a non-square
footprint — a refusal is not a low score, and letting it compete for `which.max()`
cost one debugging round.

### Result — four legs, two rolls, two eras

| roll | year | bearing | best rotation | margin | top-edge azimuth |
|---|---|---|---|---|---|
| bc5282 | 1968 | 230° | **0** | 0.089 | 230 |
| bc83062 | 1983 | 150° | **90** | 0.135 | 240 |
| bc83062 | 1983 | 93° | **90** | 0.196 | 183 |
| bc83062 | 1983 | 62° | **90** | 0.152 | 152 |

The quantity read off is the **top-edge azimuth**, `bearing + rotation`, derived from
`fly_georef_gcps()` rather than reasoned about.

Two conclusions, pointing opposite ways:

1. **The mapping is flight-relative.** bc83062 returns 90 at three widely separated
   bearings, which a geographic convention could not do. This independently justifies
   rotating the footprint onto the bearing at all — it is the strongest evidence in the
   issue for the architecture, and it arrived as a by-product.
2. **It is not a constant.** A quarter turn separates the two eras. The stop condition
   in the plan fired.

### A rival hypothesis, tested and falsified

The first two rows agree to within 10° of geographic azimuth (230, 240), which looked
like a scanner delivering a fixed orientation regardless of heading. That model
predicts rotation 180 for the 93° and 62° legs. Both measured 90. Falsified, and
recorded rather than left as a loose end.

### Detrending — tried, rejected, and why

Subtracting a 9-cell local mean before correlating collapses the **digital control** to
+0.091 against +0.005. `fly`'s footprints are estimates, so fine detail does not align
between adjacent frames and a high-pass filter removes the broad tone carrying the
whole signal. #38 correlated raw at 25 m for the same reason. The detrended film run
picked 180 by a margin of 0.010, which is noise, not a contradiction.

### Why bc5306 was not used

Its well-overlapped consecutive pairs sit at bearings 180.4, 359.9 and 0.1. On a
cardinal heading every rotation is a whole quarter turn of the same square, so the
measurement is degenerate and would report a winner drawn from noise. The calibration
script asserts this as a premise and skips such a leg rather than scoring it.

## Downstream movement, bundled AOI (Upper Bulkley, 20 frames, 7 rotated)

| | main | this branch |
|---|---|---|
| `fly_coverage(by="scale")` 1:12000 | 15.1 km², 60.7% | 14.8 km², **59.5%** |
| same, 1:31680 | 24.8 km², 100% | 24.8 km², 100% |
| `fly_overlap()` pairs | 61 | **63** |
| `fly_filter()` rows | 20 of 20 | 20 of 20 |
| `fly_select(minimal, 0.95)` | 10 | 10 |
| DEM area ratio (median) | 1.1377 | 1.1372 |
| `dem_coverage` range | 0.9996–1 | 0.9996–1 |

Small, and **downward**, which is the point: the axis-aligned square was claiming
ground the frame does not photograph. Only 7 of 20 frames rotate under the adjacency
guard, so this understates the effect on a contiguous roll — a fact about this
fixture, not about the change.

The DEM path is unmoved: all 20 frames still take `dem_agl`, `dem_coverage` is
unchanged to four figures, and the median terrain enlargement stays at the documented
~14%. Rotating the sampling rectangle did not disturb it.

## Errors Encountered

| Error | Resolution |
|-------|------------|
| `rast()` on NA path in the calibration harness | A rotation the stretch guard refuses returns NA files. That is a refusal, not a low score — return `NaN` so it cannot win `which.max()` |
| Digital control appeared broken after the `fly_bearing()` guard | It was not: all 24 digital fixture frames are contiguous runs and keep their bearings. Probed before concluding |
| `expect_warning()` leaked a second warning | One warning per refused frame; collect them with `withCallingHandlers()` and assert the count |
