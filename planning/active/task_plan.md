# Task: DEM-based terrain-adjusted footprints (#9)

`fly_footprint()` sizes every frame from the reported nominal scale, which assumes flat
ground beneath the aircraft. Issue #9 asked for a DEM option and offered three approaches,
noting the choice between them was the first decision.

Measurement reframed it. Probing the bundled AOI (20 frames, 1968, Upper Bulkley near
Houston) established two facts the issue did not have:

1. **`flying_height` is metres ASL, not height above ground** — values are round feet
   (8000, 8500, 19500, 20000 ft). Subtracting terrain elevation is what turns it into the
   height a footprint actually scales with.
2. **Nominal scale underestimates footprint area by a median ~15%, range 0.5-27%, always
   in the same direction.** Not a slope effect — a datum offset. Reported scale is
   referenced to an elevation above the real valley floor, so every footprint is larger
   than nominal.

Approach chosen (user-approved): **true-scale rectangle**. Size each frame from
`h_agl = flying_height - terrain elevation` instead of nominal scale. Geometry stays a
rectangle, so downstream consumers work unchanged. Per-corner ray-cast measures ~2% on top
of the ~15% and costs irregular geometry — deferred.

DEM source: **MRDEM-30**, NRCan's 30 m bare-earth DTM, the same product
`flooded::fl_dem_aoi()` uses. Public S3 COG, no auth, needs no dependency beyond `terra`.

## Phase 1: Test DEM fixture

- [x] Extend `data-raw/make_testdata.R` with an MRDEM-30 clip over centroids + 4 km buffer
- [x] Write `inst/testdata/dem.tif` (INT2S, DEFLATE, tiled); confirm size and 566-1520 m range
- [x] Document the source and regeneration in the script header

## Phase 2: `fly_footprint(dem =)`

- [x] Failing tests first: flat unchanged, terrain enlarges, empty geoms skipped, each guard
- [x] `terra` to Suggests with `check_installed()` guard
- [x] Two-pass sizing; `footprint_terrain` and `height_agl` columns
- [x] Guards for missing columns, no DEM coverage, non-positive `h_agl`
- [x] Confirm `dem = NULL` output is identical to current — assert, don't assume

## Phase 3: Downstream passthrough

- [x] `dem = NULL` on `fly_coverage()`, `fly_overlap()`, `fly_select()`, `fly_filter()`, `fly_georef()`
- [x] Tests that a DEM reaching each consumer changes its numbers
- [x] Verify all six call sites are covered — enumerate, don't recall

## Phase 4: Docs and release

- [x] Rewrite the flat-terrain paragraphs as conditional in all four locations
- [x] Document DEM sources: MRDEM-30 default, LidarBC via `stac-dem-bc`, BC TRIM 25 m via `bcdata`
- [x] Vignette section showing flat vs terrain-adjusted on the bundled AOI
- [x] Edit issue #9 body: `footprint_terrain` supersedes the `footprint_basis` suggestion;
      effect is a datum offset rather than a slope effect
- [x] `NEWS.md`, version 0.5.0 as the final commit

## Validation

- [x] Tests pass
- [x] `/code-check` clean on each commit
- [x] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
