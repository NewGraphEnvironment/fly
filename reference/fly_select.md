# Select photos covering an AOI

Two modes: `"minimal"` picks the fewest photos to reach target coverage
(greedy set-cover); `"all"` returns every photo whose footprint
intersects the AOI.

## Usage

``` r
fly_select(
  photos_sf,
  aoi_sf,
  mode = "minimal",
  target_coverage = 0.95,
  component_ensure = FALSE
)
```

## Arguments

- photos_sf:

  An sf point object with a `scale` column (pre-filtered to target
  year/scale).

- aoi_sf:

  An sf polygon to cover.

- mode:

  Either `"minimal"` (fewest photos to reach target) or `"all"` (every
  photo touching the AOI).

- target_coverage:

  Stop when this fraction is reached (default 0.95). Only used when
  `mode = "minimal"`.

- component_ensure:

  If `TRUE` (default `FALSE`), guarantee that every polygon component of
  `aoi_sf` is covered by at least one photo before running the greedy
  selection. Useful for multi-polygon AOIs (e.g. patchy floodplain
  fragments) where small components might otherwise get zero coverage.
  Only used when `mode = "minimal"`.

## Value

An sf object (subset of `photos_sf`). For `mode = "minimal"`, includes
`selection_order` and `cumulative_coverage_pct` columns.

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

# Fewest photos to reach 80% coverage
fly_select(centroids, aoi, mode = "minimal", target_coverage = 0.80)
#> Spherical geometry (s2) switched off
#> Selecting photos (target: 80% coverage)...
#>   3 photos -> 81.6% coverage
#> Selected 3 of 20 photos for 81.6% coverage
#> Spherical geometry (s2) switched on
#> Simple feature collection with 3 features and 11 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: -126.6796 ymin: 54.41035 xmax: -126.5269 ymax: 54.46049
#> Geodetic CRS:  WGS 84
#>    airp_id photo_year photo_date   scale film_roll frame_number     media
#> 11  697358       1968 1968-07-31 1:31680    bc5306           89 Film - BW
#> 20  697329       1968 1968-07-31 1:31680    bc5306           60 Film - BW
#> 12  697292       1968 1968-07-31 1:31680    bc5306           23 Film - BW
#>     photo_tag nts_tile                       geom selection_order
#> 11 bc5306_089   093L07 POINT (-126.6796 54.41035)               1
#> 20 bc5306_060   093L07 POINT (-126.6039 54.42617)               2
#> 12 bc5306_023   093L07 POINT (-126.5269 54.46049)               3
#>    cumulative_coverage_pct
#> 11                    41.0
#> 20                    66.5
#> 12                    81.6

# Ensure every AOI component gets at least one photo
fly_select(centroids, aoi, mode = "minimal", target_coverage = 0.80,
           component_ensure = TRUE)
