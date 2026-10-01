# Review — the written record of fly#82 (record round 3, terminal enumeration)

**Scope.** These files, at `39cd418`:
- the note section "What the photos can say about the photo date…" and the fly#80 bullet
  "Canopy at the photo date";
- the NEWS development entry;
- CLAUDE.md, Key Decision "Photo parallax, as built…" and Architecture
  `data-raw/dem_measure-photo_parallax.R`;
- the header comments of `data-raw/dem_measure-photo_parallax.R` (lines 1–55) and of
  `tests/testthat/test-fly_footprint_parallax.R`.

**Producers.** Every claim was checked against its producer:
- the shipped CSVs;
- the script;
- `findings.md`, `review-1.md` and `review-2.md`;
- `data-raw/.cache/logs/parallax_*.log`;
- fly#80's section and its test;
- `gh issue view 85`.

**Probes.**
1. **The a6 smoke draw.** Recomputed from `census_d2eaafb5.rds` with the script's Stage 2 code.
   It equals `photo_parallax_smoke/sample_620742aa.rds`, and **0 of its 10 pairs** are in the
   seed-82 real draw of 450 pairs (3 of its rolls are).
2. **The test file.** It passes: `NOT_CRAN=true`, PASS 33.
3. **Mutations.** Nine were made on a `git archive` copy in the scratchpad, never in the repo.
   Every one turned the file red (table below).

Nothing in the repo was edited except this file.

**Claim table: 137 rows.**

| prefix | where | rows |
|---|---|---|
| B | fly#80 bullet | 4 |
| N | note section | 52 |
| W | NEWS | 10 |
| A | CLAUDE.md Architecture | 10 |
| K | CLAUDE.md Key Decision | 14 |
| S | script header | 36 |
| T | test header | 11 |

- **128 agree.**
- **6 are wrong:** N8, N47, A8, S25, S30, and S33 (partly).
- **3 are unsupported or self-contradicting:** K9, T5 and T7.
- **One agreeing row points somewhere that does not:** N41 agrees, but the fly#85 body it points
  to has drifted (F3).

The findings come first, then the full table.

## Findings, most serious first

### F1 (medium) — "each before any pair of the real draw was read" is false for Amendments B and C
- **Where it appears.** Note N47 says "The plan changed three times, each before any pair of the
  real draw was read". Script header S25 says the rule was fixed "…before Amendments B and C, all
  before any pair of the real draw was read".
- **The a1 smoke read pairs from the head of the real draw.** `parallax_smoke.log` (cache key
  a1, 07:55) shows a seed-82 sample of 10 pairs:
  - `pair status: … ok 6`, so six were fetched, matched and placed;
  - `gates: … ok 4, registration_bound 2`, so they were registered and gated.
- **Round 2 showed those pairs are the head of the real draw.** The seed-82 two-per-decade draw
  is a subset of the seed-82 ninety-per-decade draw.
- **Amendment B came after that run.** It was committed at `5675ca8`, 08:40. Its own first
  sentence in `findings.md` reads "The smoke run measured 10 pairs drawn with the real seed".
  Amendment C came later still.
- **The note contradicts itself.** Three paragraphs earlier it says the smoke runs "drew from the
  head of that draw".
- **What the record supports:** "…each before any canopy slope was computed on a pair of the real
  draw". The producer is loose in the same way. `findings.md`'s Amendment B and C headers say
  "before any sampled pair is read", directly above B's sentence saying a pair was measured.

### F2 (medium) — CLAUDE.md Architecture: smoke "computes no slope on a sampled pair" became false in `39cd418`
- **Smoke no longer stops after Stage 1.** The latest commit makes smoke carry on past the
  synthetic stop (`if (!SYN_OK && !SMOKE)`, line 1048) into Stages 2–4.
