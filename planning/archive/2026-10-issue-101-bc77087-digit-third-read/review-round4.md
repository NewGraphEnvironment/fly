# Code-check round 4: fly#101, at 5adf3dd (verifying the round-3 enumeration)

## Verified (no issue)

- Real reader, re-scored from the repo's own `score.R` on an untouched copy: `unsettled (Stage B undecided)`,
  tally 3=1 5=0. Real transcript through `audit.py`: 60 calls, 58 Reads, 50/50 images, 0 undecodable, 0
  `tool_result` with `is_error`: PASS. None of the findings below can move the shipped verdict.
- Every grammar in the round-3 table is enforced in code before the cell is used (`must()` at
  `score.R:82,88,90,95,98,115-118,120,122,123`).
- No logbook image was opened. The audit's `os.listdir()` of `pages_q` was the only contact with it.
- Prose. Each round-3 fix states only what its producer supports:
  - `inst/notes/terrain-correction.md:1040-1041` ("flat top"; fly#97 a single descending stroke; fly#101 a
    curve). The producers are `batch4_rows.csv:104`, `batchC_rows.csv:54` and `reader/rows.csv` row 1.
  - `CLAUDE.md:456-461`.
  - `findings.md:35,247-249`.
  - `province_request_draft.md:19-20` (3; 3 or 7; 3 or 5).

## Walk of score(): every column reference

| line | file.cell | in table / printed list? | grammar enforced before use? |
|---|---|---|---|
| 71-73 | rows.csv (need) | presence only | n/a |
| 74 → gate | rows.csv file, frame_from, frame_to, focal_mm, height_ft_interpreted (control pages) | gate paragraph | normalised by design (A1.7) |
| **80** | **rows.csv `file`** | **neither** | **no**. See F2 |
| 81-82 | rows.csv `leading_digit_confidence` | table | yes, but the grammar admits a value that hides line 1. See F1 |
| 88-90 | rows.csv `frame_from` (figure-bearing rows) | table | yes |
| 92, 100 | `frames_final`, `height_digits`, `height_as_written` | printed | n/a |
| 95 | target `leading_digit_alternatives` | table | yes |
| 98 | target `height_digits` | table | yes |
| 115-118 | glyphs `ref_id`, `candidate`, `same_hand`, `resembles_disputed` | table | yes |
| 119 | verdict `disputed_file`, `disputed_frames` | table ("exactly 1") | only the matching row is counted; other rows are ignored |
| 119, 125 | target `frames_final` as key | printed list ("used only as the key") | exact match |
| 121-122 | verdict `decision` | table | yes |
| 123-124 | verdict `ref_ids` | table | **after internal whitespace is stripped**. See F4 |
| **125** | **glyphs `disputed_file`, `disputed_frames`** | **neither** | **no**. See F3 |
| 134 | verdict `lean` | printed | n/a |

## Findings

All four paths below were reproduced. Each mutated copy of the real reader directory sits under
`<scratchpad>/r4/` (built by `r4/mk.R`) and was scored by the unmodified `score.R` from the repo root. Each gives
`VERDICT: settled 7.8`. Its control gives `unsettled`.

- **[bug] `planning/active/transcription/score.R:82-84`: the confidence grammar still lets a figure-bearing
  line 1 drop out of target selection.** This is round 3's T1 again, closed only for unknown labels.
  - The grammar admits `ditto` and blank on every row, including a row whose height is a figure.
  - The brief says `ditto` is for a ditto line and blank is for "no height".
  - Scratch `A_blank`: line 1 keeps `?.8` but has its confidence blanked, and line 2 (5-26) is relabelled
    `clear` `7.8`. Result: `target: frames 5-26 ... settled 7.8`. Scratch `A_ditto` (line 1 labelled
    `ditto`) gives the same.
  - Control `A0_control`: the same line 2 with line 1 left `uncertain` gives `unsettled (Stage B undecided)`.
  - The round-3 table entry "clear / uncertain / illegible / ditto / blank" encodes the proxy itself.
  - Fix, on the target page:
    - blank only where `height_digits` is blank;
    - `ditto` only on a row after a figure-bearing row with a lower first final;
    - otherwise a scoring error.
