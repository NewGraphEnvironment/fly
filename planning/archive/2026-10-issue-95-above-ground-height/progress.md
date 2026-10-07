# Progress — BW/colour frames whose catalogued height may be above ground (#95)

## Session 2026-10-06

- Plan-mode exploration — phases approved by user; at the gate, chose "table + footprint route" if anything tables
- Created branch `95-bw-colour-frames-whose-catalogued-height` off main
- Scaffolded PWF baseline from issue #95 with approved phases
- Next: start Phase 1 (pre-registration)
- Phase 1: pre-registered rule written to findings.md before any per-roll-height number (spawned a Plan review in parallel)
- Phase 2: census re-run from the ETag-keyed cache (24 s, key 8212c794): 374 r <= 0 frames on 15 rolls shipped as
  `flying_height_terrain_nonpositive.csv`; the two existing CSVs byte-identical (md5 before/after). Log `run_census.log`
- Phase 3: measurement added to the generator (Stage 3c + Stage 6), not a separate script (reason in findings).
  188 roll-heights: supports 1, undecided 126, refutes 61; **nothing tables** (bc5602's logbook writes the
  catalogue's 4,000 ft under M.S.L.). Rolls tables byte-identical. Log `run_rolls.log`
- Phase 4 skipped (bc5602 already transcribed); Phase 5: no code change
- Phase 6: `test-fly_footprint_above_ground.R` (recomputes S from the census files, pins the note's three tables
  and prose figures; a flipped verdict goes red in a copy), note section, NEWS, CLAUDE.md. Filed fly#97 for the
  nine roll-heights where neither reading fits, before citing it
- Full suite: 5,476 pass, 0 fail (before round 1 fixes). Lint: helper `spacing_verdict()` replaces a nested `if`
  chain; generator re-run, all three outputs byte-identical (md5)
- Code-check round 1 (`review-round1.md`): code clean; three prose defects, all confirmed and fixed — the
  refutation median quoted without its "where nominal fits" scope (NEWS, CLAUDE.md; 0.032 over all 61), "550"
  that should be 558 (the 8 `ambiguous` carry the catalogue's figure), and the note's "wherever a page covers
  these frames" contradicted by its own table's 18 `other`. The corrected note sentence is now pinned
- Code-check round 2 (`review-round2.md`): code clean; one more prose instance, same mechanism, not inside a fix.
  "2,956 frames" was every census frame on the 188 keys, described as the two groups' frames (2,754); the other
  202 are `r > 0` frames on 8 keys neither group holds. Fixed in NOTE/NEWS/CLAUDE.md/findings, composition
  pinned (2,535 / 219 / 202 on 8 keys)
- Code-check round 3 (`review-round3.md`): named the mechanism — a count taken over one set, described as a
  neighbouring set — and found it inside round 1's fix ("no page puts the ground under it": only transcribed
  pages, 26 of 154 rolls, were read). Also: "32 roll-heights with transcribed rows" (32 is with a READ frame;
  36 have rows), "the logbook is read only where spacing supports" (fetched only there; joined everywhere),
  "about twice" (2.00-2.58, 51 of 374 within 2% of x2), and in code `n_unread` folding `conflict` with
  `uninterpreted` (now fly#93's precedence; moves no row — the generator re-ran byte-identical). All fixed and
  pinned, including the transcription scope (source-tree test). Since a defect was found inside a fix, the loop
  ends only on an enumeration: `claims_enumerated.txt` lists all 81 numeric or universal sentences in the
  shipped prose and comments, extracted mechanically
- Code-check round 4 (`review-round4.md`): the terminating enumeration — 96 claims, every number recomputes; five
  wording defects of the same mechanism, one inside round 3's fix; all fixed. Loop ended by enumeration.
  Full suite 5,490 pass at 58eb850
