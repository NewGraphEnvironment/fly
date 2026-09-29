# mask_measure-interior_zeros.R — the two measurements fly#56 asked for before the
# georeference output contract changed.
#
# 1. How much genuine black a grayscale frame loses to `-dstnodata 0`. Until v0.19.0 a
#    grayscale output marked "no data" by the value 0, so any pixel of real content at
#    exactly 0 that survived the frame-border mask came out as nodata or as 1 — either way
#    not the value scanned. Counted on the
#    SOURCE, after `fly_mask_one()`: a pixel that is 0 and still opaque in the masked copy
#    is one the old output deleted. Bilinear resampling can also produce a 0 from a
#    neighbourhood of zeros, so the output-side loss is of the same order but not
#    identical; this is the source-side count and is labelled so. For isotropic pixels (these
#    thumbnails, on square footprints) it is exact for an axis-aligned warp and an upper
#    bound for a rotated one, where bilinear resampling turns a lone 0 among brighter
#    neighbours into a non-zero output. An anisotropic scan resamples even axis-aligned.
# 1b. The same loss measured on the OUTPUT, over the calibration grayscale frames only:
#    each masked frame is warped twice through one GCP VRT, at two bearings — axis-aligned
#    (a frame with no flight bearing) and 30 degrees — once with the pre-fly#56
#    options (`-srcalpha -dstnodata 0`) and once with today's (`-srcalpha -dstalpha`). The
#    two share a grid, so a cell opaque at 0 in the new output that the old one holds as
#    nodata (deleted) or as 1 (rewritten by GDAL to dodge the nodata value) is a true 0 the
#    old contract lost. On sf's GDAL 3.8.5 it is all rewriting and no deletion, and the
#    axis-aligned count equals the source-side count.
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

# The output-side count (1b), at a given bearing. It depends on the bearing, and that is
# the finding rather than a detail: an axis-aligned warp (every frame with no flight
# bearing) of an isotropic frame lands output cells on source pixels, so bilinear
# resampling reproduces every value and every opaque 0 is lost; a rotated warp mixes neighbours and loses fewer. An
# earlier run measured 30 degrees only and was quoted as the loss. Sized so an output cell
# is about one source pixel.
measure_output <- function(src, bearing) {
  threshold <- fly_mask_threshold()
  masked <- tempfile(fileext = ".tif")
  vrt <- tempfile(fileext = ".vrt")
  old <- tempfile(fileext = ".tif")
  new <- tempfile(fileext = ".tif")
  on.exit(unlink(c(masked, vrt, old, new)), add = TRUE)
  row <- suppressWarnings(fly_mask_one(src, masked, threshold))
  if (!isTRUE(row$masked)) {
    return(data.frame(file = basename(src), lost_out = NA_real_, shifted_out = NA_real_,
                      frame_out = NA_real_, zero_new = NA_real_, error = NA_character_))
  }

  dm <- fly_gdal_dim(fly_gdal_info(src))
  ring <- fly_rectangles(matrix(c(1.2e6, 9e5), ncol = 2), dm[1] / 2, dm[2] / 2, bearing = bearing)
  gcp <- fly_georef_gcps(dm[1], dm[2], sf::st_coordinates(ring)[1:4, 1:2, drop = FALSE], 0)
  gcp_args <- unlist(lapply(seq_len(nrow(gcp)), function(j) c("-gcp", unname(gcp[j, ]))))
  sf::gdal_utils("translate", source = masked, destination = vrt,
                 options = c("-of", "VRT", "-a_srs", "EPSG:3005", gcp_args))
  base_opts <- c("-t_srs", "EPSG:3005", "-r", "bilinear", "-srcalpha")
  sf::gdal_utils("warp", source = vrt, destination = old,
                 options = c(base_opts, "-dstnodata", "0"))
  sf::gdal_utils("warp", source = vrt, destination = new,
                 options = fly_georef_warp_opts(1L, NULL, masked = TRUE))

  o <- terra::values(suppressWarnings(terra::rast(old)), mat = FALSE)
  n <- terra::values(suppressWarnings(terra::rast(new)), mat = TRUE)
  inside <- n[, 2] == 255
  # Two ways the old output could lose a true 0, counted separately. Nodata inside the
  # frame is deletion. A 1 where today's output holds 0 is GDAL moving a real value off
  # the nodata value rather than let it read as fill — silent on sf's GDAL 3.8.5, and the
  # "Value 0 ... changed to 1" message fly#68 saw printed on the Windows runner.
  zero_new <- inside & n[, 1] == 0
  data.frame(file = basename(src), lost_out = sum(is.na(o) & inside),
             shifted_out = sum(zero_new & !is.na(o) & o == 1),
             frame_out = sum(inside), zero_new = sum(zero_new), error = NA_character_)
}

