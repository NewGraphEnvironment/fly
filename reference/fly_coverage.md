# Check photo coverage of an AOI by group

Builds footprint polygons for each photo, intersects with the AOI, and
reports percent coverage grouped by a column.

## Usage

``` r
fly_coverage(photos_sf, aoi_sf, by = "photo_year")
```

## Arguments

- photos_sf:

  An sf point object with a `scale` column.

- aoi_sf:

  An sf polygon to check coverage against.

- by:

  Column name to group by (default `"photo_year"`).

## Value

A tibble with the grouping column, `n_photos`, `covered_km2`, and
`coverage_pct`.

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
fly_coverage(centroids, aoi, by = "scale")
#> Spherical geometry (s2) switched off
#> Spherical geometry (s2) switched on
#> # A tibble: 2 × 4
#>   scale   n_photos covered_km2 coverage_pct
#>   <chr>      <int>       <dbl>        <dbl>
#> 1 1:12000       10        15.1         60.7
#> 2 1:31680       10        24.8        100  
```
