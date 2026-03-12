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
  rotation = "auto"
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
  `180`, or `270`. `"auto"` (default) computes flight line bearing from
  consecutive centroids and derives rotation per-photo — requires
  `film_roll` and `frame_number` columns. Fixed values apply the same
  rotation to all photos. Overridden per-photo if `photos_sf` contains a
  `rotation` column.

## Value

A tibble with columns `airp_id`, `source`, `dest`, and `success`.

## Details

Each image's four corners are mapped to the corresponding footprint
polygon corners computed by
[`fly_footprint()`](https://newgraphenvironment.github.io/fly/reference/fly_footprint.md)
in BC Albers. GDAL translates the image with GCPs then warps to the
target CRS using bilinear resampling.

**Rotation:** Aerial photos may appear rotated in their footprints
because the camera orientation relative to north varies by flight
direction, camera mounting, and scanner orientation. The `rotation`
parameter rotates the GCP corner mapping:

- `0` — top of image maps to north edge of footprint (original behavior)

- `90` — top of image maps to east edge (90° clockwise)

- `180` — top of image maps to south edge (default, correct for most BC
  photos)

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
      .default = NA  # fall through to auto
    )

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

**Accuracy:** footprints assume flat terrain and nadir camera angle. The
georeferenced images are approximate — useful for visual context, not
survey-grade positioning. See
[`fly_footprint()`](https://newgraphenvironment.github.io/fly/reference/fly_footprint.md)
for details on limitations.

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
#> 1  699370 /tmp/RtmpiMMGjz/bc5282_176_thumb.jpg /tmp/RtmpiMMGjz/bc5282_1… TRUE   
#> 2  699415 /tmp/RtmpiMMGjz/bc5282_221_thumb.jpg /tmp/RtmpiMMGjz/bc5282_2… TRUE   
```
