# Review — the written record of fly#82 (record round 1)

Scope: `git diff main...HEAD -- inst/notes NEWS.md CLAUDE.md` (the new terrain-correction section,
the edited fly#80 "Canopy at the photo date" bullet, the NEWS entry, the two CLAUDE.md entries)
and `tests/testthat/test-fly_footprint_parallax.R`. Every number and factual claim enumerated and
checked against its producer: shipped CSVs, the script, `planning/active/findings.md`, the logs
`data-raw/.cache/logs/parallax_*.log`, `review-1.md`, `review-round5.md`, and fly#80's section and
`dem_canopy_*.csv`. No suite run; nothing edited but this file.

**Claim table: 87 rows** (note N1–N52, NEWS W1–W10, CLAUDE.md Architecture A1–A7, CLAUDE.md
Key Decision K1–K14, test T1–T4). 59 agree; 28 are findings below (several rows share one finding).

## Findings, most serious first

### F1 (high) — "no sampled pair was measured" is false by the findings' own record
Rows N7, W7, A1, K2, K12, and the test header.
- `findings.md:245` (Amendment B): "The smoke run measured 10 pairs drawn with the real seed. Its
  Stage 4 crashed in `pair_stats` before any slope existed."
- `parallax_smoke.log`: `sample: 10 pairs (1960: 2, ... 2000: 2)`, `measuring 10 pairs on 3 workers`,
  `pair status: ... ok 6`, `gates: ... ok 4, registration_bound 2`. Seed 82, 2 per decade, so they
  are probably the first two of each decade of the real draw. `parallax_smoke_a2.log` and `_a3.log`
  measured 10 more (seed 9182), and a3 reports `6 pairs gated ok; verdict code ran`. The script's own
  comment (line 95) cites a smoke-run pair, `bcc405 55`.
- What the record supports is **no canopy coefficient, φ or D was computed or read on a sampled
  pair**. That is what findings and the script's smoke banner say. Matching, placement,
  registration and gating did run on sampled pairs. K12, "Three amendments (A–C) came before any
  sampled pair", is false for B and C. The note's "each fixed before any sampled pair was *read*"
  (N51) is the correct form.

### F2 (high) — "under the rule fixed before any frame was measured" is false
Rows N6 and W7 ("under the rule fixed before the run"), and the test header repeats N6.
- The bc5282 pilot (findings:27–52) measured frames and **computed canopy coefficients** before the
  rule existed, and findings calls it a leak. Phase 0 measured 13 more pilot pairs before the rule
  (findings:73–115, `parallax_phase0*.log`).
- The rule was fixed before any *sampled pair* was measured, and per F1 not even fully that.

### F3 (medium) — "Two mechanisms, both visible in the shipped rows" is not true, and the causes are inferred
Rows N33, N35, N38, N40, N42, W8, K6.
- Findings:448–449 says plainly: "what follows is diagnosis, not a further measurement". The note
  drops that qualifier and says "visible in the shipped rows". CLAUDE.md says "Two causes:" and
  NEWS says "The two causes", both as findings.
- Four of the supporting figures are not in any shipped row:
  - 0.703, which comes from `rot2.R`, a scratch harness under an earlier algorithm, not a6;
  - the ~900 m offsets (Phase 0 scratch);
  - the radar pool's old slope collapsing "toward zero". The CSV and the logs carry no `b_old`;
    this is inferred from φ = 46.35;
  - the "124 against 3" row is shipped, but see F4.
- **The 0.703 frame cannot drive the pooled result.** bc5225 151 is `gated_registration_bound` in
  both class rows, so it is outside the 7-frame pool.
- **The measured response spread cannot produce the miss.** The only measured κ = 1 responses
  are 0.975–1.123, a ratio of at most 1.123/0.975 = 1.15. Producing the pooled misses needs a
  ratio of 1.356/0.860 = 1.58 (radar) and 0.793/0.550 = 1.44 (lidar).
- The admitted frames that carry the class contrast (bc78129, bcb96067, bcc04013, bcb00031) have no
  measured plain response. Mechanism 1 is therefore a hypothesis whose size is unmeasured, not a
  visible cause.
- An alternative is not excluded: one frame dominating the radar pool. bcc04013's per-frame φ is
  4.153 against 0.911, while bc78129 and bcc01030 read *below* VRI.

### F4 (medium) — the per-frame class counts are one source only, so "two carry old ground and no mid" is unsupported
Rows N36, N37, and T1.
- `class_phi()` (script:850–856) reports `n_mid`/`n_old` in **one** source, picked by
  `sum(old_r) >= sum(old_l)`. On a tie it picks radar. The pooled counts sum both sources'
  columns from the same `gp` (`n_cls`, script:549, 971).
- For the 7 admitted undisplaced frames, the per-frame columns sum to **151 mid / 91 old**. The
  pooled rows hold 135 + 172 = **307 mid** and 65 + 43 = **108 old**. That leaves **156 mid and 17
  old patches** in columns no per-frame row reports.
- bc78008 and bc85054, which findings:299–300 calls lidar frames, report 0/0. That is consistent
  with the tie falling to radar while their lidar columns hold patches.
- So bcb96067 (0/27) and bcb00031 (0/9) may well carry mid patches in their other source. The
  shipped data cannot show that they "carry old ground and no mid". "The classes sit in different
  frames", the premise of mechanism 1, is not established by the shipped rows.
- Separately, findings:454–455 explains bc78129's source as "dominant ... its 3 km window is 66%
  radar". The code chooses by old-patch count, not by area.

### F5 (medium) — "a frame holds a few dozen patches of each class at most" is contradicted by the shipped rows
Row N39.
- bc78129 holds 124 mid (CSV row `class,bc78129,145,...,124,3`). bc5225 holds 104 and 108 old.
- What the rows support is that the *scarcer* class per frame is at most 17 (bcc01030, 17/16).
- The script comment at line 875 ("one frame holds 1-21 mid patches") is from the a4 era and is
  also out of date.

### F6 (medium) — the terrain claim is credited to the shipped instrument, but its only producer is the pre-rule scratch pilot
Rows N9, N10, N45, W4, K3.
- "On the seven pilot pairs of roll bc5282 ... slopes of 0.95–1.13" comes from findings:44 only:
  scratch scripts, no log, before the rule, 64 px windows on a 24 px step (the shipped instrument
  uses a 32 px grid with Hann sampling and a DTM-gradient nuisance).
- NEWS says "A new instrument, `data-raw/dem_measure-photo_parallax.R`, recovers terrain this
  way". The shipped script records no DTM slope on any real pair: ĝ is not in either CSV or in any
  a6 log line.
- **The count does not reconcile.** Frames 226–236 make 10 pairs, and findings:38–39 says 2 of
  10 failed, which leaves 8. Findings:44 says "all 7 pairs".
- **Registered or not is undisclosed.** findings:45–46 (review-1 #5) records that registering on
  DTM R² "makes the DTM slope a fitted quantity, not a control". The note does not say whether
  0.95–1.13 was measured before or after that registration.

### F7 (medium) — the amendment bullets are mislabelled
Row N47.
- "Three amendments (A–C) ... each fixed before any sampled pair was read:" is followed by three
  bullets. They are Amendment B 8, Amendment B 8 and Amendment C.
- **Amendment A, which dropped the digital PATB control (findings:117–124), is not described.**
  A reader maps the bullets onto A, B and C in order.
- The lead-in says "the rule changed twice", which is right (A preceded the rule), but sits
  beside "Three amendments".
- N49 has a related problem: "the bare-earth reference became fly#80's LidarBC slope per MRDEM
  source". Only radar's reference (0.1456) is a LidarBC slope. Lidar's is 0 by assumption
  (findings:309–311, script:19–20).

### F8 (medium) — "the parallax *difference* ... whatever the air base is" states the wrong invariant
Rows N3 and W3.
- A parallax difference in px is f·B·(1/(H−h₁) − 1/(H−h₂)), which scales with B.
- What is B-free is the **ratio** to the pair's median, which is what the code computes:
  `implied_height()`, `(H − e_w)(1 − p0/p)` (script:436–439), with the comment at 432–434 stating
  it correctly. It needs the catalogue H, and ĝ then normalises that.
- The script header (lines 9–11) carries the same misstatement.

### F9 (low–medium) — "up to ~900 m" understates the producer and counts a failed registration
Row N40.
- `parallax_phase0c.log` gives these offsets:
  - bc78129: (−886, −702), which is **1,130 m**;
  - bc85054: (−756, −449), which is 879 m;
  - bcb00031: (−848, +61), which is 850 m. Its rotation and scale (7.7, −8.0) sit at the
    ±8 bounds, a failed registration by the rule's own gate.
- The offsets are registration fits on DTM R², which also absorb orientation error. They are not
  a direct measurement of centroid error.
- The ±300 m search in the first Phase 0 log shows these offsets are bounded by the search box.
  The 0c box is not recorded.

### F10 (low–medium) — "0.16–1.01 px" has no log producer and excludes a frame measured at 1.48 px
Row N14.
- findings:92 obtains 0.16–1.01 by dividing an earlier, unlogged 0.24–1.50 by 1.4826
  (0.24/1.4826 = 0.162, 1.50/1.4826 = 1.012). No log line carries it.
- `parallax_phase0c.log`'s `q_sd_px` reads 0.191–2.87, and findings:93–94 says that column is
  the plain SD.
- findings:271 gives bc5225's y-parallax **robust** SD as 1.48 px, outside the quoted range.
- It was also measured under the Phase 0 matcher. The note attaches it to "Coarse-to-fine
  phase correlation", the shipped instrument.

### F11 (low) — the ×1.7 sits beside "interpolated" as if interpolation caused it
Rows N18, N19, K9.
- "Interpolated before the 1990s" is review-1's inference from evenness: 64–77% of pre-1990
  triples have equal bases within 0.5% (`review-1.md:6–8`). It is not an observation, and it holds
  for only that share of frames.
- An interpolated, evenly spaced line does not explain a ×1.7 base on one pair. findings:97–98
  attributes bc85054 to "a misplaced centroid".
- The ×1.7 itself is right: pred 858 px against a measured 495.9 px, 1.73.

### F12 (low) — "about half the pilot pairs" is not reproducible, and "pilot" is ambiguous
Row N16.
- The note uses "pilot pairs" for the bc5282 pairs in the preceding bullet, where the
  whole-frame correlation failed on 2 of 10, not half.
- For Phase 0, comparing `parallax_phase0.log` shifts with `phase0c` gives 3–4 of 11 matched
  pairs on a wrong peak (bc5225 157.9 against 438, bcb96017 142.9 against 433, bcc04013 120.5
  against 435, and possibly bcb96067 416 against 442).

### F13 (low) — "cannot ... at thumbnail resolution" is presented as the cause
Rows N1, N52, W1, K1.
- Nothing varied resolution, and neither named cause is resolution. Pilot signal is ~2.5 px per
  10 m of canopy against a 0.16–1.01 px noise figure.
- What was measured is that *this* pooled-ratio estimator failed its synthetic test. "Cannot"
  generalises to the method. Findings:466–470 makes the same leap.

### F14 (low) — CLAUDE.md Architecture overstates two script facts
- A2: the versions CSV is not recomputed by the test. It checks only the asset set and that
  every etag is non-empty.
- A5: "FLY_PARALLAX_SMOKE=1 ... prints no slope". Smoke prints every synthetic slope
  (`parallax_smoke_a3.log`). It is the sampled-pair slopes it withholds.

## Test file findings

- **T1 — the header's reason is false.** "Not asserted, because no shipped table carries them:
  ... the 124-against-3 class counts". `dem_parallax_synthetic.csv` carries them
  (`class,bc78129,145,class,0,...,124,3`). They could be asserted, along with the 0/27 and 0/9 rows
  behind "two carry old ground and no mid" (but see F4 before pinning that).
- **T2 — stated figures that are neither asserted nor listed under "Not asserted":**
  - "two carry old ground and no mid" (N37);
  - "a few dozen patches of each class at most" (N39), which the shipped rows contradict;
  - "the radar pool's old slope collapsed toward zero" (N42);
  - the count "seven" in "seven pilot pairs of roll bc5282" (only the slope range is listed);
  - "1,250 px";
  - "about half the pilot pairs";
  - the years 1967 and 1968;
  - "Three amendments (A–C)" and their mapping (F7).

  The test reads only the note, so every figure in the NEWS entry and both CLAUDE.md entries is
  unpinned: 1.356/0.860/0.793/0.550, eleven/seven and 15.1% in NEWS; 0.95–1.13, ×1.7,
  "Five code-check rounds" and "82-row" in CLAUDE.md. The header does not say the copies are
  out of scope.
- **T3 — the admitted count is asserted against the script's own label, not recomputed.**
  `expect_identical(admitted, "7 frames")` checks the label the script wrote. Recompute it from
  the rows, as `sum(s$set == "class" & s$displaced_m == 0 & s$status == "ok") == 7`, and check
  the label against that. It can fail, so it is not vacuous, but it reads its own output.
- **T4 — no assertion that cannot fail was found.**
  - The round-5 restore-the-bug test does fire: an all-refused case returns FALSE.
  - The table rebuild matches whole lines exactly, and the 12-line count bounds added rows.
  - `synthetic_verdict()` restates the script's rule (script:991–1022) rather than reading it. A
    threshold wrong in both places would pass, but that is "one fact derived twice", not
    vacuity.

## Claim table (87 rows)

| # | location | claim | producer | agrees? |
|---|---|---|---|---|
| N1 | note, fly#80 bullet | fly#82 witness failed its synthetic controls at thumbnail resolution | a6 log FAIL | yes; "at thumbnail resolution" causal reading F13 |
| N2 | note ¶1 | image shift f B/(H−h) | script:9 | yes |
| N3 | note ¶1 | parallax *difference* measures height whatever B is | script:436–439 (ratio) | **no, F8** |
| N4 | note ¶1 | regress implied height on DTM and C, slope on C | script `pair_stats` | yes |
| N5 | note | stopped at its first verdict | final log STOP, verdict 1 | yes |
| N6 | note | rule fixed before any frame was measured | findings:27–115 | **no, F2** |
| N7 | note | no sampled pair was measured | findings:245, smoke logs | **no, F1** |
| N8 | note | script reproduces the stop, ships synthetic CSV, suite rebuilds tables | script:1028–1046, test | yes |
| N9 | note | seven pilot pairs of bc5282 (1968) | findings:27, 38–44 | **count unreconciled (10, 2 failed, "all 7"), F6** |
| N10 | note | DTM slope 0.95–1.13 | findings:44 (scratch, pre-rule) | figure matches; registration status and instrument attribution, F6 |
| N11 | note | quadratic absorbs tilt, crab, scan rotation, scale | findings:43, script:506 | yes |
| N12 | note | coarse-to-fine phase correlation on 1,250 px thumbnails | findings:34, script | yes |
| N13 | note | JPEG quality 85 | findings:34, script:721–725 | yes |
| N14 | note | y-parallax robust SD 0.16–1.01 px | findings:92 (derived, no log); phase0c 0.19–2.87; bc5225 1.48 | **unsupported, F10** |
| N15 | note | candidate peaks verified by local patches | findings:87–89 | yes |
| N16 | note | whole-frame correlation wrong on about half the pilot pairs | findings:83; logs 3–4 of 11; bc5282 2 of 10 | **weak, F12** |
| N17 | note | centroid spacing never used as air base | script (gate/seed only) | yes |
| N18 | note | before the 1990s spacing is interpolated | review-1:6–8 (inference from evenness) | **inferred, F11** |
| N19 | note | wrong by ×1.7 on one pair | phase0c pred 858 / 495.9 | yes; juxtaposition F11 |
| N20 | note | synthetic: tilt, rotation, scale on both axes, JPEG 85 | script:735–766 | yes |
| N21 | note table | flat κ=0, 3 of 3, −0.029 to +0.013 | CSV | yes (pinned) |
| N22 | note table | flat κ=1, 3 of 3, +0.989 to +1.063 | CSV | yes (pinned) |
| N23 | note table | terrain κ=0, 3 of 3, −0.029 to +0.070 | CSV | yes (pinned) |
| N24 | note table | terrain κ=1, 3 of 3, +0.975 to +1.123 | CSV | yes (pinned) |
| N25 | note | φ = mid over ≥80 y, after bare reference | script, findings B9 | yes |
| N26 | note | synthetic world where VRI model exactly true | script:891–916 | yes |
| N27 | note | on the eleven pilot frames | CSV (11 rolls) | yes (pinned) |
| N28 | note | pooled over the seven the gates admitted | CSV label, statuses | yes (2 of 4 refused by matcher, counted as refused under B 5) |
| N29 | note table | radar, no: 1.356 / 0.860 / 135/65 | CSV | yes (pinned) |
| N30 | note table | lidar, no: 0.793 / 0.550 / 172/43 | CSV | yes (pinned) |
| N31 | note table | radar, 150 m: 46.350 / 0.860 / 135/65 | CSV | yes (pinned) |
| N32 | note table | lidar, 150 m: 0.810 / 0.553 / 173/43 | CSV | yes (pinned) |
| N33 | note | two mechanisms, both visible in the shipped rows | findings:448 "diagnosis" | **no, F3** |
| N34 | note | κ=1 0.975–1.123 at true placement | CSV | yes (pinned) |
| N35 | note | snow-patched 1967 frame read 0.703 | findings:271 (rot2.R, earlier algorithm) | figure matches; not shipped, frame outside pool, F3 |
| N36 | note | one frame 124 mid against 3 old | CSV bc78129 | yes, in one source only (F4) |
| N37 | note | two carry old ground and no mid | CSV per-frame, one source | **unsupported, F4** |
| N38 | note | pooled ratio inherits ratio of frames' responses | no producer; spread 1.15 vs 1.58/1.44 | **inferred, magnitude unsupported, F3** |
| N39 | note | a few dozen patches of each class at most | CSV 124 mid, 104 old | **no, F5** |
| N40 | note | centroids up to ~900 m off | phase0c: 1,130 m max; one failed registration | **no / understated, F9** |
| N41 | note | 150 m: one plain frame fell to 0.403 | CSV bc85054 | yes (pinned) |
| N42 | note | radar pool's old slope collapsed toward zero | none (inferred from φ) | **unsupported, F3** |
| N43 | note | fly#80: DSM worse on 15.1% of 1970s frames | note:1217 | yes |
| N44 | note | fly#80 found the difference immaterial; decides a sentence | fly#80 section, rule 6 | yes |
| N45 | note | per-patch parallax a usable terrain witness | pilot scratch only | **weak, F6** |
| N46 | note | film centroids not a usable air base | findings:86, review-1 | yes (caveat F11) |
| N47 | note | three amendments (A–C), three bullets | findings A, B8, C | **mislabelled, F7** |
| N48 | note | young dropped: 2 patches in 11 pilot pairs | findings:303–305 | yes |
| N49 | note | bare reference = fly#80 LidarBC slope per source | findings:309–311 | **partly; lidar is 0 by assumption, F7** |
| N50 | note | class test pooled | Amendment C | yes |
| N51 | note | each fixed before any sampled pair was read | findings:245 | yes, literally (no coefficient) |
| N52 | note heading | "not enough, at thumbnail resolution" | — | **overclaim, F13** |
| W1 | NEWS | cannot say at thumbnail resolution | — | **F13** |
| W2 | NEWS | no code changes | diff stat (no `R/`) | yes |
| W3 | NEWS | parallax difference measures height, no air base | script ratio | **F8** |
| W4 | NEWS | the new instrument recovers terrain this way | pilot scratch | **F6** |
| W5 | NEWS | ratio of mid to old canopy | script | yes |
| W6 | NEWS | VRI-true synthetic; eleven; seven; 1.356/0.860, 0.793/0.550 | CSV | yes |
| W7 | NEWS | no sampled pair measured, under the rule fixed before the run | findings:245 | **F1, F2** |
| W8 | NEWS | the two causes | findings:448 "diagnosis" | **inferred, F3** |
| W9 | NEWS | 15.1% of the 1970s frames | note:1217 | yes |
| W10 | NEWS | synthetic controls ship; suite rebuilds the tables | test | yes |
| A1 | CLAUDE arch | stopped at its synthetic controls, no sampled pair measured | smoke logs | **F1** |
| A2 | CLAUDE arch | test recomputes synthetic and versions CSVs | test | **versions not recomputed, F14** |
| A3 | CLAUDE arch | `raycast` and fly#80 helpers through `fns_from()` | script:85–87 | yes |
| A4 | CLAUDE arch | caches keyed on three ETags, census, algorithm | script:603–611 | yes |
| A5 | CLAUDE arch | SMOKE writes nothing and prints no slope | smoke_a3 log prints slopes | **F14** |
| A6 | CLAUDE arch | STOP=n stops after stage n | script:622, 1047, 1093, 1205 | yes |
| A7 | CLAUDE arch | PSOCK `mean()` returns NA; band arithmetic | script:93–101, findings:483 | yes |
| K1 | CLAUDE KD | cannot date the canopy at thumbnail resolution | — | **F13** |
| K2 | CLAUDE KD | stopped before any sampled pair | smoke logs | **F1** |
| K3 | CLAUDE KD | DTM slope 0.95–1.13, quadratic absorbs tilt, crab, scan | findings:44 | figure yes; F6 |
| K4 | CLAUDE KD | plain synthetic controls pass | CSV | yes |
| K5 | CLAUDE KD | radar 1.356/0.860, lidar 0.793/0.550 | CSV | yes |
| K6 | CLAUDE KD | two causes (frame response; registration) | findings "diagnosis" | **inferred, F3/F4** |
| K7 | CLAUDE KD | registration lands wrong yet passes every gate | CSV bc85054 150 m, status ok | yes |
| K8 | CLAUDE KD | fly#80's VRI estimate stands alone | — | yes |
| K9 | CLAUDE KD | interpolated before 1990s; ×1.7 on a pilot pair | review-1, phase0c | ×1.7 yes; F11 |
| K10 | CLAUDE KD | per-frame φ test ill-posed, replaced (C) | findings:372–390 | yes |
| K11 | CLAUDE KD | plain passed while the estimand failed | CSV | yes |
| K12 | CLAUDE KD | three amendments (A–C) before any sampled pair | findings:245 | **F1** |
| K13 | CLAUDE KD | five rounds, 82-row enumeration | findings:394–417, review-round5:22 | yes |
| K14 | CLAUDE KD | shared mechanism: guard on a sibling object | findings:402–409 | yes |
| T1 | test header | 124-against-3 not in any shipped table | CSV carries it | **no** |
| T2 | test | coverage of stated figures | — | **gaps listed above** |
| T3 | test | admitted = "7 frames" | script label | reads its own output (low) |
| T4 | test | assertions that cannot fail | — | none found |

Count: N 52 + W 10 + A 7 + K 14 + T 4 = **87 rows**.
