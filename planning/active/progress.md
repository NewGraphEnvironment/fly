# Progress — Georeference digital frames (#38)

## Session 2026-08-30

- Plan-mode exploration: read `R/fly_georef.R`, `R/fly_footprint.R`,
  `tests/testthat/test-fly_georef.R`, `tests/testthat/test-fly_camera_format.R`,
  `data-raw/make_camera_formats.R`, `data-raw/test_georef_decades.R`
- Measured the ring-order contract, the rotation-to-edge mapping, and both bundled
  cameras' thumbnail dimensions — see `findings.md`. Narrowed the corner mapping from
  eight possibilities to one bit by geometry alone
- Two decisions taken with the user: the orthophoto QA runs in the private catalogue repo
  and only its constant comes back; a user `rotation` column keeps overriding for
  non-square frames
- Phases approved by user
- Created branch `38-georeference-digital-frames-the-corner-m` off main
- Scaffolded PWF baseline
- Next: Phase 1 — extract the GCP construction into a pure, testable function

### Phase 1 — GCP construction extracted

- `fly_georef_gcps(ncol_px, nrow_px, coords, rotation)` split out of `georef_one()`:
  pure, no GDAL, no file I/O
- Parity verified against the pre-change implementation lifted with
  `git show HEAD:R/fly_georef.R` (not reconstructed): 1024 cases — the 20 bundled film
  footprints, the 24 digital ones, and 20 random rings, at four image shapes and four
  rotations — **0 differences**
- One real difference found and fixed while doing it: the old loop produced a *named*
  character vector whenever the ring came from `sf::st_coordinates()`, because
  `coords[4, 1:2]` carries X/Y dimnames. GDAL ignores names; `identical()` does not
- Golden values written into `tests/testthat/test-fly_georef_gcps.R` so the pin survives
  that sha becoming history
- Full suite: 1181 passing, 0 failures

### Phase 2 — aspect invariant pinned

- `tests/testthat/test-fly_georef_aspect.R`: the GCP mapping must send the image's long
  pixel axis onto the footprint's long ground edge, expressed as an anisotropy ratio
  (m/px on the width axis over m/px on the height axis) that must be 1
- Premise asserted beside it: the shipped `camera_formats.csv` aspect matches the
  aspect of the thumbnails the catalogue actually serves, to 1e-3. A regenerated CSV
  that disagreed would fail there, naming the cause, rather than here
- Negative half pinned with numbers, not a threshold: rotations 0 and 180 squash by
  ratio^2 — **1.21x** on the DMC II, **2.42x** on the UltraCam. The DMC II alone would
  survive a loose tolerance; a fixture change dropping the UltraCam frames fails
- Stated explicitly that the invariant is vacuous on square film, which is why the film
  mapping needed imagery and why this cannot finish the digital job either
