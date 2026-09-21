# dem_calibrate-coverage_error.R — what a partially DEM-covered footprint costs (fly#58).
#
# Everything here is public: the airphoto centroid layer of the BC Data Catalogue and
# NRCan's MRDEM-30, both unauthenticated.
#
# Usage, from the repo root:
#   Rscript data-raw/dem_calibrate-coverage_error.R
#
#   Stage 1  select frames offline, from the centroid cache
#            `height_calibrate-flying_height_slip.R` already built
#   Stage 2  measure how often partial coverage happens against MRDEM-30, before anything
#            synthetic is generated
#   Stage 3  cache one DEM window per sweep frame
#   Stage 4  truncate those windows by a known GEOMETRIC share and measure what it costs
#   Stage 5  repeat a reduced grid on a coarsened, a reprojected and an anisotropic copy
#   Stage 6  write `inst/extdata/dem_coverage_sweep.csv` and `dem_coverage_population.csv`,
#            which the suite reads so the constants are checked against the data
#
# Read `inst/notes/terrain-correction.md` before changing anything here: four `dem_coverage`
# implementations shipped in sequence while wrong, each passing its own tests.

# `pkgload::load_all()` unconditionally, never `requireNamespace()`: a generation script
# operates on the source tree by definition.
pkgload::load_all(quiet = TRUE)
suppressMessages({
  library(sf)
  library(terra)
})
sf::sf_use_s2(FALSE)

# Cap what GDAL and terra may hold, in every process this script starts.
#
# Measured on this machine: `terra::gdalCache()` defaults to **3,276 MB per process** and
# `terraOptions()$memfrac` to 0.5 of 64 GB. A master plus two PSOCK workers may therefore
# reserve about 10 GB of block cache before reading anything, which is what put the
# machine under memory pressure and had the sweep killed four times. The windows are a few
# hundred thousand cells, so a 128 MB block cache is ample and the ceiling costs nothing.
cap_memory <- function() {
  terra::gdalCache(128)
  terra::terraOptions(memfrac = 0.05, memmax = 1, progress = 0)
  invisible(TRUE)
}
cap_memory()

CENTROIDS <- "data-raw/.cache/centroids"
CACHE     <- "data-raw/.cache/dem_coverage"
WINDOWS   <- file.path(CACHE, "windows")
MRDEM     <- "/vsicurl/https://canelevation-dem.s3.ca-central-1.amazonaws.com/mrdem-30/mrdem-30-dtm.tif"
OUT_SWEEP <- "inst/extdata/dem_coverage_sweep.csv"
OUT_POP   <- "inst/extdata/dem_coverage_population.csv"
OUT_TARGETS <- "inst/extdata/dem_coverage_targets.csv"
REPO      <- normalizePath(".")
# Two, not six. Each worker carries a `pkgload::load_all()` of the package — measured at
# 400-600 MB RSS — so six of them plus the rasters put the machine under memory pressure
# and the run was killed twice, the second time at three. Overridable, because the right
# number is a property of the machine and of what else is running on it, not of the sweep:
#   FLY_DEM_CALIB_WORKERS=6 Rscript data-raw/dem_calibrate-coverage_error.R
WORKERS   <- as.integer(Sys.getenv("FLY_DEM_CALIB_WORKERS", "2"))

# The truncation grid. Shares are of the NOMINAL footprint's area, which is exogenous —
# known before any DEM is read. Achieved `dem_coverage` is an OUTCOME, recorded per run.
SHARES <- c(0.02, 0.05, 0.10, 0.20, 0.35, 0.50, 0.65, 0.80)
# Which sides of the keep-rectangle are cut. An AOI-cropped DEM keeps a rectangle, so a
# footprint over the AOI's edge loses a strip and one over its corner loses an L.
DIRS <- c("N", "S", "E", "W", "NE", "NW", "SE", "SW")
N_PER_STRATUM <- 10
RUN_LEN <- 3          # target + neighbours, which exist only to give the target a bearing

dir.create(WINDOWS, recursive = TRUE, showWarnings = FALSE)
set.seed(58)

# Rewritten only when the content moved, so re-running against an unchanged catalogue
# leaves `git status` clean.
write_if_changed <- function(d, path) {
  tmp <- tempfile(fileext = ".csv")
  # Quote only the columns that need it. The sweep's character columns are bare tokens
  # (`na_mask`, `dem_agl`, `NE`) and quoting 11,520 rows of them costs about a fifth of the
  # file — but the population table's coverage bins are `[0,0.5)`, which carry a comma, and
  # writing those unquoted would silently shift every column after them. Decided per
  # column rather than asserted away: the first version of this was a `stopifnot` that
  # refused the population table outright.
  needs <- which(vapply(d, function(v) {
    is.character(v) && any(grepl('[",\n]', v))
  }, logical(1)))
  utils::write.csv(d, tmp, row.names = FALSE,
                   quote = if (length(needs)) needs else FALSE)
  if (!file.exists(path) || tools::md5sum(tmp) != tools::md5sum(path)) {
    file.copy(tmp, path, overwrite = TRUE) || stop("could not write ", path)
    message("wrote ", path, " (", nrow(d), " rows)")
  } else {
    message(path, " unchanged")
  }
}

# Written to a temp name and renamed, so an interrupted stage never leaves a cache entry
# that reads as complete.
save_atomic <- function(x, path) {
  tmp <- paste0(path, ".part")
  saveRDS(x, tmp)
  stopifnot(file.rename(tmp, path))
  invisible(path)
}

# `message()` with a tag, so every figure the note and NEWS quote has a producer line that
# can be grepped out of a run log.
pub <- function(...) message(sprintf(...))

# ---------------------------------------------------------------------------
# Stage 1 — select, offline
# ---------------------------------------------------------------------------

SELECTION <- file.path(CACHE, "selection.rds")

