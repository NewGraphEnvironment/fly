# A frame over forest, sized from a bare-earth DEM or from a surface model (fly#80).
#
# MRDEM-30 publishes a DSM on its DTM's own grid, and `fly_footprint()` has no notion of
# which one it is handed: it sizes from the mean of whatever surface it reads. So "pass a
# DSM" is not a pure datum shift — the surface also feeds the fly#54 height check, which
# holds `flying_height - elev` against `scale x focal_length`, and a canopy can move a frame
# across that band. See `inst/notes/terrain-correction.md`, "A forested frame is sized from
# bare earth (fly#80)", whose tables are rebuilt from the shipped data further down.

# One film frame whose reported height sits just inside the lower edge of
# `fly_height_ratio_band()` over ground at 700 m: nominal height above ground is
# 12000 x 0.153 = 1836 m, and the reported height puts it at a ratio of 0.63.
edge_frame <- function() {
  f <- height_fixture()[1, ]
  f$flying_height <- 700 + 0.63 * 12000 * 0.153
  f
}

test_that("a canopy moves a frame across the height band, so a DSM is not a pure datum shift", {
  skip_if_no_terra()
  f <- edge_frame()
  band <- fly_height_ratio_band()
  # Premise: 0.63 sits inside the band over bare ground and 30 m of canopy takes it out.
  expect_gt(0.63, band[1])
  expect_lt((f$flying_height - 730) / (12000 * 0.153), band[1])

  ground <- suppressWarnings(fly_footprint(f, dem = flat_dem(700)))
  canopy <- suppressWarnings(fly_footprint(f, dem = flat_dem(730)))
  expect_identical(ground$height_source, "reported")
  expect_identical(ground$footprint_terrain, "dem_agl")
  # Over the canopy the same frame is disputed and falls back to nominal scale.
  expect_false(identical(canopy$height_source, "reported"))
  expect_identical(canopy$footprint_terrain, "nominal_scale")

  # And a frame well inside the band takes the canopy as a datum shift, exactly: its side
  # shrinks by c / (agl - c) relative to the ground-sized one. (c / agl, the first-order
  # form, is 1.7e-4 away, 1.3% in relative terms, so the tolerance separates them.)
  g <- height_fixture()[1, ]
  a <- suppressWarnings(fly_footprint(g, dem = flat_dem(700)))
  b <- suppressWarnings(fly_footprint(g, dem = flat_dem(725)))
  expect_identical(c(a$height_source, b$height_source), c("reported", "reported"))
  side <- function(fp) sqrt(as.numeric(sf::st_area(fp)))
  expect_equal(side(a) / side(b) - 1, 25 / (a$height_agl - 25), tolerance = 1e-6)
})


# ---------------------------------------------------------------------------
# The measurement, recomputed from what `data-raw/dem_measure-canopy_height.R` shipped.
# The note's fly#80 tables are rebuilt row by row and counted. Not asserted, because no
# shipped table carries them: the census's median nominal height above ground (4,575 m), the
# canopy-epoch sensitivity at +/- 3 years, and the site windows' Meta and HRDEM columns. The
# prose is read only where a figure is matched below.
# ---------------------------------------------------------------------------

canopy_tables <- function() {
  f <- function(n) system.file("extdata", paste0("dem_canopy_", n, ".csv"), package = "fly")
  paths <- vapply(c("sample", "epoch", "lidar", "coastal", "versions", "census"), f, "")
  if (any(paths == "")) return(NULL)
  rd <- function(p) utils::read.csv(p, stringsAsFactors = FALSE)
  s <- rd(paths[["sample"]])
  s$d <- sqrt(s$area_w_dtm / s$area_w_dsm) - 1
  a <- s[s$admitted & is.finite(s$d), ]
  e <- merge(rd(paths[["epoch"]]), s[, c("airp_id", "weight", "decade")], by = "airp_id")
  # Amendment 5: known only with a finite ratio and under half the VRI area undated.
  e$known <- is.finite(e$r) & is.finite(e$unknown_share) & e$unknown_share < .5
  list(sample = s, admitted = a, epoch = e, lidar = rd(paths[["lidar"]]),
       coastal = rd(paths[["coastal"]]), versions = rd(paths[["versions"]]),
       census = rd(paths[["census"]]))
}

