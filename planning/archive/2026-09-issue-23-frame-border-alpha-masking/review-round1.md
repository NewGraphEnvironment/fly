# fly_mask() — review round 1

Staged diff: `R/fly_mask.R` (new), `tests/testthat/test-fly_mask.R` (new), `man/fly_mask.Rd`,
`NAMESPACE`. Reviewed against `soul/conventions/code-check{,-r,-spatial,-shell}.md`, fly
`CLAUDE.md`, `inst/notes/border-masking.md`, `data-raw/mask_calibrate-border_threshold.R`
and the shipped `inst/extdata/mask_border_sweep.csv`.

Suite as staged: **FAIL 0 | PASS 52**. `lintr::lint("R/fly_mask.R")` clean.
`devtools::document()` produces no NAMESPACE/man churn.

Note: while this review was running, `R/fly_mask.R` gained an **unstaged** fix replacing
`is.finite(frac_in) && frac_in > max_interior` with a separate `!is.finite(frac_in)`
refusal arm. That was on my list as a guard-fails-toward-pass and is **resolved in the
working tree** — it is not repeated below. `test-fly_mask.R` gained a matching test in the
same edit ("an unmeasurable interior fraction refuses the mask rather than writing it"), and
it is correctly built: `local_mocked_bindings(.package = "fly", .env = parent.frame())` is the
form that both targets the right namespace and unwinds with the test, and mocking is the right
call here because no fixture can make GDAL decline to report statistics. Nothing to add.

---

## Findings

### 1. [bug] `R/fly_mask.R:72`, `:142`, `:115` — the threshold is validated by one coercion and applied by another, so a factor threshold silently masks nothing

`fly_check_threshold()` deliberately converts through `as.character()` and says why:

```r
# `as.character()` first: `as.integer()` on a factor returns its LEVEL CODE, so a
# threshold read from a CSV as a factor would validate as one number and be applied as
# another.
```

The validation is right. **Its return value is then discarded** (`fly_check_threshold(threshold)`
at line 72, not `threshold <- fly_check_threshold(threshold)`), and the raw argument is what
reaches GDAL at line 142 — `as.character(as.integer(threshold))` — which is exactly the level-code
read the comment forbids. `fly_mask_row()` line 115 does the same, so the reported `threshold`
column is wrong too.

Measured on a fixture with a 10 px collar:

```
threshold = 16L          -> mask_fraction 0.2256   threshold column 16
threshold = factor("16") -> mask_fraction 0.0000   threshold column 1     <- -near 1
```

So a factor passes validation as 16, runs at `-near 1`, masks **nothing**, and returns
`masked = TRUE` with `mask_fraction = 0` — which this function's own roxygen defines as a
legitimate no-collar answer ("A mask fraction of **zero is not a warning**"). There is no
signal anywhere that the collar is still on the image. `threshold = "16"` (character) is
unaffected; only the factor path diverges.

The test cannot see it: `test-fly_mask.R:192` exercises only `factor("300")`, i.e. the
**rejected** case, where validation and application happen to agree because nothing is applied.
No test passes an *accepted* factor.

Fix is one word: `threshold <- fly_check_threshold(threshold)`, and pass that value down.
Same family as `code-check.md` → "A coercion that truncates rather than refusing defeats a
guard watching for NA" (rtj#265).

### 2. [bug] `R/fly_mask.R:67` vs `:271` — the calibration test guards a constant no production code path reads

`fly_mask_threshold()` returns `16L` and carries the whole derivation argument in its roxygen.
`fly_mask()`'s signature default is the **literal** `16`. Grepping `R/` for
`fly_mask_threshold()` returns exactly one hit, and it is inside a comment on line 276:

```
R/fly_mask.R:276:#' `fly_mask_threshold()`, and below the smallest a runaway produces.
```

