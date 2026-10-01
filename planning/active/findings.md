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

## Stage 1 probes (2026-09-30, `data-raw/.cache/logs/canopy_stage1.log`)

Versions: DTM etag `1bf05585…-9997`, DSM `83dec85a…-9994`, source `2fe298cc…-20`, all modified
2026-06-24. Cache key `d2eaafb5`.

- **Sea:** DSM equals DTM at every readable fly#65 sea site (mean difference 0.00, p95 ≤ 0.48 m at
  Howe Sound). So a DSM changes nothing over sea and fly#65's W/L verdict is surface-independent
  there. Three sites read nodata in both (as in #65).
- **Lidar cells (source 10):** MRDEM DSM − DTM equals HRDEM 2 m DSM − DTM averaged to 30 m:
  6.06/6.11, 1.21/1.22, 2.65/2.65, 17.01/17.02. Confirms source 10 *is* HRDEM there.
- **Radar cells (source 1):** Revelstoke, the one site where newer lidar covers radar cells (87 of
  10,201 cells): MRDEM DTM 9.21 m above lidar ground; lidar canopy 20.9 m against MRDEM's 11.3.
  One site, 87 cells — the reason the lidar-over-radar probe exists.
- **Noise floor:** the non-forest sites were chosen badly — "okanagan_lake" and "chilko_lake" windows
  hold forested shore (DSM − DTM mean 6.1 and 4.2 m). Alpine plateau (Spatsizi, radar) reads 1.52 m
  mean; Chilcotin grassland 4.15 m (Meta 0.49); Peace farmland 3.76 (Meta 4.01).
- **Meta against lidar:** 3.10/6.11, 0.37/1.22, 2.55/5.06, 0.52/2.65, 13.11/17.02 — Meta reads
  roughly half of lidar across these sites, consistent with the review's under-read warning. Units
  are centimetres (carmanah 17.13 m against MRDEM 14.89).

## Amendment 1 — fixed 2026-09-30 after the Stage 1 probes, before any frame is sized

Supersedes "Verdicts, in order" above where they differ; the quantities list stands, with these
changes. Reasons are in `review-1.md` (B1–B3, G1–G6).

**Instrument roles.** MRDEM DSM is the canopy surface throughout. On lidar cells it is measured
(epoch of the lidar project). On radar cells it is GLO-30 (2011–2015) and its offset from the DTM is
NRCan's removal model; the lidar-over-radar probe is the check. Meta is reported and not decisive.
T_meta is dropped (it would add a canopy height to a DTM that may already hold some).

**Population and sample.** Denominator: every DEM-eligible film frame (#58's definition). Census:
DSM and DTM overviews read together (`-r average`, identical window and size, asserted on one grid),
mean canopy under each nominal footprint, `p_census = c̄ / (scale × focal)`. Used only to stratify.
Sample: single frames drawn at random within strata of `p_census` × scale band, design weight
`N_h / n_h`. Every percentile below is weighted.

**Per sampled frame:** `fly_footprint()` on DTM and on DSM. Admitted only where both return
`footprint_terrain == "dem_agl"`, `height_source == "reported"` and `dem_coverage ≥ 0.95`; frames
whose classification differs between the two surfaces are counted and reported.

1. **MATERIAL** if the weighted 95th percentile of `d_c = side_dtm / side_dsm − 1` is **≥ 1%**.
   Why 1%: #58's per-corner ray-casting is worth ~2% on every frame and is deferred, so a
   bias under half that is below what the package already accepts.
2. **Rectangle model not degraded** if the weighted 95th of `|ρ_dsm|` is no more than the
   weighted 95th of `|ρ_dtm|` **+ 0.01**, where `ρ_X = sqrt(area W_X / area T_X) − 1`.
3. **Canopy instrument valid on radar cells** if, over the lidar-over-radar probe windows, the
   through-origin slope of `imaged_over_dtm` (lidar DSM − MRDEM DTM) on `mrdem_canopy`
   (MRDEM DSM − DTM) is within **[0.67, 1.5]**. Outside it, MRDEM's DSM misstates the imaged
   surface on radar cells by more than a third, and the rule treats the canopy magnitude as
   **UNRESOLVED** there (the lidar-cell share is still judged).
4. **Epoch**, per photo decade, over admitted sampled frames with `d_c ≥ 0.5%` (capped at 250,
   drawn with probability proportional to weight): VRI (`VEG_COMP_LYR_R1_POLY`, rank 1) stand
   origin `O = year(PROJECTED_DATE) − PROJ_AGE_1` and height `h = PROJ_HEIGHT_1` per polygon under
   the footprint. `c_then = h × (py − O) / (cy − O)` where `O ≤ py` (linear height with age — this
   understates how short a young stand is, so it understates harm); where `O > py` the stand at the
   photo was the one since replaced, whose height is unknown, and `c_then = h` (neutral). `cy` =
   2013 on radar cells. Per frame, DTM error ∝ mean `c_then`, DSM error ∝ mean `(c_then − c_now)`.
   **Epoch holds for a decade** if the weighted share of its frames where the DSM error exceeds
   the DTM error is **under 10%**.
5. **Outcome:**
   - **NOTHING** — not MATERIAL.
   - **UNRESOLVED** — MATERIAL, and 3 fails: record the magnitude from lidar cells and the probe.
   - **RECOMMEND A DSM** — MATERIAL, 2 and 3 hold, and 4 holds for at least one decade:
     recommended for those decades, documented for the rest.
   - **DOCUMENT** — MATERIAL, anything else.
   - Adding a column or changing a default is a schema change and goes to the user at the PR.

Witness disagreement that sends a figure to UNRESOLVED (AC4) is clause 3. Meta disagreeing with
lidar does not, since it has been observed reading about half of lidar before any frame was sized.

## HRDEM cannot witness MRDEM's radar cells (2026-09-30, `canopy_stage1c.log`, the Stage 1 probe)

- The first lidar-over-radar probe sampled HRDEM's **DSM** coverage and every window came back
  empty — and `do.call(rbind, <all NULL>)` cached a NULL, so the next line crashed rather than the
  probe refusing. Guard added: fewer than 30 windows stops and caches nothing.
- Cause: HRDEM's DSM reaches far past its DTM (partition 1_5: 41 GB of DSM, 5.8 GB of DTM). On
  radar cells, 2 m texture shows that extra DSM is smooth far-north surface (sd 0–12 m at 2 m lag),
  not lidar.
- Sampled on HRDEM's **DTM** coverage: **0 of 3,000** random points over BC sit on MRDEM radar
  cells. MRDEM took lidar ground everywhere HRDEM had it, so HRDEM is not independent anywhere in
  BC. (Revelstoke's 87 cells were an edge case of the site window, not a population.)

## Amendment 2 — fixed 2026-09-30, before any frame is sized

Clause 3's witness becomes **LidarBC** (public `stac-elevation-bc` collection, images.a11s.one):
1 m tiles, a bare-earth DEM and, on 95,888 of 102,460 tiles, a DSM from the same flight, CGVD2013.
Windows are whole LidarBC tiles (~1.5 km) under random MRDEM radar cells over BC land, newest tile
with both assets, only radar-sourced MRDEM cells with all four values. Clause 3 itself — the
through-origin slope of `imaged_over_dtm` on `mrdem_canopy` within [0.67, 1.5] — is unchanged.

Stated before the probe runs, so it cannot be tuned to it:
- LidarBC is mostly flown 2016 on, MRDEM's radar 2011–2015. Harvest and fire between the two
  lower the lidar canopy where the radar saw forest, so the slope is **biased low** by disturbance
  in the gap. It is reported with the tile years and not corrected.
- `dtm_resid_open` (MRDEM DTM minus lidar ground on cells the lidar calls open, canopy < 1 m) is
  the datum and ground-model error without canopy; `dtm_resid` over all cells minus it is residual
  canopy left in MRDEM's DTM.

## LidarBC probe — clause 3 (2026-09-30, `data-raw/.cache/logs/canopy_stage1g.log`)

150 windows (LidarBC tiles, median 2,690 radar-sourced MRDEM cells each) from 528 random radar
points; 155 sat under a tile with both DEM and DSM. Tile years: 2024 85, 2025 25, 2021 17, 2023
11, 2022 10, 2019–2020 2 — all after GLO-30. No read failed twice.

| per window, metres | median | 10th | 90th |
|---|---|---|---|
| MRDEM DSM − DTM (NRCan's removal model) | 7.75 | 2.66 | 11.81 |
| LidarBC DSM − DEM (measured canopy) | 4.25 | 0.73 | 10.37 |
| MRDEM DTM − lidar ground | −2.50 | −5.59 | 1.55 |
| same, on lidar-open cells | −1.66 | −4.98 | 1.91 |
| MRDEM DSM − lidar DSM | +0.34 | −2.51 | 4.01 |
| lidar DSM − MRDEM DTM (imaged over what fly sizes from) | 7.10 | 1.95 | 12.47 |

- **Clause 3 holds:** slope of `imaged_over_dtm` on `mrdem_canopy` through the origin **0.916**,
  inside [0.67, 1.5].
- It holds by **cancellation**: MRDEM overstates canopy against lidar (slope 1.209, correlation
  0.648), and its radar-derived DTM sits ~2.5 m *below* lidar ground — over-removal, not the
  residual canopy the review feared. The radar DSM is within 0.34 m of the lidar surface. So on
  radar cells the surface fly should size from is MRDEM's DSM to within ~10%, and MRDEM's DTM is
  ~7 m under it in the median.
- Meta reads 0.969 of lidar here (through origin) — much better than the five sites suggested.
- Two defects found and fixed on the way, both in the probe: undeclared −3.4e38 nodata in some
  LidarBC tiles (means of 1e37 published in a first complete run), and a 6.5-hour run caused by
  `terra::project()` over remote strip-organised TIFFs (tiles are now downloaded, 1.5 s each).

## Errors Encountered (probe)

| Error | Resolution |
|-------|------------|
| Lidar probe cached `NULL` (all windows empty) and crashed downstream | Refuse below 30 windows; HRDEM sampled on DTM coverage — then found to cover no radar cells |
| `TIFFFillStrip: Read error` aborted 6.5 h of LidarBC windows | Per-window cache, one retry, failures counted |
| LidarBC means of 1e37 | Undeclared nodata; clamp to [−100, 5000] m |
| 6.5 h for 150 windows | Download each tile (strip TIFF), project locally |

## Amendment 3 — fixed 2026-09-30 from code-check round 1, before any VRI query has run

Clause 4 (epoch) as Amendment 1 wrote it had three defects, all found by review before Stage 4
ever ran (the full run was stopped at the end of Stage 3):

- **The draw.** "Capped at 250, drawn with probability proportional to weight" and then weighted
  again by the design weight counts heavy strata twice (`sample.int(prob =)` without replacement
  is successive sampling; inclusion ran from 1.00 at weight ≥ 902 to 0.01 at weight 1 in the
  reviewer's simulation). Now: **every** admitted frame with `d_c ≥ 0.5%`, design-weighted; a cap
  (400) applies only above that and is drawn **uniformly**.
- **The heights.** VRI projects every polygon to one date (2025-12-31), so `PROJ_HEIGHT_1` is
  neither epoch's height. Heights are carried back linearly in age: `h(t) = h (t − O)/(yr − O)`,
  `c_now = h(cy)`, `c_then = h(py)` for stands standing at the photo. A stand that originated
  after the photo but before the canopy epoch replaced one of unknown height: neutral,
  `c_then = c_now`. A stand that originated after the canopy epoch was seen by neither surface:
  its area is unknown and left out of both means (`unknown_share` reports it).
- **The denominator.** A frame whose VRI is all non-treed has both errors 0 and stays in; only a
  frame with no VRI, or with all its VRI area unknown, drops out, and both are counted.

The verdict threshold (weighted share under 10% per decade) is unchanged.

## Code-check round 1 (`review-round1.md`) — disposition

| finding | disposition |
|---|---|
| bug: PPS draw then weighted again | Fixed (Amendment 3) |
| bug: VRI heights at 2025, not the epoch | Fixed (Amendment 3) |
| bug, low: all-non-treed frames dropped | Fixed (Amendment 3) |
| fragile: one seed at the top | Fixed: `set.seed(80)` immediately before each of the four draws; verified that re-seeding before the stratified draw reproduces the cached 612-frame sample exactly |
| fragile: unweighted medians quoted | Census calibration and epoch medians now weighted; identity and first-order lines labelled "sample, unweighted" (instrument diagnostics, not population figures) |

## Amendment 4 — fixed 2026-09-30 from code-check round 2, before any VRI result exists

Round 2 found the round-1 epoch fix wrong in kind, not only in a line:

- **Scale.** Amendment 3 compared VRI heights (`PROJ_HEIGHT_1`, leading-species height) with each
  other and called the result the DSM's error. The DSM's canopy is its own measurement (`c30`,
  the mean of DSM − DTM under the frame), and VRI's `c_now` is not on that scale (frame 102164:
  25.5 m against 13.3 m). Now VRI supplies only the **ratio** `r = c_then / c_now` (area-weighted,
  height carried back linearly in age as in Amendment 3), applied to the DSM's canopy: DTM error
  `∝ r · c30`, DSM error `∝ |1 − r| · c30`. **The DSM is worse on a frame iff `r < 0.5`** — the
  `c_now > 2 c_then` condition of review B2, on the frame.
- **Unknowns.** A frame is *unknown* (excluded from the share, counted, its weight reported) when it
  has no VRI, when all its VRI area is unknown, or when VRI puts no canopy where the DSM does
  (`c_now = 0`, so `r` is undefined). Treed polygons with no age or height are unknown area, not
  zero canopy. Non-treed polygons are zero in both epochs and stay in both sums.
- **Small decades.** Clause 4 holds for a decade only if it has **at least 10 known frames** and the
  known frames carry **at least half** the decade's eligible weight. Otherwise the decade is
  reported as unresolved, not as holding.
- **Canopy epoch** `cy` stays 2013 on radar-majority frames and 2018 (HRDEM's median project year)
  otherwise; the per-project year is not available. The verdict is also reported at `cy` ± 3 years,
  and the rule reads the central value.
- `class_changed` was a set test (`%in%`); it is now elementwise.

Caches for Stage 4 are tagged with the algorithm (`a4`), so nothing computed under Amendment 1 or
3 can be read back (the full run was stopped at the end of Stage 3 before writing one).

## Code-check round 2 (`review-round2.md`) — disposition

| finding | inside round-1 fix? | disposition |
|---|---|---|
| bug: `vri_one()` crashes when bcdata returns all-NA age/height as character | yes | Fixed: explicit `as.numeric()`; Stage 4 now caches raw polygons |
| bug: denominator fix scores VRI-non-treed frames as "not worse"; VRI heights on a different scale from the DSM | yes | Fixed by Amendment 4 (VRI supplies only the ratio r; DSM worse iff r < 0.5; VRI-zero-under-DSM-canopy is unknown) |
| bug: stale epoch cache from the in-flight pre-fix run | — | The run is stopped by a watcher at the end of Stage 3, before Stage 4 writes; caches now tagged `a4` |
| bug, low: `class_changed` used `%in%` | no | Fixed: elementwise `mapply(identical, …)` |
| fragile: one small decade can decide | — | Amendment 4: ≥ 10 known frames and ≥ half the decade's weight |
| fragile: `cy = 2018` for lidar frames | — | Kept, stated; verdict reported at `cy` ± 3 |
| fragile, low: "lidar-majority" mislabelled | no | Relabelled "not radar-majority" |
| (found while fixing) empty `data.frame()` with a scalar beside zero-length columns | yes, inside this round's fix | Fixed: one constructor `mk()` for empty and full; smoke passes |

## Amendment 5 — fixed 2026-09-30 from code-check round 3, before any VRI result is read

A frame is **known** for clause 4 only if VRI dates at least half its inventoried area
(`unknown_share < 0.5`: treed polygons with no age or height, and stands younger than the canopy
epoch, are undated). Round 3's smoke example was 58.6% undated and still counted in full. The
per-decade line now also reports the weighted median undated share among known frames.

## Code-check round 3 (`review-round3.md`) — disposition, and how the loop ended

| finding | disposition |
|---|---|
| fragile: census `na_bin` guard unreachable (`aggregate()` errors on 0 rows) | Fixed: built only when any census frame is NA |
| fragile: a frame "known" however little of it VRI dates | Amendment 5 |
| note: test comment's 1.7e-3 is 1.7e-4 absolute, 1.3% relative | Comment corrected |

The reviewer named one mechanism behind every earlier finding — a value used as what its name
says rather than what produced it, along four axes (instrument/scale/epoch, sampling design,
runtime type/shape, RNG state) — and enumerated every line each axis reaches, with a per-line
verdict, in `review-round3.md`. Only the two fragile items failed. Rounds 1 and 2 each found a
defect inside the previous fix, so the loop was ended by that enumeration, not by a quiet round.
