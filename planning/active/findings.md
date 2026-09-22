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

> **Superseded by Phase 1 below.** The WARNING is real; the file list here is not. Only
> `R/fly_mask.R` is flagged. Kept because *why* the probe was wrong is the finding.

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

> **Wrong — superseded by Phase 1 below.** `checking dependencies in R code ... OK`.
> `utils` and `stats` are base packages and need no `Imports` entry.

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

## Phase 1 — the check as actually run (2026-09-21)

Command, chosen to mirror `r-lib/actions/check-r-package@v2`'s defaults exactly:

```r
rcmdcheck::rcmdcheck(args = c("--no-manual", "--as-cran"),
                     build_args = c("--no-manual"),
                     error_on = "never")
```

`document = FALSE` equivalent — run through `rcmdcheck` directly rather than
`devtools::check()`, so the measurement is of the tree as committed at `81da1d0` and not
of the tree after roxygen has been re-run over it.

| | |
|---|---|
| errors | **0** |
| warnings | **1** |
| notes | **1** |
| elapsed | **243 s** on this machine, macOS, with the network up |

### WARNING 1 — non-ASCII in code, and it is ONE file, not three

```
checking code files for non-ASCII characters ... WARNING
Found the following file with non-ASCII characters:
  R/fly_mask.R
```

**Verdict: fix now.** One character, `R/fly_mask.R:293`, written as `\u2014`.

**The planning prediction was wrong and the reason is worth keeping.** It named three
files. `R/fly_footprint.R` and `R/fly_georef.R` are clean — they already carry eleven
`\u2014` escapes between them, which is exactly the remedy `R CMD check` recommends. The
probe that produced the wrong answer parsed each file and ran `deparse()` over the parse
tree, and **`deparse()` renders `\u2014` back as a literal em dash** — so it measured its
own un-escaping and reported the fix as the defect.

What the check actually runs is `tools:::.check_package_ASCII_code(dir, FALSE)`, which is
line-based over the raw file and skips comments. Run directly on the source tree it
agrees with the check:

```
respect_quotes = FALSE: R/fly_mask.R      <- what R CMD check uses
respect_quotes = TRUE:  character(0)
```

So the honest probe for this class is that function, not a parse-and-deparse. Every other
non-ASCII character in `R/` — 97 lines in `fly_footprint.R`, 52 in `fly_georef.R`, 29 of
the 30 in `fly_mask.R` — is in a comment, which the check exempts.

### NOTE 1 — CRAN incoming feasibility

```
New submission
Found the following (possibly) invalid URLs:
  https://github.com/NewGraphEnvironment/airbc             (-> .../diggs)     200
  https://newgraphenvironment.github.io/fly/               (-> www.newgraph...) 200
  https://newgraphenvironment.github.io/fly/articles/...   (-> www.newgraph...) 200
  https://newgraphenvironment.github.io/fly/reference/     (-> www.newgraph...) 200
```

**Verdict: accept as a NOTE.** It only exists under `--as-cran`, `fly` is not going to
CRAN, every URL returns 200, and the redirect is the org's own domain setup rather than
anything this package controls. It does not reach the `error-on: "warning"` gate.

### The `utils` / `stats` NOTE predicted in planning did NOT appear

`checking dependencies in R code ... OK`. `utils` and `stats` are base packages, always
available, and `R CMD check` does not require them in `Imports` to use `utils::`. **The
prediction was wrong, and the `DESCRIPTION` edit it implied is dropped from Phase 2** —
adding two Imports that nothing requires would have been a change with no reason behind
it.

### Everything else passed

Examples: OK — including the three that fetch thumbnails. Tests: OK. Vignette rebuild:
OK. So the only thing standing between this package and a gate at `error-on: "warning"`
is one character.

### What 243 s means for three runners

The local run had every dependency installed already. A cold runner adds dependency
install on top, which on macOS and Windows is CRAN binaries and on Linux is public RSPM
binaries. The three jobs run in parallel with `fail-fast: false`, so wall-clock is the
slowest one, not the sum.


## Errors Encountered

| Error | Resolution |
|-------|------------|
