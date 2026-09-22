# Review round 3 — fly#52

`/code-check`, round 3. Scope as briefed: name the **mechanism** behind the defect-inside-a-fix,
say whether the enumeration already run is the right candidate set, and scrutinise the four
specific items listed.

**Note on the snapshot.** The `files.txt` / `staged.diff` handed to this round were **stale for
`tests/testthat/test-fly_mask.R`**: they carry the 19-line GDAL block, the index carries a
28-line one that already strips a dev/beta suffix. `.github/workflows/R-CMD-check.yaml` and
`tests/testthat/test-fly_georef.R` were verified byte-identical to the index (`diff` → no
output). Everything below was checked against `git show :<path>`, not the snapshot.

---

## The mechanism

`findings.md` names it as:

> a claim about **external** behaviour — GitHub Actions' concurrency semantics, `rcmdcheck`'s
> `error_on` semantics — written into a comment from recollection rather than read from its
> source.

That is one modifier too narrow, and the modifier is the load-bearing half. Look at the three
rounds together:

| round | defect | subject of the claim |
|---|---|---|
| 0 (plan) | "an outage cannot redden this gate", evidenced by three *example* call sites | the **tests**, i.e. this repo |
| 1 | job-level `concurrency` group had no matrix value | GitHub Actions |
| 1 | `error-on: "error"` comment inverted | rcmdcheck |
| enum | `-alg floodfill` floor taken as 3.7 from this repo's conventions | GDAL |

Round 0's blocker is already an **internal** claim — the sentence was about `tests/`, and the
file:line evidence pinned to it was about `man/`. It sits in the same table as the other three
and the "external" framing does not cover it.

What all four share is one level up:

> **A load-bearing claim was asserted in a medium that cannot execute it — a YAML comment, a
> roxygen comment, a plan bullet — and the file's own idiom (long, confident, citation-dense
> prose) made each one read as already verified. Whether the subject is GitHub, rcmdcheck, GDAL
> or this repo's own test file is incidental. What is common is assertion without execution, in
> a place where nothing will ever disagree.**

Externality was a property of three of the instances, not of the mechanism. Partitioning the
candidate set on it is the "literal set used as a filter" failure in `code-check.md` — the
filter covers whatever the data happened to contain when it was written.

## Is the enumeration the right candidate set?

**Right method, wrong population.** It is missing at least two axes, and neither is empty.

- **Axis A — external behaviour.** Enumerated, 13 claims, 3 wrong. I re-derived five of them
  independently and they hold: `check-r-package@v2`'s `action.yaml` (fetched) confirms
  `error-on` default `"warning"`, `check-dir` default `"check"`, the two `_R_CHECK_*` vars
  forced only when unset, and `Show testthat output` ending `|| true` under `shell: bash` on
  every platform; `setup-r/src/installer.ts:829` confirms `NOT_CRAN=true` unless already set.
  This axis looks closed.

- **Axis B — claims about *this* repo.** Absent from the table entirely: 8 `file:line`
  citations, a block count, a NEWS restatement, two stage-ordering claims. This is the axis
  **most** likely to rot — a line number is invalidated by any edit above it, and this PR edits
  two R/test files — and the **least** likely to be re-checked, because "our own code, I know
  what's in it" is the same recollection failure under a friendlier name. I enumerated it
  mechanically (`git diff --cached -U0 | grep '^+' | grep -oE '[A-Za-z_/.-]+\.(R|Rmd)[:.][0-9]+'`
  plus every `N <noun>` phrase) and executed all 12 members. **Two failed** — findings 1 and 2
  below. One of them was broken *by this diff*.

- **Axis C — claims about what happens when this is pushed.** One member, also absent, also
  wrong: finding 3.

**On termination.** The stopping rule is not "a round came up quiet" but "the candidate set was
enumerated mechanically and every member executed". Axis A was. Axis B and C now have been, in
this round, and each is small and closed by count (12 and 1). Once findings 1–3 are fixed, the
enumeration closes — by count, not by silence.

---

## Findings

