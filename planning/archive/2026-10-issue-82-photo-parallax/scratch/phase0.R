D <- "/private/tmp/claude-501/-Users-airvine-Projects-repo-fly/0e762a6d-f932-4614-9d5b-0fc1d445cb10/scratchpad/p82"
pkgload::load_all(quiet = TRUE)
suppressMessages({library(sf); library(terra)})
sf_use_s2(FALSE); terra::gdalCache(128); terraOptions(progress = 0)
fns_from <- function(path, names) {
  for (e in parse(path, keep.source = FALSE)) {
    if (is.call(e) && identical(e[[1]], as.name("<-")) && is.name(e[[2]]) &&
        as.character(e[[2]]) %in% names && is.call(e[[3]]) &&
        identical(e[[3]][[1]], as.name("function"))) eval(e, envir = globalenv())
  }
}
fns_from("data-raw/dem_measure-coastal_water.R", c("raycast"))
source(file.path(D, "lib.R"))
BUCKET <- "/vsicurl/https://canelevation-dem.s3.ca-central-1.amazonaws.com/mrdem-30/"
DTM <- rast(paste0(BUCKET, "mrdem-30-dtm.tif")); DSM <- rast(paste0(BUCKET, "mrdem-30-dsm.tif"))
FORMAT_MM <- 228.6

roll_meta <- function(roll) {
  f <- file.path(D, "rolls", paste0(roll, ".rds"))
  if (!file.exists(f)) {
    dir.create(dirname(f), showWarnings = FALSE)
    r <- bcdata::collect(bcdata::filter(
      bcdata::bcdc_query_geodata("WHSE_IMAGERY_AND_BASE_MAPS.AIMG_PHOTO_CENTROIDS_SP"), FILM_ROLL == roll))
    names(r) <- tolower(names(r))
    saveRDS(r, f)
  }
  readRDS(f)
}

vri_over <- function(bb) {
  poly <- st_as_sfc(st_bbox(c(xmin = bb[1], ymin = bb[2], xmax = bb[3], ymax = bb[4]), crs = st_crs(3005)))
  v <- bcdata::bcdc_query_geodata("WHSE_FOREST_VEGETATION.VEG_COMP_LYR_R1_POLY") |>
    bcdata::filter(bcdata::INTERSECTS(poly)) |>
    bcdata::select(PROJ_AGE_1, PROJ_HEIGHT_1, PROJECTED_DATE, BCLCS_LEVEL_2) |>
    bcdata::collect()
  v
}

