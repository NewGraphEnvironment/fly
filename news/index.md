# Changelog

## fly (development version)

### 0.1.1 (2026-03-07)

- Add `ensure_components` parameter to
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
