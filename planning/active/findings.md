# Findings — BW/colour frames out of the height band only through terrain (#93)

## Issue context

## Problem

Some BW and colour film frames leave `fly_height_ratio_band()` only because of the ground under them. Their catalogued `flying_height` is within the band of `scale x focal_length` above sea level, but subtracting the terrain takes the ratio above ground out of it. No roll-table rule reads them.

`data-raw/height_calibrate-lower_tail_rolls.R` cuts its strata on the ratio above sea level:

| stratum | ratio above sea level |
|---|---|
| `lower_tail` | ≤ 0.5 |
| `near_upper` | 2 to 3 |
| `upper_tail` | > 3 |

A frame in band above sea level is in none of them. With a DEM, the #54 check sends every such frame to nominal scale (`height_source = "implausible"`), whatever caused it.

fly#91 settled the infrared frames of this kind (`bc5312`, `bci12`) under a new `terrain` tail, because #89's IR census held all of them. The BW/colour ones were left out of scope there.

## How many

- In the sweep's `random` set, 12 of 2,500 frames are out of band only through terrain. All 12 are below the band and none is above it. The generator prints this line; the 2,500 are a draw from the BW/colour frames with ratio above sea level ≤ 2.
- That is 0.48%, with a Poisson 95% interval of about 0.25-0.84%.
- Scaled to the 1,419,822 usable BW/colour frames at ratio ≤ 2, it comes to roughly **7,000 frames, range 3,500 to 11,900**. This is an estimate from 12 draws, not a census.

It is not known how many of them are a wrong `scale` rather than a frame where nominal scale is right. Low flights over high ground are exactly where terrain is a large share of the reported height, so some of them may be fine as catalogued.

## What to do

1. **Census the stratum.** Take every BW/colour frame whose ratio above sea level is in band and whose ratio above ground is not. That needs MRDEM under each candidate, run as a PSOCK cluster per CLAUDE.md, and it can cover a superset first: frames whose `flying_height` minus the highest plausible terrain could leave the band.
2. **Group by roll-height, and pull and transcribe the logbooks blind.** Transcribe into `data-raw/flying_height_logbooks.csv` with the catalogue values withheld, as fly#60 and fly#91 did.
3. **Run the `terrain` tail's rule unchanged.** It is #72's near_upper rule: the logbook names factor 1, no focal-length conflict, spacing fits the reported height and rejects nominal, and no logbook scale equals the catalogue's. It was fixed in fly#91's archived findings before that read. Re-register it in writing before this census is read.

Related: fly#60, fly#72, fly#89, fly#91.


## Pre-registered rule (fixed 2026-10-06, before the exact census read and before any page is transcribed)

### What was already known when this was written, and so cannot be called blind

