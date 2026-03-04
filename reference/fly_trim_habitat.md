# Trim floodplain to areas alongside target streams

Uses flat-cap buffer to extend perpendicular to streams without
extending past stream endpoints. Optionally includes lake polygons to
fill gaps where lakes interrupt the stream network. Optionally adds a
photo capture buffer.

## Usage

``` r
fly_trim_habitat(
  floodplain_sf,
  streams_sf,
  lakes_sf = NULL,
  floodplain_width = 2000,
  photo_buffer = 1800
)
```

## Arguments

- floodplain_sf:

  An sf polygon — the floodplain or lateral habitat boundary.

- streams_sf:

  An sf linestring — pre-filtered streams (from
  [`fly_query_habitat()`](https://newgraphenvironment.github.io/fly/reference/fly_query_habitat.md)
  or any source).

- lakes_sf:

  An sf polygon — lake polygons to include (from
  [`fly_query_lakes()`](https://newgraphenvironment.github.io/fly/reference/fly_query_lakes.md)
  or any source). Fills gaps where lakes interrupt stream networks.
  `NULL` to skip.

- floodplain_width:

  Buffer distance (m) perpendicular to streams. Should capture the full
  floodplain width. Uses flat end caps.

- photo_buffer:

  Buffer (m) around trimmed floodplain for photo centroid capture. Set
  to 0 to return the trimmed floodplain only.

## Value

An sf polygon in WGS84 (EPSG:4326).

## Examples

``` r
streams <- sf::st_read(system.file("testdata/streams.gpkg", package = "fly"))
#> Reading layer `streams' from data source 
#>   `/home/runner/work/_temp/Library/fly/testdata/streams.gpkg' 
#>   using driver `GPKG'
#> Simple feature collection with 10 features and 5 fields
#> Geometry type: LINESTRING
#> Dimension:     XY
#> Bounding box:  xmin: -126.7081 ymin: 54.35513 xmax: -126.5041 ymax: 54.47
#> Geodetic CRS:  WGS 84
floodplain <- sf::st_read(system.file("testdata/floodplain.gpkg", package = "fly"))
#> Reading layer `floodplain' from data source 
#>   `/home/runner/work/_temp/Library/fly/testdata/floodplain.gpkg' 
#>   using driver `GPKG'
#> Simple feature collection with 1 feature and 0 fields
#> Geometry type: MULTIPOLYGON
#> Dimension:     XY
#> Bounding box:  xmin: -126.7588 ymin: 54.31208 xmax: -126.4191 ymax: 54.48792
#> Geodetic CRS:  WGS 84
trimmed <- fly_trim_habitat(floodplain, streams, photo_buffer = 0)
#> Spherical geometry (s2) switched off
#> Buffering streams by 2000m (flat cap)...
#> Intersecting with floodplain...
#> Error in st_area.sfc(result): package lwgeom required, please install it first
#> Spherical geometry (s2) switched on
plot(sf::st_geometry(trimmed))
#> Error: object 'trimmed' not found
```
