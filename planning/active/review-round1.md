# Code check — round 1 — fly#38 staged diff

Reviewed: `git diff --cached` (11 files). Verified empirically, not by reading only:

- full suite run under `pkgload::load_all()` + `test_dir()`: **green**, 0 failures,
  0 `Error`/`Execution halted` markers (`/tmp/suite.log`).
- `devtools::document()` re-run: **no drift** — `man/fly_georef.Rd` and `NAMESPACE`
  already match the roxygen in the diff. `fly_digital_rotation()` /
  `fly_gcp_anisotropy()` are `@noRd` and correctly absent from `NAMESPACE`.
- `inst/notes/georeferencing.md` and `data-raw/georef_calibrate-corner_mapping.R`
  both exist and are in `HEAD`, so the new doc/warning references resolve.
- `testthat (>= 3.2.0)` bump in DESCRIPTION is correct and required — `.package =`
  on `local_mocked_bindings()` needs it.
- `fly_bearing()` does **not** reorder rows (it writes `bearing[ord[i]]` and returns
  the input object), so the `photos_sf` / `footprints` / `empty_fp` / `non_square`
  index alignment asked about in the brief is sound.
- `grepl(pat, NA_character_)` is `FALSE`, not `NA`, so the `width_source` block cannot
  propagate `NA` into `any()`.
- The three-way `empty_fp` / `non_square` classification genuinely removes the ordering
  hazard: `if (empty_fp[j]) next` runs before `footprints[j, ]` is ever subset, so
  `georef_one()` is never handed an empty ring, and `fly_is_square()`'s TRUE-on-EMPTY
  is masked out of `non_square` by construction.
- Rotation-selection trace over every combination of (`rotation` arg, column present,
  column `NA`, `film_roll`/`frame_number` present): the **rotation choice** for film is
  unchanged from the pre-diff code in all of them. See Finding 1 for the one place film
  behaviour *is* changed.

## Findings

### 1. **[bug]** `R/fly_georef.R:297-304` — the anisotropy guard silently drops non-square **film** scans, a documented use case

The guard is written for the digital mispairing case, but it runs on every frame,
including square film footprints. On a square footprint the anisotropy is
**independent of rotation** — it reduces to the image's own inverse aspect ratio:

```
square 4000x4000 m ring, image 1250x1180 px
  rotation   0    90   180   270
  aniso    0.944 0.944 0.944 0.944     <- identical; nothing to mispair
```

