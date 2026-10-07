# Plan review (Plan agent, read-only; findings returned as reply text and written here by the parent)

Arrived after Phase 3 had run. Summary of its findings; responses are in findings.md, "Plan review, answered".

- **B1** S is fixed by (median p_nominal, R): p_agl = 1 - (1 - p_nom)/R on a key, so median p_agl follows exactly.
  The population is in band above sea level, |log R| <= log 1.6, which is the floor below which spacing cannot
  separate readings (#60). So under a #72-shaped rule "nothing tables" is close to certain by construction;
  pre-register the expected null, or reshape the rule as #71's (logbook decides, spacing a sanity check).
  R ~ 1 keys (`bc7718`, `bcc267`, `bc81075`, `bc5715`) would only relabel frames if tabled.
- **B2** Shipping the catalogued height as above ground contradicts #60 ("the logbook's height, converted");
  the minimum change is height_m = logbook MSL with a non-1 factor, which the existing `tab_factor != 1`
  branch already handles for r <= 0 frames.
- **B3** Group-1 keys already carry terrain-tail excluded rows; a new tail collides with the key-uniqueness
  stopifnot and three test invariants.
- **G1** x2 confound for the `ground_plus` witness on r <= 0 frames (H + ground ~ 2H); tolerance should use the
  planner's datum, not census elev (selected for high ground). Alternatives: back-computed scale x focal,
  another column, misplaced centroid, wrong DEM.
- **G2** `catalogue` on r <= 0 frames is not a clean witness against: an MSL figure below the ground.
- **G3** Which frames enter S; and whether adding frames can flip a shipped A2(a) verdict.
- **G4** In-band frames on a tabled key would be sized from flying_height - elev.
- **G5** `height_fixture()` has no `film_roll`; use `roll_fixture()`.
- **G6** What breaks in `fly_footprint()` if the above-ground semantics were built.
- **G7** The window cannot come from `fns_from()`; recompute and assert 0.557-0.780.
- **G8** MSL spacing on r <= 0 frames is degenerate (side <= 0).
- **O1** The S-first gate needs an A2-style proof if the final rule judges spacing at H_log - elev.
- **O2** "Already known" is incomplete: A2's per-key nominal outcome, and #93's run_rolls.log printed p_nominal,
  log_ft, p_corrected for `bc77026`, `bc77072`, `bc77087`; round 2 said those pages write the catalogued heights.
- **A1-A3** Census vs package ground measure; constant-MSL strips; centroids placed correctly.
- **Phase 2** No expected-cache-key guard; RNG order; population CSV must not gain a row; the 374 are in band
  above sea level only.
- **S1-S2, AC1-AC4** Report group-2 S outside the tabling population; no route for an above-ground header;
  pin 16 roll-heights; keep undecided / refuted / relabel-only distinct; name the restore-the-bug mutation;
  ledger any moved terrain row.
