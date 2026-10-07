# Code-check round 4 — terminating enumeration (fly#95, HEAD 58eb850)

Reviewer: subagent, read-only (computations in scratchpad R; the only file written is this one).
Producers used: `inst/extdata/flying_height_above_ground.csv` (ag), `_terrain_nonpositive.csv` (np),
`_terrain_frames.csv` (cf), `_rolls_excluded.csv` (ex), `infrared_film_frames.csv`,
`data-raw/flying_height_logbooks.csv` (lb), `data-raw/.cache/logbooks/` (page cache),
`data-raw/.cache/centroids/` (catalogue), `run_rolls.log`, `run_census.log`, window 0.557-0.780.
`a2a` = ex rows with tail `terrain` and reason starting "spacing fits nominal scale, which no logbook".

## Findings (all prose/comment; no code defect)

1. **[fragile] inst/notes/terrain-correction.md:814-815** (entry 14) — "the other rolls' pages were never
   fetched, because only `supports` goes to the logbook". True of 127 of the 128 rolls. `bcc07085`
   (population key 1243 m, 1:3000, 1 frame, undecided) was sent to the logbook by fly#93 on its 1239/1241
   keys; the catalogue links no page for it (ex: "no logbook page covers these frames"), so it has no page,
   not an unfetched one. Computed: population rolls with no cached page = 128; of them, rolls some tail sent
   to the logbook = 1 (bcc07085). Same mechanism (a property of 127 stated of 128). Suggest: "the other 128
   have no transcribed page: 127 were never fetched, because only `supports` goes to the logbook, and the
   catalogue links none for `bcc07085`".
2. **[fragile] inst/notes/terrain-correction.md:791-792** (entry 9) — "Rows already transcribed for #60 to
   #93 are joined to every frame and reported, but gate nothing." The one roll-height that reaches the gate,
   `bc5602` 1219, is gated by rows that were already transcribed (progress.md: "Phase 4 skipped (bc5602
   already transcribed)"); its reason is "logbook does not put the ground under the catalogued height". The
   words name all already-transcribed rows; the claim holds only for those outside `supports`. Suggest:
   "...are joined to every frame and reported; outside `supports` they gate nothing."
3. **[fragile] data-raw/height_calibrate-lower_tail_rolls.R:451-452** — "only they can table, so only their
   pages are read". The wording round 3 fixed in the note ("the logbook is read only where spacing
   supports": fetched only there, joined everywhere) survives in this code comment: Stage 6 `settle(agl, ...)`
   reads (joins) the transcribed rows of all 26 transcribed population rolls, 576 frames in `read` state on
   32 roll-heights. Suggest: "so only their pages must be fetched and transcribed".
