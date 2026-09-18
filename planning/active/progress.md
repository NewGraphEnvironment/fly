# Progress — fly_footprint(dem =) returned a 110 km footprint for two 2003 film frames (#54)

## Session 2026-09-18

- Plan-mode exploration — cause found (`FLYING_HEIGHT` x10.764 in the catalogue), phases approved by user
- Gate decisions: repair-and-flag (`height_source`), both plausibility checks, partial `dem_coverage` to its own issue
- Created branch `54-fly-footprint-dem-returned-a-110-km-foot` off main
- Scaffolded PWF baseline from issue #54 with approved phases
- Next: Phase 0, then Phase 1
- Phase 0: partial `dem_coverage` split out to #58; #54 body and title reconciled
- Plan review (unnamed Plan agent) returned during Phase 1 — 2 blockers, 5 gaps, all adopted; see `review-1.md`
- Phase 1: pulled all 1,670,471 centroids (matches the catalogue's count), DEM-sampled 7,156
  deciding frames. Slipped = 1,589 frames / 13 rolls, repaired r 0.80-1.32. Band [1/1.6, 1.6],
  ceiling 16,000 m ASL (moved from `height_agl` to `flying_height` per review G1)
- Deviation from the approved plan, stated: the absolute check is on `flying_height` (ASL),
  not `height_agl`, so it is judged before any DEM window is built
- Inverse slip measured and deliberately NOT repaired (x10.76, x10 and x2 inseparable)
