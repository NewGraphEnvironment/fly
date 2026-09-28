# Code-check round 2 — fly#72 (branch 72-near-upper-scale-wrong)

Scope: staged diff, with the round-1 fixes read closely. Verified against the shipped CSVs,
`inst/extdata/flying_height_sweep.csv`, `data-raw/.cache/near_upper_verdict.rds`, the
overlap window recomputed from the centroid cache (p_window = 0.5573 to 0.7797), and two
logbook images. `test-fly_footprint_height_rolls.R` passes (`NOT_CRAN=true`, load_all).

Round-1 fixes confirmed:
- Fix 1: 120 of 132 sampled frames on tabled keys are beyond the band, the 12 inside all on
  bc85079/80/81, threshold elevation 287.4–2,636.2 m. All reproduce.
- Fix 2: `scale_pat` now rejects the remark `not requested at 1:40,000`, and reads every
  scale string in the logbook CSV correctly. No near_upper page has a scale (n_scale_read = 0),
  so the veto is inert, as the note says.
- Fix 3: bc5509's camera line is "RC8 355" with focal_mm blank. The comment is now correct.

Other figures that reproduce: 24/120, 21/82, 7/31, 1/2, 3/8, 2/9 (sum 58/252). All 22
focal-conflict rows are logbook 305 against catalogue 153. 20 tabled keys are at 153 mm
(107 frames) and 4 at 305 mm (13 frames), r_corrected 1.651/1.686/1.680/1.815. Every
accepted row has p_corrected in 0.58–0.72 and p_nominal outside the window, so none sits at
the window's top edge. bc79039 sheet 6 matches its transcription (2.55 at 152-168, f 153 mm).

## Findings

- **[severity: bug]** inst/notes/terrain-correction.md:542 (the `bc80048` bullet): the note
  says bc80048's "spacing fits nominal and rejects the reported height. It stays on nominal,
  which the spacing supports." Spacing does not fit nominal. The verdict gives
  p_nominal = 0.789 and p_corrected = 0.890, and the window's top is 0.7797, so
  `fits(p_nominal)` is FALSE along with `fits(p_corrected)`. The excluded row's reason
  ("spacing rejects the logbook's height") is correct. The note's claim that spacing
  *supports* nominal for this roll is not: spacing fits neither reading, so nothing here
  measures that nominal is right for bc80048's 11 frames. This is a shipped doc stating a
  wrong measurement.

- **[severity: bug]** inst/extdata/flying_height_rolls_excluded.csv (bc7223, 1249 m, 305 mm,
  1:2000, 5 frames) and the note's table row "excluded: no logbook page | 2 | 9": the reason
  is "no logbook page covers these frames", but a page does. `bc7223__bc7223_1.jpg` (sheet 3
  of 3) lists strip 2 as final 53–108. Its START row reads 4.1 (4,100 ft = 1,249.7 m, the
  catalogued height) and its END row reads 3.2. The transcription emits only frames 53 and
  108 for that strip, so the sampled frames 56/74/82/84/92 get `log_state = "none"`, the
  state defined as "no row on any page reaches this frame". The actual state is a covered
  strip whose height varies within it. That is the "conflict/unread vs no page" confusion
  fly#60's round 3 fixed, arriving through the transcription instead of through the code.
  The outcome is conservative (the roll stays on nominal), but the shipped reason and the
  note's "no logbook page" count (2 roll-heights) are wrong for this roll, which has 12"
  written and spacing fitting reported (p_reported 0.66–0.77, p_nominal ~0.46). Either
  transcribe 54–107 as a covered row with an unread or conflicting height, or reword the
  reason and count.

- **[severity: fragile]** data-raw/height_calibrate-lower_tail_rolls.R:247-251: the comment
  says "a number written after the scale is never swallowed into it", but
  `(?:[, ][0-9]{3})+` still swallows a space-separated three-digit number after a
  comma-grouped scale: `"1:15,000 123"` parses as 15000123 (measured). No current row
  triggers it and the veto is inert, so nothing moves today. The claim in the comment is
  false, though, and a future page reading like "1:15,000 250 ft AGL" would feed a bogus
  scale into `n_scale_same` / `n_scale_double`.

No other defects found in the R/fly_footprint.R gate, the test file, NEWS or the CLAUDE.md
entry.
