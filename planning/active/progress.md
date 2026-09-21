# Progress — Measure what a partially DEM-covered footprint costs (#58)

## Session 2026-09-20

- Plan-mode exploration: read `inst/notes/terrain-correction.md`, the DEM block of
  `R/fly_footprint.R`, the fly#54 calibration script and the two sweep-backed tests
- Five read-only probes (see `findings.md`): bearing on a single-point call, the cached
  catalogue pull and what it lacks, MRDEM's NA region relative to BC, near-shore ocean
  values, and a 2-frame feasibility run of the truncation harness
- Plan agent design review, 16 findings; two of its factual claims verified and one of its
  proposed remedies falsified (exact-zero ocean test)
- Phases approved by user, with: ship the remedy the pre-registered rule selects in this
  PR, and include the population arm
- Created branch `58-measure-what-a-partially-dem-covered-f` off main
- Scaffolded PWF baseline from issue #58 with approved phases
- Next: Phase 1, the population

### Phase 1 complete — the population

- `data-raw/dem_calibrate-coverage_error.R` stages 1-2, committed as `870a286`
- Against MRDEM-30, **66 of 1,437,147** DEM-eligible film frames sit under 0.95 coverage
  (0.0046%), and **0 of 2,975** randomly drawn frames — the control confirming the
  candidate finder missed nobody. Every DEM-sized digital frame measured is at 1.0000
- The issue's own "18 of 416" does not reproduce against MRDEM-30; the likely explanation
  is a DEM cropped to the fly#50 run's AOI, which is inference rather than measurement and
  is recorded as such
- Five defects found and fixed along the way, all in `findings.md`: a distance transform
  measured the wrong direction, two GDAL driver-guess failures in the atomic-write idiom,
  a PSOCK worker environment missing every helper, and three memory kills
- Next: Phase 3, the truncation sweep (Stage 4 running, resumes from cache after a kill)

### Phases 2-6 complete — the sweep, the decision, and four review rounds

- Sweep: 11,520 truncations of 120 frames, committed as `939f93c`. Five harness defects
  along the way (`adb37b3`): a PSOCK worker environment missing every helper, a resume
  filter that skipped nothing while the row count grew, GDAL's 3,276 MB-per-process block
  cache, the master holding the 1.67M-row catalogue, and orphaned workers causing the next
  kill
- Decision by the pre-registered rule: **no floor** (the DEM route beats nominal in the
  median at every coverage), **0.95 kept** with a measured justification replacing the
  inherited one, and **`dem_elev_sd` shipped** because coverage cannot separate the frames
  inside a band
- `/code-check`: four rounds, ~1.5M subagent tokens. Rounds 2, 3 and 4 each found a defect
  inside the previous round's fix. Findings in `review-round[1-4].md`. Terminated by
  enumeration, not by a quiet round: the suite now parses all eight of the note's tables
  and recomputes every cell, with the table count asserted
- Two of the numbers the reviews caught were wrong in the direction that flattered the
  design that shipped, and one was a feasibility-probe figure quoted as a measurement —
  the exact failure this issue's own findings file warned against
- Next: NEWS, version bump, archive, PR
