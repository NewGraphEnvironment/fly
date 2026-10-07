# Code-check review, round 3 (fly#93), diff origin/main...HEAD

Verdict: one bug, the same class as round 2's, which the round-2 guard cannot see. Also one
stale table in the planning findings and one gap in the guard's scope that has no effect today.
Batch 6, the guard's placement and every published figure check out.

## Mechanism

The round-2 reading is right but incomplete. Both defects so far, and the one below, come from
a single encoding. **`settle()` writes "none" for any frame that no consolidated row reaches,
and the reason table turns "none" into "no logbook page covers these frames".** So every
upstream step that withholds coverage reaches the shipped CSV as a claim that no page exists:

- round 2: a page that was fetched but never transcribed;
- here: a page that was transcribed, where strict consolidation declined to span the frames.

Strict consolidation is an accepted tradeoff, and withholding coverage is the intended effect.
What is not intended is that the withheld coverage shares an encoding with "no page". That
breaks the generator's own four-state contract ("never folded into 'no height'"), and the
CLAUDE.md rule that an absent measurement never shares an encoding with a real one.

Part (a) of your reading, a set derived once and never re-derived, did not reproduce. The round-2
fix carried every downstream set through (checked below). Part (b), an absence asserted from a
probe rather than from the producer, is what happened here. The producer that settles "is there a
page for this frame" is the catalogue's per-frame `FLIGHT_LOG_URL`. Neither the generator nor the
round-2 guard consults it.

## Enumeration

The instrument for "which page logs this frame" is the producer itself: the catalogue's
`FLIGHT_LOG_URL`, per frame, queried 2026-10-06 for all 218 terrain rolls. That is 46,046
features, saved in my scratchpad as `terr_urls.rds`. The cache was listed with `list.files()`.
Frame states were read from `data-raw/.cache/terrain_verdict.rds`, written 16:52:02 by the final
run, before the CSVs at 16:53:12.

### 1. Every terrain row's reason: 300 roll-heights

| set | rows / frames | result |
|---|---|---|
| tabled | 62 / 1,375 | Figures hold: 60 BW/colour with 1,344 frames; overlap 0.562-0.773; `r` 0.313-0.619, median 0.5355; partial agreement on `bc5225`, `bc5595` 2651, `bc78104` exactly; the five pre-read rows and two IR rows as stated. |
| A2 "fits nominal" / "cannot fit" | 176 / 2,380, 32 / 472 | Agree with the A2 recompute (round 2). The reason takes precedence, so pages do not matter. |
| no logbook page covers these frames | **10 / 65** | 4 rows, 10 frames, **true**: `bcb04001` 1222 and 1223, `bcc07085` 1239 and 1241 have no `FLIGHT_LOG_URL` on any frame. 3 rows, 31 frames, **true**: `bc5546` 1828, `bc7209` 3505 and `bc77103` 2286. The catalogue links them to a page that ends before them (sheet 3 of 4: 1-160; sheet 2 of 3: "photo nos 252-296"; sheet 3 of 4: ends at 253). The sheet that logs them is not linked. 3 rows, 24 frames, **FALSE**: see Finding 1. |
| logbook height or frame range not read | 5 / 90 | All true: `bc5541`, `bc78033`, `bcb90008`, `bcb98001` 949 and `bcc195`. |
| not a named multiple | 3 / 99 | True: `bc5598` 2286 has 25 of 41 agreeing; `bc77087` 1920 has 11 of 30; `bc7683` has 0 of 4. |
| spacing rejects the logbook's height | 9 / 239 | True. Page 3 of `bc77026` writes 6,700 ft = 2,042 m. `bc77072` writes 6,500 ft = 1,981 m and 6,000 ft = 1,829 m. `p_corrected` is negative on all three, and below the window on the other six. |
| different lens / writes catalogue's scale | 1 / 54, 1 / 20 | True: 54 focal conflicts on `bc82044`, and 20 scale-same on `bcb92004`. |
| logbook covers under half the frames | 1 / 10 | The wording is true: 3 of 10 frames are read. But all 7 unread frames of `bc5072` lie inside strips whose start and end lines carry different heights: 182 at 6.3 to 250 at 6.2, and 251 at 6.1 to 288 at 6.2. That is the same encoding as Finding 1. The reason does not move, because `covered < 0.5` comes first. |

The search for withheld coverage covered every frame in state "none" on a non-A2 terrain
roll-height. "Withheld" means the frame lies between two transcribed lines of its roll. That
gives 24 frames on the three "no page" rows below, plus `bc5072` (7), `bc77087` (5),
`bcb90008` (1), `bc78033` (26), `bc5225` (2) and `bc5595` (11). Only the first three have a
reason that misstates.

