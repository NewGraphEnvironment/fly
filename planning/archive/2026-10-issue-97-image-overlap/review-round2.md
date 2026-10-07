# Code-check round 2 — fly#97 branch (`main...HEAD` at 5c6c196, planning/ excluded)

Reviewer: subagent, 2026-10-07. Working tree not modified. Probes ran read-only against the shipped CSVs,
and the two test files ran green in a `git archive` copy in the scratchpad (`NOT_CRAN=true`: 166 + 74
pass). Four findings. Each one sits inside a round-1 fix. Each fix moved a claim onto a new basis (a
denominator, the logbook, a bound) and stated it over the old set, which the new basis does not fully cover.

## Findings

- **[severity: bug — published figure, the round-1 fix 4 denominator]** `inst/notes/terrain-correction.md:970-971`,
  pinned at `tests/testthat/test-fly_footprint_image_overlap.R:230-233` — **"233 of the 237 matched pairs
  that a transcribed strip reaches (285 matched)": a transcribed strip reaches 280 of the 285, not 237.**
  The 237 are the pairs whose strip has a *legible* heading. `kp_m$dir` is NA when `direction_deg` is NA,
  and that is a different set. On `bc77026` all 114 matched pairs sit inside exactly one strip. 43 of
  them (frames 175-218) are in strip 1 of page 3, where the strips file records `direction_as_written`
  "270 written over 090, both struck through" and `direction_deg` NA. The only pairs no strip reaches
  are 5 on `bc77072` 1829 (frames 224-229; the page ends at 223). Per key, reached / with a heading:
  77026 114/71, 77070 53/53, 77072-1829 11/11, 77072-1981 53/53, 77087 49/49. So the fix relabelled the
  denominator with the neighbouring set again. Correct wording: "233 of the 237 whose page gives a legible
  heading (280 reached by a transcribed strip, 285 matched)". The test pins the wording, because it
  computes 237 as `dir` non-NA and never checks the label.

- **[severity: fragile — count described as a neighbouring set, the round-1 fix 1 basis]**
  `inst/notes/terrain-correction.md:887-888` and `:959-962`, NEWS.md:5, CLAUDE.md:442-443 — **the
  location claim now rests "on the logbook's figure against MRDEM" for "the 112 frames", but no page
  covers 5 of the 112.** By the shipped `data-raw/flying_height_logbooks.csv`, the `r <= 0` frames with a
  row are: `bc77070` 59/59 (3,800), `bc77087` 38/38 (3,800), `bc77072` 1981 3/3 (6,500), `bc77026` 7/11
  (6,700, rows 140-219), and `bc77072` 1829 0/1. Frame 225 has no page at all; `_4.jpg` ends at 223.
  `bc77026` 221, 222, 237 and 247 lie past the shipped row's 219. The blind control re-read does run to 258, but
  A2 says it is never appended. So "by the logbook" covers 107 frames. The other 5 are `misplaced` only
  because the rule's verdict is per key (>= half read, 90% agreeing). Before round 1 the images were the
  stated basis, and they were per key too, so the gap did not show. Moving the basis to the page exposes
  it. Say 107 of the 112, or say the verdict is the key's.

- **[severity: bug — claim stated more strongly than its evidence, the round-1 fix 2 bound]**
  `inst/notes/terrain-correction.md:886-887`, `:953-955`, `:990-993`, NEWS.md:5, CLAUDE.md:441-442 —
  **"even at the largest side the logbook's M.S.L. height allows, the step is x1.25-x2.70 the air base"
  holds for `bc77087` only on the contested 3.8 read, and the note then says "The step verdict holds either
  way."** `bc77087`'s bound (x1.39) uses H = 1,158 m (3,800 ft). The note itself records the blind reader
  leaning 7.8. At 7,800 ft (2,377 m), the largest side that height allows (ground at sea level) gives
  step / air base = x0.68, so it is no bound at all. With MRDEM ground under the catalogue's centroids
  instead, it is x1.15 / x1.44 / x1.59 at that key's 10th / 50th / 90th percentile elevation (980 / 1,264
  / 1,367 m). The low end is under exp(tau) = x1.246. W1 `step_overstated` is computed at the catalogue's
  height, so as a label it does "hold either way". But the round-1 fix made the bound "under any height the
  logbook's figure allows" the stated reason the step is wrong, and that reason does not survive 7.8 for
  this key. The size verdict also turns on the read: at 7.8 that page's 57 frames read a different height,
  so W2 becomes `read_other` and size becomes `unsettled` rather than `nominal_unrefuted`. The note says only
  the *location* rests on the contested read. The x1.25-x2.70 endpoints are unaffected (`bc77087` is
  interior), but the clause "under any height the logbook's figure allows" is conditional for 38 of the 112
  frames. NEWS.md:5 does not mention the contested read at all.

- **[severity: bug — claim stated more strongly than its evidence, the round-1 fix 2 wording kept]**
  `inst/notes/terrain-correction.md:885-886` ("the spacing rejected nominal **only because** the
  catalogue's step is longer than the air base, by at least x1.25 to x2.70"), with the same direction in
  CLAUDE.md:438-439 ("the photos say the catalogue's step is wrong, **not the scale**") and
  `inst/notes/terrain-correction.md:860-861` ("it was the catalogue's centroid step that was wrong, not
  the scale") — **once the factor is a lower bound, "only because" and "not the scale" no longer
  follow.** Remove only the minimum step error, `exp(-D_agl)`, and the overlap at nominal becomes
  `1 - (1 - p_nominal)(1 - p_img)/(1 - p_agl)`. That is 0.428 on `bc77070`, 0.430 on `bc77087` and 0.502
  on `bc77072` 1981: still outside the 0.557-0.780 window, so spacing would still reject nominal (100 of
  the 112 frames). Only at the nominal factor (x1.9-x3.0) does the rejection disappear, and that is the
  circular, nominal-conditioned figure round 1 removed. What the measurement shows is the note's own
  body sentence: the rejection rests on a step wrong by an unknown factor of at least x1.25, so it "said
  nothing about the scale". It does not show that the step alone caused the rejection, or that the scale
  is right. The pre-fix text ("about two to three times") was coherent with "only because" under
  nominal; the fix weakened the factor and kept the causal wording. The size verdict itself
  (`nominal_unrefuted`) is worded correctly everywhere.

Checked and found consistent: `read_other` (fix 3) changes no size or location outcome, because both
`case_when`s test only `msl_catalogue` and `ground`. It is recorded in findings.md item 3 and mirrored in the
test. The fix-4 counts "31 of the 190 compared" and "0 of 36 compared (38 drawn, 2 with no thumbnail)" match
the pairs CSV, and no `fixed_pattern` row exists in any set. `exp(-D_agl)` = 1.254 / 2.700 gives
"x1.25 to x2.70". `bc77070` margin -(-0.22597) - 0.2199 = 0.006. The direction of the bound (true side <= the
side at H when H is above sea level) is right. The fly#95 logbook figures (38 / 689 / 669 / 31) are pinned
by the above-ground test and pass.
