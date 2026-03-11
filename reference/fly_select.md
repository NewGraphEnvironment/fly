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
#> Simple feature collection with 20 features and 16 fields
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
#> Simple feature collection with 3 features and 18 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: -126.6796 ymin: 54.41035 xmax: -126.5269 ymax: 54.46049
#> Geodetic CRS:  WGS 84
#>    airp_id photo_year photo_date   scale film_roll frame_number     media
#> 11  697358       1968 1968-07-31 1:31680    bc5306           89 Film - BW
#> 20  697329       1968 1968-07-31 1:31680    bc5306           60 Film - BW
#> 12  697292       1968 1968-07-31 1:31680    bc5306           23 Film - BW
#>     photo_tag nts_tile focal_length flying_height ground_sample_distance
#> 11 bc5306_089   093L07          153          5944                     NA
#> 20 bc5306_060   093L07          153          5944                     NA
#> 12 bc5306_023   093L07          153          5944                     NA
#>                                                   thumbnail_image_url
#> 11 https://openmaps.gov.bc.ca/thumbs/1968/bc5306/bc5306_089_thumb.jpg
#> 20 https://openmaps.gov.bc.ca/thumbs/1968/bc5306/bc5306_060_thumb.jpg
#> 12 https://openmaps.gov.bc.ca/thumbs/1968/bc5306/bc5306_023_thumb.jpg
#>                                                             flight_log_url
#> 11 https://openmaps.gov.bc.ca/thumbs/logbooks/1968/roll_pages/bc5306_1.jpg
#> 20 https://openmaps.gov.bc.ca/thumbs/logbooks/1968/roll_pages/bc5306_1.jpg
#> 12 https://openmaps.gov.bc.ca/thumbs/logbooks/1968/roll_pages/bc5306_1.jpg
#>    camera_calibration_url patb_georef_url                       geom
#> 11                   <NA>            <NA> POINT (-126.6796 54.41035)
#> 20                   <NA>            <NA> POINT (-126.6039 54.42617)
#> 12                   <NA>            <NA> POINT (-126.5269 54.46049)
#>    selection_order cumulative_coverage_pct
#> 11               1                    41.0
#> 20               2                    66.5
#> 12               3                    81.6

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
#> Simple feature collection with 10 features and 18 fields
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
#>     photo_tag nts_tile focal_length flying_height ground_sample_distance
#> 18 bc5306_057   093L07          153          5944                     NA
#> 11 bc5306_089   093L07          153          5944                     NA
#> 13 bc5306_024   093L07          153          5944                     NA
#> 10 bc5282_227   093L07          153          2591                     NA
#> 4  bc5282_202   093L07          153          2591                     NA
#> 17 bc5306_026   093L07          153          5944                     NA
#> 15 bc5300_236   093L08          153          5944                     NA
#> 12 bc5306_023   093L07          153          5944                     NA
#> 6  bc5282_225   093L07          153          2591                     NA
#> 20 bc5306_060   093L07          153          5944                     NA
#>                                                   thumbnail_image_url
#> 18 https://openmaps.gov.bc.ca/thumbs/1968/bc5306/bc5306_057_thumb.jpg
#> 11 https://openmaps.gov.bc.ca/thumbs/1968/bc5306/bc5306_089_thumb.jpg
#> 13 https://openmaps.gov.bc.ca/thumbs/1968/bc5306/bc5306_024_thumb.jpg
#> 10 https://openmaps.gov.bc.ca/thumbs/1968/bc5282/bc5282_227_thumb.jpg
#> 4  https://openmaps.gov.bc.ca/thumbs/1968/bc5282/bc5282_202_thumb.jpg
#> 17 https://openmaps.gov.bc.ca/thumbs/1968/bc5306/bc5306_026_thumb.jpg
#> 15 https://openmaps.gov.bc.ca/thumbs/1968/bc5300/bc5300_236_thumb.jpg
#> 12 https://openmaps.gov.bc.ca/thumbs/1968/bc5306/bc5306_023_thumb.jpg
#> 6  https://openmaps.gov.bc.ca/thumbs/1968/bc5282/bc5282_225_thumb.jpg
#> 20 https://openmaps.gov.bc.ca/thumbs/1968/bc5306/bc5306_060_thumb.jpg
#>                                                             flight_log_url
#> 18 https://openmaps.gov.bc.ca/thumbs/logbooks/1968/roll_pages/bc5306_1.jpg
#> 11 https://openmaps.gov.bc.ca/thumbs/logbooks/1968/roll_pages/bc5306_1.jpg
#> 13 https://openmaps.gov.bc.ca/thumbs/logbooks/1968/roll_pages/bc5306_1.jpg
#> 10 https://openmaps.gov.bc.ca/thumbs/logbooks/1968/roll_pages/bc5282_1.jpg
#> 4  https://openmaps.gov.bc.ca/thumbs/logbooks/1968/roll_pages/bc5282_1.jpg
#> 17 https://openmaps.gov.bc.ca/thumbs/logbooks/1968/roll_pages/bc5306_1.jpg
#> 15 https://openmaps.gov.bc.ca/thumbs/logbooks/1968/roll_pages/bc5300_2.jpg
#> 12 https://openmaps.gov.bc.ca/thumbs/logbooks/1968/roll_pages/bc5306_1.jpg
#> 6  https://openmaps.gov.bc.ca/thumbs/logbooks/1968/roll_pages/bc5282_1.jpg
#> 20 https://openmaps.gov.bc.ca/thumbs/logbooks/1968/roll_pages/bc5306_1.jpg
#>    camera_calibration_url patb_georef_url                       geom
#> 18                   <NA>            <NA> POINT (-126.6025 54.34512)
#> 11                   <NA>            <NA> POINT (-126.6796 54.41035)
#> 13                   <NA>            <NA> POINT (-126.5269 54.43578)
#> 10                   <NA>            <NA> POINT (-126.5655 54.43945)
#> 4                    <NA>            <NA> POINT (-126.5869 54.45413)
#> 17                   <NA>            <NA> POINT (-126.5262 54.38554)
#> 15                   <NA>            <NA>  POINT (-126.449 54.41519)
#> 12                   <NA>            <NA> POINT (-126.5269 54.46049)
#> 6                    <NA>            <NA>   POINT (-126.54 54.45206)
#> 20                   <NA>            <NA> POINT (-126.6039 54.42617)
#>    selection_order cumulative_coverage_pct
#> 18               1                     3.6
#> 11               2                    44.6
#> 13               3                    68.9
#> 10               4                    70.3
#> 4                5                    72.2
#> 17               6                    74.8
#> 15               7                    76.6
#> 12               8                    78.0
#> 6                9                    78.0
#> 20              10                    90.1

