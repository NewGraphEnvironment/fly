# mask_calibrate-border_threshold.R — establish the frame-border mask threshold and the
# runaway guard's cap, and falsify the circular-boundary premise of fly#23.
#
# Everything here is public: the airphoto thumbnails at openmaps.gov.bc.ca, fetched by
# `fly_fetch(type = "thumbnail")`. No licence-restricted imagery is used or needed. The
# full-resolution scans fly#23 is nominally about are NOT reachable from this package —
# the catalogue centroid layer carries no URL for them — so nothing here speaks to them.
#
# Usage: source interactively, or
#   Rscript data-raw/mask_calibrate-border_threshold.R <thumb_dir> [out_csv]
#
# `thumb_dir` is a directory of downloaded thumbnails, searched recursively. The
# measurements in `inst/notes/border-masking.md` were taken over the 264 JPEGs in
# `stac_airphoto_bc/data/raw/thumbs`, years 1967-2018.
#
# Writes `inst/extdata/mask_border_sweep.csv` — the per-frame sweep the test suite reads,
# so that both constants are checkable inside the package rather than remembered. See
# `inst/notes/border-masking.md` before changing anything here.

# `pkgload::load_all()` unconditionally, never `requireNamespace()`: a generation script
# operates on the source tree by definition, and `requireNamespace()` succeeds against
# whatever version happens to be installed.
pkgload::load_all(quiet = TRUE)

args      <- commandArgs(trailingOnly = TRUE)
thumb_dir <- if (length(args) >= 1) args[[1]] else "~/Projects/repo/stac_airphoto_bc/data/raw/thumbs"
out_csv   <- if (length(args) >= 2) args[[2]] else "inst/extdata/mask_border_sweep.csv"
thumb_dir <- path.expand(thumb_dir)

stopifnot(dir.exists(thumb_dir))

files <- list.files(thumb_dir, pattern = "\\.(jpg|jpeg|tif|tiff)$",
                    full.names = TRUE, recursive = TRUE, ignore.case = TRUE)
message("thumbnails: ", length(files), " under ", thumb_dir)
stopifnot(length(files) > 0)

THRESHOLDS <- c(0L, 4L, 8L, 12L, 16L, 20L, 24L, 32L, 48L, 64L)

work <- file.path(tempdir(), "fly23")
dir.create(work, recursive = TRUE, showWarnings = FALSE)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# The masked source, as `fly_mask()` will build it: nearblack seeds a flood fill from the
# image border, so only dark that is CONNECTED to the edge is masked. `-setalpha` appends
# the 0/255 band. Everything downstream reads that band and nothing else.
nearblack_alpha <- function(src, near, dest, alg = "floodfill") {
  sf::gdal_utils(
    "nearblack",
    source      = src,
    destination = dest,
    options     = c("-alg", alg, "-near", as.character(near), "-setalpha", "-of", "GTiff")
  )
  dest
}

n_bands <- function(path) {
  info <- sf::gdal_utils("info", source = path, quiet = TRUE)
  length(gregexpr("Band \\d+", info)[[1]])
}

# Mask fraction from GDAL's own statistics rather than by reading pixels into R. This is
# the path `fly_mask()` uses, so it is measured here rather than assumed: at full
# resolution (9600 x 9000) reading the band into R is not an option.
#
# PAM is disabled so `-stats` does not drop a `.aux.xml` sidecar beside the dataset — see
# `code-check-spatial.md`, "terra metags(): the empty case is NULL, and the sidecar is
# half the artefact". A sidecar here would also make a second run read cached statistics
# rather than recompute them.
alpha_fraction <- function(path, band = n_bands(path), srcwin = NULL) {
  vrt  <- tempfile(tmpdir = work, fileext = ".vrt")
  opts <- c("-of", "VRT", "-b", as.character(band))
  if (!is.null(srcwin)) opts <- c(opts, "-srcwin", as.character(srcwin))
  sf::gdal_utils("translate", source = path, destination = vrt, options = opts)
  info <- sf::gdal_utils("info", source = vrt, options = "-stats", quiet = TRUE,
                         config_options = c(GDAL_PAM_ENABLED = "NO"))
  unlink(c(vrt, paste0(vrt, ".aux.xml")))
  m <- regmatches(info, regexpr("STATISTICS_MEAN=[-0-9.eE+]+", info))
  if (!length(m)) return(NA_real_)
  # alpha is 255 where the pixel is kept and 0 where it is masked
  1 - as.numeric(sub("STATISTICS_MEAN=", "", m)) / 255
}

