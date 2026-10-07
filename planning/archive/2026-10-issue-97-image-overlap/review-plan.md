# Plan review (Plan agent, 2026-10-07) — findings as returned, verbatim summary

Arrived after Amendment A1 and while the real control draw was running; folded in as Amendment A2
(findings.md) before the control output was read.

- B1 `nominal_by_elimination` is algebra: G_k < 0 <=> k > ratio_asl <=> p_img > p_agl. It excludes only
  "step right, side k x nominal"; label it accurately. `misplaced` and size both rest on the centroids
  (size valid only if a misplacement preserves the step). Negative control drawn where spacing fits
  cannot show the step is trustworthy on the nine (selection).
- B2 Ties go to nominal: p_nominal ~ p_agl on bc7718 (0), bc5715 (0.003), bc80117 (0.017), bc77026
  (0.06) -> add `indistinguishable`; location must not fire there. tau has no ceiling; tau in p is the
  wrong unit (step error is relative) -> use log k. tau set on 5-pair medians, applied to 118-pair ones.
- B3 Instrument floor (~0.18-0.25); no_match is "unmeasured", not "not adjacent"; relief at low height
  can exceed the 128 px patch reach.
- B4 Appending to flying_height_logbooks.csv changes fly#95's pinned tests (test-fly_footprint_above_ground.R
  193-197, 227-231, 243-251) and note figures (terrain-correction.md 812-823). fly#95 says a
  ground-naming header ships through factor != 1: reconcile W2 `ground`. Do not append control re-reads
  (settle() does not filter `control`).
- G1 Positive control too easy; crew-written overlaps in the transcription are a real accuracy control
  (bc5598, bc78065, bc79027, bc78153, bc7454, bc78016, bc86103 80%; bcc162 65%; bc77115 30%; bc79039
  80/60). Report exp(tau) as the detectable step error.
- G2 No false-match control: unrelated pairs must give no_match; near-zero / fixed-pattern seeds
  (data panel ~70 px deep on bc85054_162); seed choice by raw count leans to high overlap.
- G3 Negative control unlike the targets (report scale/relief).
- G4 Census key vs catalogue key: the draft paired over the catalogue key; pick one.
- G5 Page guard for the 5 new rolls enforced nowhere.
- G6 G_R rounding (1,371.6 vs 1,372) makes a reading "excluded" by -0.4 m.
- O1 task_plan.md stale vs the rule; controls ran before the logbook step the rule orders first.
- O2 Re-run the generator before appending, to separate a catalogue change from a transcription effect.
- Scope: strongest result is "nominal not refuted / step wrong". Interval x ground speed would give an
  air base with no centroids (not taken up: scope). Lead 4 only partly tested (n,n+1 vs f1).
- Acceptance: tests pin tau ceiling, floor, indistinguishable; restore-the-bug incl. reordering W1.
