# Progress — A coastal frame is sized from sea level and reports full DEM coverage (#65)

## Session 2026-09-29

- Plan-mode exploration — phases approved by user
- Exploration surfaced an untested premise: over water the imaged surface *is* sea level, so
  the water-inclusive mean may be correct and the issue's land-only reference wrong. Phase 1
  now tests that first, with the rule fixed before any run
- Created branch `65-a-coastal-frame-is-sized-from-sea-level` off main
- Scaffolded PWF baseline from issue #65 with approved phases
- Next: start Phase 1
- Decision rule committed before any coastal frame measured (fd4b27a)
- Phase 1 probe: near-shore sea ~0.14 m, open water nodata; near-zero band misclassifies
  delta land, so the polygon is the witness
- Plan review 1 returned (review-1.md): runs were not contiguous (B3, confirmed), spacing
  measures shutter timing not coverage (B1), ray-cast recommended (W1). First run stopped in
  population selection before any frame was measured; Amendment 2 committed (382da95)
- LidarBC probe: sea mostly nodata, remainder −2.533 m → package computes ≈L on LidarBC
- Script rewritten: ray-cast with flat/step synthetic controls, W/L/S scored on area and
  land edge, runs drawn from whole rolls, smoke mode

## Session 2026-09-30

- Full run (240 runs, 2,334 frames, ~2h on a shared machine); determinism rerun byte-identical
- /code-check: 4 rounds. R1 mislabelled exclusion, uncounted frames, unimplemented control;
  R2 defects inside R1's fixes; R3 named the mechanism (copied story paragraph) and found the
  canopy reversal and the sea-band trend; R4 enumerated 136 claims, no wrong figure, found
  the relief confound. Filed fly#80 (canopy, package-wide)
- Note rewritten from producer lines; NEWS/CLAUDE.md/roxygen cut to asserted figures; test
  rebuilds all 6 note tables row by row (35-line pin, mutation-checked)
- Full suite 2,691 pass, 0 fail
