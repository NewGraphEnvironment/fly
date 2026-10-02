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

## Infrared film is the 9-inch negative (fly#89)

Until fly#89, `fly_film_media()` named `Film - BW` and `Film - Colour` only. The catalogue's
infrared stocks fell through to `unknown_format` and drew empty footprints: `Film - BW IR`
(771 frames, 7 rolls) and `Film - Colour IR` (3,054 frames, 25 rolls). IR aerial film was
flown in the same mapping cameras as panchromatic, so 9 inches was the likely answer. But
fly#30 refuses to size a format on likelihood, because a wrong negative still draws a
plausible rectangle. So the format was measured first.

`data-raw/format_measure-infrared_film.R` produced every figure below. It ships five
`inst/extdata/infrared_film_*.csv`, and `test-fly_footprint_infrared.R` recomputes them. The rule
was pre-registered and then amended once after its first result. Both versions are in
`planning/archive/*issue-89*/findings.md`.

### Three witnesses

- **Spacing (W1, every roll).** This is fly#60's instrument: the air base to the adjacent frame
  number, set against the designed ~60% forward overlap.
  - Readings: implied overlap at 9 inches, from nominal scale, and from the reported height less
    MRDEM on frames inside the #54 band.
  - The window is 0.557 to 0.780: the central 95% over the sweep's 2,481 in-band random BW/colour
    frames.
  - Controls: those frames give a median of 0.635 at 9 inches and 0.343 at 5 inches.
  - The same medians are computed at 5 inches and 70 mm. A pass means 9 inches fits **and**
    neither alternative does.
- **Thumbnails (W2).** Only 4 rolls carry any: `bc5312`, `bc5367`, `bcc23` and `bcf07060` (422
  frames).
  - All 4 pass against the BW/colour sweep's 254 film frames: median aspect 1, collar fraction at
    most 0.0707.
  - `fly_mask()` declined none.
  - This is weak evidence. A thumbnail is resampled to ~1,250 px, and a 5-inch or 70 mm frame is
    square too.
- **Logbooks (W3).** 27 pages on 17 rolls, read by hand into
  `data-raw/infrared_film_logbooks.csv`.
  - 6 rolls write the format or name a 23 cm camera: `bc5312` and `bc5367` (RC 8, 9" x 9"),
    `bcc23`, `bcc7` and `bcc8` (Zeiss ZE.2, 9 x 9), and `bcf335` (RC 10).
  - The other 11 name only a camera serial and stay `unrecognised`: 110398, 110399, 122520,
    124223, ZE #1 and ZE #2.
  - No page names a camera of another format.

### The result

| | pass | ambiguous | no format fits | contradicts |
|---|---|---|---|---|
| `Film - BW IR` (7 rolls) | 5 | 0 | 2 | 0 |
| `Film - Colour IR` (25 rolls) | 22 | 1 | 2 | 0 |

**No format fits four rolls.** On `bcf07060`, `bci3`, `bci95063` and `bci96066`, the 9-inch
overlap medians are 0.19 to 0.27 on the nominal reading (0.11 to 0.27 on the reported height),
below the window.

- **The pre-registered rule called this a contradiction and stopped.** A smaller format makes
  implied overlap *lower*: `bcf07060` is 0.20 at 9 inches and -0.44 at 5 inches. Only a format
  larger than 9 inches could lift these rolls into the window.
- **Amendment 1 named the outcome `fits_no_format`.** It was written after the numbers and
  approved as such. The four rolls are recorded, neither pass nor contradiction.
- **The rolls themselves look like low-overlap flying.** Looked at by eye after the verdict,
  not measured: `bcf07060` frames 010 and 011 show eight fiducials and a `30BCC (IR) 07060`
  data strip, and share little ground. `bci95063` and `bci96066` were flown at the same 1:7000-7200 and 305 mm
  as `bci93044`/`bci93045`, which sit at 0.65.
