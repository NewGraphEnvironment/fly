# Code check — round 2 — fly#38 staged diff

Scope: `git diff --cached`. Round 2's brief was to treat round 1's **fixes** as the prime
suspects. Two of the three fixes carry a defect, and one of them is the same class round 1
named by name.

Verified empirically, not by reading:

- full suite under `pkgload::load_all()` + `test_dir()`: **green — `FAIL 0 | WARN 0 |
  SKIP 0 | PASS 1244`**, 0 `Error` / `Execution halted` markers. Every finding below is
  invisible to it.
- `/tmp/cc_checklist.md` **is zero bytes** — the checklist named in the brief was empty,
  so this review worked from `CLAUDE.md`'s code-check conventions instead. Flagging it so
  nobody records "the checklist was worked through".
- Finding 2 was established by the restore-the-bug procedure: the gate was stripped from a
  copy of `georef_one()`, the patch was proven to have taken (`fly_is_square` absent from
  the deparsed body), and the test re-run.

---

## Findings

### 1. **[bug]** `R/fly_georef.R:258` — the factor defect round 1 fixed is still live in the third branch

Round 2 normalised the `rotation` column read into `user_rot` "once, here, and read from
this vector everywhere below" (`:188-191`). It is **not** read from that vector everywhere
below. There are three read sites and only two were converted:

| line | site | conversion |
|---|---|---|
| `:194` | validation | `as.integer(as.character(x))` ✅ |
| `:252` | user-override branch | `user_rot[j]` ✅ |
| **`:258`** | **`has_rotation_col` fallback branch** | **`as.integer(photos_sf[["rotation"]][j])`** ❌ raw |

The escape route is precise: a factor level that does **not** parse makes `user_rot[j]`
`NA`, which (a) passes validation, because `bad <- !is.na(user_rot) & …` excludes `NA`, and
(b) skips the `:252` user branch, because `is.na(user_val)`. Control then reaches `:258`,
which reads the raw factor and gets the **level code**.

Measured on four bundled film frames:

```
column          factor(c("180","north","180","north"))   levels: 180, north
validation      as.integer(as.character(x)) -> 180, NA, 180, NA     (passes)
per-row :258    as.integer(x)               ->   1,  2,   1,  2     (LEVEL CODES)
rotation applied                            -> 180,  2, 180,  2
n_shifts = rot %/% 90                       ->   2,  0,   2,  0
bearing/auto would have given               ->  90, 270, 270, 90
```

```
column   factor("north")   ->  rotation applied: 1, 1, 1, 1   (0 shifts -> rotation 0)
```

Consequences, all silent, all with `success = TRUE` and a GeoTIFF on disk:

- Rotations `1` and `2` **bypass the new validation entirely** — they are synthesised
  inside the loop, so "must be NA or one of 0, 90, 180, 270" never sees them.
- `1 %/% 90` and `2 %/% 90` are both `0`, so the frame is georeferenced at **rotation 0**.
  The docs at `:51` state 180 is "correct for most BC film", so the image lands 180° out.
- A factor with ≥ 361 levels would give `n_shifts >= 4` and the `subscript out of bounds`
  the round-2 fix was written to prevent — swallowed by the `tryCatch` at `:270`, naming
  neither the column nor the value. Exotic, but it is the same door.

**Why the new test misses it:** `test-fly_georef_digital.R:229` uses `factor("180")`, whose
level *parses*, so `user_rot` is non-`NA` and the `:252` branch handles it — `:258` is never
reached. The test's own comment says *"Converting in two places is how those come apart"*;
they are still converted in two places.

**Fix:** `:258` should read `user_rot[j]` too, or the branch should be restructured so the
raw column is read exactly once. Note the branch is *also* the auto/bearing path (where
`photos_sf$rotation` was written by `bearing_to_rotation()` and is a clean integer), so the
two cases need separating rather than the read merely being swapped.

---

### 2. **[bug]** `tests/testthat/test-fly_georef_digital.R:185-209` — the regression test for the round-1 fix does not exercise the gate, and its comment states a false number

The test is named "a film scan that is not exactly square still georeferences" and exists to
pin the `!fly_is_square(fp)` exemption. It uses a **1250 x 1200** image on a 4000 x 4000 m
square ring. That anisotropy is **inside** the guard's tolerance:

```
aniso                 = (4000/1250) / (4000/1200) = 0.96
abs(log(0.96))        = 0.040822
log(1.05)             = 0.048790          <- threshold
0.040822 > 0.048790   = FALSE             -> the guard would NOT have refused it
```

So the guard never fires on this fixture, gate or no gate. Confirmed by restoring the bug —
`georef_one()` re-derived with the `if (!fly_is_square(fp))` gate stripped, patch proven to
have taken:

```
WITH gate (as staged)    -> test would PASS
patch took? body has no fly_is_square: TRUE
WITHOUT gate (bug back)  -> test would PASS
```

The comment at `:200` asserts the opposite as its premise:

