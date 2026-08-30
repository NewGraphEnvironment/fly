# Progress — fly_footprint() drops footprint_basis and friends on tibble input (#35)

## Session 2026-08-29

- Plan-mode exploration — reproduced the defect, located the mechanism in
  `sf::st_sf()`, confirmed one call site, established the 225-test baseline
- User approved: preserve-input-class fix, class-shape sweep, v0.5.1 with #31
  folded in
- Created branch `35-fly-footprint-drops-footprint-basis-and` off main
- Scaffolded PWF baseline from issue #35 with approved phases
- Next: Phase 1 — regression tests that fail on unmodified source

### Phase 1 — regression tests (complete)

- `centroid_shapes()` added to `tests/testthat/setup.R`: plain / `as_tibble = TRUE`
  / `group_by()` shapes of the bundled fixture, premise asserted inline
- Four tests added to `test-fly_footprint.R` — nominal sweep, `dem` sweep,
  class contract, downstream pass-through
- **Confirmed red on unmodified source**: the `tbl` and `grouped` shapes return
  `NULL` for all four columns where the `plain` shape returns the vectors
- The class-contract test passes on the broken code by design and is commented
  as such — it guards against the coercing fix, not against #35
