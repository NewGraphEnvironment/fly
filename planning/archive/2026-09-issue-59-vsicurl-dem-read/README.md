## Outcome

fly#59 reported `fly_footprint(dem = )` taking 583 s for two frames against MRDEM-30 over
`/vsicurl/`, with `Rprof` putting all of it in `terra::extract()` and almost none of it in CPU.
The issue asked for measurement before any fix and flagged its own number as an upper bound,
since that run shared bandwidth with the 0.12.0 calibration sweep reading the same S3 object
from six workers.

The cost was one call: `fly_dem_sample()` extracted the whole rectangle vector with no `fun`,
which returns every cell. The other extract in that function reads an in-memory template and
never touches the network, so `fly_footprint()` made **two** remote reads per call rather than
the `2 x n_frames + 2` the issue assumed. 0.13.0 reads the DEM through one window per frame,
cropped to that frame's own counting grid, with the elevation mean, the coverage numerator and
the coverage denominator all read off the same values.

Two plausible alternatives were rejected on evidence rather than taste. `fun = mean` times the
same (0.66 s against 0.69 s) and is still wrong, because the numerator counts non-`NA` cells and
an aggregating extract returns one number per frame. Cropping **once over the batch** is faster
again (1.00 s against 1.23 s for eight contiguous frames) and is wrong form 4 of `dem_coverage`
arriving through the read instead of the counting grid — 243,583,754 cells for the two frames
700 km apart in this suite's own fixture.

The read window is deliberately **not** the counting template, and a review round caught the
version that made it one — `fly_dem_grid()` snaps to the *nearest* cell boundary, so it can be
smaller than the footprint. See Measurement.

One self-review finding was fixed mid-flight: the guard for a frame with no DEM under it was
first written as `tryCatch(crop(...), error = NULL)`, which tests the proxy rather than the
property — a transient read failure on a remote DEM would have become a frame silently
reporting no coverage and falling back to nominal scale. It is an explicit extent-overlap test,
so genuine read errors propagate.

The durable write-up is the "read through one window per frame" section of
`inst/notes/terrain-correction.md`. The CLAUDE.md gotcha that prescribed "crop once, then
sample" was replaced rather than marked closed, because that advice is now the wrong shape.

## Measurement

All timings 2026-09-20, quiet link, **one form per fresh R process** so the GDAL block cache
could not carry between them, run serially — concurrency is the confound the issue flagged.

- **One frame, three forms:** `extract(dem, v)` 64.59 s / **158** HTTP GETs; `crop` then
  `extract` 0.69 s / **4**; `extract(fun = mean)` 0.66 s / 4. 94x the wall clock, 39x the
  requests. All three return mean 609.150; the two cell-returning forms both return **12,616
  cells** — the licence for the change.
- **End to end,** the case the issue reports: **263.4 s before, 4.3 s after**, with identical
  `dem_coverage` (1,1), `height_agl` (1984.285, 1934.798) and `footprint_terrain`. 263 s quiet
  against 583 s contended puts the issue's own caveat at about 2.2x.
- **Eight contiguous frames:** per-frame crop 1.23 s, one shared crop 1.00 s, both 100,897
  cells and the same means. 23% is the price of a bound that cannot be defeated.
- **Local DEM does not regress:** 1.260 s against 1.437 s for the 20 bundled frames, alternated
  in one process — each extract now works over a few thousand cells instead of the whole raster.
- **The remote object is a well-formed COG:** `LAYOUT=COG`, `Block=512x512`, LZW, nine overview
  levels, 185220 x 166668 at 30 m. A block is 15.4 km and a 1:15000 footprint is 3.4 km, so one
  frame is 1-4 blocks. 4 requests is right; 158 is not.
- **Parity is what licensed it.** The previous implementation was pulled from `git show HEAD:`
  rather than rewritten, and returns identical `elev` and `covered` over eleven shapes: 20 bundled
  frames, a frame 200 km off the DEM, two off and two on, straddling the DEM edge, an empty
  geometry among real ones, all-empty input, a DEM hole, a geographic-CRS DEM, anisotropic
  120 x 904 cells.
- **The overlap test was probed at the boundary**, since it introduced an abort path the old
  code did not have: a 0.1-cell sliver overlap, exact edge touching, one micron past the edge,
  a one-cell-wide frame, and a frame spanning the DEM and 50 km past it on all sides — all five
  agree with the old implementation, none aborts.
- **Both new guards were proven to fire.** Planting a union-extent crop takes `max(crops)` to
  243,583,754 and reddens **only** the new test, because the counting grid is still per-frame
  and the pre-existing grid assertion cannot see the read at all. Dropping the off-DEM guard
  **errors** five tests, three of them pre-existing — errors rather than failures, since the
  batch aborts.
- **What changed because of it:** the issue proposed cropping once to the batch, and the
  measurement moved that to per frame; it proposed `fun = mean` as an alternative, and the
  numerator's requirements ruled it out; it assumed four remote extracts per frame, and there
  were two per call.

