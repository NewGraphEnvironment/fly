# Review round 1 — `fly_dem_sample()` window read (fly#59)

## Findings

- **[bug — appeared fixed in the working tree mid-review; confirming the fix is correct]**
  `R/fly_footprint.R` — the read window. When I started, the committed code
  (`f1aa087`) had `ei <- terra::ext(tmpl)`, i.e. it cropped to the **counting
  template**. `fly_dem_grid()` builds that with `terra::align()`, whose default is
  `snap = "near"`, so the template can be **smaller than the footprint** — and cropping
  to it discards cells the old whole-DEM `extract()` returned. That changes `elev`
  (hence `height_agl` / `footprint_terrain`), and sometimes `dem_coverage`.

  Measured against the old implementation, random DEMs (random origin, resolution
  0.3–97.3, 5–60 cells a side), one frame each:

  | case | mismatching frames |
  |---|---|
  | frame 0.2–6 cells across, near a DEM edge | 52 / 300 (19 with `covered` equal and `elev` different) |
  | frame 3–8 cells across, near a DEM edge | 6 / 300 |
  | frame 0.2–10 cells across, **wholly interior** | 8 / 200 |
  | frame 10–30 cells across | 0 / 300 |

  Worked instance: DEM res 55.2585, frame 41.6 units tall (0.75 cells). Template
  y-extent snapped *inside* the frame, crop kept 2 cells, whole-DEM extract returned 4;
  `elev` 0.4052 vs 0.4394, `covered` 1 in both (the cap hides it). So the failure is a
  silently wrong elevation, not an error and not a coverage warning.

  The working tree now reads
  `ei <- terra::align(terra::ext(vi), dem, snap = "out")`, with the template left on
  `snap = "near"`. **I re-ran every sweep above against that and got 0 mismatches in
  1100 cases** (0/300, 0/300, 0/300, 0/200). The fix is right: `snap = "out"` is a
  superset of both the footprint and the near-snapped template, so no cell whose centre
  is in the polygon can be cropped away, and keeping the template on `"near"` leaves
  `dem_coverage` exactly where fly#9 measured it.

- **[bug]** `inst/notes/terrain-correction.md:113` — stale, and it contradicts the code
  it documents:

  > `fly_dem_grid()` is the single definition of that window, so the crop and the
  > counting template cannot drift apart, and the existing mock-the-grid test bounds
  > both at once.

  After the `snap = "out"` change both halves are false: the read window is no longer
  `fly_dem_grid()`, the two windows now differ **by design** (the code comment says so
  explicitly — "The read window is NOT the counting template, and must not be"), and
  the `fly_dem_grid` mock no longer reaches the crop at all, so it bounds only the
  template. The crop-mock test added for #59 is what bounds the read now. This is the
  exact sentence that made the original defect look impossible, so it is worth
  rewriting rather than deleting. The parity list a few lines below (line ~125) should
  also name **a frame small relative to the DEM cell** — that axis is missing from it
  and is the one the defect lived on.

## Checked and clean (each run, not reasoned)

- **`on_dem` TRUE but `crop()` errors** — cannot construct one. 800 deliberately
  degenerate cases (frames pinned to all four corners and four edges, overlaps of
  0, 1e-12, 1e-9, 1e-6, res·1e-4, res·0.4999, res·0.5, res·0.5001) plus the 1100
  sweep cases: **0 crop errors**. `ei` is grid-aligned to the DEM, so a strict extent
  overlap is at least one whole cell.
- **`on_dem` FALSE where the old code returned cells** — yes, but the old number was
  the wrong one. A frame touching the DEM edge exactly (or overlapping by 1e-12) makes
  `terra::extract()` on the full DEM return cells whose **centres lie outside the
  footprint** (10×10 fixture, frame x∈[10,14], DEM x∈[0,10]: old gives `elev` 70,
  `covered` 0.125 from cells at x-centre 9.5; one corner-touching case gave
  `covered` 1). New returns NA / 0. Not a defect — a correction.
- **`vapply(..., numeric(3))` row-name indexing** — the names are literals in the
  returned `c(elev=, got=, expected=)`, so they are always present; verified at
  `nrow(in_dem) == 1` (a 3×1 matrix still carries rownames) and at n = 3.
- **Parity with the old implementation** (old body pulled from `origin/main` and run
  side by side): identical `elev` and `covered` for interior frames, a frame straddling
  the DEM edge, a wholly-off frame, mixed batches, an interior NA hole, a one-cell-wide
  frame, a sub-cell frame, anisotropic cells, an EPSG:4326 DEM, a multi-layer DEM, all
  20 bundled frames against `dem.tif`, and those 20 against `dem.tif` truncated to
  0.9/0.7/0.55/0.5/0.45/0.3 of its extent, and against `dem.tif` aggregated 8×/16×/32×/48×/64×.
- **Both new tests can fail.** Proved by restoring defects, not by reading:
  - read window → `terra::ext(fly_dem_grid(dem, in_dem))` (the union crop):
    "reads the DEM through one window per frame" → **2 failures**. So
    `local_mocked_bindings(crop = ..., .package = "terra")` genuinely intercepts the
    `terra::crop()` call made from inside the package.
  - `on_dem` guard neutralised (`if (FALSE)`): **both** tests error.
  - As shipped both pass (6 and 4 assertions); whole file `FAIL 0 ERR 0 SKIP 0 PASS 296`.
- **CLAUDE.md above the soul marker** — no contradiction. Its fly#59 bullet claims
  parity "over nine shapes including off-DEM, truncating, geographic-CRS and
  anisotropic", all of which reproduce.

## Note

`R/fly_footprint.R` changed under me during this review (another session landed the
`snap = "out"` fix). I twice patched and restored the file to drive the two defect
proofs above; `git diff` and a full `test-fly_footprint.R` run afterwards show the
working tree intact with that fix present and 296 passing assertions. Nothing of mine
remains in it.
