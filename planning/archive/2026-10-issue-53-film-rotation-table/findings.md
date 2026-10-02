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

## Controls (2026-10-02, after pre-registration commit 6e25af5)

Run through `fly_rotation_score_leg()` + `fly_rotation_verdict()`, `mask = "border"`.

| leg | verdict | decisive | margin | means 0 / 90 / 180 / 270 |
|---|---|---|---|---|
| digital bcd UltraCam, bundled 19:24 (sorted by roll, frame) | **270** | yes (5/5) | 0.634 | refused / +0.027 / refused / +0.661 |
| bc5282 226-236 | **0** | **no** | 0.092 | +0.390 / +0.298 / +0.222 / +0.281 |
| bc83062 63-73 | **90** | yes | 0.265 | +0.105 / +0.450 / +0.186 / +0.043 |
| bc83062 108-118 | — | — | — | `not_rotated`: not a leg in today's catalogue |
| bc83062 152-162 | **90** | **no** | 0.136 | +0.142 / +0.315 / +0.178 / +0.014 |

The harness reproduces #26 in **direction** on every leg it can score (0, 90, 90) and the
digital control, so the control passes as pre-registered (it named rotations, not decisiveness).
Decisiveness is the new layer and it is stricter than #26's mean margin: bc5282's leg wins
pairs 1-4 and 9-10 clearly for 0 and loses pairs 5-7 to 90/270, so a sign test against each
rival does not clear. #26's margins were never tested against a null; this says the 0.089 one
would not have survived one.

**#26's "bc83062 b=93, frames 108-118" is not a leg in the catalogue as it stands.** Frames 116
and 117 are absent; 106-115 fly 153° and 118-120 fly 73°. A subset handed to `fly_footprint()`
leaves 118 with no adjacent neighbour, so it is drawn unrotated. Whether the catalogue changed
since #26 or #26's label was wrong is not recoverable from here. The note's table quotes this
row and is corrected in Phase 5.

Runtime: ~10 s per 6-frame leg including downloads, ~20 s for 11 frames, single process.

## Amendments to the pre-registered rule (2026-10-02)

Made after the plan review (`review-plan.md`) and after reading **control** thumbnails only, before
any campaign thumbnail. Each says what prompted it, so a reader can judge whether the controls
steered it.

1. **Cardinal legs qualify.** The section-4 premise ("a cardinal leg is degenerate") was asserted,
   never measured, and it would have left ~5,000 of 6,716 rolls with no qualifying leg — a
   calibrator that answers `no_qualifying_leg` for three rolls in four is no route out. Measured on
   the two known-answer rolls (`fly_rotation_score_leg()`, central 11 frames of each cardinal leg):

   | roll | frames | bearing | verdict | decisive | margin |
   |---|---|---|---|---|---|
   | bc83062 | 46-56 | 91.9 | 90 | yes | 0.222 |
   | bc83062 | 5-15 | 89.3 | 90 | yes | 0.194 |
   | bc83062 | 25-35 | 271.9 | 90 | yes | 0.189 |
   | bc5282 | 110-120 | 169.9 | 0 | yes | 0.178 |
   | bc5282 | 133-143 | 349.8 | 0 | no | 0.011 |
   | bc5282 | 25-35 | 167.5 | 90 | no | 0.010 |
   | bc5282 | 41-51 | 345.2 | 270 | no | 0.006 |

   Every decisive cardinal leg agrees with its roll's known answer, including a reverse pair on
   bc83062 (89.3 and 271.9 — geographic would have predicted a 180 shift between them); the
   undecided ones are undecided, not wrong. What a cardinal leg cannot do alone is separate
   flight-relative from geographic, and that is the roll rule's job (amendment 2). A leg now
   qualifies on **≥ 6 frames** alone.
2. **Roll separation is ≥ 90°, not ≥ 30°** — in the roll rule, in eligibility and in
   `single_direction`. Reasoned, not measured: under a geographic truth a leg's winner is
   `round90(T - b)`, so two legs Δb < 90 apart pick the same rotation with probability
   `1 - Δb/90` — two in three at 30°. Only Δb ≥ 90 guarantees a geographic roll disagrees with
   itself. #26's rejected rival sat at 80° apart.
