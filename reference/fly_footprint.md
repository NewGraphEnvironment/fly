# Estimate photo footprint polygons from centroids and scale

Creates rectangular polygons representing the estimated ground coverage
of each airphoto, based on film negative dimensions and the reported
scale.

## Usage

``` r
fly_footprint(centroids_sf, negative_size = 9, format_size = NULL, dem = NULL)
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
  `media` value, merged over the shipped film defaults. Frames it names
  are sized from the reported `scale`, as film is, and it takes
  precedence over the shipped camera table — it is the escape hatch for
  a camera `fly` does not know. See Details.

- dem:

  Optional elevation raster used to size each frame from its true height
  above ground rather than the reported scale. A
  [`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html),
  a file path, or a `/vsicurl/` URL. Requires `flying_height` and
  `focal_length` columns, and the `terra` package. `NULL` (default)
  keeps the flat-terrain behaviour — see **Terrain** below.

## Value

An sf polygon object in the same CRS as input, with footprint
rectangles, a `footprint_basis` column recording how each was sized, a
`footprint_terrain` column recording which terrain treatment was
applied, `height_agl` giving the metres above ground each footprint was
sized from, and `dem_coverage` giving the fraction of each footprint the
DEM actually covered (`0` where it covered none, `NA` only where there
is no footprint). Frames whose format could not be resolved get an empty
geometry. Every class the input carries is carried through, so a
tibble-backed sf — which is what `bcdata::collect()` returns — comes
back tibble-backed. The order is not preserved:
[`sf::st_transform()`](https://r-spatial.github.io/sf/reference/st_transform.html)
moves `sf` to the front, so a `bcdc_sf` input returns
`sf, bcdc_sf, ...`, as it always has.

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

- `"inferred_format"`:

  digital frame with no calibration, sized from a format inferred from
  its `focal_length`

- `"assumed_default"`:

  no `media` column; `negative_size` applied

- `"unknown_format"`:

  `media` present but unknown; empty geometry

## Digital frames

A digital frame has no negative, and the catalogue mixes film and
digital in one layer — 223,667 of 1,670,471 frames province-wide are
`Digital - Colour`. Sensor dimensions are not in the centroid metadata,
but they are recoverable from the calibration report each frame links to
through `camera_calibration_url`, and `fly` ships them
(`inst/extdata/camera_formats.csv`, built by
`data-raw/make_camera_formats.R`).

Digital frames are sized as `pixel count x ground_sample_distance`,
which needs neither `scale` nor a DEM. **`scale` is never used for a
digital frame `fly` sized itself.** That field is not the true image
scale for digital: measured against terrain on 40 UltraCam Eagle frames
it gives 34% of true width, because it is a derived nominal figure — the
pixel pitch it implies is about 12.5 um for every camera regardless of
model, against real pitches of 3.9 to 12 um. `ground_sample_distance` is
in centimetres.

Where a frame carries no `camera_calibration_url` — about a fifth of
digital frames — the format is inferred from `focal_length` and
`footprint_basis` records `"inferred_format"`. Sensor width spreads only
1-3% at a given focal length, but pixel count spreads 32-83%, so an
inferred frame can only be sized through a DEM
(`width x height above ground / focal length`) and never from its GSD.

`width_source` names the calibration file or fallback rule per row, so
every footprint traces back to a source. Calibrations that could not be
corroborated are listed in `inst/extdata/camera_formats_excluded.csv`
with the reason, and frames naming one are refused rather than inferred.

**Digital footprints are not square** — sensors run from 1.10:1 (Leica
DMC II) to 1.80:1 (Intergraph DMC) — so they are rotated onto the flight
line using
[`fly_bearing()`](https://newgraphenvironment.github.io/fly/reference/fly_bearing.md).
Where no bearing can be computed the rectangle stays axis-aligned and
`width_source` says so. Film stays square and is unaffected.

Supply `format_size` to size a frame `fly` cannot, or to override it:

    fly_footprint(photos, format_size = c("Digital - Colour" = 3.54))

Filter on `footprint_basis` to keep only frames sized from a known
format.

**Focal length and flying height are available.** `FOCAL_LENGTH`,
`FLYING_HEIGHT` and `SCALE` are fully populated in
`WHSE_IMAGERY_AND_BASE_MAPS.AIMG_PHOTO_CENTROIDS_SP` and carried through
to the bundled test data. Note the field is `SCALE`, not `PHOTO_SCALE` —
the latter returns all `NULL`, which reads as missing data rather than a
wrong field name.

## Terrain

Without `dem`, footprints are sized from the reported scale, which
assumes flat ground at whatever elevation the scale was computed for.
That assumption costs more than it looks: on the bundled Upper Bulkley
AOI the reported scale **understates footprint area by a median 14%,
ranging to 26%** — and always in the same direction, because the scale
is referenced to an elevation above the valley floor the photos actually
cover.

Supplying `dem` removes that bias. `FLYING_HEIGHT` is metres above sea
level, not height above ground, so subtracting terrain elevation is what
turns it into the height ground coverage actually scales with:

    height above ground = flying_height - terrain elevation
    ground width        = format width * (height above ground / focal length)

Elevation is the **mean under the whole footprint**, not a reading at
the centroid — on a 7.2 km wide 1:31680 frame the two differ by up to
140 m. That is measured in two passes, because the footprint being
averaged over is itself what the correction changes: the first pass
averages over the nominal-scale rectangle, the second over the rectangle
the first produced. The second pass is a refinement rather than the
substance — it moves area by at most 0.5% against the correction's own
14% — and a third moves it by 0.03%, so two is where this settles.

`footprint_terrain` records what happened to each frame:

- `"nominal_scale"`:

  sized from the reported scale (no `dem`, or a fallback — see below)

- `"gsd_scaled"`:

  digital frame sized from its pixel count and ground sample distance;
  used neither the reported scale nor a DEM, so `height_agl` and
  `dem_coverage` are `NA`

- `"dem_agl"`:

  sized from height above ground

- `"no_dem_coverage"`:

  `dem` supplied but does not cover the frame

- `NA`:

  no footprint to place — see `footprint_basis`

A frame the DEM cannot correct falls back to nominal scale with a
warning, rather than being dropped. The same applies where the DEM puts
terrain at or above the aircraft, which means `flying_height` is not in
metres ASL.

**Still assumed, with or without a DEM:** the camera points straight
down. The BC catalogue carries no tilt, roll or crab, so footprints stay
axis-aligned rectangles and corner rays are not projected individually.
On this AOI that per-corner refinement is worth roughly 2%, against the
14% the DEM addresses.

**DEM sources.** Any raster `terra` can open works. Three that suit BC:

- **MRDEM-30** — NRCan's 30 m bare-earth DTM, all of Canada, public and
  unauthenticated. A good default, and what the bundled `dem.tif` is cut
  from:
  `/vsicurl/https://canelevation-dem.s3.ca-central-1.amazonaws.com/mrdem-30/mrdem-30-dtm.tif`

- **LidarBC** — sub-10 m where coverage exists; query the `stac-dem-bc`
  STAC catalogue and pass an item's COG URL.

- **BC TRIM** — 25 m provincial DEM via the `bcdata` CLI
  (`bcdata get-dem`).

Resolution matters less here than extent. A 30 m DEM resolves a 2.7 km
footprint's mean elevation perfectly well; a DEM that stops short of the
frame edges does not, and this is the ordinary failure rather than an
exotic one — a DEM cropped to an AOI simply stops. `no_dem_coverage` is
reached only when a footprint finds no elevation at all. A footprint
that is merely truncated is still corrected, from the mean of the part
the DEM described, and warns once that falls below 95%. `dem_coverage`
reports the fraction per frame — measured against the cells the
footprint should have covered, not the cells that came back — so a
truncated footprint can be filtered rather than merely noticed.

Buffer past the **corner** of the widest footprint, not its half-side:
the far point of a square is `half_side * sqrt(2)`, which at 1:31680 is
5.1 km rather than 3.6 km. Allow more again for the correction itself,
which enlarges footprints before the second pass samples them.

Coverage and overlap downstream (e.g.
[`fly_coverage()`](https://newgraphenvironment.github.io/fly/reference/fly_coverage.md),
[`fly_overlap()`](https://newgraphenvironment.github.io/fly/reference/fly_overlap.md))
accept the same `dem` argument and inherit whichever basis you give
them.

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

# Terrain-adjusted: size each frame from its height above ground instead of
# the reported scale. On this AOI every footprint grows, by a median 14%.
# terra is Suggests-only, so the DEM path is guarded here.
if (requireNamespace("terra", quietly = TRUE)) {
  terrain <- fly_footprint(
    centroids,
    dem = system.file("testdata/dem.tif", package = "fly")
  )
  print(round(100 * (as.numeric(sf::st_area(sf::st_transform(terrain, 3005))) /
    as.numeric(sf::st_area(sf::st_transform(footprints, 3005))) - 1), 1))
  print(table(terrain$footprint_terrain))
}
#>  [1] 16.9 11.1 15.4  4.9  0.5 13.4 14.1  2.1 18.1 12.8 16.1 16.0 15.0 11.0  9.0
#> [16] 26.4  6.2  9.1 16.4 15.5
#> 
#> dem_agl 
#>      20 
```
