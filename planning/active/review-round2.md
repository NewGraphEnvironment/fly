# Code review round 2 — fly#52

Staged diff: `.github/workflows/R-CMD-check.yaml` (new), `R/fly_mask.R`, `README.md`,
`tests/testthat/test-fly_georef.R`, `tests/testthat/test-fly_mask.R`, PWF files.

## The mechanism behind round 1

Round 1's four substantive findings (B1, G2, G3, G5) are one shape, not four bugs:

> **A comment in the diff asserts a fact about a system outside the diff — the test
> suite, the composite action, the runner image, `R CMD check`'s own ordering — and
> nobody executed it.**

B1 said the suite could not go red on an outage (false by eleven failures). G2 said the
information did not otherwise exist (the action already cats it). G3 said bash was
unavailable on Windows (it is not). G5 said a GDAL regression would be visible "here and
nowhere else". Every one is prose about behaviour elsewhere, and in every case the
executing cost one command.

`code-check.md` names the terminating condition: *enumerate every claim a diff makes
about behaviour elsewhere and execute each*. The round-1 sweep terminated on a **file**
(`test-fly_georef.R`) rather than on the **claim set**, which is why the same mechanism
still reaches two places below.

So this review is the enumeration. Every factual claim in the diff, executed:

| # | claim | where | verdict |
|---|---|---|---|
| 1 | `.github/workflows/` held only pkgdown | wf:5-8 | true (`ls .github/workflows`) |
| 2 | `-alg floodfill` needs GDAL >= 3.7 | wf:31, mask test:8 | true |
| 3 | three platforms, three GDAL sources | wf:31-34 | plausible; not checkable from here, benign |
| 4 | the mask test makes a sub-3.7 runner "fail by naming the cause **rather than** as an opaque nearblack error" | wf:32-34 | **FALSE — finding 2** |
| 5 | `oldrel-1` is R 4.4 | wf:37-38 | true (release 4.5 → oldrel-1 = 4.4) |
| 6 | the concurrency block stops nine queued jobs across three pushes | wf:45-56 | **the block does not do this, and breaks the matrix — finding 1** |
| 7 | action default `error-on` is `"warning"` | wf:72 | true (`action.yaml`: `default: '"warning"'`) |
| 8 | action sets `_R_CHECK_CRAN_INCOMING_`/`_R_CHECK_FORCE_SUGGESTS_` to false unless caller has | wf:77-81 | true, verbatim in the action's Check step |
| 9 | `--as-cran` is in effect | wf:78 | true — action default `args` is `c("--no-manual", "--as-cran")` |
| 10 | `fly_fetch()` returns `success = FALSE` (R/fly_fetch.R:104) | wf:94 | true, line correct |
| 11 | `fly_georef()` skips a failed row (R/fly_georef.R:314) | wf:94 | true, line correct |
| 12 | `fly_mask()` zero-length return (R/fly_mask.R:98) | wf:96-97 | true, line correct |
| 13 | "Show testthat output" exists, uses `find`, ends in `\|\| true` | wf:115-121, 126 | true, verbatim |
| 14 | Windows runners ship bash; the action's own step uses `shell: bash` | wf:123-126 | true |
| 15 | `test-fly_camera_patb.R:239` carries an unconditional `skip_on_ci()` | wf:110, 165 | true, line correct |
| 16 | testthat emits a literal `Skipped tests` string the step can grep | wf:155 | true — `testthat:::skip_report()` calls `rule(paste0("Skipped tests (", n, ")"))` |
| 17 | `check-dir` is `check/`, relative to repo root | step body | true (action default `'"check"'`, `working-directory: '.'`) |
| 18 | `fly_mask()` passes `-alg floodfill` (R/fly_mask.R:255) | mask test:8 | true, line correct |
| 19 | "an outage must not redden this gate" (whole check) | wf:83-105 | holds, but on a one-file measurement plus reasoning — **finding 5** |
| 20 | `test-fly_fetch.R` degrades to vacuous rather than red | scope note | **now measured, and the stated mechanism is wrong — finding 5** |

Two are false, one is over-read. The rest execute clean.

---

## Findings