measure_pair <- function(row) {
  rm <- roll_meta(row$film_roll)
  a_row <- rm[rm$frame_number == row$frame_number, ][1, ]
  b_row <- rm[rm$frame_number == row$frame_number + 1, ][1, ]
  th <- fly_fetch(rbind(a_row, b_row), type = "thumbnail", dest_dir = file.path(D, "thumbs"))
  if (!all(th$success)) return(list(status = "no_thumbnail"))
  a <- read_gray(th$dest[1]); b <- read_gray(th$dest[2])
  nn <- pmin(dim(a), dim(b)); a <- a[seq_len(nn[1]), seq_len(nn[2])]; b <- b[seq_len(nn[1]), seq_len(nn[2])]
  xyA <- st_coordinates(st_transform(a_row, 3005))[1, ]
  xyB <- st_coordinates(st_transform(b_row, 3005))[1, ]
  bearing <- atan2(xyB[1] - xyA[1], xyB[2] - xyA[2])
  sn <- as.numeric(sub("1:", "", a_row$scale)); f_mm <- a_row$focal_length
  pred_px <- sqrt(sum((xyB - xyA)^2)) / (sn * FORMAT_MM / ncol(a) / 1000)
  gs <- global_shift(a, b, pred_px)
  if (!is.finite(gs[["row"]])) return(list(status = "no_global", gs = gs))
  gp <- patch_shifts(a, b, gs)
  H <- a_row$flying_height
  half <- FORMAT_MM / 2000 * sn
  e3005 <- ext(xyA[1] - 2.2 * half, xyA[1] + 2.2 * half, xyA[2] - 2.2 * half, xyA[2] + 2.2 * half)
  e_dem <- ext(project(vect(e3005, crs = "EPSG:3005"), crs(DTM)))
  wt <- crop(DTM, e_dem) * 1; ws <- crop(DSM, e_dem) * 1
  e_w <- stats::median(at_xy(wt, rbind(xyA)), na.rm = TRUE)
  ratio <- (H - e_w) / (sn * f_mm / 1000)
  band <- fly_height_ratio_band()
  f_px <- f_mm / (FORMAT_MM / ncol(a))
  gsd <- (H - e_w) / f_px
  patch_m <- 64 * gsd
  wts <- smooth_to(wt, patch_m); wss <- smooth_to(ws, patch_m)
  u <- c(gs[["col"]], -gs[["row"]]); u <- u / sqrt(sum(u^2))
  gp$p <- gp$dc * u[1] + (-gp$dr) * u[2]
  gp$q <- -gp$dc * u[2] + (-gp$dr) * u[1]
  gp$xn <- (gp$c - (ncol(a) + 1) / 2) / (ncol(a) / 2); gp$yn <- ((nrow(a) + 1) / 2 - gp$r) / (nrow(a) / 2)
  good <- is.finite(gp$p) & gp$pk >= 0.1
  X <- poly2(gp$xn, gp$yn)
  fit_r2 <- function(d) {
    ok <- good & is.finite(d)
    if (sum(ok) < 30) return(NA_real_)
    y <- 1 / gp$p[ok]
    fit <- stats::lm.fit(cbind(1, X[ok, ], d[ok]), y)
    1 - sum(fit$residuals^2) / sum((y - mean(y))^2)
  }
  # Registration to terrain: offset, rotation about A's centroid and scale, chosen on the DTM
  # fit of all matched patches. Never on C.
  tf <- function(xy, par) {
    d <- sweep(xy, 2, xyA); cr <- cos(par[3] * pi / 180); sr <- sin(par[3] * pi / 180)
    d <- cbind(d[, 1] * cr + d[, 2] * sr, -d[, 1] * sr + d[, 2] * cr) * (1 + par[4] / 100)
    sweep(d, 2, xyA + par[1:2], "+")
  }
  res <- list()
  for (mir in c(FALSE, TRUE)) {
    v <- img_vec(gp, nrow(a), ncol(a), mirror = mir)
    thz <- image_theta(gs, bearing, mirror = mir)
    pl <- place(v, thz, xyA, H, e_w, f_px, wt)
    offs <- expand.grid(dE = seq(-600, 600, 60), dN = seq(-600, 600, 60))
    r2 <- vapply(seq_len(nrow(offs)), function(k) fit_r2(at_xy(wts, tf(pl$xy, c(offs$dE[k], offs$dN[k], 0, 0)))), numeric(1))
    if (all(is.na(r2))) { res[[if (mir) "mirror" else "normal"]] <- list(pl = pl, par = c(0, 0, 0, 0), r2 = NA); next }
    k <- which.max(r2)
    o <- stats::optim(c(offs$dE[k], offs$dN[k], 0, 0), function(par) {
      if (abs(par[3]) > 8 || abs(par[4]) > 8) return(1)
      v <- fit_r2(at_xy(wts, tf(pl$xy, par))); if (is.na(v)) 1 else -v
    }, control = list(maxit = 300, parscale = c(30, 30, 1, 1)))
    res[[if (mir) "mirror" else "normal"]] <- list(pl = pl, par = o$par, r2 = -o$value)
  }
  mir <- isTRUE(res$mirror$r2 > res$normal$r2)
  R <- res[[if (mir) "mirror" else "normal"]]
  xy <- tf(R$pl$xy, R$par)
  gp$E <- xy[, 1]; gp$N <- xy[, 2]
  gp$dtm <- at_xy(wts, xy); gp$dsm <- at_xy(wss, xy); gp$C <- gp$dsm - gp$dtm
  gp$ray_bad <- R$pl$bad
  list(status = "ok", gp = gp, gs = gs, info = c(airp_id = row$airp_id, year = a_row$photo_year,
       sn = sn, H = H, e_w = e_w, ratio = ratio, in_band = ratio >= band[1] & ratio <= band[2],
       gsd = gsd, patch_m = patch_m, bearing = bearing * 180 / pi, mirror = mir,
       r2_normal = res$normal$r2, r2_mirror = res$mirror$r2, pred_px = pred_px,
       offE = R$par[1], offN = R$par[2], rot = R$par[3], scl = R$par[4]),
       roll = row$film_roll, frame = row$frame_number)
}

