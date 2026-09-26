# Code-check round 1 — fly#71 staged diff

Reviewer: subagent, 2026-09-26. Worked in a copy of the tracked tree under the session
scratchpad; no repo file other than this one was touched.

## Verified (no finding)

- `R/fly_footprint.R:1178-1179` — the `tab_factor != 1` gate. Ran
  `test-fly_footprint_height_rolls.R` in a copy: all pass. Restored `tab_factor > 1` in the
  copy: exactly the new test ("a factor below 1 is applied ahead of #54's slip...") fails, 2
  expectations, no errors. The guard fires.
- `tabled` and `slipped` stay mutually exclusive (`slipped <- disputed & !tabled & ...`), so
  `height_source` assignment order cannot mislabel. A 0.1 frame whose `r_tabled` leaves the
  band falls back to #54, and only at the upper edge: that needs terrain about 78 m below
  sea level for bc78065 and is impossible for bcc00085, so the "never corrected_unit_slip"
  roxygen holds for the tabled keys.
- Counts in the prose match the tables: 22 + 6 = 28 roll-heights (vignette); upper tabled
  frames 24+15+24+68+127+41 = 299, and 1,589 - 299 = 1,290 = upper excluded frames (roxygen,
  code comment).
- The script: `settle()` holds the factor as an index, so `named[fi]` is bit-identical to
  `1/K` and `is_f()` compares it within 1e-9. `stopifnot(!anyNA(v$cause[v$accept]))` covers a
  factor reaching `accept` with no cause. `v$reason != ...` on accepted rows is NA, but
  `FALSE & NA` is FALSE, so the "; #54's 10.764 still applies" suffix cannot land on them.
  `key4` is defined before the new cross-tail `anyDuplicated` check. Every upper excluded
  reason contains "10.764", and no lower one does.

## Findings

- **[fragile] `R/fly_footprint.R:686`, `:202-208`, `:1110`, `:1144`,
  `man/fly_footprint.Rd:211`, `tests/testthat/test-fly_footprint_height_rolls.R:7` — "pre-2000"
  is false for half the tabled roll-heights.**
  The roxygen says "On six **pre-2000** roll-heights the flight logbooks show the factor is
  exactly 10". The comments say "the 299 on pre-2000 rolls" and "on the pre-2000 rolls the
  crew's height is the catalogue's divided by exactly 10".
  `bcc00085` has `photo_year` 2000 in `flying_height_sweep.csv`, and its own logbook row in
  `data-raw/flying_height_logbooks.csv` reads "flight C-057-FS-00, 2000-SEP-23". So 3 of the 6
  tabled roll-heights, and 236 of the 299 frames, are from 2000, not before it.
  This is a population claim in the user-facing docs, and CLAUDE.md's #60 entry ("×10 on
  pre-2000 rolls (fly#71)") will likely be restated from it at archive time.
  Fix: use "1978-2000", or "rolls before 2003".
  The `fly_height_slip_factor()` comment has a smaller version of the same problem. It says
  that what reaches 10.764 is "the 2003-2005 rolls ... plus the few frames no page settles".
  Three pre-2003 roll-heights also reach it (19 frames):
  - `bc5596` (1974, 8 frames, no page);
  - `bcb98013` f52 (1 frame, fits no factor);
  - `bc79027` (1979, 10 frames). Its page *does* read /10, and the spacing rule refused it.

  So "no page settles" misdescribes bc79027. That is deliberate per the stated tradeoffs,
  but the comment says otherwise.

No other issues found. The code change, the script refactor, the regenerated tables and
the tests are consistent with each other and with the #54 and #60 constraints in CLAUDE.md.
