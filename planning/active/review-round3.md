# Review round 3 — fly#56 staged diff

Scope: `git diff --cached` (R/fly_georef.R, man/fly_georef.Rd, tests/testthat/test-fly_georef_mask.R,
tests/testthat/test-fly_georef_digital.R, data-raw/mask_measure-interior_zeros.R). Worked in a
`git archive` copy of the staged tree under the session scratchpad; the repo was not touched.

## Mechanism behind the round-2 defect

A quantified claim was **restated from a derived document** (findings.md) instead of being
re-derived from its producer, so how two populations relate (264 is a subset of 10,105) was lost
in the copy. The same mechanism reaches any claim whose wording carries a scope ("on every
platform", "never", "on Windows"), because a scope is exactly what a summary compresses. Every
quantified claim in the diff is checked against its producer below.

## Findings

- **[low]** R/fly_georef.R:132 (roxygen, Nodata handling item 1), tests/testthat/test-fly_georef_mask.R
  comments in the "every output carries a real alpha band" and "true black" tests —
  "on Windows had GDAL shift it to 1 instead" names the **platform** where the cause is the
  **GDAL version**. Measured: local macOS GDAL 3.8.5 writes the 0s as nodata (NA, 121 of 121
  in a probe) with no shift; ubuntu CI installs GDAL 3.8.4; the Windows CI log (run
  36448274403) prints `Value 0 in the source dataset has been changed to 1`, the gdalwarp
  behaviour of a newer GDAL. So mac/ubuntu would shift too after a GDAL upgrade. It also
  qualifies the data-raw header ("any pixel ... at exactly 0 ... was written as nodata"): true
  only on the GDAL the measurement ran on. The shipped code is unaffected (it no longer uses
  `-dstnodata`); the prose is a proxy for the discriminating fact. Suggest "on newer GDAL (seen
  on the Windows runner)".

- **[low]** R/fly_georef.R:534-535 (`fly_georef_warp_opts()` roxygen) — "Nothing is marked by
  value, so a genuine 0 is **never** mistaken for fill." False on the `-srcnodata` leg, which
  this same function emits (mask = "none", or a declined frame given `srcnodata`): there a
  genuine source 0 becomes transparent, i.e. indistinguishable from fill. `fly_georef()`'s own
  roxygen says so ("on the frame it reaches it also removes any true black inside the frame"),
  so the two docs contradict. Scope it to the fill marker (`-dstalpha`), or to the no-srcnodata case.

- **[low]** tests/testthat/test-fly_georef_mask.R, "a declined mask falls back to srcnodata"
  comment — "`NA` is written to a UInt16 file as nodata 0". Probed (terra 1.9.50):
  `NAflag = NA` writes `NoData Value=nan`, not 0. The behavioural conclusion is right — GDAL
  honours that NaN as 0 on an integer band, so both legs masked the collar (10000/10000 opaque)
  where `NAflag = 65535` separates them (10000 vs 14400) — but the stated mechanism is wrong,
  and the NaN-to-integer reading is exactly the kind of thing a GDAL upgrade changes. Note the
  8-bit `collar_frame()` fixture carries the same `nan` nodata; its assertions passed here.

- **[low]** tests/testthat/test-fly_georef_digital.R:~225 — "the fixture is UInt32, which the
  border mask declines with a warning **of its own**". `fly_mask_one()`'s non-Byte path returns
  without warning (R/fly_mask.R:234-243, and the new georef_one comment says so); the warning is
  `georef_one()`'s new one. Misattribution in a comment only.

- **[low]** R/fly_georef.R:146-147 (roxygen) — "[fly_mask()] declines some frames — an
  unreadable or non-8-bit source, or a mask that floods into the interior" reads as the full
  list; `fly_mask_one()` also declines on "nearblack wrote no output", "interior mask fraction
  could not be measured" and "could not write the masked copy" (fly#69 counts four documented
  paths). Doc accuracy only; the code handles every decline identically.

## Claims checked and found correct (producer in brackets)

- "all 10,105 public thumbnails ... (the 264 ... among them), the mask declined none"
  [data-raw/.cache/mask_interior_zeros.csv: 10,105 rows, masked TRUE on all, calibration TRUE on
  264, 0 error reasons].
- "Before v0.19.0 this pair was refused ...; they never did" [git: the `else if` in
  `fly_georef_warp_opts()` exists since a767204, the same commit that added the refusal;
  DESCRIPTION is 0.18.0].
- "120^2 - 100^2 = 4400 source pixels" [arithmetic; probe gives 14400 vs 10000 opaque].
- "65535 on a UInt16 output" [probe: alpha max 65535].
- "+-20 m of the ring's centre is inside" the 11x11 block [block spans pixels 55-65, i.e.
  -60..+50 m about centre; ±20 m plus the bilinear reach of 10 m stays inside].
- "an error inside it fails the frame" [georef_one calls fly_mask_one with no tryCatch; the
  error reaches fly_georef's per-frame tryCatch].
- "The aspect guard under test runs before masking" [georef_one: aniso check precedes Step 1].
- fly#56, fly#68, fly#69 resolve to on-topic issues.
- man/fly_georef.Rd regenerates identically from the roxygen.
- test-fly_georef_mask.R and test-fly_georef_digital.R: all blocks pass (NOT_CRAN=true), 0
  failures, 0 warnings; test-fly_georef.R and test-fly_georef_aspect.R pass.

Accepted tradeoffs not re-raised: "on every platform" for the band count (CI-asserted, not yet
observed on Windows), unused `is_rgb`, thumbnail-only decline count, `mask = "none"` in the
digital tests.

No correctness, security or data-loss defect found in the code change itself.
