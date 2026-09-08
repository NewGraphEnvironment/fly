# The frame-border mask, tested offline on synthesized images.
#
# Real thumbnails cannot live here — `inst/notes/georeferencing.md` sets that precedent
# and `data-raw/mask_calibrate-border_threshold.R` is where they are read. What ships
# instead is `inst/extdata/mask_border_sweep.csv`, the per-frame sweep both constants were
# derived from, so "the cap sits above the largest legitimate value" is a computation here
# rather than a recollection. See `inst/notes/border-masking.md`.

# A frame with a black collar, a bright interior, and a dark blob INSIDE the frame that
# touches no edge.
#
# Three properties of this fixture are load-bearing and each is asserted as a premise
# below rather than trusted:
#
#   * the collar is 3-12, never exactly 0. A collar of 0 is masked by the pre-0.11.0
#     `srcnodata = "0"` path too, so a fixture built that way cannot reach the defect.
#   * the blob is under threshold and NOT edge-connected. Without it a plain global
#     threshold scores identically and the test cannot tell the two apart.
#   * the two answers therefore differ, by exactly the blob's area.
bordered_image <- function(path, n = 200L, collar = 10L, blob = 20L, bands = 1L) {
  m <- matrix(200L, nrow = n, ncol = n)

  # collar: 3-12, deterministic so the premise assertions are exact
  vals <- rep(seq.int(3L, 12L), length.out = n)
  for (k in seq_len(collar)) {
    m[k, ] <- vals
    m[n - k + 1L, ] <- vals
    m[, k] <- vals
    m[, n - k + 1L] <- vals
  }

  # interior blob, centred, well clear of the collar
  lo <- (n - blob) %/% 2L + 1L
  hi <- lo + blob - 1L
  m[lo:hi, lo:hi] <- 4L

  r <- terra::rast(nrows = n, ncols = n, nlyrs = bands, vals = 0L)
  for (b in seq_len(bands)) terra::values(r[[b]]) <- as.integer(t(m))
  terra::writeRaster(r, path, datatype = "INT1U", overwrite = TRUE, NAflag = NA)

  list(path = path, n = n, collar = collar, blob = blob,
       collar_frac = 1 - ((n - 2 * collar)^2) / n^2,
       # What nearblack actually removes. `-nb` (default 2) is how many non-black pixels
       # it tolerates before deciding the collar has ended, so the fill advances two
       # pixels past the last dark one on every side. Measured 0.2256 against 0.2256
       # predicted on this fixture. Stated here rather than absorbed into a loose
       # tolerance: if someone sets `-nb`, this is the assertion that says so.
       collar_frac_nb = 1 - ((n - 2 * (collar + 2L))^2) / n^2,
       blob_frac   = blob^2 / n^2,
       blob_rows   = lo:hi)
}

# A frame whose dark region touches an edge and runs to the centre — a lake reaching off
# the frame. This is what the runaway guard exists for, and NO real thumbnail in the
# measured population can reach it (largest legitimate interior fraction 0.0131 against a
# 0.05 cap), so a synthesized fixture is the only thing that can test it.
flooded_image <- function(path, n = 200L) {
  m <- matrix(200L, nrow = n, ncol = n)
  m[, 1:(n * 0.75)] <- 4L        # dark from the left edge, three quarters across
  r <- terra::rast(nrows = n, ncols = n, vals = 0L)
  terra::values(r) <- as.integer(t(m))
  terra::writeRaster(r, path, datatype = "INT1U", overwrite = TRUE, NAflag = NA)
  path
}

alpha_of <- function(path) {
  r <- suppressWarnings(terra::rast(path))
  a <- terra::as.array(r)
  a[, , dim(a)[3]]
}


