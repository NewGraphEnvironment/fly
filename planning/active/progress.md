# Progress — fly_footprint() silently returns 5x the rows when handed its own output (#37)

## Session 2026-09-01

- Plan-mode exploration — reproduced the 5x multiplication, then measured two
  defects the issue had not: `fly_bearing()` returns wrong bearings at the
  correct row count, and `fly_filter(method = "centroid")` bypasses
  `fly_footprint()` entirely
- Established that the issue's suggested `c("POINT", "MULTIPOINT")` guard
  reintroduces the bug; the guard must be POINT only
- Phases approved by user
- Created branch `37-fly-footprint-silently-returns-5x-the-ro` off main
- Spawned a Plan agent to review the design concurrently (not blocking)
- Next: Phase 1, failing tests

### Phase 1 — failing tests

- `non_point_cases()` added to `setup.R`: POLYGON, MULTIPOINT, LINESTRING, all
  built by casting the bundled footprints so each genuinely expands 20 features
  to 100 coordinate rows. Premises asserted inside the helper.
- MULTIPOINT is deliberate, not a third example: it is the case that fails
  against the issue's own suggested `c("POINT", "MULTIPOINT")` guard.
- Fixtures keep `film_roll` / `frame_number`, because `fly_bearing()` checks
  those columns before it touches geometry — without them the test would have
  passed for the wrong reason.
- Confirmed red against `main`: all rejection assertions fail, hitting testthat's
  10-failure cap.

### Phase 2 — the guard

- `fly_check_points(x, arg)` added at the top of `R/fly_footprint.R`, with the
  other internal helpers and well away from any roxygen block.
- Wired into **seven** entry points, not three. A background Plan review found
  that the four "inheriting" exports would report `centroids_sf` — an argument
  none of them has — and that the new test matched on `"must be points"` only,
  so the wrong argument name would have shipped green. Each now guards with its
  own parameter name and the tests assert that name.
- `fly_georef()`'s guard sits above `dir.create()`, so a refusal no longer leaves
  an empty output directory. Pinned by asserting the directory's absence.
- The helper also absorbs the `inherits(x, "sf")` check, keeping the `"sf object"`
  wording that `test-fly_footprint.R:43` pins.
- Error message now names the offending geometry type and the one-line fix
  (`sf::st_filter()` or `sf::st_cast()`), which is what makes the bet on
  `bcdata::collect()` returning POINT safe to hold.
- Suite green at 1286 passing, 0 failures, 0 warnings, 0 skips.

### Phase 4 — restore-the-bug verification

Neutralised `fly_check_points()` in **both** `asNamespace("fly")` and
`as.environment("package:fly")`, and printed proof the patch took rather than
assuming it. Pre-guard behaviour, points in parentheses:

| call | result |
|---|---|
| `fly_footprint(footprints)` | 100 rows (20) |
| `fly_footprint(MULTIPOINT)` | 100 rows (20) |
| `fly_bearing(footprints)` | 20 rows, max error 272.8 deg |
| `fly_filter(centroid)` | 20 rows (7) |
| `fly_overlap()` | 56 pair rows |
| `fly_select()` minimal / all | 7 / 14 rows |
| `fly_coverage()` | errors: replacement has 100 rows, data has 20 |

Then installed the issue's own suggested guard, `%in% c("POINT", "MULTIPOINT")`:
POLYGON refused, **MULTIPOINT still 100 rows**. The MULTIPOINT fixture is
therefore measured to discriminate the correct guard from the suggested one,
rather than assumed to.

### lintr

Each guarded file gains exactly one lint and `fly_footprint.R` — which defines
the helper — gains none. Confirmed as the documented installed-namespace
artifact, not a defect: `exists("fly_check_points", asNamespace("fly"))` is
FALSE while `exists("fly_warn_unsized", ...)` is TRUE, and the message is
`no visible global function definition`. Clears on reinstall.

### code-check round 1

Three findings, all reproduced before acting on them. Two were **false claims in
comments I had written** — asserted rather than measured, which is the failure
mode CLAUDE.md names:

- A `sfc_GEOMETRY` column holding only points passed the guard and then died with
  `Not compatible with STRSXP: [type=NULL]` — `st_coordinates()` has no method for
  that class. My comment had called it "a legitimate input" and cited it as the
  reason for the per-feature test. Now refused by name, with the `nrow(x) > 0`
  clause keeping zero-row input legal (`st_sf(geometry = st_sfc())` is also
  `sfc_GEOMETRY`). Both premises pinned by tests.
