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

## Session 2026-09-08 — Phase 0

- Ran the calibration over all 264 thumbnails: 2,640 sweep rows shipped as
  `inst/extdata/mask_border_sweep.csv`
- **Go/no-go passed:** `nearblack -alg floodfill` vs `terra::patches(directions = 8)`,
  correlation 0.9877, 0 of 264 frames disagreeing by more than 0.02. The dependency-free
  route holds; terra stays in Suggests
- **Threshold measured:** per-frame plateau quantiles 50% 8, 90% 12, 99% **16**, max 16.
  `fly_mask_threshold()` = 16 is the 99th percentile and the maximum
- **Guard band computed:** largest legitimate interior fraction at t16 is 0.0131
  (bcb94081_070), smallest runaway 0.2379 at t48 (bcd18704_592, a frame with no collar).
  Band (0.0131, 0.2379), geometric middle 0.0559 -> `fly_mask_max_interior()` = 0.05
- **The under-masking defect quantified:** median mask fraction 0.0016 at threshold 0
  against 0.0311 at 16, a 19.8x gap; 128 of 264 frames had under a tenth of their collar
  masked
- The fringe check was **vacuous on first run** ("no partially-covered pixels") and again
  on a real thumbnail, where vignetting is inseparable from an artifact. Rebuilt on a
  synthetic uniform interior with a rotated ground quad: output alpha is binary and every
  kept boundary pixel reads exactly the fill value, so there is no fringe
- Next: Phase 1, the note

## Session 2026-09-08 — Phases 1-5

- Phase 1: `inst/notes/border-masking.md`
- Phase 2: `fly_mask()` + 40 tests. Three review rounds; round 2 found a defect INSIDE
  round 1's fix (the new Byte guard was `length(types) && ...`, which short-circuits to
  FALSE on an unparseable info string and masks anyway), so the loop ran to an enumeration
  rather than to a quiet round
- Round 3 named the mechanism: every contract was written twice, in prose and in code,
  with nothing binding the copies; each defect was just which copy had drifted. Every fix
  is a binding
- Round 3 also found a real error in the evidence record: the note published an admissible
  band of (0.0131, 0.2379) with 4.8x margin, but 0.2379 is the MAXIMUM interior fraction at
  threshold 48, not the smallest that trips the cap there (0.0510). Corrected, and the
  correction kept in the note rather than tidied away
- Discovered while correcting it: the two constants are **coupled**. The worst legitimate
  interior fraction reaches 0.0465 at threshold 32, where the cap clears it by 1.08x
- Phases 3-4: wired into `fly_georef()` with `mask = "border"` default; band counts
  verified unchanged; the false roxygen corrected
- 11 restore-the-bug proofs, each turning exactly its own test red. The harness was wrong
  first — it read testthat's `failed` and ignored `error`, so a restored defect that
  aborted the run read as green
- End-to-end on real data: 18 grayscale frames 1967-2000, 16 lose more collar, 0 lose
  less, 2 unchanged and those are exactly the frames with no collar; 602,219 extra collar
  pixels removed
- Phase 5: NEWS, version 0.11.0, issue #23 body and title corrected, follow-up #56 filed
- Suite: 1624 passing, 0 failures, 0 skips. lintr clean (the 3 extra `fly_georef.R` lints
  are the documented installed-vs-source artifact — every new internal is absent from the
  installed namespace, every pre-existing one present)

## Session 2026-09-08 — Phase 6 and close

- 11 restore-the-bug proofs re-run against the committed state; every one turns its own
  test red (7 by failure, 2 by error, 2 by both) and none stays green
- Archived; PR opened
