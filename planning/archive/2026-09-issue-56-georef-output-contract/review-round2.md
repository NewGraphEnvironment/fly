# Code-check round 2 — fly#56 staged diff

## Findings

- **[severity: fragile]** R/fly_georef.R:161 (and man/fly_georef.Rd:190) — "On the 264 thumbnails
  `mask_threshold` was calibrated on, and on 10,105 more, the mask declined none." The 10,105 is
  the **whole directory, which contains the 264**. Verified from the producer's own output,
  `data-raw/.cache/mask_interior_zeros.csv`: 10,105 rows, `sum(calibration) == 264`, no duplicate
  basenames. `findings.md` has it right ("Whole directory today (10,105 ...)"), and the script's
  `report(res, "directory")` covers all rows. So "10,105 more" overstates the evidence by 264
  frames. Should read "and on all 10,105 in the directory" or "and on 9,841 more". This is an
  exported help page, and a published number that was copied rather than derived (karpathy §7).

## Checked and clean

- Decline paths vs. docs: `fly_mask_one()` returns `masked = FALSE` for unreadable dimensions,
  non-Byte or unreadable band type, no nearblack output, an unmeasurable interior fraction, the
  interior cap, and a failed write. The doc lists three of those as examples ("an unreadable or
  non-8-bit source, or a mask that floods into the interior"), which is not wrong. "An error
  inside it fails the frame instead" holds: the `georef_one()` call in `fly_georef()` sits inside
  a `tryCatch(error =)` and returns FALSE. The claim that "a non-Byte source returns quietly" is
  true. The warning never interpolates an NA reason in practice: every `masked = FALSE` row
  carries one.
- `fly_georef()` wraps `georef_one()` in `tryCatch(error = )` only, with no `warning =` handler,
  so the new warning cannot throw away the frame's success value.
- `fly_georef_warp_opts()`: `-srcalpha` and `-srcnodata` stay either/or, and `-dstalpha` is
  added unconditionally. This matches the roxygen.
- Measurement script: the calibration join by basename matches all 264 and has no collisions.
  All sources are JPEG, which terra and nearblack both read through GDAL, so the two agree. The
  masked copy is GTiff with 0/255 alpha, so `alpha == 255` is right. RGB rows carry NA zero
  counts, and `report()` only reads `bands == 1`. The only diff is splitting one line.
- Tests: `terra::extract(SpatRaster, matrix)` returns no ID column (checked: names are
  `lyr.1 lyr.2`), so `v[[1]]`/`v[[2]]` index gray and alpha correctly. The
  `expect_warning` regex `"declined .*band type.*srcnodata"` matches the actual message. The
  relative `tolerance = 0.05` on 4400 accepts 4180–4620, and a vacuous 0 cannot pass. The
  "accepted" test would go red under the old top-level refusal.
- Ran `test-fly_georef_mask.R` (90 pass) and `test-fly_georef_digital.R` (53 pass) with
  `NOT_CRAN=true` in a copy of the repo. There were no failures and no skips.
- The "on every platform" band-count claim is backed only by macOS/ubuntu so far. The e2e test
  asserts it with no condition, so a Windows disagreement will turn CI red rather than pass
  silently. That makes it a claim waiting on CI, not a defect.
