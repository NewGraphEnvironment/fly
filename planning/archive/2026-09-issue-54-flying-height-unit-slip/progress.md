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
- Phase 2: failing tests first (35 failed + 1 error on main's code); two vacuous assertions caught on the red run
- Phase 3: implementation; 9 of 9 own mutations red (2 needed new fixture rows), suite 257 tests / 1,829 assertions green
- Verified end to end on real `bcc03006` / `bcc03010` frames over MRDEM
- Phase 4: roxygen, terrain note, vignette, DataBC draft (not sent)
- /code-check x3 over the whole branch: 2 code regressions + 16 doc claims fixed; ended by a 94-claim enumeration
- Follow-ups filed: #58 (partial DEM coverage), #59 (remote DEM sampling 583 s / 2 frames), #60 (lower-tail heights)
- Phase 5: `devtools::check()` 0 errors / 1 warning / 0 notes — the warning is non-ASCII
  characters in `R/fly_mask.R`, untouched by this branch and present on main. 0.12.0.
- `/code-check` ran over the whole branch once implementation and docs existed (three
  rounds), rather than once per commit; the Phase 1 and 2 commits were covered by that pass
