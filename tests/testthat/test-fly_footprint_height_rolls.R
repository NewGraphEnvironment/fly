# The per-roll table of measured `flying_height` corrections (fly#60).
#
# fly#54 left the lower tail — frames reading under half the height their scale implies —
# "implausible", because three remedies fit it equally when pooled. Per roll they do not:
# the scanned logbooks and the spacing between adjacent frames settle 22 roll-heights,
# shipped in `inst/extdata/flying_height_rolls.csv`. These tests hold `fly_footprint()` to
# that table and hold the table to the sweep it was measured from.
#
# Every fixture row is keyed to a REAL table row, over level ground, so each expected
# height is arithmetic. Keyed on the catalogue's roll, height, lens and scale together: a
# frame that shares only the roll is a different frame.

roll_fixture <- function() {
  sf::st_sf(
    airp_id = 1:7,
    film_roll = c("bc7584", "bc7717", "bc7280", "bc7717", "bc7584", "bc79086", "bc7584"),
    scale = c("1:20000", "1:12500", "1:16000", "1:12500", "1:25000", "1:60000", "1:20000"),
    media = "Film - BW",
    focal_length = c(305, 305, 305, 305, 305, 305, 153),
    flying_height = c(609, 1676, 60, 1700, 609, 6325, 609),
    geometry = sf::st_sfc(
      lapply(seq(-126.60, by = 0.02, length.out = 7), function(x) sf::st_point(c(x, 54.40))),
      crs = 4326
    )
  )
}

roll_dem <- function(elev = 300) {
  bb <- sf::st_bbox(sf::st_transform(roll_fixture(), 3005))
  r <- terra::rast(xmin = bb[["xmin"]] - 30000, xmax = bb[["xmax"]] + 30000,
                   ymin = bb[["ymin"]] - 30000, ymax = bb[["ymax"]] + 30000,
                   resolution = 100, crs = "EPSG:3005")
  terra::values(r) <- elev
  r
}

roll_width <- function(fp) {
  vapply(sf::st_geometry(sf::st_transform(fp, 3005)), function(g) {
    if (sf::st_is_empty(g)) return(NA_real_)
    diff(range(sf::st_coordinates(g)[, 1]))
  }, numeric(1))
}


test_that("the fixture is keyed to real table rows, and only where it says so", {
  tab <- fly_height_roll_table()
  key <- function(roll, h, f, s) paste(roll, h, f, s)
  in_tab <- key(tab$film_roll, tab$flying_height, tab$focal_length, tab$scale_n)
  rf <- roll_fixture()
  scale_n <- as.numeric(sub("^1:", "", rf$scale))
  hit <- key(rf$film_roll, rf$flying_height, rf$focal_length, scale_n) %in% in_tab
  # Rows 1-3 are table rows (x10, scale wrong, x100); 4-7 share a roll with one and differ
  # in exactly one of height, scale or lens, or sit on a roll the table excludes.
  expect_identical(hit, c(TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE))
  rf_key <- key(rf$film_roll, rf$flying_height, rf$focal_length, scale_n)
  expect_equal(tab$factor[match(rf_key[1:3], in_tab)], c(10, 1, 100))
  excl <- utils::read.csv(system.file("extdata/flying_height_rolls_excluded.csv",
                                      package = "fly"))
  expect_true("bc79086" %in% excl$film_roll)
  # Every row is refused without the table: the premise the table exists to change.
  band <- fly_height_ratio_band()
  r <- (rf$flying_height - 300) / (scale_n * rf$focal_length / 1000)
  expect_true(all(r < band[1]))
  # Row 3 sits below the ground as catalogued, which is how a height missing two digits
  # arrives; the rest are above it, so each reaches the ratio check and not the terrain one.
  expect_identical(r < 0, c(FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE))
})