### 2. Every cached page on every terrain roll

- **The 69 rolls that A2 sends to the logbook (92 roll-heights, 1,952 frames).** The catalogue
  links 201 distinct pages. All 201 are cached, and all 201 are in `flying_height_logbooks.csv`:
  0 are linked but uncached, and 0 are cached but unread. Two rolls (`bcb04001`, `bcc07085`)
  have no page in the catalogue, which confirms findings.md:230.
- **All other terrain rolls (A2-excluded only).** 430 catalogue pages are uncached, and one roll
  has cached pages that were never read. Neither changes a verdict, because the A2 reason comes
  first in `case_when`.
- **The round-2 guard's scope is right for what it checks.** Its roll set is
  `a2$film_roll[is.na(a2$a2_reason)]`, computed after the fetch and before `settle()`. Control
  pages count as read. It is blind to two things:
  - pages the catalogue links but the cache does not hold (Finding 3);
  - frames that a transcribed page logs but no consolidated row reaches (Finding 1).
- **The whole cache.** 47 cached pages on 17 rolls are unread. Among table rows, they touch only
  the A2-excluded terrain roll above, plus `bc5702` (near_upper), `bc5596` and `bc78065` (upper),
  all of which predate this branch.

### 3. Batch 6 and the round-2 fix

- `consolidate()` over batch 6, minus its control, returns 52 lines and 13 rows. That is the same
  multiset, across all written columns, as the 13 rows appended to the CSV.
- The control `bc7692_5` consolidates to 99-129, 14,800 ft, 305 mm, matching its existing row.
- The CSV grew by 421 rows against origin/main (408 + 13), and its 182 new pages on 60 rolls are
  exactly the non-control pages of the six batches.
- The three reclassified rows read "spacing rejects", which is true (set 1).

### 4. Numbers in the docs

| claim | source | against | result |
|---|---|---|---|
| census table | note | `run_census.log` and the population CSV | ✓ |
| 111.8, 223.6, 285.4 and 142.7 m; 217.4 m slack; 136 frames at 0.050 m; 1,000 frames with 0 out of band; 374 on 15 rolls; 12 of 12 | note, CLAUDE.md ("112 m, then 143 m"), findings | — | ✓ |
| A2 176 / 2,380, 32 / 472, 92 / 1,952 on 69 rolls; 208 excluded | note, NEWS, CLAUDE.md | `run_rolls.log`:350 and the CSV | ✓ |
| 182 pages on 60 rolls, six controls agreeing on height and lens | NEWS, note | — | ✓ |
| 62 / 1,375 (60 / 1,344); 238 excluded | NEWS, CLAUDE.md, note | — | ✓ |
| 4,233 frames reached | note | `run_rolls.log`:2688 | ✓ |
| outcome table | note | CSV | Matches the CSV, which the test enforces. The "no page" row is 10 / 65 only because of Finding 1. |
| outcome table under "Result (Phase 5, `run_rolls.log`)" | findings.md:281-292 | `run_rolls.log` | **Stale**: Finding 2 |

### 5. Absence claims

| claim | source | result |
|---|---|---|
| "no logbook page covers these frames" | CSV, note | False on 3 rows (Finding 1) |
| "above the band: 0" | — | ✓ |
| "none is out of band" | — | ✓ |
| "No existing row of either table moved" | — | ✓ (verified in round 2, unchanged since) |
| "`bcb04001`, `bcc07085` have no page in the catalogue at all" | findings.md:230 | ✓ (producer query) |
| "0 failed" | `run_rolls.log` | ✓ |
| "the only untranscribed cached pages on the logbook-set rolls" | round 2 | ✓, now 0 |
| "only the rest had their pages read" | note:694 | Loose, because A2-excluded roll-heights on the same rolls were read too. The next sentence qualifies it, so this is not flagged. |

## Findings

### Finding 1 [bug] Three "no logbook page covers these frames" rows have a transcribed page that logs their frames

- **Where.**
  - `inst/extdata/flying_height_rolls_excluded.csv`: `bc5321` 1890 m (21 frames), and
    `bcb98001` at 950 m (1) and 951 m (2).
  - `inst/notes/terrain-correction.md`, outcome table row "no logbook page covers these frames
    | 10 | 65".
  - `data-raw/height_calibrate-lower_tail_rolls.R`, `settle()` (state "none") and the reason
    `case_when` ("`v$n_logbook == 0` ~ no logbook page …").
