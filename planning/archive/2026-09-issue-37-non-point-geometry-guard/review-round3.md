# Review round 3 — fly#37, scoped to `fly_check_points()`

Third pass, scoped as asked to `fly_check_points()` (`R/fly_footprint.R:83-107`) and
`tests/testthat/test-fly_footprint_point_input.R`. Everything below was measured by
running under `pkgload::load_all()` on sf 1.1.2 / R 4.5.2, with bindings patched in **both**
`asNamespace("fly")` and `as.environment("package:fly")` and a printed proof the patched
code was live before each result. No source file was edited; `git status --porcelain` is
empty.

- Full suite: `FAIL 0 | WARN 0 | SKIP 0 | PASS 1300`.
- `devtools::document()`: `NAMESPACE` unchanged at **9** `export(` lines, no `.Rd` written
  or deleted, tree clean afterwards. (The two roxygen notices about `georef_one` and
  `fly_georef_gcps` are pre-existing undocumented-internal messages, not churn.)

**Not clean.** Three findings, one of which is the mechanism behind round 2's.

---

## Findings

- **[fragile]** `R/fly_footprint.R:88-97` (clause B's message) and
  `tests/testthat/test-fly_footprint_point_input.R:198-204` — **round 2's reorder moved
  the destructive remedy from one clause's sentence into the other's; it did not remove
  it.** Clause B's message also ends in `sf::st_cast(x, "POINT")`, and that advice is
  unsafe on every input clause B can receive except MULTIPOINT-of-one.

  Measured, running the advice the caller is actually handed:

  ```
  case                  in  after st_cast   guard on result   fly_footprint()
  POLYGON               20     100          ACCEPT            100 rows, 80 dup airp_id
  MULTIPOLYGON          20     100          ACCEPT            100 rows
  MULTIPOINT            20     100          ACCEPT            100 rows
  LINESTRING            20     100          ACCEPT            100 rows
  MULTILINESTRING       20     100          ACCEPT            100 rows
  MULTIPOINT-of-one     20      20          ACCEPT             20 rows, 0 m moved   <- safe
  GEOMETRYCOLLECTION    20      20          ACCEPT             20 rows, 0 m moved   <- safe
  mixed GEOMETRY        20      20          ACCEPT             20 rows, 1940 m moved
  ```

  The first row is the package's own reproduction of #37 — **20 frames in, 100 rows out,
  80 of them carrying another photo's attributes** — reached by following the error
  message written to prevent it. The guard then accepts the result, because the guard
  tests *shape* and `st_cast(x, "POINT")` always produces the right shape.

  The last row is round 2's exact fixture, unchanged. Reordering routed it from clause C
  to clause B, and clause B offers the same remedy: 20 rows in, 20 rows out, guard
  ACCEPTED, ten frames displaced 1,940 m. Verified the delivered message really does
  contain it — `grepl("st_cast", msg)` is `TRUE` for the mixed column.

  **So the answer to "what invariant does the ordering rest on" is that the ordering was
  never the load-bearing thing.** Ordering decides *which sentence* carries the advice;
  it cannot make the advice safe, because both sentences carry it. The round-2 fix is
  correct as far as it goes — the POLYGON message is a better message — but its stated
  justification ("whose `st_cast` advice *is* conditionally phrased, and whose primary
  advice is `st_filter()`") does not hold up when the advice is run.

  The test at `:198-204` is what makes this look closed. It pins the destructiveness of
  *the message that is no longer delivered*:

  ```r
  # And the remedy the other message would have offered really is destructive,
  recast <- suppressWarnings(sf::st_cast(mixed, "POINT"))
  expect_gt(max(moved), 1000)
  ```

  The assertion is true and can fail, so it is not a test passing for the wrong reason —
  but "the other message" is wrong. The remedy is in the message this input *does* get,
  and the test proves the delivered advice is destructive while its comment reads as
  proof that it is safe.

  Mitigations worth stating rather than assuming: the POLYGON case changes the row count
  visibly (20 → 100) and `st_cast` emits `repeating attributes for all sub-geometries…`;
  the mixed case emits ten `point from first coordinate only` warnings. Neither is fly's,
  and the round-2 test suppresses the latter.

  Smallest fix consistent with the guard's purpose: make the `st_cast` clause conditional
  on the case where it is safe, i.e. only offer it when `all(got %in% c("POINT",
  "MULTIPOINT"))` and `nrow(st_coordinates(x)) == nrow(x)`, and otherwise lead with
  `st_filter()` alone. That is a one-branch change and is checkable — the table above is
  the test.

- **[fragile]** `R/fly_footprint.R:84-86` — **clause A (the `inherits(x, "sf")` test) is
  reached by no test in the suite, and nothing enforces that it runs first, although
  clauses B and C both require it.**

  Both of the suite's non-sf inputs stop earlier:
  `test-fly_footprint.R:43` (`fly_footprint(data.frame(x = 1))`) is answered by
  `fly_footprint()`'s **own** duplicate check at `R/fly_footprint.R:500`, and
  `test-fly_georef.R:74` errors on the `fly_fetch` check at `R/fly_georef.R` long before
  `fly_check_points()`. No test passes a non-sf object to `fly_bearing()`,
  `fly_select()`, `fly_filter()`, `fly_overlap()`, `fly_georef()` or `fly_coverage()` —
  the six call sites for which clause A is the *only* type check.

  Enumerating all six orderings against the point-input file, with a printed probe
  confirming each patch was live:

  | order | file result | non-sf caller gets |
  |---|---|---|
  | **A B C** (current) | PASS 45 | `` `photos_sf` must be an sf object. `` |
  | B A C | **PASS 45** | `no applicable method for 'st_geometry' applied to … "data.frame"` |
  | B C A | **PASS 45** | same |
  | A C B | FAIL 1 | — |
  | C B A | FAIL 1 | — |
  | C A B | FAIL 1 | — |

  So **every reordering that moves C above B is caught** (all three fail at
  `test-fly_footprint_point_input.R:186`, `expect_error(fly_footprint(mixed), "must be
  points, not POLYGON")` — verified by backtrace, it is that line and not something
  incidental). **Every reordering that only moves A is uncaught.** Deleting clause A
  outright is likewise invisible to the file.

  Harmful or merely different: **merely different, but in the direction the guard exists
  to close.** No corruption — the input still errors — but the caller gets an sf-internal
  message naming neither the argument, the function nor the package, which is round 1's
  own stated argument for adding the GEOMETRY clause. And the invariant is real, not
  stylistic: `nrow()` of a bare `sfc` is `NULL`, so clause C evaluates
  `logical(0) && inherits(...)`, which is `FALSE` for an `sfc_POINT` but `NA` for an
  `sfc_GEOMETRY` — measured, clause C alone on a bare `sfc_GEOMETRY` dies with
  `missing value where TRUE/FALSE needed`.

  Cheapest close: one `expect_error(fly_bearing(data.frame(x = 1)), "must be an sf
  object")` (any of the six exports other than `fly_footprint`, whose duplicate check
  would mask it). That single assertion makes B-before-A and the deletion both red.

- **[fragile]** `tests/testthat/test-fly_footprint_point_input.R:133-137` — the comment
  round 2 had corrected in `R/` survives verbatim in the test file.

  > `# st_coordinates() has no sfc_GEOMETRY method. Without this the guard passes on`
  > `# the per-feature types — all POINT — and the caller sees`
  > `# `Not compatible with STRSXP: [type=NULL]` several layers down`

  Re-measured this pass, both halves independently:

  ```
  st_transform(all-POINT GEOMETRY)   -> Not compatible with STRSXP: [type=NULL].
  st_transform(mixed GEOMETRY)       -> ok
  st_coordinates(mixed GEOMETRY)     -> not implemented for objects of class sfc_GEOMETRY
  ```

  `st_coordinates()` is never reached on the all-POINT path, so the `because` joining the
  two sentences is the same false causal claim round 2 filed — the `R/` copy was fixed
  (its table at `R/fly_footprint.R:50-53` is accurate) and this copy was not. It sits
  directly above `expect_error(sf::st_coordinates(gg), "sfc_GEOMETRY")` at `:143`, which
  is a true assertion about a path the caller does not take, so the comment is the only
  thing telling a future maintainer what that premise means. Same fix-one-copy pattern as
  the finding above.

---

## Q2 — the clause set is complete, and the residual is definitional

Verified independently of round 2 rather than inherited.

`sf:::st_coordinates.sfc` returns early on `length(x) == 0`, then `switch(class(x)[1], …)`
over exactly six classes — `sfc_POINT`, `sfc_MULTIPOINT`, `sfc_LINESTRING`,
`sfc_MULTILINESTRING`, `sfc_POLYGON`, `sfc_MULTIPOLYGON` — and `stop("not implemented for
objects of class …")` otherwise.

The closure argument is a property of `st_sfc()`, not an observation about the fixtures:
the sfc class is derived from the per-feature types, one unique type giving `sfc_<TYPE>`
and more than one giving `sfc_GEOMETRY`. `st_read()` builds its column the same way.
So **all-POINT per-feature types ⟹ sfc class ∈ {`sfc_POINT`, `sfc_GEOMETRY`}**, and the
only route to the second is an explicit `st_cast(x, "GEOMETRY")` or a manual `class<-`.
Confirmed by construction (`st_sfc(POINT, POINT)` → `sfc_POINT`;
`st_sfc(POINT, MULTIPOINT)` → `sfc_GEOMETRY`) and by sweeping `st_cast()` over all **18**
geometry types sf enumerates — only `GEOMETRY` and `POINT` produce an all-POINT column,
the other 16 either change the per-feature type (caught by clause B) or refuse the cast.

The set is therefore closed and nameable, not "nothing else has come up". Two residual
axes, both stateable precisely:

| residual | state | verdict |
|---|---|---|
| empty POINT inside an `sfc_POINT` | accepted, then `!anyNA(x) is not TRUE` | pre-existing, deliberate, fly#47 — reproduced from a GPKG round trip |
| `sfc_POINT` mixing XY and XYZ | accepted | **benign, and round 2 mis-stated it** |

The second is worth correcting in round 2's record. Round 2 reported it "fails loudly
inside `st_coordinates()` with a dimnames error". Measured this pass, `fly_footprint()`
does **not** fail — it returns the right number of rows with **0 m** displacement, both
when the input CRS is 4326 and when it is already 3005, because every read of caller
geometry in the package goes through `st_transform()` first (`fly_footprint.R:541-542`,
`fly_bearing.R:43-44`) and `st_transform()` normalises the column to XY. So round 2 was
right about `st_coordinates()` in isolation and wrong about the caller's path — the same
shape as the finding round 2 itself filed — but the error is in the safe direction.
Reachability is nil in any case: GPKG, GeoJSON and shapefile round trips all drop Z and
return a uniform XY column.

Also checked and harmless: an `sf` carrying a second, inactive `sfc` column (guard
accepts, `fly_footprint()` returns 20 correct rows).

## Q3 — clause C's advice is safe; clause A emits none

Clause C now receives only all-POINT `sfc_GEOMETRY` with `nrow > 0`. Ran its advice on
every such input:

```
all-POINT GEOMETRY        20 -> 20   guard ACCEPT   max move 0 m   fp 20 rows
all-POINT GEOMETRY (XYZ)  20 -> 20   guard ACCEPT   max move 0 m   fp 20 rows
```

Safe. Clause A gives no remedy, so there is nothing to follow. Clause B is the finding
above.

## Checked and clean

- **The B-before-C ordering is genuinely enforced**, by `:186`. All three orderings that
  invert it fail there, and the round-2 fixture's two premises (`inherits(…,
  "sfc_GEOMETRY")`, `expect_setequal(…, c("POINT", "POLYGON"))`) can both fail — neither is
  satisfied by the happy path's own structure.
- **`nrow(x) > 0` in clause C** — still load-bearing and still correct; the zero-row
  `sfc_GEOMETRY` acceptance is pinned at `:157`.
- **No test passes for the wrong reason in the new file.** `non_point_cases()` asserts its
  own premises; the `expect_error()` patterns are regex-inert with respect to their
  backticks; the vacuous zero-row pass is asserted deliberately. The one comment-level
  defect is finding 3.
- **Suite, NAMESPACE, `.Rd`** as recorded at the top.

## Convergence

Rounds 1 and 2 each found their best finding inside the previous round's fix, and this
round does the same — but the class has now been named rather than instanced: the guard's
messages recommend a remedy that produces exactly the shape the guard accepts, so no
arrangement of the clauses can make the advice safe. That is a statement about the whole
message set, and the candidate input set behind it is closed (Q2). If the clause-B advice
is made conditional on the case where it is safe, and one assertion is added for clause A,
I do not see a fourth round having a target — the residuals are definitional, not
"unlikely".
