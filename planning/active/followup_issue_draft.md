## Problem

fly#97 found that, on five roll-heights, the catalogue's centroids are not over the ground the photos cover. `fly_footprint()` places those footprints there anyway. When given `dem =`, it falls back to nominal scale on the frames whose MRDEM ground is at or above the catalogued aircraft height (`r <= 0`), and warns.

| roll-height | `r <= 0` frames | photo overlap | catalogue step's overlap at nominal |
|---|---|---|---|
| `bc77026` 2042 m | 11 | 0.807 | 0.419 |
| `bc77070` 1158 m | 59 | 0.622 | 0.283 |
| `bc77072` 1829 m | 1 | 0.640 | 0.226 |
| `bc77072` 1981 m | 3 | 0.615 | 0.114 |
| `bc77087` 1158 m | 38 | 0.623 | 0.209 |

Source: `inst/extdata/flying_height_image_overlap_keys.csv`, produced by `data-raw/height_measure-image_overlap.R`.

On these keys:
- the logbook writes the catalogue's height under an M.S.L. header;
- MRDEM under the catalogue's centroids is at or above that height on 112 frames, 107 of which a logbook row reaches, so by the page those frames are not over the ground photographed;
- the photos overlap like an ordinary flight, and even at the largest side the M.S.L. height allows, the catalogue's centroid step is 1.25 to 2.7 times the air base the images imply. So the catalogue's positions along each line are not the photos' either. On `bc77070` that margin is at the instrument's resolution, and on `bc77087` it holds only on the contested read below.

So, by the page, the frames were photographed somewhere else, over lower ground; the photos do not test the page's datum themselves (fly#97's note says why). On the five, strip headings agree with the catalogue's lines on 233 of the 237 matched pairs a transcribed strip reaches, so the lines are not rotated or reversed; how far off they are is not measured. `bc77087`'s page-1 height is contested by a blind re-read (3.8 or 7.8 thousand ft); at 7,800 ft its 38 frames would not sit under the terrain at all.

There are two more roll-heights that fly#97's rule left `unsettled`, because the two size readings coincide on them. Their pages name places far from the catalogue's frames: `bc7718` 46-69 is "TAHSIS", 359 km away, and `bc80117` is "YALE BLUFF", 97 km away.

## What to decide

Should fly surface a known misplaced centroid to the caller? Options:
- a shipped ledger read by `fly_footprint()`'s `r <= 0` warning, so the warning names the roll's state, as `fly_georef()` already does for film rolls;
- a column on the output;
- nothing, with the note as the record.

The ledger would cover only rolls measured so far. The defect is probably wider: on 1970s rolls the centroids are interpolated along digitised lines. Whatever ships should say so rather than read as a census.

Related: fly#97, fly#95, fly#82.
