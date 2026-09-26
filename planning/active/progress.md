# Progress — ~2,000 film frames carry a FLYING_HEIGHT far too small, and three remedies fit equally (#60)

## Session 2026-09-26

- /planning-init 54 aborted: #54 closed 2026-09-20, shipped in v0.12.0
- Plan-mode exploration — found the lower tail is 42 rolls with one round-feet height each; phases approved by user
- Plan gate decision: per-roll table keyed on film_roll + flying_height, with an excluded list
- Created branch `60-lower-tail-flying-height` off main
- Scaffolded PWF baseline from issue #60 with approved phases
- Next: start Phase 1
- Phase 1: spacing + round-feet + logbook instruments with controls; three parallel readers transcribed 120 logbook pages
- Phase 2: verdict — 22 roll-heights corrected (1,001 frames), 55 excluded with reasons; tables written
- Found: the note's r~2 claim is half wrong; #54's /10.764 looks like /10 on pre-2000 rolls — both to follow-up issues
- Phase 3: fly_footprint() consults flying_height_rolls.csv; height_source "corrected_roll_table"; 9 tests, 7 restored defects each go red
- /code-check: 3 rounds, 8 findings fixed; ended by enumerating all 77 labels against an independent predicate (77/77)
- Filed follow-ups #71 (#54's /10.764 looks like /10 on pre-2000 rolls) and #72 (half the r~2 mass is a wrong scale)
- Suite: 2,279 passed, 0 failed
