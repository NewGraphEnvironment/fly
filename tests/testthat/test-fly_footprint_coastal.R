# A coastal frame, whose footprint takes in sea (fly#65).
#
# MRDEM-30 carries the sea surface at ~0.14 m rather than nodata, so a coastal frame is
# sized from the mean of land AND sea — "W". fly#65 was filed on the premise that this is
# an error and the land-only mean ("L") is right. Against a ray-cast of the true footprint
# on bare earth, W is the better answer for AREA and L for where the LAND EDGE falls. A
# canopy can reverse the first (first-order, fly#80). The rule's pooled test found no
# remedy warranted; matched for relief, the sea does make W's land edge worse. See `inst/notes/terrain-correction.md`,
# "A coastal frame's sea is an elevation, not a gap (fly#65)", whose tables are rebuilt
# row by row at the end of this file.

# A frame straddling a shoreline through its centroid: sea at 0.1 m to the south, land at
# 500 m to the north, in EPSG:3005 with the step on a cell boundary so each half holds the
# same number of cells.
half_sea_case <- function() {
  pt <- sf::st_transform(terrain_fixture()[1, ], 3005)
  xy <- sf::st_coordinates(pt)
  cell <- 10
  y0 <- round(xy[2] / cell) * cell
  pt <- sf::st_set_geometry(pt, sf::st_sfc(sf::st_point(c(xy[1], y0)), crs = 3005))
  r <- terra::rast(xmin = xy[1] - 6000, xmax = xy[1] + 6000, ymin = y0 - 6000,
                   ymax = y0 + 6000, resolution = cell, crs = "EPSG:3005")
  terra::values(r) <- ifelse(terra::yFromCell(r, seq_len(terra::ncell(r))) > y0, 500, 0.1)
  list(pt = pt, dem = r)
}

test_that("a half-sea frame is sized from the mean of land and sea, and says so in dem_elev_sd", {
  skip_if_not_installed("terra")
  x <- half_sea_case()
  fp <- suppressWarnings(fly_footprint(x$pt, dem = x$dem))

  # Premise: the sea carries data, so nothing about coverage can see it — the issue's
  # observation, and still true.
  expect_identical(fp$footprint_terrain, "dem_agl")
  expect_equal(fp$dem_coverage, 1)

  # W: the sea cells are averaged in. The land-only answer would be H - 500.
  expect_equal(fp$height_agl, x$pt$flying_height - (500 + 0.1) / 2, tolerance = 1e-3)

  # `dem_elev_sd` sees the step here — half the cells 500 m from the other half spread
  # ~250 m — but that is the fixture, not a flag: on real coastal frames it runs 14 to 181 m
  # by sea fraction against 113 m inland (the shipped-table test below), so it does not
  # separate a coastal frame from a rugged inland one.
  expect_gt(fp$dem_elev_sd, 240)
  expect_lt(fp$dem_elev_sd, 260)

  # And the rectangle is the one W implies — square, film, half-side k (H - mean).
  side <- sqrt(as.numeric(sf::st_area(fp)))
  expect_equal(side, 9 * 0.0254 * fp$height_agl / 0.153, tolerance = 1e-6)
})


# ---------------------------------------------------------------------------
# The measurement, recomputed from what `data-raw/dem_measure-coastal_water.R` shipped.
# The note's tables are rebuilt row by row from the CSVs. Many prose figures are asserted
# against literals here, but the prose itself is not read, so it can drift unseen. Not
# asserted at all: the bootstrap intervals, the synthetic-control figures (the script stops
# if they fail), the 13/17 split of the ineligible frames, and the LidarBC/TRIM probe, which
# the script does not run.
# ---------------------------------------------------------------------------

