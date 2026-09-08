#' Mask the black frame border of an airphoto scan
#'
#' Scanned airphotos carry a black collar — film holder edges, fiducial marks, chamfered
#' corners, scanner overrun — outside the exposed frame. Left in place it covers adjacent
#' photos in a mosaic. `fly_mask()` writes a copy of each image with an **alpha band**
#' marking that collar transparent, leaving every pixel inside the frame untouched.
#'
#' @param src Character vector of image paths.
#' @param dest_dir Directory for the masked copies. Created if it does not exist.
#' @param threshold How close to black a pixel must be to count as collar, as a
#'   per-band distance from 0. Defaults to **16**, which is measured rather than chosen —
#'   see **Threshold** below. The default is written as a call so that the shipped value
#'   and the calibrated constant cannot drift apart; there is only one of them.
#' @param overwrite If `FALSE` (default), skip images whose masked copy already exists.
#' @return A tibble with one row per input:
#'   \describe{
#'     \item{`source`}{the input path}
#'     \item{`dest`}{the masked copy, or `NA` where none was written}
#'     \item{`mask_fraction`}{share of the frame the mask covers. `NA` wherever no mask
#'       was computed — a resumed row, or any refusal reached before the measurement}
#'     \item{`mask_fraction_interior`}{share of the central box the mask covers — the
#'       quantity the runaway guard tests. `NA` on the same rows as `mask_fraction`}
#'     \item{`threshold`}{the threshold requested for this image. `NA` on a *resumed*
#'       row, whose file was written on an earlier run at a threshold this call did not
#'       measure and must not claim}
#'     \item{`masked`}{whether a masked copy was written}
#'     \item{`reason`}{why the row is what it is. `NA` only for an ordinary freshly
#'       masked image — a *resumed* row carries a reason with `masked = TRUE`, so
#'       partition on `masked`, never on `is.na(reason)`}
#'     \item{`success`}{whether the call reached a definite conclusion about this image.
#'       A reasoned refusal — a non-Byte source, a colliding destination, a mask that
#'       exceeds the interior cap or could not be measured — is `TRUE`: the function did
#'       its job and declined. `FALSE` means something stopped it from concluding at all:
#'       the file is missing or unreadable, GDAL errored, or the copy could not be
#'       written}
#'   }
#'
#' @details
#' **The collar is edge-connected, not a shape.** The mask is a flood fill seeded from the
#' image border (GDAL `nearblack -alg floodfill`), so only darkness *reachable from the
#' edge* is masked. A dark lake or deep shadow inside the frame is kept, which is the
#' whole point: a plain threshold masks it too. Measured on 1990 roll bcb90128 frame 213,
#' a plain threshold masks 7.7% of the frame and this masks 2.5% — the missing 5% is
#' water.
#'
#' It is **not** a circle. fly#23 proposed detecting a circular lens boundary; measured
#' over 264 thumbnails spanning 1967-2018, the dark region's median area is 2.7% where an
#' inscribed circle implies 21.5%, and the middles of the image edges are as dark as the
#' corners, which a circle cannot produce. See `inst/notes/border-masking.md`.
#'
#' **Threshold:** scanned black is not 0. On these JPEGs it runs 3-12, so the exact-zero
#' matching `fly_georef()` used before v0.11.0 masked a median of **0.16%** of the frame
#' against the **3.11%** a threshold of 16 reaches — a 19.8x gap. (Both are mask
#' fractions from `mask_border_sweep.csv`. The 2.7% quoted above is the *raw dark*
#' fraction, a different measurement, and the two must not be compared.)
#'
#' The default is set from the per-frame threshold at which a frame's own collar is fully
#' consumed, taken across the measured population; `inst/notes/border-masking.md` carries
#' the distribution. It assumes **Byte** bands, and a source that is not Byte is refused
#' rather than reported as having no collar — `-near` is an absolute per-band distance, so
#' the number does not transfer to a 16-bit scan.
#'
#' **The runaway guard.** A threshold high enough to reach scene content floods inward and
#' the mask stops being a collar. Because a genuine collar hugs the border, it contributes
#' almost nothing to a central box — so the guard tests the **interior** fraction, not the
#' total, which cannot tell a thick collar from a lake running off the edge. When it
#' trips, the image is left unmasked with a warning rather than skipped: an unmasked frame
#' shows a black border, which is visible and is what callers already live with, while an
#' over-eager mask deletes real imagery transparently and nothing downstream reports it.
#'
#' A mask fraction of **zero is not a warning**. 27 of the 264 measured frames carry no
#' collar at all, digital frames among them, and for those an empty mask is the right
#' answer.
#'
#' @examples
#' centroids <- sf::st_read(system.file("testdata/photo_centroids.gpkg", package = "fly"))
#'
#' fetched <- fly_fetch(centroids[1, ], type = "thumbnail", dest_dir = tempdir())
#' masked <- fly_mask(fetched$dest[fetched$success], dest_dir = tempdir())
#' masked[, c("mask_fraction", "mask_fraction_interior", "masked")]
#'
#' @export
fly_mask <- function(src, dest_dir = "masked", threshold = fly_mask_threshold(),
                     overwrite = FALSE) {
  if (!is.character(src)) {
    stop("`src` must be a character vector of image paths, not ", class(src)[1], ".",
         call. = FALSE)
  }
  # Assign the RETURN VALUE. `fly_check_threshold()` converts through `as.character()`
  # because `as.integer()` on a factor yields its level code; discarding the result and
  # passing the raw argument on reinstates exactly the bug the conversion exists to
  # prevent — `factor("16")` would validate as 16 and run GDAL at `-near 1`, masking
  # nothing and reporting `masked = TRUE` with a fraction of 0, which this function
  # documents as the legitimate no-collar answer. One parse, one value.
  threshold <- fly_check_threshold(threshold)

  # Zero-length input must still return the documented shape. `do.call(rbind, list())` is
  # NULL, and the roxygen example reaches this whenever no thumbnail downloaded.
  if (!length(src)) {
    return(fly_mask_row(character(0), character(0), numeric(0), numeric(0),
                        integer(0), logical(0), character(0), logical(0)))
  }

  dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)

  # Output paths are derived from `basename()`, so two sources in different directories
  # with the same filename collapse onto one destination — and the second row would then
  # report `masked = TRUE` while pointing at the FIRST frame's pixels. Refused for the
  # whole batch rather than silently resolved, because there is no safe resolution: with
  # `overwrite = FALSE` the loser gets the winner's image, and with `overwrite = TRUE`
  # the winner's `dest` ends up holding the loser's.
  # A collision is TWO DIFFERENT sources landing on one destination. `duplicated(outs)`
  # alone is a proxy for that and catches the same file listed twice as well — which is
  # not a collision, has an obvious right answer (mask it once), and would otherwise
  # refuse both rows while advising the caller to "mask them into separate directories"
  # when there is only one file. `fly_fetch()$dest` can repeat, so this is reachable.
  # Counted on DISTINCT normalized sources per destination instead.
  outs  <- fly_mask_dest(src, dest_dir)
  keys  <- suppressWarnings(normalizePath(src, winslash = "/", mustWork = FALSE))
  n_src <- stats::ave(keys, outs, FUN = function(k) length(unique(k)))
  dup   <- as.integer(n_src) > 1L

  # Colliding ROWS are refused, never the batch: fly#30 and #47 settled that a frame fly
  # cannot handle is reported rather than allowed to take the other frames with it.

  rows <- lapply(seq_along(src), function(i) {
    s   <- src[[i]]
    out <- outs[[i]]

    # Defence in depth against an output landing on its own input. Currently unreachable,
    # because `fly_mask_dest()` always appends `_masked.tif` so no name can map to itself
    # — but the ORIGINAL destination rule did map an extensionless name to itself, and a
    # change to that rule would reinstate an in-place overwrite of the source, which is
    # irrecoverable and for licensed full-resolution imagery is the whole asset. Resolved
    # paths, so a relative `dest_dir` cannot slip past it. `test-fly_mask.R` asserts both
    # halves: that the branch cannot fire today, and that the predicate still works.
    #
    # (The collision branch immediately above is live and tested. This note is about THIS
    # branch only — do not read "unreachable" as covering both.)
    if (dup[[i]]) {
      return(fly_mask_row(s, NA_character_, NA_real_, NA_real_, threshold, FALSE,
                          paste0("destination collides with another source named ",
                                 basename(s), "; mask them into separate directories"),
                          TRUE))
    }

    if (file.exists(s) && fly_same_path(s, out)) {
      return(fly_mask_row(s, NA_character_, NA_real_, NA_real_, threshold, FALSE,
                          "destination is the source file", TRUE))
    }

    if (!overwrite && file.exists(out) && file.size(out) > 0) {
      # The file on disk may have been written on an earlier run at a different
      # threshold, and nothing here re-reads it. Reporting the REQUESTED threshold would
      # label it with a number it may not carry, so the column is NA and the reason says
      # the row is a resume — "masked at 16" and "a file existed and I did not look at
      # it" must stay distinguishable.
      return(fly_mask_row(s, out, NA_real_, NA_real_, NA_integer_, TRUE,
                          "existing file kept; pass overwrite = TRUE to remask", TRUE))
    }
    if (!file.exists(s)) {
      return(fly_mask_row(s, NA_character_, NA_real_, NA_real_, threshold, FALSE,
                          "source does not exist", FALSE))
    }
    tryCatch(
      fly_mask_one(s, out, threshold),
      error = function(e) {
        message("Failed to mask ", basename(s), ": ", conditionMessage(e))
        fly_mask_row(s, NA_character_, NA_real_, NA_real_, threshold, FALSE,
                     conditionMessage(e), FALSE)
      }
    )
  })

  results <- do.call(rbind, rows)

  # Two of the refusal paths warn on their own; the others would otherwise be visible
  # only to a caller who inspects the tibble. fly#30 settled that a frame fly declines to
  # handle gets reported, so the count and its reasons go in the summary line.
  declined <- !results$masked
  message(
    "Masked ", sum(results$masked), " of ", nrow(results), " images",
    if (any(declined)) {
      paste0(" (", sum(declined), " not masked: ",
             paste(sort(unique(sub(";.*$", "", results$reason[declined]))), collapse = "; "),
             ")")
    }
  )
  results
}

