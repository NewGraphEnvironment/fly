# Georeference airphoto images to footprint polygons

Warps images to their estimated ground footprint using GCPs (ground
control points) derived from
[`fly_footprint()`](https://newgraphenvironment.github.io/fly/reference/fly_footprint.md).
Produces georeferenced GeoTIFFs in BC Albers (EPSG:3005). Works with
thumbnails and full-resolution scans.

## Usage

``` r
fly_georef(
  fetch_result,
  photos_sf,
  dest_dir = "georef",
  overwrite = FALSE,
  srcnodata = "0",
  rotation = "auto",
  dem = NULL
)
```

## Arguments

- fetch_result:

  A tibble returned by
  [`fly_fetch()`](https://newgraphenvironment.github.io/fly/reference/fly_fetch.md),
  with columns `airp_id`, `dest`, and `success`.

- photos_sf:

  The same sf object passed to
  [`fly_fetch()`](https://newgraphenvironment.github.io/fly/reference/fly_fetch.md),
  with a `scale` column for footprint estimation. If a `rotation` column
  is present, per-photo rotation values are used (see **Rotation**
  below). Geometry must be POINT — the ground footprint is estimated
  *from* a centroid, so passing footprints back in is refused rather
  than coerced.

- dest_dir:

  Directory for output GeoTIFFs. Created if it does not exist.

- overwrite:

  If `FALSE` (default), skip files that already exist.

- srcnodata:

  Source nodata value passed to GDAL warp. Black pixels matching this
  value are treated as transparent (alpha=0 for RGB, nodata for
  grayscale). Default `"0"` masks camera frame borders and film holder
  edges at the cost of losing real black pixels — acceptable for
  thumbnails but may need adjustment for full-resolution scans. Set to
  `NULL` to disable source nodata detection entirely.

- rotation:

  Image rotation in degrees clockwise. One of `"auto"`, `0`, `90`,
  `180`, or `270`. **Applies only to frames whose footprint was drawn
  axis-aligned**, which since v0.9.0 means only frames for which no
  flight bearing could be computed — a single frame, or one whose
  neighbours are not adjacent by `frame_number`. Every frame that *was*
  rotated onto a bearing takes its mapping from the ring instead, so
  this argument does not reach it. `"auto"` (default) derives a
  90°-quantized rotation from the bearing; with the bearing now carried
  by the geometry, that formula only ever sees bearingless frames and
  returns its `NA` default of 180. A `rotation` column in `photos_sf`
  overrides everything, rotated or not — which is the supported way to
  georeference film (see **Rotation**). Carrying a film-era `rotation`
  column into a batch of digital frames overrides the correct mapping
  with the wrong one — drop the column, or set it to `NA` for those
  rows.

- dem:

  Optional elevation raster passed to
  [`fly_footprint()`](https://newgraphenvironment.github.io/fly/reference/fly_footprint.md),
  sizing each frame from its height above ground instead of the reported
  scale. See the **Terrain** section of
  [`fly_footprint()`](https://newgraphenvironment.github.io/fly/reference/fly_footprint.md).

## Value

A tibble with columns `airp_id`, `source`, `dest`, and `success`.

## Details

Each image's four corners are mapped to the corresponding footprint
polygon corners computed by
[`fly_footprint()`](https://newgraphenvironment.github.io/fly/reference/fly_footprint.md)
in BC Albers. GDAL translates the image with GCPs then warps to the
target CRS using bilinear resampling.

**Rotation:** the corner mapping depends on whether
[`fly_footprint()`](https://newgraphenvironment.github.io/fly/reference/fly_footprint.md)
rotated the ring onto a flight bearing, which `footprint_bearing`
records. It is not decidable from the geometry — a rectangle rotated
onto a due-north heading is still axis-parallel, and a square gives
nothing away at any bearing.

A **rotated non-square** footprint — a digital frame with a bearing —
uses a fixed mapping: the top-left pixel maps to the ring's rear-left
corner, so the top of the image points 270° round from the heading.
Measured in fly#38 on both bundled cameras by three independent routes,
which agree.

A **rotated square** footprint — a film frame with a bearing — is
**skipped with a warning** unless `photos_sf` carries a `rotation` value
for it. There is no constant to apply, and that is a measurement rather
than an omission. fly#26 scored all four rotations by adjacent-frame
overlap over four contiguous legs:

|         |      |         |               |        |
|---------|------|---------|---------------|--------|
| roll    | year | bearing | best rotation | margin |
| bc5282  | 1968 | 230°    | 0             | 0.089  |
| bc83062 | 1983 | 150°    | 90            | 0.135  |
| bc83062 | 1983 | 93°     | 90            | 0.196  |
| bc83062 | 1983 | 62°     | 90            | 0.152  |

bc83062 returns the same answer at three widely separated bearings, so
the mapping is genuinely flight-relative — but it is a quarter turn from
bc5282's, on the two eras fly#26 named at the outset. Applying either as
a global constant would be wrong for the other roll, and the failure it
produces is a valid GeoTIFF over the right ground with the picture
turned 90°, which nothing downstream would report. So the frame is
refused instead, as fly refuses an unknown recording format in
[`fly_footprint()`](https://newgraphenvironment.github.io/fly/reference/fly_footprint.md).

To georeference film, check one frame of the roll against known ground
and set the column:

    photos$rotation <- dplyr::case_when(
      photos$film_roll == "bc5282"  ~ 0L,    # measured, fly#26
      photos$film_roll == "bc83062" ~ 90L,   # measured, fly#26
      .default = NA                          # refused rather than guessed
    )

Every non-`NA` value in that column must be 0, 90, 180 or 270; anything
else is an error naming the value, rather than a rotation silently
applied as something other than what was written. **The column's meaning
changed in v0.9.0**: it used to shift corners on an axis-aligned square,
and now shifts them on a ring already rotated onto the bearing, so a
value calibrated by eye against an older release no longer means the
same thing and must be re-checked.

An **unrotated** footprint — no bearing could be computed — keeps the
old behaviour: axis-aligned, with `rotation` (or its `"auto"` default of
180) choosing which edge the top of the image maps to. `0` is north,
`90` east, `180` south, `270` west. It is warned about, because an
axis-aligned footprint is only correct if the flight line happened to
run cardinally.

A frame whose delivered image aspect disagrees with its footprint's by
more than 8% is **skipped with a warning** rather than written stretched
— the failure a wrong mapping produces is a valid GeoTIFF over the right
ground, squashed by the aspect ratio squared, which nothing downstream
would report. The threshold sits between the largest disagreement a
legitimate frame produces (a full-resolution 9-inch scan carrying the
negative's rebate, about 6.7%) and the smallest that must be caught (a
Leica DMC II frame sized through `format_size` onto a square footprint,
9.95%). It applies to square footprints too: a square one has no pairing
to get wrong, but a digital frame sized through `format_size` lands on
one, and that is the unknown-camera case — so gating on shape would
switch the check off exactly where it is needed.

A footprint built without a flight bearing is drawn axis-aligned and is
therefore georeferenced as though the flight line ran due north.
[`fly_bearing()`](https://newgraphenvironment.github.io/fly/reference/fly_bearing.md)
needs a frame that is **adjacent by `frame_number`** on the same roll,
so this is the ordinary result of georeferencing a single frame on its
own, or a sample of a roll rather than a contiguous run. It is warned
about, for film as well as digital.

**Nodata handling:** Two sources of unwanted black pixels are masked:

1.  **Warp fill** — GDAL creates black pixels outside the rotated source
    frame. RGB images get an alpha band (`-dstalpha`); grayscale use
    `dstnodata=0`.

2.  **Camera frame borders** — film holder edges, fiducial marks, and
    scanning artifacts produce black (value 0) pixels within the source
    image. The `srcnodata` parameter (default `"0"`) tells GDAL to treat
    these as transparent before warping.

**Tradeoff:** `srcnodata = "0"` also masks real black pixels (deep
shadows). At thumbnail resolution (~1250x1250) this is acceptable —
shadow detail is minimal. For full-resolution scans where shadow detail
matters, set `srcnodata = NULL` and handle frame masking downstream
(e.g., circle detection).

**Accuracy:** footprints assume a nadir camera angle, and without `dem`
they also assume flat terrain. Passing `dem` sizes each frame from its
height above ground, which on steep ground is the larger of the two
error terms — but the images stay approximate either way, useful for
visual context rather than survey-grade positioning. See the **Terrain**
section of
[`fly_footprint()`](https://newgraphenvironment.github.io/fly/reference/fly_footprint.md).

## Examples

``` r
centroids <- sf::st_read(system.file("testdata/photo_centroids.gpkg", package = "fly"))
#> Reading layer `photo_centroids' from data source 
#>   `/home/runner/work/_temp/Library/fly/testdata/photo_centroids.gpkg' 
#>   using driver `GPKG'
#> Simple feature collection with 20 features and 16 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: -126.7631 ymin: 54.34512 xmax: -126.449 ymax: 54.47635
#> Geodetic CRS:  WGS 84

# Frames 231 and 232 of bc5282 are adjacent, so they get a flight bearing and
# their footprints are rotated onto it. Film needs the roll's measured rotation
# supplied; without it the frames are refused rather than turned a quarter turn.
pair <- centroids[centroids$film_roll == "bc5282" &
                    centroids$frame_number %in% c(231, 232), ]
pair$rotation <- 0L   # measured for bc5282 in fly#26

fetched <- fly_fetch(pair, type = "thumbnail", dest_dir = tempdir())
#> Downloaded 2 of 2 files
georef <- fly_georef(fetched, pair, dest_dir = tempdir())
#> Georeferenced 2 of 2 images
georef
#> # A tibble: 2 × 4
#>   airp_id source                               dest                      success
#>     <int> <chr>                                <chr>                     <lgl>  
#> 1  699426 /tmp/Rtmp9zh1EE/bc5282_232_thumb.jpg /tmp/Rtmp9zh1EE/bc5282_2… TRUE   
#> 2  699425 /tmp/Rtmp9zh1EE/bc5282_231_thumb.jpg /tmp/Rtmp9zh1EE/bc5282_2… TRUE   
```
