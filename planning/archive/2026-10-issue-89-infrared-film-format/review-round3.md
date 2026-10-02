# Code-check round 3: fly#89 staged diff (`diff3.patch`), 2026-10-02

Read-only review. Tests ran from the repo (no edits) and from a scratchpad copy of three test blocks.
This file is the only one written in the repo.

## The mechanism behind rounds 1 and 2

The same thing went wrong each time. Prose restates a producer's result and quietly drops its
**scope**: the denominator, the reading, the subset, or what the counted things are. That is how
round 1 got rounding and an unsourced "none from 1990 on", and how round 2 got one reading's range
quoted as both, a W2 that measures only "square" written up as "23 cm", and a basis list missing a
route. The restatement is consistent with the story, and nobody re-read the producer row.

So in this round I enumerated every number and factual claim in the new or changed prose and checked
each against its producer. That covers the camera-formats.md section, the georeferencing.md hunk,
the NEWS top entry, the CLAUDE.md bullets, the fly_footprint.R comment and roxygen, the fly_georef.R
roxygen and comment, and findings.md "Amendment 1" and "Result under amendment 1". The producers are
irfilm_run1-5.log, filmrot_ir.log, the five infrared_film_*.csv, film_rotations*.csv against HEAD,
both logbook CSVs, the centroid cache, and the code. Code claims were checked in code.

**About 140 checked. 7 do not hold.** Finding 1 matters. The rest are scope slips of the same kind.

## Findings

