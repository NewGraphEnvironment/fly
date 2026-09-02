# Review round 1 — fly#37 point guard (`fly_check_points`)

Reviewed: staged diff (`NAMESPACE`, `R/fly-package.R`, `R/fly_bearing.R`,
`R/fly_coverage.R`, `R/fly_filter.R`, `R/fly_footprint.R`, `R/fly_georef.R`,
`R/fly_overlap.R`, `R/fly_select.R`, `tests/testthat/setup.R`,
`tests/testthat/test-fly_footprint_invariants.R`,
`tests/testthat/test-fly_footprint_point_input.R`).

Verified by running, not by reading: full suite `FAIL 0 | WARN 0 | SKIP 0 | PASS 1286`;
`devtools::document()` leaves `NAMESPACE` byte-identical at **9** `export(` lines; every
edge case below was measured against `pkgload::load_all()` on sf 1.1.2.

---

## Findings

### 1. **[fragile]** `R/fly_footprint.R:33-36` — the guard admits `sfc_GEOMETRY`, and the comment says that is deliberate and safe. It is not processable.

The comment states the per-feature test is chosen over `class(st_geometry(x))[1] ==
"sfc_POINT"` because the class test "rejects a GEOMETRY-typed column that happens to hold
only points, **which is a legitimate input**".

Measured — it is not a legitimate input. `sf::st_coordinates()` has no `sfc_GEOMETRY`
method:

```
guard verdict on GEOMETRY-of-points: ACCEPTED
st_coordinates(sfc_GEOMETRY)   -> ERROR: not implemented for objects of class sfc_GEOMETRY
fly_footprint(GEOMETRY)        -> ERROR: Not compatible with STRSXP: [type=NULL].
fly_bearing(GEOMETRY)          -> ERROR: Not compatible with STRSXP: [type=NULL].
fly_filter(GEOMETRY, centroid) -> ERROR: Not compatible with STRSXP: [type=NULL].
```

(reproduce: `gg <- sf::st_cast(centroids, "GEOMETRY")`, then any guarded function.)

Why it matters rather than being cosmetic:

- The guard's whole purpose is to turn an unusable geometry into an error that names the
  argument and the fix. For this input it passes the guard and dies several layers down
  with `Not compatible with STRSXP: [type=NULL].` — naming neither the argument, the
  function, nor the package. That is the exact failure mode the guard exists to replace.
- The comment is the reason a future maintainer will *not* tighten this. It reads as a
  measured justification and it is a wrong one, so the hole is documented as a feature.
  Reachable in practice through `st_cast(x, "GEOMETRY")`, a PostGIS `geometry`-typed
  column, or a mixed-geometry GeoJSON.
- It is **not** a reintroduction of #37 — `st_coordinates()` errors rather than returning
  the wrong number of rows, so no silent row multiplication. Severity is "opaque error",
  not "corrupt data".

Fix is one clause, and it keeps the per-feature test for the mixed-type case:

```r
got <- as.character(sf::st_geometry_type(x))
if (!all(got == "POINT") || inherits(sf::st_geometry(x), "sfc_GEOMETRY")) { ... }
```

with the message extended for the column-type case, and the comment corrected. Note the
zero-row `sf` built by `st_sf(id = integer(0), geometry = st_sfc())` also carries an
`sfc_GEOMETRY` column, so a naive `inherits()` clause must keep the `nrow == 0`
acceptance the suite pins (`"zero-row input is still accepted"`).

### 2. **[fragile]** `R/fly_footprint.R:21-24` — the empty-geometry justification is wrong in both halves, and an empty POINT crashes opaquely.

The comment: *"sf keeps an ALIGNED NA row for an empty POINT, so n features always yield
n rows — **including the empty geometries `fly_footprint()` itself emits** for frames
whose format it cannot resolve. So no separate row-count assertion is needed behind this
one."*

Measured, on sf 1.1.2:

- The alignment claim itself is **true**: `st_sfc(point, empty_point, point)` gives 3
  coordinate rows, the middle one `NA NA`. Good.
- The clause about `fly_footprint()`'s own empty output is **false as stated**: those are
  empty **POLYGON**, which the guard refuses on type before alignment is ever consulted.
  That case can never reach the guard as a POINT, so it supports nothing.
- An empty POINT is accepted and then fails:
  ```
  guard verdict on empty POINT:  ACCEPTED
  fly_footprint(empty POINT)  -> ERROR: !anyNA(x) is not TRUE
  ```
  (from `sf::st_polygon()` on the all-`NA` ring the NA coordinate row produces.)

