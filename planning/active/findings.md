# Findings — Half the r≈2 mass is a wrong scale (#72)

## Issue context

## Problem

`inst/notes/terrain-correction.md` and the comment on `fly_height_ratio_band()` say the mass of
film frames beyond r ≈ 2 is a 305 mm lens catalogued as 153 mm, so falling back to nominal
scale is "the correct answer there and not merely the cautious one". Measured while settling
fly#60 by the spacing between frames adjacent by frame number, **that is true for about half
of them**.

For the 209 `near_upper` frames beyond r 1.8 catalogued at 153 mm, split per roll-height:

- **90 frames** (mostly 1978–81: bc78051, bc79072, bc80048, bc80122, …) give the designed ~60%
  forward overlap under nominal scale and ~80% under the reported height. 14 fit neither. That is the lens
  reading, and the fallback is right.
- **105 of the 209 frames** give ~60% under the **reported** height and ~20% under nominal.
  91 of those are on 1972–76 bc5xxx rolls (bc5701, bc5509, bc5508, bc5699, bc5702, …); 14 are
  not (bc5138 1965, bc79141, bc79043, bc79039, bc78110), and two 1972–76 rolls do not fit this
  way (bc7407 fits nominal, bc7454 neither). Key it per roll, not by year. The height and lens are right and
  `scale` is the wrong field, recorded at half its true denominator. The fallback draws these
  frames at **half their true width**, and nothing on the row says so.

The instrument was checked on known answers first: in-band random frames read 0.63
[0.59–0.69], and #54's slipped frames read 0.62 after repair against 0.97 before.

This is the upper-side mirror of fly#60's `scale_wrong` class, which fly#60 settles for the
lower tail with logbooks as the second witness.

## What would settle it

The same two instruments fly#60 used, per roll-height: the logbook height (it should equal the
catalogue's where the scale is the wrong field) and spacing. Rows that pass both go into
`flying_height_rolls.csv` with factor 1. That needs the table lookup to reach frames above the
band as well as below it; it already keys on the band edge, not on a direction.

## Evidence

