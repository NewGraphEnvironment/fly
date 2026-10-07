# Code-check round 4 — fly#97 branch at b98ecea: a terminal enumeration

Reviewer: subagent, 2026-10-07. I did not modify the working tree. Probes ran in a `git archive` copy in
the session scratchpad. Shipped CSVs were read with `na.strings = ""`. The centroid cache
(`data-raw/.cache/centroids`) was read in place and not written. The full table is
`claims_enumerated_round4.md`: **146 claims enumerated, 16 FAIL**. They are 11 distinct defects, plus one
finding on vacuous test pins.

## Round 3's fixes

Every round-3 finding was checked against its current copies. All 16 landed in the note and the test.
Three copies still carry a round-3 defect, each the copy-drift form round 3 named:
- **fly#99 has no `bc77087` bound qualifier.** It is round 3's finding 4/10 pattern (I6).
- **"Not rotated" over the tested pairs still includes the 4 that differ** (N61, I8). Round 3's
  finding 7 was half-applied.
- **The fly#95 pointer paragraph's unqualified "the step is wrong"** (P13).

One round-3 fix introduced a new wrong statement: "The 8- and 20-patch counts set the rest" (N18). The
round-3 suggestion it followed was itself not checked against the grid.

Two defects are new:
- the Tahsis distance (N70);
- the provenance of `bc77087`'s 3.8 (N76).

The 7.8 counterfactual (N79-N83) now matches the generator: run through the relation, W2, size,
location and the STOP line. One phrasing of it (N78) states the result in the package's variable `r`,
which does not move.

## Findings

- **[severity: bug]** `inst/notes/terrain-correction.md:1015`. **"`bc7718` 46-69 is 'TAHSIS', 359 km
  from its nearest catalogued frame" is wrong for the set it names.**
  - **The producer's set.** `km_to_place` (script:700-708) measures from the key's nearest **census**
    frame. On `bc7718` 1524 m that is frames 46-69 only.
  - **The same key's other frames.** Frames 31-45 are catalogued 14.8-15.9 km from Tahsis. They are on
    the same key (1,524 m, 305 mm, 1:5000) and under the same logbook row, 31-69 at 5,000 ft, whose page
    is "Project Tahsis - Zeballos". I checked this against the centroid cache. Read as written, the
    figure is off by about 344 km.
  - **What the omission costs.** It is the strongest evidence in the section that 46-69 are misplaced:
    the in-band half of the same row sits at Tahsis and the census half 359 km away.
    - `findings.md:357` cites frame 30 instead, which is on a different key (3,810 m).
    - fly#99 (draft:24) quotes the 359 km correctly for 46-69, but leaves the 31-45 fact out of the
      issue that would build a misplacement ledger, while `bc7718` is `not_tested`.
  - **The pin cannot see it.** `test-...image_overlap.R:276` pins the census-set number.
  - **Fix.** Say "359 km from the nearest of frames 46-69, while the same key's frames 31-45, under the
    same page row, are catalogued 15 km from Tahsis", and carry that into fly#99.

- **[severity: bug]** `inst/notes/terrain-correction.md:1024`. **"fly#60's reader read 3.8" has the
  wrong provenance.**
  - The `bc77087__bc77087_1.jpg` 1-60 row first appears in `9ee2114`, "Transcribe the terrain
    roll-heights' logbook pages blind (#93)".
  - So the 3.8 read is fly#93's, and it was itself blind.
  - The note leaves the digit to the user. Who read it, and that both readers were blind (one each way),
    is the evidence the user is handed, so it has to be right.

