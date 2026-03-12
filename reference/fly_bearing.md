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

  An sf object with `film_roll` and `frame_number` columns. Projected to
  BC Albers (EPSG:3005) internally for metric bearing computation.

## Value

The input sf object with an added `bearing` column (degrees clockwise
from north, 0–360). Photos with no computable bearing (single-frame
rolls) get `NA`.

## Details

Within each roll, frames are sorted by `frame_number`. The bearing for
each frame is the azimuth to the next frame on the same roll. The last
frame on each roll gets the bearing from the previous frame.

Aerial survey flights follow back-and-forth patterns, so bearings
alternate between ~opposite directions (e.g., 90° and 270°) on
consecutive legs. Large frame number gaps may indicate a new flight line
within the same roll.

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
#>    film_roll frame_number   bearing                       geom
#> 1     bc5282          176 318.20176  POINT (-126.7091 54.3727)
#> 2     bc5282          221 231.59103 POINT (-126.4879 54.47635)
#> 3     bc5282          232 229.96917 POINT (-126.6292 54.40794)
#> 4     bc5282          202  69.25748 POINT (-126.5869 54.45413)
#> 5     bc5282          171 226.53892 POINT (-126.6885 54.38426)
#> 6     bc5282          225 229.97709   POINT (-126.54 54.45206)
#> 7     bc5282          231 229.96917 POINT (-126.6165 54.41424)
#> 8     bc5282          199  50.54281  POINT (-126.624 54.43612)
#> 9     bc5282          179  59.79819 POINT (-126.7438 54.39477)
#> 10    bc5282          227 230.03240 POINT (-126.5655 54.43945)
```
