# Why the camera format table is built the way it is

Companion to `terrain-correction.md`. Read this before regenerating
`inst/extdata/camera_formats.csv` or changing `data-raw/make_camera_formats.R`.

Established in fly#32 (2026-08-30) against the live BC Data Catalogue.

## The catalogue's `SCALE` is not the true image scale for a digital frame

This is the finding everything else follows from, and it is counter-intuitive enough
that it will be re-proposed unless it is written down.

Measured on 40 UltraCam Eagle frames against MRDEM-30 terrain:

| route | width |
|---|---|
| `pixel count x GSD` | 6003 m |
| `sensor width x (flying_height - terrain) / focal` | 6070 m |
| `sensor width x SCALE` | **2081 m** |

The first two agree to ~1% and reproduce the catalogue's own `GROUND_SAMPLE_DISTANCE`
to a 1.011 median ratio — an independent check, since GSD is not used to derive either.

The tell that `SCALE` is derived rather than measured: the pixel pitch it implies,
`GSD x 10000 / scale_denominator`, is **~12.5 um for almost every camera regardless of
model** — against real pitches of 3.9 to 12 um. A field that returns the same constant
for a Leica DMC III and an UltraCam Xp is not describing either of them.

So a digital frame is sized as `pixel count x ground_sample_distance`, and `SCALE` is
never used for a frame `fly` sized itself. Sizing from it would draw a footprint at a
third of true width that still overlaps its neighbours and still yields a coverage
percentage — the failure #30 exists to prevent.

**`GROUND_SAMPLE_DISTANCE` is in centimetres.** See `fly_gsd_m()`. Getting this wrong is
a factor of 100 in every digital footprint and the field name says nothing about units.

## Why the table is keyed on `camera_calibration_url`

- `media` is a single value (`Digital - Colour`) across all 14 camera serials.
- `focal_length` is ambiguous: catalogue focal 92 spans an 87.1 mm DMC II and a
  100.3 mm DMC III, a 15% width difference.
- Serial 20814295 is **two different cameras** — an UltraCam Eagle through 2017 and a
  different body in 2018 whose own report numbers it 22814295. Only the full calibration
  file separates them, and the catalogue's URL basename is not a reliable serial.

## The five QA checks, and what each can and cannot catch

The numbers are parsed from PDFs, never typed. No single check is trusted alone; every
field is constrained by at least two drawing on different sources.

| | check | catches | blind to |
|---|---|---|---|
| B | `px x pitch == the report's stated mm`, both axes | any single wrong digit | rows where the report states only two of the three — the check is then vacuous and is **skipped**, not counted as a pass (`mm_stated`) |
| C | report focal vs catalogue focal | a row bound to the wrong camera | a camera with no catalogue focal |
| D | plausibility bounds | a unit slip (m / mm / um), which survives B by being self-consistent | anything inside the bounds |
| E | an independent second reading | a parse that read the right number from the **wrong field** | nothing else does this — B and D cannot see it |
| F | implied ground elevation must be a real BC elevation | gross errors, using only catalogue fields | measured: doubling every pitch makes just 8 of 14 cameras implausible. A gross-error net, not a precision one |
| G | the two sizing routes agree (runtime) | a mis-keyed camera | small width errors — GSD is integer centimetres, so at GSD 12 quantization alone is +/-4% |

**B is what gives precision. F is what gives independence. Neither substitutes for the
other.** If you weaken B, nothing else in the set is tight enough to replace it.

## Extraction traps met in these specific reports

- **`2001Opixel`** — a capital O for a zero, in the 2013 UltraCam report. Note that
  `gsub("[^0-9.]", "", x)` *deletes* the O and silently returns 2001. The substitution is
  made explicitly and check B proves it.
- **`Pixel Size [<U+F06D>m]`** — the micron sign is a Private Use Area codepoint from a
  Symbol font, so it is neither `µ` nor `μ`. A human reading the extracted text sees
  `[m]` and takes **metres**.
- **`Pixel Size 5.200 m`** — the same sign dropped entirely. The parser therefore anchors
  on the label and takes the first number on the line rather than matching a unit.
- **Panchromatic vs multispectral.** Vexcel reports format both blocks identically and
  put the multispectral one directly below. Anchoring on the heading is load-bearing;
  taking the wrong block is the one parse error the numeric QA cannot see, which is why
  check E exists.

## What is deliberately not shipped, and why

`inst/extdata/camera_formats_excluded.csv` carries the reason for every one. Two classes:

- **Not machine-readable** — the calibration exists only as a scanned image. An
  independent visual reading recovered the specs and they are recorded in the reason
  field, but they are not shipped: a row this generator cannot reproduce would break the
  guarantee that re-running it reproduces the table.
- **Contradicted by the catalogue's own fields** — `72914123_2019`'s GSD, SCALE and
  FLYING_HEIGHT are mutually inconsistent under its report's 4.0 um / 100.5 mm, implying
  an aircraft below ground. Withheld.

**Extrapolation across focal lengths is opt-in, per focal, with a written argument.** It
was a refusal list first, which encoded the one instance that had been measured rather
than the property. Distance does not predict the error: the refused focal-83 row reached
across a 3.6% gap and was 93% wrong (a 53.9 mm medium-format body against a ~104 mm
UltraCam), while focal 120 reaches across a larger 5.5% gap and is right. Only camera
identity separates them, and the generator cannot see it — so the default is no row.

## The mistake to avoid when changing `fly_footprint()`

Do not branch on `half_cross` / `half_along`. They are `NA` for every camera-table row
until a sizing route fills them, and the routes run in sequence — so a condition testing
them before all routes have run is testing *arrival order*, not a property of the frame.
This broke three separate conditions across three review rounds, each found inside the
previous round's fix, and each time the symptom was total and silent for a whole class of
frame. Branch on the recording format instead, which is known before any route runs.
