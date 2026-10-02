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
  mask = c("border", "none"),
  mask_threshold = fly_mask_threshold(),
  srcnodata = NULL,
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

- mask:

  How to handle the black collar around the exposed frame. `"border"`
  (default) masks it with
  [`fly_mask()`](https://newgraphenvironment.github.io/fly/reference/fly_mask.md);
  `"none"` warps unmasked, applying `srcnodata` to every frame as before
  v0.11.0. Output carries an alpha band either way.

- mask_threshold:

  How close to black a pixel must be to count as collar. Passed to
  [`fly_mask()`](https://newgraphenvironment.github.io/fly/reference/fly_mask.md);
  the default is measured, see there.

- srcnodata:

  Source nodata value passed to GDAL warp, matched **exactly**, or
  `NULL` (default). With `mask = "none"` it applies to every frame. With
  `mask = "border"` it is the **fallback**: it applies only to a frame
  whose mask
  [`fly_mask()`](https://newgraphenvironment.github.io/fly/reference/fly_mask.md)
  declined, and never alongside a mask that ran (see **Nodata
  handling**). On its own it is close to useless as a collar mask:
  scanned black runs 3-12, so `"0"` masked a median of 0.16% of a frame
  against the 3.11% actually there, and 128 of 264 measured frames had
  under a tenth of their collar removed.

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
  overrides everything, rotated or not, including the measured film
  table (see **Rotation**). Carrying a film-era `rotation` column into a
  batch of digital frames overrides the correct mapping with the wrong
  one — drop the column, or set it to `NA` for those rows.

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

A **rotated square** footprint — a film frame with a bearing — takes its
**roll's measured rotation**, and is **skipped with a warning** when
there is none. There is no film constant: the mapping is flight-relative
but differs between rolls, and fly#53 measured it per roll by
adjacent-frame overlap over a stratified sample of the catalogue.
`inst/extdata/film_rotations.csv` ships the 57 rolls that met the rule —
44 at 90, 11 at 270, 2 at 0 — and `film_rotations_excluded.csv` lists
every other film roll in the catalogue snapshot with the reason it is
not shipped, which the warning names. A roll in neither was added to the
catalogue since.

The shipped values fall into eras (270 for the 305 mm rolls of 1964-73,
0 for the two 153 mm rolls of 1967-68, 90 from 1974) with an exception —
bcc00116 (2000) is 270 — and three unshipped rolls each have a decisive
leg against their era too, so nothing is inferred for a roll that was
not measured. A wrong mapping writes a valid GeoTIFF over the right
ground with the picture turned a quarter or half turn, which nothing
downstream would report, so the frame is refused instead, as fly refuses
an unknown recording format in
[`fly_footprint()`](https://newgraphenvironment.github.io/fly/reference/fly_footprint.md).

For a roll the table does not cover, measure it with
[`fly_rotation_calibrate()`](https://newgraphenvironment.github.io/fly/reference/fly_rotation_calibrate.md)
and join the result, or set the column yourself after checking one frame
against known ground:

    cal <- fly_rotation_calibrate(roll)            # the roll's catalogue rows
    roll$rotation <- cal$rotation[match(roll$film_roll, cal$film_roll)]

**Precedence** for a rotated film frame: a non-`NA` `rotation` column
value, then the shipped table, then refusal. The scalar `rotation`
argument never reaches it. Values were measured on the public
thumbnails; a full-resolution scan delivered in another orientation is
not covered.

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

**Nodata handling:** two sources of unwanted black pixels, handled
separately.

1.  **Warp fill** — GDAL creates pixels outside the rotated source
    frame. Every output carries an alpha band (`-dstalpha`) marking
    them, so **grayscale is written as 2 bands and RGB as 4** for a Byte
    grayscale or RGB source. Grayscale used `-dstnodata 0` before
    v0.19.0, and GDAL kept a genuine 0 inside the frame from reading as
    fill by rewriting it as 1 — silently on sf's GDAL 3.8.5 — or, where
    `srcnodata = "0"` was also given, deleted it. A value cannot be both
    content and the fill marker.

2.  **The frame collar** — film holder edges, fiducial marks and
    chamfered corners. Since v0.11.0 this is
    [`fly_mask()`](https://newgraphenvironment.github.io/fly/reference/fly_mask.md):
    a flood fill seeded from the image border, so only darkness
    *reachable from the edge* is masked and interior dark water
    survives.

**What this replaced, and why the old paragraph here was wrong.** Until
v0.11.0 the collar was handled by `srcnodata = "0"`, documented as
masking the borders at the cost of losing real black pixels. Measured
over 264 thumbnails, **both halves were false**: exact-zero matching
removed a median of 0.16% of a frame where 3.11% of collar was present,
so it did not mask the borders — and the real black it was said to cost
is a median 0.16% of the frame, which *is* the collar rather than
shadow.

**`srcnodata` with `mask = "border"` is a per-frame fallback, never a
second mask.**
[`fly_mask()`](https://newgraphenvironment.github.io/fly/reference/fly_mask.md)
declines some frames — among them an unreadable or non-8-bit source, and
a mask that floods into the interior;
[`fly_mask()`](https://newgraphenvironment.github.io/fly/reference/fly_mask.md)'s
`reason` column lists every path — and a declined frame is warped
unmasked. Given no `srcnodata`, its collar is written as opaque data.
Given one, the declined frame is warped with `-srcnodata` and every
masked frame with `-srcalpha` alone. The two are never handed to GDAL
together, because GDAL would apply both and the mask would lose: on a
synthetic frame carrying an 11x11 block of true black, adding
`-srcnodata "0 0 0"` to the masked warp removed exactly those 121
pixels. Before v0.19.0 this pair was refused on the premise that both
reached GDAL; they never did.

"Declined" means
[`fly_mask()`](https://newgraphenvironment.github.io/fly/reference/fly_mask.md)
returned `masked = FALSE`; an error inside it fails the frame instead. A
declined frame given no `srcnodata` is warned about, since its collar
reaches the output as data. The fallback is a weak last resort: it
matches **exact** values only, so it catches a collar written at exactly
0 and misses one scanned at 3-12, and on the frame it reaches it also
removes any true black inside the frame. On all 10,105 public thumbnails
measured (the 264 `mask_threshold` was calibrated on among them), the
mask declined none.

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
# their footprints are rotated onto it. bc5282 is a measured roll, so its
# rotation comes from the shipped table; an unmeasured roll would be refused.
pair <- centroids[centroids$film_roll == "bc5282" &
                    centroids$frame_number %in% c(231, 232), ]

fetched <- fly_fetch(pair, type = "thumbnail", dest_dir = tempdir())
#> Downloaded 2 of 2 files
georef <- fly_georef(fetched, pair, dest_dir = tempdir())
#> Georeferenced 2 of 2 images
georef
#> # A tibble: 2 × 4
#>   airp_id source                               dest                      success
#>     <int> <chr>                                <chr>                     <lgl>  
#> 1  699426 /tmp/Rtmp0zZnKt/bc5282_232_thumb.jpg /tmp/Rtmp0zZnKt/bc5282_2… TRUE   
#> 2  699425 /tmp/Rtmp0zZnKt/bc5282_231_thumb.jpg /tmp/Rtmp0zZnKt/bc5282_2… TRUE   
```
