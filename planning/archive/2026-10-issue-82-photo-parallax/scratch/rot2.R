source("/private/tmp/claude-501/-Users-airvine-Projects-repo-fly/0e762a6d-f932-4614-9d5b-0fc1d445cb10/scratchpad/p82/dbg2.R")
dtm <- terra::rast(MRDEM_DTM); dsm <- terra::rast(MRDEM_DSM)
set.seed(8202)
fp <- fetch_pair("bc5225", 151); a <- read_gray(fp$dest[1]); g0 <- geom_of(fp$a_row, fp$b_row)
win <- window_of(g0$xyA, FORMAT_MM / 2000 * g0$sn * 2.4)
for (k in c(0, 1)) {
  sp <- synth_pair(a, g0, win$wt, win$ws, kappa = k, flat = FALSE); g1 <- g0; g1$xyB <- sp$xyB
  m <- measure_core(a, sp$b, g1, win$wt, win$ws, register = FALSE)
  sl <- synth_slope(m, g1$H, FALSE)
  cat(sprintf("bc5225 truth kappa %d: slope %+.3f r2full %.3f gse %.3f n %d  qsd %.2f\n", k, sl[["slope"]], sl[["r2_full"]], sl[["g_se"]], sl[["n"]], stats::mad(m$gp$q, na.rm=TRUE)))
}