message("Stage 1 — selecting frames from ", CENTROIDS)
if (file.exists(SELECTION)) {
  # A resume needs the selection, not the catalogue it was drawn from. Rebuilding it costs
  # about a minute and 3.3 GB of resident memory that R does not hand back — which is what
  # the kernel sees when it decides what to kill, whatever `gc()` reports.
  sel <- readRDS(SELECTION)
  for (nm in names(sel)) assign(nm, sel[[nm]], envir = globalenv())
  pub("  restored the selection from %s (%d sweep targets, %d population frames)",
      SELECTION, nrow(targets), nrow(pop_set))
} else {
year_files <- list.files(CENTROIDS, pattern = "\\.rds$", full.names = TRUE)
stopifnot(length(year_files) > 100)
frames <- do.call(rbind, lapply(year_files, readRDS))
stopifnot(!anyDuplicated(frames$airp_id))
pub("  %d centroids cached", nrow(frames))

frames$scale_n <- suppressWarnings(as.numeric(sub("^1:", "", frames$scale)))
frames$is_film <- frames$media %in% fly_film_media()

# The film frames the DEM route would size. Film only, and that is a decision rather than a
# convenience. Digital DEM eligibility is `!by_gsd & from_table`, and `from_table` resolves
# through `camera_calibration_url`, which this cache does not carry — so a digital set
# chosen from these columns would partly never reach the DEM route at all. Film also states
# its height above ground twice, and that second statement is what anchors the sweep against
# something other than the reference DEM.
film <- frames[frames$is_film &
                 is.finite(frames$scale_n) & frames$scale_n > 0 &
                 is.finite(frames$flying_height) & frames$flying_height > 0 &
                 is.finite(frames$focal_length) & frames$focal_length > 0, ]
pub("  %d film frames the DEM route would size", nrow(film))

# Nominal half-side and half-diagonal, metres, for a 9 inch negative.
film$half_m <- 9 * 0.0254 * film$scale_n / 2
film$halfdiag_m <- film$half_m * sqrt(2)

# --- a coarse picture of MRDEM, used only to FIND candidates and to stratify -----------
#
# Read through `gdal_translate -outsize`, which resolves against the COG's own overviews:
# 1200 x 1138 at 1833 m in about six seconds. Cropping the full-resolution raster and
# aggregating it does not finish in two minutes and is the wrong instrument.
coarse_path <- file.path(CACHE, "mrdem_coarse.tif")
if (!file.exists(coarse_path)) {
  message("  reading a coarse MRDEM overview over BC")
  bb <- sf::st_bbox(sf::st_transform(sf::st_as_sfc(sf::st_bbox(
    c(xmin = 150000, ymin = 330000, xmax = 1900000, ymax = 1800000), crs = 3005)),
    terra::crs(terra::rast(MRDEM))))
  tmp <- paste0(coarse_path, ".part")
  sf::gdal_utils("translate", MRDEM, tmp, options = c(
    "-projwin", as.character(bb[1]), as.character(bb[4]),
    as.character(bb[3]), as.character(bb[2]),
    "-outsize", "1200", "0", "-r", "nearest",
    # Named explicitly: the destination carries a `.part` suffix while it is being
    # written, and GDAL cannot guess a driver from that.
    "-of", "GTiff"))
  stopifnot(file.rename(tmp, coarse_path))
}
coarse <- terra::rast(coarse_path)
pub("  coarse MRDEM %d x %d at %.0f m, %.1f%% nodata",
    nrow(coarse), ncol(coarse), terra::res(coarse)[1],
    100 * mean(is.na(terra::values(coarse))))

# Distance from each DATA cell to the nearest NODATA cell. The mask is inverted first:
# `terra::distance(x, target = NA)` measures FROM the NA cells outward, so handing it the
# DEM directly returns 0 for every data cell and marks 99.999% of the catalogue as a
# candidate — a result implausible enough to be the instrument rather than the world.
nodata_dist <- terra::distance(terra::ifel(is.na(coarse), 1, NA), target = NA, unit = "m")

# A ruggedness surface, for stratifying the sweep. Computed from the coarse DEM and so
# independent of the error being measured — the strata must not be drawn from the outcome.
coarse_relief <- terra::focal(coarse, w = 5, fun = "sd", na.rm = TRUE)

at_coarse <- function(r, x, y) {
  p <- terra::project(terra::vect(cbind(x, y), type = "points", crs = "EPSG:3005"),
                      terra::crs(r))
  terra::extract(r, p)[, 2]
}

film$dist_nodata <- at_coarse(nodata_dist, film$x, film$y)
film$relief <- at_coarse(coarse_relief, film$x, film$y)

# --- stratum 1: every frame that could possibly be partially covered ------------------
#
# Generous by two coarse cells, so the finder over-selects. It is a candidate FINDER, not
# the measurement: every candidate is then measured at full resolution in Stage 2, and the
# random draw below is the control that it missed nobody.
cell <- terra::res(coarse)[1]
film$edge_candidate <- is.na(film$dist_nodata) |
  film$dist_nodata < (film$halfdiag_m + 2 * cell)
pub("  frames whose footprint could reach MRDEM nodata: %d of %d (%.4f%%)",
    sum(film$edge_candidate), nrow(film), 100 * mean(film$edge_candidate))

# Digital frames get the same test at three times their nominal half-diagonal, because a
# digital frame's catalogued `scale` is about a third of its true image scale (fly#32) —
# so three times over-selects rather than under-selects.
digital <- frames[grepl("^Digital", frames$media), ]
digital$halfdiag_m <- 3 * 9 * 0.0254 *
  ifelse(is.finite(digital$scale_n), digital$scale_n, 20000) / 2 * sqrt(2)
digital$dist_nodata <- at_coarse(nodata_dist, digital$x, digital$y)
digital_edge <- digital[is.na(digital$dist_nodata) |
                          digital$dist_nodata < (digital$halfdiag_m + 2 * cell), ]
pub("  digital frames whose footprint could reach MRDEM nodata: %d of %d (%.4f%%)",
    nrow(digital_edge), nrow(digital), 100 * nrow(digital_edge) / nrow(digital))

# The three population totals Stage 6 publishes, taken as scalars here. Stage 6 used to
# call `nrow(film)` directly, which kept the 1.44M-row frame — and the 1.67M-row one it
# was cut from — alive for the whole run: the master measured 3.28 GB against 0.86 and
# 0.48 GB for its two workers, and it is the master that was being killed.
POP_TOTALS <- c(film_dem_eligible = nrow(film),
                film_edge_candidates = sum(film$edge_candidate),
                digital_edge_candidates = nrow(digital_edge))

# --- stratum 2: a random draw, as contiguous runs -------------------------------------
#
# Runs, not isolated frames. `fly_bearing()` refuses a neighbour that is not adjacent by
# frame number (fly#26), so a scatter of isolated frames is drawn as axis-aligned squares
# while a real frame's footprint is a square rotated onto its flight line. Rolls are drawn
# with probability proportional to size, so a frame's chance of selection stays close to
# uniform despite the clustering.
take_runs <- function(pool, n_runs, len, seed_tag) {
  by_roll <- split(seq_len(nrow(pool)), pool$film_roll)
  by_roll <- by_roll[vapply(by_roll, length, integer(1)) >= len]
  if (!length(by_roll)) return(pool[0, ])
  sizes <- vapply(by_roll, length, integer(1))
  pick <- sample(names(by_roll), min(n_runs, length(by_roll)), replace = FALSE,
                 prob = sizes / sum(sizes))
  idx <- unlist(lapply(pick, function(k) {
    i <- by_roll[[k]]
    i <- i[order(pool$frame_number[i])]
    s <- sample.int(length(i) - len + 1, 1)
    i[s:(s + len - 1)]
  }))
  out <- pool[idx, ]
  out$run_id <- paste0(seed_tag, "_", rep(seq_along(pick), each = len))
  out$run_pos <- rep(seq_len(len), length(pick))
  out
}

random_set <- take_runs(film, n_runs = 300, len = 10, seed_tag = "rand")
random_set$set <- "random"
pub("  random draw: %d frames in %d runs", nrow(random_set),
    length(unique(random_set$run_id)))

edge_set <- film[film$edge_candidate, ]
if (nrow(edge_set)) {
  edge_set$run_id <- paste0("edge_", edge_set$film_roll)
  edge_set$run_pos <- NA_integer_
  edge_set$set <- "edge"
}

pop_set <- rbind(random_set, edge_set)
pop_set <- pop_set[!duplicated(pop_set$airp_id), ]
pub("  population set: %d frames (%s)", nrow(pop_set),
    paste(names(table(pop_set$set)), table(pop_set$set), collapse = ", "))

# --- the sweep set: stratified by scale and by ruggedness -----------------------------
#
# Both axes are properties of the frame and of the ground, known before any truncation —
# never the error itself. A third of the targets is held out, untouched until the
# predictor comparison in Stage 6, so that comparison is not fit and scored on one draw.
sweep_pool <- film[!film$edge_candidate & is.finite(film$relief) &
                     film$scale_n >= 8000 & film$scale_n <= 80000, ]
scale_band <- cut(sweep_pool$scale_n, c(0, 15000, 30000, Inf),
                  labels = c("scale_fine", "scale_mid", "scale_coarse"))
relief_band <- cut(sweep_pool$relief,
                   stats::quantile(sweep_pool$relief, c(0, .25, .5, .75, 1)),
                   labels = c("relief_q1", "relief_q2", "relief_q3", "relief_q4"),
                   include.lowest = TRUE)
sweep_pool$stratum <- paste(scale_band, relief_band, sep = "/")

sweep_runs <- do.call(rbind, lapply(split(sweep_pool, sweep_pool$stratum), function(p) {
  r <- take_runs(p, n_runs = N_PER_STRATUM, len = RUN_LEN,
                 seed_tag = paste0("s", match(p$stratum[1], sort(unique(sweep_pool$stratum)))))
  if (nrow(r)) r$stratum <- p$stratum[1]
  r
}))
# The target is the middle frame of each run; the others exist only so `fly_bearing()` has
# an adjacent frame to take an azimuth from. Their own footprints are sized independently
# per frame, so whatever the truncation does to them cannot reach the target's row.
sweep_runs$is_target <- sweep_runs$run_pos == 2L
targets <- sweep_runs[sweep_runs$is_target, ]
targets$holdout <- seq_len(nrow(targets)) %% 3L == 0L
# Carried onto the runs here rather than at the stage that sweeps them: `sweep_target()`
# reads it off the run, and a column assigned in a later stage makes the function depend
# on where it is called from.
sweep_runs$holdout <- targets$holdout[match(sweep_runs$run_id, targets$run_id)]
stopifnot(!anyNA(sweep_runs$holdout))
pub("  sweep set: %d targets over %d strata (%d held out)",
    nrow(targets), length(unique(targets$stratum)), sum(targets$holdout))

digital_ids <- unique(c(
  digital_edge$airp_id,
  take_runs(digital[!is.na(digital$film_roll), ], n_runs = 50, len = 10,
            seed_tag = "dctl")$airp_id))
pub("  digital frames to pull calibration columns for: %d", length(digital_ids))

save_atomic(list(targets = targets, sweep_runs = sweep_runs, pop_set = pop_set,
                 POP_TOTALS = POP_TOTALS, digital_ids = digital_ids,
                 digital_edge_ids = digital_edge$airp_id),
            SELECTION)
}

