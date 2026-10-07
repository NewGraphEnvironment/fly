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
- Plan review returned (review-plan.md) -> Amendment A2, committed before the control output was read.
- Phase 3: 35 pages fetched; three blind transcribers; controls agree (bc77087_1 height contested: 3.8 vs 7.8);
  37 rows appended for five rolls; strips CSV (139); generator byte-identical before and after on the roll
  tables; fly#95's pinned logbook figures updated (test, note, CLAUDE.md).
- Phase 4: nine keys measured (366 pairs); five keys step_overstated -> nominal_unrefuted / misplaced (112 r<=0 frames); bc7718, bc80117 flown at ~85% overlap, indistinguishable; byte-identical re-run.
- Phase 6: tests (163 pass, mutations red), note section, NEWS, CLAUDE.md. Prose test caught 6 errors in first draft (k 2.1->1.9, headings 264/268->233/237 on the five, step 848->848-850, double rounding, two test defects). Follow-up issue: gh create failing GitHub-side (3 attempts).
