# dem_measure-coastal_water.R — is a coastal frame's sea surface an error at all? (fly#65)
#
# MRDEM-30 carries a near-zero surface over near-shore sea rather than nodata. fly#58
# recorded that as a coverage-1 failure — the mean "dragged toward sea level" — and fly#65
# was filed to measure it. This script tests the premise first: over water the surface the
# camera images IS the sea, so the water-inclusive mean the package already uses (W) may be
# the right answer, and the land-only mean the issue proposed as the reference (L) the
# wrong one.
#
# The first witness planned read no DEM: the air base between frames adjacent by number.
# It measures when the shutter fired rather than what the photo covered, so it is kept
# only as a secondary reading. The rule it was to be judged by was committed before
# any coastal frame was measured, and then replaced before any was measured by a better
# one: a ray-cast of the true footprint under the package's own vertical-camera model,
# scored on area and on the land edge. The rules are in fly#65's archived planning
# findings ("Decision rule", "Amendments", "Amendment 2"). Read them before changing any
# threshold here.
#
# Everything here is public: the airphoto centroid layer and FWA coastlines of the BC Data
# Catalogue, the BC terrestrial boundary (`bcmaps::bc_bound_hres()`, BCDC record
# 30aeb5c1-4285-46c8-b60b-15b1a6f4258b), and NRCan's MRDEM-30.
#
# Usage, from the repo root, after `height_calibrate-flying_height_slip.R` has built the
# centroid cache and `dem_calibrate-coverage_error.R` its coarse MRDEM overview:
#   Rscript data-raw/dem_measure-coastal_water.R
#
#   Stage 1  sea: what MRDEM holds at nine coastal sites
#   Stage 2  the ray-cast, which must reproduce a flat and a stepped synthetic DEM first
#   Stage 3  population: DEM-eligible film frames whose footprint can reach the coastline;
#            sample coastal runs (by scale and coastal relief) and inland control runs
#   Stage 4  size every sampled frame through `fly_footprint(dem =)`, ray-cast it, and
#            score W (the package), L (land-only mean) and S (per-side) against it
#   Stage 5  the verdicts; write `inst/extdata/dem_coastal_*.csv`
#
#   FLY_COASTAL_SMOKE=1 runs a handful of frames into a separate cache and writes nothing

pkgload::load_all(quiet = TRUE)
suppressMessages({
  library(sf)
  library(terra)
})
sf::sf_use_s2(FALSE)

# Same caps as `dem_calibrate-coverage_error.R`, for the same measured reason: GDAL's
# default block cache is 3,276 MB per process.
cap_memory <- function() {
  terra::gdalCache(128)
  terra::terraOptions(memfrac = 0.05, memmax = 1, progress = 0)
  invisible(TRUE)
}
cap_memory()

CENTROIDS  <- "data-raw/.cache/centroids"
COARSE     <- "data-raw/.cache/dem_coverage/mrdem_coarse.tif"
SMOKE      <- nzchar(Sys.getenv("FLY_COASTAL_SMOKE"))
CACHE      <- if (SMOKE) "data-raw/.cache/dem_coastal_smoke" else "data-raw/.cache/dem_coastal"
RUNS_DIR   <- file.path(CACHE, "runs")
MRDEM      <- "/vsicurl/https://canelevation-dem.s3.ca-central-1.amazonaws.com/mrdem-30/mrdem-30-dtm.tif"
OUT_FRAMES <- "inst/extdata/dem_coastal_frames.csv"
OUT_POP    <- "inst/extdata/dem_coastal_population.csv"
OUT_SITES  <- "inst/extdata/dem_coastal_sites.csv"
REPO       <- normalizePath(".")
WORKERS    <- as.integer(Sys.getenv("FLY_DEM_CALIB_WORKERS", "3"))
FORMAT_M   <- 9 * 0.0254
RUN_LEN    <- 10
N_PER_STRATUM <- if (SMOKE) 1 else 15
N_INLAND   <- if (SMOKE) 2 else 60
N_BOOT     <- 2000
BAND_M     <- 1         # |elev| under this is MRDEM's near-zero band, the second witness

stopifnot(dir.exists(CENTROIDS), file.exists(COARSE))
dir.create(RUNS_DIR, recursive = TRUE, showWarnings = FALSE)
set.seed(65)

write_if_changed <- function(d, path) {
  tmp <- tempfile(fileext = ".csv")
  needs <- which(vapply(d, function(v) is.character(v) && any(grepl('[",\n]', v)),
                        logical(1)))
  utils::write.csv(d, tmp, row.names = FALSE, na = "",
                   quote = if (length(needs)) needs else FALSE)
  if (!file.exists(path) || tools::md5sum(tmp) != tools::md5sum(path)) {
    file.copy(tmp, path, overwrite = TRUE) || stop("could not write ", path)
    message("wrote ", path, " (", nrow(d), " rows)")
  } else {
    message(path, " unchanged")
  }
}
save_atomic <- function(x, path) {
  tmp <- paste0(path, ".part")
  saveRDS(x, tmp)
  stopifnot(file.rename(tmp, path))
  invisible(path)
}
pub <- function(...) message(sprintf(...))

# ---------------------------------------------------------------------------
# Stage 1 — sea, and the two land/water witnesses
# ---------------------------------------------------------------------------

