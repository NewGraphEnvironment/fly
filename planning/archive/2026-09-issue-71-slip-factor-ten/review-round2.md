# Code-check round 2 — fly#71 staged diff

Reviewer: subagent, 2026-09-26. Method: enumerated every quantitative / scope claim the diff
adds or changes, then checked each against `flying_height_sweep.csv` (upper_tail, in band after
÷3.28084², band [1/1.6, 1.6]), `flying_height_rolls.csv`, `flying_height_rolls_excluded.csv`,
`flying_height_logbooks.csv`, `data-raw/.cache/upper_tail_verdict.rds` and the cached
catalogue centroids (`data-raw/.cache/centroids/`). No repo file other than this one touched.

## Claim table

| # | claim | location | verdict | evidence |
|---|---|---|---|---|
| 1 | 1,589 slipped frames on 13 rolls, 1974–2005 | roxygen/Rd, vignette | TRUE | sweep: 1,589, 13 rolls, years 1974–2005 |
| 2 | ×10 and ×10.764 both land all 1,589 in band | R comment l.203 | TRUE | 1,589/1,589 in band under ÷10 |
| 3 | x10 and x10.764 are 7.6% apart | R comment, script | TRUE | 10.764/10 = 1.0764 |
| 4 | six rolls before 2003 whose slipped frames a page covers | R comment, notes ("only six, 1978–2000") | TRUE | bc78065, bc78078, bc79027, bc79103, bcb98013 (1998), bcc00085 (2000); bc5596 204–211 uncovered (pages start at 212) |
| 5 | on five of the six "the crew's height is the catalogue's divided by **exactly** 10" | R/fly_footprint.R ~l.205 | FALSE for one | bc79027: 6,500 ft = 1,981.2 m vs 1,999.5 m, −0.9%. Notes correctly say "exactly … on four, and 0.9% off on bc79027" |
| 6 | 19 older frames the table does not reach | R comment | TRUE | bc5596 8 + bc79027 10 + bcb98013 1 |
| 7 | 2003–2005 rolls "carry measured per-frame heights" | R comment, CLAUDE.md, notes, script | FALSE for bcc05001 | bcc05001: 217 frames on 5 heights (106 on one) |
| 8 | "every frame is its own roll-height (463 of them)" | notes | FALSE | 1,271 frames on 463 roll-heights; 148 roll-heights hold one frame, the rest 2–8 (2003) or 25–106 (bcc05001) |
| 9 | "Round feet cannot speak for them" | notes | FALSE for bcc05001 | ÷10 gives 20,505 / 20,997 / 21,004 / 21,506 / 22,005 ft — all within 6 ft of a 500-ft figure; ÷10.764 gives 19,050 / 19,507 / 19,513 / 19,980 / 20,443. Round feet speak, and for ÷10. (2003 rolls: 12% vs 5% within 5 ft of 100 ft, ≈ chance — claim holds there) |
| 10 | ratio fits ÷10.764 better: 2003 1.06–1.11 vs 1.15–1.22; bcc05001 0.98 vs 1.08 | notes | TRUE | per-roll medians 1.060–1.111 / 1.154–1.216; 0.979 / 1.078 |
| 11 | six 2003/2005 rolls = 1,271 frames; + stragglers = 1,290 | notes, CLAUDE.md | TRUE | 232+178+231+179+234+217 = 1,271; +19 |
| 12 | 6 roll-heights, 299 frames tabled at 0.1 | everywhere | TRUE | csv; catalogue reach per key = measured (centroid cache) |
| 13 | 1,300 frames reached by the table | notes | TRUE | 1,001 + 299 |
| 14 | 28 roll-heights | vignette | TRUE | 28 rows |
| 15 | table rows: catalogue/logbook/vs ÷10/vs ÷10.764 | notes table | TRUE | recomputed: bc79027 −0.9% / +6.7%; bcb98013 −25% / −20%; others 0.00% / +7.6% |
| 16 | "÷10.764 is 6.7–7.6% short on each" | notes, CLAUDE.md | FALSE (direction) | logbook is 6.7–7.6% *above* ÷10.764; ÷10.764 is 6.3–7.1% *short* of the logbook (1 − 1/1.0764 = 7.1%) |
| 17 | "#54 drew those frames about 7.6% narrow (15% in area)" | notes; test comments ("7.6% narrow", twice) | FALSE | width ∝ height above ground, so the error is (fh/10.764 − elev)/(logbook_m − elev): per roll-height medians 0.901–0.924, i.e. **7.6–9.9% narrow, 15–19% in area**. 7.6% is the best case (bc78078), not typical; the mocked test's own fixture gives 332.3/361.5 = 8.1% |
| 18 | bcb98013: other 207 frames read 7,924 m | notes | TRUE | centroid cache: 207 at 7,924, 1 at 97,924, frames 1–208 |
| 19 | bcb98013 ÷10.764 = 9,097 m, "about 15% wide in linear size" | notes | FALSE (ASL ratio, not linear size) | 9,097/7,924 = 1.148 is ASL; linear size ∝ AGL: (9,097 − 1,042)/(7,924 − 1,042) = 1.17 → ~17% wide |
| 20 | page headed 15BCB99013, 1999, 24,000 ft | notes | TRUE | logbooks rows 201–203 |
| 21 | bc5596 204–211 at 26,212 m, "exactly ten times" 2,621 m of 141–203 | notes | TRUE (to whole-metre rounding) | centroid cache: 2,621 on 141–203, 26,212 on 204–211 |
| 22 | bc79027 implied overlap 0.82, window 0.557–0.780, page says 80% fwd | notes, CLAUDE.md | TRUE | verdict rds p_corrected 0.819; logbook row 198 note |
| 23 | 6 tabled roll-heights "flown 1978–2000", factor "exactly 10" | roxygen/Rd | TRUE | all within catalogue rounding of ÷10 |
| 24 | "the two corrections … apply to those 1,589 and nothing else: 299 by table, rest by 10.76" | roxygen/Rd | TRUE (current data) | 299 + 1,290 = 1,589 |
| 25 | "Checked before the 10.76 slip above, so a frame on a tabled roll is **never** `corrected_unit_slip`" | roxygen/Rd | FALSE as a code guarantee | `slipped <- disputed & !tabled & in_band(r_repaired)`; a keyed 0.1 frame whose `r_tabled` is > 1.6 while `r_repaired` ≤ 1.6 (a ~7–8% window above the band edge, reachable with a different DEM) is not tabled and IS slipped. Not reached by MRDEM today (max r under ÷10 is 1.18) |
| 26 | named factors of a set are at least 7.6% apart, so 2% cannot reach two | script | TRUE | |
| 27 | "logbook confirms #54" exclusion: no roll did | notes | TRUE | no such reason in excluded csv |