- **[severity: fragile]** `inst/notes/terrain-correction.md:911-913` and `CLAUDE.md:452`. **The floor is
  measured on one sign of shift, and the cause given for it is wrong.**
  - **The synthetic shifts all have one sign.** All 80 are negative (`dr_true` or `dc_true` = -L(1-p)).
  - **The grid rows are sign-dependent.** `patch_shifts()` puts grid rows at `seq(114, 1136, by = 64)`
    and keeps a row only where `r + shift` stays in [114, 1136].
    - **Negative shifts.** The last row (1,074) goes above 960 px, so nothing survives under p ≈ 0.232.
    - **Positive shifts.** Row 114 survives to about 1,022 px (p ≈ 0.19). It gives 16 patches at step 64
      and 32 at step 32, above both the 8 and 20 thresholds.
  - **What the synthetic at 0.20 shows.** `n_patches` is 0 on all 20 cases, so no grid point existed at
    all. The counts never bound.
  - **Which sign the real pairs carry.** Of the 537 matched real pairs, 531 have a positive major
    component, the sign the synthetic never tested.
  - **Why it matters.** "The 8- and 20-patch counts set the rest" is a causal claim the code
    contradicts. "Between 0.20 and 0.25" is the floor for negative shifts. For the sign the real pairs
    carry, the geometry alone would admit about 0.19 to 0.20.
  - **Fix.** Say it is measured on negative shifts, that the step-64 grid row sets it, and that it is
    lower for positive shifts. Or add positive-shift synthetics (the script already supports both axes;
    the sign is fixed).

- **[severity: fragile]** `inst/notes/terrain-correction.md:1025`. **"At 7,800 ft (2,377 m), its 38
  frames would not be at `r <= 0`" is a counterfactual stated in a variable that does not move.**
  - `r` is computed from the catalogued `flying_height` in the census and in `fly_footprint()`.
  - Round 3's re-run of the generator at 7,800 ft left `flying_height_rolls.csv` byte-identical, because
    spacing refutes the key and nothing tables it.
  - So under the 7.8 read the package still has those 38 frames at `r <= 0` and still falls back to
    nominal with a warning.
  - What changes is whether the page's aircraft is above MRDEM's ground: `h - e > 0` on all 57, the only
    thing `test-...:337` pins.
  - fly#99's "would not be under the terrain at all" is the accurate form. Use it.

- **[severity: fragile]** fly#99 body and `planning/active/followup_issue_draft.md:17`. **The step bound
  "x1.25 to x2.70 under any height the page allows" carries the `bc77070` qualifier but not
  `bc77087`'s.**
  - `bc77087`'s x1.39 holds only on the 3.8 read. At 7.8 the bound is x1.15-x1.59 over MRDEM's
    10th-90th percentile, and x0.68 over sea-level ground.
  - The note (:974, :992), NEWS:6 and CLAUDE.md:443 all carry it. The issue fly#99 will be built from
    does not.
  - The issue's `bc77087` paragraph (draft:20-22) moves the location, not the bound.

- **[severity: fragile]** `inst/notes/terrain-correction.md:998-999` and fly#99 (draft:18). **"On the
  pairs tested, the lines are not rotated or reversed" is a universal over a set that contains its four
  counterexamples.**
  - The 237 tested pairs include `bc77087` 1/2, 2/3 and 3/4 (heading 060, about 52° off) and `bc77072`
    1981 frame 111 (about 98° off).
  - The issue's "so on those pairs" refers to "the pairs with a legible page heading", the same 237.
  - Say "on the 233 that agree"; the 4 are rotated on the page's own reading.

- **[severity: fragile]** `inst/notes/terrain-correction.md:863-865`, the fly#95 pointer paragraph.
  **"On five of them the catalogue's centroid step is wrong" is the one copy left with no qualifier.**
  - It is at the instrument's resolution on `bc77070`.
  - On `bc77087` the bound x1.39 holds only on the 3.8 read.
  - Every other copy now says so; this is round 3's form 2 again.
  - The same paragraph's "fly#97 measured those nine with the photos" disagrees with the section's own
    "all seven keys here that the photos could measure" (:1048). See the next finding.

- **[severity: fragile]** `inst/notes/terrain-correction.md:1040` and `:862-863`. **The nine against the
  seven.**
  - **":1040".** "`fly_footprint()` draws these frames at nominal scale, which the photos no longer
    contradict" follows a section about the nine keys.
  - **What the two unjudged keys show.** On `bc5715` and `bcc325` the only matched pair reads the step
    x1.70 and x2.49 off nominal (D_nominal -0.53 and -0.91). That is unjudged, under the 3-pair minimum,
    not "not contradicted".
  - **":862-863".** "Measured those nine" has the same scope problem.
  - **Fix.** Scope both to the seven.

