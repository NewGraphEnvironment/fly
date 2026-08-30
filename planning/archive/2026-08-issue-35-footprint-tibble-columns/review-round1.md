# Review round 1 — #35 `st_sf()` drops trailing columns on tibble input

Branch `35-fly-footprint-drops-footprint-basis-and`. Reviewed `git diff main...HEAD`
(tests) + `git diff --cached` (fix + Rd), and the full current text of
`R/fly_footprint.R`, `tests/testthat/setup.R`, `tests/testthat/test-fly_footprint.R`.

Everything below was **measured by running R**, not reasoned about. Scripts are in
`/tmp/flyrev/`. The prior implementation was pulled with
`git show 8585fd5:R/fly_footprint.R` and sourced into an env parented on
`asNamespace("fly")` — not reconstructed from memory.

## Verdict

The fix itself is correct and, on every input I could construct, **byte-identical to
`8585fd5` for plain `data.frame` callers** while adding the four columns for tibble
callers. The five findings below are all in the surrounding material — one false
claim in the in-flight `NEWS.md`, two guard/fixture gaps, one pre-existing type
trap the fix newly exposes, and one process note.

## Findings

- **[fragile]** `NEWS.md:10` (unstaged, written by the concurrent session) — the claim
  that the overwrite change *"makes `fly_footprint(fly_footprint(x))` idempotent"* is
  **false**, and false in the dangerous direction. Measured
  (`/tmp/flyrev/10_idem.R`, `11_idem_tbl.R`):

  | input | `fly_footprint(fly_footprint(x))` |
  |---|---|
  | plain `sf` (20 rows) | **100 rows, silently** |
  | tibble-backed `sf` (20 rows) | error, `Can't recycle input of size 100 to size 20` |

  Cause is pre-existing and identical before and after the fix:
  `sf::st_coordinates()` on POLYGON input returns 5 rows per feature, so
  `fly_rectangles()` builds `5n` geometries; in the `cbind(data.frame(row.names = ...))`
  branch `row.names` is `seq_along(sfc)` = `1:100`, which recycles the 20-row attribute
  frame up to 100. Nothing warns. The overwrite change is a genuine improvement and is
  worth the NEWS line — but the idempotence sentence should be cut or replaced, because
  a reader will take it as licence to re-run the function on its own output.

- **[fragile]** `R/fly_footprint.R:493-496` / `tests/testthat/test-fly_footprint.R` —
  the behaviour change on an input that **already carries** one of the four names has
  no test, in either direction. Measured (`/tmp/flyrev/03_checks.R`, input given
  `footprint_basis = "PRE-EXISTING"` and `dem_coverage = -99`):

  ```
  old (8585fd5): ... footprint_basis, dem_coverage, footprint_basis.1, footprint_terrain, height_agl, dem_coverage.1, geometry   (23 cols)
  new:           ... footprint_basis, dem_coverage, footprint_terrain, height_agl, geometry                                       (21 cols)
  old footprint_basis[1] = "PRE-EXISTING"   new footprint_basis[1] = "Film - BW"
  ```

  The new behaviour is the better of the two — under the old code the documented
  workflow `footprints$footprint_basis != "unknown_format"` read the *caller's* column
  and fly's real answer sat unnoticed in `footprint_basis.1`. But it is (a) silent data
  loss of a caller-supplied column and (b) completely unguarded: a future
  "simplification" back to trailing `st_sf()` arguments would reinstate the `.1`
  duplicate for `data.frame` callers with **nothing in the suite failing**, since the
  class sweep only asserts the columns are present and equal across shapes. Since NEWS
  now advertises this as a deliberate second change, it wants an assertion behind it.

- **[fragile]** `tests/testthat/test-fly_footprint.R` (class-contract test) +
  `R/fly_footprint.R:152-154` (`@return`) — the contract asserted is stronger than the
  one the code provides, and the fixture is structurally unable to show it. Measured
  (`/tmp/flyrev/08_bcdc.R`) on the actual documented source shape:

  ```
  in : bcdc_sf, sf, tbl_df, tbl, data.frame
  out: sf, bcdc_sf, tbl_df, tbl, data.frame        identical(class(out), class(in)) == FALSE
  ```

  So `expect_identical(class(fly_footprint(x)), class(x))` holds for `plain`/`tbl`/
  `grouped` and **fails for a real `bcdata::collect()` result** — which is the caller
  #35 exists for, and which the unchecked "End-to-end against a real `bcdata::collect()`
  result" box in `task_plan.md` is the last defence for. The reordering is pre-existing
  (`sf::st_transform()` does it, not `st_sf()` — verify: `class(st_transform(b, 3005))`
  is already `sf, bcdc_sf, ...` before any of this code runs) and is identical old vs
  new, so it is not a regression. Two consequences worth handling:
  - the new `@return` sentence *"The input's class is preserved"* over-claims for
    exactly that caller — the class *set* survives, the order does not;
  - `NEWS.md:12` attributes the reordering to `sf::st_sf()`. It is `sf::st_transform()`.

  The four columns themselves **do** arrive correctly for `bcdc_sf` (verified TRUE),
  so the fix works; only the stated contract is too strong.

