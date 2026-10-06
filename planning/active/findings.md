# Findings — BW/colour frames out of the height band only through terrain (#93)

## Issue context

## Problem

Some BW and colour film frames leave `fly_height_ratio_band()` only because of the ground under them. Their catalogued `flying_height` is within the band of `scale x focal_length` above sea level, but subtracting the terrain takes the ratio above ground out of it. No roll-table rule reads them.

`data-raw/height_calibrate-lower_tail_rolls.R` cuts its strata on the ratio above sea level:

| stratum | ratio above sea level |
|---|---|
| `lower_tail` | ≤ 0.5 |
| `near_upper` | 2 to 3 |
| `upper_tail` | > 3 |

A frame in band above sea level is in none of them. With a DEM, the #54 check sends every such frame to nominal scale (`height_source = "implausible"`), whatever caused it.

fly#91 settled the infrared frames of this kind (`bc5312`, `bci12`) under a new `terrain` tail, because #89's IR census held all of them. The BW/colour ones were left out of scope there.

## How many

- In the sweep's `random` set, 12 of 2,500 frames are out of band only through terrain. All 12 are below the band and none is above it. The generator prints this line; the 2,500 are a draw from the BW/colour frames with ratio above sea level ≤ 2.
- That is 0.48%, with a Poisson 95% interval of about 0.25-0.84%.
- Scaled to the 1,419,822 usable BW/colour frames at ratio ≤ 2, it comes to roughly **7,000 frames, range 3,500 to 11,900**. This is an estimate from 12 draws, not a census.

It is not known how many of them are a wrong `scale` rather than a frame where nominal scale is right. Low flights over high ground are exactly where terrain is a large share of the reported height, so some of them may be fine as catalogued.

## What to do

1. **Census the stratum.** Take every BW/colour frame whose ratio above sea level is in band and whose ratio above ground is not. That needs MRDEM under each candidate, run as a PSOCK cluster per CLAUDE.md, and it can cover a superset first: frames whose `flying_height` minus the highest plausible terrain could leave the band.
2. **Group by roll-height, and pull and transcribe the logbooks blind.** Transcribe into `data-raw/flying_height_logbooks.csv` with the catalogue values withheld, as fly#60 and fly#91 did.
3. **Run the `terrain` tail's rule unchanged.** It is #72's near_upper rule: the logbook names factor 1, no focal-length conflict, spacing fits the reported height and rejects nominal, and no logbook scale equals the catalogue's. It was fixed in fly#91's archived findings before that read. Re-register it in writing before this census is read.

Related: fly#60, fly#72, fly#89, fly#91.


## Pre-registered rule (fixed 2026-10-06, before the exact census read and before any page is transcribed)

### What was already known when this was written, and so cannot be called blind

