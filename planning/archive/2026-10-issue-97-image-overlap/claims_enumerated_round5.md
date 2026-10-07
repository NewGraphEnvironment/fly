# Round 5 claim enumeration (fly#97), against b28f203

Producers: KEYS/PAIRS/STRIPS/SYN/WR = `inst/extdata/flying_height_image_overlap_{keys,pairs,strips,synthetic,written}.csv`;
AG = `flying_height_above_ground.csv` (AG0 = same on `main`); NP/TF = `flying_height_terrain_{nonpositive,frames}.csv`;
LB = `data-raw/flying_height_logbooks.csv`; ST = `data-raw/flying_height_logbook_strips.csv`; CC = centroid cache;
S = `data-raw/height_measure-image_overlap.R`; F82 = `dem_measure-photo_parallax.R`; FD = `planning/active/findings.md`;
T = `tests/testthat/test-fly_footprint_image_overlap.R` (T4 = 4th `test_that`, etc). All CSVs read with `na.strings = ""`.
"Pinned" = a test assertion that would fail if the figure moved.

## inst/notes/terrain-correction.md, fly#97 section (lines 878-1061)

| # | claim | set | producer | recomputed | verdict | pinned |
|---|---|---|---|---|---|---|
| N1 | nine roll-heights, 157 frames at r<=0 | KEYS | sum(frames_nonpositive) | 1+11+59+1+3+38+24+19+1 = 157 | PASS | T4 |
| N2 | spacing rejects nominal and AGL on the nine | AG | spacing, overlap_* vs window | all `refutes`, both outside 0.557-0.780 | PASS | T4 |
| N3 | spacing compares step with ~60% designed overlap | S window | p_window | 0.557-0.780 | PASS | S stopifnot |
| N4 | cannot say whether step or scale is wrong | logic | — | — | PASS | — |
| N5 | fly#82: 64-77% of steps equal within 0.5%, 1965/75/85 | fly#82 probe | archive issue-82 review-1:7 | 67/77/64% | PASS | no |
| N6 | nothing changed in the package | git | `git diff main...HEAD -- R/` | empty | PASS | — |
| N7 | on five of nine the step is longer than the air base | KEYS | w1 | 5 `step_overstated` | PASS | T3 |
| N8 | under any allowed height at least x1.25 to x2.70 | KEYS | exp(-D_agl) | 1.254, 1.387, 1.778, 1.800, 2.700 | PASS | T4 |
| N9 | x2.61 at the top over covered pairs | LB+PAIRS | T5 `bnd` | x1.25-x2.61 | PASS | T5 (later sentence) |
| N10 | so the rejection says nothing about scale | causal | step known wrong by >= tau | — | PASS | — |
| N11 | on those five, 107 of the 112 r<=0 frames | NP+LB | T5 reached | 107 / 112 | PASS | T5 |
| N12 | bc77087 carries 38 of the 107; page height unsettled by re-read | LB, batchC | — | 38; batchC row 54 "not interpreted" | PASS | T5 |
| N13 | read the other way, page puts ground under | TF+NP | T6 | median 1,114 within 4% | PASS | T6 |
| N14 | two flown at ~85%, readings cannot be told apart | KEYS | p_img, w1 | 0.858, 0.840; indistinguishable | PASS | T3/T4 |
| N15 | two have one matched pair each | KEYS | pairs_matched | bc5715 1, bcc325 1 | PASS | T4 table |
| N16 | shift = 1 - overlap; no catalogue field enters | S p_of | — | — | PASS | T1 |
| N17 | patch_shifts gate (>= 20 128 px, median) pulled, not copied | S:93, S:181-188 | fns_from | yes | PASS | — |
| N18 | global_shift wraps beyond ~575 px (overlap ~0.54), gates on spacing | F82:207-230 | (1250-100)/4/2*4 = 575; 1-575/1250 = 0.54; `pred_px` | yes | PASS | — |
| N19 | seeds from zero-padded masked NCC | S masked_ncc | — | yes | PASS | — |
| N20 | windows 114 px inside both frames on a 64 px grid | F82 patch_shifts | MARGIN + 64 = 114 (window centres), step 64 seed stage | yes | PASS | — |
| N21 | synthetic shifts all move one way | SYN | dr_true/dc_true | all 80 negative | PASS | T4 |
| N22 | 10/10 at 0.25, 0/10 at 0.20, where no window fits | SYN + geometry | n_patches; negative floor 1-960/1250 = 0.232 | 10/10 (p 0.2496), 0/10 | PASS | T2, T4 |
| N23 | 531 of 537 matched real pairs move the other way | PAIRS | sign of dominant component | 531 / 537 | PASS | T4 |
| N24 | for which the grid admits overlaps down to about 0.19 | geometry | row 114 survives to shift 1136-114 = 1022 px of 1250 (1249) | p = 0.182 (0.183) | **FAIL** (value: 0.18) | no |
| N25 | D_R definition and reading | S D_of | (1-p_img)/(1-p_R) = air base / step | yes | PASS | T3 |
| N26 | rule fixed before any thumbnail; amended twice before keys | git | a963182 07:31, A1 6cc901b 07:39, A2 d7a91ba 07:42, keys 16fd02e 08:07 | yes | PASS | — |
| N27 | A1 after a smoke run: the floor | FD:157 | — | yes | PASS | — |
| N28 | A2 arrived while control draw ran, committed before output read | FD:177-181 | — | yes | PASS | — |
| N29 | A2 contents (log tolerance + ceiling, indistinguishable, false-match, crew-written) | FD:183-230 | — | yes | PASS | — |
| N30 | A2 withdrew an outcome that was p_img > p_agl restated | FD:194 | nominal_by_elimination | yes | PASS | — |
| N31 | one change after the run (read_other); moved one label (bcc325), no verdict | git 5c6c196 | keys diff | 1 label; size/location unchanged | PASS (note: 4a9eea8 also added `km_to_place` after the run, reported only, not a rule change) | T3 |
| N32 | synthetic 0.35-0.90: 50 of 50, error under 1e-4 | SYN | p_true >= 0.35 | 50/50, max error 0 | PASS | T2, T4 |
| N33 | floor row 0.20 0/10, 0.25 10/10 | SYN | — | yes | PASS | T2 |
| N34 | unrelated (two different rolls): 0 of 36 compared (38 drawn, 2 no thumbnail) | PAIRS | set unrelated | 0/36, 38, 2; roll != roll_b on all 38 | PASS | T2, T4 |
| N35 | crew-written, 9 rolls, median 0.018 above page | PAIRS+WR | gated rolls | 9 gated, 5 matched each, median +0.0178 | PASS | T4 |
| N36 | bc85054 162/163 spacing x1.7 off; flagged, \|D\| 0.548 | PAIRS | positive | 0.548 (x1.73) | PASS | T2, T4 |
| N37 | ordinary 1970-85 keys where spacing fits, 34; median D -0.031; tau 0.220 | S:399-412, PAIRS | negative | 34 of 39; -0.031; 0.2199 | PASS | T2, T4 |
| N38 | ceiling log 1.25 (0.223), passed narrowly | — | — | 0.2199 vs 0.2231 | PASS | T4 |
| N39 | cannot see step error below about x1.25 | exp(tau) | — | x1.246 | PASS | — |
| N40 | 2 of the 34 exceed (x1.34, x1.41) | PAIRS | io_tau | yes | PASS | T4 |
| N41 | 192 ordinary pairs, 31 of 190 compared no match, 2 no thumbnail | PAIRS | negative | 159/31/2 | PASS | T4 |
| N42 | results table (9 rows: pairs, matched, overlaps, verdict, r<=0) | KEYS+PAIRS | — | all cells match | PASS | T4 (blank cells of 2-pair rows not asserted) |
| N43 | four overlap 0.62-0.64, ordinary flight | KEYS | p_img, window | 0.615-0.640, all in window | PASS | T4 |
| N44 | bc77026 overlaps 0.81, above window; page remark 75.9% | KEYS | p_img, overlap_written | 0.807 > 0.780 | PASS | T4 |
| N45 | 83% to 97% of pairs match, so adjacent | KEYS | matched/pairs | 82.8-96.6% | PASS | T4 |
| N46 | step implies 0.11 to 0.42 at nominal | KEYS | p_nominal | 0.114-0.419 | PASS | T4 |
| N47 | 1.9 to 3.0 times the air base at nominal | KEYS | k | 1.898-3.013 | PASS | T4 |
| N48 | on each key pages write catalogue figure under M.S.L. for >= 90% of frames read | KEYS/AG | frames_catalogue/frames_logbook; LB headers | 1.00 on all five; every header M.S.L. | PASS | T3 (w2) |
| N49 | bc77070's pages read blind for fly#97 | FD:248-253 | batch B | yes | PASS | — |
| N50 | true AGL at most the figure; side at most AGL reading | logic | — | — | PASS | — |
| N51 | no size reading brings step down; x1.25 to x2.70 (exp(-D_agl)) | KEYS | — | yes | PASS | T4 |
| N52 | x2.70 includes pairs past 219; covered x1.25-x2.61 | LB+PAIRS | T5 | yes | PASS | T5 |
| N53 | nominal unrefuted rather than confirmed | KEYS size | nominal_unrefuted x5 | yes | PASS | T3 |
| N54 | bc77070 largest (59), passes by 0.006: -0.226 vs 0.220, x1.25 | KEYS | — | 59 max; 0.0061 | PASS | T4 |
| N55 | bc77087's x1.39 holds only on 3.8 | KEYS, T6 | exp(0.3269) = 1.387; at 7.8 over sea-level ground x0.68 | yes | PASS | partly T6 |
| N56 | MRDEM at or above it on 112 frames | NP | elev >= flying_height on the five | 112; page figure < elev on all 107 read | PASS | T4 (count only, not the relation) |
| N57 | a shipped row reaches 107, every one catalogue figure under M.S.L. | LB+NP | T5 | 107; all within 2%, M.S.L. | PASS | T5 |
| N58 | other 5 have no row; misplaced only because per key | LB | — | yes | PASS | T5 |
| N59 | bc77026 221, 222, 237, 247 past 219 | LB | — | yes | PASS | T5 |
| N60 | row transcribed before fly#97, END final blank; blind re-read runs to 258; A2 kept it out | git blame a785bfd (#93); LB row 862 note; batchC_rows:13 | — | yes | PASS | no |
| N61 | bc77072 225 is on no page | S PAGES (bc77072_1..4), LB/ST | last page ends 223 | yes | PASS | T5 |
| N62 | fly#95's either-or settled by page at its word | logic | — | — | PASS | — |
| N63 | photos cannot reject other horn; D_agl uses a step shown wrong | logic | — | — | PASS | — |
| N64 | spacing not the photos' by at least x1.25; resolution on bc77070; bc77087 only on 3.8 | KEYS, T5 | — | yes | PASS | T4/T5 |
| N65 | A2 gloss wrong for step_overstated, round 1 found it; rule unchanged | FD:391 | — | yes | PASS | — |
| N66 | heading agrees on 233 of 237, none reverse | KEYS/STRIPS | dir_* | 233/237, 0 | PASS | T3, T4 |
| N67 | 4 differ: bc77087 1/2, 2/3, 3/4, bc77072 1981 frame 111 | STRIPS | dir == differ | exactly those | PASS | count only |
| N68 | of 285 matched pairs, 48 no legible heading or no strip | PAIRS/STRIPS | dir only on used pairs | 285, 48 | PASS | T4 |
| N69 | where tested no line reversed; all but 4 as page says | — | — | yes | PASS | T4 |
| N70 | images 0.858/0.840; step 0.857/0.843 | PAIRS | — | yes | PASS | T4 |
| N71 | spacing rejected them because window assumes ~60% | AG | overlaps > 0.780 | yes | PASS | — |
| N72 | readings 0.001 and 0.114 apart in D vs 2 tau 0.44 | KEYS gap | — | 0.0007, 0.1141, 0.440 | PASS | T4 |
| N73 | bc77026 remark; images 0.807 | KEYS | — | yes | PASS | T4 |
| N74 | bc80117 "80% FOREWARD O.L."; images 0.840 | KEYS | — | yes | PASS | T4 |
| N75 | bc77070 "Only 40% ... #271-#272"; 0.316 on that pair, 0.61-0.64 on neighbours | LB, PAIRS 268-271 | — | 0.3161; 0.611-0.644 | PASS (neighbours = the three preceding pairs; 271 is the key's last) | T4 |
| N76 | step 848 to 850 m on all of them | PAIRS | — | 847.88-849.63 | PASS | T4 |
| N77 | coordinates from BC Geographical Names | S PLACES | — | yes | PASS | — |
| N78 | bc7718 one row 31-69 at 5,000 ft writes "Tahsis - Zeballos"; strip 4 (46-69) "TAHSIS" | LB, ST | page title "Tahsis - Zeballos - Muchalat"; ST strip 4 46-69 TAHSIS | yes (the title is the page's; the row's strips bracket ZEBELLAS and TAHSIS) | PASS | no |
| N79 | census frames 46-69 are 359 km from Tahsis | KEYS km_to_place (nearest census frame) | — | 358.98 (all 46-69 359.0-359.4) | PASS | T4 (range not) |
| N80 | 31-45 catalogued 15 to 16 km from Tahsis (cache) | CC | x,y vs Tahsis (-126.664, 49.916) | 14.75-15.86 | PASS | no (non-shipped source, recomputes) |
| N81 | 5,000 ft exactly nominal for 1:5000 on 305 mm | arithmetic | 304.8 mm (12") x 5000 = 1524 m = 5000 ft | yes | PASS | — |
| N82 | bc80117 "YALE BLUFF" 97 km | KEYS | Yale community used; BCGN search finds no "Yale Bluff" feature | 97.5 | PASS | T4 |
| N83 | five step_overstated keys 6 to 36 km | KEYS | — | 5.96-35.83 | PASS | T4 |
| N84 | two blind reads; fly#93's reader read 3.8; 1,158 m = 3,800 ft | LB row 656 (9ee2114, #93) | "read as 3 not 7" | yes | PASS | — |
| N85 | fly#97's reader would not choose, leaned 7.8 | batchC_rows:54 | "reads most like 7.8 but could be 3.8; not interpreted" | yes | PASS | — |
| N86 | at 7,800 ft (2,377 m) above MRDEM ground on all 57 | TF+NP | — | yes | PASS | T6 |
| N87 | package would still find its 38 at r<=0 | catalogued height | — | yes | PASS | — |
| N88 | median 2,377 less MRDEM = 1,114, within 4% | TF+NP | — | 1113.8, 3.8% | PASS | T6 |
| N89 | relation ground_plus, W2 ground, stop fires | S:637-651, S:736 | round-3 re-run | yes | PASS | T6 (relation only) |
| N90 | the outcome fly#95's "What would change the answer" names | note fly#95 | — | yes | PASS | — |
| N91 | 2,377 / 1,158 = 2.05, near x2 | — | — | 2.053 | PASS | T6 |
| N92 | step bound "would fall to x1.15 to x1.59" over MRDEM 10th-90th (x0.68 sea level), under tau at low end | T6 `bound()` | quantiles of e | 10% x1.149, 25% x1.267, **50% x1.442**, 90% x1.590 vs x1.387 at 3.8 | **FAIL** (direction: only the sea-level figure and the low quantiles fall; over the median ground it rises) | T6 (values only) |
| N93 | only the W1 label is the same either way | S rules | at 7.8: size unsettled, location datum_question | yes | PASS | — |
| N94 | bc77070 flown same week, same project, 3,800 ft, read clear | LB rows 894, 656 | both 13/8/77, Op 94/77 | same day | PASS | — |
| N95 | which reading is right left open | — | — | — | PASS | — |
| N96 | fly_footprint draws these frames at nominal | R/fly_footprint.R:1352-1362 | unusable -> nominal_scale | yes | PASS | — |
| N97 | on the seven, nominal "no longer contradicted" | KEYS size | bc77087 at 7.8: W2 ground, size unsettled; page AGL median 1,114 m vs nominal 765 m (x1.46) | holds on 3.8 only for bc77087 | **FAIL** (unqualified; the next sentences qualify only the 38) | no |
| N98 | draws them at the catalogue's centroids | — | — | yes | PASS | — |
| N99 | "107 frames on five roll-heights" | NP+LB | roll-heights of the 107 reached | bc77026 2042 (7), bc77070 (59), bc77072 1981 (3), bc77087 (38): **four**; bc77072 1829's only r<=0 frame (225) is on no page | **FAIL** | no |
| N100 | 38 of them on bc77087's contested read | — | — | yes | PASS | T5 |
| N101 | bc77087's page 1 digit decides whether a page puts ground under | AG + T6 | no other page does | yes | PASS | T3/T6 |
| N102 | some pages log the intervalometer and the speed | LB, ST, the cached scans | no interval field in LB/ST; the 1977 form (`bc77070_4`) has "Exposure: Speed / Stop", i.e. shutter speed; LB's only "interval" mentions are remarks without a value | no producer | **FAIL** | no |
| N103 | on all seven measured keys the step or flown overlap was off the window, so rejection said nothing | KEYS | 5 step_overstated, 2 overlap > 0.78 | yes | PASS | partly T4 |

## inst/notes/terrain-correction.md, fly#95 sentences fly#97 changed or that mention it

| # | claim | producer | recomputed | verdict | pinned |
|---|---|---|---|---|---|
| F1 | catalogue's height on 669 of 689 frames read; none puts ground under, as transcribed; fly#97 found one page that would | AG | 661 + 8 = 669; 689; ground 0 | PASS | test-fly_footprint_above_ground |
| F2 | 31 of 154 rolls transcribed (26 at fly#95; fly#97 added the five of its nine keys' rolls that had none) | AG, LB vs LB on main | 31 / 154; 26 on main; new: bc5715 bc80117 bc77070 bc7718 bcc325 | PASS | yes |
| F3 | the other 123 not transcribed | — | 154 - 31 | PASS | — |
| F4 | headers say M.S.L. or name no datum; none names the ground | LB on population rolls | M.S.L. variants, "True Height" x2, NA x4 | PASS | — |
| F5 | 38 roll-heights with a frame the logbook reads | AG | 38 | PASS | yes |
| F6 | relation table 661 / 8 / 20 / 0 | AG | yes | PASS | yes |
| F7 | page "M.S.L." figure below ground on bc5602, bc77026, bc77072, bc77087, and bc5715, bc77070, bc7718, bc80117, bcc325 | LB x TF/NP | exactly those nine rolls (23, 7, 3, 38, 1, 59, 24, 19, 1 frames) | PASS | no |
| F8 | on bcc325 the page's figure is not the catalogue's | LB | 1,500 ft vs 1,300 ft | PASS | — |
| F9 | so either the column is not MSL or frames misplaced | logic | — | PASS | — |
| F10 | no transcribed page does; rule not amended | AG | ground 0 | PASS | yes |
| F11 | fly#97 measured seven of nine; two have one usable pair | KEYS | yes | PASS | T4 |
| F12 | on five step longer, rejection says nothing | KEYS | yes | PASS | T3 |
| F13 | on two flown ~85%, above the window | KEYS | yes | PASS | T4 |

## NEWS.md, development entry

| # | claim | verdict | note |
|---|---|---|---|
| W1 | on five of nine, photos show step longer, so rejection says nothing about scale | PASS | |
| W2 | no code change; every roll table byte-identical | PASS | `flying_height_rolls*.csv` untouched; AG moved in logbook columns, which W11 states |
| W3 | instrument reads no scale, height or centroid | PASS | |
| W4 | four controls ran before the nine | PASS | 7f9d8fb 07:54 < 16fd02e 08:07; script stops on a control |
| W5 | on five, nominal stands unrefuted | PASS | bc77087's contingency is in "An open question" |
| W6 | "By their logbooks against MRDEM, the frames there that sit under the terrain are not over the ground photographed" | **FAIL** | logbook reaches 107 of 112, on four of the five roll-heights (N99) |
| W7 | bc7718 and bc80117 ~85%, readings cannot be told apart | PASS | |
| W8 | bc77087's digit decides whether a page puts ground under | PASS | |
| W9 | CSVs ship every pair, control and verdict | PASS | |
| W10 | suite recomputes verdicts, table, listed figures | PASS | |
| W11 | five more rolls transcribed blind; moves logbook counts, no verdict | PASS | AG vs AG0: only frames_logbook/catalogue/other, logbook_ft differ |
| W12 | strips committed | PASS | |
| W13 | not done: #99 | PASS | |

## CLAUDE.md

| # | claim | verdict | note |
|---|---|---|---|
| A1 | overlap vs step | PASS | |
| A2 | patch_shifts gate via fns_from | PASS | |
| A3 | NCC seeds because global_shift wraps ~575 px and gates on spacing | PASS | |
| A4 | synthetic/unrelated/crew-written/bc85054 controls stop it before keys | PASS | (negative control also gates) |
| A5 | ships CSVs, test recomputes them, the table, listed figures | PASS | |
| A6 | reads blind strips file, never regenerated | PASS | |
| A7 | SMOKE writes nothing | PASS | S:579-581 |
| C1 | headline (five of nine, says nothing about scale) | PASS | |
| C2 | reads no catalogue field | PASS | |
| C3 | "By the logbooks, not the photos, the frames there that sit under the terrain are not over the ground photographed" | **FAIL** | as W6 |
| C4 | two others ~85% | PASS | |
| C5 | "Catalogue steps there are often evenly spaced along a digitised line (fly#82)" | **FAIL** | fly#82 measured equal steps; "along a digitised line" is a mechanism nothing measured; the note says "as if" |
| C6 | no-match is not "not adjacent"; floor direction; tau about x1.25 | PASS | 31 of 190 ordinary pairs fail to match |
| C7 | "Ground below sea level" = p_img > p_agl, withdrawn before keys (A2) | PASS | FD:135, 194 |
| C8 | "Its image leg does not test the logbook's datum either (code-check round 1)" | **FAIL** | "Its" = the withdrawn outcome; round 1's finding was about `misplaced`'s image leg (FD:391) |
| C9 | "bc77087's page 1 reads 3.8 or 7.8 (two blind reads, one each way)" | **FAIL** | the second read did not read 7.8; it declined to choose, leaning 7.8 (batchC_rows:54; the note and fly#99 say so) |
| C10 | at 7.8 first page to put ground under, close to x2 | PASS | 2.05 |
| C11 | transcription keeps 3.8 | PASS | LB row 656 |
| C12 | four rounds each found wider-set claims | PASS | |

## fly#99 body (identical to `planning/active/followup_issue_draft.md`)

| # | claim | verdict | note |
|---|---|---|---|
| I1 | "by their logbooks, the frames under the terrain on five roll-heights are not over the ground" | **FAIL** | four; the caveat "a few frames on bc77026 and bc77072" does not say bc77072 1829 has none (N99) |
| I2 | fly_footprint places at centroids; with `dem =` falls back to nominal where ground >= height, warns | PASS | "MRDEM ground" stands for whatever `dem` the caller passes |
| I3 | the five from KEYS location == misplaced | PASS | |
| I4 | page writes catalogue height under M.S.L., MRDEM at or above | PASS | on the 107 |
| I5 | photos show step longer; do not test datum | PASS | |
| I6 | bc77070 at resolution | PASS | |
| I7 | bc77087 read 3.8 by one, undecided leaning 7.8 by another; at 7.8 ground under | PASS | |
| I8 | a few frames on bc77026 and bc77072 have no row | PASS | 5 frames |
| I9 | bc7718, bc80117 unsettled; places far (TAHSIS, YALE BLUFF) | PASS | 359, 97 km |
| I10 | as fly_georef does for film rolls | PASS | |
| I11 | "catalogue steps on older rolls are often evenly spaced along a digitised line (fly#82's probe)" | **FAIL** | as C5 |

## data-raw/height_measure-image_overlap.R, lines 1-41

| # | claim | verdict | note |
|---|---|---|---|
| H1 | nine, 157, spacing rejects both | PASS | |
| H2 | ~60%; cannot say which; 64-77% 1965/75/85 | PASS | |
| H3 | image shift = 1 - overlap; no catalogue field | PASS | |
| H4 | logbook read blind before any image of the nine keys matched | PASS | 5138f19 07:47 < 16fd02e 08:07 |
| H5 | "The rule — every gate, tolerance and verdict — was fixed ... before any thumbnail was matched" | **FAIL** | A1 (after the smoke run had matched control thumbnails) changed the synthetic gate and renamed a verdict; A2 replaced the tolerance and added `indistinguishable`/withdrew an outcome; round 1 added `read_other` |
| H6 | gate >= 8 at step 64, >= 20 at step 32, median, via fns_from | PASS | S:181-189 |
| H7 | global_shift circular phase correlation at 1/4 res; wraps ~575 px; gates on spacing | PASS | F82:207-230 |
| H8 | NCC neither wraps nor reads centroids | PASS | |
| H9 | everything public | PASS | |
| H10 | run after terrain_tail and lower_tail_rolls (AG carries the join) | PASS | S:600-604, 637 |
| H11 | Stage 1 controls listed | PASS (incomplete: false-match and written controls are Stage 1 too) | |
| H12 | "Stage 2 the nine keys: every pair (n, n+1) on each key" | **FAIL** | census pairs only (A2, S:600-607): 366 of the keys' 431 catalogue pairs (bc77072 1981 64/98, bc7718 24/38, bcc325 2/11, ...) |
| H13 | SMOKE: 2 synthetic thumbnails, 3 control keys, separate cache, writes nothing | PASS | |

Totals: 172 claims, 14 FAIL (N24, N92, N97, N99, N102, W6, C3, C5, C8, C9, I1, I11, H5, H12).