LAND_TILES <- "data-raw/.cache/dem_coastal/land_tiles.rds"
COAST      <- "data-raw/.cache/dem_coastal/fwa_coastlines.rds"
dir.create(dirname(LAND_TILES), recursive = TRUE, showWarnings = FALSE)

if (!file.exists(LAND_TILES)) {
  land <- sf::st_union(sf::st_geometry(bcmaps::bc_bound_hres(ask = FALSE)))
  # Tiled once, so a frame intersects a few small polygons rather than the province.
  grid <- sf::st_make_grid(land, cellsize = 20000)
  tiles <- sf::st_intersection(sf::st_sf(tile = seq_along(grid), geometry = grid),
                               sf::st_sf(geometry = land))
  tiles <- tiles[!sf::st_is_empty(tiles), ]
  save_atomic(tiles, LAND_TILES)
}
tiles <- readRDS(LAND_TILES)
if (!file.exists(COAST)) {
  save_atomic(bcdata::collect(bcdata::bcdc_query_geodata("WHSE_BASEMAPPING.FWA_COASTLINES_SP")),
              COAST)
}
coast <- sf::st_geometry(readRDS(COAST))
pub("  coastline: %d FWA lines, %.0f km", length(coast), sum(as.numeric(sf::st_length(coast))) / 1000)

# Cells under a polygon (EPSG:3005), split by the land polygon. Returns the values and a
# land flag, read through a window snapped out, the same way `fly_dem_sample()` reads.
cells_under <- function(poly, dem, tiles) {
  pd <- sf::st_transform(sf::st_sfc(poly, crs = 3005), terra::crs(dem))
  ext <- terra::ext(terra::vect(pd))
  if (is.null(terra::intersect(ext, terra::ext(dem)))) return(NULL)
  w <- terra::crop(dem, terra::align(ext, dem, snap = "out"))
  ex <- terra::extract(w, terra::vect(pd), cells = TRUE, ID = FALSE)
  v <- ex[[1]]
  xy <- terra::xyFromCell(w, ex$cell)
  pts <- sf::st_transform(sf::st_as_sf(as.data.frame(xy), coords = c("x", "y"),
                                       crs = terra::crs(dem)), 3005)
  near <- tiles[lengths(sf::st_intersects(tiles, sf::st_as_sfc(sf::st_bbox(pts)))) > 0, ]
  land <- if (nrow(near)) lengths(sf::st_intersects(pts, near)) > 0 else rep(FALSE, length(v))
  list(v = v, land = land)
}

SITES <- data.frame(
  site = c("hecate_strait", "strait_georgia", "dixon_entrance", "howe_sound_fjord",
           "boundary_bay_flat", "roberts_bank_delta", "qc_sound", "offshore_w_haida",
           "knight_inlet_fjord"),
  lon = c(-130.9, -123.6, -132.0, -123.30, -122.95, -123.15, -129.5, -132.6, -125.9),
  lat = c(53.3, 49.25, 54.5, 49.55, 49.05, 49.05, 51.5, 52.5, 50.75))
dem <- terra::rast(MRDEM)
site_rows <- lapply(seq_len(nrow(SITES)), function(i) {
  p <- sf::st_transform(sf::st_sfc(sf::st_point(c(SITES$lon[i], SITES$lat[i])), crs = 4326), 3005)
  cu <- cells_under(sf::st_buffer(p, 1500, endCapStyle = "SQUARE")[[1]], dem, tiles)
  sea <- cu$v[!cu$land]
  lnd <- cu$v[cu$land]
  fin <- function(x) x[is.finite(x)]
  data.frame(site = SITES$site[i], lon = SITES$lon[i], lat = SITES$lat[i],
             n_sea = length(sea), n_sea_nodata = sum(!is.finite(sea)),
             sea_median = if (length(fin(sea))) round(stats::median(fin(sea)), 3) else NA,
             sea_min = if (length(fin(sea))) round(min(fin(sea)), 3) else NA,
             sea_max = if (length(fin(sea))) round(max(fin(sea)), 3) else NA,
             sea_exact_zero = sum(sea == 0, na.rm = TRUE),
             n_land = length(lnd),
             land_median = if (length(fin(lnd))) round(stats::median(fin(lnd)), 3) else NA,
             land_in_band = if (length(fin(lnd))) round(mean(abs(fin(lnd)) < BAND_M), 3) else NA)
})
sites_out <- do.call(rbind, site_rows)
for (i in seq_len(nrow(sites_out))) {
  s <- sites_out[i, ]
  pub("  site %-20s sea n=%d nodata=%d median=%s range=%s..%s zeros=%d | land n=%d median=%s in_band=%s",
      s$site, s$n_sea, s$n_sea_nodata, s$sea_median, s$sea_min, s$sea_max, s$sea_exact_zero,
      s$n_land, s$land_median, s$land_in_band)
}

# ---------------------------------------------------------------------------
# Stage 2 — the ray-cast, and the two synthetic controls it must pass first
# ---------------------------------------------------------------------------

