# Code-check round 2 — fly#101 branch diff (main...HEAD, at 0626969)

## Verified (no issue)

- **Round-1 fix 1 (A1.6 "at least one cited").** `score.R:111-125` now restricts the "at least one" test
  to the cited ids (`sup(dec, refs)`) and keeps the competing-digit comparison over all target-row refs,
  which is what A1.6's third clause says. Real reader: `unsettled (Stage B undecided)`, tally 3=1 5=0.
  Scratch copy with decision `3`, ref_ids `r5` (same, `yes`): `settled 3.8`, which is correct under A1.6
  (cited same-hand `yes` for 3, 1 > 0 for 5). The other clauses:
  - "every cited ref_id exists for this target row (file and frames)": `g` is filtered on file and frames
    before `refs %in% g$ref_id`, so citing r11 (on the slipped `bc77087_2` rows) gives no commitment.
  - A1.5: the remainder test is `substring(height_digits, 2) == ".8"`; `[3/5].8`-style notation fails
    toward `unsettled`.
  - A1.7: every case-sensitive comparison left (file names, ref ids, candidate) fails toward `unsettled` or
    a gate FAIL, never toward a settled verdict; zero control rows errors inside `tryCatch` and reports as a
    scoring error.
- **Gate on the prior readers** (`--gate-only`): fly#93 `batch4_rows.csv` and fly#97 `batchC_rows.csv`
  each 211/211, 0 mismatch, PASS, as A1.12 says.
- **audit.py.** A Read through a symlink in the reader dir that points outside is flagged (realpath), and
  the target is listed NOT READ; an unknown tool (Glob) is flagged; a transcript with zero tool calls
  against the 50-image dir FAILs (all NOT READ). A relative `file_path` is resolved against the auditor's
  cwd, so it passes only when the auditor runs from inside the reader dir, and then the only file it can
  name is a permitted one. Zero calls against an *empty* dir passes, which is operator error, not a reader
  breaking a rule.
- **Prose.** Every added sentence in NEWS, CLAUDE.md, the note, file line 656's note and the province
  draft matches its producer: verdict.csv (`undecided`, lean 3), rows.csv (`uncertain`, `3/5`; 7 never
  listed, nor in glyphs.csv), the three "flat top" descriptions (fly#93 line 656, fly#97 batchC:54
  "flat top and single descending stroke", fly#101 rows.csv), 2,377 / (2 x 1,158) = 1.026, the 1000 x 1205
  px probe in findings, and the generator md5 guard for "byte-identical". Every `fly#N` the branch adds
  resolves; fly#101's title is this issue. No stale "two blind reads" / "a third read would settle"
  outside `planning/`.
- **New test.** Passes (`test_file` under load_all, 0 fail). Under `R CMD check` the first `skip_if`
  fires: `^data-raw$` and `^planning$` are in `.Rbuildignore`, and `../../data-raw` from
  `<pkg>.Rcheck/tests/testthat` does not exist, so it skips rather than errors. No new lint (the two lints
  in the file are pre-existing lines 13 and 356).

## Findings

Neither can move the shipped verdict (the real target is `uncertain`, its first final parses, and Stage B
is `undecided`); both are places where the archived scorer, which is the instrument a later read would
reuse, fails toward a settled verdict on an input the committed rule calls no commitment.

- **[fragile]** `planning/active/transcription/score.R:85-96` — A1.6 says "`clear` with alternatives listed
  is no commitment"; the scorer implements "`clear` with *digits* listed". `alts` is built by stripping
  everything but digits and `/`, so an alternatives cell with no digit in it (`seven`, `?`, `unsure`)
  becomes empty and the `clear` row commits. Scratch copy, target set to `clear`, `height_digits` `3.8`,
  alternatives `seven`: `committed digit: 3 (read clear in Stage A)`, `VERDICT: settled 3.8`. The brief
  asks for digits, so this needs the reader to break the format, but it is the direction the rule was
  written to refuse. Fix: treat any non-blank `leading_digit_alternatives` on a `clear` target as no
  commitment.

- **[fragile]** `planning/active/transcription/score.R:78-83` — the rule's target is "the figure-bearing
  row on `bc77087_1` with the lowest first final (its line 1)"; the scorer orders by the *parsed*
  `frame_from` with `na.last = TRUE`, so a line 1 whose final the reader could not read (blank, or `1?` —
  this reader did exactly that on a control page, `9?-103` with `frame_from` blank) sorts last and a later
  figure-bearing row becomes the target. On page 1 every later line is a ditto, so this also needs a ditto
  marked as a figure. Scratch copy, line 1 `frame_from` `1?`, line 2 marked `clear` `3.8`: `target: frames
  5-26 ... VERDICT: settled 3.8`. Fix: if more than one figure-bearing row exists on the target page, or the
  lowest one's `frame_from` does not parse, return `unsettled`.

No security issues. No published claim found unsupported by its producer.
