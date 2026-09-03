# fly#26 — bearing rotation for diagonal flight lines, film half

Closed by PR for v0.9.0. #32 had built continuous footprint rotation and gated it on the
recording format being non-square, so it reached digital only and film stayed
axis-aligned. This branch removed the gate.

The framing in the issue was that this is a georeferencing bug. It is also, and more
importantly, a **coverage** bug: a film camera is mounted square-on to the flight line,
so the true footprint is a square rotated onto the bearing, and at 45 degrees an
axis-aligned square overlaps it by only 83%. `fly_coverage()` had been reporting that
missing sixth as covered ground.

Three things were measured rather than reasoned, and two of them changed the plan.

## Measurement

**The film corner mapping does not exist as a constant.** Adjacent-frame overlap
correlation, the route that decided #38, over four contiguous legs pulled from the public
catalogue:

| roll | year | bearing | best rotation | margin | top-edge azimuth |
|---|---|---|---|---|---|
| bc5282 | 1968 | 230° | 0 | 0.089 | 230 |
| bc83062 | 1983 | 150° | 90 | 0.135 | 240 |
| bc83062 | 1983 | 93° | 90 | 0.196 | 183 |
| bc83062 | 1983 | 62° | 90 | 0.152 | 152 |

Digital through the same harness returns 270 at +0.713 against 90 at +0.425, reproducing
#38 — the positive control, run first.

bc83062 giving one answer at three widely separated bearings is what establishes the
mapping is **flight-relative**, which is the strongest evidence in the issue for the whole
architecture and arrived as a by-product of failing to find a constant. But a quarter turn
separates it from bc5282, so `fly_georef()` refuses rotated film unless the caller supplies
the roll's rotation. A fixed-geographic rival hypothesis fitted the first two rows to
within 10 degrees, predicted 180 for the other two legs, and was falsified at both.

**`fly_bearing()` was making geometry batch-dependent.** It took the azimuth to the next
frame present in the object handed to it: `centroids[1:2, ]` returned 51.5 where the full
batch returned 318.2 and 231.6. Adjacency by frame number is now required. Seven of the
twenty bundled frames keep a bearing.

**A latent ring-closure defect, present on `main` since #32.** Rotation recomputed the
closing vertex rather than copying it, and BLAS returns it a few ulps off the first
(2.8e-14 at bearing 230), which `sf::st_polygon()` rejects with an error that aborts the
batch. Data-dependent, so 1338 passing tests never saw it. Found by restoring the old
`fly_rectangles()` to check the new tests could fail — the check paid for itself.

Downstream movement on the bundled AOI: coverage 60.7% -> 59.5% at 1:12000, overlap pairs
61 -> 63, DEM path unmoved (median area ratio 1.1377 -> 1.1372). Small, downward, and an
understatement, since only 7 of 20 frames rotate under the adjacency guard.

## Wrong turns worth keeping

- The plan put the measurement in Phase 1, before the mechanism. It cannot go there — the
  measurement needs bearing-rotated footprints, which is Phase 2. Reordered rather than
  hand-replicating the rotation in the script, since a reconstruction is a different
  program.
- The first film run scored 0 by a margin of 0.096 and was nearly written up as the
  constant. A detrended variant then scored 180 by 0.010. Detrending was the wrong
  instrument — it collapses the digital control too, because `fly`'s footprints are
  estimates so fine detail does not align — but the disagreement is what forced the second
  era, which is what found the real answer.
- The plan review's B1 (finite `footprint_bearing` on an empty footprint) did not
  reproduce on the bundled fixture. Fixed regardless: the mechanism is real in the code and
  the predicate was correct only because `fly_georef()` skips empty footprints first.
- A `stretch > 1.001` threshold for "diagonal" was wrong — a 180.4-degree heading is 0.4
  off cardinal and genuinely stretches by 1.0074. Replaced with the exact identity
  `|cos b| + |sin b|`, which needs no band.

## Evidence

`data-raw/georef_calibrate-corner_mapping.R` section 4 reproduces every number, from
public data only. `inst/notes/georeferencing.md` records what each check can and cannot
separate. `planning/archive/2026-09-issue-26-bearing-rotation-diagonal-film/review-26.md`
holds the plan review whose B3 finding changed the shape of the work.

## Still open

The per-roll film rotations are not shipped as a table. Two rolls is thin, and a two-row
table invites the reading that unlisted rolls are missing rather than unmeasured.