Pre-existing — the guard is a no-op for POINT, so this is not a regression. The diff's
contribution is asserting the case is handled when it is not. Either refuse empty
geometry in the guard (consistent with `footprint_basis` reporting elsewhere), or emit an
empty footprint for it as the unknown-format path already does — but do not leave the
comment claiming it is covered.

### 3. **[fragile]** `R/fly_footprint.R:26-30` — MULTIPOINT-of-one is a real behaviour break for input that previously worked correctly.

Confirmed the shape is harmless today:

```
B) coords rows: 20 vs nrow 20     # st_cast(centroids, "MULTIPOINT")
B) fly_footprint -> ERROR: `centroids_sf` must be points, not MULTIPOINT.
```

So a caller whose points arrive as MULTIPOINT — a PostGIS `MULTIPOINT`-typed column, some
OGR drivers' promote-to-multi behaviour — had a correct pipeline before this diff and gets
a hard error after it. The decision is deliberate, argued in the comment, and the message
names the one-line fix (`st_cast(x, "POINT")`), so this is flagged for the release note
rather than as a defect. Worth a `NEWS.md` line, because nothing else will tell those
callers why a working script stopped.

---

## Checked and clean

- **Q2 — placement at all seven sites.** Verified individually:
  - `fly_footprint:458` — after the `inherits()` check (message identical, so the
    duplication is inert), **before** the `scale` check. Existing
    `expect_error(fly_footprint(pt), "scale")` passes a POINT, so it is unaffected.
  - `fly_bearing:40` — after the `film_roll`/`frame_number` check, which
    `test-fly_bearing.R:50` pins. `non_point_cases()` asserts both columns are present, so
    the guard is genuinely reached rather than short-circuited. Premise asserted correctly.
  - `fly_coverage:26` and `fly_overlap:35` — **before** `sf_use_s2(FALSE)`, so a refusal
    leaves the s2 global untouched. Correct ordering.
  - `fly_filter:35`, `fly_select:50` — after `match.arg()`, before any work.
  - `fly_georef:158` — after `fetch_result`/`rotation` validation, before `dir.create()`,
    and the ordering is pinned by an `expect_false(dir.exists(dest))` on both sides.
- **Q3 — no unguarded path.** Every read of caller-supplied photo geometry is covered:
  `fly_bearing.R:41-42`, `fly_filter.R:46`, and everything else via `fly_footprint()`.
  `fly_georef.R:234`'s internal `fly_bearing(photos_sf)` is downstream of the guard.
  `fly_summary()` drops geometry; `fly_fetch()` reads only URL columns. Correct that
  neither is guarded.
- **Q4 — no assertion passing for the wrong reason.** `non_point_cases()` asserts its own
  premises (row count, per-case geometry type, `nrow(st_coordinates) > nrow`, required
  columns). The backticks in the new `expect_error()` patterns are regex-inert, so the
  tightened messages really do match. The zero-row vacuous pass is asserted deliberately.
  One inertness worth knowing rather than fixing: `fly_select()`'s guard is above the mode
  dispatch, so the `mode = "all"` and `mode = "minimal"` assertions exercise the same call
  — likewise `fly_filter()`'s two methods. True, but they cannot distinguish the paths the
  comments describe.
- **Q5 — legitimate POINT input unchanged.** Suite green at 1286 passes, including
  `"points still pass through unchanged"`. The guard is a pure no-op on POINT.
- **Roxygen/export integrity.** `fly_check_points()` sits between two `#`-commented
  internal helpers, not below a `#'` block, so nothing was rebound.
  `devtools::document()` reproduces `NAMESPACE` exactly; 9 exports intact; the
  `st_geometry_type` import is present in both `fly-package.R` and `NAMESPACE`.
- **Zero-row / empty-vector semantics.** `all(character(0) == "POINT")` is `TRUE`,
  accepted deliberately and pinned by a test that says so. A zero-row POLYGON also passes
  vacuously and yields 0 rows — harmless.
- **XYZ / XYM points.** Confirmed `st_coordinates()` gains a `Z`/`M` column but no rows,
  and both `fly_footprint.R:188-189` and `fly_bearing.R:57-58` index columns positionally
  (`1`, `2`). The comment's claim holds.

## Trivia (no action needed)

- `tests/testthat/test-fly_footprint_point_input.R` — `fake_fetch` is still constructed in
  `"every export that consumes centroids refuses non-point geometry"` but is now unused
  there, since the `fly_georef()` assertion moved to its own test.
- `tests/testthat/setup.R:167` is 124 chars against the repo's 120-char `.lintr`. No lint
  job in CI (`pkgdown.yaml` only), so nothing goes red.