test_that("a tabled frame is sized from the height the table measured", {
  skip_if_no_terra()
  rf <- roll_fixture()
  fp <- suppressWarnings(fly_footprint(rf, dem = roll_dem()))

  expect_identical(
    fp$height_source,
    c("corrected_roll_table", "corrected_roll_table", "corrected_roll_table",
      "implausible", "implausible", "implausible", "implausible")
  )
  expect_identical(fp$footprint_terrain[1:3], rep("dem_agl", 3))
  # x10: 609 m catalogued is 2,000 ft where the logbook reads 20,000 — and the height used
  # is the logbook's, 6,096 m, not the catalogue's rounding times ten.
  expect_equal(fp$height_agl[1], 20000 * 0.3048 - 300)
  # Factor 1: the height was right and the SCALE was wrong, so the reported height is used
  # as it stands — and the frame is drawn at the width that height implies (1.0 km), not
  # at the nominal-scale width the fallback would have drawn (2.9 km at 1:12500).
  expect_equal(fp$height_agl[2], 5500 * 0.3048 - 300)
  expect_equal(roll_width(fp)[2], 9 * 0.0254 * (5500 * 0.3048 - 300) / 0.305,
               tolerance = 1e-3)
  # x100 on bc7280, catalogued at 60 m: 6,096 m from the logbook, where 60 x 100 would have
  # left it 96 m short.
  expect_equal(fp$height_agl[3], 20000 * 0.3048 - 300)
  # The caller's column is never overwritten.
  expect_identical(fp$flying_height, rf$flying_height)
  # The rest keep the nominal-scale footprint exactly as without the table.
  flat <- fly_footprint(rf)
  expect_equal(roll_width(fp)[4:7], roll_width(flat)[4:7])
})


test_that("a tabled factor that does not reconcile THIS frame is not applied", {
  skip_if_no_terra()
  # Over ground at 4,000 m, x10 leaves bc7584 at (6096 - 4000) / 6100 = 0.34 of its scale:
  # the table names the slip, but for this frame the corrected height still disagrees, so
  # it stays refused exactly as #54's repair does.
  rf <- roll_fixture()[1, ]
  fp <- suppressWarnings(fly_footprint(rf, dem = roll_dem(4000)))
  expect_identical(fp$height_source, "implausible")
  expect_true(is.na(fp$height_agl))
})


test_that("the table is reported once, and its frames are not counted as implausible", {
  skip_if_no_terra()
  w <- character()
  withCallingHandlers(
    fly_footprint(roll_fixture(), dem = roll_dem()),
    warning = function(x) {
      w <<- c(w, conditionMessage(x))
      invokeRestart("muffleWarning")
    }
  )
  tabled <- grep("flying_height_rolls.csv", w, value = TRUE, fixed = TRUE)
  expect_length(tabled, 1)
  expect_match(tabled, "^3 of ")
  implausible <- grep("implausible", w, value = TRUE)
  expect_length(implausible, 1)
  expect_match(implausible, "^4 of ")
  expect_false(any(grepl("missing, zero", w, fixed = TRUE)))
})


test_that("without a film_roll column the table cannot be consulted", {
  skip_if_no_terra()
  rf <- roll_fixture()
  rf$film_roll <- NULL
  fp <- suppressWarnings(fly_footprint(rf, dem = roll_dem()))
  expect_identical(fp$height_source, rep("implausible", 7))
})


test_that("the table is consulted for every class of input", {
  skip_if_no_terra()
  rf <- roll_fixture()
  shapes <- list(
    plain = rf,
    tibble = sf::st_as_sf(tibble::as_tibble(rf)),
    grouped = sf::st_as_sf(dplyr::group_by(tibble::as_tibble(rf), .data$film_roll))
  )
  expect_true(inherits(shapes$tibble, "tbl_df"))
  expect_true(inherits(shapes$grouped, "grouped_df"))
  out <- lapply(shapes, function(x) suppressWarnings(fly_footprint(x, dem = roll_dem())))
  for (nm in names(out)) {
    expect_identical(out[[nm]]$height_source, out$plain$height_source, info = nm)
    expect_equal(out[[nm]]$height_agl, out$plain$height_agl, info = nm)
  }
})


test_that("no window is built from a tabled frame's refused height", {
  skip_if_no_terra()
  # A tabled frame is classified after the first pass and BEFORE the second, like #54's
  # slip: the second pass must sample the corrected rectangle, not the refused nominal one.
  sizes <- c()
  real_grid <- fly_dem_grid
  testthat::local_mocked_bindings(
    fly_dem_grid = function(dem, geom) {
      g <- real_grid(dem, geom)
      sizes <<- c(sizes, prod(dim(g)[1:2]))
      g
    }
  )
  rf <- roll_fixture()[2, ]           # scale wrong: nominal window 2.9 km, true 1.0 km
  suppressWarnings(fly_footprint(rf, dem = roll_dem()))
  expect_length(sizes, 2)
  true_side <- 9 * 0.0254 * (5500 * 0.3048 - 300) / 0.305 / 100
  nominal_side <- 9 * 0.0254 * 12500 / 100
  expect_lt(sizes[2], (true_side + 3)^2)
  expect_gt(sizes[1], 4 * sizes[2])    # premise: the first pass was the nominal one
  expect_gt(nominal_side, 2.5 * true_side)
})


