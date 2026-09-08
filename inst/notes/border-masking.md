# Why the frame-border mask is the way it is

Companion to `georeferencing.md`, `terrain-correction.md` and `camera-formats.md`. Read
this before changing `fly_mask()`, the `mask` argument of `fly_georef()`, or
`data-raw/mask_calibrate-border_threshold.R`.

Established in fly#23 (2026-09-07) over the 264 airphoto thumbnails in
`stac_airphoto_bc/data/raw/thumbs` — 1967 to 2018, 182 grayscale and 82 RGB, JPEG, uint8,
mostly 1250 x 1250. All of it is public: these are the images `fly_fetch(type =
"thumbnail")` downloads from openmaps.gov.bc.ca. Nothing here needed licence-restricted
imagery, and nothing here speaks to full-resolution scans — see the last section.

The sweep behind every number is shipped as `inst/extdata/mask_border_sweep.csv` (2,640
rows: 264 frames x 10 thresholds, total and interior mask fraction) so the constants are
**checkable inside the test suite** rather than remembered. Reproduce it with
`data-raw/mask_calibrate-border_threshold.R`.

## The boundary is not a circle, and the issue that asked for one was wrong

fly#23 asked for Hough-transform detection of "the circular lens image area". An
inscribed circle makes four predictions. All four fail.

These rows measure **raw darkness** — the share of pixels at or below 16, wherever they
sit — not the mask. That is the right quantity for the falsification, because it is what a
circle would have to account for, and it is deliberately the *most generous* reading: the
mask is smaller still. Do not read these numbers as mask fractions; those are in
`mask_border_sweep.csv` and appear further down.

| | an inscribed circle predicts | measured over 264 |
| --- | --- | --- |
| dark fraction | 0.2146 | median **0.027**, max 0.191 |
| frames near 0.2146 | all of them | **2 of 264** within 20% |
| corner-block darkness | ~1.0 | median 0.382 |
| edge-midpoint darkness | ~0.0 | median **0.216** |
| share of dark pixels within 5% of an edge | low | median per frame **1.000** |

**The edge-midpoint row is the one that decides.** A circle inscribed in the frame passes
through the middle of each edge, so those midpoints are inside the exposed image and
bright by construction. Measured, they are as dark as the corners on many rolls — 1977
roll bc77033 gives corner 0.314 against edge-mid 0.311, 1980 roll bc80055 gives 0.303
against 0.309. No circle produces that. It is a rectangular collar with chamfered corners:
film holder edges, fiducial marks, scanner overrun.

And **27 of the 264 carry no collar at all** at the working threshold, digital frames
among them. So there is no global shape to apply, circular or otherwise. It has to be
derived per frame.

### The physical argument, which is reasoning rather than measurement

The statistics above are taken on thumbnails, and fly#23's stated trigger is
full-resolution scans, which this package cannot obtain. So they do not by themselves
close the question at full resolution. This does: a mapping camera's film or sensor
format is designed to sit **inside** the lens's image circle, so on a correctly exposed
aerial frame the image circle **circumscribes** the format and there is no dark circle
anywhere in the frame at any resolution. The inscribed-circle model was never physically
right for this instrument class.

Marked as reasoning deliberately. It is an argument about how mapping cameras are built,
not a measurement of these files, and it should be labelled as such by anyone repeating it.

## The defect underneath: `srcnodata = "0"` masked almost none of the collar

Before v0.11.0 `fly_georef()` passed `-srcnodata "0"` to GDAL, which matches **exact**
zeros. Scanned black is not 0 — on these JPEGs it runs 3 to 12.

| | median mask fraction |
| --- | --- |
| threshold 0 (what `srcnodata = "0"` reached) | 0.0016 |
| threshold 16 | 0.0311 |
| ratio | **19.8x** |

**128 of 264 frames had less than a tenth of their collar masked**, and some had none at
all: `bc88011_200_12n` measures 0.0000 at threshold 0 against 0.0176 at 16. That is the
mosaic symptom fly#23 and fly#22 both describe.

It also means both halves of the tradeoff `fly_georef()`'s roxygen used to state were
false. It claimed to mask the borders (it did not) at the cost of losing real black pixels
(there were almost none to lose — median exact-zero content is 0.16% of a frame, and it is
collar, not shadow). Corrected in this release.

## The collar is edge-connected, and that is what preserves real dark ground

