# fly#82 instrument library (development copy; moves into data-raw/dem_measure-photo_parallax.R)

read_gray <- function(p) {
  r <- terra::rast(p)
  g <- if (terra::nlyr(r) >= 3) mean(r[[1:3]]) else r[[1]]
  m <- terra::as.matrix(g, wide = TRUE)
  storage.mode(m) <- "double"
  m
}
hann2 <- function(nr, nc) {
  outer(0.5 - 0.5 * cos(2 * pi * (0:(nr - 1)) / (nr - 1)),
        0.5 - 0.5 * cos(2 * pi * (0:(nc - 1)) / (nc - 1)))
}

# Phase correlation. Returns the shift s (rows, cols) with b[i + s] ~ a[i], refined to sub-pixel
# by a parabola through the peak and its neighbours on each axis, and the peak height of the
# normalised correlation surface (1 = identical, ~0 = unrelated).
phase_corr <- function(a, b) {
  w <- hann2(nrow(a), ncol(a))
  a <- (a - mean(a)) / max(stats::sd(a), 1e-9) * w
  b <- (b - mean(b)) / max(stats::sd(b), 1e-9) * w
  R <- stats::fft(b) * Conj(stats::fft(a))
  R <- R / pmax(Mod(R), 1e-12)
  r <- Re(stats::fft(R, inverse = TRUE)) / length(R)
  nr <- nrow(r); nc <- ncol(r)
  k <- which.max(r)
  i <- (k - 1) %% nr; j <- (k - 1) %/% nr
  g <- function(ii, jj) r[(ii %% nr) + 1, (jj %% nc) + 1]
  par <- function(y0, y1, y2) { d <- y0 - 2 * y1 + y2; if (d == 0) 0 else 0.5 * (y0 - y2) / d }
  si <- i + par(g(i - 1, j), g(i, j), g(i + 1, j))
  sj <- j + par(g(i, j - 1), g(i, j), g(i, j + 1))
  if (si > nr / 2) si <- si - nr
  if (sj > nc / 2) sj <- sj - nc
  c(row = si, col = sj, peak = r[k])
}

down <- function(m, k) {
  nr <- nrow(m) %/% k; nc <- ncol(m) %/% k
  m <- m[seq_len(nr * k), seq_len(nc * k)]
  a <- array(m, c(k, nr, k, nc))
  apply(a, c(2, 4), mean)
}

# Correlation surface of phase correlation (unrefined), for a constrained peak search.
pc_surface <- function(a, b) {
  w <- hann2(nrow(a), ncol(a))
  a <- (a - mean(a)) / max(stats::sd(a), 1e-9) * w
  b <- (b - mean(b)) / max(stats::sd(b), 1e-9) * w
  R <- stats::fft(b) * Conj(stats::fft(a)); R <- R / pmax(Mod(R), 1e-12)
  Re(stats::fft(R, inverse = TRUE)) / length(R)
}

# Global shift of B against A. Relief smears the whole-frame correlation peak, and the
# catalogue's centroid spacing can be wrong by a factor of 1.7 (bc85054 162), so neither the
# top peak nor a tight magnitude window is trusted. Instead the ten highest local maxima of the
# 1/4-resolution surface whose magnitude is within [0.25, 3] of the spacing's prediction are
# each tried as a seed for 128 px patch matching, and the one most patches confirm wins. The
# global shift is then the median of those patches, which follows relief.
MARGIN <- 50
global_shift <- function(a, b, pred_px, n_cand = 10) {
  n <- nrow(a); m <- ncol(a)
  ia <- down(a[(MARGIN + 1):(n - MARGIN), (MARGIN + 1):(m - MARGIN)], 4)
  ib <- down(b[(MARGIN + 1):(n - MARGIN), (MARGIN + 1):(m - MARGIN)], 4)
  r <- pc_surface(ia, ib)
  nr <- nrow(r); nc <- ncol(r)
  di <- (0:(nr - 1)); di[di > nr / 2] <- di[di > nr / 2] - nr
  dj <- (0:(nc - 1)); dj[dj > nc / 2] <- dj[dj > nc / 2] - nc
  mag <- 4 * sqrt(outer(di^2, dj^2, "+"))
  # local maxima in a 5x5 neighbourhood (toroidal)
  sh <- function(x, i, j) x[((seq_len(nr) - 1 + i) %% nr) + 1, ((seq_len(nc) - 1 + j) %% nc) + 1]
  mx <- r
  for (i in -2:2) for (j in -2:2) if (i || j) mx <- pmax(mx, sh(r, i, j))
  cand <- which(r == mx & mag >= 0.25 * pred_px & mag <= 3 * pred_px)
  cand <- cand[order(r[cand], decreasing = TRUE)][seq_len(min(n_cand, length(cand)))]
  best <- NULL; best_n <- 0
  for (k in cand) {
    s0 <- c(row = 4 * di[(k - 1) %% nr + 1], col = 4 * dj[(k - 1) %/% nr + 1])
    p1 <- patch_shifts(a, b, c(s0, peak = NA), pass2 = FALSE, step = 64)
    nk <- if (is.null(p1)) 0 else sum(p1$pk >= 0.1, na.rm = TRUE)
    if (nk > best_n) { best_n <- nk; best <- s0 }
  }
  if (best_n < 8) return(c(row = NA, col = NA, peak = 0, n1 = best_n, coarse_peak = max(r)))
  p1 <- patch_shifts(a, b, c(best, peak = NA), pass2 = FALSE)
  g <- p1[p1$pk >= 0.1 & is.finite(p1$dr), ]
  if (nrow(g) < 20) return(c(row = NA, col = NA, peak = 0, n1 = nrow(g), coarse_peak = max(r)))
  c(row = stats::median(g$dr), col = stats::median(g$dc), peak = stats::median(g$pk), n1 = nrow(g),
    coarse_peak = max(r))
}