# Where each point of a rectangle's boundary really lands on the ground.
#
# Under the vertical camera `fly_footprint()` assumes, a point P of the returned rectangle
# (drawn at elevation e_W) is the image of the ray through the camera and P, so at
# elevation e it meets the ground at c + (P - c) (H - e) / (H - e_W). The ray is walked
# DOWN from the window's highest elevation and the first level where the terrain reaches
# it is the hit, refined by bisection — so a ridge in front of a valley occludes it, as it
# does in the photo. A ray that meets nodata before it meets terrain is flagged, never
# guessed.
#
# `ring` is an n x 2 matrix in EPSG:3005, `win` an in-memory SpatRaster.
raycast <- function(ring, centre, H, e_w, win, step = 5, n_bisect = 30) {
  crs_dem <- terra::crs(win)
  rng <- terra::global(win, c("min", "max"), na.rm = TRUE)
  levels <- seq(rng$max + 1, rng$min - 1, by = -step)
  if (utils::tail(levels, 1) > rng$min - 1) levels <- c(levels, rng$min - 1)
  dirv <- sweep(ring, 2, centre)
  at <- function(e) {
    # e is one value per ray, or one for all
    s <- (H - e) / (H - e_w)
    g <- sweep(dirv * s, 2, centre, "+")
    p <- sf::sf_project("EPSG:3005", crs_dem, g, keep = TRUE)
    terra::extract(win, p, method = "bilinear")[, 1]
  }
  n <- nrow(ring)
  hit_hi <- rep(NA_real_, n)   # above the surface (ray still in air)
  hit_lo <- rep(NA_real_, n)   # at or below it
  bad <- rep(FALSE, n)
  prev <- rep(levels[1], n)
  for (e in levels) {
    todo <- which(is.na(hit_lo) & !bad)
    if (!length(todo)) break
    z <- at(e)[todo]
    bad[todo[is.na(z)]] <- TRUE
    got <- todo[!is.na(z) & z >= e]
    hit_lo[got] <- e
    hit_hi[got] <- e + step
  }
  bad <- bad | is.na(hit_lo)
  lo <- ifelse(bad, NA_real_, hit_lo)
  hi <- ifelse(bad, NA_real_, hit_hi)
  for (k in seq_len(n_bisect)) {
    mid <- (lo + hi) / 2
    ok <- !bad
    z <- rep(NA_real_, n)
    if (any(ok)) {
      s <- (H - mid[ok]) / (H - e_w)
      g <- sweep(dirv[ok, , drop = FALSE] * s, 2, centre, "+")
      p <- sf::sf_project("EPSG:3005", crs_dem, g, keep = TRUE)
      z[ok] <- terra::extract(win, p, method = "bilinear")[, 1]
    }
    under <- ok & !is.na(z) & z >= mid
    lo[under] <- mid[under]
    hi[ok & !under] <- mid[ok & !under]
  }
  e_hit <- (lo + hi) / 2
  s <- (H - e_hit) / (H - e_w)
  list(xy = sweep(dirv * s, 2, centre, "+"), e = e_hit, bad = bad)
}

# The boundary of a closed ring, `per_edge` points per edge, the first vertex of each
# edge included and its last excluded — so a 4-edge ring gives 4 * per_edge points.
densify <- function(v, per_edge = 32) {
  v <- v[-nrow(v), , drop = FALSE]
  do.call(rbind, lapply(seq_len(nrow(v)), function(k) {
    a <- v[k, ]
    b <- v[if (k == nrow(v)) 1 else k + 1, ]
    t <- (seq_len(per_edge) - 1) / per_edge
    cbind(a[1] + t * (b[1] - a[1]), a[2] + t * (b[2] - a[2]))
  }))
}
close_ring <- function(xy) sf::st_polygon(list(rbind(xy, xy[1, ])))

# Synthetic control, flat: T must be W.
flat_control <- function() {
  H <- 3000; f <- 0.153; a <- 0.1143 / f; e <- 700
  r <- terra::rast(xmin = 1e6 - 3000, xmax = 1e6 + 3000, ymin = 5e5 - 3000, ymax = 5e5 + 3000,
                   resolution = 10, crs = "EPSG:3005")
  terra::values(r) <- e
  h <- a * (H - e)
  v <- cbind(1e6 + c(-h, h, h, -h, -h), 5e5 + c(-h, -h, h, h, -h))
  rc <- raycast(densify(v), c(1e6, 5e5), H, e, r)
  stopifnot(!any(rc$bad))
  as.numeric(sf::st_area(close_ring(rc$xy))) / (2 * h)^2 - 1
}
# Synthetic control, a step through the centroid: 0 m to the south, 500 m to the north.
# Analytic true area 2a^2((H - e)^2 + H^2); W, drawn at the mean e/2, is a^2 e^2 smaller.
step_control <- function(per_edge = 32) {
  H <- 3000; f <- 0.153; a <- 0.1143 / f; e <- 500
  r <- terra::rast(xmin = 1e6 - 3000, xmax = 1e6 + 3000, ymin = 5e5 - 3000, ymax = 5e5 + 3000,
                   resolution = 5, crs = "EPSG:3005")
  terra::values(r) <- ifelse(terra::yFromCell(r, seq_len(terra::ncell(r))) > 5e5, e, 0)
  e_w <- e / 2
  h <- a * (H - e_w)
  v <- cbind(1e6 + c(-h, h, h, -h, -h), 5e5 + c(-h, -h, h, h, -h))
  rc <- raycast(densify(v, per_edge), c(1e6, 5e5), H, e_w, r)
  stopifnot(!any(rc$bad))
  area_t <- as.numeric(sf::st_area(close_ring(rc$xy)))
  c(true_vs_analytic = area_t / (2 * a^2 * ((H - e)^2 + H^2)) - 1,
    w_gap_vs_analytic = (area_t - (2 * h)^2) / (a^2 * e^2) - 1)
}
fc <- flat_control()
sc <- step_control(32)
sc4 <- step_control(128)
pub("  control flat: ray-cast area / rectangle area - 1 = %.2e (must be under 1e-5)", fc)
pub("  control step: ray-cast area / analytic - 1 = %.2e at 32 rays per edge, %.2e at 128 (must be under 1e-3)",
    sc[1], sc4[1])
