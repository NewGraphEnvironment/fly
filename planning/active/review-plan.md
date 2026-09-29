# Plan review — #56 (Plan agent, 2026-09-28)

Delivered as reply text (Plan agents cannot write files); recorded here with disposition.

| id | finding | disposition |
|---|---|---|
| B1 | `opaque()` assumes alpha 255; UInt16 output alpha is 65535 | Confirmed independently before the review landed; `opaque(full =)` |
| B2 | does `-srcnodata` without `-dstnodata` leave `NoData=` on output? | Checked in Phase 3; asserted in tests |
| G1 | stale roxygen: `@param mask` "exactly", warp_opts bullets, code comment | Fixed in Phase 3 |
| G2 | `data-raw/mask_calibrate-border_threshold.R` replicates old warp; `georef_calibrate-corner_mapping.R` passes srcnodata | Phase 5: label/update |
| G3 | note §236-241 and §272-298 also stale | Phase 5 |
| G4 | declined mask is silent; row 4 of #69 table ("collar warped in as data") still unreported | Warn in `georef_one()` for row 4 |
| G5 | "declined" = `masked = FALSE` returned, not an error | Stated in roxygen |
| G6 | "accepted" test does not reach GDAL | Fallback exercised end to end through `georef_one()`; wording kept honest |
| A1 | alpha "partial coverage" contradicted by note's fringe measurement (2 alpha values) | Claim kept out of NEWS/roxygen |
| A2 | srcnodata fallback is a weak last resort (exact zeros only) | Stated in roxygen and note |
| A3 | invariant is "non-alpha bands + 1" for Byte gray/RGB | Stated that narrowly |
| A4 | #68 fix is reasoning until three-platform CI runs | CI is the acceptance |
| A5 | v0.19.0 hard-coded | Breaking, pre-1.0 → minor; 0.19.0 is what the release will be |
| O2 | NoData check before Phase 4 | Done in Phase 3 |
| S1 | downstream needs full grayscale republish, not only a fixture update | In the downstream issue |
| S2 | check mask flags, colorinterp, overviews of COG, not just check_same_raster | Phase 4 |
| AC1 | assert core is non-NA and exactly 0 (not 1: the Windows symptom) | Added |
| AC4 | locate block by coordinate not array index | Added |