- **It is far commoner on IR than on BW/colour.** Over the 6,680 BW/colour rolls with at least 5 air bases, 5.76% fall
  outside the window on the nominal reading, but only 13 (0.19%) sit at or below 0.30, all flown
  1972-1979. On IR it is 4 of 32 rolls, two of them from the 1990s and one from 2007. Why those
  missions flew so little overlap is not established; what spacing does establish is that no
  smaller format explains it.

**`bcf517` is ambiguous.** It has 13 frames at 1:4000 and 153 mm.

- On the nominal reading, both 9 inches (0.770) and 5 inches (0.587) fit.
- On the reported height, 5 inches fits (0.668) and 9 inches does not (0.816). So one reading
  favours the smaller format.
- It has no thumbnail and no logbook page.

It is sized at 9 inches with the rest of `Film - Colour IR`, and named here so nobody reads it as
confirmed.

### Why catalogue spacing is admissible here when fly#82 refused it

fly#82 refuses catalogue centroid spacing as a per-pair air base. Before the 1990s the
centroids are plotted evenly along a line, and one pair was ×1.7 off what its images showed.
19 of these 32 rolls predate 1990, so the question is fair. W1 differs from fly#82 in two ways:

- **It reads a roll median, not a pair.** This part is reasoning. Plotting a line's frames
  evenly spreads its true length over them, so the mean base survives even where one pair is
  wrong.
- **It is relative.** The window comes from BW/colour frames whose spacing was plotted the
  same way, so W1 asks whether IR rolls look like 9-inch rolls measured by the same instrument.
  The pre-1990 and later IR rolls scatter alike: the median per-roll coefficient of variation
  of base is 0.0916 (22 rolls) and 0.0925 (10 rolls).

fly#60 settled heights with the same instrument on the same eras.

### What spacing cannot separate

An 18 cm frame sized at 9 inches lands in the window on most rolls, so W1 cannot tell 23 cm from
18 cm, and 18 cm is not a W1 alternative. That separation rests on two things:

- **W3:** six rolls write `9 x 9` or name an RC 10.
- **A cross-check recorded alongside it, not a gate.** Every serial on an `unrecognised` page also
  appears on BW/colour pages in `data-raw/flying_height_logbooks.csv`, on rolls fly sizes at
  9 inches. For example, 110399 flew `bc7717`, `bc78153` and `bc80122`. A mapping camera's format
  is fixed by its body.

### What changes for a caller

- **IR frames are sized, everywhere.** They are now `footprint_basis = "Film - BW IR"` /
  `"Film - Colour IR"`, and `fly_coverage()`, `fly_select()`, `fly_overlap()` and `fly_filter()`
  count them.
- **The #54 height check now reaches IR frames.** The band and slip factor were calibrated on BW
  and colour film only (the ceiling on BW/colour film and digital). On IR, 3,769 frames sit
  inside the band, 56 outside it, and none is slip-repairable.
- **Those 56 are not right at nominal scale.** They sit on three roll-heights: `bc5312`,
  `bci12` and `bci9`.
  - On each, spacing fits the reported height (0.594, 0.620, 0.620) and rejects nominal
    (0.805, 0.807, 0.228). Each logbook page writes the catalogued height: 11.0, 12.08 and
    19.5 thousand feet.
  - So each is a right height beside a wrong `scale`, the defect fly#60 and fly#72 tabled for
    BW and colour.
  - Only `bci9` falls in a population those rules read. Its height is 2.436 times
    `scale x focal` above sea level, inside #72's `near_upper`. `bc5312` (0.731) and `bci12`
    (0.762) leave the band only through terrain, which neither rule reaches.
  - Until fly#91 tables them, they are drawn at nominal scale, with or without a `dem`. That
    is about 2x (`bc5312`, `bci12`) or 0.5x (`bci9`) the width the spacing supports.
- **Callers already sizing IR through `format_size` see the change.** A caller passing
  `format_size = c("Film - Colour IR" = 9)` already sized these frames, but skipped the #54
  check; it now applies.
- **`fly_camera_format()` no longer considers IR frames.** Before, they reached its digital
  branch and only failed to resolve because no focal-length fallback matched 153 or 305.
