# Task: fly_footprint() drops footprint_basis and friends when input is a tibble (as bcdata returns) (#35)

## Problem

`fly_footprint()` silently drops `footprint_basis`, `footprint_terrain`,
`height_agl` and `dem_coverage` when its input carries the `tbl_df` class.

`bcdata::collect()` returns exactly that class, so every caller querying
`WHSE_IMAGERY_AND_BASE_MAPS.AIMG_PHOTO_CENTROIDS_SP` — the documented source for
this package — loses the whole reporting surface 0.4.0 and 0.5.0 added. The
warning still fires, so the count is visible in the console and nowhere else.

Mechanism: `sf::st_sf()` keeps only its **first** argument when that argument is
a tibble, discarding every trailing named column
(`else if (inherits(x[[1]], c("tbl_df", "tbl"))) x[[1]]`). One call site,
`R/fly_footprint.R:482`. Baseline before any change: FAIL 0 | PASS 225.

## Phase 1: Regression tests first (must fail on unmodified source)

- [x] Add `centroid_shapes()` to `tests/testthat/setup.R` — plain / tibble /
      grouped shapes of the bundled fixture, via `sf::st_read(as_tibble = TRUE)`
      rather than class hacking, with the premise asserted inline
- [x] Class-shape sweep in `test-fly_footprint.R`: all four columns present in
      every shape; `names()` identical across shapes; the four columns' **values**
      identical across shapes; output class equals input class with `sf` present
- [x] Repeat the sweep with `dem = testdata_path("dem.tif")` behind
      `skip_if_no_terra()` — all four columns come from the same `st_sf()` call
- [x] Downstream pass-through: a tibble-backed footprint still flows through
      `fly_coverage()` / `fly_overlap()` / `fly_filter()` / `fly_select()`
- [x] **Confirm the sweep fails on unmodified `R/`** before touching the source

## Phase 2: The fix

- [x] `R/fly_footprint.R:482` — assign the four columns onto the attribute frame,
      then one-arg `sf::st_sf(attrs, geometry = ...)`. Preserves the caller's
      class; chosen over `as.data.frame()`, which additionally downgrades a
      bcdata caller's tibble
- [x] Comment names the `st_sf()` branch and #35, so the next reader does not
      "simplify" it back
- [x] Restore the bug and confirm the sweep goes red — patching **both**
      `asNamespace("fly")` and `as.environment("package:fly")`, from
      `git show 8585fd5:R/fly_footprint.R` rather than from memory
- [x] Full suite green, PASS above the 225 baseline

## Phase 2b: Review findings folded in

Both reviewers ran independently against the branch; every claim below was
reproduced before acting on it.

- [x] `@return` and the class test over-claimed — `identical(class(out), class(in))`
      is FALSE for `bcdc_sf`, because `st_transform()` (not `st_sf()`) moves `sf`
      to the front. Assert the class *set*, add the `bcdc` shape the fixture
      lacked, and correct the `@return` and NEWS wording
- [x] The non-terra sweep compared constants and all-`NA`, so only *absence* made
      it fail. Sweep the mixed-media fixture too, where `footprint_basis` varies
      and reaches `unknown_format`
- [x] The collision behaviour was unguarded: the old code appended
      `footprint_basis.1` and left the caller's value under the documented name,
      so the prescribed filter read the wrong column. Now asserted
- [x] 0-row input returned `footprint_basis`/`footprint_terrain` as `logical`
      (`ifelse(logical(0), ...)`), so an empty result would not bind to a
      populated one — the per-AOI ledger in the issue. Seeded with
      `as.character()` and guarded
- [x] Downstream test used `by = "photo_year"`, which is one group on this
      fixture. Switched to `by = "scale"` (two), added non-degeneracy premises,
      and added the `fly_select()` the checkbox claimed
- [x] Cut a false NEWS claim: `fly_footprint(fly_footprint(x))` is **not**
      idempotent — a plain 20-row sf returns 100 rows silently, because
      `st_coordinates()` on polygons yields 5 rows per feature. Pre-existing and
      unchanged, but the sentence invited the round trip

## Phase 3: Document the contract

- [x] `@return` in `R/fly_footprint.R` states the input's class is preserved
- [x] `devtools::document()` — read its output; an unexpected `Writing '<x>.Rd'`
      or a falling `grep -c "^export(" NAMESPACE` means a roxygen block rebound
- [x] `lintr::lint_package()` compared against the `HEAD` baseline per file

## Phase 4: DESCRIPTION Title (#31, folded in)

- [x] Widen `Title:` and `Description:` to cover fetch and georeferencing
- [x] `devtools::document()`; `devtools::check()` for the title-case rules

## Phase 5: Release v0.5.1

- [ ] `NEWS.md` — name the class, the data source it breaks, and that geometry
      and downstream numbers were always correct (reporting loss only)
- [ ] Bump `DESCRIPTION` to `0.5.1` as the **final** commit of the branch
- [ ] Tag `v0.5.1`

## Validation

- [ ] Tests pass
- [ ] `/code-check` clean on each commit
- [ ] End-to-end against a real `bcdata::collect()` result — the case the
      fixture structurally cannot reach
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
- [ ] Post-merge, confirm the pkgdown deploy commit is the new `HEAD`

## Out of scope — file as follow-ups

- The `st_sf()` trailing-column behaviour as a `conventions/code-check.md` entry
  in `soul`, plus a grep across the other NGE packages. General R trap, belongs
  in `soul`, not on this branch.
