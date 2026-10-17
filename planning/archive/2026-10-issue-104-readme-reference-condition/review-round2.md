# Code-check round 2: branch 104-readme-describe-terrain-aware-footprints (fly#104)

Reviewer: one subagent. It made no edits to the repo apart from this file, and ran its probes
from a scratch directory under `pkgload::load_all()`. It reviewed every sentence commit 43bf3b6
rewrote, then every remaining published claim in README.md, DESCRIPTION, `_pkgdown.yml` and
the figure caption, against the code path a run takes.

## Findings

- **[bug: false published claim, the round-1 fix one axis over]** README.md:16-17, "Given an
  elevation model, fly sizes footprints from the aircraft's height above the ground rather than
  the photo's reported scale." The fix changed "each footprint" to the plural "footprints". The
  README convention counts plurals, and the round-1 finding's GSD half still applies:
  - **The DEM route excludes GSD-sized frames.** `dem_eligible <- !by_gsd & ...`
    (R/fly_footprint.R:1180). A digital frame with a resolved camera and a GSD is never sized
    from the DEM.
  - **On bundled data that is every digital frame.** `fly_footprint(photo_centroids_digital.gpkg,
    dem = dem.tif)` returns `footprint_terrain == "gsd_scaled"` on **24 of 24** frames. So the
    sentence is false for every digital frame the package ships, with the package's own DEM.
  - The film qualifier the fix added sits on the next sentence (the height check), not on this
    one.
  - **The DESCRIPTION repeats it** (and so `man/fly-package.Rd`): "or, given an elevation model,
    from the aircraft's height above the ground". Its first branch, "from their catalogued
    centroids, scale and camera format", also leaves out GSD, which is what actually sizes
    those frames (R/fly_footprint.R:1074-1087). Scale is never an input for a digital frame
    (:1044-1051).
  - **Fix.** Scope the sentence the way the next one is scoped ("For film photos, given an
    elevation model, ..."). Or, per the convention, drop the qualifier-hungry claim.

- **[bug: false published claim, missed by the round-1 fix]** `_pkgdown.yml:7`, the "Estimate
  footprints" group desc reads "The ground each photo covers, from its centroid and scale or
  from an elevation model." This is round 1's finding 1 verbatim: "each", and scale or DEM.
  43bf3b6 fixed the README and DESCRIPTION but not this line.
  - **Digital frames.** They are sized from pixel count and GSD, using "neither the reported
    scale nor a DEM" (R/fly_footprint.R:725-727). On bundled data that is all 24 digital frames.
  - **Unknown-format frames.** They get no footprint at all.

- **[bug: false published claim, the round-1 fix one axis over]** README.md:11-12,
  "...downloads the scans and places them on their estimated footprints." The fix changed
  "places each one on its" to the plural "places them on their". Both say the same thing about
  the downloaded scans, and `fly_georef()` still skips with a warning every rotated film frame
  on a roll with no measured rotation (R/fly_georef.R:369-374). Only 57 film rolls ship in
  `inst/extdata/film_rotations.csv`, against 6,659 in `_excluded.csv`.
  - **Bundled data.** `fly_footprint()` over the 20 bundled photos gives a bearing to 5 frames
    on the unshipped roll `bc5306` (23, 24, 59, 60, 61). Georeferencing all 20 scans together
    would skip those 5. "Places them" fails for a quarter of the bundled set, and it fails for
    any contiguous run of an unmeasured film roll, which is what a whole-AOI download is.
  - **The pkgdown desc** "Place scans on their estimated footprints" (`_pkgdown.yml:23`) reads
    the same way. It is a softer case, because it describes a function group.
  - **What still holds.** README.md:61-62 ("`fly_georef()` writes each one") holds for the
    example's own `selected`, as round 1 found.
  - **Fix.** Scope the sentence ("places scans on their estimated footprints where the roll's
    rotation is known"), or drop "places them on their estimated footprints" from the summary
    and leave the specific line 61-62.

- **[bug: false published claim]** README.md:12 ("picks the fewest needed"), DESCRIPTION
  ("Select the fewest photos that cover an area of interest") and `_pkgdown.yml:14` ("the
  fewest needed").
  - **The code path.** `fly_select_minimal()` is greedy set-cover (R/fly_select.R:160-205), and
    greedy does not guarantee the minimum. The old DESCRIPTION named it ("using greedy
    set-cover"); the new texts drop that qualifier and state an optimality the code does not
    compute.
  - **A counterexample through `fly_select()` itself.** The AOI is a 4 km x 2 km rectangle in
    EPSG:3005. Photos A and B are `Film - BW` at scale 1:8748.906 (2 km squares), centred on
    the rectangle's left and right halves, and together they tile it exactly. Photo C is
    1:10498.688 (a 2.4 km square), centred on the middle. `fly_select(mode = "minimal",
    target_coverage = 0.999)` picks C, A, B: 3 photos where A and B alone give 100%. C wins
    the first step, 4.8 km2 against 4.0.
  - **On bundled data it does not show.** A brute force over a 40 m grid of the bundled AOI
    found that greedy matches the minimum at every target from 0.5 to 1.0. So the README
    example's "fewest" (line 47, "the fewest photos that cover 80%") stays true, as round 1
    found. The general claim is the false one.
  - **Fix.** "a small set", "picks photos until the target is covered", or restore "greedy".

- **[bug: false published claim, low]** README.md:94-95, "with the scans, flight logbooks,
  camera calibration reports and camera files each record links to".
  - **No bundled record links to all four.** Every bundled film record has
    `camera_calibration_url` and `patb_georef_url` NA, and every bundled digital record has
    `flight_log_url` NA.
  - **The catalogue says the same.** Per CLAUDE.md, 41,249 digital frames have a PAT-B file
    and no calibration URL, and the 2003/2005 rolls have no logbook link.
  - **Fix.** "the records link to" makes it true.

## Checked and true (no finding)

- **The rewritten height-check sentence.** README.md:17-18: "For film photos it first checks
  the catalogue's flying height against that scale, repairs the errors it can identify, and
  keeps the scale where it cannot."
  - **Film only.** `comparable <- dem_eligible & film_like & ...` (:1232).
  - **Repairs.** The 10.764 slip factor and the roll table (`corrected_unit_slip`,
    `corrected_roll_table`).
  - **Fallback.** An implausible film frame falls back to nominal scale (roxygen :796-797,
    warning :1477-1482).
  - **DEM only.** The check runs only on the DEM route, which matches "Given an elevation
    model".
- **The DESCRIPTION's film clause.** "with the catalogued flying height of film photos checked
  against their scale" is correctly scoped.
- **GitHub About.** `gh repo view --json description` now returns "Historic Airphoto
  Footprints, Selection and Georeferencing for British Columbia", which matches DESCRIPTION
  `Title`. The tagline is the same wording.
- **NEWS headings.** Only heading lines changed (80 `-##`/`+# fly` lines). No release content
  sat under the dropped `# fly (development version)` heading.
- **Mask sentence.** "Scans are placed with the black border around the frame masked out"
  holds for the default `mask = "border"`, as round 1 found.
