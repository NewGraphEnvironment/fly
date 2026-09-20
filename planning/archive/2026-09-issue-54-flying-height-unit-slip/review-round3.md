# Review round 3 — fly#54 (`flying_height` checks), enumeration pass

Date: 2026-09-18. Reviewer: subagent, read-only. Nothing in the repo was modified except this file.

## Mechanism

Prose written from an impression, or from an earlier exploration, instead of being derived from the
shipped artifact at the moment of writing. It reaches seven places in this diff: the three
constant-function comments and the DEM-block comments in `R/fly_footprint.R`; the roxygen Terrain
section; the new section and table row in `inst/notes/terrain-correction.md`; the vignette paragraph;
the NEWS 0.12.0 entry; the fixture and test comments; and the `data-raw` script's comments.

## How it was checked

- `data-raw/height_calibrate-flying_height_slip.R` re-run in a scratch copy with the cache symlinked.
  Output is **byte-identical to `stage4d.log`**, both CSVs "unchanged", 4.7 s. Rows marked LOG below
  therefore have a live producer.
- CSV: independent recomputation from `inst/extdata/flying_height_sweep.csv` (7,156 rows).
- CACHE: independent recomputation from `data-raw/.cache/centroids/*.rds` (1,670,471 rows).
- RUN: `fly_footprint()` calls against `height_fixture()` / `flat_dem()` and against `main` exported
  to scratch with `git archive`.
- ARITH: recomputed by hand.
- Tests with `NOT_CRAN=true`: `test-fly_footprint_height.R` 118 expectations, `test-fly_footprint.R`
  245, `test-fly_footprint_invariants.R` 792; 0 failed, 0 error, 0 skipped.
- `man/fly_footprint.Rd` and `NAMESPACE` are byte-identical after `roxygenise()` in the scratch copy.

**No code defect found.** Also probed: no `flying_height` or `focal_length` column (pre-existing clear
error, same as `main`), zero rows, factor / character / integer64 `flying_height`. None regresses
against `main`. Bundled film, bundled digital and `terrain_fixture()` come back byte-identical to
`main` on geometry, terrain, `height_agl` and `dem_coverage`.

## Enumeration

Identical restatements of one figure are grouped in one row with every location listed.

