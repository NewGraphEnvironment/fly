# Code-check round 1: branch 104-readme-describe-terrain-aware-footprints (fly#104)

Reviewer: one subagent, which made no edits to the repo apart from this file. It checked every
published claim in README.md, DESCRIPTION, `_pkgdown.yml` and the figure caption against the code
path a run takes.

## Findings

- **[bug: false published claim]** README.md:16-18 (also DESCRIPTION `Description`, and
  `man/fly-package.Rd` generated from it). The README says "Given an elevation model, fly
  sizes each footprint from the aircraft's height above the ground rather than the photo's
  reported scale. It first checks the catalogue's flying height against that scale". That
  "each" is false on the code path `fly_footprint(dem =)` takes:
  - **Fallback to nominal scale.** A frame whose height fails the check (`height_source == "implausible"`),
    or whose DEM puts the terrain at or above the aircraft, or whose DEM coverage is too low,
    is sized from nominal scale. See the roxygen at R/fly_footprint.R:733-735 ("falls back to
    nominal scale with a warning") and the warnings at :1384-1400 and :1482.
  - **Digital frames sized from their GSD never take the DEM route.**
    `dem_eligible <- !by_gsd & ...` (R/fly_footprint.R:1180), and the documented
    `footprint_terrain` value is `"gsd_scaled"`, "used neither the reported scale nor a DEM"
    (:725-727).
  - **The check against scale runs on film only.**
    `comparable <- dem_eligible & film_like & ...` (R/fly_footprint.R:1232). A digital frame on
    the DEM route is never checked against its scale, because its `scale` is not an image scale.

  The DESCRIPTION's wording ("Estimate the ground each ... covers, from its catalogued centroid
  and scale or, given an elevation model, from the aircraft's height above the ground after
  checking the catalogued flying height against the scale") makes the same claim more softly.
  It is also not true of digital frames, which are sized from sensor format and GSD or focal
  length rather than from scale. The convention's remedy fits here: drop "each". For example,
  "Given an elevation model, fly sizes footprints from the aircraft's height above the ground
  where the catalogue's flying height checks out against the scale, and repairs the errors it
  can identify". Adding further qualifiers is the other option.

- **[bug: false published claim]** README.md:12, "downloads the scans and places each one on
  its estimated footprint". `_pkgdown.yml:23` ("Place each scan on its estimated footprint")
  has the same "each". `fly_georef()` skips frames with a warning in two cases:
  - **A rotated film frame on a roll with no measured rotation** (R/fly_georef.R roxygen,
    "Rotation"). Only 57 film rolls ship in `inst/extdata/film_rotations.csv`, and every other
    film roll is listed as excluded. Any contiguous run of frames from a study area gets a
    bearing, so it is rotated and refused on most rolls.
  - **A frame whose image aspect disagrees with its footprint by more than 8%.**

  The README's own figure shows the gap. Both of its rolls, `bc7326` and `bc81050`, are
  `not_sampled` in `film_rotations_excluded.csv`. Their stac-airphoto-bc items were produced
  under fly 0.19.0 with a caller-supplied `airphoto:rotation` of 90. Today's `fly_georef()`
  would skip both as rotated film frames unless the caller supplied that column.

  README.md:62 ("`fly_georef()` writes each one as a GeoTIFF on its footprint") does hold for
  the example's own `selected`. Its frames (bc5306 89, 60 and 23) are not adjacent, so they are
  unrotated and written, with the axis-aligned warning. That sentence is not a finding unless it
  is read as general.

- **[fragile: checkbox claims work not done]** planning/active/task_plan.md, Phase 3, has
  "[x] Keep DESCRIPTION `Title`/`Description`, the tagline and the GitHub About in step". The
  GitHub About is unchanged: `gh repo view --json description` returns "Airphoto Footprint
  Coverage Selection, Download and Georeference Engine". That differs from the new tagline and
  from `Title` ("Historic Airphoto Footprints, Selection and Georeferencing for British
  Columbia"). The README convention requires the three to change together, and the box records
  it as done. The fix is `gh repo edit NewGraphEnvironment/fly --description "..."` before the
  merge, or unticking the box.

## Checked and true (no finding)

- **Example output.** Re-ran the README example under `load_all()`. `fly_coverage(by = "scale")`
  and `fly_select(target_coverage = 0.8)` print exactly what the README shows: 59.5 and 100, and
  3 photos at 81.6%.
- **"Fewest".** "The fewest photos that cover 80%" holds for this example. A brute force over all
  190 pairs gives a best pair of 66.5%, so 3 is the minimum.
- **Bundled photos.** Twenty bundled photos, all `photo_year` 1968.
- **Links.** All 18 distinct URLs return 200. The CKAN titles match: "Airphoto Centroids", and
  "Medium Resolution Digital Elevation Model (MRDEM) - CanElevation Series".
- **Figure sources.** STAC items 1400364 (bc7326_30, 1971-07-17) and 790359 (bc81050_48,
  1981-07-13) carry `processing:software` fly 0.19.0. Their thumbnail hrefs match the URLs in
  `data-raw/readme_figure.R`, and the box is 2 km square.
- **Mask default.** `fly_georef(mask =)` defaults to `"border"`, so "Scans are placed with the
  black border ... masked out" holds for a default run.
- **Exports and pkgdown.** Every function the README and `_pkgdown.yml` name is exported, and
  `pkgdown::check_pkgdown()` reports no problems.
- **Learn more.** The vignette uses footprint, coverage, selection, fetch and georef functions.
  The four `inst/notes/` files match the "Method notes" description.
- **NEWS.** 37 `# fly x.y.z (date)` headings, matching the 37 `## x.y.z` on main, with no
  leftover `##` headings.
- **Citation and licence.** `inst/CITATION` and `CITATION.cff` exist, and the LICENSE holder is
  New Graph Environment Ltd.
