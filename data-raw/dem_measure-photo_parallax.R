# dem_measure-photo_parallax.R — what surface did the camera see at the photo date? (fly#82)
#
# fly#80 found that sizing a frame from MRDEM's DSM rather than its DTM does not matter, and left
# one question answered only by a model: was the canopy the DSM carries there when the photo was
# taken? VRI stand origin with a linear height-age curve said a DSM would be worse on 15.1% of the
# 1970s frames where canopy matters. This script asks the photos instead.
#
# Two frames adjacent by number see the same ground from two places, so a point's image moves
# between them by an amount that depends on its height: x-parallax p = f B / (H - h). Inside one
# overlap, B, f and H are shared, so the parallax DIFFERENCE between two patches measures their
# height difference whatever the air base is. The catalogue's centroid spacing — interpolated
# before the 1990s, wrong by x1.7 on at least one pair — is therefore never used as B. Per patch,
# the height the photo implies is regressed on the DTM and on `C = DSM - DTM`; the slope on C is
# how much of today's canopy the camera saw.
#
# That slope is not read against 0 and 1. The matcher responds to crown texture, placement blurs
# C, and on radar cells MRDEM's DTM sits under true ground by an amount that grows with C (fly#80,
# LidarBC). So it is rescaled between two references:
#   bare  — the slope when the camera saw bare ground: 0.146 on radar cells, from fly#80's
#           LidarBC tiles, and 0 on lidar cells, where the DTM is lidar ground;
#   old   — measured in the same pairs, on stands VRI dates as 80 or more years old at the
#           photo: canopy then, much as now.
# phi = (b_mid - bare) / (b_old - bare) is the share of today's canopy the camera saw on the
# stands between, in units of an old stand, per MRDEM source. fly#80's VRI model predicts it
# from the same patches, and the difference D is the verdict. A control on ground young at the
# photo was planned and dropped: classed cleanly, the pilots held two such patches in eleven
# pairs (Amendment B).
#
# The rule — every threshold, class, gate and verdict — was fixed in fly#82's planning findings
# ("Decision rule", amended twice — A and B — before any sampled pair was read). Read it
# before changing anything here.
#
# Everything is public: the BC Data Catalogue's airphoto centroids, thumbnails and VRI, and
# NRCan's MRDEM-30.
#
# Usage, from the repo root, after `dem_measure-canopy_height.R` has built its census:
#   Rscript data-raw/dem_measure-photo_parallax.R
#
#   Stage 0  inputs and their versions
#   Stage 1  synthetic controls: a known surface, known tilt, known placement error, JPEG 85
#   Stage 2  the sample: number-adjacent pairs where canopy matters, per decade
#   Stage 3  per pair: match, place, register, sample the DEM, class from VRI (cached)
#   Stage 4  the verdicts; write `inst/extdata/dem_parallax_*.csv`
#
#   FLY_PARALLAX_SMOKE=1 runs a handful of pairs into a separate cache and writes nothing
#   FLY_PARALLAX_STOP=<n> stops after stage n

pkgload::load_all(quiet = TRUE)
suppressMessages({
  library(sf)
  library(terra)
})
sf::sf_use_s2(FALSE)
terra::gdalCache(128)
terra::terraOptions(memfrac = 0.05, memmax = 1, progress = 0)

SMOKE      <- nzchar(Sys.getenv("FLY_PARALLAX_SMOKE"))
STOP_AFTER <- as.integer(Sys.getenv("FLY_PARALLAX_STOP", "99"))
CACHE      <- if (SMOKE) "data-raw/.cache/photo_parallax_smoke" else "data-raw/.cache/photo_parallax"
THUMBS     <- "data-raw/.cache/photo_parallax/thumbs"       # thumbnails are shared by both
ROLLS      <- "data-raw/.cache/photo_parallax/rolls"
BUCKET     <- "https://canelevation-dem.s3.ca-central-1.amazonaws.com"
MRDEM_DTM  <- paste0("/vsicurl/", BUCKET, "/mrdem-30/mrdem-30-dtm.tif")
MRDEM_DSM  <- paste0("/vsicurl/", BUCKET, "/mrdem-30/mrdem-30-dsm.tif")
CENSUS_DIR <- "data-raw/.cache/dem_canopy"
REPO       <- normalizePath(".")
WORKERS    <- as.integer(Sys.getenv("FLY_PARALLAX_WORKERS", "3"))
FORMAT_MM  <- 228.6
ALG        <- "a6"                  # the algorithm tag every cache below carries

dir.create(CACHE, recursive = TRUE, showWarnings = FALSE)
dir.create(THUMBS, recursive = TRUE, showWarnings = FALSE)
dir.create(ROLLS, recursive = TRUE, showWarnings = FALSE)

# Helpers from the fly#80 and fly#65 scripts, evaluated rather than copied: both are closed
# measurements and are not edited, and a second copy would drift. `fns_from()` itself is the one
# function taken by hand, through the same parse.
local({
  for (e in parse("data-raw/dem_measure-canopy_height.R", keep.source = FALSE)) {
    if (is.call(e) && identical(e[[1]], as.name("<-")) && identical(e[[2]], as.name("fns_from"))) {
      eval(e, envir = globalenv())
    }
  }
})
fns_from("data-raw/dem_measure-canopy_height.R",
         c("write_if_changed", "save_atomic", "pub", "head_of", "%||%"))
fns_from("data-raw/dem_measure-coastal_water.R", "raycast")

# ---------------------------------------------------------------------------
# The instrument
# ---------------------------------------------------------------------------

# Band arithmetic, not `mean()`: in a PSOCK worker terra is loaded but not attached, so base
# `mean()` does not dispatch on a SpatRaster and returns NA — every colour thumbnail then
# failed with "argument of length 0" (smoke run, bcc405 55), while the same pair passed in the
# main process.
read_gray <- function(p) {
  r <- terra::rast(p)
  g <- if (terra::nlyr(r) >= 3) (r[[1]] + r[[2]] + r[[3]]) / 3 else r[[1]]
  m <- suppressWarnings(terra::as.matrix(g, wide = TRUE))
  storage.mode(m) <- "double"
  m
}
hann2 <- function(nr, nc) {
  outer(0.5 - 0.5 * cos(2 * pi * (0:(nr - 1)) / (nr - 1)),
        0.5 - 0.5 * cos(2 * pi * (0:(nc - 1)) / (nc - 1)))
}
down <- function(m, k) {
  nr <- nrow(m) %/% k
  nc <- ncol(m) %/% k
  a <- array(m[seq_len(nr * k), seq_len(nc * k)], c(k, nr, k, nc))
  apply(a, c(2, 4), mean)
}

# Normalised phase correlation of two equal-size windows. The surface is 1 for identical
# windows and near 0 for unrelated ones.
pc_surface <- function(a, b) {
  w <- hann2(nrow(a), ncol(a))
  a <- (a - mean(a)) / max(stats::sd(a), 1e-9) * w
  b <- (b - mean(b)) / max(stats::sd(b), 1e-9) * w
  R <- stats::fft(b) * Conj(stats::fft(a))
  R <- R / pmax(Mod(R), 1e-12)
  Re(stats::fft(R, inverse = TRUE)) / length(R)
}
# The shift s with b[i + s] ~ a[i], sub-pixel by a parabola through the peak on each axis.
phase_corr <- function(a, b) {
  r <- pc_surface(a, b)
  nr <- nrow(r)
  nc <- ncol(r)
  k <- which.max(r)
  i <- (k - 1) %% nr
  j <- (k - 1) %/% nr
  g <- function(ii, jj) r[(ii %% nr) + 1, (jj %% nc) + 1]
  par <- function(y0, y1, y2) {
    d <- y0 - 2 * y1 + y2
    if (d == 0) 0 else 0.5 * (y0 - y2) / d
  }
  si <- i + par(g(i - 1, j), g(i, j), g(i + 1, j))
  sj <- j + par(g(i, j - 1), g(i, j), g(i, j + 1))
  if (si > nr / 2) si <- si - nr
  if (sj > nc / 2) sj <- sj - nc
  c(row = si, col = sj, peak = r[k])
}

MARGIN  <- 50      # px kept clear of fiducials, the data panel and the scan edge
PEAK    <- 0.1     # a patch match is used only at or above this correlation peak

# Per-patch 2-D shift on a grid over A: 128 px windows seeded by `gs`, then (pass 2) 64 px
# windows seeded by the 3x3 median of pass 1, so relief parallax far from the global shift is
# followed rather than lost.
patch_shifts <- function(a, b, gs, step = 32, win = 64, win1 = 128, pass2 = TRUE) {
  n <- nrow(a)
  m <- ncol(a)
  h <- win / 2
  h1 <- win1 / 2
  inb <- function(rr, cc, hh) {
    rr - hh >= MARGIN & rr + hh <= n - MARGIN & cc - hh >= MARGIN & cc + hh <= m - MARGIN
  }
  grid <- expand.grid(r = seq(MARGIN + h1, n - MARGIN - h1, by = step),
                      c = seq(MARGIN + h1, m - MARGIN - h1, by = step))
  grid <- grid[inb(grid$r + gs[["row"]], grid$c + gs[["col"]], h1), ]
  if (!nrow(grid)) return(NULL)
  one <- function(i, j, si, sj, hh) {
    ib0 <- round(i + si)
    jb0 <- round(j + sj)
    if (!inb(ib0, jb0, hh)) return(c(NA, NA, 0))
    pa <- a[(i - hh):(i + hh - 1), (j - hh):(j + hh - 1)]
    pb <- b[(ib0 - hh):(ib0 + hh - 1), (jb0 - hh):(jb0 + hh - 1)]
    if (stats::sd(pa) < 2 || stats::sd(pb) < 2) return(c(NA, NA, 0))
    s <- phase_corr(pa, pb)
    c(ib0 - i + s[["row"]], jb0 - j + s[["col"]], s[["peak"]])
  }
  p1 <- t(vapply(seq_len(nrow(grid)), function(k) {
    one(grid$r[k], grid$c[k], gs[["row"]], gs[["col"]], h1)
  }, numeric(3)))
  if (!pass2) {
    grid$dr <- p1[, 1]
    grid$dc <- p1[, 2]
    grid$pk <- p1[, 3]
    return(grid)
  }
  ok1 <- is.finite(p1[, 1]) & p1[, 3] >= PEAK
  seed <- t(vapply(seq_len(nrow(grid)), function(k) {
    nb <- ok1 & abs(grid$r - grid$r[k]) <= step & abs(grid$c - grid$c[k]) <= step
    if (sum(nb) < 3) return(c(gs[["row"]], gs[["col"]]))
    c(stats::median(p1[nb, 1]), stats::median(p1[nb, 2]))
  }, numeric(2)))
  p2 <- t(vapply(seq_len(nrow(grid)), function(k) {
    one(grid$r[k], grid$c[k], seed[k, 1], seed[k, 2], h)
  }, numeric(3)))
  grid$dr <- p2[, 1]
  grid$dc <- p2[, 2]
  grid$pk <- p2[, 3]
  grid
}

