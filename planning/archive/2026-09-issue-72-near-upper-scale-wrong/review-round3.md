# Code-check round 3 — fly#72 (branch 72-near-upper-scale-wrong)

Scope: staged diff, read against the shipped CSVs, `inst/extdata/flying_height_sweep.csv`,
`data-raw/.cache/near_upper_verdict.rds`, the centroid cache and `data-raw/flying_height_logbooks.csv`.
The generator was re-run in a `cp -R` copy: exit 0, and both `inst/extdata` tables came out
byte-identical to the staged ones. The overlap window is 0.557 to 0.780, and the 90 / 105 / 14 guard
passes. `test-fly_footprint_height_rolls.R` passes in the copy (`NOT_CRAN=true`, load_all:
PASS 391, FAIL 0). `devtools::document()` in the copy leaves `man/` unchanged.

## Mechanism

Each earlier finding was a claim written from the author's model of the data, or from a
snapshot of it, and not re-derived from the shipped artifact:

- in its final state (after a later fix moved the data), or
- for the cases the author did not look at directly. The claim held for the instances that
  were examined and was extended to the ones that were not.

The earlier instances were: terrain's direction (reasoned), the regex's behaviour (asserted in
a comment, never run), bc5509's lens and bc80048's spacing (a category's property attributed to
a member), and bc7223's "no page" (the transcription's shape read as the page's content).

This round, the same mechanism reaches:

1. NEWS counts that the round-2 fix made stale.
2. A NEWS count that counts one sheet pair twice.
3. A note bound that characterises only the one frame the author looked at.

## Findings

- **[severity: bug]** NEWS.md:5 — "`data-raw/flying_height_logbooks.csv` gains **183** rows from
  **144** newly read pages on **53** rolls, **transcribed blind**." Recomputed against the staged
  CSV (`git diff --cached`: 0 removed lines, only additions):
  - **185** rows are added, not 183. The round-2 fix for bc7223 added the two interior rows
    (bc7223 54-107, bc78009 84-99) after this line was written, and nobody re-derived it.
  - Those two rows' own `note` says "added at merge (fly#72 code-check)". The same goes for the
    18 whole-feet rows (1984-86 sheets), which say "interpreted as whole feet ... (fly#72
    merge)". So "transcribed blind" is no longer true of all the added rows. The readers left
    those 18 heights blank, and the merge filled them. The three tabled 305 mm rows (bc85079,
    bc85080, bc85081) rest on exactly those merge-filled heights.
  - The CSV has **142** distinct new page files. 144 is the fetch count, and it includes one
    sheet pair (`bc5701_5702_1/2`) cached under both `bc5701` and `bc5702`. findings.md:68
    says the duplicates were dropped, so 144 counts two images twice.
  - The new rows cover **52** of the 53 near_upper rolls. bc7692's pages were already in the
    CSV from fly#60. Counted by `film_roll` label they cover 54, because `bc5664` and `bc7408`
    ride on neighbours' sheets. No count gives 53.

  This is a shipped changelog stating wrong numbers about a shipped input. Suggested wording:
  "gains 185 rows from 142 newly read pages on 52 rolls (54 roll labels). 165 were transcribed
  blind; 18 whole-feet heights were interpreted at merge, and 2 interior strip rows with no
  written height were added at merge." Re-derive the numbers from the CSV rather than using
  these.

