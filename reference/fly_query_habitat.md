# Query bcfishpass for habitat streams

Queries the `bcfishpass.streams_vw` table for stream segments with
modelled habitat (rearing or spawning) for a given species and watershed
group.

## Usage

``` r
fly_query_habitat(
  conn,
  wsgroup,
  habitat_type = "rearing",
  species_code = "co",
  blue_line_keys = NULL,
  stream_names = NULL,
  min_stream_order = NULL
)
```

## Arguments

- conn:

  A DBI connection to a bcfishpass database.

- wsgroup:

  Watershed group code (e.g. `"BULK"`, `"LNIC"`).

- habitat_type:

  `"rearing"` or `"spawning"`.

- species_code:

  Species code: `"co"`, `"ch"`, `"sk"`, `"bt"`, `"st"`, `"wct"`, `"cm"`,
  `"pk"`.

- blue_line_keys:

  Numeric vector of FWA blue_line_key values (preferred — unique per
  stream).

- stream_names:

  Character vector of GNIS stream names (convenience — scoped to
  wsgroup).

- min_stream_order:

  Minimum Strahler order (applied in addition to blk/name filters).

## Value

An sf linestring object in WGS84 (EPSG:4326).