| # | where | claim | producer | measured | verdict |
|---|---|---|---|---|---|
| 1 | R const, R DEM block, roxygen, vignette, NEWS, note, test header | 1,589 film frames slipped | LOG, CSV, CACHE | 1589 | OK |
| 2 | roxygen, vignette, NEWS, note | 13 rolls | LOG, CSV | 13 | OK |
| 3 | roxygen, vignette, NEWS | flown 1974–2005 | CSV | 1974..2005 | OK |
| 4 | note | roll list with years (bc5596 1974 … bcc05001 2005) | LOG table | matches all 13 | OK |
| 5 | NEWS, note | 1,054 of them on five rolls of 2003 | CSV | 1054 on 5 rolls | OK |
| 6 | all | factor 3.28084² = 10.764 / "about 10.76" | ARITH | 10.76391 | OK |
| 7 | R const, NEWS, note table | repaired r 0.80–1.32, median 1.05 | LOG, CSV | 0.7999–1.3162, median 1.050 | OK |
| 8 | R const, NEWS, note table | as reported 10.0–15.8 / 10.01–15.83 | LOG, CSV | 10.010–15.830 | OK |
| 9 | NEWS, note (×2) | nothing between 6.69 and 10.01 | LOG, CSV. Holds for the population: r ≤ ratio_asl and `upper_tail` is a census of >3 | 6.690 / 10.010 | OK |
| 10 | R const, NEWS, note | read as feet: 3.0–4.7 (3.02–4.71), 0 of 1,589 in band | LOG, CSV | 3.022–4.707, 0 | OK |
| 11 | R const | "only candidate that survives the terrain" | LOG. Two candidates were tested | k: all in band; feet: 0 | OK |
| 12 | R band, note table | 99.2% of the random 2,500 inside the band | LOG, CSV | 0.9924 | OK |
| 13 | R band, note | 1.42 million at ratio_asl ≤ 2 | CACHE | 1,419,822 | OK |
| 14 | R band, NEWS, note | 98.7% of all 1.44 million, population-weighted | LOG, ARITH (0.9924·1419822 + 0.58·15231 + 5) / 1437147 | 98.66%; usable film 1,437,147 | OK |
| 15 | note table | random median 1.03, 2.5–97.5% 0.81–1.25 | LOG, CSV | 1.031; 0.806–1.253 | OK |
| 16 | roxygen | "as 99% of frames do" | rows 12, 14 | 98.7–99.2% | OK |
| 17 | NEWS | at most an estimated 1.2% change; slipped 0.1% | LOG, ARITH | 1.23%; 1589/1437147 = 0.11% | OK |
| 18 | R band | upper edge sits in a trough before the mass at 2.0 | CSV: random r per 0.1 bin 1.3→2.0: 16, 3, 4, 1, 1, 0, 1; near_upper (1.6,1.8] 29 vs (1.9,2.1] 128 | trough present | OK |
| 19 | R band ("…and 0.5"), note ("0.5 is its mirror image") | lower edge sits in a trough before a mass at 0.5, which is the lens swap the other way | none in the script | random r per 0.1 bin from 0.2: 2, 2, 5, 5, 10, 38, 141 — monotone, no mass, no trough, 12 frames in (0.4, 0.625]. 7 of the 10 at r 0.4–0.6 are catalogued at 153, where the mirror reading needs 305 | **NO PRODUCER** |
| 20 | note | least favourable legitimate frames "still sit at r 1.0–1.3" | none. The log prints whole-stratum quantiles only (median 1.258) | in-band near_upper (348 of 600): median 1.05, IQR 0.98–1.15, 5–95% 0.83–1.51; 56% in [1.0, 1.3], 33% below 1.0 | **WRONG** |
| 21 | NEWS, note | mass centred on r = 2; 209 of 223 beyond r 1.8 catalogued at 153 | LOG, CSV | 223 / 209 (13 at 305, 1 at 88); median 2.02. Discriminating: 24% of all film is at 153 | OK |
| 22 | R band, NEWS, note | DEM route draws a 305-as-153 frame at twice its width; nominal route never reads `focal_length` | ARITH, code read | 0.305 / 0.153 = 1.99 | OK |
| 23 | R ceiling, NEWS, note, setup, test | highest legitimate height 14,630 m (1:90000 film) | LOG, CACHE | 14630; bc5344, 1969, 1:90000, ratio_asl 1.06 | OK |
| 24 | R ceiling, NEWS, note | highest digital 7,513 m of 223,667; none above the ceiling | LOG, CACHE | 7513; 223,667; 0 | OK |
| 25 | R ceiling, NEWS, note | bc78065 reads 4,115 m at 1:2000; lowest slipped 4,115 | CSV | 4115 @ 2000; min 4115 | OK |
| 26 | note | bc78078 9,449 m at 1:6000 | CSV | 9449 @ 6000 | OK |
| 27 | test | slipped frames sit under the ceiling (> 0) | CSV | 39 of 1,589 | OK |
| 28 | note | ceiling "today catches nothing" | CACHE | film over 16,000 m: 1,550, all slipped (1589 − 39); unusable film over it: 0; other media: 0 | OK |
| 29 | R DEM, test | every slipped 2003 frame is over the ceiling, "75 km" / "~75 km" | CSV | 69,751–79,799 m, median 72,288 | OK |
| 30 | R DEM, note | a 75 km seed asks for 100 km of terrain | ARITH on `camera_formats.csv`: width / focal median 1.30, range 0.95–1.47 | 97.6 km at the median (71–110 km) | OK |
| 31 | roxygen, vignette, R DEM, test header | a 1:35000 frame drawn 110 km across | CSV | 102–118 km | OK |
| 32 | NEWS, note | 110,834 m against 8,022 m | quoted from fly#54 (accepted) | the issue body carries both | OK |
| 33 | R DEM | digital `scale` "about a third" of true image scale (note: "a third") | CACHE | median digital ratio_asl 2.87 → 0.35 | OK |
| 34 | R DEM | holding digital height against `scale` "would refuse every one of them" | CACHE | 13,686 of 217,836 digital frames (6.3%) have ratio_asl inside the band — 42% of the 32,239 with no catalogue GSD, which are the ones the DEM route sizes | **WRONG** (quantifier) |
| 35 | R DEM, roxygen | the repair fires on the 1,589 and on nothing else, catalogue-wide | LOG + ARITH: r_fix in band needs ratio_asl ≥ 6.7, so every candidate is in the `upper_tail` census | 0 of 2,733 | OK |
| 36 | NEWS, note | 2,733 sampled frames outside the band and not slipped | LOG, CSV | 2733 | OK |
| 37 | NEWS, note | 1,208 frames on a slipped roll not themselves slipped | LOG, CACHE | 1208 | OK |
| 38 | NEWS, note | 1,963 under half nominal; 1,962 sampled as lower tail; the other was in the random draw | LOG, CACHE, CSV | 965 + 998 = 1963; 1962; 1 random frame at ratio_asl ≤ 0.5 | OK |
| 39 | NEWS, note, script | ×10.764 → 726, ×10 → 729, ×2 → 799 | LOG, CSV | 726 / 729 / 799 | OK |
| 40 | note, script | doubling rescues "a different set of rolls" | CSV | ×2: 18 rolls; overlap with the ×k or ×10 rolls: 0 rolls, 0 frames (×k and ×10 share all 16) | OK |
| 41 | note | of the 799, 519 at 305 and 280 at 153 | LOG, CSV | 519 / 280 | OK |
| 42 | note | ×10.764 scatters the 1,962 from −0.70 to 5.38; 130 below, 1,106 above | LOG, CSV | −0.703 / 5.379 / 130 / 1106 (+726 = 1962) | OK |
| 43 | note | 609 m is 2,000 ft | ARITH; CSV | 609.6 m; 609 is the most common lower-tail height (211 frames) | OK |
| 44 | NEWS, note | 1,670,471 centroids, reconciled against the catalogue's own count | LOG (live WFS hit count in the re-run) | 1670471 = 1670471 | OK |
| 45 | NEWS, note | 7,156 frames sampled | LOG, CSV | 7156 (1962 / 600 / 2500 / 2094) | OK |
| 46 | NEWS | the script reproduces every figure above | LOG re-run. Rows 5, 17, 38 derive from printed tables; row 32 is attributed to the issue | — | OK |
| 47 | NEWS | the suite checks "the three constants" | test read and run | k, band and ceiling are all asserted | OK |
| 48 | test header | "the two constants are checked further down" | same test | three are checked (row 47) | **WRONG** (count; NEWS says three) |
| 49 | script header | "the unit slip … and the two constants" | reads as slip + band + ceiling | 3 | OK |
| 50 | note | "Four things here were measured" | bullets counted | 4 | OK |
| 51 | NEWS, test-fly_footprint.R | relabelled frame was sized 2.7 km; a real 1:31680 frame is 7.7 km | RUN, `main` and branch | 2,659 m on `main`; 7,688 m | OK |
| 52 | test-fly_footprint.R | `flying_height` 2,591 m against a scale implying 4,850 m | RUN, ARITH | 2591; 31680 × 0.153 = 4,847 | OK |
| 53 | note table row | relabelling `scale` builds the disagreement the checks refuse | RUN on branch | `"implausible"`, nominal_scale | OK |
| 54 | NEWS, test, note row | every bundled frame inside the band and unchanged | RUN, `main` vs branch | all `"reported"`; WKB, agl and coverage identical | OK |
| 55 | NEWS | #58, #59 ("583 s for two frames"), #60 | `gh issue view` | all three open; 583 s is in #59's title and body | OK |
| 56 | setup | row 3 slipped value 14,424 m, a legal altitude | ARITH | round(1340 × 10.7639) = 14424, under 16,000 | OK |
| 57 | setup | row 4 window 15 km hides under row 5's 21 km | ARITH, RUN on `main` | 14,660 m / 20,813 m | OK |
| 58 | setup | row 7 window 77 km | ARITH, RUN on `main` | 77,485 m | OK |
| 59 | setup | row 8 at r = 2 | ARITH | 4000 / 2000 = 2.0 | OK |
| 60 | setup | "two deliberate defects survived the first six" rows | ARITH: row 4's window is under row 5's; row 6 is refused by the ceiling whether or not digital is compared | consistent | OK |
| 61 | setup `flat_dem`, test | the 1:90000 frame is 20.6 km across, "corrected up by ~1%" | ARITH, RUN | nominal 20,574 m; returned over `flat_dem()` 20,813 m (+1.2%) | OK (nominal figure, and the test says so) |
| 62 | test | `main` returned 9 × 0.0254 × (28288 − 700) / 0.153; "41 km here" | ARITH, RUN on `main` | 41,220 m | OK |
| 63 | test | the catalogue rounds heights to a whole metre | CACHE | every film `flying_height` is an integer | OK |
| 64 | test | band costs ordinary frames under 1% | CSV | 0.76% | OK |
| 65 | test | margins > 1.2, > 1.2, > 6 | CSV | 1.280 / 1.216 / 6.26 | OK |
| 66 | test | three remedies "comparable": max / min < 1.2, all > 600 | CSV | 799 / 726 = 1.10 | OK |
| 67 | NEWS, note, R DEM | a refused frame is withheld from the second pass | RUN, spy on `fly_dem_grid` per row | rows 4 and 7: one grid (2.7 km); rows 1–3, 5, 8: two | OK |
| 68 | NEWS, R DEM | a camera-table frame over the ceiling is never seeded | RUN, spy | row 6: zero grids | OK |
| 69 | NEWS, roxygen, vignette, note | `flying_height` is never overwritten; fh − agl is not ground on corrected rows | RUN | identical column; 26,360 and 13,784 against 700 m ground | OK |
| 70 | roxygen, NEWS | `"implausible"`: > 1.6× either way and unrepaired, or > 16,000 m, or below terrain; film falls back to nominal, digital has no footprint | RUN: r = 0.4, r = 5.3, r = 28, in band at 19,000 m, fh = terrain, fh < terrain, digital 45,000 m | all `"implausible"`; film nominal_scale at 2,743 m; digital empty | OK |
| 71 | roxygen NA list; R comment at the `height_source` init | NA: no dem / GSD-sized / no footprint for another reason / uncovered / fh or focal missing | RUN of each | all NA | OK |
| 72 | roxygen | "…except that a height above 16,000 m is `"implausible"` whatever else is missing" | RUN | true with `focal_length` NA, covered or not. Three counter-cases to the broad reading: unparseable `scale` + 28,288 m → NA; GSD-sized + 50,000 m → NA; film + focal present + uncovered + 28,288 m → NA (deliberate, tested) | OK on the narrow reading; ambiguous |
| 73 | roxygen | digital: "only the 16,000 m ceiling applies to it" | RUN: digital at 100 m under 700 m terrain | `"implausible"` — the below-terrain arm applies to digital too, as the same block's `"implausible"` item says | **WRONG** (low; "only") |
| 74 | vignette | "Where they disagree by exactly that factor the corrected height is used" | RUN: row 1 at 7.5×, 8×, 14×, 15× | 8× and 14× both come back `"corrected_unit_slip"`. Accepted range for that frame is 7.6×–14.9× | **WRONG** ("exactly") |
| 75 | vignette | bundled frames all agree with their own scale; `table(terrain$height_source)` | RUN; `terrain` is defined at l.363 with `dem` | all `"reported"` | OK |
| 76 | NEWS, roxygen, vignette | `dplyr::filter(fp, height_source != "reported")` lists the frames worth a look | RUN | rows 2, 3, 4, 6, 7 | OK |
| 77 | R warnings, test | the corrected warning says "10.76" and "N of M"; the implausible one names 1.6, 16000 and nominal scale | RUN | "2 of 8", "3 of 8"; texts as claimed | OK |
| 78 | R `unsized_digital` comment, test | a digital frame below terrain still gets the no-way-to-size-it warning; a refused one does not | RUN | both as claimed | OK |
| 79 | R DEM | no `media` column is compared as film | RUN | twins → reported / corrected_unit_slip, basis assumed_default | OK |
| 80 | R DEM (`untested`), test | a slipped frame off the DEM is `no_dem_coverage` / NA, not implausible; digital over the ceiling is refused anywhere | RUN | as claimed | OK |
| 81 | script | ~1.67 million rows | LOG | 1,670,471 | OK |
| 82 | script | "every one of 104 forked chunks aborted" | `dem.log` (5,194 frames / 50 = 104); findings.md l.171 | 104 | OK |
| 83 | script | the year loop could miss NULL `PHOTO_YEAR`; 0.1% tolerance | LOG | 0 missed | OK |
| 84 | script | `ratio_asl` is an upper bound on r; "terrain only ever lowers it"; "`r <= ratio_asl`, so all of these are outside any band" | CSV | 6 of 7,156 sit over terrain below sea level (min −0.9 m), so r > ratio_asl there by at most 0.0006. The lower-tail conclusion still holds (max r 0.4999) | **WRONG** (trivial; "only ever") |
| 85 | script | `upper_tail` = "every frame the upper check could fire on" | CSV | 252 of 600 near_upper and 3 of 2,500 random frames have r > 1.6 and are not in `upper_tail` (about 6,400 frames population-weighted). True only of the repair (row 35) | **WRONG** |
| 86 | script | slipped population "identified by ROLL and by a ratio" | code read: `set == "upper_tail" & ratio_asl > 9` | roll plays no part; the test's own comment says ratio only | **WRONG** (low) |
| 87 | script | `random` drawn before the lower tail and from a population that includes it | code read, CSV | 1 random frame at ratio_asl ≤ 0.5; lower_tail excludes it | OK |
| 88 | script | `upper_tail` and `lower_tail` are censuses | CACHE | 2094 = all > 3; 1962 = 1963 − 1 | OK |
| 89 | script | infrared stocks' heights "run higher" than digital | CACHE | Colour IR max 7,620 against digital 7,513; BW IR 5,791 | OK (by 107 m) |
| 90 | script | frames with no terrain under them: 0 | LOG | 0 | OK |
| 91 | script, LOG | "film frames 1442979, usable 1437147; everything else 227492" | CACHE | 1,442,979 / 1,437,147 / 223,667 + 3,825 | OK |
| 92 | note | repaired frames land "in the same shape" as ordinary ones | CSV | ordinary median 1.03, 0.81–1.25; repaired median 1.05, 0.87–1.23 | OK |
| 93 | DESCRIPTION, NEWS | 0.12.0, 2026-09-18 | today's date | match | OK |
| 94 | `flying_height_population.csv` | bins sum to 1,437,147; ≥ 9 sums to 1,589; digital 223,667 / 7,513 | CACHE, LOG | match | OK |