#> Spherical geometry (s2) switched off
#> Seeding 9 photos for component coverage...
#>   9 seed photos -> 78% coverage
#> Selecting photos (target: 80% coverage)...
#>   10 photos -> 90.1% coverage
#> Selected 10 of 20 photos for 90.1% coverage
#> Spherical geometry (s2) switched on
#> Simple feature collection with 10 features and 11 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: -126.6796 ymin: 54.34512 xmax: -126.449 ymax: 54.46049
#> Geodetic CRS:  WGS 84
#>    airp_id photo_year photo_date   scale film_roll frame_number     media
#> 18  697326       1968 1968-07-31 1:31680    bc5306           57 Film - BW
#> 11  697358       1968 1968-07-31 1:31680    bc5306           89 Film - BW
#> 13  697293       1968 1968-07-31 1:31680    bc5306           24 Film - BW
#> 10  699421       1968 1968-05-10 1:12000    bc5282          227 Film - BW
#> 4   699396       1968 1968-05-10 1:12000    bc5282          202 Film - BW
#> 17  697295       1968 1968-07-31 1:31680    bc5306           26 Film - BW
#> 15  696206       1968 1968-07-31 1:31680    bc5300          236 Film - BW
#> 12  697292       1968 1968-07-31 1:31680    bc5306           23 Film - BW
#> 6   699419       1968 1968-05-10 1:12000    bc5282          225 Film - BW
#> 20  697329       1968 1968-07-31 1:31680    bc5306           60 Film - BW
#>     photo_tag nts_tile                       geom selection_order
#> 18 bc5306_057   093L07 POINT (-126.6025 54.34512)               1
#> 11 bc5306_089   093L07 POINT (-126.6796 54.41035)               2
#> 13 bc5306_024   093L07 POINT (-126.5269 54.43578)               3
#> 10 bc5282_227   093L07 POINT (-126.5655 54.43945)               4
#> 4  bc5282_202   093L07 POINT (-126.5869 54.45413)               5
#> 17 bc5306_026   093L07 POINT (-126.5262 54.38554)               6
#> 15 bc5300_236   093L08  POINT (-126.449 54.41519)               7
#> 12 bc5306_023   093L07 POINT (-126.5269 54.46049)               8
#> 6  bc5282_225   093L07   POINT (-126.54 54.45206)               9
#> 20 bc5306_060   093L07 POINT (-126.6039 54.42617)              10
#>    cumulative_coverage_pct
#> 18                     3.6
#> 11                    44.6
#> 13                    68.9
#> 10                    70.3
#> 4                     72.2
#> 17                    74.8
#> 15                    76.6
#> 12                    78.0
#> 6                     78.0
#> 20                    90.1

# All photos touching the AOI
fly_select(centroids, aoi, mode = "all")
#> Spherical geometry (s2) switched off
#> although coordinates are longitude/latitude, st_union assumes that they are
#> planar
#> although coordinates are longitude/latitude, st_intersects assumes that they
#> are planar
#> Selected 20 of 20 photos intersecting the AOI
#> Spherical geometry (s2) switched on
#> Simple feature collection with 20 features and 9 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: -126.7631 ymin: 54.34512 xmax: -126.449 ymax: 54.47635
#> Geodetic CRS:  WGS 84
#> First 10 features:
#>    airp_id photo_year photo_date   scale film_roll frame_number     media
#> 1   699370       1968 1968-05-10 1:12000    bc5282          176 Film - BW
#> 2   699415       1968 1968-05-10 1:12000    bc5282          221 Film - BW
#> 3   699426       1968 1968-05-10 1:12000    bc5282          232 Film - BW
#> 4   699396       1968 1968-05-10 1:12000    bc5282          202 Film - BW
#> 5   699365       1968 1968-05-10 1:12000    bc5282          171 Film - BW
#> 6   699419       1968 1968-05-10 1:12000    bc5282          225 Film - BW
#> 7   699425       1968 1968-05-10 1:12000    bc5282          231 Film - BW
#> 8   699393       1968 1968-05-10 1:12000    bc5282          199 Film - BW
#> 9   699373       1968 1968-05-10 1:12000    bc5282          179 Film - BW
#> 10  699421       1968 1968-05-10 1:12000    bc5282          227 Film - BW
#>     photo_tag nts_tile                       geom
#> 1  bc5282_176   093L07  POINT (-126.7091 54.3727)
#> 2  bc5282_221   093L08 POINT (-126.4879 54.47635)
#> 3  bc5282_232   093L07 POINT (-126.6292 54.40794)
#> 4  bc5282_202   093L07 POINT (-126.5869 54.45413)
#> 5  bc5282_171   093L07 POINT (-126.6885 54.38426)
#> 6  bc5282_225   093L07   POINT (-126.54 54.45206)
#> 7  bc5282_231   093L07 POINT (-126.6165 54.41424)
#> 8  bc5282_199   093L07  POINT (-126.624 54.43612)
#> 9  bc5282_179   093L07 POINT (-126.7438 54.39477)
#> 10 bc5282_227   093L07 POINT (-126.5655 54.43945)
```