- The empty-POINT paragraph claimed the guard covered the empty geometries
  `fly_footprint()` emits. It does not — those are empty POLYGONs, refused on
  type. An empty POINT is accepted and then fails with `!anyNA(x) is not TRUE`.
  Pre-existing; left alone deliberately, because refusing the batch would
  contradict the per-frame reporting #30 established. Filed as fly#47 and the
  comment now says so.
- MULTIPOINT-of-one worked correctly before this change and is now refused. A
  real break for PostGIS MULTIPOINT columns and promote-to-multi OGR drivers, so
  it gets its own NEWS line rather than being left for someone to discover.

Suite 1295 passing, 0 failures.

### code-check round 2 — a blocker inside round 1's fix

Exactly the pattern the conventions predict: the second pass found its best
finding *inside* the first pass's fix.

- **Round 1's `sfc_GEOMETRY` clause ran before the per-feature type test**, so it
  also swallowed a GEOMETRY column holding polygons and told that caller to
  `sf::st_cast(x, "POINT")`. On a polygon `st_cast()` takes the **first vertex**,
  not the centroid. Reproduced on a half-footprint/half-centroid column: 20 rows
  in, 20 rows out, the guard then **accepted** the result, and ten frames had
  moved **1,940 m**. Following the guard's own advice reintroduced the silent
  corruption #37 exists to stop. Fixed by running the type test first, so a mixed
  column is told it "must be points, not POLYGON", whose advice leads with
  `st_filter()`.
- **The comment and message blamed `st_coordinates()`**, and measurement says
  where it fails depends on the column's contents: an all-POINT GEOMETRY column
  dies in `st_transform()` with `Not compatible with STRSXP`, while a mixed one
  transforms fine and dies later in `st_coordinates()`. Each fact was true and
  the causal claim joining them was not — the third comment in this guard
  corrected for asserting rather than measuring.
- Added the ordering test, which round 2 noted nothing distinguished. Verified it
  discriminates: under the old ordering the assertion
  `must be points, not POLYGON` does not match, so the test goes red.

Round 2 also re-measured every remaining claim in the guard's comment and every
number in NEWS, and broke three assertions deliberately to prove they can fail.
Suite 1300 passing, 0 failures.

### code-check round 3 — the mechanism, not another instance

Asked for the mechanism rather than more instances, and got it. Round 2's
reorder moved the destructive remedy from one clause's sentence into the
other's; it did not remove it. Both messages ended in `sf::st_cast(x, "POINT")`.

Reproduced: a homogeneous POLYGON column is told to cast, and following that
advice gives **100 rows from 20 with 80 duplicated `airp_id`** — issue #37
verbatim, reached by doing what the error message said. The guard then accepts
the result, because the guard tests *shape* and `st_cast()` always produces the
right shape.

So the ordering was never load-bearing. It decides which sentence carries the
advice; it cannot make the advice safe. Fixed by offering the cast only where it
provably keeps one row per feature, and asserted as a global invariant — IF the
message names `st_cast`, THEN casting must preserve the row count — which no
arrangement of the clauses can satisfy. Verified it goes red against the
unconditional version.

Two more, both fixed:

- **Clause A (`inherits(x, "sf")`) was reached by no test.** `fly_footprint()`
  has its own duplicate check, so the suite's only non-sf test answered there,
  and the six other exports had no non-sf test at all — for them clause A is the
  only type check. It is also load-bearing for ordering: `nrow()` of a bare
  `sfc` is `NULL`, so the GEOMETRY clause alone evaluates `logical(0) && ...`
  and aborts with "missing value where TRUE/FALSE needed". Now asserted for
  three exports; verified red when clause A is removed.
- **The false causal claim round 2 corrected in `R/` survived verbatim in the
  test file.** Fixed the second copy.

Round 3 also corrected round 2's own record: mixed XY/XYZ points are benign, not
"loud", because `st_transform()` normalises the column before any coordinate
read. Round 2 was right about `st_coordinates()` in isolation and wrong about
the caller's path — the same shape as the finding round 2 itself filed.

**One gap found in my own fix**, not by the reviewer: the invariant sweep covered
only the shapes reaching the type clause, while the GEOMETRY clause emits an
`st_cast` recommendation too. Covering one clause would have made the invariant's
scope a coincidence of which clause answered first — the same mistake the
ordering fix was about. Sweep widened; verified non-vacuous, with advice withheld
on all three destructive shapes and checked on both safe ones.

Suite 1309 passing, 0 failures.