test_that("the table holds against the sweep and the logbooks it was measured from", {
  tab <- fly_height_roll_table()
  excl <- utils::read.csv(system.file("extdata/flying_height_rolls_excluded.csv",
                                      package = "fly"))
  s <- utils::read.csv(system.file("extdata/flying_height_sweep.csv", package = "fly"))
  lt <- s[s$set == "lower_tail", ]

  # Contract: the named slips, one cause each, and nothing else.
  expect_setequal(unique(tab$factor), c(1, 10, 100))
  expect_identical(tab$cause, c(`1` = "scale_wrong", `10` = "height_digit_dropped",
                                `100` = "height_two_digits_dropped")[as.character(tab$factor)],
                   ignore_attr = TRUE)
  expect_false(anyNA(tab))
  expect_false(anyNA(excl$reason) || any(!nzchar(excl$reason)))

  # Every lower-tail roll-height is either corrected or excluded with a reason — never both,
  # never neither — and the frame counts reconcile to the census exactly.
  key <- function(d) paste(d$film_roll, d$flying_height, d$focal_length, d$scale_n)
  lt_keys <- table(key(lt))
  expect_length(intersect(key(tab), key(excl)), 0)
  expect_setequal(c(key(tab), key(excl)), names(lt_keys))
  expect_identical(as.integer(lt_keys[key(tab)]), as.integer(tab$frames_measured))
  expect_identical(as.integer(lt_keys[key(excl)]), as.integer(excl$frames_measured))
  expect_identical(sum(tab$frames_measured) + sum(excl$frames_measured), nrow(lt))

  # Each row's corrected ratio recomputed from the sweep, at the precision it is published.
  for (i in seq_len(nrow(tab))) {
    d <- lt[key(lt) == key(tab)[i], ]
    r <- median((tab$height_m[i] - d$elev) / (d$scale_n * d$focal_length / 1000))
    expect_equal(round(r, 3), tab$r_corrected[i], tolerance = 1e-9, info = key(tab)[i])
    # A height-slip row must land in the band; a scale-wrong row by definition does not.
    band <- fly_height_ratio_band()
    if (tab$factor[i] == 1) {
      expect_true(r < band[1], info = key(tab)[i])
    } else {
      expect_true(r >= band[1] && r <= band[2], info = key(tab)[i])
    }
    # The height used is the logbook's, converted; and it is the catalogue's times the factor
    # to within the catalogue's rounding, which is what makes the factor the defect's name.
    expect_equal(tab$height_m[i], round(tab$logbook_ft[i] * 0.3048, 1), info = key(tab)[i])
    expect_true(abs(tab$height_m[i] / (tab$flying_height[i] * tab$factor[i]) - 1) <= 0.02,
                info = key(tab)[i])
  }
})


test_that("the key matches however round the numbers are", {
  skip_if_no_terra()
  # `read.csv()` hands the table back as integers and a frame's values arrive as doubles;
  # `paste()` writes 100000L as "100000" and 100000 as "1e+05". No shipped row is round
  # enough to show it, so the table is replaced with one that is.
  testthat::local_mocked_bindings(
    fly_height_roll_table = function() {
      data.frame(
        film_roll = "bcx1", flying_height = 1000L, focal_length = 153L, scale_n = 100000L,
        factor = 10L, height_m = 15240, stringsAsFactors = FALSE
      )
    }
  )
  rf <- roll_fixture()[1, ]
  rf$film_roll <- "bcx1"
  rf$scale <- "1:100000"
  rf$focal_length <- 153
  rf$flying_height <- 1000
  expect_identical(paste(100000), "1e+05")   # premise: the two spellings differ
  fp <- suppressWarnings(fly_footprint(rf, dem = roll_dem()))
  expect_identical(fp$height_source, "corrected_roll_table")
  expect_equal(fp$height_agl, 15240 - 300)
})
