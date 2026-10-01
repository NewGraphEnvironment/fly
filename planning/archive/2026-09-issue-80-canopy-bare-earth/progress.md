# Progress — Footprints are sized from bare earth, but over forest the camera sees the canopy (#80)

## Session 2026-09-30

- Plan-mode exploration — phases approved by user ("Go all phases")
- Found MRDEM-30 publishes a DSM on the DTM's grid (`mrdem-30-dsm.tif`) and Meta/WRI's 1 m CHM is public on AWS
- Created branch `80-footprints-are-sized-from-bare-earth-but` off main
- Scaffolded PWF baseline from issue #80 with approved phases
- Next: start Phase 1

## Session 2026-09-30 (continued)

- Plan review 1 (Plan agent): 3 blockers folded into Amendment 1 before any frame was sized
- Stage 1 probes: MRDEM DSM = DTM over sea; source 88.3% radar; HRDEM lidar ground on 0 of 3,000
  radar points → LidarBC witness (Amendment 2), slope 0.916, clause 3 holds
- Probe defects fixed: NULL cached on empty probe; undeclared −3.4e38 nodata; 6.5 h strip-TIFF reads
- Code-check rounds 1–3 → Amendments 3–5 (epoch draw, heights, denominator, scale, known frames);
  ended by the round-3 mechanism enumeration
- Full run (`data-raw/.cache/logs/canopy_final.log`): **OUTCOME NOTHING** — weighted d median 0.17%,
  95th 0.46%, 1.2% of frames over 1%; first order holds (3.0e-4); DSM does not degrade the
  rectangle (2.89% vs 2.86%); epoch holds 1960s/1980s/1990s, fails 1970s (15.1%)
- Note section, tests (restore-the-bug: prose and CSV mutations each go red)
- Next: roxygen, NEWS, CLAUDE.md, issue body, follow-up issue, lint, full suite