# PSOCK, not fork: see CLAUDE.md on mclapply and GDAL. Every use of the cluster sits inside
# one `finally`, so an error anywhere leaves no detached workers behind.
cl <- parallel::makePSOCKcluster(workers)
bearings <- c(NA, 30)
run <- tryCatch({
  invisible(parallel::clusterEvalQ(cl, pkgload::load_all(quiet = TRUE)))
  # A closure defined here is not on the workers; without this every frame "errors" and
  # the report prints zeros that read as a measurement.
  parallel::clusterExport(cl, c("measure_one", "measure_output"))
  res <- do.call(rbind, parallel::parLapplyLB(cl, files, function(f) {
    tryCatch(measure_one(f), error = function(e) {
      data.frame(file = basename(f), year = basename(dirname(f)), bands = NA_integer_,
                 masked = NA, reason = paste("error:", conditionMessage(e)),
                 n_px = NA_real_, zero_src = NA_real_, zero_kept = NA_real_)
    })
  }))
  # Checked before the output pass: a frame that errored here would otherwise drop out of
  # the calibration set below without a word, and a doomed run would still do the warps.
  n_err <- sum(grepl("^error:", res$reason))
  if (n_err > 0) {
    print(utils::head(unique(res$reason[grepl("^error:", res$reason)])))
    stop(n_err, " of ", nrow(res), " frames errored; refusing to report a partial measurement.")
  }
  res$calibration <- res$file %in% calib

  gray_calib <- files[basename(files) %in% res$file[res$calibration & res$bands %in% 1L]]
  out_side <- lapply(bearings, function(b) {
    do.call(rbind, parallel::parLapplyLB(cl, gray_calib, function(f, b) {
      tryCatch(measure_output(f, b), error = function(e) {
        data.frame(file = basename(f), lost_out = NA_real_, shifted_out = NA_real_,
                   frame_out = NA_real_, zero_new = NA_real_,
                   error = conditionMessage(e))
      })
    }, b = b))
  })
  list(res = res, out_side = out_side)
}, finally = parallel::stopCluster(cl))
res <- run$res
out_side <- run$out_side
names(out_side) <- ifelse(is.na(bearings), "axis-aligned", paste(bearings, "degrees"))
out_err <- unlist(lapply(out_side, function(d) if ("error" %in% names(d)) d$error[!is.na(d$error)]))
if (length(out_err)) {
  print(utils::head(unique(out_err)))
  stop(length(out_err), " output-side warps errored; refusing to report a partial measurement.")
}

dir.create(dirname(out_csv), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(res, out_csv, row.names = FALSE)
message("wrote ", out_csv)

report <- function(d, label) {
  cat("\n== ", label, ": ", nrow(d), " frames ==\n", sep = "")
  cat("errors:", sum(grepl("^error:", d$reason)), "\n")
  cat("bands:\n")
  print(table(d$bands, useNA = "ifany"))
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
for (lab in names(out_side)) {
  g <- out_side[[lab]]
  hit <- g$lost_out + g$shifted_out
  f <- hit / g$frame_out
  cat("\n== output side, calibration grayscale, warp ", lab, ", GDAL ",
      sf::sf_extSoftVersion()[["GDAL"]], " ==\n", sep = "")
  cat("frames measured:", sum(!is.na(hit)), "of", nrow(g), "\n")
  cat("  true 0 deleted (nodata inside the frame): frames", sum(g$lost_out > 0, na.rm = TRUE),
      " pixels", sum(g$lost_out, na.rm = TRUE), "\n")
  cat("  true 0 rewritten as 1: frames", sum(g$shifted_out > 0, na.rm = TRUE),
      " pixels", sum(g$shifted_out, na.rm = TRUE), "\n")
  cat("  every opaque 0 today accounted for by one of the two:",
      isTRUE(all(g$zero_new == hit, na.rm = TRUE)), "\n")
  cat("  affected share of frame, over affected frames: median",
      signif(stats::median(f[hit > 0], na.rm = TRUE), 3), " max", signif(max(f, na.rm = TRUE), 3),
      " above 0.1%:", sum(f > 0.001, na.rm = TRUE), "\n")
  cat("  median affected pixels over affected frames:", stats::median(hit[hit > 0], na.rm = TRUE), "\n")
  top <- g[order(-f), c("file", "lost_out", "shifted_out", "frame_out")]
  top$share <- signif((top$lost_out + top$shifted_out) / top$frame_out, 3)
  print(utils::head(top, 5), row.names = FALSE)
}
report(res, "directory")
