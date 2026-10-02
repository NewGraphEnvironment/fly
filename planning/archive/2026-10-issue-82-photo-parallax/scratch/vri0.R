D <- "/private/tmp/claude-501/-Users-airvine-Projects-repo-fly/0e762a6d-f932-4614-9d5b-0fc1d445cb10/scratchpad/p82"
suppressMessages({library(sf)}); sf_use_s2(FALSE)
source(file.path(D, "lib.R"))
fs <- list.files(file.path(D, "m0"), full.names = TRUE)
rows <- list()
for (f in fs) {
  m <- readRDS(f); if (!identical(m$status, "ok")) next
  g <- m$gp; yr <- m$info[["year"]]
  X <- poly2(g$xn, g$yn)
  ok <- is.finite(g$p) & g$pk >= 0.1 & is.finite(g$C) & !g$ray_bad
  qr <- rep(NA, nrow(g)); qr[ok] <- resid_on(g$q[ok], X[ok, ])
  mad <- stats::mad(qr, na.rm = TRUE)
  keep <- ok & abs(qr) <= 3 * mad
  vf <- file.path(D, "vri", basename(f)); dir.create(dirname(vf), showWarnings = FALSE)
  if (!file.exists(vf)) {
    bb <- c(min(g$E[keep]), min(g$N[keep]), max(g$E[keep]), max(g$N[keep]))
    poly <- st_as_sfc(st_bbox(c(xmin = bb[1], ymin = bb[2], xmax = bb[3], ymax = bb[4]), crs = st_crs(3005)))
    v <- bcdata::bcdc_query_geodata("WHSE_FOREST_VEGETATION.VEG_COMP_LYR_R1_POLY") |>
      bcdata::filter(bcdata::INTERSECTS(poly)) |>
      bcdata::select(PROJ_AGE_1, PROJ_HEIGHT_1, PROJECTED_DATE, BCLCS_LEVEL_2) |> bcdata::collect()
    saveRDS(v, vf)
  }
  v <- readRDS(vf)
  v$age_photo <- suppressWarnings(as.numeric(v$PROJ_AGE_1)) - (as.numeric(substr(as.character(v$PROJECTED_DATE), 1, 4)) - yr)
  v$cls <- ifelse(is.na(v$age_photo), "none", ifelse(v$age_photo >= 0 & v$age_photo <= 5, "young",
            ifelse(v$age_photo >= 80 & v$BCLCS_LEVEL_2 %in% "T", "old", ifelse(v$age_photo < 0, "post", "mid"))))
  h <- m$info[["patch_m"]] / 4
  cls_at <- function(dx, dy) {
    p <- st_as_sf(data.frame(x = g$E + dx, y = g$N + dy), coords = c("x", "y"), crs = 3005)
    ix <- st_intersects(p, v)
    vapply(ix, function(k) if (length(k)) v$cls[k[1]] else NA_character_, character(1))
  }
  cc <- sapply(list(c(0,0), c(-h,-h), c(-h,h), c(h,-h), c(h,h)), function(d) cls_at(d[1], d[2]))
  same <- apply(cc, 1, function(z) if (all(!is.na(z)) && length(unique(z)) == 1) z[1] else "mixed")
  t <- table(factor(same[keep], levels = c("young", "old", "mid", "post", "none", "mixed")))
  cy <- tapply(g$C[keep], same[keep], function(z) round(mean(z), 1))
  rows[[f]] <- data.frame(roll = m$roll, year = yr, n_keep = sum(keep), q_mad_px = round(mad * 1.4826, 3),
                          young = t[["young"]], old = t[["old"]], mid = t[["mid"]], post = t[["post"]],
                          none = t[["none"]], mixed = t[["mixed"]], C_young = unname(cy["young"]), C_old = unname(cy["old"]), n_vri = nrow(v))
}
tab <- do.call(rbind, rows); options(width = 200); print(tab, row.names = FALSE)
