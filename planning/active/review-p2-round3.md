# Code-check round 3 (P2) — `R/fly_rotation_calibrate.R`

Reviewer: subagent, 2026-10-02. Scope: staged diff `diff53_p2r3.patch`. Probes ran in a copy
of the repo (`scratchpad/flycopy`); nothing under the repo was edited apart from this file.

## The mechanism

Rounds 1 and 2, and both findings below, share one assumption: **absence of evidence and a
measured outcome travel in the same channel**, so the code downstream cannot tell them apart.

| round | channel | absence read as |
|---|---|---|
| R1 | `georef_one()` returning `FALSE` | a stretch refusal (a warp error) |
| R1 | leg `status` | `"scored"` (a leg never scored) |
| R2 | leg `status` | `"scored"` (a leg whose pairs were all NA) |
| R3a | the L422 gate, *computed from* the NA channel | "could have been decisive" |
| R3b | an all-NA column of `scores` | a stretch refusal (a rotation that warped and has no finite pair) |

Each fix so far added a status at the place the instance surfaced. The R2 gate at L422 is a
**proxy** for the property it names in its own comment ("`scored` means the leg COULD have
been decisive"), and it is computed from the same `NA` that also encodes "refused". That
proxy is where both new instances live.

## Findings

- **[bug] R/fly_rotation_calibrate.R:422** — The R2 gate (`>= 2` rotations each with `>= 5`
  finite pairs) is not the condition `fly_rotation_verdict()` actually needs. The verdict's
  rivals are every column with **any** finite pair (L260), and the sign test needs `>= 5`
  pairs finite under **both** winner and each rival (L265-267). So two shapes pass the gate,
  read `scored`, and can never be decisive whatever the correlations are:
  - (a) a third, non-refused rotation with 1-4 finite pairs. If it wins it has `< 5` pairs
    against everyone; if it loses it is a rival with `< 5` shared pairs. Either way
    `decisive = FALSE`.
  - (b) two rotations with 5 finite pairs each that share fewer than 5.

  Probe (copy of repo): (a) gate `scored`, verdict with a perfect column 0 `decisive = FALSE`;
  (b) gate `scored`, `decisive = FALSE`; two (a)-shaped legs on bearings 45/225 give roll state
  **`no_decisive_leg`** ("legs were scored and none decided") — exactly R2's misstatement,
  surviving inside R2's fix. Reach is narrow: it needs pair NA patterns that differ by
  rotation, which comes from pairs within a few cells of the 500-cell floor where the collar
  mask lands differently per rotation, on scales around 1:3000-1:3500 or on wide-spaced pairs.
  Remedy: test the property, not a count — `scored` iff some column `w` has
  `sum(is.finite(s[, w]) & is.finite(s[, k])) >= 5` for every other competing column `k`
  (and at least one `k`), with "competing" defined exactly as the verdict defines it.

- **[bug] R/fly_rotation_calibrate.R:254-260 with 406-409** — A refused rotation and a
  rotation that warped but has **no** finite pair are the same `NA` column, and the verdict
  drops both from `rivals` (`!is.na(means)`). The pre-registered rule ("against **each** other
  scored rotation ... n = pairs finite under both; under 5 pairs nothing is decisive"; "A
  rotation refused by the stretch guard is not scored") makes only the refused one exempt.
  So a warped rotation with zero usable pairs is exempted where the rule says it blocks, and
  this runs in the **shipping** direction. Probe: columns 0 and 90 full, 180 and 270 all NA
  (not refused) gives `decisive = TRUE`, and two such legs on 45/225 give **`shipped`**; add
  **one** finite pair to 180 and the same leg is `decisive = FALSE`. One more datum withdrawing a
  verdict is the tell that the empty case is misclassified. Reach via overlap alone is very
  narrow (every pair of one rotation must fall under 500 cells while two others keep 5), so
  this is a latent defect rather than an observed one; it is also the input the L422 gate
  cannot see, since refused and empty columns both count 0 there. Remedy: return the refused
  rotations explicitly from `fly_rotation_score_leg()` (e.g. `res$refused`, a logical per
  rotation) and have the verdict's rival set and the L422 decidability test read that, not
  `is.na(means)`.

Both remedies are one change: carry "refused" as its own value so the NA in `scores` means
only "this pair gave no evidence".

## Enumeration (mechanical walk)

### Every return of `fly_rotation_score_leg()`

| line | status | condition | evidence produced | roll-state consequence | true to what was measured? |
|---|---|---|---|---|---|
| 373 | `not_rotated` | an empty footprint, or a non-finite `footprint_bearing` | none | unscorable family | yes (label also covers "no footprint at all", same class of absence) |
| 376 | `thumbnails_unavailable` | any `th$success` FALSE (NA url included, `fly_fetch()` L83) | none | `thumbnails_unavailable` if no leg scored | yes |
| 404 | `warp_failed` | any frame at any rotation `FALSE`/error without the stretch text | none | unscorable | yes. Probed: a truncated thumbnail errors in `nearblack` and lands here, not as a scored frame |
| 415 | `refused` | all 4 rotations refused on some frame | none | unscorable | yes |
| 423 | `too_little_overlap` | `< 2` columns with `>= 5` finite pairs | none | unscorable | yes for the overlap case. With exactly 3 rotations refused it would misname a refusal as overlap; unreachable, since stretch on a square footprint is rotation-invariant (all-or-none) and digital legs refuse in pairs |
| 425 | `scored` | otherwise | `scores` | verdict decides | **not always**: finding 1 (a)/(b) — undecidable legs read as measured non-decisions; finding 2 — an empty, non-refused column grants decisiveness the rule withholds |
| (371/375/411) | — | an error in `fly_footprint()`, `fly_fetch()` or `fly_rotation_pair_r()` is uncaught | — | aborts the whole `fly_rotation_calibrate()` call | not a mis-state; no reachable trigger found (outputs are checked by `georef_one()` before scoring) |

### Every leg `status` reaching `fly_rotation_roll_state()`

The six above plus `not_scored` (L135, a leg past `max_legs`). Only `scored` legs feed `dec`
(L341). Every non-`scored` row carries `decisive = FALSE`, `rotation = NA` (L309-310).

### Every branch of `fly_rotation_roll_state()`

| line | state | reached when | true? |
|---|---|---|---|
| 340 | `no_qualifying_leg` | 0 legs | yes |
| 342 | `legs_disagree` | `> 1` distinct rotation among scored + decisive | yes, given decisive is right (finding 2 can make it fire where the rule says one leg is not decisive) |
| 345 | `shipped` | `>= 2` decisive, all agree, spread `>= 90` | yes, **except** via finding 2 |
| 346 | `single_direction` | `>= 2` decisive, all agree, spread `< 90` | yes, except via finding 2 |
| 348 | `one_decisive_leg` | exactly 1 decisive | yes, except via finding 2 |
| 349 | `no_decisive_leg` | any `scored`, none decisive | **no** when every scored leg is finding-1 shaped: they could never have decided |
| 350 | `thumbnails_unavailable` | no scored leg, `>= 1` leg unscorable for images | yes, as documented ("at least one for want of its images"); untried `not_scored` legs may exist and the doc's wording allows it |
| 354 | `legs_unscorable` | the rest | yes |

### The earlier fixes, checked

- R1 `unlink(o)` (L388): verified by test L365-387; it is also what makes `georef_one()`'s
  `file.exists && size > 0` check honest after a GDAL warn-and-return.
- R1 error not a refusal (L390-404): `stretched` is per frame, set only by the stretch text;
  an error goes to `"failed"`. Correct.
- R1 never-scored legs (L135 to L354): `not_scored` reaches `legs_unscorable`. Correct.
- R1 typed empty result (L153-156): correct.
- R2 `too_little_overlap` (L422): correct for the all-NA and one-NA cases tested
  (test L427-429), but a proxy. See finding 1.
