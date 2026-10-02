D <- "/private/tmp/claude-501/-Users-airvine-Projects-repo-fly/0e762a6d-f932-4614-9d5b-0fc1d445cb10/scratchpad/p82"
suppressMessages({library(sf)}); sf_use_s2(FALSE)
source(file.path(D, "lib.R"))
info <- c(young = 0, old = 0, other = 0); cnt <- c(young = 0, old = 0, other = 0); npair <- 0
per <- list()
for (f in list.files(file.path(D, "m0"), full.names = TRUE)) {
  m <- readRDS(f); if (!identical(m$status, "ok")) next
  g <- m$gp; yr <- m$info[["year"]]; X <- poly2(g$xn, g$yn)
  ok <- is.finite(g$p) & g$pk >= 0.1 & is.finite(g$C) & is.finite(g$dtm) & !g$ray_bad
  qr <- rep(NA, nrow(g)); qr[ok] <- resid_on(g$q[ok], X[ok, ]); keep <- ok & abs(qr) <= 3 * stats::mad(qr, na.rm = TRUE)
  v <- readRDS(file.path(D, "vri", basename(f)))
  v$age_photo <- suppressWarnings(as.numeric(v$PROJ_AGE_1)) - (as.numeric(substr(as.character(v$PROJECTED_DATE), 1, 4)) - yr)
  v$cls <- ifelse(is.na(v$age_photo), "other", ifelse(v$age_photo >= 0 & v$age_photo <= 10, "young",
            ifelse(v$age_photo >= 80 & v$BCLCS_LEVEL_2 %in% "T", "old", "other")))
  h <- m$info[["patch_m"]] / 4
  cc <- sapply(list(c(0,0), c(-h,-h), c(-h,h), c(h,-h), c(h,h)), function(d) {
    p <- st_as_sf(data.frame(x = g$E + d[1], y = g$N + d[2]), coords = c("x", "y"), crs = 3005)
    ix <- st_intersects(p, v); vapply(ix, function(k) if (length(k)) v$cls[k[1]] else "other", character(1)) })
  cls <- apply(cc, 1, function(z) { t <- table(z); if (max(t) >= 4) names(t)[which.max(t)] else "other" })
  g <- g[keep, ]; cls <- cls[keep]; X <- X[keep, ]
  fit <- stats::lm.fit(cbind(1, X, g$dtm), 1 / g$p); bD <- utils::tail(fit$coefficients, 1)
  s2 <- (stats::sd(fit$residuals) / abs(bD))^2
  Z <- sapply(c("young", "old", "other"), function(k) g$C * (cls == k))
  Zp <- apply(Z, 2, function(z) resid_on(z, cbind(X, g$dtm)))
  I <- crossprod(Zp) / s2
  info <- info + diag(I); cnt <- cnt + colSums(Z != 0); npair <- npair + 1
  per[[f]] <- c(year = yr, n = nrow(g), res_m = sqrt(s2), table(factor(cls, levels = c("young", "old", "other"))))
}
print(do.call(rbind, per))
DEFF <- 4
se <- sqrt(DEFF / info)
cat("pairs", npair, "\npatches by class", cnt, "\npooled SE (DEFF 4) over these pairs:", round(se, 3), "\n")
cat("SE at 50 pairs/decade, scaled:", round(se * sqrt(npair / 50), 3), "\n")