- **[fragile] `planning/active/task_plan.md:~36` and `planning/active/findings.md:~250` —
  `test-fly_mask.R:158` is a dead pointer, and this diff is what killed it.**
  Both files cite `test-fly_mask.R:158` as the line that greps `"flood into the image"` from the
  string changed in `R/fly_mask.R`. At `HEAD` that was exact (verified:
  `git show HEAD:tests/testthat/test-fly_mask.R | grep -n 'flood into the image'` → 158). The
  staged hunk inserts the 28-line GDAL premise block at the top of that file, so the assertion
  is now at **line 186** and line 158 is **blank**. This is the *whole* argument that the
  `—` substitution is invisible to consumers, and it now points at nothing. Axis B,
  self-inflicted, one-line fix.

- **[fragile] `.github/workflows/R-CMD-check.yaml:103-104` (restated in `findings.md` and
  `review-plan.md` B1) — "Seven blocks in test-fly_georef.R asserted
  `expect_true(result$success[1])`". Four did.**
  Measured against `HEAD`: that assertion appears in exactly four blocks — "produces
  georeferenced TIFFs", "accepts rotation parameter", "auto rotation uses bearing", "reads
  rotation from column" (`grep -c` → 4; `awk` attribution → those four). The *count* seven is
  correct for **unguarded blocks** (12 total − 2 already guarded − 3 needing no network = 7) and
  all seven were correctly guarded. The *assertion named* is wrong: three of the seven
  ("returns expected columns", "skips existing when overwrite is FALSE", "extent matches
  footprint") never touched `result$success`. This is the PR's own record of what was broken,
  restated in three files (the "documents that share an ancestor" shape), and anyone who later
  greps for the named assertion to find "the seven" finds four and concludes three guards were
  gratuitous.

- **[fragile] `planning/active/task_plan.md` Phase 3/4 (O7) — "the PR's first run goes red …
  the next goes green" will not happen as planned, and both changes are staged together right
  now.**
  `pull_request` fires one `synchronize` per **push**, at the resulting head SHA — not one per
  commit. Two commits in one `git push` produce **one** run, against a tree that already
  contains the non-ASCII fix, i.e. green. And `git diff --cached --stat` currently shows
  `.github/workflows/R-CMD-check.yaml` **and** `R/fly_mask.R` in the same index, so as staged
  they are one commit and the red run is unreachable. O7's entire payoff — "converts an
  assertion into a run ID", the only evidence that `error-on: "warning"` is a live gate on a
  runner rather than on the author's laptop — is lost silently: the Phase 4 checkbox "The first
  run … is **red**" gets ticked against a green run or quietly dropped. Procedural fix: commit
  the workflow alone → push → open the PR → confirm red → commit `R/fly_mask.R` → push again.
  (Filed here rather than waived under "planning/ is a work record" because it is an
  instruction that will be executed and will not do what it says.)

- **[fragile] `.github/workflows/R-CMD-check.yaml:38-40` — "a runner whose GDAL drops below it
  fails by naming the cause rather than as an opaque `nearblack` error." The opaque error
  arrives *first*.**
  `R CMD check` runs `checking examples` **before** `checking tests`. `fly_mask()`'s roxygen
  example fetches a thumbnail and calls `fly_mask()`, which reaches
  `sf::gdal_utils("nearblack", options = c("-alg", "floodfill", …))` (R/fly_mask.R:255, verified
  exact). On a GDAL below 3.8 that errors in the example stage, ahead of the premise test. Both
  failures appear; the opaque one is at the top of the log, which is where a reader starts. The
  claim is "as well as, second", not "rather than". (`test-fly_mask.R` is the only other caller
  — `grep -ln "fly_mask("` over `tests/` returns it alone — and the premise is first in that
  file, so the *test-stage* half of the claim is correct.)

- **[fragile] `tests/testthat/test-fly_mask.R:29-31` — the suffix strip re-opens the
  fail-toward-pass window for exactly one release: the floor's own.**
  The index version is the fixed one and it is sound for every realistic shape (measured:
  `3.8.5`→3.8.5, `3.11.0dev`→3.11.0, `3.9.0dev-5b4b9dbd`→3.9.0, `3.10.0beta1`→3.10.0,
  `3.11.0-dev`→3.11.0, `3.8.5rc1`→3.8.5; `3`, `GDAL 3.8.5` and `3.8.dev` are caught by the
  `expect_match` shape guard; `3.10.0 >= 3.8.0` is TRUE because `numeric_version` compares
  numerically, not lexically). The residual: GDAL names a development build for the
  **upcoming** release, so `3.8.0dev` is a build from *before* 3.8.0 — possibly before the
  `-alg` commit — and it strips to `3.8.0` and **passes** (measured). That is the same
  direction the comment three lines above warns about, one release narrower. Vanishingly rare
  and I would not block on it, but it is the one place a fix changed a comparison's semantics,
  so it belongs in the record rather than in nobody's head.

- **[fragile] `.github/workflows/R-CMD-check.yaml:92-95` — the comment enumerates three
  consumers of the network and answers two.**
  "…runs every example, builds the vignette and then rebuilds it, and runs the tests — all
  three of which fetch thumbnails." EXAMPLES get a paragraph, TESTS get a paragraph, the
  **vignette gets none**. I checked it and the claim does hold: `vignettes/airphoto-selection.Rmd`'s
  `fetch-georef` chunk has no `eval`/`error` guard, but survives an outage for the same reason
  the examples do (`fly_fetch()` → `success = FALSE`, `fly_georef()` skips the row at
  `R/fly_georef.R:314`, the chunk only prints a 3-row tibble), and R's re-build step escalates
  only on a non-zero exit from the vignette subprocess or a `^Warning: file .* is not portable`
  line (read from `tools:::.check_packages`), so `download.file()` warnings cannot turn it into
  a check WARNING under `error-on: "warning"`. So: not a defect — an unevidenced third of three,
  in a comment whose entire purpose is to be the evidence.

- **[fragile] `.github/workflows/R-CMD-check.yaml:36` — "ubuntu-24.04 ships 3.8.4, one patch
  release above it."** The asserted floor is **3.8.0**, so 3.8.4 is four patch releases above
  it, not one. (Reads like a sentence written against the earlier 3.7 draft and not re-derived
  when the floor moved.) I did not independently verify that noble ships 3.8.4; the arithmetic
  error is independent of that.

- **[fragile, pre-existing, not caused by this diff] `tests/testthat/test-fly_georef.R:242-250`
  — "skips existing when overwrite is FALSE" cannot fail when nothing is written.**
  `f <- list.files(dest_georef, full.names = TRUE)[1]` is `NA_character_` if `fly_georef()`
  produced no TIFF; measured, `file.mtime(NA_character_)` returns `NA` and
  `expect_equal(NA, NA)` **passes**. So the block passes over nothing in that state. It is not
  currently vacuous (`centroids[1, ]` has no bearing, so the axis-aligned path writes a file),
  and the new `skip_if_not(all(fetched$success))` makes the empty state *less* reachable, not
  more — **no regression from this diff**. Recorded because the guard this PR added is the
  right guard for the other six blocks and the wrong one for this one: the property it needs is
  "a file exists", which nothing asserts.

---

## Checked and clean (so the scope of this round is legible)

The four items the brief asked me to scrutinise:

1. **Did guarding change what any block asserts?** No. All seven guards are inserted between
   `fly_fetch()` and the first use of its result; no assertion was added, removed or reworded
   (`diff` of the index against `HEAD` per block). The **mtime block**: `dest_georef` was an
   unlinked fixed path before and is a fresh `local_tempdir()` now — both start empty, and both
   `fly_fetch()` and `fly_georef()` create with
   `dir.create(recursive = TRUE, showWarnings = FALSE)` (R/fly_fetch.R:65, R/fly_georef.R:206),
   so a pre-existing empty directory is fine where the old code passed a non-existent one. The
   **rotation loop**: measured — `for` creates no frame, so all iterations' `local_tempdir()`s
   coexist, are distinct, and are cleaned only when the enclosing `test_that` frame exits; four
   distinct output directories, exactly as the four fixed names gave before.
2. **Did `local_tempdir()` make anything vacuous via a lost directory?** No. At `HEAD` all 14
   paths were distinct names, each `unlink()`ed immediately before use — no block depended on
   another's directory, so there was nothing to break.
3. **`package_version()` on GDAL's string** — answered above; the index version already strips
   the suffix and shape-guards it, with one narrow residual.
4. **Anything in the YAML that will not do what its comment says** — findings 2, 4, 6, 7 above;
   everything else held.

Also verified and correct:

- `expect_gte()` accepts `label =` (not the `info =` trap) and renders it in the failure
  message; it discriminates — restoring the defect, `expect_gte(package_version("3.7.0"),
  package_version("3.8.0"))` fails. Not decoration.
- `skip_if_offline()` → `skip_on_cran()` + `check_installed("curl")` (testthat 3.3.2 source).
  Both premises hold on CI: `curl` **is** in `Suggests` and `needs: check` installs Suggests;
  `setup-r` sets `NOT_CRAN=true` unless already set (`installer.ts:829`), so `skip_on_cran()`
  does not silently swallow all nine guarded blocks.
- `file.path(character(0), "tests")` is `character(0)`, **not** the `paste()` length-1 trap — the
  "no `check/` directory" branch is correct.
- `list.dirs("check", recursive = FALSE)` returns `check/fly.Rcheck` and not `check` itself;
  driven against a fixture tree, all four branches reachable.
- testthat's `skip_report()` emits the literal `Skipped tests (N)` via `reporter$rule()`, so the
  `fixed = TRUE` grep matches, and `CheckReporter$end_reporter()` calls it **before** the failure
  block, so the step's tail-print carries skips, failures and the summary line.
- `test-fly_camera_patb.R:239` is `skip_on_ci()` exactly, and GitHub sets `CI=true`, so `hit`
  is guaranteed TRUE on a runner and the `!hit` branch is a genuine backstop.
- File:line citations: `R/fly_georef.R:314`, `R/fly_mask.R:98`, `R/fly_mask.R:255`,
  `R/fly_mask.R:293`, `R/fly_fetch.R:97`, `test-fly_camera_patb.R:239` — all exact.
  `R/fly_fetch.R:104` is the opening of the `tryCatch` whose handler returns `FALSE` rather than
  the `success = ok` return at 111; close enough to be useful, not flagged.
- v0.9.0's NEWS entry names all five functions the header comment lists.
- The non-ASCII fix is complete **for the check that fires**: nine `°` remain in `R/fly_bearing.R`
  and `R/fly_georef.R`, all inside `#'` comments, and R's check looks at parsed code (string
  literals), which is why only `R/fly_mask.R:293` was ever reported — consistent with the
  measured 0 warnings. No new non-ASCII enters `R/`.
- `gq#51` is OPEN and titled "R CMD check: clear the two pre-existing WARNINGs so CI can gate on
  them" — the comment's use of it is accurate.
- `on: push[main] + pull_request` does not double-fire for a same-repo PR branch; the
  `concurrency` group separates `refs/heads/main` from `refs/pull/N/merge` and separates the
  three runners; artifact names are made unique by `strategy.job-index`; `permissions: read-all`
  is what the r-lib template ships and does not block `upload-artifact`.
- `if: ${{ !cancelled() }}` runs after a failed check step *and* after a failed
  `setup-r-dependencies`, where the no-`check/` branch exits 0 — no second red tick.

## Not re-litigated

Outage measurement (FAIL 11 → FAIL 0 / SKIP 9), the 0/0/0 `rcmdcheck` run, FAIL 0 / PASS 2142,
the skip-report branch fixtures, and the accepted tradeoffs (`^\.git$` → fly#66, unguarded
network examples, `test-fly_fetch.R` vacuity, absent `devel`/`oldrel-1`, `planning/` as a work
record) — all taken as given per the brief. None was over-read by anything above.
