# Round 4 claim enumeration — fly#97 branch at b98ecea

Reviewer: subagent, 2026-10-07. Working tree not modified. Probes ran in a `git archive` copy under the
session scratchpad, with shipped CSVs read using `na.strings = ""`. The centroid cache was read in place,
without writing to it. Recomputation scripts: `scratchpad/r4/c1.R`-`c5.R`, `scratchpad/t.R`, `t2.R`.

Legend: **P** = pinned by `tests/testthat/test-fly_footprint_image_overlap.R` (line) or
`test-fly_footprint_above_ground.R` (AG:line); **src** = the source-tree-only test (skipped under
`R CMD check`, accepted); **—** = unpinned. "keys" = `flying_height_image_overlap_keys.csv`, "pairs" =
`_pairs.csv`, "ag" = `flying_height_above_ground.csv`, "lb" = `data-raw/flying_height_logbooks.csv`.

## A. Note, fly#97 section (`inst/notes/terrain-correction.md` 877-1050)

| # | line | claim | set | producer | recomputed | verdict | pin |
|---|---|---|---|---|---|---|---|
| N1 | 883 | nine roll-heights, 157 frames at `r <= 0` | nine keys | sum(keys$frames_nonpositive) | 157 | PASS | P:229 |
| N2 | 883-884 | spacing rejects nominal and the height read as above ground on them | nine | ag$spacing, overlap_nominal against 0.557-0.780 | refutes ×9; nominal 0.075-0.857, all outside | PASS | constant string only (P:233 vacuous) |
| N3 | 886-887 | "On 1970s rolls ... in fly#82's probe, 64-77% of consecutive steps equal within 0.5%" | 1970s rolls | fly#82 `review-1.md:6-8` | 1965 67%, **1975 77%**, 1985 64% | **FAIL** (range from 1965-85 stated over the 1970s) | — |
| N4 | 890 | on five of the nine the step is longer than the air base | five `step_overstated` | keys$w1 | 5 | PASS | P (table) |
| N5 | 891 | at least x1.25 to x2.70 longer under any height the logbook allows | five | exp(-D_agl) over all matched non-break pairs | 1.253-2.700; **over pairs a shipped row covers: 1.253-2.610** (bc77026: 38 of 114 pairs on 220-258, which no shipped row reaches) | **FAIL** (minor: the endpoint is computed over frames the shipped logbook does not reach) | P:256 |
| N6 | 891-892 | so spacing's rejection of nominal on those five says nothing about the scale | five | rounds 2-3 reasoning; residual nominal overlaps outside window | holds | PASS | — |
| N7 | 893-894 | logbook figure against MRDEM puts 107 of the 112 elsewhere | five's `r <= 0` | nonpositive × lb | 112; 107 covered; elev ≥ page height on 107 of 107 | PASS | src |
| N8 | 895-897 | bc77087 carries 38 of 107 and its part of the bound on a contested page height | bc77087 | lb, findings:262 | 38; 3.8 vs 7.8 | PASS | src |
| N9 | 896-897 | read the other way its page puts the ground under the catalogued height | bc77087 at 7.8 | generator relation (median h-elev within 10%) | median 1,114 vs 1,158 (3.8%) → ground_plus | PASS | P:test 7.8 |
| N10 | 898 | two flown at ~85% overlap, readings cannot be told apart | bc7718, bc80117 | keys p_img, gap ≤ 2 tau | 0.858, 0.840; gaps 0.0007, 0.114 < 0.44 | PASS | P |
| N11 | 899 | two have one matched pair each | bc5715, bcc325 | keys$pairs_matched | 1, 1 | PASS | P (table cell) |
| N12 | 903-904 | image shift is 1 - overlap whatever scale/height/centroids say; no catalogue field enters | instrument | `ncc_seeds()`/`measure_shift()`/`p_of()` | no step, bearing or centroid read | PASS | — |
| N13 | 906-907 | matching is fly#82's: patch_shifts and gate (≥ 20 confirming 128 px patches, median), pulled not copied | instrument | script:93-94, 172-197 | `fns_from()`; ≥ 8 at step 64, then ≥ 20 at step 32 | PASS | — |
| N14 | 908-910 | global_shift wraps beyond ~575 px (overlap < ~0.54) and gates on a centroid prediction | fly#82 | parallax.R:207-225 | interior 1,150, half 575; `mag` within [0.25, 3] × pred | PASS | — |
| N15 | 910 | seeds from a zero-padded masked NCC | this script | script:115-170 | yes | PASS | — |
| N16 | 911-912 | floor between 0.20 and 0.25; 10/10 at 0.25, 0/10 at 0.20 | synthetic | synthetic.csv | 10/10 at 0.2496, 0/10 at 0.20, **all 80 shifts negative** | **FAIL** (measured for one sign of shift only; see N18) | P:62-63 |
| N17 | 912-913 | a window sits 114 px inside both frames, so a pair must share ~230 px of 1,250 | gate geometry | `patch_shifts()` grid `seq(114, n-114)`, `inb()` | 228 px | PASS | — |
| N18 | 913 | "The 8- and 20-patch counts set the rest" | floor cause | grid `seq(114, 1136, by = 64)` against the shift's sign | at 0.20 `n_patches` = 0 on all 20 (no grid row exists); negative shifts lose the last row above 960 px (p < 0.232), **positive shifts keep one row to ~1,022 px (p ≈ 0.19)**; the counts never bind | **FAIL** (causal claim wrong: the step-64 grid row, sign-dependent) | — |
| N19 | 914-916 | D_R = log((1-p_img)/(1-p_R)), the log of how far the step is from the air base | definition | script:318-320 | identity | PASS | P:37-38 |
| N20 | 918-919 | rule fixed before any thumbnail was matched; amended twice before any of the nine keys measured | rule | commit order a963182 → 6cc901b → d7a91ba → 7f9d8fb → 16fd02e | holds | PASS | — |
| N21 | 920 | A1 after a smoke run on control thumbnails | A1 | findings:157 | yes | PASS | — |
| N22 | 921-923 | A2 from a plan review arriving while the control draw ran, committed before its output was read | A2 | findings:177-180 | yes (log not read) | PASS | — |
| N23 | 923-924 | A2 withdrew an outcome that restated p_img > p_agl | A2 | findings:194 | yes | PASS | — |
| N24 | 926-928 | one change after the run: the read_other split; moved one label (bcc325), no verdict | post-run changes to the script | script diffs after 16fd02e | 4a9eea8 adds reporting only (km); 9206221 lint; 5c6c196 adds `read_other`. bcc325 size/location unchanged (too_few_pairs / not_tested either way) | PASS | — |
| N25 | 932 | synthetic 0.35-0.90: 50 of 50 matched | synthetic | synthetic.csv | 50/50 | PASS | P:58-60 |
| N26 | 932 | error under 1e-4 | synthetic | recomputed from dr, dc | max 1.22e-5 | PASS | **pin is 0.02 (P:61); the 1e-4 is matched as text only (P:270)** |
| N27 | 933 | floor row | synthetic | as N16 | as N16 | PASS as counts (cause FAILS at N18) | P |
| N28 | 934 | unrelated: 0 of 36 compared matched (38 drawn, 2 no thumbnail); different rolls | unrelated | pairs | 0/36; 38; 2; same-roll 0 | PASS | P:68-71, 267 |
| N29 | 935 | crew-written, 9 rolls, median 0.018 above | gated rolls | written.csv × pairs | 9 gated; +0.0178 | PASS | P:266 |
| N30 | 936 | bc85054 162/163, spacing x1.7 off; flagged \|D\| 0.548 | positive | pairs | 0.548 (x1.73) | PASS | P:268 |
| N31 | 937 | ordinary 1970-85 keys where spacing fits, 34; median D -0.031; tau 0.220 | negative control | script:399-412; io_tau | 34 of 39; -0.031; 0.2199 | PASS | P:65-67, 263 |
| N32 | 939 | tau passed ceiling log 1.25 (0.223) narrowly | tau | log(1.25) | 0.2231 | PASS | P:235 |
| N33 | 940 | cannot see a step error under about x1.25 | tau | exp(0.2199) | 1.246 | PASS | — |
| N34 | 940-941 | step and air base differ by more than that on 2 of the 34 (x1.34, x1.41) | negative | io_tau | 2; 1.34, 1.41 | PASS | P:236 |
| N35 | 941-942 | of 192 ordinary pairs, 31 of the 190 compared did not match, 2 no thumbnail | negative | pairs | 192; 31/190; 2 | PASS | P:264 |
| N36 | 946-954 | table: 9 rows × 6 cells | nine | keys + pairs | all match | PASS | P:205-225 |
| N37 | 957-958 | four overlap 0.62-0.64, an ordinary flight | four | keys p_img within window | 0.615-0.640, inside 0.557-0.780 | PASS | P:230 (window not checked) |
| N38 | 958-959 | bc77026 overlaps 0.81, above the window; its page remarks "...(75.9%)" | bc77026 | keys, lb note | 0.807; remark present | PASS | P:230 (literal name) |
| N39 | 960 | on each, 83% to 97% of pairs match, so the frames are adjacent | five | pairs_matched/pairs | 82.8%-96.6% | PASS | P:244 |
| N40 | 961 | step implies 0.11 to 0.42 at nominal | five | keys p_nominal | 0.114-0.419 | PASS | P:240 |
| N41 | 961-962 | at nominal 1.9 to 3.0 times the air base | five | keys$k | 1.898-3.013 | PASS | P:242 |
| N42 | 963-964 | pages write the catalogue's figure under M.S.L. for ≥ 90% of frames read | five | ag frames_catalogue/frames_logbook; lb headers | 100% on each; all headers M.S.L. | PASS | src |
| N43 | 964 | bc77070's pages were read blind for fly#97 | bc77070 | findings:252 batch B; lb `main` lacks bc77070 | yes | PASS | AG:247 (31 rolls) |
| N44 | 965-966 | true height above ground at most the figure; side at most the above-ground reading | logic | ground ≥ sea level | holds | PASS | — |
| N45 | 966-968 | no size reading brings the step to the air base; x1.25-x2.70 (exp(-D_agl)) | five | keys D_agl | as N5 | PASS (endpoint as N5) | P:255 |
| N46 | 969-970 | nominal stands as the default, unrefuted rather than confirmed | five | keys$size | nominal_unrefuted ×5 | PASS | P |
| N47 | 972-973 | bc77070, the largest (59), passes by 0.006: D_agl -0.226 against tau 0.220, x1.25 | bc77070 | keys | 59 is the max; 0.0061 | PASS | P:257 |
| N48 | 974 | bc77087's x1.39 holds only on the contested 3.8 | bc77087 | exp(0.3269) | 1.387 | PASS | — |
| N49 | 978-979 | the page says M.S.L., yet MRDEM is at or above it on 112 frames | five | nonpositive | 112 | PASS | P:261, 277 |
| N50 | 979-980 | a shipped row reaches 107, every one writing the catalogue's figure under M.S.L. | five | lb join | 107; all within 2% (exact to rounding) and M.S.L. | PASS | src |
| N51 | 981-982 | the other 5 have no shipped row; misplaced only because the verdict is per key | five | lb join | 5 | PASS | src |
| N52 | 983-985 | bc77026 221, 222, 237, 247 lie past row 219, transcribed before fly#97 with END left blank; the page runs to 258 in the blind re-read, kept out by A2 | bc77026 | lb rows (added by a785bfd, #93); findings:257, 234 | holds | PASS | src (frames) |
| N53 | 986 | bc77072 225 is on no page | bc77072 | lb rows end 223; page guard (35 pages) | holds | PASS | src |
| N54 | 987-988 | settles fly#95's either-or by taking the page at its word | logic | — | holds | PASS | — |
| N55 | 989-990 | step_overstated: D_agl uses a step already shown wrong, so it does not test the datum | logic | round 1 | holds | PASS | — |
| N56 | 991-993 | spacing along each line is not the photos', by at least x1.25; at resolution on bc77070; holds on bc77087 only on 3.8 | five | as N5/N47/N48 | holds | PASS | — |
| N57 | 994-996 | A2 glossed the verdict as "the images reject reading the column as above ground"; round 1 found it | A2 | findings:391 | yes | PASS | — |
| N58 | 996-997 | on pairs with a legible heading the page agrees with the bearing on 233 of 237; 4 differ | five, matched non-break | strips dir (script:671-677) | 233/237; 4 (differ 4, reverse 0) | PASS | P:247 (sums reverse into "differ") |
| N59 | 997-998 | the 4: bc77087 1/2, 2/3, 3/4; bc77072 1981 frame 111 | five | strips | frames 1, 2, 3 and 111 | PASS | — |
| N60 | 998 | of 285 matched pairs, 48 have no legible heading or no strip | five | pairs, strips | 285 - 237 = 48 | PASS | P:250 |
| N61 | 998-999 | "On the pairs tested, the lines are not rotated or reversed" | the 237 tested | strips dir | 4 of the 237 differ (~52° and ~98°) | **FAIL** (universal over a set that includes the 4 contrary pairs) | — |
| N62 | 1000-1001 | displacement not measured; the size statement assumes it keeps the step | — | — | holds | PASS | — |
| N63 | 1004 | images read 0.858, 0.840; step gives 0.857, 0.843 | two | pairs (4-dp steps) | yes | PASS | P:258 |
| N64 | 1005 | spacing rejected them because its window assumes ~60% | two | ag overlap 0.857/0.843 > 0.780 | holds | PASS | — |
| N65 | 1006-1007 | 0.001 and 0.114 apart in D against 2 tau = 0.44; unsettled | two | keys gap, size | yes | PASS | P:260 |
| N66 | 1010 | bc77026 remark; images 0.807 | bc77026 | keys | yes | PASS | P:271 |
| N67 | 1011 | bc80117 "80% FOREWARD O.L."; images 0.840 | bc80117 | keys | yes | PASS | P:272 |
| N68 | 1012-1013 | bc77070 "Only 40%..." images 0.316 on that pair, 0.61-0.64 on its neighbours; step 848-850 m on all | bc77070 268-271 | pairs | 0.316; 0.611-0.644; 847.9-849.6 | PASS (neighbours = the three preceding pairs; 271/272 is the key's last) | P:273-275 |
| N69 | 1014 | coordinates from the BC Geographical Names service | places | script:690-702 | yes | PASS | — |
| N70 | 1015 | bc7718 46-69 is "TAHSIS", 359 km from its nearest catalogued frame | bc7718 1524 key | `km_to_place`: the key's nearest **census** frame (46-69) | 358.98 km from census frames; **the same key's catalogued frames 31-45 (1,524 m, 1:5000, under the same page row 31-69 at 5,000 ft) are 14.8-15.9 km from Tahsis** | **FAIL** (the set named, "its nearest catalogued frame", is not the producer's set; wrong by ~344 km read as written) | P:276 (census set) |
| N71 | 1015-1017 | 5,000 ft is exactly nominal height for 1:5000 on 305 mm; ground at sea level, as at Tahsis | bc7718 | arithmetic | 1,525 m = 5,003 ft (0.07%) | PASS | — |
| N72 | 1018 | bc80117 "YALE BLUFF" 97 km from its frames | bc80117 | km_to_place; cache: all 19 key frames 97.5-100.3 km | yes | PASS | P:277 |
| N73 | 1019 | the five step-overstated keys are 6 to 36 km from their places | five | km_to_place | 5.96-35.83 | PASS | P:278 |
| N74 | 1020 | a project area spans tens of km, so that does not discriminate | — | judgement, no producer | — | PASS (stated as judgement) | — |
| N75 | 1023 | the blind reader would not choose between 3.8 and 7.8, leaning 7.8 | bc77087_1 | findings:261-263 | "reads most like 7.8 but could be 3.8" | PASS | — |
| N76 | 1024 | "fly#60's reader read 3.8" | bc77087_1 row | `git log -S` on lb | **row added by 9ee2114, "Transcribe the terrain roll-heights' logbook pages blind (#93)"** | **FAIL** (wrong provenance: fly#93's blind reader) | — |
| N77 | 1024 | the catalogue's 1,158 m is 3,800 ft | arithmetic | 3800 × 0.3048 | 1,158.2 | PASS | — |
| N78 | 1025 | "At 7,800 ft (2,377 m), its 38 frames would not be at `r <= 0`" | bc77087's 38 | `r` in `fly_footprint()`/the census is computed from the catalogued `flying_height`; the 7.8 read tables nothing (spacing refutes; round 3's re-run left `flying_height_rolls.csv` byte-identical) | page aircraft above MRDEM on all 57 (P); package `r` unchanged, still ≤ 0 on the 38 | **FAIL** (counterfactual stated in the package's variable; the code that computes `r` does not move) | P:337 (h - e only) |
| N79 | 1026-1027 | median of 2,377 m less MRDEM over 57 frames is 1,114 m, within 4% of 1,158 | bc77087 | census elev | 1,114; 3.8% | PASS | P:341 |
| N80 | 1027-1029 | relation ground_plus, W2 ground, the stop fires | bc77087 at 7.8 | generator:1023-1030; script case_when; script:736 | frames_catalogue 0, ground 57 → `ground`; size `unsettled`, location `datum_question`; STOP line fires | PASS | partly (relation only) |
| N81 | 1030 | 2,377 / 1,158 is 2.05, near x2 | arithmetic | — | 2.053 | PASS | P:342 |
| N82 | 1031-1032 | the bound would fall to x1.15-x1.59 over 10th-90th pct (x0.68 at sea level), under tau at the low end | bc77087 | bound() | 1.15, 1.59, 0.68; log 1.15 = 0.14 < 0.22 | PASS | P:343-344 |
| N83 | 1033 | only the W1 label is the same either way | bc77087 | case_when at 7.8 | w1 same; w2/size/location change | PASS | — |
| N84 | 1034 | bc77070, flown the same week on the same project at 3,800 ft, was read clear | bc77070_4 | lb note: Op 94/77 Swan Lake Grinrod, 13/8/77, legibility clear | same day, same op | PASS | — |
| N85 | 1035 | which reading is right is left open | — | — | — | PASS | — |
| N86 | 1039-1040 | fly_footprint() draws "these frames" at nominal, which the photos no longer contradict | the nine (section subject) | keys | seven judged; **bc5715 and bcc325's single pairs read the step x1.70 and x2.49 off nominal** (D_nominal -0.53, -0.91), unjudged below 3 pairs | **FAIL** (minor: stated over nine, holds on seven) | — |
| N87 | 1041-1042 | by the logbooks, 107 frames on five not over the ground (38 on bc77087's contested read) | as N7 | — | yes | PASS | src |
| N88 | 1043 | whether to tell the caller is fly#99 | — | issue exists | yes | PASS | — |
| N89 | 1044-1045 | bc77087's page 1 digit decides whether a page puts the ground under a catalogued height | transcribed pages | ag frames_ground_plus = 0 elsewhere | holds | PASS | AG |
| N90 | 1046-1047 | some pages log the intervalometer and speed; not transcribed | — | lb notes ("speed 300 stop 6.8", "speed 1/300" are shutter) | no intervalometer field in lb; claim is about pages, unverified | PASS (stated as a lead) | — |
| N91 | 1048-1050 | on all seven keys the photos could measure, the step or flown overlap was off the window | seven | keys w1 | 5 step_overstated + 2 at ~0.85 | PASS | — |

## B. Note, fly#95 section (the paragraphs fly#97 changed)

| # | line | claim | set | producer | recomputed | verdict | pin |
|---|---|---|---|---|---|---|---|
| P1 | 811-812 | a page writes the catalogue's height on 669 of 689 frames read | population | ag | 661 + 8 = 669; 689 | PASS | AG:196-198, 232 |
| P2 | 812-814 | none puts the ground under it, as transcribed; fly#97 found one page whose digit, read the other way, would | population | ag gp + gh = 0; N80 | 0 | PASS | AG |
| P3 | 815 | transcribed for 31 of the population's 154 rolls | population | ag × lb | 31 / 154 | PASS | AG:228, 247 |
| P4 | 815-817 | 26 when fly#95 ran; fly#97 transcribed the five rolls of its nine keys that had none; every figure here includes them | — | lb on main | 26; new = bc5715, bc77070, bc7718, bc80117, bcc325; the eight rolls' other three already on main | PASS | AG |
| P5 | 817-818 | the other 123 were not transcribed; bcc07085 has no page | population | 154 - 31 | 123 | PASS | — |
| P6 | 818-819 | headers say M.S.L. or name no datum; none names the ground | transcribed | lb headers | M.S.L. variants and "True Height"; no ground | PASS | AG:248 |
| P7 | 819 | 38 roll-heights with a frame the logbook reads | population | ag | 38 | PASS | AG:195, 227 |
| P8 | 821-826 | table 661 / 8 / 20 / 0 | population | ag | 661, 8, 20, 0 | PASS | AG:190-192 |
| P9 | 828-831 | figure below the ground on bc5602, bc77026, bc77072, bc77087, and on bc5715, bc77070, bc7718, bc80117, bcc325 (transcribed by fly#97); bcc325's figure not the catalogue's | population | census × lb (elev > page height) | exactly these nine rolls; all headers M.S.L.; bcc325 1,500 vs 1,300 ft | PASS | — |
| P10 | 831-834 | no transcribed page does; rule not amended after the data | — | — | holds (on the 3.8 read, stated in P2) | PASS | — |
| P11 | 861-862 | the last row is nine roll-heights (listed) | nine | keys | yes | PASS | — |
| P12 | 862-863 | "fly#97 measured those nine with the photos themselves" | nine | keys w1 | 7 judged, 2 `too_few_pairs` | **FAIL** (minor; the section itself says "seven keys ... the photos could measure") | — |
| P13 | 863-865 | "On five of them the catalogue's centroid step is wrong, so spacing's rejection ... says nothing about the scale" | five | as N5 | holds with the bc77070 / bc77087 qualifiers, which this copy alone omits | **FAIL** (copy drift, round 3 form 2) | — |
| P14 | 865-866 | on two, flown at ~85% overlap, above the window | two | keys | yes | PASS | — |

## C. NEWS.md, development entry

| # | line | claim | verdict | note |
|---|---|---|---|---|
| W1 | 3 | headline: on five of the nine the step is longer than the air base, so the rejection says nothing about scale | PASS | qualified in W6 |
| W2 | 3 | no code change; every roll table byte-identical | PASS | `git diff main...HEAD -- R/ flying_height_rolls*.csv` empty |
| W3 | 4 | reads no scale, height or centroid | PASS | N12 |
| W4 | 4 | seeded by a search that neither wraps nor reads centroid spacing | PASS | N15 |
| W5 | 4 | before the nine: synthetic passed, none of 36 unrelated, 9 rolls +0.018, flagged bc85054 | PASS | commit order |
| W6 | 4 | cannot see a step error under about x1.25 | PASS | |
| W7 | 6 | at the largest side: 1.25 to 2.7; bc77070 at resolution; bc77087 contested (3,800 or 7,800 ft); nominal unrefuted | PASS (endpoint as N5) | |
| W8 | 7 | by logbooks against MRDEM, 107 frames on the five not over the ground photographed; 38 of the 107 are bc77087's | **FAIL** (minor) | the 38 are given as a count, with no word that they rest on the contested read; W7 qualifies only the bound, and W10 says the 7.8 page puts the ground under the height but not that these 38 then leave the 107 |
| W9 | 8 | bc7718 and bc80117 at ~85%, readings cannot be told apart | PASS | |
| W10 | 9 | read as 7,800 ft the page puts the ground under the height on all 57 frames: the first page to do so; 2.05x, near x2 | PASS | generator labels all 57 by the per-key median (N80) |
| W11 | 11 | the suite recomputes the verdicts, the note's table and the figures it lists | PASS | |
| W12 | 12 | five more rolls transcribed blind; 576 to 689 frames read; no fly#95 verdict moved | PASS | ag on main against HEAD: spacing, tabled, reason identical |
| W13 | 13 | strips transcription committed | PASS | |
| W14 | 14 | not done: fly#99 | PASS | |

## D. CLAUDE.md

| # | line | claim | verdict | note |
|---|---|---|---|---|
| C1 | 110-112 | fly#82's patch_shifts gate via fns_from(); padded masked NCC seeds because global_shift wraps over ~575 px and gates on spacing | PASS | N13-N15 |
| C2 | 113-114 | synthetic, unrelated, crew-written, bc85054 controls stop it before the nine are read | PASS | script:575-577 |
| C3 | 114-116 | ships `_*.csv`; test recomputes them with the note's table and the figures it lists | PASS | |
| C4 | 116-117 | reads the strips transcription, never regenerated | PASS | read at script:596; no write |
| C5 | 117-118 | FLY_IMGOVL_SMOKE=1 writes nothing | PASS | quits after controls (script:579-581) |
| C6 | 438-440 | heading: on five of nine, the photos say the step is wrong; reads no catalogue field | PASS | qualified at 442-443 |
| C7 | 442-443 | x1.25-x2.70; bc77070 by 0.006; bc77087 only on 3.8 | PASS (endpoint as N5) | |
| C8 | 443-444 | 107 of 112 (those a row reaches, 38 bc77087's) not over the ground, by the logbooks not the photos | **FAIL** (minor) | same as W8: no contingency attached to the 38 here; C14 later says the digit is open but not that these 38 depend on it |
| C9 | 445-446 | bc7718 and bc80117 at ~85%, cannot be told apart | PASS | |
| C10 | 449-451 | 1970s steps often evenly spaced (fly#82); on all seven keys the step or flown overlap was off the window | PASS | "often" fits 1975's 77% |
| C11 | 452 | matcher floor between 0.20 and 0.25 | **FAIL** (minor) | measured on negative shifts only (N16/N18); real matched pairs are 531 of 537 positive |
| C12 | 452-453 | tau ~x1.25, set by how far the step strays on ordinary keys; a no-match does not mean not adjacent | PASS | 31 of 190 adjacent ordinary pairs did not match |
| C13 | 454-457 | "ground below sea level" was exactly p_img > p_agl, withdrawn before keys (A2); the image leg does not test the datum | PASS | |
| C14 | 459-462 | page 1 reads 3.8 or 7.8; at 7.8 ground under the height on all 57; 2.05x; transcription keeps 3.8; open | PASS | lb row 3800 |

## E. fly#99 body (identical to `planning/active/followup_issue_draft.md`)

| # | draft line | claim | verdict | note |
|---|---|---|---|---|
| I1 | 3 | by their logbooks, 107 frames on five are not over the ground the centroids put them on | PASS | qualified at I9 |
| I2 | 3 | with dem, r <= 0 frames fall back to nominal and warn | PASS | `R/fly_footprint.R:1352-1360` |
| I3 | 5-11 | table of five keys | PASS | keys |
| I4 | 13 | source CSV and script | PASS | |
| I5 | 16 | page writes the catalogue's height under M.S.L.; MRDEM ≥ it on 112; a row reaches 107 | PASS | |
| I6 | 17 | the photos do not test the datum; step longer by at least x1.25 to x2.70 under any height the page allows; bc77070 at resolution | **FAIL** | the bc77087 qualifier (x1.39 only on 3.8; x1.15-x1.59 / x0.68 at 7.8) is in the note, NEWS and CLAUDE.md but not in the issue fly#99 will be built from |
| I7 | 18 | 233 of 237 on legible-heading pairs (4 differ) | PASS | |
| I8 | 18 | "so on those pairs the lines are not rotated or reversed" | **FAIL** | "those pairs" = the pairs with a legible heading, which include the 4 that differ (same as N61) |
| I9 | 20-22 | bc77087 contested; at 7,800 ft its 38 frames would not be under the terrain; its page would put the ground under the height | PASS | phrased physically, not as `r` |
| I10 | 24 | two more left `unsettled` because size readings cannot be told apart | PASS | keys$size |
| I11 | 24 | bc7718 46-69 "TAHSIS" 359 km; bc80117 "YALE BLUFF" 97 km | PASS | true for frames 46-69. The issue omits that the same key's frames 31-45 are catalogued beside Tahsis, which bears on a misplacement ledger (N70) |
| I12 | 29-31 | three options; fly_georef already names a film roll's state | PASS | |
| I13 | 33 | 1970s steps often evenly spaced (fly#82's probe); ledger not a census | PASS | |

## F. Test pins (`tests/testthat/test-fly_footprint_image_overlap.R`)

| # | line | pin | sentence it backs | vacuous? |
|---|---|---|---|---|
| T1 | 61 | `max(abs(p_img - p_true)) < 0.02` | "error under 1e-4" (note:932) | **yes** for the 1e-4: matched as literal text at :270, 200x looser computed bound |
| T2 | 233 | `"frames at \`r <= 0\`, where adjacent-frame spacing rejects nominal"` | N2 | **yes**: a constant, nothing computed; no assertion in this file that the nine keys' `ag$spacing` is `refutes` or their nominal overlap is outside the window |
| T3 | 230-232 | "Four have photos overlapping %s to %s, an ordinary flight. `bc77026` overlaps %s" | N37/N38 | partly: uses `sort(p_img)[4]` and `max()`; never checks window membership, "above the window", or that the max is bc77026 |
| T4 | 247-248 | "on %d of %d. %d differ" with differ + reverse | N58 | partly: a `reverse` pair would pass under the word "differ" (0 today) |
| T5 | 276 | `"TAHSIS", %d km` from `km_to_place` | N70 | pins the producer's (census) set, so it passes while the sentence names a different set |
| T6 | 285-321 | 107 / 112 / the 5 / catalogue-figure-under-M.S.L. / 38 | N7, N50-N53, N8 | no (source-tree only, accepted) |
| T7 | 324-347 | 7.8: median relation, h - e > 0, bound strings | N79, N81, N82, N78 | no for the arithmetic; N78's "would not be at `r <= 0`" is pinned by `h - e > 0`, which tests the page height, not `r` |
| T8 | 99-163 | w1, w2, size, location recomputed | the verdicts | no |
| T9 | 165-279 | table cells | N36 | no |

## Totals

**146 claims enumerated** (A 91, B 14, C 14, D 14, E 13), **16 FAIL**: N3, N5, N16, N18, N61, N70,
N76, N78, N86, P12, P13, W8, C8, C11, I6, I8.

They are 11 distinct defects:
- N16, N18 and C11: the floor.
- N61 and I8: "not rotated".
- W8 and C8: the 38.
- N86 and P12: nine vs seven.
- N3, N5, N70, N76, N78, P13 and I6 stand alone.

Separately, of the 9 test pins assessed, 5 are vacuous or partial (T1-T5).