# Global shift of B against A. Relief smears the whole-frame peak and centroid spacing can be
# wrong by x1.7 (bc85054 162, Phase 0), so neither the top peak nor a tight magnitude window is
# trusted: the ten highest local maxima at 1/4 resolution within [0.25, 3] of the spacing's
# prediction are each tried as a seed for 128 px patch matching, the one most patches confirm
# wins, and the global shift is those patches' median.
global_shift <- function(a, b, pred_px, n_cand = 10) {
  n <- nrow(a)
  m <- ncol(a)
  ia <- down(a[(MARGIN + 1):(n - MARGIN), (MARGIN + 1):(m - MARGIN)], 4)
  ib <- down(b[(MARGIN + 1):(n - MARGIN), (MARGIN + 1):(m - MARGIN)], 4)
  r <- pc_surface(ia, ib)
  nr <- nrow(r)
  nc <- ncol(r)
  di <- 0:(nr - 1)
  di[di > nr / 2] <- di[di > nr / 2] - nr
  dj <- 0:(nc - 1)
  dj[dj > nc / 2] <- dj[dj > nc / 2] - nc
  mag <- 4 * sqrt(outer(di^2, dj^2, "+"))
  sh <- function(x, i, j) x[((seq_len(nr) - 1 + i) %% nr) + 1, ((seq_len(nc) - 1 + j) %% nc) + 1]
  mx <- r
  for (i in -2:2) for (j in -2:2) if (i || j) mx <- pmax(mx, sh(r, i, j))
  cand <- which(r == mx & mag >= 0.25 * pred_px & mag <= 3 * pred_px)
  cand <- cand[order(r[cand], decreasing = TRUE)][seq_len(min(n_cand, length(cand)))]
  best <- NULL
  best_n <- 0
  for (k in cand) {
    s0 <- c(row = 4 * di[(k - 1) %% nr + 1], col = 4 * dj[(k - 1) %/% nr + 1])
    p1 <- patch_shifts(a, b, s0, pass2 = FALSE, step = 64)
    nk <- if (is.null(p1)) 0 else sum(p1$pk >= PEAK, na.rm = TRUE)
    if (nk > best_n) {
      best_n <- nk
      best <- s0
    }
  }
  fail <- c(row = NA, col = NA, peak = 0, n1 = best_n)
  if (best_n < 8) return(fail)
  p1 <- patch_shifts(a, b, best, pass2 = FALSE)
  g <- p1[is.finite(p1$dr) & p1$pk >= PEAK, ]
  if (nrow(g) < 20) return(fail)
  c(row = stats::median(g$dr), col = stats::median(g$dc), peak = stats::median(g$pk), n1 = nrow(g))
}

# Image vector of each patch centre from the principal point, taken as the thumbnail centre:
# x right, y up, thumbnail px. `mirror` flips x — a scan read from the other side.
img_vec <- function(r, cc, nr, nc, mirror = FALSE) {
  x <- cc - (nc + 1) / 2
  y <- (nr + 1) / 2 - r
  if (mirror) x <- -x
  cbind(x, y)
}
# Image-up azimuth on the ground: the camera moves A -> B along the bearing of B's centroid from
# A's, and content moves the opposite way in the image. That fixes the image's rotation on the
# ground including the 180-degree ambiguity fly#26 found the geometry alone cannot.
image_theta <- function(gs, bearing, mirror = FALSE) {
  dx <- gs[["col"]]
  dy <- -gs[["row"]]
  if (mirror) dx <- -dx
  bearing - atan2(-dx, -dy)
}
rot_ground <- function(v, th) {
  cbind(v[, 1] * cos(th) + v[, 2] * sin(th), -v[, 1] * sin(th) + v[, 2] * cos(th))
}
at_xy <- function(r, xy) {
  p <- sf::sf_project("EPSG:3005", terra::crs(r), xy, keep = TRUE)
  terra::extract(r, p, method = "bilinear")[, 1]
}
# DEM at the scale of a patch, weighted as the matcher weights it: phase correlation applies a
# Hann window to each 64 px patch, so the DEM is read through a Hann kernel of the patch's
# ground size, not a boxcar. The boxcar overstated the canopy slope by 13-17% on synthetic
# frames with uniform canopy (Amendment B).
hann_w <- function(k) {
  h <- 0.5 - 0.5 * cos(2 * pi * (0:(k - 1)) / (k - 1))
  w <- outer(h, h)
  w / sum(w)
}
smooth_to <- function(r, patch_m) {
  k <- max(3, round(patch_m / terra::res(r)[1]))
  if (k %% 2 == 0) k <- k + 1
  terra::focal(r, w = hann_w(k), fun = "sum", na.rm = FALSE)
}
poly2 <- function(xn, yn) cbind(xn = xn, yn = yn, xn2 = xn^2, yn2 = yn^2, xnyn = xn * yn)
resid_on <- function(y, X) {
  ok <- is.finite(y) & stats::complete.cases(X)
  r <- rep(NA_real_, length(y))
  r[ok] <- stats::lm.fit(cbind(1, X[ok, , drop = FALSE]), y[ok])$residuals
  r
}
fit_r2 <- function(y, X) {
  ok <- is.finite(y) & stats::complete.cases(X)
  if (sum(ok) < 30) return(NA_real_)
  e <- stats::lm.fit(cbind(1, X[ok, , drop = FALSE]), y[ok])$residuals
  1 - sum(e^2) / sum((y[ok] - mean(y[ok]))^2)
}
# Rigid adjustment of placed points about `centre`: offset (m), rotation (degrees), scale (%).
adjust <- function(xy, centre, par) {
  d <- sweep(xy, 2, centre)
  cr <- cos(par[3] * pi / 180)
  sr <- sin(par[3] * pi / 180)
  d <- cbind(d[, 1] * cr + d[, 2] * sr, -d[, 1] * sr + d[, 2] * cr) * (1 + par[4] / 100)
  sweep(d, 2, centre + par[1:2], "+")
}
REG_BOUND <- 8      # rotation (degrees) and scale (%) the registration may search

# Rotation is not searched by default (algorithm a3): the image's rotation comes from the measured shift and
# the flight line's bearing, and a free rotation let the search buy fit with a -7.5 degree turn
# and a 6% scale change on a synthetic whose true answer was 0 and 0 (bc78008 184: canopy slope
# 0.843 with rotation, 1.122 without; Amendment B).
# Match, place and register one pair. `a`, `b` are grey matrices; `geom` carries the A and B
# centroids (EPSG:3005), H, the scale denominator and focal length; `wt`, `ws` are DTM and DSM
# windows in memory. Registration — offset, rotation and scale, normal and mirrored — maximises
# the DTM fit of every matched patch's parallax. It never sees C.
measure_core <- function(a, b, geom, wt, ws, register = TRUE, reg_on = "open", rotate = FALSE) {
  nn <- pmin(dim(a), dim(b))
  a <- a[seq_len(nn[1]), seq_len(nn[2])]
  b <- b[seq_len(nn[1]), seq_len(nn[2])]
  xyA <- geom$xyA
  xyB <- geom$xyB
  bearing <- atan2(xyB[1] - xyA[1], xyB[2] - xyA[2])
  pitch <- FORMAT_MM / ncol(a)
  pred_px <- sqrt(sum((xyB - xyA)^2)) / (geom$sn * pitch / 1000)
  gs <- global_shift(a, b, pred_px)
  if (!is.finite(gs[["row"]])) return(list(status = "no_global", gs = gs))
  gp <- patch_shifts(a, b, gs)
  e_w <- at_xy(wt, rbind(xyA))
  if (!is.finite(e_w)) return(list(status = "no_dem", gs = gs))
  f_px <- geom$f_mm / pitch
  gsd <- (geom$H - e_w) / f_px
  patch_m <- 64 * gsd
  wts <- smooth_to(wt, patch_m)
  wss <- smooth_to(ws, patch_m)
  u <- c(gs[["col"]], -gs[["row"]])
  u <- u / sqrt(sum(u^2))
  gp$p <- gp$dc * u[1] + (-gp$dr) * u[2]
  gp$q <- -gp$dc * u[2] + (-gp$dr) * u[1]
  gp$xn <- (gp$c - (ncol(a) + 1) / 2) / (ncol(a) / 2)
  gp$yn <- ((nrow(a) + 1) / 2 - gp$r) / (nrow(a) / 2)
  matched <- is.finite(gp$p) & gp$pk >= PEAK & gp$p > 0
  X <- poly2(gp$xn, gp$yn)
  y <- ifelse(matched, 1 / gp$p, NA_real_)
  res <- list()
  rcs <- lapply(c(FALSE, TRUE), function(mir) {
    v <- img_vec(gp$r, gp$c, nrow(a), ncol(a), mirror = mir)
    th <- image_theta(gs, bearing, mirror = mir)
    ring <- sweep(rot_ground(v, th) * (geom$H - e_w) / f_px, 2, xyA, "+")
    raycast(ring, xyA, geom$H, e_w, wt, step = 5, n_bisect = 20)
  })
  # Register on open ground — C under 2 m at the unregistered placement — where there are at
  # least 30 such patches: on forest, seen canopy lowers a DTM-only fit and the search moves the
  # grid to wherever canopy hurts least, which halved the synthetic canopy slope (Amendment B).
  # Where open ground is scarce, register with C as a free regressor, which is symmetric in
  # canopy seen and not seen. One objective and one patch set serve both placements — open at
  # BOTH — so the mirror choice is never made by a difference in what was scored (code-check
  # rounds 1-3: objectives, then patch sets, then the placement the set was chosen on).
  open_at <- function(rc) {
    c0 <- at_xy(wss, rc$xy) - at_xy(wts, rc$xy)
    is.finite(c0) & c0 < 2
  }
  # Patches whose ray met the DTM at both placements; the C-free branch scores on these too, or
  # a ray that failed at one placement only made the two R² different sets (code-check round 4).
  both <- matched & !rcs[[1]]$bad & !rcs[[2]]$bad
  open_ok <- both & open_at(rcs[[1]]) & open_at(rcs[[2]])
  use_open <- reg_on == "open" && sum(open_ok) >= 30
  yr <- ifelse(open_ok, y, NA_real_)
  yb <- ifelse(both, y, NA_real_)
  for (mir in c(FALSE, TRUE)) {
    rc <- rcs[[if (mir) 2 else 1]]
    score <- if (use_open) {
      function(par) fit_r2(yr, cbind(X, at_xy(wts, adjust(rc$xy, xyA, par))))
    } else {
      function(par) {
        q <- adjust(rc$xy, xyA, par)
        d <- at_xy(wts, q)
        fit_r2(yb, cbind(X, d, at_xy(wss, q) - d))
      }
    }
    key <- if (mir) "mirror" else "normal"
    if (!register) {
      res[[key]] <- list(xy = rc$xy, bad = rc$bad, par = c(0, 0, 0, 0),
                         r2 = if (mir) -Inf else score(c(0, 0, 0, 0)), open = use_open)
      next
    }
    offs <- expand.grid(dE = seq(-600, 600, 60), dN = seq(-600, 600, 60))
    r2 <- vapply(seq_len(nrow(offs)), function(k) score(c(offs$dE[k], offs$dN[k], 0, 0)),
                 numeric(1))
    if (all(is.na(r2))) {
      res[[key]] <- list(xy = rc$xy, bad = rc$bad, par = c(0, 0, 0, 0), r2 = NA_real_,
                         open = use_open)
      next
    }
    k <- which.max(r2)
    o <- stats::optim(c(offs$dE[k], offs$dN[k], 0, 0), function(par) {
      if (!rotate) par[3] <- 0
      if (any(abs(par[3:4]) > REG_BOUND)) return(1)
      s <- score(par)
      if (is.na(s)) 1 else -s
    }, control = list(maxit = 300, parscale = c(30, 30, 1, 1)))
    if (!rotate) o$par[3] <- 0
    res[[key]] <- list(xy = rc$xy, bad = rc$bad, par = o$par, r2 = -o$value, open = use_open)
  }
  mirror <- isTRUE(res$mirror$r2 > res$normal$r2) ||
    (!is.finite(res$normal$r2) && is.finite(res$mirror$r2))
  R <- res[[if (mirror) "mirror" else "normal"]]
  if (register && !is.finite(R$r2)) return(list(status = "no_registration", gs = gs))
  xy <- adjust(R$xy, xyA, R$par)
  gp$E <- xy[, 1]
  gp$N <- xy[, 2]
  gp$dtm <- at_xy(wts, xy)
  gp$C <- at_xy(wss, xy) - gp$dtm
  # DTM gradient at the patch, for the nuisance: residual placement error puts grad(DTM) . delta
  # into the DTM regressor, unevenly by class (review-2 S4).
  tg <- terra::terrain(wts, c("slope", "aspect"), unit = "radians")
  sl <- at_xy(tg[["slope"]], xy)
  as <- at_xy(tg[["aspect"]], xy)
  gp$gE <- tan(sl) * sin(as)
  gp$gN <- tan(sl) * cos(as)
  gp$ray_bad <- R$bad
  list(status = "ok", gp = gp, gs = gs,
       reg = c(mirror = mirror, r2 = R$r2, r2_other = res[[if (mirror) "normal" else "mirror"]]$r2,
               offE = R$par[1], offN = R$par[2], rot = R$par[3], scl = R$par[4],
               on_open = R$open),
       e_w = e_w, gsd = gsd, patch_m = patch_m, pred_px = pred_px, nr = nrow(a), nc = ncol(a))
}

