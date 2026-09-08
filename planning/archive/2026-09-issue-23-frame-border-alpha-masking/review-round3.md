# fly_mask() — review round 3

Scope: `R/fly_mask.R`, `tests/testthat/test-fly_mask.R` as on disk 2026-09-08 (the files
moved under me mid-review — the summary-message block at L164-178 and the `threshold`
column doc at L22-24 arrived after my first read; everything below is against the current
state).

Round 1 found (a)-(g), round 2 found (h)-(k) *inside* round 1's fixes. This round names the
mechanism, enumerates the complete candidate set it implies, and reports what is left.

---

## Mechanism

**Every contract in this file is written down twice — once in prose (roxygen, an inline
comment, `inst/notes/border-masking.md`) and once in code — and nothing binds the two
copies.**

Read (a)-(k) as *which copy drifted*:

| | the two copies | which drifted |
|---|---|---|
| (a) | validated threshold / applied threshold | the applied one |
| (b) | `fly_mask_threshold()` / the signature literal | the literal |
| (c) | the eight-column shape / the zero-length exit | the exit |
| (d) | destination computed in the collision check / in the loop | both, independently |
| (e) | measured figures in the sweep / figures in the roxygen | the roxygen |
| (f) | "the threshold used" / what the resume path knew | the column value |
| (g) | "it assumes Byte bands" (prose) / the absence of a Byte test (code) | the code |
| (i) | `success`'s documented meaning / each branch's local choice | the branches |
| (j) | fly#30/#47's per-frame decision / "refuse the batch" | the code |
| (h),(k) | the property the prose states / the predicate beside it | the predicate |

Every accepted fix is a **binding**: call the constant instead of copying it (b); assign the
validated return (a); route every exit through `fly_mask_row()` (c, i); compute the
destination in `fly_mask_dest()` once (d). Where a fact is bound it cannot drift; where it is
restated it has drifted, every time, without exception.

(h) and (k) look like a different mechanism ("a guard failing toward pass") and are the same
one at one remove: the prose states the property — *refuse an unknown type*, *refuse a
fractional threshold* — and the predicate written beside it (`length(types) && ...`,
`is.na(as.integer(x))`) is not equivalent to it. The copy that **runs** disagrees with the
copy that is **read**, which is why reading the guard did not find either.

**Why the class is still open after two rounds.** Both rounds swept the *code* copies and
neither swept the *prose* copies against their source of truth. (e) — wrong figures in the
roxygen — is the one prose instance that was found, and it was found by reading rather than
by measuring, so the sweep stopped at the two figures somebody happened to check. The prose
copies are checkable: `inst/extdata/mask_border_sweep.csv` ships precisely so that "the
constants are checkable inside the test suite rather than remembered". Nobody had run that
check over the whole set. Doing so is finding F1 below.

---

## Enumeration

Four sets, walked mechanically rather than from recollection. Each element gets a verdict and
how it was reached.

### A. Every `fly_mask_row()` exit — 13 of them, columns vs their documented meaning

Extracted by grepping `fly_mask_row(` in `R/fly_mask.R` (13 call sites + the definition).

| # | line | path | dest | masked | success | reason | threshold | verdict |
|---|---|---|---|---|---|---|---|---|
| 1 | 99 | zero-length | — | — | — | — | — | OK, 0 rows, shape from the builder |
| 2 | 130 | destination collides | NA | F | T | set | requested | see **F2** (fires on a repeated path) |
| 3 | 137 | destination is the source | NA | F | T | set | requested | OK (unreachable today, guarded on purpose) |
| 4 | 147 | resume | out | T | T | set | `NA` | OK — doc now states the NA (L22-24) |
| 5 | 151 | source does not exist | NA | F | **F** | set | requested | OK |
| 6 | 158 | `tryCatch` error | NA | F | **F** | message | requested | OK; probed, does not abort the batch |
| 7 | 208 | dimensions unreadable | NA | F | **F** | set | requested | OK; probed with a text file, reached correctly |
| 8 | 224 | non-Byte / unreadable type | NA | F | T | set | requested | OK, both arms tested |
| 9 | 248 | nearblack wrote nothing | NA | F | **F** | set | requested | OK |
| 10 | 269 | interior unmeasurable | NA | F | T | set | requested | OK |
| 11 | 286 | interior cap exceeded | NA | F | T | set | requested | OK |
| 12 | 295 | could not write the copy | NA | F | **F** | set | requested | OK |
| 13 | 300 | masked | out | T | T | `NA` | requested | OK |

Invariants checked across all 13, by reading every call site rather than by sampling:

- `masked == !is.na(dest)` — holds on all 13.
- `is.na(reason)` iff row 13 — holds; row 4 (resume) is the documented `masked = TRUE` with
  a reason, and the doc says so.
- `success == FALSE` iff rows 5, 6, 7, 9, 12 — all five are "stopped before concluding";
  the five refusals (2, 3, 8, 10, 11) are `TRUE`. Matches the `@return` text verbatim.
- Column order is identical on all 13 because there is one builder. Pinned by the test at
  L444-448.
- `mask_fraction` / `mask_fraction_interior` are `NA` on 9 of the 13 and the `@return` text
  documents `NA` only for `dest` — **F5**.

### B. Every guard — 17 of them, predicate vs stated property, both directions

| # | line | guard | negative arm exercised | positive arm exercised | verdict |
|---|---|---|---|---|---|
| 1 | 84 | `!is.character(src)` | everywhere | `fly_mask(1:3)` | OK; a `factor` of paths errors too (no `as.character` here), which is right |
| 2 | 98 | `!length(src)` | everywhere | L253 test | OK |
| 3 | 116 | `duplicated(outs)` | L292 third frame | L271 test | **F2** — predicate is destination-duplication, property is *distinct sources* colliding |
| 4 | 136 | `file.exists(s) && fly_same_path(s, out)` | every masked row | predicate-level only (L299) | OK by design; comment misfiled — **F3** |
| 5 | 141 | resume, incl. `file.size(out) > 0` | L334 test | L334 test | OK. `overwrite = TRUE` has **no test**; probed by hand, correct (0.1502 at 8 → 0.2256 at 16 over the same dest) |
| 6 | 150 | `!file.exists(s)` | everywhere | L471 test | OK; probed `NA_character_` in `src` → this branch, no error |
| 7 | 154 | `tryCatch` | everywhere | not tested | OK; probed with a non-image file — per-frame refusal, batch survives |
| 8 | 172 | `if (any(declined))` in the message | L100 test | L452 test | OK — `message(..., NULL)` is safe (`.makeMessage` unlists), verified in the run |
| 9 | 207 | `is.null(dm)` | everywhere | probed (text file) | OK |
| 10 | 223 | `!length(types) \|\| !all(types == "Byte")` | every Byte source | L351 + L369 tests | OK — this is round 2's (h), both arms now pinned |
| 11 | 247 | `!file.exists(tmp)` | everywhere | not reachable offline | OK |
| 12 | 261 | `!is.finite(frac_in)` | everywhere | L170 test (mocked) | OK |
| 13 | 277 | `frac_in > max_interior` | every masked row | L149 test | OK; strict `>` matches "more than" |
| 14 | 293 | `!file.rename` → `!file.copy` | everywhere | not tested | OK by reading; both failure arms return `success = FALSE` |
| 15 | 341 | threshold validation (5 clauses) | L389/L398 | L212/L389 tests | OK — length, NA, fractional, `<0`, `>255` each has a case |
| 16 | 380 | `!length(m)` in `fly_alpha_fraction` | every masked row | mocked at the caller | OK |
| 17 | 395 | `fly_gdal_bands` `-1` sentinel | L540 | L540 | OK |

### C. Every literal constant — contract, or a copy of a source of truth?

| literal | where | kind | bound to its source? |
|---|---|---|---|
| `16L` | `fly_mask_threshold()` | copy of a sweep-derived fact | yes — L516-525 recomputes the plateau quantile from the shipped CSV |
| `0.05` | `fly_mask_max_interior()` | copy of a sweep-derived fact | **half** — the lower end (L500-505) is recomputed; the upper end (L509-511) computes the **max** at threshold 48, not the smallest over-cap value → **F1** |
| `0.10` | `fly_interior_srcwin(drop=)` | a contract this repo chose | yes — stated identically in roxygen L350 and in the note; pinned by L530-531 |
| `0L` / `255L` | `fly_check_threshold` bounds | a fact about Byte range | contract, correctly hardcoded |
| `255` | `fly_alpha_fraction` divisor | a fact about `-setalpha` output | contract, correct |
| `"Byte"` | L223 | a third-party token | read from the artifact by regex, not assumed |
| `-nb` (absent, GDAL default 2) | not passed | third-party default | bound — the fixture's `collar_frac_nb` states `+2` explicitly and a tolerance of 0.005, so setting `-nb` reddens a named test |
| `"_masked.tif"`, `".tif"`, `".vrt"`, `"masked"` | various | contracts | fine |

### D. Every checkable number in prose, vs `inst/extdata/mask_border_sweep.csv`

Computed from the shipped CSV (2,640 rows, 264 frames, thresholds 0/4/8/12/16/20/24/32/48/64):

