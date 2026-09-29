# mask_measure-interior_zeros.R — the two measurements fly#56 asked for before the
# georeference output contract changed.
#
# 1. How much genuine black a grayscale frame loses to `-dstnodata 0`. Until v0.19.0 a
#    grayscale output marked "no data" by the value 0, so any pixel of real content at
#    exactly 0 that survived the frame-border mask was written as nodata. Counted on the
#    SOURCE, after `fly_mask_one()`: a pixel that is 0 and still opaque in the masked copy
#    is one the old output deleted. Bilinear resampling can also produce a 0 from a
#    neighbourhood of zeros, so the output-side loss is of the same order but not
#    identical; this is the source-side count and is labelled so.
# 2. How often `fly_mask_one()` declines at the shipped constants. A declined frame is
#    warped unmasked, which is where `srcnodata` as a fallback (fly#69, absorbed into
#    fly#56) does any work.
#
# `inst/extdata/mask_border_sweep.csv` answers neither: it measures the mask's extent,
# not what is left at 0 and not whether `fly_mask_one()` accepted it.
#
# Everything is public: the airphoto thumbnails at openmaps.gov.bc.ca, as fetched by
# `fly_fetch(type = "thumbnail")`. Run over two populations:
#
#   * "calibration" — the 264 frames `mask_border_sweep.csv` was measured on, so the
#     figures share a denominator with every other number in `inst/notes/border-masking.md`
#   * "directory"   — every thumbnail under `thumb_dir` today, which has grown since
#
# Usage:
#   Rscript data-raw/mask_measure-interior_zeros.R <thumb_dir> [out_csv] [workers]
#
# Writes a per-frame CSV (default: data-raw/.cache/mask_interior_zeros.csv, gitignored)
# and prints a producer line for every figure the note and NEWS quote.

pkgload::load_all(quiet = TRUE)

args      <- commandArgs(trailingOnly = TRUE)
thumb_dir <- if (length(args) >= 1) args[[1]] else "~/Projects/repo/stac_airphoto_bc/data/raw/thumbs"
out_csv   <- if (length(args) >= 2) args[[2]] else "data-raw/.cache/mask_interior_zeros.csv"
workers   <- if (length(args) >= 3) as.integer(args[[3]]) else 8L
thumb_dir <- path.expand(thumb_dir)
stopifnot(dir.exists(thumb_dir))

files <- list.files(thumb_dir, pattern = "\\.(jpg|jpeg|tif|tiff)$",
                    full.names = TRUE, recursive = TRUE, ignore.case = TRUE)
message("thumbnails: ", length(files), " under ", thumb_dir)
stopifnot(length(files) > 0)

calib <- unique(utils::read.csv(system.file("extdata", "mask_border_sweep.csv",
                                            package = "fly"))$file)

measure_one <- function(src) {
  threshold <- fly_mask_threshold()
  out <- tempfile(fileext = ".tif")
  on.exit(unlink(out), add = TRUE)
  row <- suppressWarnings(fly_mask_one(src, out, threshold))

  r <- suppressWarnings(terra::rast(src))
  n_bands <- terra::nlyr(r)
  base <- data.frame(file = basename(src), year = basename(dirname(src)),
                     bands = n_bands, masked = isTRUE(row$masked),
                     reason = if (is.na(row$reason)) "" else row$reason,
                     n_px = terra::ncell(r), zero_src = NA_real_, zero_kept = NA_real_,
                     stringsAsFactors = FALSE)
  if (n_bands != 1L) return(base)

  v <- terra::values(r, mat = FALSE)
  zero <- !is.na(v) & v == 0
  base$zero_src <- sum(zero)
  # Declined: the frame is warped unmasked, so under the old contract every source zero
  # became nodata. Masked: only the zeros the mask left opaque are content being lost —
  # zeros inside the masked collar were meant to go.
  base$zero_kept <- if (isTRUE(row$masked) && file.exists(out)) {
    m <- suppressWarnings(terra::rast(out))
    alpha <- terra::values(m[[terra::nlyr(m)]], mat = FALSE)
    sum(zero & alpha == 255)
  } else {
    sum(zero)
  }
  base
}

# PSOCK, not fork: see CLAUDE.md on mclapply and GDAL.
cl <- parallel::makePSOCKcluster(workers)
invisible(parallel::clusterEvalQ(cl, pkgload::load_all(quiet = TRUE)))
# A closure defined here is not on the workers; without this every frame "errors" and the
# report prints zeros that read as a measurement.
parallel::clusterExport(cl, "measure_one")
res <- parallel::parLapplyLB(cl, files, function(f) {
  tryCatch(measure_one(f), error = function(e) {
    data.frame(file = basename(f), year = basename(dirname(f)), bands = NA_integer_,
               masked = NA, reason = paste("error:", conditionMessage(e)),
               n_px = NA_real_, zero_src = NA_real_, zero_kept = NA_real_)
  })
})
parallel::stopCluster(cl)
res <- do.call(rbind, res)
res$calibration <- res$file %in% calib
n_err <- sum(grepl("^error:", res$reason))
if (n_err > 0) {
  print(utils::head(unique(res$reason[grepl("^error:", res$reason)])))
  stop(n_err, " of ", nrow(res), " frames errored; refusing to report a partial measurement.")
}

dir.create(dirname(out_csv), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(res, out_csv, row.names = FALSE)
message("wrote ", out_csv)

report <- function(d, label) {
  cat("\n== ", label, ": ", nrow(d), " frames ==\n", sep = "")
  cat("errors:", sum(grepl("^error:", d$reason)), "\n")
  cat("bands:\n"); print(table(d$bands, useNA = "ifany"))
  cat("mask declined:", sum(d$masked %in% FALSE), "of", sum(!is.na(d$masked)), "\n")
  if (any(d$masked %in% FALSE)) print(table(d$reason[d$masked %in% FALSE]))
  g <- d[d$bands %in% 1L, ]
  frac <- g$zero_kept / g$n_px
  cat("grayscale frames:", nrow(g), "\n")
  cat("  with any source pixel at exactly 0:", sum(g$zero_src > 0), "\n")
  cat("  with a 0 the mask left opaque (lost to -dstnodata 0):", sum(g$zero_kept > 0), "\n")
  cat("  lost fraction of frame, over those frames: median",
      signif(stats::median(frac[g$zero_kept > 0]), 3), " max", signif(max(frac), 3), "\n")
  cat("  lost pixels, over all grayscale frames: total", sum(g$zero_kept),
      " frames above 0.1%:", sum(frac > 0.001), "\n")
}

report(res[res$calibration, ], "calibration (mask_border_sweep.csv)")
report(res, "directory")
