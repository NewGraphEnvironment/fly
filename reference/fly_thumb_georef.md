# Georeference downloaded thumbnails to footprint polygons

Warps thumbnail images to their estimated ground footprint using GCPs
(ground control points) derived from
[`fly_footprint()`](https://newgraphenvironment.github.io/fly/reference/fly_footprint.md).
Produces georeferenced GeoTIFFs in BC Albers (EPSG:3005).

## Usage

``` r
fly_thumb_georef(
  fetch_result,
  photos_sf,
  dest_dir = "georef",
  overwrite = FALSE
)
```

## Arguments

- fetch_result:

  A tibble returned by
  [`fly_fetch()`](https://newgraphenvironment.github.io/fly/reference/fly_fetch.md),
  with columns `airp_id`, `dest`, and `success`.

- photos_sf:

  The same sf object passed to
  [`fly_fetch()`](https://newgraphenvironment.github.io/fly/reference/fly_fetch.md),
  with a `scale` column for footprint estimation.

- dest_dir:

  Directory for output GeoTIFFs. Created if it does not exist.

- overwrite:

  If `FALSE` (default), skip files that already exist.

## Value

A tibble with columns `airp_id`, `source`, `dest`, and `success`.

## Details

Each thumbnail's four corners are mapped to the corresponding footprint
polygon corners computed by
[`fly_footprint()`](https://newgraphenvironment.github.io/fly/reference/fly_footprint.md)
in BC Albers. GDAL translates the image with GCPs then warps to the
target CRS using bilinear resampling.

**Accuracy:** footprints assume flat terrain and nadir camera angle. The
georeferenced thumbnails are approximate — useful for visual context,
not survey-grade positioning. See
[`fly_footprint()`](https://newgraphenvironment.github.io/fly/reference/fly_footprint.md)
for details on limitations.

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

# Fetch and georeference first 2 thumbnails
fetched <- fly_fetch(centroids[1:2, ], type = "thumbnail",
                     dest_dir = tempdir())
#> Downloaded 2 of 2 files
georef <- fly_thumb_georef(fetched, centroids[1:2, ],
                           dest_dir = tempdir())
#> Georeferenced 2 of 2 thumbnails
georef
#> # A tibble: 2 × 4
#>   airp_id source                               dest                      success
#>     <int> <chr>                                <chr>                     <lgl>  
#> 1  699370 /tmp/RtmpvyWr16/bc5282_176_thumb.jpg /tmp/RtmpvyWr16/bc5282_1… TRUE   
#> 2  699415 /tmp/RtmpvyWr16/bc5282_221_thumb.jpg /tmp/RtmpvyWr16/bc5282_2… TRUE   
```
