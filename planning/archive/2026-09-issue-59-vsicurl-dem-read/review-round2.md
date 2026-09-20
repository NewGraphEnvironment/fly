# Review round 2 — fly#59 (`fly_dem_sample()` reads the DEM through one window per frame)

Reviewed `origin/main...HEAD` on `59-fly-dem-sample-over-a-vsicurl-dem-took`.
Everything below was **run**, not reasoned. Probe scripts in `/tmp/` (`parity.R`,
`final.R`, `agree.R`, `defect1.R`, `defect2b.R`, `defect3.R`, `mock.R`).

## What I verified as sound

These were the named risk areas, and each one holds:

- **`vapply(..., numeric(3))` row indexing is safe.** vapply takes the matrix's row
  names from the **first** result, not from `FUN.VALUE`, so an unnamed `numeric(3)`
  template still yields `dimnames[[1]] == c("elev","got","expected")`. It returns a
  3x1 **matrix** for `nrow(in_dem) == 1`, so `per["elev", ]` is fine at n=1. The
  `USE.NAMES = FALSE` dimnames trap does not apply — the call does not pass it.
- **`ei[1]` on a `SpatExtent`** returns a length-1 *named* numeric (`xmin`), and `&&`
  on named length-1 logicals behaves normally. No length>1 `&&` error is reachable.
- **`vals` shapes.** `NA_real_` in the no-overlap branch and a numeric vector
  otherwise; `mean(NA_real_, na.rm=TRUE)` is `NaN`, caught by the existing
  `elev[is.nan(elev)] <- NA_real_`; `sum(!is.na(...))` is integer and `c()` promotes,
  so the `numeric(3)` template always matches. A zero-length `vals` also survives
  (`NaN`/`0`).
- **The guard agrees with `terra::crop()`'s own snapping.** Swept 400 randomized
  DEM/frame geometries (random origins, anisotropic resolutions 5–400 m, frames
  inside/straddling/outside): **0 cases** where `on_dem` was TRUE and `crop()` then
  errored. So the guard cannot let a batch abort. Strict inequality is correct —
  both extents are on the same grid, so a strictly-positive overlap is >= 1 cell.
- **Counting parity holds on every realistic shape.** Old implementation pulled from
  `origin/main` (not rewritten) and run against the new one in one process:
  17 hand-built shapes (interior, straddling each edge, corner, fully off, abutting
  exactly, mixed on/off/on, interior NA hole, all-NA DEM, anisotropic 120x904,
  geographic CRS, multi-layer, empty-among-real, single frame, 900 m coarse) —
  **all MATCH**; plus 60 randomized configurations — **58/60 MATCH**.
- **The mock in the new test genuinely intercepts.** `local_mocked_bindings(crop =,
  .package = "terra")` was confirmed to fire on the `terra::crop()` call made from
  inside the fly namespace (1 hit, measured). Not a false pass.
- **Both new tests were proven to fire.** Planting a "crop once to the batch" defect
  that does *not* route through `fly_dem_grid()` reddens exactly one test —
  `"reads the DEM through one window per frame"`. Removing the `on_dem` guard errors
  5 tests including `"survives a frame with no DEM beneath it at all"`. (Note: to
  reproduce the second you must patch **both** the namespace and the attached
  `package:fly` binding — patching `asNamespace()` alone leaves the direct-call test
  running the original, which is the recorded `load_all()` two-bindings trap.)
- Full `test-fly_footprint.R`: FAIL 0, ERROR 0, SKIP 0, PASS 255. DESCRIPTION is at
  0.13.0 and NEWS.md carries the entry.

## Findings

### 1. [fragile] The "identical elev and covered" parity claim is false in one regime

