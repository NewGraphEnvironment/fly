# Review — the written record of fly#82 (record round 2)

Scope: the note section "What the photos can say about the photo date…" plus the fly#80
"Canopy at the photo date" bullet; the NEWS development entry; the two CLAUDE.md entries; the
header comments of `data-raw/dem_measure-photo_parallax.R` and
`tests/testthat/test-fly_footprint_parallax.R`. Enumerated from scratch against the shipped CSVs,
the script (current and `44f72d8`, the a3 commit), `findings.md`, `review-1.md`, `review-2.md`,
`data-raw/.cache/logs/parallax_*.log`, the smoke cache and fly#80's section. Two probes were run:
(1) the seed-82 draw was recomputed from `census_d2eaafb5.rds` with the script's eligibility code
and compared with the smoke samples; (2) the script's verdict logic was run on the rows smoke
mode would produce. The test file passes (`NOT_CRAN=true`, PASS 34). Nothing edited but this file.

**Claim table: 118 rows** (note N1–N63, NEWS W1–W12, CLAUDE.md Architecture A1–A7, Key
Decision K1–K15, script header S1–S16, test T1–T5). 95 agree; 23 are findings below.

## Findings, most serious first

### F1 (high) — the smoke sentence misstates what ran, in both halves
Note: "Smoke runs that shook the code out matched and registered ten pairs from the head of the
real draw. They crashed before any slope existed".
- **"Matched and registered ten pairs" is false.** `parallax_smoke.log` (seed 82, a1):
  `pair status: error: argument of length 0 3, no_thumbnail 1, ok 6`;
  `gates: … ok 4, registration_bound 2`. Ten were drawn; six matched and were placed; four
  passed the registration gates.
- **"They crashed before any slope existed" is true of one run, said of "runs".** The seed-82
  run and the a2 smoke (seed 9182) crashed in `pair_stats`. The a3 smoke (seed 9182,
  `parallax_smoke_a3.log`) did not crash: `smoke: 6 pairs gated ok; verdict code ran`. In the a3
  code (`git show 44f72d8:…`, lines 1180–1335) that path calls `estimate()` → `phi_source()`, so
  canopy slopes, φ and D were **computed in memory** on six pairs and only blanked before
  printing. Findings' own wording is "prints and writes no slope, φ or D", not "computes".
- **"From the head of the real draw" is supported.** Recomputed: the seed-82 two-per-decade draw
  is a subset of the seed-82 ninety-per-decade draw (263,499 eligible pairs, same as both logs).
  The a1 code itself was never committed, so this rests on unchanged eligibility.
- **The note's headline (N8) survives.** None of the ten a3 smoke pairs is in the real draw (0
  of 10; 3 of 10 share a roll). So "no canopy slope, φ or D was computed on any sampled pair" holds
  for the real sample. The sentence that explains it does not.

### F2 (high) — the test header still carries round 1's two top findings
`test-fly_footprint_parallax.R` lines 4–6: "under the rule fixed before any frame was measured no
sampled pair was measured". The rewrite did not touch these lines.
- **"Fixed before any frame was measured"** is false. The bc5282 pilot and the 13 Phase 0 pairs
  were measured before the rule (findings, "Pilot probe" and "Phase 0").
- **"No sampled pair was measured"** is false. Six pairs from the head of the real draw were
  matched and four passed registration (F1).
- The note's form, "no canopy slope, φ or D was computed on any sampled pair", is the one the
  record supports.

### F3 (medium) — "neither candidate alone accounts for the size of the miss" has no argument for candidate 2, and a weak one for candidate 1
- **NEWS** says the note "records two candidates and why neither alone accounts for the size of
  the miss". **CLAUDE.md** K6 says "Neither candidate alone accounts for the size of the miss".
- **The note gives no such argument for candidate 2** (registration). It says only that
  registration can land wrong and pass the gates. The undisplaced pool also searched offset and
  scale, so a wrong landing is not excluded there either.
