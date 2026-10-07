# Findings — BW/colour frames whose catalogued height may be above ground (#95)

## Issue context

## Problem

The fly#93 census (`data-raw/height_measure-terrain_tail.R`) found two groups of BW/colour film frames. In both, the catalogued `flying_height` looks like a height **above ground** that was recorded as a height above sea level. No roll-table rule reads either group.

1. **374 frames on 15 rolls lie under terrain at or above the catalogued aircraft height** (`r <= 0`). Their ratio above sea level is in band, but the mean of MRDEM under the nominal square is higher than `flying_height`. `fly_footprint(dem =)` keeps them in its terrain-above-aircraft case. A factor-1 row cannot reach them (the `tabled` condition requires `r_reported > 0`), so the fly#93 `terrain` tail leaves them untailed, by amendment A3. Largest roll-heights:

   | roll | year | flying_height | focal | scale | frames | median elev |
   |---|---|---|---|---|---|---|
   | `bcc285` | 1981 | 1707 | 305 | 1:5000 | 106 | 1,974 |
   | `bc77070` | 1977 | 1158 | 153 | 1:5000 | 59 | 1,392 |
   | `bc77087` | 1977 | 1158 | 153 | 1:5000 | 38 | 1,334 |
   | `bc7718` | 1975 | 1524 | 305 | 1:5000 | 24 | 1,776 |
   | `bcc267` | 1980 | 1524 | 305 | 1:5000 | 23 | 2,213 |

   The other ten are `bc5602`, `bc81111`, `bc81075`, `bc80117`, `bc5695`, `bc77026`, `bc79121`, `bc77072`, `bcc325` and `bc5715`.

2. **176 terrain roll-heights (2,380 frames) where spacing fits nominal scale.** Amendment A2 excludes these, because no logbook height can make #72's rule accept them. Nominal scale already sizes them, but the disagreement sits in the height field. A height recorded above ground instead of above sea level would produce exactly this pattern: ratio above sea level in band, `r` below it, and nominal right.

## What to do

- Decide whether "height recorded above ground" can be tested. The logbook TRUE HEIGHT column is labelled M'/M.S.L. on the forms read so far. A page that writes a height equal to the catalogue's, under a header that says above ground, would be a witness. Spacing at `flying_height` taken as height above ground, i.e. `side = flying_height / f`, is another.
- Any rule is fixed before it is run, as in fly#60/#72/#93.
- Nothing is wrong today for group 2, which nominal already sizes. Group 1 frames are drawn at nominal with a warning.

Related: fly#93, fly#54, fly#60.
