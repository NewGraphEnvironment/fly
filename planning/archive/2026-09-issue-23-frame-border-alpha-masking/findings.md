# Findings - frame-border alpha masking (#23)

## Issue context (as filed)

> ## Problem
>
> Airphoto thumbnails and scans have black camera frame borders outside the circular lens
> image area. When mosaicking, these borders cover adjacent photos.
>
> For thumbnails (1250x1250), setting nodata=0 in the COG is acceptable - lost shadow
> detail is negligible at this resolution.
>
> For full-res scans, nodata=0 loses real dark pixels (deep shadows, dark water). Need
> proper circle detection to generate an alpha mask.
>
> ## Proposed Solution
>
> Detect the circular image boundary algorithmically (Hough transform or threshold-based
> edge detection) and generate an alpha mask during `fly_thumb_georef()` or a separate
> function [...]
>
> ## Priority
>
> Low - only needed when full-res scan processing begins. Thumbnails work fine with
> nodata=0.

`fly_thumb_georef()` was renamed `fly_georef()`. Issue #22 (closed) is the sibling that
introduced the `srcnodata` argument.

## The premise is falsified: it is a frame border, not a lens circle

Measured over **all 264** raw thumbnails in
`~/Projects/repo/stac_airphoto_bc/data/raw/thumbs`, years 1967-2018, JPEG, 1250x1250
mostly, 1 or 3 band, uint8. Dark defined as max-over-bands <= 16.

| statistic | inscribed circle predicts | measured |
| --- | --- | --- |
| dark fraction | 0.2146 | median 0.027, p90 0.051, max 0.191 |
| frames within 20% of 0.2146 | all | **2 of 264** |
| corner-block darkness | ~1.0 | median 0.382 |
| edge-midpoint darkness | ~0.0 | **median 0.216** |
| per-frame share of dark pixels within 5% of an edge | low | **median 1.000**, p25 0.988 |

The edge-midpoint number alone is decisive: an inscribed circle leaves the middle of each
edge fully inside the image and therefore bright. Measured, the edge midpoints are as dark
as the corners on many rolls (1977: corner 0.314, edge-mid 0.311; 1980: 0.303 / 0.309).

**38 of 264 frames have no dark border at all** (dark fraction < 0.002) - 1975, 1980, 1982
in part, and all ten 2018 digital frames at 1.7e-5. So there is no global mask shape to
apply, circular or otherwise; it has to be derived per frame.

Physical argument, offered as reasoning rather than measurement: a mapping camera's film
or sensor format is designed to sit **inside** the lens's image circle, so on a correctly
exposed aerial frame the image circle circumscribes the format and there is no dark
circle to detect at any resolution. This survives the thumbnail/full-res scope gap that
the statistics alone do not.

## The live defect: `srcnodata = "0"` masks almost none of the border

`-srcnodata "0"` matches only **exact** zeros. Scanned black on these JPEGs is 3-12.

| statistic | value |
| --- | --- |
| exact-zero fraction, median | 0.0026 |
| dark (<=16) fraction, median | 0.0270 |
| ratio | ~10x under-masked |

Worked cases: `bcb96027_004` zero 0.0004 vs border 0.0352 (1% of the border masked);
`bcb99033_145` 0.0002 vs 0.0133; `bc88011_200` **0.0000** vs 0.0176 - nothing masked at all.

This is the reported mosaic symptom, and it means both halves of the tradeoff stated in
`fly_georef()`'s roxygen are false: it does not mask the borders, and it costs essentially
no real black pixels.

## Edge-connected masking preserves interior dark content; a plain threshold does not

Prototype: threshold, connected components (`terra::patches`, directions = 8), keep only
components touching the image edge.

| frame | threshold-only | edge-connected |
| --- | --- | --- |
| bcb90128_213 (1990) | 0.0767 | **0.0252** |
| bcb94081_042 (1994) | 0.1779 | **0.0462** |
| bcb00003_100 (2000) | 0.0359 | 0.0356 |
| bcb96027_004 (1996) | 0.0354 | 0.0352 |

Where the dark region *is* the border the two agree; where the frame holds a dark lake or
deep shadow the plain threshold destroys it and the edge-connected mask keeps it. That is
the issue's real requirement ("nodata=0 loses real dark pixels").

