# Plan review 1 — Plan agent, 2026-10-02 (returned after the first full run)

Delivered as reply text (Plan agents cannot write files); recorded here verbatim in substance.

## Blockers
- **B1.** W1 `contradicts` fires on rolls whose spacing fits *no* candidate format (bcf07060,
  bci95063, bci96066, bci3: median p_nominal at 9 in 0.19-0.27). Smaller formats push implied
  overlap lower, so this is flight design or cataloguing, not format. Proposed: `pass` / 
  `contradicts` (9 in out AND an alternative in) / `fits_no_format` (recorded, neither).
- **B2.** W1's false-contradiction rate on known-9-inch rolls was never measured: applying the
  9-inch nominal reading to 6,664 BW/Colour rolls with >= 10 bases, 5.7% have a median outside
  [0.557, 0.780]; 12.7% of rolls at 1:8000 or larger. P(no false contradiction over 25 rolls)
  ~0.21. Proposed control (c): the same roll-level rule on matched BW/Colour rolls.
- **B3.** A W1 pass does not exclude 5 in or 18 cm. Control (b) tests the easy direction. Taking
  BW/Colour roll medians as true overlap, a 5-inch roll passes at 9 in 27.9% of the time, an
  18 cm roll 96.0%, 70 mm 0%. bcf517 (13 frames, 1:4000) is in the window at both 9 in (0.770)
  and 5 in (~0.59). Proposed: pass only with 5 in and 70 mm out; both in = `ambiguous`; add
  18 cm and say spacing cannot separate it from 23 cm.

## Gaps
- **G1.** `format_size = c("Film - Colour IR" = 9)` sizes IR today with `film_like` FALSE; after
  the change the #54 check applies (bcf517, r0 3.41, moves to nominal). NEWS line. The planned
  "format_size can override IR" test cannot go red; drop it from the prove-red list.
- **G2.** Counts the rotation re-run invalidates: `inst/notes/georeferencing.md:272-300`,
  `R/fly_georef.R:69` roxygen ("56 rolls — 44 at 90, 10 at 270, 2 at 0"), CLAUDE.md era claims.
- **G3.** Stage 4 of the rotation script restamps `film_rotations.csv$measured` as well as
  `retrieved` (`measured_on <- Sys.Date()`); write the date into the cal rds, take legacy dates
  from the shipped CSVs.
- **G4.** Stale comment `height_calibrate-flying_height_slip.R:313-314`; `fly_footprint()`
  details should list the film media; `terrain-correction.md` should say the band was
  calibrated on BW/Colour and now applies to IR.
- **G5.** Plan lists 2 output CSVs; the script writes 5.

## Assumptions
- **A1.** Pre-1990 catalogue spacing is plotted, not measured (fly#82); cite why a roll median
  is admissible.
- **A2.** W2 cannot see square formats; thumbnails are resampled to ~1250 px. Treat a W2 pass
  as non-evidence.
- **A3.** W3's camera list needs a source: RC5a/RC7 may be 18 cm; "Zeiss RMK" is ambiguous
  (RMK 21/18 is 18 cm); check K-22.
- **A4.** No material circularity in W1.
- **A5.** The rotation draw is independent of sizing provided `rolls/` and `cache_legs.rds`
  are untouched; `test-fly_film_rotations.R` pins structure, not counts.

## Ordering / Scope / Acceptance
- O1 stamping fix as its own commit; O2 pinning as a no-op commit before the media change;
  O3 transcribe logbooks before the first full run (too late — see findings); O4 amend now.
- S1 rotation re-run touches five CSVs and several docs for 2-4 rolls; consider a follow-up.
- S2 decide now what happens if one 13-frame roll (bcf517) is ambiguous.
- AC1-AC4: rotation diff confined to IR rows; all 3,825 IR frames non-empty; test recomputes
  controls and the W1 outcomes; prove-red only for sizing, basis and film_like.

**Integrity note from the reviewer:** it computed per-roll median p_nominal at 9 in from the
cache for all 32 IR rolls while reviewing.
