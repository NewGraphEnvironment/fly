# fly (development version)

## 0.8.0 (2026-09-01)

- **Every function that takes photo centroids now refuses non-POINT geometry** ([#37](https://github.com/NewGraphEnvironment/fly/issues/37)). `sf::st_coordinates()` returns one row per feature for a POINT and one row per *vertex* for anything else, so `fly_footprint()` handed its own output built five geometries per closed rectangle while the attribute frame stayed at 20 rows, and `st_sf()` recycled it up to match: **20 frames in, 100 rows out**, no error and no warning, 80 of them carrying another photo's attributes
- The reported symptom was the row count, which is the detectable half. Measured on the bundled fixtures, three functions were quietly **wrong** rather than wrong-sized: `fly_bearing()` returned the right number of bearings with values up to **272 degrees** out, because it indexes a 5n-row coordinate matrix with a permutation of `1:n`; `fly_overlap()` reported pairwise overlap across the corrupted set; and `fly_select()` in both modes indexed a 20-row frame with a length-100 logical. `fly_filter(method = "centroid")` never reached `fly_footprint()` at all and silently became a footprint filter, selecting 20 rows on the bundled AOI where points give 7. Only `fly_coverage()` errored, and only by accident of how it assigns
- The guard is **POINT only, not `c("POINT", "MULTIPOINT")`** as the issue proposed. A MULTIPOINT expands one row per constituent point exactly as a POLYGON does — measured: under the suggested guard the same footprints cast to MULTIPOINT still returned 100 rows from 20. POINT is not a proxy for "one coordinate row per feature" but exactly equivalent to it, since `sf` keeps an aligned `NA` row for an empty POINT; zero-row input stays legal
- The error names the argument the caller actually typed rather than `fly_footprint()`'s, names the offending geometry type, and names the one-line fix — `sf::st_filter()` for someone who meant to filter footprints against an area, `sf::st_cast()` for centroids that arrived in another form
- **Breaking for two input shapes that previously worked.** Centroids arriving as MULTIPOINT-of-one — from a PostGIS `MULTIPOINT` column, or an OGR driver that promotes to multi — were sized correctly before and are now refused; so is a mixed-geometry (`GEOMETRY`) column, even when every feature in it is a point, because `sf::st_coordinates()` has no method for that class and the caller otherwise saw `Not compatible with STRSXP: [type=NULL]` several layers down. Both are one call to fix, which the error names: `sf::st_cast(x, "POINT")`

## 0.7.1 (2026-09-01)

- `fly_footprint()`'s `@param dem` names the LidarBC STAC catalogue as `stac-elevation-bc`, its current name ([#46](https://github.com/NewGraphEnvironment/fly/pull/46)). Documentation only — `fly` never queries that catalogue, it takes a COG URL the caller already has, and the S3 bucket kept its old name, so no href in any example changes

## 0.7.0 (2026-08-30)

- `fly_georef()` georeferences digital frames ([#38](https://github.com/NewGraphEnvironment/fly/issues/38)). v0.6.0 gave them footprints and then excluded them from georeferencing with a warning; that exclusion is gone, so the whole post-2010 catalogue is now georeferenceable rather than only sizeable
- **The corner mapping for a non-square footprint is rotation 270 — the top-left pixel maps to the ring's rear-left corner, equivalently image columns run in the flight direction and image rows run flight-right.** It was measured, not reasoned: a digital footprint is already rotated onto its flight line, so `bearing_to_rotation()` is not applied to it, and the geometry that remains cannot distinguish 270 from 90
- The measurement needed no licence-restricted imagery, which the issue had assumed it would. Three independent public routes agree: the per-frame exterior orientation the catalogue publishes through `patb_georef_url` (the UltraCam Eagle's mount is rigid to 0.18 degrees over 6839 frames spanning the compass); adjacent-frame overlap correlation, which needs no reference imagery at all because consecutive frames check each other (+0.616 and +0.659 against at most +0.43 for the alternatives); and FWA lake darkness. `data-raw/georef_calibrate-corner_mapping.R` reproduces all three, and `inst/notes/georeferencing.md` records them — including the one that disagreed and was wrong
- A frame whose delivered image aspect does not pair with its footprint edges is now **skipped with a warning** rather than written stretched. A wrong pairing produces a valid GeoTIFF in the right CRS over the right ground, squashed by the aspect ratio squared, which nothing downstream would report. This also catches a frame sized from an inferred camera format that does not match the camera that took it
- A non-square footprint built without a flight bearing is drawn axis-aligned and so georeferences as though the flight line ran due north. `fly_bearing()` needs a neighbouring frame, so this is the ordinary result of georeferencing one frame on its own, and it is now warned about rather than left to be noticed in the output
- The `rotation` argument applies to square footprints only, and is documented as such; a `rotation` column in `photos_sf` still overrides per-photo for both. Carrying a film-era `rotation` column into a digital batch therefore overrides the correct mapping — drop the column, or set it to `NA` for those rows

## 0.6.0 (2026-08-30)

- `fly_footprint()` now sizes digital frames, closing the gap #30 made honest but left open ([#32](https://github.com/NewGraphEnvironment/fly/issues/32)). Province-wide that is 223,667 of 1,670,471 frames — the package was quietly film-only for anything after ~2010
- Sensor dimensions are read from the camera calibration reports the catalogue itself links to through `camera_calibration_url`, and shipped as `inst/extdata/camera_formats.csv` (built by `data-raw/make_camera_formats.R`). 14 calibrations covering 169,688 frames, plus focal-length fallback rows for frames carrying no calibration
- **The catalogue's `SCALE` is not the true image scale for a digital frame, and is no longer used for one.** Measured against terrain on 40 UltraCam Eagle frames it gives 34% of true width: it is a derived nominal figure, implying a pixel pitch of ~12.5 um for every camera regardless of model against real pitches of 3.9-12 um. A digital frame is sized as `pixel count x ground_sample_distance` instead, which needs neither `scale` nor a DEM. `ground_sample_distance` is centimetres
- **Footprints are no longer always square.** Digital sensors run from 1.10:1 (Leica DMC II) to 1.80:1 (Intergraph DMC), so a square footprint was up to 76% too deep. Non-square footprints are rotated onto the flight line via `fly_bearing()`. Film stays square and its output is unchanged
- New `width_source` column names the calibration file or fallback rule behind every digital footprint, and `footprint_terrain` gains `"gsd_scaled"` — `nominal_scale` is documented as "sized from the reported scale", which is the one thing this route never does
- Frames whose calibration could not be corroborated are refused rather than inferred, listed with the reason in `inst/extdata/camera_formats_excluded.csv`. Two are medium-format bodies about half the width of everything else in the record, so inferring one from focal length would have been ~1.95x too wide
- `fly_georef()` excludes rotated footprints with a warning: its corner mapping applies its own bearing rotation, calibrated for axis-aligned squares, and would count the rotation twice
- The shipped numbers are parsed from the reports, never typed, and gated on four checks before the table is written — `px x pitch` against the stated image size, report focal against the catalogue's, plausibility bounds, and an implied ground elevation that must be a real BC elevation. The last two caught a camera whose catalogue metadata contradicts its own report, which is withheld
- `format_size` is unchanged and still takes precedence, so a caller who knows their camera can override the shipped table
- New `inst/testdata/photo_centroids_digital.gpkg`: 24 real digital frames over the AOI that already ships, from two cameras 0.46 apart in aspect ratio

## 0.5.1 (2026-08-29)

- Fix `fly_footprint()` silently dropping `footprint_basis`, `footprint_terrain`, `height_agl` and `dem_coverage` whenever its input carried the `tbl_df` class ([#35](https://github.com/NewGraphEnvironment/fly/issues/35)). `bcdata::collect()` returns exactly that class, so every caller querying `WHSE_IMAGERY_AND_BASE_MAPS.AIMG_PHOTO_CENTROIDS_SP` — the documented source for this package — lost the whole reporting surface 0.4.0 and 0.5.0 added, and the documented "filter on `footprint_basis`" and "filter on `dem_coverage`" workflows were unreachable from it
- Geometry and every downstream number were always correct; what was lost was the audit trail, which is what made it invisible. `sf::st_sf()` keeps only its first argument when that argument is a tibble, discarding every trailing named column — a general R trap rather than a `fly` one
- Every class the input carries is carried through, so a tibble-backed sf comes back tibble-backed. The order is not preserved: `sf::st_transform()` moves `sf` to the front, so a `bcdc_sf` input returns `sf, bcdc_sf, ...` — as it always has
- Where the input already carried a column named `footprint_basis` (or one of the other three), the old code kept the caller's value and appended a duplicate `footprint_basis.1` — so the documented `footprint_basis != "unknown_format"` filter read the caller's column while fly's own answer sat unread beside it. The computed value now wins, and there is one column. Plain `sf` callers were affected by this too, though never by the tibble bug
- `fly_footprint()` on an input matching no frames now returns `footprint_basis` and `footprint_terrain` as `character` rather than `logical`, so an empty result binds to a populated one. Assembling a per-AOI ledger across queries previously failed on the column type the first time an area returned nothing
- Tests sweep the input-class axis (plain / tibble / grouped) rather than adding cases along the one axis the bundled fixture could present. Every fixture in the package reads back as plain `sf, data.frame`, so the suite was structurally incapable of seeing this
- Widen the `DESCRIPTION` Title and Description, which described roughly half the package — they predated `fly_fetch()`, `fly_georef()` and `fly_bearing()` ([#31](https://github.com/NewGraphEnvironment/fly/issues/31))

## 0.5.0 (2026-08-29)

- `fly_footprint()` gains a `dem` argument, sizing each frame from its height above ground instead of the reported scale ([#9](https://github.com/NewGraphEnvironment/fly/issues/9)). On the bundled Upper Bulkley AOI the reported scale understates footprint **area by a median 14%, ranging to 26%** — and always in the same direction, because the scale is referenced to an elevation above the valley floor the photos cover. This is a datum offset, not the slope effect the issue described
- `FLYING_HEIGHT` is metres above sea level, so subtracting terrain elevation is what turns it into the height ground coverage scales with. Elevation is the mean under the whole footprint, not a reading at the centroid — the two differ by up to 140 m on a 7.2 km frame. It is measured in two passes, because the footprint being averaged over is itself what the correction changes
- New `footprint_terrain`, `height_agl` and `dem_coverage` columns record which terrain treatment each frame received, the height it was sized from, and how much of its footprint the DEM actually covered — measured against the cells the footprint should have covered, so that a footprint running past the edge of a cropped DEM is reported rather than counted as complete. `footprint_basis` is unchanged: it is already matched by value downstream, so encoding terrain into it would break caller filters
- `dem` is accepted by `fly_coverage()`, `fly_overlap()`, `fly_filter()`, `fly_select()` and `fly_georef()`, so the correction is reachable from every function that builds a footprint
- Frames the DEM cannot correct — outside its coverage, or with unusable `flying_height` / `focal_length` — fall back to nominal scale with a warning rather than being dropped. A frame the DEM covers only partly is still corrected, from the mean of the covered part, and warns below 95% coverage
- New `inst/testdata/dem.tif`, a clip of NRCan's MRDEM-30. `terra` added to Suggests; it is only needed when a `dem` is supplied
- Footprints remain axis-aligned rectangles under a nadir assumption. Per-corner ray-casting measures ~2% against the 14% the DEM addresses, and is deferred

## 0.4.0 (2026-08-28)

- `fly_footprint()` sizes each frame from its `media` value instead of applying a fixed 9-inch negative to everything. A digital frame has no negative, and the catalogue mixes film and digital in one layer ([#30](https://github.com/NewGraphEnvironment/fly/issues/30))
- New `footprint_basis` column records how each footprint was sized. Frames whose recording format cannot be resolved get an empty geometry and a warning, rather than a plausible rectangle
- New `format_size` argument supplies widths for formats fly does not ship. Digital defaults are deliberately absent until sensor widths are established ([#32](https://github.com/NewGraphEnvironment/fly/issues/32))
- `negative_size` keeps its meaning as the film dimension: it sizes film and no-media input, and never sizes a digital frame
- All functions that consume footprints now report how many frames they excluded for want of one
- Fix `fly_coverage()` dropping an entire group when all its footprints were unsized, and emitting multiple rows for a multi-feature intersection
- Correct the documented claim that focal length is unavailable in centroid data — `FOCAL_LENGTH`, `FLYING_HEIGHT` and `SCALE` are fully populated

## 0.3.0 (2026-03-12)

- **BREAKING:** Rename `fly_thumb_georef()` → `fly_georef()` — not thumbnail-specific ([#24](https://github.com/NewGraphEnvironment/fly/issues/24))
- Add `rotation` parameter to `fly_georef()` (default 180°) for correcting image orientation per-roll ([#25](https://github.com/NewGraphEnvironment/fly/issues/25))
- Add `fly_bearing()` — compute flight line bearing from consecutive centroids per roll
- Per-photo rotation via `rotation` column on input sf overrides default

## 0.2.1 (2026-03-11)

- Add `workers` parameter to `fly_fetch()` for parallel downloads via `furrr`/`future` ([#21](https://github.com/NewGraphEnvironment/fly/issues/21))
- Add `furrr` and `future` to Suggests

## 0.2.0 (2026-03-11)

- **BREAKING:** Remove `fly_query_habitat()`, `fly_query_lakes()`, `fly_trim_habitat()` — migrate to [fresh](https://github.com/NewGraphEnvironment/fresh) ([#19](https://github.com/NewGraphEnvironment/fly/issues/19))
- Remove `DBI`, `RPostgres` from Suggests and `glue` from Imports

## 0.1.3 (2026-03-10)

- Add `fly_thumb_georef()` — warp downloaded thumbnails to estimated ground footprints as georeferenced GeoTIFFs ([#16](https://github.com/NewGraphEnvironment/fly/issues/16))

## 0.1.2 (2026-03-10)

- Add `fly_fetch()` for downloading thumbnails, flight logs, calibration reports, and georef files from BC Data Catalogue URLs ([#15](https://github.com/NewGraphEnvironment/fly/issues/15))
- Include URL columns and flight metadata (focal length, flying height, GSD) in bundled test data

## 0.1.1 (2026-03-07)

- Add `component_ensure` parameter to `fly_select()` for multi-polygon AOIs — guarantees at least one photo per disconnected component before greedy selection ([#12](https://github.com/NewGraphEnvironment/fly/issues/12))
- Vignette uses bookdown with numbered sections and figure cross-references
- Add `bookdown` to Suggests

## 0.1.0 (2026-03-04)

Initial release. Airphoto footprint estimation and coverage selection,
extracted from [airbc](https://github.com/NewGraphEnvironment/airbc).
