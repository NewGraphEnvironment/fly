# Review round 2 — data-raw/dem_measure-photo_parallax.R (HEAD 44f72d8)

Reviewed the whole file at HEAD and the round-1 fix diff (`git diff 5675ca8 HEAD`). The only
probe was a scratch R file (`scratchpad/probe_r2.R`). Nothing in the repo was run or edited apart
from this file.

## Findings

- **[bug: wrong verdict] Inside the round-1 `combine()` fix.** :1238-1253, consumed at
  :1285-1291. The fix drops a source only when its bootstrap variance is non-finite or its
  *point* estimate is NA. A source that is kept can still be NA in some resamples, and then
  `sum(wv * c(D_r, NA))` is NA for that resample.
  - Typical case: lidar mid (or old, via `near`) patches in only k pairs of the decade. A pair
    is absent from a within-decade resample with probability about e^-1. So about e^-k of the
    resamples have no `mid_l` estimate.
  - For k ≤ 4 that exceeds 1%, so `fail > 0.01` and the decade is `inconclusive`. Radar alone
    would have decided it.
  - Adding a handful of lidar patches therefore turns a conclusive decade inconclusive. Lidar
    is the BC minority, so this is the likely shape in most decades, the same defect round 1
    found, now one axis over (per resample instead of per point).
  - `SOURCE_OK` already applies the right test on the pooled set (`mean(!is.finite(sp)) <=
    0.01`). Apply it per decade, or drop a source's NA per resample and renormalise the
    weights.
  - Secondary: `has_pt` is evaluated per `which`. When `phi` is finite and `phi_vri` is not,
    D drops the source while PHI keeps it, so the reported `D` is not `phi − phi_vri` over the
    same sources. Rare.

- **[bug: rule not implemented] Inside the round-1 STOP fix.** :1227-1235. The per-decade `pub`
  and the phi/D columns are now gated on `STOPPED`. The per-source line is not:
  `source %s: old - bare %.3f [%.3f, %.3f]`.
  - `STOPPED` is assigned only after the loop (:1236), so under a **synthetic** STOP
    (verdict 1) the script still prints b_old − β0 with its bootstrap interval for both sources.
  - That is a canopy slope from sampled pairs, read below a stop whose rule is "nothing below
    is read".
  - It is legitimate output only when the stop is `controls` (verdict 2 is that number). Gate
    it on `SYN_OK`.
  - Note, not necessarily a defect: `dem_parallax_pairs.csv` is still written under STOP, with
    every pair's XtX/Xty/Xtr. Those are sufficient to recompute the blanked phi and D.

- **[fragile] Inside the round-1 mirror-objective fix.** :338-353, :387-388. `use_open` is now
  fixed from the normal placement, but `open_ok` (and so `yr`) is still recomputed from each
  placement's own `c0`. So with open-ground registration, normal and mirror R² are still taken
  over **different patch sets**.
  - Normal might have, say, 200 open patches and mirror 31-40. A mirror set below 30 makes it
    lose by NA, which is fine.
  - The maximum R² over 441 grid offsets plus Nelder-Mead on ~35 points with 6 regressors is
    biased upward against the same search on 200. On low-relief ground, where the quadratic
    carries most of the R², a wrong mirror can win.
  - That places every patch's C at the wrong ground point.
  - Fix: fix the patch set as well as the objective, by scoring the mirror on the normal
    placement's `open_ok` patches.

- **[fragile] Inside the round-1 "transient not cached" fix.** :321, :649-650, :939-941, :1056,
  :1092. These are labelled transient but are not:
  - `no_dem` is now `transient: no_dem`. The DEM window is already in memory (`crop(...) * 1`),
    so a non-finite DTM at A's centroid is a property of the data, not of the network. A sampled
    pair whose centroid sits on a nodata cell is never cached. Stage 3 then stops on every run
    with "pairs not measured (transient failures); run again", and Stage 4 can never run.
  - The same holds for any non-404 HTTP status from a thumbnail: 403 and 410 are labelled
    transient.
  - In Stage 1 the same status goes the other way. `transient: no_dem` is not `ok`, not gated
    and not refused, so `SYN$pass` makes it FALSE, a **FAIL**. That FAIL is saved in
    `synthetic_<VKEY>.rds`, which turns it into a permanent `STOPPED = "synthetic"`. This is
    the cache-blesses-a-failure defect round 1 fixed for Stage 3, reproduced in Stage 1.
  - Reachable in practice mainly through the displaced class cases, where `measure_core` reads
    e_w 150 m from where `synth_pair` read it.
  - These all fail loudly rather than silently, but they cannot be cleared by "run again".

