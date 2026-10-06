# Code-check round 1 — fly#91 staged diff

## Findings

- **[severity: fragile — published claim]** `inst/notes/terrain-correction.md:584` — condition 1
  of "#72's `near_upper` rule, unchanged" is misstated as "the logbook names factor 1 over at
  least half the frames". The rule the generator applies (`data-raw/height_calibrate-lower_tail_rolls.R`
  Stage 5, `v$covered >= 0.5 & v$agreeing >= 0.9`), the pre-registered rule in
  `planning/active/findings.md` ("covers at least half its frames, and at least 90% of the covered
  frames name factor 1"), and the note's own #72 statement at line 299-300 are all *coverage >= 50%
  and agreement >= 90% of covered*. The note's version is a different rule, not a paraphrase: 50%
  covered at 92% agreement (46% naming factor 1) passes the code and fails the note's wording; 60%
  covered at 85% agreement (51%) passes the note's wording and fails the code. The outcome on these
  three rows is unaffected (17/17, 14/14, 25/25), but the section presents itself as the rule that
  was run and calls it "unchanged". Fix: "the logbook covers at least half the frames, and at least
  90% of those name factor 1".

- **[severity: fragile — test comment]** `tests/testthat/test-fly_footprint_height_rolls.R:307-309`
  — the pin block's comment says each IR row is settled "with spacing fitting that height and
  rejecting nominal", but nothing in that block (or anywhere in this file) asserts
  `overlap_corrected` against the window or `p_nominal` outside it. The fact itself is held in
  `test-fly_footprint_infrared.R:121-127` (on the reported height, which equals `height_m` to 0.2 m),
  as `findings.md` "Guard checks" says, so this is a comment that claims more than its block
  checks rather than an unguarded fact. Either point the comment at the infrared test or drop the
  clause.

## Verified (no issue)

- Re-ran a copy of the staged generator in a scratch copy of the repo (centroid and logbook caches
  copied, not linked): exit 0 in 66 s; the log is **byte-identical** to
  `planning/active/run_rolls.log`, and `flying_height_rolls.csv` / `_excluded.csv` are
  byte-identical to the staged ones.
- Every number in the new note section, the camera-formats bullet and the CLAUDE.md bullet has a
  producer: `56 / 25 / 31` (log:348), `12 of 2500, 12 below` (log:349), window 0.557-0.780
  (log:9), p_nominal 0.805 / 0.807 / 0.228, p_corrected 0.594 / 0.620 / 0.620, r 0.473 / 0.506 /
  2.030 (log:796-800, 857-870), bci9 `n_scale_read` 0 (log:736). Ratios above sea level 0.731,
  0.762, 2.436 recomputed by hand.
- "Their keys reach exactly the 56 frames": counted directly against the 1.67M-frame centroid cache —
  bc5312 17 (frames 46-62), bci12 14 (1-14), bci9 25 (12-36); no BW/colour frame shares a key.
  `frames_measured` sum 1,558 -> 1,614.
- Amendment A1: old vs new `scale_pat` over every row of `flying_height_logbooks.csv` differ on
  exactly five rows, all `bci9` sheet 2 ("Scale 1/15,840", finals 101-128); no BW/colour row moves.
  bci9's disputed frames 12-36 are on sheet 1 rows with no scale, as the note says.
- Stratum assignment in Stage 3b matches the pre-registered populations, is disjoint
  (near_upper needs ratio_asl > 2, terrain needs it in band), and an unassigned or NA frame stops
  the script. `nu_row`, the sibling skip, the "nominal scale still applies" suffix, the frame-count
  reconciliation and the disjoint-key `stopifnot` all cover `terrain`.
- `fly_footprint()` gate (`R/fly_footprint.R:1237-1238`) needs no change: factor-1 rows apply on
  `out_of_band & r_reported > 0`, which the terrain frames satisfy over the caller's DEM; with a DEM
  that puts them in band they use the catalogued height, which equals `height_m` to 0.2 m.
- Tests: `test-fly_footprint_height_rolls.R`, `test-fly_footprint_infrared.R`,
  `test-fly_footprint_height.R` run with `NOT_CRAN=true` under `load_all`: 0 failures, 0 skips.
  The fixture test's stated r values (0.51, 0.55, 2.03) recompute.
- fly#93 exists and is the BW/colour terrain-only stratum. `planning/` is in `.Rbuildignore`;
  the run log carries no paths or credentials. NEWS.md 0.21.0's "until they are tabled (#91)" is a
  released entry, left for release bookkeeping.
