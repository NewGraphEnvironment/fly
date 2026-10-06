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
