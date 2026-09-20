# Progress — fly_dem_sample() over a /vsicurl/ DEM (#59)

## Session 2026-09-20

- Plan-mode exploration: mapped the whole DEM code path, read
  `inst/notes/terrain-correction.md` (required reading before touching anything under `dem`)
- Measured the three extract forms on a quiet link, fresh process each — the cause is isolated
  to `terra::extract()` with no `fun`, 64.59 s against 0.69 s for the same frame through a crop,
  with identical cell count and mean
- Measured per-frame crop against one shared crop over 8 contiguous frames — 1.23 s vs 1.00 s,
  identical results, so per-frame is affordable and bounded by construction. Design decided
- Phases approved by user
- Created branch `59-fly-dem-sample-over-a-vsicurl-dem-took` off main
- Next: Phase 1 — request counts, the align-under-crop check, and the zero-cell frame question