- **[bug]** `.github/workflows/R-CMD-check.yaml:49-51` — **the `concurrency` block is at
  job level with a group that is identical across the three matrix jobs, so the three
  platforms cancel each other.** This defeats the entire justification for the file.

  `github.workflow` and `github.ref` are the same for every matrix entry, so all three
  jobs evaluate the group to one string (`check-R-CMD-check.yaml-refs/pull/N/merge`).
  GitHub's own reference for `jobs.<job_id>.concurrency`
  (`data/reusables/actions/actions-group-concurrency.md`, fetched 2026-09-21) is explicit:

  > there can be at most one running job or workflow in a concurrency group at any time
  > … To also cancel any currently running job or workflow in the same concurrency
  > group, specify `cancel-in-progress: true`.

  So: ubuntu starts; macOS queues and cancels it; windows queues and cancels macOS. At
  most one platform actually runs per push. `fail-fast: false` does not help — that
  governs matrix *failure* propagation, not concurrency. The `matrix` context being
  listed among the allowed expression contexts for *job-level* concurrency is the tell:
  it is there because a matrix group has to be keyed on the matrix.

  **And the failure is silent in the direction this PR exists to close.** The comment
  three lines above says a cancelled run "reads as `cancelled`, not `failure`, which
  `gh-pr-merge` step 10 already distinguishes" — step 10 reads `cancelled` as
  `⊘ superseded`. So two of three platforms vanishing reads as *superseded*, not as
  *never ran*. A green PR would again mean less than it appears to, one level in.

  Two remedies, either is one edit:
  - move the block to **workflow level** (between `permissions:` and `jobs:`), which is
    also what the comment describes — the nine-queued-jobs problem is a workflow
    concern; or
  - keep it at job level and key it on the matrix:
    `group: check-${{ github.workflow }}-${{ github.ref }}-${{ matrix.config.os }}`.

  Prefer the first: it cancels the *whole* superseded run, which is what "each of which
  builds the vignette twice against the live BC catalogue" is asking for. Job-level
  keyed on `matrix.config.os` cancels per-platform and leaves the comment's arithmetic
  (nine jobs) only a third true.

  Verification is free and definitive: the first PR run's job list. Three job rows, one
  green and two `cancelled`, is this. Do not read those two as superseded.

- **[fragile]** `.github/workflows/R-CMD-check.yaml:32-34` and
  `tests/testthat/test-fly_mask.R:8-19` — **the GDAL premise test does not get there
  first, and the failure it is meant to replace is not an error.** Both halves of the
  claim were measured and both are wrong.

  *Not an error.* `fly_georef()` wraps `georef_one()` in
  `tryCatch(error = function(e) { message(...); FALSE })` (R/fly_georef.R:382-389), and
  `fly_mask()` wraps `fly_mask_one()` the same way (R/fly_mask.R:165-172). A sub-3.7
  GDAL therefore produces `success = FALSE` rows, not a raised condition. Consequence
  worth knowing on its own: the `fly_georef` and `fly_mask` **examples** and the
  vignette's `fetch-georef` chunk all *pass* on such a runner, silently producing
  nothing. The comment's "opaque `nearblack` error" never happens anywhere.

  *Not first.* testthat runs files in C-collated order and `.` (0x2E) sorts before `_`
  (0x5F), so `test-fly_georef.R` runs before `test-fly_mask.R`. `fly_georef()` defaults
  to `mask = "border"` (R/fly_georef.R:174), so all six live `expect_true(result$success[1])`
  blocks in `test-fly_georef.R` fail first, reported as `result$success[1] is not TRUE`
  — which reads as a georeferencing bug, not a GDAL floor. The premise test does fire,
  but seventh, after six failures that name nothing.

  Net: the premise test is a real improvement and the "rather than" is the part that is
  false — it is "as well as, and later in the log". (Offline the georef blocks skip and
  the claim holds exactly. That is the one case a runner will never be in.) Either
  reword to "as well as", or move the assertion somewhere testthat reaches before any
  file that calls `fly_mask()` — `setup.R`, or a filename that sorts first.