# Per-patch 2-D shift, two passes: 128 px windows seeded by the global shift, then 64 px
# windows seeded by the 3x3 median of pass 1 around each patch.
patch_shifts <- function(a, b, gs, step = 32, win = 64, win1 = 128, peak_min = 0.1, pass2 = TRUE) {
  n <- nrow(a); m <- ncol(a)
  h <- win / 2; h1 <- win1 / 2
  lo <- MARGIN + h1; hi_r <- n - MARGIN - h1; hi_c <- m - MARGIN - h1
  rows <- seq(lo, hi_r, by = step); cols <- seq(lo, hi_c, by = step)
  grid <- expand.grid(r = rows, c = cols)
  inb <- function(rr, cc, hh) rr - hh >= MARGIN & rr + hh <= n - MARGIN & cc - hh >= MARGIN & cc + hh <= m - MARGIN
  grid <- grid[inb(grid$r + gs[["row"]], grid$c + gs[["col"]], h1), ]
  if (!nrow(grid)) return(NULL)
  one <- function(i, j, si, sj, hh) {
    ib0 <- round(i + si); jb0 <- round(j + sj)
    if (!inb(ib0, jb0, hh)) return(c(NA, NA, 0))
    pa <- a[(i - hh):(i + hh - 1), (j - hh):(j + hh - 1)]
    pb <- b[(ib0 - hh):(ib0 + hh - 1), (jb0 - hh):(jb0 + hh - 1)]
    if (stats::sd(pa) < 2 || stats::sd(pb) < 2) return(c(NA, NA, 0))
    s <- phase_corr(pa, pb)
    c(ib0 - i + s[["row"]], jb0 - j + s[["col"]], s[["peak"]])
  }
  p1 <- t(vapply(seq_len(nrow(grid)), function(k)
    one(grid$r[k], grid$c[k], gs[["row"]], gs[["col"]], h1), numeric(3)))
  ok1 <- is.finite(p1[, 1]) & p1[, 3] >= peak_min
  if (!pass2) { grid$dr <- p1[, 1]; grid$dc <- p1[, 2]; grid$pk <- p1[, 3]; return(grid) }
  seed <- t(vapply(seq_len(nrow(grid)), function(k) {
    nb <- ok1 & abs(grid$r - grid$r[k]) <= step & abs(grid$c - grid$c[k]) <= step
    if (sum(nb) < 3) return(c(gs[["row"]], gs[["col"]]))
    c(stats::median(p1[nb, 1]), stats::median(p1[nb, 2]))
  }, numeric(2)))
  p2 <- t(vapply(seq_len(nrow(grid)), function(k)
    one(grid$r[k], grid$c[k], seed[k, 1], seed[k, 2], h), numeric(3)))
  grid$dr <- p2[, 1]; grid$dc <- p2[, 2]; grid$pk <- p2[, 3]
  grid$pk1 <- p1[, 3]
  grid
}

# ---- placement ------------------------------------------------------------------------
# Image vector of each patch centre from the principal point (taken as the thumbnail centre),
# x right, y up, in thumbnail px; `mirror` flips x (a scan read from the other side).
img_vec <- function(grid, nr, nc, mirror = FALSE) {
  x <- grid$c - (nc + 1) / 2; y <- (nr + 1) / 2 - grid$r
  if (mirror) x <- -x
  cbind(x, y)
}
# Image-up azimuth on the ground, from the direction content moves (A -> B) and the bearing of
# B's centroid from A's. Camera motion in the image is the opposite of content motion.
image_theta <- function(gs, bearing, mirror = FALSE) {
  dx <- gs[["col"]]; dy <- -gs[["row"]]
  if (mirror) dx <- -dx
  bearing - atan2(-dx, -dy)
}
rot_ground <- function(v, th) cbind(v[, 1] * cos(th) + v[, 2] * sin(th),
                                    -v[, 1] * sin(th) + v[, 2] * cos(th))

# Ground points (EPSG:3005) of each patch centre: drawn at elevation e_w, then ray-cast onto
# the DTM window with the fly#65 ray-cast so relief displacement is followed, not ignored.
place <- function(v, th, centre, H, e_w, f_px, win, scale = 1, off = c(0, 0)) {
  g0 <- rot_ground(v, th) * (H - e_w) / f_px * scale
  ring <- sweep(g0, 2, centre + off, "+")
  rc <- raycast(ring, centre + off, H, e_w, win, step = 5, n_bisect = 20)
  list(xy = rc$xy, e = rc$e, bad = rc$bad)
}

# DEM means at the scale of a patch: a focal mean whose window matches the patch's ground size,
# read bilinearly at each ground point.
smooth_to <- function(r, patch_m) {
  k <- max(1, round(patch_m / terra::res(r)[1]))
  if (k %% 2 == 0) k <- k + 1
  if (k == 1) r else terra::focal(r, w = k, fun = "mean", na.rm = FALSE)
}
at_xy <- function(r, xy) {
  p <- sf::sf_project("EPSG:3005", terra::crs(r), xy, keep = TRUE)
  terra::extract(r, p, method = "bilinear")[, 1]
}

# ---- nuisance -------------------------------------------------------------------------
poly2 <- function(xn, yn) cbind(xn, yn, xn^2, yn^2, xn * yn)
resid_on <- function(y, X) { ok <- is.finite(y) & stats::complete.cases(X); r <- rep(NA_real_, length(y)); r[ok] <- stats::lm.fit(cbind(1, X[ok, , drop = FALSE]), y[ok])$residuals; r }