- **Candidate 1's argument is not supported.** The note says "It cannot account for the size of
  the miss on its own", because the plain κ = 1 synthetics span ×1.15.
  - Those are three frames: bc78008, bc85054 and bcc01030.
  - The admitted frames that carry the class contrast are bc78129 (124/3), bcc04013,
    bcb96067 and bcb00031. None has a measured plain response. Round 1 F3 said so.
  - The one other measured response, bc5225 at 0.703 (`rot2.R`, findings Amendment B 3), gives
    1.123/0.703 = 1.60 against the frames that were measured. That is above both misses.
  - So the measured spread bounds the response of three frames, not of the pool. Round 1's point
    was "magnitude unmeasured". The rewrite turned it into "cannot", the opposite claim.

### F4 (medium) — script header: `FLY_PARALLAX_SMOKE=1` "runs a handful of pairs", but under a6 smoke can never reach a pair
- Smoke restricts Stage 1 to `cases$src == 1 & !cases$off` (line 887). That is one plain frame
  (bc78008) and one undisplaced class frame (bc5225).
- `plain_ok` needs at least 2 passing frames per case, and smoke has 1. `class_ok` needs a pooled
  row at both 0 and 150 m, and smoke has no displaced case.
- So `SYN_OK` is always FALSE in smoke, and line 1048 quits before Stage 2 whatever the
  instrument does. Run on the smoke subset of the shipped rows, the script's own logic gives
  `plain_ok FALSE, class_ok FALSE`.