So the shipped default and the calibrated constant are one fact stored twice, with nothing
tying them together. `test_that("both constants are where the shipped sweep says they should
be")` recomputes the plateau from the sweep and asserts it against `fly_mask_threshold()` —
a function the exported entry point never calls.

Restore-the-bug, per `code-check.md`:

```
sed -i '' 's/threshold = 16,/threshold = 64,/' R/fly_mask.R
testthat::test_file("tests/testthat/test-fly_mask.R")
#> [ FAIL 0 | WARN 0 | SKIP 0 | PASS 52 ]
```

Threshold 64 is not a benign edit — the shipped sweep says it takes the worst interior
fraction to **0.7159** and puts **32 of 264** frames over the 0.05 cap. All 52 tests stay
green, including the calibration test, because none of them can see the default.

`fly_mask_max_interior()` does **not** have this problem: it is the default of `fly_mask_one()`'s
`max_interior`, so the cap half of that test is load-bearing. Only the threshold half is
decoration.

Fix: `threshold = fly_mask_threshold()` in the signature, or add
`expect_identical(as.integer(formals(fly_mask)$threshold), fly_mask_threshold())`.
The first is better — it removes the second copy rather than checking it.

Measured sweep values, for whoever re-pins this: worst legitimate interior at thr 16 =
**0.01312**, max interior at thr 48 = **0.237895**, so the band and the 0.05 constant are
correct as documented. The test's plateau reproduction matches
`data-raw/mask_calibrate-border_threshold.R:173` exactly (same `tol`, same `hit[1]`, same
`!is.na` filter) and gives q99 = 16, max = 16 over 242 frames — that part is sound. 22 of 264
frames never plateau within the swept range and are dropped by **both** generator and test;
consistent, but undocumented, and those are precisely the frames that would want the highest
threshold. Worth a sentence in the note.

### 3. [bug] `R/fly_mask.R:96-98` — zero-length `src` returns `NULL`, not the documented tibble

```r
results <- do.call(rbind, rows)   # rows is list() -> results is NULL
message("Masked ", sum(results$masked), " of ", nrow(results), " images")
```

Measured: `fly_mask(character(0), dest_dir = tempfile())` returns **`NULL`**, prints
`Masked 0 of  images` (empty count — `nrow(NULL)` is `NULL`), and
`out[, c("mask_fraction", "masked")]` returns `NULL` rather than a 0-row frame.

The `@return` promises "A tibble with one row per input", and the roxygen **example is the
exact trigger**:

```r
masked <- fly_mask(fetched$dest[fetched$success], dest_dir = tempdir())
masked[, c("mask_fraction", "mask_fraction_interior", "masked")]
```

`fly_fetch()` returns a `success` column, so a run where nothing downloads — a network blip
during `R CMD check`, or an AOI whose thumbnails 404 — hands `character(0)` to `fly_mask()`
and the next line silently yields `NULL` instead of an empty tibble. `code-check.md` →
"Zero-length, empty, and unset are three different things".

Guard it: `if (!length(src)) return(fly_mask_row(character(0), ...))` — or build the empty
tibble from `fly_mask_row()` with zero-length inputs so the column set stays derived from one
place, which is the whole point of that helper.

### 4. [bug] `R/fly_mask.R:77` — the output path is derived from `basename()` alone, so two sources collide and an extensionless source can be overwritten in place

`out <- file.path(dest_dir, sub("\\.[^.]+$", "_masked.tif", basename(s)))`

**(a) Collision across directories.** Two rolls staged in separate directories with the same
frame filename map to one output. Measured with two visibly different images both named
`frame.tif`:

```
source                          dest                       mask_fraction  masked
.../file...beaf/frame.tif       .../frame_masked.tif       0.2256         TRUE
.../file...f32b/frame.tif       .../frame_masked.tif       NA             TRUE
```

