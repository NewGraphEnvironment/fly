# Code-check round 5: commit 19b7b6e ("Record bc77087's digit as settled at 3 by a human read")

Reviewer read the full diff, the edited sections of `inst/notes/terrain-correction.md` (lines 790-1072),
the producers (fly#93 `batch4_rows.csv`, fly#97 `batchC_rows.csv`, fly#101 `transcription/reader/verdict.csv`,
`data-raw/flying_height_logbooks.csv`, Stage 6 of `data-raw/height_calibrate-lower_tail_rolls.R`,
`inst/extdata/flying_height_rolls*.csv`, `flying_height_terrain_frames.csv`, `flying_height_sweep.csv`),
and the GitHub bodies of fly#95, fly#97, fly#99, fly#101 and PR #102. No logbook image was opened.

Three findings. Everything else checked holds (list at the end).

## F1: a new unscoped claim is wider than its producer (NEWS.md:6, inst/notes/terrain-correction.md:1069-1070)

- `NEWS.md:6`: "No transcribed logbook page puts the ground under a catalogued height; `bc77087` was the one
  candidate."
- `inst/notes/terrain-correction.md:1069-1070`: "**No transcribed page puts the ground under a catalogued
  height.** `bc77087`'s page 1 was the one candidate".

The only producer of "puts the ground under the catalogued height" is Stage 6 of
`data-raw/height_calibrate-lower_tail_rolls.R` (lines ~988-1030). It computes `relation` (`ground_plus`,
`ground_header`) over `agl_lt <- settle(agl, ...)`, which is fly#95's 188 roll-heights only. The pages read
689 of their frames on 38 roll-heights. The note scopes this correctly at line 811 ("Where a transcribed page
covers these frames ... none puts the ground under it") and at the table ("Over the 38 roll-heights with a
frame the logbook reads"). The new bullet and NEWS line drop that scope and state it over every transcribed
page. The transcription also covers the lower, upper, near_upper and terrain tails and the IR rolls, which
no producer tested with this relation. "The one candidate" is also fly#97's finding over its nine keys, not a
search of the transcription.

Before this commit the bullet said the digit "decides whether a page puts the ground under a catalogued
height". That was conditional, so it claimed no finding. The commit turns it into an unconditional one.

Probe (scratch only; it does not stand in for a producer). I applied the Stage 6 relation, median
`(h_lb - elev)` within 10% of the catalogued height, to every frame in
`inst/extdata/flying_height_terrain_frames.csv` that has exactly one covering logbook row: 117
roll-height/page-height pairs, 2,092 frames. Only `bcc544` 1615 passes, and it is `catalogue`/`ambiguous`,
not `ground_plus`.
- Upper and near_upper pages write at or below the catalogue's figure, so structurally they cannot be
  `ground_plus`.
- Spot checks of lower-tail "not a named multiple" rolls (`bcc401`, `bc5593`, `bc5097`, using sweep
  elevations) are nowhere near 10%.

So the claim is probably true, but nothing computes it at the scope it is stated.

Fix: scope both sentences the way line 811 does, for example "No page transcribed for fly#95's roll-heights
puts the ground under the catalogued height; `bc77087`'s page 1 was the one candidate fly#97 found".
- The same scope applies to `CLAUDE.md:458` ("it would have been the first page to put the ground under a
  catalogued height"). That wording is pre-existing apart from the tense, and it is the same class.
- The fly#101 issue body's Status bullet (line 31) repeats the unscoped sentence.

## F2: PR #102's title and body contradict the commit, and the archive README's "Closed by" depends on them

`planning/archive/.../README.md:66` now reads "Closed by: PR #102 (fly#101)". PR #102 is still titled
"Third blind read of bc77087's disputed height digit: unsettled (#101)", and its body says:
- line 3: "did not settle it";
- line 42: "Relates to #101. It stays open: the next instrument is the province's original page.";
- line 55: the province request as the outstanding route.

As written, merging #102 does not close fly#101 ("Relates to", not "Fixes"). The README's "Closed by" line
is therefore false until the body changes. The open PR also publishes the opposite status to the one this
commit records.

Fix: retitle and edit the PR body (status settled as 3 by a non-blind human read; drop "stays open" and the
province route; `Fixes #101` or `Closes #101`).

## F3: the edited test cannot fail if two of the three "blind reads disagreed" are misrecorded (tests/testthat/test-fly_footprint_image_overlap.R:398-431)

The test's name and its first assertion ("Three blind reads of the first digit disagreed") claim that three
reads disagreed. It checks only fly#101's read against its producer (`verdict.csv`: undecided, lean 3;
`rows.csv`: uncertain 3/5).
- The row note's "fly#93 3" and "fly#97 undecided between 3 and 7 leaning 7" are checked against nothing.
- Both producers sit in the same archive the test already globs: `2026-10-issue-93-*/transcription/batch4_rows.csv`
  for frame 1 ("3.8", 3800, "read as 3 not 7") and `2026-10-issue-97-*/transcription/batchC_rows.csv` for
  frame 1 ("?.8 (7.8 or 3.8)", height blank, "reads most like 7.8 but could be 3.8").
- If either were misstated in the note or the prose, the test would stay green. That includes the case
  where fly#97 also read 3, which would make "disagreed" false.

I verified both by hand, and the note is currently correct. This is a gap in the test, not a wrong claim.

Fix, if wanted: read both batch files beside `verdict.csv` and assert frame 1's `height_ft_interpreted`
(3800 vs NA) and the "7.8 or 3.8" text. The rest of the block does discriminate:
- it fails if the row is reverted to the old note;
- it fails if `height_ft_interpreted` moves off 3800;
- it fails if the "not blind" disclosure is dropped from the row or the note;
- it fails if fly#101's verdict files change.

The run is clean: `NOT_CRAN=true ... test_file("tests/testthat/test-fly_footprint_image_overlap.R")` gives
`[ FAIL 0 | WARN 0 | SKIP 0 | PASS 221 ]`. The other note-reading suites, `test-fly_footprint_above_ground.R`
(74) and `test-fly_footprint_terrain_tail.R` (62), also pass.

## Checked and holding

- **Read values.** Each read's value matches its producer: fly#93 3.8 (`batch4_rows.csv`); fly#97 "7.8 or 3.8",
  leaning 7.8, not interpreted (`batchC_rows.csv`); fly#101 undecided, lean 3, alternatives 3/5, 7 never
  listed (`verdict.csv`, `rows.csv`).
- **3,800 ft.** 3,800 ft = 1,158.24 m, the catalogue's 1158.
- **`bc77070`.** "`bc77070`, flown the same week on the same project at 3,800 ft" holds: `bc77070_4`, Swan
  Lake Grinrod, Op 94/77, 13/8/77, 3.8 clear. It is the same day as `bc77087_1`.
- **Shipped outputs.** No shipped output carries the logbook `note` column. `grep` of `inst/extdata` for
  "blind read", "fly#101" and "flat top" returns nothing, and neither generator reads `$note` or checksums
  the transcription. "No code change, every roll table byte-identical" therefore holds for a note-only edit.
- **Part (2) sweep.** No sentence outside `planning/archive` still calls the digit unsettled, contested or
  open, or names the province as its next step.
  - Searched: `inst/notes`, `NEWS.md` (development entry), `CLAUDE.md`, `README`, `vignettes`, `R/`,
    `data-raw/*.R` and `tests/`.
  - Remaining conditionals ("only on its 3.8 read", at notes 997 and 1064) are accurate, not stale.
  - `NEWS.md:16`, "An open question", is in the released 0.23.2 entry, which is history and correctly
    left alone.
- **Issue bodies.**
  - fly#99's body was revised to "settled as 3 ... not blind", as the archive README says.
  - fly#95's body does not cite the read.
  - fly#97's (closed) body still says "**Left open.** `bc77087`'s page-1 height ...". It is a closed issue,
    so this is not counted as a finding. Revise it if closed bodies are kept current.
- **The rule's Outcomes.** They required fly#95 and fly#99 to be revised "where they cite the contested
  read". fly#99 was revised; fly#95 cites none.
