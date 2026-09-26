## Outcome

fly#54 divides `FLYING_HEIGHT` by 3.28084² on 1,589 slipped film frames. The logbook pages
covering those frames were read blind (a subagent saw only the images and the column spec). On
every roll a page reaches, bar a one-frame typo, the crew's height is the catalogue's divided by
10, and ÷10.764 is short on each. Six roll-heights (299 frames, 1978–2000) now ride
`flying_height_rolls.csv` at factor 0.1 (`height_decimal_dropped`). Both roll tables gain a
`tail` column. The 1,290 slipped frames the table does not reach are listed in
`_excluded.csv` with a reason saying #54's 10.764 still applies. `fly_height_slip_factor()` is
unchanged: the 2003 rolls have no logbook and fit 10.764 better.

The code fix was one comparison: the roll-table gate read `tab_factor > 1`, which silently
handed a 0.1 row back to #54's repair. It now reads `!= 1`, and a mocked test goes red under
the old form. Every `/code-check` finding across three rounds was false prose, not code. Each was
a set-level claim ("pre-2000", "every page reads /10", "exactly", "7.6% narrow") that had never
been checked member by member, and one fix created a new instance. Only enumerating every claim
against the CSVs (27, then 39) ended the loop. The two round-2 findings with the most weight:
width follows height above ground, not above sea level, so ASL ratios understate the error; and
`bcc05001` lands on round 500 ft under ÷10, which makes that roll undecided rather than a clear
÷10.764 case.

## Measurement

| roll | catalogue m | logbook ft | vs ÷10 | logbook above ÷10.764 |
|---|---|---|---|---|
| bc78065 (control) | 4,115 | 1,350 | 0.00% | +7.6% |
| bc78078 | 9,449 | 3,100 | 0.00% | +7.6% |
| bc79027 | 19,995 | 6,500 | −0.9% | +6.7% |
| bc79103 | 21,946 | 7,200 | 0.00% | +7.6% |
| bcc00085 ×3 | 54,860–57,910 | 18,000–19,000 | ≤0.01% | +7.6% |
| bcb98013 f52 | 97,924 | 24,000 | −25% | — (leading-digit typo) |

- Width shortfall under #54 on the tabled roll-heights: 7.6–9.9% (median per roll-height),
  15–19% in area.
- Tabled: 6 roll-heights, 299 frames, reaching exactly 299 in the catalogue.
- Left on #54: 1,290 frames. That is 1,271 on the 2003/2005 rolls, which have no logbook link;
  8 on bc5596, which has no page; 10 on bc79027, where spacing reads 0.82 overlap and the page
  logs "80% fwd overlap"; and 1 on bcb98013.
- The lower-tail rows of both tables are identical to main on every original column.
- Wrong turn kept: the plan named the cause `height_decimal_added`. The issue's own wording
  ("a dropped decimal point") gave `height_decimal_dropped`.

## Evidence

`data-raw/flying_height_logbooks.csv` (rows for `bc78078`, `bc79027`, `bc79103`, `bcb98013` and
`bcc00085`). `data-raw/height_calibrate-lower_tail_rolls.R` reproduces every figure. The
per-claim verification tables are `review-round2.md` and `review-round3.md` in this directory.
The narrative is the fly#71 section of `inst/notes/terrain-correction.md`. Follow-up:
fly#74 (bcb98013 f52, bc5596).

Closed by: PR for #71 (branch `71-pre-2000-slip-factor`)
