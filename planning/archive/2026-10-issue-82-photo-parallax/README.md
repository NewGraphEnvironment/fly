## Outcome

fly#82 asked the photos the one question fly#80 left to VRI: was the canopy MRDEM's DSM carries
there at the photo date? The instrument reads it from the parallax between frames adjacent by
number. Each patch's parallax against the pair's median gives its height with no air base, and
that height is regressed on MRDEM's DTM and on `DSM − DTM`. The estimand is a ratio: the canopy
slope on mid-aged stands over the slope on stands VRI dates as 80 or more years old at the photo,
after a bare-earth reference.

**It stopped at its first verdict.** The plain synthetic controls passed. The class-structured
synthetic, built in a world where fly#80's VRI model is exactly true and pooled as the sample
would be, missed in both MRDEM sources. So under the decision rule no canopy slope, φ or D was
computed on any pair of the real draw. Why the ratio fails is not established; the two candidate
causes are filed as fly#85.

No code changed. What shipped:
- `data-raw/dem_measure-photo_parallax.R`, which reproduces the stop;
- `inst/extdata/dem_parallax_synthetic.csv` and `_versions.csv`;
- `tests/testthat/test-fly_footprint_parallax.R`;
- a section in `inst/notes/terrain-correction.md`.

What was learned on the way, kept because it is easy to re-derive wrongly:
- **The catalogue's film centroids are not an air base.** They are evenly spaced along lines
  before the 1990s, and one pair's spacing was ×1.7 what the images showed.
- **Registration on a DTM-only fit chases canopy.** It halved the synthetic canopy slope, and a
  free rotation overfit.
- **A per-frame test of a ratio is ill-posed.**
- **A plain single-slope pass says nothing sufficient about the ratio.**

The rule was amended three times (A–C), each before any canopy slope was computed on a pair of
the real draw. The wrong turns are kept in `findings.md`:
- a pilot that computed canopy coefficients before the rule existed, disclosed as a leak, with
  its roll excluded;
- the a1 and a4 synthetic failures;
- a disc-in-polygon class rule that classed nothing;
- a young-at-photo control that held 2 patches in 11 pairs.

## Measurement

| quantity | value | what it changed |
|---|---|---|
| plain synthetics (3 frames × 4 cases, undisplaced) | κ=0 −0.029 to +0.070; κ=1 0.975 to 1.123; all pass | instrument matches and places correctly on uniform canopy |
| plain κ=1, 150 m displaced | 1.111, 0.403, 1.022 | registration can land wrong and pass every gate |
| pooled class synthetic, radar | φ 1.356 against 0.860 (46.35 displaced) | **STOP at verdict 1** |
| pooled class synthetic, lidar | φ 0.793 against 0.550 (0.810 against 0.553 displaced) | **STOP at verdict 1** |
| pilot DTM slope, bc5282 (scratch, seven pairs, unregistered) | 0.95–1.13 | parallax tracks terrain on thumbnails |
| y-parallax robust SD, Phase 0 pilots | 0.16–1.01 px (first quoted ×1.4826 too high, corrected) | sets the noise floor |
| young-at-photo patches under the clean class rule | 2 in 11 pilot pairs | young control dropped (Amendment B) |
| class intercepts (pilots, DEFF 4) | SE ×4–8 | sensitivity only, never primary |
| centroid bases equal within 0.5% (plan-review probe) | 1965 67%, 1975 77%, 1985 64%, 1995 10% | air base never taken from the catalogue |

## Evidence

- **Logs:** `data-raw/.cache/logs/parallax_*.log` (gitignored, local to the measuring machine).
  - `parallax_stage1_a6.log` and `parallax_final.log` are the stop.
  - `parallax_phase0*.log` is Phase 0.
- **Probes:** `scratch/` (copied from the session scratchpad; paths inside point there): the
  pilot, Phase 0, Amendment B checks, the synthetic harness and the registration probes.
- **Reviews:**
  - `review-1.md` (plan) and `review-2.md` (rule);
  - `review-round1.md` … `review-round5.md`, the code-check, ended by an 82-row enumeration;
  - `review-record1.md` … `review-record3.md`, the prose, ended by a 137-claim enumeration.
- **Write-up:** `inst/notes/terrain-correction.md`, "What the photos can say about the photo
  date: not enough, with this instrument (fly#82)".
- **Follow-up:** fly#85.

Closed by: PR (this branch, `82-photo-parallax-as-a-witness-of-the-surfa`)
