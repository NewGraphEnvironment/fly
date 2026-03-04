# Summarize photo footprint sizes and date ranges by scale

Summarize photo footprint sizes and date ranges by scale

## Usage

``` r
fly_summary(photos_sf, negative_size = 9)
```

## Arguments

- photos_sf:

  An sf point object with `scale` and `photo_year` columns.

- negative_size:

  Negative dimension in inches (default 9).

## Value

A tibble with columns: `scale`, `photos`, `footprint_m`, `half_m`,
`year_min`, `year_max`.

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
fly_summary(centroids)
#> # A tibble: 2 × 6
#>   scale   photos footprint_m half_m year_min year_max
#>   <chr>    <int>       <dbl>  <dbl>    <int>    <int>
#> 1 1:12000     10        2743   1372     1968     1968
#> 2 1:31680     10        7242   3621     1968     1968
```
