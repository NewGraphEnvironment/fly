# Review round 1 — fly#60 lower-tail roll calibration

Method: read the diff, the script, both shipped CSVs, the logbook transcription and
findings.md; ran the script in a copy (`scratchpad/flycopy`) — rc 0, both shipped CSVs
reproduce byte-identical (`cmp`). Then probed the cached verdict/frames objects for the
failure modes below. Re-derived every count in findings.md Phase 2 (cause table, excluded
reasons 36/8/4/4/3, 1,001 + 961 = 1,962, reach 1,025): all match the artifacts.

Checked and found fine (no action): no duplicate airp_id or (roll, frame) key in the cache
(so the merges cannot inflate rows); no NA `elev` in the sweep (so the `s$r > 1.8` subset at
line 116 cannot emit all-NA rows); no verdict group mixes focal_length or scale_n today; the
two clean logbook controls read back 3,856 / 4,267 / 6,096 m exactly; no logbook ratio sits
near 10.764 (unnamed ratios are 0.715, 0.926, 3.251, 1.051), so excluding 10.764 from
`named` refuses nothing the logbook actually says; every accepted factor-1 row has nominal
overlap outside the window (worst bc5697 0.816 vs 0.780), so "scale_wrong" is discriminated
by spacing, not just asserted.

## Findings

- **[severity: bug]** data-raw/height_calibrate-lower_tail_rolls.R:260-265, 328-336 /
  inst/extdata/flying_height_rolls.csv row bc7280 — the shipped correction is an exact
  named factor, but the catalogue value it multiplies is truncated. bc7280: catalogue 60 m,
  logbook 20,000 ft = 6,096 m, ratio 101.6 (accepted as 100 inside the 2% tolerance), so
  `flying_height x factor` = 6,000 m — 96 m / 1.6% low, and `r_corrected` (1.053) is
  computed on the low value. A consumer applying `factor` sizes all 101 frames ~2% narrow
  over ~5 km of AGL — larger than the 0.5-1% errors this repo treats as material elsewhere.
  The x10 rows are fine (worst bc7584: 6,090 vs 6,096 m, 0.1%). Either ship the corrected
  height as `logbook_ft * 0.3048` (the table already carries `logbook_ft`), or state in the
  table/note which of the two the runtime must use; as shipped, `factor` is the column whose
  name invites use and it is the wrong one for x100.

- **[severity: fragile]** data-raw/height_calibrate-lower_tail_rolls.R:282, 313 —
  `focal_conflict` is `nzchar(focal_logbook) & n_focal_agrees < n_logbook`, and
  `focal_agrees` is FALSE for a covered frame whose logbook focal is illegible (NA) or
  ambiguous (two focal values → NA at line 255). So a roll-height where some covered frames
  carry a matching legible focal and others are illegible is excluded as "logbook names a
  different lens" — contradicting the rule text at lines 302-303 ("no legible logbook focal
  length contradicts"). No current row is in that state (every covered roll-height is either
  all-legible or all-illegible — bc7280, bc5449, bc7675, bc5628, bc79067 are all-NA), so the
  shipped tables are unaffected; it misfires on the next transcription that is partly
  legible. Count contradictions as `sum(is.finite(log_focal) & !focal_agrees)`.

- **[severity: fragile]** data-raw/height_calibrate-lower_tail_rolls.R:270, 276, 333 —
  the verdict groups on (film_roll, flying_height) but the shipped key is four fields, filled
  from `d$focal_length[1]` / `d$scale_n[1]`. If a roll-height ever mixes focal or scale (Stage
  3 anticipates it — it pastes "a/b" at lines 152-153), the shipped key covers only the first
  frame's subset while `frames_measured`, `p_corrected` and `r_corrected` describe all of
  them. No group mixes today; nothing asserts it. Split on all four fields, or
  `stopifnot(length(unique(d$focal_length)) == 1, length(unique(d$scale_n)) == 1)`.
  Related: the "reach" check at lines 357-360 keys on two fields, not the shipped four, so
  it reports 1,025 where the shipped key reaches 1,001 (the 24 are bc5655 frames at 1:7200,
  excluded by scale_n=75062). findings.md explains the 24 by "the runtime (disputed frames
  only) does not touch them"; the actual reason they are untouched is the scale_n in the key.

- **[severity: fragile]** data-raw/height_calibrate-lower_tail_rolls.R:315, 323 — a
  roll-height whose agreeing frames have no adjacent-frame base gets `p_corrected` NA →
  `spacing_ok` FALSE → reason "spacing rejects the logbook's height", when spacing measured
  nothing. Not triggered now (every agreeing group has n_base > 0), but the shipped
  `reason` column would then state a measurement that was not made.

## Clean otherwise

No security issues. `fetch_logbooks()` (lines 194-217) caches a partial file from a
transport failure as a 200 and never retries once `LOG_DIR` exists, and it fetches only the
lower-tail rolls (not the control rolls bcc228/bc7349/bc78065), but its output feeds nothing
downstream — the transcription CSV is the input — so no number depends on it.
