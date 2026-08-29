# Findings — fly_footprint() assumes a 9-inch negative (#30)

## Codebase exploration (2026-08-28)

- `fly_footprint()` is called by five exported functions: `fly_filter.R:39`,
  `fly_select.R:54` and `:111`, `fly_georef.R:114`, `fly_overlap.R:26`,
  `fly_coverage.R:29`. Whatever it returns for a digital frame propagates
  through the whole package.
- Bundled `inst/testdata/photo_centroids.gpkg` is 20 rows, 100% `Film - BW`,
  focal 153, scales 1:12000 and 1:31680. No digital frames, so the digital
  fixture must be synthesized in the test file.
- `data-raw/make_testdata.R` sources `../diggs/data/l_photo_centroids.geojson`
  filtered to `photo_year == 1968` near Houston — film-only by construction.
- The bundled test data already carries `media`, `focal_length`,
  `flying_height` and `ground_sample_distance` columns, which directly
  contradicts the docstring claim at `fly_footprint.R:20`.
- `st_intersects()` against an empty geometry returns FALSE, so without
  explicit handling a digital frame disappears from `fly_filter()` results
  with no signal at all.

## GSD cannot give footprint width

Considered during planning and rejected: `ground_width = GSD x pixels_across`,
and pixel count is absent from the centroid metadata just as sensor width is.
GSD is an *identification* lever instead —
`pixel_pitch = GSD / scale_denominator` (0.10 m at 1:15000 => 6.67 um)
narrows the camera family, and `camera_calibration_url` can confirm it.
That is the route for the follow-up research issue, not for this one.

## Issue context

## Problem

`fly_footprint()` computes ground coverage from a fixed 9-inch negative:

```r
# fly_footprint.R
width <- 9 * scale * 0.0254
```

A digital frame has no negative. The BC catalogue mixes film and digital in one
layer, and the digital share is not marginal.

Measured on a single 0.15 x 0.10 degree box (680 centroids, southeast BC):

| media | n | share | focal length | GSD |
|---|---|---|---|---|
| Film - BW | 333 | 49% | 305 / 153 mm | mostly absent |
| Film - Colour | 211 | 31% | 305 / 153 mm | mostly absent |
| **Digital - Colour** | **136** | **20%** | **92 / 100 mm** | **10 cm, populated** |

The digital frames are 2011 and 2018. Two independent tells that they are a
sensor rather than film: focal lengths of 92 and 100 mm against 153 and 305 mm
for everything on film, and a populated `GROUND_SAMPLE_DISTANCE` where film
mostly has none.

For those 136 frames `fly_footprint()` returns 1600 m of width derived from a
9-inch negative that does not exist. Whether that number lands near the truth
depends on sensor width, which is not in the centroid metadata — so it cannot be
checked from here, and that is the point rather than a caveat.

## Why it matters more than the size of the error

The footprint is not decoration. It is the reason to use this package rather
than a point-in-polygon test: **a centroid outside the AOI can still have a
footprint that overlaps it**, which is what `fly_filter(method = "footprint")`
exists to catch, and what `fly_overlap()` and `fly_coverage()` are computed
from.

A wrong footprint fails silently and plausibly. It still draws as a rectangle,
still overlaps neighbours, still produces a coverage percentage. Nothing about
the output says a fifth of the frames rest on an assumption that is
definitionally false for them.

## Proposed Solution

Branch on `MEDIA`, or refuse rather than estimate.

Refusing is a legitimate outcome here: for a workflow that catalogues thumbnails
to decide what is worth buying, "no reliable footprint for this frame" is
useful, and a confidently wrong rectangle is not. A `NA` footprint with a
recorded reason beats a plausible one.

If a sensor width can be established for the digital cameras in use, the same
`width = format * scale` form works with the right format substituted. The
9-inch default stays correct for film, which is 80% of this sample and all of
the pre-1980 record.

## Also: the docstring on focal length is out of date

`fly_footprint.R:20` says:

> The BC Air Photo Database records camera focal length per roll [but] this
> field is not available in the simplified centroid data

Both fields are **100% populated** in `WHSE_IMAGERY_AND_BASE_MAPS.AIMG_PHOTO_CENTROIDS_SP`:

| field | populated |
|---|---|
| `FOCAL_LENGTH` | 680/680 |
| `FLYING_HEIGHT` | 680/680 |
| `SCALE` | 680/680 (string, `"1:15000"`) |
| `GROUND_SAMPLE_DISTANCE` | 560/680 |

That is the same metadata #10 asks for, so #10 may be closer to done than it
reads.

Note the field is `SCALE`, not `PHOTO_SCALE` — querying the latter returns all
`NULL`, which reads as missing data rather than a wrong field name.

## Related

- #10 — flight metadata from the BC Air Photo Database
- #9 — DEM-based terrain-adjusted footprints, which needs focal length and
  flying height and can now have both

