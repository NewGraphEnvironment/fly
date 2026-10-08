# Task: Surface frames whose catalogue centroids are known to be misplaced (#99)

fly#97's rule marks five roll-heights `misplaced`. On four of them, by their logbooks, the frames under the terrain that a logbook row reaches are not over the ground the catalogue's centroids put them on; the fifth, `bc77072` 1829, has its one such frame on no page. `fly_footprint()` places those footprints at the centroids anyway. When given `dem =`, it falls back to nominal scale on the frames whose DEM ground is at or above the catalogued aircraft height (`r <= 0`), and warns.

The five are `bc77026` 2042 m, `bc77070` 1158 m, `bc77072` 1829 m and 1981 m, and `bc77087` 1158 m, from `inst/extdata/flying_height_image_overlap_keys.csv` (`location == "misplaced"`). The evidence, its counts and its limits are in `inst/notes/terrain-correction.md`, "What the frames under the terrain covered". In short:
- **The logbook.** The page writes the catalogue's height under an M.S.L. header, yet MRDEM under the catalogue's centroids is at or above it.
- **The photos.** They show the catalogue's centroid step is longer than the air base. So the spacing along each line is not the photos' either. They do not test the page's datum.
- **The caveats.**
  - `bc77070`'s step margin is at the instrument's resolution.
  - `bc77087` rests on its page's 3,800 ft. Three blind reads of that digit disagreed (3; 3 or 7; 3 or 5), and a human read settled it as 3 (fly#101). The read was not blind.
  - Four of `bc77026`'s frames under the terrain, and `bc77072` 1829's one, have no shipped logbook row.

Two more roll-heights, `bc7718` and `bc80117`, were left `unsettled` by fly#97's rule. Their pages name places far from the catalogue's frames, "TAHSIS" and "YALE BLUFF" (see the note).

## Decision (plan gate, 2026-10-07)

- Ship a warning read from a ledger (option 1), not a column, not nothing.
- Name only the five `misplaced` roll-heights; `bc7718` and `bc80117` are not named.

## Design decisions (mine; mechanism)

- **No new CSV.** Read `flying_height_image_overlap_keys.csv` directly and filter
  `location == "misplaced"`, through a reader beside `fly_height_roll_table()`
  (`R/fly_footprint.R` ~291). A copied ledger would be one fact derived twice; the keys file
  is already installed and `test-fly_footprint_image_overlap.R` recomputes `location`.
- **Key** is roll, height, lens, scale, formatted with the same `num()` used for the roll table
  (`R/fly_footprint.R` ~1220), so integer/double spelling cannot miss.
- **Reach**: only frames in `unusable & fh <= elev` (the `r <= 0` set the caller's own DEM
  produces). Frames on those roll-heights with `r > 0` get nothing: fly#97's logbook evidence is
  about frames under the terrain. Without `dem` nothing fires. Both limits go in roxygen.
- **Wording** claims what holds at the roll-height level for all five (page writes the
  catalogued height above sea level; photos show the step longer than the air base), so
  `bc77072` 1829's frame with no page is not over-claimed. It names the roll-heights and points
  at `inst/notes/terrain-correction.md`, "What the frames under the terrain covered".
- `bc7718` and `bc80117` (`not_tested`) are not named.

## Phase 1: Tests first
- [ ] `tests/testthat/test-fly_footprint_misplaced.R`: a fixture built like `height_fixture()` /
      `flat_dem()` (`tests/testthat/setup.R` ~131-163): a `bc77070` 1158/153/5000 frame over a
      flat DEM above 1158 m warns naming `bc77070 1158`; the same frame under another roll name
      warns only the generic text; a misplaced-key frame with `r > 0` does not warn; a mix
      counts only the misplaced frames
- [ ] The reader returns exactly the five keys and is the keys file's `misplaced` rows; a key
      written as integer and as double both match
- [ ] Shape sweep through `centroid_shapes()` (plain / tibble / grouped / `bcdc_sf`)
- [ ] Mutation check: drop the filter / break the key and confirm the tests go red

## Phase 2: Implement
- [ ] Reader `fly_height_misplaced_table()` beside `fly_height_roll_table()`
- [ ] Warning after the `unusable` one in `fly_footprint()`; generic warning unchanged
- [ ] Roxygen: one paragraph in the Terrain section; `devtools::document()`

## Phase 3: Record
- [ ] `inst/notes/terrain-correction.md` "What it leaves": replace "Whether to tell the caller
      is fly#99" with what shipped and its limits
- [ ] NEWS.md entry (version bump left to `/gh-pr-merge`)
- [ ] CLAUDE.md Key Decisions: one entry for fly#99
- [ ] Edit issue #99's body to record the decision

## Validation
- [ ] `devtools::test()` passes; lintr clean; `pkgdown::check_pkgdown()` (no new export)
- [ ] `/code-check` on each commit
- [ ] Plan agent review spawned concurrently after the baseline
- [ ] `/planning-archive`, `/gh-pr-push`

