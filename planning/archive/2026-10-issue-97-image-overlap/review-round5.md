# Code-check round 5 (fly#97): terminal enumeration, against b28f203

**172 claims enumerated, 14 FAIL.** Table: `planning/active/claims_enumerated_round5.md`.
Every figure recomputed from the shipped CSVs (`na.strings = ""`), the centroid cache, the logbook scans
or git, in a `git archive` copy. The test file passes there (200 expectations).

Round 4's structural fix held for figures: every figure in NEWS, CLAUDE.md and fly#99 is gone, and every
figure left in the note recomputes. What remains is the same mechanism one level up. **A figure-free
universal still has a set.** "The frames there", "on five roll-heights" and "every pair on each key" each
name a set wider than the producer's, and dropping the number removed the cue that would have shown it.
Three of the fourteen are one fact (N99, W6/C3, I1) in four copies.

## Findings

- **[severity: bug]** `inst/notes/terrain-correction.md:1052`, `NEWS.md:7`, `CLAUDE.md:441`, fly#99 /
  `planning/active/followup_issue_draft.md:3`. **The logbook basis covers four roll-heights, not five.**
  The 107 frames a shipped row reaches lie on `bc77026` 2042 (7), `bc77070` 1158 (59), `bc77072` 1981 (3)
  and `bc77087` 1158 (38). `bc77072` 1829 has one `r <= 0` frame, 225, which is on no page (its pages
  end at 223). So:
  - "By the logbooks, 107 frames on five roll-heights are not over the ground photographed" is wrong.
    It should be four.
  - NEWS's "By their logbooks against MRDEM, the frames there that sit under the terrain are not over the
    ground photographed" covers all 112 frames on all five. CLAUDE.md's matching sentence does too.
  - fly#99 opens with "by their logbooks, the frames under the terrain on five roll-heights". Its caveat,
    "a few frames on `bc77026` and `bc77072` have no shipped logbook row", is true but does not reveal
    that one of the five has none.

  `bc77072` 1829 is `misplaced` only through its key-level W2, which comes from 12 frames that are not
  under the terrain. The note's own line 931 ("They are `misplaced` only because the verdict is made per
  key") is correct. No test pins the roll-heights of the 107: T5 pins only the count and the five
  excluded frames.
- **[severity: bug]** `inst/notes/terrain-correction.md:917`. **The positive-shift floor is 0.18, not
  "about 0.19".** In the seed stage (`patch_shifts(step = 64)`, F82:156-165), grid row 114 stays in bounds
  in B until `114 + dr <= n - 114`. That is `dr <= 1022` px of 1250, so p = 1 - 1022/1250 = 0.182
  (0.183 at 1249). The step-32 stage has the same first row and passes 32 patches against a gate of 20,
  and the NCC `min_frac` admits shifts to ~1,033 px, so neither binds. The figure traces to round 4's
  "≈ 0.19 for 1,022 px", an arithmetic slip. It is unpinned.
- **[severity: bug]** `data-raw/height_measure-image_overlap.R:16`. **"The rule — every gate, tolerance
  and verdict — was fixed ... before any thumbnail was matched."** A1 came after the smoke run had matched
  control thumbnails. It changed the synthetic gate and renamed `not_adjacent` to `no_overlap`. A2 then
  replaced the tolerance with a log-unit tau and a ceiling, added `indistinguishable`, and withdrew
  `nominal_by_elimination`. Round 1 added `read_other`. The note (lines 922-927) has it right: the rule
  was fixed before any thumbnail, then amended twice before any key.
- **[severity: bug]** `data-raw/height_measure-image_overlap.R:37`. **"Stage 2 the nine keys: every pair
  (n, n+1) on each key."** Stage 2 keeps only census pairs, those with at least one frame in the two
  census files (A2, S:600-607). That is 366 of the keys' 431 catalogue pairs: `bc77072` 1981 64/98,
  `bc7718` 24/38, `bcc325` 2/11, `bc77072` 1829 18/25, `bc77087` 57/59.
- **[severity: bug]** `CLAUDE.md:453`. **"(two blind reads, one each way)".** fly#97's reader did not
  read 7.8. Batch C (`transcription/batchC_rows.csv:54`) reads "?.8 (7.8 or 3.8) ... reads most like 7.8
  but could be 3.8; not interpreted". The note (line 1031) and fly#99 both say "would not choose, leaned
  7.8". CLAUDE.md is the only copy that turns the second read into a reading.
- **[severity: fragile]** `inst/notes/terrain-correction.md:1050-1052`. **"On the seven roll-heights the
  photos could measure, that [nominal] is no longer contradicted"** holds for `bc77087` only on the 3.8
  read.
  - At 7,800 ft the page puts the ground a median 1,114 m below the aircraft, x1.46 the 765 m that nominal
    1:5000 on 153 mm implies.
  - The rule would then give W2 `ground`, and size would become `unsettled` (S:695-701).
  - The bc77087 section says only "Only the W1 label is the same either way". The next sentence here
    qualifies the 38 frames, not this claim.
