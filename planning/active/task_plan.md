# Task: Detect circular image boundary for alpha masking (#23)

## Problem

Issue #23 asks for Hough-transform circle detection to mask the "circular lens image
area" of airphoto scans, because `fly_georef(srcnodata = "0")` masks real dark pixels.

**The premise is falsified by the data, and there is a different live defect underneath
it.** Measured across all 264 raw thumbnails in
`~/Projects/repo/stac_airphoto_bc/data/raw/thumbs` (1967-2018, JPEG, 1 and 3 band):

| claim | inscribed circle predicts | measured |
| --- | --- | --- |
| dark fraction | 0.2146 | median **0.027**, max 0.191; 2 of 264 within 20% of 0.2146 |
| corner darkness | ~1.0 | median 0.382 |
| edge-midpoint darkness | ~0.0 | median **0.216** - a circle cannot darken edge midpoints |
| dark pixels within 5% of an edge | low | median per-frame share **1.000** |

It is a frame border with chamfered corners, not a lens circle. 38 of 264 frames have
no dark border at all (fraction < 0.002), including all ten 2018 digital frames - so no
global mask shape is right either.

**The live defect:** `-srcnodata "0"` masks only *exact* zeros. Scanned black is 3-12,
not 0. Median exact-zero fraction is 0.0026 against 0.027 at threshold 16 - so roughly
90-97% of the black border is currently not masked at all, which is exactly the reported
mosaic symptom.

**Scope limit.** #23's trigger is full-resolution scans, which are licence-restricted and
unreachable from this package. That is why `fly_mask()` is exported: a user holding
licensed scans on disk needs an entry point that does not go through `fly_fetch()`.

## Approach

GDAL's `nearblack` utility is this problem, and `sf::gdal_utils()` already dispatches to
it - `-alg floodfill` is a flood fill seeded from the image border, i.e. exactly the
edge-connected-dark-component prototype, in C++, with no new dependency. Verified:
output band counts do not change on either path.

## Phase 0: Measure, no package code

- [x] Write `data-raw/mask_calibrate-border_threshold.R`, taking the thumbnail directory as an argument
- [x] Verify `nearblack -alg floodfill` agrees per-frame with `terra::patches(directions = 8)` across all 264 - the go/no-go for the dependency-free route
- [x] Re-cut the threshold sweep **per frame**: the threshold at which each frame's own mask fraction stops growing; take a high quantile as `fly_mask_threshold()`
- [x] Measure `frac_total` and `frac_interior` distributions and their **maxima** at that threshold; set `fly_mask_max_interior()` above the largest legitimate value, and record the computed admissible band
- [x] Verify bilinear resampling of the alpha band does not leave a dark fringe at the mask boundary; if it does, record the erode-inward remedy rather than changing resampling
- [x] Commit the script and `inst/extdata/mask_border_sweep.csv` (264 frames x threshold grid) so both constants are checkable inside the suite

## Phase 1: The argument, before any code

