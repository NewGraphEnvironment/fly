# Review round 6 — fly, `dem`-based terrain-adjusted footprints (#9)

Branch `9-dem-based-terrain-adjusted-footprints` @ `34e8ec4`. All verification run
against the live package via `devtools::load_all()`. Working tree restored to HEAD
after every restore-the-defect experiment (`git status` clean).

## Findings

### [bug] tests/testthat/test-fly_footprint.R:567-586 — the guard for round 5's allocation defect cannot fail

`test_that("fly_footprint does not size its coverage grid to the span of the photo set")`
is the only test written to catch the union-template defect fixed in `34e8ec4`, and it
asserts the failure as elapsed time:

```r
elapsed <- system.time(
  fp <- suppressWarnings(fly_footprint(centroids, dem = testdata_path("dem.tif")))
)[["elapsed"]]
expect_lt(elapsed, 10)
expect_equal(fp$footprint_terrain, c("dem_agl", "no_dem_coverage"))
expect_equal(fp$dem_coverage, c(1, 0))
```

I restored the pre-`34e8ec4` union form of `expected` in `fly_dem_sample()` verbatim
(the single `terra::rast(terra::align(terra::ext(v), dem), ...)` template plus
`vapply(split(tmpl_cells[, 2], tmpl_cells[, 1]), length, numeric(1))`) and re-ran:

| | elapsed | peak RSS |
|---|---|---|
| fixed (per-frame template) | **0.18 s** | 278 MB |
| defect restored (union template) | **1.00 s** | 4.17 GB |

`expect_lt(elapsed, 10)` therefore passes with a 10x margin on the exact defect it
exists to catch. And the other two assertions in the test are satisfied by the
defective code too — `dem_coverage` is `c(1, 0)` either way, because a union template
gets the denominator *right*, it just allocates 243 million cells to do it.

Running the whole suite with the defect restored:

```
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 222 ]
```

Zero failures across all 222 tests. Nothing in the suite catches it.

For contrast, the *other* round-5 fix is genuinely guarded: replacing
`covered <- ifelse(corrected, second$covered, first$covered)` with
`covered <- second$covered` fails 3 tests (`test-fly_footprint.R:457`, `:584`, `:621`).

The commit message claims "Both have tests that fail when the defect is restored".
Measured, the first does not. It also says the distant-frame call "goes from seconds
and gigabytes to 0.18 s" — the gigabytes are real (4.17 GB), the seconds are not
(1.00 s).

**Why the threshold cannot be tightened into a fix.** The separation at 30 m is
0.18 s vs 1.00 s. Any threshold that separates those is inside normal CI scheduling
jitter, so tightening `10` to `0.5` buys a flaky test rather than a working guard.

**What does separate them.** Two options, both verified:

1. *Make the fixture reach the failure mode harder.* Same two frames 700 km apart, but
   a finer DEM. With an in-memory 4 m EPSG:3005 raster over frame 1 only
   (2.25M cells, so cheap to build):

   | | elapsed |
   |---|---|
   | fixed | **2.26 s** |
   | defect restored | **48.69 s** |

   That separates at the existing `< 10` threshold with a 4x margin either side. Cost
   is ~2.3 s of suite time.

2. *Assert the allocation directly rather than its wall-clock shadow.* The quantity
   that actually differs by 14,950x is the template cell count, and it is not
   observable from outside `fly_dem_sample()`. Returning it (or the peak template
   extent) alongside `elev`/`covered` would make the guard exact and instant.

Option 1 is the smaller change; option 2 is the one that stops this test rotting again
the next time hardware gets faster.

---

## Everything else checked, and clean

Verified by running, not by reading.

### The newest code from round 5

- **`covered <- ifelse(corrected, second$covered, first$covered)` indexing.**
  `first$covered`, `second$covered`, `corrected`, `sized` and `candidate` are all
  length `n`; `fly_dem_sample()` pre-fills `elev`/`covered` to `length(rects)` and
  writes into `[ok]`. Confirmed aligned on a fixture with an empty geometry *in the
  middle* (frame 2 unknown-format, frame 3 700 km off the DEM):
  `basis = Film - BW | unknown_format | Film - BW`,
  `terrain = dem_agl | NA | no_dem_coverage`,
  `dem_coverage = 1 | NA | 0`. Frame 1's `height_agl` reproduces the brute-force mean
  under its own returned geometry to 0.08 m.
- **`split()` key order.** The comment claims IDs come back 1..n ascending. Verified
  against `terra::extract()` on a 3-polygon fixture where polygon 2 misses the raster
  entirely: 3 IDs returned, `split()` length 3. terra emits a row per polygon even for
  a total miss, so `got` can never be shorter than `expected`.
- **Per-frame template loop with gaps.** `in_dem` is built from `rects[ok]`, and both
  `got` (via `per_frame`) and `expected` (via `seq_len(nrow(in_dem))`) index that same
  compacted set. Correct with holes.
- **Reported coverage vs returned geometry.** The frame ships `resize(second$elev)`
  while `covered` describes `resize(first$elev)` — one iteration behind. Measured the
  residual: max `|reported - truth|` is **1.2e-4** over the 20 bundled frames, and
  exactly **0** on the 25.6%-covered edge frame the round-5 test uses. Not worth a
  finding.

### Documented numbers — recomputed

