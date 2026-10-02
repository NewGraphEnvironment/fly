# Code-check round 2: fly#53 parts 3-4 (round-1 fixes, documentation)

All probes ran in a scratchpad copy of the tree. Catalogue figures come from running HEAD's
and the working tree's `fly_bearing()` over all 1,670,471 frames in
`data-raw/.cache/centroids/`. Campaign figures come from the shipped CSVs, plus the 116 roll
pulls in `data-raw/.cache/film_rotations/rolls/`.

## Findings

- **[severity: claim]** NEWS.md:10 and CLAUDE.md:183-186. The #87 count and rule are copied
  from the issue body, not from the rule that shipped.
  - **The figures are the issue's, not the rule's.** 48,801 / 5,432 digital / "3.0%" is the
    issue's population of "forward step more than 1.5x the backward step". The shipped rule
    gives different numbers, from HEAD against the working tree over the cache:
    - **48,138** frames change bearing, 5,390 of them digital, plus 10 that become `NA`.
    - **42,000** change by more than 10 degrees, 4,225 of them digital.
    - **6,113** of the changed frames already had a forward bearing within 10 degrees of the
      line, so they were never "rotated onto the turn".
  - **What that makes false.** NEWS says those 48,801 frames were "rotated onto the turn" and
    the 5,432 digital ones "georeferenced onto that azimuth", and then that "Footprints...
    move for those frames only". All of that is false as written.
  - **The two docs disagree with the roxygen.** `R/fly_bearing.R`:42 / `man/fly_bearing.Rd`
    give "about 41,600" for the same fact. That figure is consistent with the 42,000 measured
    here.
  - **Both docs state the rule wrongly.** NEWS has "forward step is more than 1.5x its
    backward one now takes the backward bearing", and CLAUDE.md the same. Both leave out the
    condition round-1 fix (5) added, that the backward step must continue the line. That
    condition is what keeps the 479 / 37 frames right.
  - **The percentage.** 3.0% is 48,801 over frames with both neighbours adjacent (2.95%).
    Over the catalogue it is 2.9%.
  - **Fix.** Derive the count from the shipped rule, use the same figure in all three places,
    and state the continuation condition.

