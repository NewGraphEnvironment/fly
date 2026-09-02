# Review round 2 — fly#37 geometry guard

Second pass, targeting round 1's fixes rather than the original change. Everything below
was measured by running, with `pkgload::load_all()` and bindings patched in **both**
`asNamespace("fly")` and `as.environment("package:fly")`. No source file was edited; the
tree is clean and `NAMESPACE` still carries exactly 9 `export(` lines after
`devtools::document()` (no `.Rd` written or deleted).

Suite: `FAIL 0 | WARN 0 | SKIP 0 | PASS 1295`.

## Findings

- **[fragile]** `R/fly_footprint.R:72-79` — the `sfc_GEOMETRY` clause added by round 1
  runs **before** the per-feature type check, so it also catches a GEOMETRY column that
  is *not* all points, and hands that caller a remedy that silently corrupts the data.
  The message is unconditional — `Use sf::st_cast(centroids_sf, "POINT")` — and its own
  text ("even when every feature in it is a point") is false for that input.

  Measured, on a 20-row GEOMETRY column holding 10 footprint POLYGONs and 10 centroid
  POINTs built from the bundled fixture:

  ```
  guard  -> `centroids_sf` has a mixed-geometry (GEOMETRY) column ... Use `sf::st_cast(centroids_sf, "POINT")`.
  after st_cast(x, "POINT"):  n = 20  (was 20)      <- row count unchanged, so nothing looks wrong
  guard now:                  ACCEPTED
  fly_footprint(recast):      nrow 20, duplicated airp_id 0
  displacement from the true centroid (m):
   [1] 1940 1940 1940 1940 1940 1940 1940 1940 1940 1940  0 0 0 0 0 0 0 0 0 0
  ```

  `st_cast()` on a mixed GEOMETRY column takes the **first vertex** of each polygon, not
  its centroid, so following the package's own error message relocates half the frames by
  1.94 km and the guard then passes them. Right row count, no warning — the same silent
  class the guard exists to close, reached by doing what the guard told you to do.

  Fix is a reorder, not new logic: run `!all(got == "POINT")` first. Verified — the mixed
  column then gets `` `centroids_sf` must be points, not POLYGON `` (whose `st_cast`
  advice *is* conditionally phrased, and whose primary advice is `st_filter()`), the
  all-POINT GEOMETRY column still gets the mixed-geometry message, and
  `test-fly_footprint_point_input.R` stays fully green. Note that no existing test
  distinguishes the two orderings.

