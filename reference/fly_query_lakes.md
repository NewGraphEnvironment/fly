# Query FWA lake polygons that intersect habitat streams

Returns lake polygons from `whse_basemapping.fwa_lakes_poly` that share
a `waterbody_key` with the input streams. Use with
[`fly_trim_habitat()`](https://newgraphenvironment.github.io/fly/reference/fly_trim_habitat.md)
to fill gaps where lakes interrupt the stream network.

## Usage

``` r
fly_query_lakes(conn, streams_sf)
```

## Arguments

- conn:

  A DBI connection to a bcfishpass database.

- streams_sf:

  An sf linestring — habitat streams (e.g. from
  [`fly_query_habitat()`](https://newgraphenvironment.github.io/fly/reference/fly_query_habitat.md)).

## Value

An sf polygon object in WGS84 (EPSG:4326), or `NULL` if no waterbody
keys are found.
