# Review round 4 — data-raw/dem_measure-photo_parallax.R (HEAD 771b573, algorithm a5)

Read: the whole file at HEAD; the round-3 fix diff (`git diff HEAD~1 HEAD -- data-raw/`);
review-round3.md; findings.md "Decision rule", "Amendment A", "Amendment B"; the checklist
(code-check conventions). `raycast`, `save_atomic`, `write_if_changed` and `head_of` were read
in their source scripts. Probes ran in `scratchpad/r4/` only; nothing in the repo was run or
edited apart from this file.

Probes:
- `probe_keep.R`: round 3's singular case through the a5 `solve_cols`. It now solves, with young
  NA when every young patch is a singleton, and young kept (diag 0.325 against a max of 2940)
  when one pair carries two young patches. **The fix works.**
- `probe_net.R`, `probe_flaky.R`: a tiled GeoTIFF on a local range-capable HTTP server, read
  through `/vsicurl/`. In one run the server is killed mid-crop; in the other every third range
  returns 503. Both runs raise the same error, `[crop] too few values for writing: 0 < N`. The
  a5 network regex does **not** match it (F1).
- `probe_icpt_srcs.R`: `sources_for`, `combine` and `verdict_of` evaluated verbatim from the
  file. The primary fit pools r+l; the intercept fit pools r only. The guard does not fire,
  although lidar's intercept-fit interval is wholly below 0 (F3).

## Enumeration (58 rows)

"Same object?" asks whether the guard and the quantity it protects are evaluated on the same
subset, placement, source, resample and stage. R3 marks a round-3 fix.

