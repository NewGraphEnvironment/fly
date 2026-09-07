# Findings — Resolve inferred_format from the camera named in a frame's PAT-B file (#50)

## The population, measured 2026-09-06 against the live catalogue

`MEDIA == "Digital - Colour"` and `GEOREF_METADATA_IND == "Y"`, pulled per year 2005–2025,
then filtered client-side for a missing `CAMERA_CALIBRATION_URL`.

**41,249 frames** carry a PAT-B file and no calibration — the population this issue is
about, against the 207 the issue names, which were an AOI subset. They sit in four years
and seven distinct archives.

| photo year | frames |
|---|---|
| 2011 | 17,093 |
| 2012 | 7,649 |
| 2015 | 14,717 |
| 2016 | 1,790 |

**Filtering server-side does not work.** `dplyr::filter(CAMERA_CALIBRATION_URL == "")`
against the WFS returns **0 features** for a population of 41,249 — the column arrives as
`NA` in R and the CQL comparison matches nothing. The predicate must be applied after
`collect()`. A positive control (the same query without that one clause, for 2012)
returned 7,649 rows, which is what separated a broken probe from an empty world.

## The archives, measured

Seven distinct `patb_georef_url` values over those frames. **Two are 404s**, and they
download as a 196-byte HTML body under a `.csv` name — `utils::download.file()` reports
success, so this must be detected by content, not by exit status. See `code-check-r.md`,
"`download.file(quiet = TRUE)` never tells you the HTTP status".

| archive | catalogue frames | file inside | schema | identity | GSD |
|---|---|---|---|---|---|
| `d_001_fi_12_georef.csv` | 4,822 | bare CSV | `roll_frame` + `airp_id` | `camera` = `Vexcel Ultracam XP`, `lens_no` = **0** | `gsd` = 30 |
| `d_002_fi_12_georef.csv` | 2,827 | bare CSV | `roll_frame` + `airp_id` | `camera` = `Vexcel Ultracam X`, `lens_no` = **0** | `gsd` = 30 |
| `d_004_fi_11_georef.csv` | 11,826 | bare CSV | `roll_frame` + `airp_id` | `camera` = `DMC1`, `lens_no` = 100044 | `gsd` = 30 |
| `d_003_fi_11_georef.csv` | 4,354 | — | **404** | — | — |
| `d_006_fi_11_georef.csv` | 913 | — | **404** | — | — |
| `d_001_fi_15_georef.zip` | 14,717 | `.txt` (CSV) + `.ORI` | `frm_roll_frame` | `ccre_lens_number` = 20814295, `ccre_camera_type` = `Ultracm Eagle` | `seg_gsd` = 25 |
| `d_001_fi_16_georef.zip` | 1,790 | `.txt` (CSV) + 2 `.ori` | `frm_roll_frame` | `ccre_lens_number` = 10519431, `ccre_camera_type` = `UltraCam XP` | `seg_gsd` = 25 |

Two further archives were read while planning, both serving frames that already have a
calibration URL: `d_003_fi_13_georef.zip` (the `gr_*`/`ccre_*` schema) and
`d_005_emn_19_georef.zip`, whose `.csv` is a **third** schema — `roll_frame`, `cam_s_no`
(`22814295`), `calib_date`, `eop_*` — carrying a serial and no camera string.

So there are three schemas and they are **not** identified by file extension: the `.txt`
inside a zip is a CSV, the `.csv` inside a zip is a different schema, and a bare `.csv`
is a third. Dispatch on the column names present. `.ori` / `.ORI` files carry no camera
identity in any archive and the extension case varies.

### The joins are exact

Every archive joined 100% of its catalogue frames. Where both keys exist they agree.