- [ ] Write `inst/notes/border-masking.md`: the circle falsification with the table above; the physical argument (a mapping camera's format sits inside the lens image circle, so there is no dark circle at any resolution) marked as reasoning rather than measurement; the sweep; why each constant is what it is; the guard's computed admissible band
- [ ] Record the tried-and-rejected list: total-fraction cap, the `terra::patches` prototype, `-alg twopasses`
- [ ] Record the scope limit - full-res is unreachable, `nearblack` assumes Byte bands, and `-near` does not transfer to 16-bit scans
- [ ] Record that no real thumbnail in the population can reach the runaway guard at the chosen threshold, so only a synthesized fixture can

## Phase 2: `fly_mask()`

- [ ] `R/fly_mask.R` - `fly_mask(src, dest_dir = "masked", threshold = 16, overwrite = FALSE)` returning a tibble with `source`, `dest`, `mask_fraction`, `mask_fraction_interior`, `threshold`, `masked`, `reason`, `success`
- [ ] `fly_mask_one()` plus `@noRd` constants `fly_mask_threshold()` and `fly_mask_max_interior()`, matching `fly_gcp_stretch_max()` / `fly_digital_rotation()`
- [ ] Measure the fraction on the **source**, pre-warp - measuring the warped output counts GDAL's fill outside the rotated frame, which at a 45-degree bearing is nearly half the output
- [ ] Interior fraction via `gdal_translate -of VRT -b <alpha> -srcwin` + `gdal_utils("info", "-stats")`, so no pixels are read into R
- [ ] Runaway guard: warn naming the file, both fractions, the threshold and the remedy; fall back to unmasked; a zero mask fraction is **not** a warning (38 of 264 legitimately have none)
- [ ] `tests/testthat/test-fly_mask.R` - Fixture A (border ring valued 3-12 **never exactly 0**, bright interior, interior dark blob not touching any edge) with both premises asserted, and an assertion that threshold-only and edge-connected answers **differ** on it
- [ ] Fixture B (dark blob touching an edge and reaching past the interior box): guard message grepped, `masked` FALSE, `success` TRUE, file written with today's band count
- [ ] Assertions against `mask_border_sweep.csv`: every legitimate frame below the cap, margin real on both sides, runaway case above it, `expect_gt(nrow(sweep), 200)` as a premise
- [ ] `devtools::document()`, check `NAMESPACE` gained exactly `export(fly_mask)`, add to `_pkgdown.yml` reference and run `pkgdown::check_pkgdown()`

## Phase 3: Wire into `fly_georef()`

- [ ] Add `mask = "border"` and `mask_threshold = 16`; `srcnodata` default changes `"0"` -> `NULL`
- [ ] Passing `srcnodata` non-NULL with `mask = "border"` is an **error** naming both arguments and the remedy - not a silent drop
- [ ] Extract `fly_georef_warp_opts(is_rgb, srcnodata, masked)` as a pure `@noRd` function, the same split that made `fly_georef_gcps()` testable
- [ ] Use `-of VRT` for the GCP translate step so only the nearblack output is materialised
- [ ] `tests/testthat/test-fly_georef_mask.R` - pure-args assertions (`-srcnodata` absent whenever masked, `-srcalpha` present whenever masked, `-dstalpha` iff RGB, `-dstnodata 0` iff grayscale)
- [ ] Parity assertion: `mask = "none"` reproduces today's exact option vector, so the old path is byte-identical to the current release
- [ ] Band-contract assertions pinned explicitly: 3-band source -> 4 bands out with band 4 Alpha; 1-band source -> 1 band out with `NoData Value=0`
- [ ] Rotation-invariance assertion: the same source under two footprint rotations gives an identical `mask_fraction` - this is what pins "measured on the source, not the warped output"
- [ ] End-to-end: opaque pixel count with `mask = "border"` is strictly less than with `mask = "none"`, by about the border fraction

## Phase 4: Correct the false documentation

- [ ] Fix the `srcnodata` `@param` and the **Tradeoff** paragraph in `fly_georef()`'s `@details` - both halves of the stated tradeoff are contradicted by measurement. Its own commit, since it is true independently of the feature

## Phase 5: Release and issue bookkeeping

- [ ] Edit issue #23's body to the measured problem and retitle it
- [ ] `NEWS.md` entry: the falsification, the under-masking defect, `fly_mask()`, band counts unchanged, `srcnodata` default change
- [ ] Bump `DESCRIPTION` to 0.11.0 as the final commit of the branch
- [ ] Open a follow-up issue for switching grayscale from `-dstnodata 0` to a real alpha band, naming the band-count change and `stac_airphoto_bc` as the consumer

## Phase 6: Restore-the-bug proof

- [ ] Four restorations, each with **exact prior bytes** from git rather than a rewrite
- [ ] Run with `testthat::test_file()`, never `test_local()` / `devtools::test()`
- [ ] Print a probe proving each patch took, and **grep the output for the expected message** rather than reading the exit status
- [ ] Read `as.data.frame(test_file(f))$failed` rather than the console, which truncates at 10
- [ ] Record per-restoration failure counts and grepped messages in the PR body

## Validation

- [ ] Tests pass
- [ ] `lintr::lint_package()` diffed against the branch-point baseline
- [ ] `devtools::document()` output read; `NAMESPACE` gained exactly one export
- [ ] `pkgdown::check_pkgdown()` clean
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
