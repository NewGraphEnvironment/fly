## Outcome

`fly_georef()` now georeferences film from a measured per-roll table rather than refusing every
rotated film frame. `fly_rotation_calibrate()` moved fly#26's adjacent-frame overlap measurement
into the package with a pre-registered rule (sign-test-decisive legs; a roll ships on two
agreeing legs ≥ 90° apart), and `data-raw/georef_calibrate-film_rotations.R` ran it over a
stratified sample: 56 rolls ship, and every other film roll in the catalogue snapshot (6,660) is
in a ledger with its state, which the refusal names. The key stays the roll because the values
fall into eras with exceptions (bcc00116, 2000, is 270 where its era is 90). Along the way:
two of #26's four legs turned out not to be as recorded, its cardinal-leg premise was measured
and dropped, a leg-end bearing defect affecting 42,001 catalogue frames was found and fixed
(fly#87), and infrared film was found unsized (fly#89, open). The lesson the code-check rounds
kept teaching: an absent measurement must never share an encoding with a real one — three
rounds in a row found a gap reported as a measurement, each inside the previous fix, until the
scorer returned `refused` explicitly.

## Measurement

- Population 6,716 film rolls (cache of 2026-09-18), 6,575 eligible; 116 examined across 27
  series × 5-year strata, 79 with thumbnails.
- 56 shipped — 44 at 90, 10 at 270, 2 at 0; **0** rolls with disagreeing decisive legs; 23 rolls
  with decisive legs on more than one mission, none disagreeing. 250 of 406 scored legs decisive,
  decisive margins 0.055-0.697 (median 0.247).
- Controls: digital 270 decisive (margin 0.634); #26's existing legs reproduce their winners
  (bc5282 0, bc83062 90 and 90), only one of them decisive under the sign test.
- Cardinal legs on the known rolls: 4 of 7 decisive, all agreeing with the roll — the premise
  that made 75% of rolls unmeasurable was wrong.
- fly#87: 48,139 frames change bearing (2.88%), 42,001 by more than 10° (4,225 digital); the
  continuation check cut wrongly turned frames from 479 to 37.
- Wrong turns kept: the first leg finder was quadratic in rolls and never finished; the first
  fixed draw wasted strata on rolls with no thumbnails (amendment 7); the first campaign run was
  stopped before calibrating a roll when round 3 found the refused-vs-empty conflation.

## Evidence

`findings.md` here (rule, seven dated amendments, controls, campaign result, both code-check
tables); `review-*.md` here; `inst/extdata/film_rotations*.csv`; re-run with
`data-raw/georef_calibrate-film_rotations.R` (cache under `data-raw/.cache/film_rotations/`).

Closed by: PR (this branch), commits d1e1a53, 59eadcd, 7f070c1, 10fef11, 1e64799
