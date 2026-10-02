source("/private/tmp/claude-501/-Users-airvine-Projects-repo-fly/0e762a6d-f932-4614-9d5b-0fc1d445cb10/scratchpad/p82/dbg2.R")
dtm <- terra::rast(MRDEM_DTM); dsm <- terra::rast(MRDEM_DSM)
set.seed(8202)
fp <- fetch_pair("bc78008", 184); a <- read_gray(fp$dest[1]); g0 <- geom_of(fp$a_row, fp$b_row)
win <- window_of(g0$xyA, FORMAT_MM / 2000 * g0$sn * 2.4)
sp <- synth_pair(a, g0, win$wt, win$ws, kappa = 1, flat = FALSE)
g1 <- g0; g1$xyB <- sp$xyB
for (rg in c("free", "open")) { set.seed(1)
  m <- measure_core(a, sp$b, g1, win$wt, win$ws, register = TRUE, reg_on = rg)
  print(rg); print(round(m$reg, 3)); print(round(synth_slope(m, g1$H, FALSE), 3)) }
m0 <- measure_core(a, sp$b, g1, win$wt, win$ws, register = FALSE)
print("none"); print(round(m0$reg, 3)); print(round(synth_slope(m0, g1$H, FALSE), 3))
gp <- m0$gp; ok <- is.finite(gp$p) & gp$pk >= 0.1 & gp$p > 0
cat("n matched", sum(ok), " patch_m", m0$patch_m, " gsd", m0$gsd, "\n")