- **[severity: fragile]** `inst/notes/terrain-correction.md:1043-1044`. **"The step bound would fall to
  x1.15 to x1.59 over MRDEM's 10th to 90th percentile."** Against the 3.8 bound of x1.387, the T6
  `bound()` gives 10% x1.149, 25% x1.267, 50% x1.442, 75% x1.542 and 90% x1.590. Over the median ground
  the bound rises. Only the like-for-like figure (sea-level ground, x0.68) and the low quantiles fall.
  Suggested wording: "would be x1.15 to x1.59 ... (x0.68 over sea-level ground, the like-for-like bound)".
  The values are pinned; the direction word is not.
- **[severity: fragile]** `inst/notes/terrain-correction.md:1056-1057`. **"Some pages log the
  intervalometer and the speed."** No producer:
  - Neither `flying_height_logbooks.csv` nor `flying_height_logbook_strips.csv` has an interval field.
  - The only "interval" text in LB is two remarks with no value: 1968 "unable to hold constant
    interval", and "F.O. interval set to max".
  - The "speed" the fly#97 transcriptions record ("speed 300 stop 6.8") is the 1977 form's **Exposure:
    Speed / Stop** column, so it is shutter speed, not ground speed. This was checked on the cached scan
    `data-raw/.cache/logbooks/bc77070__bc77070_4.jpg`.

  Round 4 passed this as "a lead". As written, it is an assertion about the scans that what was read of
  them contradicts. Either cite a page that logs both or say "an air base from interval and ground
  speed, if a page logs them, would ...".
- **[severity: fragile]** `CLAUDE.md:446`, fly#99 / `followup_issue_draft.md:22`. **"Catalogue steps
  ... are often evenly spaced along a digitised line (fly#82)."** fly#82's probe measured equal steps
  (64-77% within 0.5%). The digitised line is a mechanism no one measured. The note (line 888) and the
  script header keep "as if". Round 3 removed "interpolated evenly" from the note for the same reason.
- **[severity: fragile]** `CLAUDE.md:450-451`. **"Its image leg does not test the logbook's datum either
  (code-check round 1)."** The antecedent of "Its" is the withdrawn outcome ("Ground below sea level" /
  `nominal_by_elimination`). Round 1's finding was about the image leg of `misplaced` (FD:391), the A2(4)
  gloss "the images reject reading the column as above ground". The sentence credits round 1's finding to
  the wrong outcome.

## Test pins that can pass while their sentence is wrong

Each pin in T4-T6 was read against its sentence. Most pin both the figure and, since round 4, the
property the sentence asserts. These do not:

- **T5** pins `sum(reached) == 107` and the five excluded frames, not which roll-heights the 107 sit on.
  So line 1052's "five roll-heights" passes (finding 1).
- **T4 `at or above it on %d frames.`** pins only the count, 112, from KEYS `frames_nonpositive`. It does
  not check MRDEM >= the page's height. That holds: page < elev on all 107 frames read, with 3,800 ft =
  1,158.24 m against 1,158 m catalogued. A 2% tolerance in T5's `cat_msl` would let it fail silently.
- **T4 `The census frames, 46-69, are %d km`** checks the distance, not that the census frames of
  `bc7718` 1524 are 46-69. They are.
- **T4 heading pin** checks the count of 4 `differ`, not the four pairs named. They are right: `bc77087`
  1, 2, 3 and `bc77072` 1981 111.
- **T4 `Of the five keys' %d matched pairs`** computes matched *and non-break* pairs. These are equal
  today because no matched pair is a line break, but the two can come apart.
- **T4 table** asserts the overlap cells only where `pairs_used >= 3`. For the two 2-pair rows the blank
  cells are not asserted, so a figure typed there would pass.
- **T4 `crew-written overlap, %d rolls`** reads `sum(w$gated)` from the WRITTEN constants. It would still
  read 9 if a gated roll had no matched pair and dropped out of the median. All 9 have 5 today.
- **Unpinned and correct:** N5, N60, N67 (names), N78, N80, N84-N85, N94.
- **Unpinned and wrong:** N24 ("about 0.19"), N92 ("fall"), N97, N99, N102.

## Outside the enumerated scope, noted only

- `CLAUDE.md:421-422`, the fly#95 Key Decision, was edited by fly#97 to read "689 ... 669 carry the
  catalogue's figure and no page puts the ground under it". It dropped the qualifier the note's fly#95
  section now carries: "on the transcription as it stands", with `bc77087`'s digit.
- In fly#99, "the frames whose MRDEM ground is at or above" describes `fly_footprint()`, which uses
  whatever `dem` the caller passes, not MRDEM.
- In the note at line 925, "One change came after the run" is true of the rule. `4a9eea8` also added the
  reported `km_to_place` column to the shipped keys CSV after the run.

## Re-verified correct, where earlier rounds had found defects

- The 3.8 read is fly#93's (9ee2114). The re-read declined to choose.
- `bc7718` 31-45 is 14.75-15.86 km from Tahsis, from the cache.
- The covered-pair bound is x1.25-x2.61. `bc77070` passes by 0.0061.
- The fly#95 counts are 669/689, 38 roll-heights, 31/154 and 26 on `main`, and exactly nine rolls carry
  the page figure below the ground.
- 531/537 matched pairs are positive, and all 80 synthetic shifts are negative.
- The heading count is 233/237 of 285, with 0 reverse.
- The 7.8 counterfactual recomputes: 2,377 m, median 1,114 m, 3.8%, 2.05.
