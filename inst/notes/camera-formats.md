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
  file separates them, and the catalogue's URL basename is not a reliable serial. That is
  a statement about the **key**, not about `report_serial`, and fly#50 turns it into a
  rule: a camera identity published elsewhere is matched against `report_serial` first and
  against the key only as a fallback. See "Resolving a camera the province named" below.

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


## Resolving a camera the province named (fly#50)

About 41,249 digital frames carry a `patb_georef_url` and **no** `camera_calibration_url`.
Until v0.10.0 they were sized only from `focal_length`, which fixes the sensor width to
within a few percent and says nothing about the pixel count — so `footprint_basis` read
`inferred_format` and the frame got no footprint at all without a DEM.

The PAT-B files those frames link to name the camera. `fly_camera_patb()` reads them and
`fly_camera_format()` turns the name into a format, which puts the frame on the ordinary
`px_cross x GSD` route. 22,366 of the 41,249 resolve; the rest are refused for a reason
that travels in `width_source`.

### The three schemas, and why dispatch is on columns

Measured 2026-09-06 over every archive those frames reference.

| schema | key | camera identity | GSD | where |
|---|---|---|---|---|
| bare CSV | `roll_frame` **and** `airp_id` | `camera` string, plus `lens_no` — which is 0 in both 2012 archives and 100044 in the 2011 one | `gsd` | 2011, 2012 |
| `gr_*` / `ccre_*` | `frm_roll_frame` | `ccre_lens_number`, `ccre_camera_type` | `seg_gsd` | 2013, 2015, 2016 |
| `eop_*` | `roll_frame` | `cam_s_no` | — | 2018-2019 |

**The file extension does not identify the schema.** The `.txt` inside one zip is a CSV,
the `.csv` inside another is a different schema, and a bare `.csv` is a third. `.ori` and
`.ORI` members carry full exterior orientation and no camera identity at all. Two of the
seven archives are **404s** answered with a 196-byte HTML body under a `.csv` name;
`utils::download.file()` sets FAILONERROR and raises rather than writing it, but any
client that does not — or a copy already cached by one — hands the HTML to the parser, so
absence is read from the content too.

### The serial index runs two passes, and the difference decides 14,717 frames

Serial `20814295` reaches five calibration rows: four UltraCam Eagles, plus the 2018 body
the catalogue **files** under 20814295 while the camera's own report numbers it
`22814295`, at 26460 x 17004 against 20010 x 13080. A single union index calls that
ambiguous and refuses every frame of the 2015 project that publishes it.

So: **`report_serial` tokens first, `key` tokens only as a fallback.** The key pass is
still needed, and not only for rows whose report gave no serial — the Intergraph DMC
reports itself `DMC01 - 0039`, whose longest digit run is `0039`, while a PAT-B lens
number for that body is `100039`, which only the key carries.

Two things that are easy to get wrong here and are silent:

- **Tokenise, do not concatenate.** `gsub("[^0-9]", "", "UC-Fp-1-20114172-f70")` is
  `12011417270` and matches nothing.
- **Strip the `_YYYY` suffix from keys first.** Left on, token `2014` reaches
  `20814295_2014` and `50311261_2014`, which *agree* on their format — so the ambiguity
  guard stays silent and any four-digit identity equal to 2014 resolves confidently to an
  UltraCam Eagle.

And build the index from `calib_file` rows **only**. The `focal_length` keys are bare
numbers, so a short serial hitting one gives `from_table = TRUE` with `px_cross = NA`: a
confident `footprint_basis` and no footprint, which is worse than the `inferred_format`
it replaced.

### A serial that is present but unknown REFUSES

`d_001_fi_16_georef.txt` labels **both** its cameras `UltraCam XP`. One of them is serial
`70912643` — `UC-SX-1-70912643`, an UltraCam **X** at 14430 px against the Xp's 17310. So
the province's own camera string is wrong for one of two bodies in a single file, and a
name fallback would size 1,790 frames 20% wide.

