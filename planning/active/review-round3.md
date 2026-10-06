# Code-check round 3 — fly#91 staged diff

## The mechanism

All three earlier findings come from one shared assumption. Prose about the roll table
describes what it contains: its tails, its strata, where its rows came from, its counts.
Each sentence was true when written, while every row came from the BW/colour sweep through
three tails. fly#91 added two things that change what those sentences mean:

- a fourth tail, `terrain`;
- a second source set, the IR census, holding frames on both sides of the band.

Each sentence was then checked against the copy being edited, not against the others.

The sub-pattern this round adds is vocabulary. Three words carry a meaning that the new rows
broke:

- **"stratum" vs "tail".** The sweep's `random` set is a stratum and is not a tail.
- **"beyond the band".** Elsewhere in the repo, including the new section's own heading, this
  means r > 1.6.
- **"the table ... measured from the sweep".**

## Findings

- **[severity: fragile — published claim]** `inst/notes/terrain-correction.md:579-581`. The
  note says: "No other stratum holds such a frame, since every other tail is outside the band
  above sea level." That is false as written, and the same section disproves it.
  - Its own Bound paragraph (`:610-612`) says 12 of the sweep's 2,500 `random` draws are
    exactly such frames: in band above sea level, out of it only through the ground.
  - `random` is a stratum of the sweep. The generator's run log prints those 12 from
    `s$set == "random"`: "12 of 2500 (12 below, 0 above)".
  - What is true is the clause after "since": no **tail** holds such a frame.
  - The same wrong claim appears in:
    - `data-raw/height_calibrate-lower_tail_rolls.R:216`, "which no other stratum holds". The
      same script counts them from the random stratum 30 lines later, at `:141-146` of the
      diff hunk.
    - `CLAUDE.md:362`, "which no stratum held". This one is ambiguous: it is true only if
      "which" means the two IR rolls rather than the condition.
  - `data-raw:21`, "which no stratum above holds", is defensible: the header above it names
    only the lower, upper and near_upper sets.
  - **Fix:** change "stratum" to "tail" (or "no rule-bearing set") in the note and at
    `data-raw:216`.

- **[severity: fragile — test comment false]**
  `tests/testthat/test-fly_footprint_height_rolls.R:193-195`. The comment says: "Three sets,
  one per tail: fly#60's lower tail, fly#71's ... and fly#72's near_upper frames". The block
  it heads now builds **four** sets, `lower`, `upper`, `near_upper` (BW/colour plus IR
  `bci9`) and `terrain`, at `:214-215`, and loops over all four. The fly#91 comment at
  `:203-205` describes the IR addition, but the opening count was never updated. This is the
  same shape as R2's finding (a count restated in one place, corrected in another).

- **[severity: fragile — published claim]** `inst/notes/camera-formats.md:356-357`. The note
  says: "`bc5312` (0.731) and `bci12` (0.762) leave the band only through terrain, which
  neither rule reaches." This is present tense, and the next bullet (`:358-364`) says they
  were tabled.
  - `terrain-correction.md:583` says both sets "ran under #72's `near_upper` rule,
    unchanged". So #72's rule does now reach them, through the `terrain` set.
  - CLAUDE.md's copy of this sentence was rewritten in this diff, from "Only `bci9` falls in
    a population the #60/#72 rules read" to "which no stratum held". The camera-formats copy
    was not.
  - What stays true is that neither rule's **stratum** (ratio above sea level ≤ 0.5, or 2 to
    3) held them. The test comment at `test-fly_footprint_infrared.R:112-114` says it that
    way and is correct.