# Patches that enter the regression. Gates are on the match and on placement, never on C or on
# the parallax's agreement with it: a correlation peak at or above PEAK, a ray that met the DTM,
# finite DEM values, and a y-parallax — which relief does not produce in a vertical pair —
# within 3 robust SDs of the quadratic through it, which drops mismatches.
usable <- function(gp) {
  X <- poly2(gp$xn, gp$yn)
  ok <- is.finite(gp$p) & gp$p > 0 & gp$pk >= PEAK & !gp$ray_bad & is.finite(gp$dtm) &
    is.finite(gp$C) & is.finite(gp$gE) & is.finite(gp$gN)
  qr <- rep(NA_real_, nrow(gp))
  if (sum(ok) >= 30) qr[ok] <- resid_on(gp$q[ok], X[ok, ])
  ok & is.finite(qr) & abs(qr) <= 3 * stats::mad(qr, na.rm = TRUE)
}

# Height the photo implies for each patch, relative to the pair: H - h = f B / p, so
# h - h_ref = (H - h_ref) (1 - p_ref / p). The scale (H - h_ref) is the catalogue's height over
# the DTM at A's centre; an error in it scales every slope in the pair alike and cancels in phi.
implied_height <- function(gp, H, e_w) {
  p0 <- stats::median(gp$p)
  (H - e_w) * (1 - p0 / gp$p)
}

# Regression columns: a patch's C enters the column of its class. Mid and old are split by MRDEM
# source, because the bare-earth reference differs (radar 0.146, lidar 0) and so does the canopy
# epoch (2013, 2018). Young is kept for the record; it has no role in a verdict (Amendment B).
COLS <- c("young", "mid_r", "mid_l", "old_r", "old_l", "post", "other")
EPOCH_OF <- c(r = 2013, l = 2018)

# VRI class of each patch from its stand's age at the photo date. A patch takes a class only
# when at least 90% of its footprint, grown by a 60 m margin for what registration leaves,
# lies in VRI polygons of that one class, and only when the footprint is single-source in
# MRDEM: 99% radar or 99% lidar. Everything else is `other`. (Review-2 S1 and S6: four of five
# points half a patch from the centre left the patch's outer half in the neighbouring stand.)
vri_classes <- function(gp, v, year, patch_m, src) {
  n <- nrow(gp)
  hs <- patch_m / 2 + 60
  sq <- sf::st_sfc(lapply(seq_len(n), function(i) {
    sf::st_polygon(list(cbind(gp$E[i] + c(-hs, hs, hs, -hs, -hs),
                              gp$N[i] + c(-hs, -hs, hs, hs, -hs))))
  }), crs = 3005)
  sv <- terra::vect(sf::st_transform(sq, terra::crs(src)))
  radar <- terra::extract(src == 1, sv, fun = mean, ID = FALSE)[[1]]
  lidar <- terra::extract(src == 10, sv, fun = mean, ID = FALSE)[[1]]
  srcl <- ifelse(is.finite(radar) & radar >= 0.99, "r",
          ifelse(is.finite(lidar) & lidar >= 0.99, "l", NA_character_))
  cls <- rep("other", n)
  r <- rep(NA_real_, n)
  if (nrow(v)) {
    v <- sf::st_make_valid(v)
    age <- suppressWarnings(as.numeric(v$PROJ_AGE_1))
    pyr <- as.numeric(substr(as.character(v$PROJECTED_DATE), 1, 4))
    treed <- v$BCLCS_LEVEL_2 %in% "T"
    ap <- age - (pyr - year)                      # stand age at the photo date
    v$vcls <- ifelse(!treed | !is.finite(ap), "other",
              ifelse(ap < 0, "post", ifelse(ap <= 10, "young", ifelse(ap >= 80, "old", "mid"))))
    v$origin <- pyr - age
    sqf <- sf::st_sf(id = seq_len(n), geometry = sq)
    pieces <- suppressWarnings(sf::st_intersection(sqf, v[, "vcls"]))
    if (nrow(pieces)) {
      pieces$a <- as.numeric(sf::st_area(pieces))
      tab <- stats::aggregate(a ~ id + vcls, data = sf::st_drop_geometry(pieces), FUN = sum)
      tab$share <- tab$a / (2 * hs)^2
      tab <- tab[order(tab$id, -tab$share), ]
      tab <- tab[!duplicated(tab$id) & tab$share >= 0.9, ]
      cls[tab$id] <- tab$vcls
    }
    # fly#80's model, per patch: height linear in age from origin O, so then/now =
    # (photo - O) / (epoch - O), clamped to [0, 1]; the origin is the stand under the centre.
    ctr <- sf::st_as_sf(data.frame(x = gp$E, y = gp$N), coords = c("x", "y"), crs = 3005)
    k <- vapply(sf::st_intersects(ctr, v), function(z) if (length(z)) z[1] else NA_integer_,
                integer(1))
    O <- v$origin[k]
    ep <- EPOCH_OF[ifelse(is.na(srcl), "r", srcl)]
    r <- pmin(pmax((year - O) / (ep - O), 0), 1)
  }
  # A mid or old patch whose centre VRI cannot date has no prediction; zeroing its r would say VRI
  # predicts bare ground there and pull phi_VRI down, so it is `other` (code-check round 1).
  cls[cls %in% c("mid", "old") & !is.finite(r)] <- "other"
  split <- cls %in% c("mid", "old")
  cls[split & is.na(srcl)] <- "other"
  cls[split & !is.na(srcl)] <- paste0(cls[split & !is.na(srcl)], "_", srcl[split & !is.na(srcl)])
  r[!cls %in% c("mid_r", "mid_l", "old_r", "old_l")] <- NA_real_
  list(cls = cls, r = r)
}

# A pair's sufficient statistics for the pooled regression (Frisch-Waugh with pair-specific
# nuisance): y and each column's C are residualised on the pair's own intercept, quadratic in
# image position (tilt, crab, scan rotation, scale), DTM gradient and DTM.
#
# - Scale. y is divided by g, the pair's own DTM coefficient from the full model, so a pair whose
#   catalogue height is off by 20% does not enter the pool 20% louder (review-2 4b).
# - Weight. 1 / sigma^2 with sigma the height-equivalent of the matcher's own noise, read from
#   the y-parallax — which relief does not produce — never from the residual of y, which carries
#   the canopy signal (review-2 4a).
# - VRI. Xtr is the same statistic for y* = r C on mid and old patches: what fly#80's model says
#   the camera saw. Solved with the pair's other columns it gives the slope VRI predicts.
# - Sensitivity. The `_i` statistics add class intercepts to the nuisance (review-2 S3).
nuisance_of <- function(gp) cbind(poly2(gp$xn, gp$yn), gE = gp$gE, gN = gp$gN, dtm = gp$dtm)
pair_stats <- function(gp, H, e_w, q_sd) {
  y <- implied_height(gp, H, e_w)
  Z <- sapply(COLS, function(k) gp$C * (gp$cls == k))
  N <- nuisance_of(gp)
  live <- colSums(Z != 0) > 0
  Xf <- cbind(1, N, Z[, live, drop = FALSE])
  fit <- stats::lm.fit(Xf, y)
  gi <- 1 + which(colnames(N) == "dtm")              # the DTM column
  df <- nrow(Xf) - fit$rank
  s2 <- sum(fit$residuals^2) / df
  XtXi <- tryCatch(solve(crossprod(Xf)), error = function(e) NULL)
  g <- unname(fit$coefficients[gi])
  g_se <- if (is.null(XtXi)) NA_real_ else sqrt(s2 * XtXi[gi, gi])
  r2 <- 1 - sum(fit$residuals^2) / sum((y - mean(y))^2)
  y <- y / g
  sigma <- (H - e_w) / stats::median(gp$p) * q_sd / abs(g)
  w <- 1 / sigma^2
  # One vector per column, every branch length n: a scalar from some branches made `sapply()`
  # return a list and `rowSums()` fail (code-check round 1).
  ystar <- rowSums(vapply(COLS, function(k) {
    if (k %in% c("mid_r", "mid_l", "old_r", "old_l")) ifelse(gp$cls == k, gp$rv * gp$C, 0)
    else numeric(nrow(gp))
  }, numeric(nrow(gp))))
  stat <- function(NN) {
    yp <- resid_on(y, NN)
    Zp <- apply(Z, 2, function(z) resid_on(z, NN))
    list(XtX = crossprod(Zp) * w, Xty = crossprod(Zp, yp) * w,
         Xtr = crossprod(Zp, resid_on(ystar, NN)) * w)
  }
  D <- sapply(COLS[COLS != "other"], function(k) as.numeric(gp$cls == k))
  D <- D[, colSums(D) > 0, drop = FALSE]
  list(main = stat(N), icpt = stat(cbind(N, D)), w = w, g = g, g_se = g_se, r2_full = r2,
       n_cls = table(factor(gp$cls, levels = COLS)),
       c_cls = vapply(COLS, function(k) if (any(gp$cls == k)) mean(gp$C[gp$cls == k]) else NA_real_,
                      numeric(1)),
       dtm_surv = stats::var(resid_on(gp$dtm, poly2(gp$xn, gp$yn))) / stats::var(gp$dtm),
       c_surv = stats::var(resid_on(gp$C, poly2(gp$xn, gp$yn))) / stats::var(gp$C))
}

# Column slopes from summed statistics; a column with no information is dropped, not inverted.
solve_cols <- function(XtX, Xty) {
  # A column is kept on its information relative to the largest, not on being non-zero: a class
  # with one patch in a pair is annihilated by its own dummy in the intercept fit and leaves a
  # diagonal of ~1e-31, which `> 0` kept and `solve()` then refused (code-check round 3).
  dg <- diag(XtX)
  keep <- is.finite(dg) & dg > 1e-9 * max(dg[is.finite(dg)], 0)
  b <- stats::setNames(rep(NA_real_, length(COLS)), COLS)
  if (any(keep)) b[keep] <- solve(XtX[keep, keep, drop = FALSE], Xty[keep])
  b
}
# The slopes fly#80's VRI model predicts. On mid and old the predicted seen surface is r C; on
# young, post and other it is the observed slope times C, so those columns cancel rather than
# leak through the joint fit (review-2 B2).
solve_vri <- function(XtX, Xtr, b) {
  dg <- diag(XtX)
  keep <- is.finite(dg) & dg > 1e-9 * max(dg[is.finite(dg)], 0) & is.finite(b)
  po <- keep & !(COLS %in% c("mid_r", "mid_l", "old_r", "old_l"))
  rhs <- Xtr
  if (any(po)) rhs <- rhs + XtX[, po, drop = FALSE] %*% b[po]
  solve_cols(XtX, rhs)
}