| archive | catalogue frames | matched by `airp_id` | matched by `roll_frame` |
|---|---|---|---|
| `d_001_fi_12` | 4,822 | 4,822 | 4,822 |
| `d_002_fi_12` | 2,827 | 2,827 | 2,827 |
| `d_004_fi_11` | 11,826 | 11,826 | 11,826 |
| `d_001_fi_15` | 14,717 | — | 14,717 |
| `d_001_fi_16` | 1,790 | — | 1,790 |

`roll_frame` is `<film_roll>_<zero-padded frame_number>`, three digits in every archive
read — with frame numbers running to 990, so three digits is the observed width and not a
guarantee. Derive it from the file's own keys.

## What actually resolves: 22,366 of 41,249

| archive | frames | route | resolves to |
|---|---|---|---|
| `d_001_fi_12` | 4,822 | camera name | UltraCamXp, 17310 x 0.30 = **5,193 m** |
| `d_002_fi_12` | 2,827 | camera name | UltraCam X, 14430 x 0.30 = **4,329 m** |
| `d_001_fi_15` | 14,717 | serial 20814295 | UltraCam Eagle, 20010 x 0.25 = **5,002 m** |
| `d_001_fi_16` | 1,790 | — | serial 10519431 is not in the table — **refused** |
| `d_004_fi_11` | 11,826 | — | serial 100044 not in the table, `DMC1` is not a label — **refused** |
| `d_003`, `d_006_fi_11` | 5,267 | — | archive is a 404 — **refused** |

The 5,193 m figure reproduces the issue's own measurement exactly.

## Three things the measurement changed in the plan

### 1. The catalogue GSD is 0 for 2011 and 2012 — the PAT-B file must supply it

`GROUND_SAMPLE_DISTANCE` is **0** on all 24,742 frames of 2011 and 2012, and 25 on all
16,507 of 2015 and 2016. `fly_footprint()` requires `gsd_m > 0` for the `by_gsd` route, so
resolving the camera alone leaves 2012 — the issue's own headline case — with no footprint.

The PAT-B files carry the GSD themselves (`gsd` = 30 in the bare CSVs, `seg_gsd` = 25 in
the `gr_*` schema, agreeing with the catalogue where the catalogue has a value). So
`fly_camera_patb()` returns a `patb_gsd` column, and `fly_footprint()` uses it **only**
where `ground_sample_distance` is absent or 0. The catalogue column is never overwritten;
where the PAT-B GSD was used, `width_source` says so.

### 2. A serial that is present but unknown is a REFUSAL, not a licence to read the name

`d_001_fi_16_georef.txt` labels **both** its cameras `UltraCam XP`, and one of them is
serial `70912643` — which is `UC-SX-1-70912643`, an UltraCam **X** (14430 x 9420 @ 7.2 µm,
not 17310 x 11310 @ 6.0 µm). So the province's own camera string is measurably wrong for
one of the two bodies in a single file, and a name-first or name-fallback rule would size
those frames 20% too wide.

The rule that survives the measurement:

- **Serial resolves it.** Where the archive carries a serial that the table knows, use it.
- **A known-format serial always beats the name**, and the name is never consulted to
  correct it.
- **An unknown serial refuses.** Falling through to the camera string is exactly what
  would go wrong here.
- **The name is consulted only where the archive carries no serial at all** (`lens_no` = 0
  in the 2012 files), and only where the label maps to one format.

This narrows the plan's "serial wins where both are present" to "a present serial is the
only answer", and it is why the 1,790 frames of 2016 are refused rather than guessed.

### 3. The serial index needs two passes, not a union

Serial `20814295` reaches five table rows: four UltraCam Eagle calibrations (2013, 2014,
2016, 2017) and the 2018 row, which is keyed `20814295_2018` but whose report numbers the
camera `22814295` and whose format is different (26460 x 17004). A single union index
would call `20814295` ambiguous and refuse 14,717 correct frames.

**Try the `report_serial` index first; fall back to the `key` index only if that finds
nothing.** The serial a camera reports is its identity; the catalogue's key is the
filename the province filed it under.

