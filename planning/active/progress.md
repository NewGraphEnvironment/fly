# Progress — Half the r≈2 mass is a wrong scale (#72)

## Session 2026-09-27

- Plan-mode exploration — phases approved by user (tail = `near_upper`; scope = sampled roll-heights)
- Created branch `72-near-upper-scale-wrong` off main
- Scaffolded PWF baseline from issue #72 with approved phases
- Next: start Phase 1
- Plan review (Plan agent) → `review-plan.md`; A1 (spacing must reject nominal), A2 (scale veto), A3 folded into the rule before the run
- Phase 1: fetched 144 pages for 53 rolls; three blind readers transcribed 185 rows; merged 183 into `data-raw/flying_height_logbooks.csv`
- Phase 2: generator settles `near_upper`; 24 roll-heights / 120 frames tabled `scale_wrong`, 34 / 132 excluded; tables regenerated, lower/upper rows unchanged
- Phase 3: tests widened to three tails; near_upper frame sized from its height (bc5509), lens roll (bc78051) stays nominal, restore-the-bug via mocked table; r_corrected held to one unit in the third decimal (published height_m rounding)
- Phase 4: fly_footprint comments/roxygen, terrain-correction.md new fly#72 section, NEWS, CLAUDE.md Key Decisions
- /code-check: 3 rounds (review-round1..3.md). R1: reach claim backwards (terrain lowers r), scale parser read remark scales, test comment. R2: parser fix still swallowed trailing digits (inside a fix), bc80048 wording, bc7223 "no page" vs unread (interior rows added). R3: mechanism = claims written from a picture of the data, not recomputed; enumerated 43 claims, 2 false (NEWS row counts stale after R2 fix; Bound paragraph missed the 1,534-frame bc850xx family at r_asl 1.999). Fixed and verified directly; loop ended by enumeration
- Full suite before the round fixes: FAIL 0 | SKIP 0 | PASS 2537; roll tests after: 391 PASS