# ---------------------------------------------------------------------------
# Stage 0 — inputs, and the version of each remote one
# ---------------------------------------------------------------------------

MRDEM_SRC <- paste0("/vsicurl/", BUCKET, "/mrdem-30/mrdem-30-source.tif")
VERSIONS <- do.call(rbind, lapply(c(dtm = MRDEM_DTM, dsm = MRDEM_DSM, source = MRDEM_SRC),
                                  function(u) head_of(sub("^/vsicurl/", "", u))))
VERSIONS <- data.frame(asset = rownames(VERSIONS), VERSIONS, row.names = NULL)
for (i in seq_len(nrow(VERSIONS))) {
  pub("  version %-4s %s etag %s modified %s", VERSIONS$asset[i], VERSIONS$status[i],
      VERSIONS$etag[i], VERSIONS$modified[i])
}
stopifnot(all(VERSIONS$status == "200"))
# fly#80's census: every DEM-eligible film frame with its coarse canopy shift p, keyed on the
# same three ETags (dtm|dsm|source), so the census must have been built against this MRDEM.
census_files <- list.files(CENSUS_DIR, "^census_[0-9a-f]{8}\\.rds$", full.names = TRUE)
if (!length(census_files)) stop("no census in ", CENSUS_DIR, ": run dem_measure-canopy_height.R")
key_of <- function(lines) {
  f <- tempfile()
  writeLines(lines, f)
  k <- substr(unname(tools::md5sum(f)), 1, 8)
  unlink(f)
  k
}
CENSUS_KEY <- key_of(paste(VERSIONS$etag[match(c("dtm", "dsm", "source"), VERSIONS$asset)],
                           collapse = "|"))
CENSUS <- file.path(CENSUS_DIR, paste0("census_", CENSUS_KEY, ".rds"))
if (!file.exists(CENSUS)) stop("census for this MRDEM version not found: ", CENSUS)
pub("  census %s", CENSUS)
# Every cache below is keyed on all three ETags, the census and the algorithm: the classes read
# the source layer and the sample reads the census (code-check round 4).
VKEY <- key_of(c(paste(VERSIONS$etag, collapse = "|"), CENSUS_KEY, ALG))
pub("  cache key %s (algorithm %s)", VKEY, ALG)

dtm <- terra::rast(MRDEM_DTM)
dsm <- terra::rast(MRDEM_DSM)

window_of <- function(xy, half) {
  e3005 <- terra::ext(xy[1] - half, xy[1] + half, xy[2] - half, xy[2] + half)
  e_dem <- terra::ext(terra::project(terra::vect(e3005, crs = "EPSG:3005"), terra::crs(dtm)))
  list(wt = terra::crop(dtm, e_dem) * 1, ws = terra::crop(dsm, e_dem) * 1)
}

if (STOP_AFTER < 1) quit(save = "no")

# The catalogue rows of one roll (thumbnail URLs are not in the centroid cache), cached.
roll_meta <- function(roll) {
  f <- file.path(ROLLS, paste0(roll, ".rds"))
  if (!file.exists(f)) {
    q <- bcdata::bcdc_query_geodata("WHSE_IMAGERY_AND_BASE_MAPS.AIMG_PHOTO_CENTROIDS_SP")
    r <- bcdata::collect(bcdata::filter(q, FILM_ROLL == !!roll))
    r <- sf::st_transform(r, 3005)
    xy <- sf::st_coordinates(r)
    r <- sf::st_drop_geometry(r)
    names(r) <- tolower(names(r))
    r$x <- xy[, 1]
    r$y <- xy[, 2]
    # A unique temporary name: `save_atomic()` uses a fixed one and runs share ROLLS (round 2).
    tmp <- tempfile(tmpdir = ROLLS, fileext = ".part")
    saveRDS(as.data.frame(r), tmp)
    file.rename(tmp, f) || stop("could not write ", f)
  }
  readRDS(f)
}
# A and B of a pair: their catalogue rows and thumbnails, or a status saying why not.
fetch_pair <- function(roll, frame) {
  rm <- roll_meta(roll)
  a_row <- rm[rm$frame_number == frame, , drop = FALSE]
  b_row <- rm[rm$frame_number == frame + 1, , drop = FALSE]
  if (nrow(a_row) != 1 || nrow(b_row) != 1) return(list(status = "not_one_row"))
  urls <- c(a_row$thumbnail_image_url, b_row$thumbnail_image_url)
  if (any(is.na(urls) | !nzchar(urls))) return(list(status = "no_thumbnail"))
  dest <- file.path(THUMBS, basename(urls))
  for (k in 1:2) {
    if (!file.exists(dest[k]) || file.size(dest[k]) == 0) {
      # To a part file, renamed only when complete: an interrupted download must not leave a
      # truncated thumbnail the next run reuses (code-check round 1).
      part <- tempfile(tmpdir = THUMBS, fileext = ".part")   # unique: runs share THUMBS
      h <- tryCatch(curl::curl_fetch_disk(urls[k], part), error = function(e) e)
      if (inherits(h, "error")) {
        unlink(part)
        return(list(status = paste("transient: thumbnail", conditionMessage(h))))
      }
      if (h$status_code != 200) {
        unlink(part)
        # 5xx and 429 can clear on a rerun; any other code is a property of the URL (round 2).
        transient <- h$status_code >= 500 || h$status_code == 429
        return(list(status = paste0(if (transient) "transient: " else "",
                                    "thumbnail_http_", h$status_code)))
      }
      file.rename(part, dest[k]) || stop("could not rename ", part)
    }
  }
  list(status = "ok", a_row = a_row, b_row = b_row, dest = dest)
}
vri_over <- function(xy) {
  bb <- c(min(xy[, 1]), min(xy[, 2]), max(xy[, 1]), max(xy[, 2]))
  poly <- sf::st_as_sfc(sf::st_bbox(c(xmin = bb[1], ymin = bb[2], xmax = bb[3], ymax = bb[4]),
                                    crs = sf::st_crs(3005)))
  q1 <- function() {
    bcdata::bcdc_query_geodata("WHSE_FOREST_VEGETATION.VEG_COMP_LYR_R1_POLY") |>
      bcdata::filter(bcdata::INTERSECTS(poly)) |>
      bcdata::select(PROJ_AGE_1, PROJ_HEIGHT_1, PROJECTED_DATE, BCLCS_LEVEL_2) |>
      bcdata::collect()
  }
  v <- tryCatch(q1(), error = function(e) tryCatch(q1(), error = function(e2) e2))
  if (inherits(v, "error")) stop("VRI query failed: ", conditionMessage(v))
  if (nrow(v)) v <- sf::st_transform(v, 3005)
  v
}

geom_of <- function(a_row, b_row, shift = c(0, 0)) {
  list(xyA = c(a_row$x, a_row$y) + shift, xyB = c(b_row$x, b_row$y) + shift,
       H = a_row$flying_height, sn = as.numeric(sub("1:", "", a_row$scale)),
       f_mm = a_row$focal_length)
}

# ---------------------------------------------------------------------------
# Stage 1 — synthetic controls
# ---------------------------------------------------------------------------
# A known answer through the whole instrument. Frame B is synthesised from a real thumbnail A by
# moving each pixel by the parallax a known surface would give — h = DTM + kappa * C at the
# pixel's ray-cast ground point — plus a tilt field the quadratic must absorb, and saved as JPEG
# at quality 85, the thumbnails' own (Phase 0). The pipeline then measures it as it measures a
# real pair. Run on real geometry (the A frame's centroid, height, scale and DEM window), so the
# terrain and canopy statistics are BC's, not invented.
#
#   flat_C0  h = mean DTM + 0 * C         slope on C must be within 0.10 of 0
#   flat_C1  h = mean DTM + 1 * C         slope within 0.25 of 1 (Amendment B: phi is a ratio)
#   dtm_C0   h = DTM                      slope within 0.10 of 0
#   dtm_C1   h = DTM + C                  slope within 0.25 of 1
#   *_off    the same with A's centroid displaced 150 m before measuring: the registration has
#            to find it, and what it does not find is the placement shrinkage, reported
# Classes are not used here: one slope on all of C. The flat cases have no terrain to register
# against, so they are measured at the true placement: they test the matcher, not registration.

write_pgm <- function(m, path) {
  con <- file(path, "wb")
  on.exit(close(con))
  writeChar(sprintf("P5\n%d %d\n255\n", ncol(m), nrow(m)), con, eos = NULL)
  writeBin(as.raw(pmin(255, pmax(0, round(t(m))))), con)
}
jpeg85 <- function(m) {
  pgm <- tempfile(fileext = ".pgm")
  jpg <- tempfile(fileext = ".jpg")
  write_pgm(m, pgm)
  st <- system2("magick", c(pgm, "-quality", "85", jpg), stdout = FALSE, stderr = FALSE)
  if (st != 0 || !file.exists(jpg)) stop("magick could not write ", jpg)
  out <- read_gray(jpg)
  unlink(c(pgm, jpg))
  out
}