- **[fragile]** `tests/testthat/test-fly_mask.R:16` — **`package_version()` errors, with
  a message naming neither GDAL nor the floor, on any GDAL release name carrying a
  non-numeric suffix.** Direct answer to scrutiny item 3: no, it is not safe for every
  string GDAL emits. Measured on R 4.5:

  ```
  3.8.5            -> 3.8.5        3.7.0beta1       -> ERROR: invalid version specification
  3.9.3-1          -> 3.9.3.1      3.10.0dev        -> ERROR: invalid version specification
  3.11.0           -> 3.11.0       3.12.0dev-1a2b3c -> ERROR: invalid version specification
  ```

  `sf_extSoftVersion()[["GDAL"]]` is `GDALVersionInfo("RELEASE_NAME")`, which carries
  exactly those suffixes on dev, beta and rc builds. On such a runner the test errors
  with `invalid version specification '3.10.0dev'` — i.e. it becomes the opaque failure
  it was written to prevent, and it does so whether GDAL is 3.6 or 3.12.

  Unlikely on the three chosen runners (all ship releases), which is why this is
  `fragile` and not `bug`. One line closes it:
  `package_version(sub("^([0-9]+(\\.[0-9]+)*).*$", "\\1", sf::sf_extSoftVersion()[["GDAL"]]))`.

  The rest of that test is sound: `expect_gte()` on a `numeric_version` was driven in
  **both** directions — passes at 3.8.5, and at 3.6.0 fails with
  `Expected ... >= ...  Actual comparison: "3.6.0" < "3.7.0"`. The assertion is not
  decoration.

- **[fragile]** `tests/testthat/test-fly_georef.R:57-62` (the overwrite/mtime block) —
  **pre-existing latent vacuity, now the only thing standing between this block and a
  silent pass.** Measured: `file.mtime(NA_character_)` is `NA`, and
  `expect_equal(NA, NA)` passes. If the first `fly_georef()` run writes no file for any
  reason other than a failed fetch, `list.files(dest_georef, full.names = TRUE)[1]` is
  `NA` and the block passes having compared nothing.

  Not introduced by this diff and not made more likely by it — `skip_if_not()` in fact
  removes the outage path that used to reach it. Recorded because the block was edited
  and because the remedy is one line (`expect_false(is.na(f))` as a premise), not
  because anything is broken today.

- **[fragile]** `.github/workflows/R-CMD-check.yaml:83-84` and the scope note —
  **"An outage at the BC Data Catalogue must not redden this gate" is stated as a
  property of the whole check and was measured on one file.** Scrutiny item 5.

  So I measured the second file. Under the same dead-proxy simulation
  (`http_proxy=http://127.0.0.1:9`), `test-fly_fetch.R` gives **FAIL 0 / ERROR 0 /
  SKIP 0 / PASS 13**. The claim holds. But the *stated reason* — "asserts on
  `result[result$success, ]` subsets" — is only half of it, and the half it leaves out
  is the fragile one:

  `test-fly_fetch.R:22-37` ("skips existing files when overwrite is FALSE") does **not**
  assert on a success subset. It compares two mtimes, and it survives an outage only
  because `utils::download.file()` on a refused connection leaves **no file at all**
  (measured: `exists: FALSE`, `list.files: 0`), so `f` is `NA` and the comparison is
  vacuous. Note this contradicts the comment in `R/fly_fetch.R:92-95`, which says
  `download.file()` "truncates its target before it runs, so an interrupted fetch leaves
  a 0-byte file". Both are true of different failure modes — an interrupted transfer
  leaves the 0-byte file, a refused connection does not — and only one of them is the
  one that makes this test safe. Had the outage been a mid-transfer drop rather than a
  refusal, `fly_fetch()`'s own `file.size(dest_file) > 0` guard would have re-downloaded
  on the second call and moved the mtime, and the block would be red.

  Nothing to change in this PR. The note to correct is the scope line: the file degrades
  to vacuous **on a connection-level outage**, measured on macOS, and not for the reason
  given. Leaving it as "asserts on subsets" invites the next person to trust a mechanism
  that is not the one holding.

---

## Checked and clean

Scrutiny items 1, 2 and 4, plus the round-1 fixes.