Row 2 reports `masked = TRUE` and hands the caller **row 1's image** as its masked copy. It
takes the `!overwrite && file.exists(out)` resume branch at line 79, which cannot tell a copy
of *this* frame from a copy of a different one. With `overwrite = TRUE` the direction reverses:
the second run overwrites the first, and row 1's `dest` then points at row 2's content. Either
way a frame is silently attributed another frame's pixels, with `masked = TRUE`. Same shape as
`code-check.md` → "A cache keyed on fewer inputs than the comparison varies".

**(b) In-place destruction of an extensionless source.** `sub("\\.[^.]+$", ...)` does not match
a name with no extension, so `basename(s)` passes through unchanged and `out == s` whenever
`dest_dir` is the source's own directory. Measured:

```
fly_mask(s, dest_dir = dirname(s), overwrite = TRUE)
#> dest == source: TRUE
#> source md5 changed: TRUE      bands before/after: 1 / 2
```

The original scan is replaced by its masked copy. With `overwrite = FALSE` the same collapse
takes the resume branch and returns `masked = TRUE` pointing at the **unmasked** original.

Narrow trigger, unrecoverable outcome, and one line closes both: refuse when
`normalizePath(out) == normalizePath(s)`, and refuse (or disambiguate) duplicate `out` values
within a batch — `anyDuplicated(out)` over the vector before the `lapply`.

### 5. [bug] `R/fly_mask.R:55-56` — "38 of the 264 measured frames carry no collar" is contradicted by the sweep, the note, and the test in the same commit

Roxygen: "**38** of the 264 measured frames carry no collar at all".
`inst/notes/border-masking.md:44`: "**27** of the 264 carry no collar at all".
`tests/testthat/test-fly_mask.R:174`: "**27** of the 264 measured frames carry no collar at all".

Recomputed from the shipped sweep at the working threshold:

```
frac_total == 0     at thr 16 : 23
frac_total < 0.002  at thr 16 : 27   <- matches the note and the test
frac_total < 0.005  at thr 16 : 45
```

There is no reading of the sweep that gives 38. This is user-facing help rendered to pkgdown,
and it is the only one of the three restatements that is wrong. `karpathy.md` §7 — derive every
number from the artifact it describes.

### 6. [bug] `R/fly_mask.R:40-42` — the "0.3% against 2.7%" comparison uses two figures the notes measure differently, one of which the notes say in bold not to use this way

Roxygen: "the exact-zero matching `fly_georef()` used before v0.11.0 masked a median of
**0.3%** of the frame against the **2.7%** actually there."

`inst/notes/border-masking.md:66-70` and the sweep:

```
median mask fraction, threshold 0  : 0.0016   (0.16%, not 0.3%)
median mask fraction, threshold 16 : 0.0311   (3.11%, not 2.7%)
```

The 2.7% is the note's **raw dark fraction** median (0.027) from the circle-falsification
table, which that section flags explicitly:

> These rows measure **raw darkness** … Do not read these numbers as mask fractions; those are
> in `mask_border_sweep.csv`.

So the paragraph pairs a mask fraction with a dark fraction and calls both mask fractions —
the misreading the note added a warning to prevent. It also understates the defect it exists to
describe: the note's own ratio is **19.8x**, the roxygen's numbers imply 9x.

The neighbouring uses are correct and should stay: "median area is 2.7% where an inscribed
circle implies 21.5%" (line 36) is the dark fraction used as a dark fraction, and
"bcb90128 frame 213 … 7.7% … 2.5%" (line 31) matches `border-masking.md:89` (0.0767 / 0.0252)
to the digit.

### 7. [fragile] `R/fly_mask.R:79-81` — the resume branch reports a `threshold` the file on disk may not have been made with

The warm path checks only `file.exists(out) && file.size(out) > 0`, then returns
`threshold = <the value the caller asked for>` and `masked = TRUE`. A copy written on an
earlier run at a different threshold is returned as current, labelled with the *requested*
threshold rather than the one it carries, and never re-checked against the interior cap. The
row is indistinguishable from a fresh mask except that both fraction columns are `NA`.

