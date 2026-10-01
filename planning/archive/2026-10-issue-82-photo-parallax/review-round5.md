# Review round 5 — data-raw/dem_measure-photo_parallax.R (HEAD a4cf2d8, algorithm a6)

Read: the whole file at HEAD; the round-4 fix and Amendment C diff (`git diff HEAD~1 HEAD --
data-raw/`); review-round4.md; findings.md ("Decision rule", Amendments A, B and C); the
checklist. `raycast` was read in `dem_measure-coastal_water.R`, and `head_of` plus fly#80's VKEY
in `dem_measure-canopy_height.R`. Probes ran in `scratchpad/r5/` only. Nothing in the repo was run
or edited apart from this file.

Probes:
- `probe_r5.R`, part 2: `split(SYN[pl, ], SYN$case[pl])` with every `dtm_C1` frame refused. Only
  three cases are judged, and `plain_ok` is **TRUE**. With every plain row refused, `plain_ok` is
  also TRUE, because `all(logical(0))` is TRUE (F1).
- `probe_r5b.R`: the class pool's `ix` under `cls_st[[i]] <- NULL`, which deletes a list element
  rather than storing NULL. Over 5,000 random status patterns on the real layout (18 plain rows,
  then 22 class rows):
  - `ix` and the pooled ids equal the gate-admitted frames **every time**. Deletion only ever
    shifts entries that are not yet filled, and the list stays at least as long as its last
    filled index.
  - In 40% of patterns the `&` emits a recycling warning, which is cosmetic (note N1).
- fly#80's key, by reading: one line, `dtm|dsm|source`, the same bytes as the new `CENSUS_KEY`.

## Enumeration (82 rows; 35 changed since round 4: 11 updated, 24 new)

Round 3's mechanism: is the guard evaluated on the same subset, placement, source, resample,
stage and cause as the quantity it protects? **U** marks a row updated since round 4 and **N** a
new row.