- **Stage 4 now computes slopes on the smoke's own sampled pairs.**
  - It runs `pair_stats()` on every gate-eligible smoke pair. That function fits
    `stats::lm.fit(Xf, y)` with the canopy-by-class columns in `Xf`, so it computes per-class
    canopy coefficients.
  - `estimate()` → `phi_source()` → `solve_cols()` then compute pooled class slopes, φ, φ_VRI
    and D, at the point and in 50 bootstrap resamples.
- **None of it is printed or written, and the headline still holds** (see "Smoke behaviour"
  below).
  - The a6 smoke pairs are disjoint from the real draw (probe 1).
  - So "no canopy slope, φ or D was computed on any pair of the real draw" (N7, W7, K2, T2)
    still holds.
- **A8 does not.** The script header's own wording, "prints no slope of a pair", is the correct
  form. CLAUDE.md was not updated with it.

### F3 (low–medium) — the fly#85 body, which the note cites, still carries claims rounds 1–2 removed
- **The note points readers there.** N41: "What would have to change is filed as fly#85."
- **The open issue body (checked today) still says three things the record no longer claims:**
  - "It stopped at its synthetic controls before any sampled pair was measured." Round 2 F2 found
    this false: the a1 smoke measured pairs from the head of the draw.
  - "neither alone accounts for the size of the miss: the plain synthetics span x1.15, against
    misses of x1.58 (radar) and x1.44 (lidar)". This is round 2 F3, unsupported, and it was cut
    from the note, NEWS and CLAUDE.md.
  - "The stand classes sit in different frames." This is round 2 F9: the shipped rows do not
    show it.
- **The issue body is the next document the note sends a reader to.** Under feature-workflow,
  "Issue bodies get edited, not appended", it should be edited to match.

### F4 (low) — note N8: "Early smoke runs drew from the head of that draw" — one run did
- **Only one run used the real seed.** Seed 9182 for smoke has been in the script since the
  first commit of it (`5675ca8`, a2, line 936). So the only smoke run on the real seed is a1
  (`parallax_smoke.log`).
- **The findings say one run.** `findings.md` reads "The smoke run measured 10 pairs drawn with
  the real seed", singular.
- **Why the plural matters.** It invites the reading that more of the real draw was touched than
  was. Round 2 F1 flagged "runs" too, and the rewrite kept the plural.
- **Not independently verifiable.** "Crashed before any slope existed" (N9) rests on
  `findings.md` alone, because the a1 code was never committed. It is consistent with the log:
  the a1 gate line printed before `pair_stats` crashed, so a1 gated without the full-model fit.

### F5 (low) — CLAUDE.md K9: "a test of single slopes says nothing about the ratio"
- **The rule says the opposite.** Amendment B 5 kept the plain κ = 0 test for the ratio's sake:
  "Plain κ=0 must be within 0.10 of 0: an additive bias does not cancel in φ".
- **So the single-slope test is necessary for the ratio, not irrelevant to it.** What the
  outcome supports is narrower: plain synthetics passing is not *sufficient* for the ratio.

### F6 (low) — script header S30 and S33, the smoke line
- **"Runs one frame per synthetic case" (S30): false for the displaced cases.**
  - Line 888 keeps `cases$src == 1 & !cases$off`. So dtm_C0 at 150 m, dtm_C1 at 150 m and class
    at 150 m run **zero** frames.
  - Smoke has no displaced pool, which is one reason it can never pass.
- **"Into a separate cache" (S33): partly false.**
  - Thumbnails and roll metadata go to the shared `photo_parallax/thumbs` and
    `photo_parallax/rolls` (lines 64–65, "thumbnails are shared by both").
  - Samples, pairs and synthetics do go to `photo_parallax_smoke/`.

### F7 (low) — test header: the "Not asserted" list has two gaps and a false reason
- **Two note figures are neither asserted nor listed:**
  - "The plan changed **three** times" (N46);
  - stands "**80 or more** years old" (N23).

  Every other figure in the note section and NEWS that is not asserted is listed:
  - 64–77% with its 1965/1975/1985 and 0.5%;
  - ×1.7;
  - 15.1%.