test_that("the fixture can reach the failure modes it is built for", {
  skip_if_no_terra()
  f <- bordered_image(tempfile(fileext = ".tif"))
  a <- terra::as.array(suppressWarnings(terra::rast(f$path)))[, , 1]

  # Premise 1: the collar is dark but never exactly 0. A collar of 0 is masked by the old
  # exact-zero path as well, so a fixture built that way proves nothing about this one.
  collar_px <- a[1, ]
  expect_gt(min(collar_px), 0)
  expect_lte(max(collar_px), 12)

  # Premise 2: the blob is under threshold, non-empty, and touches no edge.
  expect_gt(f$blob_frac * f$n^2, 0)
  expect_true(all(a[f$blob_rows, f$blob_rows] <= fly_mask_threshold()))
  expect_equal(min(f$blob_rows) > 1L, TRUE)
  expect_equal(max(f$blob_rows) < f$n, TRUE)

  # Premise 3: a plain threshold and an edge-connected mask give DIFFERENT answers here.
  # If they agreed, every assertion below would pass for a plain threshold too and the
  # test would discriminate nothing.
  threshold_only  <- mean(a <= fly_mask_threshold())
  edge_connected  <- f$collar_frac
  expect_gt(threshold_only, edge_connected)
  expect_equal(threshold_only - edge_connected, f$blob_frac, tolerance = 1e-9)
})


test_that("fly_mask() masks the collar and leaves interior darkness alone", {
  skip_if_no_terra()
  f   <- bordered_image(tempfile(fileext = ".tif"))
  out <- fly_mask(f$path, dest_dir = tempfile(), threshold = fly_mask_threshold())

  expect_true(out$success)
  expect_true(out$masked)
  expect_true(file.exists(out$dest))

  # The collar comes off, and by exactly the amount nearblack's `-nb` overrun predicts —
  # known to three decimals because the fixture was built rather than sampled. The strict
  # collar is 0.190 and the overrun accounts for the rest; asserting the loose value with
  # a wide tolerance would have hidden which of the two was being measured.
  expect_equal(out$mask_fraction, f$collar_frac_nb, tolerance = 0.005)
  expect_gt(out$mask_fraction, f$collar_frac)

  # THE assertion. The interior blob is under threshold and survives, because it is not
  # reachable from the image edge. A plain threshold deletes it.
  al <- alpha_of(out$dest)
  expect_true(all(al[f$blob_rows, f$blob_rows] == 255))

  # ...and the collar really is transparent, so the test above is not passing because
  # nothing was masked at all.
  expect_true(all(al[1, ] == 0))

  # A collar hugs the border, so it contributes essentially nothing to the central box.
  # This is the property the runaway guard's predicate rests on.
  expect_lt(out$mask_fraction_interior, 0.001)
})


test_that("output band count matches the source, with alpha appended", {
  skip_if_no_terra()

  gray <- bordered_image(tempfile(fileext = ".tif"), bands = 1L)
  g    <- fly_mask(gray$path, dest_dir = tempfile())
  expect_equal(fly_gdal_bands(fly_gdal_info(g$dest)), 2L)

  rgb <- bordered_image(tempfile(fileext = ".tif"), bands = 3L)
  r   <- fly_mask(rgb$path, dest_dir = tempfile())
  expect_equal(fly_gdal_bands(fly_gdal_info(r$dest)), 4L)

  # RGB gets a properly declared alpha band. Grayscale does NOT — nearblack writes
  # `ColorInterp=Undefined` on band 2 there, measured, which is why `fly_georef()` reaches
  # it with `-srcalpha` (forces the last band) rather than by reading ColorInterp.
  expect_match(fly_gdal_info(r$dest), "ColorInterp=Alpha")
})


test_that("the runaway guard fires, warns by name, and falls back rather than skipping", {
  skip_if_no_terra()
  src <- flooded_image(tempfile(fileext = ".tif"))

  # Several messages may be emitted; match against all of them rather than the first.
  # `expect_warning(expr, regexp)` checks only the first condition.
  w <- testthat::capture_warnings(
    out <- fly_mask(src, dest_dir = tempfile(), threshold = fly_mask_threshold())
  )
  expect_true(any(grepl("flood into the image", w)))
  expect_true(any(grepl("interior", w)))

  # Declined, not failed: the call produced a definite answer and said why.
  expect_false(out$masked)
  expect_true(out$success)
  expect_true(is.na(out$dest))
  expect_match(out$reason, "interior cap")
  expect_gt(out$mask_fraction_interior, fly_mask_max_interior())
})