The mask is a flood fill seeded from the image border, so only darkness **reachable from
the edge** is masked. This is not a refinement — it is the difference between the fix and
a new bug:

| frame | plain threshold | edge-connected |
| --- | --- | --- |
| bcb90128_213 (1990) | 0.0767 | **0.0252** |
| bcb94081_042 (1994) | 0.1779 | **0.0462** |
| bcb00003_100 (2000) | 0.0359 | 0.0356 |
| bcb96027_004 (1996) | 0.0354 | 0.0352 |

Where the dark region *is* the collar the two agree to a thousandth. Where the frame holds
a dark lake or a deep shadow, a plain threshold deletes it and the flood fill keeps it. The
missing 5% and 13% in the first two rows is water, and it is exactly what fly#23 meant by
"nodata=0 loses real dark pixels".

## GDAL `nearblack` is this algorithm, and it needs no new dependency

`sf::gdal_utils()` dispatches `util = "nearblack"`, and GDAL's `-alg floodfill` (GDAL >=
3.7) is a flood fill seeded from the image border — the algorithm above, in C++,
reachable through a package already in Imports. `-setalpha` appends the 0/255 band and
`-near` is the threshold.

A `terra::patches(directions = 8)` implementation was written first and is **kept in
`data-raw/` as the control**, not shipped: putting it in the package would place a
Suggests dependency on the default code path of an exported function, and at full
resolution it would read a 9600 x 9000 image into R.

**The two were measured against each other before the dependency-free route was adopted**,
because they need not agree: had GDAL's fill been 4-connected, a chamfered corner joined
only diagonally would have broken away. Over all 264 frames at threshold 16:

| | value |
| --- | --- |
| correlation | **0.9877** |
| frames disagreeing by more than 0.02 | **0 of 264** |
| median difference (GDAL minus terra) | +0.0064 |

GDAL masks consistently a little more, and the amount is explained rather than tolerated:
`-nb` (default 2) is how many non-black pixels nearblack accepts before deciding the
collar has ended, so the fill advances two pixels past the last dark one on every side. On
a synthetic 200 x 200 frame with a 10-pixel collar that predicts 0.2256 against a strict
0.1900, and the measured value is 0.2256. `tests/testthat/test-fly_mask.R` asserts that
number rather than absorbing it into a loose tolerance, so setting `-nb` would fail a test
that names it.

`terra` therefore stays in Suggests.

## The threshold is 16, and the sweep is easy to read backwards

`fly_mask_threshold()` is **16**.

The first reading of the sweep took the population median of mask fractions by threshold,
saw the increments fall (0.0134, 0.0077, 0.0028, 0.0037, 0.0021, 0.0012) and called 12-16
a knee with a plateau to 32. **That reading is wrong twice.** The smallest increment is
24 -> 32, not 16 -> 24, so the curve does not say what it was said to say; and a median of
mask *fractions* cannot distinguish a fully-removed collar from a small one, because it
moves for both reasons at once. It is the wrong statistic, not merely misread.

The calibration target is **per frame**: the threshold past which that frame's own mask
stops growing, because its collar is gone and the next dark thing is scene content.
Measured over all 264:

| plateau threshold | 0 | 4 | 8 | 12 | 16 |
| --- | --- | --- | --- | --- | --- |
| frames | 80 | 35 | 85 | 37 | 5 |

| quantile | 50% | 90% | 95% | 99% | max |
| --- | --- | --- | --- | --- | --- |
| threshold | 8 | 12 | 12 | **16** | 16 |

16 is the 99th percentile **and** the maximum: every frame in the population has its
collar fully consumed at 16, and none needs more. That it coincides with the number the
wrong reading produced is luck, and the note records both so nobody re-derives it from the
median again.

The tie, had there been one, breaks toward the higher value: under-masking leaves a
visible black border, which self-reports in the mosaic, while over-masking punches a
transparent hole in real imagery, which nothing downstream reports.

**It assumes Byte bands.** `-near` is a per-band distance from 0, so on a 16-bit scan the
same number means 1/256th of the distance it means here. This threshold does not transfer.

## The guard tests the INTERIOR fraction, and the band is computed

`fly_mask_max_interior()` is **0.05**, on the mask's share of a central box with 10%
dropped from each side.