# Everything a worker needs in its own global environment.
#
# A PSOCK worker deserialises a function whose environment IS the master's global
# environment as one bound to its OWN global environment, so every helper and constant the
# function reaches for has to be put there explicitly. Collected in one place rather than
# listed at each of the three cluster call sites, because a helper added later would
# otherwise be forgotten in one of them and the failure is `object 'X' not found` from
# inside a worker, several stages after the omission.
worker_objs <- function() {
  nms <- c("MRDEM", "WINDOWS", "CACHE", "DIRS", "CUT_U", "RUN_LEN",
           "window_radius", "window_path", "fetch_window", "cap_memory",
           "keep_rect", "rect_sfc", "covered_stats", "sweep_target", "measure_coverage")
  nms <- nms[vapply(nms, exists, logical(1), envir = globalenv())]
  stats::setNames(lapply(nms, get, envir = globalenv()), nms)
}

install_worker_objs <- function(objs) {
  for (nm in names(objs)) assign(nm, objs[[nm]], envir = globalenv())
  invisible(TRUE)
}

# ---------------------------------------------------------------------------
# Stage 2 — how often this actually happens, before anything synthetic
# ---------------------------------------------------------------------------
#
# The issue cites "18 of 416 DEM-corrected frames fell under 95% dem_coverage" from the
# fly#50 run. No artifact holds it, so it is re-derived here rather than quoted.
#
# This runs BEFORE the truncation sweep on purpose: it can change which remedy is worth
# building at all. A handful of locatable frames argues for reporting; a large affected
# population would argue for a fallback.
#
# The random draw is also the control on the candidate finder. The finder reads a 1833 m
# overview, so it cannot see an interior nodata hole a few cells across; if any randomly
# drawn frame comes back short of full coverage, the finder missed something.

# `fly_footprint()` itself, never a reimplementation of its coverage arithmetic — the
# column under study is the one a caller receives.
measure_coverage <- function(d, dem_src) {
  pts <- sf::st_as_sf(d, coords = c("x", "y"), crs = 3005, remove = FALSE)
  fp <- withCallingHandlers(
    fly_footprint(pts, dem = terra::rast(dem_src)),
    warning = function(w) invokeRestart("muffleWarning")
  )
  data.frame(
    airp_id = d$airp_id, set = d$set, photo_year = d$photo_year,
    scale_n = d$scale_n, relief = d$relief, dist_nodata = d$dist_nodata,
    dem_coverage = fp$dem_coverage, footprint_terrain = fp$footprint_terrain,
    height_source = fp$height_source, height_agl = fp$height_agl,
    bearing = fp$footprint_bearing, stringsAsFactors = FALSE
  )
}

# Batched and cached per batch: losing a long remote run to one dropped connection at
# minute 40 is a real cost, and the cache makes a retry incremental rather than total.
run_batched <- function(todo, tag, batch = 1000, chunk = 25) {
  path <- file.path(CACHE, paste0(tag, ".rds"))
  done <- if (file.exists(path)) readRDS(path) else NULL
  todo <- todo[!todo$airp_id %in% done$airp_id, ]
  if (!nrow(todo)) {
    pub("  %s: complete (%d frames cached)", tag, nrow(done))
    return(done)
  }
  pub("  %s: %d frames to measure", tag, nrow(todo))
  # Frames stay in roll/frame order inside a chunk so contiguous ones land together, where
  # their 60% overlap is absorbed by GDAL's block cache — and so that `fly_bearing()` has
  # an adjacent frame to work from, which a scatter of isolated frames would not.
  todo <- todo[order(todo$film_roll, todo$frame_number), ]
  batches <- split(todo, ceiling(seq_len(nrow(todo)) / batch))
  for (bi in seq_along(batches)) {
    b <- batches[[bi]]
    chunks <- split(b, ceiling(seq_len(nrow(b)) / chunk))
    # A PSOCK cluster, not `mclapply()`: GDAL's curl handles do not survive a fork on
    # macOS, and every one of 104 forked chunks aborted with "An irrecoverable exception
    # occurred" while the wrapper still exited 0 (fly#54).
    cl <- parallel::makeCluster(WORKERS)
    t0 <- Sys.time()
    got <- tryCatch(
      parallel::parLapply(cl, chunks, function(d, dem_src, repo, objs, setup) {
        tryCatch({
          suppressMessages(pkgload::load_all(repo, quiet = TRUE))
          suppressMessages(sf::sf_use_s2(FALSE))
          setup(objs)
          cap_memory()
          measure_coverage(d, dem_src)
        }, error = function(e) conditionMessage(e))
      }, dem_src = MRDEM, repo = REPO, objs = worker_objs(),
      setup = install_worker_objs),
      finally = parallel::stopCluster(cl)
    )
    failed <- vapply(got, function(g) !is.data.frame(g), logical(1))
    if (any(failed)) {
      stop(sum(failed), " of ", length(got), " chunks failed in ", tag, ": ",
           paste(unique(unlist(got[failed])), collapse = " | "))
    }
    done <- rbind(done, do.call(rbind, got))
    save_atomic(done, path)
    pub("  %s: batch %d/%d, %d frames, %.1f min", tag, bi, length(batches), nrow(done),
        as.numeric(difftime(Sys.time(), t0, units = "mins")))
  }
  done
}

message("Stage 2 — measuring coverage over MRDEM-30")
pop <- run_batched(pop_set, "population")

sized <- pop[pop$footprint_terrain %in% "dem_agl", ]
pub("  DEM-corrected: %d of %d measured frames", nrow(sized), nrow(pop))
for (s in sort(unique(pop$set))) {
  z <- sized[sized$set == s, ]
  if (!nrow(z)) next
  pub("  %-7s n=%-5d  min cov %.4f  under 1: %d  under 0.95: %d  under 0.8: %d  under 0.5: %d",
      s, nrow(z), min(z$dem_coverage), sum(z$dem_coverage < 1),
      sum(z$dem_coverage < fly_dem_coverage_min()), sum(z$dem_coverage < 0.8),
      sum(z$dem_coverage < 0.5))
}
# The control on the finder: a randomly drawn frame short of full coverage is a frame the
# 1833 m overview could not see.
rand_short <- sized[sized$set == "random" & sized$dem_coverage < 1, ]
pub("  finder control: %d of %d randomly drawn frames short of full coverage",
    nrow(rand_short), sum(sized$set == "random"))
pub("  frames the DEM does not reach at all (no_dem_coverage): %d",
    sum(pop$footprint_terrain %in% "no_dem_coverage"))
