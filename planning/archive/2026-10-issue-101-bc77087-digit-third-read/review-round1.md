# Code-check round 1 — fly#101 branch diff (main...HEAD)

## Verified (no issue)

- `Rscript planning/active/transcription/score.R planning/active/transcription/reader` reproduces the
  findings exactly: gate 211 frames / 4 pages, covers 203 (0.962), 0 mismatch, PASS; target `1-4`,
  `?.8`, `uncertain`, `3/5`; Stage B `undecided`, lean 3, tally 3=1 5=0; VERDICT `unsettled (Stage B
  undecided)`. Under both the original rule and Amendment A1, `undecided` is no commitment, so the
  verdict follows the rule as written.
- Glyph counts in findings (26 refs, 13/13; same-hand `yes` r5, r11 for 3, none for 5; 8 rows naming
  `bc77087_2`, 18 naming the target) match `glyphs.csv`. "Did not list 7" matches rows/glyphs/verdict.
  "Flat top" is in fly#93's shipped note and fly#97's `batchC_rows.csv` ("flat top and single descending
  stroke"). 2,377 / (2 x 1,158) = 1.026, so "2.6% off x2" holds.
- `data-raw/flying_height_logbooks.csv`: one line changed, `note` only; `height_ft_interpreted` 3800.
- New test passes (218 PASS in its file); all seven test files that read `terrain-correction.md` pass
  (0 fail / 0 skip / 0 error). No test greps the removed prose. Under `R CMD check` the first `skip_if`
  fires (`data-raw` and `planning` are in `.Rbuildignore` and `../../data-raw` does not exist from
  `<pkg>.Rcheck/tests/testthat`), so it skips rather than errors.

## Findings

- **[fragile]** `planning/active/transcription/score.R:117-121` — the Stage B commitment check does not
  implement Amendment A1.6 as written. A1.6 requires "at least one **cited** same-hand reference
  resembles the glyph (`yes`)"; the scorer's `sup(dec) < 1` counts every same-hand `yes` reference for
  the decided digit, cited or not, and only checks that cited ids exist. Mutation (scratch copy of the
  reader dir, `verdict.csv` set to decision `3`, ref_ids `r1`, where r1 is `partly`): scorer prints
  `committed digit: 3 (Stage B, 1 same-hand reference(s))` and `VERDICT: settled 3.8`. Under A1.6 that
  is `unsettled`. A guard that fails toward a settled verdict. It cannot change the shipped outcome
  (the real decision is `undecided`), but findings.md ("Amendment A1", item 6/7) presents this scorer as
  the pre-registered rule's implementation and it ships in the archive as the instrument a re-read would
  reuse. Fix: restrict the `sup()` count used for the "at least one" test to `g$ref_id %in% refs`
  (and the competing-digit comparison can stay over all refs, as A1.6's third clause says "more
  same-hand yes references than every other candidate").

- **[fragile]** `tests/testthat/test-fly_footprint_image_overlap.R:410-414` — `vf` lists
  `planning/active/transcription/reader/verdict.csv` before the archive glob and takes `vf[1]`. Once this
  branch is archived, any later issue that reuses this layout (a fourth read from a province scan is the
  named next step, and would naturally reuse `score.R`/`reader/`) puts its own `verdict.csv` at the active
  path, and this test then checks fly#101's claims against that issue's reader — red for reasons
  unrelated to the change under test, or, if the new read is also `undecided` lean 3 on `3/5`, green on
  the wrong file. Prefer the archive path (or glob only `*issue-101*`) so the test reads fly#101's own
  output.

- **[fragile, minor]** `planning/active/province_request_draft.md` ("can be read as either a 3 or a 7 at
  the published size") — after the third read, the candidates named are 3/7 (fly#97) and 3/5 (fly#101).
  The draft is unsent and the user decides; flagging only because CLAUDE.md and the note now point to it
  as "the remaining route", so whoever sends it would state a narrower ambiguity than the record holds.

No security issues. No other claim in NEWS, CLAUDE.md, the note, the transcription note or findings.md
found unsupported by its producer.
