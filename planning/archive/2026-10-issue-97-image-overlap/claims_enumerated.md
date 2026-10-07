# Claims enumerated — code-check round 3 (fly#97)

Reviewer: subagent, 2026-10-07, at `fc813da`. Candidate set built mechanically: every sentence or table
cell in the named locations stating a number, count, range or universal (sentences split by script, then
read). Every value below is recomputed from the shipped CSVs read with `na.strings = ""`, or from the
generator itself where noted. Probes ran in a `git archive` copy in the scratchpad; the repo was not
touched. "Pinned" cites `tests/testthat/test-fly_footprint_image_overlap.R` (IO) or
`test-fly_footprint_above_ground.R` (AG) by line.

Abbreviations: K = `flying_height_image_overlap_keys.csv`, P = `_pairs.csv`, ST = `_strips.csv`,
SY = `_synthetic.csv`, W = `_written.csv`, AG = `flying_height_above_ground.csv`,
NP = `flying_height_terrain_nonpositive.csv`, LB = `data-raw/flying_height_logbooks.csv`.
"five" = the five `step_overstated` keys; "nine" = the nine roll-heights.

## inst/notes/terrain-correction.md — fly#95 paragraphs edited by fly#97

| # | location | claim | set | producer | recomputed | verdict | pinned? |
|---|---|---|---|---|---|---|---|
| 1 | note:812 | catalogue's height on 669 of the 689 frames it reads | transcribed frames on 188 keys | AG `frames_catalogue + frames_ambiguous`, `frames_logbook` | 661+8 = 669; 689 | PASS | AG (669, 689) |
| 2 | note:812-813 | "and none puts the ground under it" | transcribed pages | AG `frames_ground_plus + _header` = 0 | 0 as shipped; **57 if `bc77087_1` reads 7.8** (generator re-run) | PASS as shipped; conditional, see #79 | no |
| 3 | note:813-814 | transcribed for 31 of the population's 154 rolls | rolls in AG | LB rolls ∩ AG rolls | 31 / 154 | PASS | AG:228,245 |
| 4 | note:814-815 | 26 when fly#95 ran; fly#97 transcribed the five rolls of its nine keys that had none | | LB diff vs main | 5 new rolls (bc5715, bc77070, bc7718, bc80117, bcc325), 37 rows | PASS | no |
| 5 | note:816 | The other 123 were not transcribed | | 154 - 31 | 123 | PASS | no |
| 6 | note:818 | Over the 38 roll-heights with a frame the logbook reads | AG keys | `frames_logbook > 0` | 38 | PASS | AG |
| 7 | note:822-825 | table 661 / 8 / 20 / 0 | | AG sums | 661 / 8 / 20 / 0 | PASS | AG:190 |
| 8 | note:826-828 | page's M.S.L. figure below the ground under some frames on bc5602, bc77026, bc77072, bc77087, and on bc5715, bc77070, bc7718, bc80117 "transcribed by fly#97" | rolls whose page figure < MRDEM under a census frame it covers | per-frame join LB x census | 9 rolls: the 8 named **plus bcc325** (frame 72, elev 468.5 m under a 1,500 ft = 457.2 m M.S.L. row) | FAIL (incomplete list of the fly#97 five) | no |
| 9 | note:830-831 | "no transcribed page does" (put the ground under the height) | transcribed pages | AG | as shipped yes; not under the blind reader's 7.8 on `bc77087_1` | PASS as shipped; see #79 | no |
| 10 | note:856-858 | nine roll-heights ... Spacing rejects nominal there as well | nine | AG `spacing`, `overlap_nominal` | all nine refutes, nominal outside 0.557-0.780 | PASS | AG:154 |
| 11 | note:859-861 | fly#97 measured those nine ...: where spacing rejected nominal, the catalogue's centroid step is wrong, so the rejection says nothing about the scale | nine (spacing rejected nominal on all nine) | K `w1` | step wrong on 5 (`step_overstated`); on bc7718/bc80117 the step agrees with the images (D_nominal -0.010, +0.024); bc5715/bcc325 unmeasured | FAIL (stated over 9, holds on 5) | no |

