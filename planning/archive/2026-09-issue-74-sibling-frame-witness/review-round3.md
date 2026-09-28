# Code-check review, round 3: fly#74 Stage 5b logic (adversarial)

## Findings

- **[severity: bug]** `data-raw/height_calibrate-lower_tail_rolls.R`, `relation()` (the `exact()` tolerance and
  the `d10`/`d100` tolerances), plus rule 3 in the Stage 5b comment. **Rule 3 assumes the catalogue rounds to
  whole metres. It does not always round. It sometimes truncates, and that makes the rule refuse a sibling
  that every other witness supports.**

  The tolerance `|h - k s| <= 0.5 (k + 1)` is derived from "whole-metre rounding on both sides". But the
  catalogue stores 2,000 ft (609.6 m) as **609**, and 2,400 ft (731.5 m) as 731. Both are truncations, and
  both sit in the shipped `flying_height_rolls.csv` (bc5449, bc7584, bc5536). Across the cache, for
  round-50-ft heights where floor and round differ, 50,579 frames sit at the floored value and 363,865 at
  the rounded one. Truncation is a minority convention, but it is real. Under truncation the error on
  each height is in (-1, +0.5], not ±0.5.

  The wrong refusal happens in the real data. `lower bc7675 609 (305 mm, 1:16000)` has **84 frames**, and
  its neighbour frame 214 reads **6,096 m = 20,000 ft exactly**. `6096 - 10 x 609 = 6`, which is 0.5 m past
  the 5.5 limit, so the row is excluded with `sibling_reason = "no adjacent frame in an exact named
  relation"`. Every other witness agrees with the sibling:
  - The logbook names factor 10 on all 34 frames it reads (0.40 coverage, so the logbook rule refused
    it only on coverage).
  - Spacing under 6,096 m gives overlap 0.616, and `r_corrected` = 1.00.
  - It is the same 609 ↔ 20,000 ft pairing the logbook settles for bc7584.

  I re-ran `sibling()` over all 549 roll-heights with a tolerance that admits truncation on both sides
  (`|h - k s| <= k + 1`; `d10` <= 11, `d100` <= 101). **bc7675 is the only outcome that changes**, and it
  changes to ACCEPT. Both controls still hold: bc5596 frame 212 at 2,438 m is still 30.6 m off
  x10.764, far outside 11.8. So the rule as written drops 84 frames that its own design intends to settle,
  because a premise stated in the comment is false for this catalogue.

  The rule was fixed before the run, so changing it now is a methodology decision for the author. The
  evidence for the rounding convention is independent of the Stage 5b outcome: it comes from the shipped
  logbook rows. At minimum, the comment's "within the whole-metre rounding on both sides" is factually
  wrong.

## Checked and found sound (with evidence)

- **Duplicated (roll, frame) keys:** there are 0 in the full `frames` cache, so the ±1 adjacency cannot
  pair a frame with itself or reach a frame that Stage 1 excluded from spacing.
- **`own` from the catalogue key vs `d` from the sampled set:** reach = measured (1,354 = 1,354), so every
  key frame is sampled and `own` and `d` hold the same frames.
- **Non-contiguous runs:** all four accepted roll-heights are single contiguous runs (bc87070 169-202,
  bcc822 120-130, bc5596 204-211, bcb98013 52). No accepted row relies on one run's neighbour while
  another run's neighbour names something else.
- **Neighbour on a disputed or tabled roll-height:** rule 2's band gate removes these. Of the four accepted
  rows, three have exactly one naming neighbour and one non-naming in-band neighbour (bc87070 at
  168 = 4,054, bcc822 at 131 = 6,858, bc5596 at 212 = 2,438). That is rule 4's "new leg" clause working as
  designed. None of those non-naming neighbours comes near a named relation.
- **Digit relation:** the string test cannot produce a leading zero. `digit` and `x10`/`d10` coincide only
  near h ≈ 1111·10^n / 9-type values, and then the row is refused because it names more than one
  relation. `rel_factor("digit")` can never equal 0.1, 10 or 100 exactly, so the `case_when` cause order
  is safe.
- **Veto (`log_factor`):** it fires on the logbook's modal named factor even when coverage is under half,
  which matches rule 5 as written. In the real data no excluded row reaches the veto stage. Every
  `sibling_reason` is one of the three early exits: 10 have no adjacent frame at another height, 499
  have no in-band neighbour, and 8 have no exact relation.
- **Fields on moved rows:** `factor`, `height_m`, `log_ft` (NA), `n_agree` (NA), `p_corrected`,
  `r_corrected`, `reason` (NA) and `witness` are all overwritten. The remaining stale fields (`n_logbook`,
  `covered`, `n_base`, `focal_logbook`) are not written to either CSV. `cause` reads the overwritten
  `factor`. I reproduced the generator from the staged index and got output byte-identical to the staged
  CSVs.

## Observations (not defects today)

- `"adjacent frames name different relations"` also covers two cases that are not different relations:
  one neighbour naming two relations, and two naming neighbours at different heights naming the *same*
  relation (the `d10` tolerance admits sibling heights 3958 and 3962 for h = 396). Neither case occurs in
  the current data. The label would be wrong only if one did.
