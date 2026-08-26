# Download airphoto files from BC Data Catalogue URLs

Downloads thumbnail images, flight logs, camera calibration reports, or
geo-referencing files for selected airphotos. The URL columns must be
present in the input data (available from the full BC Data Catalogue
centroid layer).

## Usage

``` r
fly_fetch(
  photos_sf,
  type = "thumbnail",
  dest_dir = "photos",
  overwrite = FALSE,
  workers = 1
)
```

## Arguments

- photos_sf:

  An sf object with airphoto metadata, typically output from
  [`fly_select()`](https://newgraphenvironment.github.io/fly/reference/fly_select.md)
  or
  [`fly_filter()`](https://newgraphenvironment.github.io/fly/reference/fly_filter.md).
  Must contain the relevant URL column for the requested `type`.

- type:

  File type to download. One of `"thumbnail"`, `"flight_log"`,
  `"calibration"`, or `"georef"`.

- dest_dir:

  Directory to save downloaded files. Created if it does not exist.

- overwrite:

  If `FALSE` (default), skip files that already exist in `dest_dir`.

- workers:

  Number of parallel download workers. `1` (default) runs sequentially.
  Values greater than 1 use
  [`furrr::future_map_dfr()`](https://furrr.futureverse.org/reference/future_map.html)
  with
  [future::multisession](https://future.futureverse.org/reference/multisession.html)
  — requires `furrr` and `future` packages.

## Value

A tibble with columns `airp_id`, `url`, `dest`, and `success`.

## Details

URL column mapping:

- `"thumbnail"` → `thumbnail_image_url`

- `"flight_log"` → `flight_log_url`

- `"calibration"` → `camera_calibration_url`

- `"georef"` → `patb_georef_url`

Photos with missing (`NA` or empty) URLs are skipped and reported as
`success = FALSE` in the output.

When `workers > 1`, a
[future::multisession](https://future.futureverse.org/reference/multisession.html)
plan is set for the duration of the call and restored on exit. Each
download is independent so parallelism is safe.

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

# Download thumbnails for first 2 photos
result <- fly_fetch(centroids[1:2, ], type = "thumbnail",
                    dest_dir = tempdir())
#> Downloaded 2 of 2 files
result
#> # A tibble: 2 × 4
#>   airp_id url                                                      dest  success
#>     <int> <chr>                                                    <chr> <lgl>  
#> 1  699370 https://openmaps.gov.bc.ca/thumbs/1968/bc5282/bc5282_17… /tmp… TRUE   
#> 2  699415 https://openmaps.gov.bc.ca/thumbs/1968/bc5282/bc5282_22… /tmp… TRUE   
```
