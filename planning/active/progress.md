# Progress - frame-border alpha masking (#23)

## Session 2026-09-07

- Plan-mode exploration: measured all 264 raw thumbnails in `stac_airphoto_bc`, which
  falsified the issue's circular premise and surfaced a live under-masking defect in
  `srcnodata = "0"`
- Prototyped edge-connected masking with `terra::patches`, then found GDAL `nearblack
  -alg floodfill` does the same thing through `sf::gdal_utils()` with no new dependency
- Verified band-count preservation end to end (gray 1->1, rgb 3->4) and that a VRT
  carries the GCPs into gdalwarp
- Three forks put to the user and answered: build the border mask; on by default;
  synthesized fixture plus a `data-raw/` corpus script
- Plan reviewed by a Plan subagent, which corrected the threshold-sweep reading, moved
  the guard predicate from total to interior fraction, and showed band counts need not
  change
- Created branch `23-frame-border-alpha-masking` off main
- Scaffolded PWF baseline with the approved phases
- Next: Phase 0, the calibration script and shipped sweep table