4. **[fragile] CLAUDE.md:414** (entry 45) and **tests/testthat/test-fly_footprint_above_ground.R:2-3**
   (entry 70) — "`test-fly_footprint_above_ground.R` recomputes it" / "Everything is recomputed from what
   [the two scripts] shipped". The test recomputes the spacing side of the CSV (`frames`,
   `frames_nonpositive`, `frames_base`, `ratio_asl`, `overlap_agl`, `overlap_nominal`, `spacing`) from the
   census files. The logbook side (`frames_logbook`, `frames_catalogue`, `frames_ground_plus`,
   `frames_ambiguous`, `frames_ground_header`, `frames_other`, `frames_focal_conflict`, `logbook_ft`),
   `frames_outside`, `tabled` and the `supports` reason are only checked for internal consistency (sums,
   `>= 0`, all FALSE, bc5602's literal values), not recomputed — they cannot be from shipped files, since the
   per-frame logbook join is not shipped. NEWS states it correctly ("recomputes the spacing verdict and the
   note's tables"). Suggest CLAUDE.md "recomputes its spacing verdict and pins the rest"; test header
   "The spacing verdict is recomputed from ... and never trusted; the logbook columns are held to their sums".
5. **[fragile] inst/notes/terrain-correction.md:828** (entry 18) — "The rule asked for a page that says
   'ground'". The rule (note:792-794, findings "Witness L", code `rel_ground_plus` / `ground_header`) has two
   arms: a header naming the ground, or a page height whose median `h - elev` is within 10% of the catalogued
   height, which need not say "ground". The conclusion ("no transcribed page does") holds for both arms
   (ground_plus 0, ground_header 0); the description names one arm for the rule. Suggest "asked for a page
   that puts the ground under the height".

## Round 3's fixes (58eb850)

- Note rule bullets (entries 8-11): checked against code; defects 2 above (and 3, in the code comment
  the fix did not reach). Otherwise OK.
- "558 of the 576 frames it reads" / "26 of the population's 154 rolls" / "32 roll-heights with a frame the
  logbook reads": all recompute (below). Finding 1 sits in the new sentence.
- "2.00 to 2.58, median 2.16, 51 within 2% of x2": recomputes.
- Code: `n_unread` split into `n_conflict` / `n_uninterpreted`, precedence identical to Stage 5's
  `unread_state` (conflict where `n_conflict >= n_uninterpreted & n_conflict > 0`, then uninterpreted, then
  unspanned / none only where `n_logbook == 0`, then under half). OK. Only `supports` rows reach these arms,
  and bc5602 is fully read, so no shipped row moves.
- New source-tree test: skips under an installed check (path absent), runs from the tree. OK.

## Per-entry table

Abbreviations: ag/np/cf/ex/lb as above. "OK" = words' set and figure recompute; "N/A" = rule, pointer or
reasoning with no count (rule statements checked against code).

| # | words name (set, quantity) | computed | verdict |
|---|---|---|---|
| 1 | provenance line; two groups left by fly#93 | Stage 3c computes, Stage 6 writes ag; census writes np | OK |
| 2 | r<=0 frames: 374; drawn at nominal with warning | nrow(np)=374; fly_footprint `unusable` warning, `terrain[unusable] <- "nominal_scale"` | OK |
| 3 | roll-heights where A2 found nominal fits: 176 | nrow(a2a)=176; log l.350 "176 fit nominal (2380 frames)" | OK |
| 4 | bcc285 1707: 106 of group 1, 39 of group 2 | ag bcc285 frames 145, nonpos 106; key in a2a; 145-106=39 cf frames | OK |
| 5 | roll-heights 188; every frame either census file holds on them 2,956 | nrow(ag)=188; sum(ag$frames)=2956 = cf+np on keys; IR on keys 0 | OK |
| 6 | two groups 2,754; +202 above ground on 8 keys an r<=0 frame reaches, not A2(a) | 374+2380=2754; non-a2a keys 12, above frames 202, keys with >0: 8 | OK |
| 7 | nothing changed in package; formulas | `git diff main...HEAD -- R/ rolls csvs` empty; sides FORMAT_M*H/f, FORMAT_M*S | OK |
| 8 | logbook decides only at supports; fetched/transcribed only those rolls | `agl_rolls` = supports rolls into `want` and `terr_rolls` guard | OK |
| 9 | already-transcribed rows joined everywhere, gate nothing | bc5602's already-transcribed rows gate it | WRONG (finding 2) |
| 10 | ground arm: median h-elev within 10%, or ground header | code `rel_ground_plus` per key+log_ft; `ground_header` also requires figure within 2% of catalogue (implicit in "put the ground under the catalogued height") | OK (rule) |
| 11 | tabling rule; spacing table 1/24/23, 126/1562/174, 61/1370/177 | code `tabled`; aggregate(ag) gives exactly these; outside frames all BW/colour, in band or no terrain (13,231 catalogue frames = frames+outside) | OK |
| 12 | bc5602 page: 4,000 ft on all 24, =1,219 m, M.S.L. header | lb bc5602_2.jpg frames 46-69 (24) 4000 ft, "TRUE HEIGHT (M¹/M.S.L.)"; 4000*0.3048=1219.2 | OK |
| 13 | ground under 23 of them 1,234-1,591 m | np bc5602: 23 frames, elev 1233.6-1591.4 | OK |
| 14 | 558 of 576 read; 26 of 154 rolls; the other rolls never fetched because only supports | 550+8=558, sum(frames_logbook)=576; 154 rolls, 26 in lb; 127 of 128 never fetched, bcc07085 has no linked page | WRONG (finding 1) |
| 15 | transcribed headers M.S.L. or no datum; none names ground | headers on the 26 rolls: blank 4, "True Height" 2, rest M'/M.S.L.-type; ground regex 0 over all lb | OK |
| 16 | 32 roll-heights with a read frame; 550/8/18/0 | sum(frames_logbook>0)=32; catalogue 550, ambiguous 8 (bcc544 1615, elev 94-324 m), other 18, gp+gh 0 | OK |
| 17 | bc5602, bc77026, bc77072, bc77087: M.S.L. figure below ground under some frames | per-frame join, h_lb < elev: exactly these 4 rolls (23/7/3/38 frames), headers M.S.L.-type | OK |
| 18 | rule asked for a page that says "ground"; no transcribed page does; not amended | gp 0, gh 0; findings lists no amendment; but rule has two arms | WRONG-wording (finding 5) |
| 19 | p_agl identity; every frame in band ASL; under 1.6x | identity exact (linear in p_nom, medians commute; test 1e-9); ratio_asl 0.628-1.593 | OK |
| 20 | readings differ by abs(ratio_asl-1) | sides ratio = ratio_asl | OK |
| 21 | 126 undecided: median 0.120, q90 0.352, max 0.494; 494 of 1,562 frames >20% | 0.120 / 0.352 / 0.494; sum(frames[d>0.2])=494 of 1562 | OK |
| 22 | 52 refutes where nominal fits; median 0.028 out; 23 under 0.02; r<=0 table 174/20/23/157 | 52; 0.0275 -> "0.028"; 23; 174 / 20 / 23 / 157 | OK |
| 23 | misplaced centroid gives r<=0, invisible to spacing | reasoning | N/A |
| 24 | fly#97 | open, "Frames under terrain where spacing rejects both nominal scale and the height read as above ground" | OK |
| 25 | `factor != 1` branch reaches r<=0 frames | `out_of_band` includes r<=0; `tabled` arm `tab_factor != 1 & in_band(r_tabled)` has no r>0 condition | OK |
| 26 | 374 r<=0: (H+elev)/H 2.00-2.58, median 2.16; 51 within 2% of x2 | 2.0018 / 2.5788 / 2.1560; 51 | OK |
| 27 | such a page ambiguous with x2 | reasoning | N/A |
| 28 | NEWS heading | — | N/A |
| 29 | no code change; every roll table byte-identical | diff R/ and rolls csvs empty; progress md5 | OK |
| 30 | 374 frames; 176 roll-heights | as 2, 3 | OK |
| 31 | 188 roll-heights, 2,956 frames the two census files hold on them | as 5 | OK |
| 32 | rule fixed before any per-roll-height number | findings.md l.31 | OK |
| 33 | 1 / 126 / 61 | table(ag$spacing) | OK |
| 34 | bc5602 1219 m, 4,000 ft, M.S.L. header; nothing tables | as 12; all(!ag$tabled) | OK |
| 35 | 576 logbook-read frames, 558 catalogue's; none ground | as 14/16 | OK |
| 36 | in band ASL; under 1.6x | as 19 | OK |
| 37 | undecided differ by median 12%, up to 49% | 0.120, 0.494 (per roll-height, the unit throughout) | OK |
| 38 | where nominal fits, median 0.028 outside | as 22 | OK |
| 39 | np ships 374 frames | 374 rows | OK |
| 40 | nine roll-heights (157 of the 374) reject nominal too | refutes & !fits(nominal): 9 keys, 157 | OK |
| 41 | 188 = keys of 374 r<=0 and 176 A2(a); every census frame 2,956 | as 5 | OK |
| 42 | 1 / 126 / 61 | as 33 | OK |
| 43 | bc5602 4,000 ft under M.S.L. | as 12 | OK |
| 44 | 576 / 558 / none | as 35 | OK |
| 45 | test "recomputes it" (the CSV) | only spacing columns recomputed | WRONG-scope (finding 4) |
| 46 | p_agl identity | as 19 | OK |
| 47 | ratio under 1.6 | as 19 | OK |
| 48 | up to 49%; median 0.028 | as 21/22 | OK |
| 49 | ship via `factor != 1` | as 25 | OK |
| 50 | 2.0-2.6 times; 51 of 374 within 2% | as 26 | OK |
| 51 | nine roll-heights, 157 frames; fly#97 | as 40, 24 | OK |
| 52 | census scope (pre-existing) | unchanged from main | OK |
| 53 | census method (pre-existing) | unchanged from main | OK |
| 54 | ships three files incl. `_nonpositive.csv` (374 at r<=0) | Stage 5 writes 3; 374 rows | OK |
| 55 | smoke writes nothing | `SMOKE` gate (pre-existing) | OK |
| 56 | two groups (code comment) | as 2, 3 | OK |
| 57 | spacing Stage 3c, logbooks Stage 6, rule fixed first | code layout; findings | OK |
| 58 | writes ag one row per roll-height; stops rather than tabling | anyDuplicated(key)=0; `if (any(av$tabled)) stop(...)` | OK |
| 59 | rule fixed before any number | findings | N/A |
| 60 | side formulas | code `p_agl` | OK |
| 61 | supports/undecided/refutes/no_base definitions | `spacing_verdict()` | OK |
| 62 | Stage 6 per frame via `settle()` | `settle(agl, named = 1, tail = "above_ground")` | OK |
| 63 | relation definitions | `case_when` matches | OK |
| 64 | `tapply()` returns 1-d array; flattened | `as.vector(gp[...])` | N/A |
| 65 | A3, shipped frame by frame | census writes np | OK |
| 66 | np header "every in-band frame under terrain at or above the aircraft" | `stopifnot(nrow == sum(nonpos), all(H-elev <= 0), all(in_band(ratio_asl)))` | OK |
| 67 | r<=0 frames with same air base | `npos$base <- f1$base[...]` | OK |
| 68 | bc77072 flies two | np keys for bc77072: 1829, 1981 | OK |
| 69 | test-file subject | — | N/A |
| 70 | "Everything is recomputed ... spacing verdict never trusted" | logbook columns not recomputed | WRONG-scope (finding 4) |
| 71 | section title pointer | matches note heading | OK |
| 72 | window = central 95% of in-band random frames at reported height, #89 air base | test `agl_window()` = generator's `p_window`, round to 0.557/0.780 | OK |
| 73 | population both census files on keys; 374 on 15 rolls, 16 roll-heights | 374, 15 rolls, 16 keys | OK |
| 74 | 2,535 on A2(a) keys, 219 r<=0 elsewhere, 202 above on 8 of other 12 keys | 2535 (2380 cf + 155 np), 219, 202 on 8 of 12 | OK |
| 75 | shipped base rounded to 0.1 m | `num(base, 1)` | OK |
| 76 | r<=0 frames move no A2(a) verdict; nominal fits on all 176 | fits(overlap_nominal) on 176 of 176 a2a keys | OK |
| 77 | bc5602 4,000 ft (1,219 m) every frame, M.S.L. | as 12 | OK |
| 78 | none of the read frames has ground under; 32 / 576 | as 16 | OK |
| 79 | transcription is data-raw, not installed | `skip_if(!file.exists(...))` | OK |
| 80 | every roll with a read frame is transcribed | 24 rolls with read frames, all in lb | OK |
| 81 | no transcribed header names the ground | regex over all 871+ lb rows: 0 | OK |

### Added (missed by the extraction)

| # | sentence | computed | verdict |
|---|---|---|---|
| A1 | CLAUDE.md:107-108 "A re-run from an intact cache takes under a minute and must leave the first two byte-identical" | progress.md: 24 s, md5 identical | OK |
| A2 | note:808 "fits the window read as above ground (0.631) and not at nominal (0.510)"; "(153 mm, 1:6000)" | ag bc5602 overlap_agl 0.631, overlap_nominal 0.51, 153, 6000 | OK |
| A3 | note:854-856 "The last row is nine roll-heights: [list]" | refutes & !fits(nominal) keys = the 9 listed | OK |
| A4 | note:841 "The window holds both. Nominal stays." | undecided = both fit; nothing tables | OK |
| A5 | note:836-837 "'Nothing tables' was close to certain before anything ran" | judgement | N/A |
| A6 | NEWS "the overlap read as above ground is a fixed function of nominal's overlap and flying_height / (scale x focal)" | as 19 | OK |
| A7 | NEWS "flying_height_above_ground.csv has one row per roll-height. The suite recomputes the spacing verdict and the note's tables from them." | 188 unique keys; test recomputes spacing and pins the note's three tables to the CSV | OK |
| A8 | NEWS "Nominal scale stays where it was." | no code change | OK |
| A9 | CLAUDE.md "Two things are load-bearing." | two bullets | OK |
| A10 | generator:451-452 "only they can table, so only their pages are read" | Stage 6 reads transcribed rows of 26 rolls | WRONG-wording (finding 3) |
| A11 | generator Stage 3c "Only `supports` can table, so only its rolls go to the logbook (as A2 does for fly#93)" | `agl_rolls` | OK |
| A12 | generator Stage 6 "tabled only where spacing supports, ... at least half ... 90% ... no legible lens ... no frame outside the two censuses" | `av$tabled` | OK |
| A13 | generator Stage 6 "Frames the logbook READS, not frames a row covers ..." / "Under half read: ... fly#93's precedence (Stage 5), never folded" | matches Stage 5 `unread_state` | OK |
| A14 | test:107-108 "The two predicted sides are exactly `ratio_asl` apart, so S is a function of the median nominal overlap and that ratio" | identity, asserted to 1e-9 | OK |
| A15 | test:195 "`ambiguous` frames carry the catalogue's figure too (ground near sea level)" | ambiguous requires rel_catalogue; bcc544 elev 94-324 m under 1,615 m | OK |

## Counts

81 extracted: 70 OK, 6 N/A (23, 27, 28, 59, 64, 69), 5 WRONG (9, 14, 18, 45, 70).
Added 15: 13 OK, 1 N/A (A5), 1 WRONG (A10).
Distinct findings: 5, all fragile prose/comment, none in a shipped number or in code behaviour.