The name is read **only** where the archive carries no serial at all (`lens_no` is 0 on
every row of both 2012 archives), and then only on exact equality after normalising the
manufacturer prefix away. A prefix match would resolve the published `DMC II 230` from the
shipped `DMC II` row, and with it a DMC II 250 (17216 x 14656) or a 140 (12096 x 11200).

The same confusion is why `70912643_2015` shipped mislabelled `UltraCamXp` through
v0.9.0. The label now comes from the serial prefix in the generator, and a test asserts
that every calibration-row label maps to exactly one sensor size — which is the invariant
that makes the name route safe at all.

### The catalogue's GSD is 0 for whole years, so the PAT-B file supplies it

`GROUND_SAMPLE_DISTANCE` is **0** on all 24,742 digital frames of 2011 and 2012, and 25 on
all 16,507 of 2015 and 2016. Resolving the camera alone therefore leaves 2012 — the case
this issue was opened for — still unsizeable. `patb_gsd` fills the gap, and only where the
catalogue has nothing: where both are present they agree, and preferring the PAT-B value
would make a footprint depend on whether the caller happened to run the fetch.

### What it costs a DEM caller

A newly resolved frame becomes `by_gsd`, and `dem_eligible` is `!by_gsd` — so a caller
passing a `dem` now gets the GSD footprint where they used to get a terrain-corrected one.

Measured over every row of the three archives rather than an AOI subset, against the
exterior orientation the province publishes per frame. **`n` below is archive rows, not
catalogue frames** — an archive covers its whole project, including frames that carry a
calibration URL and never take this route, which is why the Eagle's 15,592 exceeds the
14,717 frames the resolve figures count (`sensor width x agl / focal`, both from the
PAT-B file itself), the GSD route and the optical footprint agree closely:

| camera | n | GSD route | exterior orientation | ratio | implied GSD vs stated |
|---|---|---|---|---|---|
| UltraCam Xp | 4,822 | 5,193 m | 5,220 m | 0.995 | 30.2 against 30 cm |
| UltraCam X | 2,827 | 4,329 m | 4,337 m | 0.998 | 30.1 against 30 cm |
| UltraCam Eagle | 15,592 | 5,002 m | 5,000 m | 1.001 | 25.0 against 25 cm |

So the change costs a DEM caller **at most 0.5%**, and in the direction of a slightly
narrower footprint.

The GSD-beats-DEM precedence was set in fly#32 and is not changed here. Note what this
measurement replaced: an earlier draft quoted 4,073 m and 4,066 m from an AOI subset in the
issue body and paired them with a 32.1 cm implied GSD taken from the **first row** of one
archive. Those two halves contradict each other — `px_cross x 0.321` is 4,633 m, not
4,066 m — and the single row was not representative: over 2,827 frames the median implied
GSD is 30.1 cm. Measure the population, not row one.

### Delivered image orientation for the newly reachable cameras

`fly_georef()` skips a frame whose delivered aspect does not pair with its footprint
edges, and its constant was measured on the two cameras in the bundled fixture only.
Measured 2026-09-06 against the live thumbnails, all three newly reachable bodies deliver
**portrait**, exactly as those two — image width is the along-track pixel count and image
height the across-track one:

| camera | thumbnail | px | shipped aspect |
|---|---|---|---|
| UltraCam Xp | `bcd12001_001_30_thumb.jpg` | 784 x 1200 | 1.531 |
| UltraCam X | `bcd12008_001_rgb_30_thumb.jpg` | 784 x 1200 | 1.532 |
| UltraCam Eagle | `bcd15101_001_25_8bit_rgb_thumb.jpg` | 818 x 1251 | 1.530 |

So these frames pass the aspect gate. That settles the pairing, not the quarter turn:
rotations 90 and 270 remain geometrically indistinguishable — see
`inst/notes/georeferencing.md`.