# All photos touching the AOI
fly_select(centroids, aoi, mode = "all")
#> Spherical geometry (s2) switched off
#> although coordinates are longitude/latitude, st_union assumes that they are
#> planar
#> although coordinates are longitude/latitude, st_intersects assumes that they
#> are planar
#> Selected 20 of 20 photos intersecting the AOI
#> Spherical geometry (s2) switched on
#> Simple feature collection with 20 features and 16 fields
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
#>     photo_tag nts_tile focal_length flying_height ground_sample_distance
#> 1  bc5282_176   093L07          153          2591                     NA
#> 2  bc5282_221   093L08          153          2591                     NA
#> 3  bc5282_232   093L07          153          2591                     NA
#> 4  bc5282_202   093L07          153          2591                     NA
#> 5  bc5282_171   093L07          153          2438                     NA
#> 6  bc5282_225   093L07          153          2591                     NA
#> 7  bc5282_231   093L07          153          2591                     NA
#> 8  bc5282_199   093L07          153          2591                     NA
#> 9  bc5282_179   093L07          153          2591                     NA
#> 10 bc5282_227   093L07          153          2591                     NA
#>                                                   thumbnail_image_url
#> 1  https://openmaps.gov.bc.ca/thumbs/1968/bc5282/bc5282_176_thumb.jpg
#> 2  https://openmaps.gov.bc.ca/thumbs/1968/bc5282/bc5282_221_thumb.jpg
#> 3  https://openmaps.gov.bc.ca/thumbs/1968/bc5282/bc5282_232_thumb.jpg
#> 4  https://openmaps.gov.bc.ca/thumbs/1968/bc5282/bc5282_202_thumb.jpg
#> 5  https://openmaps.gov.bc.ca/thumbs/1968/bc5282/bc5282_171_thumb.jpg
#> 6  https://openmaps.gov.bc.ca/thumbs/1968/bc5282/bc5282_225_thumb.jpg
#> 7  https://openmaps.gov.bc.ca/thumbs/1968/bc5282/bc5282_231_thumb.jpg
#> 8  https://openmaps.gov.bc.ca/thumbs/1968/bc5282/bc5282_199_thumb.jpg
#> 9  https://openmaps.gov.bc.ca/thumbs/1968/bc5282/bc5282_179_thumb.jpg
#> 10 https://openmaps.gov.bc.ca/thumbs/1968/bc5282/bc5282_227_thumb.jpg
#>                                                             flight_log_url
#> 1  https://openmaps.gov.bc.ca/thumbs/logbooks/1968/roll_pages/bc5282_1.jpg
#> 2  https://openmaps.gov.bc.ca/thumbs/logbooks/1968/roll_pages/bc5282_1.jpg
#> 3  https://openmaps.gov.bc.ca/thumbs/logbooks/1968/roll_pages/bc5282_1.jpg
#> 4  https://openmaps.gov.bc.ca/thumbs/logbooks/1968/roll_pages/bc5282_1.jpg
#> 5  https://openmaps.gov.bc.ca/thumbs/logbooks/1968/roll_pages/bc5282_1.jpg
#> 6  https://openmaps.gov.bc.ca/thumbs/logbooks/1968/roll_pages/bc5282_1.jpg
#> 7  https://openmaps.gov.bc.ca/thumbs/logbooks/1968/roll_pages/bc5282_1.jpg
#> 8  https://openmaps.gov.bc.ca/thumbs/logbooks/1968/roll_pages/bc5282_1.jpg
#> 9  https://openmaps.gov.bc.ca/thumbs/logbooks/1968/roll_pages/bc5282_1.jpg
#> 10 https://openmaps.gov.bc.ca/thumbs/logbooks/1968/roll_pages/bc5282_1.jpg
#>    camera_calibration_url patb_georef_url                       geom
#> 1                    <NA>            <NA>  POINT (-126.7091 54.3727)
#> 2                    <NA>            <NA> POINT (-126.4879 54.47635)
#> 3                    <NA>            <NA> POINT (-126.6292 54.40794)
#> 4                    <NA>            <NA> POINT (-126.5869 54.45413)
#> 5                    <NA>            <NA> POINT (-126.6885 54.38426)
#> 6                    <NA>            <NA>   POINT (-126.54 54.45206)
#> 7                    <NA>            <NA> POINT (-126.6165 54.41424)
#> 8                    <NA>            <NA>  POINT (-126.624 54.43612)
#> 9                    <NA>            <NA> POINT (-126.7438 54.39477)
#> 10                   <NA>            <NA> POINT (-126.5655 54.43945)
```