test_that("an unmeasurable interior fraction refuses the mask rather than writing it", {
  skip_if_no_terra()
  f <- bordered_image(tempfile(fileext = ".tif"))

  # `fly_alpha_fraction()` returns NA when GDAL reports no statistics. Guarding the
  # comparison with `is.finite()` would silently SKIP the runaway check in that case and
  # write the mask anyway — a guard failing toward pass on the one branch that exists to
  # catch a flood. Mocked rather than provoked because a GDAL build that fails to report
  # statistics is not something a fixture can arrange.
  testthat::local_mocked_bindings(
    fly_alpha_fraction = function(path, band, srcwin = NULL) NA_real_,
    .package = "fly",
    .env = parent.frame()      # unwinds with this test, not with the helper
  )

  w <- testthat::capture_warnings(
    out <- suppressMessages(fly_mask(f$path, dest_dir = tempfile()))
  )
  expect_true(any(grepl("could not measure", w)))
  expect_false(out$masked)
  expect_true(is.na(out$dest))
  expect_match(out$reason, "could not be measured")

  # Reported as a definite answer, not as a failure: the call did its job and declined.
  expect_true(out$success)
})


test_that("a frame with no collar masks nothing, and that is not a warning", {
  skip_if_no_terra()
  src <- tempfile(fileext = ".tif")
  r <- terra::rast(nrows = 100, ncols = 100, vals = 200L)
  terra::writeRaster(r, src, datatype = "INT1U", overwrite = TRUE, NAflag = NA)

  # 27 of the 264 measured frames carry no collar at all. An empty mask is the right
  # answer for them, so it must not warn.
  expect_silent(out <- suppressMessages(fly_mask(src, dest_dir = tempfile())))
  expect_true(out$masked)
  expect_equal(out$mask_fraction, 0, tolerance = 1e-6)
})


test_that("fly_mask() validates its arguments by value, not by coercion", {
  expect_error(fly_mask(1:3), "character vector")
  expect_error(fly_mask("a.tif", threshold = -1), "between 0 and 255")
  expect_error(fly_mask("a.tif", threshold = 256), "between 0 and 255")
  expect_error(fly_mask("a.tif", threshold = c(1, 2)), "single whole number")
  expect_error(fly_mask("a.tif", threshold = "ninety"), "single whole number")

  # `as.integer()` on a factor returns its LEVEL CODE, so a threshold read from a CSV as
  # a factor would validate as one number and be applied as another. The guard converts
  # through `as.character()` for exactly this reason.
  expect_error(fly_mask("a.tif", threshold = factor("300")), "between 0 and 255")
})


test_that("an accepted factor threshold is APPLIED as the number it validated as", {
  skip_if_no_terra()
  f <- bordered_image(tempfile(fileext = ".tif"))

  # `as.integer()` on a factor returns its LEVEL CODE, so `factor("16")` is 1. Validation
  # converts through `as.character()` and gets 16; if the validated value is discarded and
  # the raw argument is passed on, GDAL runs at `-near 1`, masks nothing, and reports
  # `masked = TRUE` with `mask_fraction = 0` — which this function documents as the
  # legitimate no-collar answer. The two are then indistinguishable.
  #
  # The rejected case (`factor("300")`) cannot see this: nothing is applied there.
  int_run <- fly_mask(f$path, dest_dir = tempfile(), threshold = 16L)
  fac_run <- fly_mask(f$path, dest_dir = tempfile(), threshold = factor("16"))

  expect_equal(fac_run$mask_fraction, int_run$mask_fraction, tolerance = 1e-9)
  expect_equal(fac_run$threshold, 16L)
  expect_gt(fac_run$mask_fraction, 0)
})


test_that("the shipped default IS the calibrated constant, not a copy of it", {
  # Changing the signature default without changing the constant would otherwise leave
  # every test green while the exported function ran at a threshold the sweep rejects.
  expect_identical(eval(formals(fly_mask)$threshold), fly_mask_threshold())
})


