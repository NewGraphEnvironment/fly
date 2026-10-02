# Plan review (Plan agent, 2026-10-02) — summary as received

Blockers
- B1 #26's legs 108:118 (not a leg: 108-114 fly 153, 116-117 absent) and 152:162 (flies 251-259,
  not 62) do not exist as recorded; control "reproduce 0,90,90,90" fails by construction.
- B2 cardinal-leg exclusion leaves ~5,000 of 6,716 rolls `no_qualifying_leg`; premise asserted
  not measured; digital DMC control leg flies 271 and decided cleanly.
- B3 30 deg separation does not test flight-relative vs geographic: under geographic truth two
  legs agree with probability 1 - db/90; need db >= 90 (reverse legs fully informative).
Gaps
- G1 fly_bearing() gives the last frame of each line the turn azimuth; table would turn a refusal
  into a silently wrong GeoTIFF for ~5-8% of film frames.
- G2 thumbnail URLs not constructible (4 naming conventions); re-pull; test via centroid_shapes();
  bcdata not in DESCRIPTION but used in example.
- G3 605 of ~1,484 eligible rolls carry >1 scale (missions); record a segment per leg; tabulate
  within-roll across-segment agreement.
- G4 all-not_rotated / all-refused legs mapped to no_decisive_leg, which is false.
- G5 a digital frame sized onto a square footprint reaches the film branch; warning must say
  "not film" rather than "added after snapshot".
- G6 overlap scoring cannot see a reflection about the flight line.
Ordering O1 controls before pre-registration; O2 update task_plan to the in-flight rule.
Assumptions A1 #26 margins came from an unmasked srcnodata=0 pipeline; controls can only expect
winners. A2 sign test right. A3 interpolated centroids; 29 zero-length steps; 1,450 gaps.
A4 several strata < 4 eligible.
Scope S1 use rlang::check_installed. S2 trim excluded CSV; ship a population CSV for counts.
Acceptance: test-fly_georef.R:190 network test breaks; override tests using 0 go vacuous (use
90); unmeasured fixture by relabelling; README line 27.
