# Code-check round 3 — fly#97 branch (`main...HEAD` at fc813da, planning/ excluded)

Reviewer: subagent, 2026-10-07. I did not modify the working tree. Probes ran in a `git archive` copy in
the scratchpad, with the centroid and logbook caches copied in. That includes one re-run of
`height_calibrate-lower_tail_rolls.R` on a scratch logbook in which only `bc77087_1`'s 1-60 row was
changed to 7,800 ft. `test-fly_footprint_image_overlap.R` is green in the copy (`NOT_CRAN=true`). The
full enumeration is `claims_enumerated.md`: 126 claims, 31 FAIL.

## Mechanism

Round 2's statement is right as far as it goes: a fix moves a claim onto a new basis and keeps stating it
over the old set. But that is one of three ways the same thing happens. The general form is this: **a
claim's set is taken from the label or the framing next to it, not from the producer that computes the
property. And each claim exists in several copies, which are fixed one at a time.**

1. **The set comes from a verdict label.** A property computed on a subset is stated over the set that
   a verdict, or the issue's framing, names:
   - "where spacing rejected nominal" (nine keys) for "the step is wrong" (five);
   - "the five" (`step_overstated`) for "ordinary flights" (four);
   - "five roll-heights" (311 frames) for "not where the photos were taken" (107 by the page);
   - "the lines" for "not rotated" (233 of 285 pairs, 4 contrary);
   - "up to" for a 95th percentile.

   No producer computes the stated set, so no test can pin it.
2. **Copy drift.** One claim lives in up to seven places: the note's intro, its body, "What it leaves",
   the fly#95 pointer, NEWS, CLAUDE.md, and the issue with its draft. Each round fixed the copy the
   reviewer cited. Two examples:
   - Round 2's heading fix reached the note and the test but not the fly#99 issue or its draft.
   - Round 2's bc77087 qualifier reached the step bound but not the 107-frame location count. That count
     was itself new in round 2, and 38 of its frames are bc77087's.
3. **A counterfactual asserted rather than run.** Round 2 added "at 7,800 ft its page would read
   `read_other`" by reasoning, without putting the 7,800 ft read through the generator's rule. Run
   through it, the page reads `ground`. That is the one result the whole fly#95 → fly#97 chain was
   waiting for, and the note states the opposite.

**Where it reaches.** Each finding below is one instance, and nothing beyond these 31 claims was found.
Form 1 is findings 2, 3, 5, 7, 8, 11 and 14. Form 2 is findings 4, 6 and 10. Form 3 is finding 1, and in
weaker form finding 15. The remedy that ends it is mechanical, not another round:
- For every figure, grep all seven copies by its number and its key phrase.
- Take each claim's set from the expression that computes it.
- Run every "would" through the generator.

## Findings

- **[severity: bug]** `inst/notes/terrain-correction.md:996-998`. **At 7,800 ft `bc77087`'s page reads
  `ground`, not `read_other`.** That puts the ground under the catalogued height, which is fly#95's
  "what would change the answer".
  - **What the re-run shows.** I re-ran the generator in scratch with only the `bc77087_1` 1-60 row
    changed to 7800.
    - `flying_height_above_ground.csv` moves in that one row: `frames_ground_plus` 57 of 57,
      `frames_catalogue` 0.
    - `flying_height_rolls.csv` stays byte-identical.
    - Through the image-overlap script's own `case_when`, W2 is `ground`, so location becomes
      `datum_question`. Amendment A2(5) and the script's `STOP FOR THE USER` line both fire.
  - **Why.** The median over the 57 frames of (2,377 m minus MRDEM) is 1,114 m, 3.8% under the
    catalogued 1,158 m, inside the 10% `ground_plus` tolerance.
  - **What it means.** Under the blind reader's leaning, the catalogued height on this key reads as a
    height above ground. That is the outcome fly#95 tested for and found nowhere. The note says the page
    would merely disagree.
  - **Statements that are true only on the 3.8 read.** Each says so nowhere:
    - fly#95's "none puts the ground under it" and "no transcribed page does" (note:812-813, :830-831);
    - its table row "the ground under the catalogued height ... 0" (note:825), which would be 57;
    - `bc77087`'s place on fly#99's list of misplaced-centroid keys.
  - **The x2 caveat.** 2,377 / 1,158 = 2.05, 2.6% from the x2 slip fly#95 warns about, so a 7.8 page
    alone would still not settle it.
  - **Fix.** State the 7.8 consequence as computed, in the note, CLAUDE.md:458-459 and the fly#99 body.
    Pin it with a test that recomputes the `ground_plus` relation at 2,377 m from the census elevations.

