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
