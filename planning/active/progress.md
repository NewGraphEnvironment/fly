# Progress — fly_footprint() drops footprint_basis and friends on tibble input (#35)

## Session 2026-08-29

- Plan-mode exploration — reproduced the defect, located the mechanism in
  `sf::st_sf()`, confirmed one call site, established the 225-test baseline
- User approved: preserve-input-class fix, class-shape sweep, v0.5.1 with #31
  folded in
- Created branch `35-fly-footprint-drops-footprint-basis-and` off main
- Scaffolded PWF baseline from issue #35 with approved phases
- Next: Phase 1 — regression tests that fail on unmodified source
