# Progress — DEM-based terrain-adjusted footprints (#9)

## Session 2026-08-29

- Plan-mode exploration: measured `flying_height` units, quantified the terrain effect,
  compared MRDEM-30 against elevatr head to head
- User steered DEM source from elevatr to the federal product used by `flooded`; verified
  MRDEM-30 works over the fly AOI and changes the answer by < 0.5 pct points
- Phases approved by user
- Created branch `9-dem-based-terrain-adjusted-footprints` off main
- Next: Phase 1 — MRDEM-30 test fixture

### Phase 1 — test DEM fixture (done)

- `data-raw/make_testdata.R` gains an MRDEM-30 `/vsicurl/` clip over centroids + 4 km
- `inst/testdata/dem.tif`: 973x1086 at 30.5 m, 566-1520 m, 306 KB — matches the probe exactly
- Buffer rationale recorded in the script: the widest footprint is 7.2 km, so an edge frame
  reaches 3.6 km past the centroid bbox