# `kappa` is a scalar, or a function of ground points (n x 2, EPSG:3005) returning one kappa
# per point — the class-structured synthetic sets it from VRI classes. The base is a designed
# 62% overlap, not the catalogue's spacing, which can be wrong by x1.7 (bc85054 162). Nuisance
# the real pairs carry and the quadratic must absorb is put in on both axes: a tilt field, a
# 0.3-degree rotation and a 0.3% scale difference between the exposures.
synth_pair <- function(a, geom, wt, ws, kappa, flat, nuisance = TRUE) {
  nr <- nrow(a)
  nc <- ncol(a)
  pitch <- FORMAT_MM / nc
  f_px <- geom$f_mm / pitch
  xyA <- geom$xyA
  e_w <- at_xy(wt, rbind(xyA))
  bearing <- atan2(geom$xyB[1] - xyA[1], geom$xyB[2] - xyA[2])
  B_px <- 0.38 * nr
  st <- 8
  rs <- seq(1, nr, by = st)
  cs <- seq(1, nc, by = st)
  g <- expand.grid(r = rs, c = cs)
  v <- img_vec(g$r, g$c, nr, nc)
  ring <- sweep(rot_ground(v, bearing) * (geom$H - e_w) / f_px, 2, xyA, "+")
  rc <- raycast(ring, xyA, geom$H, e_w, wt, step = 5, n_bisect = 20)
  d0 <- at_xy(wt, rc$xy)
  c0 <- at_xy(ws, rc$xy) - d0
  k <- if (is.function(kappa)) kappa(rc$xy) else rep(kappa, nrow(g))
  base <- if (flat) mean(d0, na.rm = TRUE) else d0
  h <- base + k * c0
  h[!is.finite(h)] <- mean(h, na.rm = TRUE)
  par <- B_px * (geom$H - e_w) / (geom$H - h)       # rows; image up lies along the flight line
  xn <- v[, 1] / (nc / 2)
  yn <- v[, 2] / (nr / 2)
  tr <- tc <- 0
  if (nuisance) {
    dk <- 0.3 * pi / 180
    tr <- 2.0 * xn^2 + 1.5 * yn + 1.0 * xn * yn + dk * v[, 1] - 0.003 * v[, 2]
    tc <- 1.2 * yn^2 - 1.0 * xn - dk * v[, 2] + 0.003 * v[, 1]
  }
  # Fields in image rows: the row shift is down-the-rows (content moves +row), the column
  # shift rightwards. In image (x right, y up) a +y component is -row.
  interp <- function(M, ii, jj) {
    n1 <- nrow(M)
    n2 <- ncol(M)
    i0 <- pmin(pmax(floor(ii), 1), n1 - 1)
    j0 <- pmin(pmax(floor(jj), 1), n2 - 1)
    fi <- pmin(pmax(ii - i0, 0), 1)
    fj <- pmin(pmax(jj - j0, 0), 1)
    at <- function(i, j) M[(j - 1) * n1 + i]
    (1 - fi) * (1 - fj) * at(i0, j0) + fi * (1 - fj) * at(i0 + 1, j0) +
      (1 - fi) * fj * at(i0, j0 + 1) + fi * fj * at(i0 + 1, j0 + 1)
  }
  # Coarse field to full resolution by its own coordinates: coarse row k is image row
  # 1 + (k - 1) * st. A raster resample between two extents misplaced it by -3 to +1.3 px
  # (code-check round 1).
  to_full <- function(z) {
    M <- matrix(z, nrow = length(rs))
    M[!is.finite(M)] <- mean(M, na.rm = TRUE)
    irow <- matrix(rep(seq_len(nr), nc), nr)
    jcol <- matrix(rep(seq_len(nc), each = nr), nr)
    matrix(interp(M, (irow - 1) / st + 1, (jcol - 1) / st + 1), nr)
  }
  sr <- to_full(par - tr)
  sc <- to_full(tc)
  # B[i, j] = A[i - s_r, j - s_c], each shift taken at A's own pixel, not B's (a base apart):
  # fixed-point steps from the mean shift.
  irow <- matrix(rep(seq_len(nr), nc), nr)
  jcol <- matrix(rep(seq_len(nc), each = nr), nr)
  hr <- matrix(mean(sr), nr, nc)
  hc <- matrix(0, nr, nc)
  for (it in 1:4) {
    ia <- irow - hr
    ja <- jcol - hc
    hr <- interp(sr, ia, ja)
    hc <- interp(sc, ia, ja)
  }
  ii <- irow - hr
  jj <- jcol - hc
  ok <- ii >= 1 & ii < nr & jj >= 1 & jj < nc
  b <- matrix(stats::runif(nr * nc, 0, 255), nr)
  b[ok] <- interp(a, ii[ok], jj[ok])
  list(b = jpeg85(b), xyB = xyA + c(sin(bearing), cos(bearing)) * B_px * (geom$H - e_w) / f_px,
       truth = list(xy = rc$xy, k = k))
}

# One slope on all of C, through the same nuisance as the pairs. Terrain cases are divided by
# the pair's own DTM coefficient as `pair_stats()` divides them; flat cases have no terrain to
# give one, and are read raw.
synth_slope <- function(m, H, flat) {
  none <- c(slope = NA, se = NA, n = 0, r2_full = NA, g_se = NA)
  if (!identical(m$status, "ok")) return(none)
  gp <- m$gp[usable(m$gp), ]
  if (nrow(gp) < 30) return(replace(none, "n", nrow(gp)))
  y <- implied_height(gp, H, m$e_w)
  X <- cbind(if (flat) poly2(gp$xn, gp$yn) else nuisance_of(gp), C = gp$C)
  fit <- stats::lm(y ~ X)
  # By name, and refusing an aliased fit: `summary.lm()` drops aliased rows, so a position read
  # returned a finite ratio of the wrong coefficients (code-check round 2).
  if (anyNA(stats::coef(fit))) return(c(replace(none, "n", nrow(gp))[1:4], g_se = -1))
  sm <- summary(fit)
  cf <- sm$coefficients
  g <- if (flat) 1 else cf["Xdtm", 1]
  c(slope = cf["XC", 1] / g, se = cf["XC", 2] / abs(g), n = nrow(gp), r2_full = sm$r.squared,
    g_se = if (flat) 0 else cf["Xdtm", 2])
}

# The class-structured synthetic: the world is fly#80's VRI model exactly — on mid and old
# patches the camera saw r C, elsewhere half of C — so the phi the pipeline measures must equal
# the phi the VRI machinery predicts from the same patches (review-2 S5). Measured with the bare
# reference at 0, since a synthetic has no DTM bias.
class_phi <- function(m, src, v, year, H) {
  none <- c(phi = NA, phi_vri = NA, n_mid = 0, n_old = 0, n = 0, r2_full = NA, g_se = NA)
  if (!identical(m$status, "ok")) return(none)
  gp <- m$gp[usable(m$gp), ]
  if (nrow(gp) < 30) return(replace(none, "n", nrow(gp)))
  vc <- vri_classes(gp, v, year, m$patch_m, src)
  gp$cls <- vc$cls
  gp$rv <- vc$r
  st <- pair_stats(gp, H, m$e_w, stats::mad(resid_on(gp$q, poly2(gp$xn, gp$yn))))
  b <- solve_cols(st$main$XtX, st$main$Xty)
  rb <- solve_vri(st$main$XtX, st$main$Xtr, b)
  sname <- if (sum(gp$cls == "old_r") >= sum(gp$cls == "old_l")) "r" else "l"
  mid <- paste0("mid_", sname)
  old <- paste0("old_", sname)
  out <- c(phi = unname(b[mid] / b[old]), phi_vri = unname(rb[mid] / rb[old]),
           n_mid = sum(gp$cls == mid), n_old = sum(gp$cls == old), n = nrow(gp),
           r2_full = st$r2_full, g_se = st$g_se)
  attr(out, "stats") <- st
  out
}

SYN_FILE <- file.path(CACHE, paste0("synthetic_", VKEY, ".rds"))
SYN_SRC <- data.frame(film_roll = c("bc78008", "bc85054", "bcc01030"),
                      frame_number = c(184, 162, 156))
# The class-structured synthetic runs on every Phase 0 pilot frame that matched and is pooled as
# Stage 4 pools pairs: one frame holds 1-21 mid patches, too few to estimate a ratio of two slopes
# to 0.1, which is why the per-frame test of Amendment B could not be passed by a correct
# instrument (Amendment C).
SYN_CLS <- data.frame(film_roll = c("bc5225", "bc78129", "bc78008", "bc78110", "bc85054",
                                    "bc81009", "bcb96017", "bcb96067", "bcc04013", "bcc01030",
                                    "bcb00031"),
                      frame_number = c(151, 145, 184, 69, 162, 18, 221, 13, 120, 156, 10))
src_rast <- terra::rast(MRDEM_SRC)
src_window <- function(wt) terra::crop(src_rast, terra::ext(wt)) * 1
if (!file.exists(SYN_FILE)) {
  set.seed(8202)
  cases <- expand.grid(case = c("flat_C0", "flat_C1", "dtm_C0", "dtm_C1"),
                       off = c(FALSE, TRUE), src = seq_len(nrow(SYN_SRC)),
                       stringsAsFactors = FALSE)
  cases <- cases[!(grepl("^flat", cases$case) & cases$off), ]
  cases$set <- "plain"
  cls_cases <- expand.grid(case = "class", off = c(FALSE, TRUE), src = seq_len(nrow(SYN_CLS)),
                           stringsAsFactors = FALSE)
  cls_cases$set <- "class"
  cases <- rbind(cases, cls_cases)
  if (SMOKE) cases <- cases[cases$src == 1 & !cases$off, ]
  rows <- vector("list", nrow(cases))
  cls_st <- vector("list", nrow(cases))
  for (i in seq_len(nrow(cases))) {
    cs <- cases[i, ]
    srcs <- if (cs$set == "plain") SYN_SRC else SYN_CLS
    fp <- fetch_pair(srcs$film_roll[cs$src], srcs$frame_number[cs$src])
    stopifnot(identical(fp$status, "ok"))
    a <- read_gray(fp$dest[1])
    g0 <- geom_of(fp$a_row, fp$b_row)
    win <- window_of(g0$xyA, FORMAT_MM / 2000 * g0$sn * 2.4)
    flat <- grepl("^flat", cs$case)
    if (cs$set == "plain") {
      kappa <- if (grepl("C1$", cs$case)) 1 else 0
      v <- NULL
    } else {
      # kappa per ground point from the VRI stand under it: r on mid and old, 0.5 elsewhere.
      v <- vri_over(rbind(g0$xyA - 6000, g0$xyA + 6000))
      vv <- sf::st_make_valid(v)
      age <- suppressWarnings(as.numeric(vv$PROJ_AGE_1))
      pyr <- as.numeric(substr(as.character(vv$PROJECTED_DATE), 1, 4))
      ap <- age - (pyr - fp$a_row$photo_year)
      O <- pyr - age
      cl <- ifelse(!(vv$BCLCS_LEVEL_2 %in% "T") | !is.finite(ap), "other",
            ifelse(ap < 0, "post", ifelse(ap <= 10, "young", ifelse(ap >= 80, "old", "mid"))))
      sw <- src_window(win$wt)
      kappa <- function(xy) {
        p <- sf::st_as_sf(data.frame(x = xy[, 1], y = xy[, 2]), coords = c("x", "y"), crs = 3005)
        k <- vapply(sf::st_intersects(p, vv), function(z) if (length(z)) z[1] else NA_integer_,
                    integer(1))
        s1 <- at_xy(sw, xy)
        ep <- ifelse(is.finite(s1) & s1 == 10, EPOCH_OF[["l"]], EPOCH_OF[["r"]])
        r <- pmin(pmax((fp$a_row$photo_year - O[k]) / (ep - O[k]), 0), 1)
        ifelse(!is.na(k) & cl[k] %in% c("mid", "old") & is.finite(r), r, 0.5)
      }
    }
    sp <- synth_pair(a, g0, win$wt, win$ws, kappa = kappa, flat = flat)
    g1 <- g0
    g1$xyB <- sp$xyB
    if (cs$off) {
      ang <- stats::runif(1, 0, 2 * pi)
      d <- 150 * c(sin(ang), cos(ang))
      g1$xyA <- g1$xyA + d
      g1$xyB <- g1$xyB + d
    }
    m <- measure_core(a, sp$b, g1, win$wt, win$ws, register = !flat)
    if (cs$set == "plain") {
      sl <- synth_slope(m, g1$H, flat)
      cp <- c(phi = NA, phi_vri = NA, n_mid = NA, n_old = NA)
    } else {
      cp <- class_phi(m, src_window(win$wt), v, fp$a_row$photo_year, g1$H)
      cls_st[i] <- list(attr(cp, "stats"))
      sl <- c(slope = NA, se = NA, n = cp[["n"]], r2_full = cp[["r2_full"]], g_se = cp[["g_se"]])
    }
    # Every pair gate applies to a synthetic as to a real pair: one the gates refuse is "gated",
    # neither a pass nor a fail (Amendment B; code-check round 1 found only rotation applied).
    status <- m$status
    if (identical(status, "ok")) {
      status <- if (sl[["n"]] < 50) "gated_few_patches"
      else if (isTRUE(sl[["g_se"]] == -1)) "gated_aliased"
      else if (!is.finite(sl[["r2_full"]]) || sl[["r2_full"]] < 0.5) "gated_model_r2"
      else if (!flat && (abs(m$reg[["rot"]]) > 6 || abs(m$reg[["scl"]]) > 6)) "gated_registration_bound"
      else if (!flat && (!is.finite(sl[["g_se"]]) || sl[["g_se"]] > 0.1)) "gated_dtm_scale"
      else "ok"
    }
    rows[[i]] <- data.frame(set = cs$set, film_roll = srcs$film_roll[cs$src],
                            frame_number = srcs$frame_number[cs$src], case = cs$case,
                            displaced_m = if (cs$off) 150 else 0,
                            kappa = if (cs$set == "plain") kappa else NA,
                            status = status, n = sl[["n"]], slope = sl[["slope"]],
                            se = sl[["se"]], phi = cp[["phi"]], phi_vri = cp[["phi_vri"]],
                            n_mid = cp[["n_mid"]], n_old = cp[["n_old"]],
                            reg_r2 = if (identical(m$status, "ok")) m$reg[["r2"]] else NA)
    pub("  synthetic %-5s %-9s %-8s off %3d  status %s  slope %+.3f  phi %.3f vs %.3f",
        cs$set, rows[[i]]$film_roll, cs$case, rows[[i]]$displaced_m, status, rows[[i]]$slope,
        rows[[i]]$phi, rows[[i]]$phi_vri)
  }
  syn <- do.call(rbind, rows)
  # Pooled class synthetic, per displacement and source, over the frames the gates admit.
  pooled <- list()
  for (off in c(0, 150)) {
    ix <- which(syn$set == "class" & syn$displaced_m == off & syn$status == "ok" &
                  !vapply(cls_st, is.null, logical(1)))
    if (!length(ix)) next
    XtX <- Reduce(`+`, lapply(cls_st[ix], function(z) z$main$XtX))
    Xty <- Reduce(`+`, lapply(cls_st[ix], function(z) z$main$Xty))
    Xtr <- Reduce(`+`, lapply(cls_st[ix], function(z) z$main$Xtr))
    ncl <- Reduce(`+`, lapply(cls_st[ix], function(z) as.numeric(z$n_cls)))
    names(ncl) <- COLS
    b <- solve_cols(XtX, Xty)
    rb <- solve_vri(XtX, Xtr, b)
    for (sn in c("r", "l")) {
      mid <- paste0("mid_", sn)
      old <- paste0("old_", sn)
      pooled[[length(pooled) + 1]] <- data.frame(
        set = "class_pooled", film_roll = paste0(length(ix), " frames"), frame_number = NA,
        case = paste0("source_", sn), displaced_m = off, kappa = NA, status = "ok",
        n = sum(syn$n[ix]), slope = NA, se = NA, phi = unname(b[[mid]] / b[[old]]),
        phi_vri = unname(rb[[mid]] / rb[[old]]), n_mid = ncl[[mid]], n_old = ncl[[old]],
        reg_r2 = NA)
    }
  }
  save_atomic(rbind(syn, do.call(rbind, pooled)), SYN_FILE)
}
SYN <- readRDS(SYN_FILE)
# Plain cases (Amendment B 5): a synthetic that measures and returns a wrong answer or NA FAILS;
# one the gates or the matcher refuse is neither pass nor fail; each case needs at least two of
# its three frames passing and none failing. Class cases (Amendment C): per-frame phi is a
# diagnostic; the pooled phi per source, where the pool holds >= 30 mid and >= 30 old patches,
# must be within 0.10 of the pooled VRI prediction, undisplaced and displaced, with at least one
# source qualifying in each.
refused <- grepl("^gated", SYN$status) | SYN$status %in% c("no_global", "no_registration", "no_dem")
SYN$pass <- NA
pl <- SYN$set == "plain" & SYN$displaced_m == 0 & !refused
SYN$pass[pl] <- with(SYN[pl, ], ifelse(status != "ok" | !is.finite(slope), FALSE,
                     ifelse(kappa == 0, abs(slope) <= 0.10, abs(slope - 1) <= 0.25)))
