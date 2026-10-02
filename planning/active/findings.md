# Findings — Infrared film (Film - BW IR, Film - Colour IR) is sized as an unknown format (#89)

## Issue context

## Problem

`fly_film_media()` (`R/fly_footprint.R`) lists `"Film - BW"` and `"Film - Colour"` only, so the catalogue's infrared film — **`Film - BW IR` (771 frames) and `Film - Colour IR` (3,054 frames)**, counted over the cached catalogue in `data-raw/.cache/centroids` — is treated as an unknown recording format: `footprint_basis = "unknown_format"`, an empty geometry, and no coverage, selection or georeferencing.

Found in fly#53's film rotation campaign, where every drawn roll of the `bci` and `bcf` series, and three `bcc` rolls from 1965-69, came back `legs_unscorable`: e.g. `bcc23`, `bcc7`, `bcc8` and `bcf07060` are all `Film - Colour IR` at focal 305, and 73/73, 87/87, 87/87 and 247/247 of their footprints are empty.

## The question

#30 refuses an unknown format rather than guessing, and that is right until someone establishes the format. IR aerial film was flown in the same mapping cameras on the same 9-inch rolls as panchromatic and colour, so it is probably `negative_size` — but that is reasoning, and #30's whole point is that a 9-inch negative applied to a different format still draws a plausible rectangle. Establish it before adding the media values:

- Thumbnail aspect and the collar geometry `fly_mask()` measures (#23) against the BW/colour population.
- Adjacent-frame spacing against designed overlap at the stated scale and focal, as #60 used for heights.

Once sized, the IR rolls in `inst/extdata/film_rotations_excluded.csv` (state `legs_unscorable`, or unmeasured) can be calibrated with `fly_rotation_calibrate()`.


## Pre-registered rule (2026-10-02, before any IR measurement)

**What had been read when this was written.** Counts only: IR frames and rolls per media value,
scale and focal per roll (centroid cache), and — from the #53 roll cache — the fraction of each
pulled IR roll's frames carrying a `thumbnail_image_url`, and how many `flight_log_url` pages each
carries. No IR air base, overlap, thumbnail pixel or logbook page has been read. Any later change
to this section is an amendment, dated, with the reason, and listed under "Amendments".

**Population.** Every centroid-cache frame whose `media` is `Film - BW IR` or `Film - Colour IR`:
3,825 frames on 32 rolls (771 / 7 rolls, 3,054 / 25 rolls). Each roll carries one media value.

**The question.** Is an IR frame's recording format the 9-inch (23 cm) negative
`fly_footprint()` applies to `Film - BW` and `Film - Colour`? The live alternatives are the
other aerial formats IR film was sold in: 70 mm (a ~2.2-inch frame) and 5-inch rolls. A 9.5-inch
frame is not a live alternative — no mapping camera exposes one — and spacing cannot separate it.

### W1 — adjacent-frame spacing (primary; every roll)

- **Instrument.** The one fly#60 built (`data-raw/height_calibrate-lower_tail_rolls.R`):
  air base = distance to the frame numbered one away on the same roll, the smaller of the two
  neighbours, duplicated (roll, frame) keys excluded, a zero base set NA. Implied forward
  overlap `p = 1 - base / side`, `side = format x ground scale`.
- **Two readings per frame**, each at 9 inches:
  - `p_nominal`: side from catalogued `scale`.
  - `p_reported`: side from `(flying_height - elev) / focal`, `elev` the MRDEM-30 mean under the
    nominal 9-inch square, as `height_calibrate-flying_height_slip.R` samples it. Counted only
    on frames whose `r = (flying_height - elev) / (scale x focal)` is inside
    `fly_height_ratio_band()`, so a slipped height (#54) or a wrong scale (#72) never decides it.
- **Window.** The central 95% (2.5-97.5%) of per-frame `p_reported` over the in-band `random`
  frames of `inst/extdata/flying_height_sweep.csv` — fly#60's window, recomputed, not chosen.
- **Per roll and reading**, the reading is *measurable* when at least 5 frames give a finite `p`.
  The roll **passes** when the median of at least one measurable reading lies in the window. It
  **contradicts** when it has a measurable reading and no measurable reading's median lies in
  the window. With no measurable reading it is `unmeasurable`, recorded, and neither.
- **Discrimination, reported per roll.** The same medians recomputed at 5 inches and at 70 mm
  (56 mm frame). A pass counts as evidence *against* those formats only where their medians fall
  outside the window; the count of such rolls is reported.
- **Controls, before any IR roll is read.** (a) In-band random frames: median `p_reported` within
  0.1 of 0.60 (fly#60's control). (b) The same frames sized at 5 inches must have a median outside
  the window. Either failing stops the script.

### W2 — thumbnails (rolls whose frames carry one)

- Fetched with `fly_fetch(type = "thumbnail")`; measured with `fly_mask()` at
  `fly_mask_threshold()`, so the collar fraction is the same quantity as `frac_total` at
  threshold 16 in `inst/extdata/mask_border_sweep.csv`.
- **Reference.** The 254 film frames of that sweep (aspect under 1.5; the 10 at 912 x 1608 are
  digital): largest aspect `max/min` 1.0056; collar fraction 0 to 0.0707.
- **Per roll**, on frames whose mask did not decline: median aspect at most 1.0056 and median
  collar fraction at most 0.0707 passes; either above contradicts. A 70 mm or 5-inch frame scanned
  as a 9-inch thumbnail would show a collar far beyond 0.07 or a non-square image. Declines and
  their reasons are recorded and are not a contradiction by themselves.

### W3 — logbooks (rolls with a `flight_log_url` page)

- Read by hand into `data-raw/infrared_film_logbooks.csv` (an input, never regenerated).
- A page that names a camera: a 23 cm-format mapping camera (Wild RC5/RC5a/RC7/RC8/RC9/RC10/
  RC20/RC30, Zeiss RMK, Fairchild K-17/T-11, Zeiss/Wild with a 23 cm cone) passes; a named
  camera with a different format (any 70 mm or 5-inch camera, e.g. Vinten, Hasselblad, K-22 at
  5 in) contradicts; an unrecognised model is recorded as `unrecognised` and counts neither way.
  A page naming a frame or roll size directly is read the same way. A page naming nothing is
  `not_stated`.

### Decision

- Add `Film - BW IR` and `Film - Colour IR` to `fly_film_media()` if and only if: both W1
  controls pass; every measurable roll passes W1; no roll contradicts W2; no page contradicts W3.
  The decision is per media value: a contradiction on a BW IR roll does not block Colour IR.
- On any contradiction: stop, record it, and escalate to the user. No per-roll format table in
  this issue.

### Reported, not a gate

- The `r` distribution of IR frames against `fly_height_ratio_band()`: how many the #54 check will
  use as reported, repair by the slip factor, or send to nominal once IR counts as film.

### Amendments

(none)

## First full run (2026-10-02, 14:31-14:39 UTC) — the rule fired

`data-raw/.cache/irfilm_run1.log`. Stages 0-4 ran; Stage 5 stopped as designed (no logbook
transcription yet). Nothing written to `inst/extdata`.

- Population as pre-registered: 3,825 frames, 32 rolls, no duplicated (roll, frame) key, every
  frame with terrain under it. 422 thumbnails on 4 rolls (bc5312, bc5367, bcc23, bcf07060); 17
  rolls carry a logbook page.
- **Controls passed.** Window (2,481 in-band random frames) 0.557 to 0.780; (a) median 0.635;
  (b) at 5 in 0.343, outside.
- **W1: 28 pass, 4 contradict** — bcf07060 (p_nominal 0.200 / p_reported 0.224), bci3
  (0.274 / 0.113), bci95063 (0.191 / 0.212), bci96066 (0.274 / 0.273). All four are BELOW the
  window. Two are BW IR and two Colour IR, so under the rule as written both media values are
  blocked. 27 of the 28 passes put 5 in outside the window; all 28 put 70 mm outside.
- **W2: 4 pass**, 0 declined. bcf07060 collar median 0.0486, aspect 1.
- **#54 band on IR frames**: 3,769 reported, 56 outside the band, 0 slip-repairable.

**A look at bcf07060, taken after the verdict, labelled as such.** Frames 010 and 011 are
square 23 cm mapping frames: eight fiducials (corners and side midpoints) and a data strip
`30BCC (IR) 07060 No.010` — a 30 cm cone, matching focal 305. They share little ground, which
fits low forward overlap. A format smaller than 9 inches would push implied overlap lower
still; only a larger one could lift it into the window. So the four contradictions are
evidence about how these rolls were flown or catalogued, not about format — review-1 B1.

**Status:** per the rule, stopped on the media change and escalated to the user. Independent
work (logbook transcription, the rotation stamping fix, pinning the data-raw scripts)
continues meanwhile. Any rule change is an amendment made after these numbers were read.

## Errors Encountered

| Error | Resolution |
|-------|------------|