pub("  control step: (T - W) / a^2 e^2 - 1 = %.2e at 32, %.2e at 128 (the Jensen gap)", sc[2], sc4[2])
# The step is a discontinuity, and a polygon through rays at a finite spacing cuts the
# corner where it crosses an edge, so the reproduction is judged by convergence: the gap
# must be within 5% at the density used and the error must fall at least 3x when the rays
# are four times denser. A defect in the ray-cast would not converge.
if (abs(fc) > 1e-5 || abs(sc[1]) > 1e-3 || abs(sc[2]) > 0.05 ||
    abs(sc4[2]) > abs(sc[2]) / 3) {
  stop("the ray-cast does not reproduce its synthetic controls; it is not trusted")
}

# ---------------------------------------------------------------------------
# Stage 3 — the population, and the sample
# ---------------------------------------------------------------------------

SELECTION <- file.path(CACHE, "selection.rds")
if (file.exists(SELECTION)) {
  sel <- readRDS(SELECTION)
  for (nm in names(sel)) assign(nm, sel[[nm]], envir = globalenv())
  pub("  restored the selection from %s", SELECTION)
} else {
  frames <- do.call(rbind, lapply(list.files(CENTROIDS, "\\.rds$", full.names = TRUE), readRDS))
  stopifnot(!anyDuplicated(frames$airp_id))
  frames$scale_n <- suppressWarnings(as.numeric(sub("^1:", "", frames$scale)))

  # fly#58's eligibility for "the DEM route would size it", unchanged, so the population
  # is counted on the same denominator `dem_coverage_population.csv` publishes. Film only:
  # a digital frame's `scale` is not an image scale (fly#32), and fly#58 found 6 of 223,667
  # digital frames DEM-sized at all.
  film <- frames[frames$media %in% fly_film_media() &
                   is.finite(frames$scale_n) & frames$scale_n > 0 &
                   is.finite(frames$flying_height) & frames$flying_height > 0 &
                   is.finite(frames$focal_length) & frames$focal_length > 0, ]
  rm(frames)
  film$halfdiag_m <- FORMAT_M * film$scale_n / 2 * sqrt(2)

  # Coastal: the centroid within the nominal half-diagonal of an FWA coastline — the
  # footprint can reach the sea. Exact distance to the nearest line.
  pts <- sf::st_as_sf(film[, c("x", "y")], coords = c("x", "y"), crs = 3005)
  nf <- sf::st_nearest_feature(pts, coast)
  film$coast_dist <- as.numeric(sf::st_distance(pts, coast[nf], by_element = TRUE))
  rm(pts, nf)
  film$coastal <- film$coast_dist < film$halfdiag_m

  coarse <- terra::rast(COARSE)
  relief <- terra::focal(coarse, w = 5, fun = "sd", na.rm = TRUE)
  at <- sf::st_transform(sf::st_as_sf(film[, c("x", "y")], coords = c("x", "y"), crs = 3005),
                         terra::crs(coarse))
  film$relief <- terra::extract(relief, terra::vect(at))[, 2]
  rm(at)

  POP <- data.frame(
    measure = c("film_dem_eligible", "film_coastal"),
    n = c(nrow(film), sum(film$coastal)))
  by_scale <- cut(film$scale_n, c(0, 15000, 30000, 80000, Inf),
                  labels = c("to_15000", "15000_30000", "30000_80000", "over_80000"))
  POP <- rbind(POP, data.frame(
    measure = paste0("film_coastal_scale_", levels(by_scale)),
    n = as.integer(tapply(film$coastal, by_scale, sum))),
    data.frame(measure = paste0("film_eligible_scale_", levels(by_scale)),
               n = as.integer(table(by_scale))))

  # Runs: ten consecutive frame numbers on one roll, all present and eligible, centred on
  # the drawn frame. Drawn from the whole roll, not from a filtered pool — a run cut from
  # a pool of coastal frames skips numbers, and a frame at a gap loses its bearing
  # (review B3).
  film <- film[!is.na(film$film_roll) & is.finite(film$frame_number), ]
  key <- paste(film$film_roll, film$frame_number)
  film <- film[!key %in% key[duplicated(key)], ]
  key <- paste(film$film_roll, film$frame_number)
  OFFSETS <- -4:5
  pos <- sapply(OFFSETS, function(o) match(paste(film$film_roll, film$frame_number + o), key))
  full <- rowSums(is.na(pos)) == 0

  sb <- cut(film$scale_n, c(0, 15000, 30000, Inf), labels = c("fine", "mid", "coarse"))
  in_scale <- film$scale_n >= 8000 & film$scale_n <= 80000
  centre_ok <- full & in_scale & is.finite(film$relief)
  cq <- stats::quantile(film$relief[film$coastal & centre_ok], 0:4 / 4)
  rb <- cut(film$relief, cq, labels = paste0("relief_q", 1:4), include.lowest = TRUE)
  film$stratum <- ifelse(film$coastal, paste(sb, rb, sep = "/"), "inland")

  draw <- function(idx, n) idx[sample.int(length(idx), min(n, length(idx)))]
  centres <- unlist(lapply(split(which(centre_ok & film$coastal), film$stratum[centre_ok & film$coastal]),
                           draw, N_PER_STRATUM))
  inland_c <- draw(which(centre_ok & !film$coastal & film$coast_dist > film$halfdiag_m + 5000),
                   N_INLAND)
  mk <- function(ci, set) {
    do.call(rbind, lapply(seq_along(ci), function(j) {
      r <- film[pos[ci[j], ], ]
      r$run_id <- sprintf("%s%03d", substr(set, 1, 1), j)
      r$stratum <- film$stratum[ci[j]]
      r$set <- set
      r
    }))
  }
  runs <- rbind(mk(centres, "coastal"), mk(inland_c, "inland"))
  # A frame drawn into two runs is measured once, in the first.
  runs <- runs[!duplicated(runs$airp_id), ]
  cols <- c("airp_id", "photo_year", "film_roll", "frame_number", "scale", "scale_n",
            "media", "focal_length", "flying_height", "x", "y", "relief", "coast_dist",
            "coastal", "run_id", "stratum", "set")
  runs <- runs[, cols]

  # Air base, from the whole roll: the nearer of the two adjacent frames.
  nb <- function(o) match(paste(runs$film_roll, runs$frame_number + o), key)
  dn <- nb(1); dp <- nb(-1)
  d_next <- sqrt((film$x[dn] - runs$x)^2 + (film$y[dn] - runs$y)^2)
  d_prev <- sqrt((film$x[dp] - runs$x)^2 + (film$y[dp] - runs$y)^2)
  runs$base <- suppressWarnings(pmin(d_next, d_prev, na.rm = TRUE))
  runs$base[!is.finite(runs$base) | runs$base == 0] <- NA_real_
  save_atomic(list(POP = POP, runs = runs), SELECTION)
  rm(film, pos)
}
for (i in seq_len(nrow(POP))) pub("  population %s: %d", POP$measure[i], POP$n[i])
pub("  coastal share of DEM-eligible film: %.2f%%",
    100 * POP$n[POP$measure == "film_coastal"] / POP$n[POP$measure == "film_dem_eligible"])