(The package's own `test-fly_georef_aspect.R:110` asserts exactly this — "square film is
isotropic at every rotation, so the invariant is vacuous there".)

So for film the guard is not a corner-mapping check at all; it is a bare
"is this image square to within 5%" check, and a fail is unfixable by the user because
no rotation moves the number. Measured:

```
film scan  1250x1250 -> aniso 1.0000  refused = FALSE
film scan  1250x1200 -> aniso 0.9600  refused = FALSE
film scan  1250x1180 -> aniso 0.9440  refused = TRUE
film scan  9600x9000 -> aniso 0.9375  refused = TRUE   <- ordinary full-res 9" scan
```

`fly_georef()` is documented as working with "full-resolution scans"
(`R/fly_georef.R:5`, and the `srcnodata` tradeoff paragraph at :101-105 exists
specifically for them). A full-resolution scan that includes any of the rebate/fiducial
border is routinely a few percent off square. Those frames previously georeferenced
(stretched by that same few percent, far inside the footprint's own estimation error);
they now return `success = FALSE` with no output file.

The warning text compounds it — it says *"the corner mapping would stretch it by
0.937x. Skipped rather than written squashed"*, which sends the reader to look for a
rotation fix that does not exist for a square footprint.

**Why the suite cannot see it:** every bundled film thumbnail is exactly 1250x1250
(verified by fetching six of them and reading `gdalinfo`), so the fixture set is
structurally incapable of reaching this — the "fixture that cannot reach the failure
mode" class in CLAUDE.md.

**Suggested shape of a fix** (the guard should measure *mispairing*, not *aspect
mismatch*): compare `aniso` against the best anisotropy achievable over the four
rotations, and refuse only when another pairing would be materially better. Equivalently,
apply the guard only where `non_square[j]` — a square footprint has no pairing to get
wrong. Either way, the guard then still catches the 2.42x UltraCam case and the
inferred-format mismatch it was written for, and stops refusing film it should accept.

---

### 2. **[fragile]** `R/fly_georef.R:232-236` — the `rotation` *column* is never validated, and this diff makes it load-bearing where it used to be inert

The `rotation` **argument** is validated at :133-138 to be one of 0/90/180/270. The
`rotation` **column** is not; it goes straight into `as.integer()` and then into
`fly_georef_gcps()`'s `n_shifts <- rotation %/% 90`. Measured:

```
rot -90  -> silently treated as rotation 0 (n_shifts <= 0, no shift applied)
rot  45  -> silently treated as rotation 0
rot 360  -> ERROR: subscript out of bounds   (c(5:4, 1:4) -> 6 ground rows vs 4 pixel rows)
rot 450  -> ERROR: subscript out of bounds
```

The error is swallowed by the `tryCatch` at :252-258, so a whole batch fails with
`Failed to georef <file>: subscript out of bounds` — a message that names neither the
column nor the offending value. A factor column is worse: `as.integer(factor("180"))` is
`1`, which is silently rotation 0.

This is pre-existing for film, but the diff changes its weight in two ways: (a) the new
`user_rotation_col` branch makes the column override the *measured* digital mapping,
and (b) the new docs actively instruct users to manage this column for digital batches
("drop the column, or set it to `NA` for those rows", :32-34). A column that was inert
for digital frames is now the highest-precedence input for them.

One line beside the existing argument check would close it — validate the non-`NA`
column values against `c(0, 90, 180, 270)` and stop naming the bad value.

---

### 3. **[fragile]** `R/fly_georef.R:218-220` — duplicate or absent `airp_id` resolves silently

`fp_idx <- which(photos_sf[["airp_id"]] == results$airp_id[i])`, then `j <- fp_idx[1]`.

- **Duplicate `airp_id`** (the same frame arriving twice from two overlapping catalogue
  queries `rbind`-ed together): every duplicate row is georeferenced onto the *first*
  row's footprint, rotation and squareness classification. The output path is
  `basename(src)`, so the second write also lands on the same file. No warning.
- **Absent `airp_id` column**: `photos_sf[["airp_id"]]` is `NULL`, `NULL == x` is
  `logical(0)`, `which()` is `integer(0)`, so *every* row `next`s and the function
  reports `Georeferenced 0 of N images` as though the images were simply unfetchable.
- In both skip paths `results$dest[i]` has already been assigned at :210, so the returned
  tibble names an output file that was never written (`success = FALSE` alongside it, so
  a caller reading `success` is fine; one reading `dest` is not).

All pre-existing, but the diff adds two more per-row lookups keyed on `j`
(`empty_fp[j]`, `non_square[j]`) that inherit it, and the brief asked. A
`if (length(fp_idx) > 1) warning(...)` and an explicit `airp_id` presence check would
make both states visible.

---

### 4. **[fragile]** `tests/testthat/test-fly_georef_digital.R:104-114` — test asserts less than its name claims

```r
test_that("frames with no footprint are still skipped, and warned about once", {
  ...
  seen <- capture_rotations(
    suppressWarnings(fly_georef(fake_fetch(photos), photos, dest_dir = tempfile()))
  )
  expect_length(seen, sum(!unsized))
})
```

The body checks only the *count* of frames reaching `georef_one()`. The
"warned about once" half is inside `suppressWarnings()` and is never asserted — an
implementation that warned zero times, or once per frame, passes this test unchanged.
The premise line (`expect_true(any(unsized))`) is good and does its job; the missing
piece is an `expect_warning(..., "no footprint")` around the call, or a
`withCallingHandlers` count.

---

### 5. **[fragile]** `tests/testthat/test-fly_georef_digital.R:159-162` — comment contradicts the assertion directly beneath it

```r
# And the guard is about the pairing, not about rotation 0 as such: a square footprint
# takes rotation 0 happily, because there is nothing to mispair.
sq <- ring(hc = 1000, ha = 1000)
out3 <- tempfile(fileext = ".tif")
expect_warning(georef_one(src, sq, out3, rotation = 0), "Skipped rather than")
```

The comment says the square footprint is accepted; the assertion asserts it is
**refused**. The *next* comment (:164-165) explains why the refusal is correct, but a
reader or a future editor hitting the first comment reads the assertion as the bug.
CLAUDE.md's own rule applies here — "read the guard, not the comment above it" — and this
is the shape that produces a wrong "fix".

Minor companion: `out3` is never checked for non-existence the way `out2` is at :157, and
the return value of that call is discarded (`expect_false(res)` is only done for `out2`).

---

### 6. **[fragile]** `R/fly_georef.R:158-169` — the no-bearing warning is a string match on another function's output, and every failure direction is silence

`grepl("axis_aligned_no_bearing", footprints$width_source)` is a stringly-typed contract
with `fly_footprint()`, which builds that marker by `paste0()`-appending to
`width_source` (`R/fly_footprint.R:543-545`). Three ways it goes quiet without an error:
the marker text changing on the producing side; `width_source` being absent (the
`%in% names()` guard at :158 skips the whole block); `width_source` being `NA` for the
row (`grepl` returns `FALSE`). All three fail toward "no warning", the direction that
reads as success.

It is currently correct and the new end-to-end test at :117-130 does couple the two
sides, which is what keeps this at *fragile* rather than *bug*. Worth noting because the
value being matched is produced two modules away and nothing pins its text.

---

## Checked and found sound

- **`user_rotation_col` / `has_rotation_col` split** — correct. `user_rotation_col` is
  captured before the auto path can set `photos_sf$rotation`, so a bearing-derived
  rotation can never masquerade as a user override. Every combination traced:
  | rotation arg | column | column value | result | vs. pre-diff |
  |---|---|---|---|---|
  | `"auto"` | absent, roll+frame present | — | bearing-derived per row | unchanged |
  | `"auto"` | absent, no roll/frame | — | message + 180 | unchanged |
  | `"auto"` | present | value | value | unchanged |
  | `"auto"` | present | `NA` | 180 (film) / 270 (digital) | film unchanged |
  | fixed `r` | absent | — | `r` (film) / 270 (digital) | film unchanged |
  | fixed `r` | present | `NA` | `r` (film) / 270 (digital) | film unchanged |
- **`fly_gcp_anisotropy()` degenerate inputs** — no `log()` of a negative is reachable
  (both terms are `sqrt()`); `w == 0` gives `aniso == 0`, `log(0)` is `-Inf`, `abs(-Inf)`
  exceeds the threshold, so it refuses rather than errors; `NA` short-circuits on
  `!is.finite(aniso)` before `log()` is evaluated, so no `NA` reaches `if`.
  `ncol_px = 0` returns `NA_real_` as documented. `warning()` inside the loop is not
  caught by the `tryCatch` (which handles `error` only), so it reaches the caller.
- **Guard headroom** — real digital thumbnails land at anisotropy 0.99974 (0.03% off)
  against a 5% tolerance and a 21% minimum for the least-eccentric wrong pairing.
  DEM-sized digital frames preserve the sensor aspect exactly (`resize()` scales both
  half-dimensions by the same `k`), so the DEM route cannot drift into the guard.
- **Input class shapes** — ran `fly_georef()` end to end over plain / tibble / grouped /
  `bcdc_sf` digital centroids (the `centroid_shapes()` sweep): all four give rotation
  270 for all 6 frames and `success` 6/6. The `width_source` `$` access and
  `photos_sf[["rotation"]][j]` indexing are safe on every shape.
- **Discriminating power of the new tests** — checked each is capable of failing:
  digital bearings are ~343 deg, which `bearing_to_rotation()` maps to **0**, not 270, so
  the digital assertions discriminate. In the mixed-batch test the four film frames map
  to **90, 270, 270, 90** — two coincide with the digital constant, but the two 90s make
  the assertion fail against an implementation that applied 270 everywhere, so the test
  is not vacuous. The `wrong <- 2.4217` pin and the reversed-ring handedness check both
  fail on a broken implementation.
- **`local_mocked_bindings()` scoping** — `.env = parent.frame()` unwinds with the
  calling test rather than the helper, and mocks `fly`'s namespace (the correct target
  for an internal `fly_georef()` -> `georef_one()` call path). No leak: the last test in
  the same file calls the **real** `georef_one()` and writes actual GeoTIFFs, and it
  passes. The `test-fly_georef*.R` files that run after it are unaffected.
- **`fly_is_square()` TRUE-on-EMPTY** — neutralised, see the classification note above.
  `fly_is_square()` also returns early on empty before `st_coordinates()`, so it cannot
  error on an unsized frame.
- No shipped camera in `inst/extdata/camera_formats.csv` has a square sensor (minimum
  aspect 1.0995, DMC II), so the "square digital sensor falls through to the film rule"
  path is not currently reachable.

## Not raised (deliberately)

- The orphaned `# unname() matters` comment at `R/fly_georef.R:288-291` now sits above
  the anisotropy block rather than above the `gcp_args` loop it describes — readability
  only.
- `DESCRIPTION` `Date: 2026-08-29` while `NEWS.md` dates 0.7.0 as 2026-08-30.
- The warning and `.Rd` say `inst/notes/georeferencing.md`; installed, the path is
  `notes/georeferencing.md`. Consistent with existing house style elsewhere in the
  package.