test_that("zero-length input returns the documented shape, not NULL", {
  # `do.call(rbind, list())` is NULL. The roxygen example reaches this whenever no
  # thumbnail downloaded, and the next line subsets the result.
  out <- suppressMessages(fly_mask(character(0), dest_dir = tempfile()))
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0L)
  expect_identical(
    names(out),
    c("source", "dest", "mask_fraction", "mask_fraction_interior", "threshold",
      "masked", "reason", "success")
  )
  # The column set must come from the same builder every other exit uses, or an added
  # column reaches some paths and not this one.
  expect_identical(names(out), names(fly_mask_row(NA_character_, NA_character_, NA_real_,
                                                  NA_real_, 1L, FALSE, NA_character_, FALSE)))
})


test_that("two sources with one basename are refused rather than silently collided", {
  skip_if_no_terra()
  d1 <- tempfile()
  d2 <- tempfile()
  dir.create(d1)
  dir.create(d2)
  a <- bordered_image(file.path(d1, "frame.tif"))
  b <- bordered_image(file.path(d2, "frame.tif"))

  # Both map to <dest_dir>/frame_masked.tif. Left alone, the second row reports
  # `masked = TRUE` while its `dest` holds the FIRST frame's pixels.
  #
  # Refused per row rather than by aborting the batch: fly#30 and #47 settled that a
  # frame fly cannot handle is reported, not allowed to take the other frames with it.
  out <- suppressMessages(fly_mask(c(a$path, b$path), dest_dir = tempfile()))
  expect_equal(nrow(out), 2L)
  expect_false(any(out$masked))
  expect_true(all(is.na(out$dest)))
  expect_true(all(grepl("collides", out$reason)))
  expect_true(all(out$success))

  # ...and a third, non-colliding frame in the same batch is still masked.
  c3 <- bordered_image(file.path(d1, "other.tif"))
  mixed <- suppressMessages(fly_mask(c(a$path, b$path, c3$path), dest_dir = tempfile()))
  expect_equal(mixed$masked, c(FALSE, FALSE, TRUE))
})


test_that("a masked copy can never land on top of its own source", {
  skip_if_no_terra()

  # The original defect was `sub("\\.[^.]+$", "_masked.tif", basename(s))`, which does not
  # match a name with NO extension — so the name passed through unchanged and, with
  # `dest_dir` set to the source's own directory, the masked copy replaced the original
  # scan. Irrecoverable, and for licensed full-resolution imagery it is the whole asset.
  #
  # `fly_mask_dest()` now strips the extension and always appends, so the output cannot
  # equal the input for ANY name. Asserted over the awkward ones rather than the tidy one,
  # since the tidy one was never the problem.
  d <- tempfile()
  names_awkward <- c("scan", "scan.tif", "scan.masked", "scan_masked.tif",
                     "a.b.c.tif", ".hidden", "no.ext.here")
  srcs <- file.path(d, names_awkward)
  outs <- fly_mask_dest(srcs, d)

  expect_false(any(fly_same_path(srcs, outs)))
  expect_false(any(srcs == outs))
  expect_true(all(grepl("_masked\\.tif$", outs)))

  # The destination is NOT injective, and pretending otherwise is how the collision bug
  # comes back: `scan` and `scan.tif` in one directory both map to `scan_masked.tif`.
  # That is why `fly_mask()` refuses a colliding batch instead of resolving it.
  expect_gt(anyDuplicated(outs), 0L)
  expect_equal(fly_mask_dest(file.path(d, "scan"), d),
               fly_mask_dest(file.path(d, "scan.tif"), d))

  # And the runtime guard still fires if a future destination scheme reintroduces it.
  f <- bordered_image(tempfile(fileext = ".tif"))
  expect_true(fly_same_path(f$path, f$path))
  expect_false(fly_same_path(f$path, paste0(f$path, "x")))
})


