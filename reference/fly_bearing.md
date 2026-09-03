# Compute flight line bearing from consecutive airphoto centroids

Estimates the flight direction for each photo by computing the azimuth
between consecutive centroids on the same film roll, sorted by frame
number. Useful for diagnosing image rotation issues in
[`fly_georef()`](https://newgraphenvironment.github.io/fly/reference/fly_georef.md).

## Usage

``` r
fly_bearing(photos_sf)
```

## Arguments

- photos_sf:

  An sf point object with `film_roll` and `frame_number` columns.
  Projected to BC Albers (EPSG:3005) internally for metric bearing
  computation. Geometry must be POINT. Handed footprints this returned
  the right *number* of bearings with the wrong values, so it is refused
  rather than coerced.

## Value

The input sf object with an added `bearing` column (degrees clockwise
from north, 0–360). Photos with no **adjacent** frame on the same roll
get `NA` — a single-frame roll, and any frame whose neighbours in the
supplied object are more than one frame number away.

## Details

Within each roll, frames are sorted by `frame_number`. The bearing for
each frame is the azimuth to the next frame on the same roll, and the
last frame of an adjacent run takes the bearing from the previous one.

**The neighbour must be adjacent by frame number.** Aerial survey
flights follow back-and-forth patterns, so a roll holds several legs;
two frames that merely sit next to each other in a *sample* of a roll
may be on different legs, and the azimuth between those is a cross-leg
artefact rather than a heading. In the bundled test data, bc5282 frames
179 and 199 are 20 apart and 3.3 footprint-sides apart, and pairing them
gives 59.8° on a roll that flies about 230°.

So a gap of more than one frame yields `NA`. This is deliberately
strict: adjacency is demonstrable, whereas "close enough to be on the
same line" needs a threshold in footprint-sides that this function
cannot measure. Since
[`fly_footprint()`](https://newgraphenvironment.github.io/fly/reference/fly_footprint.md)
rotates a footprint onto this bearing, an `NA` costs an axis-aligned
rectangle while a wrong azimuth costs a rectangle confidently rotated
onto ground the frame does not cover.

To keep bearings across a subset, call `fly_bearing()` on the contiguous
roll first and carry the column: subsetting removes neighbours, and a
frame whose neighbour was dropped has no adjacent one left.

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
with_bearing <- fly_bearing(centroids)
with_bearing[, c("film_roll", "frame_number", "bearing")]
#> Simple feature collection with 20 features and 3 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: -126.7631 ymin: 54.34512 xmax: -126.449 ymax: 54.47635
#> Geodetic CRS:  WGS 84
#> First 10 features:
#>    film_roll frame_number  bearing                       geom
#> 1     bc5282          176       NA  POINT (-126.7091 54.3727)
#> 2     bc5282          221       NA POINT (-126.4879 54.47635)
#> 3     bc5282          232 229.9692 POINT (-126.6292 54.40794)
#> 4     bc5282          202       NA POINT (-126.5869 54.45413)
#> 5     bc5282          171       NA POINT (-126.6885 54.38426)
#> 6     bc5282          225       NA   POINT (-126.54 54.45206)
#> 7     bc5282          231 229.9692 POINT (-126.6165 54.41424)
#> 8     bc5282          199       NA  POINT (-126.624 54.43612)
#> 9     bc5282          179       NA POINT (-126.7438 54.39477)
#> 10    bc5282          227       NA POINT (-126.5655 54.43945)
```
