# Code-check round 1 — fly#89 staged diff (IR film measurement), 2026-10-02

Scope: `data-raw/format_measure-infrared_film.R`, `data-raw/infrared_film_logbooks.csv`, the five
`inst/extdata/infrared_film_*.csv`, `tests/testthat/test-fly_footprint_infrared.R`, and the
`planning/active` edits. Reviewed read-only; probes were run against the cache, and nothing in the repo
was modified apart from this file.

## Verdict

No defect in the script, the test, or the shipped CSVs changes a verdict or the decision. There is one
wrong published figure and some planning-file drift.

## Findings

- **[bug — published figure]** `planning/active/findings.md:137-138`. Amendment 1's base rate reads
  "5.75% ... (3.10% below, 2.65% above)". The producer line in `irfilm_run4.log:9` prints
  **5.76% (below 3.11%, above 2.65%)**. Recomputed from the cache with the script's own code, it is
  385/6680 = 5.763% and 208/6680 = 3.114%. 177/6680 = 2.65% and 13/6680 = 0.19% are correct.
  The quoted 5.75 and 3.10 match no producer: review-1 had 5.7% over 6,664 rolls. This paragraph is
  what the note and NEWS will be written from, so fix it before Phase 6 copies it.
  In the same sentence, **"none from 1990 on"** has no producer line. The script prints the count
  (13) but not the years. I checked it: the 13 rolls run 1972-1979, the latest being bc79075 at
  0.164, so the claim is true. Either have the control (c) line print the max `photo_year` of the
  rolls at or below 0.30, or drop the clause.

- **[fragile]** `data-raw/format_measure-infrared_film.R:369-371`. The W3 completeness guard fails
  toward pass. It stops only on a roll with a logbook URL and **zero** transcribed pages. A roll with
  2 URLs and 1 page read passes, and so does a page transcribed under the wrong file. An
  `other_format` page that was never transcribed would then silently leave W3 at `pass`. No effect
  today: I matched `infrared_film_logbooks.csv` against the unique `flight_log_url` basenames of all
  32 pulled rolls, and the sets are identical in both directions (27 = 27). A stronger guard would
  compare transcribed `file` basenames to the roll's URL basenames, i.e. `setequal` per roll.

- **[drift]** `planning/active/findings.md:160-163` and the missing run-4 record. The "First full run"
  section still ends "**Status:** per the rule, stopped on the media change and escalated". Nowhere in
  findings.md are the run-4 outcomes under amendment 1 recorded: 27 pass / 1 ambiguous (bcf517) /
  4 fits_no_format, W2 4 pass, W3 6 pass / 11 unrecognised / 15 no_page, decision `add` for both
  media. They exist only in progress.md and the gitignored log, so findings fails the reboot test
  on the result itself.

- **[drift]** `planning/active/task_plan.md`, Phase 2 and Phase 3 checkboxes, flipped to `[x]` in this
  diff.
  - Phase 2's ship item names `inst/extdata/infrared_film_spacing.csv`. That file does not exist;
    five other CSVs ship (review-1 G5).
  - Phase 3 says the logbook CSV has "the same columns as `flying_height_logbooks.csv` plus
    `camera_as_written`". It does not: it has no height, frame-range or control columns, and it adds
    `format_as_written`, `film_type_as_written`, `camera_format` and `same_camera_bw_colour`.
  - The checkboxes now certify text that does not describe the landed work.

- **[drift, minor]** `tests/testthat/test-fly_footprint_infrared.R:4` cites `inst/notes/camera-formats.md`,
  "Infrared film". That section does not exist yet (Phase 6). Fine if Phase 6 lands it under that
  exact heading.

## Checked and clean (so the next round need not redo it)

- **Rule fidelity.** The script (lines 246-255) and the test (lines 39-46) implement amendment 1
  identically: `measurable` comes from the in9 medians; `pass` is in9 in some reading with neither
  in5 nor mm70 in any; then `ambiguous`; then `contradicts` is an alt in while in9 is out; then
  `fits_no_format`. The media decision adds `any(w1 == "pass")`, which neither the registered rule
  nor the amendment states. It is stricter, it is in both the script and the test, and it changes
  nothing.
- **Independence.** The test recomputes the window, controls (a) and (b), every W1 verdict, W2 and
  W3 from `elev`, `base`, thumbnail dims and fractions, and the page classes. It does not trust the
  shipped verdict columns: test 3 and the last test read shipped `w1`, `w2` and `w3`, but tests 2-4
  have already pinned each of those against a recomputation. The unavoidable dependency is that
  `base` and `elev` are script outputs.
- **Rounding.** No verdict can flip from the 0.1 m rounding of `elev` or `base`. The smallest margin
  of any deciding median from a window edge is 0.008, for bci2 nominal in9 at 0.565, and bci2's
  reported 0.635 is in regardless. Next are bcf517 nominal in9 at 0.7705 (0.0095) and bcf517
  nominal in5 at 0.587 (0.03). The rounding moves a median by about 1e-4.
- **Controls.** Control (a) errors on an NA median (`if (NA)`), which stops the script, and it runs
  before (b). (b)'s `fits(NA)`-is-FALSE pass direction is therefore unreachable, because p5 is NA
  exactly when p9 is.
- **Stage 1 guard.** `setequal(airp_id)` fails toward stop. Stage 0's single-media and no-mixed-roll
  `stopifnot` is sound.
- **Same sampler as the sweep.** The DEM sampler (nominal 9-inch square, `extract(fun = mean,
  na.rm = TRUE)`) matches `height_calibrate-flying_height_slip.R:191-200`. The air-base code
  matches `height_calibrate-lower_tail_rolls.R` line for line. The cache file pattern differs
  (`^[0-9]{4}\.rds$` against `\.rds$`), but the cache holds only year files, so the result is the
  same.
- **Window.** The window reproduces as 0.557-0.780 (fly#60's).
  `infrared_film_window.csv` has 2,481 rows, unique `airp_id`, no NA `base`, and the sweep's random
  `airp_id` are unique, so the test's `merge` cannot fan out.
- **Same-camera claims.** Serials 110398, 110399, 122520 and 124223, and ZE#1 (bc7454), all appear
  in `flying_height_logbooks.csv`. All 13 rolls named in `same_camera_bw_colour` are `Film - BW`
  in the cache.
- **CSV types and NAs.** `frames.csv` has 0 NA in every column. `dup_key` reads back logical.
  `thumbnails.csv` `reason` is "" for every row and reads back NA under `na.strings = ""`; nothing
  reads it. bcf07060 has 53 thumbnails at 1245 x 1250 (aspect 1.004), all under 1.0056. No
  thumbnail exceeds collar 0.0707.
- **Test run.** `NOT_CRAN=true` gives FAIL 1 / PASS 28. The single failure is line 149
  (`fly_film_media()`), as intended.

## Observation for the note (not a defect)

bcf517, the `ambiguous` roll (13 frames, 1:4000, 153 mm, 1986), splits by reading:

| reading  | 9 in median | 5 in median |
|----------|-------------|-------------|
| reported | 0.816, out of the window | 0.668, in |
| nominal  | 0.770, in | 0.587, in |

So on the reported reading only 5 inches fits. Admitting Colour IR sizes it at 9 inches. The
amendment permits this, but when the note names it, it should say that one reading favours 5
inches, not just "both fit".