# Nuisance only: no coefficient on C is fitted anywhere below.
nuisance <- function(m) {
  g <- m$gp; ok <- is.finite(g$p) & g$pk >= 0.1 & is.finite(g$dtm) & is.finite(g$C) & !g$ray_bad
  g <- g[ok, ]
  X <- poly2(g$xn, g$yn)
  q_sd <- stats::sd(resid_on(g$q, X), na.rm = TRUE)
  fit <- stats::lm.fit(cbind(1, X, g$dtm), 1 / g$p)
  bD <- fit$coefficients[length(fit$coefficients)]
  res_m <- stats::sd(fit$residuals) / abs(bD)
  dperp <- resid_on(g$dtm, X); cperp <- resid_on(g$C, X)
  cpp <- resid_on(g$C, cbind(X, g$dtm))
  se_b <- res_m / sqrt(sum(cpp^2))
  data.frame(n = nrow(g), peak_med = stats::median(g$pk), q_sd_px = q_sd, res_m = res_m,
             dtm_surv = stats::var(dperp) / stats::var(g$dtm), C_surv = stats::var(cperp) / stats::var(g$C),
             r_CD = stats::cor(cperp, dperp), sd_C = stats::sd(g$C), mean_C = mean(g$C), se_b_naive = se_b)
}

pairs <- readRDS(file.path(D, "phase0_pairs.rds"))
out <- list()
for (i in seq_len(nrow(pairs))) {
  f <- file.path(D, "m0", paste0(pairs$airp_id[i], ".rds"))
  dir.create(dirname(f), showWarnings = FALSE)
  if (!file.exists(f)) {
    m <- tryCatch(measure_pair(pairs[i, ]), error = function(e) list(status = paste("error:", conditionMessage(e))))
    saveRDS(m, f)
  }
  m <- readRDS(f)
  if (!identical(m$status, "ok")) { message(pairs$film_roll[i], " ", m$status, " ", if (is.numeric(m$gs)) paste(signif(m$gs, 3), collapse = " ") else ""); next }
  nu <- nuisance(m)
  inf <- m$info
  out[[i]] <- cbind(data.frame(roll = m$roll, frame = m$frame, year = inf[["year"]], sn = inf[["sn"]],
                               ratio = round(inf[["ratio"]], 2), gsd = round(inf[["gsd"]], 2), shift = round(sqrt(sum(m$gs[1:2]^2)), 1),
                               gpeak = round(m$gs[["peak"]], 3), n1 = m$gs[["n1"]], mirror = inf[["mirror"]],
                               r2n = round(inf[["r2_normal"]], 3), r2m = round(inf[["r2_mirror"]], 3),
                               pred = round(inf[["pred_px"]]), off = sprintf("%+.0f,%+.0f", inf[["offE"]], inf[["offN"]]),
                               rot = round(inf[["rot"]], 1), scl = round(inf[["scl"]], 1)),
                    signif(nu, 3))
}
tab <- do.call(rbind, out)
options(width = 250); print(tab, row.names = FALSE)
saveRDS(tab, file.path(D, "phase0_tab.rds"))
