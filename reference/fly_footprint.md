# Estimate photo footprint polygons from centroids and scale

Creates rectangular polygons representing the estimated ground coverage
of each airphoto, based on film negative dimensions and the reported
scale.

## Usage

``` r
fly_footprint(centroids_sf, negative_size = 9, format_size = NULL)
```

## Arguments

- centroids_sf:

  An sf point object with a `scale` column (e.g. "1:31680"). A `media`
  column (e.g. `"Film - BW"`, `"Digital - Colour"`) selects the
  recording format per frame when present.

- negative_size:

  Negative dimension in inches (default 9 for standard 9" x 9"). Applies
  to film frames, and to every frame when there is no `media` column. It
  never sizes a digital frame — see `format_size`.

- format_size:

  Named numeric vector of recording-format widths in inches, keyed by
  `media` value, merged over the shipped film defaults. Supply this to
  size frames whose format `fly` does not know — see Details.

## Value

An sf polygon object in the same CRS as input, with footprint rectangles
and a `footprint_basis` column recording how each was sized. Frames
whose format could not be resolved get an empty geometry.

## Details

Ground coverage is computed as `negative_size * scale_number * 0.0254`
metres per side. Rectangles are constructed in BC Albers (EPSG:3005) for
accurate metric distances, then transformed back to the input CRS.

The scale denominator is parsed from the `scale` column string (e.g.
`"1:12000"` becomes `12000`).

**Film and digital are not the same measurement.** The 9-inch default
reflects the standard 228 mm negative used by BC aerial survey cameras
(e.g. Wild RC-10, Zeiss RMK). A digital frame has no negative, and the
catalogue mixes the two in one layer — roughly a fifth of frames in a
sampled area are `Digital - Colour`. Ground width scales with the
recording format, so applying a negative dimension to a sensor produces
a rectangle that is wrong by an unknown factor while still drawing,
still overlapping neighbours, and still yielding a coverage percentage.

Each row is therefore sized from its `media` value, and
`footprint_basis` records the outcome:

- the `media` value:

  format resolved from the format table

- `"assumed_default"`:

  no `media` column; `negative_size` applied

- `"unknown_format"`:

  `media` present but unknown; empty geometry

Shipped defaults cover film only. Digital frames resolve to
`"unknown_format"` rather than an invented number, because the sensor
width they would need is not in the centroid metadata — and neither is
the pixel count that would let `ground_sample_distance` stand in for it.
Supply `format_size` if you know the camera:

    fly_footprint(photos, format_size = c("Digital - Colour" = 3.54))

Filter on `footprint_basis` to keep only frames sized from a known
format.

**Focal length and flying height are available.** `FOCAL_LENGTH`,
`FLYING_HEIGHT` and `SCALE` are fully populated in
`WHSE_IMAGERY_AND_BASE_MAPS.AIMG_PHOTO_CENTROIDS_SP` and carried through
to the bundled test data. Note the field is `SCALE`, not `PHOTO_SCALE` —
the latter returns all `NULL`, which reads as missing data rather than a
wrong field name.

**Flat-terrain assumption:** footprints are estimated assuming flat
ground beneath the aircraft. In reality terrain slope changes the actual
ground coverage — downhill slopes increase the true footprint (ground
falls away from the camera), while uphill slopes reduce it. In steep
terrain typical of BC valleys, true footprints may differ meaningfully
from these estimates. Coverage and overlap calculations downstream (e.g.
[`fly_coverage()`](https://newgraphenvironment.github.io/fly/reference/fly_coverage.md),
[`fly_overlap()`](https://newgraphenvironment.github.io/fly/reference/fly_overlap.md))
inherit this limitation.

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
footprints <- fly_footprint(centroids)
plot(sf::st_geometry(footprints))


# How each footprint was sized
table(footprints$footprint_basis)
#> 
#> Film - BW 
#>        20 

# Keep only frames sized from a known recording format
sized <- footprints[footprints$footprint_basis != "unknown_format", ]
nrow(sized)
#> [1] 20
```