## GDAL `nearblack -alg floodfill` is this algorithm, already reachable

`sf::gdal_utils()` dispatches `util = "nearblack"` (documented alongside info, warp,
translate...). GDAL 3.8.5 via sf on this machine supports `-alg floodfill|twopasses`,
`-near <dist>`, `-setalpha`.

`bcb90128_213_thumb.jpg` at threshold 16:

| method | mask fraction |
| --- | --- |
| plain threshold | 0.0767 |
| terra edge-connected prototype | 0.0252 |
| `nearblack -alg floodfill` | **0.0312** |
| `nearblack -alg twopasses` | 0.0303 |

Close to the prototype and far from the plain threshold. `-near` is a per-band distance
from black and `-nb` (default 2) tolerates non-black pixels in the collar, which is why
floodfill eats slightly more than a strict connected-component. **No new dependency:**
terra stays in Suggests.

## Band counts do not change - verified end to end

```
gray  1 band -> nearblack -setalpha -> 2 -> translate -of VRT (+GCPs) -> warp -srcalpha -dstnodata 0 -> 1 band out
rgb   3 band -> nearblack -setalpha -> 4 -> translate -of VRT (+GCPs) -> warp -srcalpha -dstalpha    -> 4 bands out
```

`-srcalpha` excludes the last band from the warped band list, so today's output contract
holds on both paths and nothing downstream in `stac_airphoto_bc` moves. The VRT carries
the GCPs (`<GCPList>` present), so this removes a full-size temp copy rather than adding
one.

**Measured wrinkle:** on a grayscale source `-setalpha` writes `ColorInterp=Undefined` on
band 2, not `Alpha`. RGB gets `Alpha` correctly. `-srcalpha` works either way because it
forces the last band, but nothing may key on ColorInterp for the grayscale path.

## The threshold sweep, and how not to read it

Median edge-connected mask fraction by threshold (terra prototype, 2 frames per year):

| t | 0 | 4 | 8 | 12 | 16 | 24 | 32 | 48 | 64 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| median | 0.0007 | 0.0141 | 0.0219 | 0.0247 | 0.0283 | 0.0304 | 0.0316 | 0.0369 | 0.0461 |
| max | 0.0235 | 0.0492 | 0.0512 | 0.0518 | 0.0699 | 0.0964 | 0.1437 | 0.2662 | 0.4979 |

A first reading called 12-16 a knee and 16-32 a plateau. **That is backwards** - the
smallest median increment is 24->32 (0.0012), not 16->24 (0.0021). More importantly a
median of mask *fractions* cannot distinguish a fully-removed border from a small one, so
it is the wrong calibration target entirely. Phase 0 re-cuts this **per frame**: the
threshold at which each frame's own mask stops growing, then a high quantile of that
distribution.

The t64 max of 0.4979 is a 2018 digital frame - one with *no* border at all - flooding
into scene content. That is the runaway the guard exists for.

## The guard predicate: interior fraction, not total

Total mask fraction cannot separate "a thick border" from "a lake touching the edge and
reaching the centre", and the lake is the failure the guard exists for. A genuine border
contributes ~0 to a central box by construction, so the interior fraction has a far wider
admissible band. Computable without terra: `gdal_translate -of VRT -b <alpha> -srcwin` a
central window, then `gdal_utils("info", "-stats")` and read the band mean.

## Scope limit: full-res scans are unreachable from this package

The catalogue centroid layer carries `thumbnail_image_url`, `flight_log_url`,
`camera_calibration_url`, `patb_georef_url` - and no full-resolution scan URL. Full-res
scans are licence-restricted. So #23's stated trigger cannot be fixtured, tested or
calibrated here, `nearblack`'s Byte assumption is untested against 16-bit scans, and
`-near` does not transfer to them. `fly_mask()` is exported so a user holding licensed
scans on disk has an entry point that does not go through `fly_fetch()`.

## Errors Encountered

| Error | Resolution |
| --- | --- |
| `Rscript` heredoc needed for multi-line probes; inline `-e` mangles regex backslashes | `Rscript /dev/stdin <<'EOF'` - quoted heredoc, no file written |
| Aliased `ls` emits ANSI colour codes through pipes | Use `find` for listings |
