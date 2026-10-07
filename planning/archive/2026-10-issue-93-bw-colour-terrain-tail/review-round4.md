# Code-check round 4 (fly#93): the round-3 fix, and every "no page" / "not reached" row

Reviewer: round-4 subagent, 2026-10-06. Scope: round 3's `unspanned` state and widened unread-page
guard, then an enumeration of every excluded row carrying either reason, against the producers.
Nothing in the repo was edited apart from this file. Probes ran in a scratch copy, with the cache
symlinked back.

## Enumeration

**Producers used.**
- **Is there a page.** `FLIGHT_LOG_URL` per frame from bcdata
  (`WHSE_IMAGERY_AND_BASE_MAPS.AIMG_PHOTO_CENTROIDS_SP`, `FILM_ROLL %in%` the 16 rolls involved).
  The read returned 2,782 features, equal roll by roll to the frame counts in
  `data-raw/.cache/centroids/*.rds`, so it was complete. No URL is the empty string.
- **Does a transcribed row reach it.** `frame_from`/`frame_to` in `data-raw/flying_height_logbooks.csv`,
  by `film_roll`. They were checked against two sets of frames: the measured frames of each roll-height
  (`*_verdict.rds` `$frames`, matched by `key4`), and every catalogue frame its key reaches (centroid cache).
- **The page images**, where the catalogue links a page for frames the transcription does not reach.
  I read `bc77103_2`, `bc5546_3`, `bc79029_3` and `bc78104_3` in `data-raw/.cache/logbooks/`.

**The set.** 504 excluded rows across all tails, on 16 rolls.

| tail | reason | rows | frames | rolls | true |
|---|---|---|---|---|---|
| upper | no logbook page covers these frames | 463 | 1,271 | bcc03004, bcc03006, bcc03007, bcc03008, bcc03046, bcc05001 | 463 |
| lower | no logbook page covers these frames | 29 | 51 | bcb05001 | 29 |
| terrain | no logbook page covers these frames | 4 | 10 | bcb04001, bcc07085 | 4 |
| lower | transcribed logbook rows reach none of these frames | 1 | 52 | bc78104 (1,295 m) | 1 |
| near_upper | transcribed logbook rows reach none of these frames | 1 | 4 | bc79029 (1,676 m) | 1 |
| terrain | transcribed logbook rows reach none of these frames | 6 | 55 | bc5321, bc5546, bc7209, bc77103, bcb98001 ×2 | 6 |

**Result: 504 of 504 are true, 0 false.**

- **"No logbook page" (496 rows, 9 rolls).** The catalogue links no `FLIGHT_LOG_URL` on any frame of any
  of these rolls. None has a row in the logbook CSV, and none has a cached page. These are the same 9
  rolls as the run log's `logbook pages for 9 rolls: 0 fetched or cached, 0 failed`.
- **"Transcribed rows reach none" (8 rows).** For each, 0 measured frames fall inside any transcribed
  range, and every roll has transcribed, linked pages. The cases:
  - `bc78104` 211-262: sheet 3 of 4 ends at 201. The image confirms it.
  - `bc79029` 67-110: sheet 3 of 3 ends at 61. The image confirms it.
  - `bc5546` 195-206: the only linked page is sheet 3 of 4, ending at 160. The image confirms it.
  - `bc7209` 297-303: page 2 ends at final 296. The lines after it are DO NOT USE or TEST with no final.
  - `bc77103` 254-265: the catalogue links these frames to sheet 2, which the image shows holds 100-126
    only. The last transcribed final is 253 on sheet 3, and sheet 4 is not linked.
  - `bc5321` 168-228: the lines at 91 (6.2) and 229 (6.5) differ in height, so consolidation declined.
  - `bcb98001` 42-44: they sit between line 14 (3100, unit not established) and line 45 (no height).
  The note's account ("pages that end before their frames, or whose lines the consolidation declined to
  span") matches each of them.

**Pre-existing class (origin/main).** Main had 494 "no logbook page" rows. Two of them were false:
`lower` `bc78104` 1,295 m and `near_upper` `bc79029` 1,676 m, whose rolls have three linked, transcribed
pages. Both are now "rows reach none", which is true. The other 492 are true, and they are unchanged on
this branch. **No false "no page" row remains in any tail.**

**Note and NEWS figures.**
- **Terrain outcome table.** Recomputed from the two CSVs, every cell matches: 62/1,375, 176/2,380,
  32/472, 6/55, 4/10, 5/90, 3/99, 9/239, 1/54, 1/20, 1/10, totalling 300.
- **Near_upper table.** "rows reach none 1 / 4" matches.
- **Log.** `run_rolls.log` agrees: 120/2,958 corrected and 788/5,674 excluded. The per-reason cross-tab
  matches the CSV, A2 is 176/32/92 on 69 rolls, and the catalogue links 202 pages.
- **The 182 pages on 60 rolls.** Recomputed as the files in the branch's logbook CSV that are absent from
  `origin/main`'s: 182 files, 60 rolls by prefix and by label. Main's 450 rows are unchanged.
