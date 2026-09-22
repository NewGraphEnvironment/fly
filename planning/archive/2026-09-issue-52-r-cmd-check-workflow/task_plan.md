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
  needs GDAL >= 3.7 — **wrong, and kept as written because it is what the decision was
  taken on**. GDAL's own `nearblack.rst` marks `-alg` `versionadded:: 3.8`; the 3.7 came
  from this repo's conventions and is filed as soul#255. The decision is unaffected; the
  guard built on it would have passed on a build with no `-alg` at all — and the three
  platforms ship different GDAL builds. R devel and
  oldrel-1 are dropped: this package is not going to CRAN, and oldrel-1 (R 4.4) is far
  above the declared `Depends: R (>= 4.1)`, so it would not test that claim either.
- **Fix the pre-existing WARNING in this PR and gate at `error-on: '"warning"'`** (the
  action default) rather than gq's `'"error"'` + follow-up issue. gq#51 has been open
  since.

## Phase 1: Measure the check before writing any workflow

- [x] Run `rcmdcheck` with the action's exact defaults, capture output under the
      scratchpad, grep for `WARNING|NOTE|ERROR` — **0 errors, 1 warning, 1 note**
- [x] Record every WARNING and NOTE verbatim in `findings.md`, each with a verdict:
      fix now / accept as NOTE / out of scope
- [x] Record the wall-clock the check took — **243 s** locally with deps installed
- [x] Confirm the predictions. **Both were wrong and are recorded as wrong**: the
      non-ASCII WARNING names only `R/fly_mask.R` (the other two files already use
      `\u2014`, and the probe's `deparse()` un-escaped them), and the `utils`/`stats`
      NOTE does not exist — they are base packages

## Phase 2: Clear what Phase 1 found, so the gate can sit at WARNING

- [x] `R/fly_mask.R:293` — the one flagged character, written as `\u2014` to match the
      eleven escapes `R/fly_footprint.R` and `R/fly_georef.R` already carry. `\u2014`
      rather than `--` because it keeps the rendered message byte-identical, so no
      consumer can notice; `test-fly_mask.R` greps `"flood into the image"` from the
      same string, ahead of the dash
- [x] ~~Add `stats` and `utils` to `DESCRIPTION` Imports~~ — dropped, Phase 1 showed
      `checking dependencies in R code ... OK`
- [x] `devtools::document()` — not needed, no roxygen block changed (message text only)
- [x] Full suite green — `FAIL: 0  ERROR: 0  SKIP: 0  PASS: 2141`
- [x] Check reports **0 errors, 0 warnings, 1 note** (CRAN incoming feasibility, recorded)
- [x] `/code-check`, commit

## Phase 3: Add the workflow

Ordered workflow-**first** on the plan review's O7: clearing the WARNING before the
workflow exists means the gate is never seen firing on a runner. Pushed in this order the
PR's first run goes red on the real pre-existing WARNING and the next goes green, which
costs one extra run on a public repo and turns "the gate is configured" into a run ID.

- [x] `.github/workflows/R-CMD-check.yaml` — 3-platform matrix at R release, default
      `error-on`, a `concurrency` group, and comments recording why three platforms, why
      `error-on` is left alone, and what the action already does that this does not
      need to repeat
- [x] A **"Report skipped tests"** step, `if: !cancelled()`. The action already cats the
      raw testthat output, so the step's job is narrower than first written: the skip
      block on its own rather than buried in a collapsed dump, and a **failure** when
      the output cannot be read at all (the action's version ends in `|| true`)
- [x] `/code-check` (3 rounds + plan review + 2 enumerations), commit, push, PR #67 — red run read

## Phase 3b: Make the gate trustworthy (from the plan review, B1)

Seven blocks in `test-fly_georef.R` assert `expect_true(result$success[1])` on a fresh,
unguarded download. A catalogue hiccup would have reddened three runners on an unrelated
diff — fly#52's own complaint in a new form.

- [x] Guard all seven with `skip_if_offline()` + `skip_if_not(all(fetched$success))`,
      matching the two #49-era blocks below them
- [x] Move the fourteen shared fixed `tempdir()` names to `withr::local_tempdir()` —
      `unlink()` fails **silently** on Windows with a handle open, and `fly_fetch()`
      then serves the stale file as a cache hit
- [x] Measure both directions under a simulated outage, against the file as it stood at
      `HEAD` rather than a reconstruction
- [x] Assert the GDAL floor (**3.8**, not the 3.7 the conventions carry — soul#255) `fly_mask()` depends on, so a runner below it fails
      by naming the cause
- [x] README badge

## Phase 4: Read the first run, then close out

- [x] Poll sparsely with `gh run view <id> --json status,conclusion` — never
      `gh run watch`
- [x] The first run (workflow only) is **red** on the non-ASCII WARNING — the gate
      demonstrated on a runner. Run
      [35680424973](https://github.com/NewGraphEnvironment/fly/actions/runs/35680424973)
- [x] It also found two pre-existing defects neither reachable from this machine: a
      BLAS-dependent premise in `test-fly_footprint.R` (342/720 locally, 0/720 on every
      runner) and a Windows-only band count contradicting a documented invariant
      ([#68](https://github.com/NewGraphEnvironment/fly/issues/68))
- [x] All three jobs green on the second — [35681274310](https://github.com/NewGraphEnvironment/fly/actions/runs/35681274310), `Status: OK` on each. **Discriminator for a red run**: re-run the
      failed job once. Reproducible is a finding (GDAL portability, a platform bug);
      not reproducible is catalogue flake, and gets filed rather than worked around
- [x] Skip report non-empty and identical on all three (2 skips: `skip_on_ci()` and the BLAS premise); **no** `skip_if_offline()` skips, so the network tests genuinely ran. A platform-specific skip
      is a finding
- [x] Slowest job: **Windows 7m39s** (ubuntu 6m17s, macOS 4m50s) — it is the input to any future decision about
      adding `devel`/`oldrel-1` back
- [x] `NEWS.md` + version bump to 0.14.1 as the final commit of the branch
- [x] `/planning-archive`

## Out of scope

- A lint workflow (`.lintr` exists; separate gate, separate issue)
- `^\.git$` in `.Rbuildignore`. The plan review argued for folding it in, and the argument
  is good — CI is structurally incapable of catching it, so the PR defining the gate is
  the natural place. But it was scoped out at the plan gate, and reversing an approved
  decision on a reviewer's say-so while the user is away is not the agent's call. Filed as
  [#66](https://github.com/NewGraphEnvironment/fly/issues/66) with the reviewer's
  reasoning, rather than left as a sentence in a PR body
- Guarding the network examples — they already degrade to `success = FALSE`, and
  `--as-cran` runs `\donttest{}` examples anyway

## Validation

- [x] Three jobs green, read from `gh run view <id> --json status,conclusion,jobs`
- [x] The gate is shown reachable **on a runner**: run 35680424973 red on the WARNING,
      35681274310 green after the fix
- [x] The skip report is non-empty on every runner — 2 skips each
- [x] `/code-check` run to an enumeration, not a quiet round
- [x] PWF checkboxes match landed work
- [x] `/planning-archive` on completion
