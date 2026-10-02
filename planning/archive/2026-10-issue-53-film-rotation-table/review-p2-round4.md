# Code-check round 4 (P2): `R/fly_rotation_calibrate.R`

Reviewer: subagent, 2026-10-02. Scope: staged diff `diff53_p2r4.patch` plus the untracked
`data-raw/georef_calibrate-film_rotations.R` and `tests/testthat/test-fly_film_rotations.R`.
Probes ran on a copy of the R file and on a copy of the repo (`scratchpad/frc_r4.R`,
`scratchpad/flyr4`). The campaign cache was read and not written. Nothing under the repo was
edited apart from this file. `test-fly_rotation_calibrate.R` passes in the copy (113 expectations).

## The R3 fix itself

Correct. `refused` now travels from `fly_rotation_score_leg()` (L406, L434, L450, L452) to the
verdict (L329) and to the gate (L448). The verdict's rival set (L267) and the gate's competitor
set (L286) are both `!refused`, so a non-refused all-NA column blocks decisiveness: test L119-124
covers this. The data-raw callers pass `res$refused` (L183, L201), and the test decodes it from
the CSV (L49-52). The verdict's default `refused = FALSE` errs in the safe direction: if a caller
omits `refused`, a refused column counts as an untested rival and blocks decisiveness, so the
leg can never be wrongly shipped.

### Is `fly_rotation_could_decide()` exactly the verdict's precondition?

**Yes, quantified over outcomes. No, for the outcome actually measured, and that does not matter.**

- **Existential equivalence holds.**
  - **Decisive implies TRUE.** If the verdict is decisive, its winner `w` is non-refused,
    because L262 sets refused means to NA and `which.max` skips them. L275 then requires `w`
    to share at least 5 finite pairs with every non-refused rival. That is exactly the
    gate's condition for that `w`.
  - **TRUE implies a decisive outcome exists.** Take the gate's `w`, set its finite pairs to
    1 and every other finite score to -1. Then `w` has the top mean and wins every shared
    pair, and 5 of 5 gives p = 1/32 <= 0.05.
  - **Brute force agrees.** Over 19,993 random NA/refused patterns (n = 5-10 pairs), the gate
    disagreed with "some outcome makes the verdict decisive" **0** times.
- **For the realised scores, TRUE can coexist with an undecidable winner.** Example (test it
  with `scratchpad/probe_r4.R`):
  - column 0 is finite on pairs 1-10, column 90 on pairs 1-5 and column 180 on pairs 6-10.
  - The gate's `w` is 0, which shares 5 pairs with each of the others.
  - If 90 has the top mean, it wins and shares 0 pairs with 180, so the leg is not decisive.
  - In the random sweep, 832 scored draws ended up with a winner like this.
- **Why it does not matter:**
  - **Direction.** It can only report a leg as `scored` and not decisive. That makes the roll
    `no_decisive_leg` instead of `legs_unscorable`; both are excluded, and neither ships.
  - **The rule.** It picks the winner by mean and says that "under 5 pairs nothing is
    decisive". So a leg whose testable candidate lost on the mean is a non-decision the rule
    measured, not missing evidence.
  - **Reach.** It needs NA patterns that differ by rotation and are nearly disjoint. Only
    pairs close to the 500-cell floor produce those, where the collar mask lands differently
    per rotation.

## Findings

