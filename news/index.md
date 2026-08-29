# Changelog

## fly (development version)

### 0.4.0 (2026-08-28)

- [`fly_footprint()`](https://newgraphenvironment.github.io/fly/reference/fly_footprint.md)
  sizes each frame from its `media` value instead of applying a fixed
  9-inch negative to everything. A digital frame has no negative, and
  the catalogue mixes film and digital in one layer
  ([\#30](https://github.com/NewGraphEnvironment/fly/issues/30))
- New `footprint_basis` column records how each footprint was sized.
  Frames whose recording format cannot be resolved get an empty geometry
  and a warning, rather than a plausible rectangle
- New `format_size` argument supplies widths for formats fly does not
  ship. Digital defaults are deliberately absent until sensor widths are
  established
  ([\#32](https://github.com/NewGraphEnvironment/fly/issues/32))
- `negative_size` keeps its meaning as the film dimension: it sizes film
  and no-media input, and never sizes a digital frame
- All functions that consume footprints now report how many frames they
  excluded for want of one
- Fix
  [`fly_coverage()`](https://newgraphenvironment.github.io/fly/reference/fly_coverage.md)
  dropping an entire group when all its footprints were unsized, and
  emitting multiple rows for a multi-feature intersection
- Correct the documented claim that focal length is unavailable in
  centroid data — `FOCAL_LENGTH`, `FLYING_HEIGHT` and `SCALE` are fully
  populated

### 0.3.0 (2026-03-12)

- **BREAKING:** Rename `fly_thumb_georef()` →
  [`fly_georef()`](https://newgraphenvironment.github.io/fly/reference/fly_georef.md)
  — not thumbnail-specific
  ([\#24](https://github.com/NewGraphEnvironment/fly/issues/24))
- Add `rotation` parameter to
  [`fly_georef()`](https://newgraphenvironment.github.io/fly/reference/fly_georef.md)
  (default 180°) for correcting image orientation per-roll
  ([\#25](https://github.com/NewGraphEnvironment/fly/issues/25))
- Add
  [`fly_bearing()`](https://newgraphenvironment.github.io/fly/reference/fly_bearing.md)
  — compute flight line bearing from consecutive centroids per roll
- Per-photo rotation via `rotation` column on input sf overrides default

### 0.2.1 (2026-03-11)

- Add `workers` parameter to
  [`fly_fetch()`](https://newgraphenvironment.github.io/fly/reference/fly_fetch.md)
  for parallel downloads via `furrr`/`future`
  ([\#21](https://github.com/NewGraphEnvironment/fly/issues/21))
- Add `furrr` and `future` to Suggests

### 0.2.0 (2026-03-11)

- **BREAKING:** Remove `fly_query_habitat()`, `fly_query_lakes()`,
  `fly_trim_habitat()` — migrate to
  [fresh](https://github.com/NewGraphEnvironment/fresh)
  ([\#19](https://github.com/NewGraphEnvironment/fly/issues/19))
- Remove `DBI`, `RPostgres` from Suggests and `glue` from Imports

### 0.1.3 (2026-03-10)

- Add `fly_thumb_georef()` — warp downloaded thumbnails to estimated
  ground footprints as georeferenced GeoTIFFs
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
