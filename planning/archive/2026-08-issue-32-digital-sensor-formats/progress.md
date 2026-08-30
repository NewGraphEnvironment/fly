# Progress — sensor widths for digital frames (#32)

## Session 2026-08-30

- Plan-mode exploration against the live catalogue; phases approved by user
- Established the provincial digital population (223,667 frames, 18 calibration files,
  14 serials) — the issue's "unknown at filing"
- Found that `SCALE` is not the true image scale for digital frames, and that sensors
  are not square; both confirmed with the user and folded into the plan
- Ran the numeric QA before writing any code: B 15/15, C 14/15, F 13/14, G 1.1% median.
  Two rows flagged and dispositioned
- Created branch `32-establish-sensor-widths-for-digital-fram` off main
- Scaffolded PWF baseline with approved phases
- Phase 1: generator + `camera_formats.csv` (14 calibration + 5 fallback rows)
- Phase 2: QA B/C/D/E/F all run. E (independent double entry) agreed exactly on all 14
  shipped rows, and additionally recovered three scanned reports plus the AIC Pro's
  53.9 mm width — which is why the focal-83 fallback is now refused
- Phase 3-4: non-square rotated footprints, resolver, `width_source`, `gsd_scaled`
- Phase 5: real digital testdata, check G, docs, NEWS, `CLAUDE.md` correction
- Plan review (10 findings) and code-check round 1 (12 findings) both folded in
- Suite 426 pass / 0 fail; lint +3 over baseline, all confirmed installed-vs-source
  artifacts for the new internal functions
- Code-check rounds 2 and 3 both found a defect inside the previous round's fix, and
  both had the SAME root cause: branching on `half_cross`, which is NA for every
  camera-table row by construction. Round 2 - the DEM route unreachable for those rows;
  round 3 - rotation never applied to them. Rotation is now decided from the format's
  aspect ratio, which is known before any sizing route runs
- Added a structural invariant sweep (`test-fly_footprint_invariants.R`) over 12 input
  shapes, since three separate conditions had drifted from the same fact
- Suite 1162 pass / 0 fail / 0 warn; lint baseline+3, all confirmed artifacts
- Filed #38 for georeferencing digital frames, deferred rather than guessed
- Next: PR
