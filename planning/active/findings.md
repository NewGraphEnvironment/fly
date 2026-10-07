# Findings — Settle the disputed height digit on bc77087's logbook page 1 (#101)

## Issue context

**If we do it:** we learn whether any logbook page puts the ground under a catalogued height. That is fly#95's open question, and the answer would decide whether `bc77087`'s 57 frames ship a corrected height through the existing `factor != 1` route. **If we never do:** the transcription keeps 3.8, `bc77087` stays `misplaced` on a contested read, and fly#95's "no page does" stays true only as transcribed.

## Problem

`bc77087` page 1 (`data-raw/.cache/logbooks/bc77087__bc77087_1.jpg`, frames 1-60, "Swan Lake Grinrod") writes a TRUE HEIGHT whose first digit is disputed.
- fly#93's blind reader read **3.8**, which matches the catalogue's 1,158 m.
- fly#97's blind reader declined to choose, leaning **7.8**: a flat top and a single descending stroke.

Read as 7,800 ft (2,377 m), the median over the 57 frames of the height less MRDEM is 1,114 m, within 4% of 1,158 m. So the generator's relation would be `ground_plus` and W2 `ground`. fly#97's rule would then stop for a decision on the package's shape. 2,377 / 1,158 = 2.05 is close to the x2 slip, so the page alone would not settle the datum.

See `inst/notes/terrain-correction.md`, "What the frames under the terrain covered".

## What to do

Get a third, independent read of that one digit: a fresh blind reader, or the original scan at higher resolution if the province holds one. Fix the rule for what a 7.8 would ship before reading it, as fly#60/#72/#93/#95/#97 did.

`bc77070` was flown the same week on the same project at 3,800 ft, and its page reads clear. That is context, not evidence about this digit.

Related: fly#97, fly#95, fly#99.

## Already known before the rule (plan-mode exploration, 2026-10-07) — NOT blind

