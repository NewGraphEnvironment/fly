# Findings — Surface frames whose catalogue centroids are known to be misplaced (#99)

## Issue context

## Problem

fly#97's rule marks five roll-heights `misplaced`. On four of them, by their logbooks, the frames under the terrain that a logbook row reaches are not over the ground the catalogue's centroids put them on; the fifth, `bc77072` 1829, has its one such frame on no page. `fly_footprint()` places those footprints at the centroids anyway. When given `dem =`, it falls back to nominal scale on the frames whose DEM ground is at or above the catalogued aircraft height (`r <= 0`), and warns.

The five are `bc77026` 2042 m, `bc77070` 1158 m, `bc77072` 1829 m and 1981 m, and `bc77087` 1158 m, from `inst/extdata/flying_height_image_overlap_keys.csv` (`location == "misplaced"`). The evidence, its counts and its limits are in `inst/notes/terrain-correction.md`, "What the frames under the terrain covered". In short:
- **The logbook.** The page writes the catalogue's height under an M.S.L. header, yet MRDEM under the catalogue's centroids is at or above it.
- **The photos.** They show the catalogue's centroid step is longer than the air base. So the spacing along each line is not the photos' either. They do not test the page's datum.
- **The caveats.**
  - `bc77070`'s step margin is at the instrument's resolution.
  - `bc77087` rests on its page's 3,800 ft. Three blind reads of that digit disagreed (3; 3 or 7; 3 or 5), and a human read settled it as 3 (fly#101). The read was not blind.
  - Four of `bc77026`'s frames under the terrain, and `bc77072` 1829's one, have no shipped logbook row.

Two more roll-heights, `bc7718` and `bc80117`, were left `unsettled` by fly#97's rule. Their pages name places far from the catalogue's frames, "TAHSIS" and "YALE BLUFF" (see the note).

## What to decide

Should fly surface a known misplaced centroid to the caller? Options:
- a shipped ledger read by `fly_footprint()`'s `r <= 0` warning, so the warning names the roll's state, as `fly_georef()` already does for film rolls;
- a column on the output;
- nothing, with the note as the record.

The ledger would cover only rolls measured so far. The defect may be wider: consecutive catalogue steps on older rolls are often equal to within 0.5% (fly#82's probe). Whatever ships should say so rather than read as a census.

Related: fly#97, fly#95, fly#82.



