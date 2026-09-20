# Progress — fly_dem_sample() over a /vsicurl/ DEM (#59)

## Session 2026-09-20

- Plan-mode exploration: mapped the whole DEM code path, read
  `inst/notes/terrain-correction.md` (required reading before touching anything under `dem`)
- Measured the three extract forms on a quiet link, fresh process each — the cause is isolated
  to `terra::extract()` with no `fun`, 64.59 s against 0.69 s for the same frame through a crop,
  with identical cell count and mean
- Measured per-frame crop against one shared crop over 8 contiguous frames — 1.23 s vs 1.00 s,
  identical results, so per-frame is affordable and bounded by construction. Design decided
- Phases approved by user
- Created branch `59-fly-dem-sample-over-a-vsicurl-dem-took` off main
- Phase 1 closed. Request counts: **158 GETs for the current path against 4 for a windowed
  read**, one frame. `terra::align()` returns the identical extent whether handed the DEM or a
  crop of it, and `terra::crop()` to an overhanging extent **clips rather than pads**, so
  beyond-extent ground still yields no row. The zero-cell frame turned out **not** to be a
  defect: `terra::extract()` emits an NA placeholder row for a polygon that misses the raster
  entirely, so `split()` keeps every ID and the old code was correct. Nothing to file — but the
  new code has to reproduce it, because `terra::crop()` *errors* on that input
- Phase 2: `fly_dem_sample()` now reads one window per frame, numerator and denominator off the
  same values. Parity against the HEAD implementation pulled from git (never rewritten by hand):
  **identical `elev` and `covered` over 9 shapes** (and, after review, over a multi-layer DEM
  and frames swept 0.05-60 cells across at three resolutions — parity holds wherever a frame
  covers at least one cell centre, which is the condition the note now states) — 20 bundled frames, a frame 200 km off the
  DEM, two off and two on, straddling the DEM edge, an empty geometry among real ones, all
  empty, a DEM hole, a geographic-CRS DEM, anisotropic 120x904 cells
- End to end, the case the issue reports: **263.4 s before, 4.3 s after**, identical coverage
  (1,1), `height_agl` (1984.285, 1934.798) and `footprint_terrain`. 263 s quiet against the
  issue's 583 s contended confirms its own upper-bound caveat
- Phase 3: two tests added, and **both proven to fire**. Planting a union-extent crop takes
  `max(crops)` to **243,583,754 cells** — the exact figure the note records. The
  **pre-existing** grid assertion stays green through that plant, because it watches
  `fly_dem_grid()` and cannot see the read, so the new test is not redundant with it. Dropping the off-DEM guard errors **5** tests, three of them pre-existing
- Suite green: FAIL 0, ERROR 0, SKIP 0, **PASS 1852** — 1829 on `main`, 1880 after the first
  pair of new tests, 1852 once review round 3 replaced the 40-frame small-frame test with a
  12-frame one targeting the right regime (1880 - 41 + 13). Lint unchanged against HEAD (4 and 4, all
  `object_usage_linter`, the known installed-vs-source artifact)
- Issue body reconciled; CLAUDE.md gotcha replaced with a decision; note and roxygen updated
- Next: /code-check rounds, then NEWS and the version bump as the final commit