**1. Did guarding change what any of the seven blocks asserts?** No. Every guard is
`skip_if_offline()` at the top plus `skip_if_not(all(fetched$success), ...)` placed
**after** the `fly_fetch()` call and **before** the first assertion, in all seven. No
assertion was weakened, reordered or removed; the diff adds lines and swaps the tempdir
expression, nothing else. All ten live-network blocks in the file are now guarded (the
two #49-era ones already were), and the four offline blocks correctly are not.

*The overwrite/mtime block specifically:* `withr::local_tempdir()` yields a fresh empty
directory, which is what `file.path(tempdir(), "...")` + `unlink()` yielded before, so
`list.files(dest_georef, full.names = TRUE)[1]` still picks the file the first run wrote
and the mtime pair still measures the same thing. `Sys.sleep(1)` and `expect_equal()` on
POSIXct are untouched.

*The rotation loop specifically:* measured rather than reasoned. `for` does not create a
frame in R, so `parent.frame()` inside the loop body is the `test_that()` evaluation
frame and all four deferrals attach there. Driven directly:

```
inside test_that, all still exist: TRUE  n = 4
all distinct: TRUE
after test_that, any still exist: FALSE
```

Four distinct directories, all live for the duration of the loop (so no iteration can
read another's output), all removed at test exit. The scoping is right, and it is right
for a reason — not by luck.

**2. Did `local_tempdir()` make anything vacuous by removing a shared directory?** No,
and it structurally could not have: every one of the fourteen old sites began with
`unlink(dest, recursive = TRUE)`, so cross-`test_that()` persistence was already
impossible. The change is `unlink()`-then-use → create-fresh, which is the same state
with the Windows silent-`unlink()` failure removed. No block reads a path another block
wrote.

**4. The workflow, against the real action.** Fetched
`r-lib/actions/v2/check-r-package/action.yaml` and read it rather than trusting the
comments. Everything in rows 7-9, 13-14 and 17 of the table above checks out verbatim,
including the two `Sys.setenv` lines and the `|| true` on the action's own step. The
`build_args: 'c("--no-manual")'` override is equivalent to the action's default
`'"--no-manual"'` — harmless.

**The skip-report step's four branches** were re-derived against the real layout, not
only the fixture trees:
- `list.dirs("check", recursive = FALSE)` on a missing directory returns `character(0)`
  (measured), and with `recursive = FALSE` it does **not** include the path itself, so
  `file.path(character(0), "tests")` is `character(0)` → prints, `quit()` exits 0. ✓
- `check-dir` really is `check/` at repo root, so `check/fly.Rcheck/tests` is where it
  looks. ✓
- `pattern = "[.]Rout"` matches `testthat.Rout` and `testthat.Rout.fail`, so a red test
  run still reports its skips. ✓
- `if: ${{ !cancelled() }}` runs after a failed check step (which is the case the step
  exists for) and after a failed *setup* step, where `check/` does not exist and the
  step correctly prints-and-exits-0 rather than adding a second red tick. ✓
- The non-vacuity premise holds: `setup-r` exports `NOT_CRAN=true`, so
  `skip_if_offline()`'s internal `skip_on_cran()` does not short-circuit, and
  `test-fly_camera_patb.R:239`'s `skip_on_ci()` guarantees at least one skip on every
  runner — so the "No skip block" branch really is surprising when it fires. ✓

**The non-ASCII fix.** `R/*.R` still contains non-ASCII on 220 lines across eleven
files, which initially reads as an incomplete fix. It is not: `R CMD check`'s
"checking R files for non-ASCII characters" exempts comments, and every remaining
occurrence is in a comment or roxygen line — the string literals in
`R/fly_footprint.R` and `R/fly_georef.R` already use `\uXXXX`. The single em dash in a
`warning()` string at `R/fly_mask.R:293` was the only one in code, which is exactly what
the measured 1-warning → 0-warning transition says. `test-fly_mask.R:158` greps
`"flood into the image"`, which the edit does not touch.

**README badge.** URL matches the workflow's path and filename.

---

## One measurement that is over-read, and one that is under-read

Neither changes a conclusion; both are worth correcting in the record.

**Over-read:** *"the file as it stood at `HEAD` gives FAIL 11 … with the guards FAIL 0,
SKIP 9"* is a measurement of `test-fly_georef.R`, quoted in the workflow comment under a
sentence about the whole gate ("An outage … must not redden this gate"). The gate is
`R CMD build` + examples + vignette + 25 test files. Finding 5 closes the one remaining
file that could have contradicted it; the other 23 never touch the network. The claim is
now true — but it was a scope inference when written, not a measurement.

**Under-read:** *"rcmdcheck with the action's exact inputs AND the two env vars: 0/0/0"*
is stronger than stated, because `callr::rcmd_safe_env()` sets `NOT_CRAN=true`, so that
local run **did** execute the seven guarded blocks rather than skipping them at
`skip_on_cran()`. Worth writing down: a reader who repeats that check with
`NOT_CRAN` unset will get a different skip count and may read it as drift.
