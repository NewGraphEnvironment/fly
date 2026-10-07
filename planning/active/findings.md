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

## Pre-registered rule (fixed 2026-10-06, before any per-roll-height spacing or logbook verdict for this question exists)

### What was already known when this was written, and so cannot be called blind

- The issue's table of the five largest `r <= 0` roll-heights, and fly#93's census counts (374 frames on 15
  rolls at `r <= 0`; 176 A2(a) roll-heights, 2,380 frames).
- **fly#93's excluded reasons** for every terrain roll-height, including those of the group-1 rolls. Among
  them: `bcc285` 1707, `bc79121` 2438, `bc81075` 1554/1676, `bc81111` 2073 and `bc5715` 2499 are A2(a)
  "spacing fits nominal" **on their `r > 0` frames**; `bc77070` 1158, `bc77087` 1158/1676/1981, `bc5602`
  1219, `bc5695` 945, `bc5715` 732 and `bcc325` 396 are A2(b); `bc77026` 2042 and `bc77072` 1829/1981 had
  spacing reject the logbook's height. So the two groups share roll-heights.
- **Pooled peek over group 2** (2,380 frames), computed in plan mode: `ratio_asl` median 1.06, range
  0.63-1.59; overlap median 0.672 at nominal and 0.674 at `flying_height` read as above ground. Group-2
  roll-heights by `ratio_asl`: 20 at <= 0.77, 8 at 0.77-0.9, 60 at 0.9-1.1, 49 at 1.1-1.3, 39 above 1.3.
- **Logbooks.** All 871 transcribed rows carry a TRUE HEIGHT header that is M'/M.S.L.-type, "True Height",
  or blank; none says above ground. Rows exist for 4 of the 15 group-1 rolls (`bc5602`, `bc77026`,
  `bc77072`, `bc77087`) and 22 of group 2's 144 rolls.
- Not computed: any per-roll-height overlap at `flying_height` read as above ground; any spacing on a
  `r <= 0` frame; any logbook relation under this rule.
- An observation, not a result: 1,524 m is 5,000 ft, which is exactly the height above ground that 1:5000 on a
  12-inch lens implies. On `bc7718` and `bcc267` the catalogued height *is* nominal above ground, to the metre.

### The hypothesis, and what it predicts

**AGL**: on a roll-height, the catalogued `flying_height` is the height above ground, not above sea level.
Then each frame's along-track side is `FORMAT_M x flying_height / f`, and its forward overlap is
`p_agl = 1 - base / (FORMAT_M x flying_height / f)`.

Nominal scale predicts `p_nominal = 1 - base / (FORMAT_M x scale_n)`. Neither depends on terrain, so
a roll-height mixing `r <= 0` and `r > 0` frames is judged on one quantity, and the two predicted sides
are exactly `ratio_asl` apart. **Where `ratio_asl` is near 1 the two readings cannot be separated by spacing,
and do not need to be: they draw the same footprint to within `|ratio_asl - 1|`.**

### Population

Every roll-height (roll, `flying_height`, `focal_length`, `scale_n`) that reaches a BW/colour frame at
`r <= 0` in fly#93's census, or that fly#93's A2(a) excluded. Its frames are every frame of that key in
either fly#93 census file (`flying_height_terrain_frames.csv` and, from Phase 2,
`flying_height_terrain_nonpositive.csv`). The infrared census holds no frame at `r <= 0` (checked), so IR
adds nothing.

### Witness S: spacing (decided first)

Per roll-height, over frames with a finite `base` (the generator's f1 rule):
`P_agl = median p_agl`, `P_nom = median p_nominal`, against the generator's window (`p_window`, the
central 95% of in-band random frames' overlap as reported), `fits()` as there.

| S | condition |
|---|---|
| `supports` | `fits(P_agl)` and not `fits(P_nom)` |
| `undecided` | `fits(P_agl)` and `fits(P_nom)` |
| `refutes` | not `fits(P_agl)` |
| `no_base` | no frame has a finite `base` |

### Witness L: the logbook

Per frame, through `settle()`'s own join and states (read / conflict / uninterpreted / unspanned / none),
with `h_lb` = logbook feet x 0.3048. A read frame is classified:

| relation | condition |
|---|---|
| `catalogue` | `abs(h_lb / flying_height - 1) <= 0.02` (the crew's figure is the catalogue's) |
| `ground_plus` | `abs(median over the roll-height's read frames of (h_lb - elev) / flying_height - 1) <= 0.10`, evaluated per logbook height |
| `ambiguous` | both of the above (ground within ~12% of the height of sea level, where AGL and ASL coincide) |
| `other` | neither |

`elev` is the census's (the sweep's instrument). A row whose `height_header` names the ground
(`/ground|A\.?G\.?L|terrain|clearance/i` and not `/M\.?S\.?L/i`) turns `catalogue` into `ground_header`.
The 10% is fixed here: it is narrower than anything spacing can separate (~1.6x), wide enough for a crew's
planning datum against MRDEM's mean under the frames, and disjoint from `catalogue` wherever the ground
is more than ~12% of the height above sea level, which holds for every `r <= 0` frame by definition.

### The tabling rule (#72-shaped)

A roll-height is tabled as above ground only where **all** hold:

1. S is `supports`;
2. the logbook reads at least half its frames, and at least 90% of those are `ground_plus` or
   `ground_header`;
3. no legible logbook focal length contradicts the catalogue's (to 3 mm);
4. not one of the roll-height's frames is in band as catalogued (the defect is the roll-height's, not a
   frame's).

Everything else is excluded with the reason that fired, the first in this order: S (`refutes`,
`undecided`, `no_base`), then 2-4. The height shipped follows #60: the logbook's, never the catalogue's,
where the logbook supplies it. If any row tables, how it is encoded is put back to the user before the
generator writes it, because it is a schema decision.

### Evaluation order (as fly#93's A2)

S is computed first, from logbook-independent quantities. Pages are fetched and transcribed blind only for
roll-heights where S is `supports`; S `refutes`/`undecided`/`no_base` cannot table whatever a page says.
L is still reported, ungated, on every population roll-height that already has transcribed rows.

### What each outcome means

- **Tabled**: the footprint is sized from the height above ground; today it is nominal with a warning.
- **`undecided`**: AGL and nominal fit together; nominal stays and the two differ by `|ratio_asl - 1|`,
  which is reported as the bound on what is left unsaid.
- **`refutes`**: spacing rejects reading the catalogued height as above ground; that roll-height's height
  is wrong some other way, and nominal stays where nominal fits.
