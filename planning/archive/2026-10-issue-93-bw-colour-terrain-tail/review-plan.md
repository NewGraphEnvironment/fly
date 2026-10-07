# Plan review (Plan agent, read-only, 2026-10-06) — findings and disposition

| # | finding | disposition |
|---|---|---|
| B1 | A2 at `p_reported` is not exclusion-only for the 39 "fit neither": the logbook height can be 2% off, and `p_corrected` is a subset median | already fixed in the pre-registration (c57a6ed) before the review landed: A2(b) uses the frame range at 0.98-1.02 h, which bounds any subset median |
| B2 | "logbook not read" is false where rows exist (whole pages transcribed, 12 rolls with rows) | A2 reasons reworded to make no claim about reading; A2 cannot reach `accept` anyway (it excludes only rows where condition 3 cannot hold), and the generator also sets `accept <- accept & !a2` explicitly |
| B3 | Control 2 is circular (M calibrated on the sweep including the 12); 12 is weak | M made self-consistent over every frame read exactly (loop); Control 3 added: a seeded 1,000-frame draw from the 500 m past the prefilter, read exactly, must hold 0 out of band; Control 2 kept as a join check |
| G1 | the above-band stop is vacuous, since the prefilter reads only the lower side | upper arm added (`coarse < need_high + M`) |
| G2 | coarse NA handling | separate sum/count tables; no valid coarse cell means the frame is read |
| G3 | no MRDEM version key | ETag printed; caches keyed on it |
| G4 | `r <= 0` silently dropped | counted in the population CSV (amendment A3) |
| G5 | tests: `height_rolls.R:320` pins 2 terrain rows; `:222` excl tails; `:210-215` IR-only terrain | added to Phase 6 |
| G6 | the `nu_row` mutation is not observable | target the scale veto instead, or record it as not observable |
| G7 | docs: NEWS.md:14, terrain-correction.md:619, fly_footprint.R:267,285 | added to Phase 7 |
| A1 | elev differs from `fly_footprint()`'s rotated first pass | recorded; completeness is with respect to MRDEM, axis-aligned |
| A2 | sweep not representative for M | addressed by the self-consistent M |
| A3 | classify on the rounded value | done |
| O2 | the dry-run expectation is wrong for the 12 transcribed rolls | noted |
| S1 | "fit nominal" may be a height recorded above ground, not "fine as catalogued" | reworded as a hypothesis |
