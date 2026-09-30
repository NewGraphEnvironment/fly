## Outcome

fly#65 was filed on the premise that MRDEM's ~0.14 m near-shore sea surface is an error that
drags a coastal frame's mean "toward sea level". Over water that surface is what the photo
images, so the premise was tested before any remedy was designed. A ray-cast of the true
footprint (vertical camera, MRDEM bare earth) scored the package's land-and-sea mean (W)
against the issue's land-only mean (L) and a per-side rectangle (S).

- **Area:** W is closer.
- **Land edge:** L is closer.
- The rule's pooled test found no remedy warranted, so `fly_footprint()` is unchanged.
- Matched for relief, the sea does worsen W's land edge (not its area).
- A canopy can reverse the area verdict: first-order, and filed as fly#80.

Two things were learned about method:

- **The planned instrument measured the wrong thing.** Adjacent-frame spacing measures when
  the shutter fired, not what the photo covered. It was replaced, and the rule re-fixed,
  before any frame was measured (plan review 1).
- **Most defects were in the prose, not the code.** Four code-check rounds found published
  causes, denominators and comparisons written from one copied "Reading" paragraph rather
  than read off a producer line, including inside the previous round's fixes. It ended with
  an enumeration of 136 claims (review-round4.md). The test now rebuilds every note table
  row by row.

## Measurement

- **Population:** 95,222 of 1,437,147 DEM-eligible film frames are coastal (6.63%).
- **Sample:** 2,334 frames measured; 2,124 admitted; 1,242 coastal frames with sea, and
  592 inland frames.
- **Material:** `d = side_W/side_L − 1` is 0.71% median and 3.18% at the 95th percentile.
- **Area:** median |linear error| is W 0.34%, L 0.67%, S 0.34%. Paired W−L −0.0029
  [−0.0036, −0.0023].
- **Land edge:** misplaced share of the land is W 4.43%, L 3.67%, S 3.71%. Paired W−L
  +0.0032 [+0.0024, +0.0043].
- **Premise (95th percentile, W, coastal vs inland):**
  - Pooled: area 2.16 vs 3.18%, land edge 15.05 vs 15.87%, so no remedy.
  - Relief-matched: land edge 15.05 vs 15.06%, and coastal is worse by 2–9 points in four
    of five relief bins. Area 2.16 vs 2.95%.
- **By sea fraction:** the land-edge 95th rises 13.7 → 20.8% while the median falls
  4.96 → 3.91%.
- **Canopy (first-order):** W−L goes −0.00287 / −0.00122 / +0.00014 / +0.00220 at
  0 / 15 / 30 / 60 m.
- **Instrument controls:** flat 1.2e-12. Step area 2.6e-4 at 32 rays, which is over the
  1e-4 fixed in advance (disclosed), and 6.4e-5 at 128. Control 3 median 0.021 m.
  Determinism: three runs re-measured byte-identical.
- **LidarBC** (two tiles, 20 m): 75% and 92% nodata over sea.

Changed because of it: the fly#58 "Ocean" bullet was retracted and a fly#65 section added to
`inst/notes/terrain-correction.md`, and fly#80 was filed. The finding lives in that note,
fly's existing home for terrain research; no `research/` directory was created.

Wrong turns kept:

- The first run was stopped in population selection when review found its runs were not
  contiguous.
- The step control's first threshold failed on discretisation and became a convergence test.
- "Land border" and then "shoreline misregistration" were each asserted as the cause of an
  exclusion and each retracted.
- "Canopy does not discriminate" was wrong.
- "The sea does not make W worse" was a pooled reading that relief confounds.

## Evidence

- `data-raw/.cache/logs/dem_coastal_run*.log` (gitignored, local to the measuring machine;
  run2 is the full measurement, run6 the final analysis). Every figure is reproduced by
  `data-raw/dem_measure-coastal_water.R` from the committed CSVs
  `inst/extdata/dem_coastal_*.csv`.
- Reviews: `review-1.md` (plan) and `review-round1.md` … `review-round4.md` (code-check).

Closed by: PR (this branch, `65-a-coastal-frame-is-sized-from-sea-level`)
