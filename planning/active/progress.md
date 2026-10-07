# Progress — BW/colour frames whose catalogued height may be above ground (#95)

## Session 2026-10-06

- Plan-mode exploration — phases approved by user; at the gate, chose "table + footprint route" if anything tables
- Created branch `95-bw-colour-frames-whose-catalogued-height` off main
- Scaffolded PWF baseline from issue #95 with approved phases
- Next: start Phase 1 (pre-registration)
- Phase 1: pre-registered rule written to findings.md before any per-roll-height number (spawned a Plan review in parallel)
- Phase 2: census re-run from the ETag-keyed cache (24 s, key 8212c794): 374 r <= 0 frames on 15 rolls shipped as
  `flying_height_terrain_nonpositive.csv`; the two existing CSVs byte-identical (md5 before/after). Log `run_census.log`
