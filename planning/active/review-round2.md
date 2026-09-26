# Code-check round 2 — fly#60 (lower-tail roll table)

Reviewed: diff_r2.patch, R/fly_footprint.R (whole DEM route), the new test file, the
calibration script, both shipped CSVs, setup.R. Ran `test-fly_footprint_height_rolls.R`
and `test-fly_footprint_invariants.R` with NOT_CRAN=true in a copy (/tmp/fly_review_r2):
both green.

Round-1 fixes checked and holding: runtime sizes from `height_m` (bc7280 -> 6096);
focal conflict counts only legible mismatches; verdict grouped on the same 4-field key the
runtime matches, with the reach check on those 4 fields; "no adjacent frames" is its own
reason, reached only when spacing is non-finite.

Runtime classification checked: `tabled` is excluded from `implausible` by name, and a
tabled frame always has a finite first-pass elev (r_reported finite), so it lands in
`corrected` and never in the `unusable` residual; the second pass samples
`resize(first$elev, tab_height)`, the corrected rectangle; the NA/"NA" key hole is closed
by `keyed`; `out_of_band` (not `disputed`) is what lets bc7280's below-terrain height reach
the table, and a tabled factor that fails to reconcile falls back exactly as before.

## Findings

- **[fragile]** tests/testthat/test-fly_footprint_invariants.R:46 — the invariant
  `has_height <- fp$height_source %in% c("reported", "corrected_unit_slip")`, asserted
  identical to `!is.na(fp$height_agl)` and to `footprint_terrain == "dem_agl"`, is now
  false for the new value: a `"corrected_roll_table"` frame has a `height_agl` and is
  `dem_agl`, but is not in the set. It stays green only because no `footprint_cases()`
  input sits on a table row (the bundled frames are bc5282/1968). The closed set was not
  widened when a third "has a height" value was added, so the guard now encodes a wrong
  contract and will fail the day a case reaches the table (e.g. if `roll_fixture()` is
  added to the sweep), or — worse — mislead a reader into treating
  `corrected_roll_table` as heightless. Add the new value to the set.

- **[fragile]** R/fly_footprint.R:1133-1135 — the key is built with `paste()` on
  mixed types: `tab$scale_n` / `tab$flying_height` / `tab$focal_length` are read by
  `read.csv()` as **integer**, while `fh` and `scale_num` are **double**. `paste()` formats
  them differently for round values: `paste(100000L)` is `"100000"` but `paste(100000)` is
  `"1e+05"` (measured; likewise 1e6). No row in today's table has such a value (largest
  scale_n 75062), so nothing is mis-matched now, but a regenerated table carrying a
  1:100000 row would silently never match — the frame falls back to "implausible" with no
  error. The script's reach check (`key4` over `frames`, both numeric) and the test's
  fixture check (numeric scale vs integer table, same as runtime) cannot see it. Format
  both sides explicitly (e.g. `format(x, scientific = FALSE, trim = TRUE)` or
  `sprintf("%.0f")`) or coerce both to the same type before pasting.

No bugs found that produce a wrong footprint, height or classification on today's table.