img_dim <- function(path) {
  info <- sf::gdal_utils("info", source = path, quiet = TRUE)
  d <- regmatches(info, regexpr("Size is \\d+, \\d+", info))
  as.integer(strsplit(sub("Size is ", "", d), ", ")[[1]])
}

# The central box, 10% dropped from each side. Generous rather than tight, so that a
# thick border on a full-resolution scan does not intrude on the window and read as
# interior. `-srcwin` takes xoff yoff xsize ysize.
interior_srcwin <- function(nc, nr, drop = 0.10) {
  xo <- floor(nc * drop); yo <- floor(nr * drop)
  c(xo, yo, nc - 2 * xo, nr - 2 * yo)
}

# The terra prototype the GDAL route has to agree with: threshold, 8-connected
# components, keep only those touching the image edge. Kept in this script and NOT in the
# package — it is the control, and shipping it would put terra on the default code path.
terra_edge_connected <- function(src, thr) {
  a <- terra::as.array(suppressWarnings(terra::rast(src)))
  m <- if (dim(a)[3] > 1) apply(a, c(1, 2), max) else a[, , 1]
  dark <- m <= thr
  if (!any(dark)) return(0)
  r <- terra::rast(nrows = nrow(m), ncols = ncol(m))
  terra::values(r) <- as.integer(t(dark))
  r[r == 0] <- NA
  pt  <- terra::patches(r, directions = 8, zeroAsNA = TRUE)
  v   <- matrix(terra::values(pt), nrow = nrow(m), byrow = TRUE)
  ids <- unique(c(v[1, ], v[nrow(v), ], v[, 1], v[, ncol(v)]))
  ids <- ids[!is.na(ids)]
  sum(!is.na(v) & v %in% ids) / length(v)
}

# ---------------------------------------------------------------------------
# 1. The sweep — every frame, every threshold, total and interior mask fraction
# ---------------------------------------------------------------------------
# This is the table that ships. The test suite reads it so that "the cap sits above the
# largest legitimate value" is a computation rather than a recollection.

sweep <- list()
for (i in seq_along(files)) {
  src <- files[[i]]
  dm  <- tryCatch(img_dim(src), error = function(e) NULL)
  if (is.null(dm)) { message("skip (unreadable): ", basename(src)); next }
  win <- interior_srcwin(dm[1], dm[2])
  for (thr in THRESHOLDS) {
    dest <- file.path(work, sprintf("nb_%03d_%03d.tif", i, thr))
    ok <- tryCatch({ nearblack_alpha(src, thr, dest); TRUE }, error = function(e) FALSE)
    if (!ok || !file.exists(dest)) { unlink(dest); next }
    ab <- n_bands(dest)
    sweep[[length(sweep) + 1L]] <- data.frame(
      file           = basename(src),
      year           = basename(dirname(src)),
      nc             = dm[1], nr = dm[2],
      bands_src      = ab - 1L,
      threshold      = thr,
      frac_total     = alpha_fraction(dest, band = ab),
      frac_interior  = alpha_fraction(dest, band = ab, srcwin = win),
      stringsAsFactors = FALSE
    )
    unlink(dest)
  }
  if (i %% 20 == 0) message("  swept ", i, " / ", length(files))
}
sweep <- do.call(rbind, sweep)
message("sweep rows: ", nrow(sweep))

# Rounded at the writer. The fractions carry ~15 significant digits of float noise
# otherwise, which triples the file and makes a regenerated table differ from a committed
# one in digits nothing reads. Six decimals is four more than any assertion uses.
sweep$frac_total    <- round(sweep$frac_total, 6)
sweep$frac_interior <- round(sweep$frac_interior, 6)

