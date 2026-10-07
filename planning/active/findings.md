# Findings — Frames under terrain where spacing rejects both nominal scale and the height read as above ground (#97)

## Issue context

## Problem

fly#95 tested whether the catalogued `flying_height` is a height above ground on the frames under terrain at or above the aircraft (`r <= 0`). On nine roll-heights, adjacent-frame spacing rejects **both** readings on offer: the catalogued height read as above ground, and nominal scale. These frames are drawn at nominal scale today, with a warning. Spacing does not support that fallback either.

| roll | height (m) | focal | scale | frames | of them `r <= 0` | overlap, above ground | overlap, nominal |
|---|---|---|---|---|---|---|---|
| `bc5715` | 732 | 153 | 1:4800 | 2 | 1 | 0.199 | 0.202 |
| `bc77026` | 2042 | 305 | 1:6000 | 118 | 11 | 0.479 | 0.419 |
| `bc77070` | 1158 | 153 | 1:5000 | 64 | 59 | 0.526 | 0.283 |
| `bc77072` | 1829 | 153 | 1:10000 | 17 | 1 | 0.355 | 0.228 |
| `bc77072` | 1981 | 153 | 1:10000 | 55 | 3 | 0.354 | 0.164 |
| `bc77087` | 1158 | 153 | 1:5000 | 57 | 38 | 0.478 | 0.209 |
| `bc7718` | 1524 | 305 | 1:5000 | 24 | 24 | 0.857 | 0.857 |
| `bc80117` | 1372 | 153 | 1:8000 | 19 | 19 | 0.860 | 0.843 |
| `bcc325` | 396 | 153 | 1:2000 | 2 | 1 | 0.285 | 0.075 |

The window is 0.557-0.780, from the generator. That is 157 `r <= 0` frames out of the 374. Source: `inst/extdata/flying_height_above_ground.csv`.

## Leads, none tested

- **Overlap below the window** (seven of the nine). The along-track side is longer than nominal, so the frames cover more ground than their scale says. The logbooks for `bc77026`, `bc77072` and `bc77087` write the catalogued heights under an M.S.L. header, and that figure is below MRDEM under some of the frames.
- **Overlap above the window** (`bc7718`, `bc80117`). The side is shorter than nominal. On `bc7718`, 1,524 m is 5,000 ft, which is exactly nominal height above ground for 1:5000 on a 12-inch lens.
- **A misplaced centroid.** A centroid on ground higher than the photo covers would give `r <= 0`, and spacing cannot see a translation. Thumbnails against the terrain could.
- **Frames that are not adjacent along one line.** The f1 air base rule takes the nearer neighbour by number. A roll flown in short legs could still pair frames across a turn.

## What to do

Decide whether any instrument can say what these frames covered. Fix any rule before running it, as in fly#60, #72, #93 and #95.

Related: fly#95, fly#93.


## Already known before the rule (plan-mode exploration, 2026-10-07) — NOT blind

Read before any rule existed, so nothing below is evidence the rule may be tuned against.

- **Catalogue centroids on these rolls are interpolated.** Consecutive steps inside a key repeat to the
  metre (`bc77087` 931 x 20, `bc7718` 161/164, `bc77026` 797/805). fly#82: "64-77% of consecutive bases in
  1965, 1975 and 1985 were equal within 0.5%", and `bc85054` 162's spacing was 2,353 m against ~1,360 m
  in the images (x1.7).
- **Steps inside a key jump.** `bc77026` 28,084 m and 2,627 m; `bc77070` up to 2,801 m; `bc77072` 94 km
  and 11.9 km; `bc77087` 6.6 km and 40 km; `bc7718` 372 km (two lines on one key); `bc80117` 3 km;
  `bcc325` 4 km. (Steps over the catalogue key, which reaches frames outside the census on 5 keys.)
- **Logbooks already read** (`data-raw/flying_height_logbooks.csv`, fly#60-#95) write the catalogue's
  height under "True Height (M'/M.S.L.)" on `bc77026` (6,700 ft, frames 140-219, "Pemberton Area",
  remark "Forward overlap seems excessive (75.9%)"), `bc77072` (6,500 ft frames 105-203 and 6,000 ft
  204-223, "Spences Bridge/Savona") and `bc77087` (3,800 ft frames 1-60, "Swan Lake Grindrod"). Height
  minus nominal height above ground: 213 m, ~451/~299 m, ~393 m — valley-floor heights; MRDEM medians
  under the catalogue's frames 1,729, 1,260/1,575, 1,264 m.
- `bc7718` 1,524 m = 5,000 ft = nominal height above ground for 1:5000 on 305 mm (implied ground 0 m).
- Centroid positions (lon/lat ranges) of every key were printed; `bc77087` 1-60 sit at 49.80-50.31 N,
  119.11-119.22 W. No thumbnail of any of the nine keys has been opened or matched.
- **Coverage.** All 8 rolls have a thumbnail on every frame and `FLIGHT_LOG_URL` pages (35 distinct).
  Untranscribed: `bc77070`, `bc7718`, `bc80117`, `bcc325`, `bc5715`.

## Why fly#82's `global_shift()` is not used unchanged

Its seed search is a circular phase correlation over the 1/4-resolution interior (~287 px of a 1,250 px
thumbnail less a 50 px margin), so a shift beyond half the window (~575 px, overlap under ~0.54) wraps
to a shorter vector of the other sign; and its candidates are gated to [0.25, 3] x a prediction made
from centroid spacing, the quantity under test. Both censor exactly the overlaps this issue needs.
So seeds come from a **zero-padded, masked normalised cross-correlation** (no wrap, no spacing input)
over the 1/4-resolution interior, restricted to shifts leaving at least 10% of the interior overlapping;
the ten highest local maxima are each confirmed by fly#82's own `patch_shifts()` (pulled with
`fns_from()`, not copied), and fly#82's own acceptance gate decides (best seed: >= 8 confirming
128 px patches at step 64; then >= 20 at step 32; shift = median of confirming patches).