# --- Stage 2b: the digital frames, whose eligibility the cache cannot answer -----------
#
# The issue's own figure is a digital one, so it cannot be re-derived from film alone. A
# digital frame reaches the DEM route only when `fly_camera_format()` resolves it AND it
# has no usable ground sample distance (`!by_gsd & from_table`), and both depend on
# `camera_calibration_url` / `patb_gsd`, which the centroid cache does not carry. Those
# columns are pulled for the candidates and for a control, rather than the whole
# catalogue: 673 rows against 223,667.
dig_path <- file.path(CACHE, "digital_attrs.rds")
if (file.exists(dig_path)) {
  dig <- readRDS(dig_path)
} else {
  pub("  pulling calibration columns for %d digital frames", length(digital_ids))
  parts <- split(digital_ids, ceiling(seq_along(digital_ids) / 200))
  dig <- do.call(rbind, lapply(parts, function(ids) {
    d <- bcdata::bcdc_query_geodata("WHSE_IMAGERY_AND_BASE_MAPS.AIMG_PHOTO_CENTROIDS_SP") |>
      dplyr::filter(AIRP_ID %in% !!ids) |>
      dplyr::collect()
    names(d) <- tolower(names(d))
    xy <- sf::st_coordinates(sf::st_transform(sf::st_geometry(d), 3005))
    out <- as.data.frame(sf::st_drop_geometry(d)[, c(
      "airp_id", "photo_year", "scale", "film_roll", "frame_number", "media",
      "focal_length", "flying_height", "ground_sample_distance",
      "camera_calibration_url", "patb_georef_url")])
    out$x <- xy[, 1]
    out$y <- xy[, 2]
    out
  }))
  save_atomic(dig, dig_path)
}
dig$scale_n <- suppressWarnings(as.numeric(sub("^1:", "", dig$scale)))
dig$set <- ifelse(dig$airp_id %in% digital_edge_ids, "digital_edge", "digital_random")
dig$relief <- NA_real_
dig$dist_nodata <- NA_real_
dig_pop <- run_batched(dig, "population_digital")
for (s in sort(unique(dig_pop$set))) {
  z <- dig_pop[dig_pop$set == s, ]
  sized_d <- z[z$footprint_terrain %in% "dem_agl", ]
  pub("  %-15s n=%-5d  DEM-sized %-5d  under 1: %d  under 0.95: %d  min %s",
      s, nrow(z), nrow(sized_d), sum(sized_d$dem_coverage < 1, na.rm = TRUE),
      sum(sized_d$dem_coverage < fly_dem_coverage_min(), na.rm = TRUE),
      if (nrow(sized_d)) sprintf("%.4f", min(sized_d$dem_coverage)) else "-")
  pub("      routes: %s", paste(names(table(z$footprint_terrain, useNA = "ifany")),
                                table(z$footprint_terrain, useNA = "ifany"), collapse = ", "))
}

# Everything from here works on 120 cached windows and needs none of the catalogue. Held,
# it is gigabytes of master-process residency for the whole sweep.
rm(list = intersect(c("frames", "film", "digital", "digital_edge", "coarse",
                      "nodata_dist", "coarse_relief", "random_set", "edge_set",
                      "sweep_pool", "pop_set", "dig", "ll"), ls()))
invisible(gc(full = TRUE))
pub("  master residency after dropping the catalogue: %.2f GB",
    sum(gc()[, "used"] * c(56, 8)) / 2^30)

message("POP DONE")

# ---------------------------------------------------------------------------
# Stage 3 — one DEM window per sweep frame
# ---------------------------------------------------------------------------
#
# Sized from the LARGEST rectangle the frame could physically produce: `resize(0, fh)`,
# the sea-level seed `fly_footprint()` itself uses, times sqrt(2) to reach the corner.
# Terrain above sea level only ever makes the rectangle smaller, so no truncation run can
# produce one that overhangs this window — which matters because truncation runs the
# correction the WRONG way. Losing high ground lowers the mean, raises the height above
# ground and ENLARGES the rectangle; a window sized from the full-coverage answer plus a
# fixed margin would be truncated a second time by the harness itself, and the harness
# would attribute it to the truncation under test.
window_radius <- function(d) {
  9 * 0.0254 * d$flying_height / (d$focal_length / 1000) / 2 * sqrt(2)
}

window_path <- function(airp_id) file.path(WINDOWS, paste0(airp_id, ".tif"))

fetch_window <- function(d, dem_src) {
  path <- window_path(d$airp_id)
  if (file.exists(path)) return(invisible(path))
  dem <- terra::rast(dem_src)
  r <- window_radius(d)
  box <- sf::st_buffer(sf::st_sfc(sf::st_point(c(d$x, d$y)), crs = 3005), r,
                       endCapStyle = "SQUARE")
  e <- terra::ext(terra::vect(sf::st_transform(box, terra::crs(dem))))
  # Two cells of margin, so the window's own edge is never mistaken for a truncation.
  e <- terra::extend(e, 2 * terra::res(dem)[1])
  # `.part.tif`, not `.part`: GDAL guesses the driver from the extension, and a bare
  # `.part` fails with "cannot guess file type from filename" — the same trap the coarse
  # overview hit through `gdal_utils()`. The suffix still makes the write atomic, which is
  # what matters: an interrupted fetch must not leave a window that reads as complete.
  tmp <- paste0(path, ".part.tif")
  terra::writeRaster(terra::crop(dem, e), tmp, overwrite = TRUE, datatype = "FLT4S")
  stopifnot(file.rename(tmp, path))
  invisible(path)
}

message("Stage 3 — caching one DEM window per sweep frame")
todo_win <- targets[!file.exists(window_path(targets$airp_id)), ]
if (nrow(todo_win)) {
  pub("  %d windows to fetch", nrow(todo_win))
  chunks <- split(todo_win, ceiling(seq_len(nrow(todo_win)) / 5))
  cl <- parallel::makeCluster(WORKERS)
  got <- tryCatch(
    parallel::parLapply(cl, chunks, function(d, dem_src, repo, objs, setup) {
      tryCatch({
        suppressMessages(pkgload::load_all(repo, quiet = TRUE))
        suppressMessages(sf::sf_use_s2(FALSE))
        setup(objs)
        cap_memory()
        for (i in seq_len(nrow(d))) fetch_window(d[i, ], dem_src)
        TRUE
      }, error = function(e) conditionMessage(e))
    }, dem_src = MRDEM, repo = REPO, objs = worker_objs(),
    setup = install_worker_objs),
    finally = parallel::stopCluster(cl)
  )
  bad <- !vapply(got, isTRUE, logical(1))
  if (any(bad)) stop(sum(bad), " window chunks failed: ",
                     paste(unique(unlist(got[bad])), collapse = " | "))
}
stopifnot(all(file.exists(window_path(targets$airp_id))))
pub("  %d windows cached", nrow(targets))

# ---------------------------------------------------------------------------
# Stage 4 — truncate by a known geometric share
# ---------------------------------------------------------------------------
#
# The treatment variable is the share of the NOMINAL footprint removed, computed from
# geometry before any DEM is read. Achieved `dem_coverage` is an OUTCOME and is recorded
# as one: truncation biases the first pass's mean, which changes the height above ground,
# which resizes the rectangle, which moves the coverage again. Measured over this sweep
# that feedback is negligible in the middle and real in the tail: `share_removed` minus
# `1 - dem_coverage` has a median of 0.000, a 90th percentile of 0.055 and a maximum of
# 0.284. The decision does not rest on the magnitude — achieved coverage is downstream of
# the treatment whatever its size, so regressing the error on it fits an outcome to an
# outcome. The mapping is published instead, because any shipped constant has to be
# expressed in the number the code holds.
#
# Both mechanisms are "keep only what is inside an axis-aligned rectangle", which is
# exactly what a DEM cropped to an AOI does: a footprint over the AOI's edge loses a
# strip, one over its corner loses an L. `na_mask` keeps extent, origin and resolution
# fixed; `extent_crop` moves them, and so is the only one that exercises the `on_dem`
# guard and `crop()`-clips-rather-than-pads. They are compared at matched share.

# Fractions of the footprint's bounding box kept, per cut side. Not solved to round
# shares: the share is MEASURED from the geometry, which removes a bisection from the
# inner loop and costs nothing, since the share is recorded either way.
CUT_U <- c(0.05, 0.12, 0.22, 0.35, 0.50, 0.65, 0.80, 0.92)

# The keep-rectangle, in the DEM's own CRS, as an `ext`-style numeric.
keep_rect <- function(fb, dir, u) {
  xr <- fb[3] - fb[1]
  yr <- fb[4] - fb[2]
  k <- c(fb[1], fb[2], fb[3], fb[4])
  if (grepl("N", dir)) k[4] <- fb[4] - u * yr
  if (grepl("S", dir)) k[2] <- fb[2] + u * yr
  if (grepl("E", dir)) k[3] <- fb[3] - u * xr
  if (grepl("W", dir)) k[1] <- fb[1] + u * xr
  k
}

rect_sfc <- function(k, crs) {
  sf::st_sfc(sf::st_polygon(list(rbind(
    c(k[1], k[2]), c(k[3], k[2]), c(k[3], k[4]), c(k[1], k[4]), c(k[1], k[2])))), crs = crs)
}