- **[bug, data and published claim]** `inst/notes/camera-formats.md:329-331` ("The 56 fall back to
  nominal scale, as any film frame does"), `NEWS.md:4` ("56 fall back to nominal scale"), and
  findings "Result" (#54 band line).
  - The count is right. What the 56 *are* was never looked at.
  - In the shipped `infrared_film_frames.csv`, all 56 fall on three roll-heights, and on each one
    spacing **rejects nominal and fits the reported height**:

    | roll | frames | catalogued | r | p_nominal at 9 in | p_reported at 9 in |
    |---|---|---|---|---|---|
    | `bc5312` | 46-62 (17) | 3353 m, 1:30000, 153 mm | ~0.47 | 0.805 (above window) | 0.594 (in) |
    | `bci12` | 1-14 (14) | 3682 m, 1:15840, 305 mm | ~0.51 | 0.807 (above) | 0.620 (in) |
    | `bci9` | 12-36 (25) | 5944 m, 1:8000, 305 mm | ~2.03 | 0.228 (below) | at 1:15840: 0.610, r 1.03 |

  - `bci9`'s own logbook row in `data-raw/infrared_film_logbooks.csv` reads "scale 1/15,840
    written". The rest of the roll is catalogued 1:15840 at the same 5,944 m.
  - The scales look swapped between the two 1976 Forest Protection rolls: `bci9` 12-36 carry
    `bci12`'s 1:8000, and `bci12` 1-14 carry `bci9`'s 1:15840.
  - This is the "right height beside a wrong scale" class from fly#60 and fly#72. CLAUDE.md says
    of it that "#54's fallback to nominal was the defect".
  - **Before this diff**, these 56 frames were empty geometry, as fly#30 intends. **After it**,
    they draw from a scale the package's own shipped witnesses reject: about 2x too wide on
    `bc5312` and `bci12`, and about 0.5x on `bci9`, so 4x or 0.25x in area. A DEM caller gets an
    `implausible` warning. A caller with no DEM gets no signal at all.
  - The format decision is unaffected, since all three rolls pass W1.
  - **Fix.** Either table the three roll-heights in `flying_height_rolls.csv` under the existing
    #60/#72 rules (spacing rejects nominal; `bci9` also has a logbook scale), or file that as a
    follow-up. Either way, change the note and NEWS from "fall back to nominal, as any film frame
    does" to the measured fact: spacing says nominal is the wrong reading for all 56.

- **[published claim, overclaim]** `NEWS.md:12` ("Spacing cannot separate 23 cm from 18 cm; the
  logbooks do") and `CLAUDE.md` Key Decision ("Spacing cannot separate 23 cm from 18 cm. The
  logbooks do that.").
  - Logbook pages exist for 17 of the 32 rolls. Only 6 write 9 x 9 or name an RC 10.
  - 15 rolls have no page, so nothing separates 23 cm from 18 cm on them. These include 4 of the
    7 BW IR rolls (`bci93044`, `bci93045`, `bci95063`, `bci96066`), plus `bcf517` and
    `bcf07060`.
  - The note's own section ("That separation rests on two things") is accurate. The one-liners
    drop the denominator.
  - Fix: "the logbooks do, on the 17 rolls that have one".

- **[published claim]** `inst/notes/georeferencing.md:288` says "every leg came back `not_rotated`
  before its thumbnails were asked for".
  - The HEAD `film_rotations_legs.csv` has 250 legs on the 26 IR rolls: **150 `not_rotated` and
    100 `not_scored`**. The 100 were over `max_legs` and never ran.
  - Fix: "every scored leg".

- **[published figure, scope dropped]** `inst/notes/camera-formats.md:297` says "Over the 6,680
  BW/colour rolls, 5.76% ...".
  - The producer (control (c)) counts rolls with **at least 5 bases**.
  - The snapshot holds 6,684 BW/colour rolls (6,716 film rolls in `filmrot_ir.log` Stage 0, less
    the 32 IR rolls).
  - findings.md has the qualifier ("with at least 5 bases") and the note lost it. Add it back.

- **[published claim]** `inst/notes/camera-formats.md:330` says "The band, slip factor and
  ceiling were calibrated on BW and colour only".
  - The ceiling's producer, `height_calibrate-flying_height_slip.R:315-321` ("film and
    digital"), takes the maximum over BW/colour film **and digital** frames.
  - The point the sentence makes, that no IR frame was in any of the three calibrations, is true.
    Say "on BW and colour film (and, for the ceiling, digital); never on IR".

- **[minor, incomplete list]** `inst/notes/camera-formats.md:273-274` and findings "Same-camera
  observation" give the serials as "110398, 110399, 122520, 124223, and ZE #1".
  - `bcc84`'s page also writes **ZE #2 / UAG #2** (`infrared_film_logbooks.csv`), and the list
    omits it.
  - The claim still holds:
    - `bcc84` also names 110398.
    - ZE #2 is on BW pages: `flying_height_logbooks.csv` has "ZE#2 UAG#4 110398".
    - ZE.2 is the camera on `bcc23`, `bcc7` and `bcc8`, which write 9 x 9.
  - Either add ZE #2 or say "serials" and drop ZE #1.

- **[drift, planning, introduced by the round-2 fix]** `planning/active/progress.md` says "smoke
  then four full runs (`data-raw/.cache/irfilm_run{1..5}.log`)".
  - There are five logs, and all five are full-population runs (Stage 0: 3,825 frames on 32
    rolls):
    - run 1 stopped at the missing logbooks, after W1 and W2;
    - run 2 stopped on the W2 NA error;
    - run 3 completed under the registered rule and also wrote the CSVs;
    - runs 4 and 5 ran under the amendment.
  - So "four" is wrong. Say five, and say that run 3 wrote CSVs that run 4 overwrote.

## Round-2 fixes, checked

- **`fly_footprint()` basis item.** The camera-table route is restored ("a digital frame whose
  camera the shipped table resolved by calibration or PAT-B identity"). This matches
  `basis[from_table] <- ifelse(fmt$inferred, "inferred_format", media)`, where only the
  focal-length fallback sets `inferred`. The man page is regenerated to match.
- **The 0.19-0.27 range.** The nominal and reported ranges are now given separately in the note,
  NEWS and findings. They match run 5: nominal 0.200 / 0.274 / 0.191 / 0.274, reported 0.224 /
  0.113 / 0.212 / 0.273.
- **"Square 23 cm frames".**
  - Removed from `fly_footprint.R`.
  - The note now marks the `bcf07060` observation as "by eye, not measured".
  - I opened `bcf07060_010` and `_011` from the cache. Both show eight fiducials (four corners
    and four mid-sides) and the data strip `30BCC (IR) 07060 No.010` / `No.011`.
  - The coastline shift between the two frames is about 900 of 1,250 px, which fits "share little
    ground". The observation holds as worded.
- **Counts in `georeferencing.md`, CLAUDE.md and the `fly_georef` roxygen.** 57 shipped (44 /
  11 / 2), 6,659 excluded, and 59 measured but not shipped (37 / 10 / 9 / 3). The era and focal
  table (2/11/0, 0/33/11, 2/0/10, 0/44/1) is recomputed from `film_rotations.csv`.
  - The 116 examined and 79 with thumbnails reconcile: 79 = 57 + 10 + 9 + 3.
  - "Three unshipped rolls against their era" still holds: `bcf07060`'s one decisive leg is 90,
    which is in its era.
  - `bcc23` is 1969, 305 mm, and its decisive legs are 46.8 / 286.0 / 212.3, at least 90 degrees
    apart.
- **Non-IR rows of all five `film_rotations*.csv`.** Identical to HEAD (`all.equal` after
  dropping IR rolls). `_population.csv` is identical.
  - The 26 IR rolls were all drawn.
  - The 6 not drawn are `bc5312`, `bc5367`, `bcc84`, `bcc92`, `bcf517` and `bci7`.
  - So the two thumbnail-bearing rolls that were not drawn explain why the "other 24 have no
    thumbnails at all" agrees with W2's 4 thumbnail rolls.
- **`fly_georef.R` comment.** It now says "the day that roll was calibrated", which matches
  `res$cal$measured_on` written in `one()`. The legacy dates taken from the shipped CSVs are the
  same day.
- **The rotation date fix.**
  - `prev_excl$measured` reads back as logical.
  - The fallback reads both shipped tables.
  - An undated roll stops the run.
  - No defect found.
- **Tests.**
  - `test-fly_footprint_infrared.R`: 29 pass, 0 fail.
  - `test-fly_film_rotations.R`: all pass (1,250 + 419 + 173 + 171 + ...).
  - The three new `test-fly_footprint.R` blocks: 8 pass. All runs used `NOT_CRAN=true`.

## Checked and matching (selection)

- **Population.** 771 / 7 and 3,054 / 25, and 3,825 / 32.
- **Window and controls.**
  - Window 0.557-0.780 at n = 2,481.
  - The sweep's `random` set is drawn from the pinned BW/colour `film`.
  - Controls 0.635 and 0.343.
  - Control (c): 6,680 rolls, 5.76 / 3.11 / 2.65%, 13 rolls (0.19%) flown 1972-1979.
- **W1.** 27 pass / 1 ambiguous / 4 fits_no_format / 0 contradicts, and the per-media table.
  - `bcf07060` is 0.200 and -0.441.
  - `bcf517` is 13 frames at 1:4000 and 153 mm, with 0.770 / 0.587 / 0.816 / 0.668.
  - Years are 1975 / 1995 / 1996 / 2007.
  - `bci95063` (1:7000) and `bci96066` (1:7200) are both 305 mm. `bci93044` and `bci93045` are
    1:7200, at 0.652 and 0.650.
- **W2.**
  - 4 rolls and 422 thumbnails, all 1,250 px, aspect 1.
  - Per-frame collar at most 0.0617, against a reference maximum of 0.0707 over 254 frames. No IR
    roll is in the mask sweep.
  - 0 declined.
- **W3.**
  - 27 pages on 17 rolls, 6 pass, 11 unrecognised, and no `other_format`.
  - Every serial cross-reference roll is `Film - BW` in the cache, and each roll's BW page carries
    that serial.
  - Run 3's `not_stated 11` against run 4's `unrecognised 11` is a script branch added between
    runs. The logbook CSV is untouched since 07:42.
- **#54 band.**
  - 3,769 / 56 / 0 slip-repairable.
  - The maximum IR height is 7,620 m, under the 16,000 m ceiling.
  - No IR roll is in either roll table.
  - "The repair fires on the 1,589 and nothing else" (`fly_footprint.R`) still holds.
- **Downstream behaviour.**
  - `fly_coverage()`, `fly_select()`, `fly_overlap()` and `fly_filter()` all go through
    `fly_footprint()`, so "now count them" holds.
  - The focal fallback keys are 80 / 92 / 100 / 120 / 127, and the IR focal lengths are 153 /
    305.
  - The `format_size` route was not `film_like` before this diff and is now.
- **The four pins.**
  - The #54, #58, #65 and #80 scripts are pinned.
  - The other `data-raw/` scripts take film from the pinned sweep or census, or do not filter on
    `media`.
