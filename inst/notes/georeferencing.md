# Why the corner mapping is the way it is

Companion to `terrain-correction.md` and `camera-formats.md`. Read this before changing
`fly_georef_gcps()`, the rotation `fly_georef()` applies to a non-square footprint, or
`data-raw/georef_calibrate-corner_mapping.R`.

Established in fly#38 (2026-08-30) against published BC data. Nothing here needed
licence-restricted imagery.

## The ring order is a contract, and it is in the rectangle's own frame

`fly_rectangles()` emits vertices in this order, in local coordinates where `+y` is the
flight heading and `+x` is 90 degrees clockwise of it:

| ring row | local | flight-relative |
|---|---|---|
| 1 | `(-hc, -ha)` | rear-left |
| 2 | `( hc, -ha)` | rear-right |
| 3 | `( hc,  ha)` | front-right |
| 4 | `(-hc,  ha)` | front-left |

Rotation onto the bearing is applied to the whole rectangle, so **the ring means the same
thing whether or not it was rotated**. That is what lets one constant serve both the
bearing-rotated frames and the `axis_aligned_no_bearing` ones, and it is why
`fly_georef()` must not apply `bearing_to_rotation()` to a rotated footprint: the
bearing is already in the ring, and applying it again counts it twice.

Since fly#26 this applies to **film as well as digital** — every footprint is rotated
onto its bearing where one can be computed, and `footprint_bearing` records it. So
`fly_georef()` routes on whether the ring was rotated, not on whether it is square;
squareness stood in for that and the two have come apart. The film half of the story is
at the end of this file, and it does **not** end in a constant.

Also since fly#26, `fly_rectangles()` rotates four vertices and closes the ring by
copying the first, rather than carrying a fifth row through the arithmetic. See
"Closure is by copy" below before changing it.

## The mapping is rotation 270: top-left pixel to the rear-left ground corner

Equivalently: **image columns run in the flight direction, image rows run flight-right.**

Three independent measurements. They are listed in the order that makes the weakest one
easiest to over-trust, which is the order they were run in.

### 1. Exterior orientation — authoritative-looking, and the one that misled

The catalogue publishes per-frame exterior orientation through `patb_georef_url`, which
`fly_fetch(type = "georef")` already fetches. It is free, public, and covers every
digital frame.

The measurement is the offset between the camera's image x-axis azimuth and the flight
heading computed from the frame's own neighbours. **The control that matters is sum
versus difference**: a rigid mount holds `image_x_azimuth - heading` constant, while a
ground frame whose axes are read in the wrong order holds `image_x_azimuth + heading`
constant instead. The two are indistinguishable on a project that flies one axis.

| camera | n | compass bins | rigid | reflected |
|---|---|---|---|---|
| UltraCam Eagle M3 | 6839 | 32 | median **0.18**, MAD 0.47, 98.7% within 5 | median 254.7, MAD 100.6, **14.1%** |
| Leica DMC II (bundled project) | 5450 | 8, all E/W | median −177.7, 97.6% | median 357.0, **98.4%** |
| Leica DMC II (3 further projects) | 7924 | 13 | median ≈ −178, 22–96% | 2–17% |

So the Eagle's mount is rigid to half a degree with its image x-axis **along the heading**,
and reflection is excluded outright. Under the ordinary top-left raster convention that
gives rotation 270.

The DMC II reading gives an offset of 180 degrees instead, which would put it at rotation
90 — and it is **wrong**. Note what it looks like: 97.6% agreement on the bundled project,
a clean-looking median, four projects pooled. What that number cannot show is that the
bundled project flies east and west only, so its own data cannot separate the two
hypotheses at all (97.6% against 98.4%), and the file that produces it has
`gr_omega/gr_phi/gr_kappa` zeroed, an undocumented 3x3 matrix in their place, and a
`c2` column that is the literal string `00000000000` in every row. It is a chain of
assumed conventions wearing a large sample size.

### 2. Adjacent-frame overlap — the measurement that decides

Consecutive frames on a line overlap heavily, so at the correct rotation their common
ground must agree. A 180-degree error reflects each frame about **its own** centre, and
because the centres differ the overlap then shows different ground.

This needs no reference imagery of any kind. The frames check each other.

Mean Pearson r between adjacent georeferenced frames, on a common 25 m grid:

| rotation | UltraCam Eagle M3 | Leica DMC II |
|---|---|---|
| 0 | +0.095 | +0.356 |
| 90 | +0.069 | +0.429 |
| 180 | +0.135 | +0.331 |
| **270** | **+0.616** | **+0.659** |

Both cameras, unambiguously, and the same answer.

### 3. Water darkness — an outside opinion

Lakes are dark and FWA knows exactly where they are. Only discriminating when the water
sits off-centre, since a 180-degree error rotates about the footprint centre — so the
offset is reported beside the result rather than assumed.

Mean luminance inside FWA lake polygons minus the frame mean:

| rotation | frame 778 (water 442 m off-centre) | frame 779 (1684 m off-centre) |
|---|---|---|
| 0 | +0.7 | +16.9 |
| 90 | −12.1 | +1.1 |
| 180 | −5.4 | −5.6 |
| **270** | **−23.4** | **−9.5** |

## What each check can and cannot catch

- **The aspect invariant** (`tests/testthat/test-fly_georef_aspect.R`) rejects rotations
  0 and 180, because those pair the image's long axis with the footprint's short edge.
  It **cannot** separate 270 from 90 — they differ by 180 degrees about the centre and a
  rectangle is symmetric under that. It is also vacuous on square film, which is the
  whole of the pre-existing georef suite.
- **It cannot catch a mirrored mapping either.** Traversing the ring the other way leaves
  every edge length and the aspect ratio identical and produces a reflection. The signed
  area of the ground quad in pixel order is what separates those, and it is asserted.
- **The overlap and water checks** both need real thumbnails, so they live in
  `data-raw/`, not in the test suite.

## The stretch tolerance, and why it is not a shape gate

`georef_one()` refuses a mapping whose image and footprint disagree about the frame's
shape by more than 10%. The number is set from measurements, not picked:

| \|log\| off isotropic | what it is |
|---|---|
| 0.0000 | the bundled film thumbnails, 1250 x 1250 |
| 0.0645 | a full-resolution 9-inch scan at 9600 x 9000, carrying the negative's rebate |
| **0.0770** | **the tolerance, 1.08** |
| 0.0949 | the tightest case that must be caught — a Leica DMC II frame sized through `format_size` onto a square footprint |
| 0.1898 | the tightest mispairing on a frame's own footprint, the same DMC II squared |
| 0.4421 | a portrait UltraCam frame on a square footprint |

The admissible band is **(1.0667, 1.0995)** and it is narrow, because a square-footprint
DMC II frame is only slightly more eccentric than a badly rebated film scan. A first
draft set 1.10, which is outside it by 0.4% and let exactly one row of
`camera_formats.csv` through — the DMC II, the one case the tolerance had replaced a
shape gate to cover. The test that was supposed to guard the threshold asserted it
against the *UltraCam* at 0.442, which any tolerance clears. **Check a threshold against
the least favourable member of the population, computed, not against a remembered
example.**

An earlier version exempted square footprints instead, on the reasoning that a square one
has no pairing to get wrong. It is true and it is the wrong fix: `format_size` sizes a
frame from a single width, so a digital frame from a camera `fly` does not know lands on a
**square** footprint — and that is precisely the case the guard exists for. A shape gate
switches it off there. A tolerance wide enough for the rebate does not.

## Film has no constant, and that is a measurement (fly#26)

Everything above is about a **non-square** footprint. fly#26 rotated film onto its
bearing too, which needs its own corner mapping, and the answer is that there is not one.

### Why the geometry cannot settle it, and why it is worse here

The aspect invariant rejects a mapping that pairs the image's long axis with the
footprint's short edge. A square footprint has no long axis, so on film the invariant is
vacuous against **all four** rotations rather than merely unable to separate two of them.
Nothing in the test suite can catch a wrong film mapping.

Worse, on a square the mapping is not free-standing. With `hc == ha` nothing
distinguishes the along-track axis from the cross-track one, so rotating by `b` and
mapping with shift `r` is indistinguishable from rotating by `b ± 90` and mapping with
`r ∓ 90`. What is measured below is a **composite** of the mapping and
`fly_rectangles()`'s vertex order and rotation sign. That convention is pinned in
`test-fly_camera_format.R` as *ring vertex 1 sits at `bearing + 225` from the centroid*.
**If that assertion is ever changed, everything in this section is void.**