- **[severity: claim]** The era statements present bcc00116 as the single exception. Measured
  rolls in the ledger contradict the eras too, and the published wording does not exclude them.
  - **Where.** NEWS.md:7 ("The exception is bcc00116"), the `R/fly_georef.R` Rotation
    roxygen, `inst/notes/georeferencing.md` "Why the key is the roll" ("90 is every roll
    measured from 1974 to 2010, except bcc00116"), and CLAUDE.md ("270 is every 305 mm roll
    of 1964-73 ... 90 everything from 1974"). CLAUDE.md drops even "measured".
  - **The counter-era rolls.** Three rolls in `film_rotations_excluded.csv` with
    `measured = TRUE` have decisive legs (`film_rotations_legs.csv`) that go against the eras:
    - **bc7397** (1972, 305 mm): one decisive leg at **90**, inside the "270" era.
    - **bc5650** (1975, 153 mm): one decisive leg at **0**, inside the "90 from 1974" era.
    - **bcb00037** (2000, 305 mm): one decisive leg at **270**, a second bcc00116-like case.
  - **Why it is only a claim.** Each roll has one decisive leg, so the rule rightly does not
    ship them, and fly_georef refuses them. Nothing is written wrong.
  - **Why it still matters.** These are rolls that were measured, so "every roll measured ...
    is 90 except bcc00116" is false. "A per-era default would have written it a half turn
    wrong" understates the evidence against an era default, which is what the roll key rests
    on.
  - **Fix.** Say "every shipped roll", or name the three rolls.

- **[severity: claim]** NEWS.md:9 ("Two of its four film legs do not exist in today's
  catalogue") and CLAUDE.md:147-148 ("bc83062 108:118 and 152:162 are not legs in today's
  catalogue"). This is false for 152:162. In the cache, 151->160 fly 251-252 degrees and
  160->163 fly 259, so it is a leg flying 251 rather than the 62 that #26 wrote. The
  campaign's own Stage 2 treats it as an existing leg and requires it to reproduce 90
  (`georef_calibrate-film_rotations.R`, `controls26`, amendment 3: "each #26 leg that exists
  (... bc83062 63-73 and 152-162)"). The note and the corner_mapping correction say it
  correctly ("flies 251, not 62"). Only 108:118 does not exist.

- **[severity: claim]** CLAUDE.md:164-168, "Four code-check rounds each found a gap reported as
  a measurement". The findings table and text say three: rounds 1-3 found this class, and the
  bullet lists three examples. Round 4 found "no defect inside the round-3 fix" (0 bugs, 2
  fragile, neither of this class) and ended the loop by enumeration.

- **[severity: fragile]** R/fly_bearing.R `leg_end()`, the continuation check
  `turn(azimuth(i - 1, i), azimuth(i - 2, i - 1)) <= 10`.
  - **The defect.** When frames i-2 and i-1 share a point, `azimuth(i - 2, i - 1)` is
    `atan2(0, 0)` = 0. That is the zero-step trap this same diff guards in `zero`. The
    backward step is then compared against north. A line-end frame on any non-north line
    fails the check and keeps the turn bearing.
  - **How many.** Exactly 1 such frame in the cache, so the impact is negligible.
  - **Fix.** Treat a zero-length i-2 -> i-1 step like an absent one, `step(i - 2, i - 1) > 0`
    in the `if`, or leave it and note it.

## Round-1 fixes: checked and clean

1. **Snapshot date.** `fly_film_refusal()` now reads the snapshot date from the unmeasured
   rows. In the shipped ledger the 6,600 unmeasured rows are all 2026-09-18 and the 60
   measured rows are all 2026-10-02, so it prints 2026-09-18. The test pins this.
2. **`single_direction_measured`.** It is chosen on `measured`. The 3 measured and 63
   unmeasured `single_direction` rows get different texts.
3. **Zero backward step.** The round-1 probe `(0,0),(700,700),(700,700),(1400,1400),(2100,2100)`
   now gives `45 45 45 45 45`.
4. **Empty POINT.** The middle frame now gives `NaN NaN NaN` with no abort.
5. **Continuation condition.** It is present and pinned by a test. By my criterion (line =
   azimuth i-2 -> i-1), 41,978 frames are corrected, consistent with the comment's 41,581.

## Numbers verified against the CSVs or cache (correct as published)

- **Shipped table.** 56 shipped (44 / 10 / 2), and 6,660 in the ledger. 6,716 rolls and 6,575
  eligible, across 27 strata.
- **The sample.** 116 examined. 79 have thumbnails on at least half their frames, recomputed
  from the roll pulls.
- **Ledger states.** `legs_unscorable` 26 (all IR: 21 Colour IR and 5 BW IR; 7 bcf, 16 bci,
  and bcc7, bcc8, bcc23 of 1967-69), `thumbnails_unavailable` 13, `no_decisive_leg` 10,
  `one_decisive_leg` 8, `single_direction` 3 measured and 63 unmeasured,
  `one_qualifying_leg` 62, `no_qualifying_leg` 16, `not_sampled` 6,459.
- **Focal and era tables.** Both match exactly.
- **bcc00116.** Three decisive legs: 265, 85 and 85.
- **Legs.** 0 rolls have disagreeing decisive legs, and 23 multi-segment rolls all agree. 250
  of 406 scored legs are decisive.
- **Shipped rolls.** Legs per roll split 9 / 8 / 15 / 13 / 11, and `legs` equals the decisive
  count on every row. Every shipped roll's decisive legs span at least 90 degrees (minimum
  122). The reverse pairs on bc4234, bc4261 and bc7049 are as stated.
- **bc83062.** 108-118 is as described (106-115 at 153, no 116 or 117, 119 onward at 73), and
  152-162 is at 251. The cardinal-leg statement holds on the two known-answer rolls.
- **Sign-test thresholds.** "5 of 5 ... 9 of 10" is right at p <= 0.05. "Two times in three at
  30 degrees" is 1 - 30/90.
- **fly_georef precedence.** User value, then table, then refusal. The scalar argument is
  never reached. Unchanged from round 1.
