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
