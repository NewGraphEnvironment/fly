# Progress — fly_footprint() assumes a 9-inch negative (#30)

## Session 2026-08-28

- Plan-mode exploration of `fly_footprint()` and its five internal callers
- Established that GSD alone cannot yield footprint width; recorded the
  `pixel_pitch = GSD / scale` identification lever for the follow-up issue
- Phases approved by user; scope contained by handing sensor-width research
  to a separate issue
- Created branch `30-fly-footprint-assumes-a-9-inch-negative` off main
- Scaffolded `planning/` (first use in this repo) and the PWF baseline
- Next: Phase 1 — failing tests

### Phases complete

- Phase 1 `5137f85` — failing tests, mixed film/digital fixture
- Phase 2 `b2d2f91` — media-aware sizing, `footprint_basis`, `format_size`
- Phase 3 `287d1cc` — downstream reporting; fixed a group vanishing from
  `fly_coverage()` via `numeric(0)`
- Phase 4 `429a347` — docs, vignette, and a recovered `export(fly_footprint)`
- Phase 5 — research handed to #32

Suite 126 pass / 0 fail. lintr: 15 style lints before and after, none new.

Two bugs found that the issue did not name:

1. `fly_coverage()` dropped an entire group when its footprints were all
   unsized — `st_area()` on an empty intersection returns `numeric(0)`, which
   collapses the tibble to zero rows. Also folded a multi-feature intersection
   into one row instead of several.
2. Inserting the internal helpers between the roxygen block and
   `fly_footprint()` bound the docs and `@export` to the helper, silently
   removing `export(fly_footprint)` from NAMESPACE. The suite stayed green
   because `load_all()` ignores NAMESPACE.