- **[fragile]** `R/fly_footprint.R:65-72` (comment) and `R/fly_footprint.R:74-76` (user
  message) — both attribute the GEOMETRY failure to `sf::st_coordinates()`. Measured,
  `fly_footprint()` never reaches `st_coordinates()` for that input. With the clause
  removed, the backtrace is:

  ```
   7. └─fly::fly_footprint(gg)
   8.   ├─sf::st_transform(centroids_sf, 3005) at R/fly_footprint.R:526
  ...
  14.       └─sf:::CPL_transform(...)
  Error: Not compatible with STRSXP: [type=NULL].
  ```

  `st_transform()` fails first. And the STRSXP failure is not a property of
  `sfc_GEOMETRY` at all — a genuinely mixed point+polygon GEOMETRY column
  `st_transform()`s **fine** and would instead have died later inside
  `st_coordinates()`. So the two facts the comment states are each true in isolation
  (`st_coordinates(gg)` really does say "not implemented for objects of class
  sfc_GEOMETRY"; the caller really does see `Not compatible with STRSXP`) but the
  `because … and` that joins them is not, and it holds only for the one fixture shape.
  The test premise `expect_error(sf::st_coordinates(gg), "sfc_GEOMETRY")`
  (`test-fly_footprint_point_input.R:143`) is likewise true but is not the caller's path.

  This is the same class round 1 corrected two comments for, and it is load-bearing here:
  the stated justification for the clause is "`st_coordinates()` has no method", so
  someone who later finds sf has gained one has a written reason to relax a guard that
  `st_transform()` independently requires.

## Verified correct (attacked and held)

**The `nrow(x) > 0` clause is right and creates no hole.** `st_coordinates.sfc` returns
early on `length(x) == 0` before its `switch()`, so a zero-row GEOMETRY column is
genuinely readable. Measured, a `st_sf(scale = character(0), geometry = st_sfc())` passes
cleanly through all five: `fly_footprint`, `fly_coverage`, `fly_overlap`, `fly_select`,
`fly_filter`, all returning 0 rows. `nrow()` is well defined for every sf shape the
package accepts. Removing the clause turns the documented empty-query input into an
error — confirmed by breaking it (test at `:157` goes red).

**`inherits(st_geometry(x), "sfc_GEOMETRY")` is the right class test.**
`st_coordinates.sfc` dispatches on `class(x)[1]` and handles POINT / MULTIPOINT /
LINESTRING / MULTILINESTRING / POLYGON / MULTIPOLYGON, `stop()`ing otherwise.
`sfc_GEOMETRY` is the only unreadable class whose *per-feature* types can be all POINT —
`sfc_GEOMETRYCOLLECTION` and friends are caught by the type check with a correct message.
XYZ points pass and should: measured 3 features → `dim(st_coordinates()) == c(3, 3)`, a
column and not a row, and `fly_footprint()` sizes them fine.

**Nothing that previously worked and should still work is rejected.** All vignette and
`@examples` chains stay POINT: `fly_filter()`, `fly_select()` (both modes) return
`sfc_POINT`; `fly_overlap()`/`fly_coverage()` return tibbles. The two breaks (MULTIPOINT-
of-one, GEOMETRY columns) are deliberate and are in NEWS.

**Every comment claim in `fly_check_points()` re-measured and true:**

| claim | measured |
|---|---|
| sf keeps an aligned NA row for an empty POINT | 3 features → 3 coord rows, row 1 `NA NA` |
| an empty POINT is accepted, then fails `!anyNA(x) is not TRUE` | accepted; `fly_footprint()` errors with exactly that (fly#47 decision consistently implemented) |
| the empty geometries `fly_footprint()` emits are empty POLYGONs | `sfc_POLYGON`, `st_is_empty` TRUE, refused on type |
| MULTIPOINT expands like POLYGON | 20 features → 100 coord rows |
| MULTIPOINT-of-one would be harmless | 20 features → 20 coord rows |
| `st_sf(geometry = st_sfc())` carries `sfc_GEOMETRY` | yes |

**NEWS/comment measurements reproduced** with the guard replaced by a no-op:
`fly_footprint(poly)` 100 rows from 20; `fly_bearing()` 20 rows, max raw delta **272.8°**;
`fly_filter(method = "centroid")` 20 vs 7; `fly_filter(method = "footprint")` 14 vs 20;
`fly_coverage()` errors (`replacement has 100 rows, data has 20`); `fly_overlap()` returns
56 pairs silently; `fly_select()` 7 (minimal) / 14 (all) silently.

**Tests can fail.** Three deliberate breaks, each with a printed proof the broken code was
live:

| break | proof | result |
|---|---|---|
| drop the `sfc_GEOMETRY` clause | GEOMETRY column now `ACCEPTED` | `:145` red, reproducing `Not compatible with STRSXP: [type=NULL]` |
| move the `fly_georef()` guard below `dir.create()` | dir created despite refusal | `:102` red (`dir.exists` TRUE) |
| drop `nrow(x) > 0` | 0-row GEOMETRY now `REFUSED` | `:157`/`:158` red |

**`non_point_cases()` circularity does not mask a failure.** Patching `fly_footprint()` to
return the fly#37 expansion (40 rows from 20) makes the fixture error at its own premise —
`nrow(x) == nrow(centroids) is not TRUE` — rather than silently supply a degraded fixture,
and the loop head `names(non_point_cases())` evaluates before any `expect_error()`, so the
error cannot be swallowed by a regexp match.

**One exotic input noted and not reported as a finding:** an `sfc_POINT` column mixing XY
and XYZ features (constructible via `st_sfc()`, not reachable from a GDAL read) passes the
guard and then fails loudly inside `st_coordinates()` with a dimnames error. Loud, not
silent, and outside the guard's stated scope.