| # | guard / gate / filter (line) | protected quantity | same object? | correct? |
|---|---|---|---|---|
| 1 | `stopifnot(VERSIONS$status == "200")` :591 | VKEY, versions CSV | yes. It now covers all three assets | yes |
| 2 U | CENSUS_KEY = key_of(dtm\|dsm\|source) from VERSIONS :603 | census read in Stage 2 | yes, the same bytes as fly#80's VKEY | yes |
| 3 U | VKEY = key_of(3 etags, CENSUS_KEY, ALG) :610 | synthetic, sample and pair caches | yes, the source ETag and census are now in it | **fixed** (F4 r4) |
| 4 | `stopifnot(fp$status == "ok")` :891 | synthetic thumbnails | yes | yes |
| 5 | `register = !flat` :929 | flat synthetics at true placement; class cases registered | yes | yes |
| 6 | `synth_slope` n < 30 :821 / status n < 50 :942 | plain slope | yes | yes |
| 7 | aliased → `g_se = -1` → `gated_aliased` :827, :943 | status label | yes | yes |
| 8 | `gated_model_r2` :944 | slope / class stats R² | yes | yes |
| 9 | `gated_registration_bound` :945 | `m$reg` | yes | yes |
| 10 | `gated_dtm_scale` :946 | g_se of the fit that scales y | yes | yes |
| 11 | `class_phi` n < 30 :843 | per-frame φ, now a diagnostic | yes | yes |
| 12 | `class_phi` `sname` by old count :850 | per-frame φ and φ_VRI, diagnostic | yes | yes |
| 13 U | `refused` :995 → `pl` :997 | pass | one vector for pass and print | yes |
| 14 U | print label :1007-1010 | printed line | reads `refused` and `pass` directly | yes |
| 15 U | `plain_ok` = per case ≥ 2 pass, none fail, over `split(SYN[pl, ], SYN$case[pl])` :1012 | verdict 1, plain half | **no**: the case set is derived from the admitted rows, so a case whose every frame is refused is absent, not failed | **F1** |
| 16 | shrink filter `status == "ok"` :1020 | shrink line | yes | yes |
| 17 | `same` (scale, focal, height of A+1) :1043 | eligibility | yes | yes |
| 18 | spacing in [0.15, 0.7] side :1048 | eligibility | yes | yes |
| 19 | one per roll, N_DECADE :1059-1060 | draw | yes | yes (accepted) |
| 20 | `fetch_pair` non-ok → return :1078 | pair outcome | yes | yes |
| 21 | HTTP 5xx/429 transient :665 | retry vs cache | yes, and it now goes through the sidecar (#63) | yes |
| 22 | `no_global` / `no_dem` / `no_registration` :318, :321, :399 | cached outcome | yes | yes |
| 23 | `open_ok` = `both` & open at both placements :357 | open-branch objective | yes | yes |
| 24 | `use_open` count ≥ 30 :358 | branch choice, both placements | yes | yes |
| 25 U | C-free branch scores `yb` (`both`) :360, :369 | mirror choice via `fit_r2` | yes, one set at both placements | **fixed** (F5 r4) |
| 26 | `register && !is.finite(R$r2)` :399 | chosen placement | yes | yes |
| 27 | `usable()` :424 | regression patches | yes | yes |
| 28 | `n_usable < 50` → `few_patches` :1093 | pair_stats | yes | yes |
| 29 | `q_sd` on usable gp :1088 | weight | yes (and class_phi :847 uses the same form) | yes |
| 30 | VRI bbox ± (patch_m/2 + 200) :1094 | class squares ± (patch_m/2 + 60) | yes | yes |
| 31 | `vri_classes` 90% / 99% / finite r :482, :462, :496 | cls, r | yes | yes |
| 32 U | network regex | — | removed; recurrence decides (#62) | **fixed** (F1 r4) |
| 33 U | `failed:` reaches Stage 4 | the sample | now guarded by #64 | see #64 |
| 34 U | "VRI query" always transient | — | removed; a VRI error goes through the sidecar | **fixed** (F7 r4) |
| 35 | `missing` → stop :1162 | Stage 4 | the same predicate as `todo` | yes |
| 36 | ST NULL for non-ok or gate :1182 | pair_stats | yes | yes |
| 37 | `gate_of` model_r2 :1191 | `st$r2_full` | yes | yes |
| 38 | `gate_of` registration_bound :1192 | `m$reg` | yes | yes |
| 39 | `gate_of` dtm_scale :1193 | g_se | yes | yes |
| 40 | `live` columns :521 | Xf | yes | yes |
| 41 | non-empty dummies :547 | icpt nuisance | yes | yes |
| 42 | `solve_cols` relative keep :562 | b | yes | yes |
| 43 | `solve_vri` keep & finite b :572 | rb | yes | yes |
| 44 | `own_old` ≥ 100 in ≥ 5 pairs :1260 | olds per source | yes | yes |
| 45 | `identical(d_old, d)` reuse :1268-1270 | bo, rbo | yes | yes |
| 46 | SOURCE_OK :1311 | verdict 2 | yes | yes |
| 47 | STOPPED :1318 | everything below | yes | yes |
| 48 | `sources_for` → `combine` for D, PHI, VRI :1376-1379 | pooled estimates | yes | yes |
| 49 | `fail > 0.01` :1382 | verdict | yes | yes |
| 50 | `verdict_of` n ≥ 10 :1347 | verdict | yes | yes |
| 51 U | intercept fit finite **and** `setequal(srcs_i, srcs)` :1392-1394 | MORE/LESS over `srcs` | yes, Di is now pooled over exactly the verdict's sources | **fixed** (F3 r4) |
| 52 U | contradiction keyed on `v` :1395-1396 | MORE/LESS on D_ci | yes | **fixed** (F6 r4) |
| 53 | `old_from` per source :1400 | label | yes | yes |
| 54 | source line under `!SMOKE && SYN_OK` :1313 | printed verdict 2 | yes | yes |
| 55 | decade line under `!nzchar(STOPPED)` :1421 | printed verdicts | yes | yes |
| 56 | synthetic stop blanks source columns :1433 | verdicts CSV | yes | yes (`boot_fail` accepted) |
| 57 | `^(phi\|D)` blanking :1442 | CSV estimates | yes | yes |
| 58 | `if (!SMOKE)` writes :1452 | CSVs | yes | yes |
| 59 N | `both` = matched & !bad₁ & !bad₂ :356 | the set both branches score | yes; `bad` is never NA (raycast initialises FALSE and ORs `is.na`) | yes |
| 60 N | `yb` :360 | C-free R², normal and mirror | yes | yes |
| 61 N | versions CSV rows from VERSIONS + census + ALG :1458 | provenance | yes, the source row is now present | yes |
| 62 N | attempts sidecar: cache only on recurrence of the same message :1117-1127 | retry vs `failed:` | per id, one worker per id, keyed dir | yes (accepted rule) |
| 63 N | `^transient:` statuses through the same sidecar :1118 | retry vs cache | yes | yes |
| 64 N | systematic refusal: `any(table(fails) >= 2)` on the exact message :1170-1174 | "failures are systematic" (a cause) | **no**: it groups on text. A message carrying a pair-specific number (terra's `[crop] too few values for writing: 0 < N`, with N set by the window's cell count; curl's byte and ms counts) is unique per pair whatever its cause | **F2** |
| 65 N | refusal scope `^failed:` only | sample completeness | `thumbnail_http_<4xx>`, `not_one_row` and `no_thumbnail` are cached on first sight and never counted | note N3 |
| 66 N | `st_all` over `SAMPLE$airp_id` :1167 | the set Stage 4 reads (`M`) | yes | yes |
| 67 N | `setequal(srcs_i, srcs)` :1394 | Di covers the verdict's sources | yes | yes |
| 68 N | `v == more && Di_ci[2] < 0`, `v == less && Di_ci[1] > 0` :1395-1396 | B14 "wholly on the other side" | yes | yes |
| 69 N | class pool `ix`: set, offset, **post-gate** `status == "ok"` :965 | pooled XtX | yes. A frame `ok` before gating and gated after carries `gated_*` and is excluded | yes |
| 70 N | `!is.null(cls_st)` under list deletion :935, :966 | alignment of stats to rows | yes (probe: 5,000 patterns, all correct) | yes (warning, N1) |
| 71 N | XtX / Xty / Xtr = Σ `cls_st[ix]$main` :968-970 | pooled b, rb | yes, the same `ix` | yes |
| 72 N | `ncl` → `n_mid`, `n_old` :971, :982 | qualification counts | yes, the same `ix`, from `n_cls` of the same usable `gp` that built XtX | yes |
| 73 N | `n = sum(syn$n[ix])`, label `length(ix) frames` :979-981 | record | yes | yes |
| 74 N | pooled φ = b_mid / b_old, φ_VRI = rb_mid / rb_old :981-982 | Amendment C (β0 = 0) vs Stage 4 `phi_source` | the same formula, with β0 = 0 | yes |
| 75 N | `qual` = pooled row & n_mid ≥ 30 & n_old ≥ 30 :1001 | which source is judged | yes | yes |
| 76 N | pooled pass, NA → FALSE :1002 | pass | yes | yes |
| 77 N | `class_ok`: ≥ 1 qualifying row per offset, all pass :1015-1018 | verdict 1, class half | yes; an empty pool gives FALSE | yes |
| 78 N | `SYN_OK = plain_ok && class_ok` :1019 | verdict 1 | inherits F1 | F1 |
| 79 N | class synthetic gates :942-946 vs real `gate_of` :1191-1193 and few_patches :1093 | "gated as a real pair is" | the same thresholds on the same quantities | yes |
| 80 N | class `src_window(win$wt)` :934 vs real :1096 | radar/lidar split | yes | yes |
| 81 N | class synthetic `q_sd` :847 vs real :1088 | weights in the pool | the same expression on the same usable gp | yes |
| 82 N | print label `(too few patches)` for a non-qualifying pooled row :1010 | printed line | agrees with `qual` | yes |

**Two of the 82 rows are not on the same object, #15 (with #78) and #64.** Both are inside the
latest commit:
- #15 is in the Amendment C rewrite of the plain acceptance.
- #64 is in the round-4 F2 fix.

Both are the round-3 mechanism: a guard computed on a derived subset (the admitted rows; the
message text) while it protects the whole (the case set; the cause). The Amendment C pooled
statistic itself (#69-#77, #79-#81) is clean. Every one of its counts, sums and gates is taken over
the one `ix`.

The 7 round-4 defects (#3, #25, #32, #33, #34, #51, #52) are fixed. #33's replacement is #64.

## Findings

### F1 — [fails toward pass on verdict 1] A plain case whose every frame is refused vanishes from `plain_ok`

**Inside the latest commit** (the Amendment C rewrite of the acceptance), lines 997 and 1012-1014.

- `pl` drops refused rows, and `split(SYN[pl, ], SYN$case[pl])` splits on a character vector, so
  its groups are only the cases that still have a row.
- A case with all three frames gated or unmatched is therefore not judged at all, and `all()`
  over the remaining cases is TRUE.
- If every plain undisplaced row is refused, the split is empty and `all(logical(0))` is TRUE.
  So `plain_ok` passes with **no** plain synthetic measured.
- Probe (`probe_r5.R`): with `dtm_C1` entirely refused, the cases judged are dtm_C0, flat_C0 and
  flat_C1, and `plain_ok` is TRUE. With all plain rows refused, it is also TRUE.
- Amendment B 5 requires each case to have "≥ 2 of its 3 frames measured and passing". Round 4's
  a5 form split `judged`, which kept refused rows with `pass = NA`, so this case scored 0 < 2 and
  FAILED. a6 regressed it.
- This is checklist "Zero-length, empty, and unset" and "A guard that fails toward pass".
- Reach: the a4 run passed every plain undisplaced frame, so it needs the a6 re-run to gate a whole
  case. That run is a fresh cache, because VKEY moved. But this is the instrument verdict, and
  it fails silently toward PASS.

**Fix:** judge every plain undisplaced row and keep the refused rows with `pass = NA`. Split on a
fixed factor so an empty case is present and fails:

```r
pj <- SYN$set == "plain" & SYN$displaced_m == 0
plain_ok <- all(vapply(split(SYN[pj, ], factor(SYN$case[pj],
                         levels = c("flat_C0", "flat_C1", "dtm_C0", "dtm_C1"))),
                       function(z) sum(z$pass %in% TRUE) >= 2 && !any(z$pass %in% FALSE),
                       logical(1)))
```

Keep `pl` for setting `pass` only. Restore-the-bug check: with one case all refused, this
returns FALSE.

### F2 — [silently thinned sample, low-medium] The systematic-failure refusal groups on exact text, so per-pair numbers defeat it

**Inside the latest commit** (the round-4 F2 fix), lines 1169-1173.

- The guard stops only when two or more pairs share a byte-identical `failed:` message. Many
  messages embed a pair-specific number:
  - terra's `[crop] too few values for writing: 0 < N`, which round 4 measured as **the** error
    a cut-off `/vsicurl/` DEM read raises. N is the window's cell count, set by scale and
    location.
  - curl's `… after 10001 milliseconds with X out of Y bytes received`.
  - Paths in `could not write …` / `could not rename …`.
- Each pair whose identical message recurs on its own two runs is cached as `failed:`, with a
  message no other pair shares.
- So a systematic cause (a flaky link over two runs, or a DEM-read defect) produces N distinct
  messages, `table()` counts 1 each, and Stage 4 proceeds with those pairs gated out and no
  refusal.
- That is round 4's F2 outcome, reached through the message text instead of the regex: the
  guard reads the text while the quantity it protects is the cause. Larger windows (smaller
  scales) make more range requests, so the loss is plausibly scale-correlated rather than random.
- The accepted rule (cache on identical recurrence) is not in question. Only the **grouping** of
  the refusal that backs it is.

**Fix:**
- Group on a digit-normalised message, `table(gsub("[0-9]+", "#", fails))`.
- Also refuse when the total `failed:` count exceeds a small bound (for example more than 1% of
  `SAMPLE`, or more than 2 pairs), whatever the grouping.
- Restore-the-bug check: two pairs failing `0 < 12616` and `0 < 20449` must stop.

## Notes (not filed)

- **N1.** `cls_st[[i]] <- attr(cp, "stats")` deletes element i when `class_phi` returns `none`
  (NULL attr). The pool is still correct (probe, 5,000 patterns), but `vapply(cls_st, …)` can be
  shorter than `syn`. The `&` then recycles and warns "longer object length is not a multiple",
  in 40% of patterns. `cls_st[i] <- list(attr(cp, "stats"))` stores NULL and silences it. This
  is cosmetic, but a reviewer reading the log may chase it.
- **N2.** Amendment C, "≥ 30 … in both the undisplaced and the displaced pool": the code
  qualifies each source **per pool**. A source with ≥ 30 mid and old undisplaced but not displaced
  is judged undisplaced only, and the other source can carry the displaced pool. That is a
  defensible reading. The stricter one, a source that qualifies in either pool is judged in
  both, is not what was coded. Confirm the wording or tighten it.
- **N3.** The refusal reads only `^failed:`. `thumbnail_http_<4xx>` is cached on first sight as a
  property of the URL (round 2), so a WAF 403 or a URL-scheme change across many pairs is never
  counted. Including it would also count legitimate missing thumbnails (404s), so scoping it out
  is deliberate. The only record is the `pair status` line of the run that measured them.
- **N4.** A transient that recurs identically, such as `thumbnail_http_503` during a two-run
  outage, is cached as `failed:`. If two pairs share it, every later run stops at the refusal and
  nothing retries it. That is loud, but the stop message does not say to delete the `.rds` files
  to retry. This is within the accepted rule; it is listed only because the recovery is manual.
- **N5.** VRI is queried live per pair and the pairs are cached. Neither VKEY nor the versions CSV
  records the VRI vintage, so pairs measured across a VRI release mix inventories. Each pair's
  `PROJECTED_DATE` keeps its own age arithmetic consistent. Low.

## Rule conformance

- **Decision rule, Amendment A, Amendment B:** all as round 4, plus the following.
  - B14: now applied over the verdict's own source set, keyed on the verdict.
  - B5's "≥ 2 of 3 per case" is **not implemented** for a case with every frame refused (F1).
- **Amendment C:** implemented.
  - The 11 frames match the findings list.
  - Each frame runs undisplaced and displaced 150 m.
  - Each is gated as a real pair is (#79).
  - The pool sums `pair_stats()$main` over exactly the post-gate `ok` frames (#69-#73), as Stage 4
    sums G.
  - φ and φ_VRI are taken with β0 = 0 (#74).
  - The source threshold is ≥ 30 mid and old patches, counted on the same frames as XtX (#72,
    #75).
  - The tolerance is ≤ 0.10, with NA → FAIL.
  - At least one qualifying source is required in each pool (#77).
  - Per-frame φ is kept as a diagnostic.
  - The one interpretive point is N2.
- **Checklist:** "Zero-length, empty, and unset" and "A guard that fails toward pass" (F1);
  "One fact derived twice" / "A proxy is not the property" (F2, the message as a proxy for the
  cause).

**Loop status:** not terminated by enumeration. Two defects remain, both inside the latest
commit's fixes. Both fixes are mechanical and carry their own restore-the-bug checks above.
