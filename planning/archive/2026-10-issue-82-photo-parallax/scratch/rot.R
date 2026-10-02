source("/private/tmp/claude-501/-Users-airvine-Projects-repo-fly/0e762a6d-f932-4614-9d5b-0fc1d445cb10/scratchpad/p82/dbg2.R")
dtm <- terra::rast(MRDEM_DTM); dsm <- terra::rast(MRDEM_DSM)
for (src in list(c("bc78008", 184), c("bc5225", 151), c("bcc04013", 120))) {
  set.seed(8202)
  fp <- fetch_pair(src[1], as.integer(src[2])); a <- read_gray(fp$dest[1]); g0 <- geom_of(fp$a_row, fp$b_row)
  win <- window_of(g0$xyA, FORMAT_MM / 2000 * g0$sn * 2.4)
  sp <- synth_pair(a, g0, win$wt, win$ws, kappa = 1, flat = FALSE)
  g1 <- g0; g1$xyB <- sp$xyB
  for (rt in c(TRUE, FALSE)) {
    m <- measure_core(a, sp$b, g1, win$wt, win$ws, register = TRUE, rotate = rt)
    sl <- synth_slope(m, g1$H, FALSE)
    cat(sprintf("%-9s rotate=%-5s %s  reg %s  slope %+.3f r2full %.3f gse %.3f n %d\n", src[1], rt, m$status,
      paste(sprintf("%s=%.2f", names(m$reg), m$reg), collapse = " "), sl[["slope"]], sl[["r2_full"]], sl[["g_se"]], sl[["n"]]))
  }
}
