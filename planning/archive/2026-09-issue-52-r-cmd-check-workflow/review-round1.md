# Review — round 1, fly#52 (R-CMD-check workflow + the non-ASCII WARNING fix)

Reviewed the **staged** diff (`git diff --cached`). The working tree has already moved
ahead of it in `.github/workflows/R-CMD-check.yaml`, `tests/testthat/test-fly_georef.R`,
`tests/testthat/test-fly_mask.R` and `README.md`; where a finding is already addressed
there I say so, because the actionable part is then *staging* it rather than writing it.

Nothing in the repo was modified by this review. The defect-restoration and the
offline runs were done against copies under the session scratchpad.

---

## Findings

### 1. [bug] The staged diff ships the workflow's central claim without the fix that makes it true

`.github/workflows/R-CMD-check.yaml` (staged, the `check-r-package` comment block):

> The examples and the vignette are NOT guarded against the BC Data Catalogue being
> unreachable … So an outage degrades this check to a quieter one; it does not redden it.

The reasoning covers examples and the vignette. `R CMD check` also runs **the tests**, and
in the staged tree `tests/testthat/test-fly_georef.R` asserts `expect_true(result$success[1])`
on a fresh download in seven blocks with no guard at all.

Measured — HTTP blackholed at `127.0.0.1:9`, `test_file()` on the tree as staged
(`git show HEAD:tests/testthat/test-fly_georef.R`):

```
test-fly_georef.R  FAIL: 11  ERROR: 0  SKIP: 2  PASS: 6
```

That is `checking tests ... ERROR`, which reddens all three runners regardless of
`error-on`. So as staged, a catalogue hiccup on an unrelated PR turns the new gate red —
the outcome the comment says cannot happen.

The working tree already fixes it (`skip_if_offline()` + `skip_if_not(all(fetched$success))`),
and I reproduce its numbers exactly: **FAIL 0, SKIP 9, PASS 3** offline. But that fix is
**unstaged**:

```
AM .github/workflows/R-CMD-check.yaml
 M tests/testthat/test-fly_georef.R      <- the fix
 M tests/testthat/test-fly_mask.R
```

A `git commit` from this index ships the workflow and the claim, and leaves the fix behind.
Stage `tests/` with the workflow, in the same commit.

### 2. [bug] Job-level `concurrency` with no matrix key puts all three platform jobs in one group

Working tree, `.github/workflows/R-CMD-check.yaml`:

```yaml
    concurrency:
      group: check-${{ github.workflow }}-${{ github.ref }}
      cancel-in-progress: true
```

This sits inside `jobs.R-CMD-check:` (confirmed by parsing: job keys are `runs-on, name,
strategy, concurrency, env, steps`), so it is evaluated **per matrix job** — and the
expression contains no matrix value, so ubuntu, macOS and Windows all resolve to the
identical group string. Only one job per concurrency group runs at a time, and
`cancel-in-progress: true` cancels the running one as the next is queued. The matrix
serialises and its own siblings cancel each other.

The failure is quiet, which is what makes it worth fixing before the first run: a
cancelled job is not a failed one, and `gh-pr-merge` step 10 explicitly reads
`cancelled`/`skipped` as `⊘ superseded`. One green tick and two "superseded" in a single
run reads as normal supersession, not as a matrix that never ran — and the matrix is the
diff's stated reason for the runner spend.

Remedy — put the matrix key in the group:

```yaml
      group: check-${{ github.workflow }}-${{ github.ref }}-${{ matrix.config.os }}
```

Confirm on the first run rather than assuming: three concurrent jobs, none cancelled.

### 3. [fragile] The `error-on` rationale is inverted, in the block that exists to justify the gate

Line 73 (staged and working tree):

> A gate landed at "error" over a pre-existing WARNING is a gate nobody can make green,
> and it silently stops catching the next WARNING too.

`rcmdcheck(error_on = "error")` throws only on ERRORs — a WARNING passes. So a gate at
`"error"` over a pre-existing WARNING **is** green, which is precisely why it is the
tempting wrong move and why the second clause is the whole argument. The sentence that is
true is the one about `"warning"`: a gate at `"warning"` over a pre-existing WARNING is
the one nobody can make green, which is why the WARNING was cleared in the same PR.

As written the two halves contradict each other, and a reader who takes the first half at
face value learns the opposite of the lesson.

### 4. [fragile] "tests/ with no .Rout means this step is looking in the wrong place" — one cause stated as the meaning

`R CMD check` copies `tests/` into `<pkg>.Rcheck/` **before** running anything in it, so
"present, no `.Rout`" also covers: the test stage started and did not finish. A hard R
crash before the first flush (GDAL is in scope), or a timeout on the check step itself,
lands there. It is the one branch that manufactures a second red tick, and it does so on a
run whose real cause is elsewhere.

