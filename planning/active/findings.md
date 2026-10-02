# Findings — Ship measured per-roll film rotations as a table (#53)

## Issue context

## What changes if we do it

Film becomes georeferenceable without the caller doing their own calibration. #26 established that the corner mapping is **flight-relative but per-roll**, and measured two rolls:

| roll | year | rotation | margin |
|---|---|---|---|
| bc5282 | 1968 | 0 | 0.089 |
| bc83062 | 1983 | 90 | 0.135, 0.196, 0.152 (three legs) |

Shipping those as `inst/extdata/film_rotations.csv`, keyed on `film_roll` and consulted by `fly_georef()` before the refusal fires, would make those two rolls work out of the box and give later measurements somewhere to land.

## What happens if we never do

`fly_georef()` keeps refusing every rotated film frame with a warning naming the fix, and each user re-derives the same numbers for the same rolls. That is the *correct* default — refusing beats writing a GeoTIFF turned a quarter turn — so this is an improvement, not a defect.

## Why it was deliberately not done in #26

Two rows is a thin table, and a thin table invites the reading that an unlisted roll is **missing** rather than **unmeasured**. That is the failure `camera_formats_excluded.csv` exists to prevent on the digital side: every calibration deliberately not shipped is recorded *with its reason*. A film table needs the same discipline before it ships, plus enough rows that the fallback-to-refusal reads as a real state rather than as an omission.

## What would make it ready

- More rolls, spanning more eras. The 1968/1983 split is the whole evidence base for "per-roll", and two points cannot distinguish per-roll from per-era from per-scanner.
- A stated provenance column per row — which legs, what margin, measured when — since `data-raw/georef_calibrate-corner_mapping.R` reproduces the method but not the record.
- A decision on whether the key is `film_roll`, `photo_year`, or something about the scanning batch. `#26` could not settle this: the two measured rolls differ in both roll and era.

Method and full results: `inst/notes/georeferencing.md`, "Film has no constant". Reproduce with `data-raw/georef_calibrate-corner_mapping.R` section 4.


## Errors Encountered

| Error | Resolution |
|-------|------------|

## Leg structure in the catalogue (cache probe, 2026-10-02, no thumbnails read)

`data-raw/.cache/centroids/` holds **6,716 film rolls** (1,446,804 frames once rows with no
roll or frame are dropped); no duplicated roll-frame; 2 rolls span more than one year.
Centroids along a pre-1990s line are interpolated — identical step bearing and spacing
repeated frame after frame — and a leg change shows as an adjacent-by-number step with a
wild bearing and a spacing jump (bc5282 21→22: 13.2 km against ~1.1 km; bc83062 39→40:
6.6 km against ~0.7 km). So a leg is found by **step bearing and step spacing together**,
not by frame adjacency alone. bc5282 flies 308 / 168 / 345 / 126 / 128 legs in its first 75
frames; bc83062 93 / 89 / 269 / 272 / 101 / 92 / 150 — most of bc83062 is cardinal, which is
why #26 measured it on three hand-picked diagonal legs.

## Pre-registered rule (fixed before any thumbnail is read)

Written here and committed before the campaign runs. The code in `R/fly_rotation_calibrate.R`
implements exactly this; a change after the first thumbnail is read is an amendment, dated
and recorded below with its reason.

**Leg.** Frames on one roll, ordered by `frame_number`, joined by steps that are adjacent by
number. A run continues while each step's bearing is within **10°** of the run's first step
and its spacing within a factor **1.5** of the run's median spacing. A qualifying leg has
**≥ 6 frames** and is **not cardinal**: the median step bearing sits **≥ 15°** from every
multiple of 90 (the section-4 premise of `georef_calibrate-corner_mapping.R`, kept as #26
used it). A leg longer than 11 frames is scored on its central 11, #26's leg length.

**Leg score.** Each frame's footprint from `fly_footprint()` (no DEM), which must be square
and rotated (finite `footprint_bearing`). Thumbnails georeferenced by `georef_one()` at
rotations 0/90/180/270 with `fly_georef()`'s defaults (`mask = "border"`), so the verdict is
for what a caller actually gets. Each adjacent pair scored by the Pearson correlation of
their common ground resampled (`average`) to 25 m, pixels with alpha 0 excluded, ≥ 500
common cells or the pair is NA. A rotation refused by the stretch guard is not scored, it
does not compete.

**Leg verdict.** The rotation with the highest mean pair correlation. **Decisive** when, against
**each** other scored rotation, the winner has the higher correlation on enough pairs that a
one-sided sign test gives **p ≤ 0.05** (n = pairs finite under both; 5 of 5, 6 of 6, 7 of 7,
7 of 8, 8 of 9, 9 of 10; under 5 pairs nothing is decisive). Basis: a leg verdict drawn from noise would win each pair with
probability ½; requiring that against every rival is what a margin floor cannot say, because
a margin has no scale until a null gives it one. Adjacent pairs share a frame, so they are
not independent and the nominal p flatters the leg; the two-leg roll rule is what absorbs
that, not the p. The margin (best − runner-up) is recorded,
not thresholded.

**Roll states**, evaluated in this order, first match wins — the serious states first:
1. `legs_disagree` — two decisive legs name different rotations.
2. `shipped` — ≥ 2 decisive legs, all agree, and two of them have bearings **≥ 30°** apart
   (circular; a reverse leg counts, and is the sharpest flight-relative-vs-geographic test,
   since geographic predicts a 180° shift between them).
3. `single_direction` — ≥ 2 decisive legs agree but all lie within 30° of each other.
4. `one_decisive_leg`
5. `no_decisive_leg` — ≥ 1 leg scored, none decisive.
6. `thumbnails_unavailable` — qualifying legs exist, none could be scored for want of images.
7. `no_qualifying_leg` — nothing in the input meets the leg definition.

The ledger adds an eighth, `not_sampled`, for an eligible roll the campaign did not draw.

**Sample.** Eligibility from the cache alone: ≥ 2 qualifying legs with bearings ≥ 30° apart.
Strata are roll series (`sub("[0-9].*", "", film_roll)`) × 5-year bin of `photo_year`. Draw
**4** eligible rolls per stratum (all of them where fewer), `set.seed(53)`; bc5282 and bc83062
forced in. In a drawn roll at most **6** legs are scored, chosen as the
longest, so a roll with many lines does not cost more than it informs.

**Controls, before the campaign.** (1) Digital: the bundled UltraCam frames 19:24 through the
same scorer must return 270 decisive. (2) #26's four film legs must reproduce 0, 90, 90, 90.
Either failing stops the run.

**What this cannot witness.** Only thumbnails are public, so every verdict is for the
thumbnail delivery; a full-resolution scan delivered in another orientation is not covered.
Every verdict is a composite with `fly_rectangles()`' vertex order (vertex 1 at
`bearing + 225`), and void if that changes.
