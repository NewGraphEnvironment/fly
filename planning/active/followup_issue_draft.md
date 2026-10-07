## Problem

fly#97 found, by their logbooks, that 107 frames on five roll-heights are not over the ground the catalogue's centroids put them on. `fly_footprint()` places those footprints at the centroids anyway. When given `dem =`, it falls back to nominal scale on the frames whose MRDEM ground is at or above the catalogued aircraft height (`r <= 0`), and warns.

| roll-height | `r <= 0` frames | photo overlap | catalogue step's overlap at nominal |
|---|---|---|---|
| `bc77026` 2042 m | 11 | 0.807 | 0.419 |
| `bc77070` 1158 m | 59 | 0.622 | 0.283 |
| `bc77072` 1829 m | 1 | 0.640 | 0.226 |
| `bc77072` 1981 m | 3 | 0.615 | 0.114 |
| `bc77087` 1158 m | 38 | 0.623 | 0.209 |

Source: `inst/extdata/flying_height_image_overlap_keys.csv`, produced by `data-raw/height_measure-image_overlap.R`. The reasoning is in `inst/notes/terrain-correction.md`, "What the frames under the terrain covered".

**What establishes it.**
- **The logbook.** The page writes the catalogue's height under an M.S.L. header, yet MRDEM under the catalogue's centroids is at or above that height on 112 frames. A logbook row reaches 107 of them, so by the page those frames were photographed over lower ground.
- **The photos.** They do not test the page's datum. What they do show is that the catalogue's centroid step is longer than the air base, by at least x1.25 to x2.70 under any height the page allows. So the spacing along each line is not the photos' either. On `bc77070` that margin is at the instrument's resolution.
- **Headings.** On the pairs with a legible page heading, the page's strip heading agrees with the catalogue's line bearing on 233 of 237 (4 differ), so on those pairs the lines are not rotated or reversed. How far the frames are displaced is not measured.

**`bc77087` is contested.** Its page-1 height is 3.8 or 7.8 thousand ft, and a blind re-read could not settle which.
- At 7,800 ft its 38 frames would not be under the terrain at all.
- Its page would then put the ground under the catalogued height, which is fly#95's open question, not this one.

There are two more roll-heights that fly#97's rule left `unsettled`, because the two size readings cannot be told apart there. Their pages name places far from the catalogue's frames: `bc7718` 46-69 is "TAHSIS", 359 km away, and `bc80117` is "YALE BLUFF", 97 km away.

## What to decide

Should fly surface a known misplaced centroid to the caller? Options:
- a shipped ledger read by `fly_footprint()`'s `r <= 0` warning, so the warning names the roll's state, as `fly_georef()` already does for film rolls;
- a column on the output;
- nothing, with the note as the record.

The ledger would cover only rolls measured so far. The defect may be wider: on 1970s rolls, catalogue steps are often evenly spaced along a digitised line (fly#82's probe). Whatever ships should say so rather than read as a census.

Related: fly#97, fly#95, fly#82.
