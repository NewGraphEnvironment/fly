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


## Phase 2 — after the one-character fix

`R/fly_mask.R:293`, raw em dash -> `\u2014`.

| | before | after |
|---|---|---|
| errors | 0 | **0** |
| warnings | **1** | **0** |
| notes | 1 | 1 (CRAN incoming feasibility) |
| elapsed | 243 s | 234 s |

Suite: `FAIL: 0  ERROR: 0  SKIP: 0  PASS: 2141`. Zero skips is the expected local shape —
the machine is online and `CI` is unset, so `skip_on_ci()` and `skip_if_offline()` both
pass through. On a runner at least one skip is guaranteed, which is what the workflow's
skip-report step exists to surface.

**This before/after pair is the evidence that `error-on: "warning"` is a reachable gate
and not decoration.** A green run alone cannot show that: the WARNING level had to be
observed firing on this package and then observed clearing.

### The rendered message is unchanged, and the obvious probe says otherwise

`deparse()` **re-escapes** non-ASCII, so grepping a deparse of the function body for a
literal em dash returns `FALSE` after the fix — which reads as "the message changed". It
did not. Pulling the string constant out of the parse tree and testing the value:

```
value:  ... Left unmasked — lower
contains U+2014: TRUE
```

Same trap as the Phase 1 probe, in the opposite direction — `deparse()` un-escaped there
and re-escapes here. Compare **values**, never a deparse, when the question is what a
string contains. `test-fly_mask.R` greps `"flood into the image"` from the same
string and is unaffected either way.

### `DESCRIPTION` untouched

Struck from the plan after Phase 1: `checking dependencies in R code ... OK`.


## Code review rounds

`/code-check`, `general-purpose` reviewers, findings in `review-round<N>.md`.

### Round 1 — two real defects, both introduced by this change

- **The job-level `concurrency` group contained no matrix value**, so all three runners
  evaluated the same group string and `cancel-in-progress: true` would have made them
  **cancel each other**. The symptom is the quiet one: a cancelled run reads as
  `cancelled`, not `failure`, so two platforms would simply never have reported. Fixed by
  putting `matrix.config.os` in the group. The concurrency block was itself a fix for a
  round-of-review finding, so this is a defect inside a fix and the loop continues.
- **A comment was inverted.** It said a gate at `error-on: "error"` over a pre-existing
  WARNING "is a gate nobody can make green". The opposite: `"error"` *passes* with a
  WARNING present, which is exactly what makes it the tempting wrong move and what makes
  it weak.
- A third, softer: the skip-report step's error message stated one cause ("this step is
  looking in the wrong place") as the meaning of a state with several. Reworded to refuse
  the state without claiming to diagnose it.

### Known and not fixed: `test-fly_fetch.R` is vacuous under an outage

Measured under the same dead-proxy simulation: **FAIL 0, SKIP 0, PASS 13**. Nine downloads
that tested nothing, and because it does not *skip*, the workflow's skip report will not
mention it either.

The obvious explanation — "it asserts on `result[result$success, ]` subsets, which go
empty" — is right for most of the file and **wrong for the block that matters**, which
survives only because a refused connection leaves no file behind. A drop *mid-transfer*
would leave a partial one and turn that block red. Pre-existing and out of scope for
fly#52; recorded so it is not rediscovered as a surprise, and so the reason on record is
the real one.


### The enumeration that ends the review loop

Round 1's concurrency bug sat **inside a fix** (the concurrency block was itself a
response to a plan-review finding), so per `code-check`'s stopping rule a quiet round no
longer ends the loop — only an enumeration does.

**The mechanism** behind both round-1 defects: a claim about *external* behaviour —
GitHub Actions' concurrency semantics, `rcmdcheck`'s `error_on` semantics — written into
a comment from recollection rather than read from its source. Both were confidently
stated and both were wrong in the direction that reads as careful.

So the candidate set is every factual claim the workflow makes about something outside
this repo, and each was checked against its own source:

| claim | source | verdict |
|---|---|---|
| `check-dir` defaults to `check` | `action.yaml` | ✓ |
| `error-on` defaults to `"warning"` | `action.yaml` | ✓ |
| `error-on: "error"` passes with a WARNING present | `rcmdcheck` semantics | ✓ (the round-1 comment said the opposite) |
| the action forces `_R_CHECK_CRAN_INCOMING_=false`, `_R_CHECK_FORCE_SUGGESTS_=false` | `action.yaml` | ✓ — so the CRAN-incoming NOTE never appears on CI |
| the action already cats testthat output, ending `\|\| true` | `action.yaml` | ✓ |
| Windows runners can run `shell: bash` | the action uses it unconditionally on all platforms | ✓ |
| a job-level `concurrency` group is evaluated **per matrix job** | GitHub's context-availability table lists `matrix` for `jobs.<job_id>.concurrency` and **not** for the top-level `concurrency` | ✓ — and this is what makes the missing `matrix.config.os` a real bug |
| a cancelled run reads `cancelled`, not `failure` | `gh-pr-merge` step 10 | ✓ |
| `R CMD check` copies `tests/` in before running them | observed: `check/fly.Rcheck/tests/testthat/test-*.R` present beside `testthat.Rout` | ✓ |
| `oldrel-1` is R 4.4 | release is 4.5.x | ✓ |
| **`-alg floodfill` needs GDAL >= 3.7** | GDAL's `nearblack.rst`: `-alg` carries `versionadded:: 3.8` | ✗ **wrong** |
| ~~"roughly fifteen live fetches per job"~~ | nobody counted | ✗ removed rather than defended |
| ~~v0.9.0 changed `fly_footprint()`, `fly_bearing()`, `fly_georef()`~~ | `NEWS.md` names bearing, georef, rectangles, is_square, coverage | ✗ restated from NEWS |

**The GDAL one is the reason the enumeration was worth running.** The premise test added
one round earlier asserted `>= 3.7.0` — so on a GDAL 3.7 build, which has no `-alg` flag
at all, the guard would have **passed** and `nearblack` would then have failed with an
unrecognised-option error naming nothing. A guard failing toward pass on precisely the
release it exists to catch, and the wrong number came from this repo's own conventions
rather than from upstream. Now `>= 3.8.0` with the citation inline, and the convention
error is filed as
[soul#255](https://github.com/NewGraphEnvironment/soul/issues/255).

Three of thirteen claims were wrong. None was reachable by reading the file again.


### The GDAL premise, driven in every direction

A version premise that only ever passes is decoration, so the shipped expression was run
against every shape GDAL emits:

```
'3.8.5'      -> pass          '3.7.3'      -> REJECTS
'3.8.0'      -> pass          '3.7.0'      -> REJECTS   <- what the 3.7 floor let through
'3.9.0beta1' -> pass          '3.4.1'      -> REJECTS   <- ubuntu-22.04
'3.11.0-dev' -> pass          '2.4.0'      -> REJECTS
'3.12'       -> pass          ''/'unknown' -> PREMISE FAILS (unparseable)
```

The pre-release rows are the second defect this test carried. `package_version()`
**errors** on `"3.9.0beta1"` and `"3.11.0-dev"` (measured), so a runner with a
pre-release GDAL would have turned a correct package red — a version premise failing in
the one direction it must not. The suffix is stripped before parsing, and the strip's own
output is asserted, so a version string shaped in some way nobody anticipated names
itself rather than erroring three lines later.


### Rounds 2 and 3, and what ended the loop

Round 2 re-found the concurrency bug (it was reviewing the pre-fix diff) and added: the
GDAL comment was wrong in **both halves**, `package_version()` errors on pre-release
strings, and `test-fly_georef.R`'s mtime block is latently vacuous.

Round 3 found the loop's own tail:

| finding | verdict |
|---|---|
| `test-fly_mask.R:158` is a dead citation **killed by this diff** — the 28-line GDAL block moved it, and it was the evidence that the `\u2014` substitution is invisible to consumers | fixed; the plan files now cite the assertion's text, which does not move |
| "Seven blocks asserted `expect_true(result$success[1])`" — seven were unguarded, **four** asserted `result$success` | fixed in the workflow, the plan and NEWS |
| The red-then-green demonstration cannot happen if both commits go out in one push: `pull_request` fires once per **push**, not per commit | the push is sequenced deliberately, and Phase 4 records the run IDs |
| "fails by naming the cause **rather than** an opaque error" — `checking examples` runs before `checking tests`, so the premise arrives seventh | fixed; combined with round 2's finding that the error is swallowed entirely |
| "3.8.4, one patch release above" the 3.8.0 floor — it is four | fixed |
| `3.8.0dev` strips to `3.8.0` and passes | stated as a residual rather than engineered around: narrowing it would reject legitimate dev builds of later releases |

**The mechanism, corrected.** After round 1 it was called "external-behaviour claims
written from recollection", and the enumeration was filtered on *externality*. Round 3 is
right that this is the "literal set used as a filter" failure: externality was a property
of three instances, not of the mechanism. The mechanism is **an assertion made in a medium
that cannot execute it** — a YAML comment, a roxygen comment, a plan bullet — written in an
idiom that reads as already-verified. That widens the population by two axes, both then
enumerated by count:

| population | members | wrong |
|---|---|---|
| claims about external behaviour | 13 | 3 |
| claims about this repo | 12 | 2 |
| claims about what happens on push | 1 | 1 |

Six of twenty-six. None was reachable by reading the files again, and the loop ends on the
enumeration rather than on a quiet round — which is the rule once a defect has been found
inside a fix, and one was (the concurrency group).


## Errors Encountered

| Error | Resolution |
|-------|------------|