94 rows: 85 OK, 8 WRONG, 1 NO PRODUCER. No code defect.

## Findings

Ordered by how much a reader could be misled. None changes behaviour; all are prose.

1. **Row 20 — `inst/notes/terrain-correction.md`, third bullet: "still sit at r 1.0–1.3."** No producer.
   The script prints only whole-stratum near_upper quantiles. Recomputed for the 348 in-band near_upper
   frames: median 1.05, IQR 0.98–1.15, 5–95% 0.83–1.51. 56% fall in [1.0, 1.3] and 33% sit below 1.0.
   Same class as round 2's finding, and in the paragraph next to the one round 2 fixed. Either print
   the quantiles from the script and quote them, or drop the range.

2. **Row 19 — `R/fly_footprint.R` `fly_height_ratio_band()` comment ("…the next one out, at 2.0 and
   0.5") and the note's "0.5 is its mirror image."** The upper half is measured (row 18). The lower half
   has no producer. The random sample shows r counts per 0.1 bin from 0.2 of 2, 2, 5, 5, 10, 38, 141:
   monotone, with no mass at 0.5 and no trough at 0.625, on 12 frames. 7 of the 10 random frames at
   r 0.4–0.6 are catalogued at 153 mm, where the mirror-image reading (a 153 catalogued as 305) needs
   them at 305. The lower edge is 1/1.6 by symmetry ("one factor rather than two edges"), which the
   comment already says. Make that the stated reason for the lower edge and drop the claimed trough.

3. **Row 74 — vignette: "Where they disagree by exactly that factor."** Measured: fixture row 1 at 8× and
   at 14× its true height both come back `"corrected_unit_slip"`, divided by 10.764 (`height_agl` 1,253
   and 2,718 against a true 1,928). The rule is "dividing by the factor lands inside the band", which
   is how the roxygen puts it. Suggested wording: "where dividing by that factor brings them back into
   agreement".

4. **Row 34 — `R/fly_footprint.R` DEM-block comment: "would refuse every one of them."** 13,686 of 217,836
   digital frames (6.3%) have ratio_asl inside [1/1.6, 1.6], and all of them are among the 32,239
   digital frames with no catalogue GSD (42% of those), which are the ones the DEM route sizes.
   "Most" is supported (median ratio 2.87). "Every" is not.

5. **Row 85 — script Stage 3 comment: `upper_tail` is "every frame the upper check could fire on."** 252
   of 600 near_upper frames and 3 random frames have r > 1.6 and sit outside `upper_tail`. The
   statement is true of the repair only (row 35), and that is the property the census matters for.
   Say that.

6. **Row 73 — roxygen: "so only the 16,000 m ceiling applies to it."** A digital frame at 100 m under
   700 m terrain returns `"implausible"`, as the same block's `"implausible"` item says. Suggested
   wording: "so the comparison against scale is not made for it; the ceiling still is".

7. **Row 86 — script Stage 4 comment: "identified by ROLL and by a ratio."** The code is
   `set == "upper_tail" & ratio_asl > 9`, so roll is not used. The test's own comment has it right.

8. **Row 48 — `test-fly_footprint_height.R` header: "the two constants."** Three are checked further
   down, and NEWS says three.

9. **Row 84 — script Stage 2 and Stage 3 comments: "terrain only ever lowers it" and "`r <= ratio_asl`."**
   6 of 7,156 sampled frames sit over terrain below sea level (min −0.9 m), so r exceeds ratio_asl
   there by at most 0.0006. Immaterial to every conclusion: lower-tail max r is 0.4999, and the census
   argument of row 35 has a margin of 6.7 against 3. "Only ever" is measurably not so.

Row 72 is not raised as a finding. It records that the new "whatever else is missing" exception is
true only where the missing thing is `focal_length`. Read more broadly, three cases contradict it:
an unparseable `scale`, a GSD-sized frame, and an uncovered film frame with its focal length present.
The last of those is deliberate and tested. A tighter wording, "…is `"implausible"` even where
`focal_length` is missing", removes the ambiguity.

## Termination

94 claims enumerated and 85 verified against a producer. The 9 that remain are all qualitative
wording or quantifiers ("still sit at", "every", "exactly", "only", "only ever", a trough, a count of
constants). **No number quoted from the log or the CSVs is wrong this round.** Every figure in NEWS,
the note's table and the constant comments traces to a line of `stage4d.log`, which the script
reproduces byte-for-byte. After these nine are fixed, what remains open is adjective-and-quantifier
prose with no producer. A grep of the added lines for `every|all|none|never|only|exactly|still` is
the mechanical sweep for that axis.
