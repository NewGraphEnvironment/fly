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
  below).

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
  `180`, or `270`. Applies to frames with a **square** footprint only.
  `"auto"` (default) computes flight line bearing from consecutive
  centroids and derives rotation per-photo — requires `film_roll` and
  `frame_number` columns. Fixed values apply the same rotation to every
  square-footprint photo. A non-square footprint ignores this argument
  and uses the measured digital mapping (see **Rotation**); a `rotation`
  column in `photos_sf` still overrides per-photo, for both. Carrying a
  film-era `rotation` column into a batch of digital frames therefore
  overrides the correct mapping with the wrong one — drop the column, or
  set it to `NA` for those rows.

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

**Rotation:** the corner mapping depends on the footprint's shape,
because
[`fly_footprint()`](https://newgraphenvironment.github.io/fly/reference/fly_footprint.md)
builds the two shapes differently.

A **square** footprint is axis-aligned, so the mapping carries the
rotation. The `rotation` parameter rotates it:

- `0` — top of image maps to north edge of footprint

- `90` — top of image maps to east edge (90° clockwise)

- `180` — top of image maps to south edge (correct for most BC film)

- `270` — top of image maps to west edge

When `rotation = "auto"`, the bearing-to-rotation formula is:
`floor((bearing + 91) / 90) * 90 %% 360`. This was calibrated on BC
aerial photos spanning 1968–2019 across multiple camera systems and
scanners. Photos on diagonal flight lines (~45° off cardinal) may be
imperfect — check visually and override with a `rotation` column if
needed.

Within a film roll, consecutive flight legs alternate direction
(back-and-forth pattern), so different frames on the same roll may need
different rotations. This is why `"auto"` computes per-photo, not
per-roll. To override, add a `rotation` column to `photos_sf`:

    photos$rotation <- dplyr::case_when(
      photos$film_roll == "bc5282" ~ 270,
      .default = NA  # non-square footprints fall through to the digital mapping;
                     # square ones to `rotation`, which is 180 under "auto" —
                     # NOT back to the per-photo bearing
    )

Every non-`NA` value in that column must be 0, 90, 180 or 270; anything
else is an error naming the value, rather than a rotation silently
applied as something other than what was written.

A **non-square** footprint — every digital frame — is already rotated
onto its flight line by
[`fly_footprint()`](https://newgraphenvironment.github.io/fly/reference/fly_footprint.md),
so the ring carries the bearing and applying it again would count it
twice. Those frames use a fixed mapping instead: the top-left pixel maps
to the ring's rear-left corner, equivalently image columns run in the
flight direction and image rows run flight-right. That was measured in
fly#38 on both bundled cameras by three independent routes and is the
same for each; see `inst/notes/georeferencing.md`.

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

A non-square footprint built without a flight bearing is drawn
axis-aligned and is therefore georeferenced as though the flight line
ran due north.
[`fly_bearing()`](https://newgraphenvironment.github.io/fly/reference/fly_bearing.md)
needs a neighbouring frame, so this is the ordinary result of
georeferencing a single frame on its own, and it is warned about.

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

# Fetch and georeference with auto rotation (uses bearing from centroids)
fetched <- fly_fetch(centroids[1:2, ], type = "thumbnail",
                     dest_dir = tempdir())
#> Downloaded 2 of 2 files
georef <- fly_georef(fetched, centroids[1:2, ],
                     dest_dir = tempdir())
#> Georeferenced 2 of 2 images
georef
#> # A tibble: 2 × 4
#>   airp_id source                               dest                      success
#>     <int> <chr>                                <chr>                     <lgl>  
#> 1  699370 /tmp/RtmpdB1Kwl/bc5282_176_thumb.jpg /tmp/RtmpdB1Kwl/bc5282_1… TRUE   
#> 2  699415 /tmp/RtmpdB1Kwl/bc5282_221_thumb.jpg /tmp/RtmpdB1Kwl/bc5282_2… TRUE   
```
