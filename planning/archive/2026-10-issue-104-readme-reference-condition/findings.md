# Findings — README: describe terrain-aware footprints and per-roll calibration (#104)

## Issue context

## Problem

The README is mostly current on georeferencing (v0.20.0 rotation work is described), but it never mentions the terrain and calibration work that makes the footprints trustworthy.

## Findings

**Shipped but not in the README (underselling)**
- Terrain-aware footprints, `fly_footprint(dem =)` (v0.5.0, v0.12.0, v0.14.0)
- Flying-height and scale corrections from a measured per-roll table (v0.15.0 to v0.24.0)
- The collar mask, `fly_mask()` (v0.11.0)
- Camera calibration, `fly_camera_patb()`
- The two-band alpha output (v0.19.0, breaking)

**Stale**
- NEWS.md opens with a "development version" header while DESCRIPTION is 0.24.0
- The README does not mention diggs (interactive selection) or stac_airphoto_bc (where georeferenced photos are catalogued). See also #7.

## Tasks

- [ ] Add the shipped capabilities above, framed as: the pre-disturbance reference condition for a site
- [ ] Add the relationship to diggs and stac_airphoto_bc
- [ ] Fix the NEWS header
- [ ] Group the `_pkgdown.yml` reference index by purpose. It has no `reference:` sections today, so the docs site shows a flat alphabetical list.

## Context

Audited 2026-10-14 against `origin/main` @ `0acccf6`, from README, DESCRIPTION, NEWS, NAMESPACE and vignettes. Verify each item against the code before acting. Versions cited are where a capability landed.

The New Graph website will describe this package from its README (NewGraphEnvironment/newgraphenvironment.github.io#53), so the README is the source of truth for the public one-liner. Plain language in the opening paragraph: what it does today, and what restoration planning, implementation or monitoring decision it informs.


## Plan-mode exploration (2026-10-16)

- **NEWS:** the published changelog (gh-pages `news/index.html`) has a single section,
  "fly (development version)", with all 37 `## x.y.z (date)` releases nested under it; its table
  of contents lists only "development version". `/gh-pr-merge` handles `# pkg x.y.z (date)`
  headings (`DATED_HEADINGS`).
- **pkgdown reference:** no `reference:` block; the site lists "All functions" alphabetically.
  12 exported topics, plus `fly-package` (internal).
- **README:** hand-written `README.md`, no `README.Rmd`. `man/figures/readme-priority.png` has no
  generating script and nothing but the README references it.
- **Ecosystem table:** flooded's (flooded#81) is the most recent and complete; fly's row there is
  "Estimate airphoto footprints and select optimal coverage for a study area".
- **Figure source:** both thumbnails are BC Albers (EPSG:3005) GeoTIFFs, 1258 px at 3.26 m and
  1272 px at 3.97 m, and both contain the 2 km box.
- **GitHub About** reads "Airphoto Footprint Coverage Selection, Download and Georeference Engine";
  DESCRIPTION `Title` reads "Historic Airphoto Footprints, Selection and Georeferencing for
  British Columbia".

## User amendment (2026-10-16, before baseline)

"keep it simple language professional dont get into the details too much. use actual airphotos.
dont talk about diggs. use our ecosystem table." Airphotos for the figure, with the STAC items
`1400364` (1971-07-17) and `790359` (1981-07-13) at McKilligan Rd, centred -126.5345, 54.45192.

## Phase 1: claims checked against the code (2026-10-16)

| README claim | Where it is true | Shipped |
|---|---|---|
| Footprints sized from height above ground when given an elevation model | `fly_footprint(dem =)`, `R/fly_footprint.R:931`; `height_agl`, `dem_coverage` in `@return` | v0.5.0 (#9) |
| The catalogue's flying height is checked against scale, and known errors corrected | inside `if (!is.null(dem))` at `R/fly_footprint.R:1141-1547`; `height_source`, `corrected_roll_table` at :1542; `inst/extdata/flying_height_rolls.csv` | v0.12.0 (#54), v0.15.0 (#60) to v0.24.0 |
| **Only with a DEM.** Without `dem` no height check runs, so the README ties the correction to the elevation model | same block | |
| Digital frames sized from the camera named in PAT-B files | `fly_camera_patb()`, exported | v0.10.0 (#50) |
| Black scan border masked | `fly_georef(mask = "border")` is the default, via `fly_mask()` | v0.11.0 (#23) |
| Every georeferenced output carries an alpha band | `fly_georef()` `@param mask`: "Output carries an alpha band either way" | v0.19.0 (#56, breaking) |
| Film photos rotated from a measured per-roll table | `inst/extdata/film_rotations.csv`, read at `R/fly_georef.R:675` | v0.20.0 (#53) |

Per the user's "dont get into the details too much", the README states these in one or two
plain sentences. The roll counts, versions and notes stay in NEWS and `inst/notes/`.

## Errors Encountered

| Error | Resolution |
|-------|------------|