A coarse census in plan mode, read-only, using fly#80's cached 250 m DTM (`gdal_translate -outsize 7000
-r average` of MRDEM-30) under the nominal 9-inch square:

- ~4,750 BW/colour frames are in band above sea level and out of band on `r`.
- They sit on 293 roll-heights on 214 rolls, all below the band.
- 12 of those rolls already carry rows in `flying_height_logbooks.csv`.

Spacing on the coarse census, per roll-height median, against the window 0.557-0.780:

| at the catalogued height | at nominal | roll-heights | rolls | frames |
|---|---|---|---|---|
| fits | rejected | ~74 | 56 | ~1,520 |
| fits | fits | 37 | | |
| rejected | fits | 143 | | |
| rejected | rejected | 39 | | |

Coarse elevation against the sweep's exact elevation, over 7,147 sweep frames: 8.5 m at the median, 110 m
at the 99.9th percentile and 162 m at most.

No logbook page of a new roll has been opened, and no catalogue value has been shown to any transcriber.

### Population

Usable BW/colour film frames: the sweep's filter, spelled out as in `height_calibrate-flying_height_slip.R`.
That is `media` in `Film - BW` / `Film - Colour`, finite positive `scale_n`, `focal_length` and
`flying_height`. It is not read from `fly_film_media()`, so IR is not drawn twice; IR is #89's census.

With `nominal_agl = scale_n * focal_length / 1000`, `ratio_asl = flying_height / nominal_agl` and
`r = (flying_height - elev) / nominal_agl`:

- `elev` is the sweep's measure: the mean of MRDEM-30 DTM under the nominal 9-inch square, axis-aligned,
  built in EPSG:3005 and transformed to the DEM's CRS, `terra::extract(fun = mean, na.rm = TRUE)`.
- **`terrain`**: `ratio_asl` is in band (`fly_height_ratio_band()`, edges inclusive), `r` is not, and `r > 0`.
  This is fly#91's definition, unchanged.
- **Above the band through terrain** needs ground below sea level (`elev < flying_height - band[2] *
  nominal_agl <= 0`). Every candidate for it is read exactly. If any frame lands there, the script **stops**,
  because no rule was fixed for one. The same goes for `r <= 0`.

### Prefilter (which frames get the exact read)

Every in-band frame where either of these holds:

- `coarse_elev > flying_height - band[1] * nominal_agl - M`: within `M` of leaving the band below;
- `flying_height - band[2] * nominal_agl > -M`: within `M` of leaving it above.

Also every frame whose coarse box holds no valid cell. A coarse nodata frame is read, never excluded.

- `M` = 2 x the largest |coarse − exact| over every sweep frame with both values finite. It is computed
  in the script and printed.
- A producer line prints, over census frames, the smallest `need − coarse_elev` slack, i.e. how close
  the margin came to binding.
- The coarse DTM is rebuilt into this script's own cache with the same recipe, keyed on MRDEM's ETag.

### Controls (the script stops if any fails)

1. **The instrument is the sweep's.** Every sweep frame inside the prefilter is read exactly by this
   script's worker. It must reproduce the shipped `flying_height_sweep.csv` `elev` to 0.1 m. If MRDEM has
   changed under the sweep, this fails rather than mixing versions.
2. **Completeness.** Every sweep `random` frame that is out of band only through terrain (12 today) is in
   the census, with the same `elev`.
3. **The same air base.** `base` is computed with the generator's f1 rule (the adjacency `fly_bearing()`
   uses), and the generator asserts equality to 0.1 m, as it does for the IR census.

### The rule

#72's near_upper rule, **unchanged**, with 1 the only factor named (`settle(named = 1, tail = "terrain")`),
joined to fly#91's IR terrain frames. A roll-height is tabled at factor 1 (`scale_wrong`) only where all
four hold:

1. the logbook covers at least half its frames, and at least 90% of those name factor 1 (logbook feet
   x 0.3048 within 2% of the catalogued height);
2. no legible logbook focal length contradicts the catalogue's (to 3 mm);
3. spacing under the logbook height fits the window **and** spacing at nominal does not;
4. no legible logbook scale equals the catalogue's (to 2%).

The fly#74 sibling witness is not applied: the scale is disputed, not the height.

### Amendment A2: evaluation order (written before the exact census and the read)

Condition 3 is examined **before** any page is transcribed. A roll-height for which it **cannot** hold,
whatever a logbook says, is not transcribed. "Cannot" is decided from logbook-independent quantities only,
so A2 removes no roll-height the unamended rule could accept:

- **(a) Nominal half.** `p_nominal` in `settle()` is the median over **all** frames of the roll-height, and
  it does not depend on the logbook. If `fits(median p_nominal)`, condition 3 fails whatever is read.
- **(b) Logbook-height half.**
  - Under factor 1 the shipped height `h_true` is within 2% of `flying_height`.
  - `p_corrected` is a median over a **subset** of the frames, those whose logbook agrees.
  - For each frame with a finite `base`, overlap is monotone in height, so its value at any `h_true` lies in
    `[p_i(0.98 h), p_i(1.02 h)]`.
  - A median of any subset lies within the range of its members.
  - So if `[min_i p_i(0.98 h), max_i p_i(1.02 h)]` does not intersect the window, or no frame has a finite
    `base`, condition 3 fails whatever is read.

A roll-height that (a) or (b) excludes ships in `flying_height_rolls_excluded.csv`, with the reason that
fired, ahead of every logbook reason:

- (a): "spacing fits nominal scale; logbook not read; nominal scale still applies";
- (b): "spacing cannot fit the catalogued height within 2%; logbook not read; nominal scale still applies".

It is never "no logbook page covers these frames", because an absent read is not an absent page. Every
other roll-height is transcribed and goes through the rule above in full.

A2 applies to the whole `terrain` tail, IR included. `bc5312` and `bci12` pass it (spacing 0.594 / 0.620 at
the reported height, 0.805 / 0.807 at nominal). The diff must show both rows byte-identical.

### Audit: anything new for BW/colour?

| step | verdict |
|---|---|
| 9-inch `FORMAT_M`, window, focal tolerance, scale regex (A1), key formatting | the rule was built on BW/colour; no change |
| disjoint-tail `stopifnot` | `terrain` is in band above sea level; the other three tails are outside it. Disjoint by construction, as in fly#91 |
| `elev` against `fly_footprint()`'s own first pass | `fly_footprint()` reads the footprint rotated onto its bearing (#26) where a bearing exists. The census uses the sweep's axis-aligned square, as every tail does. A frame near the edge may classify differently in the package, and the table row reaches it there anyway, since the key is the roll-height. Recorded as an assumption carried over |

### What each outcome means

- **All four hold:** tabled, `tail = "terrain"`, `witness = "logbook"`, `height_m` = logbook feet x 0.3048.
  `fly_footprint(dem =)` then sizes these frames from that height (`corrected_roll_table`).
- **Any fails:** the row is excluded with the reason that fired, and the frames stay nominal.
- **A2(a) roll-heights** (spacing fits nominal) are where nominal scale is right: the "fine as catalogued"
  case the issue raises, where the catalogued height, not the scale, is the field that disagrees. They are
  counted and reported, and not acted on here.

### Amendments after the plan review and the smoke run (2026-10-06, before the full census)

The plan review is `review-plan.md`. The smoke run read 1,074 candidate frames from a draw, not the census.

- **A2 wording** (before any page was read). The two A2 reasons make no claim about whether a page was
  read, because whole pages are transcribed and 12 rolls already carry rows:
  - "spacing fits nominal scale, which no logbook height changes; nominal scale still applies";
  - "spacing cannot fit the catalogued height within 2%, whatever the logbook reads; nominal scale still
    applies".

  The generator also sets `accept <- accept & !a2`. That is redundant by construction and kept as the guard.
- **Self-consistent margin** (before the full census). `M` starts at 2x the sweep's worst coarse error and is
  recomputed as 2x the worst over every frame read exactly. The prefilter widens until a pass leaves `M`
  where it was. The sweep over-represents large footprints, and the coarse error grows on small ones over
  steep ground.
- **Control 3** (before the full census). A seeded draw of up to 1,000 frames the prefilter turned away, from
  the 500 m just past its lower edge, is read exactly. Not one may be out of band.
- **A3: `r <= 0`** (written AFTER the smoke run, which found 11 such frames in 1,074, on 7 rolls).
  - The pre-registration stopped the script on them, as fly#91 did. These are frames under terrain at or
    above the catalogued aircraft.
  - `fly_footprint()` holds them in its own terrain-above-aircraft case and applies a factor-1 row only
    where `r_reported > 0` (`R/fly_footprint.R`, the `tabled` condition). So the `terrain` tail cannot move
    them whatever it decides.
  - They are counted in the population CSV and assigned to no tail. A follow-up issue records them.
  - Frames above the band still stop the script.
- **S1.** The A2(a) "spacing fits nominal" roll-heights are consistent with a height recorded above ground
  rather than above sea level. That is a hypothesis, not an outcome, and it is not tested here.
