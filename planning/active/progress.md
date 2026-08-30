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
- Next: Phase 1 — camera format table