# Mean, spread and a planar fit over the cells a footprint actually covered — every one of
# these is computable inside `fly_dem_sample()` from values it already holds, which is the
# whole point. A predictor fitted on the full window is not one the package could ever
# report.
covered_stats <- function(r, poly) {
  v <- terra::extract(r, terra::vect(poly), xy = TRUE, ID = FALSE)
  names(v)[1] <- "z"
  v <- v[!is.na(v$z), , drop = FALSE]
  if (!nrow(v)) {
    return(list(n = 0L, mean = NA_real_, sd = NA_real_, range = NA_real_,
                grad = NA_real_, planar = NA_real_))
  }
  out <- list(n = nrow(v), mean = mean(v$z), sd = stats::sd(v$z),
              range = diff(range(v$z)), grad = NA_real_, planar = NA_real_)
  if (nrow(v) >= 8 && stats::sd(v$x) > 0 && stats::sd(v$y) > 0) {
    fit <- stats::lm.fit(cbind(1, v$x - mean(v$x), v$y - mean(v$y)), v$z)
    cf <- fit$coefficients
    out$grad <- sqrt(cf[2]^2 + cf[3]^2)
    # Extrapolate the plane over the WHOLE footprint, not just the covered part: the
    # centre of every cell the footprint should have covered.
    #
    # Taken off `fly_dem_grid()` through `terra::extract()`, which is the same C++
    # centre-in-polygon test the coverage DENOMINATOR is counted with — so the plane is
    # averaged over exactly the cells `dem_coverage` says are missing, and not over a set
    # obtained a second way. Doing it as an `sf::st_intersects()` over every cell of the
    # template was also 20,000 point-in-polygon tests per run, 154 million across the
    # sweep.
    tmpl <- fly_dem_grid(r, poly)
    terra::values(tmpl) <- 1L
    cen <- terra::extract(tmpl, terra::vect(poly), xy = TRUE, ID = FALSE)
    cen <- cen[!is.na(cen[[1]]), c("x", "y"), drop = FALSE]
    if (nrow(cen)) {
      out$planar <- mean(cf[1] + cf[2] * (cen$x - mean(v$x)) + cf[3] * (cen$y - mean(v$y)))
    }
  }
  out
}