The working tree's move from `if: always()` to `if: ${{ !cancelled() }}` removes the
commonest instance (a cancelled run mid-tests) and is a genuine improvement. A step-level
timeout is not cancellation, so the branch is not closed — just narrow. Either widen the
message to name both readings, or make that branch a loud `cat()` plus a non-zero exit
only when the check step itself succeeded.

### 5. [fragile] `test-fly_fetch.R` defeats the skip-report step's stated purpose, and nothing says so

Same offline harness:

```
test-fly_fetch.R  FAIL: 0  ERROR: 0  SKIP: 0  PASS: 13
```

It survives an outage by being **vacuous**, not by skipping —
`downloaded <- result[result$success, ]; expect_true(all(file.exists(downloaded$dest)))`
is trivially TRUE on zero rows, and nine downloads produced `Downloaded 0 of N` messages
with every assertion still green.

The new step's whole job is to stop "the guards ran and passed" and "the guards never
executed" looking alike. On a catalogue outage it will print the skips from
`test-fly_georef.R` and `test-fly_camera_patb.R` and say **nothing at all** about
`test-fly_fetch.R`, whose coverage has silently evaporated with zero skips recorded. The
working-tree comment says the outage-proofing "took a change to the suite rather than a
claim about it" and names only `test-fly_georef.R` — true, and incomplete in exactly the
direction this step exists to cover.

Not necessarily this PR's job to fix the file, but the comment should not imply the suite
is now outage-visible when one of its two network files is outage-*invisible*.

---

## Answers to the four questions

### Q3 — is the `—` escape safe? Yes, and it is the complete fix

Restored the literal em dash in a scratch copy and ran the check's own predicate:

```
tools:::.check_package_ASCII_code(".")   # as staged  -> character(0)
tools:::.check_package_ASCII_code(".")   # defect back -> "R/fly_mask.R"
```

So the guard fires and clears — the WARNING is reachable and the one character is what
clears it. The check parses with comments dropped, which is why the **29** em dashes
elsewhere in `fly_mask.R` and the ones across ten other R files are not flagged: only
string literals and symbols count.

The rendered value is unchanged. Pulling the literal out of the parse tree:

```
"That is a flood into the image, not a collar. Left unmasked — lower "
nchar 68, grepl("—", ., fixed = TRUE) TRUE
```

`test-fly_mask.R:158` greps `"flood into the image"` and the line below it greps
`"interior"`; neither crosses the em dash. `R/fly_georef.R:358` already writes `—`
in the same kind of message, so the file is now consistent with its sibling rather than
an exception.

### Q2 — the "Report skipped tests" step

**`check/` is the right directory.** Fetched `r-lib/actions@v2/check-r-package/action.yaml`
(note: `action.yaml`, not `.yml`). It runs
`rcmdcheck::rcmdcheck(..., check_dir = ("check"))` with `working-directory: .`, and the
report step's default working directory is `${{ github.workspace }}`, so `list.dirs("check")`
resolves. Also worth knowing from that file: `build_args` (underscore) is the real input
name, so the diff spells it correctly, and `args` is left at
`c("--no-manual", "--as-cran")`.

**`shell: Rscript {0}` propagates.** Measured: `stop()` → exit 1 ("Execution halted"),
`quit(save = "no")` → exit 0. The `stop()` branch will redden the step.

**The branch mechanics are sound.** Probed each:

| state | result |
|---|---|
| no `check/` | `list.dirs()` → `character(0)` → prints, exit 0 |
| `check/` empty | same |
| `check/fly.Rcheck/tests/testthat.Rout` | found, skip block printed |
| renamed to `testthat.Rout.fail` | still matched by `[.]Rout` (the failure-path name) |

`file.path(character(0), "tests")` is `character(0)` — it does **not** hit the
`paste()` phantom-row trap — and `character(0)[logical(0)]` is `character(0)`.

**The grep target is real.** `testthat:::skip_report()` emits
`reporter$rule(paste0("Skipped tests (", n, ")"))` and `CheckReporter$end_reporter()`
calls it (testthat 3.3.2), so the literal `"Skipped tests"` is in the `.Rout`. `readLines()`
strips `\r`, measured, so a CRLF checkout on the Windows runner is not a hazard here.

**`if: always()` does not create a confusing second tick in the cases I could reach** —
build failure and install failure both leave no `tests/`, and a check that failed *in* the
tests leaves a `.Rout.fail` that is read normally. The residue is finding 4. The working
tree's `!cancelled()` is the better default.

**One thing the staged comment gets wrong, and the working tree has already fixed:** the
action carries its own `Show testthat output` step (`if: always()`, `shell: bash`,
`find … -name 'testthat.Rout*' -exec cat`), which prints the same skip block on all three
platforms — Windows included, via Git Bash. So the staged claim that without this step the
two states "produce the same green tick" is false. The working-tree rewrite names the step,
says what it adds (the block on its own, and a failure when the output is not there) and
withdraws the "PowerShell / neither tool" justification. Both corrections are right.

### Q1 — will it be green on macOS and Windows?

