# Compute pairwise overlap between photo footprints

For each pair of photos whose footprints intersect, computes the overlap
area and the percentage of each photo's footprint that overlaps. Most
useful on same-scale photos from the same flight.

## Usage

``` r
fly_overlap(photos_sf)
```

## Arguments

- photos_sf:

  An sf point object with a `scale` column.

## Value

A tibble with columns `photo_a`, `photo_b`, `overlap_km2`, `pct_of_a`,
and `pct_of_b`. Only pairs with non-zero overlap are returned.

## Details

Overlap percentages are estimates based on flat-terrain footprints from
[`fly_footprint()`](https://newgraphenvironment.github.io/fly/reference/fly_footprint.md).
See that function for details on terrain limitations.

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
photos_12k <- centroids[centroids$scale == "1:12000", ]
selected <- fly_select(photos_12k, aoi, mode = "all")
#> Spherical geometry (s2) switched off
#> although coordinates are longitude/latitude, st_union assumes that they are
#> planar
#> although coordinates are longitude/latitude, st_intersects assumes that they
#> are planar
#> Selected 10 of 10 photos intersecting the AOI
#> Spherical geometry (s2) switched on
fly_overlap(selected)
#> Spherical geometry (s2) switched off
#> Spherical geometry (s2) switched on
#> # A tibble: 7 × 5
#>   photo_a photo_b overlap_km2 pct_of_a pct_of_b
#>     <int>   <int>       <dbl>    <dbl>    <dbl>
#> 1  699370  699365       2.05      27.2     27.2
#> 2  699370  699373       0.134      1.8      1.8
#> 3  699426  699425       3.92      52.1     52.1
#> 4  699396  699393       0.246      3.3      3.3
#> 5  699396  699421       1.5       19.9     19.9
#> 6  699419  699421       1.46      19.4     19.4
#> 7  699425  699393       0.676      9        9  
```