coastal_tables <- function() {
  fp <- system.file("extdata/dem_coastal_frames.csv", package = "fly")
  pp <- system.file("extdata/dem_coastal_population.csv", package = "fly")
  sp <- system.file("extdata/dem_coastal_sites.csv", package = "fly")
  if (fp == "" || pp == "" || sp == "") {
    return(NULL)
  }
  m <- utils::read.csv(fp, stringsAsFactors = FALSE)
  m$elev_w <- m$flying_height - m$height_agl
  m$elev_l <- m$elev_w + (m$mean_land - m$mean_all)
  m$sea_frac <- m$n_sea / m$n_cells
  m$d <- (m$flying_height - m$elev_w) / (m$flying_height - m$elev_l) - 1
  lin <- function(a) sqrt(a / m$area_t) - 1
  m$err_w <- lin(m$area_w)
  m$err_l <- lin(m$area_l)
  m$err_s <- lin(m$area_s)
  m$edge_w <- (m$incl_w + m$excl_w) / m$land_t
  m$edge_l <- (m$incl_l + m$excl_l) / m$land_t
  m$edge_s <- (m$incl_s + m$excl_s) / m$land_t
  list(frames = m,
       coastal = m[m$admitted & m$coastal & is.finite(m$d) & m$d > 0, ],
       inland = m[m$admitted & m$set == "inland" & !m$coastal, ],
       population = utils::read.csv(pp, stringsAsFactors = FALSE),
       sites = utils::read.csv(sp, stringsAsFactors = FALSE))
}
q <- function(x, p) unname(stats::quantile(x, p))

test_that("the shipped coastal tables are the ones the note was written from", {
  x <- coastal_tables()
  skip_if(is.null(x), "the coastal measurement is not installed")
  m <- x$frames
  # Premises: a truncated table would make everything below vacuous.
  expect_identical(nrow(m), 2334L)
  expect_identical(anyDuplicated(m$airp_id), 0L)
  expect_identical(length(unique(m$run_id[m$set == "coastal"])), 180L)
  expect_identical(length(unique(m$run_id[m$set == "inland"])), 60L)
  # Every frame accounted for exactly once: not DEM-sized at a believed height, outside
  # cells not reading as sea, no land cell at all, or admitted. No ray met nodata.
  eligible <- m$footprint_terrain %in% "dem_agl" & m$height_source %in% "reported" &
    m$dem_coverage >= fly_dem_coverage_min()
  expect_identical(sum(!eligible), 30L)
  expect_identical(sum(m$outside_not_sea), 157L)
  expect_identical(sum(m$outside_not_sea & m$coastal), 152L)
  expect_identical(sum(m$no_land), 23L)
  expect_identical(sum(m$admitted), 2124L)
  expect_identical(sum(!eligible) + sum(m$outside_not_sea) + sum(m$no_land) + sum(m$admitted),
                   nrow(m))
  # What the outside-not-sea test caught is not one thing: half sit at sea level, but
  # dozens do not, so the note states the spread rather than a cause.
  o <- m$sea_median[m$outside_not_sea]
  expect_equal(round(stats::median(o), 2), 0.09)
  expect_identical(c(sum(o > 0.5), sum(o > 1), sum(o > 5)), c(42L, 28L, 10L))
  # The admitted frames, in the note's five groups.
  a <- m[m$admitted, ]
  d <- a$height_agl / (a$height_agl - (a$mean_land - a$mean_all)) - 1
  expect_identical(c(sum(a$coastal & a$n_sea > 0 & d > 0), sum(a$coastal & a$n_sea > 0 & d <= 0),
                     sum(a$coastal & a$n_sea == 0), sum(a$set == "coastal" & !a$coastal),
                     sum(a$set == "inland" & !a$coastal)),
                   c(1242L, 1L, 64L, 225L, 592L))
  expect_identical(sum(a$set == "inland" & a$coastal), 0L)
  # 2,400 drawn, 66 drawn twice and measured once: no run is over ten, and the short
  # runs are short by 66 in all.
  per_run <- table(m$run_id)
  expect_identical(max(per_run), 10L)
  expect_identical(sum(10L - per_run), 66L)
  # Three frames of run c052 carry a raised surface outside the polygon.
  c052 <- m$sea_median[m$run_id == "c052" & m$outside_not_sea]
  expect_identical(sum(c052 > 5), 3L)
  expect_equal(round(stats::median(c052[c052 > 5]), 2), 9.95)
  # No admitted frame had a ray reach nodata, and none is a residual class.
  expect_true(all(m$rays_bad[m$admitted] == 0))
  expect_true(all(m$footprint_terrain[m$admitted] == "dem_agl"))
  expect_true(all(m$height_source[m$admitted] == "reported"))
  expect_true(all(m$dem_coverage[m$admitted] >= fly_dem_coverage_min()))
  expect_identical(nrow(x$coastal), 1242L)
  expect_identical(length(unique(x$coastal$film_roll)), 138L)
  expect_identical(nrow(x$inland), 592L)
  expect_identical(length(unique(x$inland$film_roll)), 59L)
})