- **[bug] `score.R:80`: rows.csv `file` selects the target page's rows, and no grammar checks it.** It is in
  neither the table nor the printed list.
  - The brief warns readers to write the page name "exactly, even where you read the line on a crop", so a
    crop name is the expected slip.
  - Scratch `B_file`: line 1's `file` is set to `bc77087__bc77087_1__row1_col1_x2.png`, and line 2 is
    `clear` `7.8`. Result: `settled 7.8`.
  - Fix: every `file` must be one of the five page names, or scoring error. The gate is unaffected, because an
    unrecognised file can only uncover control frames.
- **[bug] `score.R:125`: glyphs `disputed_file`/`disputed_frames` filter the references the tally counts,
  and no grammar checks them.** They are in neither the table nor the printed list.
  - A reference keyed to no disputed row is dropped silently. If the dropped references are a competitor's,
    the "more than every other candidate" test (A1.6) passes on a filtered set.
  - **The real reader made exactly this slip on 8 of 26 rows** (r9-r12 and r22-r25 keyed to `bc77087_2`).
  - Scratch `C_misKey`: alternatives `3/7`; r1 is a 7, `same` `yes`, keyed to the target; r2 and r3 are 3s,
    `same` `yes`, keyed `bc77087_2.jpg`; the decision is 7 citing r1. Tally 3=0 7=1: `settled 7.8`.
  - Control `C_control`: the same rows keyed to the target give 3=2 7=1, `unsettled (a competing digit has as
    much support)`.
  - So `findings.md:229-231` ("because of a protocol slip by the reader, not a scorer defect") is wrong as
    stated. The slip could not move this read, which is `undecided`, but the scorer's silent drop of it is a
    defect of the round-3 class.
  - The verdict filter at `:119` has the same hole for any extra verdict row whose key names no disputed row.
    For example, a mis-keyed `undecided` row beside a keyed `7` row is ignored.
  - Fix, either of:
    - (a) every glyphs/verdict key must name a rows.csv row on the target page labelled `uncertain`/`illegible`,
      else scoring error. On the real reader this turns `unsettled (Stage B undecided)` into
      `unsettled (scoring error: ...)`: still unsettled, and A1.9 makes it final, but the prose that quotes the
      verdict string would need to follow.
    - (b) count competitor support over all glyph rows regardless of key, which fails safe and leaves the real
      verdict string unchanged.
- **[fragile] `score.R:123-124`: `ref_ids` has all whitespace stripped before the grammar test, not just
  surrounding space.** Round 3's table promises "case and surrounding space aside", so this is a normalisation
  the table does not cover. An internal space joins two tokens into a different id.
  - Scratch `D_space`: r1 is a 3 `partly`, r14 is a 7 `same` `yes`, alternatives `3/7`, and the decision is 7
    with `ref_ids` = `r1 4`. Cited refs become `r14`: `settled 7.8`.
  - This one is contrived, since a reader would more likely write `r1 r4`, which fails safe.
  - Fix: `trimws()` then grammar, with no internal stripping.
- **[fragile] `planning/active/transcription/audit.py:25-37`: a Read counts as having read the image whether
  or not it succeeded.** The audit lists `tool_use` blocks and never looks at the matching `tool_result`.
  - So an image whose Read returned an error, and therefore never reached the reader, counts as read.
  - Scratch: the real transcript with the `tool_result` of the Read of `bc77087__bc77087_1.jpg` (the target
    page itself) set to `is_error: true` and its content replaced with an error string. Result:
    `images in dir: 50; distinct images read: 50 ... AUDIT: PASS`.
  - The real transcript has 0 errored results, so its PASS stands.
  - Fix: add a basename to `read` only when its `tool_use_id` has a `tool_result` without `is_error`.
- **[published claim] `planning/active/findings.md:341-360` ("Enumeration (terminal)") is incomplete.**
  - "These are the cells `score()` reads to decide anything" and "Cells not in this table are printed and
    never tested" are both false. F2 and F3 are three cells that decide which rows are scored (rows.csv `file`;
    glyphs `disputed_file`/`disputed_frames`), and they are in neither list.
  - The `leading_digit_confidence` row's grammar admits the T1 path (F1).
  - The `ref_ids` row describes a check the code performs on a normalised form (F4).
  - Same shape as round 2's closing claim, which round 3 corrected.

No security issues.