| # | guard / gate / filter (line) | protected quantity | same object? | correct? |
|---|---|---|---|---|
| 1 | `stopifnot(VERSIONS$status == "200")` :586 | VKEY, versions CSV | yes | yes |
| 2 | CENSUS_KEY (dtm\|dsm\|source) and file exists :597-608 | census read in Stage 2 | yes | yes |
| 3 | VKEY = md5(dtm\|dsm etags, ALG) :587-589 | synthetic, sample and pair caches | **no**: the caches also depend on `mrdem-30-source.tif` (classes, synthetic κ) and on the census (sample) | **F4 (low)** |
| 4 | `stopifnot(fp$status == "ok")` :882 | synthetic thumbnails | yes | yes |
| 5 | `register = !flat` :920 | flat synthetics at true placement | yes | yes |
| 6 | `synth_slope` n < 30 :819 / status n < 50 :932 | plain slope | yes (usable gp) | yes |
| 7 | aliased → `g_se = -1` → `gated_aliased` :825, :933 (R3) | synthetic status label | yes (same lm) | yes |
| 8 | `gated_model_r2` :934 | slope (plain: lm R²; class: pair_stats R²) | yes | yes |
| 9 | `gated_registration_bound` :935 | `m$reg` of the same measure | yes | yes |
| 10 | `gated_dtm_scale` :936 | g_se of the same fit that scales y | yes | yes |
| 11 | `class_phi` n < 30 :841 | φ, φ_VRI | yes | yes |
| 12 | `class_phi` `sname` by old count :848 | φ and φ_VRI on one source | yes | yes (NA → FAIL accepted) |
| 13 | `SYN$pass` refused set :958 | pass | yes, the same literal list as #14 | yes |
| 14 | print label refused set :968 | printed line | agrees with #13 | yes |
| 15 | SYN_OK: ≥ 2 pass, none fail, per case :972-976 | verdict 1 | judged = everything except plain displaced; class displaced included (B5) | yes |
| 16 | shrink filter `status == "ok"` :977 (R3) | shrink line | yes; its complement is exactly the per-frame "(refused)" set | yes |
| 17 | `same` (scale, focal, height of A+1) :1000 | pair eligibility | yes (census rows) | yes |
| 18 | spacing in [0.15, 0.7] side :1005 | eligibility | yes | yes |
| 19 | one per roll, N_DECADE :1016-1017 | draw | yes | yes (design accepted) |
| 20 | `fetch_pair` non-ok → return :1035 | pair outcome | yes | yes |
| 21 | HTTP 5xx/429 transient :663 | cache | yes | yes (408 accepted) |
| 22 | `no_global` / `no_dem` / `no_registration` :318, :321, :395 | cached outcome | yes | yes |
| 23 | `open_ok` = matched & open at **both** placements :354 (R3) | the open-branch objective, normal and mirror | yes | yes |
| 24 | `use_open` count ≥ 30 :355 | branch choice for both placements | yes | yes |
| 25 | C-free branch: `y` = all matched :362-366 | mirror choice via `fit_r2` | **no**: `complete.cases` drops a patch whose ray is `bad` (xy NA) at one placement only, so normal and mirror are scored on different sets | **F5 (low)** |
| 26 | `register && !is.finite(R$r2)` :395 | chosen placement | yes | yes |
| 27 | `usable()` :420-427 | regression patches | yes (the same gp that becomes `patches`) | yes |
| 28 | `n_usable < 50` → `few_patches` :1050 | pair_stats | yes | yes |
| 29 | `q_sd` on usable gp :1045 | weight | yes | yes |
| 30 | VRI bbox ± (patch_m/2 + 200) :1051 | class squares ± (patch_m/2 + 60) | yes, it contains them | yes |
| 31 | `vri_classes`: 90% share, 99% single source, finite r :478, :458, :492 | cls, r | yes (r from the centre stand, by design) | yes |
| 32 | `one()` network regex → `transient:` :1074 (R3) | "a rerun clears it" | **no**: the regex reads the message, not the cause. A failed MRDEM or source read says `[crop] too few values…` | **F1** |
| 33 | `one()` other → `failed:`, cached :1076-1082 (R3) | the Stage 4 sample | **no**: nothing downstream counts `failed:`. A systematic error drops pairs silently | **F2** |
| 34 | `"VRI query"` → always `transient:` :1074 (R3) | "a rerun clears it" | **no**: a deterministic VRI error never clears | **F7 (low)** |
| 35 | `missing` → stop :1116 | Stage 4 | yes, the same predicate as `todo` | yes |
| 36 | ST NULL for non-ok or gate :1126 | pair_stats | yes | yes |
| 37 | `gate_of` model_r2 :1134 | `st$r2_full` | yes | yes |
| 38 | `gate_of` registration_bound :1135 | `m$reg` | yes | yes |
| 39 | `gate_of` dtm_scale :1136 | g_se from the same fit as g | yes | yes |
| 40 | `live` columns :517 | Xf | yes | yes |
| 41 | non-empty dummies :543 | icpt nuisance | yes | yes |
| 42 | `solve_cols` relative keep :557-558 (R3) | b | yes (the same summed XtX) | yes (probe) |
| 43 | `solve_vri` keep & finite b :567-568 (R3) | rb | yes; b comes from the same XtX | yes |
| 44 | `own_old` ≥ 100 patches in ≥ 5 pairs :1201 | olds per source | yes (G rows) | yes (B17) |
| 45 | `identical(d_old, d)` reuse :1211-1213 | bo, rbo | yes | yes |
| 46 | SOURCE_OK: lower bound of sep ≥ 0.15, ≤ 1% fail :1254 | verdict 2 | yes (the same `boot_idx` and `boot_b0` as the decades) | yes (B16) |
| 47 | STOPPED :1261 | everything below | yes | yes |
| 48 | `sources_for` → `combine` for D, PHI and VRI :1319-1322 | pooled estimates | yes (one srcs, one set of weights) | yes |
| 49 | `fail > 0.01` :1326 | verdict | yes (D$bt) | yes (B15) |
| 50 | `verdict_of` n ≥ 10, interval :1289 | verdict | yes (gated pairs in the decade) | yes (B18) |
| 51 | intercept fit not computable → inconclusive :1331-1334 (R3) | MORE/LESS on the primary D over `srcs` | **no**: Di is pooled over `sources_for(pti, bti)`, computed independently, and can be a strict subset of `srcs` | **F3** |
| 52 | contradiction keyed on `sign(D$pt)` :1332 | MORE/LESS, which is keyed on D_ci | **no**: the point against the interval | **F6 (low)** |
| 53 | `old_from` per source :1336-1341 (R3) | label | yes (the same G counts and `own`) | yes |
| 54 | source line printed only under `!SMOKE && SYN_OK` :1256 | printed verdict 2 | yes | yes |
| 55 | decade line printed only under `!nzchar(STOPPED)` :1357 | printed verdicts | yes | yes |
| 56 | synthetic stop blanks `source_*_separates` and `sources` :1369-1375 (R3) | verdicts CSV | yes | yes (see note on `boot_fail`) |
| 57 | `^(phi\|D)` blanking :1378 | CSV estimates | yes (all 22 estimate columns) | yes |
| 58 | `if (!SMOKE)` writes :1388 | CSVs | yes | yes |

