# Code check — round 3 — fly#38 staged diff

Scope: `git diff --cached`. Brief: treat **round 2's fixes** as the prime suspects, verify
they are complete and introduced nothing.

**Verdict: round 2's fixes 1, 3 and 4 (the `user_rot` write-back, the discriminating film
fixture, the tolerance-pin test) are sound and verified. Fix 2 — replacing the shape gate
with a single tolerance of 1.10 — is off by 0.4% and leaves one of the two bundled cameras
outside the guard, in exactly the case the tolerance was chosen to cover.**

Verified empirically, not by reading:

- full suite under `pkgload::load_all()` + `test_dir()`: **FAIL 0 | WARN 0 | SKIP 0 |
  PASS 1251**. Every finding below is invisible to it.
- `devtools::document()` re-run: **no drift** — `git status` unchanged afterwards.
- `lintr::lint("R/fly_georef.R")`: **1** lint against **5** at `HEAD`. The one remaining
  (`no visible global function definition for 'fly_is_square'`) is the installed-namespace
  artifact CLAUDE.md documents — confirmed:
  `exists("fly_is_square", asNamespace("fly"))` is `FALSE` on the installed copy.
- Restore-the-bug run on a **new** assertion, both bindings patched, patch proven to have
  taken. Result below.
- `data-raw/georef_calibrate-corner_mapping.R` exists; `^planning$` is in `.Rbuildignore`,
  so `review-round*.md` do not ship. New test filename is portable. No new examples.

---

## Findings

### 1. **[bug]** `R/fly_georef.R:483` (`fly_gcp_stretch_max() = 1.10`) — the tolerance is 0.4% too loose, and a Leica DMC II frame on a `format_size` square footprint slips through the guard silently

This is round 2's fix 2 and the case round 2's finding 3 was written about. The shape gate
was removed in favour of a tolerance specifically so that a digital frame sized through
`format_size` — which takes a single width and therefore produces a **square** footprint —
would still be checked. The new note says so in as many words
(`inst/notes/georeferencing.md`, "The stretch tolerance, and why it is not a shape gate"):

> `format_size` sizes a frame from a single width, so a digital frame from a camera `fly`
> does not know lands on a **square** footprint — and that is precisely the case the guard
> exists for. A shape gate switches it off there. A tolerance wide enough for the rebate
> does not.

For the **UltraCam** it does. For the **DMC II** it does not, by 0.4%:

```
threshold  |log(1.10)|          = 0.0953102
DMC II     |log(15552/14144)|   = 0.0948987      <- shipped px counts
DMC II     |log(972/884)|       = 0.0948987      <- delivered thumbnail, aspect test :58
                                  0.0948987 > 0.0953102  ->  FALSE   (NOT refused)
```

Confirmed end to end on a bundled DMC II frame, real `fly_footprint()` + real
`georef_one()` + real GDAL:

```
media:                            Digital - Colour
fly_footprint(one, format_size = c("Digital - Colour" = 87))
footprint square?                 TRUE
image 1414 x 1555 px (DMC II aspect)
  rot   0  aniso 1.099717  |log| 0.095053  refused=FALSE
  rot  90  aniso 1.099717  |log| 0.095053  refused=FALSE
  rot 180  aniso 1.099717  |log| 0.095053  refused=FALSE
  rot 270  aniso 1.099717  |log| 0.095053  refused=FALSE

georef_one returned: TRUE   file written: TRUE   warnings: 0
```

A ~10% stretch, written silently, `success = TRUE` — the exact failure the code comment at
`:323-327` describes as "a valid GeoTIFF, in the right CRS, over the right ground — just
squashed … which nothing downstream would report".

**Every row of `inst/extdata/camera_formats.csv` was checked**, `calib_file` and
`focal_length` alike (19 rows). Two columns matter and only one of them is in the shipped
table/comment:

| case | quantity | tightest row | refused? |
|---|---|---|---|
| non-square footprint, 90-off pairing | `\|log(r²)\|` | DMC II, 0.18980 | **yes**, all 19 |
| **square footprint (`format_size`)** | `\|log(r)\|` | **DMC II, 0.09490** | **no** — the only row that slips |

Every other row is refused in both columns (next-tightest square case is the UltraCam Eagle
at 0.42515). So the answer to the brief's question is: **yes, one shipped camera produces a
mispairing inside the tolerance, and it is the square-footprint case the tolerance replaced
the shape gate to cover.**

**The two tables that argue for 1.10 both omit this row.** `georef_one():335-344` and the
note both list the square-footprint case as `0.442 — a portrait digital frame on a square
footprint`, which is the UltraCam. The DMC II's square case at 0.0949 sits *below* the
`0.095 the tolerance` line and appears in neither.

**There is an admissible value; 1.10 is just outside it.** The two constraints are
`> 0.06454` (the 9600x9000 film rebate) and `< 0.09490` (DMC II square):

```
admissible fly_gcp_stretch_max()  in  (1.0667, 1.0995)
shipped                                1.10          <- outside, by 0.4%
e.g. 1.08  ->  |log| 0.07696          1.19x headroom below, 1.23x above
```

The band is narrow, and that narrowness is itself worth recording beside the constant —
the current comment claims "roughly 1.5x of headroom below and 2x above", which is true of
the `r²` column only.

Note also the margin is 0.00026 in log space. A DMC II thumbnail delivered at a slightly
different rounding, or a full-res frame vs a thumbnail, flips this either way — so the
behaviour is not merely wrong, it is unstable at the boundary.

---

### 2. **[fragile]** `tests/testthat/test-fly_georef_digital.R:235` — the tolerance test's third number picks the lenient bundled camera; written for the other one the same assertion fails

Answering the brief's item 3 directly: the test **can** fail (proven below), and none of its
three numbers is arithmetically wrong. But the third assertion is named for a property that
does not hold:

```r
expect_gt(abs(log(1654 / 1063)), tol)        # portrait frame on a square footprint
```

`1654/1063` is the **UltraCam Eagle M3**. Substituting the other bundled camera — the same
claim, the same fixture set, one line — fails:

```
UltraCam Eagle M3 portrait frame on a square footprint: 0.4421015 > 0.09531 ?  TRUE
Leica DMC II      portrait frame on a square footprint: 0.0948987 > 0.09531 ?  FALSE

── Failure: a DMC II frame on a square footprint is also refused ──
Expected `abs(log(972/884))` > `log(fly:::fly_gcp_stretch_max())`.
Actual comparison: 0.09490 <= 0.09531
```

So the test asserting "the tolerance sits between the film rebate and the tightest
mispairing" is asserting it against the second-tightest case. This is the `CLAUDE.md`
"fixture that cannot reach the failure mode" shape, at one remove: the fixture *set* has
both cameras and the assertion reaches only one of them.

The same omission is in `georef_one()`'s comment table, the `@details` roxygen at
`R/fly_georef.R:90-95`, and the note's table — all four say the square-footprint case is
0.442 without saying it is camera-specific.

**The test is otherwise real.** Restore-the-bug, tolerance reverted to round 2's 1.05, both
bindings patched:

```
proof patch took: namespace value = 1.05  / search-path value = 1.05
proof it is REACHED: georef_one deparse mentions fly_gcp_stretch_max: TRUE

unpatched                    FAIL=0   PASS=45
patched 1.05                 FAIL=10  PASS=35
failing tests:
  - a film scan carrying the negative's rebate still georeferences
  - the stretch tolerance sits between the film rebate and the tightest mispairing
```

Both go red, so round 2's fix 3 (the 1250x1172 fixture replacing the non-discriminating
1250x1200) genuinely closed the hole round 2 named. That half is verified.

---

### 3. **[fragile]** `R/fly_georef.R:69-70` and `man/fly_georef.Rd:93` — the new `case_when` comment is true only for `rotation = "auto"`

Answering the brief's item 4. The claim:

```r
.default = NA  # square footprints fall through to 180, non-square to the
               # digital mapping — NOT back to the per-photo bearing
```

Traced over the whole product of (footprint shape) x (`rotation` argument), with an all-`NA`
column present, `georef_one()` mocked at the boundary:

```
  film    NA column, rotation=auto   -> 180, 180, 180, 180     <- claim holds
  film    NA column, rotation=0      ->   0,   0,   0,   0     <- claim FALSE
  film    NA column, rotation=90     ->  90,  90,  90,  90     <- claim FALSE
  film    NA column, rotation=270    -> 270, 270, 270, 270     <- claim FALSE

  digital NA column, rotation=auto   -> 270, 270, 270, 270     <- claim holds
  digital NA column, rotation=0      -> 270, 270, 270, 270     <- claim holds
  digital NA column, rotation=90     -> 270, 270, 270, 270     <- claim holds
  digital NA column, rotation=270    -> 270, 270, 270, 270     <- claim holds
```

The non-square half is correct in all four. The square half is correct in one of four —
`R/fly_georef.R:279` is `if (auto_rotation) 180L else rotation`, so an explicit `rotation`
argument is what an `NA` row falls through to, not 180.

The behaviour is defensible (the caller gets what they asked for) and the fix is one
clause: "…fall through to the `rotation` argument, 180 by default". Raised because round 2's
finding 5 was about this exact comment being wrong, and the replacement is wrong in a
narrower way. Note also that `test-fly_georef_digital.R:88-97` pins the *digital* half of
this and nothing pins the square half.

---

## Round 2's fixes — verified complete

### Fix 1 — one parse into `user_rot`, unparseable refused, written back

**Sound on every count the brief asked about.**

- **Write-back safety across sf shapes.** `photos_sf[["rotation"]] <- user_rot` run over
  `centroid_shapes()` (plain / tibble / grouped / `bcdc_sf`): value correct, `nrow`
  preserved, `sf_column` attribute intact, class **set** preserved in all four. Only the
  class *order* moves on `bcdc_sf` (`bcdc_sf, sf, …` → `sf, bcdc_sf, …`), which CLAUDE.md
  already records as expected and which cannot matter here because `photos_sf` is a local
  copy that is never returned. End to end with a factor column, all four shapes give
  identical rotations (`180, 270, 180, 270`).
- **Nothing downstream is disturbed.** `fly_footprint()` runs at `:154`, *before* the
  write-back at `:219`, so footprints are built from the caller's original column.
  `fly_bearing()` at `:225` is inside `if (auto_rotation && !has_rotation_col)` and
  `has_rotation_col` is `TRUE` whenever a user column exists, so it is unreachable on the
  write-back path and cannot desynchronise anything. The only later reads are
  `names()`, `[["airp_id"]]` and `[["rotation"]][j]`.
- **No remaining raw reads.** `:277` (`as.integer(photos_sf[["rotation"]][j])`) is the site
  round 2's finding 1 named; it now reads the written-back integer vector, so `as.integer()`
  is the identity there. Round 2's escape route — an unparseable factor level reaching `:277`
  and yielding a level code — is closed twice over: the value is refused at `:212` before the
  loop, *and* the write-back would have made `:277` correct anyway. Measured:

  ```
  factor c(180, north)     STOP: `photos_sf$rotation` must be NA or one of 0, 90, 180, 270. Got: north.
  factor('north')          STOP: ... Got: north.
  chr c(ninety,NA,180,NA)  STOP: ... Got: ninety.          <- round 2 finding 4, closed
  int 360                  STOP: ... Got: 360.
  int -90                  STOP: ... Got: -90.
  all NA logical           applied: 180, 180, 180, 180
  numeric 180.0 / chr '180' / list col   applied: 180, ...
  ```

  The residual fragility is structural rather than live: the conversion still happens in two
  places (`:206` and `:277`) and the second is correct only because of the write-back, which
  is the hazard `:216-218`'s own comment warns about. Moving `:277` to `user_rot[j]` would
  remove the dependence; today nothing is wrong.