3. **Controls restated.** #26's "bc83062 108:118 at 93°" is not a leg (106-115 fly 153°, 116-117
   absent, 118 onward 73°) and "152:162 at 62°" flies **251°**. The control is now: the digital
   leg returns 270 decisive, and each #26 leg that exists (bc5282 226-236, bc83062 63-73 and
   152-162) returns #26's direction. Decisiveness is not required of them; #26's margins came from
   an unmasked `srcnodata = "0"` pipeline (pre v0.11.0), so only winners are comparable.
4. **Two states added.** A leg on which the stretch guard refused all four rotations is `refused`,
   not `scored`; a roll none of whose legs could be scored for a reason other than thumbnails is
   `legs_unscorable`. Folding both into `no_decisive_leg` ("scored, none decided") was false.
5. **Segment recorded.** 605 eligible rolls carry more than one scale. Each leg records its
   `segment` (scale / flying height), and the campaign tabulates whether decisive legs on one roll
   but different segments agree — the only data here that bears on roll vs scanning batch. Not a
   shipping requirement: the key is the roll, by decision at the gate.
6. **Ledger states for an unmeasured roll**, from the cache: `no_qualifying_leg`,
   `one_qualifying_leg`, `single_direction`, `not_sampled`, with a `measured` column separating
   them from the same names reached by measurement.

Limit added to "what this cannot witness": overlap scoring cannot see a **reflection about the
flight line** — both frames' centres sit on that axis, so a mirrored scan agrees with its
neighbour exactly. Only known ground (the section-3 water check) can.
7. **The draw continues until a stratum has 4 rolls with thumbnails** (at most 12 examined per
   stratum). The smoke run drew bc4196 and bc4200 (1963), and neither carries a single
   `thumbnail_image_url` — the cache cannot see availability, so a fixed draw of 4 spends the
   stratum on rolls that cannot be measured. The draw *order* is still the seeded permutation
   fixed before anything is read; which rolls are examined depends on availability only, never
   on a verdict. A roll counts when at least half its frames carry a URL. Every roll examined is
   calibrated and recorded (an imageless one lands in `thumbnails_unavailable`), so the ledger's
   `measured` covers everything looked at.

Code-check round 2 (P2) added a leg status, `too_little_overlap`: a leg is `scored` only when
two rotations each have 5 finite pairs, i.e. when it could have been decisive. Pairs share under
500 cells at 25 m on a 1:3000 frame, and such a leg was reading as a measured non-decision —
the same class as amendment 4.

Code-check round 3 (P2) named the mechanism behind all three rounds: **an absent
measurement and a real one shared one encoding**, so downstream code inferred which it was —
`FALSE` for refusal-or-error (round 1), `status == "scored"` for scored-or-empty (rounds 1-2),
and an all-NA column for refused-or-no-pairs (round 3). Round 3 found the last one shipping a
leg as decisive against a rival it was never tested on. Fixed at the source: the scorer
returns `refused` explicitly, the verdict takes it, and `scored` is gated by
`fly_rotation_could_decide()`, the verdict's own precondition. The campaign was stopped before
any roll was calibrated (41 pulls cached) and restarted on the fixed code.

Code-check round 4 (P2) found no defect inside the round-3 fix and terminated the loop by
enumeration: every NA / NULL / FALSE / empty-string / zero-row encoding across the calibrator,
the table test and the campaign script, each checked for whether its two meanings can still be
confused; `fly_rotation_could_decide()` brute-forced equivalent to the verdict's precondition
over 19,993 random NA/refusal patterns. Two fragile points fixed: zero-length steps no longer
join a leg (`atan2(0, 0)` is north; one qualifying such leg in the catalogue, bc7223 110-119),
and `too_little_overlap` legs now ship their pairs so the table test recomputes the gate, with
the 5-pair minimum read from one helper.