#' One row of the `fly_mask()` result, built in one place
#'
#' Every exit from `fly_mask()` returns the same eight columns in the same order. Built
#' here rather than at each `return()` so a column added later cannot reach some paths and
#' not others — `rbind()` on frames with differing names errors, but on frames with the
#' same names in a different order it silently transposes the values.
#' @noRd
fly_mask_row <- function(source, dest, frac, frac_interior, threshold,
                         masked, reason, success) {
  dplyr::tibble(
    source                 = source,
    dest                   = dest,
    mask_fraction          = as.numeric(frac),
    mask_fraction_interior = as.numeric(frac_interior),
    threshold              = as.integer(threshold),
    masked                 = masked,
    reason                 = reason,
    success                = success
  )
}

#' Mask one image
#' @noRd
fly_mask_one <- function(src, out, threshold, max_interior = fly_mask_max_interior()) {
  info <- fly_gdal_info(src)
  dm   <- fly_gdal_dim(info)
  if (is.null(dm)) {
    return(fly_mask_row(src, NA_character_, NA_real_, NA_real_, threshold, FALSE,
                        "could not read image dimensions", FALSE))
  }

  # `-near` is an ABSOLUTE per-band distance from 0, so on a 16-bit scan a threshold
  # calibrated on Byte imagery reaches essentially nothing. The result would be
  # `mask_fraction` about 0 with `masked = TRUE` — which this function documents as the
  # correct answer for a frame that has no collar. Two states, one representation, and
  # the wrong one is silent. Refused instead, as `fly_footprint()` refuses a recording
  # format it cannot resolve.
  # `regmatches()` yields character(0) when nothing matches, so `length(types) && ...`
  # short-circuits to FALSE and masks an image whose type could not be read — the same
  # fail-toward-pass the interior guard below refuses. An unknown type is refused, not
  # assumed to be Byte.
  types <- unique(sub("^Type=", "", regmatches(info, gregexpr("Type=\\w+", info))[[1]]))
  if (!length(types) || !all(types == "Byte")) {
    return(fly_mask_row(src, NA_character_, NA_real_, NA_real_, threshold, FALSE,
                        if (!length(types)) {
                          "band type could not be read; the threshold needs 8-bit imagery"
                        } else {
                          paste0("band type is ", paste(types, collapse = "/"),
                                 ", not Byte; the threshold is calibrated on 8-bit imagery")
                        },
                        TRUE))
  }

  # Written to a temp file first. The guard below may decline the mask, and a declined
  # mask must leave nothing at `out` — a half-written masked copy sitting where a caller
  # expects either a good one or none is worse than either.
  tmp <- tempfile(fileext = ".tif")
  on.exit(unlink(tmp), add = TRUE)

  sf::gdal_utils(
    "nearblack",
    source      = src,
    destination = tmp,
    options     = c("-alg", "floodfill", "-near", as.character(as.integer(threshold)),
                    "-setalpha", "-of", "GTiff")
  )
  if (!file.exists(tmp)) {
    return(fly_mask_row(src, NA_character_, NA_real_, NA_real_, threshold, FALSE,
                        "nearblack wrote no output", FALSE))
  }

  alpha_band <- fly_gdal_bands(fly_gdal_info(tmp))
  frac       <- fly_alpha_fraction(tmp, alpha_band)
  frac_in    <- fly_alpha_fraction(tmp, alpha_band, srcwin = fly_interior_srcwin(dm[1], dm[2]))

  # An unmeasurable mask is not a verified one. `is.finite()` guarding the comparison below
  # would silently skip the guard when the statistics could not be read, and write the mask
  # anyway - a guard failing toward pass on the one branch that exists to catch a flood.
  # Refused here instead, with its own reason so "could not measure" stays distinguishable
  # from "measured and too large".
  if (!is.finite(frac_in)) {
    warning(
      basename(src), ": could not measure how much of the frame's interior the mask ",
      "covers, so it cannot be checked against the ", round(max_interior * 100, 1),
      "% a frame border can account for. Left unmasked rather than written unverified. ",
      "See `inst/notes/border-masking.md`.",
      call. = FALSE
    )
    return(fly_mask_row(src, NA_character_, frac, frac_in, threshold, FALSE,
                        "interior mask fraction could not be measured", TRUE))
  }

  # The runaway guard. Tested on the INTERIOR fraction: a collar hugs the border, so it
  # contributes almost nothing here, while a flood into scene content necessarily does.
  # Total area cannot make that distinction - a thick collar and a lake running off the
  # edge occupy the same share of the frame.
  if (frac_in > max_interior) {
    warning(
      basename(src), ": the mask covers ", round(frac_in * 100, 1), "% of the frame's ",
      "interior (", round(frac * 100, 1), "% overall) at threshold ", threshold,
      ", above the ", round(max_interior * 100, 1), "% a frame border can account for. ",
      "That is a flood into the image, not a collar. Left unmasked — lower ",
      "`threshold`, or accept the border. See `inst/notes/border-masking.md`.",
      call. = FALSE
    )
    return(fly_mask_row(src, NA_character_, frac, frac_in, threshold, FALSE,
                        "mask exceeded the interior cap", TRUE))
  }

  # `file.rename()` returns FALSE rather than erroring, and this is the one destructive
  # step - everything above it aborts safely. An unchecked rename reports a mask that was
  # never written. See `code-check.md`, floodplains#83.
  if (!file.rename(tmp, out)) {
    if (!file.copy(tmp, out, overwrite = TRUE)) {
      return(fly_mask_row(src, NA_character_, frac, frac_in, threshold, FALSE,
                          "could not write the masked copy", FALSE))
    }
  }

  fly_mask_row(src, out, frac, frac_in, threshold, TRUE, NA_character_, TRUE)
}