### Fix 3 — the discriminating film fixture

Verified by restore-the-bug above (goes red at 1.05, green at 1.10). The premise assertions
at `:218-219` are correct: `|log(aniso)|` for 1250x1172 on a 4000 m square ring is
0.064412, matching the pinned `0.0644` and the 9600x9000 scan it stands in for
(`|log(9000/9600)| = 0.064539`).

### Fix 4 — the `case_when` roxygen

See finding 3 — the non-square half is right, the square half is right in one of four
combinations.

---

## Checked independently and found sound

- **Film is bit-for-bit unchanged for a square footprint and a square scan.** The GCP
  construction was pulled from `HEAD`'s bytes (`git show HEAD:R/fly_georef.R`, sourced into
  its own environment — not rewritten from memory) and compared against the staged one over
  all 20 bundled film footprints x 4 rotations x 2 square scan sizes: **160 cases, 0
  differences**. Rotation *selection* re-traced over every combination of (`rotation` arg,
  column present, column `NA`, `film_roll`/`frame_number` present) and is unchanged, except
  where a previously-silent invalid column value now `stop()`s — a deliberate, NEWS-worthy
  behaviour change, and the safe direction. The new anisotropy guard is vacuous at
  `aniso = 1`, which `test-fly_georef_aspect.R:110` asserts.
- **The guard cannot be reached with a non-finite value.** `!is.finite(aniso)`
  short-circuits before `log()`; `w == 0` gives `log(0) = -Inf`, which exceeds the threshold
  and refuses rather than errors; degenerate dimensions return `NA_real_`
  (`test-fly_georef_gcps.R:162`).
- **No fixture makes both sides of a comparison identical.** `test-fly_georef_aspect.R:50`
  compares the shipped CSV against hand-measured thumbnail dimensions — genuinely
  independent numbers. `test-fly_georef_digital.R:67` computes the film expectation from
  `bearing_to_rotation(fly_bearing(...))`, the same functions the code calls, but the
  bundled bearings give `90, 270, 270, 90` and the two `90`s discriminate against a
  "270 everywhere" implementation; the test's comment states the limitation. The digital
  premise at `:40-41` is the load-bearing one and it is asserted (bearings ~343° map to 0,
  not 270).
- **The `stop()` cannot leave a half-written batch** — it fires before the loop. It does run
  after `dir.create()` and after `fly_footprint()`, so an invalid column costs a footprint
  computation before aborting; no correctness consequence.
- **`R CMD check` surface.** New file `tests/testthat/test-fly_georef_digital.R` — portable
  name, no spaces. `planning/` (both new review files) is excluded by `^planning$` in
  `.Rbuildignore`. `data-raw/` likewise, so the `data-raw/georef_calibrate-corner_mapping.R`
  pointer in NEWS/roxygen names a file that is not installed — consistent with existing house
  style, not raised. No new `@examples`; the existing block is unchanged and its
  network dependence is pre-existing. `devtools::document()` produces no drift.
  `testthat (>= 3.2.0)` bump is required by `local_mocked_bindings(.package =)` and is
  present.
- **`empty_fp` / `non_square` three-way classification** — unchanged from round 1's
  verification; `if (empty_fp[j]) next` precedes the only `footprints[j, ]` subset.
- No hardcoded absolute paths, no secrets, no shell quoting, no writes outside `dest_dir` /
  `tempfile()`.

## Not raised

- `# unname() matters` at `R/fly_georef.R:355-358` still describes the `gcp_args` loop it now
  sits above rather than beside — carried from rounds 1 and 2, readability only.
- `DESCRIPTION` `Date: 2026-08-30` now agrees with NEWS — the round-1/2 note is stale.
- `as.integer("180.5")` truncates to `180` and is accepted. Consistent with `as.integer()`
  semantics, and 269.9 is refused by name, so no silent wrong rotation is reachable.
