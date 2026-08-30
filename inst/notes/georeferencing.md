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
`fly_georef()` must not apply `bearing_to_rotation()` to a non-square footprint: the
bearing is already in the ring, and applying it again counts it twice.

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

## The one thing that would invalidate this

All three measurements are downstream of `camera_formats.csv` assigning the long sensor
axis to the **across-track** direction. Get that wrong and the footprint itself is
rotated 90 degrees on the ground, and no corner mapping repairs it. Two things guard it:
`parse_vexcel()` reads the manufacturer's own `long track` / `cross track` labels rather
than inferring, and `fly_georef()` refuses any frame whose delivered image aspect does not
pair isotropically with its footprint edges — which is also what catches a frame sized
from an inferred format that does not match its real camera.