cp <- SYN$set == "class_pooled"
qual <- cp & SYN$n_mid >= 30 & SYN$n_old >= 30
SYN$pass[qual] <- with(SYN[qual, ], is.finite(phi) & is.finite(phi_vri) & abs(phi - phi_vri) <= 0.10)
for (i in seq_len(nrow(SYN))) {
  pub("  synthetic %-12s %-9s %-9s off %3d  slope %+.3f  phi %.3f vs %.3f (mid %s, old %s)  %s",
      SYN$set[i], SYN$film_roll[i], SYN$case[i], SYN$displaced_m[i], SYN$slope[i], SYN$phi[i],
      SYN$phi_vri[i], SYN$n_mid[i], SYN$n_old[i],
      if (refused[i]) "(refused)" else if (!is.na(SYN$pass[i])) {
        if (SYN$pass[i]) "pass" else "FAIL"
      } else if (SYN$set[i] == "plain") "(displaced, reported)"
      else if (SYN$set[i] == "class") "(per frame, diagnostic)" else "(too few patches)")
}
# Split ALL undisplaced plain rows, refused ones included, on the four cases as fixed levels: a
# case whose every frame was refused must fail, not vanish into `all(logical(0))` (round 5).
pu <- SYN$set == "plain" & SYN$displaced_m == 0
plain_ok <- all(vapply(split(SYN[pu, ], factor(SYN$case[pu],
                                               levels = c("flat_C0", "flat_C1", "dtm_C0", "dtm_C1"))),
                       function(z) sum(z$pass %in% TRUE) >= 2 && !any(z$pass %in% FALSE),
                       logical(1)))
class_ok <- all(vapply(c(0, 150), function(off) {
  z <- SYN[qual & SYN$displaced_m == off, ]
  nrow(z) >= 1 && all(z$pass)
}, logical(1)))
SYN_OK <- plain_ok && class_ok
shrink <- with(SYN, slope[set == "plain" & kappa == 1 & displaced_m > 0 & status == "ok"])
pub("  synthetic controls %s; plain kappa 1 displaced 150 m: %s", if (SYN_OK) "PASS" else "FAIL",
    paste(sprintf("%.3f", shrink), collapse = ", "))

sig <- function(d) {
  num <- vapply(d, is.double, logical(1))
  d[num] <- lapply(d[num], signif, 10)
  d
}
write_versions <- function() {
  vers <- rbind(VERSIONS[, c("asset", "etag", "modified")],
                data.frame(asset = c("census", "algorithm"), etag = c(basename(CENSUS), ALG),
                           modified = c("", "")))
  write_if_changed(vers, "inst/extdata/dem_parallax_versions.csv")
  write_if_changed(sig(SYN), "inst/extdata/dem_parallax_synthetic.csv")
}
# Verdict 1: an instrument that fails its synthetic controls is not applied to the sample. Nothing
# below runs; what is written is the controls and the versions they were run against.
if (!SYN_OK) {
  pub("  STOP (synthetic): the instrument fails its synthetic controls; no sampled pair is measured")
  if (!SMOKE) write_versions()
  quit(save = "no")
}
if (STOP_AFTER < 2) quit(save = "no")

# ---------------------------------------------------------------------------
# Stage 2 — the sample
# ---------------------------------------------------------------------------
# Pairs where canopy matters (census p >= 0.25%), one per roll, 90 per decade, drawn uniformly
# within a decade. The pilot rolls are out: bc5282 because its canopy coefficients were computed
# before the rule existed, the rest because Phase 0 tuned the instrument on them.

PILOT_ROLLS <- c("bc5282", "bc5117", "bc5225", "bc5346", "bc78129", "bc78008", "bc78110",
                 "bc80041", "bc85054", "bc81009", "bcb96017", "bcb96067", "bcb96099",
                 "bcc04013", "bcc01030", "bcb00031")
N_DECADE <- if (SMOKE) 2 else 90
DECADES <- c(1960, 1970, 1980, 1990, 2000)

SAMPLE_FILE <- file.path(CACHE, paste0("sample_", VKEY, ".rds"))
if (!file.exists(SAMPLE_FILE)) {
  cen <- readRDS(CENSUS)
  cen <- cen[order(cen$film_roll, cen$frame_number), ]
  k <- match(paste(cen$film_roll, cen$frame_number + 1), paste(cen$film_roll, cen$frame_number))
  same <- !is.na(k) & cen$scale[k] == cen$scale &
    cen$focal_length[k] == cen$focal_length & cen$flying_height[k] == cen$flying_height
  same[is.na(same)] <- FALSE
  side <- FORMAT_MM / 1000 * cen$scale_n
  spacing <- sqrt((cen$x[k] - cen$x)^2 + (cen$y[k] - cen$y)^2)
  elig <- same & is.finite(spacing) & spacing >= 0.15 * side & spacing <= 0.7 * side &
    cen$p_census >= 0.0025 & cen$decade %in% DECADES & !(cen$film_roll %in% PILOT_ROLLS)
  e <- cen[elig, ]
  pub("  sample frame: %d eligible pairs on %d rolls (%s)", nrow(e), length(unique(e$film_roll)),
      paste(sprintf("%d: %d", DECADES, as.integer(table(factor(e$decade, levels = DECADES)))),
            collapse = ", "))
  # Smoke draws with its own seed, so its pairs are not the head of the real sample.
  set.seed(if (SMOKE) 9182 else 82)
  draw <- do.call(rbind, lapply(DECADES, function(d) {
    z <- e[e$decade == d, ]
    z <- z[sample.int(nrow(z)), ]
    z <- z[!duplicated(z$film_roll), ]
    z[seq_len(min(N_DECADE, nrow(z))), ]
  }))
  draw$n_eligible_decade <- as.integer(table(factor(e$decade, levels = DECADES))[as.character(draw$decade)])
  save_atomic(draw, SAMPLE_FILE)
}
SAMPLE <- readRDS(SAMPLE_FILE)
pub("  sample: %d pairs (%s)", nrow(SAMPLE),
    paste(sprintf("%d: %d", DECADES, as.integer(table(factor(SAMPLE$decade, levels = DECADES)))),
          collapse = ", "))
if (STOP_AFTER < 3) quit(save = "no")

# ---------------------------------------------------------------------------
# Stage 3 — per pair (cached, PSOCK)
# ---------------------------------------------------------------------------

measure_pair <- function(row) {
  fp <- tryCatch(fetch_pair(row$film_roll, row$frame_number),
                 error = function(e) list(status = paste("transient: catalogue", conditionMessage(e))))
  if (!identical(fp$status, "ok")) return(list(status = fp$status))
  a <- read_gray(fp$dest[1])
  b <- read_gray(fp$dest[2])
  g <- geom_of(fp$a_row, fp$b_row)
  win <- window_of(g$xyA, FORMAT_MM / 2000 * g$sn * 2.4)
  m <- measure_core(a, b, g, win$wt, win$ws)
  if (!identical(m$status, "ok")) return(m[c("status", "gs")])
  ok <- usable(m$gp)
  gp <- m$gp[ok, ]
  # Robust SD of the y-parallax residual (stats::mad is already scaled to an SD).
  q_sd <- stats::mad(resid_on(gp$q, poly2(gp$xn, gp$yn)))
  # Pass rate of the y-parallax gate among patches otherwise usable, for the record (review-2 3b).
  out <- list(status = "ok", gs = m$gs, reg = m$reg, e_w = m$e_w, gsd = m$gsd,
              patch_m = m$patch_m, pred_px = m$pred_px, n_matched = nrow(m$gp), n_usable = nrow(gp),
              q_sd = q_sd, H = g$H, year = fp$a_row$photo_year)
  if (nrow(gp) < 50) return(c(out, list(gate = "few_patches")))
  hs <- m$patch_m / 2 + 200
  v <- vri_over(rbind(c(min(gp$E) - hs, min(gp$N) - hs), c(max(gp$E) + hs, max(gp$N) + hs)))
  vc <- vri_classes(gp, v, fp$a_row$photo_year, m$patch_m, src_window(win$wt))
  gp$cls <- vc$cls
  gp$rv <- vc$r
  out$patches <- gp[, c("r", "c", "p", "q", "pk", "xn", "yn", "E", "N", "dtm", "C", "gE", "gN",
                        "cls", "rv")]
  out$n_vri <- nrow(v)
  out
}

