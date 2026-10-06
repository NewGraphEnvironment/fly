# Progress — BW/colour frames out of the height band only through terrain (#93)

## Session 2026-10-06

- Plan-mode exploration — phases approved by user (spacing-first logbook read; new census script + shipped CSV)
- Coarse census in plan mode (read-only, fly#80's cached 250 m MRDEM DTM): ~4,750 frames, 293 roll-heights, 214 rolls; spacing at catalogued height passes on ~74 roll-heights
- Created branch `93-bw-colour-frames-out-of-the-height-band` off main
- Scaffolded PWF baseline from issue #93 with approved phases
- Next: Phase 1 pre-registration
- Phase 1: rule pre-registered in findings.md before the exact census and any transcription. A2 was tightened
  from "condition 3 at p_reported" to a provably exclusion-only test: the nominal half, plus the frame range at
  0.98-1.02 of the height, because p_corrected is a median over the agreeing subset at a height within 2%.
  The prefilter also covers the above-band side and coarse-nodata frames.
- Phase 2: census script written; two smoke runs (the first stopped on r <= 0 frames → A3). Full census from a
  frozen copy (`run_census.log`): 18,747 read exactly over 2 margin passes (M 223.6 → 285.4 m);
  4,773 frames, 298 roll-heights, 216 rolls; r <= 0 374 frames on 15 rolls; Controls 1-3 pass;
  A2 preview 176 nominal / 35 cannot / 87 to the logbook (1,746 frames). The source differs from the
  frozen copy only by lint reflow.
- Full suite on 6f73de0: [ FAIL 0 | WARN 0 | SKIP 0 | PASS 5403 ]
- Code-check round 1: 4 findings, all fixed (9305262); generator re-run, three exclusions reclassified.
- Re-ran the committed census script from cache: both shipped CSVs byte-identical; preview 176 / 32 / 90
  BW/colour to the logbook, matching the generator's 92 with the two IR rows.