| claim | where | measured | verdict |
|---|---|---|---|
| median 14% area understatement | roxygen, NEWS, vignette | 13.77% | ok |
| "ranging to 26%" / 0.5–26.4% | roxygen, NEWS | min 0.45, max 26.39 | ok |
| centroid vs footprint-mean up to 140 m | roxygen, NEWS | 140.06 m (1:31680); 60.6 m (1:12000) | ok |
| second pass moves area "at most 0.53%" | roxygen comment | 0.529% max, 0.145% median | ok |
| third pass 0.03% | roxygen | 0.034% max; fourth pass 0.000% | ok |
| test comment "differ by up to 130 m" | test:163 | 140 m — a true lower bound | ok |
| ~2% per-corner ray-cast | roxygen, NEWS, vignette | `(200/5300)*3600 = 136 m` on a 7200 m side = 1.9%; a linear figure quoted beside a 14% *area* figure, but flagged "roughly" and used only to justify deferral | not wrong |
| 0.42 pp MRDEM vs elevatr | `data-raw` comment | historical, needs elevatr; not recomputed | unverified |

The archived `planning/archive/.../findings.md` table has drifted slightly against the
regenerated fixture (1:31680 max +27.2% recorded vs +26.4% now). That file is an
archived planning record, excluded from the build by the new `^planning$` in
`.Rbuildignore`, and every shipped claim derived from it is current.

### `data-raw/make_testdata.R` and the committed fixture

Re-ran the DEM section against the live MRDEM-30 COG with the committed
`photo_centroids.gpkg` as input and compared to `inst/testdata/dem.tif`:

```
old dim: 1098 1210    new dim: 1098 1210
identical ext: TRUE   res: 30.45109 (both)
max abs diff: 0       n differing cells: 0      NA mismatch: 0
```

Byte-equivalent. The committed fixture is what the script produces today.

Buffer arithmetic: `st_buffer(photos, 5400)` against a nominal 1:31680 corner distance
of 5.12 km. The corrected footprint's corner reaches ~5.75 km, which 5400 does not
cover on its own — but the 3979 crop with `snap = "out"` plus the reprojection to 3005
adds 1.9–3.8 km of extra margin, and measured `min(dem_coverage)` over the 20 frames is
**0.9996** with no warning. (The DEM is 47% NA by cell count, which is just the rotated
3979 rectangle inside its 3005 bounding box — consistent with a ~30° rotation.) It
works; the margin is incidental rather than designed, but the shipped `dem_coverage`
column reports it either way.

### Downstream `dem` threading

Exercised each function with `dem` supplied *and* a group of frames forced to
`unknown_format` (empty geometries), which is the interaction the prompt asks about:

- `fly_coverage()` — 1:12000 group 15.1 → 16.0 km2 with the DEM; the all-unsized
  1:31680 group still emits a row at 0 (the round-1 zero-length fix holds under `dem`).
- `fly_overlap()` — 7 pairs, no non-finite `pct_of_a`/`pct_of_b`. An empty footprint
  never enters the pair loop because `st_intersects()` gives it no neighbours, so
  `fp_areas[i] == 0` is unreachable as a divisor.
- `fly_select(mode = "minimal", component_ensure = TRUE)` — `photo_idx` bookkeeping
  intact: `selection_order` is `1..n` and `cumulative_coverage_pct` is monotone and the
  same length as `selected_idx`, with seeds included.
- `fly_filter()` — footprints and `aoi_test` are both in the input CRS; unchanged.
- `fly_georef()` — GCP corner order is BL, BR, TR, TL in both bases (the DEM only
  scales the square, it does not reorder the ring), and an end-to-end warp of a
  synthetic image lands the output extent exactly on the footprint bbox in both cases.
  `fly_bearing()` adds a column without reordering rows, so the post-hoc
  `photos_sf <- fly_bearing(photos_sf)` cannot desynchronise `fp_idx` from `footprints`.
- `fly_warn_unsized()` — with `dem`, an empty geometry can still only arise from an
  unresolved format or an unparseable scale (`corrected` requires
  `is.finite(candidate) & candidate > 0`, so the DEM path never writes a non-finite
  half-side). The warning's pointer to `footprint_basis` / `format_size` stays accurate.

### Robustness probes (no crashes, correct answers)

- every frame unsized + `dem` → all `NA` terrain, all empty, no error
- zero-row input + `dem` → 0 rows
- DEM coarser than the footprint (4 km and 10 km cells against a 2.7 km frame) →
  coverage 1, `dem_agl`
- footprint smaller than one cell, and a zero half-side → no zero-cell-raster error in
  `terra::values(tmpl) <- 1L`
- 4 m DEM with a frame 700 km outside it → 2.26 s, 695 MB

### Housekeeping

- `devtools::test()`: `FAIL 0 | WARN 0 | SKIP 0 | PASS 222`
- `devtools::document()`: no diff — `man/` is in sync with the roxygen
- vignette renders clean end to end
- `lintr::lint_package()` reports `unused argument (dem = dem)` at five downstream call
  sites. That is the documented installed-vs-source artifact (the installed `fly` is
  0.4.0, whose `fly_footprint()` has no `dem` formal), not a defect.

## Round-6 verdict

One real finding: a guard test that cannot fail, on the newest fix in the branch. The
sixth round continues the pattern the first five established — and this time the defect
is in the *test* written to prove the fix, which is the same failure mode as R3's
"premise assertion that could not fail", one level out.