- **Restore-the-bug check**: patched `fly_georef_gcps()` to ignore its rotation argument
  (the pre-#38 behaviour — `bearing_to_rotation(271)` returns 0), in *both*
  `asNamespace("fly")` and `as.environment("package:fly")`, with a printed ground
  coordinate that can only come from the broken version. Result: **FAIL=2**, the two
  isotropy assertions. The guard fires

### Phase 3 — the constant is 270, and the plan's premise was wrong

A concurrent plan review found that `patb_georef_url` — a column `fly_fetch()` already
supports — carries **per-frame exterior orientation**, published and free. So the
licence-restricted orthophotos were never the only route, and are not the best one.
Verified before acting on it: the file downloads, parses, and covers all 24 bundled
frames.

Three measurements, all public, all in `data-raw/georef_calibrate-corner_mapping.R`:

1. **Exterior orientation.** The Eagle's image x-axis tracks the flight heading at
   0.18 deg (MAD 0.47) over 6839 frames spanning 32 compass bins, with the reflected
   reading excluded at 14.1% against 98.7%. Under the ordinary top-left raster
   convention that is rotation 270.
2. **Adjacent-frame overlap.** Needs no reference imagery — consecutive frames overlap,
   so at the right rotation their common ground agrees, and a 180-degree error reflects
   each frame about its own centre. 270 wins on both cameras: +0.616 and +0.659 against
   at most +0.43.
3. **FWA lake darkness.** 270 makes water darkest on both frames tested, with the water
   442 m and 1684 m off the footprint centre so the test could actually discriminate.

**The PATB reading disagreed for the DMC II and was wrong.** It said 90. It looked
strong — 97.6% agreement, four projects pooled — and could not have been right: that
camera's bundled project flies east and west only, so its own data separates the two
hypotheses at 97.6% against 98.4%, which is to say not at all. Recorded in
`inst/notes/georeferencing.md` as the cautionary half, because it is the measurement a
reader will find most convincing.

Both cameras give the same answer, so the constant is global rather than a per-camera
column.

### Phase 4 — exclusion removed, digital frames georeference

- Non-square footprints take `fly_digital_rotation()` (270) and never
  `bearing_to_rotation()`. Classification is three-way — empty / square / non-square —
  computed before the loop, because `fly_is_square()` reports an EMPTY geometry as
  square and squareness alone therefore cannot stand in for "has ground control"
- Isotropy guard in `georef_one()`: a mapping that would stretch the image by more than
  5% is refused with a warning rather than written. Real data lands at 0.03% off
  isotropic and the least eccentric wrong pairing is 21% off, so the tolerance has
  room in both directions
- `user_rotation_col` captured **before** the auto path overwrites `has_rotation_col`.
  Without it nothing downstream could tell a user column from a bearing-derived one, so
  the documented override would have silently stopped working for digital frames
- Warning added for a non-square footprint with no bearing — the ordinary result of
  georeferencing one frame on its own, since `fly_bearing()` needs a neighbour
- Live check: 6 Eagle frames georeference 6 of 6 in EPSG:3005; a mixed batch of 3 film
  and 3 digital gives film the bearing rule and digital the constant, 6 of 6, no warning
- New tests observe the rotation at the boundary rather than inferring it from output

**A leaking mock, found by the guard tests failing.** `local_mocked_bindings(.env = )`
is the environment the mock unwinds with, not the target — `.package` names the target.
Passing `asNamespace("fly")` installed the stub correctly and then never removed it,
because a namespace does not exit, so every later test in the run kept it. It leaked in
the direction that reads as success: a stub returning `TRUE` makes assertions pass. It
surfaced only because a later test asserted a file existed that the stub never wrote.
`testthat` pin bumped to >= 3.2.0 for `.package`. Recorded in CLAUDE.md.

### Phase 5 — notes, docs, release

- `inst/notes/georeferencing.md` written in Phase 3 (the measurement record)
- README, vignette georef section, `@details` **Rotation** and `@param rotation` all
  rewritten — the old text documented film-only behaviour as if it were general
- `devtools::document()`: `fly_georef.Rd` only, exports steady at 9, no rebind
- NEWS entry; version 0.6.0 -> 0.7.0

### Code-check round 1 — one real regression, four fragilities

Findings in `planning/active/review-round1.md`.

**Fixed — the regression I would have shipped.** The isotropy guard ran on film too, and
on a *square* footprint the anisotropy is the image's own inverse aspect and is identical
at all four rotations — so it stopped being a corner-mapping check and became "is this
scan square to within 5%", which no rotation can fix. Reproduced before fixing: a
1250x1250 thumbnail passes, a 9600x9000 full-resolution 9-inch scan is **refused**.
`fly_georef()` documents full-resolution scans as supported, and every bundled film
thumbnail is exactly 1250x1250, so the fixture set was structurally incapable of reaching
it. Guard now gated on `!fly_is_square(fp)`, with a regression test on a 1250x1200 scan
asserting no warning at any of the four rotations.

**Fixed — the `rotation` column was never validated**, and this branch made it the
highest-precedence input for digital frames while the docs tell users to manage it. 360
indexed past the ring and surfaced from inside `tryCatch` as "subscript out of bounds",
naming neither column nor value; 45 and -90 shifted by zero and georeferenced silently
wrong.

**And a second bug inside that fix.** Validating with `as.integer(as.character(x))` while
the per-row read still used `as.integer(x)` means a factor column validates as 180 and is
*applied* as its level code, 1. Converting in two places is exactly how those come apart
(CLAUDE.md, cross-function normalisation). Normalised once into `user_rot` and read from
that one place; the test asserts the factor is honoured as 180 and explicitly that it is
not 1.

**Fixed — two tests.** One named "warned about once" never asserted a warning, only a
frame count, so it passed for zero warnings. `expect_warning()` was the wrong instrument
because the fixture raises a second, unrelated warning that testthat then re-raises;
counting under `withCallingHandlers` makes the assertion exact. The other carried a
comment saying a square footprint is accepted directly above an assertion that it is
refused — the shape that produces a wrong "fix".

**Accepted.** Duplicate/absent `airp_id` resolving silently is pre-existing and unrelated
to digital frames; the no-bearing warning being a `grepl()` on a marker `fly_footprint()`
appends is stringly-typed but currently coupled by an end-to-end test.

### Code-check round 2 — three more, two of them inside round 1's fixes

Findings in `planning/active/review-round2.md`. The pattern held: the fixes were the
prime suspects, and that is where two of the three were.

**The factor defect round 1 named was still live.** The round-1 fix normalised the column
into `user_rot` and its own comment claimed it was "read from this vector everywhere
below" — there were three read sites and only two were converted. A factor level that
does *not* parse gives `NA`, which passes validation and skips the user branch, so control
reached the third site and got the **level code**. Measured:
`factor(c("180","north",...))` gave rotations `180, 2, 180, 2`, and `1 %/% 90` is 0, so
those frames georeferenced at rotation 0 with `success = TRUE`. The new test used
`factor("180")`, whose level parses, so it never reached that branch. Fixed by writing
the parsed vector back into `photos_sf` so there is exactly one parse, and by refusing a
value that was supplied but did not parse instead of downgrading it to NA.

**The shape gate was the wrong fix for round 1's regression.** Exempting square footprints
switches the guard off for a digital frame sized through `format_size`, which produces a
*square* footprint from a single width — the unknown-camera case the guard exists for.
Measured: a portrait 1063x1654 image on that square footprint wrote a **1.556x stretch
silently, 0 warnings**. Replaced with a single tolerance of 10%, set from measurements
rather than picked:

| \|log\| off isotropic | what |
|---|---|
| 0.065 | full-resolution 9-inch scan with rebate — the worst legitimate case |
| **0.095** | **the tolerance** |
| 0.190 | tightest mispairing the shipped table can produce (DMC II) |
| 0.442 | portrait digital frame on a square footprint |

Roughly 1.5x headroom below and 2x above. Pinned as its own test so moving it has to
disagree with numbers rather than with a comment.

**And my regression test for round 1 could not fail.** Its 1250x1200 fixture is 0.041 off
isotropic, inside even the old 5% tolerance, so it passed with the gate stripped —
verified by restoring the bug. The comment beside it asserted "outside the guard's 5%
tolerance", which was false and was the premise a reader would trust. Replaced with
1250x1172, the same aspect as the 9600x9000 scan that motivated it, at 0.064 — the
closest legitimate case to the threshold.

**Fixed in passing:** the `@details` `case_when` example claimed `.default = NA` falls
through to auto. It does not — a square footprint falls to 180 and a non-square one to
the digital mapping.

### Code-check round 3 — the tolerance was 0.4% too loose

Findings in `planning/active/review-round3.md`. Round 2's fixes were the target, and one
of them was wrong by a hair in the direction that matters.

`fly_gcp_stretch_max()` was set to **1.10**. The tightest case it has to catch is a Leica
DMC II frame sized through `format_size` onto a square footprint: `|log(15552/14144)| =
0.09490` against `log(1.10) = 0.09531`. It slipped — verified end to end on a real
bundled frame through `fly_footprint()`, `georef_one()` and GDAL: file written,
`success = TRUE`, **0 warnings**, a 10% stretch. Of all 19 rows in `camera_formats.csv`
it is the only one that slips, and it is the exact case the tolerance had replaced the
shape gate to cover.

The admissible band is **(1.0667, 1.0995)** — narrow, because a square-footprint DMC II
frame is barely more eccentric than a badly rebated film scan. Set to **1.08**, near the
middle, with 1.19x margin below and 1.23x above.

**And the test that was supposed to guard the threshold could not.** It asserted the
square-footprint case using the UltraCam at 0.442 — the *most* eccentric camera, which
any tolerance clears. Picking the lenient example is how the threshold came to be wrong
in the first place. Rewritten to compute over every row of the shipped table and assert
that none slips, plus the margin on both sides. Restore-the-bug: putting 1.10 back takes
it from FAIL=0 to FAIL=2, both bindings patched with the value printed.

Also fixed: the `case_when` roxygen comment held only under `rotation = "auto"` — under an
explicit argument a square footprint falls through to that argument, not to 180.

Lint: `data-raw/georef_calibrate-corner_mapping.R` cleaned from 6 style lints to 0.
`R/fly_georef.R` is 1 against a `main` baseline of 5, and that one is the documented
installed-vs-source artifact (`exists("fly_gcp_stretch_max", asNamespace("fly"))` is
FALSE).