PAIRS_DIR <- file.path(CACHE, paste0("pairs_", VKEY))
dir.create(PAIRS_DIR, showWarnings = FALSE)
todo <- SAMPLE$airp_id[!file.exists(file.path(PAIRS_DIR, paste0(SAMPLE$airp_id, ".rds")))]
if (length(todo)) {
  pub("  measuring %d pairs on %d workers", length(todo), WORKERS)
  one <- function(id) {
    f <- file.path(PAIRS_DIR, paste0(id, ".rds"))
    row <- SAMPLE[SAMPLE$airp_id == id, ][1, ]
    # Any error, and any status marked transient, is retried rather than cached, until the same
    # message has been seen on two runs: then it is cached as `failed:`. A message is not a cause
    # — a DEM read cut off mid-crop raises terra's "too few values", which matches no network
    # pattern — so recurrence, not text, decides (code-check round 4).
    m <- tryCatch(measure_pair(row), error = function(e) list(status = paste("error:", conditionMessage(e))))
    if (grepl("^error:|^transient:", m$status)) {
      af <- file.path(PAIRS_DIR, paste0(id, ".attempts"))
      seen <- if (file.exists(af)) readLines(af, warn = FALSE) else character(0)
      msg <- gsub("[\r\n]+", " ", m$status)
      if (!(msg %in% seen)) {
        cat(msg, "\n", file = af, append = TRUE, sep = "")
        return(m$status)
      }
      m <- list(status = paste("failed:", sub("^(error|transient): ?", "", msg)))
    }
    save_atomic(m, f)
    m$status
  }
  fn_names <- c("read_gray", "hann2", "down", "pc_surface", "phase_corr", "patch_shifts",
                "global_shift", "img_vec", "image_theta", "rot_ground", "at_xy", "smooth_to", "hann_w",
                "src_window",
                "poly2", "resid_on", "fit_r2", "adjust", "measure_core", "usable", "vri_classes",
                "roll_meta", "fetch_pair", "geom_of", "window_of", "vri_over", "measure_pair",
                "raycast", "save_atomic", "pub", "%||%")
  const_names <- c("MARGIN", "PEAK", "REG_BOUND", "FORMAT_MM", "COLS", "EPOCH_OF", "BUCKET",
                   "THUMBS", "ROLLS", "PAIRS_DIR", "SAMPLE", "MRDEM_DTM", "MRDEM_DSM", "REPO")
  if (WORKERS > 1) {
    cl <- parallel::makePSOCKcluster(WORKERS)
    parallel::clusterExport(cl, c(fn_names, const_names, "one"))
    parallel::clusterEvalQ(cl, {
      setwd(REPO)
      suppressMessages(pkgload::load_all(REPO, quiet = TRUE))
      sf::sf_use_s2(FALSE)
      terra::gdalCache(128)
      terra::terraOptions(memfrac = 0.05, memmax = 1, progress = 0)
      dtm <- terra::rast(MRDEM_DTM)
      dsm <- terra::rast(MRDEM_DSM)
      src_rast <- terra::rast(paste0("/vsicurl/", BUCKET, "/mrdem-30/mrdem-30-source.tif"))
      NULL
    })
    st <- unlist(parallel::parLapplyLB(cl, todo, one))
    parallel::stopCluster(cl)
  } else {
    st <- vapply(todo, one, character(1))
  }
  pub("  pair status: %s", paste(names(table(st)), table(st), sep = " ", collapse = ", "))
}
# Transient failures were not cached; a second run retries them. Refuse to report on a sample
# with holes, as `mask_measure-interior_zeros.R` refuses on a frame that errored.
missing <- SAMPLE$airp_id[!file.exists(file.path(PAIRS_DIR, paste0(SAMPLE$airp_id, ".rds")))]
if (length(missing)) stop(length(missing), " pairs not measured (failures seen once); run again")
# And refuse when failures look systematic: two or more pairs failing with one message is a code
# or service defect, which would otherwise reach Stage 4 as "the controls do not separate"
# (code-check round 4; the PSOCK `mean()` defect failed every colour thumbnail one way).
st_all <- vapply(SAMPLE$airp_id, function(id) readRDS(file.path(PAIRS_DIR, paste0(id, ".rds")))$status,
                 character(1))
fails <- st_all[grepl("^failed:", st_all)]
if (length(fails)) {
  # Grouped with digits masked: messages carry pair-specific numbers (terra's "too few values
  # ... 0 < N", curl's byte counts), so exact text never groups a shared cause (round 5). And a
  # total over 1% of the sample, or more than 2 pairs, refuses whatever the messages say.
  tab <- table(gsub("[0-9]+", "#", fails))
  for (k in seq_along(tab)) pub("  failed x%d: %s", tab[[k]], names(tab)[k])
  if (any(tab >= 2) || length(fails) > max(2, 0.01 * nrow(SAMPLE))) {
    stop(length(fails), " pairs failed (shared messages or over 1% of the sample); fix the cause, ",
         "delete their .rds and .attempts files in ", PAIRS_DIR, ", and run again")
  }
}
if (STOP_AFTER < 4) quit(save = "no")

# ---------------------------------------------------------------------------
# Stage 4 — the verdicts
# ---------------------------------------------------------------------------

M <- lapply(SAMPLE$airp_id, function(id) readRDS(file.path(PAIRS_DIR, paste0(id, ".rds"))))
ST <- lapply(M, function(m) {
  if (!identical(m$status, "ok") || !is.null(m$gate)) return(NULL)
  pair_stats(m$patches, m$H, m$e_w, m$q_sd)
})
# Gates on matching, placement and the DTM regressor — never on C's coefficient. The model R² is
# the full model's (review-2 3a): symmetric in canopy seen and canopy not seen.
gate_of <- function(m, st) {
  if (!identical(m$status, "ok")) return(m$status)
  if (!is.null(m$gate)) return(m$gate)
  if (!is.finite(st$r2_full) || st$r2_full < 0.5) return("model_r2")
  if (abs(m$reg[["rot"]]) > 6 || abs(m$reg[["scl"]]) > 6) return("registration_bound")
  if (!is.finite(st$g_se) || st$g_se > 0.1) return("dtm_scale")
  "ok"
}
gate <- vapply(seq_along(M), function(i) gate_of(M[[i]], ST[[i]]), character(1))
pub("  gates: %s", paste(names(table(gate)), table(gate), sep = " ", collapse = ", "))

UT <- which(upper.tri(diag(length(COLS)), diag = TRUE), arr.ind = TRUE)
num <- function(x) if (is.null(x) || !length(x)) NA_real_ else unname(x)
pairs_out <- do.call(rbind, lapply(seq_along(M), function(i) {
  m <- M[[i]]
  s <- SAMPLE[i, ]
  st <- ST[[i]]
  reg <- if (identical(m$status, "ok")) m$reg else NULL
  d <- data.frame(airp_id = s$airp_id, film_roll = s$film_roll, frame_number = s$frame_number,
                  photo_year = s$photo_year, decade = s$decade, scale_n = s$scale_n,
                  p_census = s$p_census, n_eligible_decade = s$n_eligible_decade,
                  status = m$status, gate = gate[i],
                  shift_px = if (is.null(m$gs) || !is.finite(m$gs[["row"]])) NA else
                    sqrt(m$gs[["row"]]^2 + m$gs[["col"]]^2),
                  n_usable = num(m$n_usable), q_sd = num(m$q_sd), patch_m = num(m$patch_m),
                  reg_r2 = num(reg[["r2"]]), reg_mirror = num(reg[["mirror"]]),
                  reg_offE = num(reg[["offE"]]), reg_offN = num(reg[["offN"]]),
                  reg_rot = num(reg[["rot"]]), reg_scl = num(reg[["scl"]]),
                  r2_full = num(st$r2_full), g = num(st$g), g_se = num(st$g_se), w = num(st$w),
                  dtm_surv = num(st$dtm_surv), c_surv = num(st$c_surv))
  for (k in COLS) {
    d[[paste0("n_", k)]] <- if (is.null(st)) NA else as.integer(st$n_cls[[k]])
    d[[paste0("c_", k)]] <- if (is.null(st)) NA else st$c_cls[[k]]
  }
  for (fit in c("main", "icpt")) {
    for (j in seq_len(nrow(UT))) {
      d[[sprintf("%s_xtx_%s_%s", fit, COLS[UT[j, 1]], COLS[UT[j, 2]])]] <-
        if (is.null(st)) NA else st[[fit]]$XtX[UT[j, 1], UT[j, 2]]
    }
    for (k in COLS) {
      d[[sprintf("%s_xty_%s", fit, k)]] <- if (is.null(st)) NA else st[[fit]]$Xty[k, 1]
      d[[sprintf("%s_xtr_%s", fit, k)]] <- if (is.null(st)) NA else st[[fit]]$Xtr[k, 1]
    }
  }
  d
}))

# Summed statistics of a set of pairs, from the shipped columns, so the test recomputes them.
summed <- function(d, fit) {
  XtX <- matrix(0, length(COLS), length(COLS), dimnames = list(COLS, COLS))
  for (j in seq_len(nrow(UT))) {
    v <- sum(d[[sprintf("%s_xtx_%s_%s", fit, COLS[UT[j, 1]], COLS[UT[j, 2]])]])
    XtX[UT[j, 1], UT[j, 2]] <- v
    XtX[UT[j, 2], UT[j, 1]] <- v
  }
  Xty <- vapply(COLS, function(k) sum(d[[sprintf("%s_xty_%s", fit, k)]]), numeric(1))
  Xtr <- vapply(COLS, function(k) sum(d[[sprintf("%s_xtr_%s", fit, k)]]), numeric(1))
  list(XtX = XtX, Xty = Xty, Xtr = Xtr)
}

# The bare-earth reference per MRDEM source (Amendment B): what the slope on C is when the camera
# saw bare ground. On radar cells MRDEM's DTM sits under true ground by an amount that grows with
# C — fly#80's LidarBC tiles give the slope, with its SE, and it is drawn afresh in every bootstrap
# resample. On lidar cells the DTM is lidar ground, so 0.
lid <- utils::read.csv("inst/extdata/dem_canopy_lidar.csv")
b0fit <- summary(stats::lm(I(-dtm_resid) ~ mrdem_canopy, data = lid))$coefficients
BETA0 <- c(r = b0fit["mrdem_canopy", 1], l = 0)
BETA0_SE <- c(r = b0fit["mrdem_canopy", 2], l = 0)
pub("  bare-earth reference: radar %.4f (se %.4f), lidar 0", BETA0[["r"]], BETA0_SE[["r"]])

