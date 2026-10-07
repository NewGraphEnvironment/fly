# Code-check review, round 2 (fly#93), diff origin/main...HEAD

Verdict: the round-1 fix to A2 is correct as code, but its consequence was not carried through.
It sent three roll-heights to the logbook. The re-run fetched their pages, and nobody read them.
The shipped reason and three documents then say those pages do not exist. One finding is a bug;
the second is stale figures in the planning findings.

## What was verified clean

- **The A2(b) bound is now valid for every case `settle()` can produce.**
  - `agree` requires `abs(log_ft * FT / flying_height - 1) <= 0.02`, so each agreeing frame's
    logbook height is in [0.98 h, 1.02 h] (relative to the catalogue height). `h_true` is
    their median, so it is in that range too.
  - `p_corrected` is a median, with `na.rm = TRUE`, over agreeing frames, all evaluated at the
    one `h_true`. A frame with an NA base drops out, and the `ok &` in `unbounded` matches that.
  - Where every `ok` frame has `elev < 0.98 h`, the side is positive at every admissible
    `h_true`. Overlap is increasing in `h`, so each value is in [p(0.98 h), p(1.02 h)] and any
    subset median is in [lo, hi].
  - Where some frame has `elev >= 0.98 h`, the side can be 0 (giving -Inf, or NaN when
    base = 0) or negative (overlap > 1). A median of an even count can then land between a
    value below the window and one above it. `unbounded` sends the roll-height to the logbook,
    which is the conservative direction. The equality case (`elev == 0.98 h`) is included.
  - An NA `elev` cannot reach A2: the census and the IR terrain set both assert `r > 0`, and
    an NA would make `if (!can)` error rather than pass silently.
  - The generator, the census preview and the suite recompute use the same predicate.
- **A2(a)** uses the same `median(p_nominal, na.rm = TRUE)` over the same four-field group
  that `nu_row`'s `!fits(p_nominal)` uses.
- **The appended logbook rows equal `consolidate()` over the raw batch files minus the five
  control pages.** 1,420 literal lines, of which 38 are control lines, leave 1,382 lines from
  176 pages on 58 rolls. They consolidate to 408 rows, an identical full-row multiset on all 14
  columns. No appended page was already in the CSV.
- **The consolidation fix holds one axis over.** Only two non-control lines are unranged, both
  on `bc5541_2` (`15?` and `164`), and neither falls inside a consolidated run. Recomputed, the
  batch-2 control yields 202, 219 and 233, as the note says. The other four controls
  reproduce their existing rows.
- **Shipped tables.** The A2 counts from the shipped excluded CSV are 176 / 2,380 and
  32 / 472, which gives 92 / 1,952 to the logbook. The tabled terrain rows sit on 69 rolls in
  total. Neither roll table has a removed line against origin/main.
- **Tests.** `test-fly_footprint_terrain_tail.R` and `test-fly_footprint_height_rolls.R` pass
  on HEAD (run from a copy with `NOT_CRAN=true`).
- **The census script's margin loop.** `M_new <= M` breaks only when the final pass's reads
  leave the max unchanged, so `margin_m == 2 * coarse_error_max_m` holds as the test asserts.
  The upper arm, Control 3 and the A3 split are sound.

## Findings

- **[bug] inst/extdata/flying_height_rolls_excluded.csv (`bc77026` 2042 m, `bc77072` 1829 m and
  1981 m, 175 frames); inst/notes/terrain-correction.md:690 ("none has a page, so none moved
  beyond its reason"); planning/active/findings.md:344 ("The catalogue links no page for either
  roll").**
  - **What happened.** The round-1 fix made these three roll-heights unbounded, so A2 sends
    them to the logbook. The re-run then fetched their pages: `run_rolls.log:351` reads
    "logbook pages for 11 rolls: 6 fetched or cached, 0 failed". The cache holds
    `bc77026__bc77026_2.jpg`, `_3.jpg` and `bc77072__bc77072_1.jpg` through `_4.jpg`, all
    written at 16:41 alongside the verdict `.rds` files. `bc77072_1` is a legible Film Record
    with a TRUE HEIGHT column filled in.
  - **What is missing.** None of the six pages is in `data-raw/flying_height_logbooks.csv`.
    These are the only untranscribed cached pages on any of the 69 logbook-set rolls; every
    other roll's cached pages are all transcribed, or the roll has none.
  - **What ships as a result.**
    - `settle()` finds `n_logbook == 0` for all three roll-heights. The excluded CSV says "no
      logbook page covers these frames", which is false: the pages exist and were not read.
    - The note and findings.md state as fact that no page exists. The note's "only the rest
      had their pages read" no longer holds.
    - The note's outcome row "no logbook page covers these frames | 13 | 240" counts these 175
      frames under that reason.
  - **Why it matters.** The fix's own rationale is that A2 must not decide these roll-heights,
    and the logbook must. As shipped, the logbook was never consulted, so 175 frames sit on
    nominal scale under a reason that misstates why. If their pages agree with the catalogue
    height and spacing fits, they would be tabled.
  - **Mechanisms.**
    - *Written data outlives the fix*: the A2 change moved the set to read, and the
      transcription stayed fixed at the old set.
    - *An absent measurement never shares an encoding with a real one* (CLAUDE.md, #53 and
      #60): "page not read" is reported as "no page".
  - **Nothing guards it.** The generator never checks that every fetched page of a
    logbook-set roll appears in the transcription CSV, so the gap passes silently.
  - **Fix.** Transcribe the six pages blind, as the other 176 were, with a control page in
    the batch. Consolidate them, append, re-run, and correct the three documents.
  - **Guard to add.** In the generator, after `fetch_logbooks`, stop when any cached page of
    a roll in `a2$film_roll[is.na(a2$a2_reason)]` is absent from `logs$file`.

- **[docs] planning/active/findings.md:224, 230-231 and 254 carry pre-fix figures that the
  round-1 fix changed.** Each line, with what it says and what is now true:

  | line | says | now |
  |---|---|---|
  | 224 | "89 go to the logbook (1,777 frames, 67 rolls)" | 92, 1,952, 69 (only line 223 got the parenthetical) |
  | 230 | "81 roll-heights on 60 rolls have no page transcribed" | 84 on 62 |
  | 231 | "That leaves 176 pages on 58 rolls to read" | 182 pages on 60 rolls, 6 of them still unread, per the bug above |
  | 254 | "consolidated into 406 rows" | 408: the round-1 consolidation fix split `bc7683_3`'s 1-144 into three rows; the CSV diff adds 408 |

  The archived findings are the measurement record, so these will be read as current.