pub("  sampled: %d coastal runs, %d inland runs, %d frames",
    length(unique(runs$run_id[runs$set == "coastal"])),
    length(unique(runs$run_id[runs$set == "inland"])), nrow(runs))

# ---------------------------------------------------------------------------
# Stage 4 — size every sampled frame, ray-cast it, and score W, L and S against it
# ---------------------------------------------------------------------------

empty_measure <- function() {
  list(n_cells = NA_integer_, n_sea = NA_integer_, n_band = NA_integer_,
              n_sea_band = NA_integer_, n_outside_high = NA_integer_, n_outside_na = NA_integer_,
              mean_all = NA_real_, mean_land = NA_real_, sea_median = NA_real_,
              rays_bad = NA_integer_, area_t = NA_real_, area_w = NA_real_,
              area_l = NA_real_, area_s = NA_real_, land_t = NA_real_,
              incl_w = NA_real_, excl_w = NA_real_, incl_l = NA_real_, excl_l = NA_real_,
              incl_s = NA_real_, excl_s = NA_real_)
}

measure_frame <- function(poly, row, dem, tiles) {
  out <- empty_measure()
  H <- row$flying_height
  e_w <- H - row$height_agl
  v <- sf::st_coordinates(poly)[, 1:2]
  centre <- c(row$x, row$y)
  # The window every ray can reach: W scaled out to the lowest plausible surface.
  reach <- (H + 50) / (H - e_w)
  big <- sweep(sweep(v, 2, centre) * reach, 2, centre, "+")
  bd <- sf::st_transform(sf::st_sfc(close_ring(big[-nrow(big), ]), crs = 3005), terra::crs(dem))
  ext <- terra::ext(terra::vect(bd))
  if (is.null(terra::intersect(ext, terra::ext(dem)))) return(out)
  win <- terra::crop(dem, terra::align(ext, dem, snap = "out"))
  win <- terra::toMemory(win)

  cu <- cells_under(poly, win, tiles)
  if (is.null(cu)) return(out)
  ok <- is.finite(cu$v)
  z <- cu$v[ok]; land <- cu$land[ok]
  band <- abs(z) < BAND_M
  sea_all <- cu$v[!cu$land]
  out$n_cells <- length(z); out$n_sea <- sum(!land); out$n_band <- sum(band)
  out$n_sea_band <- sum(!land & band)
  out$n_outside_high <- sum(is.finite(sea_all) & sea_all > 2)
  out$n_outside_na <- sum(!is.finite(sea_all))
  out$mean_all <- if (length(z)) mean(z) else NA_real_
  out$mean_land <- if (any(land)) mean(z[land]) else NA_real_
  out$sea_median <- if (any(!land)) stats::median(z[!land]) else NA_real_

  rc <- raycast(densify(v), centre, H, e_w, win)
  out$rays_bad <- sum(rc$bad)
  if (any(rc$bad) || !is.finite(out$mean_land)) return(out)
  tp <- sf::st_make_valid(sf::st_sfc(close_ring(rc$xy), crs = 3005))
  e_l <- e_w + (out$mean_land - out$mean_all)
  wp <- sf::st_sfc(poly, crs = 3005)
  scale_about <- function(s) sweep(sweep(v, 2, centre) * s, 2, centre, "+")
  lp <- sf::st_sfc(sf::st_polygon(list(scale_about((H - e_l) / (H - e_w)))), crs = 3005)

  # S: each side moved by the mean elevation of the triangle between it and the centroid.
  vv <- v[-nrow(v), ]
  mids <- (vv + vv[c(2:4, 1), ]) / 2
  s_side <- vapply(1:4, function(k) {
    tri <- sf::st_sfc(close_ring(rbind(centre, vv[k, ], vv[if (k == 4) 1 else k + 1, ])), crs = 3005)
    trd <- sf::st_transform(tri, terra::crs(win))
    zz <- terra::extract(win, terra::vect(trd), ID = FALSE)[[1]]
    (H - mean(zz, na.rm = TRUE)) / (H - e_w)
  }, numeric(1))
  moved <- sweep(sweep(mids, 2, centre) * s_side, 2, centre, "+")
  corner <- function(k) {           # corner between side k-1 and side k is vertex k
    j <- if (k == 1) 4 else k - 1
    moved[j, ] + moved[k, ] - centre
  }
  sv <- t(sapply(1:4, corner))
  sp <- sf::st_sfc(close_ring(sv), crs = 3005)

  near <- tiles[lengths(sf::st_intersects(tiles, sf::st_as_sfc(sf::st_bbox(c(tp, wp, lp, sp))))) > 0, ]
  landg <- if (nrow(near)) sf::st_union(sf::st_geometry(near)) else sf::st_sfc(sf::st_polygon(), crs = 3005)
  ar <- function(g) if (length(g)) sum(as.numeric(sf::st_area(g))) else 0
  land_t <- sf::st_intersection(tp, landg)
  out$area_t <- ar(tp); out$area_w <- ar(wp); out$area_l <- ar(lp); out$area_s <- ar(sp)
  out$land_t <- ar(land_t)
  edge <- function(cp) {
    lc <- sf::st_intersection(cp, landg)
    c(incl = ar(sf::st_difference(lc, tp)), excl = ar(sf::st_difference(land_t, cp)))
  }
  ew <- edge(wp); el <- edge(lp); es <- edge(sp)
  out$incl_w <- ew[["incl"]]; out$excl_w <- ew[["excl"]]
  out$incl_l <- el[["incl"]]; out$excl_l <- el[["excl"]]
  out$incl_s <- es[["incl"]]; out$excl_s <- es[["excl"]]
  out
}

