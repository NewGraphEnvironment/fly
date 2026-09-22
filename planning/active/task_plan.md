# Task: fly has no R-CMD-check workflow, so a green PR check only means pkgdown built (#52)

`.github/workflows/` holds only `pkgdown.yaml`, so a green PR check on `fly` means the
docs site built. It does not mean `R CMD check` passes, that the 24-file test suite runs
anywhere but the author's machine, or that the examples still execute. v0.9.0 changed
three exported functions on that evidence alone.

Outcome: `R CMD check` runs on ubuntu, macOS and Windows at R release for every push to
`main` and every PR, gating at WARNING, with the package clean at that level on arrival.

## Decisions taken at the plan gate

- **Matrix: three platforms at R release** — ubuntu, macOS, Windows. `fly` calls GDAL
  through `sf::gdal_utils()` for warp, translate and `nearblack -alg floodfill`, which
  needs GDAL >= 3.7, and the three platforms ship different GDAL builds. R devel and
  oldrel-1 are dropped: this package is not going to CRAN, and oldrel-1 (R 4.4) is far
  above the declared `Depends: R (>= 4.1)`, so it would not test that claim either.
- **Fix the pre-existing WARNING in this PR and gate at `error-on: '"warning"'`** (the
  action default) rather than gq's `'"error"'` + follow-up issue. gq#51 has been open
  since.

## Phase 1: Measure the check before writing any workflow

- [ ] Run `devtools::check(args = c("--no-manual", "--as-cran"))`, capture output under
      the scratchpad, grep for `WARNING|NOTE|ERROR`
- [ ] Record every WARNING and NOTE verbatim in `findings.md`, each with a verdict:
      fix now / accept as NOTE / out of scope
- [ ] Record the wall-clock the check took — it sets the expectation for three runners
- [ ] Confirm the predicted em-dash WARNING and `utils`/`stats` NOTE actually appear.
      If either does not, say so rather than carrying the prediction forward

## Phase 2: Clear what Phase 1 found, so the gate can sit at WARNING

- [ ] Replace em dashes in the **string literals** of `R/fly_footprint.R`,
      `R/fly_georef.R`, `R/fly_mask.R` with `--`. Comments and roxygen untouched — the
      check does not see them
- [ ] Add `stats` and `utils` to `DESCRIPTION` Imports
- [ ] `devtools::document()`, reading what it prints
- [ ] Full suite green, confirming no test regex was crossing an em dash
- [ ] `devtools::check()` reports **0 WARNINGs**; residual NOTEs recorded with a reason
- [ ] `/code-check`, commit

## Phase 3: Add the workflow

- [ ] `.github/workflows/R-CMD-check.yaml` — 3-platform matrix at R release, default
      `error-on`, comments recording why three platforms, why `error-on` is left alone,
      and why the network examples are left unguarded (with file:line evidence)
- [ ] A **"Report skipped tests"** step, `if: always()` — `test-fly_camera_patb.R`
      carries `skip_on_ci()` by design and two `test-fly_georef.R` blocks skip on an
      unreachable catalogue, so without this a green tick cannot be told from a run that
      executed neither
- [ ] `/code-check`, commit
- [ ] Push and open the PR

## Phase 4: Read the first run, then close out

- [ ] Poll sparsely with `gh run view <id> --json status,conclusion` — never
      `gh run watch`
- [ ] All three jobs green. A macOS/Windows failure is a real GDAL portability finding,
      recorded and filed, not a reason to weaken the gate
- [ ] Read each job's skip report; record what skipped where. A platform-specific skip
      is a finding
- [ ] `NEWS.md` line + version bump as the final commit of the branch
- [ ] `/planning-archive`

## Out of scope

- A lint workflow (`.lintr` exists; separate gate, separate issue)
- `^\.git$` in `.Rbuildignore` — real, one line, prescribed by `code-check-r.md`, but not
  needed for this check to pass. Named in the PR description rather than folded in
- Guarding the network examples — they already degrade to `success = FALSE`, and
  `--as-cran` runs `\donttest{}` examples anyway

## Validation

- [ ] Three jobs green, read from `gh run view <id> --json status,conclusion,jobs`
- [ ] The gate is shown reachable, not decoration: a WARNING that *was* present in
      Phase 1 and is gone in Phase 2
- [ ] The skip report is non-empty on every runner (`skip_on_ci()` guarantees one)
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