| claim | where | measured | verdict |
|---|---|---|---|
| 264 thumbnails, 1967-2018 | roxygen L46, note | 264 frames | ✓ |
| median mask fraction at threshold 0 = 0.16% | roxygen L51 | 0.001571 | ✓ |
| at threshold 16 = 3.11% | roxygen L52 | 0.031087 | ✓ |
| ratio 19.8x | roxygen L52, note | 19.788 | ✓ |
| 27 of 264 carry no collar | roxygen L70, note | 27 below the note's 0.002 criterion (23 exactly 0); the same 0.002 criterion is used by the test at L518, so it is a stated criterion rather than a fudge | ✓ |
| bcb90128_213: 7.7% plain vs 2.5% edge-connected | roxygen L42 | note's table: 0.0767 / 0.0252 | ✓ |
| median raw dark 2.7%, circle implies 21.5% | roxygen L46-47 | note's table: 0.027 / 0.2146 | ✓ |
| threshold 16 is the 99th percentile and the max plateau | note | recomputed by L516-525, passes | ✓ |
| largest legitimate interior fraction 0.0131 (bcb94081_070) at 16 | note, test L56 | 0.013120, bcb94081_070 | ✓ |
| **smallest runaway 0.2379 at threshold 48** | note | 0.2379 is the **maximum** at 48; 14 frames exceed the cap there and the smallest is **0.0510** | ✗ **F1** |
| **admissible band (0.0131, 0.2379), 4.8x below the smallest runaway** | note, echoed in `fly_mask_max_interior()`'s roxygen | true band on the note's own criterion is (0.0131, 0.0510); the cap sits **1.02x** below, not 4.8x | ✗ **F1** |
| threshold 64, bcd18704_592 = 0.7159 | note | 0.71591, same frame | ✓ |

**Termination claim.** Sets A-D are the complete image of the mechanism: every place this
file states a contract (A: a column's meaning; B: a property a predicate stands for; C: a
value with a source of truth; D: a measured number) is listed above, extracted by grepping
the call sites and by recomputing every prose figure from the shipped CSV rather than
recalling it. Three entries are unbound and are reported below. Nothing else in the four
sets sits above its source of truth.

---

## Findings

### F1 — the calibration note's "smallest runaway" is the **maximum**, so the stated margin above the cap is 4.7x too generous (`inst/notes/border-masking.md`, "The guard tests the INTERIOR fraction"; echoed at `R/fly_mask.R:421-423`; unpinnable by `tests/testthat/test-fly_mask.R:509-511`)

The note publishes:

> | smallest **runaway**, threshold 48 | **0.2379** | bcd18704_592 (2018) |
>
> Admissible band **(0.0131, 0.2379)**, geometric middle 0.0559. The constant sits at 0.05 —
> 3.8x above the largest legitimate value and 4.8x below the smallest runaway.

Measured from the shipped sweep:

```
t=16  frames over 0.05: 0    max 0.0131
t=20  frames over 0.05: 0    max 0.0143
t=24  frames over 0.05: 0    max 0.0160
t=32  frames over 0.05: 0    max 0.0465
t=48  frames over 0.05: 14   min over cap 0.0510   max 0.2379
t=64  frames over 0.05: 32   min over cap 0.0525   max 0.7159
```

0.2379 is the **largest** interior fraction at threshold 48, not the smallest runaway. At
that threshold 14 frames trip the guard; the smallest is `bc78107_221` at **0.0510**.
Whatever subset one calls "runaways", it is a subset of those 14, so the smallest is at most
0.0510. The derived figures are therefore wrong: the band is (0.0131, 0.0510), its geometric
middle is 0.0259, and 0.05 sits **1.02x** below the smallest tripping frame — the cap is at
the very top of its band, not in the middle of it.

Why it matters, given the cap is safe today. At the shipped threshold nothing comes close
(max 0.0131, and still 0.0465 at threshold 32), so no output is wrong now. The damage is to
the record: the note is the evidence a future editor uses to move the constant, and it tells
them there is 4.8x of headroom above 0.05 when there is 2%. Raising the cap toward the
"geometric middle" the note computes (0.0559) would silently admit frames the note itself
classes as floods. This is class (e) — a prose figure restating a measurement — which round 1
found twice and evidently did not sweep to completion.

The test cannot catch it. L509 computes `max(frac_interior[threshold == 48])` and the comment
beside it pins a *different* sentence ("a runaway must exceed it, or the guard could never
fire") — a correct existence claim for which `max` is the right statistic. The note's claim
is about the *minimum*, and no assertion computes one.

Fix: correct the row and the two derived numbers in the note; correct
`fly_mask_max_interior()`'s roxygen ("below the smallest a runaway produces" is true only by
2%, which is not what "both ends measured" implies); and either state the runaway criterion
so `min` is computable from the CSV, or drop the band-middle argument, which is what makes
the wrong number load-bearing.