measure_run <- function(run, dem_src, tiles) {
  dem <- terra::rast(dem_src)
  pts <- sf::st_as_sf(run, coords = c("x", "y"), crs = 3005, remove = FALSE)
  # `fly_footprint()` itself for every sized number, never a reimplementation of it.
  fp <- withCallingHandlers(fly_footprint(pts, dem = dem),
                            warning = function(w) invokeRestart("muffleWarning"))
  geo <- sf::st_geometry(fp)
  run$footprint_terrain <- fp$footprint_terrain
  run$height_source <- fp$height_source
  run$height_agl <- fp$height_agl
  run$dem_coverage <- fp$dem_coverage
  run$dem_elev_sd <- fp$dem_elev_sd
  per <- lapply(seq_len(nrow(fp)), function(i) {
    usable <- !sf::st_is_empty(geo[i]) && run$footprint_terrain[i] %in% "dem_agl" &&
      is.finite(run$height_agl[i])
    o <- if (usable) measure_frame(geo[[i]], run[i, ], dem, tiles) else empty_measure()
    as.data.frame(o)
  })
  cbind(sf::st_drop_geometry(run), do.call(rbind, per))
}

todo <- setdiff(unique(runs$run_id), sub("\\.rds$", "", list.files(RUNS_DIR, "\\.rds$")))
pub("  runs to measure: %d of %d", length(todo), length(unique(runs$run_id)))
if (length(todo)) {
  # Stopped explicitly below: `on.exit()` at a script's top level never fires.
  cl <- parallel::makeCluster(WORKERS)
  objs <- list(cap_memory = cap_memory, cells_under = cells_under, raycast = raycast,
               densify = densify, close_ring = close_ring, empty_measure = empty_measure,
               measure_frame = measure_frame, measure_run = measure_run,
               save_atomic = save_atomic, BAND_M = BAND_M, RUNS_DIR = RUNS_DIR)
  res <- tryCatch({
    parallel::clusterCall(cl, function(repo, objs, tiles_path) {
      setwd(repo)
      suppressMessages(pkgload::load_all(quiet = TRUE))
      sf::sf_use_s2(FALSE)
      for (nm in names(objs)) assign(nm, objs[[nm]], envir = globalenv())
      assign("tiles", readRDS(tiles_path), envir = globalenv())
      cap_memory()
      NULL
    }, REPO, objs, LAND_TILES)
    sel_runs <- runs[runs$run_id %in% todo, ]
    parallel::parLapplyLB(cl, split(sel_runs, sel_runs$run_id), function(run, dem_src) {
      out <- tryCatch(measure_run(run, dem_src, tiles),
                      error = function(e) structure(conditionMessage(e), class = "run_error"))
      if (inherits(out, "run_error")) return(paste(run$run_id[1], out))
      save_atomic(out, file.path(RUNS_DIR, paste0(run$run_id[1], ".rds")))
      NA_character_
    }, MRDEM)
  }, finally = parallel::stopCluster(cl))
  errs <- stats::na.omit(unlist(res))
  # Refuse to report over a hole: a run that errored is not a run that found nothing.
  if (length(errs)) stop(length(errs), " runs errored, e.g. ", errs[1])
}
m <- do.call(rbind, lapply(list.files(RUNS_DIR, "\\.rds$", full.names = TRUE), readRDS))
m <- m[m$run_id %in% runs$run_id, ]
stopifnot(setequal(unique(m$run_id), unique(runs$run_id)))