- The header line is false, and smoke mode no longer exercises Stages 2–4 at all. That is a
  defect in the script as well as in its comment. CLAUDE.md A6 ("computes no slope on a sampled
  pair; it prints the synthetic slopes") is true, but only because smoke always stops.

### F5 (medium) — script header: "amended twice — A and B"
Line 32: the rule was "amended twice — A and B — before any sampled pair was read".
- **Amendment A predates the rule.** Findings places it "before Phase 1 code", ahead of
  "Decision rule — fixed".
- **The amendments to the rule are B and C.** C, the pooled class test that stopped the study,
  is omitted.
- This contradicts the note and CLAUDE.md K13, both "Three amendments (A–C)".

### F6 (medium–low) — the per-frame φ range mixes in the displaced runs
Note, candidate 1: "On the three admitted frames holding both classes it ranged from −0.402 to
4.153 against known answers of 0.642–0.911."
- −0.402 is bcc04013 **displaced 150 m**. That is candidate 2's condition, quoted as evidence
  for candidate 1.
- Undisplaced, the range is 0.363–4.153 against 0.649–0.911.
- The test pins the mixed range (`both <- ok[is.finite(ok$phi), ]` takes both displacements), so
  the test preserves the defect.

### F7 (medium–low) — "Phase 0 registration moved real pairs by up to 1.1 km" quotes a registration the rule would refuse
- The 1.1 km is bc78129: (−886, −702) = 1,130 m in `parallax_phase0c.log`.
- That fit's rotation is **−6.2°**, outside the rule's |rotation| ≤ 6° gate ("a value at the ±8
  bound is a failed registration"; the gate is 6). Its R² is 0.507.
- The largest offset from an in-gate registration is bc85054 at 879 m.
- Phase 0 also searched rotation freely, which the a6 instrument no longer does.
- As evidence of how far real placements can be off, the figure is a failed fit.

### F8 (low–medium) — the pilot's "before registration" / "unregistered" has no producer, and its "seven" does not reconcile
- **Registration.** The note says "scratch code, before registration". CLAUDE.md K5 and the test
  header say "seven unregistered pairs". The pilot did register: a ±300 m search on DTM-only R²
  moved the grid 0–95 m (findings, "Pilot probe").
  - Findings gives one DTM-slope range, 0.95–1.13, and does not say whether it is from the
    registered fit or the unregistered one.
  - Round 1 F6 flagged this as undisclosed. The rewrite resolved it by assertion.
- **The count.** Frames 226–236 make 10 pairs and 2 failed the global match, which leaves 8.
  Findings says "all 7 pairs". The note repeats 7 without the discrepancy (round 1 F6, open).

### F9 (low) — candidate 1's premise and "dominant source" are still one-source readings (round 1 F4, open)
- **"Dominant source" is not dominant by area.** `class_phi()` reports the source with more *old*
  patches, and a tie goes to radar (line 853). "Dominant source" reads as dominant by area, as
  findings' "66% radar" does.
- **The per-frame rows omit most of the mid patches.** For the seven admitted undisplaced frames
  they sum to 151 mid / 91 old. The pooled rows hold 307 / 108, so **156 mid and 17 old patches**
  sit in columns no per-frame row reports.
- **The premise is therefore not shown.** "The classes sit in different frames", stated in the
  note's candidate 1 heading and in CLAUDE.md K7, is not shown by the shipped rows. Neither is
  "the three admitted frames holding both classes", which counts the reported source only.

### F10 (low) — "the eleven pilot frames" names the wrong set to a reader of this section
- The section calls bc5282's pairs "pilot" ("Terrain, in a pilot"; "2 of 10 pilot pairs on that
  roll"). bc5282 226–236 is exactly eleven frames.
- The eleven in the class synthetic are the Phase 0 frames that matched (Amendment C), and none
  of them is on bc5282.
- NEWS ("eleven pilot frames") and CLAUDE.md K3 ("seven pilot frames") carry the same label.

### F11 (low) — Amendment A's reason is half the record's
- The note says A dropped the digital control "because the in-pair ratio was meant to cancel what
  it measured".
- Amendment A names two jobs. Placement shrinkage cancels in φ. The **matcher check** was handed
  to the synthetic controls, which do not cancel in the ratio.
- It also gives the cost reasons: PATB parsing traps, an extrapolated 120 mm format, and B/H of
  about 0.25 halving the signal.

### F12 (low) — two CLAUDE.md characterisations without a producer
- **K11**, "one pilot centroid sat ×1.7 off". ×1.7 is a spacing ratio: 2,353 m catalogued against
  about 1,360 m imaged (findings, Phase 0), and 858 / 495.9 px in phase0c. It is not the offset of
  a centroid. The note's "×1.7 off the images' own spacing" is the correct form.
- **K15**, "The record's own review found its prose written from the story in the same way",
  meaning the same mechanism as "a guard computed on a sibling". `review-record1.md` names no
  mechanism and draws no such parallel.

## Test file findings

- **TF1 — the round-5 restore-the-bug test cannot fail against the script.**
  - "the verdict logic fails a case whose every frame is refused" exercises
    `synthetic_verdict()`, a copy defined in the test file. Nothing in the file loads or
    reads the script's `plain_ok`.
  - The shipped CSV carries only per-row `pass`, which is computed before the aggregation the bug
    lived in. Restoring the round-5 bug in `data-raw/dem_measure-photo_parallax.R` and
    regenerating leaves the CSV, and every test here, unchanged.
  - The block guards the test's own helper (which test 1 relies on). The comment presents it as a
    guard on the script's fix.
- **TF2 — prose figures neither asserted nor listed under "Not asserted":**
  - "ten pairs" (note, smoke sentence), which is also wrong (F1);
  - "JPEG 85" (note; script header). The previous header listed "the JPEG quality", and the
    rewrite dropped it;
  - "0.146" bare reference (script header);
  - "Five code-check rounds" and "82-row enumeration" (CLAUDE.md K14). Round 1 T2 raised these
    and they are still unlisted;
  - "Three amendments (A–C)" (note, CLAUDE.md, NEWS by reference);
  - "1965, 1975 and 1985", "within 0.5%", "1968" (minor);
  - the CLAUDE.md copies of 1.356 / 0.860 / 0.793 / 0.550, ×1.15 / ×1.58 / ×1.44 and "seven". The
    test reads the note and NEWS only, and the header does not say CLAUDE.md is out of scope.
- **TF3 — the header's "seven unregistered pairs"** repeats F8's unsupported qualifier.
- **TF4 (low) — `expect_true(all(nzchar(v$etag)))` passes an `NA` etag** (`nzchar(NA)` is TRUE).
  It can fail on `""`, so it is not vacuous, but it cannot catch a missing value.
- **No other assertion that cannot fail was found.**
  - The table rebuild matches whole lines and bounds the line count (12).
  - `admitted` is now recomputed from statuses, which fixes round 1 T3.
  - Every `expect_match` interpolates a value computed from the rows.

## Claim table (118 rows)

| # | location | claim | producer | agrees? |
|---|---|---|---|---|
| N1 | note fly#80 bullet | fly#82 parallax witness built, failed synthetic controls, VRI stands alone | final log STOP | yes |
| N2 | note fly#80 bullet | linear height-age understates how short a young stand is | fly#80 section; B 19 | yes |
| N3 | note ¶1 | fly#80 left canopy-at-photo-date to a model | findings Problem | yes |
| N4 | note ¶1 | p = f B / (H − h) | script header, `implied_height` | yes |
| N5 | note ¶1 | h − h₀ = (H − h₀)(1 − p₀/p), no air base, scale common | derivation; script `(H − e_w)(1 − p0/p)` | yes |
| N6 | note ¶1 | slope on C = canopy seen | script `pair_stats` | yes |
| N7 | note | stopped at its first verdict | final log | yes |
| N8 | note | no canopy slope, φ or D computed on any sampled pair, rule fixed before any read | a6 quits before Stage 2; a3 smoke pairs 0/10 in real draw (probe) | yes |
| N9 | note | smoke matched and registered ten pairs | smoke log: ok 6, gates ok 4 | **no, F1** |
| N10 | note | …from the head of the real draw | probe: seed-82 2/decade ⊂ 90/decade | yes (a1 code uncommitted) |
| N11 | note | they crashed before any slope existed | a1, a2 crashed; a3 ran verdict code | **misleading, F1** |
| N12 | note | smoke draw then given its own seed | script 9182, Amendment B | yes |
| N13 | note | pilot frames excluded from the sample | `PILOT_ROLLS` (16 rolls) | yes |
| N14 | note | bc5282 canopy coefficients computed in scratch before the rule | findings Pilot probe | yes |
| N15 | note | script reproduces the stop, ships synthetic CSV, suite rebuilds tables | final log, test | yes |
| N16 | note | seven pairs of bc5282 | findings: 10 pairs, 2 failed, "all 7" | **unreconciled, F8** |
| N17 | note | 1968 | findings | yes |
| N18 | note | DTM slopes 0.95–1.13 | findings Pilot probe | yes |
| N19 | note | "before registration" | pilot did register; slope's fit unstated | **unsupported, F8** |
| N20 | note | quadratic absorbs tilt, crab, scan rotation, scale | findings rule, script:509 | yes |
| N21 | note | recorded in findings; script does not reproduce it | script | yes |
| N22 | note | coarse-to-fine phase correlation, peaks verified by local patches | findings Phase 0, script | yes |
| N23 | note | whole-frame wrong on 2 of 10 pilot pairs on that roll | findings Pilot probe | yes |
| N24 | note | …and on several Phase 0 pairs | findings "about half"; logs 3–4 of 11 | yes |
| N25 | note | centroid spacing never used as the air base | script (gate/seed window only) | yes |
| N26 | note | 1965/1975/1985: 64–77% of bases equal within 0.5% | review-1: 67/77/64% | yes |
| N27 | note | so pre-1990s spacing carries no per-frame base | review-1 (IQR 0.998–1.002) | yes (reviewer's inference, labelled) |
| N28 | note | one Phase 0 pair ×1.7 off the images' spacing | phase0c 858/495.9; findings 2,353/1,360 | yes |
| N29 | note | synthetic: warp by known surface, tilt, rotation, scale on both axes, JPEG 85 | `synth_pair`, `jpeg85` | yes |
| N30 | note table | flat κ=0, 3 of 3, −0.029 to +0.013 | CSV | yes (pinned) |
| N31 | note table | flat κ=1, 3 of 3, +0.989 to +1.063 | CSV | yes (pinned) |
| N32 | note table | terrain κ=0, 3 of 3, −0.029 to +0.070 | CSV | yes (pinned) |
| N33 | note table | terrain κ=1, 3 of 3, +0.975 to +1.123 | CSV | yes (pinned) |
| N34 | note | quantity = mid slope over ≥80 y slope, after bare reference | Amendment B 9 | yes |
| N35 | note | synthetic world where VRI model exactly true | Amendment B 5, script kappa | yes |
| N36 | note | ran on the eleven pilot frames | CSV 11 rolls (Phase 0) | figure yes; **label, F10** |
| N37 | note | pooled over the seven the gates admitted | CSV statuses | yes (pinned) |
| N38 | note | missed in both sources | CSV pass FALSE ×4 | yes |
| N39 | note table | radar, no: 1.356 / 0.860 / 135/65 | CSV | yes (pinned) |
| N40 | note table | lidar, no: 0.793 / 0.550 / 172/43 | CSV | yes (pinned) |
| N41 | note table | radar, 150 m: 46.350 / 0.860 / 135/65 | CSV | yes (pinned) |
| N42 | note table | lidar, 150 m: 0.810 / 0.553 / 173/43 | CSV | yes (pinned) |
| N43 | note | φ 46 = old slope tiny against mid | definition, β0 = 0 | yes |
| N44 | note | why not established; two candidates, diagnosis | findings Outcome | yes |
| N45 | note | candidate 1: classes sit in different frames | per-frame rows one source; 156 mid unreported | **unsupported, F9** |
| N46 | note | one frame 124 mid vs 3 old "in its dominant source" | CSV; source picked by old count | figure yes; **"dominant", F9** |
| N47 | note | three admitted frames hold both classes | CSV (reported source only) | yes, one source (F9) |
| N48 | note | per-frame φ −0.402 to 4.153 vs 0.642–0.911 | CSV, both displacements | **misleading, F6** |
| N49 | note | response spread cannot account for the miss on its own | 3 frames measured; contrast frames unmeasured | **unsupported, F3** |
| N50 | note | κ=1 span 0.975–1.123, ratio 1.15 | CSV | yes (pinned) |
| N51 | note | miss ratios 1.58 radar, 1.44 lidar | CSV | yes (pinned) |
| N52 | note | response on uniform canopy vs stands not measured | — | yes |
| N53 | note | registration can land wrong and pass every gate | CSV bc85054 150 m status ok | yes |
| N54 | note | one plain frame fell to 0.403 | CSV | yes (pinned) |
| N55 | note | Phase 0 registration moved real pairs up to 1.1 km | phase0c bc78129 1,130 m at rot −6.2° | figure yes; **misleading, F7** |
| N56 | note | thumbnail resolution not varied | — | yes |
| N57 | note | fly#80: DSM worse on 15.1% of 1970s frames where canopy matters | note fly#80 table, canopy test | yes |
| N58 | note | no code or default could change; fly#80 immaterial | rule verdict 6 | yes |
| N59 | note | three amendments, each fixed before any sampled pair read | findings A–C | yes |
| N60 | note | A dropped because the ratio cancels what it measured | Amendment A (two jobs, cost reasons) | **partial, F11** |
| N61 | note | B dropped young: 2 patches in 11 pilot pairs | Amendment B 8 | yes |
| N62 | note | B: bare = LidarBC slope on radar, 0 on lidar by construction | Amendment B 8 | yes |
| N63 | note | C pooled the class test; one frame cannot estimate the ratio | Amendment C | yes |
| W1 | NEWS | parallax as built cannot say…; no code changes | diff `R/` empty | yes |
| W2 | NEWS | fly#80 left the question to VRI stand origin | findings Problem | yes |
| W3 | NEWS | parallax against median gives height, no air base | script | yes |
| W4 | NEWS | pilot on one 1968 roll tracked terrain this way | findings Pilot probe | yes |
| W5 | NEWS | the script builds the instrument | script | yes |
| W6 | NEWS | ratio of mid to old canopy seen | Amendment B 9 | yes |
| W7 | NEWS | VRI-true synthetic on eleven pilot frames, seven admitted | CSV | yes; label F10 |
| W8 | NEWS | radar 1.356 vs 0.860, lidar 0.793 vs 0.550 | CSV | yes (pinned) |
| W9 | NEWS | no canopy slope on any sampled pair, rule fixed before any read | as N8 | yes |
| W10 | NEWS | note records why neither candidate alone accounts for the miss | note argues candidate 1 only | **no, F3** |
| W11 | NEWS | DSM worse on 15.1% of 1970s frames | fly#80 | yes |
| W12 | NEWS | ships synthetic CSV; suite rebuilds note tables | test | yes |
| A1 | CLAUDE arch | fly#82 asks whether parallax can say the surface | script | yes |
| A2 | CLAUDE arch | stops at Stage 1, no canopy slope on any sampled pair | final log | yes |
| A3 | CLAUDE arch | ships synthetic CSV (verdicts, tables recomputed) and `_versions.csv` | test | yes |
| A4 | CLAUDE arch | `raycast` and fly#80 helpers through `fns_from()` | script:83–87 | yes |
| A5 | CLAUDE arch | cache keyed on three ETags, census, algorithm tag | script:613 `VKEY` | yes |
| A6 | CLAUDE arch | smoke writes nothing, no sampled-pair slope, prints synthetic slopes | script 887, 1048 | yes (because smoke always stops, F4) |
| A7 | CLAUDE arch | PSOCK `mean()` NA trap | script:93–101 | yes |
| K1 | CLAUDE KD | cannot date canopy; no slope on a sampled pair; no code change | as N8 | yes |
| K2 | CLAUDE KD | estimand ratio of mid to old slope | Amendment B 9 | yes |
| K3 | CLAUDE KD | VRI-true synthetic, seven pilot frames, radar/lidar figures | CSV | yes; label F10 |
| K4 | CLAUDE KD | plain synthetics passed | CSV | yes |
| K5 | CLAUDE KD | pilot DTM 0.95–1.13 on seven unregistered pairs | findings | **unsupported qualifier, F8** |
| K6 | CLAUDE KD | neither candidate alone accounts for the miss | note | **unsupported, F3** |
| K7 | CLAUDE KD | classes in different frames; ×1.15 vs ×1.58/×1.44 | CSV figures; premise | figures yes; **inference F3/F9** |
| K8 | CLAUDE KD | registration can land wrong and pass every gate | CSV | yes |
| K9 | CLAUDE KD | fly#80's VRI estimate stands alone | — | yes |
| K10 | CLAUDE KD | never use centroid spacing as B; pre-1990s evenly spaced | review-1 | yes |
| K11 | CLAUDE KD | one pilot centroid sat ×1.7 off | spacing ratio, not centroid | **misleading, F12** |
| K12 | CLAUDE KD | test a ratio pooled; per-frame test ill-posed (C) | Amendment C | yes |
| K13 | CLAUDE KD | three amendments fixed before any sampled pair read | findings | yes |
| K14 | CLAUDE KD | five rounds, 82-row enumeration, guard on a sibling | findings Code-check | yes |
| K15 | CLAUDE KD | record review found prose from the story "in the same way" | review-record1 (no such mechanism) | **unsupported, F12** |
| S1 | script header | fly#80: DSM vs DTM does not matter; one question left to a model | fly#80 | yes |
| S2 | script header | 15.1% of 1970s frames | fly#80 | yes |
| S3 | script header | stops at Stage 1, so no sampled pair is measured | final log | yes (of the script's run) |
| S4 | script header | p formula, h − h0 formula, ratio cancels B | derivation | yes |
| S5 | script header | spacing evenly spaced pre-1990s, ×1.7 on one pilot pair | review-1, phase0c | yes |
| S6 | script header | slope on C is canopy seen | script | yes |
| S7 | script header | radar DTM under ground by an amount growing with C | review-1 0.146; fly#80 | yes |
| S8 | script header | bare 0.146 radar, 0 lidar | review-1, Amendment B 8 | yes |
| S9 | script header | old = ≥80 y at the photo | rule | yes |
| S10 | script header | φ formula per source; VRI predicts; D is the verdict | Amendment B 9–10 | yes |
| S11 | script header | young dropped: two patches in eleven pairs (B) | Amendment B 8 | yes |
| S12 | script header | rule "amended twice — A and B" | findings: A before rule; B and C after | **no, F5** |
| S13 | script header | everything is public | sources | yes |
| S14 | script header | stage list incl. JPEG 85 | script | yes |
| S15 | script header | SMOKE runs a handful of pairs into a separate cache | smoke always quits at Stage 1 (probe) | **no, F4** |
| S16 | script header | STOP=n stops after stage n | script | yes |
| T1 | test header | rule fixed before any frame measured; no sampled pair measured | findings, smoke log | **no, F2** |
| T2 | test header | recomputes verdicts, rebuilds note tables and figures | test body | yes |
| T3 | test header | not-asserted list ("seven unregistered pairs") | findings | **F8 / TF3** |
| T4 | test | coverage of stated figures | — | **gaps, TF2** |
| T5 | test | assertions that cannot fail | — | **TF1 (against the script); TF4 low** |

Count: N 63 + W 12 + A 7 + K 15 + S 16 + T 5 = **118 rows**.