`data-raw/height_calibrate-lower_tail_rolls.R` prints the per-roll split ("near_upper r > 1.8
at 153 mm").


What exploration found that shapes the work:
- `fly_footprint()` needs **no logic change**: `out_of_band` is two-sided and the factor-1 gate is
  `tab_factor == 1 & r_reported > 0` (R/fly_footprint.R ~1166–1193). A near_upper frame is
  `disputed`, not `slipped` (r/10.764 ≈ 0.19), so today it is `implausible` → nominal; tabled, it
  becomes `corrected_roll_table` at the reported height. Only comments/roxygen change.
- **0 of the 44 rolls have logbook rows** in `data-raw/flying_height_logbooks.csv`, and
  `fetch_logbooks()` runs only when the cache dir is absent. Transcription is the heavy phase.
- `settle()` already takes `(set, named, tail)`; spacing, the focal-conflict check (which is
  exactly the lens reading: logbook says 305 → excluded "names a different lens; nominal scale
  already sizes it") and the key-uniqueness guard carry over. Sibling witness (Stage 5b) relations
  are height relations only; near_upper rows skip it with a stated sibling_reason.
- Test `the table holds against the sweep…` hard-codes `tail ∈ {lower, upper}` and "factor-1 row
  ⇒ r < band[1]" — both widen.


## Logbooks for the near_upper rolls (Phase 1, 2026-09-27)

- 53 rolls sit beyond the band in the near_upper sample (252 frames, 58 roll-heights: 224 at
  153 mm on 44 rolls, 25 at 305 mm, 3 at 88 mm). Every one links logbook pages; 144 fetched,
  `bc80048_4.jpg` is a 404 upstream (retried once, same).
- Transcribed blind by three unnamed general-purpose readers given only image paths and
  `scratchpad/transcribe_instructions.md`; one control sheet each. All three controls read
  back as catalogued: bc7349 1-217 at 20.0, bcc228 1-166 at 12.650, bc78065 62-270 at 13.0.
  Spot-checked bc85080_1 and bc5701_5702_1 against the images myself: exact.
- 183 rows appended (2 identical-content duplicates from a sheet cached under two rolls
  dropped), existing 214 rows byte-untouched; 2 interior rows added after code-check round 2,
  so 185 new rows, 142 distinct page files, 54 roll labels. 1984-86 sheets write whole feet ("21000"), not
  thousands; the readers left those blank per instruction and the merge reads them as feet (18
  rows, noted in `note`). "2150" on bc78101_2 and bc5645_3 left uninterpreted, as the fly#60
  rows left "1,000" and "600".
- Instruction change against fly#60's rows: `focal_mm` filled only where a focal length is
  WRITTEN, never inferred from a camera model (fly#60 rows put 153 beside "RC8 502"). On this
  set the lens is the question, so a camera-inferred 153 would have been the answer smuggled in.
- No near_upper page writes a photo scale, so the A2 scale veto never fired (0 read).

## Verdict (Phase 2)

Rule fixed before the run, with the Plan review's A1 folded in: near_upper additionally needs
spacing to REJECT nominal, because the logbook height cannot separate a lens roll from a scale
roll. Controls all passed, and the spacing split still reproduces the issue's 90 / 105 / 14.

- **24 roll-heights, 120 frames tabled at factor 1, `scale_wrong`** — 20 at 153 mm (107 frames,
  mostly 1972-76 bc55xx-bc57xx) and 4 at 305 mm (13 frames: bc7692, bc85079/80/81).
  r_corrected 1.65-2.53; the r ~ 2 mass is 21 of them (114 frames); 3 roll-heights (6 frames,
  bc7692/bc85079/bc85081, 305 mm, r 1.65-1.69) are the 1.6-1.8 group the review flagged (A4) —
  the scale is wrong there too, but not by 2.
- **Catalogue reach: 3,227 frames — an upper bound.** First written as "every one out of band
  whatever the terrain"; wrong way round (code-check round 1): terrain LOWERS r, and 12 of the
  132 sampled frames on the tabled keys (bc85079/80/81) are in band, already `reported` at the
  same height. Sizing unaffected; the claim was not.
- **34 roll-heights (132 frames) excluded, nominal scale still applies:**
  - 21 (82 frames): the logbook writes a 12" lens — the lens reading, now with a witness the
    spacing never saw. The issue's lens rolls bc78051, bc79072, bc80122 are all here.
  - 7 (31 frames): spacing rejects the reported height (bc80048, bc7407, bc7454, bc7716,
    bc79075, bc5667, bc80005). **bc80048's logbook says 6"** and spacing fits neither reading
    (0.79 nominal, 0.89 reported, window top 0.78); left on nominal for want of a witness.
  - 1 (2 frames): bc79043 — logbook writes 305 but spacing fits the reported height. The
    witnesses disagree; excluded with that reason.
  - 3 (8 frames): logbook height not factor 1 (bc81012, bcc544, bc84029); 1 (5 frames): height
    not read (bc7223 — its strip's height changes from 4.1 to 3.2 along it; first shipped as "no
    page" because only the two endpoint frames were transcribed, code-check round 2; an interior
    row with no height was added for it and for bc78009 84-99); 1 (4 frames): no page (bc79029).
- lower/upper rows of both tables are byte-identical to main (diff adds lines only).

## Bound

The near_upper set is a 600-frame SAMPLE of 2 < r_asl <= 3. Not measured here: roll-heights no
sampled frame sits on; 505 upper_tail census frames that are not #54-slipped; 3 random-set frames
beyond the band (one, bc5703 1:6000 at 153 mm, r 1.99, looks like this class).

## Errors Encountered

| Error | Resolution |
|-------|------------|
| Rewriting the logbook CSV with `write.csv()` re-quoted all 214 existing rows | Reverted; append with `write.table(append = TRUE)` and typed logical/integer columns |
