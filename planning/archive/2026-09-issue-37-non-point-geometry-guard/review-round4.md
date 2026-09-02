# Review round 4 — fly#37, scoped to commit `88c73f9`

Fourth pass, scoped as asked to the newest commit only ("Offer the st_cast remedy only
where it cannot defeat the guard"). Everything below was measured by running under
`pkgload::load_all()` on sf 1.1.2 / R 4.5.2. Where the prior version was restored, the
bindings were patched in **both** `asNamespace("fly")` and `as.environment("package:fly")`
with a printed proof the patched code was live. No source file was edited;
`git status --porcelain` is empty.

- Full suite: `FAIL 0 | WARN 0 | SKIP 0 | PASS 1309`.
- `devtools::document()`: `NAMESPACE` unchanged at **9** `export(` lines, no `.Rd` written
  or deleted, tree clean afterwards. (The two roxygen notices about `georef_one` and
  `fly_georef_gcps` are the pre-existing undocumented-internal messages, not churn.)
- The commit's own claim that the new test goes red against the unconditional version
  holds: restored, the file gives **FAIL 5 | PASS 53**, failing in
  `"a GEOMETRY column holding polygons is refused as polygons, not as GEOMETRY"` and
  `"the guard never recommends a cast that would defeat it"`.

**Not clean.** One finding, and it is the same class again: `cast_keeps_rows` is a proxy,
and the hole is reachable.

---

## Findings

- **[bug]** `R/fly_footprint.R:98-107` — **`nrow(st_coordinates(x)) == nrow(x)` is a sum,
  and a sum cannot see a redistribution across features.** A homogeneous MULTIPOINT column
  in which one frame carries two vertices and one frame is empty satisfies it, so the
  guard offers `st_cast()`, and following that advice shifts every frame's geometry one
  position against its attributes — **18 of 19 frames wrong by up to 20.4 km**, row count
  preserved, no duplicated `airp_id`, and the guard then ACCEPTS the result.

  Built from the bundled fixture: frame 1 digitised twice, frame 20 with no location
  recorded, everything else a single point. Both ingredients are live in this package's
  own record — MULTIPOINT is the input fly#37 proposed accepting and the comment at
  `R/fly_footprint.R:36-40` refuses deliberately, and empty geometry is fly#47,
  documented at `R/fly_footprint.R:30-34` as "reproduced from a GPKG round trip".

  ```
  n = 20   nrow(st_coordinates(x)) = 20   ->  cast_keeps_rows = TRUE

  message the caller gets:
    `centroids_sf` must be points, not MULTIPOINT. ... use `sf::st_filter()`.
    If these really are centroids in another form, `sf::st_cast(centroids_sf, "POINT")`.

  following it:   rows 20 -> 20    dup airp_id 0    guard on result: ACCEPT

  displacement of each frame from its true centroid (m):
      0 16559 11912 5837 10202 12235 6506 2490 9026 12574
   8068 11356  2758 5443 10984 20374 15490 6695 6031   NA
  ```

  The mechanism is that `st_cast()` produced 20 point geometries (2 from frame 1, 1 each
  from frames 2-19, 0 from frame 20) and the attribute frame kept its own 20 rows
  unexpanded, so `BC002` receives `BC001`'s second vertex, `BC003` receives `BC002`'s, and
  so on down. **Unique ids, right row count, right shape** — every property the guard
  tests, and every property #37 taught it to test.

  It reaches a caller. Measured on the same object:

  ```
  fly_bearing(recast)     OK, 20 rows            <- bearings from shifted points
  fly_overlap(recast)     ERROR !anyNA(x)        <- fly#47, not this guard
  fly_footprint(recast)   ERROR !anyNA(x)        <- fly#47

  the natural next step, dropping the frame with no location (fly#47):
    rows 19, all POINT, guard ACCEPT
    fly_footprint()  ->  19 rows, footprint_basis "Film - BW", NO ERROR, NO WARNING
    footprint centres displaced: 0 16559 11912 5837 ... 6031 m
    frames wrong by >100 m: 18 of 19
  ```

  So the empty frame that makes the arithmetic coincide is also the thing fly#47 stops on
  — but only until the caller removes it, which is what fly#47's message asks for. After
  that the whole pipeline is silent.

  **It does not need the 1-and-1 coincidence.** Any layer where the extra vertices equal
  the unlocated frames trips it:

  ```
  1 dup-digitised + 1 unlocated   coords=20 n=20  offers_cast=TRUE  17 of 19 wrong, max 20374 m
  2 dup-digitised + 2 unlocated   coords=20 n=20  offers_cast=TRUE  16 of 18 wrong, max 12337 m
  3 dup-digitised + 3 unlocated   coords=20 n=20  offers_cast=TRUE  15 of 17 wrong, max 15840 m
  ```

  **Which types can carry it, measured rather than reasoned.** The break needs a feature
  contributing zero coordinates, which only an empty geometry does — so the vector is any
  homogeneous non-POINT type whose `st_coordinates()` tolerates an empty:

  ```
  empty MULTIPOINT among MULTIPOINTs   st_coordinates() -> no error   <- reachable
  empty LINESTRING among LINESTRINGs   st_coordinates() -> no error   <- reachable
  empty POLYGON among POLYGONs         number of columns of matrices must match (see arg 2)
  sfc_GEOMETRY                         not implemented for objects of class sfc_GEOMETRY
  sfc_GEOMETRYCOLLECTION               not implemented for objects of class sfc_GEOMETRYCOLLECTION
  ```

  POLYGON and MULTIPOLYGON are blocked by accident, not by the condition — the empty
  breaks `st_coordinates()` before the sum is taken. That is worth stating because it is
  exactly the kind of incidental protection that disappears when sf tightens a method.

  Mitigation, stated rather than assumed: `st_cast()` does warn —
  `number of items to replace is not a multiple of replacement length` — on every case
  above. It is a base-R length warning that names nothing about geometry, it is the same
  class of external warning round 3 correctly declined to count as protection for the
  POLYGON case, and `suppressWarnings()` around a cast is ordinary user code.

  **This is a proxy, in the sense `CLAUDE.md` already names twice.** The property wanted
  is per-feature — *each feature contributes exactly one coordinate* — and the condition
  tests it in aggregate, so it is blind to any redistribution that conserves the total.
  Same family as "a cross-item consistency check cannot see a defect that hits every item"
  and "a guard that encodes the cause you measured is a proxy for the property you want".

  Two fixes, both measured against every case in the sweep plus the breaking input, and
  both withhold on the break while keeping the advice on `MULTIPOINT-of-one`:

  ```
  case                 current   per-feature   count + no-empty
  POLYGON              FALSE     FALSE         FALSE
  MULTIPOINT           FALSE     FALSE         FALSE
  LINESTRING           FALSE     FALSE         FALSE
  MULTIPOINT-of-one    TRUE      TRUE          TRUE
  GEOMETRY-of-points   FALSE     FALSE         FALSE
  GEOMETRY-mixed       FALSE     FALSE         FALSE
  BREAKING             TRUE      FALSE         FALSE     <-- the finding
  ```

  ```r
  # per-feature: the last column of st_coordinates() is the feature index
  co  <- st_coordinates(x)
  ok  <- all(tabulate(as.integer(co[, ncol(co)]), nbins = nrow(x)) == 1L)

  # or, count + the one thing that can break the sum
  ok  <- nrow(st_coordinates(x)) == nrow(x) && !any(sf::st_is_empty(sf::st_geometry(x)))
  ```

  The second is the smaller change and its closure argument is stateable: a non-empty
  feature contributes at least one coordinate, so "no empties" plus "the total equals the
  feature count" forces exactly one each. The first needs no such argument but relies on
  the last-column convention of `st_coordinates()`.

  The comment at `R/fly_footprint.R:99-101` states the proxy as an equivalence — *"cast is
  safe **exactly when** the coordinate count already equals the feature count"* — and the
  case above is the counterexample to the direction that matters. That sentence is the
  third comment on this PR asserting something not measured, and it is the one that will
  stop the next reader from looking.

---

## Q1 — the `tryCatch` swallows nothing it should propagate

Enumerated what `st_coordinates()` can throw for an input that has already failed the
type test (measured, above): three "cannot read this column" errors and one matrix-shape
error from an empty POLYGON. Every one of them means *the cast cannot be reasoned about*,
which is a "no" and not a condition to re-raise — and the function is on its way to
`stop()` in the next expression regardless, so propagating would only replace a good
message with a worse one. `tryCatch(error = )` does not intercept interrupts, so nothing
user-facing is masked either. **No finding.**

The one thing worth naming: the empty-POLYGON error is doing load-bearing work it was
never intended to do (it is what keeps POLYGON off the finding above), so this handler is
currently the only reason a whole type family is safe. Fixing the condition removes that
dependency.

## Q2 — the sweep's scope is sound, but its assertion is the guard's own predicate

Measured which cases actually enter the loop body:

| case | `keeps` | enters loop | clause |
|---|---|---|---|
| POLYGON | FALSE | FALSE | B |
| MULTIPOINT | FALSE | FALSE | B |
| LINESTRING | FALSE | FALSE | B |
| **MULTIPOINT-of-one** | TRUE | **TRUE** | B |
| **GEOMETRY-of-points** | FALSE | **TRUE** | **C** |
| GEOMETRY-mixed | FALSE | FALSE | B |

**Clause coverage is complete and not a coincidence.** Both clauses that can emit an
`st_cast` recommendation are reached — clause B through `MULTIPOINT-of-one`, clause C
through `GEOMETRY-of-points` — and clause C's message is *unconditional*, so that case is
the only one in the sweep where the row-count assertion is an independent check. Round 3's
own gap note (covering one clause would make the scope a coincidence of which clause
answered first) was correctly acted on.

**Neither premise can be satisfied by structure, and one has no margin.** `any(!keeps)` is
carried by five cases; `any(keeps)` is carried by exactly one, `MULTIPOINT-of-one`. That
is the single-member-no-margin shape `CLAUDE.md` records from gq#77 — remove or change
that one fixture and the premise fails, which is the correct direction, but there is
nothing between it and vacuity. A mitigating fact worth writing down rather than
rediscovering: `any(keeps)` being TRUE *implies* the loop body runs at least once, because
clause B offers the cast exactly when `keeps` holds, so the premise is a genuine
non-vacuity guard for clause B. It says nothing about clause C — drop
`GEOMETRY-of-points` and both premises still pass with clause C unswept.

**The defect is the assertion, not the scope.** Inside the loop the sweep asserts
`expect_equal(nrow(recast), nrow(cases[[nm]]))` — which for clause B is the guard's own
condition restated. The guard offers the cast only when the coordinate count equals the
row count; the test then checks that the cast keeps the row count. Ran the shipped
assertion against the breaking input:

```
message offers st_cast: TRUE
expect_equal(nrow(recast), nrow(brk)):  PASSES     <- the shipped assertion
frames displaced >100 m: 18 of 19,  max 20374 m
```

So the sweep would admit the finding above without going red. It validates the guard
against its own predicate — the same shape as `CLAUDE.md`'s "a reference generated by
feeding your artifact to the consumer is circular", one level in. The assertion that
discriminates is displacement, not row count: cast, then require every point to be
`st_equals()` its original geometry (or within a tolerance of it), which is the property
"non-destructive" actually means and which the row count only stands in for.

## Q3 — the three-of-seven coverage is harmless, and the reason is checkable

Measured what each call site does with a non-`sf` object:

```
fly_footprint   `centroids_sf` must be an sf object.      <- its OWN duplicate check
fly_bearing     `photos_sf` must have `film_roll` and `frame_number` columns.
fly_bearing(+)  `photos_sf` must be an sf object.          <- tested
fly_overlap     `photos_sf` must be an sf object.          <- tested
fly_select      `photos_sf` must be an sf object.          <- tested
fly_filter      `photos_sf` must be an sf object.          <- untested, same path
fly_coverage    `photos_sf` must be an sf object.          <- untested, same path
fly_georef      `fetch_result` must be output from `fly_fetch()`.
```

`fly_filter()` and `fly_coverage()` take the identical path through the identical clause
with no logic of their own between the entry point and it, so they are covered by
construction rather than by luck — deleting clause A makes the three tested exports red,
and there is no edit that breaks these two while leaving those three green.
`fly_footprint()` is genuinely masked, and by a check emitting the *same string*, so a
test there would pass against a deleted clause A — the comment at
`test-fly_footprint_point_input.R:255-258` says exactly this and is correct.
`fly_georef()` stops earlier on its `fly_fetch` contract. **No finding**; the omission is
justified and the justification is the one written down.

## Q4 — comment claims, each re-measured

| claim | location | verdict |
|---|---|---|
| POLYGON: 20 rows in, `st_cast`, 100 out, guard ACCEPTS, 80 duplicated `airp_id` | `R/fly_footprint.R:94-97`, test `:229-232` | **true** — measured 20 → 100, dup 80, ACCEPT |
| mixed column moves each polygon to its first ring vertex, 1,940 m, row count unchanged | `R/fly_footprint.R:97-98`, test `:190-192` | **true** — 20 → 20, max 1940 m |
| `nrow()` of a bare `sfc` is `NULL`, so the GEOMETRY clause alone aborts with "missing value where TRUE/FALSE needed" | test `:260-263` | **true** — reproduced verbatim |
| `fly_bearing()` checks its required columns before the geometry guard | test `:264-265` | **true** — see Q3 table |
| `st_coordinates()` throws on an unreadable column, "a no rather than an error to propagate" | `R/fly_footprint.R:101-102` | **true** — see Q1 |
| "cast is safe **exactly when** the coordinate count already equals the feature count" | `R/fly_footprint.R:99-101` | **FALSE** — the finding above is the counterexample |

## Checked and clean

- **Attempted breaks that the condition correctly refuses.** MULTIPOINT-of-one,
  MULTIPOINT-of-one with an empty (withheld though safe), GEOMETRYCOLLECTION-of-one-point
  (withheld though safe), CIRCULARSTRING (withheld, and the cast errors so withholding is
  right), empty POLYGON among POLYGONs, `sfc_GEOMETRY` in every arrangement, XYZ.
- **The conservative direction, named rather than assumed.** Advice is withheld where the
  cast would in fact be safe for: any GEOMETRYCOLLECTION, any column containing an empty
  geometry even where the mapping is 1:1, and any type `st_coordinates()` has no method
  for. All are the acceptable direction, and the count + no-empty fix above widens exactly
  the second of them, which is the one the finding requires.
- **Clause C's cast is still safe.** POINT → POINT is 1:1 including empties, so the
  unconditional recommendation in the GEOMETRY clause has no equivalent hole; re-derived
  rather than inherited from round 3.
- **The commit's restore-the-bug claim.** Verified independently — 5 failures against the
  pre-`88c73f9` guard, with a printed proof the patched binding was live.
- **Suite, `NAMESPACE`, `.Rd`, tree** as recorded at the top.

## Convergence

Round 3 named the class — the guard's remedy produces the shape the guard accepts — and
the fix tests the right *property* at the wrong *granularity*: a per-feature invariant
checked as a total. That is one step in from round 3's finding rather than a new class, so
the recursion has narrowed rather than moved.

I would not call this terminal. What I can state precisely is the remaining candidate set
for **this** condition: a break requires a feature contributing zero coordinates, and only
an empty geometry does that, so `!any(st_is_empty(...))` closes it by construction rather
than by enumeration — which is the kind of residual round 3 was reaching for. Once the
condition is per-feature, the sweep's assertion still needs to move from row count to
displacement, or the next instance of this class will pass it too.