test_that("the coastal population is counted on fly#58's denominator", {
  x <- coastal_tables()
  skip_if(is.null(x), "the coastal measurement is not installed")
  pop <- stats::setNames(x$population$n, x$population$measure)
  # The same eligibility fly#58 published, so the two shares compare.
  expect_identical(unname(pop["film_dem_eligible"]), 1437147L)
  expect_identical(unname(pop["film_coastal"]), 95222L)
  expect_equal(round(100 * pop[["film_coastal"]] / pop[["film_dem_eligible"]], 2), 6.63)
  # "About 1,440 times the 66 frames partial coverage reaches" (fly#58).
  expect_equal(round(pop[["film_coastal"]] / 66, -1), 1440)
  # The scale bands partition both totals.
  expect_identical(sum(pop[grepl("^film_coastal_scale_", names(pop))]), pop[["film_coastal"]])
  expect_identical(sum(pop[grepl("^film_eligible_scale_", names(pop))]),
                   pop[["film_dem_eligible"]])
})

test_that("MRDEM carries near-shore sea as ~0.14 m and open water as nodata", {
  x <- coastal_tables()
  skip_if(is.null(x), "the coastal measurement is not installed")
  s <- x$sites
  rownames(s) <- s$site
  # The issue's own site reproduces: data, not nodata, and not one exact zero.
  expect_identical(s["hecate_strait", "n_sea_nodata"], 0L)
  expect_identical(s["hecate_strait", "sea_exact_zero"], 0L)
  expect_equal(s["hecate_strait", "sea_median"], 0.137)
  for (open in c("qc_sound", "offshore_w_haida")) {
    expect_identical(s[open, "n_sea_nodata"], s[open, "n_sea"])
  }
  # Why the near-zero band cannot be the land/water witness: delta land sits in it.
  expect_equal(s["roberts_bank_delta", "land_in_band"], 0.148)
})

test_that("the W/L choice is material: d reaches 3.2% of width at the 95th percentile", {
  x <- coastal_tables()
  skip_if(is.null(x), "the coastal measurement is not installed")
  d <- x$coastal$d
  expect_equal(round(stats::median(d), 4), 0.0071)
  expect_equal(round(q(d, .95), 4), 0.0318)
  expect_equal(round(max(d), 4), 0.0848)
  expect_equal(round(mean(d > 0.01), 3), 0.382)
})

test_that("W is right for area, L and S for the land edge", {
  x <- coastal_tables()
  skip_if(is.null(x), "the coastal measurement is not installed")
  co <- x$coastal
  med <- function(v) round(stats::median(v), 4)
  # Area, linear error against the ray-cast.
  expect_equal(med(abs(co$err_w)), 0.0034)
  expect_equal(med(abs(co$err_l)), 0.0067)
  expect_equal(med(abs(co$err_s)), 0.0034)
  expect_lt(stats::median(abs(co$err_w) - abs(co$err_l)), 0)
  # Land edge, as a share of the true land area.
  expect_equal(med(co$edge_w), 0.0443)
  expect_equal(med(co$edge_l), 0.0367)
  expect_equal(med(co$edge_s), 0.0371)
  expect_gt(stats::median(co$edge_w - co$edge_l), 0)
  # Which way each errs on land: W claims land the photo never saw, L drops land it did.
  expect_equal(med(co$incl_w / co$land_t), 0.0331)
  expect_equal(med(co$incl_l / co$land_t), 0.0214)
  expect_equal(med(co$excl_w / co$land_t), 0.0046)
  expect_equal(med(co$excl_l / co$land_t), 0.0140)
})