- **The stated reason is false for one listed item.** The list says the figures are unasserted
  "because no shipped table carries them (each has its producer in the archived planning findings
  or review files)". That does not hold for fly#80's 15.1%.
  - A shipped fly#80 CSV carries it.
  - `test-fly_footprint_canopy.R:215–220` rebuilds it.
  - The same item says as much: "which fly#80's own test pins".
- **The JPEG-quality item is obsolete but harmless.** The note no longer quotes 85.

## Smoke behaviour (verified by reading `39cd418`)

- **Stage 1.** Smoke runs one plain frame (bc78008) on four undisplaced cases and one class frame
  (bc5225) undisplaced.
  - `plain_ok` needs at least 2 passing frames per case, so in smoke it is always FALSE.
  - `class_ok` needs a qualifying pooled row at both 0 and 150 m, so in smoke it is always FALSE.
  - So `SYN_OK` is FALSE in every smoke run.
- **Stage 1 output.** It prints only synthetic rows: slopes of synthetic frames, and φ of the
  single class synthetic. No pair is involved.
- **Stage 2.** Smoke draws with seed 9182. The a6 sample is 10 pairs, disjoint from the real draw
  (probe 1). It prints counts only.
- **Stage 3.** `measure_pair()` matches, places and classes, and caches patches. It computes no
  slope, and prints status counts only.
- **Stage 4.**
  - **Computed:** `pair_stats()`, `estimate()`, the bootstrap and the per-decade verdicts, all in
    memory (F2).
  - **Printed:** `gates:` counts; `bare-earth reference` (0.1456 from LidarBC tiles, not a pair);
    `STOP (synthetic): no verdict is read`; `smoke: N pairs gated ok`.
  - **Guarded, so never printed in smoke:** the source-separation print (`!SMOKE && SYN_OK`) and
    the per-decade φ/D print (`!SMOKE && !nzchar(STOPPED)`).
- **Stage 4 honours the synthetic stop in smoke.**
  - `STOPPED` is `"synthetic"` because `SYN_OK` is FALSE.
  - `source_*_separates` and `sources` are set to NA, every `^(phi|D)` column is blanked, and
    `verdict` is `not_read`.
- **Writes.** `write_versions()` and both `write_if_changed()` calls sit under `if (!SMOKE)`.
  The Stage-1 stop's `write_versions()` is now unreachable in smoke, because the branch is
  `!SYN_OK && !SMOKE`. So smoke writes nothing to `inst/extdata/`.
- **Conclusion: smoke prints and writes no slope, φ or D of a pair**, and Stage 4 honours the
  stop. It does compute them in memory (F2).
- **A live run confirms it.** A smoke run under the new code (`parallax_smoke_final.log`, a6)
  finished at about 10:52.
  - It printed `pair status: no_global 1, ok 9` and `gates: no_global 1, ok 7,
    registration_bound 2`.
  - It printed `STOP (synthetic): no verdict is read` and `smoke: 7 pairs gated ok`.
  - No line other than the `synthetic` ones carries a slope or φ.
  - `git status` shows nothing written to `inst/extdata/`.
  - So `pair_stats()`, φ and D were computed in memory on 7 smoke pairs, none of them in the real
    draw (F2).

## Test assertions — every one can fail

Each mutation was made on a scratch copy, never in the repo.

| mutation | result |
|---|---|
| note 0.403 → 0.404 | FAIL 1 |
| note "eleven" → "twelve" | FAIL 1 |
| plain table range +0.013 → +0.014 | FAIL 1 |
| NEWS radar 1.356 → 1.357 | FAIL 1 |
| note "seven the gates admitted" → "six" | FAIL 1 |
| note (bcc01030) → (bc78008) | FAIL 1 |
| extra row added to the pooled table | FAIL 1 |
| CSV plain bc85054 dtm_C1 slope → 1.4, pass flag kept TRUE | FAIL 5 |
| CSV pooled φ set equal to φ_VRI, all four rows | FAIL 8 |
| test helper: round-5 bug restored (admitted rows only, unlevelled split) | FAIL 1 |
| baseline | PASS 33 |