- **[fragile]** `R/fly_footprint.R:384` (pre-existing, newly exposed) — on a **0-row**
  input, `footprint_basis` and `footprint_terrain` come back **`logical`**, not
  `character`, because `ifelse(logical(0), ...)` returns `logical(0)`. Old and new are
  identical here (`all.equal(old(x[0,]), new(x[0,]))` is `TRUE`), so this is not a
  regression — but the fix makes the columns reach tibble callers for the first time,
  and the type is load-bearing for the obvious downstream move
  (`/tmp/flyrev/12_bindrows.R`):

  ```
  dplyr::bind_rows(fly_footprint(x[0, ]), fly_footprint(x))
  #> Error: Can't combine `..1$footprint_basis` <logical> and `..2$footprint_basis` <character>
  ```

  Anyone assembling a per-AOI ledger across queries — the `stac_airphoto_bc` use case
  in the issue — hits this the first time an AOI returns no frames. One line
  (`character(0)` / `NA_character_` seeds, or `rep(NA_character_, n)` before the
  `ifelse`) closes it, and it is cheap to fold in here since the release is already
  about this function's reporting columns.

- **[process]** working tree — a **concurrent session is editing this checkout**
  (`DESCRIPTION`, `NEWS.md`, `planning/active/findings.md` changed *during* this
  review; they were clean at the start). Per CLAUDE.md "Two agent sessions must not
  share one git working tree". Also: I ran `devtools::document()` as part of the
  verification, which regenerated `man/fly-package.Rd` to match their new
  `DESCRIPTION` Title. That file is now modified and unstaged. The regeneration is
  correct — do not revert it — but it is my write, not theirs.

- **[note, not a defect]** `planning/active/task_plan.md` Phase 1 marks
  *"Downstream pass-through: ... `fly_coverage()` / `fly_overlap()` / `fly_filter()` /
  `fly_select()`"* complete, but the implemented test covers only the first three;
  `fly_select()` is not in it. I exercised `fly_select()` (all three modes),
  `fly_summary()` and `fly_bearing()` across plain/tibble/grouped myself
  (`/tmp/flyrev/09_select.R`) — **all pass**, so there is no bug hiding behind the
  checkbox, only PWF drift.

## What I verified clean, and how

Each of the seven questions asked, answered by measurement rather than reading.

1. **Zero-row input** (`/tmp/flyrev/03_checks.R`). Old and new both return without
   error and `all.equal(old, new)` is `TRUE` — same 21 names, same column types,
   same everything. `$<-` on a 0-row tibble with a length-0 RHS is accepted (0
   matches `nrow`), and the four vectors are always exactly `nrow()` long
   (`rep()`/`ifelse()` over length-`n` inputs), so no recycling difference exists to
   find. The only 0-row wrinkle is the `logical` typing above, which is unchanged.

2. **Input already carrying `footprint_basis`** — see finding 2. New behaviour is the
   better one; the risk is that it is untested, not that it is wrong.

3. **Non-sequential row names**, `centroids[c(5, 3, 11), ]` (`/tmp/flyrev/03_checks.R`).
   No reorder, no drop, no misalignment, and old/new `all.equal` `TRUE`:

   ```
   input row.names  5,3,11
   old out          row.names 1,2,3   airp_id 699365,699426,697358
   new out          row.names 1,2,3   airp_id 699365,699426,697358   geometry identical: TRUE
   ```

   The `row.names` reset to `1:n` is `st_sf()`'s own `row.names = seq_along(x[[sf_column]])`
   default and is present in both implementations. Alignment checked independently:
   each output rectangle's centroid equals its input point (`all.equal`, tol 1e-6).
   Repeated on the tibble subset — same geometry, four columns present.

4. **`sf_column` and column ordering** (`/tmp/flyrev/03_checks.R`, `07_odd.R`).
   `attr(, "sf_column")` is `"geometry"` and last in both; `names()`, `row.names()`,
   `class()`, `agr` and `st_crs()` all identical to `8585fd5`, and `all.equal(old, new)`
   is `TRUE`. Re-ran that comparison across seven awkward inputs to make sure the
   `cbind(...)` fall-through branch had not shifted: non-syntactic column name, list
   column, factor column, matrix column, single row, and an input whose sfc is named
   `geom` (which the bundled fixture is — the output is renamed to `geometry` by both
   implementations alike). **All seven: names identical, `all.equal` TRUE.**

