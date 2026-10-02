# Measure a film roll's corner mapping from its own overlapping frames

A film footprint is a square rotated onto its flight line, and which
corner of the scanned image belongs on which corner of that square is a
property of the **roll**, not of film: fly#26 measured 0 on bc5282
(1968) and 90 on bc83062 (1983). So
[`fly_georef()`](https://newgraphenvironment.github.io/fly/reference/fly_georef.md)
refuses a rotated film frame unless the roll's rotation is known, either
from the measured table it ships or from a `rotation` column. This
function produces that column for a roll the table does not cover, by
the same measurement and the same rule that built the table.

## Usage

``` r
fly_rotation_calibrate(
  photos_sf,
  dest_dir = tempfile("fly_rotation_"),
  max_legs = 6,
  mask = c("border", "none"),
  mask_threshold = fly_mask_threshold()
)
```

## Arguments

- photos_sf:

  Catalogue centroids for one or more film rolls, as POINT geometry with
  the columns
  [`fly_footprint()`](https://newgraphenvironment.github.io/fly/reference/fly_footprint.md)
  needs plus `film_roll`, `frame_number` and `thumbnail_image_url`. Pass
  whole rolls, or at least whole flight lines: legs are found from
  frames adjacent by `frame_number`, so a sample of a roll finds none.

- dest_dir:

  Directory the thumbnails and the trial GeoTIFFs are written to.

- max_legs:

  Most legs scored per roll, chosen as the longest. Every leg found is
  still reported.

- mask, mask_threshold:

  Passed to the warp exactly as
  [`fly_georef()`](https://newgraphenvironment.github.io/fly/reference/fly_georef.md)
  uses them, so the verdict is for the output a caller actually gets.

## Value

A tibble with one row per roll: `film_roll`; `rotation`, the measured
value or `NA`; `state`, why; `legs_found` and `legs_qualifying`; `legs`,
a list-column with one row per qualifying leg carrying its frames,
bearing, segment, status, verdict, margin, number of scored pairs and
the mean overlap correlation at each rotation; and `pairs`, a
list-column with every scored pair, from which each verdict can be
recomputed.

## Details

**What is measured.** Consecutive frames on a line overlap by about 60%,
so at the correct rotation their common ground must agree. Each leg is
georeferenced at all four rotations and every adjacent pair is scored by
the correlation of their common ground at 25 m. No reference imagery is
needed: the frames check each other. This is the measurement that
decided the digital mapping in fly#38.

**What counts as a leg.** Frames joined by steps adjacent by
`frame_number` whose bearing stays within 10 degrees of the leg's first
step and whose spacing stays within a factor 1.5 of the leg's median. It
**qualifies** with at least 6 frames, on any bearing. A leg longer than
11 frames is scored on its central 11.

**When a leg is decisive.** The winning rotation must beat **each**
other rotation on enough pairs that a one-sided sign test gives p \<=
0.05: 5 of 5, 6 of 6, 7 of 7, 7 of 8, 8 of 9, 9 of 10. A rotation the
stretch guard refuses does not compete.

**When a roll gets a rotation.** At least two decisive legs, all of them
agreeing, two of them on bearings at least 90 degrees apart. Ninety,
because a roll whose scans came off in a fixed *geographic* orientation
would also agree with itself on two legs closer than that, and the
shipped value is applied on every bearing the roll flies. A reverse leg
counts. The states, first match wins:

|  |  |
|----|----|
| `state` | meaning |
| `legs_disagree` | two decisive legs name different rotations |
| `shipped` | the rule above is met; `rotation` is set |
| `single_direction` | decisive legs agree, but all within 90 degrees |
| `one_decisive_leg` | one leg decided, which the rule does not accept alone |
| `no_decisive_leg` | legs were scored and none decided |
| `thumbnails_unavailable` | no leg scored, and at least one for want of its images |
| `legs_unscorable` | no leg scored for another reason (see the leg `status`) |
| `no_qualifying_leg` | nothing in the input meets the leg definition |

Each leg's `status` says which: `scored` (it could have decided),
`not_rotated`, `thumbnails_unavailable`, `refused`, `warp_failed`,
`too_little_overlap` (pairs share under 500 cells at 25 m, as at 1:3000)
or `not_scored`. Its `segment` is the scale and flying height along it,
so legs from different missions on one roll can be told apart.

The rule was fixed before the campaign that built
[`fly_georef()`](https://newgraphenvironment.github.io/fly/reference/fly_georef.md)'s
table read a single thumbnail, and this function applies it unchanged.
See `inst/notes/georeferencing.md`.

**What it cannot tell you.** The verdict is for the image measured — the
public **thumbnail**. A full-resolution scan delivered in another
orientation is not covered. Nor is a scan **mirrored** about the flight
line: both frames' centres sit on that axis, so a mirrored pair agrees
with itself exactly and overlap cannot see it.

## See also

[`fly_georef()`](https://newgraphenvironment.github.io/fly/reference/fly_georef.md),
which consults the shipped table of measured rolls.

## Examples

``` r
if (FALSE) { # interactive()
# One leg of bc5282 and one of its reverse, pulled from the catalogue.
roll <- bcdata::bcdc_query_geodata("WHSE_IMAGERY_AND_BASE_MAPS.AIMG_PHOTO_CENTROIDS_SP") |>
  bcdata::filter(FILM_ROLL == "bc5282") |>
  bcdata::collect()
names(roll) <- tolower(names(roll))
cal <- fly_rotation_calibrate(roll, max_legs = 2)
cal[, c("film_roll", "rotation", "state")]

# Join it on, and fly_georef() uses it.
roll$rotation <- cal$rotation[match(roll$film_roll, cal$film_roll)]
}
```
