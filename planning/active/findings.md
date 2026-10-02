# Findings — Ship measured per-roll film rotations as a table (#53)

## Issue context

## What changes if we do it

Film becomes georeferenceable without the caller doing their own calibration. #26 established that the corner mapping is **flight-relative but per-roll**, and measured two rolls:

| roll | year | rotation | margin |
|---|---|---|---|
| bc5282 | 1968 | 0 | 0.089 |
| bc83062 | 1983 | 90 | 0.135, 0.196, 0.152 (three legs) |

Shipping those as `inst/extdata/film_rotations.csv`, keyed on `film_roll` and consulted by `fly_georef()` before the refusal fires, would make those two rolls work out of the box and give later measurements somewhere to land.

## What happens if we never do

`fly_georef()` keeps refusing every rotated film frame with a warning naming the fix, and each user re-derives the same numbers for the same rolls. That is the *correct* default — refusing beats writing a GeoTIFF turned a quarter turn — so this is an improvement, not a defect.

## Why it was deliberately not done in #26

Two rows is a thin table, and a thin table invites the reading that an unlisted roll is **missing** rather than **unmeasured**. That is the failure `camera_formats_excluded.csv` exists to prevent on the digital side: every calibration deliberately not shipped is recorded *with its reason*. A film table needs the same discipline before it ships, plus enough rows that the fallback-to-refusal reads as a real state rather than as an omission.

## What would make it ready

- More rolls, spanning more eras. The 1968/1983 split is the whole evidence base for "per-roll", and two points cannot distinguish per-roll from per-era from per-scanner.
- A stated provenance column per row — which legs, what margin, measured when — since `data-raw/georef_calibrate-corner_mapping.R` reproduces the method but not the record.
- A decision on whether the key is `film_roll`, `photo_year`, or something about the scanning batch. `#26` could not settle this: the two measured rolls differ in both roll and era.

Method and full results: `inst/notes/georeferencing.md`, "Film has no constant". Reproduce with `data-raw/georef_calibrate-corner_mapping.R` section 4.


## Errors Encountered

| Error | Resolution |
|-------|------------|