- **[fragile] Inside the round-1 `.part` fix.** :641. The part name is deterministic
  (`<dest>.part`), and `THUMBS` is shared by the smoke and real runs (:60). Two processes
  fetching the same thumbnail both open the same `.part`, and the second truncates the first's
  inode mid-write.
  - The first to finish renames a file that can still hold zero-filled ranges. It is then
    cached with `size > 0` and read as a complete JPEG.
  - The second then fails `file.rename` → `stop`.
  - Use a unique temp name in the same directory, e.g. `tempfile(tmpdir = THUMBS)`.
  - `save_atomic()` (fixed `<path>.part`) has the same exposure on the shared `ROLLS` cache.
    That code comes from fly#80 and is accepted, but the shared directory is this script's.
  - This only bites with concurrent runs, but two are running now.

- **[fragile: silently wrong number] Round 1's premise behind the NA → FAIL fix.** :807-813.
  `synth_slope()` reads the C slope as `cf[k, ]` and g as `cf[k − 1, ]` from
  `summary(fit)$coefficients`. `summary.lm` **drops** aliased coefficients rather than
  returning NA.
  - Probed: with C aliased, row k is `Ndtm` and row k−1 is the previous nuisance term, so
    "slope" = DTM coef / that term's coef = 439.1, finite.
  - The new `!is.finite(slope) → FAIL` guard therefore cannot see the aliased case round 1
    named as one of its NA sources.
  - This needs a degenerate C (constant over the usable patches), so it is unlikely on the
    three forested SYN frames. Use `coef(fit)[c("gp$C", ...)]` by name, or check
    `any(is.na(coef(fit)))`.

- **[fragile: mislabel] Inside the round-1 `old_from` fix.** :1268-1270, :1297. The label now
  follows `own`, but behaviour did not change when `near` adds nothing:
  - the `all` row always (`near = rows_all`);
  - a decade with no gated pairs in its neighbours.

  There the old column is the decade's own sub-threshold one, and the CSV says `adjacent`.
  Round 1's "own" mislabel became an "adjacent" mislabel. Label the case as its own state.

## Checked and clean

- `ystar` via `vapply(..., numeric(nrow(gp)))`: every branch has length n. Dropping the old
  `ystar[!is.finite] <- 0` is safe because `vri_classes()` now turns every mid/old with
  non-finite r into `other`, and `usable()` guarantees finite C. With nrow(v) = 0, r is all NA
  but cls is already all `other`.
- STOP indices: `< 1`, `< 2`, `< 3`, `< 4` after stages 0-3.
- `to_full()`: coarse k ↔ image row `1 + (k − 1)·st`. The column-major order matches
  `expand.grid(r = rs, c = cs)`. `interp()` now sizes from `M`, and its other two callers
  (`sr`, `a`) are nr × nc. Edge rows extrapolate as constants.
- The synthetic gate order and thresholds match `gate_of()`. `no_global` / `no_registration`
  are refused per Amendment B item 5. An NA phi, phi_vri or slope with status ok is FAIL. For
  class rows, `kappa == 0` is evaluated but not selected.
- `rotate = FALSE`: `par[3]` is zeroed inside the objective and on the result, and both the
  Stage 1 and Stage 3 callers take the default. The rotation gate is now vacuous, as intended.
- PSOCK exports: `vri_over` is now defined before Stage 1 and is exported. No new global is
  referenced from the worker path.
- `measure_pair`: catalogue and rename errors are transient, VRI errors are `error:`, and
  neither is cached. 404 is cached as definitive.
- STOP blanking: `^(phi|D)` hits every estimate column and not `decade`, and
  `VERDICTS[est] <- NA_real_` recycles correctly.

/Users/airvine/Projects/repo/fly/planning/active/review-round2.md