## Decision rule — fixed 2026-10-07, before any thumbnail of the nine keys or the controls is matched

### W1 — image overlap, per pair

A pair is frames n and n+1 of one key (roll, flying_height, focal_length, scale). Thumbnails are
1,250 px square (1,249 on some), taken as the 9-inch format, as fly#82 does (`pitch = 228.6 / ncol`);
the collar's share is absorbed by the control.

- `p_img = 1 - |s| / L`, where `s` is the confirmed shift (row, col) in full-resolution px and `L` the
  thumbnail's side along the larger shift component. Dimensionless: no scale, height or centroid enters.
- `p_nominal = 1 - step / (0.2286 x scale_n)` and `p_agl = 1 - step / (0.2286 x flying_height / f)`,
  where `step` is the catalogue distance between the two centroids — per pair, not fly#95's f1 minimum.
- **Pair status:** `matched` (gate above), `no_match`, `no_thumbnail`. A pair whose `step` exceeds 3 x
  the key's median step is `line_break`: measured and reported, kept out of every median.

### Controls — run first; any gate failing stops the script and nothing is written

1. **Synthetic, known shift.** Five real control thumbnails, each paired with a copy of itself shifted
   by a known vector (overlap 0.20, 0.35, 0.50, 0.65, 0.80, 0.90; along rows and along columns; the
   uncovered strip filled from a different thumbnail), saved as JPEG 85. Gate: every case `matched`
   with `|p_img - p_true| <= 0.02`.
2. **Negative control.** Seed 9701. From the sweep's `random` frames in band (the population that set
   the window), film, photo_year 1970-1985, focal 153 or 305, draw 40 roll-heights whose median
   `p_nominal` (fly#95's f1 spacing) fits the window, and on each up to 5 pairs (n, n+1 on the key, not
   `line_break`), first pairs by frame number from a seeded start. Per roll-height with >= 3 matched
   pairs: `d = median(p_img) - median(p_nominal)`.
   - Gate: at least 30 roll-heights with >= 3 matched pairs, and `|median(d)| <= 0.05`.
   - **tau = the 95th percentile of |d|** over those roll-heights. Reported; not adjusted afterwards.
3. **Positive control.** `bc85054` 162/163 must be `matched` with `|p_img - p_nominal| > tau`.

### W1 verdict per key (first that fires)

1. `too_few_pairs` — under 3 matched non-break pairs. (`bc5715` and `bcc325` have one pair on the
   census key, so they land here by construction: 2 `r <= 0` frames.)
2. `not_adjacent` — under half of all the key's pairs matched (breaks included).
3. `consistent_nominal` — `|median p_img - median p_nominal| <= tau`.
4. `consistent_agl` — `|median p_img - median p_agl| <= tau`.
5. `disagrees` — neither; `k = (1 - median p_nominal) / (1 - median p_img)` reported. If the centroid
   spacing were the true air base, k is the true along-track side over the nominal one.

### W2 — the logbook

