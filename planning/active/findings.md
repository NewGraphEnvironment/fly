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

## MRDEM-30 provenance (NRCan product specification, Edition 1.2, 2025-06-20)

Read before any canopy surface is trusted. Source: `CanElevation-MRDEM-Product-Specifications.pdf`
(`https://ftp.maps.canada.ca/pub/elevation/dem_mne/MRDEM_MNEMR`), §7.2, §7.5, §7.6, §11.5.

- **The DTM is derived from the DSM outside lidar.** "Where available, the HRDEM Mosaic derived
  from lidar was used ... Elsewhere, the processing workflow combines a forest removal model and a
  settlement removal model that is applied to the GLO-30 values". The inputs named are the World
  Settlement Footprint and "the Canadian Forest Heights layer"; details "will be published shortly".
- So on `mrdem-30-source.tif` value **1** (adjusted Copernicus GLO-30), `DSM − DTM` **is NRCan's
  forest-removal model**, not an independent measurement of canopy. On value **10** (HRDEM lidar
  mosaic, resampled 1 m → 30 m) it is a lidar canopy surface. Value **5** is a blend buffer.
  Presence is not provenance: agreement between DSM−DTM and a canopy model tells us nothing if the
  model is where DSM−DTM came from.
- **Epochs:** GLO-30 2011–2015 (TanDEM-X). HRDEM 2006–ongoing, median project year 2018.
- **Accuracy (Table 2):** DTM derived from GLO-30, against HRDEM DTM: RMSE 4.99 m / LE90 8.07 m
  vegetated, 1.59 / 2.60 non-vegetated. DTM from HRDEM against RTK: 2.55 / 4.17 vegetated,
  1.04 / 1.69 non-vegetated. So the bare-earth surface the package sizes from is itself ~5 m RMSE
  under forest where it came from radar — an error that is not a bias of known sign.
- GLO-30 is X-band InSAR; its DSM sits below the true canopy top by an unknown, stand-dependent
  amount. The spec does not say whether the removal model corrects for that.

Consequence for the plan: the independent witness (Meta/WRI 1 m CHM, trained on ALS + GEDI,
Maxar imagery) is not optional. It is the only canopy magnitude here that NRCan's pipeline did not
produce.

## Decision rule — fixed 2026-09-30, before any frame is measured

### Quantities

Per frame, `H` = `flying_height`, film only (as fly#58/#65; a digital frame's `scale` is not an
image scale and fly#58 found almost none DEM-sized).

- **c̄** — mean of `DSM − DTM` (MRDEM-30) under the frame. Census: from coarse overviews, under
  the nominal footprint. Ray-cast sample: from the 30 m grids, under the returned rectangle.
- **p = c̄ / height_agl** — first-order predicted linear shrink of the true footprint relative to
  the DTM-sized rectangle (a DTM-sized frame is too wide by ≈ p).
- **T_dsm** — ray-cast of the returned rectangle's boundary onto the DSM (the #65 ray-cast,
  unchanged). **T_dtm** — the same onto the DTM (replicates #65's base).
- **W_dtm** = `fly_footprint(dem = DTM)` (the package today); **W_dsm** = `fly_footprint(dem = DSM)`.
- Errors are linear: `err_X = sqrt(area_X / area_T) − 1`.
- **Realised canopy shift** `r = sqrt(area_T_dtm / area_T_dsm) − 1`; first order predicts `r ≈ p`.
- **T_meta** — ray-cast onto DTM + Meta CHM aggregated (mean) to the DTM's 30 m grid, on a
  subsample; **c̄_meta** its mean canopy under the frame.
- **u** — the disturbed fraction of the footprint: the share of its area inside a BC consolidated
  cutblock (`WHSE_FOREST_VEGETATION.VEG_CONSOLIDATED_CUT_BLOCKS_SP`, `HARVEST_START_YEAR_CALENDAR`)
  or a historical fire perimeter (`WHSE_LAND_AND_NATURAL_RESOURCE.PROT_HISTORICAL_FIRE_POLYS_SP`,
  `FIRE_YEAR`) dated **between** the photo year and 2015 (the canopy epoch's end), or **within 40
  years before** the photo (so the photo saw young regrowth that has since grown). On such ground
  the modern canopy is not the photo's.

### Verdicts, in order

1. **Materiality (census).** MATERIAL if the 95th percentile of `p` over DEM-eligible film frames
   (reported heights inside `fly_height_ratio_band()`) is **≥ 1%** — the threshold #65 used for
   "matters". Reported overall, by scale band and by decade, with the share over 0.5% and 1%.
2. **Instrument checks (ray-cast sample), each must hold or the verdict it feeds is withheld:**
   - both synthetic controls pass (the #65 thresholds, unchanged);
   - **census calibration:** median ratio of census `p` to the 30 m `p` on sampled frames within
     [0.8, 1.25]; else the census is re-stated as biased by that factor, not used as is;
   - **first order:** median `|r − p| / p` under 10% on frames with `p ≥ 0.25%`; else the first-
     order formula is recorded as not holding and the ray-cast figures stand alone.
3. **Canopy magnitude is corroborated** if, on forested sampled frames (`c̄ ≥ 5 m`), the median of
   `c̄_meta / c̄` is within **[0.67, 1.5]**. Reported separately for source 1 and source 10.
4. **Outcome:**
   - **NOTHING** — not MATERIAL. The magnitude is recorded in the note; no doc change beyond that.
   - **RECOMMEND A DSM** — MATERIAL, **and** corroborated (3), **and** for at least one photo era
     (decade) the median `u` over its forested sampled frames is **under 0.25**, **and** on those
     frames `median(|err_W_dsm| − |err_W_dtm|) < 0` against T_dsm with a roll-bootstrap 95%
     interval excluding 0. Recommended only for the eras that pass; the others are documented.
     (The last clause is near-circular by construction and is kept to catch a defect, not to
     decide: T_dsm assumes the DSM is the imaged surface. The epoch clause is what decides.)
   - **DOCUMENT** — MATERIAL but any clause of RECOMMEND fails: the bias, its size by scale and
     era, and why a DSM is not recommended are written into `fly_footprint()` and the note.
   - Any outcome that would add an output column or change a default is a schema change and goes
     to the user at the PR; the rule does not license it.

### What the rule cannot see, stated before the run

- Growth of undisturbed stands between photo and canopy epoch (a 1950s stand is shorter than
  the same stand in 2013). Not in `u`; the DSM overstates such a frame's canopy. Unmeasured.
- Canopy on source-1 ground is NRCan's model; its X-band bias is unknown. Meta is the check.
- Cutblock and fire layers are incomplete before ~1950s–1970s; `u` is a lower bound there.
- The ray-cast shares the vertical-camera, no-tilt model with the package (#10 unchanged).
