# Code-check round 1 — fly#97 branch (`main...HEAD`, planning/ excluded)

Reviewer: subagent, 2026-10-07. Working tree not modified; probes ran read-only against the repo's
caches from the scratchpad.

## Findings

- **[severity: bug — published verdict basis]** `data-raw/height_measure-image_overlap.R:717-722` (the
  `location` rule) and `inst/notes/terrain-correction.md:953-955`, `:886-887` — **the image leg of every
  `misplaced` verdict is vacuous, so the note publishes "the images reject reading the height as above
  ground" as evidence it is not.**
  All five `misplaced` keys are W1 `step_overstated`. Amendment A2(3) says, correctly, what
  `step_overstated` shows: both readings are rejected *at the catalogue's step*, which means the step
  overstates the air base and "does not select nominal". The same argument applies to the AGL reading:
  `D_agl` is computed with the step the verdict has just declared wrong, so `D_agl < -tau` does not reject
  reading the column as above ground — under that reading the images are equally consistent with a
  shorter true air base (step/air base = exp(-D_agl) = 1.25-2.70 on the five). A2(4) nonetheless puts
  `step_overstated` in the `misplaced` set with the gloss "the images reject reading the column as above
  ground, by more than tau". On these keys `misplaced` therefore reduces to W2 `msl_catalogue` plus
  `r <= 0` — exactly the disjunction fly#95 already published ("either the column is not above sea level
  as written, or the frames are not where the catalogue puts them", note ~l.829), resolved by trusting the
  page. The photos add nothing to it. The rule was implemented as written, but the note's prose
  (l.953-955, "On those five, the images reject reading the height as above ground, and the page says it
  is above sea level") states an image result that the rule's own A2(3) contradicts, and the intro
  (l.886-887) makes it unqualified: "On those five, the centroids are not over the ground photographed".
  The evidence covers only the 112 `r <= 0` frames, not the five keys' 311 frames. NEWS.md:5 and
  CLAUDE.md:441-442 phrase it as resting on the logbooks, which is the honest version. The note should
  say the same: the location verdict is the logbook's M.S.L. header against MRDEM, and the images are
  neutral on it once the step is shown to be wrong. That matters most for `bc77087` (38 of the 112
  frames), whose page height is already contested (3.8 or 7.8).

- **[severity: bug — published figure stated unconditionally]** NEWS.md:5, CLAUDE.md:441,
  `inst/notes/terrain-correction.md:886` and `:946`, pinned by `test-fly_footprint_image_overlap.R`
  (`"%.1f to %.1f times the air base"` from `k`) — **"the step is 1.9 to 3.0 times the air base" holds only
  at nominal scale, and the text then uses it to conclude that nominal stands.**
  `k = (1 - p_nominal) / (1 - p_img)` is the step over the air base the images imply *if the side is
  nominal*. The size verdict is `nominal_unrefuted`: nominal is neither confirmed nor refuted. So the
  published ratio presupposes the reading the sentence goes on to infer: NEWS has "The step is 1.9 to 3.0
  times the air base, so spacing's rejection of nominal said nothing about scale, and nominal stands". The
  bound the measurement actually supports, given the logbook's M.S.L. height (true side <= the AGL side),
  is step/air base >= exp(-D_agl) = **1.25 to 2.70** (`bc77070` 1.25, `bc77087` 1.39, `bc77072` 1.78/1.80,
  `bc77026` 2.70). For `bc77070`, the largest key at 59 frames, that is 1.25, at the instrument's
  resolution (tau = x1.246). The note at l.946 ("implies 0.11 to 0.42 at nominal, so it is 1.9 to 3.0
  times the air base the images imply") is nearest to correct but is still read as a plain fact. The
  `step_overstated` verdict itself is sound: it rests on `D_agl < -tau`, not on `k`, and no admissible tau
  (<= the 0.2231 ceiling) flips `bc77070`.

- **[severity: fragile — a read page shipped as unread]** `data-raw/height_measure-image_overlap.R:648-652`,
  shipped in `inst/extdata/flying_height_image_overlap_keys.csv` row `bcc325` — **`w2_height = "not_read"`
  for a key whose page was read** and writes a different height (`frames_logbook` 2, `frames_catalogue` 0,
  `frames_other` 2, `logbook_ft` 1500 against the catalogue's 1,300 ft). The rule's residual class is
  named `not_read`, so the code follows the rule. But the CSV now encodes "the logbook disagrees" the same
  way as "no logbook". That is the absent-equals-real collision CLAUDE.md records three times (#53, fly#93's
  `unspanned`). No verdict moves, because `bcc325` is `too_few_pairs`. The shipped label is still false, and
  a key with enough pairs would land in `not_tested`, reported as if its page had never been read.

- **[severity: fragile — counts described as a neighbouring set]**
  - `inst/notes/terrain-correction.md:956` — "Strip headings ... agree ... on 233 of 237 matched pairs".
    The five keys have **285** matched non-break pairs. 237 is the subset with a page strip whose range
    holds both frames of the pair (`nrow(s) == 1`). On `bc77026` only 71 of its 114 matched pairs have a
    heading. The test pins the same mislabelled denominator.
  - `inst/notes/terrain-correction.md:928`, pinned at `test-fly_footprint_image_overlap.R:232` — "31 of
    192 ordinary pairs did not match". 33 of 192 did not match (31 `no_match`, 2 `no_thumbnail`), or 31 of
    the 190 that were compared.
  - Likewise "0 of 38" unrelated pairs (note l.921, NEWS:4): 2 of the 38 were never compared
    (`no_thumbnail`), so it is 0 of 36. That does not change the gate.

Checked and found consistent: the W1/size/location `case_when`s match A2 item by item, and so does the
test's recomputation. Every other figure in the note, NEWS and CLAUDE.md checks against the shipped CSVs:
0.62-0.81, 0.11-0.42, 83-97%, 112, 157 = 112 + 43 + 2, gaps 0.001/0.114 against 0.44, tau
0.220/ceiling 0.223, |D| 0.548, +0.018, the 0.316 / 0.61-0.64 / 848-850 m figures on `bc77070`, and the
km_to_place values. The fly#95 logbook figures (38 / 689 / 669 / 661 / 20 / 31 / 123) reconcile row by row
with the `flying_height_above_ground.csv` diff, and no `spacing`, `tabled` or `reason` value moved. The
35-page guard list matches every `flight_log_url` in the cached roll metadata. The masked-NCC
sign and offset conventions agree with `patch_shifts()`/`phase_corr()`. The synthetic `p_true` values
(0.2496, 0.3504, 0.6496) gate exactly the 50 intended cases. `write_if_changed()` writes `na = ""`, which
matches the tests' `na.strings = ""`. The negative-control draw's `sort(ck)` is locale-sensitive in
principle, but a space-ignoring collation moves 9 of 578 positions and none of the 40 drawn. The
uncommitted working-tree diff is formatting only.
