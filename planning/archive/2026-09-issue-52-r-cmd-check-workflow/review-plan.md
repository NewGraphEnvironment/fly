# Plan review — fly#52

`Plan` subagent, spawned concurrently with Phase 1 per `planning.md` step 3. It read the
PWF triple, the draft workflow, the real `r-lib/actions/check-r-package@v2` `action.yml`
and `setup-r/src/installer.ts`, the Phase 1 check log, and the package source.

The `Plan` agent type has no Write tool, so it returned the review as reply text and this
file is written from it. A first attempt died on an API 529 and was re-spawned.

## Disposition

| # | Finding | Verdict | What was done |
|---|---|---|---|
| **B1** | **Blocker.** The workflow comment and `findings.md` claimed an outage cannot redden the check, citing three *example* call sites. Seven blocks in `test-fly_georef.R` assert `expect_true(result$success[1])` on a **fresh, unguarded** download. ~15 live fetches per job x 3 runners. | **Real — verified independently** | Guarded all seven with `skip_if_offline()` + `skip_if_not(all(fetched$success))`, the pattern the two #49-era blocks below them already used. Measured both directions (below). Comment rewritten. |
| G2 | The "Report skipped tests" step duplicates the action's own `Show testthat output` step, and its comment claimed the information did not otherwise exist. | Real | Comment rewritten to say what it actually adds: the block on its own rather than buried in a collapsed dump, and a **failure** when the output cannot be read. The action's ends in `|| true`. |
| G3 | The stated reason for writing the step in R — "Windows default shell is PowerShell and neither tool is available" — is false. Windows runners ship Git Bash and the action itself uses `shell: bash` with `find`. | Real | Comment corrected. The R implementation stays; the reason is now "no shell quoting layer, one code path", which is true. |
| G4 | No `concurrency` block. Three pushes to a PR queue nine jobs, each building the vignette twice against a live catalogue. | Real | Added, with `cancel-in-progress: true`. |
| G5 | The matrix comment claimed a GDAL regression "would be visible here and nowhere else". It would be visible as an *unexplained* `nearblack` failure — nothing names the floor. | Real | Added a premise test in `test-fly_mask.R` asserting it, and corrected the comment to point at it. Deliberately an assertion, not a skip: there is no version of this package that works below the floor. **The first draft used `>= 3.7`, the figure this repo's conventions carry; GDAL's own `nearblack.rst` marks `-alg` `versionadded:: 3.8`, so the guard would have passed on a build with no `-alg` at all.** Now 3.8, and the convention error is [soul#255](https://github.com/NewGraphEnvironment/soul/issues/255). |
| G6 | `README.md` has an empty `<!-- badges: start -->` block; `use_github_action("check-standard")`, which the issue names as the remedy, adds the badge. | Real | Added. |
| O7 | The plan guarantees the gate is never *observed* firing on a runner — the WARNING is cleared before the workflow exists, so the first CI run is green and nobody sees `error-on: "warning"` do anything. | Real | **Taken.** Commits ordered workflow-first: the PR's first run goes red on the real pre-existing WARNING, the next goes green. Costs one extra run on a public repo and converts an assertion into a run ID. |
| O8/O9 | PWF drift — Phase 1 and most of Phase 2 done with boxes unticked, and `task_plan.md` still carried both retracted predictions while only `findings.md` was corrected. | Real | Both files corrected. The plan is the thing that gets executed; correcting only the findings leaves the executable half wrong. |
| A10 | "The catalogue is reachable from a GH runner" rests on four green pkgdown runs — one platform, three thumbnails — and was doing duty for ~15 fetches x 3 platforms x 5 hard assertions. | Real | Narrowed in `findings.md`. B1's fix removes the load it was carrying. |
| A11 | The local run did **not** mirror the CI check. The action forces `_R_CHECK_CRAN_INCOMING_=false` and `_R_CHECK_FORCE_SUGGESTS_=false`, so the CRAN-incoming NOTE will not appear on CI at all. | Real — found independently at the same time | Re-measured under those env vars: **0 errors, 0 warnings, 0 notes**, 200 s. Recorded, and noted in the workflow so the next person does not read a local NOTE as CI's. |
| A12 | The GDAL claim was unmeasured. | Real | Same fix as G5. |
| S13 | `^\.git$` in `.Rbuildignore` should be folded in, not deferred: CI is structurally incapable of catching it (`actions/checkout` produces a `.git` *directory*, which R excludes anyway), so the PR defining the gate is the right place. | **Argument accepted, change declined** | The user scoped this out at the plan gate. Reversing an approved decision because a reviewer argued well is not mine to do while they are away. Filed as [#66](https://github.com/NewGraphEnvironment/fly/issues/66) instead, with the reviewer's reasoning — including that the assertion it prescribes has a placement problem of its own, since a test reading `.Rbuildignore` by relative path silently skips under `R CMD check`. |
| S14 | `upload-snapshots: true` is inert — `tests/testthat/_snaps/` is empty. | Real | Removed. Every other line in the file carries a reason. |
| AC15 | "A macOS/Windows failure is a GDAL portability finding" cannot distinguish that from a catalogue hiccup. | Real | Phase 4 now carries the discriminator: re-run the failed job once; reproducible is a finding, non-reproducible is flake. |
| AC16 | Record the slowest job's wall-clock; it is the input to any future decision about adding `devel`/`oldrel-1`. | Real | Added to Phase 4. |
| — | `if: always()` runs on cancellation; `if: !cancelled()` closes the one window where the step could add a confusing second red tick. | Real | Taken. |
| — | Windows: `test-fly_georef.R` reused fixed names under a session-lifetime `tempdir()` with unchecked `unlink()`, which fails **silently** on Windows when a handle is open — leaving a stale file that `fly_fetch()`'s cache hit then serves. | Real | Fixed in the same edit as B1: all fourteen sites now use `withr::local_tempdir()`. |
| — | `test-fly_camera_patb.R`'s fetches are cache hits, not network calls — `patb_cache()` pre-copies `inst/testdata/patb/` and `R/fly_fetch.R:97` treats a non-empty existing file as success. "Downloaded 2 of 2 files" in the log looks like a network call and is not. | Correct, worth recording | Recorded here. |
| — | `NOT_CRAN=true` is set by `setup-r`, so `skip_on_cran()` does not short-circuit `skip_on_ci()` — the skip report's non-vacuity premise holds. | Correct | No change; the premise was checked rather than assumed. |

## The blocker, measured in both directions

HTTP routed at a dead local port (`http_proxy=http://127.0.0.1:9`), so DNS still resolves
and `skip_if_offline()` passes — isolating the `skip_if_not(all(fetched$success))` guard
as the thing under test. The pre-change file was pulled from git rather than
reconstructed, and run beside the new one in the same process:

| `test-fly_georef.R` | FAIL | SKIP | PASS |
|---|---|---|---|
| as it stood at `HEAD` | **11** | 2 | 10 |
| with the guards | **0** | 9 | 7 |

So the claim "an outage cannot redden this gate" was false by eleven failures when it was
written, and is true now. Without this, a catalogue hiccup would have reddened three
runners on an unrelated diff — which is how a gate teaches people to ignore it, and is
fly#52's own complaint in a new form.

## What the reviewer got wrong

Nothing material. Two of its findings (A11's env vars, G2's duplicate step) were reached
independently from the action source at roughly the same time, which is corroboration
rather than a second source — both readings came from the same `action.yml`.
