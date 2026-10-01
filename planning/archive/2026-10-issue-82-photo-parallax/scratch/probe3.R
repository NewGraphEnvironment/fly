D <- "/private/tmp/claude-501/-Users-airvine-Projects-repo-fly/0e762a6d-f932-4614-9d5b-0fc1d445cb10/scratchpad/p82"
source(file.path(D, "pc.R"))
suppressMessages({library(sf); library(terra)})
terra::gdalCache(128)
BUCKET <- "/vsicurl/https://canelevation-dem.s3.ca-central-1.amazonaws.com/mrdem-30/"
dtm <- rast(paste0(BUCKET, "mrdem-30-dtm.tif")); dsm <- rast(paste0(BUCKET, "mrdem-30-dsm.tif"))
r <- readRDS(file.path(D, "bc5282.rds"))
xy <- st_coordinates(st_transform(r, crs(dtm)))
pair <- function(fa, PATCH = 48, WIN = 64, STEP = 24) {
  ia <- which(r$frame_number == fa); ib <- which(r$frame_number == fa + 1)
  a <- read_gray(sprintf("%s/thumbs/bc5282_%d_thumb.jpg", D, fa))
  b <- read_gray(sprintf("%s/thumbs/bc5282_%d_thumb.jpg", D, fa + 1))
  g <- phase_corr(a[26:1225, 26:1225], b[26:1225, 26:1225])
  sr <- g[["row"]]; sc <- g[["col"]]
  # patch grid in A whose B counterpart is inside B
  rows <- seq(40 + WIN, 1210 - WIN, by = STEP); cols <- seq(40 + WIN, 1210 - WIN, by = STEP)
  grid <- expand.grid(r = rows, c = cols)
  grid <- grid[grid$r + sr > 40 + WIN & grid$r + sr < 1210 - WIN &
               grid$c + sc > 40 + WIN & grid$c + sc < 1210 - WIN, ]
  h <- WIN / 2
  res <- t(vapply(seq_len(nrow(grid)), function(k) {
    i <- grid$r[k]; j <- grid$c[k]
    ib0 <- round(i + sr); jb0 <- round(j + sc)
    pa <- a[(i - h):(i + h - 1), (j - h):(j + h - 1)]
    pb <- b[(ib0 - h):(ib0 + h - 1), (jb0 - h):(jb0 + h - 1)]
    if (sd(pa) < 2 || sd(pb) < 2) return(c(NA, NA, NA))
    s <- phase_corr(pa, pb)
    c(ib0 - i + s[["row"]], jb0 - j + s[["col"]], s[["peak"]])
  }, numeric(3)))
  grid$dr <- res[, 1]; grid$dc <- res[, 2]; grid$pk <- res[, 3]
  # image frame: x right, y up; content motion (dx, dy) = (dc, -dr)
  dx <- sc; dy <- -sr
  bvec <- c(xy[ib, 1] - xy[ia, 1], xy[ib, 2] - xy[ia, 2])
  B <- sqrt(sum(bvec^2)); bear <- atan2(bvec[1], bvec[2])
  a_img <- atan2(-dx, -dy); th <- bear - a_img
  px <- B / sqrt(dx^2 + dy^2)          # ground metres per pixel implied by centroid base
  x <- (grid$c - 625.5) * px; y <- (625.5 - grid$r) * px
  grid$E <- xy[ia, 1] + x * cos(th) + y * sin(th)
  grid$N <- xy[ia, 2] - x * sin(th) + y * cos(th)
  # parallax along the base direction (unit image vector of content motion)
  u <- c(dx, dy) / sqrt(dx^2 + dy^2)
  grid$p  <- grid$dc * u[1] + (-grid$dr) * u[2]
  grid$q  <- -grid$dc * u[2] + (-grid$dr) * u[1]   # y-parallax
  # DEM means over each patch (square, PATCH px)
  hw <- PATCH / 2 * px
  e <- ext(min(grid$E) - 2 * hw, max(grid$E) + 2 * hw, min(grid$N) - 2 * hw, max(grid$N) + 2 * hw)
  t1 <- crop(dtm, e); s1 <- crop(dsm, e)
  pts <- vect(cbind(grid$E, grid$N), crs = crs(dtm))
  sq <- buffer(pts, hw, capstyle = "square")
  grid$dtm <- extract(t1, sq, fun = mean, ID = FALSE)[[1]]
  grid$dsm <- extract(s1, sq, fun = mean, ID = FALSE)[[1]]
  grid$can <- grid$dsm - grid$dtm
  attr(grid, "info") <- c(B = B, px = px, shift = sqrt(dx^2 + dy^2), peak = g[["peak"]],
                          H = r$flying_height[ia], bear = bear * 180 / pi, th = th * 180 / pi)
  grid
}
fit <- function(grid) {
  inf <- attr(grid, "info")
  g <- grid[is.finite(grid$p) & is.finite(grid$dtm) & grid$pk > 0.15 & abs(grid$q - median(grid$q, na.rm=TRUE)) < 3, ]
  p0 <- median(g$p); Hh <- inf[["H"]] - median(g$dtm)
  g$hpar <- Hh * (1 - p0 / g$p)                 # relative height from parallax, metres
  g$xn <- (g$c - 625) / 625; g$yn <- (625 - g$r) / 625
  m <- lm(hpar ~ xn + yn + I(xn^2) + I(yn^2) + I(xn * yn) + dtm + can, data = g)
  m0 <- lm(hpar ~ dtm + can, data = g)
  list(n = nrow(g), info = inf, coef = summary(m)$coefficients[c("dtm", "can"), 1:2],
       coef0 = summary(m0)$coefficients[c("dtm", "can"), 1:2],
       sd_dtm = sd(g$dtm), sd_can = sd(g$can), mean_can = mean(g$can),
       cor_dc = cor(g$dtm, g$can), resid_sd = sd(resid(m)))
}
for (fa in c(226, 229, 230, 231, 233, 234, 235)) {
  g <- pair(fa); f <- fit(g)
  cat(sprintf("\n%d->%d n=%d shift=%.1f px=%.2f m B=%.0f  sd_dtm=%.1f sd_can=%.1f mean_can=%.1f cor=%.2f resid=%.1f\n",
              fa, fa + 1, f$n, f$info[["shift"]], f$info[["px"]], f$info[["B"]], f$sd_dtm, f$sd_can, f$mean_can, f$cor_dc, f$resid_sd))
  print(round(f$coef, 3)); print(round(f$coef0, 3))
  saveRDS(g, sprintf("%s/grid_%d.rds", D, fa))
}