#' Where a masked copy of each source goes
#'
#' Derived from the file name, and deliberately NOT injective: `scan` and `scan.tif` both
#' map to `scan_masked.tif`. `fly_mask()` refuses the colliding ROWS — never the batch —
#' rather than letting one frame be handed another's pixels. Split out so the collision
#' check and the per-file loop cannot compute the destination differently.
#' @noRd
fly_mask_dest <- function(src, dest_dir) {
  file.path(dest_dir, paste0(sub("\\.[^./]+$", "", basename(src)), "_masked.tif"))
}

#' Do two paths name the same file?
#'
#' `normalizePath()` warns and returns its input unchanged for a path that does not exist,
#' which is the ordinary case for the destination. Suppressed and compared on whatever it
#' could resolve, which is enough: the case being caught is an output landing exactly on
#' its own input.
#' @noRd
fly_same_path <- function(a, b) {
  norm <- function(x) suppressWarnings(normalizePath(x, winslash = "/", mustWork = FALSE))
  identical(norm(a), norm(b))
}

#' Validate a mask threshold
#'
#' Separate from the body so the `fly_georef()` wiring can reuse it rather than growing a
#' second opinion about what a legal threshold is. Nothing else calls it yet.
#' @noRd
fly_check_threshold <- function(threshold, arg = "threshold") {
  # `as.character()` first: `as.integer()` on a factor returns its LEVEL CODE, so a
  # threshold read from a CSV as a factor would validate as one number and be applied as
  # another. Same trap `fly_georef()` guards on the `rotation` column.
  raw <- as.character(threshold)
  num <- suppressWarnings(as.numeric(raw))
  val <- suppressWarnings(as.integer(raw))
  # `as.integer("16.7")` is 16 — it TRUNCATES rather than refusing, so a fractional value
  # would pass a guard watching for NA and then run at a threshold nobody asked for.
  # Compared against `round()` so the truncation is caught by value.
  fractional <- length(num) == 1L && !is.na(num) && num != round(num)
  if (length(val) != 1L || is.na(val) || fractional || val < 0L || val > 255L) {
    stop("`", arg, "` must be a single whole number between 0 and 255. Got: ",
         paste(raw, collapse = ", "), ".", call. = FALSE)
  }
  invisible(val)
}