The quantity to read off is the **top-edge azimuth**, `bearing + rotation` — where the
top of the image points on the ground. It is derived from `fly_georef_gcps()` rather
than reasoned about.

### The measurement

Adjacent-frame overlap correlation, the route that decided the digital case. Exterior
orientation is unavailable — 1968 film has no `patb_georef_url`.

Positive control first, through the same harness: digital returns **270 at +0.713**
against 90 at +0.425, reproducing the table above. Rotations 0 and 180 do not appear
because the stretch guard *refuses* them on a non-square footprint; a refusal is not a
low score and must not compete for `which.max()`.

| roll | year | bearing | best rotation | margin | top-edge azimuth |
|---|---|---|---|---|---|
| bc5282 | 1968 | 230° | **0** | 0.089 | 230 |
| bc83062 | 1983 | 150° | **90** | 0.135 | 240 |
| bc83062 | 1983 | 93° | **90** | 0.196 | 183 |
| bc83062 | 1983 | 62° | **90** | 0.152 | 152 |

Two conclusions, pointing opposite ways:

1. **The mapping is flight-relative.** bc83062 returns the same answer at three widely
   separated bearings, which a geographic convention could not do. This is the strongest
   evidence for rotating the footprint onto the bearing at all, and it arrived as a
   by-product of trying to find a constant.
2. **It is not a constant.** A quarter turn separates the two eras — which is what fly#26
   said at the outset: *"same bearing, different eras → camera/scanner orientation
   difference that 90° quantization can't capture."*

So `fly_georef()` **refuses** a rotated square footprint unless the caller supplies the
roll's rotation, and the warning names the roll and the remedy. A wrong mapping here
produces a valid GeoTIFF over the right ground with the picture turned a quarter turn,
which nothing downstream would report — the same reason the stretch guard skips rather
than writing squashed, and the same call #30 made for an unknown recording format.

### A rival hypothesis, falsified rather than left open

The first two rows agree to within 10° of *geographic* azimuth (230, 240), which looked
like a scanner delivering a fixed orientation regardless of heading. That model predicts
rotation 180 for the 93° and 62° legs. Both measured **90**. Falsified.

### What was tried and rejected

- **Detrending** (subtract a 9-cell local mean before correlating) collapses the digital
  control to +0.091 against +0.005. `fly`'s footprints are estimates, so fine detail does
  not align between adjacent frames and a high-pass filter removes the broad tone that
  carries the whole signal. The detrended film run picked 180 by a margin of 0.010, which
  is noise rather than a contradiction. #38 correlated raw at 25 m for the same reason.
- **bc5306**, the other bundled roll. Its well-overlapped consecutive pairs sit at
  bearings 180.4, 359.9 and 0.1. On a cardinal heading every rotation is a whole quarter
  turn of the same square, so the measurement is degenerate and would report a winner
  drawn from noise. The calibration script asserts this as a premise and skips such a leg.
- **The bundled fixture on its own.** After fly#26's adjacency guard exactly one true
  frame-to-frame diagonal pair survives in it. One pair is not a measurement, so the legs
  are pulled from the public catalogue.

### Closure is by copy, not by recomputation

`fly_rectangles()` rotates **four** vertices and appends the first again to close the
ring. It must not carry a fifth row through the arithmetic: `%*%` computes rows
independently and an optimised BLAS may block or vectorise them differently, so the
recomputed closing vertex can land a few ulps off the first. Measured at bearing 230 on a
1000 m half-side: 2.8e-14 in y. `sf::st_polygon()` requires exact closure and **errors**,
so one unlucky frame aborts the whole batch. It is data-dependent, which is why the
bundled fixture never showed it and 1343 tests passed over it — `test-fly_footprint.R`
now sweeps 720 bearings, and asserts that the recomputed form does fail somewhere in that
sweep so the test cannot quietly become decoration.

## The one thing that would invalidate this

All three measurements are downstream of `camera_formats.csv` assigning the long sensor
axis to the **across-track** direction. Get that wrong and the footprint itself is
rotated 90 degrees on the ground, and no corner mapping repairs it. Two things guard it:
`parse_vexcel()` reads the manufacturer's own `long track` / `cross track` labels rather
than inferring, and `fly_georef()` refuses any frame whose delivered image aspect does not
pair isotropically with its footprint edges — which is also what catches a frame sized
from an inferred format that does not match its real camera.
