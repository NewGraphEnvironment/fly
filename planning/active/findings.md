# Findings — DEM-based terrain-adjusted footprints (#9)

## `flying_height` is metres ASL, not height above ground

Measured on `inst/testdata/photo_centroids.gpkg` (n = 20):

| scale | focal (mm) | flying_height (m) | = feet | H_agl from scale (m) | implied ground elev (m) |
|---|---|---|---|---|---|
| 1:12000 | 153 | 2438 | 7999 | 1836 | 602 |
| 1:12000 | 153 | 2591 | 8501 | 1836 | 755 |
| 1:31680 | 153 | 5944 | 19501 | 4847 | 1097 |
| 1:31680 | 153 | 6096 | 20000 | 4847 | 1249 |

The round-feet values are the tell. Implied ground elevations (602-1249 m) bracket real
Houston-area terrain, confirming the field is ASL. This is what makes a DEM necessary
rather than merely refining: `h_agl = flying_height - terrain elevation`.

Note `H = f * S` exactly, so the nominal-scale and focal-length formulations are
algebraically identical. The DEM is the only thing that adds information.

## The effect is a datum offset, not a slope effect

Nominal scale underestimates footprint **area** consistently, never overestimates it:

| scale | n | centroid elev (m) | area correction (footprint-mean sampling) | median |
|---|---|---|---|---|
| 1:12000 | 10 | 578-674 | +0.5% .. +18.2% | +13.4% |
| 1:31680 | 10 | 595-904 | +6.1% .. +27.2% | +15.6% |

Reported scale is referenced to an elevation above the real valley floor. The issue framed
this as slope making footprints bigger or smaller; the measured bias is bulk and
one-directional, and much larger than the slope term.

## Sampling point matters — the iteration is not cosmetic

Elevation at the centroid vs mean elevation under the flat footprint differs by up to
**130 m** (1:31680 frames, where the footprint is 7.2 km across). That moves the 1:12000
median correction from +16.5% (centroid-only) to +13.4% (one iteration). Hence the two-pass
design: size from centroid elevation, re-sample the mean under that rectangle, resize.

## Ray-cast adds ~2% on top of ~15%

Per-corner terrain intersection displaces a corner by roughly `(Δelev / H_agl) × half_width`.
For 1:31680 here: `(200 / 5300) × 3600 ≈ 136 m` on a 7200 m side ≈ 2%. Not worth irregular
geometry plus iterative corner solving while a 15% scale bias is unaddressed. Deferred.

## DEM source: MRDEM-30 over elevatr

Both verified this session over the fly AOI (centroids + 4 km buffer, 28.3 × 22.6 km):

| source | res | clipped size | elev range | dependency |
|---|---|---|---|---|
| MRDEM-30 (NRCan DTM, S3 COG) | 30 m | 306 KB | 566-1520 m | `terra` only |
| elevatr z=10 (AWS terrain mosaic) | 45 m | 242 KB | 544-1539 m | + `elevatr` |

They agree to within **0.42 percentage points** on the resulting area correction (mean
absolute centroid-elevation difference 3.1 m, max 9 m). So the choice costs no accuracy and
rests on other grounds: MRDEM is the house standard (`flooded::fl_dem_aoi()`), is bare-earth
DTM rather than a mixed-provenance mosaic, adds no dependency, and gives users a documented
source for their own AOIs. Fetch took 4-6 s via `/vsicurl/`.

MRDEM is a single 84 GB COG in EPSG:3979 covering Canada. `/vsicurl/` range-reads only the
intersecting bytes. **Never reproject it whole** — transform the points to the DEM's CRS for
extraction instead.

## `footprint_terrain` rather than encoding terrain in `footprint_basis`

The issue suggested `footprint_basis` carry a terrain-adjusted value. It should not:
`footprint_basis` is already matched by value downstream — the shipped example in
`?fly_footprint` filters `footprint_basis != "unknown_format"` — so appending a suffix like
`"Film - BW (terrain)"` would silently break caller filters. Format basis and terrain basis
are separate facts and get separate columns.

## Errors Encountered

| Error | Resolution |
|-------|------------|
| `st_as_sfc` no applicable method for `sfc_POLYGON` | `st_union()` already returns sfc; drop the redundant `st_as_sfc()` |
| `invalid 'na.print' specification` from `print(df, n = 25)` | `n =` is a tibble arg; the object was a data.frame after `as.data.frame()` |
| `[rast] file does not exist` across two Rscript calls | `tempdir()` differs per R session; write probe artifacts to a stable path |