#' The central box, as a GDAL `-srcwin`
#'
#' Ten percent dropped from each side, generously rather than tightly: a thick collar on a
#' full-resolution scan must not intrude on the window and read as interior. `-srcwin`
#' takes `xoff yoff xsize ysize`.
#' @noRd
fly_interior_srcwin <- function(nc, nr, drop = 0.10) {
  xo <- floor(nc * drop)
  yo <- floor(nr * drop)
  c(xo, yo, max(1L, nc - 2L * xo), max(1L, nr - 2L * yo))
}

#' Masked share of a band, from GDAL's statistics rather than from its pixels
#'
#' Alpha is 255 where a pixel is kept and 0 where it is masked, so the masked share is
#' `1 - mean/255`. Read through a VRT so no pixels enter R — at full resolution
#' (9600 x 9000) reading the band is not an option.
#'
#' PAM is disabled so `-stats` leaves no `.aux.xml` sidecar beside the dataset. A sidecar
#' would also make a second call read cached statistics rather than recompute them.
#' @noRd
fly_alpha_fraction <- function(path, band, srcwin = NULL) {
  vrt  <- tempfile(fileext = ".vrt")
  on.exit(unlink(c(vrt, paste0(vrt, ".aux.xml"))), add = TRUE)

  opts <- c("-of", "VRT", "-b", as.character(band))
  if (!is.null(srcwin)) opts <- c(opts, "-srcwin", as.character(srcwin))
  sf::gdal_utils("translate", source = path, destination = vrt, options = opts)

  info <- sf::gdal_utils("info", source = vrt, options = "-stats", quiet = TRUE,
                         config_options = c(GDAL_PAM_ENABLED = "NO"))
  m <- regmatches(info, regexpr("STATISTICS_MEAN=[-0-9.eE+]+", info))
  if (!length(m)) return(NA_real_)
  1 - as.numeric(sub("STATISTICS_MEAN=", "", m)) / 255
}