`inst/notes/terrain-correction.md` (fly#59 section, "The check that licensed the
change"), CLAUDE.md ("The old and new functions return identical `elev` and
`covered` over nine shapes") and NEWS.md ("Nothing about the answer changes") all
assert exact parity. Measured, with the HEAD implementation from git and the new one
in a single process:

```
DEM: 10x10, 100 m cells, xmin/ymin 0, values 1:100
frame: x 200..800, y -500..top  (pokes `top` metres into the DEM from below)

top=  0.5 .. 49.9   OLD elev=96    cov=0.06667  |  NEW elev=95.5  cov=0.06667   DIFF
top= 50   .. 150    OLD elev=95.5  cov=0.1667   |  NEW elev=95.5  cov=0.1667    match
```

11 of 20 sweep points disagree on `elev`, and 2 of 60 randomized configurations hit
it too. `covered` is unaffected — only the sampled **values** move.

The regime is a frame that covers **no DEM cell centre** but still touches the
raster. `terra::extract()` falls back to returning the cells the polygon touches;
the full-raster call returns cells 93 and 99 (mean 96) and the cropped call returns a
different pair (mean 95.5), because `terra::align(snap = "near")` snaps the window's
edge away from the row the frame actually touches. That is the crop changing **what
is read**, which the note explicitly says cannot happen: *"the window alters what is
read and never what is counted"* — true of the count, not of the values.

Bounded honestly: I could **not** reach this through `fly_footprint()`. Tried both
the bundled `dem.tif` (its NA edge collar makes both paths agree at
`no_dem_coverage`) and a variant with the NA collar filled so the edge cells carry
data — old and new agreed on `dem_coverage` and `height_agl` at every poke depth
from 3 m to 40 m. So this is a documented-claim defect plus a narrow behavioural
change in a degenerate regime, not a live data-loss bug. Fix is to the wording:
say parity was checked over the nine shapes listed and holds wherever the frame
covers at least one cell centre, rather than asserting it unconditionally.

### 2. [fragile] The note says the failure is "caught". There is no `tryCatch`, deliberately

`inst/notes/terrain-correction.md`, fly#59 section, last bullet of "Two things the
window must not quietly change":

> `terra::crop()` **errors**. Unguarded that would abort a batch over one
> unlocatable frame. **It is caught**, and the frame comes back with no elevation…

It is not caught. `R/fly_footprint.R:280-289` tests the extents and the code comment
right there argues *against* catching:

> Tested on the extents rather than by catching the error, because "crop() failed" is
> a proxy for "no DEM here" and the two come apart: a tryCatch here would turn a
> transient read failure on a remote DEM into a frame that silently reports no
> coverage and falls back to nominal scale.

`grep -n tryCatch R/fly_footprint.R` finds only line 119 (unrelated) and line 285
(that comment). So the note tells a future reader to look for — and, if it went
missing, to restore — precisely the construct the implementation refuses. This is the
shape CLAUDE.md elsewhere guards with "Do not 'finish' this by picking one". Reword
to "it is guarded on the extents, and deliberately not caught — see the comment".

### 3. [fragile] The note and NEWS contradict each other on what the old test covers; the note is the wrong one

Note, fly#59 section:

> `fly_dem_grid()` is the single definition of that window … and **the existing
> mock-the-grid test bounds both at once**.

NEWS.md for 0.13.0 says the opposite:

> … reddens that test alone, **because the counting *grid* is still per-frame and the
> existing grid assertion cannot see the read at all**.

Measured. Planting a faithful "crop once to what we are about to sample" defect —
union window built with `terra::align(ext(vect(in_dem)), dem)`, i.e. **not** through
`fly_dem_grid()`, counting template left per-frame — gives:

```
FAIL 2  ERR 0  PASS 253
[1] "fly_footprint reads the DEM through one window per frame"     <- only this one
```

`"does not size its coverage grid to the span of the photo set"` stays green. NEWS is
right; the note is wrong. It matters because the note is the document CLAUDE.md sends
people to before touching anything under `dem`: anyone who believed it could delete
the new test as redundant and ship the union-sized read silently. (My first planted
variant *did* redden both — but only because it routed the union through
`fly_dem_grid()`, which the old test mocks. That is not the defect being guarded
against.)

### 4. [fragile] CLAUDE.md publishes the confounded speed-up; NEWS and the note publish the measured one

CLAUDE.md, new decision block:

> The reported case — two frames — went 583 s to **4.3 s**.

The note, three paragraphs earlier in the same PR, disowns that number:

> That 583 s was never a clean comparison. The run shared bandwidth with the fly#54
> calibration sweep … a contended link against a quiet one.

and `findings.md` records the like-for-like figure: **263.4 s before, 4.3 s after**,
61x. NEWS.md gets it right ("goes from 263 s to 4.3 s"). CLAUDE.md is the document
every future session reads first and it is the one carrying the 135x headline built
from a before-number measured under contention and an after-number measured quiet.
Use 263 s -> 4.3 s, and keep 583 s only as the originally-reported upper bound.

### 5. [fragile] The PWF evidence record names a mechanism that does not exist

`planning/active/findings.md` ("Both new guards were proven to fire") and
`planning/active/progress.md` both describe the planted defect as:

> drop the `tryCatch` around `terra::crop()` — **5 tests error**, three of them
> pre-existing

There is no `tryCatch` around `terra::crop()` (finding 2). I reproduced the
experiment by removing the **extent guard** and got exactly 5 errors, three
pre-existing — so the measurement is real and the number is right; only its
description is wrong. Worth correcting since these files are the archived evidence
record for the change.

## Not findings, but worth knowing

- Peak memory per frame is now roughly 2x what it was: the counting template and the
  cropped window are both resident inside the loop. Cell counts are unchanged and
  fly#54 already withholds the 110 km case, so this is not a regression I can
  demonstrate — noting it because the note's allocation argument only discusses cell
  counts, not simultaneous residency.
- One early probe (`/tmp/min.R`) had `fly_dem_sample()` throw
  `[crop] extents do not overlap` three runs in a row on the top=20 frame above, and
  I could not reproduce it afterwards in any of ~10 later runs, nor in the 400-case
  guard/crop sweep, nor through `fly_footprint()`. Recording it because the failure
  mode is the exact one the guard exists to prevent, but I have no reproduction and
  would not act on it. Treating it as probe error per "the probe is broken before the
  world is".

## Verdict

No bug that loses or corrupts data, and no security issue. The code change is sound:
counting parity holds everywhere a frame covers a cell centre, the guard is airtight
against `crop()`'s own snapping across 400 randomized geometries, both new tests
provably fire, and the mock is real. The five findings are documentation-accuracy
defects in files this repo treats as load-bearing (the note, CLAUDE.md, the evidence
record), of which **2 and 3 are the ones that would cost somebody real work**.
