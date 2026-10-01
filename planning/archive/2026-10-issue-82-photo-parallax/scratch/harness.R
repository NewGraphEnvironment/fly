source("/private/tmp/claude-501/-Users-airvine-Projects-repo-fly/0e762a6d-f932-4614-9d5b-0fc1d445cb10/scratchpad/p82/dbg2.R")
dtm <- terra::rast(MRDEM_DTM); dsm <- terra::rast(MRDEM_DSM)
hann_w <- function(k) { h <- 0.5 - 0.5 * cos(2 * pi * (0:(k - 1)) / (k - 1)); w <- outer(h, h); w / sum(w) }
smooth_w <- function(r, patch_m, kind) {
  k <- max(3, round(patch_m / terra::res(r)[1])); if (k %% 2 == 0) k <- k + 1
  if (kind == "box") terra::focal(r, w = k, fun = "mean", na.rm = FALSE) else terra::focal(r, w = hann_w(k), fun = "sum", na.rm = FALSE)
}
slopes <- function(m, wt, ws, H) {
  gp <- m$gp[usable(m$gp), ]; xy <- cbind(gp$E, gp$N)
  y <- implied_height(gp, H, m$e_w); out <- c()
  for (kind in c("box", "hann")) {
    d <- at_xy(smooth_w(wt, m$patch_m, kind), xy); C <- at_xy(smooth_w(ws, m$patch_m, kind), xy) - d
    sl <- terra::terrain(smooth_w(wt, m$patch_m, kind), c("slope", "aspect"), unit = "radians")
    s_ <- at_xy(sl[["slope"]], xy); a_ <- at_xy(sl[["aspect"]], xy)
    gE <- tan(s_) * sin(a_); gN <- tan(s_) * cos(a_)
    for (grad in c(FALSE, TRUE)) {
      N <- cbind(poly2(gp$xn, gp$yn), d); if (grad) N <- cbind(N, gE, gN)
      ok <- is.finite(y) & is.finite(C) & stats::complete.cases(N)
      f <- stats::lm.fit(cbind(1, N[ok, ], C[ok]), y[ok]); cf <- f$coefficients
      bC <- unname(utils::tail(cf, 1)); gD <- unname(cf[1 + ncol(poly2(1, 1)) + 1])
      out[paste(kind, if (grad) "grad" else "nograd", sep = "_")] <- bC
      out[paste(kind, if (grad) "grad" else "nograd", "gnorm", sep = "_")] <- bC / gD
    }
  }
  out
}
SRCS <- data.frame(film_roll = c("bc78008", "bc85054", "bcc01030"), frame_number = c(184, 162, 156))
set.seed(8202)
rows <- list()
for (i in 1:3) for (cs in c("dtm_C0", "dtm_C1")) for (rg in c("free")) {
  fp <- fetch_pair(SRCS$film_roll[i], SRCS$frame_number[i]); a <- read_gray(fp$dest[1]); g0 <- geom_of(fp$a_row, fp$b_row)
  win <- window_of(g0$xyA, FORMAT_MM / 2000 * g0$sn * 2.4)
  sp <- synth_pair(a, g0, win$wt, win$ws, kappa = as.numeric(grepl("C1$", cs)), flat = grepl("^flat", cs))
  g1 <- g0; g1$xyB <- sp$xyB
  set.seed(8202 + i); m <- measure_core(a, sp$b, g1, win$wt, win$ws, register = rg != "none", reg_on = rg)
  sl <- if (identical(m$status, "ok")) slopes(m, win$wt, win$ws, g1$H) else NA
  cat(sprintf("%-9s %-8s %-5s %-10s %s\n", SRCS$film_roll[i], cs, rg, m$status, paste(sprintf("%s=%+.3f", names(sl), sl), collapse = " ")))
  rows[[length(rows) + 1]] <- c(roll = SRCS$film_roll[i], case = cs, sl)
}
saveRDS(rows, file.path("/private/tmp/claude-501/-Users-airvine-Projects-repo-fly/0e762a6d-f932-4614-9d5b-0fc1d445cb10/scratchpad/p82", "harness3.rds"))
