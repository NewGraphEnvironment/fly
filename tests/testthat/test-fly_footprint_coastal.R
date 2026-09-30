# A coastal frame, whose footprint takes in sea (fly#65).
#
# MRDEM-30 carries the sea surface at ~0.14 m rather than nodata, so a coastal frame is
# sized from the mean of land AND sea — "W". fly#65 was filed on the premise that this is
# an error and the land-only mean ("L") is right. A ray-cast of the true footprint, under
# the vertical camera the package already assumes, says the premise is half right: W is the
# better answer for AREA, L for where the LAND EDGE falls, and neither is off by more than
# the per-corner cost every inland frame already carries. See `inst/notes/terrain-correction.md`,
# "A coastal frame's sea is an elevation, not a gap (fly#65)".

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
# Every figure the note and NEWS quote is asserted here at the precision it is printed to;
# the bootstrap intervals are not (they are seeded in the script and printed in its log).
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
  expect_identical(sum(m$admitted), 2124L)
  expect_identical(sum(m$land_border), 157L)
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
  # L is always narrower than W, so it errs small wherever sea is present.
  expect_true(all(co$area_l < co$area_w))
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