- **[severity: bug]** `inst/notes/terrain-correction.md:859-861`, `CLAUDE.md:438-439` (heading),
  `NEWS.md:3` (headline). **"Where spacing rejected nominal, the step is wrong" is stated over the nine
  roll-heights and holds on five.**
  - Spacing rejected nominal on all nine.
  - On `bc7718` and `bc80117` the catalogue step agrees with the images (D_nominal -0.010 and +0.024,
    inside tau). There the rejection came from the flown ~85% overlap, as the note's own body says.
  - `bc5715` and `bcc325` were not measured.
  - NEWS's headline adds "it is the catalogue's centroids that are wrong", a cleft that excludes the
    scale. Round 2 removed that exclusion in the body and kept it in the headline.
  - Fix: scope these to "on five of the nine".

- **[severity: bug]** `inst/notes/terrain-correction.md:947`, `NEWS.md:3` and `:5`, fly#99 body.
  **"Flown as ordinary flights" is stated over the five and holds on four.**
  - `bc77026`'s photos read 0.807. That is above the 0.557-0.780 window the section uses for "the ~60% a
    flight is designed to".
  - Its own page remarks "Forward overlap seems excessive (75.9%)". The note quotes that at :985.
  - The four others read 0.615-0.640. The range "0.62 to 0.81" is right; the label is not.

- **[severity: bug]** `inst/notes/terrain-correction.md:888-889`, `NEWS.md:5`, `CLAUDE.md:443-444`.
  **"By the logbook's figure, 107 of the 112 frames are not over the ground photographed" is unqualified,
  and 38 of the 107 rest on `bc77087`'s contested 3.8.**
  - Round 2 attached the contested-read qualifier to the step bound in each of these copies, but not to
    the location count it introduced in the same edit.
  - At 7.8 those 38 frames leave `r <= 0`, and the page puts the ground under the height (finding 1).
  - The note body (:973) and the fly#99 body carry the qualifier; these three do not.
  - The 107 itself is right. Every one of the 107 rows writes the catalogue's figure under an M.S.L.
    header, and MRDEM is at or above the page height on 107 of 107.

- **[severity: bug]** `inst/notes/terrain-correction.md:1005-1007`, fly#99 body (¶1, and "So, by the
  page, the frames were photographed somewhere else"). **"On five roll-heights the centroids are not
  where the photos were taken" is stated over the five keys' 311 frames.**
  - The location basis, the page against MRDEM, covers the 107 `r <= 0` frames a row reaches.
  - The photo leg (the step is wrong) is per key. It sits at the instrument's resolution on `bc77070`
    and on a contested read on `bc77087`.
  - Round 1 named exactly this, 311 against 112, for the intro. The fix did not reach "What it leaves"
    or the issue, which is the copy fly#99 will be built from.

- **[severity: bug]** fly#99 issue body and `planning/active/followup_issue_draft.md`. **"233 of the 237
  matched pairs a transcribed strip reaches" is round 1's wrong label.**
  - A strip reaches 280. The 237 are the pairs whose strip writes a legible heading.
  - Round 2 fixed this in the note and the test only. The issue was filed from the draft after round 1.

- **[severity: fragile]** `inst/notes/terrain-correction.md:974-976`, fly#99 body. **"So the lines are
  not rotated or reversed" is a universal over every line on the five, drawn from 233 agreeing pairs.**
  - 4 pairs differ: `bc77087` 1/2, 2/3 and 3/4, where the strip writes heading 060 and the catalogue's
    bearing is ~8°, about 52° off; and `bc77072` 1981 frame 111, heading 200 against 298°.
  - 43 `bc77026` pairs (175-218) have no legible heading, and 5 have no strip.
  - Three of the four contrary pairs are on the contested key. Say "on 233 of 237, 4 differ", and
    limit the conclusion to the pairs tested.

- **[severity: bug]** `inst/notes/terrain-correction.md:928-929`. **"Even on ordinary keys the step
  differs from the images' air base by up to about x1.25" turns a 95th percentile into a maximum.**
  - Over the 34 control keys the largest |d| is 0.346, x1.41.
  - 2 of the 34 exceed tau: x1.34 and x1.41.
  - Unpinned.

- **[severity: fragile]** `inst/notes/terrain-correction.md:963-964`. **"Past the appended row's 219" is
  wrong provenance.**
  - `bc77026`'s 140-219 row is on `main`. It was transcribed before fly#97 (findings.md:48-49).
  - A2 appended only the five new rolls' 37 rows.
  - Read with the intro's "the other 5 have no logbook row", it also hides that the page does cover
    221-247. Only the shipped transcription does not (the blind re-read runs to 258).
  - Say "past the shipped row's 219, whose END the earlier transcriber left blank".

- **[severity: fragile]** `inst/notes/terrain-correction.md:969-970`. **"What the photos add is that,
  under either reading, the catalogue's positions along each line are not the photos'" restates the step
  bound with no qualifier.**
  - The qualifier sits at :886-887 and :955 but not here.
  - On `bc77070` the bound is x1.254 against exp(tau) = 1.246.
  - On `bc77087` it is x1.15 at the low end on the 7.8 read.

