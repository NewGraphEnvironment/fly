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

## Environment

terra 1.9.50, GDAL 3.13.0 (terra) / 3.8.5 (sf), PROJ 9.8.1, macOS.

## Errors Encountered

| Error | Resolution |
|-------|------------|
| `'\[' is an unrecognized escape` from an inline `Rscript -e` regex | Wrote the probe to a file and ran `Rscript <path>` — the `code-check-shell.md` rule about regexes in inline `-e` |