## Code

- `tab_factor != 1` gate, `tab_factor == 1` exact compare against CSV-read 0.1/1: correct.
- `settle()` / verdict / `confirms_54` / reason suffix / `stopifnot` reconciliations: no bug found.
- Test file: reconciliation per tail, pinned ÷10 finding, mocked gate test with premise check — sound.
  The mocked table omits `tail`, which the code never reads; fine.

## Findings

- **[fragile — false prose]** inst/notes/terrain-correction.md (new fly#71 section, the
  2003/2005 bullet) — "They carry measured per-frame heights, so every frame is its own
  roll-height (463 of them). Round feet cannot speak for them." False on both counts: 1,271
  frames sit on 463 roll-heights, and `bcc05001` is 217 frames on **five** heights, which under
  ÷10 are 20,505 / 20,997 / 21,004 / 21,506 / 22,005 ft — round 500-ft planned altitudes,
  i.e. round feet do speak for bcc05001 and favour ÷10, against its ratio (0.98 vs 1.08)
  favouring ÷10.764. The exclusion itself stands (no logbook), but "so leaving them on #54's
  factor is not a default" is overstated for bcc05001. Same "carry measured per-frame heights"
  over all six rolls in CLAUDE.md (fly#71 Key Decision), R/fly_footprint.R comment above
  `fly_height_slip_factor()`, and should be scoped to the 2003 rolls.
- **[fragile — false prose]** inst/notes/terrain-correction.md "so #54 drew those frames about
  7.6% narrow (15% in area)"; tests/testthat/test-fly_footprint_height_rolls.R comments
  "7.6% narrow" (pinned-finding block and the mocked-gate test) — width scales with height
  above ground, so the measured shortfall is 7.6–9.9% linear, 15–19% area, per tabled
  roll-height median; 7.6% is the minimum. The mocked test's own fixture is 8.1%.
- **[fragile — false prose]** inst/notes/terrain-correction.md and CLAUDE.md "÷10.764 is
  6.7–7.6% short on each" — the 6.7–7.6% is the logbook's excess over ÷10.764 (the table's
  own "+7.6%" column); ÷10.764 is 6.3–7.1% short.
- **[fragile — false prose]** inst/notes/terrain-correction.md, bcb98013 bullet — "÷10.764
  gives 9,097 m, about 15% wide in linear size": 15% is the ASL ratio; linear size goes with
  AGL, (9,097 − 1,042)/(7,924 − 1,042) = 1.17, about 17% wide.
- **[fragile — false prose]** R/fly_footprint.R comment above `fly_height_slip_factor()` — "on
  five of the six rolls … the crew's height is the catalogue's divided by exactly 10": one of
  the five, bc79027, is 0.9% off (the notes say so correctly).
- **[fragile — overclaim]** R/fly_footprint.R roxygen (and man/fly_footprint.Rd) "Checked before
  the 10.76 slip above, so a frame on a tabled roll is never `\"corrected_unit_slip\"`" — the
  code does not guarantee it: a keyed factor-0.1 frame with `r_tabled` just above 1.6 and
  `r_repaired` inside the band falls through `!tabled` into `slipped`. Unreachable on the
  shipped data with MRDEM; reachable with another DEM. Either say "on the measured frames" or
  make a keyed-but-out-of-band 0.1 frame not fall to #54.