A coarse census in plan mode, read-only, using fly#80's cached 250 m DTM (`gdal_translate -outsize 7000
-r average` of MRDEM-30) under the nominal 9-inch square:

- ~4,750 BW/colour frames are in band above sea level and out of band on `r`.
- They sit on 293 roll-heights on 214 rolls, all below the band.
- 12 of those rolls already carry rows in `flying_height_logbooks.csv`.

Spacing on the coarse census, per roll-height median, against the window 0.557-0.780:

| at the catalogued height | at nominal | roll-heights | rolls | frames |
|---|---|---|---|---|
| fits | rejected | ~74 | 56 | ~1,520 |
| fits | fits | 37 | | |
| rejected | fits | 143 | | |
| rejected | rejected | 39 | | |

Coarse elevation against the sweep's exact elevation, over 7,147 sweep frames: 8.5 m at the median, 110 m
at the 99.9th percentile and 162 m at most.

No logbook page of a new roll has been opened, and no catalogue value has been shown to any transcriber.

### Population

Usable BW/colour film frames: the sweep's filter, spelled out as in `height_calibrate-flying_height_slip.R`.
That is `media` in `Film - BW` / `Film - Colour`, finite positive `scale_n`, `focal_length` and
`flying_height`. It is not read from `fly_film_media()`, so IR is not drawn twice; IR is #89's census.

With `nominal_agl = scale_n * focal_length / 1000`, `ratio_asl = flying_height / nominal_agl` and
`r = (flying_height - elev) / nominal_agl`:

- `elev` is the sweep's measure: the mean of MRDEM-30 DTM under the nominal 9-inch square, axis-aligned,
  built in EPSG:3005 and transformed to the DEM's CRS, `terra::extract(fun = mean, na.rm = TRUE)`.
- **`terrain`**: `ratio_asl` is in band (`fly_height_ratio_band()`, edges inclusive), `r` is not, and `r > 0`.
  This is fly#91's definition, unchanged.
- **Above the band through terrain** needs ground below sea level (`elev < flying_height - band[2] *
  nominal_agl <= 0`). Every candidate for it is read exactly. If any frame lands there, the script **stops**,
  because no rule was fixed for one. The same goes for `r <= 0`.

### Prefilter (which frames get the exact read)

Every in-band frame where either of these holds:

- `coarse_elev > flying_height - band[1] * nominal_agl - M`: within `M` of leaving the band below;
- `flying_height - band[2] * nominal_agl > -M`: within `M` of leaving it above.

Also every frame whose coarse box holds no valid cell. A coarse nodata frame is read, never excluded.

- `M` = 2 x the largest |coarse − exact| over every sweep frame with both values finite. It is computed
  in the script and printed.
- A producer line prints, over census frames, the smallest `need − coarse_elev` slack, i.e. how close
  the margin came to binding.
- The coarse DTM is rebuilt into this script's own cache with the same recipe, keyed on MRDEM's ETag.

### Controls (the script stops if any fails)

1. **The instrument is the sweep's.** Every sweep frame inside the prefilter is read exactly by this
   script's worker. It must reproduce the shipped `flying_height_sweep.csv` `elev` to 0.1 m. If MRDEM has
   changed under the sweep, this fails rather than mixing versions.
2. **Completeness.** Every sweep `random` frame that is out of band only through terrain (12 today) is in
   the census, with the same `elev`.
3. **The same air base.** `base` is computed with the generator's f1 rule (the adjacency `fly_bearing()`
   uses), and the generator asserts equality to 0.1 m, as it does for the IR census.

### The rule

#72's near_upper rule, **unchanged**, with 1 the only factor named (`settle(named = 1, tail = "terrain")`),
joined to fly#91's IR terrain frames. A roll-height is tabled at factor 1 (`scale_wrong`) only where all
four hold:

1. the logbook covers at least half its frames, and at least 90% of those name factor 1 (logbook feet
   x 0.3048 within 2% of the catalogued height);
2. no legible logbook focal length contradicts the catalogue's (to 3 mm);
3. spacing under the logbook height fits the window **and** spacing at nominal does not;
4. no legible logbook scale equals the catalogue's (to 2%).

The fly#74 sibling witness is not applied: the scale is disputed, not the height.

### Amendment A2: evaluation order (written before the exact census and the read)

Condition 3 is examined **before** any page is transcribed. A roll-height for which it **cannot** hold,
whatever a logbook says, is not transcribed. "Cannot" is decided from logbook-independent quantities only,
so A2 removes no roll-height the unamended rule could accept:

- **(a) Nominal half.** `p_nominal` in `settle()` is the median over **all** frames of the roll-height, and
  it does not depend on the logbook. If `fits(median p_nominal)`, condition 3 fails whatever is read.
- **(b) Logbook-height half.**
  - Under factor 1 the shipped height `h_true` is within 2% of `flying_height`.
  - `p_corrected` is a median over a **subset** of the frames, those whose logbook agrees.
  - For each frame with a finite `base`, overlap is monotone in height, so its value at any `h_true` lies in
    `[p_i(0.98 h), p_i(1.02 h)]`.
  - A median of any subset lies within the range of its members.
  - So if `[min_i p_i(0.98 h), max_i p_i(1.02 h)]` does not intersect the window, or no frame has a finite
    `base`, condition 3 fails whatever is read.

A roll-height that (a) or (b) excludes ships in `flying_height_rolls_excluded.csv`, with the reason that
fired, ahead of every logbook reason:

- (a): "spacing fits nominal scale; logbook not read; nominal scale still applies";
- (b): "spacing cannot fit the catalogued height within 2%; logbook not read; nominal scale still applies".

It is never "no logbook page covers these frames", because an absent read is not an absent page. Every
other roll-height is transcribed and goes through the rule above in full.

A2 applies to the whole `terrain` tail, IR included. `bc5312` and `bci12` pass it (spacing 0.594 / 0.620 at
the reported height, 0.805 / 0.807 at nominal). The diff must show both rows byte-identical.

### Audit: anything new for BW/colour?

| step | verdict |
|---|---|
| 9-inch `FORMAT_M`, window, focal tolerance, scale regex (A1), key formatting | the rule was built on BW/colour; no change |
| disjoint-tail `stopifnot` | `terrain` is in band above sea level; the other three tails are outside it. Disjoint by construction, as in fly#91 |
| `elev` against `fly_footprint()`'s own first pass | `fly_footprint()` reads the footprint rotated onto its bearing (#26) where a bearing exists. The census uses the sweep's axis-aligned square, as every tail does. A frame near the edge may classify differently in the package, and the table row reaches it there anyway, since the key is the roll-height. Recorded as an assumption carried over |

### What each outcome means

- **All four hold:** tabled, `tail = "terrain"`, `witness = "logbook"`, `height_m` = logbook feet x 0.3048.
  `fly_footprint(dem =)` then sizes these frames from that height (`corrected_roll_table`).
- **Any fails:** the row is excluded with the reason that fired, and the frames stay nominal.
- **A2(a) roll-heights** (spacing fits nominal) are where nominal scale is right: the "fine as catalogued"
  case the issue raises, where the catalogued height, not the scale, is the field that disagrees. They are
  counted and reported, and not acted on here.

### Amendments after the plan review and the smoke run (2026-10-06, before the full census)

The plan review is `review-plan.md`. The smoke run read 1,074 candidate frames from a draw, not the census.

- **A2 wording** (before any page was read). The two A2 reasons make no claim about whether a page was
  read, because whole pages are transcribed and 12 rolls already carry rows:
  - "spacing fits nominal scale, which no logbook height changes; nominal scale still applies";
  - "spacing cannot fit the catalogued height within 2%, whatever the logbook reads; nominal scale still
    applies".

  The generator also sets `accept <- accept & !a2`. That is redundant by construction and kept as the guard.
- **Self-consistent margin** (before the full census). `M` starts at 2x the sweep's worst coarse error and is
  recomputed as 2x the worst over every frame read exactly. The prefilter widens until a pass leaves `M`
  where it was. The sweep over-represents large footprints, and the coarse error grows on small ones over
  steep ground.
- **Control 3** (before the full census). A seeded draw of up to 1,000 frames the prefilter turned away, from
  the 500 m just past its lower edge, is read exactly. Not one may be out of band.
- **A3: `r <= 0`** (written AFTER the smoke run, which found 11 such frames in 1,074, on 7 rolls).
  - The pre-registration stopped the script on them, as fly#91 did. These are frames under terrain at or
    above the catalogued aircraft.
  - `fly_footprint()` holds them in its own terrain-above-aircraft case and applies a factor-1 row only
    where `r_reported > 0` (`R/fly_footprint.R`, the `tabled` condition). So the `terrain` tail cannot move
    them whatever it decides.
  - They are counted in the population CSV and assigned to no tail. A follow-up issue records them.
  - Frames above the band still stop the script.
- **S1.** The A2(a) "spacing fits nominal" roll-heights are consistent with a height recorded above ground
  rather than above sea level. That is a hypothesis, not an outcome, and it is not tested here.

## Census result (Phase 2, `run_census.log`)

| step | n |
|---|---|
| usable BW/colour film frames | 1,437,147 |
| in band above sea level | 1,389,968 |
| read exactly (2 margin passes, M 223.6 → 285.4 m) | 18,747 |
| out of band below, r > 0: **the census** | **4,773** on 298 roll-heights, 216 rolls |
| r <= 0, terrain at or above the aircraft (A3, untailed) | 374 on 15 rolls |
| above the band | 0 |
| no terrain under the frame | 23 |

- **Coarse error.** Against the sweep's 7,156 frames: median 6.8 m, max 111.8 m. Over the 18,724 frames read
  exactly: median 7.7 m, max 142.7 m. The second pass did not raise it.
- **Margin slack.** The smallest among census frames is 217.4 m of M = 285.4 m. No census frame sits more than
  the worst error inside the prefilter.
- **Control 1.** 136 sweep frames read again, max |difference| 0.050 m. That is the 0.1 m rounding of the
  shipped column.
- **Control 2.** 12 of 12 sweep random frames are in the census.
- **Control 3.** 1,000 frames read from the 500 m past the prefilter: 0 out of band.
- **By decade:** 1960s 625, 1970s 2,710, 1980s 1,318, 1990s 109, 2000s 11.

The issue's estimate was ~7,000 (3,500-11,900) from 12 draws. The census is 4,773 below the band, plus 374 at
r <= 0, which the random draw's definition (`r > 0`) also excluded.

## Dry run of the generator (Phase 3, `run_rolls_dry.log`)

A2 over the 300 terrain roll-heights, the 298 BW/colour plus the 2 IR:

- 176 fit nominal (2,380 frames);
- 35 cannot fit the catalogued height within 2% (647; 32 and 472 after code-check round 1);
- 89 go to the logbook (1,777 frames, 67 rolls; 92, 1,952 and 69 after code-check round 1). Pages were fetched for those rolls: 176 new pages, 0 failed.

**Five roll-heights are already accepted** from pages fly#60/#72 transcribed blind for their own tails:
`bc5598` 2255 m, `bc5689` 1524, `bc7211` 3505, `bc78104` 2438, `bcc544` 1768. Those readers were blind to the
catalogue but were not reading for this stratum. Nothing in the rule distinguishes why a page was transcribed.

No existing row of either table changed. 81 roll-heights on 60 rolls have no page transcribed (84 on 62 after code-check round 1). Two of those
rolls (`bcb04001`, `bcc07085`) have no page in the catalogue at all. That leaves 176 pages on 58 rolls to read (182 on 60 after round 1; batch 6 read the other six).

## Blind logbook read (Phase 4)

Five general-purpose transcribers (told not to spawn) each read about 36 pages, packed whole by roll. Each
batch was copied into its own scratch directory with the brief (`transcriber_brief.md`, archived) and nothing
else: no catalogue height, scale or lens, no repo file. Each batch also carried one page already in
`flying_height_logbooks.csv`, as a blind control.

**Consolidation (a processing step, written after batch 5 returned and before any generator run).**
- The new readers transcribed the forms literally. These forms log each strip's start (ST) and end (END)
  final on separate lines, with the height dittoed between them.
- fly#60's transcriber had written such a strip as one range. Left literal, the finals between ST and END
  would read as uncovered, and coverage (condition 1) would fail on notation.
- So the appended rows are consolidated page by page (`consolidate.R`, archived):
  - lines are sorted by first final;
  - consecutive lines at the same interpreted height and lens are merged into one range;
  - lines at different heights, or with no height or no range, are never merged, so the frames between them
    stay uncovered rather than guessed.
- The check is batch 5's control page, `bc79026_2`. Six literal lines (finals 141, 147, 148, 159, 160, 169,
  all "22.0"/ditto, 305 mm) consolidate to exactly the existing row: 141-169, 22,000 ft, 305 mm.
- The raw per-line transcriptions are archived beside the PWF as evidence.

**Read.** 1,382 literal lines from 176 pages on 58 rolls, consolidated into 406 rows (408 after the round-1 consolidation fix) and appended with
`control = FALSE`. The raw files are in `transcription/batch*_rows.csv`.

**Controls**, one already-transcribed page per batch:

| batch | page | existing row | blind read, consolidated |
|---|---|---|---|
| 1 | `bc81027_4` | 138-164, 6,500 ft, 153 | 138-164, 6,500 ft, 153 |
| 2 | `bc84029_2` | 202-249, 16,500 ft, 304 | 202-233, 16,500 ft, 304 |
| 3 | `bc81012_2` | 192-195, 8,300 ft, 153 | 192-195, 8,300 ft, 153 |
| 4 | `bc78051_1` | 1-131, 22,500 ft, 305 | 1-131, 22,500 ft, 305 |
| 5 | `bc79026_2` | 141-169, 22,000 ft, 305 | 141-169, 22,000 ft, 305 |

- Height and lens agree on all five.
- Batch 2's range is narrower. That form writes the height only on Start lines and leaves the Finish column
  blank. The consolidation as written does not extend a run through a line with no height, so the last
  strip (234-249) stays uncovered. That was left alone: the rule was fixed before this result, and a
  narrower range can only withhold coverage, so it can only exclude.

**Frame ranges against the catalogue's frame numbers.** On the median roll the logbook covers every
catalogued frame.
- `bc5546` is the exception: its page writes finals 1-160, and the catalogue holds 195-206. Those frames
  stay uncovered, so the refusal path applies; nothing is guessed.
- Low-coverage rolls (`bcb98001` 0.09, `bcb90008` 0.10, `bc5072` 0.35) are pages whose lines carry no
  height or no finals.

## Result (Phase 5, `run_rolls.log`)

| terrain tail | roll-heights | frames |
|---|---|---|
| tabled (factor 1, `scale_wrong`, logbook) | 62 (60 BW/colour, 2 IR) | 1,375 (1,344 BW/colour) |
| excluded by A2: spacing fits nominal | 176 | 2,380 |
| excluded by A2: cannot fit the catalogued height | 32 | 472 |
| no logbook page covers these frames | 13 | 240 |
| logbook height is not a named multiple | 3 | 99 |
| logbook height or frame range not read | 5 | 90 |
| spacing rejects the logbook's height | 6 | 64 |
| logbook names a different lens (spacing fits the reported height) | 1 | 54 |
| logbook writes the catalogue's scale | 1 | 20 |
| logbook covers under half the frames | 1 | 10 |

- **Tabled rows.**
  - `r_corrected` is 0.313-0.619, median 0.536. These frames were drawn at nominal, about twice the width
    the spacing supports.
  - Overlap at the logbook height is 0.562-0.773, median 0.625.
- **Partial agreement.** Three rows (`bc5225` 914 m, `bc5595` 2,651 m, `bc78104` 2,438 m) are tabled with
  the logbook agreeing on a subset of the frames: 4/7, 15/28 and 97/106. Their `r_corrected` is the
  subset median. The suite recompute assumed full agreement; it now bounds a subset row by the range of its
  frames.
- **No existing row moved.** Every row of both tables is unchanged; the diff is additions only (60 table
  rows, 238 exclusions). The two IR terrain rows are byte-identical, so A2 moved nothing that was there.
- **Reach.**
  - The terrain keys reach 4,233 catalogue frames against 1,375 measured. The rest are frames in band on
    the same roll-height, which `fly_footprint()` never hands to the table, and which the shipped census
    reproduces by key.
  - The census covers only the stratum. A key also reaches frames on the same roll-height that are out of
    band with r <= 0 (A3), and the `r_reported > 0` gate keeps those off the table.

## Guard checks (Phase 6)

These ran in a scratch copy of the package, with `data-raw/.cache` symlinked. Tests were run per file with
`NOT_CRAN=true`.

| mutation | where | caught by |
|---|---|---|
| A2's "fits nominal" reason relabelled "no logbook page covers these frames" | excluded CSV | terrain_tail A2 test (1 failure) |
| one census frame dropped | terrain frames CSV | terrain_tail reconciliation (1); height_rolls set reconciliation (3) |
| `bc5689`'s two terrain rows relabelled `near_upper` | rolls CSV | height_rolls (8) |
| `bc5598`'s row removed | rolls CSV | height_rolls, including the fixture test (9) |
| `terrain` dropped from `nu_row` | generator, re-run | terrain_tail (1) |
| one note figure changed (2,380 → 2,381) | notes | terrain_tail note-table test (1) |

The baseline was 0 failures in both files.

**Review G6.** The `nu_row` mutation moves no table row, because A2 already guarantees that every terrain
row reaching the rule rejects nominal. It is observable anyway: `bc82044` 2,743 m gets the other defect's
reason ("nominal scale already sizes it"), which breaks the tail's "still applies" contract.

The generator mutation re-run wrote its intermediate `.rds` verdicts through the symlink into
`data-raw/.cache/`. Nothing shipped reads them, and the next real run overwrites them.

## Code-check round 1 (`review-round1.md`)

Four findings, all real, none moving a tabled row:

1. **A2(b)'s bound fails where a frame's ground is within 2% of the aircraft.**
   - Fixed by treating such a roll-height as unbounded. This matches A2's own pre-registered claim that it
     excludes only what the rule could never accept, which the first implementation did not meet.
   - The fix covers the generator, the census preview and the suite recompute.
   - Three roll-heights move from "cannot fit" to the logbook: `bc77026` 2042 m (107 frames), and `bc77072`
     at 1981 m (52) and 1829 m (16). The re-run fetched six pages for them. Recording them as having no page
     was WRONG: `ls --color` defeated an anchored grep (round 2). Batch 6 reads them; see below.
   - Corrected A2 counts: 176 / **32** (472 frames) / **92** to the logbook (1,952, 69 rolls). A2 now
     excludes 208, not 211.
2. **The prefilter's upper arm as implemented is `coarse < need_high + M`.** The pre-registration wrote
   `need_high > -M`, which does not depend on the coarse elevation.
   - Recorded here as an amendment. It was written after smoke run 1, where the pre-registered arm took
     35k frames, and before the full census.
   - It is sound by the same margin argument as the lower arm, and the full run read 1,511 frames through it.
3. **Consolidation merged across lines with no height**, contrary to the pre-registered text.
   - Fixed: every ranged line now takes part in the ordering, and a run cannot cross one with no height.
   - One page changed (`bc7683_3`: one row becomes three). No verdict moved; `bc7683` 2438 m is excluded
     either way.
   - Batch 2's control now covers 202, 219 and 233, not 202-233.
4. **Doc slips.** The note's pass count: two passes, not three. The census header's "~250 m": the run's
   picture is 314 m. Both fixed.

After the fixes the generator was re-run (`run_rolls.log`). The only table change is the three
reclassified exclusions. No other row moved, and the tabled count is 62 / 1,375 as before.

## Code-check round 2 (`review-round2.md`): a defect inside round 1's fix

- **Finding 1.** Round 1's A2 fix sent three roll-heights to the logbook. The re-run fetched six pages for
  them (`bc77026_2/3`, `bc77072_1-4`), and nobody read them. The shipped reason said "no logbook page covers
  these frames", and the findings and note said the rolls had no page.
- **Cause.** My check for the pages was `ls | grep '^bc77026__'`. Here `ls` is aliased to `ls --color`, so
  the anchored grep could never match. A broken probe was read as an absence.
- **Fixes.**
  - **Batch 6.** One transcriber read the six pages blind, with control `bc7692_5`, which matched its
    existing row exactly (99-129, 14,800 ft, 305 mm). 13 consolidated rows were appended.
  - **Result.** The pages write the catalogued heights: `bc77026` 6,700 ft = 2,042 m, `bc77072` 6,500 ft =
    1,981 m and 6,000 ft = 1,829 m. Spacing rejects them at those heights, so all three are excluded as
    "spacing rejects the logbook's height". The table is unchanged at 62 / 1,375.
  - **The outcome table moves.**

    | row | before | after |
    |---|---|---|
    | no logbook page | 13 / 240 | 10 / 65 |
    | spacing rejects | 6 / 64 | 9 / 239 |

  - **Guard.** After the fetch, the generator stops if any cached page of a terrain roll A2 leaves to the
    logbook is missing from the transcription. Proven: on the tree before batch 6, the generator stopped
    naming exactly the six pages.
- **Finding 2.** Four figures in this file predated the round-1 fixes. They are now annotated in place.

Totals now: 182 pages on 60 rolls read in six batches, six controls agreeing on height and lens.
