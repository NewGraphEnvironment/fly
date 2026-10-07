# Code-check round 3 (fly#95): mechanism, and every place it reaches

Reviewed: branch diff at fbce436 (excluding planning/), against the shipped CSVs, the
logbook transcription, the logbook cache and the run logs. Probes were read-only R over
`inst/extdata/*.csv`, `data-raw/flying_height_logbooks.csv` and `data-raw/.cache/logbooks/`.

## Mechanism

**A number is computed over one set, and the sentence names a neighbouring set.** The
author describes what the set *is* from the story (the "two groups", "frames a page covers",
"roll-heights with transcribed rows", "r <= 0 frames") instead of reading the label off the
line that produced the count (`log_state == "read"`, `frames_logbook > 0`, the pool on the
keys, the boundary case `elev == flying_height`). Every instance so far is a scope swap
between a set and its superset or subset: "where nominal fits" vs all refutes, `catalogue`
vs `catalogue + ambiguous`, the two groups vs every census frame on the keys.

Why it survives the suite: the prose-pinning test checks that the sentence **contains the
number** and that the number equals a count. It never computes the set the sentence's
**words** name, so a correct number under the wrong label passes. Round 2's fix pinned the
composition (2,754 + 202) because a reviewer computed the named set by hand; the other
labels have not had that done.

## Round 2's fix itself

Clean. Recomputed: 2,956 = 2,582 frames of `flying_height_terrain_frames.csv` + 374 of
`_nonpositive.csv` on the 188 keys; the infrared census (which the generator's `terr` does
include) contributes 0 frames on these keys, so "either census file" / "the two census
files" is exact. 2,754 = 2,380 (A2(a) frames, run_rolls.log line 350) + 374. 202 frames on
8 of the 12 non-A2(a) keys; 2,535 / 219 match. `bcc285` 1707: 106 + 39 = 145, an A2(a) key.
CLAUDE.md's "every census frame on them (2,956)" and NEWS's sentence are right.

## Findings

- **[severity: bug (shipped claim)]** `inst/notes/terrain-correction.md:809-811, 823`;
  `tests/testthat/test-fly_footprint_above_ground.R:143` — "**Where a page covers these
  frames** ... **no page** puts the ground under it", "none names the ground", "the rule
  asked for a page that says 'ground', none does", and the test comment "Wherever a page
  covers these frames, none puts the ground under the catalogued height". The set actually
  examined is **transcribed** pages, which exist for **26 of the population's 154 rolls**
  (36 keys, 639 frames). The other 128 rolls (2,317 of 2,956 frames, `log_state == "none"`)
  never had their pages fetched: Stage 4 fetches only `agl_rolls` (the one `supports` roll)
  for this question, and the pre-registered rule itself records "rows exist for 4 of the 15
  group-1 rolls and 22 of group 2's 144 rolls". So "no page" is a claim about pages nobody
  read. This is exactly the fly#93 load-bearing rule in CLAUDE.md ("'No page' is only ever
  what the catalogue says"; a withheld or unread page shipped as an absent one). NEWS.md:5
  and CLAUDE.md:413 are correctly scoped ("Across/On the 576 logbook-read frames ... no
  page") and are not affected. Fix: "Where a transcribed page covers these frames (26 of
  their 154 rolls; the other rolls' pages were not fetched, since only `supports` goes to
  the logbook) ..." and "none of the transcribed headers names the ground".

- **[severity: bug (shipped claim, pinned by the test)]** `inst/notes/terrain-correction.md:810-811`;
  `tests/testthat/test-fly_footprint_above_ground.R:191, 224` — "Over the **32 roll-heights
  with transcribed rows** (576 frames read)". 32 is `sum(frames_logbook > 0)`: roll-heights
  with at least one **read** frame. Roll-heights whose roll has transcribed rows are **36**
  (639 frames); roll-heights with a frame some row covers are **33** (one more key has 3
  `uninterpreted` frames; the rest are `unspanned`, 60 frames). The test asserts the 32 and
  pins the string, so it holds the number to the label it does not compute. Fix: "Over the
  32 roll-heights with a frame the logbook reads (576 frames)".

- **[severity: bug (shipped claim, self-contradiction)]** `inst/notes/terrain-correction.md:790`
  — "**The logbook** is read only where spacing supports". The table eight lines later
  reports logbook relations on 32 roll-heights, 31 of them `undecided`/`refutes`. What is
  true is narrower: pages are *fetched and required to be transcribed* only for `supports`
  rolls; Stage 6 joins every frame to whatever #60-#93 already transcribed, and the
  verdict uses the logbook only where spacing supports. Same mechanism: "read" labels the
  fetch set while the table counts the join set. It is also what makes the "no page"
  claim above read as a census.

- **[severity: bug (shipped claim)]** `inst/notes/terrain-correction.md:860`, `CLAUDE.md:423`
  — "On `r <= 0` frames, 'the height plus the ground' is **about twice** the height ... so
  such a page alone is ambiguous with x2". That holds at the boundary (`elev == flying_height`),
  not over the set. Over the 374 shipped frames `1 + elev / flying_height` is 2.00 to 2.58,
  median 2.16, 90th percentile 2.41; only **51 of 374** sit within 2% of 2, the tolerance
  `settle()` uses to name a factor. So a page writing height-plus-ground is
  distinguishable from x2 on most of these frames. The recommendation it supports (ship the
  logbook figure as ASL through `factor != 1`) does not depend on it, but the stated reason
  is wrong for the population it names. Fix: "at least twice the height (2.0-2.6x, median
  2.16), so near the boundary such a page is ambiguous with x2".