test_that("the resume branch does not claim a threshold it never measured", {
  skip_if_no_terra()
  f <- bordered_image(tempfile(fileext = ".tif"))
  dd <- tempfile()

  first <- suppressMessages(fly_mask(f$path, dest_dir = dd, threshold = 8L))
  expect_true(first$masked)

  # The file on disk was written at 8. Asking for 16 without `overwrite` keeps it, and
  # reporting 16 would label it with a number it does not carry.
  again <- suppressMessages(fly_mask(f$path, dest_dir = dd, threshold = 16L))
  expect_true(again$masked)
  expect_true(is.na(again$threshold))
  expect_match(again$reason, "overwrite")
})


test_that("a non-Byte source is refused rather than reported as having no collar", {
  skip_if_no_terra()
  src <- tempfile(fileext = ".tif")
  r <- terra::rast(nrows = 60, ncols = 60, vals = 5000L)
  terra::writeRaster(r, src, datatype = "INT2U", overwrite = TRUE, NAflag = NA)

  # `-near` is an absolute per-band distance, so a Byte-calibrated threshold reaches
  # nothing on 16-bit imagery and the result would read `mask_fraction` 0 with
  # `masked = TRUE` — the same representation as a frame that genuinely has no collar.
  out <- suppressMessages(fly_mask(src, dest_dir = tempfile()))
  expect_false(out$masked)
  expect_match(out$reason, "not Byte")

  # A reasoned refusal, so `success` is TRUE: the function concluded and declined.
  expect_true(out$success)
})


test_that("an unreadable band type is refused too, not assumed to be Byte", {
  skip_if_no_terra()
  f <- bordered_image(tempfile(fileext = ".tif"))

  # `regmatches()` gives character(0) when nothing matches, so a guard written as
  # `length(types) && !all(types == "Byte")` short-circuits to FALSE and masks an image
  # whose type it could not read — the same fail-toward-pass the interior guard refuses.
  testthat::local_mocked_bindings(
    fly_gdal_info = function(path) "Size is 200, 200\nBand 1 Block=200x1 ColorInterp=Gray",
    .package = "fly",
    .env = parent.frame()
  )

  out <- suppressMessages(fly_mask(f$path, dest_dir = tempfile()))
  expect_false(out$masked)
  expect_match(out$reason, "could not be read")
  expect_true(out$success)
})


test_that("a fractional threshold is refused rather than truncated", {
  # `as.integer("16.7")` is 16 — it truncates rather than returning NA, so a guard
  # watching for NA cannot see it and GDAL runs at a threshold nobody asked for.
  # `code-check.md`, rtj#265: compare against round(), do not watch for NA.
  expect_error(fly_mask("a.tif", threshold = 16.7), "whole number")
  expect_error(fly_mask("a.tif", threshold = 0.9), "whole number")
  expect_error(fly_mask("a.tif", threshold = -3.7), "whole number")

  # A whole number given as a double is fine — this refuses fractions, not doubles.
  expect_silent(fly_check_threshold(16))
  expect_identical(fly_check_threshold(16), 16L)
})


test_that("every exit path agrees with the documented reason/success contract", {
  skip_if_no_terra()
  d <- tempfile()
  dir.create(d)
  good <- bordered_image(file.path(d, "good.tif"))
  dd1 <- tempfile()
  dd2 <- tempfile()
  dir.create(dd1)
  dir.create(dd2)
  dup1 <- bordered_image(file.path(dd1, "dup.tif"))
  dup2 <- bordered_image(file.path(dd2, "dup.tif"))
  flood <- flooded_image(file.path(d, "flood.tif"))
  wide <- file.path(d, "wide.tif")
  terra::writeRaster(terra::rast(nrows = 40, ncols = 40, vals = 5000L), wide,
                     datatype = "INT2U", overwrite = TRUE, NAflag = NA)
  missing <- file.path(d, "nope.tif")

  # Enumerated rather than sampled. `success` must mean the same thing on every path, and
  # the way that breaks is a new branch picking whichever value looked right locally —
  # which is how the non-Byte and interior-cap refusals came to disagree.
  res <- suppressWarnings(suppressMessages(
    fly_mask(c(good$path, dup1$path, dup2$path, flood, wide, missing),
             dest_dir = tempfile())
  ))
  names(res$success) <- c("masked", "collide", "collide", "cap", "nonbyte", "missing")

  # Reasoned refusals conclude: success TRUE.
  expect_true(all(res$success[c("collide", "cap", "nonbyte")]))
  expect_true(res$success[["masked"]])
  # Only a genuine failure is FALSE.
  expect_false(res$success[["missing"]])

  # `reason` is NA only for an ordinary fresh mask.
  expect_true(is.na(res$reason[1]))
  expect_true(all(!is.na(res$reason[-1])))

  # A row is masked iff it has a dest.
  expect_identical(res$masked, !is.na(res$dest))

  # And the column set is identical on every path, in one order — `rbind()` on frames
  # whose names are the same but reordered transposes the values silently.
  expect_identical(
    names(res),
    c("source", "dest", "mask_fraction", "mask_fraction_interior", "threshold",
      "masked", "reason", "success")
  )
})