Of the 58 rows, **7 are not on the same object.**
- **Three are inside round-3 fixes:** #32, #33, #51. #34 is also inside one, at low severity.
- **#52** sits on a line round 3 rewrote.
- **#25** is the sibling branch of round 3's open-set fix.
- **#3** predates round 3.

The loop has **not** terminated. Round 3's fixes reproduce the mechanism at three sites. In #32
and #34 the guard reads a message's text while the quantity is the error's cause.

## Round-3 fixes, one by one

| fix | verdict |
|---|---|
| relative-information keep in `solve_cols` / `solve_vri` | correct. The probe reproduces round 3's case and it now solves |
| intercept fit not computable → inconclusive | covers only the case where **every** source fails → F3 |
| one open patch set taken from both placements | correct for the open branch; the C-free branch still differs (F5, low) |
| per-source `old_from` | correct |
| `gated_aliased` | correct |
| network vs deterministic error classification | wrong in both directions → F1, F7; and caching removed the refusal → F2 |
| source columns blanked under a synthetic stop | correct |
| shrink filter | correct |

## Findings

### F1 — [silently wrong sample] A network failure in a DEM read is cached as a permanent `failed:`

**Inside the round-3 classification fix.** Lines 1072-1082.

- In Stage 3, `window_of()` (:617) and `src_window()` (:864) read MRDEM through `/vsicurl/`.
- When a range request fails, the error terra raises is `[crop] too few values for writing:
  0 < N`. That was measured twice: once with the server killed mid-read, once with every third
  range returning 503 (`probe_net.R`, `probe_flaky.R`).
- GDAL's own text (`TIFFReadEncodedTile`, `IReadBlock failed`) arrives only as warnings.
- The error message contains none of `curl|http|vsicurl|timeout|connection|resolve|ssl`, so the
  pair is saved as `failed: [crop] …` and **never retried**.
- Stage 4 then runs with that pair gated out. Its `gate` column carries the message, but nothing
  stops or counts it.

This is the "bless an absence forever" that round 1's comment (:1078-1080) exists to prevent,
now reached through the new branch. Its reach is the network: about 450 pairs × 3 remote crops
each, over the same link fly#59 found shared and slow.

**Fix:** do not decide transience from message text for errors raised after `fetch_pair`. Keep
`failed:` uncached for one or two reruns (an attempts sidecar per id), and cache it only when the
same message recurs. Alternatively, add `too few values|IReadBlock|TIFFRead` to the transient set,
but that is a list that will be incomplete again.

### F2 — [fails toward a verdict] `failed:` caching removed the only refusal, so a systematic error is reported as a result

**Inside the round-3 classification fix.** Lines 1076-1082 and 1116-1117.

- Before a5, any non-transient error was left uncached, so `missing` stopped the run. That was
  loud but stuck.
- Now every deterministic error is cached and **Stage 4 proceeds**, with no check on how many
  pairs failed or why.
- The precedent sits in this file, at :93-96. A PSOCK-only defect made **every colour
  thumbnail** fail ("argument of length 0"). Under a5 that is cached as `failed:` for a class of
  pairs, likely concentrated in the later decades. Those pairs leave G, and the verdicts are
  computed on the rest.
- CLAUDE.md records the same event for `mask_measure-interior_zeros.R`: a closure missing on the
  workers made every frame "error". That script **refuses to report** (:156); this one no longer
  does.
- If every pair fails:
  - G has 0 rows, so `solve_cols` returns NA, SOURCE_OK is all FALSE, and `STOPPED = "controls"`.
  - `dem_parallax_verdicts.csv` is written with `source_r_separates = FALSE`,
    `source_l_separates = FALSE` and `stopped = controls`.
  - That is the rule's verdict-2 outcome, "the photos cannot separate canopy…", produced by a
    code defect. (I traced this by reading `summed`, `solve_cols` and the `VERDICTS <- NULL$x`
    path; I did not run it.)

**Fix:** cache `failed:`, but make Stage 4 refuse while any pair is `failed:`. An acknowledged
id list (or an env override naming the count) lets a known-bad thumbnail through. At minimum,
refuse when more than one pair shares an error message, and print the grouped messages.

### F3 — [rule step not implemented; fails toward pass] The intercept sensitivity checks a different source set from the verdict it guards

**Inside the round-3 "not computable → inconclusive" fix.** Lines 1319, 1323 and 1331-1334.

- `srcs <- sources_for(pt, bt)` and `sources_for(pti, bti)` are computed independently.
- The intercept fit loses information first: a class dummy annihilates every singleton, so lidar
  old with scattered single patches is the likely case. A source can therefore pass in the main
  fit and fail the ≤1% rule in the intercept fit.
