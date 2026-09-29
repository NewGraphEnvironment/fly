# Review round 1 — fly#56 staged diff

## Clean

No issues found.

Checked, and why each held:

- `fly_georef_warp_opts()`: `-srcalpha` / `-srcnodata` is a strict else-if, so the pair the
  checklist's "GDAL applies -srcnodata and an alpha mask together" rule warns about cannot
  reach GDAL. `n_bands` is the ORIGINAL source's band count and is only consulted on the
  unmasked (`-srcnodata`) arm, so the extra alpha band on the masked copy never inflates the
  srcnodata vector.
- gdalwarp propagating an explicit `-srcnodata` to the output as dstnodata (which would bring
  the value collision back on the mask = "none" / fallback path): probed in a scratch dir on
  this machine's GDAL — `-srcnodata 0 -dstalpha` on a 1-band Byte source writes 2 bands and
  NO NoData Value; mask flags are PER_DATASET ALPHA. The new test asserting no "NoData Value"
  on both legs covers this.
- Decline warning in `georef_one()`: `res$reason` exists on the `fly_mask_row()` tibble
  (no partial-match or missing-column risk). Only fires when srcnodata is NULL; the non-Byte
  decline path in `fly_mask_one()` is silent, so this is the only warning there and the
  `expect_warning(..., "declined .*band type.*srcnodata")` regexp matches it.
- Tests discriminate: the interior-zero test passes `srcnodata = "0"` on a frame the mask
  accepts, so leaking `-srcnodata` would turn the block transparent (alpha != 255); reverting
  to `-dstnodata 0` makes the block NA. The fallback test's 4400 +- 5% (relative, +-220) fails
  on the no-op mutation (difference 0). UInt16 fixture written with NAflag = 65535 so the file's
  own nodata does not mask the collar in both legs (comment explains, and is correct).
- `test-fly_georef_digital.R` `mask = "none"` changes: the aspect guard runs before masking,
  so the tests still exercise what they claim; `expect_no_warning` would otherwise catch the
  new decline warning on UInt32 fixtures.
- No other in-package consumer (R/, vignettes) reads georef outputs' band count or nodata.
- `data-raw/mask_measure-interior_zeros.R`: statement split only.
