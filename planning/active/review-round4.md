# Code-check round 4: enumeration of the round-3 fix text (fly#89), 2026-10-02

Read-only pass. This file is the only one written. The scope is the text written to fix round 3:
camera-formats.md (the #54 bullets, "at least 5 air bases", the serial list), georeferencing.md
("every leg it scored"), the NEWS top entry, the CLAUDE.md IR bullets, findings.md (the #54 band
line and the same-camera list), progress.md (the runs line), and the fly#91 issue body.

Producers re-read for this pass:
- `infrared_film_frames.csv`, recomputed in R: r, ratio_asl, and overlap at nominal and at the
  reported height per roll-height.
- `infrared_film_rolls.csv`, `infrared_film_pages.csv`, and both logbook CSVs.
- `irfilm_run1-5.log`.
- HEAD's `film_rotations_legs.csv` and `film_rotations_excluded.csv`.
- `R/fly_rotation_calibrate.R` and `R/fly_footprint.R`.
- `height_calibrate-flying_height_slip.R` (the set definitions) and
  `height_calibrate-lower_tail_rolls.R`.
- The page images `bcir9_1/2`, `bcir12_1/2` and `bc5312_2`.

**About 85 claims checked**, counting each cell of the fly#91 table. **4 fail**, and 2 more are
minor scope or imprecision.

## Findings

- **[published claim, and fly#91's plan] The "fly#60/#72 class" scope is dropped for two of the
  three roll-heights.** Affected: `camera-formats.md` ("That is the fly#60/#72 class"), the
  `NEWS.md` top entry ("the fly#60/#72 wrong-scale class"), findings "Result under amendment 1",
  and the fly#91 body ("This is the class fly#60 and fly#72 tabled for BW and colour"; "Run the
  three roll-heights through the existing roll-table rules in
  `data-raw/height_calibrate-lower_tail_rolls.R`").
  - fly#60's population is the lower tail, `ratio_asl <= 0.5`
    (`height_calibrate-flying_height_slip.R:165`; CLAUDE.md: "under half their nominal height").
  - fly#72's population is `near_upper`, `2 < ratio_asl <= 3`.
  - The roll-table generator reads only `lower_tail`, `upper_tail`, and `near_upper` beyond the
    band (`height_calibrate-lower_tail_rolls.R:237`, `:400`).
  - From `infrared_film_frames.csv`, the ratio_asl values are:

    | roll-height | ratio_asl | stratum |
    |---|---|---|
    | `bc5312` 46-62 | **0.731** | neither |
    | `bci12` 1-14 | **0.762** | neither |
    | `bci9` 12-36 | 2.436 | #72's `near_upper` |

  - `bc5312` and `bci12` leave the band only because of terrain (elev 705-1355 m and 1197-1248 m).
    On BW/colour, frames like them were never in any population #60 or #72 settled, so none was
    ever tabled.
  - The defect *kind* is right and well supported. Spacing fits the reported height. Each
    logbook also writes the catalogued height: `bc5312` sheet 2 "11.0" for 46-62 = 3,353 m;
    `bci12` sheet 1 "12.08" for 1-14 = 3,682 m; `bci9` sheet 1 "19.5" = 5,944 m.
  - **What is wrong is that fly#91's remedy, as written, will not reach two of its three
    roll-heights.**
  - Fix: say "the defect fly#60/#72 tabled (right height, wrong scale)". In fly#91, state that
    `bc5312` and `bci12` sit at ratio_asl 0.73-0.76, outside every stratum the generator reads,
    so that tabling them needs a population or rule amendment and not just a re-run. Note that
    all three heights are logbook-confirmed.

- **[published claim] `inst/notes/georeferencing.md:288`: "every leg it scored came back
  `not_rotated`".**
  - In this package, `scored` is a leg *status*: "`scored` (it could have decided)"
    (`fly_rotation_calibrate.R:60`).
  - None of the 250 IR legs at HEAD is `scored`:
    - **150 are `not_rotated`.** These are the attempted legs, the longest ≤ 6 per roll at the
      default `max_legs = 6`: 22 rolls × 6, 2 × 5, 2 × 4. `fly_rotation_score_leg()` returned
      `fail("not_rotated")` before `fly_fetch()`.
    - **100 are `not_scored`** (over `max_legs`, never attempted, `:135`).
  - The fix reuses the word for the status these legs explicitly are not. That is the
    absent-as-measured encoding CLAUDE.md's #53 decision warns about.
  - Fix: "every leg it attempted (up to six per roll) came back `not_rotated` before its
    thumbnails were asked for; the other 100 were over `max_legs`".

- **[count] CLAUDE.md IR Key Decision: "Three things are load-bearing."**
  - Four bullets follow: the amendment, `bcf517`, 23 cm vs 18 cm, and the 56 frames. The
    round-3 fix added the fourth bullet and did not change the count.
  - Fix: "Four things", or move the 56-frame bullet out of the list.

- **[fly#91 body] "`bci9`'s sheet 2 (`bcir9_2.jpg`, finals 101-140)".**
  - The FINAL column on that sheet runs 101, 106, 107, 110, 111, 118, 119, 128.
  - "129-140" is written in the FIELD column (field 105 is final 101), with no final beside it.
  - The catalogue's frames on that sheet are 101-118 (5,898 m = the sheet's 19,350 ft).
  - Fix: "finals 101-128".
  - The other sheet claims check out:
    - "Scale 1/15,840" is written at the foot of sheet 2.
    - Sheet 1 covers finals 1-100, including 12-36 (OP 215/76 Boomerang Creek).
    - Sheet 1 writes no scale.

## Minor (scope, not wrong)

- **fly#91 body: "With a DEM, these frames draw at about 2x … or 0.5x".** The same holds with no
  DEM, because without a `dem` every film frame is nominal and the #54 check never runs
  (`fly_footprint.R` ~1110-1450 is inside the `dem` branch). The qualifier implies that a no-DEM
  caller is unaffected. Round 3 made the opposite point: that caller gets no signal at all.
  `camera-formats.md`'s "With a `dem` they fall back to it … so they draw at about 2x" reads the
  same way. Suggest "with or without a DEM".
- **No producer line or test recomputes the per-roll-height figures.** The figures are 0.59-0.62,
  0.81 / 0.81 / 0.23, r 0.47 / 0.51 / 2.03, and ~2x / 0.5x. They reproduce exactly from
  `infrared_film_frames.csv`: 0.594 / 0.620 / 0.620, 0.805 / 0.807 / 0.228, and 1/r = 2.11 /
  1.97 / 0.49. But neither `format_measure-infrared_film.R` (its roll-level `p_reported` uses
  in-band frames only) nor `test-fly_footprint_infrared.R` produces them, and the test does not
  check `height_class` (56 / 3,769) at all. That count's only producer is `irfilm_run5.log:76`.
  Not wrong today. It is the "never a number without its producer" gap.

## Checked and matching

- **camera-formats.md.**
  - 3,769 / 56 / 0 slip-repairable (`run5.log:76`; the CSV has no `slip_repairable` class).
  - The band and slip factor were calibrated on BW/colour film. The ceiling is the maximum over
    film with `ratio_asl <= 3` and over digital (`height_calibrate…slip.R:315-321`).
  - With a `dem`, the 56 are `implausible` and sized from nominal (`fly_footprint.R:1248-1254`,
    `:1382-1390`).
  - The three roll-heights, with frames 17 / 14 / 25 (46-62, 1-14, 12-36).
  - The window is 0.557-0.780, so 0.805 and 0.807 sit above it and 0.228 below.
  - "At least 5 air bases": `bw_n >= MIN_FRAMES` (5), counted on finite overlaps.
  - 6,680, 5.76%, and 13 (0.19%) flown 1972-1979.
  - The serial list (110398, 110399, 122520, 124223, ZE #1, ZE #2) is now complete against the
    11 unrecognised rolls in `infrared_film_logbooks.csv`.
- **georeferencing.md.** 26 IR rolls were `legs_unscorable` at HEAD. "Before its thumbnails were
  asked for" holds, because `not_rotated` returns before `fly_fetch()`.
- **NEWS and CLAUDE.md.** Six pass / 11 unrecognised / 15 no page, which sums to 32
  (`run5.log` Stage 5). 3,769 / 56. "Drawn at nominal until tabled".
- **findings.md.** The #54 band line. "ZE#2 alongside 110398" is right: `bcc84` writes
  "ZE #2 / UAG #2 110398", and `bc7407`/`bc7408` in `flying_height_logbooks.csv` write
  "ZE#2 UAG#4 110398".
- **progress.md.**
  - Five full runs. Runs 1 and 2 halted: run 1 on the missing logbooks, run 2 on the W2 NA.
  - Run 3 completed under the registered rule and wrote CSVs.
  - Runs 4 and 5 ran under the amendment. Their logs differ only by the added "flown 1972-1979"
    text.
  - Run 1's W1 was "contradicts 4, pass 28".
- **fly#91 table.** Every cell matches the CSV: scale, height, focal, frame counts, median r,
  and both overlaps. Also checked: 56 of 3,825; the window; the `near_upper` rule's location in
  `height_calibrate-lower_tail_rolls.R`; and that #60 and #72 describe "right height beside a
  wrong scale, where the nominal fallback was the defect" (CLAUDE.md).