| serial | report_serial index | key index | resolves |
|---|---|---|---|
| 20814295 | 4 rows, one format | 5 rows, two formats | UltraCam Eagle, from the report index |
| 22814295 | 1 row | — | UltraCam Eagle M3 |
| 70912643 | 1 row | 1 row | UltraCam X |
| 121201 | — (no report serial) | 1 row | DMC II |
| 100039 | — (`DMC01 - 0039` gives `0039`) | 1 row | DMC |

The ambiguity guard still applies within each pass.

## The issue's two reported data problems: one real, one not

### Not a defect — `20814295` vs `22814295`

The issue reads the gap as "the key looks like the typo". It is not. `key` is the
catalogue's calibration URL basename **by construction**, and it is the only thing
separating the two camera bodies the catalogue files under one serial — an UltraCam Eagle
through 2017 and a different body in 2018 whose own report numbers it 22814295. This is
already recorded in `inst/notes/camera-formats.md` ("Why the table is keyed on
`camera_calibration_url`") and in `report_serial()`'s own comment in
`data-raw/make_camera_formats.R`. Changing the key would break the `calib_file` join.

The right conclusion is the opposite of the issue's: because a PAT-B `cam_s_no` matches
the *report* serial rather than the key, the index has to read both — see change 3 above.

### Real — `70912643_2015` is labelled `UltraCamXp` and is an UltraCam X

| | px_cross | px_along | pitch |
|---|---|---|---|
| UltraCam X (`UC-SX-`) | 14430 | 9420 | 7.2 µm |
| UltraCam Xp (`UC-SXp-`) | 17310 | 11310 | 6.0 µm |

The row carries `report_serial = UC-SX-1-70912643` and UltraCam **X** dimensions, so only
the label is wrong. Nothing sized from it is affected today, because nothing joins on
`camera` — which is exactly why it matters before something does: it is the label the
2,827 UltraCam X frames of 2012 have to match.

The cause is in the generator. `camera_name()` tests `c(..., "UltraCamXp", "UltraCam Xp",
"UltraCam Eagle", "UltraCamEagle", "UltraCam X", ...)` against the whole report text and
returns the first hit, so a report mentioning `UltraCamXp` anywhere beats the correct
`UltraCam X`. A regenerate reintroduces it. The province makes the same mistake in
`d_001_fi_16_georef.txt`, which is corroboration rather than coincidence.

## The stated GSD is nominal, and the two sizing routes disagree by 7% on one camera

`agl x pitch / focal` against the stated GSD, from the 2012 files' own first rows:

| archive | camera | agl | implied GSD | stated GSD |
|---|---|---|---|---|
| `d_001_fi_12` | UltraCam Xp (6.0 µm, f100.5) | 5086.5 | 30.4 cm | 30 |
| `d_002_fi_12` | UltraCam X (7.2 µm, f100.5) | 4481.6 | 32.1 cm | 30 |

The Xp agrees to 1.2%. The X is 7% out, which is more than the ±1.7% that integer-centimetre
quantization alone can explain. It is not evidence against the camera identity — reading
`d_002` as an Xp instead gives 26.8 cm, an 11% error in the other direction, so UltraCam X
remains the better fit and the `UC-SX` serial in the sibling 2016 archive agrees. The
stated GSD is used regardless, which is what the existing digital route already does; the
disagreement is recorded so that a footprint 7% narrow on those 2,827 frames is a known
quantity rather than a surprise.

## Errors Encountered

| Error | Resolution |
|-------|------------|
| `dplyr::filter(CAMERA_CALIBRATION_URL == "")` returned 0 features for a 41,249-frame population | The WFS does not match an absent value that way. Collect first, filter in R. Found with a positive control, not by reading the query |
| Two `patb_georef_url` values download as a 196-byte 404 HTML page under a `.csv` name, exit 0 | Detect by content — a PAT-B file's first line is a quoted header naming a known key column |
