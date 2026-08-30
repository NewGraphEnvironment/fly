# Findings — sensor widths for digital frames (#32)

All numbers below measured 2026-08-29/30 against the live BC Data Catalogue WFS
(`WHSE_IMAGERY_AND_BASE_MAPS.AIMG_PHOTO_CENTROIDS_SP`) and the calibration reports it
links to.

## Population

| | frames | share |
|---|---|---|
| whole catalogue | 1,670,471 | |
| `Digital - Colour` (the only digital media value) | 223,667 | 13.4% |
| digital with a `CAMERA_CALIBRATION_URL` | 179,311 | 80.2% of digital |
| digital resolvable to a sensor size | 171,233 | 76.6% of digital |

18 distinct calibration files, 14 distinct serials. Not the two cameras the issue
assumed, but a tractable set rather than a long tail.

## `SCALE` is not the true image scale for digital frames

The finding that most changes the work. Measured on 40 UltraCam Eagle frames against
MRDEM-30 terrain:

| route | width |
|---|---|
| `pixel_count x GSD` | 6003 m |
| `sensor_width x (flying_height - terrain) / focal` | 6070 m |
| `sensor_width x SCALE` (today's arithmetic) | **2081 m** |

The first two agree to ~1% and reproduce the catalogue's own `GROUND_SAMPLE_DISTANCE`
to a 1.011 median ratio — an independent check, since GSD was not used to derive them.
The implied pixel pitch from `GSD x 10000 / scale_denominator` is ~12.5 um for almost
every camera regardless of model, against real pitches of 3.9-12 um, which is the tell
that `SCALE` is a derived nominal figure rather than a measurement.

Consequence: shipping a sensor width while keeping the scale path would draw digital
footprints at a third of true size — still drawing, still overlapping, still producing
coverage percentages. Worse than #30's refusal.

## Sensors are not square

| camera | w x h mm | aspect |
|---|---|---|
| Leica DMC II 230 | 87.0912 x 79.2064 | 1.10 |
| UltraCam (all models) | ~103.9-105.8 x ~67.9-68.0 | 1.53-1.56 |
| Leica DMC III | 100.3392 x 56.9088 | 1.76 |
| Intergraph DMC | 165.888 x 92.160 | 1.80 |

`fly_rectangles()` builds squares. A square DMC III footprint is 76% too deep. Width
alone also spans 87.1-165.9 mm, so a single invented "digital" default would have been
wrong by up to 90%.

Orientation matters once footprints are non-square: the wide dimension is cross-track
(the Vexcel reports label it `cross track` explicitly), so the rectangle must be rotated
to the flight line. `fly_bearing()` already computes that.

## Keying

`media` is one value across all 14 cameras. `focal_length` is ambiguous — measured
against ground truth on frames that do have a calibration:

| catalogue focal | distinct widths | spread |
|---|---|---|
| 70, 79, 90, 127 | 1 each | exact |
| 100 | 4 | 1.9% |
| 80 | 3 | 5.5% |
| 92 | 2 (87.09 vs 100.34) | 15.2% |

Pixel count is far worse at the same keys — 32% spread at focal 80, 83% at focal 100 —
so a focal-keyed frame can be sized by width x AGL/focal but **not** by px x GSD.

Serial 20814295 is genuinely two cameras: UltraCam Eagle (20010 px @ 5.2 um) through
2017, Eagle Prime II (26460 px @ 4.0 um) in 2018 — and the 2018 report numbers itself
22814295, so the catalogue's URL basename is not a reliable serial. Only the full
calibration-file key distinguishes them.

## Unresolvable reports

| file | why | frames |
|---|---|---|
| `11937933_2009` (Rollei P65) | image-only PDF, 0 extractable characters | 443 |
| `12335326_2017` (PhaseOne) | image-only PDF, 0 extractable characters | 7,140 |
| `10210206_2015` | aerial-triangulation report, not a calibration certificate | 495 |

## QA results (pre-implementation run)

| check | result |
|---|---|
| B: `px x pitch == stated image size`, both axes | **15/15**, max rel. err 1.8e-16 |
| C: report focal vs catalogue focal | 14/15 — `dmc100039_2006` reports 120, catalogue 127 |
| F: implied ground elevation plausible | 13/14 — `72914123_2019` implies -414 m |
| G: two sizing routes agree | 1.1% median deviation over 40 frames |

Every report states pixel count, pixel size **and** image size independently, so B is a
real constraint on all rows rather than a restatement.

F's sensitivity, measured rather than assumed: doubling every pitch makes only 8 of 14
cameras implausible. It is a gross-error net; B is what gives precision.

### Two rows the QA flagged

- `dmc100039_2006` (4,052 frames) — report gives virtual focal 120 mm, catalogue records
  127. Ship with both recorded; GSD is 0 for all these frames so only the DEM route
  applies and focal enters linearly.
- `72914123_2019` (1,545 frames) — catalogue `GSD` 12 cm, `SCALE` 9600 and
  `FLYING_HEIGHT` ~2600 m are mutually inconsistent under the report's own 4.0 um /
  100.5 mm: implied AGL 3015 m exceeds the aircraft's height. GSD 8 cm or pitch 6.0 um
  would reconcile it; neither is supported. **Withheld.**

## Fixture

The bundled Houston AOI holds **181 digital frames** over the DEM that already ships:
76 `121201_2011` (Leica DMC II, aspect 1.10) and 105 `20814295_2018` (UltraCam Eagle
Prime II, aspect 1.56). Two very different aspect ratios, so the fixture can reach the
non-square branch.

This corrects `CLAUDE.md`, which says the AOI has no digital frame and that "digital
coverage cannot come from there". True of the 20 *sampled* photos (`photo_year == 1968`),
not of the AOI.

## Errors Encountered

| Error | Resolution |
|-------|------------|
| `BBOX(SHAPE,...)` CQL filter returned 0 for a **positive control** (an AOI known to hold 1,584 frames) | Not a data finding — a broken probe. Query bboxes through `bcdata::filter(BBOX(...))`, and always run a positive control before reporting an absence |
| `sed 1d f1 f2 f3` inside `find -exec ... +` strips only the first file's header | 23 stray header rows entered a 223k-row analysis silently. Loop per file: `for f in ...; do sed 1d "$f"; done` |
| `sed -n '/X/,$d' file` prints nothing | `-n` suppresses auto-print, so a delete-to-end script emits an empty file. Drop `-n` |
| WFS caps `GetFeature` at 10,000 features with no error | Page with `startIndex`, and reconcile the total against `resultType=hits` |
| MRDEM `/vsicurl` extraction over points scattered across BC exceeded a 10-minute timeout | For QA that only needs plausibility, invert for implied terrain from `FLYING_HEIGHT` and `GSD` instead — no DEM needed |