- **[severity: bug]** inst/notes/terrain-correction.md, section "The r ≈ 2 mass…", **Bound**
  paragraph — "3 random-set frames beyond the band (one, `bc5703` at 1:6000 and 153 mm, r 1.99,
  looks like this class)." The three frames are bc5703 (153 mm, 1:6000, 1829 m, r 1.99),
  **bc85083** (305 mm, 1:10000, 6096 m, r 1.73) and **bc85090** (305 mm, 1:10000, 6096 m, r 1.63).
  The two it leaves out look *more* like the tabled class than bc5703 does:
  - They are 1985, 305 mm, 1:10000, Monkman-area rolls numbered next to the three 305 mm rows
    this diff tables (bc85079, bc85080, bc85081 at 6401 m).
  - They sit at 20,000 ft, and the logbook already in this diff writes 20,000 ft for bc85080
    85-145 and bc85081 81-97, on the same camera and scale.

  They were never sampled because their r above sea level is 6096 / 3050 = **1.999**, just
  under the stratum's floor of 2.025. The whole 20,000 ft / 305 mm / 1:10000 family in 1985
  falls in that gap:

  | roll | frames |
  |---|---|
  | bc85080 | 61 |
  | bc85081 | 17 |
  | bc85082 | 180 |
  | bc85083 | 251 |
  | bc85089 | 255 |
  | bc85090 | 252 |
  | bc85091 | 223 |
  | **total** | **1,239** |

  So the sentence names one frame as the unmeasured instance of the class and implies the other
  two are not instances. That understates the unmeasured reach, in the paragraph a reader uses to
  judge what the table does not cover. The generic "roll-heights no sampled frame sits on" covers
  these frames, but the named example points away from the largest concentration. Suggested fix:
  say all three look like the class. Name the 1985 305 mm 1:10000 rolls at 20,000 ft, which sit
  at r above sea level 1.999, below the stratum, with a logbook page already read for two of
  them.

No other defects. The R gate, the generator rule and the test assertions are clean, and so is
every other prose claim (table below).

## Enumeration: every claim in the diff's new prose, recomputed

