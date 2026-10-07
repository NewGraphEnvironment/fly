# Code-check round 1 (fly#95)

Scope: branch diff (excluding planning/), the pre-registered rule in `planning/active/findings.md`,
the shipped CSVs, `run_rolls.log` and `run_census.log`.

Checked and found to agree: Stage 3c and 6 against the pre-registered rule (S classes and their order,
`ground_plus` per logbook height via `tapply` on `paste(key, log_ft)`, `ground_header` only turning a
`catalogue` frame, 50%/90% thresholds, focal to 3 mm, reason order S then 2-4); the census r <= 0 export
(no NA rows from `read[nonpos, ]`, since `out` already requires finite `r`); `key_cat` uses the same scale
parse as the census, so no key is undercounted; no dup_key frame reaches `settle()`'s merge; the
`p_agl = 1 - (1 - p_nominal) / ratio_asl` identity is exact for medians (affine, increasing); every number
in the note's three tables and its prose; the four rolls whose M.S.L. figure is below MRDEM (recomputed by
joining the logbook rows: bc5602 23/23, bc77026 7/7, bc77072 1981 3/3, bc77087 38/38); every read row's
header is M'/M.S.L.-type (the two blank-header rows, bc5225 191-192, carry no height); rounded overlaps vs the
exact window (0.557279-0.779679) flip no class. Both changed test files pass in a copy (60 + 62).

## Findings

- **[bug: wrong shipped number]** NEWS.md:6 and CLAUDE.md:420 — "The refutations sit a median 0.028
  outside the window." Over all 61 refuted roll-heights the median distance outside the window is **0.032**
  (exact window). 0.028 is the median over the **52 refuted roll-heights where nominal fits**, which is how
  the note (line 833-834) scopes it and what the test pins. NEWS and CLAUDE.md drop the scope, so the figure
  they quote is for a different population than the sentence names. Either add "where nominal fits" or
  quote 0.032.

- **[bug: wrong shipped number]** NEWS.md:5 ("the crew wrote the catalogue's height on 550") and
  CLAUDE.md:412 ("550 carry the catalogue's figure") — the crew wrote the catalogue's height on **558** of
  the 576 read frames. The 8 `ambiguous` frames (`bcc544` 1615 m, logbook 5,300 ft = 1,615.4 m) are by
  definition `catalogue` AND `ground_plus`, i.e. they do carry the catalogue's figure. The note's table
  is a partition (550 / 8 / 18 / 0) and is fine; the NEWS and CLAUDE.md prose turns the partition's first
  cell into "carry the catalogue's figure", which undercounts by 8.

- **[bug: wrong shipped claim]** inst/notes/terrain-correction.md:807-808 — "**Wherever a page covers
  these frames, the crew wrote the catalogue's height under an M.S.L. header.** That holds over the 32
  roll-heights with transcribed rows (576 frames read)". It does not hold on 18 of those frames: `bc5697`
  610 m (9 frames, logbook 5,000 ft = 1,524 m) and `bc82044` 2316 m (9 frames at 9,600 ft = 2,926 m), which
  the table directly beneath lists as "neither". The M.S.L.-header half is true for every read row; the
  "catalogue's height" half needs "on 558 of them" (or similar), not "wherever".

No code defects found in the generator, census or test changes.