- **Other figures.** Overlap 0.562-0.773 and r 0.313-0.619 (median 0.5355, so 0.536) match. 4,773/298,
  374 and 60/1,344 match.
- **Tests.** `test-fly_footprint_terrain_tail.R` and `test-fly_footprint_height_rolls.R` pass in the copy
  with `NOT_CRAN=true`.
- **Exception.** Finding 1 below.

## Findings

### 1. "No existing row of either roll table moved" is now false, in NEWS and in the note (doc does not match data)

The round-3 fix changed the `reason` of two pre-existing excluded rows. Against `origin/main`, these are
the only non-terrain lines that differ:

```
-"lower","bc78104",1295,...,"no logbook page covers these frames",...
+"lower","bc78104",1295,...,"transcribed logbook rows reach none of these frames",...
-"near_upper","bc79029",1676,...,"no logbook page covers these frames; nominal scale still applies",...
+"near_upper","bc79029",1676,...,"transcribed logbook rows reach none of these frames; nominal scale still applies",...
```

- **NEWS.** `NEWS.md:4`, in the development section, still says "No existing row of either roll table
  moved." It does not mention the reason correction anywhere. A caller who reads
  `flying_height_rolls_excluded.csv` sees two fly#60/fly#72 rows change with no note.
- **The note contradicts itself.** `inst/notes/terrain-correction.md:748-749` says "The same wording moved
  on two rows of older tails". Three lines later, `:752` says "No existing row of either table moved, the
  IR rows included."
- **Remedy.** Make both say that no verdict or tabled row moved, and that two excluded rows of older tails
  had a false "no logbook page" reason corrected (`bc78104` 1,295 m, `bc79029`).
- **Historical NEWS.** The v0.15.0 line `NEWS.md:98` ("30 with no logbook page") was false then by one
  (`bc78104`). It is a historical release note, so it is pre-existing and needs no change.

### 2. `unread_state` ignores `unspanned`, so its "most of the unread frames" comment is false on two rows (low; no shipped reason is false)

`unread_state` votes only between `conflict` and `uninterpreted`. The comment above it says the reason
"names the state most of the unread frames are in". With `unspanned` now a named state with its own
reason, two shipped terrain rows break that comment:

- `bc78033` 1,676 m has 4 uninterpreted and 26 unspanned frames, and ships "logbook height or frame range
  not read".
- `bcb90008` 1,219 m is a 1/1 tie and ships the same reason.

**The shipped reasons are true, not false.** On `bc78033` the 26 unspanned frames (196-223) sit inside a
strip whose end lines (195, 207, 208, 224) carry the scribbled "5.5" the transcriber did not interpret.
5,500 ft is the catalogued 1,676 m, so "not read" is the more faithful description.

**The same physical case is encoded two ways.** `bcb98001` 950/951 (frames 42-44) also sit between lines
whose heights were not interpreted. They ship "transcribed logbook rows reach none" only because no
measured frame of those roll-heights lands on an end line. Whether a strip interior bounded by unread
lines reads as "not read" or "not reached" depends on where the sampled frames fall.

**Remedy, either of:**
- **Change the comment, not the data.** State the precedence, `conflict` > `uninterpreted` > `unspanned`.
- **Or fix the encoding.** Classify a frame that lies between two transcribed lines of its roll, at least
  one of them with an unread height, as `uninterpreted`. That moves `bcb98001` 950/951 to "not read" and
  leaves `bc78033` where it is.

Neither option changes a verdict.

### Checked, no defect

- **`unspanned` population.** `logs$film_roll` includes control rows and rows with no frame range. No
  shipped row is on a roll whose only rows lack a range, and every one of the 8 `unspanned` rows' rolls has
  ranged rows. The state is decided per roll, so a roll-height cannot mix `none` and `unspanned`.
- **Rolls with pages but no rows under their own label.** Only `bc7350` (a CONTROL page, rows labelled
  `bc7349`) has a transcribed page and no row labelled with its own roll, and it has no excluded row.
- **Arm order.** When `n_logbook == 0`, `covered < 0.5` always holds. The conflict and uninterpreted arms
  therefore pre-empt the new arm, which only matters as in finding 2. A mostly-unspanned roll-height with
  `n_logbook > 0` falls to "covers under half", which is true.
- **The widened guard compares like with like.** `linked_pages` and `fetch_logbooks()` both name files
  `FILM_ROLL__basename(URL)`, and `logs$file` uses the same form. The IR pages (`bci12__bcir12_1.jpg`) match.
- **Two latent ways the guard can stop.** Both fail loud, and neither is reachable with today's 69 rolls:
  - a terrain roll that is also a CONTROL roll, whose transcribed file is `CONTROL_`-prefixed;
  - a page shared between two rolls and transcribed under the other roll's prefix, as
    `bc5597__bc5596_5597_3.jpg` is.
- **Whether the guard can stay silent.** Its catalogue read is the same paged bcdata `collect()` that
  returned 46,046 features in round 3. On this run it listed 202 pages, which agrees with the log. It
  cannot fire for other tails by design, and the enumeration shows no false row there today.