```r
# 0.96 — outside the guard's 5% tolerance, and identical at every rotation.
```

`0.96` is **inside** the tolerance. The assertion two lines down
(`expect_equal(fly_gcp_anisotropy(...), 0.96)`) is correct and passes; it is the
interpretation that is wrong, and it is the interpretation a future editor will trust when
deciding whether the exemption is still needed.

This is `CLAUDE.md`'s "a fixture that cannot reach the failure mode is not validation",
with the aggravating factor that a stated measurement licenses the claim.

Dimensions that would actually exercise it (same 4000 m square ring):

```
 1250x1250  aniso=1.0000  refuses=FALSE   <- cannot exercise
 1250x1200  aniso=0.9600  refuses=FALSE   <- cannot exercise  (what the test uses)
 1250x1180  aniso=0.9440  refuses=TRUE    <- exercises the gate
 9600x9000  aniso=0.9375  refuses=TRUE    <- exercises the gate; round 1's own example
```

Round 1's finding was motivated by the 9600x9000 full-resolution scan. Using that, or
1250x1180, makes the test discriminating and costs nothing.

*(The gate is genuinely exercised elsewhere — `:178-181`, the 2000 x 2000 m square ring at
anisotropy 2.0, does fail with the gate removed. So the fix is covered; it is this
specifically-named regression test that is decoration.)*

---

### 3. **[bug]** `R/fly_georef.R:317` — the gate switches the guard off for a digital frame sized through the documented `format_size` escape hatch