| P2 round | findings | fixed | inside previous fix? |
|---|---|---|---|
| 1 | 1 bug, 3 fragile | 4 | — |
| 2 | 1 fragile | 1 | yes (same class as R1 #3) |
| 3 | 2 bugs | 2 | yes (inside the R2 gate) |
| 4 | 0 bugs, 2 fragile; enumeration | 2 | no |

## Campaign result (2026-10-02, `data-raw/georef_calibrate-film_rotations.R`)

Every figure below is read from the shipped CSVs (`inst/extdata/film_rotations*.csv`).

- Population: **6,716** film rolls in the cache snapshot (2026-09-18); **6,575** eligible (≥ 2
  qualifying legs ≥ 90° apart, from the cache alone); 27 series × 5-year strata.
- **116** rolls examined in draw order, **79** with thumbnails on at least half their frames.
- **56 shipped** — 44 at **90**, 10 at **270**, 2 at **0**. **No roll's decisive legs
  disagreed** (`legs_disagree` = 0). 250 of 406 scored legs were decisive; decisive margins
  run 0.055-0.697, median 0.247. Shipped rolls carry 2-6 decisive legs (9 / 8 / 15 / 13 / 11).
- Measured and not shipped (60): `legs_unscorable` 26, `thumbnails_unavailable` 13,
  `no_decisive_leg` 10, `one_decisive_leg` 8, `single_direction` 3. The 26 unscorable are
  infrared film (`Film - Colour IR` / `Film - BW IR`), which `fly_footprint()` sizes as an
  unknown format — every bci and bcf roll drawn, and three bcc rolls of 1965-69. Filed as
  fly#89.
- Unmeasured (6,600): `not_sampled` 6,459, `single_direction` 63, `one_qualifying_leg` 62,
  `no_qualifying_leg` 16.
- **Within a roll, missions agree.** 23 measured rolls have decisive legs on more
  than one segment (scale / flying height); in none does the rotation differ across them.

**The pattern, and why it is not a rule.**

| | 0 | 90 | 270 |
|---|---|---|---|
| focal 153 | 2 | 11 | 0 |
| focal 305 | 0 | 33 | 10 |
| before 1974 | 2 | 0 | 9 |
| 1974 on | 0 | 44 | 1 |

0 is bc5270 and bc5282 (1967-68, 153 mm); 270 is every 305 mm roll measured from 1964 to 1973;
90 is every roll measured from 1974 to 2010 — **except bcc00116 (2000, 305 mm), which is 270**,
on three decisive legs (265°, 85°, 85°). One exception in 45 post-1973 rolls is exactly what a
per-era default would get silently wrong, and it is a quarter turn wrong twice over. The table
stays keyed on the roll, by the gate decision and now by measurement.

**Flight-relative, re-established.** #26's falsification of a fixed-geographic mapping rested on
two legs that do not exist as recorded (amendment 3). The campaign settles it directly: every
shipped roll carries two decisive legs ≥ 90° apart that agree, and many are reverse pairs
(bc4234 261° / 82°, bc4261 91° / 271°, bc7049 357° / 177°) where a geographic mapping would
predict a 180° shift.

## Code-check, Phases 3-4

| round | findings | fixed | inside previous fix? |
|---|---|---|---|
| 1 | 1 bug (refusal quoted the measured rows' date as the snapshot), 4 fragile (single_direction wording; zero backward step; NA coordinates abort `fly_bearing()`; 479 frames turned by a short off-line backward step) | 5 | — |
| 2 | 4 published claims (#87 figures were the issue's, not the shipped rule's; bcc00116 called the only exception; "two #26 legs do not exist"; "four rounds"), 1 fragile (zero-length step judged in the continuation check) | 5 | yes (inside round-1 fix 5) |

Ended by enumeration of the mechanism round 2 named — a heading taken from a zero-length step.
Every bearing computation in the package (`grep atan2 R/`): `fly_bearing.R` forward bearing
(zero → NA), backward bearing (zero → NA), continuation `azimuth(i - 1, i)` (reached only when
`back > 0`), `azimuth(i - 2, i - 1)` (guarded `step > 0`); `fly_rotation_calibrate.R` step
bearings (used only on `adj` steps, which require `s > 0`) and the leg median (over `adj` steps
only). Six sites, all guarded.

fly#87 figures derived by running HEAD's and the branch's `fly_bearing()` over all 1,670,471
cached frames: 48,139 change bearing (2.88%), 5,390 digital; 42,001 by more than 10 degrees,
4,225 digital; 10 become NA, none newly finite.
