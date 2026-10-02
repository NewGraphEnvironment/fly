# Progress — Ship measured per-roll film rotations as a table (#53)

## Session 2026-10-02

- Plan-mode exploration — phases approved by user. Gate decisions: key is `film_roll` only; every
  film roll in the catalogue gets a recorded state (none silently dropped) and an exported
  calibrator gives any unshipped roll a measured route out; ~4 rolls per series x 5-year cell.
- Created branch `53-ship-measured-per-roll-film-rotations-a` off main
- Scaffolded PWF baseline from issue #53 with approved phases
- Next: Phase 1 (pre-register the rule)
- Phase 1 pre-registration committed (6e25af5); controls run; plan review returned three
  blockers (cardinal exclusion, 30-degree separation, #26 legs that do not exist) — seven dated
  amendments in findings.md, all before any campaign thumbnail
- Phase 2: `fly_rotation_calibrate()` with four code-check rounds (table in findings.md)
- Filed fly#87 (leg-end bearing) from plan review G1; fix in the working tree for Phase 4
- Campaign running: 116 rolls examined, 79 with thumbnails
