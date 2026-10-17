# Task: README: describe terrain-aware footprints and per-roll calibration (#104)

The README is mostly current on georeferencing (v0.20.0 rotation work is described), but it never
mentions the terrain and calibration work that makes the footprints trustworthy.

Phases approved at the plan gate, then amended by the user before the baseline (2026-10-16):
*"keep it simple language professional dont get into the details too much. use actual airphotos.
dont talk about diggs. use our ecosystem table"*, plus the two McKilligan Rd airphotos (1971,
1981) to put in the README. The README also follows soul's `readme.md` convention: fixed section
order, a figure made by committed code, no function list.

## Phase 1: Verify the claims against the code
- [x] For each capability the README will name, find the version that shipped it and the
  argument or column a reader would use: `fly_footprint(dem =)` and `footprint_terrain` /
  `height_agl` / `dem_coverage`; `height_source` and the roll table; `fly_mask()`;
  `fly_camera_patb()`; the georef alpha band. Read each from the roxygen and NEWS, not CLAUDE.md
- [x] Record each claim and its source in `findings.md`

## Phase 2: README figure from real airphotos
- [x] `data-raw/readme_figure.R`: the 1971 (`bc7326_030`) and 1981 (`bc81050_048`) georeferenced
  thumbnails from stac-airphoto-bc, cropped to the same 2 km box at McKilligan Rd, upper Bulkley /
  Neexdzii Kwa (EPSG:3005 964426, 1049182, 966426, 1051182), side by side, year-labelled, opaque
  background, written to `man/figures/readme-history.png`
- [x] Check it at its published width; remove `man/figures/readme-priority.png`, which nothing
  else references and no script makes

## Phase 3: README
- [x] Section order per `readme.md`: title, sticker, badges, tagline; opening; figure and caption;
  Installation; Example; Learn more; Ecosystem; Data and methods it builds on; Citation and License
- [x] Opening: plain, professional, short. What fly does today, that footprints are sized from
  the terrain and corrected for catalogue height and scale errors, and that it gives a site's
  pre-disturbance reference condition for restoration planning and monitoring. No details
- [x] Remove the function-name bullet list, "Used by" and "Related packages"; no mention of diggs
- [x] Ecosystem: flooded's table, with fly in bold as "this package", plus stac_airphoto_bc,
  where the georeferenced photos are published
- [x] Keep DESCRIPTION `Title`/`Description`, the tagline and the GitHub About in step

## Phase 4: NEWS header
- [ ] Drop `# fly (development version)` and promote every `## x.y.z (date)` to
  `# fly x.y.z (date)`, so pkgdown shows one changelog section per release
- [ ] Verify: `tools:::.build_news_db_from_package_NEWS_md()` parses every version, and the built
  changelog has one section per release

## Phase 5: Group the reference index
- [ ] `reference:` in `_pkgdown.yml`, grouped by purpose, each with a one-line `desc`:
  Estimate footprints (`fly_footprint`, `fly_camera_patb`, `fly_summary`); Choose photos for an
  area (`fly_filter`, `fly_select`, `fly_coverage`, `fly_overlap`); Download (`fly_fetch`);
  Georeference (`fly_georef`, `fly_bearing`, `fly_mask`, `fly_rotation_calibrate`)
- [ ] `pkgdown::check_pkgdown()` passes

## Phase 6: Release
- [ ] NEWS entry under `# fly 0.24.1`; bump DESCRIPTION as the final commit

## Validation

- [ ] Tests pass
- [ ] `/code-check` clean (each commit, or once over the branch with `/code-check branch`)
- [ ] pkgdown home, changelog and reference render as intended
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
