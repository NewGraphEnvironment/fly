# Review — docs round 2 (staged diff after cf47430, fly#56)

Probes run in a scratch copy of the repo against the public thumbnails (read only), on
sf's GDAL 3.8.5, plus Homebrew's CLI GDAL 3.13.0 for the message check.

## Findings

- **[high]** `data-raw/mask_measure-interior_zeros.R` `measure_output()` (the fixed
  `bearing = 30`), and every doc that quotes its result: `NEWS.md:3`, `CLAUDE.md` Key Decision
  ("41 of 182 ... max 0.26%; the source-side count of 161 is an upper bound that an early draft
  quoted as the loss"), `inst/notes/border-masking.md` ("41 of 182 frames", "The same script's
  source-side count ... is an upper bound, not the loss: bilinear resampling turns a lone 0
  among collar-dark 3-12 into a non-zero output. An earlier draft of this note quoted it as the
  loss."), and `planning/active/findings.md` ("The source-side figures below are an upper
  bound"). **The 41-frame figure measures a 30-degree rotation, and the path most grayscale
  output took is not rotated.** A film frame with no flight bearing is warped axis-aligned (13 of
  the 20 bundled frames have none). A film frame with a bearing is refused unless the caller
  supplies `rotation`. On an axis-aligned warp the output grid lines up with the source pixels,
  bilinear resampling reproduces every value, and **every opaque source 0 is rewritten**. The
  source-side count is then the output loss exactly, not an upper bound.
  I measured this with `measure_output()`'s own code, changing only `bearing`:

  | frame | bearing 30 (what the docs quote) | bearing 0 / NA | source opaque zeros |
  | --- | --- | --- | --- |
  | bcb94081_042 | 3,922 rewritten (0.26%) | **54,612** rewritten (3.5%) | 54,612 |
  | bc5300_010 | 31 | **173** | 173 |

  I also ran bcb94081_042 on a realistic ground footprint: half-side 2,537 m, so about 4 m
  cells, with bearing NA. It rewrote 54,612 of 54,612. So the round-1 finding (b) that prompted
  this pass assumed "bilinear onto a rotated grid". That assumption does not hold for the common
  path, and the correction swapped a right-for-unrotated number for a wrong-for-unrotated one.
  Readers get the wrong magnitude by up to about 14x, and the NEWS "at most 0.26% of one frame"
  bound is false: 3.5% for that frame unrotated. Remedy: measure at bearing NA (or at both), and
  state the old figures (161 of 182 frames, up to 3.5%) as the axis-aligned loss, with the
  rotated result as the case where resampling masks isolated zeros. The "lone 0 among collar-dark
  3-12" mechanism only operates under rotation, and it is conjecture in any case: the output
  pass did not test it.

- **[low]** `data-raw/mask_measure-interior_zeros.R`, the second `parLapplyLB(cl, gray_calib,
  measure_output)`, has no `tryCatch`. That is not silent, because an error aborts the script.
  But the abort happens before `parallel::stopCluster(cl)`, so the PSOCK workers are orphaned.
  Detached workers outlive their master (spatial checklist, "PSOCK workers outlive their
  master"). Use `tryCatch(..., finally = stopCluster(cl))` or `on.exit`.

- **[low]** `planning/active/findings.md` (new paragraph): "the 'Windows shifts to 1' framing
  of #68 was a GDAL behaviour everywhere, only printed there". It is printed by GDAL version, not
  by platform. Homebrew's GDAL 3.13.0 CLI on this Mac prints `Warning 1: Value 0 in the source
  dataset has been changed to 1 ...` for the same VRT, and sf's 3.8.5 prints nothing. The
  public note's wording ("sf's GDAL 3.8.5 on macOS does the same and says nothing") is accurate.
  The planning file's framing is the one that is off.

## Checked and correct

- **Measurement validity, apart from the geometry.** Old and new outputs share a grid. Dims
  and extent were identical in every probe (1708x1708 at 30 degrees, 1250x1250 unrotated).
  The script does not assert this, but it holds, and a mismatch would surface as an R length
  warning. terra reads the old output's nodata 0 as NA. The new alpha has only the values
  {0, 255}, so `inside` misses no partial-alpha cells. Partial-alpha cells holding a new 0
  numbered 0. There is no confound: inside the frame, old and new differ nowhere except at the
  0-to-1 cells, and no old 1 sits where the new value is above 1.
- **"Silently on sf's GDAL 3.8.5".** Supported. With `sf::gdal_utils(..., quiet = FALSE)` and
  calling handlers for warnings and messages, the probe captured nothing and printed nothing.
  CLI 3.13 prints the warning.
- **Log figures.** Every one matches log3.txt as the docs state it: 41 frames, 12,682 px,
  median 13, max 0.26% (bcb94081_042), ten worst all bcb94081, 0 deleted, 161 of 182 and 3.5%
  source-side, 0 of 264 and 0 of 10,105 declined, 182 of 264 grayscale. The table's framing
  as the figure is what is wrong; see the high finding.
- **Rotated warp alpha.** Two distinct output alpha values on a rotated warp: confirmed
  (0, 255).
- **Public repo.** No private sibling is named anywhere in the diff. progress.md says "the
  private sibling" only.