`code-check.md` → "Test the cold/create path of idempotent code": the warm path here is the one
that *compares before deciding*, and it compares nothing. At minimum the `threshold` column
should be `NA_integer_` on this branch, or the reason column should say the row is a resume,
so a downstream consumer can tell "masked at 16" from "a file exists and I did not look at it".

### 8. [fragile] `R/fly_mask.R:44-45` — the Byte-only limitation is documented but not detected, and its failure mode is the one the docs call correct

"It assumes **Byte** bands and does not transfer to 16-bit scans." Nothing checks the band type.
On a 16-bit scan `-near 16` reaches essentially nothing, so the result is `mask_fraction ≈ 0`,
`masked = TRUE`, no warning — which line 55 defines as the right answer for a frame with no
collar. The two states are given one representation.

The package's own stated disposition (`CLAUDE.md`, "Refuse rather than estimate an unknown
recording format") points the other way. `fly_gdal_info()` already returns the string; `Type=Byte`
is in it, and a refusal with its own `reason` costs one line. Not blocking for the thumbnail
route this ships against, but it is the exact case the roxygen says will arrive at full resolution.

---

## Checked and clean

Recorded so the next round does not re-probe them.

- **PAM sidecars.** `GDAL_PAM_ENABLED=NO` on the `-stats` read is correctly placed and
  sufficient. Measured after a full run: no `.aux.xml` beside the source, beside the dest, or
  anywhere in `tempdir()`. The `on.exit(unlink(c(vrt, paste0(vrt, ".aux.xml"))))` belt-and-braces
  is harmless.
- **Band indexing.** `fly_gdal_bands()` correctly returns `0L` for no match (`gregexpr()` → `-1`),
  and taking the band *count* as the alpha index is right for `nearblack -setalpha`, which appends
  alpha last. A `0` band count reaches `-b 0`, which errors in `gdal_translate` and is caught
  per-file by the outer `tryCatch` — fails loud, correct.
- **Temp-file lifetime.** `tmp` is created before `on.exit()` registers its cleanup, the rename
  happens after every refusal arm, and `file.rename()`'s return value is checked with a
  `file.copy()` cross-device fallback. This is the floodplains#83 lesson applied correctly.
- **`-srcwin` numeric formatting.** `as.character()` on a double emits scientific notation at
  1e5 (`as.character(100000)` is `"1e+05"`), which would corrupt the option vector. Not reachable:
  it needs an image ≥ 1,000,000 px on a side. At 9600 x 9000 the values are `960`/`7680`.
- **`fly_interior_srcwin()`** degenerate guard, `expect_gte(w[3], 1)` — correct, and the test
  covers the odd-dimension rounding case.
- **Fixture reachability.** `bordered_image()` genuinely discriminates flood-fill from a plain
  threshold (premise 3 asserts the two answers differ by exactly the blob area), and the collar is
  3-12 rather than 0, so it cannot be masked by the old `srcnodata = "0"` path. `flooded_image()`
  does reach the runaway arm — verified, `frac_interior` 0.75 against the 0.05 cap. Neither is
  vacuous.
- **Roxygen block placement.** No helper sits between the `@export` block and `fly_mask()`;
  `grep -c "^export(" NAMESPACE` rises by exactly 1.
- **`expect_warning` trap.** The runaway test correctly uses `capture_warnings()` + `any(grepl())`
  rather than `expect_warning(expr, regexp)`, which only inspects the first condition.

---

# fly_mask() — independent review (second reviewer, appended 2026-09-08)

Appended rather than overwriting: the review above was already in this file and was written
against an earlier revision of `R/fly_mask.R` (PASS 52). This review reads the file as it
stands now (381 lines / 411 test lines, `NOT_CRAN=true testthat::test_file()` → **FAIL 0 |
SKIP 0 | PASS 80**). The earlier revision's defects — factor threshold applied as a level
code, `do.call(rbind, list())` returning NULL on zero-length input, the 38-vs-27 collar-free
count, and the `basename()` destination collision — are all fixed in the current file and are
not repeated here.

