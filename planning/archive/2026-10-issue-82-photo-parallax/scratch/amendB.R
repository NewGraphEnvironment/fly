D <- "/private/tmp/claude-501/-Users-airvine-Projects-repo-fly/0e762a6d-f932-4614-9d5b-0fc1d445cb10/scratchpad/p82"
suppressMessages({library(sf); library(terra)}); sf_use_s2(FALSE)
source(file.path(D, "lib.R"))
SRC <- rast("/vsicurl/https://canelevation-dem.s3.ca-central-1.amazonaws.com/mrdem-30/mrdem-30-source.tif")
DTM <- rast("/vsicurl/https://canelevation-dem.s3.ca-central-1.amazonaws.com/mrdem-30/mrdem-30-dtm.tif")
res <- list(); pw <- list()
for (f in list.files(file.path(D, "m0"), full.names = TRUE)) {
  m <- readRDS(f); if (!identical(m$status, "ok")) next
  g <- m$gp; yr <- m$info[["year"]]; pm <- m$info[["patch_m"]]
  X <- poly2(g$xn, g$yn)
  ok <- is.finite(g$p) & g$pk >= 0.1 & is.finite(g$C) & is.finite(g$dtm) & !g$ray_bad
  qr <- rep(NA, nrow(g)); qr[ok] <- resid_on(g$q[ok], X[ok, ]); keep <- ok & abs(qr) <= 3 * stats::mad(qr, na.rm = TRUE)
  g <- g[keep, ]; qr <- qr[keep]
  v <- st_make_valid(st_transform(readRDS(file.path(D, "vri", basename(f))), 3005))
  age <- suppressWarnings(as.numeric(v$PROJ_AGE_1)); pyr <- as.numeric(substr(as.character(v$PROJECTED_DATE), 1, 4))
  treed <- v$BCLCS_LEVEL_2 %in% "T"; ap <- age - (pyr - yr); O <- pyr - age
  # single-source share of each patch footprint (square + 60 m), and class by area share
  pts <- st_as_sf(data.frame(x = g$E, y = g$N), coords = c("x", "y"), crs = 3005)
  hs <- pm / 2 + 60
  sq <- st_as_sf(st_sfc(lapply(seq_len(nrow(g)), function(i) st_polygon(list(cbind(g$E[i] + c(-hs, hs, hs, -hs, -hs), g$N[i] + c(-hs, -hs, hs, hs, -hs))))), crs = 3005))
  disc <- sq
  e <- ext(project(vect(st_as_sfc(st_bbox(sq))), crs(SRC)))
  sc <- crop(SRC, e)
  radar <- terra::extract(sc == 1, vect(st_transform(sq, crs(SRC))), fun = mean, ID = FALSE)[[1]]
  lidar <- terra::extract(sc == 10, vect(st_transform(sq, crs(SRC))), fun = mean, ID = FALSE)[[1]]
  vcls <- ifelse(!treed | !is.finite(ap), "other", ifelse(ap < 0, "post", ifelse(ap < 3, "edge0_3",
           ifelse(ap <= 10, "young", ifelse(ap >= 80, "old", "mid")))))
  v$vcls <- vcls
  dis <- do.call(rbind, lapply(unique(vcls), function(k) st_sf(vcls = k, geometry = st_union(v[v$vcls == k, ]))))
  A <- as.numeric(st_area(sq))
  share <- sapply(dis$vcls, function(k) { it <- suppressWarnings(st_intersection(sq, dis[dis$vcls == k, ])); out <- numeric(nrow(sq)); if (nrow(it)) { ix <- st_intersects(sq, dis[dis$vcls == k, ]); ar <- vapply(seq_len(nrow(sq)), function(i) if (length(ix[[i]])) as.numeric(st_area(st_intersection(st_geometry(sq)[i], st_geometry(dis[dis$vcls == k, ])))) else 0, numeric(1)); out <- ar / A }; out })
  share <- matrix(share, nrow = nrow(sq)); colnames(share) <- dis$vcls
  best <- apply(share, 1, which.max); bshare <- share[cbind(seq_len(nrow(sq)), best)]
  cls_disc <- ifelse(bshare >= 0.9, colnames(share)[best], "other")
  single <- (radar >= 0.99 | lidar >= 0.99) & is.finite(radar)
  cls_disc[!single] <- "other"
  pid <- vapply(st_intersects(st_centroid(sq), v), function(k) if (length(k)) k[1] else NA_integer_, integer(1))
  # cutblock corroboration for young: a consolidated cutblock harvested within [photo-12, photo-1] covering the disc centre
  cbf <- file.path(D, "cut", basename(f)); dir.create(dirname(cbf), showWarnings = FALSE)
  if (!file.exists(cbf)) {
    bb <- st_as_sfc(st_bbox(disc))
    cb <- tryCatch(bcdata::bcdc_query_geodata("WHSE_FOREST_VEGETATION.VEG_CONSOLIDATED_CUT_BLOCKS_SP") |>
      bcdata::filter(bcdata::INTERSECTS(bb)) |> bcdata::select(HARVEST_START_YEAR_CALENDAR) |> bcdata::collect(), error = function(e) NULL)
    saveRDS(cb, cbf)
  }
  cb <- readRDS(cbf)
  corr <- rep(FALSE, nrow(g))
  if (!is.null(cb) && nrow(cb)) {
    cb <- st_transform(cb, 3005); hy <- suppressWarnings(as.numeric(cb$HARVEST_START_YEAR_CALENDAR))
    cbk <- cb[is.finite(hy) & hy >= yr - 12 & hy <= yr - 1, ]
    if (nrow(cbk)) corr <- lengths(st_intersects(pts, cbk)) > 0
  }
  # r under linear and a concave curve (Chapman-Richards shape, k = 0.03, c = 1.3) for y/m/o
  lin <- function(a, now) pmin(pmax(a / now, 0), 1)
  cr <- function(t) (1 - exp(-0.03 * pmax(t, 0)))^1.3
  apx <- ap[pid]; nowx <- ifelse(radar >= 0.99, 2013, 2018) - O[pid]
  r_lin <- ifelse(cls_disc %in% c("mid", "old"), lin(apx, nowx), NA)
  r_con <- ifelse(cls_disc %in% c("mid", "old"), pmin(cr(apx) / cr(nowx), 1), NA)
  res[[f]] <- data.frame(roll = m$roll, year = yr, n = nrow(g), radar_ok = sum(radar >= 0.99, na.rm = TRUE), lidar_ok = sum(lidar >= 0.99, na.rm = TRUE),
    young = sum(cls_disc == "young"), young_cut = sum(cls_disc == "young" & corr), edge0_3 = sum(cls_disc == "edge0_3"),
    old = sum(cls_disc == "old"), mid = sum(cls_disc == "mid"), post = sum(cls_disc == "post"))
  # power with gradient nuisance and q-based sigma; with / without class intercepts
  grd <- terrain(crop(DTM, ext(project(vect(st_as_sfc(st_bbox(disc))), crs(DTM)))), c("slope", "aspect"), unit = "radians")
  sl <- at_xy(grd[["slope"]], cbind(g$E, g$N)); as <- at_xy(grd[["aspect"]], cbind(g$E, g$N))
  gE <- tan(sl) * sin(as); gN <- tan(sl) * cos(as)
  N <- cbind(poly2(g$xn, g$yn), g$dtm, gE, gN)
  sig <- (m$info[["H"]] - m$info[["e_w"]]) / median(g$p) * 1.4826 * stats::mad(qr)
  srcl <- ifelse(radar >= 0.99, "r", ifelse(lidar >= 0.99, "l", NA))
  cl5 <- ifelse(cls_disc %in% c("mid", "old") & !is.na(srcl), paste0(cls_disc, "_", srcl),
         ifelse(cls_disc %in% c("post"), "post", "other"))
  KK <- c("mid_r", "mid_l", "old_r", "old_l", "post", "other")
  Z <- sapply(KK, function(k) g$C * (cl5 == k))
  Dm <- sapply(KK[1:5], function(k) as.numeric(cl5 == k))
  okN <- stats::complete.cases(N)
  Zp <- apply(Z[okN, , drop = FALSE], 2, function(z) resid_on(z, N[okN, ]))
  Zi <- apply(Z[okN, , drop = FALSE], 2, function(z) resid_on(z, cbind(N[okN, ], Dm[okN, colSums(Dm[okN, , drop = FALSE]) > 0, drop = FALSE])))
  pw[[f]] <- list(I0 = crossprod(Zp) / sig^2, I1 = crossprod(Zi) / sig^2, sig = sig,

                  rl = list(r_lin = r_lin, r_con = r_con, cls = cl5, Zp = Zp, C = g$C[okN]))
}
tab <- do.call(rbind, res); print(tab, row.names = FALSE); cat("totals:\n"); print(colSums(tab[, -(1:2)]))
I0 <- Reduce(`+`, lapply(pw, `[[`, "I0")); I1 <- Reduce(`+`, lapply(pw, `[[`, "I1"))
se <- function(I) { k <- diag(I) > 1e-9; s <- rep(NA, ncol(I)); s[k] <- sqrt(4 * diag(solve(I[k, k]))); setNames(s, colnames(I)) }
cat("SE without class intercepts (DEFF 4):\n"); print(round(se(I0), 3))
cat("SE with class intercepts (DEFF 4):\n"); print(round(se(I1), 3))
cat("sigma per pair (m):", round(sapply(pw, `[[`, "sig"), 1), "\n")
rb <- function(which) {
  num <- c(mid_r = 0, old_r = 0, mid_l = 0, old_l = 0); den <- num
  for (p in pw) { z <- p$rl; okc <- z$cls[seq_len(nrow(z$Zp))]
    for (k in names(num)) { i <- which(okc == k & is.finite(z[[which]][seq_len(nrow(z$Zp))]))
      num[k] <- num[k] + sum(z[[which]][i] * z$C[i] * z$Zp[i, k]); den[k] <- den[k] + sum(z$Zp[i, k]^2) } }
  r <- num / den; c(r, phi_r = unname(r["mid_r"] / r["old_r"]), phi_l = unname(r["mid_l"] / r["old_l"]))
}
cat("linear  :", round(rb("r_lin"), 3), "\n"); cat("concave :", round(rb("r_con"), 3), "\n")