- **[severity: fragile — published claim, vocabulary]** These places say "beyond the band"
  for the whole IR census:
  - `R/fly_footprint.R:285`, "the infrared rows (fly#91) from a census of every IR frame
    beyond the band";
  - `data-raw/height_calibrate-lower_tail_rolls.R:297-298`, "the near_upper frames beyond
    the band (fly#72) and the infrared census beyond it";
  - `data-raw:250`, the message "infrared census beyond the band: 56 frames", which is printed
    into `run_rolls.log:348`;
  - `test-fly_footprint_height_rolls.R:203`, "the infrared census beyond the band".

  Across the repo, "beyond the band" means r > band[2]. Two examples: "near_upper frames
  beyond the band" (`near <- ... s$r > band[2]`), and the new section's own heading, "one
  beyond the band, two out of it only through terrain". The 31 `terrain` frames are
  **below** the band. Read in the repo's own vocabulary, the `fly_footprint()` comment says
  the IR census covers `bci9` only, and leaves the two `terrain` rows with no stated source.
  `data-raw:94-97` gets it right ("The IR frames outside the band"). Use "outside".

- **[severity: fragile — test/comment claim, low]**
  `tests/testthat/test-fly_footprint_height_rolls.R:8-9` and the test name at `:186` say the
  suite holds "the table to the sweep it was measured from". The three IR rows were not
  measured from the sweep, which holds no IR frame. They were measured from
  `infrared_film_frames.csv`, and this block now reads that file at `:207`. The test does the
  right thing; the stated provenance is now partly false.

### Pre-existing instances of the same mechanism (not introduced by this diff; fly#91 is the second addition that left them stale)

- `R/fly_footprint.R:280`, "so the table reaches only the frames it was measured on". This
  has been false since #72.
  - Today the `near_upper` keys reach **3,252** catalogue frames against 145 measured. That
    is 3,227 for the BW/colour rows, as `terrain-correction.md:532` itself says, plus
    `bci9`'s 25.
  - The `lower`, `upper` and `terrain` keys do reach exactly their measured frames
    (1,130 / 308 / 31; recomputed from `data-raw/.cache/centroids/`).
  - The same claim is at `data-raw/...lower_tail_rolls.R:781`, whose code asserts only
    `reach >= frames_measured`.
- `inst/notes/terrain-correction.md:328-330`, "which reaches exactly the 1,001 measured
  frames (1,300 since fly#71 ..., and 1,438 since fly#74 ...)". This is a running count that
  stopped at fly#74.
  - After #72 the table measured 1,558 frames. After #91 it measures 1,614 and reaches 4,721
    (`run_rolls.log:929,1261`).
  - "Exactly" has not held since #72.

## Round 2's fixes, re-checked

- `terrain-correction.md:550-551`: "The BW/colour `near_upper` rows come from a 600-frame
  sample ... (The one infrared row, `bci9`, comes from fly#91's IR census.)" Correct: the CSV
  has 25 `near_upper` rows, 24 BW/colour and `bci9`.
- `terrain-correction.md:577`: "settled alongside #72's sample, not drawn into it." Correct.
  The generator's comments still say `bci9` "joins it" (`data-raw:20`), is "joined to its
  sample" (`:214`), and "join[s] #72's sample" (`:476`). These describe the literal
  `rbind(near, ir_near)` and claim nothing about the draw, so I judge them true. They are the
  wording R2 moved the note away from, and the caller may want to harmonise them.
- `R/fly_footprint.R:284-286`: the sample/census split is correct. See the
  "beyond the band" finding above for its last clause.

## Enumeration: every sentence checked

Method: `grep -rn` for near_upper, tail(s), stratum, sample, census, roll-height,
flying_height_rolls, "reaches", "beyond the band" and "measured from" across R/,
inst/notes/, CLAUDE.md, data-raw/height_calibrate-lower_tail_rolls.R, tests/ and man/. Each
hit was then read in context.

| location | claim | verdict |
|---|---|---|
| CLAUDE.md:97-99 | test holds both to the sweep; generator also reads IR census, run format_measure first | true ("It" is ambiguous, but both the test and generator do read it) |
| CLAUDE.md:360-364 | 56 IR frames, three roll-heights, bci9 near_upper, terrain tail under #72's rule, fixed before blind read; BW/colour unmeasured (fly#93); lower is ratio_asl ≤ 0.5 | "which no stratum held" ambiguous/false (finding 1); rest true (fly#93 title confirms; slip script `:167` defines lower) |
| CLAUDE.md:511-516 (#72) | 24 roll-heights / 120 frames / reach ≤ 3,227 under near_upper, over the 252 sampled frames | true, scoped to #72's 252-frame sample (BW reach recomputed 3,227) |
| CLAUDE.md:462, 480 | #60 marks corrected_roll_table; #71 six rows at 0.1, both tables carry tail | true |
| R/fly_footprint.R:229-235 | 12" lens on 21 sampled roll-heights; scale_wrong rows at factor 1 | true (excluded near_upper: no IR rows) |
| R/fly_footprint.R:264-270 | tail values lower/upper/near_upper/terrain; terrain = IR in band asl, out through ground | true |
| R/fly_footprint.R:280 | table reaches only frames it was measured on | FALSE (pre-existing since #72) |
| R/fly_footprint.R:281-284 | every unsettled lower/upper/near_upper/terrain roll-height listed in excluded | true (0 terrain excluded; test asserts set reconciliation) |
| R/fly_footprint.R:284-286 | BW/colour near_upper from 600-sample; IR rows from census "beyond the band"; BW terrain-only unmeasured | first and third true; "beyond the band" FALSE in repo vocabulary (finding 4) |
| R/fly_footprint.R:735-745 / man/fly_footprint.Rd:232-240 | fly#91 added to list; "on either side of the band" | true; Rd mirrors roxygen |
| R/fly_footprint.R:1375-1382 warning | settled by logbooks or adjacent frame + spacing | true |
| data-raw:9-11 | "Both tails go through one function" | true (fly#71-scoped history) |
| data-raw:18-22 | bci9 joins #72's stratum; terrain tail; "no stratum above holds" | true / defensible |
| data-raw:94-103 | stratum rules; "which no other stratum holds" | rule text true (near_upper includes r > band[2], matching code `:242`); "no other stratum" FALSE (finding 1) |
| data-raw:139-140 | random-sample share of the BW/colour terrain-only population reported, not settled | true |
| data-raw:250 message | "infrared census beyond the band" | FALSE vocabulary (finding 4) |
| data-raw:296-299 | logbook fetch covers lower, upper, near_upper, IR census "beyond it" | FALSE vocabulary (finding 4) |
| data-raw:320-323 | A1: no BW/colour row writes a slash, no verdict moves | true (no BW/colour `scale_as_written` contains "/"; BW rows byte-identical in both CSVs) |
| data-raw:476-477 | IR near_upper join #72's sample; terrain own tail | true as code description (see R2 re-check) |
| data-raw:516-520 | terrain through near_upper rule unchanged; two readings ~2x apart | true (`nu_row` includes terrain) |
| data-raw:575 | sibling run over every excluded roll-height "in both tails" | pre-existing fly#74 wording; near_upper/terrain are skipped with a reason, so not false for #91 |
| data-raw:781 | key reaches only frames measured on | FALSE (pre-existing since #72) |
| data-raw:792-794 | tails disjoint: terrain in band asl, every other tail outside | true |
| terrain-correction.md:309 | lower-tail excluded 55 / 961 | true, scoped to #60 |
| terrain-correction.md:328-330 | reaches exactly 1,001 (1,300; 1,438) | FALSE (pre-existing; now 1,614 measured, 4,721 reach) |
| terrain-correction.md:397 | test holds table to the sweep and logbooks | true for fly#71's rows (scoped) |
| terrain-correction.md:406, 467 | fly#74 run over both tails; 5 of 521 | true, scoped to fly#74 |
| terrain-correction.md:497-500 | #72 over every sampled frame beyond band (252/53/58) | true |
| terrain-correction.md:511-512 | no sampled page writes a scale, veto never fired | true (log: n_scale_read 0 on every near_upper row, after A1) |
| terrain-correction.md:516-525 | #72 result table, 24 / 120 tabled | true, scoped to #72's run (no test pins it) |
| terrain-correction.md:532 | keys reach 3,227 | true for the 24 BW/colour rows (recomputed) |
| terrain-correction.md:550-551 | BW/colour near_upper from sample; bci9 from IR census | true (R2 fix holds) |
| terrain-correction.md:571-574 | IR census elev/base measured as the sweep's; script asserts bases agree | true (stopifnot at data-raw:108; IR elev is mean under nominal 9-in square, axis-aligned, as in the slip script) |
| terrain-correction.md:577 | bci9 25 frames, 2.436, settled alongside the sample | true |
| terrain-correction.md:578-581 | terrain bc5312/bci12 31 frames; "No other stratum holds such a frame" | counts true; "no other stratum" FALSE (finding 1) |
| terrain-correction.md:582 | anything else stops; none today | true (log 348: 25 + 31 = 56) |
| terrain-correction.md:583-589 | rule conditions 1-4 | true (R1/R2 verified); near_upper bullet omits `r > band[2]`, but no out-of-band frame with ratio 2-3 can have r < 0.625 in today's data, so no outcome is affected |
| terrain-correction.md:590-593 | A1 audit; window from BW/colour | true |
| terrain-correction.md:598-602 | table of overlap/heights/r | true (log 857-869; CSV rows) |
| terrain-correction.md:604-608 | factor 1 scale_wrong; keys reach exactly 56; BW rows byte-identical; ~half / ~twice width; no DEM → nominal | true (reach recomputed 17/14/25; `git diff --cached` shows only 3 added rows; excluded CSV unchanged) |
| terrain-correction.md:610-612 | bci9 sheet 2 writes "Scale 1/15,840"; frames 12-36 on sheet 1 with no scale | true (logbook CSV rows 446-450; log n_scale_read 0) |
| terrain-correction.md:614-617 | IR census only; 12 of 2,500 random BW/colour terrain-only, all below; fly#93 | true (log 349) |
| camera-formats.md:343-345 | 3,769 in band, 56 out, none slip-repairable | true (test asserts) |
| camera-formats.md:354-357 | only bci9 in a population those rules read; "which neither rule reaches" | first clause true by stratum; "neither rule reaches" FALSE now (finding 3) |
| camera-formats.md:358-364 | tabled at factor 1; blind read; spacing fits/rejects; widths 2x/0.5x; no DEM nominal | true |
| tests height_rolls:3-9, :186 | table held to "the sweep it was measured from" | partly FALSE (finding 5) |
| tests height_rolls:193-195 | "Three sets, one per tail" | FALSE (finding 2) |
| tests height_rolls:203-205 | IR census "beyond the band"; near_upper or terrain, nowhere else | "beyond" FALSE vocabulary (finding 4); rest true |
| tests height_rolls:231-233 | near_upper and terrain name only factor 1 | true |
| tests height_rolls:254, 278-279 | excluded near_upper/terrain on nominal; scale-wrong row stays on its side, below for terrain | true (else-branch asserts r < band[1]) |
| tests height_rolls:304-306 | IR rows pinned; spacing recomputed in test-fly_footprint_infrared.R | true (infrared test `:121-127`) |
| tests height_rolls:319 | terrain holds exactly two roll-heights | true |
| tests height_rolls:511-513 | fixture r 0.51, 0.55, 2.03 over 1,000 m | true (2353/4590=0.513; 2682/4831=0.555; 4944/2440=2.026) |
| tests height_rolls:524-525, 531 | ~half / ~twice nominal; control at nominal | true (control r 0.485, out of band, no key) |
| tests infrared:112-114 | only bci9 where the fly#60/#72 strata reach | true (strata, not rules) |
| tests infrared:133-134 | with a DEM none of the 56 drawn at nominal | true for any DEM putting them out of band (in band → catalogued height, within 0.2 m of table) |
| NEWS.md:6 (0.21.0) | 56 drawn at wrong width until tabled (#91) | true as a released note; the dev section is empty and release bookkeeping adds #91 |

## Verdict

There are no data or code defects. Five published claims are false under the IR rows: the
stratum/tail wording in three places, the "three sets" test comment, camera-formats "neither
rule reaches", and "beyond the band" for the whole IR census in four places. A sixth, the
test's "measured from the sweep", is partly false. Two statements were already stale before
this diff: the table "reaches only / exactly the measured frames" (`R/fly_footprint.R:280`,
`data-raw:781`, `terrain-correction.md:328-330`). None changes a shipped number or a test
outcome.