The gate reasons that a square footprint has "no pairing to get wrong". True of the *corner
mapping*. But `!fly_is_square(fp)` is a proxy, and it also stands for **"was sized as
film"** — which for a digital frame is precisely the mismatch the guard's own comment at
`:306-308` says it exists to catch ("a frame sized from an inferred format that does not
match the camera that actually took it").

`format_size` is the documented escape hatch "for a camera `fly` does not know"
(`R/fly_footprint.R` roxygen), it takes a single width, and a single width produces a
**square** footprint. So every unknown digital camera routed through the documented escape
hatch now bypasses the guard. Measured on bundled digital frame 19 with a portrait
1063 x 1654 image:

```
media:                              Digital - Colour
fly_footprint(dig, format_size = c("Digital - Colour" = 9))
footprint square?                   TRUE
guard runs?                         NO   (gated off)
written?                            TRUE, 0 warnings
anisotropy the mapping applies:     1.556      (guard refuses at >1.05 or <0.952)
```

A 1.556x stretch, written silently, with `success = TRUE` — the exact failure the code
comment describes as "a valid GeoTIFF, in the right CRS, over the right ground — just
squashed … which nothing downstream would report". Before the gate this frame was refused.

Related documentation gap: the roxygen at `:81-84` still promises, without qualification,
that "A frame whose delivered image aspect does not pair with its footprint edges is
**skipped with a warning**". After the gate that holds only for non-square footprints. The
`@param rotation` text was updated for the square/non-square split; this paragraph was not.

**Shape of a fix** (round 1 suggested it and it survives this finding): keep the guard
running on every frame, but compare `aniso` against the **best** anisotropy achievable over
the four rotations, refusing only when another pairing would be materially better. That
measures mispairing directly instead of using shape as a stand-in, so it accepts the
off-square film scan *and* still refuses the square-footprint digital frame above.

---

### 4. **[fragile]** `R/fly_georef.R:194-200` — the new validation cannot refuse a value that does not parse

`bad <- !is.na(user_rot) & !user_rot %in% c(0L, 90L, 180L, 270L)` excludes `NA`, and
`as.integer(as.character(x))` produces `NA` for anything unparseable. So a typo is
indistinguishable from a deliberate `NA` and is silently downgraded to the fallback:

```
rotation = c("ninety", NA, "180", NA)     -> ACCEPTED, no error
rotations applied:  180, 180, 180, 180
bearing/auto would have given:  90, 270, 270, 90
```

Row 3's `"180"` was honoured; row 1's `"ninety"` was discarded without a word. The batch
mixes honoured and ignored values with nothing reporting which. The block is titled
"refused by name, not by GDAL" — an unparseable value is exactly the case that most needs
naming, and it is the one case that gets through.

Cheap close: compute `parsed_na <- is.na(user_rot) & !is.na(photos_sf[["rotation"]])` and
fold it into `bad`.

Note this also feeds finding 1: it is `user_rot[j]` being `NA` here that routes a factor to
the raw read at `:258`.

---

### 5. **[fragile]** `R/fly_georef.R:66-71` — the documented `case_when` escape hatch does not do what its comment says, and this diff promotes it

The roxygen example says:

```r
photos$rotation <- dplyr::case_when(
  photos$film_roll == "bc5282" ~ 270,
  .default = NA  # fall through to auto
)
```

`NA` does **not** fall through to auto for a film frame. Presence of the column sets
`has_rotation_col` at `:181`, which suppresses the whole auto/bearing block at `:204`, and
an `NA` row then lands on `if (auto_rotation) 180L`. Measured on the same four film frames:

```
rotation column all NA :  180, 180, 180, 180
no rotation column     :   90, 270, 270,  90   <- what "fall through to auto" promises
```

So a user who overrides one roll and leaves the rest `NA` silently loses bearing-derived
rotation on **every other roll in the batch** — 180° wrong on two of these four frames.

The behaviour is pre-existing, but the diff makes it load-bearing and more prominent: the
new `@param rotation` text at `:31-34` instructs users to "set it to `NA` for those rows",
and the new digital test at `:79-84` pins `NA` → fall-through as correct **for digital**
(where it genuinely is, because `non_square[j]` catches it before the film branch). The doc
now describes one behaviour that is true for digital and false for film, in a paragraph that
says "for both".

Either fix the fall-through (test `all(is.na(user_rot))` rather than column presence when
deciding whether to run the auto block) or correct the comment to say `NA` means 180 for
film. Whichever, the two halves should stop contradicting.

---

## Checked and found sound

- **Index alignment** — re-derived independently rather than trusting round 1.
  `fly_footprint()` preserves row count and order (`nrow` 4 → 4, `airp_id` identical), so
  `footprints`, `empty_fp` and `non_square` are all in `photos_sf` row order.
  `j <- which(photos_sf[["airp_id"]] == …)[1]` indexes `photos_sf`, and `user_rot` is
  built from `photos_sf[["rotation"]]` before any reassignment, so `user_rot[j]`,
  `empty_fp[j]` and `non_square[j]` are all keyed on the same thing. The one reassignment
  of `photos_sf` (`fly_bearing()` at `:206`) is unreachable when a user column exists, so
  it cannot desynchronise `user_rot`.
- **Film behaviour bit-for-bit unchanged when no digital frame is present** — the
  anisotropy guard is new in this diff, so a square footprint skipping it is exactly the
  pre-diff path. Rotation selection for film re-traced and unchanged. The one behaviour
  change is the new `stop()`, below.
- **`fly_is_square()` called per frame inside `georef_one()`** — correct and consistent
  with `non_square[j]`: it is per-feature (`vapply` over `seq_along(g)`), uses
  `all.equal(max(d), min(d))` with the default relative tolerance, and has no batch-shared
  state, so `fly_is_square(footprints)[j]` and `fly_is_square(footprints[j, ])` cannot
  disagree. No batch dependence. Cost is one `st_transform()` of a single already-3005
  feature per frame — negligible beside the two GDAL calls that follow.
  `st_transform()` would error on a missing CRS, but `footprints` is transformed to 3005 at
  `:143` before the loop, so that is unreachable from `fly_georef()`.
- **`fly_is_square()` TRUE-on-EMPTY inside `georef_one()`** — harmless. An empty ring would
  die earlier at `sf::st_coordinates(fp)[1:4, ]`, and `fly_georef()` returns at
  `if (empty_fp[j]) next` before `fp` is ever subset.
- **Fix 3, the `withCallingHandlers` warning counts** — these can fail, in both directions.
  `test-fly_georef_digital.R:114-122` counts warnings matching `"have no footprint"` and
  asserts `expect_identical(n, 1L)`; an implementation warning zero times fails, and one
  warning per frame fails. The text matches `fly_warn_unsized()`'s
  `" frames have no footprint and are excluded from "`. Muffling every warning is correct
  here — the fixture also raises `fly_footprint()`'s unknown-format warning, which
  `expect_warning()` would re-raise as a test WARNING.
  `:131-139` (`expect_warning` "no flight bearing" on one frame, `expect_no_warning` on six)
  discriminates a guard that never fires and one that always does. Suite runs `WARN 0`.
- **New `test-fly_georef_gcps.R` tests** — the handedness test is real (reversing the ring
  flips the sign, asserted). The anisotropy test is not vacuous despite `wrong` being
  hand-computed from the same 3175/2040/1063/1654 numbers `ultracam_ring()` encodes,
  because `expect_equal(wrong, 2.4217, tolerance = 1e-4)` pins the value independently.
  `aniso(90)` and `aniso(270)` both being 1 is acknowledged in the file header as
  geometrically unavoidable.
- **`stop()` reachability** — the new validation is before the loop and before
  `dir.create()`'s side effects matter, so it cannot leave a half-written batch. It *is* a
  behaviour change: a film batch carrying `-90` or `45` in a `rotation` column previously
  ran (silently at rotation 0) and now aborts the entire call rather than skipping the bad
  rows. That is the right direction — fail loud — and is worth a NEWS line if there is not
  one, but it is not a defect.
- No new hardcoded absolute paths, no secrets, no shell quoting, no file-writing side
  effects outside `dest_dir` / `tempfile()`.

## Not raised

- The `# unname() matters` comment at `:329-332` still describes the `gcp_args` loop it now
  sits two blocks above — readability only, carried over from round 1.
- `DESCRIPTION` `Date:` vs `NEWS.md` 0.7.0 date, carried over from round 1.