- **[severity: fragile]** `data-raw/height_calibrate-lower_tail_rolls.R:1040, 1058, 1061` —
  the mechanism in code. `n_unread` folds `conflict` (rows disagree) and `uninterpreted`
  into one count reported as "logbook height or frame range not read", and that branch
  fires only when `n_logbook == 0`; a roll-height partly read and partly in conflict falls
  to "logbook covers under half the frames", where `covered` is `n_logbook / n` (frames
  **read**, not covered). fly#93's Stage 5 (lines 722-735) handles both precedences
  separately because an earlier draft folded them (CLAUDE.md: "no page, rows that disagree,
  a row not read are three states, and an earlier draft folded them into one"). Moves
  nothing today: only `bc5602` passes spacing and it is 24/24 read. It will mislabel the
  first `supports` roll-height with a conflict. Fix: reuse fly#93's `unread_state`
  precedence, keyed on `covered < 0.5`, with `conflict` named separately.

- **[severity: fragile]** `tests/testthat/test-fly_footprint_above_ground.R:4` — cites the
  section as "Is the catalogued height above ground? (fly#95)"; the heading is "Is the
  catalogued height above ground? Not with these instruments (fly#95)". A restatement
  written from memory of its source, the same mechanism at its smallest.

Not re-flagged (accepted tradeoff): `inst/notes/terrain-correction.md:794` describes
condition 4 as "no frame of the key in band as catalogued", while the code and the reason
string also count frames with no terrain under them. It is the same mechanism (label
narrower than the count). The tradeoff accepts the count, and nothing tables. If the prose
is touched for the findings above, "(in band as catalogued, or with no terrain under it)"
would make it match the generator's own comment.

Checked and correct: 374/15/16; 1/126/61/0 and the spacing table; 550/8/18/0 and 558 of
576; `bc5602` 0.631/0.510, 4,000 ft on 24 frames, ground 1,234-1,591 m under 23; the four
rolls whose M.S.L. figure sits below the ground (`bc5602` 23, `bc77087` 38, `bc77026` 7,
`bc77072` 1981 3, and no others); every covering header on a read frame names M.S.L.;
0.120/0.352/0.494, 494 of 1,562; 52 refuted-where-nominal-fits, 0.028, 23 under 0.02; the
r <= 0 table (174/20/23/157) and the nine keys, each of which carries r <= 0 frames;
"draws at nominal with a warning" (`fly_footprint.R:1353`); NEWS "every roll table is
byte-identical" (neither roll CSV is in the diff); no population key is in
`flying_height_rolls.csv`. Code labels `frames_outside`, `frames_logbook` (read frames,
and the note calls them that), `frames_nonpositive`, the `agl_keys` union and the
spacing reason strings match what they count.
