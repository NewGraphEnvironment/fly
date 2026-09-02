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
