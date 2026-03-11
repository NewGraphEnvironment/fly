# Changelog

## fly (development version)

### 0.2.0 (2026-03-11)

- **BREAKING:** Remove `fly_query_habitat()`, `fly_query_lakes()`,
  `fly_trim_habitat()` — migrate to
  [fresh](https://github.com/NewGraphEnvironment/fresh)
  ([\#19](https://github.com/NewGraphEnvironment/fly/issues/19))
- Remove `DBI`, `RPostgres` from Suggests and `glue` from Imports

### 0.1.3 (2026-03-10)

- Add
  [`fly_thumb_georef()`](https://newgraphenvironment.github.io/fly/reference/fly_thumb_georef.md)
  — warp downloaded thumbnails to estimated ground footprints as
  georeferenced GeoTIFFs
  ([\#16](https://github.com/NewGraphEnvironment/fly/issues/16))

### 0.1.2 (2026-03-10)

- Add
  [`fly_fetch()`](https://newgraphenvironment.github.io/fly/reference/fly_fetch.md)
  for downloading thumbnails, flight logs, calibration reports, and
  georef files from BC Data Catalogue URLs
  ([\#15](https://github.com/NewGraphEnvironment/fly/issues/15))
- Include URL columns and flight metadata (focal length, flying height,
  GSD) in bundled test data

### 0.1.1 (2026-03-07)

- Add `component_ensure` parameter to
  [`fly_select()`](https://newgraphenvironment.github.io/fly/reference/fly_select.md)
  for multi-polygon AOIs — guarantees at least one photo per
  disconnected component before greedy selection
  ([\#12](https://github.com/NewGraphEnvironment/fly/issues/12))
- Vignette uses bookdown with numbered sections and figure
  cross-references
- Add `bookdown` to Suggests

### 0.1.0 (2026-03-04)

Initial release. Airphoto footprint estimation and coverage selection,
extracted from [airbc](https://github.com/NewGraphEnvironment/airbc).