# ---------------------------------------------------------------------------
# Stage 5 — the verdicts, as Amendment 2 states them
# ---------------------------------------------------------------------------

m$elev_w <- m$flying_height - m$height_agl
m$elev_l <- m$elev_w + (m$mean_land - m$mean_all)
m$sea_frac <- m$n_sea / m$n_cells
m$d <- (m$flying_height - m$elev_w) / (m$flying_height - m$elev_l) - 1
lin <- function(a) sqrt(a / m$area_t) - 1
m$err_w <- lin(m$area_w); m$err_l <- lin(m$area_l); m$err_s <- lin(m$area_s)
m$edge_w <- (m$incl_w + m$excl_w) / m$land_t
m$edge_l <- (m$incl_l + m$excl_l) / m$land_t
m$edge_s <- (m$incl_s + m$excl_s) / m$land_t

eligible <- m$footprint_terrain %in% "dem_agl" & m$height_source %in% "reported" &
  is.finite(m$dem_coverage) & m$dem_coverage >= fly_dem_coverage_min()
m$land_border <- eligible & m$n_sea > 0 &
  (m$n_outside_na > 0 | m$n_outside_high > 0.10 * (m$n_sea + m$n_outside_na))
m$rays_failed <- eligible & !m$land_border & (is.na(m$rays_bad) | m$rays_bad > 0)
m$admitted <- eligible & !m$land_border & !m$rays_failed & is.finite(m$area_t) &
  is.finite(m$mean_land)
pub("  frames sampled %d; eligible %d; excluded over a land border %d; ray met nodata %d; admitted %d",
    nrow(m), sum(eligible), sum(m$land_border), sum(m$rays_failed), sum(m$admitted))

co <- m[m$admitted & m$coastal & is.finite(m$d) & m$d > 0, ]
inl <- m[m$admitted & m$set == "inland" & !m$coastal, ]
q <- function(x, p) unname(stats::quantile(x, p, na.rm = TRUE))
pub("  coastal frames with sea in them: %d on %d rolls; inland frames: %d on %d rolls",
    nrow(co), length(unique(co$film_roll)), nrow(inl), length(unique(inl$film_roll)))

# 1. Materiality.
pub("  d (side_W / side_L - 1): median %.4f, 90th %.4f, 95th %.4f, max %.4f",
    stats::median(co$d), q(co$d, .9), q(co$d, .95), max(co$d))
pub("  share of coastal frames with d over 1%%: %.3f", mean(co$d > 0.01))
material <- q(co$d, .95) >= 0.01
pub("  MATERIAL (95th percentile of d at or over 1%%): %s", material)

set.seed(65)
boot_median_diff <- function(d, a, b) {
  x <- abs(d[[a]]) - abs(d[[b]])
  by <- split(x, d$film_roll)
  est <- stats::median(x)
  bs <- vapply(seq_len(N_BOOT), function(i) {
    stats::median(unlist(by[sample(names(by), length(by), replace = TRUE)], use.names = FALSE))
  }, numeric(1))
  c(est = est, lo = q(bs, .025), hi = q(bs, .975))
}
verdict <- function(s) if (s["hi"] < 0) "first better" else if (s["lo"] > 0) "second better" else "tied"
fmt <- function(s) sprintf("%+.5f [%+.5f, %+.5f]", s["est"], s["lo"], s["hi"])

# 2. Area.
a_wl <- boot_median_diff(co, "err_w", "err_l")
a_ws <- boot_median_diff(co, "err_w", "err_s")
pub("  area |err|: W median %.4f, L %.4f, S %.4f (linear, against the ray-cast)",
    stats::median(abs(co$err_w)), stats::median(abs(co$err_l)), stats::median(abs(co$err_s)))
pub("  area, median(|err_W| - |err_L|): %s -> %s", fmt(a_wl),
    c("first better" = "W", "second better" = "L", tied = "tied")[verdict(a_wl)])