- **[severity: fragile]** `NEWS.md:7` and `CLAUDE.md:443-444`. **The 38 `bc77087` frames inside the 107
  are given as a count, with no word that they rest on the contested read.**
  - Round 3 finding 4 asked for that qualifier. The note intro (:895-897), "What it leaves" (:1042) and
    fly#99 (draft:21) now carry it.
  - **NEWS.** Its qualifier sits on the bound bullet (:6). The open-question bullet (:9) says the page
    would put the ground under the height, not that these 38 then leave the 107.
  - **CLAUDE.md.** It is the same at :444 against :459-462.
  - **Fix.** Write "38 of the 107, all `bc77087`'s, on its contested 3.8 read".

- **[severity: fragile]** `inst/notes/terrain-correction.md:886-887`. **The fly#82 probe's 64-77% is
  stated over "1970s rolls".**
  - The range is 1965 (67%), 1975 (77%) and 1985 (64%) (`planning/archive/2026-10-issue-82-photo-parallax/review-1.md:6-8`).
    Only one of the three is a 1970s year.
  - Say "in fly#82's probe of 1965, 1975 and 1985 rolls, 64-77%", or "77% in 1975".
  - **Related, outside the enumerated set.** `data-raw/height_measure-image_overlap.R:7-8` still says "on
    1970s rolls the centroids are interpolated evenly along each line". That is round 3's finding-13
    universal, in a copy the round-3 sweep did not include.

- **[severity: fragile]** `inst/notes/terrain-correction.md:891` and `:968`, NEWS:6, CLAUDE.md:442 and
  fly#99. **"At least x1.25 to x2.70 under any height the logbook's figure allows": the x2.70 endpoint
  takes in frames no shipped row reaches.**
  - On `bc77026` it is the median over 114 pairs, 38 of them on frames 220-258.
  - Only the unappended blind re-read covers those frames.
  - Over pairs a shipped row covers, the range is x1.25 to x2.61 (`bc77072` 1829: x1.78 on its 11
    covered pairs, against x1.80).
  - The qualitative claim stands. Either cite 2.61, or say the endpoint relies on the blind re-read's
    140-258 row.

- **[severity: fragile]** `tests/testthat/test-fly_footprint_image_overlap.R`. **Five pins can pass while
  their sentence is wrong.**
  - **:233.** `"frames at \`r <= 0\`, where adjacent-frame spacing rejects nominal"` is a constant.
    Nothing in this file asserts that the nine keys' `ag$spacing` is `refutes` or that their nominal
    overlap is outside the window.
  - **:61 and :270.** The note's "error under 1e-4" is matched as literal text. The computed bound is
    0.02, 200 times looser; the actual figure is 1.2e-5.
  - **:230-232.** It never checks that the four are inside the window, that the fifth is above it, or
    that the maximum is `bc77026`. The key's name is literal.
  - **:247-248.** "%d differ" sums `dir_differ + dir_reverse`, so a reversed line would pass under the
    word "differ".
  - **:276.** It pins `km_to_place`, the census set, which is how the Tahsis finding above passes.

## Checked and consistent

130 claims PASS; the table gives each with its producer. Among them:
- every table cell and control figure;
- tau, 0.223, 2 of 34 (x1.34 and x1.41), 31/190/2;
- 0.62-0.64, 0.81, 83-97%, 0.11-0.42, 1.9-3.0;
- `bc77070`'s 0.006 and its 271/272 figures;
- 112 and 107, with all 107 rows at the catalogue's figure under M.S.L.;
- the five unreached frames;
- 233/237/48/285 and the four contrary pairs' identities;
- 0.001/0.114 against 0.44;
- 97 km, 6-36 km;
- the 7.8 relation, W2 = ground, the STOP line, 1,114 m, 2.05, x1.15/x1.59/x0.68, and W1 alone unchanged;
- `bc77070` 13/8/77, the same Op 94/77 as `bc77087` page 1, read clear;
- the post-run change limited to `read_other`, with `km_to_place` reporting only;
- fly#95's 669/689/661/8/20/0/38/31/154/123;
- the nine-roll "likewise" set (exactly these nine; `bcc325` 1,500 against 1,300 ft);
- no fly#95 verdict moved (spacing, tabled and reason identical to `main`);
- roll tables and `R/` unchanged;
- the CLAUDE.md Architecture bullet;
- fly#99's description of the `r <= 0` fallback and warning (`R/fly_footprint.R:1352-1360`).

The `bc77087` 3.8 against 7.8 question is left open accurately in every copy. The two defects on it are
the reader's provenance (fly#93, not fly#60) and the `r <= 0` phrasing.