5. **Can the sweep pass vacuously?** No. Restored the bug properly — patched **both**
   `asNamespace("fly")` and `as.environment("package:fly")` (the search-path copy is
   what the test file resolves), from the extracted `8585fd5` bytes, and printed a
   proof line before running (`/tmp/flyrev/04_restore.R`):

   ```
   patching 2 environments; search has package:fly: TRUE
   PROOF broken: footprint_basis in names(fly_footprint(tbl)) == FALSE (must be FALSE)
   -> test-fly_footprint.R goes red, 10-failure cap reached ("... and 13 more")
   ```

   On the specific sub-questions asked:
   - The `plain` iteration of `expect_identical(names(out[[nm]]), names(out$plain))`
     **is** a self-comparison that cannot fail, as are the per-column and
     `st_geometry()` comparisons for `nm == "plain"`. This does **not** make the test
     vacuous, because the guard is carried by the separate absolute assertion
     `expect_true(all(reported %in% names(out[[nm]])))`, which is a real check for
     every shape including `plain`. Three no-op assertions out of ~30; worth knowing,
     not worth changing.
   - No comparison is over an empty set. Measured (`/tmp/flyrev/05_vacuity.R`):
     `fly_filter` 20 rows, `fly_coverage` 1 row with `covered_km2 = 24.8`,
     `fly_overlap` 61 pairs, and in the `dem` sweep `any(footprint_terrain == "dem_agl")`
     `TRUE` with 20 non-`NA` `dem_coverage` — the premise assertions in that test are
     real and do reach the terrain code.
   - The `stopifnot()` premise in `centroid_shapes()` **is** reachable (evaluated on
     every one of the four calls) and rots in the safe direction: if `sf` ever makes
     `st_read()` tibble-backed by default, `!inherits(plain, "tbl_df")` fires and names
     the premise instead of the behaviour. One asymmetry — it asserts the `plain`/`tbl`
     premises but not `inherits(grouped, "grouped_df")`, so the third shape has no
     premise of its own.
   - The class-contract test and the consumer pass-through test both pass on the broken
     code (confirmed in the restore run). The first is explicitly commented as such; the
     second is a forward guard rather than a #35 regression guard and is not labelled,
     which is a smaller version of the same thing.

6. **`.data$scale` in `dplyr::group_by()`** — safe. Verified two ways rather than by
   reasoning about imports. In `R_DEFAULT_PACKAGES=base Rscript --vanilla` with
   **nothing attached but base** (`/tmp/flyrev/06_data_pronoun.R`), `group_by(df, .data$scale)`
   succeeds — `.data` comes from rlang's data mask, not the search path
   (`exists(".data")` in globalenv is `FALSE`). And the full `R CMD check` runs
   `testthat.R` clean: **Status: OK, 0 errors | 0 warnings | 0 notes**, tests `[78s/84s] OK`.

7. **Other `st_sf()` sites** — `grep -rn "st_sf(" R/` gives exactly two.
   `R/fly_footprint.R:64` is `st_sf(geometry = rects[ok])`, a bare geometry frame that
   attaches nothing to user data and cannot hit the branch. The other is the fixed one.
   I also swept the adjacent mechanisms rather than trusting the `st_sf` grep:
   `cbind` / `bind_cols` / `st_set_geometry` have no hits; columns are attached to
   user-supplied objects by `$<-` at `fly_coverage.R:34`, `fly_select.R:118,207-208`,
   plus `fly_bearing.R` and `fly_georef.R` — which is the same mechanism the fix
   adopts, so none are affected. Confirmed empirically by running `fly_select()`
   (minimal / all / component_ensure), `fly_summary()` and `fly_bearing()` against all
   three class shapes: no errors, correct classes out.

## Other checks

- Full suite: **FAIL 0 | WARN 0 | SKIP 0 | PASS 275** (baseline in `findings.md` was 225).
- `lintr::lint("R/fly_footprint.R")`: no lints, and no lints on the `HEAD` baseline
  either — no change in lint count.
- `devtools::document()` printed no `Writing '<x>.Rd'` for an unexpected file;
  `NAMESPACE` unchanged, `grep -c "^export("` still 9, `export(fly_footprint)` present
  — the roxygen block did not rebind.
- The staged `man/fly_footprint.Rd` is in sync with the roxygen source (re-running
  `document()` produced no further diff to it). Its non-ASCII em-dashes match 18
  already present in that file at `HEAD` and in four other `.Rd` files, and
  `R CMD check` is clean.