#' GDAL info, and the two facts read out of it
#'
#' One parse per fact, in one place. `gregexpr()` returns `-1` rather than an empty match
#' when nothing matches, so a naive `length(...[[1]])` reports **one** band for a file
#' with none — an absence that reads as a grayscale image.
#' @noRd
fly_gdal_info <- function(path) sf::gdal_utils("info", source = path, quiet = TRUE)

#' @noRd
fly_gdal_bands <- function(info) {
  m <- gregexpr("Band \\d+", info)[[1]]
  if (length(m) == 1L && m[[1]] == -1L) return(0L)
  length(m)
}

#' @noRd
fly_gdal_dim <- function(info) {
  d <- regmatches(info, regexpr("Size is \\d+, \\d+", info))
  if (!length(d)) return(NULL)
  as.integer(strsplit(sub("Size is ", "", d), ", ")[[1]])
}

#' The threshold at which a frame's black collar is fully consumed
#'
#' Set from the per-frame plateau across the measured population, not from the population
#' median of mask fractions — a median of fractions cannot tell a fully-removed collar
#' from a small one, because it moves for both reasons at once.
#'
#' Reproduce with `data-raw/mask_calibrate-border_threshold.R`. See
#' `inst/notes/border-masking.md` for the distribution and the conservatism argument that
#' breaks the tie: under-masking leaves a visible black border, which self-reports;
#' over-masking punches a transparent hole in real imagery, which does not.
#' @noRd
fly_mask_threshold <- function() 16L

#' How much of a frame's interior a border mask may cover before it is refused
#'
#' Above the largest interior fraction any legitimate frame produces at
#' `fly_mask_threshold()`: measured over 264 thumbnails that maximum is **0.0131**, so
#' 0.05 clears it by 3.81x and **no frame in the population can trip the guard** at the
#' shipped threshold. Only a synthesized fixture reaches it.
#'
#' **This constant is coupled to `fly_mask_threshold()` and does not survive raising it
#' alone.** The worst legitimate interior fraction climbs with the threshold — 0.0131 at
#' 16, 0.0160 at 24, **0.0465 at 32** — so at 32 the cap clears it by 1.08x, and by 48 it
#' is 14 of 264 frames over the cap. An earlier draft of the note quoted an admissible
#' band of (0.0131, 0.2379); 0.2379 is the *maximum* interior fraction at threshold 48,
#' not the smallest value that trips the cap there, which is 0.0510. Re-measure both
#' constants together, from `inst/extdata/mask_border_sweep.csv`, or not at all.
#' @noRd
fly_mask_max_interior <- function() 0.05