| # | Claim | Where | Result |
|---|---|---|---|
| 1 | 209 sampled beyond r 1.8 at 153 mm: 90 nominal / 105 reported / 14 neither | note §fly#72; generator guard | verified: generator prints 90/105/14; "neither" = bc80048 (9), bc7454 (3), bc77013 (2), none of them both-fit |
| 2 | Nominal implies ~20% on the 105 | note §fly#72 | verified: median roll p_nominal 0.22 |
| 3 | Generator stops unless it reproduces 90/105/14 | note; generator | verified (code) |
| 4 | 252 frames, 53 rolls, 58 roll-heights, all lenses | note; NEWS; CLAUDE | verified: 224 at 153 mm, 25 at 305 mm, 3 at 88 mm |
| 5 | Readers had images only, one control sheet each, all three read back as catalogued | note | not verifiable from shipped artifacts: new rows carry no `control=TRUE`, and the evidence is only in findings.md |
| 6 | `focal_mm` filled only where a focal length is written | note; NEWS; CLAUDE | verified: 0 of the new rows have `focal_mm` without a focal length in `focal_as_written`, and 22 with only a camera id are blank |
| 7 | Logbook height cannot separate the readings; factor 1 agrees on both | note; CLAUDE; NEWS; generator | verified: all 21 lens rows have factor 1 and n_agree = n |
| 8 | Lens roll's reported height implies ~0.80 overlap; window top 0.78 | note; generator comment | verified: lens-row p_corrected 0.779–0.838; window top 0.7797 |
| 9 | No sampled page writes a scale, so the veto never fired | note | verified: n_scale_read = 0 on all 58; `scale_as_written` empty on every new row |
| 10 | Outcome table 24/120, 21/82, 7/31, 1/2, 3/8, 1/5, 1/4 | note | verified against excluded.csv (sum 58/252) |
| 11 | 20 × 153 mm (107 frames), 4 × 305 mm (13 frames) | note | verified |
| 12 | Sixteen 1972–76 bc54xx–bc57xx, plus bc5138, bc78110, bc79039, bc79141 | note | verified: photo_year 1972–76 on all 16 |
| 13 | "mostly 1972–76 rolls" | NEWS | verified: 17 of 24, bc7692 (1974) included |
| 14 | Three 305 mm rows at r 1.65–1.69 | note | verified: 1.651 / 1.686 / 1.680 (bc85080 1.815) |
| 15 | Keys reach 3,227 catalogue frames | note; NEWS; CLAUDE | verified by the same `key4` count over 1,670,471 cached frames |
| 16 | Terrain lowers r; table consulted only outside the band | note; CLAUDE; NEWS | verified: `r_reported = (fh - elev) / nominal_agl`; `hit[!out_of_band] <- NA` |
| 17 | Threshold ground 287–2,636 m depending on roll | note | verified: 287.4 (bc79039) to 2,636.2 (bc5508/09/10) |
| 18 | 120 of 132 sampled frames on tabled keys beyond the band; 12 inside, all bc85079/80/81 | note | verified: 5 / 3 / 4 |
| 19 | In-band frames already sized from the same height, so nothing changes | note; NEWS | verified: height_m differs from the catalogue by at most 0.5 m |
| 20 | Fallback drew them at 1/r, half at r = 2 | note; NEWS | verified: disputed, not slipped (r / 10.764 < 0.625), hence implausible and nominal |
| 21 | bc78051, bc79072, bc80122 among the 82 lens frames | note | verified |
| 22 | bc80048: logbook writes 6"; 0.79 nominal, 0.89 reported, both above 0.78 | note | verified in substance: page reads "21162 f 153 mm"; 0.789 / 0.890 > 0.7797 |
| 23 | bc79043: 12" written; spacing fits reported; excluded as disagreeing | note | verified: "f 305 mm"; p_corrected 0.772 inside, p_nominal 0.507 below 0.557 |
| 24 | near_upper = 600-frame sample of 2 < r above sea level ≤ 3 | note; R comment; generator comment; NEWS | verified: 600 rows, r above sea level 2.025–2.999 |
| 25 | 505 upper_tail census frames #54 does not repair | note | verified: 2,094 − 1,589 |
| 26 | 3 random frames beyond the band; one, bc5703, looks like this class | note | **false**: see finding 2 |
| 27 | 223 beyond r 1.8, 209 at 153 mm | note, r = 2 bullet | verified |
| 28 | "about half of it" is the wrong lens | note bullet; CLAUDE #54 sentence; R comment; generator comment | verified as approximate: 90 vs 105 in the split; 82 vs 120 by logbook |
| 29 | "the roll table now corrects" the wrong-scale half | note bullet | overstated scope (corrects only sampled keys); bounded in the section below it, not flagged |
| 30 | Logbooks write a 12" lens on 21 sampled roll-heights | R comment; CLAUDE | verified: all 21 are logbook 305 against catalogue 153 |
| 31 | Factor-1 rows correct a scale, not a height, so are not among the 308 | roxygen / Rd | verified: 308 is the upper-tail reach and near_upper is separate |
| 32 | Factor 1 is the only factor named for near_upper | R comment; generator | verified: `named = 1`; tabled factors {1}; witness all "logbook" |
| 33 | Every sampled near_upper roll-height left on nominal is listed with its reason | R comment | verified: 34 excluded, all carrying "nominal scale" |
| 34 | A near_upper key (2 < r ≤ 3) cannot be a slipped one (> 3) | generator comment | verified: upper_tail r above sea level min 3.054; stopifnot passes |
| 35 | Scale regex: no digit may follow; "1:15,000 123" and "1:15840 12 frames" read as no scale | generator comment | verified by tracing the lookahead: both give NA |
| 36 | Roll with no cached page is refetched; costs one request | generator comment | verified: re-run logged "7 rolls: 0 fetched or cached, 0 failed" |
| 37 | 183 rows / 144 pages / 53 rolls / transcribed blind | NEWS | **false**: see finding 1 |
| 38 | bc5509 logbook 21,500 ft (6,553.2 m); camera line names no focal | test comment | verified: "RC8 355", focal blank |
| 39 | bc78051's logbook writes a 12" lens | test comment | verified in substance: "110398 f 305" |
| 40 | Drawn about 2.6 times what the fallback drew | test comment | verified: (6553.2 − 300) / 2448 = 2.55 |
| 41 | Rounding cases bc5648, bc79039 need ±0.001 | test comment | accepted per brief; the test passes |
| 42 | A scale-wrong near_upper row stays above the band | test | verified: r_corrected min 1.651 |
| 43 | bc7223 START 4.1 / END 3.2; bc78009 83 ditto 2.60 / 100 2.70 | logbook CSV notes | consistent with the round-2 read of the image; the rows land as uninterpreted (bc7223 log_state all "uninterpreted") |