- **Height**, from the generator's own Stage 6 join (`flying_height_above_ground.csv`, re-run after the
  new transcriptions), not a second join here: `msl_catalogue` where `frames_logbook >= frames / 2` and
  `frames_catalogue >= 0.9 x frames_logbook` (the page writes the catalogue's figure, under a header
  that does not name the ground — M.S.L. or unlabelled, as in fly#95). Else `ground` where
  `frames_ground_plus + frames_ground_header >= 0.9 x frames_logbook` with the same coverage, else
  `not_read`.
- **Strip direction**, from the new strips transcription: per frame on a matched non-break pair, the
  page's strip heading against the catalogue bearing of the frame's step; `agree` within 35 degrees
  (allowing ~20 degrees of 1970s magnetic declination), `reverse` within 35 of the opposite, else
  `differ`. **Reported, not gating.**
- **Place**, verbatim. **Reported, not gating.** Overlap remarks: reported against `p_img`.

### The two outcomes per key

**Size:**
- `not_adjacent` / `too_few_pairs` — as W1.
- `nominal_confirmed` — W1 `consistent_nominal`.
- `agl_supported` — W1 `consistent_agl` and W2 height is not `msl_catalogue`. (`consistent_agl` with
  `msl_catalogue` is `unsettled`: the two witnesses conflict.)
- `nominal_by_elimination` — W1 `disagrees`, W2 `msl_catalogue`, and the side the images would need
  under the catalogue's spacing is physically excluded: `G_k = flying_height - k x scale_n x f_m < 0` (f in metres)
  (the ground under an aircraft at the logbook's M.S.L. height would be below sea level).
- `unsettled` — anything else.

**Location** (the `r <= 0` frames only):
- `misplaced` — W2 `msl_catalogue` and W1 not `consistent_agl` and W1 has a verdict (3-5): the crew
  flew the catalogue's figure above sea level, the images reject reading it as above ground, so the
  ground MRDEM puts under the catalogue's centroid (at or above that height) is not the ground
  photographed.
- `datum_question` — W1 `consistent_agl` or W2 `ground`.
- `not_tested` — anything else.

### What can change the package

Nothing, if the answer is `misplaced` / `nominal_*` (decided at the plan gate; a follow-up issue on
flagging such frames is filed instead). `agl_supported` on any key stops the work for the user's
decision on shape before `fly_footprint()` is touched.

### Order

1. This rule committed. 2. Logbook pages fetched and transcribed blind (catalogue values withheld,
control page each); generator re-run. 3. Controls (synthetic, negative, positive). 4. The nine keys.

### Amendment A1 (2026-10-07) — after the smoke run, before the real control draw or any key pair

The smoke run (`FLY_IMGOVL_SMOKE=1`, 2 synthetic thumbnails, 3 control keys, nothing of the nine) matched
every synthetic case at overlap 0.35-0.90 to within 1e-5, and none at 0.20. That is the reused gate's
geometry, not a defect: `patch_shifts()` places 128 px windows at least `MARGIN + 64 = 114` px from every
edge of *both* frames, so a pair must share roughly 230 px or more of a 1,250 px side before one window
fits — overlap about 0.25 or more. The rule demanded a capability fly#82's gate cannot have. Amended:

- **Synthetic gate:** every case with `p_true >= 0.35` matched, within 0.02. Cases at 0.20, 0.25 and
  0.30 (0.25 and 0.30 added) are measured and reported to state the floor; they gate nothing.
- **W1 verdict 2** is renamed `no_overlap` (was `not_adjacent`), same condition (under half of all the
  key's pairs matched). It means the frames do not share the overlap the matcher needs: either they are
  not adjacent along one line, *or* they were flown at under ~0.3 overlap. The two are not separated,
  and the note says so. The size outcome carries the same name.
- Nothing else changes: tau, the negative and positive controls, the order, and every other verdict.

Smoke figures (2 control keys, not the real draw): median d -0.020, tau 0.064; `bc85054` 162/163
p_img 0.603 against p_nominal 0.314. Reported here because they were seen; the real draw is
independent of them (same seed, 40 keys).

### Amendment A2 (2026-10-07) — from the plan review (`review-plan.md`), before the real control output was read

The real control draw was started (frozen copy of the A1 script) before this review arrived. Its pair
measurements are cached and reused; its log was **not read** before this amendment was committed, and
none of the nine keys has been matched. Each change below traces to a review finding, verified by
re-derivation where it is a claim.

1. **tau in log units, with a ceiling (B2).** Per control key, `d = log((1 - p_img) / (1 - p_nominal))`
   (the log of the step error the images imply). tau = 95th percentile of |d|. **Gate: tau <= log(1.25)**,
   else stop. `exp(tau)` is reported as the smallest step error the instrument can see. Every W1
   comparison below is in the same unit: `D_R = log((1 - p_img) / (1 - p_R))`.
2. **`indistinguishable` (B2).** Before the consistency tests, a key whose two readings differ by
   `|log ratio_asl| = |log((1 - p_nominal)/(1 - p_agl))| <= 2 tau` and whose images are consistent with
   either (`|D_nominal| <= tau` or `|D_agl| <= tau`) is `indistinguishable`. W1 order is now:
   `too_few_pairs`, `no_overlap`, `indistinguishable`, `consistent_nominal` (`|D_nominal| <= tau`),
   `consistent_agl` (`|D_agl| <= tau`), `step_overstated` (`D_agl < -tau` and `D_nominal < -tau`: the
   images overlap more than either reading allows at the catalogue step), else `disagrees`.
3. **`nominal_by_elimination` is withdrawn (B1).** It was the inequality `p_img > p_agl` restated
   (`G_k < 0 <=> k > ratio_asl <=> p_img > p_agl`; re-derived). What that inequality does show, given a
   height above sea level: the true height above ground is at most H, so the true side is at most
   `format x H / f`, so at the true air base the overlap is at most `p_agl`. Images overlapping more
   mean the catalogue step **overstates the air base**. It does not select nominal. The size outcome
   is renamed accordingly:
   - `step_overstated` (W1) with W2 `msl_catalogue` -> size `nominal_unrefuted`: the spacing that
     rejected nominal used a step longer than the air base, so it says nothing about the scale; nominal
     stands as the package default, neither confirmed nor refuted.
   - `consistent_nominal` -> `nominal_consistent` (images and the catalogue step agree at nominal; this
     rests on the step being the air base, which the location verdict may contradict — stated, untested).
   - `consistent_agl` -> `agl_supported` where W2 is not `msl_catalogue`, else `unsettled`.
   - `indistinguishable`, `disagrees`, and `step_overstated` without `msl_catalogue` -> `unsettled`.
   - `too_few_pairs`, `no_overlap` -> themselves.
4. **Location (B2).** `misplaced` needs W2 `msl_catalogue` and W1 in {`consistent_nominal`,
   `step_overstated`, `disagrees`} — the images reject reading the column as above ground, by more than
   tau, on a key where the readings are distinguishable. `datum_question`: W1 `consistent_agl` or W2
   `ground`. Else `not_tested` (including `indistinguishable`).
5. **W2 `ground` stops the work (B4).** fly#95 says a page naming the ground ships through the existing
   `factor != 1` branch. That is a package change, so any key with W2 `ground` or size `agl_supported`
   stops for the user's decision before `fly_footprint()` is touched.
6. **False-match control (G2).** Gate: frame n of one negative-control pair against frame n+1 of the
   next (different rolls), all of them: at most 5% `matched`. A matched shift with `p_img > 0.95`
   (fixed pattern: data panel, fiducials) is status `fixed_pattern` and counts as no match everywhere.
7. **Written-overlap control (G1).** Strips whose transcribed logbook row writes a forward overlap, one
   row per roll, frame range and figure from `flying_height_logbooks.csv`: `bc5598` 1-25, `bc78065`
   62-270, `bc79027` 190-204, `bc78153` 145-193, `bc7454` 1-123, `bc5561` 1-17, `bc78016` 11-31,
   `bc86103` 154-179 (80%), `bcc162` 1-110 (65%), and `bc77115` 67-116 (30%, under the floor: reported
   only). Up to 5 pairs (n, n+1 on one roll-height inside the range) from a seeded start. **Gate:** at
   least 6 of the 9 gated rolls with >= 3 matched pairs, and the median over them of
   `median p_img - written` within +/-0.08. (`bc79039` and `bc5138` change overlap inside a range at an
   unmapped frame; not used.)
8. **Pairs are the census frames' (G4).** A pair is n, n+1 on the catalogue key with **at least one
   frame in the two census files** — the population fly#95 judged. `bc5715` and `bcc325` then have one
   pair each and fall to `too_few_pairs`, as the rule already said.
9. **Page guard (G5).** Stage 2 stops unless every one of the 35 linked pages of the eight rolls
   appears in `flying_height_logbooks.csv` or the strips transcription.
10. **Logbook rows and fly#95 (B4, O2).** Before appending, the generator is re-run on the unchanged
    transcription and both roll tables must come out byte-identical (separating a catalogue change from
    a transcription effect). Only the five new rolls' rows are appended (`control = FALSE`); the control
    re-reads (batch C, `bc81027_4`, `bc78051_1`) are compared in scratch and never appended. After the
    append, `flying_height_rolls.csv` and `_excluded.csv` must stay byte-identical (else stop). fly#95's
    tests and note pin logbook counts that the five rolls change; those figures are updated, each
    marked as moved by fly#97's transcription, and fly#95's verdicts (`spacing`, `tabled`) must not move.
11. **Order deviation (O1), recorded:** the control draw ran before the generator re-run; the controls
    touch none of the nine keys, the transcription was already complete, and nothing read from either
    informs the other.

Not taken up, and why: interval x ground speed as a centroid-free air base (scope: a second
transcription pass; recorded as a lead in the note); a seed-selection rule other than fly#82's (the
false-match gate tests what it would protect against).

## Blind logbook read (Phase 3), 2026-10-07

Three general-purpose transcribers (told not to spawn), each given only page images and
`transcriber_brief.md` (fly#93's brief plus a per-strip `strips.csv`: strip, finals, heading, place,
overlap remark). No catalogue value reached them. Batch A: `bc80117` (7 pages), `bc5715` (5) + control
`bc81027_4`. Batch B: `bc77070` (4), `bc7718` (3, shared `bc7717_7718` pages), `bcc325` (5) + control
`bc78051_1`. Batch C: the 11 already-transcribed pages of `bc77026`, `bc77072`, `bc77087`, re-read for
strips — every one a height control. Raw outputs: `transcription/batch*_{rows,strips}.csv`.

**Controls, consolidated with fly#93's `consolidate.R`:** `bc81027_4` 138-164 6,500 ft 153 and
`bc78051_1` 1-131 22,500 ft 305, both exact. Batch C agrees with every existing row except:
- `bc77026_3`: blind 140-258 at 6,700 ft where the existing row stops at 219 (the earlier transcriber
  left the END final 258/259 blank).
- `bc77087_3`: 90-103 where the existing row reads 96-103 (its note already says the 96 "may be a 0
  overwritten as 6").
- **`bc77087_1` — the page that carries the `bc77087` 1158 key — the blind reader would not interpret
  the height**: "?.8 (7.8 or 3.8) ... reads most like 7.8 but could be 3.8; not interpreted". The
  existing row reads 3.8 with "first digit drawn with a flat top, read as 3 not 7". The catalogue's
  1,158 m is 3,800 ft. Under A2 the control re-read is never appended, so W2 for `bc77087` stays on the
  existing row (`msl_catalogue`). Recorded here because the location verdict for that key rests on it:
  at 7,800 ft (2,377 m) the frames would sit at r ~ 1.45 over the catalogue's ground, in band.

**New rows.** 37 consolidated rows on 24 pages appended (`control = FALSE`) for the five rolls. Every
page writes TRUE HEIGHT (M'/M.S.L.). On the keys: `bc5715` 82-84 2,400 ft (= 732 m), `bc77070` 209-272
3,800 ft (= 1,158), `bc7718` 31-69 5,000 ft (= 1,524), `bc80117` 32-50 4,500 ft (= 1,372), `bcc325`
66-72 1,500 ft (457 m; the catalogue's 396 m is 1,300 ft, which the page writes for 61-65).
139 strips (all eight rolls, controls excluded) to `data-raw/flying_height_logbook_strips.csv`.

**`bc7718` 46-69 is strip 4, heading 180, place "TAHSIS"** — a west-coast Vancouver Island inlet at sea
level. 5,000 ft is exactly nominal height above ground at 1:5000 on 305 mm, so the implied ground is
0 m; MRDEM under the catalogue's frames reads 1,677-1,908 m.

**Generator.** Re-run before the append: every shipped CSV byte-identical (79 s). After: `flying_height_rolls.csv`
and `_excluded.csv` byte-identical; `flying_height_above_ground.csv` moved only in the logbook columns of
the six keys on the five rolls (no `spacing`, `tabled` or `reason` moved). fly#95's pinned logbook
figures moved and were updated in its test, note and CLAUDE.md: roll-heights read 32 -> 38, frames read
576 -> 689, catalogue's figure 558 -> 669 (550 -> 661 + 8 ambiguous), neither 18 -> 20, rolls
transcribed 26 -> 31. NEWS.md's v0.23.x entry is release history and is not edited.

## Controls (Stage 1), real draw — 2026-10-07

A1 script (`run_controls_a1.log`, read only after A2 was committed) and A2 script (`run_controls_a2.log`)
over the same cached pairs. The A2 gates are the ones in force:

| control | result | gate |
|---|---|---|
| synthetic, p_true >= 0.35 | 50 of 50 matched, max error < 1e-4 | all matched within 0.02: PASS |
| synthetic floor | 0.20: 0 of 10; 0.25: 10 of 10; 0.30: 10 of 10 | reported |
| negative | 40 keys drawn, 39 with pairs, 192 pairs (159 matched, 31 no_match, 2 no thumbnail); 34 keys with >= 3 matched; median d -0.031; **tau 0.2199** (x1.246) | >= 30 keys, \|median d\| <= 0.05, tau <= log 1.25 = 0.2231: PASS, **narrowly on the ceiling** |
| false match | 38 unrelated pairs: 0 matched, 36 no_match, 2 no thumbnail | <= 5%: PASS |
| written overlap | 9 of 9 gated rolls, 5 of 5 pairs each; median p_img - written +0.018 | >= 6 rolls, within 0.08: PASS |
| positive | `bc85054` 162/163 p_img 0.603, p_nominal 0.314, \|D\| 0.548 | > tau: PASS |

- Under A1's p-unit definition the same draw gave tau 0.080 and median d +0.011; reported, superseded.
- The images agree with the crew-written overlaps on every roll (0.798-0.849 where 80% is written,
  0.656 where 65% is), and on those rolls with the catalogue spacing too (p_nominal 0.782-0.854).
- `bc77115`'s "30% overlap setting" reads 0.660 in the images and 0.656 by spacing: the note's
  setting is not the flown overlap (or not a forward overlap). Reported only, as fixed.
- On ordinary 1970-85 pairs 31 of 192 (16%) do not match. A key under half matched is `no_overlap`;
  a key at the ordinary rate is not.
- tau is set by the spread of the catalogue's spacing against the images on ordinary keys (95th
  percentile, 34 keys): the instrument cannot see a step error smaller than about x1.25.

## The nine keys (Stages 2-3) — 2026-10-07

366 pairs on the nine keys (census pairs, A2): 327 matched, 39 no_match. Page guard passed (35 of 35
linked pages transcribed). Re-run from cache: all five CSVs byte-identical (30 s).

| key | pairs (matched) | p_img | p_nominal | p_agl | D_nominal | D_agl | W1 | W2 | size | location | r <= 0 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `bc5715` 732 | 2 (1) | 0.527 | 0.196 | 0.194 | | | too_few_pairs | msl_catalogue | too_few_pairs | not_tested | 1 |
| `bc77026` 2042 | 118 (114) | 0.807 | 0.419 | 0.479 | -1.103 | -0.993 | step_overstated | msl_catalogue | nominal_unrefuted | misplaced | 11 |
| `bc77070` 1158 | 63 (53) | 0.622 | 0.283 | 0.526 | -0.641 | -0.226 | step_overstated | msl_catalogue | nominal_unrefuted | misplaced | 59 |
| `bc77072` 1829 | 18 (16) | 0.640 | 0.226 | 0.352 | -0.767 | -0.588 | step_overstated | msl_catalogue | nominal_unrefuted | misplaced | 1 |
| `bc77072` 1981 | 64 (53) | 0.615 | 0.114 | 0.316 | -0.834 | -0.576 | step_overstated | msl_catalogue | nominal_unrefuted | misplaced | 3 |
| `bc77087` 1158 | 57 (49) | 0.623 | 0.209 | 0.478 | -0.741 | -0.327 | step_overstated | msl_catalogue | nominal_unrefuted | misplaced | 38 |
| `bc7718` 1524 | 24 (23) | 0.858 | 0.857 | 0.857 | -0.010 | -0.011 | indistinguishable | msl_catalogue | unsettled | not_tested | 24 |
| `bc80117` 1372 | 18 (17) | 0.840 | 0.843 | 0.860 | 0.024 | 0.138 | indistinguishable | msl_catalogue | unsettled | not_tested | 19 |
| `bcc325` 396 | 2 (1) | 0.629 | 0.076 | 0.286 | | | too_few_pairs | not_read | too_few_pairs | not_tested | 1 |

tau 0.2199. `r <= 0` frames: location misplaced 112, not_tested 45; size nominal_unrefuted 112,
unsettled 43, too_few_pairs 2. No key reads W2 `ground` or size `agl_supported`, so nothing stops for
the user and the package does not change (Phase 5).

**What it says, key group by key group.**
- **Seven below the window (leads 1 and 4).** On the five keys with enough pairs the photos overlap
  0.62-0.81, an ordinary flight, where the catalogue's step says 0.11-0.42 at nominal. The step is
  1.9 to 3.0 times the air base the images imply at nominal (`k`; first written here as 2.1, from
  memory of the log; corrected by the note's prose test). At nominal only: see code-check round 1. The frames *are* adjacent (86-97% of
  pairs match). Given the crew's height above sea level, no size reading can bring the step down to the
  images', so it is the step that is wrong; spacing's rejection of nominal said nothing about scale.
- **Two above the window (lead 2).** `bc7718` and `bc80117` were flown at ~85% overlap: the images read
  0.858 and 0.840, the catalogue step gives 0.857 and 0.843. Spacing rejected them because the window
  assumes ~60%, not because a reading is wrong. The two readings coincide there (gap 0.001 and 0.114
  against 2 tau 0.44), so the rule cannot say which and leaves both `unsettled`.
- **Location (lead 3).** On the five keys, the page writes the catalogue's figure under an M.S.L. header,
  and MRDEM under the catalogue's centroids is at or above that height on 112 frames: by the page, those
  frames are not over the ground photographed. (First written as "the images reject reading it as above
  ground"; code-check round 1 showed that is not so for `step_overstated` — see below.) Headings agree with the
  catalogue's line bearings on 233 of 237 matched pairs on the five (264 of 268 over all nine; 4 differ,
  0 reversed), so the lines are not
  rotated or reversed; if the misplacement is a translation that keeps the step, the size statement
  stands, and that is an assumption the images cannot test.

**Corroboration outside the gates (reported, never gating):**
- `bc77026`: images 0.807 against the page's "Forward overlap seems excessive (75.9%)".
- `bc80117`: images 0.840 against "80% FOREWARD O.L.".
- `bc77070` 271/272: images 0.316, against 0.61-0.64 on the pairs around it, where the page writes "Only
  40% overlap between #271-#272". The catalogue step is 848-850 m on that pair and on its neighbours.
- Places against the catalogue's positions (`km_to_place`: nearest census frame centroid to the nearest
  place the page names, coordinates from the BC Geographical Names service, queried 2026-10-07; the
  first version of this bullet gave places from memory and overstated `bc77072`'s distance — the
  catalogue's frames do lie in the Spences Bridge-Savona corridor):
  - `bc7718` 46-69, "TAHSIS" strip 4: 359 km. The catalogue places frame 30 of the same roll at
    126.86 W, beside Tahsis, and 46-69 at 121.66 W. 5,000 ft is nominal height above ground at 1:5000 on
    305 mm, so the page's height puts the ground at sea level, as at Tahsis.
  - `bc80117`, "YALE BLUFF": 97 km.
  - The five `misplaced` keys: 6.0 to 35.8 km (`bc77072` 1981 6.0, `bc77087` 9.7, `bc5715` 13.5,
    `bc77026` 17.7, `bc77070` 33.1, `bc77072` 1829 35.8). A project area spans tens of km, so these do
    not discriminate, and the location verdict does not use them.
- **`bc77087`'s location verdict rests on a contested read.** The blind reader of page 1 would not
  choose between 3.8 and 7.8 (leaning 7.8). At 7,800 ft the frames' r would be > 0 and the key would not
  be `r <= 0` at all; its size verdict (`step_overstated`) holds either way (at 7,800 ft the catalogue
  step still implies 0.46 against the images' 0.62). `bc77070`, flown the same week over the same
  project at 3,800 ft, was read clear.

## Tests (Phase 6)

`tests/testthat/test-fly_footprint_image_overlap.R` recomputes every pair's p_img from its shift, both
readings from the step, the line breaks, every control gate and tau, and every key's W1, W2, size,
location and heading tally. tau from the shipped 4-dp values is 0.21978 against the script's 0.21990,
so it is pinned at 3 dp ("0.220"). Mutations, in a scratch copy of the tree: a flipped size verdict ->
red; one negative pair's p_img moved 0.10 -> red; W1 with `consistent_agl` tested before
`consistent_nominal` -> unchanged, as the review asked: no distinguishable key is consistent with both.

## Errors Encountered

| Error | Resolution |
|-------|------------|
| Synthetic 0.20 overlap never matches | The reused gate's geometry (128 px windows, 50 px margin): Amendment A1, floor reported |
| `gh issue create` GraphQL "Something went wrong" x2, REST "unexpected end of JSON input" | GitHub-side; nothing created; retried later |
| tau pinned at 4 dp fails from the shipped CSV | The CSV rounds p to 4 dp; pinned at 3 dp |

## Code-check round 1 (`review-round1.md`) — four findings, all real, all in what the documents claim

1. **The image leg of `misplaced` is vacuous on `step_overstated` keys.** A2(4) glossed the location verdict
   as "the images reject reading the column as above ground". But `step_overstated` says the step is wrong
   under both readings, so `D_agl`, computed with that step, cannot test the datum. On the five keys the
   location verdict is fly#95's either-or settled by trusting the page. The rule and verdict are unchanged
   (fixed before the data); the note now states the basis as the logbook against MRDEM and says what the
   photos do add (the catalogue's positions along each line are not the photos', under either reading).
2. **"1.9 to 3.0 times the air base" is `k`, which assumes nominal**, and NEWS used it to conclude nominal
   stands (circular). What holds under any side the M.S.L. height allows is `exp(-D_agl)`: x1.25 (`bc77070`),
   x1.39 (`bc77087`), x1.78/x1.80 (`bc77072`), x2.70 (`bc77026`). **`bc77070` passes `step_overstated` by
   0.006** (D_agl -0.2260 against tau 0.2199) — now stated in the note, NEWS and CLAUDE.md.
3. **`bcc325` shipped `w2_height = not_read` although its page was read** (1,500 ft against the catalogue's
   1,300). The residual class now splits: `read_other` (covered, under 90% either way) and `not_read`. Only
   `bcc325`'s label moved; no verdict depends on the split. An encoding fix after the run, not a rule change.
4. **Denominators:** headings 233 of the 237 matched pairs a transcribed strip reaches (285 matched);
   ordinary pairs 31 of the 190 compared did not match (2 no thumbnail); unrelated 0 of 36 compared
   (38 drawn). Note, NEWS and the test pins corrected.

## Code-check round 2 (`review-round2.md`) — four findings, all inside round-1 fixes

Mechanism, as the reviewer named it: each round-1 fix moved a claim onto a new basis and kept stating it
over the old set, which the new basis does not fully cover.
1. **Heading denominator still mislabelled.** 237 is the matched pairs whose strip writes a *legible*
   heading (`bc77026` 175-218 sit under "270 written over 090, both struck through"); a strip reaches 280
   of the 285 (none reaches `bc77072` 224-228). (My own first probe said 285 reach: it read empty strings
   as present — a broken probe, caught by re-reading with `na.strings = ""`.)
2. **The logbook basis covers 107 of the 112 frames.** `bc77026` 221, 222, 237, 247 lie past the
   appended row's 219 (only the unappended blind re-read reaches them); `bc77072` 225 has no page. They
   are `misplaced` only because the verdict is per key. Now stated and pinned (source-tree test).
3. **`bc77087`'s bound holds only on the 3.8 read.** At 7,800 ft: x0.68 over sea-level ground, x1.15 /
   1.44 / 1.59 over MRDEM's 10th/50th/90th percentile under its frames; W2 would be `read_other`, size
   `unsettled`. Only its W1 label is read-independent. Now in the note, NEWS and CLAUDE.md.
4. **Causal wording a lower bound does not support.** Removing only the minimum step error leaves nominal
   overlaps 0.428 / 0.430 / 0.502 (`bc77070` / `bc77087` / `bc77072` 1981), still outside the window, so
   "rejected nominal only because" and "the step, not the scale" overclaim; "says nothing about the
   scale" is what holds. Reworded in the note (three places) and CLAUDE.md (two).

## Code-check round 3 (`review-round3.md`, `claims_enumerated.md`) — an enumeration: 126 claims, 31 FAIL, 16 findings

**Mechanism** (the reviewer's, extending round 2's): a claim's set is taken from the label or framing
next to it, not from the producer that computes the property, and each claim lives in up to seven copies
(note intro, body, "What it leaves", the fly#95 pointer, NEWS, CLAUDE.md, fly#99 and its draft) that get
fixed one at a time; plus a counterfactual asserted rather than run.

**The substantive one.** Round 2 wrote that at 7,800 ft `bc77087`'s page "would read `read_other`". Run
through the generator's relation (the reviewer re-ran the generator in scratch with only that row at
7,800; I re-derived the arithmetic): the median over its 57 frames of 2,377 m less MRDEM is 1,114 m,
within 4% of 1,158, so all 57 are `ground_plus`, W2 is `ground`, and A2(5)'s stop would fire. That is
the result fly#95 tested for and found nowhere — on the reading the blind reader leaned to. 2,377 / 1,158
is 2.05, near the x2 slip. **The shipped transcription keeps fly#60's 3.8, so the rule does not stop; the
question of which digit is right goes to the user.** The note, NEWS, CLAUDE.md, fly#95's "none puts the
ground under it" and fly#99 now say so, and a test recomputes the relation at 7,800 ft.

**The rest, fixed by rewriting every copy at once and cutting the number of copies:** the step-is-wrong
claim scoped to five of nine (two were flown at 85%, two unmeasured); "ordinary flights" scoped to four
(`bc77026` 0.81, above the window); the 107 qualified by `bc77087`'s 38; "five roll-heights not where the
photos were taken" restated as 107 frames by the logbook; fly#99's heading label; "up to x1.25" (a 95th
percentile; 2 of 34 control keys exceed it, x1.34 and x1.41); "lines not rotated" limited to the pairs
tested (4 differ, 48 untested); "appended row" provenance (the 140-219 row predates fly#97); the
photo-leg restatement qualified; `bcc325` added to the "likewise" list; the post-run `read_other` split
recorded in the note; "interpolated evenly" as fly#82's 64-77%; "coincide" -> "cannot be told apart";
the floor stated as measured; the test name and NEWS/CLAUDE.md no longer claim every figure is pinned,
and the listed ones were added (157, 0.223, 2 of 34, the floor counts, 9 rolls, the 7.8 figures, 38 of
107, the catalogue-figure predicate on the 107). "Ships" -> "committed" for the strips file.

Copy sweep after the fix: each flagged phrase grepped across note, NEWS, CLAUDE.md and the fly#99 draft;
every remaining hit is scoped to its producer's set. Test: 191 pass.

## Code-check round 4 (`review-round4.md`, `claims_enumerated_round4.md`) — re-enumeration: 146 claims, 16 FAIL

Round 3's 16 fixes all landed in the note and the test; three older copies (fly#99, the fly#95 pointer,
"not rotated") still carried a round-3 defect, and one round-3 fix wrote a new wrong sentence (the floor's
"8- and 20-patch counts set the rest": the synthetic shifts all have one sign, 531 of 537 matched real
pairs the other, and the step-64 grid row is what sets it). Two new defects: `bc7718`'s "359 km from its
nearest catalogued frame" (the census set; 31-45 of the same row are catalogued 15-16 km from Tahsis),
and the 3.8 read attributed to fly#60 (it was fly#93's blind transcription, 9ee2114 — so the digit has had
two blind reads, one each way). Also: "would not be at `r <= 0`" for a variable the package computes from
the catalogued height; x2.70 includes `bc77026` pairs no shipped row covers (x2.61 over covered pairs);
"measured those nine"/"no longer contradict" over nine where two are unjudged; 38 unqualified in NEWS and
CLAUDE.md; 64-77% from 1965/75/85 stated over "1970s rolls" (and the script header still said
"interpolated evenly"); five test pins that could pass while their sentence was wrong.

**Fix, structural this time:** the note corrected claim by claim; NEWS, CLAUDE.md and fly#99 cut to a
handful of figure-free claims pointing at the note, so there is one copy of each figure; the five pins
replaced by assertions of what the sentences claim (window membership, refutes on all nine, the
synthetic error bound, the sign split, the covered-pair bound, reverse count 0). Script change is a
comment. Test: 200 pass.

## Code-check round 5 (`review-round5.md`, `claims_enumerated_round5.md`) — 172 claims, 14 FAIL

The round-4 structure held for figures: every figure left in the note recomputed, and NEWS, CLAUDE.md and
fly#99 carry none. What remained was the same mechanism without numbers: figure-free claims naming too
wide a set. The main one: **the logbook basis covers four roll-heights, not five** — `bc77072` 1829's only
`r <= 0` frame (225) is on no page. Others: the positive-shift floor is 0.18, not 0.19 (1 - 1022/1250);
the script header said the rule was fixed before any thumbnail was matched (A1 came after a smoke run)
and that Stage 2 measures every pair (it measures census pairs); CLAUDE.md said "two blind reads, one
each way" (the second declined to choose); "no longer contradicted" over seven holds on `bc77087` only on
3.8; "the bound would fall" (at the median ground it rises, x1.44 against x1.39); "some pages log the
intervalometer" had no producer (the "speed" column is shutter speed); "evenly spaced along a digitised
line" states fly#82's "as if" as mechanism; CLAUDE.md's "Its image leg" pointed at the wrong outcome; the
fly#95 CLAUDE.md decision dropped the "as transcribed" qualifier; fly#99 said "MRDEM" where the caller's
DEM is used; and five pins that could pass while their sentence was wrong (roll-heights of the 107, the
MRDEM >= height relation, 46-69, the differing pairs by name, the 9 rolls from the matches).

**Fixed mostly by deletion or narrowing**, so the fix introduced little new text. Test: 208 pass.

## Terminal enumeration (author, after round 5)

Round 5's table holds 158 PASS claims whose text did not change. The 14 FAIL rows are fixed above. The
new or changed sentences, each checked against its producer:

| new/changed text | producer | check |
|---|---|---|
| floor "down to about 0.18" | 1 - (1250 - 2 x 114)/1250 = 0.182 | pinned |
| bound "would move to x1.15 to x1.59 (against x1.39 on the 3.8 read), and to x0.68 over sea-level ground; under tau at the low end" | pairs + census elev at 2,377 m | pinned (x1.15, x1.59, x0.68; x1.39 pinned elsewhere); 1.15 < exp(tau) 1.246 |
| "no longer contradicted (on `bc77087`, only on its 3.8 read)" | keys CSV size; round-5 analysis at 7.8 (size unsettled) | consistent |
| "107 frames on four roll-heights ... 38 ... the fifth, `bc77072` 1829, has its one such frame on no page" | logbook join over nonpositive census | pinned (four keys, 107, 38, frame 225) |
| "The transcription records none" (centroid-free air base) | column names of both transcriptions | no interval/speed field |
| "older roll" | the nine keys are 1975-1982; fly#82's probe 1965/75/85 | scope narrowed, no figure |
| script header: rule fixed before any thumbnail matched, A1 after a smoke run, A2 from a plan review, `read_other` after the run | findings.md | matches the record |
| script header: Stage 2 census pairs | `kp` filter on `cen_rf` | matches the code |
| CLAUDE.md: four of them / steps often equal within 0.5% / keys marked `misplaced`, all `step_overstated` / fly#93 read 3.8, fly#97 declined leaning 7.8 / five rounds each found wider-set claims / fly#95 "as transcribed" | keys CSV (5 misplaced x step_overstated); git 9ee2114; rounds 1-5 records | each checked |
| NEWS: four of them | logbook join | pinned via the note |
| fly#99: five marked, four with logbook evidence, bc77026's four and bc77072 1829's one without; "DEM ground" | keys CSV, logbook join, `R/fly_footprint.R` | checked |

Nothing new sits above its producer. **The loop ends on this enumeration.** Spend: five review rounds
(rounds 3-5 enumerations), plus the plan review and three blind transcribers: nine subagents.
