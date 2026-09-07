# Review round 2 — fly#50 (PAT-B camera identity)

Scope: `git diff origin/main...HEAD` (commits `0ba388f`, `64adb17`, `93dcf33`) plus the
staged tree. Every file changed in that range read in full.

Baseline: `devtools::test()` — `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 1444 ]`.
`pkgdown::check_pkgdown()` — no problems (the new export needs no index entry, the site
has no explicit reference section). The roxygen example was run verbatim and is offline:
the 24 bundled digital centroids reference exactly two archives, both bundled.

**Note on the working tree.** Between the first and last command of this review the
working tree gained unstaged edits to `CLAUDE.md`, `NEWS.md`, `R/fly_camera_format.R`
(+5 comment lines), `R/fly_footprint.R` (roxygen only), `inst/notes/camera-formats.md`,
`man/fly_footprint.Rd`, `tests/testthat/test-fly_georef_aspect.R` and
`vignettes/airphoto-selection.Rmd` — a parallel session. None of them touch the code
below; line numbers are against the current working tree. Nothing was touched here.

---

## Findings

### 1. **[bug]** `R/fly_camera_patb.R:261-262` — `match()` on an all-`NA` id column attributes another frame's camera

```r
m <- match(key_frame[rows], tab$key)
if (!is.na(s$airp_id)) {
  m2 <- match(id_frame[rows], tab$id)
  m[is.na(m)] <- m2[is.na(m)]
}
```

`match()` treats `NA` as a matchable value: `match(NA_character_, c("1", NA))` is `2`.
`tab$id` is `as.character(pull(s$airp_id))`, so any blank `airp_id` in a published bare-CSV
archive puts an `NA` in it. `id_frame` is `rep(NA_character_, n)` whenever the caller has
no `airp_id` column at all — which the guard at :167-171 explicitly permits, since
`film_roll` + `frame_number` is a documented alternative. The two meet and every frame
whose roll/frame key missed the archive is silently given that row's camera, serial, GSD
and `patb_source`.

Measured, with one `airp_id` blanked in the bundled bare fixture and a caller carrying
roll/frame only:

```
frame 1 (bcd12001_001, really in the file):  serial 0  camera "Vexcel Ultracam XP"
frame 2 (zzz99999_007, in NO archive):       serial 0  camera "Vexcel Ultracam XP"
                                             source d_001_fi_12_georef.csv
```