## inst/notes/terrain-correction.md — "What the frames under the terrain covered" (fly#97)

| # | location | claim | set | producer | recomputed | verdict | pinned? |
|---|---|---|---|---|---|---|---|
| 12 | note:879 | nine roll-heights, with 157 frames at r <= 0 | nine | K `frames_nonpositive` | 157 | PASS | not in this section's test (AG:154 pins the 9 keys) |
| 13 | note:879-880 | spacing rejects nominal and also the height read as above ground | nine | AG | all refutes / nominal outside | PASS | AG |
| 14 | note:880-881 | ~60% forward overlap a flight is designed to | | window 0.557-0.780 (script stopifnot) | 0.557-0.780 | PASS | no |
| 15 | note:882-883 | on 1970s rolls ... the centroids are interpolated evenly along each digitised line (fly#82) | all 1970s rolls, every line | note:1734 (fly#82): "64-77% of consecutive bases in 1965, 1975 and 1985 were equal within 0.5%", a plan-review probe | a fraction, three years, "equal within 0.5%"; interpolation and digitised lines are inference | FAIL (universal from a fraction; mechanism stated as fact) | no |
| 16 | note:885-887 | On five of the nine, the photos show the step is longer than the air base by at least x1.25 to x2.70 under any height the logbook's figure allows (bc77087 only on its contested read) | five | K `exp(-D_agl)` | 1.254 / 2.700 | PASS (qualified) | IO:241 |
| 17 | note:887 | so spacing's rejection of nominal there says nothing about the scale | five | lower bound on step error | rejection used a step wrong by >= x1.25 | PASS | no |
| 18 | note:888-889 | On those five, by the logbook's figure against MRDEM, 107 of the 112 r <= 0 frames are not over the ground photographed | 112 r<=0 frames | NP x LB, per frame | 107 reached; all 107 rows write the catalogue's figure under M.S.L.; elev >= page height on 107/107. **38 of the 107 are bc77087's, on the contested 3.8** | FAIL (count unqualified; the bc77087 qualifier is attached to the bound only) | IO:296 (string), IO:291 (count; skips under R CMD check) |
| 19 | note:889 | the other 5 have no logbook row | 5 frames | LB | no shipped row; the page covers bc77026 221-247 (blind re-read 140-258) | PASS (shipped transcription), wording see #47 | IO:292 |
| 20 | note:889 | Two were flown at ~85% overlap, where the readings cannot be told apart | bc7718, bc80117 | K `p_img`, `w1` | 0.858, 0.840; indistinguishable | PASS | IO:245 (values) |
| 21 | note:889-890 | Two have one matched pair each, too few to judge | bc5715, bcc325 | K | 2 (1) each; too_few_pairs | PASS | IO table rows |
| 22 | note:894 | Two thumbnails adjacent by number share ground | premise | | 83-97% match on the five; 0 of 36 unrelated | PASS (premise) | no |
| 23 | note:894-895 | no catalogue field enters [the shift] | | `p_of()` | dr, dc, nr, nc only | PASS | IO:42 |
| 24 | note:897-898 | at least 20 confirming 128 px patches, the shift their median | | script `measure_shift()`; fly#82 `patch_shifts(win1 = 128, step = 32)` | 20, 128, median | PASS | no |
| 25 | note:899-900 | wraps any shift beyond ~575 px (overlap under ~0.54) | | findings.md:62-63 | 1 - 575/1250 = 0.54 | PASS | no |
| 26 | note:902-903 | window must sit 114 px inside both frames, so a pair must share roughly 230 px or more of a 1,250 px side | | MARGIN 50 + 64 | 114; 2 x 114 = 228 px = overlap 0.18 | PASS (arithmetic) | no |
| 27 | note:902 | The floor is the gate's geometry | | SY | 230 px is overlap 0.18, but 0.20 (250 px shared) matches 0 of 10: the stated geometry does not by itself produce the measured floor | FAIL (causal, stronger than the arithmetic) | no |
| 28 | note:903-904 | match at overlap 0.25 and above, never at 0.20 | | SY | 0.25 10/10, 0.30 10/10, >= 0.35 50/50; 0.20 0/10 | PASS | IO:69-70 (counts, not the prose) |
| 29 | note:909 | The rule was fixed before any thumbnail was matched | | findings.md:72 | | PASS | no |
| 30 | note:909-910 | amended twice, both times before any of the nine keys was measured | all changes to the rule | findings.md:157-240, :401-403 | A1, A2 before; **the W2 residual split (`read_other`) was made after the run** (findings item 3, round 1) and changed a shipped label (`bcc325`) | FAIL (post-data change unrecorded in the note) | no |
| 31 | note:912-913 | A2 ... committed before its output was read | | findings.md:179-181 | log not read before commit | PASS | no |
| 32 | note:921 | synthetic 0.35 to 0.90: 50 of 50 matched, error under 1e-4 | p_true >= 0.35 | SY | 50/50; max err 0 at 4 dp (0.3504-0.90) | PASS | IO:65-67, :259 |
| 33 | note:922 | 0.20: 0 of 10; 0.25: 10 of 10 | | SY | 0/10; 10/10 | PASS | IO:69-70 (counts; prose unpinned) |
| 34 | note:923 | 0 of 36 compared matched (38 drawn, 2 with no thumbnail); two different rolls | unrelated | P `set == "unrelated"` | 0 / 36 / 38 / 2; same-roll pairs 0 | PASS | IO:79-81, :253 |
| 35 | note:924 | crew-written overlap, 9 rolls, median 0.018 above | gated rolls | P written x W | 9 gated, 5/5 each; +0.0178 | PASS | IO:91-92, :257 (9 not pinned) |
| 36 | note:925 | bc85054 spacing x1.7 off; \|D\| 0.548 | | P positive | k 1.730; \|D\| 0.548 | PASS | IO:258 |
| 37 | note:926 | ordinary 1970-85 keys where spacing fits, 34; median D -0.031; tau 0.220 | negative keys with >= 3 matched | P negative | 34; -0.0307; 0.2198 | PASS | IO:73-76, :249 (34 not pinned; only >= 30) |
| 38 | note:928 | tau passed its ceiling of log 1.25 (0.223) narrowly | | | 0.2198 vs 0.2231 | PASS | IO:75 (0.223 prose unpinned) |
| 39 | note:928-929 | Even on ordinary keys the step differs from the images' air base by up to about x1.25 | 34 keys | P negative, \|d\| | 95th pct x1.246, but **max \|d\| 0.346 = x1.41**; 2 of 34 keys beyond tau (x1.34, x1.41) | FAIL ("up to" from a 95th percentile) | no |
| 40 | note:929-930 | the instrument cannot see a step error smaller than that | | tau | | PASS | no |
| 41 | note:930-931 | Of 192 ordinary pairs, 31 of the 190 compared did not match, and 2 had no thumbnail | negative pairs | P | 192 / 31 / 190 / 2; fixed_pattern 0 | PASS | IO:250 |
| 42 | note:935-945 | table: pairs (matched), p_img, p_nominal, verdict, r<=0 per key | nine | K, P | all cells match | PASS | IO:192-209 |
| 43 | note:947 | The five below the window were flown as ordinary flights | five | K `p_img` against the window 0.557-0.780 | 4 inside (0.615-0.640); **bc77026 0.807 is above the window**, and its page says "Forward overlap seems excessive (75.9%)" | FAIL (stated over 5, holds on 4) | no |
| 44 | note:947-948 | photos overlap 0.62 to 0.81, and 83% to 97% of pairs match | five | K | 0.615-0.807; 82.8-96.6% | PASS | IO:230, :234 |
| 45 | note:948 | so the frames are adjacent | five | pairs_matched/pairs | >= 83% matched; a no-match is not non-adjacency | PASS | no |
| 46 | note:948-950 | step implies 0.11 to 0.42 at nominal: at nominal the step would be 1.9 to 3.0 times the air base | five | K `p_nominal`, `k` | 0.114-0.419; k 1.898-3.013 | PASS (conditional now) | IO:231, :233 |
| 47 | note:951-952 | On each, the pages write the catalogue's figure under an M.S.L. header for at least 90% of the frames they read | five | AG; LB headers | 80/80, 64/64, 12/12, 55/55, 57/57 (100%); every header "True Height (M'/M.S.L.)"; bc77087's on the 3.8 read | PASS (bc77087 qualified at :955, :996) | IO:137 (w2), not the prose |
| 48 | note:952-953 | true height above ground at most that figure, true side at most the AGL-read side | | ground >= sea level | | PASS | no |
| 49 | note:954 | No size reading brings the step down to the images' air base | five | exp(-D_agl) > 1 | holds on the 3.8 read; bc77087 at 7.8 x0.68 over sea level (qualified next sentence) | PASS (qualified) | no |
| 50 | note:954-955 | step is x1.25 to x2.70 the air base (exp(-D_agl)): the step is wrong | five | K | 1.254-2.700 | PASS | IO:240 |
| 51 | note:955-956 | bc77087's x1.39 rests on its page's contested 3.8 | | K D_agl -0.3269 | 1.387 | PASS | no |
| 52 | note:956-958 | Spacing's rejection said nothing about scale; nominal unrefuted, not confirmed | five | K `size` | nominal_unrefuted x5 | PASS | IO:152 |
| 53 | note:959 | bc77070, the largest of the five (59 r<=0 frames) | five, by r<=0 | K | 59 > 38 > 11 > 3 > 1 | PASS | IO table |
| 54 | note:959-960 | passes by 0.006; D_agl -0.226 against tau 0.220: x1.25 | | K, tau | 0.0062; 1.254 vs exp(tau) 1.246 | PASS | IO:242 |
| 55 | note:962-963 | MRDEM at or above it on 112 frames, 107 of which a logbook row reaches | r<=0 frames on the five | NP, LB | 112 (elev >= fh on 112/112); 107 | PASS | IO:236, :273, :286, :291 |
| 56 | note:963-965 | the other 5: bc77026 221, 222, 237, 247 "past the appended row's 219" and reached only by the blind re-read; bc77072 225, which no page covers | 5 frames | LB, strips, batchC | frames right; blind re-read 140-258 reaches them; no page/strip reaches 225 (last 223). **The 140-219 row is not appended: it is on main**, transcribed before fly#97; A2 appended only the five new rolls' 37 rows | FAIL (provenance) | IO:292-293, :297 |
| 57 | note:965 | are misplaced only because the verdict is made per key | | K rule | | PASS | no |
| 58 | note:967-969 | step_overstated says the step is wrong under both readings, so D_agl ... does not test the datum | | | | PASS | no |
| 59 | note:969-970 | under either reading, the catalogue's positions along each line are not the photos' | five | exp(-D_agl) | bc77070 at resolution (1.254 vs 1.246); bc77087 x1.15 at the low end on 7.8 | FAIL (unqualified restatement of #16) | no |
| 60 | note:973 | bc77087's 38 of these frames rest on a contested read | | K | 38 | PASS | table only |
| 61 | note:974-975 | headings agree on 233 of the 237 matched pairs whose strip writes a legible heading (285 matched; a strip reaches 280) | five, matched non-break | ST `dir`, `place` | 233 / 237 / 285 / 280 | PASS | IO:237-239 |
| 62 | note:975-976 | so the lines are not rotated or reversed | all lines on the five | ST | 233 agree, **4 differ** (bc77087 1-3: heading 060 vs bearing 8°; bc77072 1981 111: 200 vs 298°), 0 reverse; 43 illegible (bc77026 175-218), 5 unreached | FAIL (universal from 233 of 285, with 4 contrary) | no |
| 63 | note:977-978 | How far they are displaced is not measured | | | | PASS | no |
| 64 | note:979-980 | images read 0.858 and 0.840; step gives 0.857 and 0.843 | bc7718, bc80117 | K | 0.8582/0.8397; 0.8567/0.8435 | PASS | IO:245 |
| 65 | note:980 | Spacing rejected them because its window assumes ~60% | | AG overlap_nominal vs window | 0.857, 0.843 > 0.780; step agrees with images | PASS | no |
| 66 | note:980-982 | readings 0.001 and 0.114 apart in D, against 2 tau = 0.44 | | K gap | 0.0007, 0.1141; 0.44 | PASS | IO:247 |
| 67 | note:985 | bc77026 remarks 75.9%; images 0.807 | | K overlap_written, p_img | | PASS | IO:261 |
| 68 | note:986 | bc80117 "80% FOREWARD O.L."; images 0.840 | | K | | PASS | IO:262 |
| 69 | note:987-988 | 271/272 images 0.316; 0.61 to 0.64 on its neighbours | | P bc77070 | 0.316; neighbours 268-270 give 0.611-0.644 (the window is the test's choice: 265-270 give 0.611-0.655) | PASS (set of "neighbours" unstated) | IO:263 |
| 70 | note:988 | catalogue step 848 to 850 m on all of them | 268-271 | P | 847.9-849.6 | PASS | IO:265 |
| 71 | note:990 | bc7718 46-69 "TAHSIS", 359 km from its nearest catalogued frame | census frames 46-69 | K km_to_place | 358.98 | PASS | IO:267 |
| 72 | note:990-991 | catalogue puts frame 30 of the same roll beside Tahsis, and 46-69 in the interior | | centroid cache only (gitignored) | frame 30 at 126.860 W, 14.3 km from Tahsis; 46-69 at ~121.66 W. (Frames 31-45 of the *same key* also sit there.) | PASS (no shipped producer) | no |
| 73 | note:991-992 | 5,000 ft is exactly nominal height above ground for 1:5000 on 305 mm | | arithmetic | 1,525 m vs 1,524 m (12 in lens: exact) | PASS | no |
| 74 | note:993 | bc80117 YALE BLUFF 97 km | | K | 97.49 | PASS | IO:268 |
| 75 | note:994 | five misplaced keys 6 to 36 km | | K | 5.96-35.83 | PASS | IO:269 |
| 76 | note:997 | blind reader would not choose, leaning 7.8; fly#60's reader read 3.8 | | batchC rows; LB note | "reads most like 7.8 but could be 3.8"; LB "read as 3 not 7" | PASS | no |
| 77 | note:997-998 | At 7,800 ft its 38 frames would not be at r <= 0 | 57 census frames | census elev | max elev 1,431.6 m < 2,377.4 m | PASS | no |
| 78 | note:998 | ... its size `unsettled` | | size rule | step_overstated, W2 not msl -> unsettled | PASS | no |
| 79 | note:998 | **its page would read `read_other`** | | generator Stage 6 + W2 rule | generator re-run in scratch with only the 1-60 row at 7800: frames_ground_plus **57/57**, W2 **`ground`** -> location `datum_question`, A2(5) STOP. median(2,377 - elev) = 1,114 m, 3.8% under 1,158 m | FAIL | no |
| 80 | note:998-1000 | step bound x1.15-x1.59 over MRDEM 10th-90th pct (x0.68 at sea level), under tau at the low end | | census elev 980/1264/1367 | 1.149 / 1.442 / 1.590; 0.675; 1.149 < 1.246 | PASS | no |
| 81 | note:1000-1001 | Only its W1 label is the same either way | | | W2, size, location all move | PASS | no |
| 82 | note:1005 | fly_footprint() draws these frames at nominal, which the photos no longer contradict | 157 | | vacuous on the 2 unmeasured | PASS | no |
| 83 | note:1005-1007 | It draws them at the catalogue's centroids, which on five roll-heights are not where the photos were taken | all frames on the five (311) | logbook basis covers 107 r<=0 frames; photo leg per key, at resolution on bc77070, contested on bc77087 | 107 of 311 by the page | FAIL (set wider than basis; round 1 flagged 311 vs 112) | no |
| 84 | note:1008-1009 | some pages log the intervalometer and the speed | | LB / batchB notes ("speed 300", "interval set to max") | present | PASS | no |
| 85 | note:1010-1012 | On all seven keys the photos could measure, the step or the flown overlap was off what the window assumes | 7 | K | 5 step_overstated + 2 at ~85% | PASS | no |

## NEWS.md — development version

| # | location | claim | set | producer | recomputed | verdict | pinned? |
|---|---|---|---|---|---|---|---|
| 86 | NEWS:3 | The frames under the terrain where spacing rejected nominal scale were flown as ordinary flights | 157 frames / nine | K | ordinary on 4 keys (0.615-0.640); bc77026 0.807 above window; bc7718/bc80117 ~85%; 2 unmeasured | FAIL | no |
| 87 | NEWS:3 | it is the catalogue's centroids that are wrong | nine (cleft: exclusive) | K | step wrong on 5; on 2 the step agrees | FAIL | no |
| 88 | NEWS:3 | No code change, and every roll table is byte-identical | rolls, _excluded | git diff main | identical; `flying_height_above_ground.csv` (one row per roll-height) moved in 6 rows' logbook columns | PASS (package vocabulary; ambiguous) | no |
| 89 | NEWS:4 | 0 of 36 compared; 9 rolls; median error +0.018; flagged bc85054 | | P, W | as #34-36 | PASS | IO |
| 90 | NEWS:5 | On five of the nine the photos overlap 0.62 to 0.81, an ordinary flight | five | K | see #43 | FAIL | no |
| 91 | NEWS:5 | step implies 0.11 to 0.42 | five | K | | PASS | no |
| 92 | NEWS:5 | step is 1.25 to 2.7 times the air base ... nominal unrefuted | five | K | | PASS | no |
| 93 | NEWS:5 | On bc77070 that margin is at the instrument's resolution; on bc77087 it rests on a page height a blind re-read could not settle | | | | PASS | no |
| 94 | NEWS:5 | MRDEM at or above it on 107 frames a logbook row reaches (112 on the five): by the logbook, those frames are not over the ground photographed | 107 | NP, LB | 107; 38 of them on the contested read, unqualified here | FAIL (as #18) | no |
| 95 | NEWS:5 | bc7718 and bc80117 flown at ~85%, readings cannot be told apart | | K | | PASS | no |
| 96 | NEWS:6 | `_*.csv` ship every pair, control and verdict | | files | yes | PASS | no |
| 97 | NEWS:6 | the suite recomputes them and the note's figures | note's figures | IO | many unpinned (#12, 15, 27, 30, 37's 34, 38's 0.223, 39, 51, 59, 62, 72, 77-81, 83) | FAIL (overclaim) | n/a |
| 98 | NEWS:6 | moves fly#95's logbook counts (576 to 689) but none of its verdicts | AG | diff vs main | only frames_logbook/_catalogue/_other/logbook_ft moved, 6 rows; spacing/tabled/reason unchanged | PASS | AG |
| 99 | NEWS:6 | strips transcription "ships as" data-raw/... | | .Rbuildignore `^data-raw$` | committed, not shipped | FAIL (minor) | no |
| 100 | NEWS:7 | follow-up issue | | fly#99 exists | | PASS | no |

## CLAUDE.md — Architecture bullet (:110-118) and Key Decision (:438-456)

| # | location | claim | set | producer | recomputed | verdict | pinned? |
|---|---|---|---|---|---|---|---|
| 101 | CLAUDE:112-113 | global_shift() wraps shifts over ~575 px and gates on centroid spacing | | findings.md:62-65 | | PASS | no |
| 102 | CLAUDE:113-114 | synthetic, unrelated-pair, crew-written-overlap and bc85054 controls stop it | | script gates | the negative (tau) control gates too; list, not a universal | PASS | no |
| 103 | CLAUDE:115-116 | test recomputes [the CSVs] together with the note's prose | | IO | subset pinned | FAIL (as #97) | n/a |
| 104 | CLAUDE:117-118 | strips file is an input, never regenerated; SMOKE writes nothing | | script | | PASS | no |
| 105 | CLAUDE:438-439 | Where spacing rejected nominal ..., the photos say the catalogue's step is wrong | nine | K | 5 | FAIL (as #11) | no |
| 106 | CLAUDE:440-442 | five of nine overlap 0.62-0.81 where step says 0.11-0.42; x1.25-x2.70 (bc77070 by 0.006; bc77087 only on 3.8) | five | K | | PASS | no |
| 107 | CLAUDE:443-444 | By the logbooks against MRDEM, 107 of the 112 r<=0 frames are not over the ground photographed | 107 | NP, LB | unqualified for bc77087's 38 | FAIL (as #18) | no |
| 108 | CLAUDE:444-445 | bc7718 and bc80117 flown at ~85%, where the two readings coincide | | K gap | bc7718 0.0007 (coincide); bc80117 0.114 in D (x1.12): under 2 tau, not coincident | FAIL (minor: "coincide" for "cannot be told apart") | no |
| 109 | CLAUDE:448-449 | Centroids there [1970s rolls] are interpolated along digitised lines | | fly#82 | as #15 | FAIL | no |
| 110 | CLAUDE:449-451 | On all seven keys ... step or flown overlap off what the window assumes | 7 | K | | PASS | no |
| 111 | CLAUDE:452-454 | floor ~a quarter (0.25 matches, 0.20 does not); tau ~x1.25 set by how far the step strays on ordinary keys | | SY, tau | 95th pct (max is x1.41) | PASS | IO |
| 112 | CLAUDE:455-457 | "Ground below sea level" was exactly p_img > p_agl, withdrawn before the keys were read | | findings A2(3) | re-derived: G_k<0 <=> k > ratio <=> p_img > p_agl | PASS | no |
| 113 | CLAUDE:458-459 | bc77087's page 1 height is contested (3.8 or 7.8) and recorded | | | omits that 7.8 makes the page put the ground under the catalogued height | PASS (true; incomplete, see #79) | no |

## fly#99 issue body (identical to planning/active/followup_issue_draft.md bar a trailing newline)

| # | location | claim | set | producer | recomputed | verdict | pinned? |
|---|---|---|---|---|---|---|---|
| 114 | #99 ¶1 | on five roll-heights, the catalogue's centroids are not over the ground the photos cover | 311 frames on the five | logbook basis: 107 r<=0 frames | 107 | FAIL (as #83) | no |
| 115 | #99 ¶1 | with dem =, falls back to nominal on r <= 0 and warns | | CLAUDE.md fly#93/95 | | PASS | no |
| 116 | #99 table | 11/59/1/3/38; 0.807...; 0.419... | five | K | all match | PASS | no |
| 117 | #99 bullet 2 | 112 frames, 107 of which a logbook row reaches | | NP, LB | 112/107 | PASS (bc77087 qualified later in the body) | no |
| 118 | #99 bullet 3 | photos overlap like an ordinary flight | five | K | bc77026 0.807 | FAIL (as #43) | no |
| 119 | #99 bullet 3 | step 1.25 to 2.7 times the air base; bc77070 at resolution; bc77087 only on the contested read | five | K | | PASS | no |
| 120 | #99 ¶ | So, by the page, the frames were photographed somewhere else, over lower ground | frames on the five | page basis 107 | | FAIL (minor, as #83) | no |
| 121 | #99 ¶ | headings agree on 233 of the 237 matched pairs a transcribed strip reaches | | ST | a strip reaches 280; 237 = legible heading. Round 1's wrong label, fixed in the note and test in round 2, not here | FAIL | no |
| 122 | #99 ¶ | so the lines are not rotated or reversed | | ST | 4 differ, 48 untested | FAIL (as #62) | no |
| 123 | #99 ¶ | bc77087 contested 3.8 or 7.8; at 7,800 ft its 38 frames would not sit under the terrain at all | | census elev | true; omits that at 7.8 the page reads `ground` (datum question, not a misplaced centroid) | PASS (incomplete; see #79) | no |
| 124 | #99 ¶ | two more roll-heights unsettled because the two size readings coincide | | K gap | bc80117 0.114 apart | FAIL (minor, as #108) | no |
| 125 | #99 ¶ | TAHSIS 359 km; YALE BLUFF 97 km | | K | | PASS | no |
| 126 | #99 last ¶ | on 1970s rolls the centroids are interpolated along digitised lines | | fly#82 | as #15 | FAIL (as #15; "probably wider" is hedged, this clause is not) | no |

## Tally

126 claims: 95 PASS, 31 FAIL (13 in the note, 6 in NEWS, 5 in CLAUDE.md, 7 in the issue). They collapse
to 16 findings in `review-round3.md`.
