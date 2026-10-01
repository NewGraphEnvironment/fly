D <- "/private/tmp/claude-501/-Users-airvine-Projects-repo-fly/0e762a6d-f932-4614-9d5b-0fc1d445cb10/scratchpad/p82"
suppressMessages({library(terra)})
BUCKET <- "/vsicurl/https://canelevation-dem.s3.ca-central-1.amazonaws.com/mrdem-30/"
dtm <- rast(paste0(BUCKET, "mrdem-30-dtm.tif")); dsm <- rast(paste0(BUCKET, "mrdem-30-dsm.tif"))
prep <- function(g) {
  inf <- attr(g, "info")
  g <- g[is.finite(g$p) & g$pk > 0.15 & abs(g$q - median(g$q, na.rm = TRUE)) < 3, ]
  p0 <- median(g$p); Hh <- inf[["H"]] - median(g$dtm, na.rm = TRUE)
  g$hpar <- Hh * (1 - p0 / g$p); g$xn <- (g$c - 625) / 625; g$yn <- (625 - g$r) / 625
  attr(g, "info") <- inf; g
}
sample_at <- function(g, dE, dN, t1, s1, hw) {
  sq <- buffer(vect(cbind(g$E + dE, g$N + dN), crs = crs(dtm)), hw, capstyle = "square")
  g$dtm <- extract(t1, sq, fun = mean, ID = FALSE)[[1]]
  g$dsm <- extract(s1, sq, fun = mean, ID = FALSE)[[1]]
  g$can <- g$dsm - g$dtm; g
}
form <- hpar ~ xn + yn + I(xn^2) + I(yn^2) + I(xn * yn)
for (fa in c(226, 229, 230, 231, 233, 234, 235)) {
  g <- prep(readRDS(sprintf("%s/grid_%d.rds", D, fa))); inf <- attr(g, "info")
  hw <- 24 * inf[["px"]]
  e <- ext(min(g$E) - 600, max(g$E) + 600, min(g$N) - 600, max(g$N) + 600)
  t1 <- crop(dtm, e); s1 <- crop(dsm, e)
  offs <- expand.grid(dE = seq(-300, 300, 30), dN = seq(-300, 300, 30))
  r2 <- vapply(seq_len(nrow(offs)), function(k) {
    gg <- sample_at(g, offs$dE[k], offs$dN[k], t1, s1, hw)
    summary(lm(update(form, . ~ . + dtm), data = gg))$r.squared
  }, numeric(1))
  k <- which.max(r2)
  gg <- sample_at(g, offs$dE[k], offs$dN[k], t1, s1, hw)
  m <- lm(update(form, . ~ . + dtm + can), data = gg)
  ms <- lm(update(form, . ~ . + dsm), data = gg); md <- lm(update(form, . ~ . + dtm), data = gg)
  cf <- summary(m)$coefficients
  cat(sprintf("%d  off (%+4.0f,%+4.0f) R2 %.3f (0,0: %.3f) | dtm %.3f (%.3f) can %+.3f (%.3f) | R2 dtm-only %.4f dsm-only %.4f\n",
              fa, offs$dE[k], offs$dN[k], r2[k], r2[offs$dE == 0 & offs$dN == 0],
              cf["dtm", 1], cf["dtm", 2], cf["can", 1], cf["can", 2],
              summary(md)$r.squared, summary(ms)$r.squared))
}
