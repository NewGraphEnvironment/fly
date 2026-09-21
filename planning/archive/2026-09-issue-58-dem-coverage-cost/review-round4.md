# Review round 4 — fly#58, `dem_elev_sd` and the partial-coverage measurement

Reviewed the **working tree** (not the staged diff — the staged copy is one round behind:
`inst/notes/terrain-correction.md` and `tests/testthat/test-fly_footprint_coverage.R` both
carry unstaged round-3 work, including the whole "every row of the note's published tables
recomputes" test and the widened DEM-vs-nominal table).

Everything was recomputed with `Rscript` from
`inst/extdata/dem_coverage_{sweep,targets,population}.csv`. Non-vacuity of the new
note-table test was established by mutation: every numeric cell of every table in the
section was multiplied by 3 and the suite re-run, one cell at a time (≈150 runs). The note
was restored afterwards and verified byte-identical.

Full suite: **PASS 2096, FAIL 0, ERROR 0, SKIP 0** (`NOT_CRAN=true devtools::test()`).

---

## Findings

- **[fragile]** `tests/testthat/test-fly_footprint_coverage.R:377-485` — the note-table
  test walks **six of the eight** tables in the section, and nothing asserts that it
  walked them all. Its own comment says "so a figure cannot be published here without
  being checked"; that is not what it does. Each table is located by a hand-written header
  regex, so any table whose header is not in the list is simply invisible to it.

  Proven by mutation (×3 on each cell, suite stays green):

  | note line | table | cells no assertion can see |
  |---|---|---|
  | 286 | `\| population \| n \| could reach nodata \| DEM-sized \| under 0.95 \|` | all 11 |
  | 450 | `\| predictor, covered cells only \| Spearman rho vs abs error \|` | all 5 |

  The population table is *transcribed* from `dem_coverage_population.csv`; the test that
  reads that CSV asserts against its own literals, never against the note, so the two can
  diverge silently. The rho table is worse: it is the table that decides **which statistic
  ships**, and two of its five rows — `covered_grad` **0.480** and
  `covered_grad x lost share x side / agl` **0.801** — are asserted nowhere in the suite at
  all (grep confirms; the "coverage cannot separate" test pins only 0.717, 0.185 and
  0.152). 0.801 is the number the sentence "Pooled, the gradient product barely beats
  coverage, and on that alone no column would have shipped" rests on.

  Both recompute correctly today (I get 0.4798 and 0.8009 over the held-out population),
  so nothing is *wrong* — the guard is narrower than the claim it makes about itself.
  Cheapest fix is to terminate by enumeration rather than by listing: count the `|---`
  header rows between `## What a partially covered footprint costs` and `## Testing this`
  and `expect_identical()` that count against the number of tables walked, then add the two.

- **[fragile]** `inst/notes/terrain-correction.md:320-326` — the "Eight are **not**
  recomputable" sentence is paired with "ship so the suite recomputes the figures here from
  the artifact rather than trusting them", which reads as a claim that the complement *is*
  recomputed. It is not. Recomputable-and-published-but-unasserted, all verified by me
  against the shipped CSVs:

  | note figure | recomputes to | what the suite asserts |
  |---|---|---|
  | calibrated bound `4.97`, `95.3%`, `6.1x`, `89.4%` | 4.97067 / 95.263% / 6.082 / 89.364% | nothing |
  | rho table `0.480`, `0.801` | 0.4798 / 0.8009 | nothing |
  | "maximum error difference is **14.79%**" | 0.147907 | nothing (only `length(disagree) < 5`) |
  | "**1,633** runs ... max **0.43%**, 99th **0.11%**, median **0.003%**" | 1633 / 0.004256 / 0.001127 / 3.11e-5 | `sum(both) > 1600`, `max < 0.005` |
  | "**1,856** matched runs" | 1856 | `> 1800` |
  | "**10,248** runs" (analytic agreement) | 10248 | `nrow(u) > 6000` |
  | "`ref_n` is **90,692** natively and **101** on the coarse arm" | frame 215166: 90692 / 101 | only "all 40 differ" |
  | arms "with **zero classification flips**" | 0 of 624 per arm | the flips assertion is native-only |

  The three restricted mechanism figures (0.43 / 0.11 / 0.003) additionally have **no
  producer line in the generator** — `data-raw/dem_calibrate-coverage_error.R:945-949`
  prints only the unrestricted max. That is the identical defect round 3 fixed for the
  within-band block ("it had no producer line at all until a review round recomputed the
  note against nothing").

  Separately, the enumeration of eight may be short by one: the affected film frames'
  **scale range `1:10000 to 1:70000`** (note line 293) is not in any shipped table either —
  `dem_coverage_targets.csv` carries `scale_n` for the 120 sweep targets, not for the 66
  affected catalogue frames. The list names "the 1982-1996 span", which is the other half
  of the same sentence. I confirmed the eight as listed *are* genuinely non-recomputable.

- **[bug]** `R/fly_footprint.R:484-486` and `man/fly_footprint.Rd:45-47` — the `dem_elev_sd`
  NA rule added by round 3 is incomplete, and it omits the **common** case. It says NA
  "wherever `dem_coverage` is, and also where the DEM described only a single cell, since a
  spread needs two". A frame the DEM does not reach gets `dem_coverage == 0` (not `NA` —
  that is deliberate and documented one line above) with `dem_elev_sd == NA`, because
  `sum(!is.na(vals))` is **0**, not 1. Reproduced on the bundled fixture:

  ```
            terrain dem_coverage dem_elev_sd empty
  1         dem_agl            1    23.37762 FALSE
  2 no_dem_coverage            0          NA FALSE
  ```

  1,103 of the 11,520 shipped sweep runs are `no_dem_coverage`, so this is the dominant
  NA-with-non-NA-coverage case, not an edge. A caller who takes the documented rule at its
  word and treats `is.na(dem_elev_sd) & !is.na(dem_coverage)` as "exactly one cell" is
  wrong on every off-DEM frame. "fewer than two cells" is the exact statement, and nothing
  in the suite pins this case.

- **[fragile]** `tests/testthat/test-fly_footprint_coverage.R` — `tolerance = 2e-2` on the
  note-table comparisons is testthat/waldo's **relative** tolerance, so every figure the
  note publishes to three decimals is pinned only to ±2%. Measured: changing Table 1's
  `12.529%` max-abs cell to `12.629%` leaves the suite green (0.79% relative). The five
  other cells I mutated by comparable absolute amounts all went red, so the guard does
  work above 2% relative — but on the large cells (`23.563%`, `12.529%`, `5.755%`) it
  cannot see a wrong last-two-digits. A relative tolerance of `5e-4` still clears the
  rounding of every published cell I checked.

- **[fragile]** `tests/testthat/test-fly_footprint_coverage.R:190-194` — the round-3
  comment justifying the aligned held-out filter states the two spellings "diverge on nine
  rows of the full population". No population I can construct gives nine. `covered_n > 0 &
  is.finite(err)` against `dem_coverage > 0 & is.finite(covered_grad)` differ on **173**
  rows of the raw 11,520, **161** after `ref_ok`, **7** over native, **6** over
  `native_sized`, and **0** over the population actually used (`native_sized & holdout` —
  which is the "select the same rows on today's data" half, and that half is correct).
  Nine is reachable only as `sum(covered_n == 1)` = 9, i.e. the rows where a spread is
  undefined — one direction of the divergence, not the divergence. Nothing depends on the
  number; it is a figure in a comment that does not recompute, in a file whose premise is
  that figures recompute.

---

## Round-3 fixes: verified correct

Each of the eight was re-derived from the shipped CSVs.

1. **The 0.215 correction landed everywhere.** `grep` over `R/`, `man/`, `inst/notes/`,
   `data-raw/`, `tests/` and `NEWS.md` for every two-frame-probe number — `0.215`, `0.204`,
   `3.31`, `6.59`, `8.5%`, `2570`, `112 m` — finds **only** the three deliberate references
   to the correction itself (note line 342, generator line 1012, test lines 238/246/250).
   No probe figure survives as a live claim. The replacement distribution recomputes:
   median gap **-0.000104**, 90th |gap| **0.0549**, max |gap| **0.2842**; the 76 runs within
   0.01 of a 0.30 share have median achieved coverage **0.69895** and none within 0.01 of
   0.215.
2. **The `flipped to:` sub-line.** `sw` is `ref_ok`-filtered at generator line 856, so the
   headline and the sub-line now both run over 7,616 native `na_mask` runs and both report
   **873**, all `no_dem_coverage`, all at coverage exactly 0, none `implausible`. Verified
   the 169 `implausible` runs in the sweep all belong to the excluded target `1154997`.
3. **Arms `flips N of M` is right.** `all_a` is the arm's full `na_mask` population before
   the `dem_agl` filter: native **873 of 7616**, and **0 of 624** for each of coarse /
   geographic / anisotropic. The zero is genuine rather than the old
   zero-by-construction — the arms cut at `cut_u` ≤ 0.80 only (native goes to 0.92), so no
   arm run reaches total loss. The note's "with zero classification flips" holds.
   (Cosmetic only: `n=453 ... flips 0 of 624` puts two different populations on one line.)
4. **`within_sd` pinned at both ends.** Raw 0.385498 and 0.594250 → 0.39 / 0.59 ✓, and the
   gradient's 0.265518 / 0.588970 → 0.27 / 0.59 ✓, `sum(within_sd > within_grad) == 5` ✓.
   All six bands ≥ 30 rows, so the `sum(!is.na(...)) == 6L` premises are live.
5. **The held-out spellings now agree.** Script `ho` (line 964) and test `h` both select
   **2,259** rows and give identical rhos (-0.717104, 0.185080, 0.151920, 0.479825). The
   test's extra `is.finite(covered_grad)` is inert here and strictly safer — the script's
   spelling would admit a `covered_n == 1` row whose `covered_sd` is `NA`, and
   `stats::cor(use = "everything")` would then publish `NA`.
6. **`dem_coverage` rho sign.** −0.717104 ✓.
7. **`dem_elev_sd` NA rule documented** — but see the finding above; it is incomplete.
8. **Eight non-recomputable, enumerated** — the eight named are genuinely not derivable
   from the shipped tables; see the finding above for a possible ninth.

## Also verified against the artifacts

- Premises: 11,520 runs; 240 target rows keyed uniquely on (`airp_id`, `arm`); 120 frames;
  119 `ref_ok` native; 12 strata; 40 holdout; `1154997` excluded, stratum
  `scale_fine/relief_q4` ✓; all 40 coarse `ref_n` differ from native; merge loses no row.
- `fly_dem_coverage_min()`'s comment: 0.794 at 0.95 and 0.94, 1.221 at 0.92, 2.520 at 0.85,
  0.335 / 1.491 / 23.563, signed median under 0.05% to 0.8 — all ✓.
- Roxygen and `.Rd`: 0.18% / 0.34% / 1.5% / 24% / "13 to 52" / "2.3 to 4.1" ✓; the `.Rd` is
  a faithful render of the roxygen with `%` escaped.
- The new warning text's 0.34% / 1.5% / 24% / "2 to 4 times" ✓.
- All 8 rows of the widened DEM-vs-nominal table, including the "DEM worse on" counts
  (0, 0, 3, 7, 24, 62, 97, 229) ✓.
- Calibrated bound, arm medians (0.696 / 0.585 / 0.677 / 0.777), mechanism agreement,
  population census (87 = 22+20+16+8+13+3+5; 66; 26; 2,975) ✓.
- `fly_dem_sample()`: `spread` is read off the same pass as `covered`, `numeric(4)` vapply
  contract is correct, `first`/`second` always carry `spread`, `no_geom` clears it, and the
  column survives the `centroid_shapes()` class sweep (`fly_reported_cols()` updated).
- CSV write: the per-column `quote` selection is correct — `coverage_bin` (`[0,0.5)`) is
  quoted in `dem_coverage_population.csv` and nothing else is; sweep/targets are unquoted
  and read back with the right types. Artifacts total 1.56 MB.

## Housekeeping

- `NEWS.md` has no entry under "# fly (development version)" for #58 / `dem_elev_sd` yet.
  Expected if release bookkeeping happens at merge; flagging only so it is not forgotten.
- Comments at `tests/testthat/test-fly_footprint.R:795` and `:836` still say "the four
  reporting columns" / "All four columns"; there are now six.
