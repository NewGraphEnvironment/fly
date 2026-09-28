# Task: Half the r≈2 mass is a wrong scale, not a mislabelled lens, and the fallback draws it at half width (#72)

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

Decisions taken at the gate: `tail = "near_upper"` (third value; `upper` stays #54's slipped
frames); scope = every out-of-band roll-height in the sweep's 600-frame `near_upper` **sample**
(all lenses), with unsampled roll-heights stated as a bound.

## Phase 1: Fetch and transcribe the near_upper logbooks
- [ ] Make `fetch_logbooks()` fetch rolls missing from the cache (not only when the dir is absent), and call it for the out-of-band near_upper rolls
- [ ] Record which of the 44 rolls have no `flight_log_url` / failed fetch
- [ ] Transcribe every fetched page into `data-raw/flying_height_logbooks.csv`, same schema, **blind**: readers get only the image paths, never catalogue height/scale/lens (2–3 unnamed general-purpose subagents, each writing rows to a scratch file; merged and spot-checked by me)
- [ ] Re-read the fly#60 control rolls (`bcc228`, `bc7349`) in the same batch as a reader check; note `scale_as_written` where legible (reported, not gated)

## Phase 2: Generator — settle near_upper per roll-height
- [ ] In `height_calibrate-lower_tail_rolls.R`, define the set: `near_upper` frames with r > band[2]; run `settle(near, named = 1, tail = "near_upper")`, rule fixed before running (fly#60's: ≥50% covered, ≥90% agreeing, no legible focal conflict, spacing in window)
- [ ] Controls before the verdict: spacing on the issue's split (lens rolls fit nominal, scale rolls fit reported), plus the existing controls unchanged
- [ ] Sibling witness not applied to near_upper (no height relation); `sibling_reason` states why; excluded reason suffixed "nominal scale still applies"
- [ ] Extend `cause`, the census `stopifnot`s and the key-uniqueness check to three tails; regenerate both CSVs; confirm lower/upper rows are byte-identical to before (diff)
- [ ] Record printed numbers (frames/roll-heights settled, lens vs scale split, catalogue reach) in findings.md

## Phase 3: Tests
- [ ] Widen tail setequal to three values; census reconciliation loop over `near_upper` set; factor-1 row ⇒ r beyond the band on its own tail's side
- [ ] A near_upper tabled frame (real table row, r ≈ 2) is `corrected_roll_table`, sized from the reported height at ~2× the nominal width; the same frame off the table stays `implausible`/nominal — restore-the-bug check that the test reddens without the row
- [ ] An excluded near_upper roll-height naming 305 mm in its logbook stays nominal

## Phase 4: Docs
- [ ] Rewrite the r≈2 claims: `fly_height_ratio_band()` comment (R/fly_footprint.R ~223), roll-table comment (~254), roxygen (~700–737 incl. frame counts), `inst/notes/terrain-correction.md` (~233 and roll-table section)
- [ ] NEWS entry derived from the regenerated tables; CLAUDE.md Key Decisions entry; `devtools::document()`

## Validation

- [ ] Tests pass
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
