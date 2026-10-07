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