wq <- function(x, w, p) {
  k <- is.finite(x) & is.finite(w)
  x <- x[k]
  w <- w[k]
  o <- order(x)
  x[o][which(cumsum(w[o]) / sum(w) >= p)[1]]
}

canopy_section <- function() {
  np <- system.file("notes/terrain-correction.md", package = "fly")
  if (np == "") return(NULL)
  md <- readLines(np, warn = FALSE)
  start <- grep("^## A forested frame is sized from bare earth", md)
  h2 <- grep("^## ", md)
  md[seq(start, min(h2[h2 > start]) - 1)]
}

test_that("the canopy shift is not material: weighted 95th under 1% of width", {
  x <- canopy_tables()
  skip_if(is.null(x), "the canopy measurement is not installed")
  a <- x$admitted
  expect_identical(nrow(x$sample), 612L)
  expect_identical(nrow(a), 594L)
  # The rule's clause 1, on the design-weighted sample.
  expect_lt(wq(a$d, a$weight, .95), .01)
  # The weights carry the sample back to every census frame with a canopy value.
  cen <- x$census
  expect_equal(sum(x$sample$weight), sum(cen$n[cen$p_bin != "none"]), tolerance = 1e-6)
  # Passing a DSM moves a frame across the height checks: two of the sample do.
  changed <- x$sample$fp_dtm_height != x$sample$fp_dsm_height
  expect_identical(sum(changed, na.rm = TRUE), 2L)
  expect_true(all(x$sample$fp_dtm_height[which(changed)] == "implausible"))
})

test_that("the LidarBC witness admits MRDEM's DSM on radar cells", {
  x <- canopy_tables()
  skip_if(is.null(x), "the canopy measurement is not installed")
  lp <- x$lidar
  expect_identical(nrow(lp), 150L)
  slope <- unname(stats::coef(stats::lm(imaged_over_dtm ~ 0 + mrdem_canopy, data = lp)))
  expect_gte(slope, 0.67)
  expect_lte(slope, 1.5)
  expect_equal(round(slope, 3), 0.916)
  # And NRCan's own lidar could not have been the witness.
  v <- x$versions
  expect_identical(v$etag[v$asset == "hrdem_ground_points"], "n=3000;radar=0;lidar=2940;blend=60")
})