- **[severity: fragile]** `inst/notes/terrain-correction.md:826-828`. **The "likewise" list names four
  of the five rolls fly#97 transcribed and omits `bcc325`.**
  - Its frame 72 sits under a row 66-72 writing 1,500 ft (457.2 m, M.S.L. header), with MRDEM at
    468.5 m.
  - The full set of rolls whose page figure is below the ground under a census frame it covers is the
    eight named plus `bcc325`.
  - Unpinned.

- **[severity: fragile]** `inst/notes/terrain-correction.md:909-910`. **"It was amended twice, both
  times before any of the nine keys was measured" leaves out a later change.**
  - The W2 residual class was split after the run: `not_read` became `read_other` / `not_read`
    (round 1 finding 3; findings.md:401-403 calls it "an encoding fix after the run"). The rule's text
    said "else `not_read`".
  - It changed a shipped label (`bcc325`) and no verdict.
  - The note is the durable record, and CLAUDE.md treats dated amendments as load-bearing (#53). Record
    it as a post-data change.

- **[severity: fragile]** `inst/notes/terrain-correction.md:882-883`, `CLAUDE.md:448-449`, fly#99 body.
  **"On 1970s rolls the centroids are interpolated evenly along each digitised line" is a universal and
  a mechanism, stated as fact.**
  - The producer it cites (fly#82, note:1734) is a plan-review probe: "64-77% of consecutive bases in
    1965, 1975 and 1985 were equal within 0.5%".
  - Say "are often evenly spaced along a line (64-77% of consecutive steps in fly#82's probe)".

- **[severity: fragile]** `CLAUDE.md:445`, fly#99 body. **"Where the two readings coincide" is stronger
  than the producer.**
  - It fits `bc7718` (gap 0.0007).
  - It does not fit `bc80117`: 0.114 apart in D (x1.12), which is under 2 tau but not coincident.
  - The note's "cannot be told apart" is the correct wording.

- **[severity: fragile]** `inst/notes/terrain-correction.md:902-904`. **"The floor is the gate's
  geometry" is a causal claim the stated arithmetic does not reach.**
  - 230 px shared of 1,250 is an overlap of 0.18.
  - Yet 0.20, which shares 250 px, matched 0 of 10.
  - The geometry is necessary, not sufficient. The rest is the 8- and 20-patch counts on the step-64 and
    step-32 grids. Say so, or state the floor as measured (between 0.20 and 0.25).

- **[severity: fragile]** `tests/testthat/test-fly_footprint_image_overlap.R:165` (test name "every
  figure in its prose"), `NEWS.md:6` ("the suite recomputes them and the note's figures"),
  `CLAUDE.md:115-116` ("together with the note's prose"). **The pin is a subset.**
  - **Unpinned:** 157 (in this section); 34; 0.223; 9 rolls; the floor prose; "up to x1.25";
    x1.39; x1.15-x1.59; x0.68; the 7.8 W2 consequence; the heading conclusion and its 4 differ; the
    "likewise" list; frame 30; the 5,000 ft arithmetic.
  - **The only pin on 107/5** (`:276-297`) is skipped under `R CMD check`, because `data-raw/` is
    `.Rbuildignore`d. Its `reached` predicate also tests only that a row with a height covers the frame,
    not that the row writes the catalogue's figure under M.S.L. I checked: all 107 do.
  - **Related, minor:** `NEWS.md:6` says the strips transcription "ships as `data-raw/...`". It is
    committed, not shipped.
  - Fix: either pin the listed figures (each is one expression over the shipped CSVs, plus a
    `ground_plus` recomputation at 2,377 m), or say "recomputes the verdicts and the figures listed in
    the test".

Checked and found consistent (95 claims; see the table):
- all table cells;
- the controls' counts;
- tau and median d;
- the 0.62-0.81 and 0.11-0.42 ranges, `k` 1.9-3.0 and exp(-D_agl) 1.25-2.70;
- `bc77070`'s 0.006;
- 112 and 107, with all 107 rows at the catalogue's figure under M.S.L.;
- the five unreached frames;
- 233/237/285/280;
- the gaps 0.001/0.114 against 0.44;
- the `bc77070` 271/272 figures;
- km_to_place;
- fly#95's 31/154/123/38/661/8/20/669/689;
- no fly#95 verdict moved;
- x1.15/1.44/1.59 and x0.68 at 7.8, and 0 frames at `r <= 0` there.

`bc7718`'s frame 30 claim has no shipped producer. It holds against the centroid cache, and frames 31-45
of the same key also sit beside Tahsis, which is stronger evidence than frame 30.