test_that("the same source listed twice is masked, not refused as a collision", {
  skip_if_no_terra()
  f <- bordered_image(tempfile(fileext = ".tif"))

  # `duplicated(outs)` is a PROXY for "two different sources land on one destination". It
  # also fires on one file listed twice, which is not a collision, has an obvious right
  # answer, and would be refused with advice to "mask them into separate directories"
  # when there is only one file. `fly_fetch()$dest` can repeat, so this is reachable.
  out <- suppressMessages(fly_mask(c(f$path, f$path), dest_dir = tempfile()))
  expect_equal(nrow(out), 2L)
  expect_true(all(out$masked))
  expect_true(all(out$success))
  expect_identical(out$dest[1], out$dest[2])

  # The second row takes the resume branch, so it reports NA rather than claiming a
  # threshold it did not apply.
  expect_false(is.na(out$mask_fraction[1]))
  expect_true(is.na(out$threshold[2]))
})


test_that("refusals are named in the summary, not left only in the tibble", {
  skip_if_no_terra()
  d <- tempfile()
  dir.create(d)
  good <- bordered_image(file.path(d, "good.tif"))
  wide <- file.path(d, "wide.tif")
  terra::writeRaster(terra::rast(nrows = 40, ncols = 40, vals = 5000L), wide,
                     datatype = "INT2U", overwrite = TRUE, NAflag = NA)

  # Only two of the seven refusal paths warn on their own. Without the summary carrying
  # the rest, a batch that declined half its frames looks the same as one that masked
  # them all unless the caller inspects the tibble. fly#30: report what was excluded.
  msg <- testthat::capture_messages(fly_mask(c(good$path, wide), dest_dir = tempfile()))
  expect_true(any(grepl("Masked 1 of 2", msg)))
  expect_true(any(grepl("1 not masked", msg)))
  expect_true(any(grepl("not Byte", msg)))
})


test_that("a missing source is reported per file rather than aborting the batch", {
  skip_if_no_terra()
  good <- bordered_image(tempfile(fileext = ".tif"))
  out  <- suppressMessages(
    fly_mask(c(good$path, tempfile(fileext = ".tif")), dest_dir = tempfile())
  )
  expect_equal(nrow(out), 2L)
  expect_equal(out$success, c(TRUE, FALSE))
  expect_match(out$reason[2], "does not exist")
})


