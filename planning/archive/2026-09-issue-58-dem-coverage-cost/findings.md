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

## Phase 1 measured — the population, against MRDEM-30 (2026-09-20)

Against the DEM `fly_footprint()` documents as its default, **partial coverage is
essentially absent in BC**.

### Film

| stratum | n | DEM-sized | cov < 1 | cov < 0.95 | cov < 0.8 | cov < 0.5 | min |
|---|---|---|---|---|---|---|---|
| edge candidates (census) | 113 | 87 | 82 | 66 | 42 | 22 | 0.0064 |
| random draw (control) | 3000 | 2975 | **0** | **0** | 0 | 0 | 1.0000 |

So **66 of 1,437,147** DEM-eligible film frames sit under 0.95 — 0.0046%. The edge
stratum also holds 26 frames the DEM does not reach at all (`no_dem_coverage`). The
affected frames run 1982-1996 at scales 1:10000 to 1:70000.

**The random draw is the control on the candidate finder**, which reads a 1833 m overview
and so cannot see a nodata hole a few cells across. 0 of 2,975 randomly drawn frames are
short of full coverage, so the finder missed nobody at that resolution. Its residual blind
spot is a nodata patch smaller than a coarse cell.

Incidentally: 25 of 3,000 randomly drawn frames come back `height_source == "implausible"`
(0.83%), consistent with the ~1.2% fly#54 estimated.

### Digital

| stratum | n | DEM-sized | cov < 1 | routes |
|---|---|---|---|---|
| edge candidates (census) | 173 | 6 | **0** | dem_agl 6, gsd_scaled 167 |
| random control | 500 | 130 | **0** | dem_agl 130, gsd_scaled 340, NA 30 |

Every DEM-sized digital frame measured comes back at coverage **1.0000**. 167 of the 173
edge candidates never reach the DEM route at all — they are sized from their ground
sample distance.

### What this does to the issue's own figure

**The issue's "18 of 416 DEM-corrected frames fell under 95% `dem_coverage`, one as low as
47%" does not reproduce against MRDEM-30.** Nothing in the catalogue's digital population
is partially covered by it. The likely explanation is that the fly#50 run supplied a DEM
cropped to that run's area of interest, which is the failure `fly_footprint()`'s own
documentation already calls the ordinary one — but that is inference, not measurement, and
the run left no artifact to check it against.

The consequence for this issue is a reframing rather than a retraction: **the frequency of
partial coverage is not a property of the catalogue at all.** With the documented default
DEM it is a 0.005% event. With a user-supplied DEM it happens exactly as often as that
user under-buffers, which no measurement here can bound. So the decision has to rest on
what partial coverage *costs* when it happens, which is Phase 3.

### A coverage-1 failure this sweep cannot generate

MRDEM returns a near-zero surface over near-shore ocean rather than nodata (probe 4), so a
coastal frame reports `dem_coverage` ~ 1 with its mean dragged toward sea level. It is
invisible to `dem_coverage`, it is not reachable by removing cells, and it is out of scope
here — recorded as a bound on the claim rather than fixed.

## Errors Encountered

| Error | Resolution |
|-------|------------|
| `terra::crop()` then `aggregate()` over the BC bbox of MRDEM-30 did not finish in 120 s | Reads at full resolution. `sf::gdal_utils("translate", -outsize)` resolves against the COG's own overviews and returns a 1200 x 1138 grid in 5.9 s |
| `terra::distance(x, target = NA)` marked 99.999% of the catalogue as an edge candidate | It measures FROM the NA cells outward, so every data cell reads 0. Invert the mask first: `distance(ifel(is.na(r), 1, NA), target = NA)`. A result that implausible is the instrument, not the world |
| `gdal_utils("translate")` and `terra::writeRaster()` both failed with "cannot guess driver / file type from filename" | The atomic-write idiom appends `.part`, and GDAL guesses the driver from the extension. Pass `-of GTiff`, or name the temp file `.part.tif` |
| Sweep workers died with `could not find function "window_path"` | A PSOCK worker binds a deserialised function to its OWN global environment, so every helper and constant has to be installed there explicitly. Collected in one `worker_objs()` rather than listed at each of the three cluster call sites |
| The sweep was killed three times for system memory | Each worker carries a `pkgload::load_all()` at 400-600 MB RSS, and other sessions on this machine were holding ~4 GB of R. Dropped to 2 workers, made `WORKERS` an env override, and cached the sweep every 20 targets so a kill costs one batch rather than the run |

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


## Harness hazard noted, not yet fixed

`resume.sh` (scratch, not shipped) reaps orphaned PSOCK workers with
`pkill -f "parallel:::.workRSOCK"`. That pattern matches **any** session's workers, and a
PSOCK worker reports `PPID 1` whether it is live or orphaned, so parentage cannot tell
mine apart. No other session had workers running when this was noticed, but the correct
form is for the script to register its own worker PIDs (`clusterCall(cl, Sys.getpid)`) to a
file and for the reap to kill only those. To be applied at the next restart rather than by
editing a file bash is reading expression by expression.
