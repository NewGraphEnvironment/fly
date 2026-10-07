# fly#101: a third blind read of `bc77087`'s page-1 height digit

## Outcome

`bc77087_1.jpg` line 1 writes the TRUE HEIGHT for 57 frames, and its first digit was disputed. fly#93's
reader committed to 3. fly#97's declined between 3 and 7, leaning 7. A 7.8 would make it the first page to
put the ground under a catalogued height (fly#95).

A third blind read ran under a rule fixed and committed before the read (`findings.md`, "The rule" and
Amendment A1). It came back **unsettled**: the reader's leading digit was uncertain between **3 and 5**,
leaning 3, and it never listed 7. Its glyph comparison decided neither.

- **What shipped.** The transcription keeps 3.8. Only the row's note changed, to record the three reads.
  Both generators re-ran with all 44 other CSVs byte-identical.
- **Prose.** The note, NEWS, `CLAUDE.md`, fly#99 and fly#101 say three blind reads have not settled it.
- **What is left.** The next instrument is the province's original page. A request is drafted in
  `province_request_draft.md` and has **not been sent**.

**What was learned.**
- **A general-purpose subagent is not blind in this repo.** It carries the project `CLAUDE.md`, which
  named both prior reads. A canary showed it (bc77 yes, 3.8/7.8 yes), while a Plan-type subagent carries
  none of it.
- **The scorer for a pre-registered rule is itself a guard.** Four code-check rounds each found it settling
  on input the rule calls no commitment. The mechanism was predicates tested on normalised or routed cells.
  It ended when every column `score()` reads was classified from a scan of the code, not recalled.

## Measurement

- **The control gate held the reader to the roll's other heights.** It covered 203 of 211 frames on
  `bc77087_2`-`_5` with 0 mismatches. Frames 96-103 went uncovered because the reader wrote `9?`.
  fly#93's and fly#97's readers each cover 211/211 with 0 mismatches, so the gate tests compliance and
  gross misreading, not 3-versus-7.
- **Audit.** The reader read 50 of 50 images, every Read inside its directory, and made no other call.
- **Stage B:** 26 references.
  - Same-hand `yes`: 2 for 3, 0 for 5.
  - Decision `undecided`, lean 3.
  - 8 rows were keyed to the wrong page. The final scorer refuses them, so the verdict string is a
    scoring error. With the keys corrected it reads "Stage B undecided". Both are unsettled.
- **Provincial copy.** The published scan is 1000 x 1205 px. No larger copy was found at the paths probed:
  a 403 on listing and 404 on four siblings.
- **Baseline.** Both generators on the unedited tree: 45/45 CSVs byte-identical, the live catalogue
  query included.

**Wrong turns, kept.**
- The approved plan gave the reader `bc77070_1`-`_4`.
  - `_4` was withheld before any read: it names the same place at a clear 3.8.
  - The plan review then found `_3` shows the same project struck over a 7.5, so all of `bc77070` went.
- The first reader type (general-purpose) would have been primed, which the canary caught.
- The round-3 enumeration was written from recall and was wrong; round 4 replaced it with a measured one.
- Twice an uncomputed or unverified sentence went into `findings.md` and was caught and removed:
  - a 5.8 elevation figure;
  - a wrong reason for the scorer's tally.

## Evidence

- `transcription/reader/*.csv`: the reader's output, extracted from its transcript by script.
- `transcription/{score.R,audit.py,make_reader_dir.sh,transcriber_brief.md,brief_stage_b.md,pages_q.md5}`:
  the instrument, as committed before the read.
- `review-plan.md`, `review-round[1-4].md`: the plan review and four code-check rounds.

Closed by: PR for fly#101. The issue stays open for the province's original.