A question the issue raised was closed as **not a defect**: `terra::extract()` emits an `NA`
placeholder row for a rectangle that misses the raster entirely, so `split()` keeps every ID and
the old code's ID alignment was sound. Nothing was filed. It mattered anyway, because
`terra::crop()` *errors* on that input and the new code had to reproduce the old behaviour.

## What review caught, and the mechanism behind it

`/code-check` ran four rounds (one was stopped after producing nothing and respawned), and they
are the reason this entry is worth reading.

**Round 1 found a real bug in the committed code.** The read window was the counting template,
and `fly_dem_grid()` align()s with `snap = "near"` — nearest boundary, which can be *inside* the
footprint. Cropping to it dropped cells the whole-DEM extract returned: 52 of 300 frames between
0.2 and 6 cells across disagreed on mean elevation, and the worst shape is silent, because
`pmin(1, got/expected)` caps `dem_coverage` back to 1 while `elev` is quietly wrong. The session's
own parity sweep had missed it entirely — every frame in it was ~66 cells across, so **the fixture
could not reach the failure mode.** Fixed by snapping the read window **out** while the template
stays on "near"; re-swept, 0 divergent in 1200 cases across five regimes.

**Round 2 found five prose defects, and they share one mechanism:** a sentence that was true of
an earlier draft of the code and was not updated when the code changed. The sharpest was the note
saying the off-DEM case "is caught" — that wording survived the very edit that replaced the
`tryCatch` with an extent test, so it pointed a future reader at the construct the code now
deliberately refuses. Also: a claim that the pre-existing mock-the-grid test bounds the read (it
does not — only the new test reddens on a faithful union-crop defect); a CLAUDE.md headline
quoting "583 s to 4.3 s", mixing a contended figure with a quiet one where like-for-like is
263.4 s; an unconditional parity claim that in fact holds only where a frame covers at least one
cell **centre**; and planning notes describing a planted defect as "drop the tryCatch" when no
tryCatch exists.

**Round 3 enumerated 63 claims and found three that were never measured at all** — and its
largest finding is a sentence that was *never* true rather than one that went stale. Round 1's
fix shipped with a reachability argument reasoned from frame **width**: "a 3.4 km frame is under
4 cells across on a 900 m DEM, so this is reachable". Measured, interior frames at that width
diverge **0 of 200** times. A near-snap only discards a column whose own centre is outside the
polygon, and `extract()` takes a cell by its centre, so discarding it changes nothing. The real
trigger is the frame's **overlap with the DEM** covering no cell centre — a frame of *any* size
at the edge of coverage, i.e. the ordinary AOI-cropped DEM: 100 of 100 overlap depths under half
a cell diverge, 0 of 100 once the overlap passes a cell. Four documents and a test had copied the
wrong proxy; the note had stated the right condition two paragraphs below it.

Round 3 also caught the regression test's premise being a proxy (it passed 34 of 40 while only 1
of 40 frames would have differed, so the guard rested on a seed), a roxygen line telling users a
pre-crop gains nothing where the repo's own figures show 19%, and a miscounted parity list.

**The mechanism, which is the durable lesson:** every sentence in this change restates a
measurement taken against a draft, and the change reversed direction twice afterwards. The class
at risk is the **justification**, not the fact — "the read costs 64.59 s" is checkable and does
not move when the code does; "so this is reachable on real data" has its truth condition in an
inference, so reading the code beside it can never contradict it. The terminating question is
therefore not *"is this still true"* but *"was it ever measured, and where is that measurement
recorded"*.

The parity claim is now stated **with its condition**, which is the durable lesson: a frame
covering no cell centre falls into `terra::extract()`'s touched-cells fallback, and that fallback
is computed over whatever raster it is handed, so a crop and the full DEM can legitimately return
different cells.

**A fourth round was launched and lost.** It was scoped to the claims written by the round-3
fix — by the mechanism above, the likeliest place for the next defect — and it died silently at
a 1.47 MB transcript, as the first round-1 agent had. It is recorded as lost rather than clean,
because an agent with nothing to say and a dead one look identical from the calling side. Its
job was done by hand instead: enumerating the new claims against their measurements found two
more instances of the same mechanism (a NEWS sentence still describing the superseded test, and
three stale claims in the PR body and this file), which are corrected here.

## Evidence

Probe scripts are session scratch and not committed; every figure above is reproducible from
`inst/testdata/dem.tif`, `inst/testdata/photo_centroids.gpkg` and the MRDEM-30 URL in the
`fly_footprint()` roxygen. The committed record is
`tests/testthat/test-fly_footprint.R` ("reads the DEM through one window per frame", "survives a
frame with no DEM beneath it at all") and the fly#59 section of
`inst/notes/terrain-correction.md`. No constant was derived, so no sweep ships — unlike #54 and
#23, this change adds no number the suite needs to re-check.

`R CMD check` reports one pre-existing WARNING for non-ASCII characters in `R/fly_mask.R`, a
file this branch does not touch; the repo runs pkgdown only, so it is not a CI gate and was left
alone rather than widening the PR.

Closed by: PR for branch `59-fly-dem-sample-over-a-vsicurl-dem-took`