test_that("the sea does not make a coastal frame worse than an inland one", {
  x <- coastal_tables()
  skip_if(is.null(x), "the coastal measurement is not installed")
  co <- x$coastal
  inl <- x$inland
  # Area: coastal 95th under inland 95th, so the remedy threshold (+0.01) is not reached.
  expect_equal(round(q(abs(co$err_w), .95), 4), 0.0216)
  expect_equal(round(q(abs(inl$err_w), .95), 4), 0.0318)
  expect_lt(q(abs(co$err_w), .95) - q(abs(inl$err_w), .95), 0.01)
  # Land edge: the same, against +0.02 (1% of width, as area).
  inl_edge <- (inl$incl_w + inl$excl_w) / inl$land_t
  expect_equal(round(q(co$edge_w, .95), 4), 0.1505)
  expect_equal(round(q(inl_edge, .95), 4), 0.1587)
  expect_lt(q(co$edge_w, .95) - q(inl_edge, .95), 0.02)
  # With the 151 excluded coastal frames that have d > 0 put back: no verdict moves.
  m <- x$frames
  back <- m[m$outside_not_sea & m$coastal & is.finite(m$d) & m$d > 0 &
              is.finite(m$area_t) & m$rays_bad %in% 0, ]
  expect_identical(nrow(back), 151L)
  cs <- rbind(co, back)
  expect_equal(round(q(abs(cs$err_w), .95), 4), 0.0238)
  expect_equal(round(q(cs$edge_w, .95), 4), 0.1477)
  # The signed medians by sea band: L always short, W between -0.14% and +0.27%.
  band <- cut(co$sea_frac, c(0, .1, .25, .5, .75, 1), include.lowest = TRUE)
  sw <- tapply(co$err_w, band, stats::median)
  sl <- tapply(co$err_l, band, stats::median)
  expect_equal(round(range(sw), 4), c(-0.0014, 0.0027))
  expect_equal(round(range(sl), 4), c(-0.0072, -0.0029))
  # The lowest height above ground admitted, which the tide bound uses, and the sample's
  # median height and relief.
  expect_equal(round(min(m$height_agl[m$admitted])), 697)
  expect_equal(round(stats::median(co$height_agl)), 5268)
  expect_equal(round(stats::median(co$dem_elev_sd), 1), 81.3)
  # Matched for relief the land-edge pass disappears; area keeps its margin.
  rb <- stats::quantile(co$dem_elev_sd, 0:5 / 5)
  cb <- cut(co$dem_elev_sd, rb, include.lowest = TRUE)
  ib <- cut(inl$dem_elev_sd, rb, include.lowest = TRUE)
  expect_false(anyNA(ib))
  wt <- as.numeric(table(cb)[as.character(ib)] / table(ib)[as.character(ib)])
  wq <- function(v, p) {
    o <- order(v)
    v[o][which(cumsum(wt[o]) / sum(wt) >= p)[1]]
  }
  expect_equal(round(wq(inl_edge, .95), 4), 0.1506)
  expect_equal(round(wq(abs(inl$err_w), .95), 4), 0.0295)
  # W's median land edge falls with sea fraction while its 95th rises.
  expect_equal(round(as.numeric(tapply(co$edge_w, band, stats::median)), 4),
               c(0.0496, 0.0488, 0.0441, 0.0397, 0.0391))
})

test_that("dem_elev_sd does not separate coastal frames from inland ones", {
  x <- coastal_tables()
  skip_if(is.null(x), "the coastal measurement is not installed")
  co <- x$coastal
  band <- cut(co$sea_frac, c(0, .1, .25, .5, .75, 1), include.lowest = TRUE)
  by <- round(tapply(co$dem_elev_sd, band, stats::median), 1)
  expect_equal(as.numeric(by), c(164.2, 180.6, 115.3, 53.3, 13.9))
  expect_equal(round(stats::median(x$inland$dem_elev_sd), 1), 112.8)
})

