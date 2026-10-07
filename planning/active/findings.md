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