pub("  area, median(|err_W| - |err_S|): %s -> %s", fmt(a_ws),
    c("first better" = "W", "second better" = "S", tied = "tied")[verdict(a_ws)])
# 3. Land edge.
e_wl <- boot_median_diff(co, "edge_w", "edge_l")
e_ws <- boot_median_diff(co, "edge_w", "edge_s")
pub("  land edge (incl + excl) / land_T: W median %.4f, L %.4f, S %.4f",
    stats::median(co$edge_w), stats::median(co$edge_l), stats::median(co$edge_s))
pub("  land falsely included: W median %.4f, L %.4f; falsely excluded: W %.4f, L %.4f",
    stats::median(co$incl_w / co$land_t), stats::median(co$incl_l / co$land_t),
    stats::median(co$excl_w / co$land_t), stats::median(co$excl_l / co$land_t))
pub("  land edge, median(e_W - e_L): %s -> %s", fmt(e_wl),
    c("first better" = "W", "second better" = "L", tied = "tied")[verdict(e_wl)])
pub("  land edge, median(e_W - e_S): %s -> %s", fmt(e_ws),
    c("first better" = "W", "second better" = "S", tied = "tied")[verdict(e_ws)])

# 4. The premise: does the sea make W worse than W already is inland?
pub("  W |area err|: coastal median %.4f 95th %.4f | inland median %.4f 95th %.4f",
    stats::median(abs(co$err_w)), q(abs(co$err_w), .95),
    stats::median(abs(inl$err_w)), q(abs(inl$err_w), .95))
area_excess <- q(abs(co$err_w), .95) - q(abs(inl$err_w), .95)
pub("  area: coastal 95th minus inland 95th = %+.4f (remedy threshold +0.01)", area_excess)
# The inland land-edge counterpart is the whole footprint, since inland all ground is land.
inl_edge <- (inl$incl_w + inl$excl_w) / inl$land_t
edge_excess <- q(co$edge_w, .95) - q(inl_edge, .95)
pub("  land edge: W coastal 95th %.4f, inland 95th %.4f, excess %+.4f (remedy threshold +0.02, i.e. 1%% of width as area)",
    q(co$edge_w, .95), q(inl_edge, .95), edge_excess)
pub("  PREMISE: remedy warranted on area %s, on land edge %s",
    area_excess > 0.01, edge_excess > 0.02)

# Signed, by sea fraction — which way W errs.
bands <- cut(co$sea_frac, c(0, .1, .25, .5, .75, 1), include.lowest = TRUE)
co$sea_frac_band <- as.character(bands)
for (b in levels(bands)) {
  x <- co[co$sea_frac_band %in% b, ]
  if (!nrow(x)) next
  pub("  sea %-10s n=%4d d %.4f | signed err W %+.4f L %+.4f S %+.4f | edge W %.4f L %.4f | dem_elev_sd %.1f",
      b, nrow(x), stats::median(x$d), stats::median(x$err_w), stats::median(x$err_l),
      stats::median(x$err_s), stats::median(x$edge_w), stats::median(x$edge_l),
      stats::median(x$dem_elev_sd))
}
pub("  inland dem_elev_sd median %.1f", stats::median(inl$dem_elev_sd))

# Secondary: spacing, with its bias stated before the run (Amendment 2) — toward L over sea.
m$f_m <- m$focal_length / 1000
roll_med <- stats::ave(m$base, m$film_roll, FUN = function(b) stats::median(b, na.rm = TRUE))
m$base_ok <- is.finite(m$base) & m$base >= 0.5 * roll_med & m$base <= 1.5 * roll_med
m$p_w <- 1 - m$base / (FORMAT_M * m$height_agl / m$f_m)
sp <- m[m$admitted & m$base_ok, ]
spc <- sp[sp$coastal & is.finite(sp$d) & sp$d > 0, ]
xd <- spc$d - stats::ave(spc$d, spc$film_roll)
yd <- spc$p_w - stats::ave(spc$p_w, spc$film_roll)
pub("  spacing (secondary): inland median p_W %.3f; coastal within-roll slope of p_W on d %+.3f (n=%d); within-roll sd of d %.4f",
    stats::median(sp$p_w[!sp$coastal]), sum(xd * yd) / sum(xd^2), nrow(spc), stats::sd(xd))

keep <- c("airp_id", "run_id", "stratum", "set", "coastal", "photo_year", "film_roll",
          "frame_number", "scale_n", "focal_length", "flying_height", "base",
          "footprint_terrain", "height_source", "height_agl", "dem_coverage", "dem_elev_sd",
          "n_cells", "n_sea", "n_band", "n_sea_band", "n_outside_high", "n_outside_na",
          "mean_all", "mean_land", "sea_median", "rays_bad", "area_t", "area_w", "area_l",
          "area_s", "land_t", "incl_w", "excl_w", "incl_l", "excl_l", "incl_s", "excl_s",
          "land_border", "admitted")
out <- m[order(m$run_id, m$frame_number), keep]
num <- vapply(out, is.double, logical(1))
out[num] <- lapply(out[num], function(x) signif(x, 10))
if (SMOKE) {
  message("smoke run: nothing written")
  quit(save = "no")
}
write_if_changed(out, OUT_FRAMES)
write_if_changed(POP, OUT_POP)
write_if_changed(sites_out, OUT_SITES)