I cannot promise it, but I narrowed the exposure and found no platform-specific WARNING
path that survives inspection:

- **Non-ASCII is platform-independent** and now clean (Q3 above). No other R file carries
  a non-ASCII *literal*.
- **The CRAN-incoming URL check cannot fire.** The action's Check step sets
  `_R_CHECK_CRAN_INCOMING_=false` and `_R_CHECK_FORCE_SUGGESTS_=false` unless the caller
  already has. So `--as-cran` here does not run the incoming feasibility check at all: the
  accepted "New submission + four URLs" NOTE will not appear on CI, and — the part that
  matters for the gate — a redirect or 404 on one of those URLs cannot become a WARNING.
  The working tree already says this; the staged version does not know it.
- **A GDAL without `-alg floodfill` degrades rather than errors.** `fly_mask_one()` is
  wrapped in `tryCatch(error = …)` inside `fly_mask()`'s per-row loop, so the examples and
  the vignette would report a declined mask and carry on; `fly_georef()` leaves the
  unmasked source in place. It reddens only through `test-fly_mask.R`, which is exactly
  what the working tree's revised matrix comment now claims. (`sf` is unpinned in
  DESCRIPTION, so CI gets current sf; local is sf 1.1.2 / GDAL 3.8.5 and `nearblack` is
  dispatched.)
- **The vignette is the remaining exposure**, since a chunk error becomes
  `checking re-building of vignette outputs ... WARNING` and trips the gate. Every chunk
  that could error is either `eval = requireNamespace("terra", …)`-guarded or degrades:
  `fly_fetch()` returns `success = FALSE`, `fly_georef()`'s film-rotation refusal is
  `warning()` + `next` (R/fly_georef.R:348-365), not `stop()`, and the `[ , c("airp_id",
  "dest", "success")]` subset works because `results` is built with those columns before
  the loop.
- **Nothing else I could find:** `inst/` is 3.5 MB (no installed-size NOTE); thumbnail URL
  basenames carry no Windows-illegal characters and are 12-20 chars; the Windows runner's
  `TEMP` has no spaces; `readLines()` strips CR so the note/CSV goldens are CRLF-safe;
  `tests/testthat/_snaps` is empty **and untracked**, so the staged `upload-snapshots: true`
  was a no-op (its removal in the working tree costs nothing); and there is no
  `expect_snapshot()` anywhere, so the absence of `NOT_CRAN=true` costs no coverage — the
  suite's only `skip_on_cran()` sits directly above a `skip_on_ci()`.

### Q4 — assumptions stated as measurements

Findings 3, 4 and 5 above are the substantive ones. Two smaller ones:

- **"roughly fifteen live thumbnail fetches per job"** (working tree) is low by about half.
  Counted: 9 `fly_fetch()` calls in `test-fly_fetch.R` (the offline run printed nine
  `Downloaded 0 of N` lines), 9 in `test-fly_georef.R` (seven of them `centroids[1, ]`),
  5 across the three examples, and 3 in the vignette which `R CMD check` builds **twice**
  (build, then re-build) = 6. The working tree's move to `withr::local_tempdir()` per test
  also removes the shared-`tempdir()` / `overwrite = FALSE` dedupe that used to collapse
  repeats, so most are now distinct downloads. ~30 is the honest figure; either re-derive
  it or drop the number.
- **"a green PR check meant the docs site built, and nothing else"** (header, both
  versions). `pkgdown::build_site_github_pages()` runs every `@examples` block and knits
  the vignette, so ubuntu has in fact been executing the example code and the GDAL path on
  every PR — without the tests, without `R CMD check`, and without going red when
  `fly_mask()` declines. The two sentences after it are exactly right: I confirmed no
  R-CMD-check workflow has ever existed here (`git log --diff-filter=AD -- .github/workflows`
  returns only `pkgdown.yaml`, added at v0.1.0).

**Citations all resolve**, which is worth saying since four of them are load-bearing:
`R/fly_fetch.R:104` = `ok <- tryCatch({`; `R/fly_georef.R:314` = `if (!fetch_result$success[i]) next`
(exact); `R/fly_mask.R:98` = `if (!length(src)) {` (exact);
`tests/testthat/test-fly_camera_patb.R:239` = `skip_on_ci()` (exact).

---

## Method

- Defect restoration for the WARNING: `R/` copied to the scratchpad, literal em dash
  re-inserted with `perl -CSD`, `tools:::.check_package_ASCII_code()` run on both.
- Offline measurement: `http_proxy`/`https_proxy` pointed at `127.0.0.1:9`,
  `pkgload::load_all()` + `testthat::test_file(reporter = "silent")`, counts read off the
  returned object rather than the console. The staged (`HEAD`) `test-fly_georef.R` was run
  from a scratch copy of `tests/testthat/` so the repo was never touched.
- `r-lib/actions@v2` `check-r-package/action.yaml` fetched and read directly, not recalled.
- Workflow YAML parsed with `yaml::read_yaml()` to confirm where `concurrency` binds.
