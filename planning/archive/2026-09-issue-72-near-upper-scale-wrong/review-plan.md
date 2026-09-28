# Plan review — fly#72 (Plan agent, 2026-09-27)

Verdict: no blocker. `fly_footprint()` already reaches a factor-1 row above the band
(`out_of_band` two-sided; gate `tab_factor == 1 & r_reported > 0`; table before #54's slip).

| # | Finding | Disposition |
|---|---|---|
| G1 | Sibling witness would misfire on near_upper (falls into lower-tail branch, empty `d`) | Fixed: explicit skip, `sibling_reason` states why |
| G2 | Census stopifnot, suffix, key comment, rds saves hard-coded to two sets | Fixed |
| G3 | Doubled "nominal scale" in suffixed reason | Fixed: suffix only where the reason does not already say it |
| G4 | Tests assume two tails in several places | Phase 3 |
| O1 | Fetch already done | Noted |
| O2 | Spacing-split control is circular | Kept as a regression stop on the instrument; the independent check is the logbook lens on the issue's named rolls, reported in findings |
| A1 | Logbook height cannot separate lens from scale (both predict factor 1); spacing window top 0.78 vs lens-roll ~0.80 | Fixed in the rule BEFORE running: near_upper also requires spacing to reject nominal |
| A2 | `scale_as_written` is the only field stating the disputed value | Transcribed on every page; a legible scale equal to the catalogue's vetoes; twice it reported |
| A3 | Lens conflict where spacing fits reported gets a misleading reason | Separate reason |
| A4 | r 1.6-1.9 frames are not the half-scale mechanism | Report r≈2 and 1.6-1.9 separately |
| S1 | Numbers: 252 frames, 53 rolls, 58 roll-heights (all lenses) | Corrected |
| S2 | Unsampled bound misses 505 non-slipped upper_tail census frames and 3 random frames | Stated as a bound in the note |
| S3 | Catalogue reach overstates (most in band, never consulted) | Report as an upper bound |
| AC1 | Zero-accepted outcome | Tests assert the near_upper census reconciles whether or not rows are accepted |
| AC2-4 | Diff CSVs by tail; docs list; restore-the-bug test | Phases 2-4 |
