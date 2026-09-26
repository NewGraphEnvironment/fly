# Code-check round 3 — fly#71 staged diff

Reviewer: subagent, 2026-09-26. Method: enumerated every quantitative / scope claim the diff
adds or changes (including those rewritten since round 2) and checked each against
`flying_height_sweep.csv` (upper_tail, in band after ÷3.28084², band [1/1.6, 1.6]),
`flying_height_rolls.csv`, `flying_height_rolls_excluded.csv`, `data-raw/flying_height_logbooks.csv`,
the cached logbook pages (`data-raw/.cache/logbooks/`) and the cached catalogue centroids.
No repo file other than this one touched.

## Claim table

| # | claim | location | verdict | evidence |
|---|---|---|---|---|
| 1 | 1,589 slipped frames, 13 rolls, 1974–2005 | roxygen/Rd, vignette, test premise | TRUE | sweep: 1,589; 13 rolls; years 1974, 1978, 1979, 1998, 2000, 2003, 2005 |
| 2 | ×10 and ×10.764 are 7.6% apart, both land all 1,589 in band | R ~l.203, script | TRUE | 10.764/10 = 1.0764; round 2 #2 |
| 3 | "on five of the six rolls before 2003 whose slipped frames a page covers ... ÷10, to 0.9% (the sixth is a one-frame typo no factor fits)" | R ~l.205 | TRUE | covered: bc78065, bc78078, bc79027, bc79103, bcc00085 (÷10 within 0.92%), bcb98013 (frame 52: −25% / −20%) |
| 4 | roll-heights that also pass spacing are in the roll table, consulted first | R ~l.207 | TRUE | 6 upper rows; `tabled` computed before `slipped <- disputed & !tabled` |
| 5 | what reaches 10.764 is the 2003–2005 rolls (no logbook) + 19 older frames | R ~l.209 | TRUE | excluded upper: 1,271 (bcc03004/06/07/08/46, bcc05001) + bc5596 8 + bc79027 10 + bcb98013 1 = 1,290. "No logbook": no page cached for any bcc03*/bcc05001 roll although the fetch covered upper-tail rolls (bcc00085 and bcb98013 pages were fetched); consistent, not independently queried |
| 6 | 2003 rolls "carry measured per-frame heights and fit 10.764 better"; bcc05001 undecided | R, CLAUDE.md | TRUE | 1,054 frames on 458 roll-heights (148 single-frame, max 8); ratio medians 1.06–1.11 vs 1.15–1.22 (round 2 #10) |
| 7 | factor 0.1 "where the height is ten times too LARGE ... rolls flown before 2003" | R ~l.252 | TRUE | tabled rolls 1978, 1978, 1979, 2000 |
| 8 | every #54-slipped roll-height not reached is in `_excluded.csv` | R ~l.258 | TRUE | test reconciles set keys; 1,589 = 299 + 1,290 |
| 9 | six roll-heights flown 1978–2000, factor "exactly 10" | roxygen/Rd | TRUE | 1350 ft = 411.48 vs 411.5; 3100 = 944.88 vs 944.9; 7200 = 2194.56 vs 2194.6; 18000/18500/19000 ft vs 5486.0/5639.0/5791.0 — all ≤0.01% |
| 10 | "Checked before the 10.76 slip above" | roxygen/Rd | TRUE | code order (round-2 "never" overclaim removed) |
| 11 | 299 by roll table, rest by 10.76 | roxygen/Rd, R ~l.1111 | TRUE | all 299 sweep frames land in band under the logbook height (r 0.894–1.180), so every one is `tabled` |
| 12 | "the 1978-2000 rolls #54 divides by 10.764, whose logbooks read ten times less" | R ~l.1146 | TRUE | |
| 13 | CLAUDE.md headline: "#54's slipped frames are ÷10 **wherever a logbook reaches them**, and ÷10.764 stays for the rest" | CLAUDE.md fly#71 Key Decision | FALSE | a logbook reaches bcb98013 frame 52 (page rows 1–123 at 24,000 ft) and it is not ÷10 (−25%); bc79027's logbook reaches it and reads ÷10 yet it stays on ÷10.764. The body qualifies both; the bolded headline does not |
| 14 | "÷10 on every slipped roll a page covers bar a one-frame typo (bc78065, bc78078, bc79027, bc79103, bcc00085)" | CLAUDE.md | TRUE | as #3 |
| 15 | "6.7–7.6% above ÷10.764 on each" | CLAUDE.md, notes | TRUE | bc79027 +6.65%, others +7.64–7.65% |
| 16 | 6 roll-heights (299 frames), factor 0.1, cause `height_decimal_dropped`, `tail` column in both tables | CLAUDE.md, notes | TRUE | csv: 24+15+24+68+127+41 = 299 |
| 17 | "they and three stragglers (1,290 frames) stay on it, each listed ... with a reason saying so" | CLAUDE.md, notes | TRUE | 3 straggler rolls; all 466 upper excluded rows end "#54's 10.764 still applies"; frames 1,279 + 10 + 1 = 1,290 |
| 18 | gate `!= 1`, `> 1` handed 0.1 rows to #54 | CLAUDE.md, R, test | TRUE | code l.1181 |
| 19 | bc79027 reads ÷10, spacing rejects, page logs 80% vs ~60% window; overlap 0.82, window 0.557–0.780 | CLAUDE.md, notes | TRUE | round 2 #22; excluded reason "spacing rejects..." 10 frames |
| 20 | bcb98013 frame 52 leading-digit typo no factor recovers | CLAUDE.md, notes | TRUE | 97,924 vs 207 frames at 7,924; logbook 24,000 ft fits neither within 2% |
| 21 | notes: 1,001 → 1,300 frames reached | notes l.329 | TRUE | 1,001 + 299 |
| 22 | "Logbook pages cover the slipped frames of only six, flown 1978-2000" | notes | TRUE | bc5596's page (bc5596_5597_3) starts at 212, slipped are 204–211; no pages for 2003/2005 rolls |
| 23 | notes table rows (catalogue m, logbook ft, vs ÷10, vs ÷10.764) | notes | TRUE | recomputed: 0.00/+7.6 ×3 rolls, bc79027 −0.9/+6.7, bcc00085 ≤0.01/+7.6, bcb98013 −25/−20; bc79027 catalogue 19,995 (frames 205–214) |
| 24 | "exactly ... on four, and 0.9% off on bc79027" | notes | TRUE | |
| 25 | tabled roll-heights drawn 7.6–9.9% narrow (median per roll-height), 15–19% in area | notes, test comment | TRUE | width ratio (fh/K − elev)/(h_log − elev) medians 0.901–0.924; squared 0.812–0.853 (14.7–18.8%) |
| 26 | "bc78065 produced the hypothesis, so the four other rolls are the independent confirmation" | notes | TRUE | four = bc78078, bc79027, bc79103, bcc00085 |
| 27 | "No roll did" (confirm 10.764) | notes | TRUE | no such reason in excluded csv |
| 28 | six 2003/2005 rolls = bcc03004/06/07/08/46 + bcc05001, 1,271 frames | notes | TRUE | sweep |
| 29 | five 2003 rolls: 1,054 frames on 458 roll-heights | notes | TRUE | recomputed 1,054 / 458 |
| 30 | bcc05001 217 frames, 5 heights, within 6 ft of round 500 ft under ÷10 (20,505–22,005); ratio 0.98 vs 1.08 | notes | TRUE | round 2 #9/#10; 5 excluded rows, 217 frames |
| 31 | bc5596 204–211: 26,212 m "exactly ten times" 2,621 m of 141–203 | notes | TRUE to whole-metre rounding | centroid cache: 2,621 on 141–203, 26,212 on 204–211; 10.0008×, both roundings of 8,600 / 86,000 ft |
| 32 | bcb98013 ÷10.764 = 9,097 m, ~17% wide linear | notes | TRUE | (9,097 − 1,042)/(7,924 − 1,042) = 1.17 |
| 33 | page headed 15BCB99013, 1999, 24,000 ft | notes | TRUE | logbooks csv note "flight B-010-E-99, date 1999-AUG-02" |
| 34 | vignette "On 28 roll-heights" | vignette | TRUE | 22 + 6 rows |
| 35 | test: "within 1% of ÷10, over 6% above ÷10.764" on every tabled slipped roll-height | test | TRUE | max 0.01% / min 7.64% |
| 36 | test mock: bc78065 4,115 m vs 1,350 ft; fixture 8.1% narrow within 7.6–9.9% | test | TRUE | 332.3/361.5 = 0.919 |
| 37 | script: named factors ≥7.6% apart so 2% cannot reach two | script | TRUE | |
| 38 | script: 2003 rolls cannot speak on round feet | script | TRUE | round 2 #9 (≈ chance for 2003) |
| 39 | script: "among slipped frames ... condition 3 is a sanity check and the logbook alone decides the factor" | script | TRUE (characterisation) | the factor is the logbook's; condition 3 still gates (it excluded bc79027), which "sanity check" does not deny |

## Code

- Gate `tab_factor != 1 & in_band(r_tabled)`: correct; 0.1 read from CSV as double, `== 1` exact
  compare only against 1. All 299 sweep frames pass `in_band(r_tabled)`.
- `tabled` precedes `slipped`; `fh_used[tabled]` ≤ 5,791 m so the 16,000 m ceiling cannot refuse
  a tabled bcc00085 frame even though its catalogued 54,860 m exceeds it (film frames are seeded
  from scale, so `over_ceiling` seeding exclusion does not starve `first$elev`).
- Script: `settle()`, index-based factor match, `confirms_54`, reason suffix (NA-safe via
  `!v$accept`), reconciliation `stopifnot`s, cross-tail key uniqueness — no bug found.
- Test: per-tail reconciliation and mocked gate test sound; mocked table omits `tail`, which the
  code never reads.

## Findings

- **[low — false prose]** CLAUDE.md, fly#71 Key Decision headline — "#54's slipped frames are ÷10
  **wherever a logbook reaches them**, and ÷10.764 stays for the rest". A logbook reaches
  `bcb98013` frame 52 (page rows 1–123, 24,000 ft) and it is not ÷10 (−25%); and `bc79027`'s
  logbook reaches it and reads ÷10, yet it stays on ÷10.764 because spacing rejects it. The body
  of the same bullet qualifies both ("bar a one-frame typo", "bc79027 reads ÷10 but spacing
  rejects it"), but the bolded headline is the set-level summary a reader takes away, and it is
  the same shape round 1 flagged ("every roll a page covers is /10"). Suggest e.g. "#54's
  slipped frames are ÷10 wherever a logbook reads them, and are tabled where spacing agrees;
  ÷10.764 stays for the rest".

Everything else in the claim table checks out against the data; no code bugs found.