- Di is then pooled over the remaining sources only. `all(is.finite(Di_ci))` is TRUE, and the
  guard checks a sensitivity that does not include the source driving the verdict.
- `probe_icpt_srcs.R`:
  - main = r+l, D = 0.326 [0.235, 0.412], **MORE**;
  - intercept fit = r only, 0.100 [−0.089, 0.294], so the guard does **not** fire;
  - lidar's intercept fit fails in 5.05% of resamples, and its interval is [−0.599, −0.206],
    wholly on the other side.
- This is round 3's own principle, "a sensitivity that cannot run is not a pass", applied to all
  sources but not to each.

**Fix:** for a MORE/LESS, require `setequal(sources_for(pti, bti), srcs)`, else inconclusive.
Alternatively pool Di over `srcs` and require each source's intercept fit to be finite and fail
in ≤ 1% of resamples.

### F4 — [stale cache, low] VKEY does not cover two inputs its caches depend on

Line 588.

- VKEY hashes the DTM and DSM ETags and ALG.
- The synthetic and pair caches also depend on `mrdem-30-source.tif`, through `vri_classes()`'
  radar/lidar split and the synthetic κ epoch.
- The sample cache depends on the census, whose key (:597-605) includes the source ETag.
- A change to the source layer alone forces a new census (CENSUS_KEY moves), but reuses the old
  sample and pair results built against the old census and source.
- `dem_parallax_versions.csv` also omits the source ETag, though the instrument reads it.

**Fix:** put the source ETag (or CENSUS_KEY) into VKEY, and the source row into the versions
CSV. Low reach, since MRDEM releases move all three together.

### F5 — [fragile, low] The C-free registration branch still scores normal and mirror on different patch sets

**The sibling of round 3's open-set fix.** Lines 361-366.

- The open branch now uses one set, open at both placements.
- The C-free branch scores `y` (all matched) at each placement. `fit_r2` drops rows that are not
  complete cases, and `raycast` returns xy = NA for a ray that is `bad` at that placement only.
- So the two R² values compare different sets, and the comment at :347-349 ("One objective and
  one patch set serve both placements") is false for this branch.
- Reach is small: a bad ray needs DEM nodata inside the 2.4× window, and MRDEM carries the sea as
  values (fly#65).

**Fix:** score both placements on `matched & !rcs[[1]]$bad & !rcs[[2]]$bad`.

### F6 — [low] The contradiction test is keyed on the point estimate's sign, the verdict on the interval

Line 1332, on the line round 3 rewrote.

- MORE means `D_ci[1] > 0`, but the check tests `D$pt > 0`.
- A percentile interval of a ratio estimator can exclude its own point estimate. If it does, or
  if `D$pt == 0`, a contradicting intercept fit is not caught (MORE with `D$pt ≤ 0` checks the
  wrong side).

**Fix:** key on `v`: `(v == "more_canopy_than_vri" && Di_ci[2] < 0) || (v ==
"less_canopy_than_vri" && Di_ci[1] > 0)`.

### F7 — [low] "VRI query" is unconditionally transient

**Inside the round-3 classification fix.** Line 1074.

- `vri_over()` wraps **every** bcdata error as "VRI query failed".
- So a deterministic VRI failure on one pair is never cached, and the run stops on every rerun
  with "transient failures; run again". That is round 3's F5, now reached through the VRI branch.
- No common path into it was found.
- It is resolved by the same attempts sidecar proposed under F1.

## Notes (not filed)

- `boot_fail` (:1345) survives the stop blanking. It is a count of failed resamples, not an
  estimate, so it is harmless, but it is a number computed below a stop.
- The Stage 1 header (:704-707) still gives the κ=1 tolerance as 0.15. The code applies 0.25, as
  Amendment B 5 requires, so the code is right and the comment is not.
- Real pairs whose `crossprod(Xf)` will not invert are labelled `dtm_scale`, round 3's F4 mislabel
  on the real side. I found no reachable cause at these column scales.

## Rule conformance

Decision rule, Amendment A and Amendment B: every step I traced is implemented, with the
exceptions F3 (B14 is not applied per source) and F2 (no refusal on a partial sample; this is a
checklist item, "A guard that fails toward pass", and the precedent of the sibling script, not a
rule step). Steps checked:
- B1-B5, including ≥ 2 of 3 per case with none failing, and κ=1 within 0.25;
- B6-B7, B9-B13, B15-B18;
- the sample frame and draw;
- the pilot exclusion.