test_that("every table in the note's fly#65 section is rebuilt from the shipped data", {
  x <- coastal_tables()
  skip_if(is.null(x), "the coastal measurement is not installed")
  np <- system.file("notes/terrain-correction.md", package = "fly")
  skip_if(np == "", "the terrain note is not installed")
  md <- readLines(np, warn = FALSE)
  start <- grep("^## A coastal frame's sea is an elevation", md)
  h2 <- grep("^## ", md)
  sec <- md[seq(start, min(h2[h2 > start]) - 1)]
  # Terminate by enumeration: six tables, each rebuilt row by row below. A seventh fails
  # here until it is accounted for, as fly#58's section guard does for its own.
  expect_identical(sum(grepl("^\\|[- |]+\\|$", sec)), 6L)
  # And 35 table lines, so a row added to any of them fails until it is rebuilt below
  # (6 headers, 6 separators, 23 rows: 3 site, 4 candidate, 4 canopy, 2 percentile,
  # 5 relief, 5 sea band).
  expect_identical(sum(startsWith(sec, "|")), 35L)

  co <- x$coastal
  inl <- x$inland
  s <- x$sites
  rownames(s) <- s$site
  pc <- function(v, k = 2) sprintf(paste0("%.", k, "f%%"), 100 * v)
  med <- function(v) stats::median(v)
  inl_edge <- (inl$incl_w + inl$excl_w) / inl$land_t
  f3 <- function(v) sprintf("%.3f", v)
  near <- s[c("hecate_strait", "strait_georgia", "dixon_entrance"), ]
  shore <- s[c("howe_sound_fjord", "boundary_bay_flat", "roberts_bank_delta"), ]
  rows <- c(
    sprintf("| Hecate Strait (the fly#58 site), Strait of Georgia, Dixon Entrance | median %s–%s m, range %s..%s | %d |",
            f3(min(near$sea_median)), f3(max(near$sea_median)), f3(min(near$sea_min)),
            f3(max(near$sea_max)), sum(near$sea_exact_zero)),
    sprintf("| Howe Sound (fjord), Boundary Bay (tidal flat), Roberts Bank (delta) | median %s–%s m, down to −%.1f m | %d |",
            f3(min(shore$sea_median)), f3(max(shore$sea_median)), -min(shore$sea_min),
            sum(shore$sea_exact_zero)),
    sprintf("| area, median \\|linear error\\| | **%s** | %s | %s |",
            pc(med(abs(co$err_w))), pc(med(abs(co$err_l))), pc(med(abs(co$err_s)))),
    sprintf("| land edge, median (incl + excl) / land | %s | **%s** | %s |",
            pc(med(co$edge_w)), pc(med(co$edge_l)), pc(med(co$edge_s))),
    sprintf("| land wrongly included | %s | %s | |",
            pc(med(co$incl_w / co$land_t)), pc(med(co$incl_l / co$land_t))),
    sprintf("| land wrongly excluded | %s | %s | |",
            pc(med(co$excl_w / co$land_t)), pc(med(co$excl_l / co$land_t))),
    sprintf("| area, linear | %s | %s |", pc(q(abs(co$err_w), .95)), pc(q(abs(inl$err_w), .95))),
    sprintf("| land edge | %s | %s |", pc(q(co$edge_w, .95)), pc(q(inl_edge, .95))),
    # First-order canopy: the true footprint shrinks by (agl - c (1 - w)) / agl.
    vapply(c(0, 15, 30, 60), function(cm) {
      kc <- co$height_agl / (co$height_agl - cm * (1 - co$sea_frac))
      ki <- inl$height_agl / (inl$height_agl - cm)
      w <- (1 + co$err_w) * kc - 1
      l <- (1 + co$err_l) * kc - 1
      # The note prints a typographic minus.
      sgn <- sub("^-", "\u2212", sprintf("%+.5f", med(abs(w) - abs(l))))
      sprintf("| %d m | %s | %s | %s |", cm, sgn, pc(q(abs(w), .95)),
              pc(q(abs((1 + inl$err_w) * ki - 1), .95)))
    }, character(1)),
    {
      rb <- stats::quantile(co$dem_elev_sd, 0:5 / 5)
      cb <- cut(co$dem_elev_sd, rb, include.lowest = TRUE)
      ib <- cut(inl$dem_elev_sd, rb, include.lowest = TRUE)
      edges <- c(0, signif(rb[2:5], 3), round(rb[6]))
      vapply(seq_len(5), function(i) {
        sprintf("| %s–%s | %d | %d | %s | %s |", format(edges[i]), format(edges[i + 1]),
                sum(cb == levels(cb)[i]), sum(ib == levels(ib)[i]),
                pc(q(co$edge_w[cb == levels(cb)[i]], .95)),
                pc(q(inl_edge[ib == levels(ib)[i]], .95)))
      }, character(1))
    },
    {
      band <- cut(co$sea_frac, c(0, .1, .25, .5, .75, 1), include.lowest = TRUE)
      lab <- c("0–0.1", "0.1–0.25", "0.25–0.5", "0.5–0.75", "0.75–1")
      vapply(seq_along(levels(band)), function(i) {
        xb <- co[band == levels(band)[i], ]
        sprintf("| %s | %d | %s | %s |", lab[i], nrow(xb), pc(q(abs(xb$err_w), .95)),
                pc(q(xb$edge_w, .95)))
      }, character(1))
    }
  )
  for (r in rows) expect_true(r %in% sec, info = r)
  # The open-water row is a count, not a figure: every sea cell nodata at both sites, and
  # the note says so.
  expect_true(all(s[c("qc_sound", "offshore_w_haida"), "n_sea_nodata"] ==
                    s[c("qc_sound", "offshore_w_haida"), "n_sea"]))
  expect_true("| Queen Charlotte Sound, west of Haida Gwaii | **all nodata** | — |" %in% sec)
})
