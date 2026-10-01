# Review round 3 — data-raw/dem_measure-photo_parallax.R (HEAD b46a884, algorithm a4)

I read the whole file at HEAD, the round-2 fix diff (`git diff HEAD~1 HEAD`), and findings.md
("Decision rule", "Amendment A", "Amendment B"). I ran two probes in
`scratchpad/r3/probe1.R` and `probe2.R`, and reproduced BETA0 from `dem_canopy_lidar.csv`
(0.14564, SE 0.06755, which matches Amendment B). Nothing in the repo was run or edited apart
from this file.

## Mechanism

Every defect so far comes from the same move: **a guard is computed on one object, and the
quantity it protects is computed on a sibling object.** The two agree only where the guard was
first written. Each round fixed the site that was reported and left the sibling. The siblings
were:

- the point set and the resample (R1 and R2 `combine`);
- the normal placement and the mirror (R1 objective, R2 patch set, and R3 below: the patch set is
  now chosen on the normal placement's ground);
- the source-agnostic pair list and a per-source old column (R2 `old_from`, R3 below);
- the printed line and the written CSV (R2 `source` line, R3 below);
- "the column is non-empty" (`diag > 0`) and "the column carries information" (R3 icpt, below);
- the status prefix and "a rerun clears it" (R2 `no_dem` and HTTP codes, R3 `error:`).

How the four candidates fare:

- **(a) "missing in a subset" and (d) "read under a stop"** are both this mechanism.
- **(b) "several lists of status strings must agree"** holds only as two literal lists. The
  refused set appears at :951 and again at :961, and they agree today.
- **(c) "positional layout"** is closed. Every read is now either by name or through a column
  order built once, from `COLS` and `UT`.

## Enumeration (place → correct / defect)

### Status strings: producer × classifier

| producer (line) | strings | one() cache :1067 | Stage 1 pass :951 / print :961 | gate_of :1118 | verdict |
|---|---|---|---|---|---|
| measure_core :318 | `no_global` | cached | refused / refused | dropped | correct |
| measure_core :321 | `no_dem` | cached | refused / refused | dropped | correct (window is in memory) |
| measure_core :394 | `no_registration` | cached | refused / refused | dropped | correct |
| fetch_pair :640, :642 | `not_one_row`, `no_thumbnail` | cached | Stage 1 `stopifnot` | dropped | correct |
| fetch_pair :652 | `transient: thumbnail <curl msg>` | not cached | stop | — | correct |
| fetch_pair :658 | `transient: thumbnail_http_5xx/429`; `thumbnail_http_<other>` | not cached / cached | stop | dropped | correct except 408, which is cached as definitive (negligible) |
| measure_pair :1027 | `transient: catalogue <msg>`, which covers every fetch_pair error including rename | not cached | — | — | correct |
| one() :1063 | `error: <msg>`, covering **every** other error: network (VRI) and deterministic alike | not cached | — (Stage 1 has no tryCatch; a stop is loud) | — | **defect F5**: a deterministic error blocks Stage 4 permanently |
| Stage 1 :926-930 | `gated_*` | — | refused / refused | — | correct; but see F4 for the label of an aliased fit |
| measure_pair :1043 | `ok` + gate `few_patches` | cached | — | `few_patches` | correct |

### Empty or degenerate subsets

| place | subset | handling | verdict |
|---|---|---|---|
| pair_stats :516 `live` | class with no patch in the pair | dropped from the full fit | correct |
| pair_stats :542 `D` | class dummies | empty ones dropped | correct |
| solve_cols :553 `diag > 0`, **main** fit | class absent from the summed set | dropped | correct: an empty column gives exactly 0, a 1-patch column is not annihilated by N |
| solve_cols :553 `diag > 0`, **icpt** fit | class with **exactly one patch** in every pair that has it | its own dummy annihilates it, so diag is about 1e-31, which is > 0 and kept | **defect F1** |
| estimate :1222 | a source with no mid or old patches in a set | NA for that source | correct |
| sources_for / combine | a source NA at the point or in >1% of resamples; NA within one resample | dropped, then renormalised | correct (accepted tradeoff) |
| combine :1262 | `var` NA when fewer than 2 finite values | cannot occur: srcs require ≥99% finite | correct |
| verdict loop :1287 | decade with no gated pairs | `next` | correct |
| `own` :1289 | decided on the point set, held for resamples | design | correct |
| old_from :1318 | neighbours that add **no old patches of this source** | labelled `adjacent` | **defect F3** (mislabel) |
| ci() | all NA | quantile on empty gives NA, then inconclusive | correct |
| class_phi :842 | chosen source with 0 mid or 0 old patches | phi NA, so FAIL, cached as a synthetic stop | conforms to the rule's wording ("NA is a FAIL"). Noted, not filed |
| synth_slope :819 | aliased coefficients | `none`, then `gated_model_r2` | **defect F4** (mislabel; the effect, a refusal, is acceptable) |
| by_case :966 | a case with fewer than 2 frames measured and passing | SYN_OK FALSE | correct (Amendment B 5); smoke always STOPs here, which is harmless |
| G with 0 rows | — | VERDICTS becomes a list (`NULL$x <-`) | unreachable outside smoke, and smoke writes nothing |

### Normal against mirror

| place | quantity | verdict |
|---|---|---|
| :353-356 `use_open` | objective fixed on normal | correct |
| :353-357 `open_ok` / `yr` | patch set fixed, **but chosen at the normal placement's ground** | **defect F2** (low) |
| :391-393 mirror choice, :394 no_registration | — | correct; optim never returns worse than its finite start |

### Read under a stop or before a gate

| place | under synthetic stop | under controls stop | verdict |
|---|---|---|---|
| :1243 `source` line | suppressed | printed (verdict 2) | correct |
| :1337 verdict line | suppressed | suppressed | correct |
| :1350 `^(phi\|D)` blanking | blanked | blanked | correct; it covers all 22 estimate columns |
| :1344-1345 `source_r_separates`, `source_l_separates`; :1321 `sources` | **written** | written (correct there) | **defect F6** |
| pairs CSV | written | written | accepted tradeoff |
| :970-972 `shrink` summary | — | — | includes slopes of frames the gates refused (F7, low) |

### Positional reads (c)

These are all by name now, or through a single order: `gi`, `cf["Xdtm"]` / `cf["XC"]`,
`m$reg[["rot"]]`, `gs[["row"]]`, `st$n_cls[[k]]`, `Xty[k, 1]`, `b0fit["mrdem_canopy", 1]`, and
the `UT` / `COLS` order shared by `pairs_out` and `summed()`. The positional matrices
(`p1`, `p2`, `img_vec`, `rot_ground`) each have one writer and one reader. All correct.

## Findings

- **[bug: rule silently not applied]** :537-539, :552-556, :1298-1316. **The class-intercept
  sensitivity (Amendment B 14) cannot run whenever a class has exactly one patch in a pair.**
  Not inside a round-2 fix: this is the pre-existing icpt fit, with the same mechanism.
  - In `stat(cbind(N, D))`, a class with one patch in a pair has `Z_k = C_i e_i` and its dummy
    `D_k = e_i`, so the residualised column is zero in exact arithmetic. Numerically it is
    ~1e-16, and its diagonal is ~1e-31.
  - `solve_cols()` keeps any column with `diag > 0`. `solve()` then fails:
    - probe1: *"system is computationally singular: reciprocal condition number = 2.4e-35"*;
    - probe2: the same with six such pairs among 30 (diag 3.5e-30 against max 3119).
  - `estimate()`'s `tryCatch` turns that into NA for **both** sources. So `sources_for(pti, bti)`
    is empty, `Di` is NA, and `all(is.finite(Di_ci))` is FALSE. **The contradiction check is
    skipped and a MORE/LESS verdict stands unchecked.** The only trace is NA `D_icpt*` columns.
  - Reach: with young at "2 patches in 11 pairs" (and `post`, `mid_l`, `old_l` similarly
    sparse), a decade or a resample whose young patches are all singletons is the likely case.
    If one pair carries ≥2 of them, about 37% of resamples lack it, the icpt source fails in
    more than 1% of resamples, and it is dropped. The main fit is unaffected: N alone does not
    annihilate a single-patch column.
  - Fix: keep a column on information relative to the matrix, e.g.
    `diag(XtX) > 1e-9 * max(diag(XtX))`, or per pair zero `Zp` columns whose class has fewer than
    2 patches when dummies are present. Also consider making MORE/LESS `inconclusive` (or at
    least flagged) when the intercept fit is not computable, because as written the guard fails
    toward pass.

- **[fragile] Inside the round-2 mirror patch-set fix.** :353-357. The patch set is now the same
  for normal and mirror, but it is chosen by `c0 < 2` **at the normal placement's ground**.
  - Under a true mirror, those patches are open only at the wrong ground. At the true (mirror)
    ground they carry canopy, which is exactly the canopy-lowers-the-DTM-fit penalty Amendment B
    3 measured.
  - So the comparison is again asymmetric, now biased toward normal.
  - Fix: a set that is open at both placements, i.e. compute `c0` for both and take
    `matched & c0_n < 2 & c0_m < 2`. Low, because a true mirror's terrain fit usually dominates.
    No synthetic is ever mirrored, so nothing tests this.

- **[mislabel] Inside the round-2 `old_from` fix.** :1318-1319. The `adjacent` /
  `own_below_threshold` test is `length(setdiff(near, rows)) > 0`, which is the same for both
  sources. Where the neighbours have gated pairs but **no old patches of that source**, which is
  likely for lidar, the old column is still the decade's own sub-threshold one and the CSV says
  `adjacent`.
  - Fix: test `sum(G[setdiff(near, rows), paste0("n_old_", sn)]) > 0` per source.

- **[mislabel] Inside the round-2 `synth_slope` fix.** :819 with :926-927. An aliased fit returns
  `none` with `n` set, so with ≥50 usable patches the status becomes `gated_model_r2`, though no
  model R² was measured. The effect (refused, which counts against the ≥2-of-3 rule) is
  defensible. The status recorded in `dem_parallax_synthetic.csv` is not.
  - Fix: give it its own status, e.g. `gated_aliased`, matched by `^gated`.

- **[fragile] Same class as round 2's `no_dem`.** :1063-1067, :1102-1103. `error:` covers every
  error not wrapped as `transient: catalogue`. That includes deterministic ones:
  - a 200 response that is not an image, caught in `read_gray`;
  - `patch_shifts()` returning NULL into `measure_core`;
  - a geometry error in `vri_classes`.

  None is cached, so one such pair makes Stage 3 stop on every run with *"transient failures;
  run again"*, and Stage 4 can never run. It is loud, but it cannot be cleared by a rerun, and
  the message says it can. Rare: I found no common path into it.
  - Fix: cache an `error:` outcome after N attempts, or name the network errors (VRI) as
    `transient:` and cache the rest.

- **[rule not implemented] Same class as round 2's `source` line, on the write side.**
  :1344-1345 and :1321. Under `STOPPED == "synthetic"`, `dem_parallax_verdicts.csv` still
  carries `source_r_separates`, `source_l_separates` and, per decade, `sources` (SOURCE_OK ∩
  finite D). These are verdict 2's outcome on the sampled pairs, below a stop whose rule is
  "nothing below is read".
  - The round-2 fix gated the printed form on `SYN_OK`, and these are the written form of the
    same fact.
  - This is not the pairs CSV's sufficient statistics (the accepted tradeoff); it is the verdict.
  - Fix: blank them (NA / "") when `STOPPED == "synthetic"`.

- **[minor reporting] :970-972.** The "plain kappa 1 displaced 150 m" summary lists slopes from
  every displaced frame, including those the pair gates refused (e.g. `gated_registration_bound`).
  The per-frame line marks them `(refused)`; the summary that the note will quote does not.
  - Filter on `!grepl("^gated", status)`, or print the status beside each number.

/Users/airvine/Projects/repo/fly/planning/active/review-round3.md