# One target frame, every truncation. Returns one row per run.
sweep_target <- function(run, dem_arm = NULL, dirs = DIRS, us = CUT_U,
                         mechs = c("na_mask", "extent_crop"), arm = "native") {
  tgt <- which(run$is_target)
  stopifnot(length(tgt) == 1L)
  full <- if (is.null(dem_arm)) terra::rast(window_path(run$airp_id[tgt])) else dem_arm
  pts <- sf::st_as_sf(run, coords = c("x", "y"), crs = 3005, remove = FALSE)

  fp0 <- withCallingHandlers(fly_footprint(pts, dem = full),
                             warning = function(w) invokeRestart("muffleWarning"))
  ref <- fp0[tgt, ]
  # The reference must be a fully covered, DEM-sized, believed-height frame, or the
  # treatment is not truncation alone. A frame that is anything else is dropped by name.
  ok_ref <- isTRUE(ref$footprint_terrain == "dem_agl") &&
    isTRUE(ref$height_source == "reported") &&
    isTRUE(!is.na(ref$dem_coverage) && ref$dem_coverage >= 0.9999)
  area_ref <- as.numeric(sf::st_area(sf::st_transform(ref, 3005)))
  geom_ref <- sf::st_transform(sf::st_geometry(ref), terra::crs(full))

  # The nominal (pass-zero) footprint: what the first pass samples, and the shape the
  # treatment share is defined against. Built with the package's own constructor and the
  # bearing the package resolved, so it is the same rectangle the code uses.
  half_nom <- 9 * 0.0254 * run$scale_n[tgt] / 2
  nom <- fly_rectangles(matrix(c(run$x[tgt], run$y[tgt]), ncol = 2),
                        half_nom, half_nom, fp0$footprint_bearing[tgt])
  sf::st_crs(nom) <- 3005
  nom_d <- sf::st_transform(nom, terra::crs(full))
  fb <- as.numeric(sf::st_bbox(nom_d))[c(1, 2, 3, 4)]
  area_nom <- as.numeric(sf::st_area(nom_d))

  base <- data.frame(
    airp_id = run$airp_id[tgt], run_id = run$run_id[tgt], stratum = run$stratum[tgt],
    holdout = run$holdout[tgt], arm = arm,
    scale_n = run$scale_n[tgt], focal_length = run$focal_length[tgt],
    flying_height = run$flying_height[tgt], relief_coarse = run$relief[tgt],
    bearing = fp0$footprint_bearing[tgt],
    ref_ok = ok_ref, ref_agl = ref$height_agl, ref_area = area_ref,
    ref_coverage = ref$dem_coverage, stringsAsFactors = FALSE
  )
  s_ref <- covered_stats(full, geom_ref)
  base$ref_elev <- s_ref$mean
  base$ref_sd <- s_ref$sd
  base$ref_range <- s_ref$range
  base$ref_grad <- s_ref$grad
  base$ref_n <- s_ref$n

  # The nominal-scale answer, with no DEM at all: the fallback the DEM route is being
  # compared against.
  fpn <- withCallingHandlers(fly_footprint(pts), warning = function(w) invokeRestart("muffleWarning"))
  base$nominal_area <- as.numeric(sf::st_area(sf::st_transform(fpn[tgt, ], 3005)))

  grid <- expand.grid(mech = mechs, dir = dirs, u = us, stringsAsFactors = FALSE)
  rows <- lapply(seq_len(nrow(grid)), function(i) {
    k <- keep_rect(fb, grid$dir[i], grid$u[i])
    if (k[3] <= k[1] || k[4] <= k[2]) return(NULL)
    keep <- rect_sfc(k, terra::crs(full))
    lost <- sf::st_difference(nom_d, keep)
    share <- if (length(lost)) as.numeric(sf::st_area(lost)) / area_nom else 0

    trunc <- if (grid$mech[i] == "na_mask") {
      terra::mask(full, terra::vect(keep))
    } else {
      terra::crop(full, terra::ext(k[1], k[3], k[2], k[4]))
    }
    # A mask must not move the counting grid. `fly_dem_grid()` aligns to the DEM's own
    # cell boundaries, so an origin or resolution that moved would change the denominator
    # and the two mechanisms would stop being comparable.
    if (grid$mech[i] == "na_mask") {
      stopifnot(all(terra::origin(trunc) == terra::origin(full)),
                all(terra::res(trunc) == terra::res(full)))
    }

    fp <- withCallingHandlers(fly_footprint(pts, dem = trunc),
                              warning = function(w) invokeRestart("muffleWarning"))
    row <- fp[tgt, ]
    area <- as.numeric(sf::st_area(sf::st_transform(row, 3005)))
    st <- covered_stats(trunc, sf::st_transform(sf::st_geometry(row), terra::crs(full)))
    # The mean of the part that was taken away, from the UNTRUNCATED window: the sign of
    # the error, which a magnitude-only record averages out.
    lost_elev <- if (length(lost) && as.numeric(sf::st_area(lost)) > 0) {
      lv <- terra::extract(full, terra::vect(lost), ID = FALSE)[, 1]
      mean(lv, na.rm = TRUE)
    } else NA_real_

    data.frame(
      mech = grid$mech[i], dir = grid$dir[i], cut_u = grid$u[i],
      share_removed = share,
      dem_coverage = row$dem_coverage,
      footprint_terrain = row$footprint_terrain,
      height_source = row$height_source,
      height_agl = row$height_agl,
      area = area,
      covered_n = st$n, covered_mean = st$mean, covered_sd = st$sd,
      covered_range = st$range, covered_grad = st$grad, covered_planar = st$planar,
      lost_elev = lost_elev,
      stringsAsFactors = FALSE
    )
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (!length(rows)) return(NULL)
  cbind(base[rep(1, length(rows)), ], do.call(rbind, rows), row.names = NULL)
}

run_sweep <- function(runs, tag, arm_fn = NULL, arm = "native", ...) {
  path <- file.path(CACHE, paste0(tag, ".rds"))
  done <- if (file.exists(path)) readRDS(path) else NULL
  by_target <- split(runs, runs$run_id)
  # Keyed on the target frame, and asserted rather than assumed. The first version tested
  # `names(by_target) %in% unique(done$run_id)` against an output that carried no `run_id`
  # column at all: `%in% NULL` is FALSE for everything, so nothing was ever skipped and
  # each resume redid the same twenty targets. The row count still grew, which is exactly
  # what made it read as progress.
  stopifnot(is.null(done) || all(c("airp_id", "run_id") %in% names(done)))
  done_targets <- unique(done$airp_id)
  by_target <- by_target[vapply(by_target, function(r) {
    !r$airp_id[which(r$is_target)] %in% done_targets
  }, logical(1))]
  if (!length(by_target)) {
    pub("  %s: complete (%d rows cached)", tag, nrow(done))
    return(done)
  }
  pub("  %s: %d targets", tag, length(by_target))
  # Cached every 20 targets rather than once at the end. The first attempt at this stage
  # was killed for memory with nothing saved, and the windows it had already read were the
  # expensive half.
  for (grp in split(seq_along(by_target), ceiling(seq_along(by_target) / 20))) {
    done <- rbind(done, run_sweep_batch(by_target[grp], tag, arm_fn, arm, ...))
    save_atomic(done, path)
    pub("  %s: %d rows cached", tag, nrow(done))
  }
  done
}

run_sweep_batch <- function(by_target, tag, arm_fn, arm, ...) {
  cl <- parallel::makeCluster(WORKERS)
  t0 <- Sys.time()
  got <- tryCatch(
    parallel::parLapply(cl, by_target, function(run, repo, objs, setup, arm_fn, arm, extra) {
      tryCatch({
        suppressMessages(pkgload::load_all(repo, quiet = TRUE))
        suppressMessages(sf::sf_use_s2(FALSE))
        setup(objs)
        cap_memory()
        dem_arm <- if (is.null(arm_fn)) NULL else {
          arm_fn(terra::rast(window_path(run$airp_id[which(run$is_target)])))
        }
        do.call(sweep_target, c(list(run = run, dem_arm = dem_arm, arm = arm), extra))
      }, error = function(e) conditionMessage(e))
    }, repo = REPO, objs = worker_objs(), setup = install_worker_objs,
    arm_fn = arm_fn, arm = arm, extra = list(...)),
    finally = parallel::stopCluster(cl)
  )
  failed <- vapply(got, function(g) !is.data.frame(g) && !is.null(g), logical(1))
  if (any(failed)) {
    stop(sum(failed), " of ", length(got), " targets failed in ", tag, ": ",
         paste(utils::head(unique(unlist(got[failed])), 3), collapse = " | "))
  }
  out <- do.call(rbind, got[!vapply(got, is.null, logical(1))])
  pub("  %s: +%d rows in %.1f min", tag, nrow(out),
      as.numeric(difftime(Sys.time(), t0, units = "mins")))
  out
}

message("Stage 4 — truncating by a known geometric share")
# `extent_crop` on a quarter of the targets, `na_mask` on all of them: the second
# mechanism is a control on the first, not a doubling of the sweep.
crop_runs <- sweep_runs[sweep_runs$run_id %in%
                          unique(targets$run_id)[seq(1, nrow(targets), by = 4)], ]
sweep_mask <- run_sweep(sweep_runs, "sweep_mask", mechs = "na_mask")
sweep_crop <- run_sweep(crop_runs, "sweep_crop", mechs = "extent_crop")
sweep <- rbind(sweep_mask, sweep_crop)
pub("  sweep: %d rows, %d targets, reference usable on %d",
    nrow(sweep), length(unique(sweep$airp_id)),
    length(unique(sweep$airp_id[sweep$ref_ok])))

# ---------------------------------------------------------------------------
# Stage 5 — the axes the native-resolution sweep cannot reach
# ---------------------------------------------------------------------------
#
# `inst/notes/terrain-correction.md` lists the axes the bundled fixture holds constant, and
# a sweep run on MRDEM-30 in its own CRS at its own resolution reaches exactly one of them,
# the truncating extent. The threshold under review was set for reprojection slivers, and
# the reprojection branch does not execute at all unless the DEM is in another CRS — so
# licensing a change to it from native-CRS data only would repeat the failure the note was
# written about. Three arms, all free from the windows already cached.
ARM_FNS <- list(
  # ~900 m. A footprint a few cells across cannot express 0.95 at all; quantisation alone
  # may make the threshold meaningless there.
  coarse = function(w) terra::aggregate(w, fact = 30, fun = "mean", na.rm = TRUE),
  # The only way to execute the reprojection branch, and the only way to produce the
  # NA slivers the 0.95 threshold exists for.
  geographic = function(w) terra::project(w, "EPSG:4326"),
  # Non-square cells are ordinary away from the equator.
  anisotropic = function(w) terra::aggregate(w, fact = c(4, 12), fun = "mean", na.rm = TRUE)
)

message("Stage 5 — robustness arms")
# A reduced grid: four cardinal directions, four shares, a third of the targets. The arms
# are a check that the native result does not depend on resolution, CRS or cell shape, not
# a second full sweep.
arm_runs <- sweep_runs[sweep_runs$run_id %in% unique(targets$run_id)[seq(1, nrow(targets), by = 3)], ]
arms <- lapply(names(ARM_FNS), function(a) {
  run_sweep(arm_runs, paste0("sweep_", a), arm_fn = ARM_FNS[[a]], arm = a,
            dirs = c("N", "S", "E", "W"), us = c(0.12, 0.35, 0.50, 0.80),
            mechs = "na_mask")
})
sweep <- rbind(sweep, do.call(rbind, arms))
pub("  arms: %s", paste(names(table(sweep$arm)), table(sweep$arm), collapse = ", "))

# ---------------------------------------------------------------------------
# Stage 6 — what it means, and the artifacts the suite re-reads
# ---------------------------------------------------------------------------

# Only runs whose reference frame was fully covered, DEM-sized and believed. Anything else
# would put the fly#54 height checks or `no_dem_coverage` inside the treatment.
sw <- sweep[sweep$ref_ok, ]
pub("\n  usable runs: %d of %d, over %d of %d targets",
    nrow(sw), nrow(sweep), length(unique(sw$airp_id)), length(unique(sweep$airp_id)))

# The error, as a LINEAR ratio. Area is the square of it; the note states the conversion
# once and quotes linear throughout, because the probe and the warning both speak of width.
sw$err <- sqrt(sw$area / sw$ref_area) - 1
sw$nominal_err <- sqrt(sw$nominal_area / sw$ref_area) - 1
# The analytic term: half-side scales with height above ground, so the whole first-order
# effect is the elevation bias divided by the height above ground.
sw$err_analytic <- sw$height_agl / sw$ref_agl - 1
sw$elev_bias <- sw$covered_mean - sw$ref_elev
# Did the truncation change how the frame was classified? A flip is a jump to nominal
# scale, not a few percent of resize, and it is the larger failure where it happens.
sw$flipped <- !(sw$footprint_terrain %in% "dem_agl") | !(sw$height_source %in% "reported")

# Stated over the population the note quotes — native `na_mask` runs with a usable
# reference — not over every arm and mechanism at once, or the reproducer prints a
# different pair from the document it reproduces.
nat_usable <- sw[sw$arm == "native" & sw$mech == "na_mask", ]
pub("  classification flips: %d of %d native na_mask runs (%.1f%%)",
    sum(nat_usable$flipped), nrow(nat_usable), 100 * mean(nat_usable$flipped))
if (any(nat_usable$flipped)) {
  # The same population as the headline above it. A first version left this on `sw`, which
  # is every arm and mechanism at once — 1,096 rows under a headline reporting 873.
  pub("    flipped to: %s",
      paste(names(table(nat_usable$footprint_terrain[nat_usable$flipped])),
            table(nat_usable$footprint_terrain[nat_usable$flipped]), collapse = ", "))
}

# What the pipeline contributes over the arithmetic. If these agree everywhere, the result
# is a terrain-statistics one and transfers past this package.
unflipped <- sw[!sw$flipped & is.finite(sw$err) & is.finite(sw$err_analytic), ]
pub("  realised vs analytic error, unflipped runs: max |difference| %.2e over %d runs",
    max(abs(unflipped$err - unflipped$err_analytic)), nrow(unflipped))

native <- sw[sw$arm == "native", ]
# The population every table below is computed over, defined ONCE. A first version applied
# the `dem_agl` filter to the robustness arms and not to this, so the script's own producer
# lines printed a different lowest band from the note they produce: n=2380 and max 25.290%
# against 1,507 and 23.563%, because all 873 total-loss runs sit at coverage 0 and fall in
# that band. A frame that lost its terrain entirely is a nominal-scale fallback, not a
# partially covered footprint, and it does not belong in a table about partial coverage.
mask <- native[native$mech == "na_mask" & native$footprint_terrain %in% "dem_agl", ]

# The headline: signed linear error by achieved coverage. Signed, because the two routes
# fail in opposite directions — partial coverage over high ground draws the footprint too
# BIG, and the nominal fallback draws it too small, and overclaiming ground is not
# symmetric with underclaiming for a set-cover consumer.
band <- cut(mask$dem_coverage, c(-0.01, 0.2, 0.4, 0.6, 0.8, 0.9, 0.95, 0.99, 1.01))
pub("\n  signed linear error by achieved dem_coverage (na_mask, native):")
for (b in levels(band)) {
  z <- mask$err[band == b & is.finite(mask$err)]
  if (!length(z)) next
  pub("    %-14s n=%-5d  median %+7.3f%%  5-95%% %+7.3f%% .. %+7.3f%%  max|.| %6.3f%%",
      b, length(z), 100 * stats::median(z), 100 * stats::quantile(z, .05),
      100 * stats::quantile(z, .95), 100 * max(abs(z)))
}

# The same thing split by how rugged the ground is — the issue's own claim, that coverage
# alone cannot be the answer.
pub("\n  |linear error| at dem_coverage under 0.5, by relief quartile:")
deep <- mask[mask$dem_coverage < 0.5 & is.finite(mask$err), ]
rq <- sub(".*/", "", deep$stratum)
for (q in sort(unique(rq))) {
  z <- abs(deep$err[rq == q])
  pub("    %-10s n=%-5d  median %6.3f%%  90th %6.3f%%  max %6.3f%%", q, length(z),
      100 * stats::median(z), 100 * stats::quantile(z, .9), 100 * max(z))
}

# Is the DEM route ever worse than the fallback it replaced? Compared on the same frames,
# against the same reference, at matched coverage.
pub("\n  DEM route vs nominal fallback (na_mask, native), by achieved coverage:")
for (b in levels(band)) {
  z <- mask[band == b & is.finite(mask$err) & is.finite(mask$nominal_err), ]
  if (!nrow(z)) next
  pub("    %-14s n=%-5d  median |dem| %6.3f%%  median |nominal| %6.3f%%  dem worse on %d (%.1f%%)",
      b, nrow(z), 100 * stats::median(abs(z$err)), 100 * stats::median(abs(z$nominal_err)),
      sum(abs(z$err) > abs(z$nominal_err)),
      100 * mean(abs(z$err) > abs(z$nominal_err)))
}

# The two mechanisms, compared at matched share on the targets that got both.
both <- sweep[sweep$ref_ok & sweep$arm == "native" &
                sweep$airp_id %in% sweep$airp_id[sweep$mech == "extent_crop"], ]
both$err <- sqrt(both$area / both$ref_area) - 1
key <- paste(both$airp_id, both$dir, both$cut_u)
m1 <- both[both$mech == "na_mask", ]
m2 <- both[both$mech == "extent_crop", ]
i <- match(paste(m2$airp_id, m2$dir, m2$cut_u), paste(m1$airp_id, m1$dir, m1$cut_u))
ok <- !is.na(i) & is.finite(m2$err) & is.finite(m1$err[i])
pub("\n  na_mask vs extent_crop on %d matched runs: max |coverage difference| %.4f, max |error difference| %.4f%%",
    sum(ok), max(abs(m2$dem_coverage[ok] - m1$dem_coverage[i][ok])),
    100 * max(abs(m2$err[ok] - m1$err[i][ok])))

# Where the geometric treatment lands in the number the code actually holds. A shipped
# constant has to be expressed in `dem_coverage`, so the mapping is published.
pub("\n  geometric share removed -> achieved dem_coverage (na_mask, native):")
for (u in sort(unique(mask$cut_u))) {
  z <- mask[mask$cut_u == u, ]
  pub("    cut_u %.2f  share removed %.3f (%.3f-%.3f)  achieved coverage %.3f (%.3f-%.3f)",
      u, stats::median(z$share_removed), min(z$share_removed), max(z$share_removed),
      stats::median(z$dem_coverage), min(z$dem_coverage), max(z$dem_coverage))
}

# The predictor comparison, on held-out targets only, and using statistics computable from
# the cells the DEM route actually read — the full-window figures could never be reported
# by the package.
ho <- mask[mask$holdout & is.finite(mask$err) & mask$covered_n > 0, ]
pub("\n  predictors of |linear error|, held-out targets only (n=%d runs, %d targets):",
    nrow(ho), length(unique(ho$airp_id)))
for (p in c("dem_coverage", "covered_sd", "covered_range", "covered_grad")) {
  v <- ho[[p]]
  ok2 <- is.finite(v)
  pub("    %-14s Spearman rho vs |error| = %+.3f", p,
      stats::cor(v[ok2], abs(ho$err[ok2]), method = "spearman"))
}
# The product the physics implies: a gradient times the offset of what was lost, over the
# height above ground. Both halves are computable from the covered cells.
ho$predicted <- abs(ho$covered_grad) * (1 - ho$dem_coverage) *
  sqrt(ho$ref_area) / abs(ho$height_agl)
ok2 <- is.finite(ho$predicted)
pub("    %-14s Spearman rho vs |error| = %+.3f", "grad x loss",
    stats::cor(ho$predicted[ok2], abs(ho$err[ok2]), method = "spearman"))

# Within a coverage band, which is the question actually being asked once coverage is
# known. Pooled, coverage dominates and the terrain statistics barely beat it; this block
# is what decides between `covered_sd` and `covered_grad`, and it had no producer line at
# all until a review round recomputed the note against nothing.
pub("\n  within-band Spearman rho vs |error| (held-out):")
hbb <- cut(ho$dem_coverage, c(0, .2, .4, .6, .8, .95, 1.01))
r_sd <- tapply(seq_len(nrow(ho)), hbb,
               function(i) stats::cor(ho$covered_sd[i], abs(ho$err[i]), method = "spearman"))
r_gr <- tapply(seq_len(nrow(ho)), hbb,
               function(i) stats::cor(ho$covered_grad[i], abs(ho$err[i]), method = "spearman"))
for (lv in levels(hbb)) {
  pub("    %-12s sd %+0.3f   grad %+0.3f", lv, r_sd[[lv]], r_gr[[lv]])
}
pub("    sd %.3f-%.3f ; grad %.3f-%.3f ; sd better in %d of %d bands",
    min(r_sd), max(r_sd), min(r_gr), max(r_gr), sum(r_sd > r_gr), length(r_sd))

# The calibrated bound the note publishes and deliberately does NOT ship. Fitted on the
# training targets alone and scored on the held-out ones, or it would be reporting how well
# it fits its own fit.
tr_b <- mask[!mask$holdout & mask$dem_coverage > 0 & is.finite(mask$covered_sd), ]
ho_b <- mask[mask$holdout & mask$dem_coverage > 0 & is.finite(mask$covered_sd), ]
scale_of <- function(z) z$covered_sd * (1 - z$dem_coverage) / abs(z$height_agl)
k_bound <- stats::quantile(abs(tr_b$err) / scale_of(tr_b), .95, na.rm = TRUE)
pub("\n  calibrated bound k = %.2f (95th pct on training, n=%d)", k_bound, nrow(tr_b))
pub("    held-out: holds on %.1f%% of %d runs; median bound/actual %.1fx; under half coverage holds on %.1f%%",
    100 * mean(abs(ho_b$err) <= k_bound * scale_of(ho_b), na.rm = TRUE), nrow(ho_b),
    stats::median(k_bound * scale_of(ho_b) / abs(ho_b$err), na.rm = TRUE),
    100 * mean((abs(ho_b$err) <= k_bound * scale_of(ho_b))[ho_b$dem_coverage < 0.5],
               na.rm = TRUE))

# The share-to-coverage mapping, as a distribution rather than one example. An earlier
# draft of the note quoted "0.30 comes back as 0.215" from the two-frame feasibility probe,
# which parameterised the cut differently; measured here the two agree closely in the
# middle and diverge only in the tail.
gap <- mask$share_removed - (1 - mask$dem_coverage)
pub("  share_removed vs 1 - dem_coverage: median %.3f, 90th %.3f, max %.3f",
    stats::median(gap), stats::quantile(abs(gap), .9), max(abs(gap)))

# The fifth candidate, out of scope to ship here and measured rather than left unmentioned:
# extrapolating the covered cells' plane over the part the DEM did not describe.
pl <- mask[is.finite(mask$covered_planar) & is.finite(mask$covered_mean), ]
pub("\n  planar extrapolation vs the covered mean, |elevation error| in m:")
for (b in levels(cut(pl$dem_coverage, c(-0.01, 0.5, 0.8, 0.95, 1.01)))) {
  z <- pl[cut(pl$dem_coverage, c(-0.01, 0.5, 0.8, 0.95, 1.01)) == b, ]
  if (!nrow(z)) next
  pub("    %-14s n=%-5d  covered mean %7.2f  planar %7.2f  planar better on %.1f%%",
      b, nrow(z), stats::median(abs(z$covered_mean - z$ref_elev)),
      stats::median(abs(z$covered_planar - z$ref_elev)),
      100 * mean(abs(z$covered_planar - z$ref_elev) < abs(z$covered_mean - z$ref_elev)))
}

# The arms.
# Each arm against its OWN full-coverage reference, and over the frames the DEM still
# sized — the same population the tables above use, or the arms would not be comparable
# with them.
pub("\n  robustness arms, |linear error| at achieved coverage under 0.8:")
for (a in sort(unique(sw$arm))) {
  all_a <- sw[sw$arm == a & sw$mech == "na_mask", ]
  z <- all_a[all_a$dem_coverage < 0.8 & all_a$footprint_terrain %in% "dem_agl" &
               is.finite(all_a$err), ]
  if (!nrow(z)) next
  # Flips counted BEFORE the `dem_agl` filter, or the column is 0 by construction: a
  # flipped run is one that is no longer `dem_agl`, so filtering on it first removes every
  # row the count exists to find, and the reproducer becomes decoration.
  pub("    %-12s n=%-5d  median %6.3f%%  90th %6.3f%%  flips %d of %d", a, nrow(z),
      100 * stats::median(abs(z$err)), 100 * stats::quantile(abs(z$err), .9),
      sum(all_a$flipped), nrow(all_a))
}

# ---------------------------------------------------------------------------
# The artifacts
# ---------------------------------------------------------------------------

# Two tables, not one. The per-target facts are constant across that target's runs within
# an arm, so carrying them on each row cost 3.5 MB against the 395 KB and 156 KB the
# package's other shipped sweeps take.
#
# Keyed on `airp_id` AND `arm`, which a first version got wrong. Every arm samples a
# DIFFERENT raster — coarsened, reprojected or anisotropic — so it computes its own
# full-coverage reference against it, and those references are not interchangeable:
# `ref_area` differs on 39 of the 40 arm targets and `ref_n` on all 40, by 90,692 cells
# against 101 on the coarse arm. Keeping one row per frame silently measured every arm's
# truncation against the NATIVE reference, which conflates "this arm's DEM differs" with
# "truncation cost this much" — and the arm medians it produced disagreed with the
# script's own per-arm figures.
targets_out <- sweep[!duplicated(sweep[, c("airp_id", "arm")]),
                     c("airp_id", "arm", "run_id", "stratum", "holdout", "scale_n",
                       "focal_length", "flying_height", "relief_coarse", "bearing",
                       "ref_ok", "ref_agl", "ref_area", "ref_elev", "ref_sd", "ref_range",
                       "ref_grad", "ref_n", "nominal_area")]
targets_out$relief_coarse <- round(targets_out$relief_coarse, 2)
targets_out$bearing <- round(targets_out$bearing, 2)
targets_out$ref_agl <- round(targets_out$ref_agl, 2)
targets_out$ref_area <- round(targets_out$ref_area)
targets_out$nominal_area <- round(targets_out$nominal_area)
targets_out$ref_elev <- round(targets_out$ref_elev, 3)
targets_out$ref_sd <- round(targets_out$ref_sd, 3)
targets_out$ref_range <- round(targets_out$ref_range, 2)
targets_out$ref_grad <- signif(targets_out$ref_grad, 6)
targets_out <- targets_out[order(targets_out$arm, targets_out$airp_id), ]
stopifnot(!anyDuplicated(paste(targets_out$airp_id, targets_out$arm)),
          nrow(targets_out) == length(unique(paste(sweep$airp_id, sweep$arm))))

sweep_out <- sweep[, c("airp_id", "arm", "mech", "dir", "cut_u", "share_removed",
                       "dem_coverage", "footprint_terrain", "height_source", "height_agl",
                       "area", "covered_n", "covered_mean", "covered_sd", "covered_range",
                       "covered_grad", "covered_planar", "lost_elev")]
# Rounded to what the note quotes and the test recomputes. `area` and `height_agl` decide
# the linear error, which is published to three decimals of a percent, so six significant
# figures is two orders of magnitude of headroom.
sweep_out$share_removed <- round(sweep_out$share_removed, 6)
sweep_out$dem_coverage <- round(sweep_out$dem_coverage, 6)
sweep_out$height_agl <- round(sweep_out$height_agl, 3)
sweep_out$area <- round(sweep_out$area)
sweep_out$covered_mean <- round(sweep_out$covered_mean, 3)
sweep_out$covered_sd <- round(sweep_out$covered_sd, 3)
sweep_out$covered_range <- round(sweep_out$covered_range, 2)
sweep_out$covered_grad <- signif(sweep_out$covered_grad, 6)
sweep_out$covered_planar <- round(sweep_out$covered_planar, 3)
sweep_out$lost_elev <- round(sweep_out$lost_elev, 3)
sweep_out <- sweep_out[order(sweep_out$arm, sweep_out$airp_id, sweep_out$mech,
                             sweep_out$dir, sweep_out$cut_u), ]

# The population, binned: what the sampled sets stand for, and the base rate the decision
# rests on.
pop$media <- "film"
cov_bin <- cut(pop$dem_coverage, c(-0.01, 0.5, 0.8, 0.9, 0.95, 0.99, 0.9999, 1.01),
               labels = c("[0,0.5)", "[0.5,0.8)", "[0.8,0.9)", "[0.9,0.95)",
                          "[0.95,0.99)", "[0.99,1)", "1"))
# Binned by route as well as by stratum. Without the route a reader cannot separate the
# frames the DEM SIZED and left short of coverage from the ones it never reached: the edge
# stratum holds 66 of the first and 26 of the second, and both land in the lowest bin.
population <- do.call(rbind, lapply(
  split(pop, list(pop$set, pop$footprint_terrain), drop = TRUE), function(z) {
    b <- cut(z$dem_coverage, c(-0.01, 0.5, 0.8, 0.9, 0.95, 0.99, 0.9999, 1.01),
             labels = levels(cov_bin))
    data.frame(media = "film", set = z$set[1],
               footprint_terrain = z$footprint_terrain[1],
               coverage_bin = levels(cov_bin), n = as.integer(table(b)),
               stringsAsFactors = FALSE)
  }))
population <- population[population$n > 0, ]
# The two figures the strata stand for, so a sampled rate can be re-weighted to the
# catalogue rather than read as if the sample were the population.
population <- rbind(population, data.frame(
  media = c("film", "film", "digital"),
  set = c("film_dem_eligible_total", "film_edge_candidates_total", "digital_edge_candidates_total"),
  footprint_terrain = NA_character_,
  coverage_bin = NA_character_,
  n = as.integer(POP_TOTALS[c("film_dem_eligible", "film_edge_candidates",
                              "digital_edge_candidates")]),
  stringsAsFactors = FALSE))

write_if_changed(targets_out, OUT_TARGETS)
write_if_changed(sweep_out, OUT_SWEEP)
write_if_changed(population, OUT_POP)
message("ALL DONE")