### F2 — the same source path listed twice is refused as a collision, and the batch masks nothing (`R/fly_mask.R:116`, `129-134`)

`dup <- duplicated(outs) | duplicated(outs, fromLast = TRUE)` tests the **destination**. The
property being guarded, stated in the comment at L105-110, is that *two different frames*
must not collapse onto one file — "the second row would then report `masked = TRUE` while
pointing at the FIRST frame's pixels". Two occurrences of one path cannot do that: the pixels
are identical and there is no ambiguity to resolve.

Probed:

```r
fly_mask(c(p, p), dest_dir = tempfile())
#   masked success reason
# 1  FALSE    TRUE destination collides with another source named fileXXXX.tif; mask them into separate directories
# 2  FALSE    TRUE destination collides with another source named fileXXXX.tif; mask them into separate directories
```

Nothing is masked, and because both rows carry `success = TRUE` a caller partitioning on
`success` sees a clean run that produced no files. The remedy in the message is also wrong for
this input — there are no separate directories to mask into; the fix is to deduplicate.

Reachable through the package's own documented pipeline: `fly_mask(fetched$dest[fetched$success])`
where the centroid set carries a duplicated frame, or any `c()` of two overlapping file lists.

Fix: flag a destination only when it is reached by more than one **distinct** source —

```r
key  <- suppressWarnings(normalizePath(src, winslash = "/", mustWork = FALSE))
n_by <- tapply(key, outs, function(k) length(unique(k)))
dup  <- n_by[outs] > 1L
```

Two rows for one file then both mask and both point at the same `dest`, which is truthful.
Test both arms: `c(p, p)` must mask, `c(d1/frame.tif, d2/frame.tif)` must still refuse.

### F3 — the comment above the collision guard describes a different guard, and calls a live branch unreachable (`R/fly_mask.R:122-128`)

```r
    # Defence in depth, and currently unreachable: `fly_mask_dest()` always appends
    # `_masked.tif`, so no name can map to itself. ...
    # `test-fly_mask.R` asserts both halves: that the branch cannot fire today, ...
    if (dup[[i]]) {
```

Every sentence in that block is about the `fly_same_path(s, out)` branch seven lines below.
The `dup` branch it actually sits on is reachable, fires on real input, and has a test at
L271 proving it. A future editor pruning "currently unreachable defence in depth" removes the
guard whose absence reinstates exactly the corruption the block above it describes — a row
reporting `masked = TRUE` over another frame's pixels. Move the comment to L136.

### F4 — the falsified "refuses the batch" claim survives in two places (`R/fly_mask.R:108`, `R/fly_mask.R:306`)

Round 2's (j) changed the code from batch-abort to per-row refusal. The inline comment was
patched by appending a contradiction rather than by correcting it —

```
# whole batch rather than silently resolved, because there is no safe resolution: ...
# ...and the colliding ROWS are refused, not the batch.
```

— and `fly_mask_dest()`'s roxygen still asserts the pre-fix behaviour outright:

```r
#' ... — `fly_mask()` refuses the batch rather than letting them collide.
```

`grep -n "refuses the batch\|whole batch" R/fly_mask.R` returns both. This is the mechanism's
signature: the code copy was fixed, the prose copies were not swept, and one of them now
states the opposite of the code with no marker that it is stale.

### F5 — `@return` documents `NA` only for `dest`, while both fraction columns are `NA` on 9 of 13 exits (`R/fly_mask.R:19-21`)

`mask_fraction` and `mask_fraction_interior` are `NA` on every refusal *and* on the resume
path. The `threshold` column got its `NA` documented in this round's edit (L22-24) and the
`reason` column carries an explicit "partition on `masked`" warning; the two fraction columns
got neither, so `mean(out$mask_fraction)` over a batch with one refusal in it returns `NA`
with nothing in the docs to explain it. One clause each, matching what `threshold` now has.

---

## Verdict

The mechanism is prose-vs-code copies of one contract with nothing binding them. Sets A-D
enumerate every such copy in the two files; A and B are clean apart from F2/F3, C is clean
apart from the half-bound cap in F1, and D — the set neither previous round measured — holds
F1 and F4. Recommend fixing F1 (wrong measurement in the shipped evidence record), F2 (false
refusal, whole batch produces nothing), F3 (comment invites deleting a live guard), then F4
and F5, and pinning F1 with an assertion that computes the **minimum** over-cap value rather
than the maximum.
