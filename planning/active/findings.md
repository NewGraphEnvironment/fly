# Findings — Resolve inferred_format from the camera named in a frame's PAT-B file (#50)

## PAT-B schemas, measured 2026-09-06 against two live archives

Downloaded from `openmaps.gov.bc.ca/thumbs/patb_files/`, the same public route
`fly_fetch(type = "georef")` already targets and `data-raw/georef_calibrate-corner_mapping.R`
already reads.

| archive | file | rows | key column | identity columns |
|---|---|---|---|---|
| `d_003_fi_13_georef.zip` | `d_003_fi_13_georef.txt` | 5481 | `frm_roll_frame` (`bcd13300_001`) | `ccre_lens_number` (`121201`), `ccre_camera_type` (`DMC II 230`), `ccre_manufacturer` (`Zeiss`), `ccre_calibrated_focal_length` (92.0145) |
| `d_005_emn_19_georef.zip` | `D_005_EMN_19_georef.csv` | 6997 | `roll_frame` (`bcd19501_001`) | `cam_s_no` (`22814295`), `calib_date` (`2018-03-05`) |
| `d_003_fi_13_georef.zip` | `2013-093EKLMN_103HI.ori` | — | internal photo number | **none** |

Both archives are `.zip`, so **file extension does not identify the schema** — the `.txt`
inside the first is a CSV with a `gr_*`/`ccre_*` schema, and the `.csv` inside the second
is a distinct `eop_*` schema. Dispatch on the column names present.

### The join is serial digits, against both `key` and `report_serial`

- `ccre_lens_number` = `121201` is exactly the key prefix of `camera_formats.csv` row
  `121201_2011`.
- `cam_s_no` = `22814295` is exactly the serial inside that table's
  `report_serial = UC-EpII-1-22814295-f80` (row keyed `20814295_2018`).

So one index built from digits in both columns reaches both schemas.

### `ccre_calibration_report_url` is not a route

The `gr_*` schema carries that column and it is `NA` in every row of the sampled file.
It would have given the exact calibration key directly; it does not.

## The issue's two reported data problems: one real, one not

### Not a defect — `20814295` vs `22814295`

The issue reads the gap as "the key looks like the typo". It is not. `key` is the
catalogue's calibration URL basename **by construction**, and it is the only thing
separating the two camera bodies the catalogue files under one serial — an UltraCam Eagle
through 2017 and a different body in 2018 whose own report numbers it 22814295. This is
already recorded in `inst/notes/camera-formats.md` ("Why the table is keyed on
`camera_calibration_url`") and in `report_serial()`'s own comment in
`data-raw/make_camera_formats.R`. Changing the key would break the `calib_file` join.

The right conclusion is the opposite of the issue's: because `cam_s_no` matches the
*report* serial rather than the key, the index must read **both** columns.

### Real — `70912643_2015` is labelled `UltraCamXp` and is an UltraCam X

| | px_cross | px_along | pitch |
|---|---|---|---|
| UltraCam X (`UC-SX-`) | 14430 | 9420 | 7.2 µm |
| UltraCam Xp (`UC-SXp-`) | 17310 | 11310 | 6.0 µm |

The row carries `report_serial = UC-SX-1-70912643` and UltraCam **X** dimensions, so only
the label is wrong — nothing sized from it is affected today, because nothing joins on
`camera`. The cause is in the generator: `camera_name()` tests the pattern list
`c(..., "UltraCamXp", "UltraCam Xp", "UltraCam Eagle", ..., "UltraCam X", ...)` against
the whole report text and returns the first hit, so a report mentioning "UltraCamXp"
anywhere wins over the correct "UltraCam X". A regenerate reintroduces it.

## Errors Encountered

| Error | Resolution |
|-------|------------|
