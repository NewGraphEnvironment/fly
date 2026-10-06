# Findings — Three infrared roll-heights carry a right height beside a wrong scale (#91)

## Issue context

## Problem

fly#89 sized infrared film as the 9-inch negative, so IR frames now reach the #54 `flying_height` check. 56 of the 3,825 IR frames fall outside `fly_height_ratio_band()`. They sit on three roll-heights. On every one of them, adjacent-frame spacing in `inst/extdata/infrared_film_frames.csv` fits the **reported** height and rejects nominal scale. The figures are printed by `data-raw/format_measure-infrared_film.R` and recomputed by `test-fly_footprint_infrared.R`:

| roll | frames | scale | flying_height | focal | ratio above sea level | r | overlap at nominal | overlap at reported |
|---|---|---|---|---|---|---|---|---|
| `bc5312` | 17 | 1:30000 | 3353 | 153 | 0.731 | 0.47 | 0.805 | 0.594 |
| `bci12` | 14 | 1:15840 | 3682 | 305 | 0.762 | 0.51 | 0.807 | 0.620 |
| `bci9` | 25 | 1:8000 | 5944 | 305 | 2.436 | 2.03 | 0.228 | 0.620 |

The window is 0.557 to 0.780. The logbook pages write each catalogued height: 11.0, 12.08 and 19.5 thousand feet. So each roll-height carries a right height beside a wrong `scale`, the defect fly#60 and fly#72 tabled for BW and colour.

Today all 56 are drawn at nominal scale, with or without a DEM. That is about 2x (`bc5312`, `bci12`) or 0.5x (`bci9`) the width the spacing supports. With a DEM the #54 check sends them to nominal; without one every film frame is nominal.

## What to do

**The existing rules do not reach two of the three.** `data-raw/height_calibrate-lower_tail_rolls.R` reads the strata cut on ratio above sea level: `lower_tail` (at or below 0.5), `upper_tail`, and `near_upper` (2 to 3).
- `bci9` (2.436) is inside `near_upper`, so it can go through the near-upper rule as it stands.
- `bc5312` and `bci12` (0.73, 0.76) leave the band only through terrain, so no stratum holds them.

Settling those two needs a rule for terrain-driven out-of-band frames, fixed before it is run. The witnesses are the same: logbook and spacing.

**Logbook note on `bci9`.** Sheet 2 (`bcir9_2.jpg`, finals 101-128) has "Scale 1/15,840" written on it. Its 1:8000 frames are 12-36, which sheet 1 covers, and sheet 1 writes no scale. So that note is not yet a witness for them.

**The rules were fixed for BW and colour.** Check whether any of them assumes BW/colour before running them on IR, and record any amendment as such.

Found in code-check rounds 3-4 of fly#89. It was out of scope there: that issue settles format, not height.


## Pre-registered rule (fixed 2026-10-06, before the blind logbook read)

**What was already known when this was written, and so cannot be called blind.** Spacing on
all three roll-heights (from #89's `infrared_film_frames.csv`: fits the reported height,
rejects nominal), and the three logbook heights as a #89 reviewer read them with the catalogue
values in view (11.0, 12.08, 19.5 thousand feet). What is NOT yet known is what a reader who
cannot see the catalogue writes down for these pages, which is the logbook witness the rule
uses. Phase 2 produces it.

### Populations

From `inst/extdata/infrared_film_frames.csv`, the frames with `height_class == "outside_band"`
(56 today). With `ratio_asl = flying_height / (scale_n * focal_length / 1000)` and
`r = (flying_height - elev) / (scale_n * focal_length / 1000)`, each frame goes to:

- `near_upper` if `2 < ratio_asl <= 3` and `r > band[2]` — #72's stratum, joined to the sweep's
  252 frames and run through the same `settle()` call. Today: `bci9` 5944 m 1:8000 305 mm.
- `terrain` (new tail) if `ratio_asl` is inside the band and `r` is not — out of band only
  because of the ground under it. Today: `bc5312` 3353 m 1:30000 153 mm and `bci12` 3682 m
  1:15840 305 mm.
- anything else (`ratio_asl <= 0.5`, `> 3`, `(1.6, 2]`, or `r <= 0`): the script **stops**. No
  such frame exists today; a future IR census that produced one needs its own rule.

### The rule

#72's `near_upper` rule, unchanged, applied to both sets, with 1 the only factor named
(`settle(named = 1)`). A roll-height is tabled at factor 1 (`scale_wrong`) only where:

1. the logbook covers at least half its frames, and at least 90% of the covered frames name
   factor 1 (logbook feet x 0.3048 within 2% of the catalogued height);
2. no legible logbook focal length contradicts the catalogue's (within 3 mm);
3. spacing under the logbook height is inside the window **and** spacing at nominal scale is
   not — both halves, as for `near_upper`;
4. no legible logbook scale equals the catalogue's (to 2%): `scale` is the field the row says
   is wrong.

The same-roll sibling witness (fly#74) is not applied: the scale is disputed, not the height,
so there is no relation between heights for a neighbour to name.

### What each outcome means

- All four hold: tabled, `tail` as above, `witness = "logbook"`, `height_m` the logbook's
  feet converted. `fly_footprint(dem =)` then sizes these frames from that height
  (`height_source = "corrected_roll_table"`).
- Any fails: the roll-height ships in `flying_height_rolls_excluded.csv` with the reason
  that actually fired, suffixed "nominal scale still applies", and the frames stay on
  nominal. No fallback rule, no second attempt with a looser threshold.
- A logbook that writes the catalogue's scale for the disputed frames vetoes (4). That would
  be evidence against the catalogue's scale being wrong, and is reported as such.

### Audit: does any step assume BW/colour?

| step | assumes BW/colour? | verdict |
|---|---|---|
| `FORMAT_M` = 9 in | yes, as written | settled for IR by #89 (W1/W2/W3); no change |
| overlap window (0.557-0.780) | measured on BW/colour random in-band frames | the designed ~60% overlap is a flight-planning convention, not a film property; #89's W1 held 27 of 32 IR rolls inside the same window. No change; recorded as an assumption carried over |
| focal tolerance (3 mm) | no | 6" and 12" read as 152-153 / 304-305 regardless of film |
| logbook height = thousands of feet ASL | the #60 forms | the transcriber records the column header verbatim; a header that does not say feet/MSL is noted, and a page whose unit cannot be established is `height_ft_interpreted` blank (read as no height, not guessed) |
| **scale regex (`scale_pat`)** | **yes — only `1:N`** | **Amendment A1 (below)** |
| key formatting (`num()`) | no | unchanged |
| disjoint-tail `stopifnot` | its comment reasons from the three ratio_asl strata | `terrain` is in band above sea level, every other tail is outside it (lower <= 0.5, near_upper (2, 3], upper > 3), so it is disjoint by construction; comment extended |
| `elev` | the sweep's mean under the nominal 9-inch square | `infrared_film_frames.csv` computes it the same way (`format_measure-infrared_film.R` Stage 2); no change |
| `base` | f1's adjacency rule | recomputed in the generator from the same centroid cache and asserted equal to the shipped `base` to 0.1 m |

**Amendment A1 (written before the read).** `scale_pat` accepts only `1:N`. #89's pages for
`bci9` write the scale as "1/15,840", which the pattern reads as no scale at all — so on IR
pages condition 4 could be silently disabled by notation. The pattern is widened to accept
`/` as well as `:` after the leading 1. No existing row of `flying_height_logbooks.csv` has a
`/` in `scale_as_written` (checked: 25 rows carry a scale, all `1:`), so this changes no
BW/colour verdict; the regenerated CSVs are diffed to prove it.