Total mask fraction was tried first and rejected. It cannot separate "a thick collar" from
"a lake touching the edge and reaching the centre" — both occupy the same share of the
frame, and only the second is the failure the guard exists for. A genuine collar hugs the
border, so it contributes almost nothing to a central box, which makes the interior
fraction a far better-conditioned discriminator.

At the shipped threshold the margin is wide, and **no frame in the measured population can
trip the guard**:

| threshold | max interior fraction | frames over the 0.05 cap | smallest that trips it |
| --- | --- | --- | --- |
| **16 (shipped)** | **0.0131** | **0 of 264** | — |
| 24 | 0.0160 | 0 | — |
| 32 | 0.0465 | 0 | — |
| 48 | 0.2379 | 14 | 0.0510 |
| 64 | 0.7159 | 32 | 0.0525 |

The cap clears the worst legitimate frame (bcb94081_070, 1994) by **3.81x**.

**An earlier draft of this section published an admissible band of (0.0131, 0.2379) with a
4.8x margin below "the smallest runaway". That was wrong.** 0.2379 is the *maximum*
interior fraction at threshold 48, not the smallest value that trips the cap there, which
is 0.0510. The error was in the direction that flatters the constant, and it was found by a
reviewer recomputing it from the shipped sweep rather than reading the sentence.

**The two constants are coupled, and the cap does not survive raising the threshold on its
own.** The worst legitimate interior fraction climbs with the threshold: 0.0131 at 16,
0.0160 at 24, **0.0465 at 32** — where the cap clears it by only 1.08x. Re-measure both
from `mask_border_sweep.csv` together, or neither.

The worst frame at high thresholds is worth naming: `bcd18704_592` is a 2018 digital frame
with **no collar at all**. Given a threshold high enough to reach scene content the fill
escapes the border and consumes 72% of the interior. That is the failure mode the guard
exists for, and it is a flood rather than a mis-sized collar.

**When it trips, the frame is left unmasked with a warning — not skipped.** This is
deliberately the opposite call to the stretch tolerance in `georeferencing.md`, and the
reason is that the outcomes there are symmetric and here they are not. A squashed GeoTIFF
and a correct one both look fine, so the stretch guard refuses. Here, an unmasked frame
shows a black border — visible, and what every caller lived with before this release —
while an over-eager mask silently deletes real imagery. Falling back costs a cosmetic
property; skipping would cost a georeferenceable frame.

**A mask fraction of zero is not a warning.** 27 of 264 frames legitimately have no collar.

## Nothing downstream changes band count

Verified end to end on sf's GDAL 3.8.5:

```
gray 1 band -> nearblack -setalpha -> 2 -> translate -of VRT (+GCPs) -> warp -srcalpha -dstnodata 0 -> 1 band out
rgb  3 band -> nearblack -setalpha -> 4 -> translate -of VRT (+GCPs) -> warp -srcalpha -dstalpha    -> 4 bands out
```

`-srcalpha` forces the last band to be read as alpha and excludes it from the warped band
list, so today's output contract holds on both paths. The GCP step is a **VRT**, which
carries a `<GCPList>` that gdalwarp reads — so masking removes a full-size temp copy
rather than adding one. At 9600 x 9000 x 4 that is the difference between roughly 350 MB
and 700 MB of scratch per frame.

Two wrinkles, both measured:

- On a **grayscale** source `-setalpha` writes `ColorInterp=Undefined` on band 2, not
  `Alpha`. RGB gets `Alpha` correctly. `-srcalpha` works either way because it forces the
  last band regardless — but nothing may key on `ColorInterp` for the grayscale path.
- Grayscale output carries `-dstnodata 0` rather than an alpha band, which is strictly
  weaker: it cannot express partial coverage at the mask boundary, and a genuine 0-valued
  pixel inside the frame is indistinguishable from a masked one — the same class of defect
  the mask exists to fix, on the output side. 182 of the 264 measured frames are grayscale.
  Changing it moves the band count of every grayscale output from 1 to 2, which
  `stac_airphoto_bc` consumes, so it is tracked separately as fly#56 rather than bundled
  here.

### The warp does not pull masked black into the pixels beside it

If GDAL did not exclude invalid source pixels from the bilinear kernel, every kept pixel
along the mask boundary would be dragged toward 0 and this fix would introduce a
one-pixel dark rim of its own. Measured, it does not — and the measurement had to be
built carefully, because the obvious version of it answers nothing:

| | measured |
| --- | --- |
| distinct output alpha values | **2** (0 and 255 — no partial coverage) |
| kept pixels adjacent to the mask, synthetic uniform interior | 574 |
| their luminance | **200 to 200**, the fill value exactly |
| same, kept pixels not adjacent | 200 to 200 |

Two ways this check goes vacuous, both met on the way to the number above:

- **On an axis-aligned warp there are no boundary pixels at all.** The first run reported
  "no partially-covered pixels to measure", which reads as a clean bill and is not one.
  The GCPs must describe a genuinely rotated ground quad, as `fly_rectangles()` produces.
- **On a real thumbnail the question is unanswerable.** The exposed frame is genuinely
  darker at its edge, so boundary pixels read low whether or not a fringe exists. Measured
  on a 2005 RGB thumbnail the boundary-to-interior luminance ratio is **0.63**, and none of
  that is attributable to the warp. Only a synthetic frame with a uniform interior
  separates the two.

Had a fringe been present the remedy would have been to erode the mask inward by a pixel,
**not** to change the resampling.

### `-srcnodata` and the mask are mutually exclusive, and GDAL will not tell you

`fly_georef()` refuses the combination. The reason is **not** that GDAL rejects it — it
does not. All four forms run clean and produce the expected band count:

| warp options | result |
| --- | --- |
| `-srcalpha -dstalpha` | ok, 4 bands |
| `-srcalpha -srcnodata "0 0 0" -dstalpha` | ok, 4 bands |
| `-srcalpha -srcnodata "0 0 0 0" -dstalpha` | ok, 4 bands |
| `-srcnodata "0 0 0" -dstalpha` (no srcalpha) | ok, 4 bands |

An early draft of this note asserted the three-value form was a length mismatch against a
four-band source. Measured, it is not, and neither is the four-value form. **The package
refuses the combination precisely because GDAL accepts it silently.**

What it silently does, measured on a 100 x 100 synthetic frame with an 8-pixel collar and
an 11 x 11 block of *true black* (value 0) at the centre:

| | opaque | transparent |
| --- | --- | --- |
| `-srcalpha` alone | 6400 | 3600 |
| plus `-srcnodata "0 0 0"` | **6279** | 3721 |

The difference is 121 pixels — exactly the interior block. Adding `-srcnodata` to a masked
warp deletes the real black content the mask exists to preserve, which is the defect
fly#23 was filed about, reintroduced by the option that was supposed to fix it. Nothing is
reported, so the package raises the error GDAL does not.

## What was tried and rejected

- **Hough / circle detection**, as fly#23 proposed — falsified above.
- **A cap on total mask fraction** rather than interior — cannot separate a thick collar
  from a lake running off the edge, which is the failure it exists to catch.
- **The `terra::patches(directions = 8)` prototype** — correct, and kept in `data-raw/` as
  the control, but shipping it would put a Suggests package on a default code path and
  read a full-resolution image into R.
- **`nearblack -alg twopasses`** — the pre-3.7 algorithm, which collapses inward from each
  edge along rows and columns rather than flood-filling. It gave 0.0303 against floodfill's
  0.0312 on bcb90128_213, so it is close on this population, but it is not
  edge-connectivity and has no reason to stay close on a frame whose collar is irregular.
- **Raising `srcnodata` from `"0"` to a near-black value** — the smallest change, and it is
  a plain threshold: it destroys the interior water the table above measures.

## What this cannot reach

- **Full-resolution scans.** The BC catalogue centroid layer carries
  `thumbnail_image_url`, `flight_log_url`, `camera_calibration_url` and
  `patb_georef_url`, and no URL for a full-resolution scan; those are licence-restricted.
  So fly#23's stated trigger cannot be fixtured, tested or calibrated in this package.
  `fly_mask()` is exported precisely so that a caller holding licensed scans on disk has an
  entry point that does not go through `fly_fetch()`. Both constants above, and the Byte
  assumption, are properties of the thumbnail population and should be re-measured on
  scans before being trusted there.
- **The runaway guard, on real data.** At threshold 16 the largest interior fraction any
  of the 264 produces is 0.0131 against a cap of 0.05, so **no frame in the measured
  population can trip it**. Only a synthesized fixture can, and the test suite says so
  where it builds one. A green run over real thumbnails is not evidence the guard works.
- **16-bit imagery.** `-near` is an absolute per-band distance and the threshold does not
  transfer.
