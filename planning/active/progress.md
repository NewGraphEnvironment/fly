# Progress — Frames under terrain where spacing rejects both nominal scale and the height read as above ground (#97)

## Session 2026-10-07

- Plan-mode exploration — phases approved by user (instruments: images + logbooks; no package change if centroids misplaced, follow-up issue instead)
- Created branch `97-frames-under-terrain-where-spacing-rejec` off main
- Scaffolded PWF baseline from issue #97 with approved phases
- Next: Phase 1 (pre-register the rule)
- Phase 1: decision rule written to findings.md before any thumbnail is matched or new page read.
  One change from the plan, recorded there: fly#82's `global_shift()` wraps shifts over ~575 px and
  gates candidates on centroid spacing, so seeds come from a padded masked NCC; matching and the
  acceptance gate stay fly#82's (`patch_shifts()` via `fns_from()`). Added a synthetic known-shift control.
