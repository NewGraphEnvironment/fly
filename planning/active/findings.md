# Findings — Measure what a partially DEM-covered footprint costs (#58)

## Measured in plan mode, 2026-09-20

Four probes, all read-only, against MRDEM-30 and the package source.

### 1. A single-point `fly_footprint()` call draws an axis-aligned square

```
single-point bearing: NA   width_source: axis_aligned_no_bearing
full-batch bearings (first 6): NA NA 230 NA NA NA
n with finite bearing in batch: 7 of 20
```

`fly_bearing()` refuses a neighbour that is not adjacent by frame number (fly#26), so one
point handed to `fly_footprint()` has no bearing and the rectangle is never rotated. A
truncation study swept over eight directions must therefore pass contiguous roll runs, or
it is studying half-plane cuts of an axis-aligned square — not of the rotated rectangle a
real frame gets.

### 2. The catalogue pull is already cached

`data-raw/.cache/centroids/` holds 127 years, 1,670,471 rows, with
`airp_id, photo_year, scale, film_roll, frame_number, media, focal_length, flying_height,
ground_sample_distance, x, y`. Frame selection needs no network.

It does **not** hold `camera_calibration_url` or `patb_georef_url`. `from_table` (and so
digital DEM eligibility, `!by_gsd & from_table` at `R/fly_footprint.R:958`) depends on the
first of those, so a digital set chosen from cached columns alone would partly never reach
the DEM route at all.

### 3. MRDEM-30's NA region, relative to BC

| point | lon, lat | MRDEM |
|---|---|---|
| Hecate Strait | -130.8, 53.2 | 0.094 |
| interior, Houston | -126.7, 54.4 | 649.79 |
| just north of 49 | -119.5, 49.01 | 646.95 |
| Washington | -120.5, 48.0 | **NA** |
| Washington | -120.5, 47.0 | **NA** |
| far Pacific | -138.0, 50.0 | **NA** |

So against the package's own default DEM, partial coverage in BC is a **border**
phenomenon — a frame straddling 49 N loses its southern part, one systematic direction,
not eight equally.

### 4. Near-shore ocean is a near-zero surface, not NA and not exact zero

A 3 km window in Hecate Strait: `n = 40000`, **exact zeros = 0**, `|v| < 0.5` = 40000,
range 0.098 to 0.189 m.

Two consequences. A coastal frame half over water reports `dem_coverage` ~ 1 while its
mean elevation is dragged toward sea level — a coverage-1 failure this sweep cannot
generate and `dem_coverage` cannot see. And the obvious guard for it, a count of exact-zero
cells, **can never fire**: the test has to be a low-variance near-zero band, or a coastline
intersect.

### 5. Feasibility probe — an anecdote, not a measurement

Two frames, extent truncated from the south, error in footprint width against the same
frame's full-coverage answer:

| frame | relief | cov 0.98 | cov 0.80 | cov 0.50 | cov 0.21 | nominal |
|---|---|---|---|---|---|---|
| 1:24000, coast mountains | 2570 m | -0.15% | +0.16% | +3.31% | +6.59% | +8.5% |
| 1:16000, Nechako plateau | 112 m | +0.01% | +0.14% | +0.44% | +0.78% | +0.3% |

`n = 2` cannot separate relief from gradient — they are collinear in a sample of two — and
both frames were axis-aligned squares per probe 1. **These numbers must not reach the note
or NEWS as measured figures.** They establish that the harness runs in seconds per frame
and nothing else.

Note also that the achieved coverage is not the target: a 0.30 target came back 0.215 on
the mountain frame and 0.204 on the plateau, because the second pass resizes the rectangle.

## Design review (Plan agent, 2026-09-20)

16 findings. The load-bearing ones, with what verification showed:

- **The x-axis is an output of the y-axis.** Truncation biases the first-pass mean, which
  changes `agl`, which resizes the rectangle, which moves the coverage. Confirmed by probe
  5 above. The treatment variable must be exogenous and geometric; achieved coverage is an
  outcome.
- **Extent cropping cannot express a corner bite** — a crop keeps a rectangle. The
  8-direction design is not implementable by cropping. `NA` masking is the primary
  mechanism.
- **The truncation treatment collides with the fly#54 height checks.** `r_reported` is
  computed from the truncated first pass, so truncation can push a frame across
  `fly_height_ratio_band()` and flip it to `"implausible"` — a ~14% area jump, not a 3%
  one.
- **The quality-column predictor must be computable from the covered cells alone**, and the
  physics points at gradient x lost-centroid offset, not at relief.
- **The "worse than nominal" arm judges the DEM route against its own limit.** Legitimate as
  a sensitivity measure (the reference is what buffering the DEM would give you, which is
  the existing warning's own advice); not a ground-truth accuracy claim. Anchored on a
  subset by `patb_georef_url` exterior orientation and by `r`.
- One of the review's own remedies was wrong: it proposed excluding ocean-contaminated
  frames by a count of exact-zero cells. Probe 4 shows there are none.

## Errors Encountered

| Error | Resolution |
|-------|------------|
| `terra::crop()` then `aggregate()` over the BC bbox of MRDEM-30 did not finish in 120 s | Reads at full resolution; a province-wide coarse mask is the wrong instrument. Use a random draw plus a coordinate-only border census instead |

## Issue context

## Problem

A footprint that hangs off the edge of the DEM is sized from the **mean elevation of the
part that is covered**. That is documented behaviour and it is reported — `dem_coverage`
gives the fraction per frame, and `fly_footprint()` warns once it falls below
`fly_dem_coverage_min()` (0.95) — but nothing has ever measured what it costs.

During the fly#50 run over the province-wide digital population, **18 of 416
DEM-corrected frames fell under 95% `dem_coverage`, one as low as 47%**. A frame half off
the DEM is sized from the half that happens to be on it, and its `height_agl` sits in the
same column, with the same `footprint_terrain = "dem_agl"`, as a fully sampled
neighbour's.

Split out of fly#54, which turned out to be a catalogue defect in `FLYING_HEIGHT` and has
nothing to do with coverage.

## What is not known

- How wrong a partially covered frame actually is. The error is the difference between the
  mean over the covered part and the mean over the whole footprint, which depends on the
  terrain, not on the coverage fraction alone — 47% covered over a plateau costs nothing,
  80% covered across a valley wall may cost a lot.
- Whether there is a coverage fraction below which the DEM route is worse than the
  nominal-scale fallback it replaced. `no_dem_coverage` falls back at zero; nothing falls
  back at 5%.
- Whether 0.95 is the right place to warn. It was set to stay quiet on reprojection
  slivers (a bundled frame is 99.96% covered), not from a measured error.

## Approach

Work it from real examples rather than reasoning. Take frames that are **fully** covered
by MRDEM, truncate the DEM under them to known fractions (from several directions, since
the answer depends on which part is lost), and compare `height_agl` and footprint area
against the full-coverage answer. That gives error as a function of coverage on real
terrain, and the 18 frames from the fly#50 run are the natural first set.

Only then decide between: leave it as is, move the warning threshold, add a floor below
which the route falls back to nominal scale, or report a per-frame quality column.

## Notes

`inst/notes/terrain-correction.md` is required reading — four `dem_coverage`
implementations passed 200+ tests while wrong, because the bundled DEM cannot reach the
failure mode. A truncating extent is one of the axes it names.

