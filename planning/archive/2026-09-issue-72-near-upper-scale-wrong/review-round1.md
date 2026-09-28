# Review round 1 — fly#72 staged diff

## Findings

- **[bug — false claim in shipped note]** inst/notes/terrain-correction.md, new section, bullet 2
  ("Their keys reach **3,227** catalogue frames, all in the 2 < r above sea level ≤ 3 stratum,
  so every one is outside the band whatever the terrain and the table fires on all of them.
  The fallback drew them at 1/r of their width").
  The inference runs the wrong way: terrain *lowers* r (r_agl = (fh − elev)/nominal ≤ r_asl), so
  r_asl > 2 does not keep a frame above 1.6. `fly_footprint()` only consults the table for
  `out_of_band` frames (R/fly_footprint.R ~1204). The key reaches the band at a terrain of
  fh − 1.6·nominal: 390 m for bc5642/44/45/48/50/89, 406 m for bc5699/5701/5702, 330 m for
  bc78110, 287 m for bc79039, 936 m for bc7692, 1,521 m for bc85079–81. The shipped sweep already
  disproves it: of the 132 sampled frames on the 24 tabled keys, **12 sit inside the band**
  (r 1.49–1.57, all on bc85079/80/81, which is half of those three rolls' 24 sampled frames).
  Those frames are `"reported"`, the table does not fire on them, and the fallback never drew
  them narrow. Their sizing is unaffected, because factor 1 means the same height. But the
  sentence is wrong, and so is the NEWS implication that all 3,227 frames the keys reach move
  from a 1/r-wide fallback to `"corrected_roll_table"`. CLAUDE.md's "reaching 3,227 in the
  catalogue" is accurate as a key count; only the note's "every one / fires on all of them"
  is false. Suggest: "reach 3,227 catalogue frames; the table fires on those that terrain leaves
  beyond the band (in the sample, 120 of 132), and the rest were already sized from their
  height".

- **[fragile]** data-raw/height_calibrate-lower_tail_rolls.R:187–189, the logbook scale parser.
  It reads any "1:" anywhere in `scale_as_written` as the page's scale. Row 117 (bc78105,
  `remark: "not requested at 1:40,000"`) parses to 40000, a scale the remark says was *not*
  flown. The capture `[0-9][0-9, ]*` also swallows trailing space-separated digits (for example
  "1:15,000 12 photos" becomes 1500012). Today this is inert: no near_upper frame's covering row
  carries a scale (`log_scale` is NA on all 252, so the veto never fires, as the note says). But
  the veto is wired to `n_scale_same > 0`, so it would drop a row if a future page's remark
  names the catalogue's scale.

- **[minor — wrong premise in test comment]** tests/testthat/test-fly_footprint_height_rolls.R:597.
  The comment says bc5509's logbook "reads 21,500 ft (6,553.2 m) on a 6\" lens". The transcribed
  row (bc5509__bc5509_1.jpg) has `focal_as_written` "RC8 355" and a **blank** `focal_mm`, and the
  shipped row has `log_focal` NA. So the logbook states no lens there, and the acceptance rests
  on spacing alone. That matches the note's own point that the height cannot discriminate, so
  the comment overstates the witness.

## Checked and clean

- Every count in the note's outcome table (24/120, 21/82, 7/31, 1/2, 3/8, 2/9 → 58/252) against
  the shipped CSVs. The 20 × 153 mm / 107 frames and 4 × 305 mm / 13 frames split. All sixteen
  bc54xx–bc57xx rows are 1972–76. r_corrected 1.651/1.686/1.680 on bc7692/85079/85081. Reach
  3,227 (lower 1,130, upper 308). 505 = 2,094 − 1,589. The 3 random-set frames beyond the band,
  bc5703 among them. All 21 focal-conflict rows are 305 against 153 (bc79075's 85 against 88
  is not a conflict). No near_upper page writes a scale.
- The logbook CSV has 183 added rows and no removed or altered ones. 142 new files; roll labels
  reach 54, since bc5664 and bc7408 ride on neighbours' pages. NEWS says "144 pages on 53 rolls",
  which matches the fetch count in progress.md. That is defensible if 2 fetched pages yielded no
  rows, and not flagged.
- Rule: `spacing_ok & !fits(p_nominal)` cannot produce NA (`fits()` is `is.finite() & ...`). The
  reason ordering gives each excluded near_upper row the predicate that fired, and the
  "; nominal scale still applies" suffix is skipped only where the text already says so. The
  sibling skip is correct, the census stopifnot includes `near`, and the 90/105/14 guard is exact.
- Tests: the whole file passes in a temp copy (NOT_CRAN=true, load_all). The factor-1
  near_upper row is reached (r = 2.55 > 1.6, `r_reported > 0`), and the mocked-table test
  restores the defect and would fail without the row.
