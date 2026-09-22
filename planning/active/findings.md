# Findings — fly has no R-CMD-check workflow (#52)

## Issue context

## What changes if we do it

CI actually checks the package. Today `.github/workflows/` holds **only** `pkgdown.yaml`, so a green PR check means the docs site built — not that `R CMD check` passes, not that the test suite runs on any machine but the author's. Adding `usethis::use_github_action("check-standard")` closes that.

## What happens if we never do

Every "CI green" on a `fly` PR keeps meaning less than it reads. The exposure is concrete rather than theoretical: v0.9.0 (#49) changed `fly_footprint()`, `fly_bearing()` and `fly_georef()`, and the only evidence the package still checks was a local `devtools::test()` run. A broken `@examples` block, a missing `Suggests`, or a platform-dependent failure would reach `main` and surface for whoever installs from GitHub.

It also silently weakens two conventions this repo already relies on. `code-check-r.md` records that `skip_on_cran()` does **not** skip on GitHub Actions — advice that presumes there is a CI run to skip in. And `ci-monitoring.md`'s session-start sweep is a backstop for failures nobody watched, which cannot catch what never runs.

## Notes

- `r-lib/actions`' check workflow sets `cancel-in-progress: true`, so expect the cancelled-run case `gh-pr-merge` step 10 already handles.
- Worth deciding at the same time whether the matrix is release-only or includes oldrel/devel. `fly` depends on sf/terra, so the runner cost is not trivial.
- Two tests added in #49 hit the network (`fly_fetch()` against the public catalogue). They are guarded by `skip_if_offline()` and a `skip_if_not(all(fetched$success))`, but a CI run is where that guarding gets tested for the first time.


## Measured during planning (read-only, before any change)

All verified against the tree at `de045d7`.

### A WARNING is already there

Parsing every file in `R/` and deparsing — which drops comments, so this is what
`R CMD check` actually sees — finds em dashes inside **string literals**:

| file | count |
|---|---|
| `R/fly_footprint.R` | 6 |
| `R/fly_georef.R` | 1 |
| `R/fly_mask.R` | 1 |

gq hit the identical class and it was a WARNING there, with `Encoding: UTF-8` declared
exactly as `fly` declares it (`gq/DESCRIPTION:16`). At the action's default
`error-on: '"warning"'` this would be red on arrival — which is why Phase 2 clears it
rather than relaxing the gate (gq#51 took the other route and has been open since).

### No test greps across an em dash

The two regexes near those strings sit clear of them:

- `"no flight bearing"` — `test-fly_georef.R:180`, `test-fly_georef_digital.R:168`
- `"per-roll property"` — `test-fly_georef.R:215`

Read, not run. To be re-confirmed by the suite in Phase 2.

### A NOTE is likely too

`R/` uses `utils::` (`download.file`, `head`, `read.csv`, `unzip`) and `stats::`
(`ave`, `sd`); neither is in `DESCRIPTION` Imports. That is the
`'::' or ':::' import not declared from` NOTE.

### Network paths degrade to skips, not failures

Three examples (`fly_fetch`, `fly_georef`, `fly_mask`) and one vignette chunk hit the BC
catalogue with no guard, and `R CMD check` runs all of them. None errors on an outage:

- `fly_fetch()` returns `success = FALSE` — `R/fly_fetch.R:104`
- `fly_georef()` skips a failed row — `R/fly_georef.R:314`
- `fly_mask()` has an explicit zero-length return whose own comment names the roxygen
  example as the caller that reaches it — `R/fly_mask.R:98`

The two network *tests* are `skip_if_offline()` + `skip_if_not(all(fetched$success))`
guarded. So the exposure is the opposite of a red build — a **silent skip**. That is what
the "Report skipped tests" step in Phase 3 exists for.

### The catalogue is reachable from a GH runner

`pkgdown.yaml` already builds the vignette, including its `fly_fetch()` chunk, and the
last four runs are green (checked 2026-09-21).

### House precedent is split

| repo | shape |
|---|---|
| gq | ubuntu-only, `error-on: '"error"'` with a documented pre-existing WARNING |
| rfp | ubuntu-only, default `error-on`, extra source-checkout step, **"Report skipped tests"** |
| spacehakr | full 5-runner r-lib matrix, defaults |

The skip-report step is taken from rfp.

## Errors Encountered

| Error | Resolution |
|-------|------------|