- **[fragile] R/fly_rotation_calibrate.R:209**: `atan2(0, 0)` is 0, so a run of coincident
  centroids becomes a leg with **bearing 0** and spacing 0. A missing heading is encoded as
  north. This is the same defect the diff fixes in `fly_bearing()` (L126-133, fly#87), but
  this second caller of the idea was left unfixed.
  - **Measured on `cache_legs.rds`:** 21 zero-spacing runs, **1 qualifying**: `bc7223`
    110-119, 10 frames, bearing 0.
  - **No outcome changes today**, for three reasons:
    - `bc7223` is eligible on its real legs alone (317 and 141 degrees).
    - Under the fixed `fly_bearing()` these frames get bearing NA, so the leg is
      `not_rotated` and can never be decisive.
    - Nothing else in the cache is affected.
  - **The live path is Stage 1 eligibility.** At `data-raw/...:113`, a phantom bearing-0 leg
    can make a roll that is `single_direction` (or has one qualifying leg) look eligible, and
    it inflates `legs_qualifying` in the ledger.
  - **Remedy:** treat a step with `s == 0` as non-continuing and non-starting, e.g.
    `adj <- diff(r$f) == 1 & s > 0`.
- **[fragile] tests/testthat/test-fly_film_rotations.R:40-61 with R/fly_rotation_calibrate.R:449, 352**:
  the `scored` / `too_little_overlap` split is the gate that rounds 2-4 have been about. It is
  **trusted, not recomputed**, although the file header says every verdict and state is
  recomputed from shipped pair scores.
  - **What ships:** a `too_little_overlap` leg returns `scores = NULL` (L449), so
    `fly_rotation_pair_rows()` ships no pairs for it (L352). The test never asserts
    `fly_rotation_could_decide()` for any leg.
  - **This gate decides shipping.** Wrongly sending a leg to `too_little_overlap` can remove
    a decisive dissenting leg, which turns `legs_disagree` into `shipped`.
  - **The 5 is written twice.** The minimum shared-pairs count is a literal in both L275 and
    L290, despite L283's "stated once". So the exactness verified above is two literals that
    happen to agree, and nothing pins them together.
  - **Remedy:**
    - Ship pairs for `too_little_overlap` legs too (return `scores` there).
    - In the test, assert `could_decide == (status == "scored")` for every leg that carries
      pairs.
    - Or take the 5 from one helper.

No bug found. Both items are latent today: the first was measured on the cache, and the second
because the gate is currently exact.

## Enumeration: every absent-vs-real encoding

### `R/fly_rotation_calibrate.R`

| line | value | can mean | still confusable? |
|---|---|---|---|
| 101-103 | empty footprint (`drawn` FALSE) | unknown format vs a digital frame | No. Only drawn non-square frames count as digital. An undrawn film frame passes and its leg becomes `not_rotated` (L399). |
| 115 | `frames` NA | non-numeric frame number | No. Excluded from legs (L196) and from `which()` (L126, L130). |
| 116/119 | `rolls_in` NA | no roll | No. Dropped by `na.omit` and `which()`. |
| 121-123 | zero-row `rl`/`q` | no leg | No. Template (L143), then `no_qualifying_leg`. `legs_found == legs_qualifying` always now that cardinal legs qualify. |
| 135 | `not_scored`, `scores` NULL, no `refused` | not tried (over `max_legs`) | No. Its own status, which goes to `legs_unscorable`. |
| 192-197, 239 | typed empty legs | no finite input / no adjacent step | No. |
| **209** | **bearing 0** | **a north heading vs a zero-length step (`atan2(0,0)`)** | **Yes. Finding 1.** |
| 219-221 | `med` 0 | coincident run | Yes, via the same zero-step case: a zero run only continues with zero steps. Finding 1. |
| 258-260 | `refused` default / NULL | not supplied | Safe direction: all-NA columns compete and block. |
| 261-262 | `means` NA | refused vs no finite pair | No longer read as rivalry. Rivals come from `refused` (L267), margin from finite means (L268). |
| 265 | `rotation` NA, `decisive` FALSE | no finite column | Only reachable outside `scored`, because the gate requires 2 or more finite competitors. |
| 270 | `margin` NA | no finite rival | Unreachable for `scored` legs: the gate gives every competitor at least 5 finite pairs. So a shipped `margins` field never carries `"NA"` (`data-raw` L288). |
| 272-278 | `decisive` FALSE | tested and lost vs untestable (fewer than 5 shared pairs) | By design: the rule says that under 5 pairs nothing is decisive. The leg-level distinction is the gate's job (see above). |
| 285-293 | gate FALSE | fewer than 2 competitors vs no well-connected column | Exact existentially (0 of 19,993). Realised-winner gap does not matter (see above). |
| 301 / 340-341 | `refused` `""` vs NA | none refused vs not recorded | In memory, no. In the CSV, both are written `""` (na = ""). A `refused`-status leg carries NULL, hence NA, hence `""`, so it **reads as "none refused"**. The test decodes `refused` for `scored` legs only, and those always carry the vector (L452), so it is unambiguous there. A reader of the shipped legs CSV is misled for `refused`-status rows. Not a bug: no consumer. |
| 317-323 | segment `"NA / NA"` | missing column vs all-NA column | Both mean absent. Recorded only, unused by the rule. |
| 328-333 | non-scored row: NA rotation, FALSE decisive | no verdict | No. The status disambiguates, and `roll_state` filters on `status == "scored"` (L368). |
| 346 | `warnings` 0 | none vs not counted | Informational only. |
| 352 | zero-row pairs | not scored vs `too_little_overlap` | Pairs are dropped for both. Finding 2: the gate cannot be recomputed. |
| 367-381 | states | | Each branch reads `status` and `decisive` only. No NA reaches them, because `decisive` is always TRUE or FALSE. |
| 399 | `not_rotated` | empty footprint vs NA bearing (incl. fly#87's zero-step NA) | Both are absences, one status. Fine. |
| 403 | `thumbnails_unavailable` | `success` FALSE | `fly_fetch()` never yields NA `success` (L86, L100, L106-111), so `!all()` cannot hit `if (NA)`. |
| 417-429 | `"refused"` | stretch guard vs **non-finite anisotropy** (`fly_georef.R:460`, `!is.finite(aniso)` emits the same "would stretch it by" text) | A degenerate GCP set reads as a refusal. For a square footprint this is the same at every rotation, so all 4 are refused and the status is `refused`, never `scored`. Not reachable to a verdict. |
| 429-431 | `"failed"` | error, or FALSE without stretch text | No. Becomes `warp_failed` (R1 fix holds). |
| 433-436 | `refused[k]` TRUE, column left NA | refused | Now explicit. |
| 441-443 | `refused` status, **no `refused` vector** | all refused | Status disambiguates. Its CSV row reads `""` (see L340). |
| 448-451 | `too_little_overlap` | not decidable | Exact (see above). 3-of-4 refused would misname a refusal as overlap; this is unreachable on film (square footprint, so all or none). |
| 476 / 481 / 482 | pair NA | no intersection / under 500 cells / zero-variance `cor` | All are absences, and every one is treated as "no evidence" by both the gate and the verdict. |

### `tests/testthat/test-fly_film_rotations.R`

| line | decode | confusable? |
|---|---|---|
| 49-51 | `refused` from CSV: all-empty column → `read.csv` gives **logical NA** → none refused; mixed → character with `""` → none refused; `"0;180"` → parsed | Correct for every `scored` row. **One trap:** if every non-empty value in the column is a single rotation (`"90"`), `read.csv` types it **integer**, and `strsplit()` errors with "non-character argument" (probed). It fails loudly and cannot happen on film (refusal is all-or-none on a square footprint). `colClasses = c(refused = "character")` would remove it. |
| 52 | `as.matrix(p)`: a score column that is all-NA file-wide comes in as logical; a mix of logical and numeric gives a numeric matrix | Fine. |
| 54-56 | `rotation` / `margin` NA written as `""` | Unreachable for `scored` legs (see L265, L270). |
| 44-60 | only `scored` legs recomputed | Finding 2: the gate itself is not checked. |
| 70 | `roll_state` from CSV legs | `decisive` is always TRUE/FALSE; status is text. Fine. |

### `data-raw/georef_calibrate-film_rotations.R`

| line | encoding | confusable? |
|---|---|---|
| 113, 117-120 | eligibility from cache bearings | Finding 1 (phantom bearing 0). |
| 115 | `found_by[r]` NA → 0 | Correct. |
| 183, 201 | verdict with `res$refused` | Correct. For a non-`scored` control, L183 errors in `colMeans(NULL)`. That stops the run loudly, which is the intended outcome for a failed control, though with an opaque message. |
| 269, 274 | zero-row legs/pairs → NULL in `bind_rows` | Fine. A roll with no legs is recomputed as `no_qualifying_leg` from zero CSV rows (test L69-70). |
| 288 | `sprintf("%.3f", margin)` | Margins on decisive legs are always finite. |
| 306-309 | `na = ""` on all CSVs | `refused`: NA and `""` collapse (table above), harmless for `scored`. Other NA fields (`rotation`, `margin`) occur on non-`scored` rows only, and nothing recomputes from those. |