own_old <- function(d, sname) {
  n <- d[[paste0("n_old_", sname)]]
  sum(n) >= 100 && sum(n > 0) >= 5
}
# phi and its VRI prediction for one source from a set of pairs; old taken from `d_old` when the
# decade lacks its own (Amendment B: pooled with the adjacent decades only).
phi_source <- function(d, d_old, sname, beta0, fit) {
  S <- summed(d, fit)
  b <- solve_cols(S$XtX, S$Xty)
  rb <- solve_vri(S$XtX, S$Xtr, b)
  So <- if (identical(d_old, d)) S else summed(d_old, fit)
  bo <- if (identical(d_old, d)) b else solve_cols(So$XtX, So$Xty)
  rbo <- if (identical(d_old, d)) rb else solve_vri(So$XtX, So$Xtr, bo)
  mid <- paste0("mid_", sname)
  old <- paste0("old_", sname)
  phi <- (b[[mid]] - beta0) / (bo[[old]] - beta0)
  phi_vri <- rb[[mid]] / rbo[[old]]
  c(phi = phi, phi_vri = phi_vri, D = phi - phi_vri, sep = bo[[old]] - beta0)
}

G <- pairs_out[pairs_out$gate == "ok", ]
N_BOOT <- if (SMOKE) 50 else 2000
set.seed(8203)
boot_idx <- replicate(N_BOOT, unlist(lapply(split(seq_len(nrow(G)), G$decade), function(ix) {
  ix[sample.int(length(ix), length(ix), replace = TRUE)]
}), use.names = FALSE), simplify = FALSE)
boot_b0 <- stats::rnorm(N_BOOT, BETA0[["r"]], BETA0_SE[["r"]])
ci <- function(x) unname(stats::quantile(x, c(0.025, 0.975), na.rm = TRUE))

# One estimate set for the rows `rows` of G: per source, then pooled over sources by inverse
# bootstrap variance of D. `old_rows` is the set old is taken from, per source.
estimate <- function(rows, old_rows, b0r, fit) {
  out <- list()
  for (sname in c("r", "l")) {
    beta0 <- if (sname == "r") b0r else 0
    e <- tryCatch(phi_source(G[rows, ], G[old_rows[[sname]], ], sname, beta0, fit),
                  error = function(err) c(phi = NA, phi_vri = NA, D = NA, sep = NA))
    out[[sname]] <- e
  }
  out
}

SEP_MIN <- 0.15
rows_all <- seq_len(nrow(G))
olds_all <- list(r = rows_all, l = rows_all)
pt_all <- estimate(rows_all, olds_all, BETA0[["r"]], "main")
bt_all <- lapply(seq_len(N_BOOT), function(k) {
  ix <- boot_idx[[k]]
  estimate(ix, list(r = ix, l = ix), boot_b0[k], "main")
})
SOURCE_OK <- c(r = FALSE, l = FALSE)
for (sname in c("r", "l")) {
  sp <- vapply(bt_all, function(z) z[[sname]][["sep"]], numeric(1))
  SOURCE_OK[[sname]] <- is.finite(pt_all[[sname]][["sep"]]) && ci(sp)[1] >= SEP_MIN &&
    mean(!is.finite(sp)) <= 0.01
  if (!SMOKE && SYN_OK) {
    pub("  source %s: old - bare %.3f [%.3f, %.3f] -> %s", sname, pt_all[[sname]][["sep"]],
        ci(sp)[1], ci(sp)[2], if (SOURCE_OK[[sname]]) "separates" else "does not separate")
  }
}
STOPPED <- if (!SYN_OK) "synthetic" else if (!any(SOURCE_OK)) "controls" else ""

# Sources are pooled by inverse bootstrap variance of D, over one source set for all three
# quantities: those that separate overall (verdict 2), have a finite point D in this set of pairs,
# and fail in at most 1% of its resamples. Within a resample a missing source is dropped and the
# weights renormalised, so one source's absence never turns the pool NA (code-check rounds 1-2).
sources_for <- function(est_pt, est_bt) {
  srcs <- names(SOURCE_OK)[SOURCE_OK]
  srcs[vapply(srcs, function(sn) {
    dd <- vapply(est_bt, function(z) z[[sn]][["D"]], numeric(1))
    is.finite(est_pt[[sn]][["D"]]) && mean(!is.finite(dd)) <= 0.01 && stats::var(dd, na.rm = TRUE) > 0
  }, logical(1))]
}
combine <- function(est_pt, est_bt, which, srcs) {
  if (!length(srcs)) return(list(pt = NA_real_, bt = rep(NA_real_, length(est_bt))))
  v <- vapply(srcs, function(sn) stats::var(vapply(est_bt, function(z) z[[sn]][["D"]], numeric(1)),
                                            na.rm = TRUE), numeric(1))
  wsum <- function(vals) {
    ok <- is.finite(vals)
    if (!any(ok)) return(NA_real_)
    sum((1 / v[ok]) * vals[ok]) / sum(1 / v[ok])
  }
  pt <- wsum(vapply(srcs, function(sn) est_pt[[sn]][[which]], numeric(1)))
  bt <- vapply(est_bt, function(z) wsum(vapply(srcs, function(sn) z[[sn]][[which]], numeric(1))),
               numeric(1))
  list(pt = pt, bt = bt)
}

verdict_of <- function(D_ci, n) {
  if (n < 10 || any(!is.finite(D_ci))) return("inconclusive")
  if (D_ci[1] > 0) return("more_canopy_than_vri")
  if (D_ci[2] < 0) return("less_canopy_than_vri")
  if (D_ci[1] >= -0.15 && D_ci[2] <= 0.15) return("agrees")
  "inconclusive"
}

verdict_rows <- list()
for (d in c(DECADES, NA)) {
  label <- if (is.na(d)) "all" else as.character(d)
  rows <- if (is.na(d)) rows_all else which(G$decade == d)
  if (!length(rows)) next
  near <- if (is.na(d)) rows_all else which(abs(G$decade - d) <= 10)
  own <- vapply(c(r = "r", l = "l"), function(sn) own_old(G[rows, ], sn), logical(1))
  olds <- lapply(c(r = "r", l = "l"), function(sn) if (own[[sn]]) rows else near)
  pt <- estimate(rows, olds, BETA0[["r"]], "main")
  bt <- lapply(seq_len(N_BOOT), function(k) {
    ix <- boot_idx[[k]]
    ixd <- ix[ix %in% rows]
    ixn <- ix[ix %in% near]
    estimate(ixd, lapply(own, function(o) if (o) ixd else ixn), boot_b0[k], "main")
  })
  pti <- estimate(rows, olds, BETA0[["r"]], "icpt")
  bti <- lapply(seq_len(N_BOOT), function(k) {
    ix <- boot_idx[[k]]
    ixd <- ix[ix %in% rows]
    ixn <- ix[ix %in% near]
    estimate(ixd, lapply(own, function(o) if (o) ixd else ixn), boot_b0[k], "icpt")
  })
  srcs <- sources_for(pt, bt)
  D <- combine(pt, bt, "D", srcs)
  PHI <- combine(pt, bt, "phi", srcs)
  VRI <- combine(pt, bt, "phi_vri", srcs)
  Di <- combine(pti, bti, "D", sources_for(pti, bti))
  # (the source-set check against `srcs` is applied with the verdict below)
  fail <- mean(!is.finite(D$bt))
  D_ci <- ci(D$bt)
  v <- if (fail > 0.01) "inconclusive" else verdict_of(D_ci, length(rows))
  Di_ci <- ci(Di$bt)
  # The class-intercept fit must not contradict the primary one (review-2 S3), and a MORE or LESS
  # stands only where it could be computed: a sensitivity that cannot run is not a pass
  # (code-check round 3 — it never ran, and the guard failed toward pass).
  # It must also cover the same sources as the verdict it guards: the intercept fit loses lidar
  # first, and pooled over radar alone it hid a lidar interval wholly on the other side
  # (code-check round 4). The contradiction is keyed on the verdict, not on the point.
  srcs_i <- sources_for(pti, bti)
  if (v %in% c("more_canopy_than_vri", "less_canopy_than_vri") &&
      (!all(is.finite(Di_ci)) || !setequal(srcs_i, srcs) ||
       (v == "more_canopy_than_vri" && Di_ci[2] < 0) ||
       (v == "less_canopy_than_vri" && Di_ci[1] > 0))) {
    v <- "inconclusive"
  }
  row <- data.frame(decade = label, n_pairs = length(rows),
                    old_from = if (is.na(d)) "all" else paste(vapply(c("r", "l"), function(sn) {
                      if (own[[sn]]) return("own")
                      extra <- setdiff(near, rows)
                      if (length(extra) && sum(G[extra, paste0("n_old_", sn)]) > 0) "adjacent"
                      else "own_below_threshold"
                    }, character(1)), collapse = "/"),
                    sources = paste(srcs, collapse = "+"),
                    phi = PHI$pt, phi_lo = ci(PHI$bt)[1], phi_hi = ci(PHI$bt)[2],
                    phi_vri = VRI$pt, phi_vri_lo = ci(VRI$bt)[1], phi_vri_hi = ci(VRI$bt)[2],
                    D = D$pt, D_lo = D_ci[1], D_hi = D_ci[2], boot_fail = fail,
                    D_icpt = Di$pt, D_icpt_lo = Di_ci[1], D_icpt_hi = Di_ci[2], verdict = v)
  for (sn in c("r", "l")) {
    row[[paste0("phi_", sn)]] <- pt[[sn]][["phi"]]
    row[[paste0("phi_vri_", sn)]] <- pt[[sn]][["phi_vri"]]
    dd <- vapply(bt, function(z) z[[sn]][["D"]], numeric(1))
    row[[paste0("D_", sn)]] <- pt[[sn]][["D"]]
    row[[paste0("D_", sn, "_lo")]] <- ci(dd)[1]
    row[[paste0("D_", sn, "_hi")]] <- ci(dd)[2]
  }
  for (k in COLS) row[[paste0("n_", k)]] <- sum(G[rows, paste0("n_", k)])
  verdict_rows[[label]] <- row
  if (!SMOKE && !nzchar(STOPPED)) {
    pub("  %-4s n=%3d old %-17s phi %.3f [%.3f, %.3f]  VRI %.3f  D %+.3f [%+.3f, %+.3f]  -> %s",
        label, length(rows), row$old_from, PHI$pt, row$phi_lo, row$phi_hi, VRI$pt, D$pt,
        D_ci[1], D_ci[2], v)
  }
}
VERDICTS <- do.call(rbind, verdict_rows)
VERDICTS$synthetic_pass <- SYN_OK
VERDICTS$source_r_separates <- SOURCE_OK[["r"]]
VERDICTS$source_l_separates <- SOURCE_OK[["l"]]
VERDICTS$beta0_r <- BETA0[["r"]]
VERDICTS$stopped <- STOPPED
if (STOPPED == "synthetic") {
  # Verdict 2 sits below verdict 1: under a synthetic stop its outcome is not written either
  # (code-check round 3).
  VERDICTS$source_r_separates <- NA
  VERDICTS$source_l_separates <- NA
  VERDICTS$sources <- NA_character_
}
if (nzchar(STOPPED)) {
  # Nothing below a stop is read (the rule): every estimate is blanked before it can be written.
  est <- grepl("^(phi|D)", names(VERDICTS))
  VERDICTS[est] <- NA_real_
  VERDICTS$verdict <- "not_read"
  pub("  STOP (%s): no verdict is read", STOPPED)
}
if (SMOKE) {
  pub("  smoke: %d pairs gated ok; verdict code ran; no slope or phi is printed or written",
      nrow(G))
}

if (!SMOKE) {
  write_versions()
  write_if_changed(sig(pairs_out), "inst/extdata/dem_parallax_pairs.csv")
  write_if_changed(sig(VERDICTS), "inst/extdata/dem_parallax_verdicts.csv")
}
