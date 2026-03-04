# Filter photos by spatial relationship with an AOI

Subsets photos whose footprint or centroid intersects the area of
interest. The footprint method catches photos whose centroid falls
outside the AOI but whose ground coverage overlaps it.

## Usage

``` r
fly_filter(photos_sf, aoi_sf, method = c("footprint", "centroid"), buffer = 0)
```

## Arguments

- photos_sf:

  An sf point object with a `scale` column.

- aoi_sf:

  An sf polygon defining the area of interest.

- method:

  One of `"footprint"` (default) or `"centroid"`.

- buffer:

  Buffer distance in metres added to the AOI before testing intersection
  (default 0). Applied in BC Albers (EPSG:3005).

## Value

A subset of `photos_sf` that intersects the AOI.

## Examples

``` r
centroids <- sf::st_read(system.file("testdata/photo_centroids.gpkg", package = "fly"))
#> Reading layer `photo_centroids' from data source 
#>   `/home/runner/work/_temp/Library/fly/testdata/photo_centroids.gpkg' 
#>   using driver `GPKG'
#> Simple feature collection with 20 features and 9 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: -126.7631 ymin: 54.34512 xmax: -126.449 ymax: 54.47635
#> Geodetic CRS:  WGS 84
aoi <- sf::st_read(system.file("testdata/aoi.gpkg", package = "fly"))
#> Reading layer `aoi' from data source 
#>   `/home/runner/work/_temp/Library/fly/testdata/aoi.gpkg' using driver `GPKG'
#> Simple feature collection with 1 feature and 0 fields
#> Geometry type: MULTIPOLYGON
#> Dimension:     XY
#> Bounding box:  xmin: -126.75 ymin: 54.34813 xmax: -126.45 ymax: 54.47
#> Geodetic CRS:  WGS 84
# Footprint method finds more photos than centroid method
fp_result <- fly_filter(centroids, aoi, method = "footprint")
ct_result <- fly_filter(centroids, aoi, method = "centroid")
nrow(fp_result) >= nrow(ct_result)
#> [1] TRUE
```
