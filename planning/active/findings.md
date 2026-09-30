# Findings — Footprints are sized from bare earth, but over forest the camera sees the canopy (#80)

## Issue context

## Problem

`fly_footprint(dem =)` sizes a frame from the mean of a **bare-earth** DEM (MRDEM-30 is a DTM), but over forest the camera images the canopy top. So every frame sized over forest is drawn too wide by about `canopy_height × (land share) / height_agl`, in the same direction — the datum-offset kind of error #9 exists to remove, left at canopy height.

Found while measuring fly#65. There it matters because the land-and-sea mean the package uses (W) and the land-only mean (L) err in **opposite directions**, so a canopy offset changes which is closer. To first order (a uniform canopy over every land cell, not a re-run ray-cast), over 1,242 coastal frames:

| canopy on the land | median(\|W\| − \|L\|) | W area 95th, coastal | inland |
|---|---|---|---|
| 0 m | −0.00287 | 2.16% | 3.18% |
| 15 m | −0.00122 | 2.27% | 3.37% |
| 30 m | +0.00014 | 2.38% | 3.62% |
| 60 m | +0.00220 | 3.05% | 4.97% |

The inland column is the general point: an all-land frame takes the whole shift, so its 95th-percentile linear error goes from 3.18% to 4.97% under 60 m of canopy. Producer: the `canopy` lines of `data-raw/dem_measure-coastal_water.R` (fly#65).

## What is not known

- How much of the catalogue sits over canopy tall enough to matter, and how tall. No canopy-height model was used; the table is a uniform-canopy sensitivity, not a measurement.
- Whether the first-order formula holds against a ray-cast on a real DSM.
- Whether passing a DSM instead of a DTM is simply the answer — callers can already do that, and the documentation recommends MRDEM's DTM.

## Approach

Measure before deciding, as #58 and #65 did: pick a public canopy-height or DSM product covering BC, ray-cast a sample of forested frames against it, and compare the DTM-sized rectangle with the true footprint. Then decide between documenting it, recommending a DSM, or nothing.

## Errors Encountered

| Error | Resolution |
|-------|------------|
