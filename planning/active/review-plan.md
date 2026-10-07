# Plan review (Plan agent, 2026-10-07) — reviewed ae14556

Read-only agent; findings returned as reply text and written here by the orchestrator. The reviewer did not
open any logbook image.

## Blocker
- **B1. The project CLAUDE.md leaks both prior reads, the lean and the stakes to a general-purpose reader.**
  `CLAUDE.md:456-461` ("`bc77087`'s page 1 reads 3.8 or 7.8 ... leaning 7.8 ...") and `:421-423`. Plan/Explore
  types do not carry CLAUDE.md. Fix: canary; if leaked, use a Plan-type reader returning text, or a headless
  run outside the repo (needs the user).
- **B2. `bc77070_3` carries the same priming `bc77070_4` was withheld for, pointing the other way.** Its
  row (`flying_height_logbooks.csv:894`) notes "Project: 'Swan Lake - Grinrod' struck, 'Lamming Mills -
  McBride' written above; Op 94 struck, 57 written; ... date 13/8/77", height 7.5 — and `bc77087_1` is Swan
  Lake Grinrod, Op 94/77, 13/8/77. Withhold `_3`, or all of `bc77070` (gate 211 frames on `bc77087_2`-`_5`).
  No leading-3 height glyph then remains in the set; record that.

## Gap
- **G1.** `task_plan.md` contradicts the committed rule in `findings.md` (gate wording, "every 3 and 7",
  "9 pages plus 36 crops", counterfactual test, "row 656" = file line 656 = R row 655). Make findings.md the
  authority and sync.
- **G2.** Reader outputs that crash `score.R` rather than map to a verdict: missing file/column; case
  variants (`Clear`, `Same`, `Yes`); non-integer `frame_from` ("96?") errors in `seq()`; heights compared as
  strings ("6,500"); blank `focal_mm` on ditto lines blocks merging and can drop coverage under 90%. Fix:
  coerce, compare numerically, case-insensitive; pre-register "any error / missing file / protocol violation
  -> unsettled", and a re-spawn policy.
- **G3.** The `.8` remainder depends on how an uncertain digit is written ("[3/7].8", "x.8", "3/7.8" all
  mis-parse). Specify the notation or a dedicated column.
- **G4.** `clear` with non-empty alternatives counts as a commitment; support for the decided digit is not
  compared with the competing candidate's; filtered by file not frames; `verdict.md` refs not checked to exist;
  the decided digit is copied by hand by a non-blind orchestrator. Use machine-readable `verdict.csv` +
  `ref_id`.
- **G5.** Reader compliance never checked (no reads outside its directory, no Bash, all images read).
  Audit the transcript; neutral directory name outside the repo; md5s recorded before spawning.
- **G6.** Stage A and B in one pass, so "don't change rows.csv after Stage B" is uncheckable. Two turns:
  Stage A, hash, then Stage B via SendMessage.
- **G7.** Brief example `1/7` plants a contested digit; use `5/6`.
- **G8.** "An open question" is in the released 0.23.2 NEWS entry; add a new dev entry, leave release notes.
- **G9.** A frozen worktree lacks the gitignored caches; the calibrate script also queries the live
  catalogue every run. Run in place with md5s before/after.

## Ordering
- **O1.** Baseline re-run of both generators on the unedited tree before editing line 656.
- **O2.** Amend and commit before the reader directory is rebuilt and the reader spawned; rebuild only from
  the committed script and record md5s.
- **O3.** Record the gate's dry run on the prior readers in findings.

## Assumption
- **A1.** Gate reachable but weak: fly#97's real outputs 419/419, 0 mismatch; fly#93's batch4 211/211 on the
  `bc77087` control pages. Tests compliance and gross failure, not 3-vs-7 discrimination; circular on
  `bc77070` (its rows are fly#97's reader output); absorbs 96-vs-90 on line 660.
- **A2.** One new commitment to 7 settles against fly#93's earlier commitment to 3 (1-1 among commitments).
  The user should confirm, or make a 1-1 split `unsettled`.
- **A3.** 2x crops of 1200x1446 are downsampled above ~1.15 MP, so effective gain ~1.6x. Size crops to fit.
  Script comment "10%" overlap is actually 20%.
- **A4.** "Near x2, ambiguous": 2,377 / (2 x 1,158) = 1.026, outside the generator's 2% named-factor tolerance.
  State the number.

## Scope
- **S1.** Province draft "every outcome" vs findings "unsettled only".
- **S2.** Under 3.8/unsettled the re-run is a no-op guard (neither generator reads `note`).

## Acceptance — the 7.8 trace
- Unchanged: `flying_height_rolls.csv`, `_excluded.csv` and all `fly_footprint()` reads (only
  `flying_height_rolls.csv`, `R/fly_footprint.R:292`). `bc77087 1158` is excluded by A2
  (`flying_height_rolls_excluded.csv:174`) before any logbook; the reason is unchanged at 7,800 ft.
- Changes: `flying_height_above_ground.csv:67` (`frames_catalogue` 57->0, `frames_ground_plus` 0->57,
  `logbook_ft` 3800->7800; spacing stays `refutes`, tabled FALSE, Stage 6 stop does not fire);
  `flying_height_image_overlap_keys.csv:7` (`frames_catalogue` 57->0, `frames_ground` 0->57, `w2_height`
  ground, `size` unsettled, `location` datum_question). pairs/strips/synthetic/written unchanged. The overlap
  script prints "STOP FOR THE USER" but writes.

## Copies Phase 3 misses
Note `:812-814`, `:816-825`, `:828`, `:833-835`, `:868-876` (+ CLAUDE.md `:430-433`, contradicting "record,
don't apply"), `:896`, `:983-984`, `:1047`, `:1053-1060`; CLAUDE.md `:421-423`, `:444-446`, `:456-461`;
NEWS 0.23.2 `:9`, `:11` (see G8). Tests failing under 7.8: `test-fly_footprint_above_ground.R:146`,
`:189-192`, `:232`; `test-fly_footprint_image_overlap.R:247`, `:285`, `:289`, `:327`, `:332`, `:345`,
`:347-351`, `:363-366`. New line-656 test: key on `file` + `frame_from == 1`, skip outside source tree.