test_that("every table in the note's fly#80 section is rebuilt from the shipped data", {
  x <- canopy_tables()
  skip_if(is.null(x), "the canopy measurement is not installed")
  sec <- canopy_section()
  skip_if(is.null(sec), "the terrain note is not installed")
  # Three tables and 20 table lines (3 headers, 3 separators, 14 rows: 5 lidar, 4 scale,
  # 5 decade). A table or row added fails here until it is rebuilt.
  expect_identical(sum(grepl("^\\|[- |]+\\|$", sec)), 3L)
  expect_identical(sum(startsWith(sec, "|")), 20L)

  pc <- function(v, k = 2) sprintf(paste0("%.", k, "f%%"), 100 * v)
  mm <- function(v) sub("^-", "−", sprintf("%.2f m", v))
  lp <- x$lidar
  a <- x$admitted
  share1 <- function(d) sum(d$weight[d$d > .01]) / sum(d$weight)
  scale_row <- function(lab, d) {
    sprintf("| %s | %d | %s | %s | %s |", lab, nrow(d), pc(wq(d$d, d$weight, .5)),
            pc(wq(d$d, d$weight, .95)), pc(share1(d), 1))
  }
  e <- x$epoch
  dec_row <- function(dd, lab) {
    xd <- e[e$decade == dd, ]
    k <- xd[xd$known, ]
    enough <- nrow(k) >= 10 && sum(k$weight) / sum(xd$weight) >= .5
    cell <- if (enough) pc(sum(k$weight[k$r < .5]) / sum(k$weight), 1) else "unresolved (too few)"
    sprintf("| %s | %d | %d | %s |", lab, nrow(xd), nrow(k), cell)
  }
  rows <- c(
    sprintf("| MRDEM DSM − DTM (NRCan's removal model) | %s |", mm(stats::median(lp$mrdem_canopy))),
    sprintf("| LidarBC DSM − DEM (measured canopy) | %s |", mm(stats::median(lp$lidar_canopy))),
    sprintf("| MRDEM DTM − LidarBC ground | %s |", mm(stats::median(lp$dtm_resid))),
    sprintf("| MRDEM DSM − LidarBC DSM | %s |", sub("^", "+", mm(stats::median(lp$dsm_resid)))),
    sprintf("| LidarBC DSM − MRDEM DTM (what fly should size from, above what it does) | %s |",
            mm(stats::median(lp$imaged_over_dtm))),
    scale_row("all", a),
    scale_row("to 1:15000", a[a$scale_band == "fine", ]),
    scale_row("1:15000–1:30000", a[a$scale_band == "mid", ]),
    scale_row("over 1:30000", a[a$scale_band == "coarse", ]),
    dec_row(1960, "1960s"), dec_row(1970, "1970s"), dec_row(1980, "1980s"),
    dec_row(1990, "1990s"), dec_row(2000, "2000s")
  )
  for (r in rows) expect_true(r %in% sec, info = r)

  # Prose figures with a shipped producer.
  txt <- gsub("\\s+", " ", paste(sec, collapse = " "))
  sh <- x$versions$etag[x$versions$asset == "source_share"]
  sh <- stats::setNames(as.numeric(sub(".*=", "", strsplit(sh, ";")[[1]])),
                        sub("=.*", "", strsplit(sh, ";")[[1]]))
  expect_match(txt, sprintf("%s of MRDEM is taken from radar", pc(sh[["radar"]], 1)), fixed = TRUE)
  expect_match(txt, sprintf("%s from lidar, %s a blend", pc(sh[["lidar"]], 1), pc(sh[["blend"]], 1)),
               fixed = TRUE)
  r <- a[a$area_t_dtm > 0 & a$area_t_dsm > 0, ]
  rho_dtm <- abs(sqrt(r$area_w_dtm / r$area_t_dtm) - 1)
  rho_dsm <- abs(sqrt(r$area_w_dsm / r$area_t_dsm) - 1)
  expect_match(txt, sprintf("weighted 95th of %s sized from the DSM and %s from the DTM",
                            pc(wq(rho_dsm, r$weight, .95)), pc(wq(rho_dtm, r$weight, .95))),
               fixed = TRUE)
  today <- sqrt(r$area_w_dtm / r$area_t_dsm) - 1
  expect_match(txt, sprintf("weighted median %s too wide", pc(wq(today, r$weight, .5))), fixed = TRUE)
  expect_match(txt, sprintf("95th of %s", pc(wq(abs(today), r$weight, .95))), fixed = TRUE)
  expect_match(txt, sprintf("over the %d sampled frames where", nrow(e)), fixed = TRUE)
})

test_that("measured canopy leaves fly#65's area verdict standing", {
  x <- canopy_tables()
  skip_if(is.null(x), "the canopy measurement is not installed")
  fp <- system.file("extdata/dem_coastal_frames.csv", package = "fly")
  skip_if(fp == "", "the coastal measurement is not installed")
  m <- merge(utils::read.csv(fp, stringsAsFactors = FALSE), x$coastal, by = "airp_id")
  expect_identical(nrow(x$coastal), sum(utils::read.csv(fp)$admitted))
  m$err_w <- sqrt(m$area_w / m$area_t) - 1
  m$err_l <- sqrt(m$area_l / m$area_t) - 1
  m$elev_w <- m$flying_height - m$height_agl
  m$elev_l <- m$elev_w + (m$mean_land - m$mean_all)
  m$d <- (m$flying_height - m$elev_w) / (m$flying_height - m$elev_l) - 1
  k <- m$height_agl / (m$height_agl - m$c_coastal)
  w <- (1 + m$err_w) * k - 1
  l <- (1 + m$err_l) * k - 1
  co <- m$coastal & is.finite(m$d) & m$d > 0 & m$n_sea > 0
  # W is still closer on area, to first order, under each frame's own canopy.
  expect_lt(stats::median(abs(w[co]) - abs(l[co])), 0)
  sec <- canopy_section()
  skip_if(is.null(sec), "the terrain note is not installed")
  txt <- gsub("\\s+", " ", paste(sec, collapse = " "))
  expect_match(txt, sprintf("median %.2f m of mean canopy, inland %.2f m",
                            stats::median(m$c_coastal[co]),
                            stats::median(m$c_coastal[m$set == "inland" & !m$coastal])), fixed = TRUE)
})
