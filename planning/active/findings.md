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