Every claim below was probed on this machine (`/tmp/probe_mask.R`), not reasoned.

## Findings

- **[bug]** `R/fly_mask.R:187-193` — **the Byte-type guard fails toward pass when it cannot
  parse a type.** `types <- unique(sub("^Type=", "", regmatches(info, gregexpr("Type=\\w+",
  info))[[1]]))` yields `character(0)` when nothing matches, and the condition is
  `length(types) && !all(types == "Byte")` — so an unparseable `gdalinfo` short-circuits to
  FALSE and the image is masked anyway. Measured: with the `Type=` tokens stripped from a real
  `gdalinfo` string, `length(types) == 0` and *guard skipped = TRUE*. The state that then
  ships is exactly the one the comment three lines above says must never exist —
  `mask_fraction` ≈ 0 with `masked = TRUE`, indistinguishable from the documented legitimate
  no-collar answer. Note the sibling guard 30 lines below (`!is.finite(frac_in)`, line 222)
  refuses on precisely this class of unknown, with a comment explaining why: two guards, same
  "could not determine", opposite dispositions. Fix is one operator:
  `if (!length(types) || !all(types == "Byte"))`. Reachability is low (real `gdalinfo` always
  emits `Type=`), which is why the direction it fails in is the whole finding.

- **[bug]** `R/fly_mask.R:24-26` vs `:118-119`, `:128-129`, `:189-192` — **the documented
  contract for `reason` and `success` is contradicted by three of the code's own exit paths.**
  The `@return` block says `reason` is "why not, where `masked` is `FALSE`" and `success` is
  "`FALSE` only on a GDAL or file error, not on a reasoned refusal". Measured on a resume run:
  `masked = TRUE` **and** `reason = "existing file kept; pass overwrite = TRUE to remask"`, so
  a caller partitioning on `is.na(reason)` misclassifies every resumed row. And the two
  reasoned refusals disagree with each other and with the doc: the interior-cap refusal
  (line 247) correctly returns `success = TRUE`, while the non-Byte refusal (line 189) and the
  destination-is-source refusal (line 118) return `success = FALSE` — the non-Byte one framed
  in its own comment as a deliberate refusal ("as `fly_footprint()` refuses a recording format
  it cannot resolve") and cemented by `expect_false(out$success)` at `test-fly_mask.R:348`.
  One of the doc and the code has to move; as it stands `success` cannot be used to separate a
  refusal from a failure, which is the only thing that column is for.
  Related, same column: `message("Masked ", sum(results$masked), ...)` at line 146 counts
  resume rows as masked this run.

- **[fragile]** `R/fly_mask.R:113-120` — **the same-path guard's stated premise is false under
  the `fly_mask_dest()` that ships in the same file.** The comment says "A source with no
  extension yields `out == s`"; line 271 now strips the extension and appends `_masked.tif`
  *unconditionally*, so `out` can never equal `s` for any name — which
  `test-fly_mask.R:302-304` asserts directly ("the output cannot equal the input for ANY
  name"). The branch and its `"destination is the source file"` reason are unreachable. Keeping
  it as defence-in-depth is fine; the comment describing the *pre-fix* behaviour in the present
  tense is what will mislead whoever next edits `fly_mask_dest()`.

- **[fragile]** `R/fly_mask.R:100-107` — **the collision check aborts the whole batch**, which
  contradicts the per-file reporting this same function applies to every other failure
  (`"source does not exist"` at line 131, the `tryCatch` at 135, and the test at
  `test-fly_mask.R:353` that exists to pin it), and contradicts fly `CLAUDE.md`'s stated #30 /
  #47 decision that one bad frame must not take the other nineteen with it. The comment's
  justification — "there is no safe resolution" — is not the case: refusing *only* the
  colliding rows (`masked = FALSE`, `success = FALSE`, a reason naming the collision) is safe,
  per-file, and leaves every other frame masked. As written, one duplicate basename in a
  200-frame fetch discards 199 good masks.

- **[fragile]** `R/fly_mask.R:288` — roxygen claim not met: "Separate from the body so
  `fly_georef()` can reuse it and the two cannot disagree about what a legal threshold is."
  `fly_check_threshold` is referenced nowhere outside `R/fly_mask.R` (grepped across `R/`), and
  `fly_georef()` takes `srcnodata` — a *string* defaulting to `"0"` — not a threshold. The
  stated invariant ("the two cannot disagree") does not exist yet.

- **[fragile]** `R/fly_mask.R:295-296` — **a fractional threshold truncates silently rather
  than refusing.** Measured: `fly_check_threshold(16.7)` returns `16`, no warning. The test
  named "validates its arguments by value, not by coercion" (`test-fly_mask.R:210`) covers
  sign, range, length, unparseable and factor, and never a fractional value — so the one
  coercion that still happens is the one the test's own title claims to rule out. `code-check.md`
  ("A coercion that truncates rather than refusing defeats a guard watching for NA", rtj#265)
  prescribes an abort for a parseable-but-fractional value; compare against `round()` with a
  tolerance rather than watching for `NA`.

- **[minor]** `R/fly_mask.R:329-330` — `as.character()` on the `-srcwin` doubles renders values
  ≥ 1e5 in scientific notation (measured: `as.character(100000)` → `"1e+05"`), which GDAL will
  not parse. Unreachable at airphoto sizes — needs an image ~125,000 px wide — but
  `format(x, scientific = FALSE)` closes it for free, and the same function's doc already
  advertises 9600 x 9000 as the design point.

- **[minor]** `R/fly_mask.R:214-232` — only `frac_in` is checked for finiteness; a run where
  the total fraction came back `NA` while the interior one did not would write the mask and
  report `mask_fraction = NA`. Both come from the same call so divergence is unlikely, but the
  refusal is asymmetric with the reasoning at line 217-221.

## Checked and clean

- Result shape: every exit routes through `fly_mask_row()`, including the new zero-length path,
  and `test-fly_mask.R:264` pins the column set against that builder rather than a literal.
  (Note the comment at `R/fly_mask.R:154-155` is factually wrong — `rbind.data.frame` matches
  columns *by name* and does not transpose — but the practice it argues for is right and
  nothing depends on the claim.)
- Alpha band index: `fly_gdal_bands()` returns the band count, `nearblack -setalpha` appends or
  sets the last band in all four input shapes (gray, RGB, gray+alpha, RGBA), so the last band is
  always alpha. `gregexpr()`'s `-1` is handled and pinned at `test-fly_mask.R:422`.
- PAM: `GDAL_PAM_ENABLED=NO` is a real `sf::gdal_utils()` argument on the installed sf 1.1.2
  (checked `formals()`), the VRT sidecar is unlinked on exit, and no `.aux.xml` is written
  beside `tmp` or `out`.
- Temp-file lifetime: `on.exit(unlink(tmp), add = TRUE)` is armed before `nearblack` runs and is
  a no-op after a successful rename; the `file.rename` → `file.copy` fallback is checked in both
  directions, per floodplains#83.
- Fixture reachability: the collar is 3-12 (never 0) and the blob is under threshold and
  edge-disconnected, both asserted as premises; the `-nb 2` overrun is asserted as an exact
  predicted value rather than absorbed into a tolerance; the runaway fixture is the only thing
  that can reach the guard and the test asserts the reason string, not just the exit state.
- Sweep re-derivation: `worst_ok` is the least-favourable member computed from the shipped CSV,
  both margins are asserted, and a truncated CSV is caught by the row/frame-count premises
  before any of it.