- **`expect_false(v$ok)` never fails alone.** `ok` is `plain_ok && class_ok`. It can still fail,
  so it is not vacuous.
- **`etag` now catches `NA`** (`!is.na & nzchar`).
- **No assertion that cannot fail was found.**

## Claim table (137 rows)

| # | location | claim | producer | verdict |
|---|---|---|---|---|
| B1 | fly#80 bullet | linear height-age understates how short a young stand is | fly#80 text, unchanged since `84265e4` | agrees (fly#80's) |
| B2 | fly#80 bullet | a witness from the photos (parallax between adjacent frames) was built in fly#82 | script | agrees |
| B3 | fly#80 bullet | …and failed its synthetic controls | CSV, `parallax_final.log` | agrees |
| B4 | fly#80 bullet | so this estimate stands alone | final log STOP | agrees |
| N1 | note ¶1 | fly#80 left one question to a model: canopy at the photo date | findings Problem; fly#80 section | agrees |
| N2 | note | p = f B / (H − h) | script header, `implied_height` | agrees |
| N3 | note | inside one overlap f, B, H are shared | pair rule (same lens, height) | agrees |
| N4 | note | h − h₀ = (H − h₀)(1 − p₀/p); no air base needed | derivation; script uses e_w for h₀ | agrees |
| N5 | note | regressing on DTM and C gives a slope on C = canopy seen | `pair_stats`, `synth_slope` | agrees |
| N6 | note | stopped at its first verdict | final log | agrees |
| N7 | note | no canopy slope, φ or D computed on any pair of the real draw | a6 quits before Stage 2; a1 crash (findings); a3/a6 smoke 0/10 in draw | agrees |
| N8 | note | early smoke runs drew from the head of that draw | one run (a1, seed 82); 9182 since `5675ca8` | **wrong (count), F4** |
| N9 | note | …and crashed before any slope existed | findings Amendment B (a1 uncommitted) | agrees (findings only) |
| N10 | note | smoke runs now use their own seed | script 9182 | agrees |
| N11 | note | script reproduces the stop, ships synthetic CSV; suite rebuilds tables | final log; test | agrees |
| N12 | note | synthetic: real thumbnail warped by known surface parallax | `synth_pair` | agrees |
| N13 | note | with tilt, rotation and scale difference on both axes | `synth_pair` nuisance | agrees |
| N14 | note | saved as JPEG | `jpeg85` | agrees |
| N15 | note table | flat κ=0: 3 of 3, −0.029 to +0.013 | CSV | agrees (pinned) |
| N16 | note table | flat κ=1: 3 of 3, +0.989 to +1.063 | CSV | agrees (pinned) |
| N17 | note table | terrain κ=0: 3 of 3, −0.029 to +0.070 | CSV | agrees (pinned) |
| N18 | note table | terrain κ=1: 3 of 3, +0.975 to +1.123 | CSV | agrees (pinned) |
| N19 | note | centroid spacing is never used as the air base | script (seed window and gate only) | agrees |
| N20 | note | plan-review probe: 64–77% of consecutive bases, 1965/75/85, within 0.5% | review-1 (67/77/64%) | agrees |
| N21 | note | so the spacing carries no per-frame base there | review-1 | agrees |
| N22 | note | one Phase 0 pair: spacing ×1.7 what images showed | findings Phase 0; phase0c 858/495.9 | agrees |
| N23 | note | quantity = mid slope over ≥80 y slope after bare reference removed | Amendment B 9 | agrees |
| N24 | note | synthetic world where fly#80's VRI model is exactly true | Amendment B 5/C; class κ code | agrees |
| N25 | note | ran on eleven Phase 0 pilot frames | CSV, `SYN_CLS` | agrees (pinned) |
| N26 | note | pooled over the seven the gates admitted | CSV statuses | agrees (pinned) |
| N27 | note | …as the sample would be pooled | Amendment C; script sums `pair_stats` | agrees |
| N28 | note | missed its known answer in both sources | CSV pass FALSE ×4 | agrees |
| N29 | note table | radar, no: 1.356 / 0.860 / 135 / 65 | CSV | agrees (pinned) |
| N30 | note table | lidar, no: 0.793 / 0.550 / 172 / 43 | CSV | agrees (pinned) |
| N31 | note table | radar, 150 m: 46.350 / 0.860 / 135 / 65 | CSV | agrees (pinned) |
| N32 | note table | lidar, 150 m: 0.810 / 0.553 / 173 / 43 | CSV | agrees (pinned) |
| N33 | note | why not established; two candidates, neither measured | findings Outcome ("diagnosis") | agrees |
| N34 | note | candidate 1: matcher response differs between class-carrying frames (as candidate) | labelled unmeasured | agrees |
| N35 | note | shipped rows show response only on uniform canopy | CSV plain κ uniform | agrees |
| N36 | note | 0.975–1.123 over three frames | CSV | agrees (pinned) |
| N37 | note | one of which (bcc01030) also holds both classes | CSV 17/16; bc78008, bc85054 are 0–0 ties, so 0 old in both sources | agrees (pinned) |
| N38 | note | candidate 2: displaced 150 m, one plain frame fell to 0.403 | CSV bc85054 | agrees (pinned) |
| N39 | note | that frame passed every gate | CSV status ok | agrees (pinned) |
| N40 | note | thumbnail resolution not varied | script | agrees |
| N41 | note | what would have to change is filed as fly#85 | issue open, on topic; body drifted | agrees; **body F3** |
| N42 | note | fly#80 VRI is the only estimate: DSM worse on 15.1% of 1970s frames | fly#80 table, canopy test | agrees |
| N43 | note | no code or default could have changed either way | rule verdict 6 | agrees |
| N44 | note | fly#80 found the DTM–DSM difference immaterial | fly#80 | agrees |
| N45 | note | so this question decides only a sentence | rule verdict 6 (subsection and bullet) | agrees |
| N46 | note | the plan changed three times | findings A, B, C | agrees (unlisted, F7) |
| N47 | note | …each before any pair of the real draw was read | a1 smoke read 10 head-of-draw pairs before B | **wrong, F1** |
| N48 | note | Amendment A came before the decision rule | findings order | agrees |
| N49 | note | A dropped a digital control on exterior orientation | Amendment A (PATB) | agrees |
| N50 | note | B and C amended the rule | findings | agrees |
| N51 | note | B replaced the young control with fly#80's bare-earth reference | Amendment B 8 | agrees |
| N52 | note | C pooled the class test | Amendment C | agrees |
| W1 | NEWS | parallax as built cannot say…; no code changes | `git diff origin/main...HEAD -- R/` empty | agrees |
| W2 | NEWS | fly#80 left the question to VRI stand origin | findings Problem | agrees |
| W3 | NEWS | script reads it from parallax between number-adjacent frames | script design | agrees |
| W4 | NEWS | question needs a ratio, mid over old | Amendment B 9 | agrees |
| W5 | NEWS | VRI-true synthetic pooled over the seven admitted pilot frames | CSV | agrees (pinned) |
| W6 | NEWS | radar 1.356 vs 0.860, lidar 0.793 vs 0.550 | CSV | agrees (pinned) |
| W7 | NEWS | no canopy slope computed on the real draw | as N7 | agrees |
| W8 | NEWS | why it fails not established (#85) | findings; issue | agrees |
| W9 | NEWS | fly#80 stands alone; 15.1% of 1970s frames | fly#80 | agrees |
| W10 | NEWS | ships synthetic CSV; suite rebuilds the note's tables | test | agrees |
| A1 | CLAUDE arch | fly#82: can parallax say what surface the camera saw | script | agrees |
| A2 | CLAUDE arch | stops at its Stage 1 synthetic controls | final log | agrees |
| A3 | CLAUDE arch | so no canopy slope is computed on any sampled pair | full run quits before Stage 2 | agrees (full run) |
| A4 | CLAUDE arch | ships synthetic CSV (test recomputes verdicts, tables) and `_versions.csv` | test, extdata | agrees |
| A5 | CLAUDE arch | pulls `raycast` and fly#80 helpers via `fns_from()` | script 83–93 | agrees |
| A6 | CLAUDE arch | cache keyed on three ETags, census, algorithm tag | `VKEY` | agrees |
| A7 | CLAUDE arch | smoke writes nothing | `if (!SMOKE)` guards | agrees |
| A8 | CLAUDE arch | smoke computes no slope on a sampled pair | `39cd418` Stage 4 runs in smoke | **wrong, F2** |
| A9 | CLAUDE arch | smoke prints the synthetic slopes | Stage 1 `pub` | agrees |
| A10 | CLAUDE arch | PSOCK worker `mean()` on SpatRaster gives NA | script comment; findings errors | agrees |
| K1 | CLAUDE KD | parallax as built cannot date the canopy | CSV stop | agrees |
| K2 | CLAUDE KD | no canopy slope computed on the real draw | as N7 | agrees |
| K3 | CLAUDE KD | no code change | git diff | agrees |
| K4 | CLAUDE KD | ratio estimand failed its own pooled synthetic | CSV | agrees |
| K5 | CLAUDE KD | so fly#80's VRI estimate stands alone | — | agrees |
| K6 | CLAUDE KD | the ratio is mid-stand over old-stand canopy slope | Amendment B 9 | agrees |
| K7 | CLAUDE KD | VRI-true synthetic missed in both sources | CSV | agrees |
| K8 | CLAUDE KD | the plain synthetics passed | CSV | agrees |
| K9 | CLAUDE KD | so a single-slope test says nothing about the ratio | Amendment B 5 (κ=0 bias does not cancel in φ) | **unsupported, F5** |
| K10 | CLAUDE KD | test a ratio estimand pooled, as estimated | Amendment C | agrees |
| K11 | CLAUDE KD | why it fails not established (fly#85) | findings | agrees |
| K12 | CLAUDE KD | centroid spacing evenly spaced along lines before the 1990s | review-1 | agrees |
| K13 | CLAUDE KD | ×1.7 off on a pilot pair | findings Phase 0 | agrees |
| K14 | CLAUDE KD | read the note and archived findings | prescription (archive pending) | agrees |
| S1 | script hdr | fly#80: DSM vs DTM does not matter | fly#80 | agrees |
| S2 | script hdr | one question left to a model | findings Problem | agrees |
| S3 | script hdr | VRI linear: DSM worse on 15.1% of 1970s frames | fly#80 | agrees |
| S4 | script hdr | stops at Stage 1 | final log | agrees |
| S5 | script hdr | fails its pooled class-structured synthetic | CSV | agrees |
| S6 | script hdr | so no sampled pair is measured | full run (smoke's own pairs stated on line 48) | agrees |
| S7 | script hdr | x-parallax p = f B / (H − h) | derivation | agrees |
| S8 | script hdr | B, f and H shared in one overlap | pair rule | agrees |
| S9 | script hdr | h − h0 = (H − h0)(1 − p0/p); p0/p cancels B | derivation | agrees |
| S10 | script hdr | spacing evenly spaced along a line before the 1990s | review-1 | agrees |
| S11 | script hdr | off by ×1.7 on one pilot pair | findings | agrees |
| S12 | script hdr | therefore never used as B | script | agrees |
| S13 | script hdr | height regressed on DTM and C; slope on C = canopy seen | `pair_stats` | agrees |
| S14 | script hdr | matcher responds to crown texture | review-1 finding 6 | agrees |
| S15 | script hdr | placement blurs C | review-1 finding 4 | agrees |
| S16 | script hdr | radar DTM under true ground, growing with C (fly#80, LidarBC) | review-1 0.146; fly#80 | agrees |
| S17 | script hdr | bare = 0.146 on radar, from fly#80's LidarBC tiles | review-1; Amendment B 8 (0.1456) | agrees |
| S18 | script hdr | bare = 0 on lidar by construction | Amendment B 8 | agrees |
| S19 | script hdr | old = ≥80 y at photo, canopy then much as now | rule | agrees |
| S20 | script hdr | φ = (b_mid − bare)/(b_old − bare) per source | Amendment B 9; `phi_source` | agrees |
| S21 | script hdr | VRI predicts φ from the same patches; D is the verdict | Amendment B 9–10 | agrees |
| S22 | script hdr | young control dropped: two patches in eleven pairs (B) | Amendment B 8 | agrees |
| S23 | script hdr | rule fixed in "Decision rule" after A, before B and C | findings order | agrees |
| S24 | script hdr | every threshold, class, gate and verdict fixed there (then amended) | findings | agrees |
| S25 | script hdr | all before any pair of the real draw was read | as N47 | **wrong, F1** |
| S26 | script hdr | everything is public | sources | agrees |
| S27 | script hdr | run after `dem_measure-canopy_height.R` has built its census | Stage 0 stop | agrees |
| S28 | script hdr | stage list 0–4 | script | agrees |
| S29 | script hdr | Stage 1: known surface, tilt, placement error, JPEG 85 | `synth_pair`, `jpeg85`, 150 m | agrees |
| S30 | script hdr | smoke runs one frame per synthetic case | displaced cases run 0 frames (line 888) | **wrong (partial), F6** |
| S31 | script hdr | smoke draws two pairs a decade | `N_DECADE` | agrees |
| S32 | script hdr | drawn with its own seed | 9182 | agrees |
| S33 | script hdr | into a separate cache | thumbs and rolls shared (lines 64–65) | **partly wrong, F6** |
| S34 | script hdr | smoke writes nothing | `if (!SMOKE)` guards | agrees |
| S35 | script hdr | smoke prints no slope of a pair | all pair-level prints guarded | agrees (verified) |
| S36 | script hdr | `FLY_PARALLAX_STOP=<n>` stops after stage n | lines 626, 1053, 1099, 1211 | agrees |
| T1 | test hdr | the script built an instrument meant to read canopy seen at the photo date | script | agrees |
| T2 | test hdr | failed controls, so no canopy slope on any pair of the real draw | as N7 | agrees |
| T3 | test hdr | what shipped is the controls | extdata (plus versions) | agrees |
| T4 | test hdr | recomputes their verdicts from the shipped rows | test 1 | agrees |
| T5 | test hdr | rebuilds the tables and figures of the note section and NEWS | two note figures unasserted and unlisted | **gap, F7** |
| T6 | test hdr | CLAUDE.md and code comments not pinned | test body | agrees |
| T7 | test hdr | not asserted "because no shipped table carries them", producers in findings or reviews | false for 15.1% (shipped fly#80 CSV) | **self-contradicting, F7** |
| T8 | test hdr | fly#80's 15.1% pinned by fly#80's own test | `test-fly_footprint_canopy.R:215–220` | agrees |
| T9 | test hdr | 64–77% from a plan-review probe | review-1 | agrees |
| T10 | test hdr | ×1.7 spacing on a Phase 0 pair | findings | agrees |
| T11 | test 2 comment | the script's copy was fixed for the same defect in round 5 | findings Code-check; script line 1018 | agrees |

**Total: 4 + 52 + 10 + 10 + 14 + 36 + 11 = 137 rows.**