Frame 2 must be `NA/NA/NA`. This is the attributes-shifted-against-the-frame shape the
comment two lines above says the `match()`-not-`join()` choice exists to prevent (fly#37),
arriving through `NA` rather than through duplicate keys — and it fails toward a
*confident wrong sensor*, not toward a refusal, so `fly_footprint()` will draw a footprint
for it with `inferred = FALSE`.

The `key` side is safe by luck rather than by design: `fly_patb_key()` builds through
`paste0()`, so `tab$key` is never `NA` (`NA` roll becomes the literal `"na"`). Only the id
side is exposed. One line closes it:

```r
m2 <- match(id_frame[rows], tab$id)
m2[is.na(id_frame[rows]) | is.na(tab$id[m2])] <- NA_integer_
```

Reachable through documented usage; the existing test at
`test-fly_camera_patb.R:105-133` cannot see it because the bundled fixture's `airp_id`
column has no blanks and every caller it builds carries `airp_id`.

---

### 2. **[bug]** `R/fly_camera_format.R:61` + `:153` — a tie in the longest digit run silently picks by position instead of refusing

`fly_serial_tokens()` deliberately returns *all* longest-equal runs, and its comment says
so: *"ties keep both rather than picking one"*. The resolver then reads only the first:

```r
tok <- s[1]
```

So a published serial string with two equal-length digit runs resolves to whichever
appears first in the text, with `note = NA` and `inferred = FALSE`. Measured against the
shipped table:

```
"100039-327542" -> dmc100039_2006   (13824 x 7680)
"327542-100039" -> dmc327542_2017   (25728 x 14592)
```

Same identity, two different sensors, chosen by digit order. That is precisely the
ambiguity `ambiguous_serial:` exists to refuse, going unrefused — and unlike the shipped
`report_serial` values (checked: no ties among the 12 calibration rows), the input here is
arbitrary text the province writes into `ccre_lens_number` / `cam_s_no` / `lens_no`, so it
is not constrained by anything this package controls.

Either refuse on `length(s) > 1`, or resolve every token and refuse unless they agree.
Whichever, the comment at :55 and the code have to be made to say the same thing — right
now the comment describes the safe behaviour and the code implements the unsafe one.

---

### 3. **[fragile]** `R/fly_camera_patb.R:251` — `quiet` suppresses a data-integrity warning, not just progress

```r
if (length(conflict) && !quiet) {
  warning(basename(u), " gives more than one camera for ", ...)
}
```

`quiet` is documented as *"Suppress the per-archive progress messages"*. It also silences
the only notice that an archive published two different cameras for one frame key and an
arbitrary one was taken. Measured on a fixture with a conflicting duplicate row:

```
quiet = TRUE   -> "Vexcel Ultracam XP", no warning
quiet = FALSE  -> WARNING SEEN: ... gives more than one camera for 1 frame key(s) ...
```

Every test in the suite calls with `quiet = TRUE`, and the arbitrary pick can be the same
20%-wrong sensor (`UltraCam X` vs `UltraCamXp`) the whole serial-before-name design exists
to refuse. A `warning()` about the data should not be gated on a verbosity flag about
progress; move it outside the `!quiet` test, or document `quiet` as suppressing it.

---

### 4. **[fragile]** `R/fly_camera_patb.R:83-88` and `:222-227` — an extraction failure is reported as "no camera identity"

```r
ex <- file.path(dirname(path), paste0(".", basename(path), "_x"))
dir.create(ex, recursive = TRUE, showWarnings = FALSE)
members <- tryCatch(utils::unzip(path, exdir = ex), error = function(e) character(0))
```

Both failure paths are swallowed — `showWarnings = FALSE` on the `dir.create`, `tryCatch`
on the `unzip` — and both land on the caller's message:

```
No PAT-B table in <archive> - it holds no camera identity (a 404 body, or `.ori` only).
N frame(s) left unresolved.
```

That sentence asserts a cause. An unwritable `dest_dir`, a full disk or a corrupt archive
all produce it, and the operator is pointed at the province's data rather than at their
own filesystem. Same family as `code-check.md`'s "a guard that fires correctly and then
points at the wrong fix". Distinguish "could not read it" from "it holds nothing"; the
empty-parse-is-not-a-pass row applies too.

Secondary, and confirmed: the extraction directory is created inside `dest_dir` and never
removed, so a persistent cache accumulates hidden trees —

```
.d_003_fi_13_georef.zip_x/2013-093EKLMN_103HI.ori
.d_003_fi_13_georef.zip_x/d_003_fi_13_georef.txt
.d_005_emn_19_georef.zip_x/D_005_EMN_19_georef.csv
```

`tempfile()` + `on.exit(unlink())` avoids both the writability coupling and the litter,
at the cost of re-extracting per call.

---

### 5. **[fragile]** `data-raw/make_testdata.R:252` — `patb_get()` blesses a truncated cached download

```r
if (!file.exists(dest)) utils::download.file(url, dest, mode = "wb", quiet = TRUE)
```

This is the exact guard the same branch adds to `fly_fetch()` (`R/fly_fetch.R:92`, with a
comment naming the trap), not applied here. `download.file()` truncates its target before
writing, so an interrupted fetch leaves a short or empty file that `file.exists()` then
accepts on every later run. `stopifnot(nrow(d) > 0)` catches the empty case; it does not
catch a partial CSV, which regenerates a silently short fixture. `&& file.size(dest) > 0`
plus a row-count check, or the same non-empty guard already written next door.

---

## Checked and clean

Recorded so a later round does not re-derive them.

- **`agree()` cannot be vacuous on the shipped table.** All 12 `calib_file` rows carry
  non-`NA` `px_cross`/`px_along`/`width_mm`/`height_mm`; the restriction to `calib_file`
  keeps the four all-`NA` `focal_length` rows out, which is what would have made it so.
  `length(rows) == 1` gives `unique()` length 1 — correct, not vacuous.
- **The two-pass index is built as designed.** Dumped: `report` maps `20814295` to the
  four agreeing UltraCam Eagle rows and `22814295` to the 2018 row alone; `key` maps
  `20814295` to all five (which is why it must run second), and carries `100039` for the
  DMC that `report` only has as `0039`. `_YYYY` is stripped — no `2011`…`2019` token in
  either index.
- **`nchar >= 3` / all-zeros filter.** `"0"` → no token → falls through to the name (which
  is what the 2012 archives need); `"000000-12"` → longest run is the zeros, filtered,
  and `"12"` was never a candidate. Correct.
- **`take(i, ...)` with a scalar index.** `out$x[i] <<- from$x` on a 1-row data frame is
  fine; the mocked table in `test-fly_camera_serial.R` reaches the same path.
- **`patb_note` and the `paste0` NA trap.** Both appends (`fly_camera_format.R:335-344`
  and `fly_footprint.R:672-678`) use `ifelse(is.na(...))` rather than pasting blindly.
  Verified the fallback-plus-refusal string `"focal_length=100; unknown_serial:10519431"`.
- **`refused <- is.na(width_in) & !from_table & !is.na(fmt$width_source)`** is a strict
  generalisation of the old `startsWith("withheld:")` test — a withheld row has
  `width_mm = NA`, so `from_table` is `FALSE` and it still lands. No row that resolved can
  enter it.
- **`gsd_from_patb`.** `use_pg` requires `(is.na(gsd_m) | gsd_m <= 0)`, so the catalogue
  value is never overwritten; `& by_gsd` afterwards keeps the tag off rows sized another
  way. Units match `fly_gsd_m()` (centimetres) and the 6003/6003/5002.5 m assertion in the
  test pins it.
- **Schema dispatch order.** A `bare` file cannot match `gr` (no `frm_roll_frame`) or
  `eop` (no `cam_s_no`); `gr` is tested first and `eop` before `bare`, so an `eop` file
  that also carried a `camera` column still dispatches as `eop`. Confirmed against all
  three fixtures' real headers.
- **`pull()` returning `rep(NA, nrow(d))`.** Logical `NA`, but every consumer coerces —
  `as.character()` → `NA_character_`, `as.numeric()` → `NA_real_`. No logical leaks into a
  character column.
- **`fly_patb_attach()` really preserves a tibble.** `$<-` has no `st_sf()`-style
  first-argument branch; the `centroid_shapes()` sweep covers plain / tibble / grouped /
  `bcdc_sf` and passes.
- **Zero-row input** returns 0 rows with `camera_serial` character and `patb_gsd` numeric.
- **`fly_fetch()`'s new `file.size(dest_file) > 0`** is the right shape and does not change
  the 404 path (`download.file()` with FAILONERROR leaves no file, so `file.exists()` is
  already `FALSE`).
- **The 404 fixture** is caught by content (`^\s*<`), and a leading-blank-line HTML body
  would still be refused one step later by the schema dispatch.
- **The live canary** (`test-fly_camera_patb.R:236`) is correctly gated `skip_on_ci()` +
  `skip_if_offline()`; `curl` was added to Suggests, which `skip_if_offline()` needs. It
  ran and passed locally, so `SKIP 0` is honest rather than a hidden skip.
- **The two label tests in `test-camera_formats.R`** are not vacuous: the premise
  `expect_gt(max(table(calib$camera)), 1L)` guards the per-row tautology, and the second
  test restores the `70912643_2015` mislabel and shows the invariant goes red on it.
