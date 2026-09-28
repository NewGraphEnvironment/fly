## Outcome

fly#54 had called the film mass at r ≈ 2 a 305 mm lens catalogued as 153, and so treated its
nominal-scale fallback as correct. fly#60's spacing split that mass in half, and this issue
settled it per roll-height. 144 logbook pages were fetched for the 53 rolls beyond the band in
the sweep's `near_upper` sample, and three blind readers transcribed them, one control sheet
each; all three controls read back as catalogued. The generator then ran fly#60's two
witnesses under a new `tail = "near_upper"`. The main lesson came from the plan review: **the
logbook height cannot tell the two defects apart**, because a wrong lens and a wrong scale both
mean the crew flew the catalogued height. So for this tail, spacing must *reject* nominal
scale, not just fit the reported height. That rule was fixed before the run. Code-check took
three rounds. Every finding was the same mechanism: a claim written from a mental picture of
the data, not recomputed from it. The loop ended when round 3 enumerated all 43 claims in the
new prose.

## Measurement

- 252 sampled frames beyond the band, on 53 rolls and 58 roll-heights. The spacing split
  reproduces the issue's 90 / 105 / 14.
- **24 roll-heights (120 frames) tabled at factor 1, `scale_wrong`**: 20 at 153 mm, mostly on
  1972–76 rolls, and 4 at 305 mm. Their keys reach at most 3,227 catalogue frames. These frames
  were drawn at 1/r of their width, and are now drawn from their height.
- **21 roll-heights (82 frames) have a logbook that writes a 12" lens.** That confirms the lens
  reading, with a witness spacing never saw, and those frames stay on nominal scale.
- Wrong turns, kept:
  - I claimed the reach was out of band "whatever the terrain". It is not: terrain lowers r,
    and 12 of the 132 sampled frames are in band.
  - The note said bc80048's spacing "supports nominal". It fits neither reading.
  - bc7223 first shipped as "no page", when its page covers it with a height that changes
    along the strip.
  - The scale parser read remark scales, then swallowed trailing digits.
- Bound: this was a sample, not a census. 1,534 frames on nine 1985 rolls at 6,096 m, 305 mm,
  1:10000 fall just under the stratum floor (1.999 against 2.025) and are unmeasured.

## Evidence

`data-raw/height_calibrate-lower_tail_rolls.R` (set `near_upper`);
`data-raw/flying_height_logbooks.csv` (rows after line 215); the note section
"The r ≈ 2 mass is two defects" in `inst/notes/terrain-correction.md`; the plan review and the
code-check rounds are `review-*.md` in this directory.

Closed by: PR (fly#72)
