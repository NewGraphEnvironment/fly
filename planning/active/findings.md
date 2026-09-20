# Findings — fly_dem_sample() over a /vsicurl/ DEM (#59)

## Where the cost is

`fly_dem_sample()` (`R/fly_footprint.R:232-275`) makes two `terra::extract()` calls, and only
the first touches the network:

| line | call | reads |
|---|---|---|
| `R/fly_footprint.R:243` | `terra::extract(dem, v)` — no `fun`, whole vector | **the DEM — the whole cost** |
| `R/fly_footprint.R:269` | `terra::extract(tmpl, vi)`, per-frame denominator loop | `tmpl`, built in memory by `fly_dem_grid()` + `values<-1L` — **never the network** |

`fly_dem_grid()` (`R/fly_footprint.R:218-224`) reads only `res()`, `crs()` and `align()` —
metadata on the open handle, no pixels. So `fly_footprint()` issues exactly **two** remote reads
per call, one per pass (`R/fly_footprint.R:916` and `:972`), not `2 x n_frames + 2`.

The issue body's "each frame is also extracted four times" is true in call count and wrong about
where the cost is. Three of the four are local.

## The remote object is a well-formed COG

Measured 2026-09-20 (`terra::describe()`, 6 s):

```
Size is 185220, 166668        Pixel Size = (30, -30)
LAYOUT=COG   COMPRESSION=LZW   INTERLEAVE=BAND
Band 1 Block=512x512 Type=Float32   NoData=-32767
Overviews: 92610x83334 ... 361x325   (nine levels)
```

A 512-cell block is 15.4 km; a 1:15000 footprint is 3.4 km. So one frame is 1-4 blocks, and a
windowed read is cheap by construction.

## Timings — 2026-09-20, quiet link, one form per fresh R process

Fresh processes so the GDAL block cache cannot carry between forms. Run serially, never
concurrently — concurrency is the confound that made the issue's 583 s an upper bound.

**One frame** (first bundled centroid, 1:15000 square, 1.714 km half-side):

| form | secs | cells | mean elev |
|---|---|---|---|
| `crop(dem, ext(v))` then `extract(crop, v)` | **0.69** | 12616 | 609.150 |
| `extract(dem, v, fun = mean, na.rm = TRUE)` | **0.66** | — | 609.150 |
| `extract(dem, v)` — the current path | **64.59** | 12616 | 609.150 |

94x. And cropping returns the **identical cell count and identical mean**, which is the
invariant the fix rests on: a windowed read does not change what `dem_coverage` counts.

Cropping is as fast as aggregating *and* keeps the every-cell return the numerator needs, so the
issue's option 1 beats its option 2 outright — no second aggregating call for the count, no risk
of a custom R closure falling off terra's fast path, and `sum(!is.na(...))` stays as written.

**Eight contiguous frames**, per-frame crop vs one shared crop:

| form | secs | cells | sum of means |
|---|---|---|---|
| per-frame crop | **1.23** | 100897 | 5262.4246 |
| one shared crop | **1.00** | 100897 | 5262.4246 |

Per-frame costs 23% more on contiguous frames — the GDAL block cache absorbs the 60% overlap, so
it is 0.15 s/frame rather than 0.69 — and it is bounded by one footprint by construction. Cheap
price for never being able to reproduce the union-sized allocation `terrain-correction.md` records.

The 1.23 s independently reproduces fly#54's "1.3 s for eight frames against a local crop", now
straight off the remote COG.

**Whole-AOI context:** `terra::crop()` of the entire bundled extent (47 x 46 km, 2.4 M cells, all
20 bundled frames) off the same remote object takes 4.4 s, `inMemory` TRUE.

## The local-DEM path does not regress

The old code made one `extract()` over every rectangle; the new one makes n crops and n
extracts, so a slowdown on the common local path was the obvious risk. Measured by alternating
the two implementations in one process, five rounds each, 20 bundled frames against the bundled
`dem.tif`:

| | median secs |
|---|---|
| old, one extract over all 20 | 1.437 |
| new, one window per frame | **1.260** |

12% *faster*, not slower — each extract now works over a window of a few thousand cells instead
of the whole 1210 x 1098 raster, which more than pays for the per-frame crop.

## End to end, the case the issue reports

Two frames, remote MRDEM, `fly_footprint(cen, dem = u)`, the old implementation pulled from
`git show HEAD:` and swapped in with `assignInNamespace()`. Each run printed whether the loaded
body contained `terra::crop`, so the comparison cannot be a tautology.

| | secs | dem_coverage | height_agl | footprint_terrain |
|---|---|---|---|---|
| before (`has_crop=FALSE`) | **263.4** | 1,1 | 1984.285, 1934.798 | dem_agl, dem_agl |
| after (`has_crop=TRUE`) | **4.3** | 1,1 | 1984.285, 1934.798 | dem_agl, dem_agl |

61x, identical answers. 263 s on a quiet link against the issue's 583 s on a contended one is
the confound the issue itself flagged, quantified: about 2.2x.

## Both new guards were proven to fire

| planted defect | result |
|---|---|
| crop once over `in_dem` rather than per frame | `max(crops)` = **243,583,754** cells — the figure the note records — and **only the new test** reddens, since the counting grid is still per-frame and the old grid test cannot see the read |
| remove the off-DEM extent guard, so `terra::crop()` runs unconditionally | **5 tests error**, three of them pre-existing. Errors, not failures: the batch aborts |

Restored from a byte-compared copy afterwards, suite re-run green.

## The overlap test was probed at the boundary, not reasoned about

Replacing a first draft's `tryCatch(crop(...), error = NULL)` with an explicit extent test —
there is no `tryCatch` in the shipped code — introduced one risk
worth measuring: an input where `on_dem` is TRUE but `terra::crop()` still errors would now abort
a batch where the old code merely returned `NA` for that frame. Five boundary shapes, old against
new:

| case | agree |
|---|---|
| overlaps the east edge by 0.1 of a cell | yes — both `elev` NA, `covered` 0 |
| frame extent exactly touching the east edge | yes |
| frame one micron past the east edge | yes |
| frame exactly one cell wide, well inside | yes |
| frame spanning the whole DEM and 50 km past it on all sides | yes — both `elev` 866.2, `covered` 0.0359 |

No abort and no divergence. Strict inequality is what makes the touching case fall on the
no-overlap side, where it belongs: extents that share only a boundary share no cell.

A second probe asked whether an **NA** extent could reach the test, since `if (!NA)` would error.
Reprojecting a BC rectangle into an orthographic CRS centred on the far side of the globe yields
an empty geometry, and **old and new then fail identically** with `missing value where
TRUE/FALSE needed`. Pre-existing, of fly#47's family, and not a regression — so no guard was
added for it.

## Environment

terra 1.9.50, GDAL 3.13.0 (terra) / 3.8.5 (sf), PROJ 9.8.1, macOS.

## Errors Encountered

| Error | Resolution |
|-------|------------|
| `'\[' is an unrecognized escape` from an inline `Rscript -e` regex | Wrote the probe to a file and ran `Rscript <path>` — the `code-check-shell.md` rule about regexes in inline `-e` |