- `bc77087_1.jpg` line 1 writes the TRUE HEIGHT (M'/M.S.L.) for finals 1-60; every later line on the page is
  a ditto of it, so one glyph decides the key `bc77087 1158 153 5000` (57 catalogue frames).
- fly#93's blind reader (`planning/archive/2026-10-issue-93-bw-colour-terrain-tail/transcription/batch4_rows.csv`)
  read 3.8: "first digit drawn with a flat top, read as 3 not 7". That is the shipped row, file line 656 of
  `data-raw/flying_height_logbooks.csv`. fly#97's blind reader (`.../2026-10-issue-97-image-overlap/transcription/batchC_rows.csv`)
  wrote "?.8 (7.8 or 3.8) ... reads most like 7.8 but could be 3.8; not interpreted".
- The catalogue's 1,158 m is 3,800 ft. `bc77070_4`, the same project ("Swan Lake Grinrod") flown the same
  week, reads 3.8 clear. That is context, not evidence about this glyph (issue #101).
- **The province serves no larger copy.** `FLIGHT_LOG_URL` is
  `https://openmaps.gov.bc.ca/thumbs/logbooks/1977/roll_pages/bc77087_1.jpg`, 1000 x 1205 px, 229,143 B,
  byte-for-byte the cached file. The directory answers 403 to listing; `.../1977/bc77087_1.jpg`,
  `.../logbooks/1977/roll_pages/bc77087_1.jpg` (no `thumbs`), a `.tif` sibling and a `roll_pages_hr/`
  sibling all answer 404 (GET, 2026-10-07). A higher-resolution original can only come from asking the
  province, which is outward-facing: drafted, never sent from here.
- Nobody on this issue has looked at the glyph: not the planner, not the plan reviewer (told not to).

## The rule (fixed 2026-10-07, committed before the third reader is spawned)

### Decided at the plan gate (by the user)

1. If the read settles 7.8: record it, do not apply it. `fly_footprint()` is untouched; the shape decision
   that fly#97's A2(5) stop asks for goes to a new issue.
2. The third read is a blind subagent only.

### Instrument

A fresh general-purpose subagent (Opus), unnamed, told not to spawn, not to use Bash and not to open
anything but the images in its directory. Its brief is `transcription/transcriber_brief.md`: fly#93/#97's
`rows.csv` brief, plus `leading_digit_confidence` / `leading_digit_alternatives` filled for **every**
figure-bearing height, and a Stage B (after `rows.csv` is written) comparing every non-`clear` leading digit
against unambiguous same-hand instances of each candidate digit elsewhere on the pages
(`glyphs.csv`, `verdict.md`). The target is not named; it is one height among many.

Its directory (`transcription/make_reader_dir.sh`, built in the gitignored cache): `bc77087_1`-`_5` and
`bc77070_1`-`_3`, each whole plus four overlapping 2x Lanczos quadrant crops.

**Amended from the approved plan before anything was read: `bc77070_4` is withheld.** The plan listed
`bc77070_1`-`_4`. `bc77070_4` is the same project and place ("Swan Lake Grinrod", per
`data-raw/flying_height_logbook_strips.csv`) at a clear 3.8, so a reader matching place names would read
the disputed page's height off it. That is the context the issue rules out as evidence. `bc77070_1`-`_3`
(Chilako River, Stuart River, Lamming Mills) carry 7s in the height column and stay.

No catalogue value, prior read, issue, note or place-to-height association reaches it.

### Control gate

`transcription/score.R` consolidates the reader's rows with fly#93's `consolidate.R` and compares the height
at every final covered by an existing row on the seven control pages (`bc77087_2`-`_5`, `bc77070_1`-`_3`;
419 frames). **Pass:** no frame where the reader's height differs from the existing row's (or where the
reader gives one frame two heights), and the reader covers at least 90% of the 419. **Fail voids the
read:** verdict `unsettled`.

Exercised before the read on synthetic outputs (scratch only): the existing rows themselves -> PASS, 419/419,
`settled 3.8`; one control row moved to 3000 -> FAIL, 12 mismatches, `unsettled`; target `uncertain 3/7`
with Stage B deciding 7 and one same-hand `yes` reference -> `settled 7.8`; deciding 3 with no supporting
reference -> `unsettled (no commitment)`; no decision -> `unsettled`.

### Target and verdict

The target is the figure-bearing row on `bc77087_1` with the lowest first final (line 1). The reader
**commits** to its leading digit if either:
- it marked the digit `clear` in Stage A; or
- `verdict.md` decides a digit for that row in Stage B **and** `glyphs.csv` holds at least one reference for
  that digit judged `same` hand whose `resembles_disputed` begins `yes`.

Then, with the gate passed and the rest of the figure read as `.8`:
- commits to 3 -> **settled 3.8**;
- commits to 7 -> **settled 7.8**;
- anything else (declines, leans, `undecided`, another digit, a different remainder, gate failed) ->
  **unsettled**.

No lean counts, fly#97's included. The decided digit is copied by hand from `verdict.md` into `score.R`'s
second argument; everything else is computed.

**Limitation, stated now:** all three readers are Claude subagents of one model family. Three such reads
are not three independent human reads, and a shared bias in how this glyph is seen would not show as
disagreement.

### Outcomes

- **settled 3.8.** Only the `note` of file line 656 changes (`height_ft_interpreted` stays 3800), so both
  generators re-run from frozen copies must leave every `inst/extdata` output byte-identical. Prose moves
  from "contested" to "settled at 3.8 by a third blind read".
- **settled 7.8.** File line 656 becomes `7.8` / `7800`, its note recording the three reads. Re-run
  `data-raw/height_calibrate-lower_tail_rolls.R` and `data-raw/height_measure-image_overlap.R`; ship the
  regenerated `flying_height_above_ground.csv` and `flying_height_image_overlap_*.csv`. A new issue
  takes A2(5)'s shape decision (fly#95: 2,377 / 1,158 = 2.05 is near x2). **If `flying_height_rolls.csv`,
  `flying_height_rolls_excluded.csv` or anything else `fly_footprint()` reads changes, stop and ask.**
- **unsettled.** File line 656 keeps 3.8, and its note records the third read. Prose says three reads, and
  the unsent draft to the province is the remaining route.

In every outcome the 7,800 ft counterfactual test stays (it recomputes a relation, not a read), and the
bodies of fly#95 and fly#99 are revised where they cite the contested read.

## Amendment A1 (2026-10-07) — from the plan review (`review-plan.md`), before anything was read

Nothing has been read: no reader has been spawned, and the reader directory built at `ae14556` was deleted
unread. The reviewer did not open any logbook image. Every change below makes the instrument stricter or
the scoring total; none changes what an outcome ships.

1. **The reader is a Plan-type subagent (B1).** The project `CLAUDE.md` names both prior reads and fly#97's
   lean. A canary, asked only from context with no tools, answered: general-purpose — "bc77..." yes,
   "Swan Lake" no, "3.8/7.8 digit" **yes**; Plan — no, no, no. So a general-purpose reader would be primed.
   A Plan agent has Read but cannot write, so it returns its CSVs as fenced text, and the orchestrator writes
   them verbatim to the reader directory. It stays a blind subagent, as decided at the gate.
2. **All of `bc77070` is withheld (B2).** Its row for `bc77070_3` (file line 894) records "'Swan Lake -
   Grinrod' struck ... Op 94 struck" over a 7.5: the same project, Op and date as `bc77087_1`, cueing 7, as
   `_4` cued 3. The set is `bc77087_1`-`_5`, and the gate drops to 211 frames on `bc77087_2`-`_5`. **No leading 3
   is left in a height column of the set** (heights there: 7.5, 6.5, 6.3, 5.6, 6.0, 5.5, 8.0, 7.5, 8.7), so
   same-hand 3s can come only from dates, frame numbers and the like. Recorded, not remedied: the only
   remedy would put a cue back in.
3. **Crops are a 3 x 3 grid** of 40% x 40% windows at 0/30/60%, 2x Lanczos, about 800 x 964 px (0.77 MP), so
   the enlargement is not undone by downsampling (A3; the first script's 2x2 crops were 1200 x 1446 and
   its "10% overlap" was 20%). 10 images per page, 50 in all.
4. **Two turns (G6).** Stage A (`transcription/transcriber_brief.md`) is sent alone and does not mention a
   glyph comparison. Its `rows.csv` is written and hashed. Then `transcription/brief_stage_b.md` is sent to the
   same agent (SendMessage). Both texts are fixed by this commit. The brief's example is `5/6`, not `1/7` (G7).
5. **The figure is read from a dedicated column (G3).** `height_digits` writes every uncertain digit as `?`.
   The remainder test is on `height_digits` after its first character, and it must be `.8`.
6. **Stage B output is machine-read (G4).** `verdict.csv` (decision, lean, ref_ids) and `glyphs.csv` (ref_id).
   A Stage B decision commits only if:
   - every cited ref_id exists for this target row (file **and** frames);
   - at least one cited same-hand reference resembles the glyph (`yes`); and
   - the decided digit has **more** same-hand `yes` references than every other candidate.

   `clear` with alternatives listed is no commitment. No digit is copied by hand.
7. **Scoring is total (G2).** `score.R` coerces finals to integers and heights to numbers (commas allowed)
   and is case-insensitive. On a control page it fills a blank `focal_mm` on a line from the page's single
   written focal, so ST/END lines merge as fly#93's did. Any error, missing file or missing column is
   `unsettled (scoring error)`. Exercised on 13 synthetic outputs (scratch only):
   - clear 3 -> `settled 3.8`; clear 7 -> `settled 7.8`;
   - one control row moved -> gate FAIL, `unsettled`;
   - heights written with commas -> PASS; a finals cell "96?" -> covers 203/211 (0.962), PASS;
   - clear with alternatives, a tie with a competing digit, a cited ref missing, `undecided` with a lean,
     no `verdict.csv`, a remainder of `.6` -> each `unsettled` with its reason;
   - a missing column -> `unsettled (scoring error)`;
   - an uncertain digit, decided 7 with 2-to-0 support -> `settled 7.8`.
8. **Compliance audit (G5), run before scoring.** `transcription/audit.py` parses the reader's transcript and
   passes only if every tool call is a Read of a file inside the reader directory and every one of its 50
   images was read. Exercised:
   - the plan review's transcript: 45 calls, all flagged;
   - a decoy Plan reader that read two generated images: PASS;
   - the same with a third, unread image added: FAIL, naming it.

   The directory has a neutral name outside the repo (`<scratchpad>/pages_q`). Its md5s are recorded here
   before spawning.
9. **Re-spawn policy.** A read the audit fails may be re-run **once**, with a fresh reader. A failed gate,
   a scoring error caused by the reader's output, and any verdict are final.
10. **Generators run in place (G9),** from frozen copies in the scratchpad, with md5s of all 45 CSVs under
    `inst/extdata` and `data-raw` taken before and after.
    - **Baseline (O1), on the unedited tree:** both exit 0, and all 45 come back byte-identical. The
      calibrate script's live catalogue query changed nothing.
11. **The 7.8 outcome's diff, pre-registered cell by cell (Acceptance).** Anything else changing is a stop:
    - `flying_height_above_ground.csv` `bc77087 1158` row: `frames_catalogue` 57->0, `frames_ground_plus`
      0->57, `logbook_ft` 3800->7800; `tabled`/`reason` unchanged.
    - `flying_height_image_overlap_keys.csv` `bc77087 1158` row: `frames_catalogue` 57->0, `frames_ground`
      0->57, `w2_height` -> `ground`, `size` -> `unsettled`, `location` -> `datum_question`. The overlap
      script's "STOP FOR THE USER" line is then expected, and is answered by decision 1 at the gate.
    - `flying_height_rolls.csv`, `_excluded.csv` and every other CSV: byte-identical.
    - 2,377 / (2 x 1,158) = 1.026: 2.6% off x2, outside the generator's 2% tolerance for a named factor
      (A4). The shape issue states that number rather than "ambiguous".
12. **The gate measured on the prior readers (O3, A1):**
    - fly#93's `batch4_rows.csv` and fly#97's `batchC_rows.csv` each cover 211/211 frames, 0 mismatches.
    - So the gate is reachable. It tests compliance and gross misreading, not whether a reader can tell
      a 3 from a 7.
    - It absorbs the 90-vs-96 disagreement on file line 660 (frames 96-103 match either way).
13. **Kept as approved, flagged for the user (A2).** Fixed at the plan gate: "commits to 7 -> settled 7.8"
    holds even though fly#93's read was itself a commitment to 3. A 7 now would be one commitment each way,
    plus fly#97's lean; a 3 would be two commitments to none. The outcome ships no package behaviour.
14. **NEWS (G8):** a new development entry. The released 0.23.2 entry is not edited.
15. The province draft (`province_request_draft.md`) ships in the archive under every outcome. Only under
    `unsettled` is it named as the remaining route (S1).

### Reader directory, built before spawning

`<scratchpad>/pages_q`: 50 images from `make_reader_dir.sh` at e07d371 (crops 800 x 964). md5 per file in
`transcription/pages_q.md5` (md5 of that listing: `37a451f51abb670c3a4d4bebeb129438`).
