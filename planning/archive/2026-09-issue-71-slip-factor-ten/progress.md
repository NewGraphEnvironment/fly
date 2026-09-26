# Progress — fly#54's ÷10.764 looks like ÷10 on the pre-2000 slipped rolls (#71)

## Session 2026-09-26

- Plan-mode exploration — phases approved by user; gate decision: add a `tail` column to both
  shipped roll tables
- Created branch `71-pre-2000-slip-factor` off main
- Scaffolded PWF baseline from issue #71 with approved phases
- Next: start Phase 1
- Phase 1: 5 logbook pages fetched and transcribed blind by a subagent (commit eef7572)
- Plan agent review arrived; 3 findings adopted (see findings.md)
- Phases 2–4: `tab_factor != 1` gate, mocked 0.1 test (red before the fix), script refactored into
  `settle()` over both tails, tables regenerated with `tail`, sweep test split by tail. Full suite:
  one failure (my assertion sign), fixed; roll tests 202 pass
- Cause name `height_decimal_dropped`, not the plan's `height_decimal_added`: it is the issue's
  own wording ("a dropped decimal point")
- Phase 5: fly#71 section in `inst/notes/terrain-correction.md`, a CLAUDE.md Key Decision, the
  vignette count updated to 28, follow-up fly#74 filed (bcb98013 typo, bc5596 sibling ×10)
- `/code-check`, three rounds (review-round1..3.md), no code bugs in any of them. Every finding was
  a false set-level claim in prose: "pre-2000" where bcc00085 is 2000, "every page /10" where
  bcb98013 is not, ASL ratios quoted as width, and an unenforced "never corrected_unit_slip".
  Round 1's fix produced a new instance, so rounds 2 and 3 enumerated every claim (27, then 39)
  against the CSVs; round 3 left one false headline, now fixed. Round 2 also turned up that
  `bcc05001` lands on round 500 ft under ÷10, so that roll is undecided rather than a ÷10.764 case
- Full suite: FAIL 0 | PASS 2348