dir.create(dirname(out_csv), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(sweep, out_csv, row.names = FALSE)
message("wrote ", out_csv)

# ---------------------------------------------------------------------------
# 2. Per-frame plateau — the threshold at which a frame's own border is fully consumed
# ---------------------------------------------------------------------------
# The calibration target, and it is NOT the population median of mask fractions. A median
# of fractions cannot tell a fully-removed border from a small one; it moves for both
# reasons at once. What matters per frame is the point past which the mask stops growing
# because the border is gone and the next dark thing is scene content.
#
# Defined as the lowest threshold whose fraction is within `tol` of the frame's own
# fraction at the next threshold up — i.e. where the curve goes flat for that frame.

plateau_for <- function(d, tol = 0.002) {
  d <- d[order(d$threshold), ]
  if (nrow(d) < 2) return(NA_integer_)
  if (max(d$frac_total, na.rm = TRUE) < 0.002) return(0L)   # no border at all
  growth <- diff(d$frac_total)
  hit <- which(growth <= tol)
  if (!length(hit)) return(NA_integer_)
  d$threshold[hit[1]]
}

plateaus <- vapply(split(sweep, sweep$file), plateau_for, integer(1))
plateaus <- plateaus[!is.na(plateaus)]
has_border <- vapply(split(sweep, sweep$file),
                     function(d) max(d$frac_total, na.rm = TRUE) >= 0.002, logical(1))

cat("\n== per-frame plateau threshold ==\n")
cat("frames with a border:", sum(has_border), "of", length(has_border), "\n")
print(table(plateaus[has_border[names(plateaus)]]))
cat("quantiles over bordered frames:\n")
print(stats::quantile(plateaus[has_border[names(plateaus)]],
                      c(0.5, 0.9, 0.95, 0.99, 1), na.rm = TRUE))
cat("\n-> fly_mask_threshold() should be the ~99th percentile of this distribution.\n")

# ---------------------------------------------------------------------------
# 3. The guard's admissible band, computed
# ---------------------------------------------------------------------------
# The cap must sit above the largest INTERIOR fraction any legitimate frame produces at
# the chosen threshold, and below the smallest a runaway produces. Both ends measured:
# picking a number between two numbers you have not computed is guesswork with a decimal
# point in it (CLAUDE.md, fly#38 — check a threshold against the least favourable case).

report_at <- function(thr) {
  d <- sweep[sweep$threshold == thr, ]
  if (!nrow(d)) return(invisible(NULL))
  cat(sprintf("\n== threshold %d (n = %d) ==\n", thr, nrow(d)))
  cat("frac_total    "); print(round(stats::quantile(d$frac_total, c(0.5, 0.9, 0.99, 1), na.rm = TRUE), 4))
  cat("frac_interior "); print(round(stats::quantile(d$frac_interior, c(0.5, 0.9, 0.99, 1), na.rm = TRUE), 5))
  worst <- d[which.max(d$frac_interior), ]
  cat(sprintf("worst interior: %s (%s) %.5f\n", worst$file, worst$year, worst$frac_interior))
}
for (thr in c(8L, 12L, 16L, 20L, 24L, 32L, 48L, 64L)) report_at(thr)

cat("\n-> fly_mask_max_interior() sits above the max frac_interior at the chosen",
    "threshold\n   and below the runaway values at 48/64. Record both ends in the note.\n")

# ---------------------------------------------------------------------------
# 4. Agreement with the terra prototype — the go/no-go for the dependency-free route
# ---------------------------------------------------------------------------
# GDAL's flood fill and `terra::patches(directions = 8)` need not agree: if GDAL's fill is
# 4-connected, a chamfered corner joined only diagonally would break away. Measured per
# frame rather than argued, on the threshold the sweep selects.

agree_thr <- 16L
agree <- lapply(files, function(src) {
  dest <- file.path(work, "agree.tif")
  ok <- tryCatch({ nearblack_alpha(src, agree_thr, dest); TRUE }, error = function(e) FALSE)
  if (!ok) return(NULL)
  g <- alpha_fraction(dest)
  unlink(dest)
  t_ <- tryCatch(terra_edge_connected(src, agree_thr), error = function(e) NA_real_)
  data.frame(file = basename(src), gdal = g, terra = t_,
             stringsAsFactors = FALSE)
})
agree <- do.call(rbind, agree)
agree$diff <- agree$gdal - agree$terra

cat("\n== nearblack floodfill vs terra::patches(directions = 8), threshold", agree_thr, "==\n")
print(round(stats::quantile(agree$diff, c(0, 0.25, 0.5, 0.75, 1), na.rm = TRUE), 5))
cat("frames disagreeing by more than 0.02: ",
    sum(abs(agree$diff) > 0.02, na.rm = TRUE), " of ", nrow(agree), "\n", sep = "")
cat("correlation: ", round(stats::cor(agree$gdal, agree$terra, use = "complete.obs"), 4), "\n", sep = "")
cat("\n-> if these disagree materially the dependency-free route is off and the terra\n",
    "   implementation ships instead, with terra promoted to Imports.\n", sep = "")

# ---------------------------------------------------------------------------
# 5. GDAL behaviour checks the implementation rests on
# ---------------------------------------------------------------------------
# Each of these is a premise the design would fail silently on. Measured, not reasoned.

cat("\n== GDAL behaviour ==\n")
cat("sf GDAL: ", sf::sf_extSoftVersion()[["GDAL"]], "\n", sep = "")

gcps <- c("-gcp", "0", "0", "1200000", "900000",
          "-gcp", "100", "0", "1201000", "900000",
          "-gcp", "100", "100", "1201000", "899000",
          "-gcp", "0", "100", "1200000", "899000")

# One representative of each band count present. `which()[1]` on an empty set gives NA,
# and `files[NA]` is NA rather than a zero-length vector - which then reaches `n_bands()`
# as a path and fails several lines later, naming a regex rather than the empty set. So
# the NAs come out here, and a directory holding only one band count checks only that one.
band_of <- vapply(files, function(f) tryCatch(n_bands(f), error = function(e) NA_integer_),
                  integer(1))
reps <- c(files[which(band_of == 1L)[1]], files[which(band_of >= 3L)[1]])
reps <- unique(reps[!is.na(reps)])
if (!length(reps)) message("no readable representative frames for the GDAL behaviour checks")

for (src in reps) {
  nb0 <- n_bands(src)
  m <- file.path(work, "chk_nb.tif"); nearblack_alpha(src, 16L, m)
  info_m <- sf::gdal_utils("info", source = m, quiet = TRUE)
  ci <- paste(regmatches(info_m, gregexpr("ColorInterp=\\w+", info_m))[[1]], collapse = ",")

  v <- file.path(work, "chk_gcp.vrt")
  sf::gdal_utils("translate", source = m, destination = v,
                 options = c("-of", "VRT", "-a_srs", "EPSG:3005", gcps))
  has_gcp <- any(grepl("GCP", readLines(v, warn = FALSE)))

  o <- file.path(work, "chk_warp.tif")
  opts <- c("-t_srs", "EPSG:3005", "-r", "bilinear", "-srcalpha")
  opts <- if (nb0 >= 3) c(opts, "-dstalpha") else c(opts, "-dstnodata", "0")
  sf::gdal_utils("warp", source = v, destination = o, options = opts)

  cat(sprintf("src bands %d -> nearblack %d [%s] -> vrt gcps %s -> warp %d bands\n",
              nb0, n_bands(m), ci, has_gcp, n_bands(o)))

  unlink(c(m, v, o))
}

# ---------------------------------------------------------------------------
# 6. Does the warp pull masked black into the pixels next to it?
# ---------------------------------------------------------------------------
# If GDAL did not exclude invalid source pixels from the bilinear kernel, every kept pixel
# along the mask boundary would be dragged toward 0 and the fix would introduce a one-pixel
# dark rim of its own. The remedy for that would be to erode the mask inward, NOT to change
# the resampling - so it has to be measured before the design is trusted.
#
# It MUST be measured on a synthetic frame with a UNIFORM interior. Run against a real
# thumbnail the question is unanswerable: the exposed frame is genuinely darker at its
# edge (vignetting), so boundary pixels read low whether or not a fringe exists. Measured
# on a 2005 RGB thumbnail the boundary/interior luminance ratio is 0.63, and none of that
# is attributable. On a uniform interior the expected value is exactly the fill value.

cat("\n== alpha fringe, on a synthetic uniform interior ==\n")
{
  n <- 200L; collar <- 10L; fill <- 200L
  mm <- matrix(fill, n, n)
  vals <- rep(seq.int(3L, 12L), length.out = n)
  for (k in seq_len(collar)) {
    mm[k, ] <- vals; mm[n - k + 1L, ] <- vals
    mm[, k] <- vals; mm[, n - k + 1L] <- vals
  }
  syn <- file.path(work, "fringe_src.tif")
  rr <- terra::rast(nrows = n, ncols = n, nlyrs = 3L, vals = 0L)
  for (b in 1:3) terra::values(rr[[b]]) <- as.integer(t(mm))
  terra::writeRaster(rr, syn, datatype = "INT1U", overwrite = TRUE, NAflag = NA)

  mk <- nearblack_alpha(syn, 16L, file.path(work, "fringe_nb.tif"))

  # A genuinely ROTATED ground quad, as `fly_rectangles()` produces for a real bearing.
  # An axis-aligned one resamples on-grid and produces no boundary blending at all, which
  # reads as "no fringe" while having tested nothing.
  cx <- 1200000; cy <- 900000; hw <- 2500; hh <- 2500; bb <- 35 * pi / 180
  rt <- function(x, y) c(cx + x * cos(bb) - y * sin(bb), cy + x * sin(bb) + y * cos(bb))
  co <- list(rt(-hw, hh), rt(hw, hh), rt(hw, -hh), rt(-hw, -hh))
  pxc <- list(c(0, 0), c(n, 0), c(n, n), c(0, n))
  gg <- unlist(lapply(1:4, function(i) c("-gcp", as.character(pxc[[i]]), as.character(co[[i]]))))

  vv <- file.path(work, "fringe.vrt")
  sf::gdal_utils("translate", source = mk, destination = vv,
                 options = c("-of", "VRT", "-a_srs", "EPSG:3005", gg))
  oo <- file.path(work, "fringe_warp.tif")
  sf::gdal_utils("warp", source = vv, destination = oo,
                 options = c("-t_srs", "EPSG:3005", "-r", "bilinear", "-srcalpha", "-dstalpha"))

  aa   <- terra::as.array(suppressWarnings(terra::rast(oo)))
  nbo  <- dim(aa)[3]
  al   <- aa[, , nbo]
  lum  <- aa[, , 1]
  keep <- al == 255
  adj  <- keep & (rbind(FALSE, al[-nrow(al), ] == 0) | rbind(al[-1, ] == 0, FALSE) |
                  cbind(FALSE, al[, -ncol(al)] == 0) | cbind(al[, -1] == 0, FALSE))

  cat("distinct output alpha values: ", length(unique(as.vector(al))),
      " (2 means GDAL emits binary alpha, no partial coverage)\n", sep = "")
  cat("kept pixels: ", sum(keep), ", of which adjacent to the mask: ", sum(adj), "\n", sep = "")
  cat("luminance, kept and NOT adjacent: ", min(lum[keep & !adj]), "-", max(lum[keep & !adj]), "\n", sep = "")
  cat("luminance, kept and ADJACENT:     ", min(lum[adj]), "-", max(lum[adj]),
      " (fill value is ", fill, ")\n", sep = "")
  cat(if (sum(adj) > 0 && min(lum[adj]) == fill) {
        "-> no fringe: GDAL excludes invalid source pixels from the resample kernel.\n"
      } else if (sum(adj) == 0) {
        "-> VACUOUS: no boundary pixels to measure. Check the GCPs actually rotate.\n"
      } else {
        "-> FRINGE PRESENT: erode the mask inward. Do NOT change the resampling.\n"
      })
  unlink(c(syn, mk, vv, oo))
}

unlink(work, recursive = TRUE)