test_that("both constants are where the shipped sweep says they should be", {
  sweep_path <- system.file("extdata/mask_border_sweep.csv", package = "fly")
  skip_if(sweep_path == "", "mask_border_sweep.csv is not installed")
  sweep <- utils::read.csv(sweep_path, stringsAsFactors = FALSE)

  # Premise: a truncated table would make every assertion below vacuous, and would do it
  # silently. 264 frames x 10 thresholds.
  expect_gt(nrow(sweep), 2000)
  expect_gt(length(unique(sweep$file)), 200)

  thr <- fly_mask_threshold()
  at  <- sweep[sweep$threshold == thr, ]
  expect_gt(nrow(at), 200)

  # The cap sits above the largest interior fraction any legitimate frame produces at the
  # working threshold — computed against the least favourable member of the population,
  # not a remembered example.
  worst_ok <- max(at$frac_interior, na.rm = TRUE)
  expect_lt(worst_ok, fly_mask_max_interior())

  # ...with real margin on that side. A cap a hair above the worst case is a cap that
  # fires on the next roll.
  expect_gt(fly_mask_max_interior() / worst_ok, 2)

  # ...and real margin on the other side: a runaway must exceed it, or the guard could
  # never fire for any input at all and the constant is decoration.
  runaway <- max(sweep$frac_interior[sweep$threshold == 48], na.rm = TRUE)
  expect_gt(runaway, fly_mask_max_interior())
  expect_gt(runaway / fly_mask_max_interior(), 2)

  # Every figure `inst/notes/border-masking.md` publishes about the guard, recomputed
  # from the artifact it describes. The defect this closes is the one that produced the
  # whole family: a contract written twice, in prose and in code, with nothing binding
  # the copies — an earlier draft of that section published 0.2379 as "the smallest
  # runaway" when it is the MAXIMUM at threshold 48, flattering the margin by 4.7x.
  over_at <- function(thr) {
    x <- sweep$frac_interior[sweep$threshold == thr]
    c(max = max(x, na.rm = TRUE), n_over = sum(x > fly_mask_max_interior(), na.rm = TRUE),
      min_over = suppressWarnings(min(x[x > fly_mask_max_interior()], na.rm = TRUE)))
  }
  # testthat 3e tolerances are RELATIVE, so 2e-2 here means "agrees with the four decimals
  # the note prints", not "within 0.02 of it".
  expect_equal(unname(over_at(16)["max"]), 0.0131, tolerance = 2e-2)
  expect_equal(unname(over_at(16)["n_over"]), 0)
  expect_equal(unname(over_at(32)["max"]), 0.0465, tolerance = 2e-2)
  expect_equal(unname(over_at(32)["n_over"]), 0)
  expect_equal(unname(over_at(48)["n_over"]), 14)
  expect_equal(unname(over_at(48)["min_over"]), 0.0510, tolerance = 2e-2)
  expect_equal(unname(over_at(48)["max"]), 0.2379, tolerance = 2e-2)

  # The published 3.81x margin at the shipped threshold.
  expect_equal(fly_mask_max_interior() / unname(over_at(16)["max"]), 3.81, tolerance = 2e-2)

  # And the coupling: the cap does NOT survive raising the threshold on its own. At 32 it
  # clears the worst legitimate frame by only 1.08x, which is the sentence in the note.
  expect_lt(fly_mask_max_interior() / unname(over_at(32)["max"]), 1.2)

  # The threshold is the per-frame plateau's high quantile. Recomputed here rather than
  # asserted from memory: the first reading of this sweep took a population median of mask
  # fractions and got the shape of the curve backwards.
  plateau <- vapply(split(sweep, sweep$file), function(d) {
    d <- d[order(d$threshold), ]
    if (max(d$frac_total, na.rm = TRUE) < 0.002) return(0L)
    g <- diff(d$frac_total)
    hit <- which(g <= 0.002)
    if (!length(hit)) return(NA_integer_)
    as.integer(d$threshold[hit[1]])
  }, integer(1))
  plateau <- plateau[!is.na(plateau)]
  expect_gte(fly_mask_threshold(), stats::quantile(plateau, 0.99, names = FALSE))
})


test_that("the interior window drops a tenth from each side and never degenerates", {
  expect_equal(fly_interior_srcwin(1000L, 1000L), c(100, 100, 800, 800))
  expect_equal(fly_interior_srcwin(1250L, 1249L), c(125, 124, 1000, 1001))

  # A tiny image must still yield a legal window rather than a zero-size one.
  w <- fly_interior_srcwin(3L, 3L)
  expect_gte(w[3], 1)
  expect_gte(w[4], 1)
})


test_that("fly_gdal_bands() reports zero rather than one when nothing matches", {
  # `gregexpr()` returns -1 for no match, so a naive `length(...[[1]])` reports ONE band
  # for a file with none — an absence that reads as a grayscale image, and would send a
  # bandless input down the grayscale branch.
  expect_equal(fly_gdal_bands("no bands here"), 0L)
  expect_equal(fly_gdal_bands("Band 1 ... Band 2 ..."), 2L)
})