- **`bc5321`.** The catalogue links all 21 frames (168-228) to `bc5321_1.jpg`, which is cached
  and transcribed. It is sheet 1 of 1. Its strip 13 is logged on two lines:
  - "91 … 6.2 … 13 090 START STURGEON BANK";
  - "229 … 6.5 … 13 090 END 2 MI. E. WAHLEACH LAKE".

  So frames 92-228 are logged on one strip, whose start and end lines write different heights.
  Strict consolidation correctly declines to span them. `settle()` then puts the frames in
  "none" rather than the "conflict" its own comment defines for this case ("covering rows with
  heights that disagree; left unread, not guessed"). The correct reason is "logbook rows covering
  these frames disagree".
- **`bcb98001`.** The catalogue links frames 42-44 to `bcb98001_2.jpg`, which is cached and
  transcribed. Its only line is "014 … 3100 … Start" / "045 … End". The 3100 was not interpreted
  (`height_ft_interpreted` is blank), so no row spans 14-45.
  - Frame 45 is reached by the literal "45" row and reads "logbook height or frame range not
    read" (roll-height 949).
  - Frames 42-44 are on the same logged line and read "no logbook page covers these frames"
    (950, 951).
  - So one line of one page gives three per-frame roll-heights two different reasons.
- **The evidence was already on hand.** findings.md:277 already describes `bcb98001` as a page
  "whose lines carry no height or no finals".
- **Why it matters.**
  - This is round 2's defect class, an absent reading shipped as an absent page, arriving by a
    path the round-2 guard cannot see: every page here is transcribed, so the guard passes.
  - It also matters for verdicts later. Read at the height its own start line writes, each row
    would meet every other condition:
    - `bc5321`: 6,200 ft is exactly the catalogue's 1,890 m; the lens is 153; `p_corrected` is
      0.628, inside the 0.557-0.780 window; `p_nominal` is 0.798, outside it.
    - `bcb98001`: 3,100 ft is within 0.6% of 950 and 951 m; `p_corrected` is 0.652 and 0.661;
      `p_nominal` is 0.806 and 0.805.
  - Withholding them is the accepted tradeoff. Telling a later reader that no page exists sends
    that reader away from the one place a follow-up should look.
- **Fix.** Encode withheld coverage as its own state, in `settle()`.
  - **Rule.** A frame on a roll with transcribed rows on both sides of it, or, better, a frame
    whose catalogue-linked page is in `logs$file`, is "uninterpreted", or "conflict" where the
    bracketing lines carry different read heights. It is never "none".
  - **Effect on `bc5321` and `bcb98001`.** They move to "disagree" (21) and "not read" (3).
  - **Effect on `bc5072`.** Its unread state changes too, but its reason does not, because
    `covered < 0.5` with `unread_state == "conflict"` would then read "logbook rows covering
    these frames disagree". Pick one of the two outcomes and record it.
  - **Docs.** Correct the note's table, which becomes "no logbook page" 7 / 41, plus the rows the
    frames move to. The test's stems already cover both destinations.
  - **Regression test.** Add a test that no "no logbook page" row has a frame between two
    transcribed lines of its roll.
  - **Cheaper alternative.** Keep the encoding, and change the reason wording to "no transcribed
    row covers these frames", which is what the predicate actually tests.

### Finding 2 [docs] The findings.md "Result (Phase 5, `run_rolls.log`)" outcome table is stale

- **Where.** `planning/active/findings.md:281-292`.
- **What.** It still reads "no logbook page covers these frames | 13 | 240" and "spacing rejects
  the logbook's height | 6 | 64". The `run_rolls.log` it names now produces 10 / 65 and 9 / 239.
- **Why it matters.** The round-2 section says pre-fix figures "are now annotated in place", but
  this table was not. It also has the "13 / 240" row from before round 1. The archive README
  treats findings as the measurement record, so a reader takes the table under the "Result"
  heading as current.
- **Fix.** Annotate the table in place, as the other four lines were.

### Finding 3 [guard scope] The round-2 guard checks cached pages, not the pages the catalogue links

- **Where.** `data-raw/height_calibrate-lower_tail_rolls.R:377-390`.
- **What.** Pages are fetched only for rolls with no cached page at all
  (`setdiff(want, cached)` at roll level), and `fetch_logbooks()` reports failures without
  stopping. So a page that failed to download, on a roll with other pages cached, is never
  retried. It is also invisible to the guard, which lists only the cache. Its frames would then
  ship as "no logbook page covers these frames": the same mechanism as Finding 1, arriving
  through the fetch.
- **No effect today.** The producer query above shows all 201 linked pages of the 69 rolls
  cached and read.
- **Fix.**
  - Have `fetch_logbooks()` return `u`, and run it for every roll in the logbook set, not only
    uncached rolls: cached files short-circuit, so this costs one WFS query.
  - Stop on any `FILM_ROLL__basename(FLIGHT_LOG_URL)` absent from the cache, or on any failed
    status.
