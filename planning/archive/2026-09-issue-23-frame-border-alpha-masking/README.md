# fly#23 — frame-border alpha masking

**Outcome:** the issue asked for Hough-transform detection of a "circular lens image area"
and its premise turned out to be false. Measured over all 264 thumbnails in
`stac_airphoto_bc/data/raw/thumbs` (1967-2018), the dark region is a rectangular collar
with chamfered corners, not a lens circle — and 27 frames have no collar at all.
Underneath it was a live defect the issue had not identified: `srcnodata = "0"` matches
*exact* zeros while scanned black runs 3-12, so it was removing a median 0.16% of a frame
where 3.11% of collar was present, and 128 of 264 frames had under a tenth of their collar
masked. That is the mosaic symptom fly#22 and fly#23 both describe. Shipped `fly_mask()`
(a flood fill seeded from the image border, via GDAL `nearblack -alg floodfill` through
`sf::gdal_utils()`, so no new dependency) and made it `fly_georef()`'s default. Output band
counts are unchanged, so nothing downstream in `stac_airphoto_bc` moves. Released as
0.11.0; issue body and title corrected rather than appended to; follow-up filed as fly#56.

## Measurement

| | |
| --- | --- |
| circle predicts dark fraction 0.2146 | measured median **0.027**, 2 of 264 near it |
| circle predicts bright edge midpoints | measured median darkness **0.216** — decisive |
| `srcnodata = "0"` vs threshold 16 | 0.0016 vs 0.0311 median mask fraction, **19.8x** |
| frames with under a tenth of the collar masked | **128 of 264** |
| edge-connected vs plain threshold, bcb90128_213 | 0.0252 vs 0.0767 — the 5% is a lake |
| GDAL floodfill vs `terra::patches(directions = 8)` | r **0.9877**, 0 of 264 off by >0.02 |
| `fly_mask_threshold()` | **16** — 99th percentile *and* max of the per-frame plateau |
| `fly_mask_max_interior()` | **0.05** — 3.81x above the worst legitimate frame at 16 |
| end to end, 18 grayscale frames 1967-2000 | 16 lose more collar, **0 lose less**, 2 unchanged and those are exactly the frames with none; **602,219** extra collar pixels removed |

Two readings of the threshold sweep were wrong before the right one, and both are recorded
in `inst/notes/border-masking.md` rather than tidied away. The first took the population
median of mask fractions and called 12-16 a knee with a plateau to 32 — the smallest
increment is actually at 24 -> 32, and a median of fractions cannot separate a
fully-removed collar from a small one in any case. The second published an admissible band
of (0.0131, 0.2379) for the guard; 0.2379 is the *maximum* interior fraction at threshold
48, not the smallest that trips the cap there, which is 0.0510. Correcting it exposed
something neither reading had: **the two constants are coupled** — the worst legitimate
interior fraction reaches 0.0465 by threshold 32, where the cap clears it by 1.08x — so
raising the threshold without re-measuring the cap breaks the guard.

Also measured, and each one changed the design: GDAL accepts `-srcnodata` alongside the
mask silently and then deletes exactly the interior black the mask exists to keep (121
pixels of an 11x11 synthetic block); `-srcalpha` excludes the alpha band from the warped
band list, which is what let masking default to on with no band-count change; the warp
does **not** pull masked black into neighbouring pixels, though that check was vacuous
twice before it measured anything — an axis-aligned warp has no boundary pixels, and on a
real thumbnail vignetting is inseparable from an artifact.

## Evidence

- `data-raw/mask_calibrate-border_threshold.R` — reproduces everything above from a
  directory of thumbnails
- `inst/extdata/mask_border_sweep.csv` — 264 frames x 10 thresholds, shipped so the test
  suite recomputes both constants and every figure the note publishes
- `inst/notes/border-masking.md` — the argument, the tried-and-rejected list, and the
  scope limits
- `review-round1.md`, `review-round3.md` — the review record. Round 2 found a defect
  *inside* round 1's fix, so the loop ran to an enumeration rather than to a quiet round;
  round 3 named the mechanism (every contract written twice, in prose and in code, with
  nothing binding the copies) and found the guard-band error above

## Refs

Commits `13c0351` (Phase 0) through `ef4810d` (Phase 5). Issue fly#23, follow-up fly#56.
