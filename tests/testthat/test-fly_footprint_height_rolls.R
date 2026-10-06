# The per-roll table of measured `flying_height` corrections (fly#60).
#
# fly#54 left the lower tail — frames reading under half the height their scale implies —
# "implausible", because three remedies fit it equally when pooled. Per roll they do not:
# the scanned logbooks and the spacing between adjacent frames settle 22 roll-heights,
# shipped in `inst/extdata/flying_height_rolls.csv`. fly#71 read the same logbooks against
# #54's slipped frames and added the 1978-2000 roll-heights whose height is ten times too
# large, where #54 divides by 10.764. These tests hold `fly_footprint()` to
# that table and hold the table to the sweep, and the infrared census, it was measured from.
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
    tibble = sf::st_as_sf(dplyr::as_tibble(rf)),
    grouped = sf::st_as_sf(dplyr::group_by(dplyr::as_tibble(rf), .data$film_roll))
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


test_that("the table holds against the sweep, census and logbooks it was measured from", {
  tab <- fly_height_roll_table()
  excl <- utils::read.csv(system.file("extdata/flying_height_rolls_excluded.csv",
                                      package = "fly"))
  s <- utils::read.csv(system.file("extdata/flying_height_sweep.csv", package = "fly"))
  band <- fly_height_ratio_band()
  in_band <- function(r) r >= band[1] & r <= band[2]
  # Four sets, one per tail: fly#60's lower tail, fly#71's #54-slipped frames — the upper
  # tail that dividing by 10.764 brings into the band — fly#72's near_upper frames beyond
  # the band, the r ~ 2 mass, and fly#91's terrain frames (built below).
  up <- s[s$set == "upper_tail", ]
  up <- up[in_band((up$flying_height / fly_height_slip_factor() - up$elev) /
                     (up$scale_n * up$focal_length / 1000)), ]
  nu <- s[s$set == "near_upper", ]
  nu <- nu[(nu$flying_height - nu$elev) / (nu$scale_n * nu$focal_length / 1000) > band[2], ]
  expect_identical(nrow(up), 1589L)   # premise: #54's census
  expect_identical(nrow(nu), 252L)
  # fly#91: the infrared census outside the band, which the BW/colour sweep does not hold. Each
  # frame goes where its ratio above sea level puts it: #72's near_upper stratum, or `terrain`
  # — in band above sea level and out of it only through the ground — and nowhere else.
  ir <- utils::read.csv(system.file("extdata/infrared_film_frames.csv", package = "fly"))
  ir <- ir[ir$height_class == "outside_band", ]
  ir_asl <- ir$flying_height / (ir$scale_n * ir$focal_length / 1000)
  ir_near <- ir_asl > 2 & ir_asl <= 3
  ir_terr <- in_band(ir_asl)
  expect_true(all(xor(ir_near, ir_terr)))
  expect_identical(c(sum(ir_near), sum(ir_terr)), c(25L, 31L))
  cols <- c("film_roll", "flying_height", "focal_length", "scale_n", "elev")
  sets <- list(lower = s[s$set == "lower_tail", cols], upper = up[, cols],
               near_upper = rbind(nu[, cols], ir[ir_near, cols]), terrain = ir[ir_terr, cols])

  # Contract: the named slips, one cause each, and nothing else. The upper tail names only
  # 1/10 by factor: a logbook confirming 10.764 is excluded, since #54's repair already sizes
  # it. The one relation that is not a factor is a leading digit, which only a same-roll
  # sibling can name (fly#74), so its row carries the ratio it implies and a cause saying so.
  expect_setequal(unique(tab$tail), c("lower", "upper", "near_upper", "terrain"))
  expect_setequal(unique(excl$tail), c("lower", "upper", "near_upper"))
  expect_true(all(tab$witness %in% c("logbook", "sibling")))
  # An excluded row says why each witness passed it over: the logbook in `reason`, the
  # same-roll sibling in `sibling_reason`.
  expect_false(anyNA(excl$sibling_reason) || any(!nzchar(excl$sibling_reason)))
  digit <- grepl("leading_digit", tab$cause, fixed = TRUE)
  expect_true(all(tab$witness[digit] == "sibling"))
  expect_setequal(unique(tab$factor[tab$tail == "lower" & !digit]), c(1, 10, 100))
  expect_setequal(unique(tab$factor[tab$tail == "upper" & !digit]), 0.1)
  # near_upper names only 1: the height was flown and the scale is the wrong field (fly#72).
  # So does terrain (fly#91), which is the same defect reached through the ground.
  expect_setequal(unique(tab$factor[tab$tail %in% c("near_upper", "terrain")]), 1)
  expect_true(all(tab$witness[tab$tail %in% c("near_upper", "terrain")] == "logbook"))
  expect_identical(tab$cause[!digit],
                   c(`1` = "scale_wrong", `10` = "height_digit_dropped",
                     `100` = "height_two_digits_dropped",
                     `0.1` = "height_decimal_dropped")[as.character(tab$factor[!digit])],
                   ignore_attr = TRUE)
  expect_identical(tab$cause[digit],
                   ifelse(tab$tail[digit] == "upper", "height_leading_digit_added",
                          "height_leading_digit_dropped"))
  expect_equal(tab$factor[digit], round(tab$height_m[digit] / tab$flying_height[digit], 6))
  # A row carries the witness that settled it, and nothing from the one that did not.
  lb <- tab$witness == "logbook"
  expect_false(anyNA(tab[lb, setdiff(names(tab), "sibling_frame")]))
  expect_true(all(is.na(tab$logbook_ft[!lb])))
  expect_true(all(is.finite(tab$sibling_frame[!lb])) && all(is.na(tab$sibling_frame[lb])))
  expect_false(anyNA(tab[!lb, setdiff(names(tab), c("logbook_ft", "frames_logbook"))]))
  expect_false(anyNA(excl$reason) || any(!nzchar(excl$reason)))
  # An excluded slipped roll-height is still repaired by #54, and its reason says so.
  expect_true(all(grepl("10.764", excl$reason[excl$tail == "upper"], fixed = TRUE)))
  expect_false(any(grepl("10.764", excl$reason[excl$tail != "upper"], fixed = TRUE)))
  # An excluded near_upper or terrain roll-height stays on nominal scale, and its reason says so.
  expect_true(all(grepl("nominal scale", excl$reason[excl$tail %in% c("near_upper", "terrain")],
                        fixed = TRUE)))

  key <- function(d) paste(d$film_roll, d$flying_height, d$focal_length, d$scale_n)
  expect_length(intersect(key(tab), key(excl)), 0)
  for (tl in names(sets)) {
    set <- sets[[tl]]
    tb <- tab[tab$tail == tl, ]
    ex <- excl[excl$tail == tl, ]
    # Every roll-height of the set is either corrected or excluded with a reason — never
    # both, never neither — and the frame counts reconcile to the census exactly.
    set_keys <- table(key(set))
    expect_setequal(c(key(tb), key(ex)), names(set_keys))
    expect_identical(as.integer(set_keys[key(tb)]), as.integer(tb$frames_measured), info = tl)
    expect_identical(as.integer(set_keys[key(ex)]), as.integer(ex$frames_measured), info = tl)
    expect_identical(sum(tb$frames_measured) + sum(ex$frames_measured), nrow(set), info = tl)

    # Each row's corrected ratio recomputed from the sweep, at the precision it is published.
    # The generator takes it from the logbook height unrounded and `height_m` is published to
    # 0.1 m, so a ratio on a half-way third decimal can round either side (bc5648, bc79039):
    # held to within one unit in the third decimal, not to the digit.
    for (i in seq_len(nrow(tb))) {
      d <- set[key(set) == key(tb)[i], ]
      expect_gt(nrow(d), 0)
      r <- median((tb$height_m[i] - d$elev) / (d$scale_n * d$focal_length / 1000))
      expect_true(abs(r - tb$r_corrected[i]) <= 0.001, info = key(tb)[i])
      # A height-slip row must land in the band; a scale-wrong row by definition does not,
      # and stays on the side of the band its tail came from — below it for terrain.
      if (tb$factor[i] == 1 && tl == "near_upper") {
        expect_true(r > band[2], info = key(tb)[i])
      } else if (tb$factor[i] == 1) {
        expect_true(r < band[1], info = key(tb)[i])
      } else {
        expect_true(in_band(r), info = key(tb)[i])
      }
      # The height used is the logbook's, converted; and it is the catalogue's times the
      # factor to within the catalogue's rounding, which is what makes the factor the
      # defect's name. A sibling row ships the sibling's catalogued height, and a factor
      # relation to it is exact to what storing whole metres can move a figure, rounded or
      # truncated: big - k small in [-(1 + k/2), k + 1/2] (fly#74).
      if (tb$witness[i] == "logbook") {
        expect_equal(tb$height_m[i], round(tb$logbook_ft[i] * 0.3048, 1), info = key(tb)[i])
        expect_true(abs(tb$height_m[i] / (tb$flying_height[i] * tb$factor[i]) - 1) <= 0.02,
                    info = key(tb)[i])
      } else if (!grepl("leading_digit", tb$cause[i], fixed = TRUE)) {
        hs <- c(tb$flying_height[i], tb$height_m[i])
        k <- max(tb$factor[i], 1 / tb$factor[i])
        r <- max(hs) - k * min(hs)
        expect_true(r >= -(1 + k / 2) && r <= k + 1 / 2, info = key(tb)[i])
      }
    }
  }
  # fly#91's three infrared roll-heights, pinned: each settled by its logbook at the
  # catalogued height (11.0, 12.08 and 19.5 thousand feet, read blind). That spacing fits
  # that height and rejects nominal is recomputed in `test-fly_footprint_infrared.R`.
  ir_rows <- tab[tab$film_roll %in% c("bc5312", "bci12", "bci9"), ]
  ir_rows <- ir_rows[order(ir_rows$film_roll), ]
  expect_identical(key(ir_rows), c("bc5312 3353 153 30000", "bci12 3682 305 15840",
                                   "bci9 5944 305 8000"))
  expect_identical(ir_rows$tail, c("terrain", "terrain", "near_upper"))
  expect_identical(ir_rows$cause, rep("scale_wrong", 3))
  expect_identical(ir_rows$witness, rep("logbook", 3))
  expect_equal(ir_rows$logbook_ft, c(11000, 12080, 19500))
  expect_identical(as.integer(ir_rows$frames_logbook), c(17L, 14L, 25L))
  # Nothing else carries the new tail: it holds exactly these two roll-heights.
  expect_identical(sum(tab$tail == "terrain"), 2L)
  expect_false(any(excl$film_roll %in% c("bc5312", "bci12", "bci9")))

  # fly#71's finding, pinned: on every tabled slipped roll-height the logbook sits within
  # 1% of the catalogue divided by 10, and over 6% above it divided by 10.764 — which is
  # the height #54 drew these frames from.
  u <- tab[tab$tail == "upper" & tab$witness == "logbook", ]
  expect_true(all(abs(u$height_m / (u$flying_height / 10) - 1) < 0.01))
  expect_true(all(u$height_m / (u$flying_height / fly_height_slip_factor()) - 1 > 0.06))
})


test_that("a same-roll sibling settles roll-heights no logbook does (fly#74)", {
  tab <- fly_height_roll_table()
  excl <- utils::read.csv(system.file("extdata/flying_height_rolls_excluded.csv",
                                      package = "fly"))
  key <- function(d) paste(d$film_roll, d$flying_height, d$focal_length, d$scale_n)
  row <- function(k) tab[key(tab) == k, ]
  # bc5596 204-211: 26,212 m, ten times frame 203's 2,621 m to within the rounding, and no
  # logbook page. Frame 212 on the other side reads 2,438 m, which 10.764 reaches to 0.12%,
  # so the sibling that names the relation is 203 and the height is its height.
  a <- row("bc5596 26212 153 12000")
  expect_identical(nrow(a), 1L)
  expect_identical(a$witness, "sibling")
  expect_identical(a$tail, "upper")
  expect_equal(a$height_m, 2621)
  expect_equal(a$factor, 0.1)
  expect_identical(a$cause, "height_decimal_dropped")
  expect_equal(a$sibling_frame, 203)
  expect_identical(a$frames_measured, 8L)
  # bcb98013 frame 52: 97,924 m is 7,924 with a leading 9, and frames 51 and 53 both read
  # 7,924. Its linked logbook page reads 24,000 ft, which names no factor, so it vetoes
  # nothing.
  b <- row("bcb98013 97924 153 40000")
  expect_identical(nrow(b), 1L)
  expect_identical(b$witness, "sibling")
  expect_equal(b$height_m, 7924)
  expect_identical(b$cause, "height_leading_digit_added")
  expect_identical(b$frames_measured, 1L)
  # bc7675 609 m: 2,000 ft TRUNCATED (609.6), beside frame 214 at 6,096 m (20,000 ft). The
  # residual 6096 - 10 x 609 = 6 m is past what rounding alone allows (5.5), so a tolerance
  # that assumes the catalogue only rounds refuses the one row here that needs truncation.
  t7 <- row("bc7675 609 305 16000")
  expect_identical(t7$witness, "sibling")
  expect_equal(t7$height_m, 6096)
  expect_equal(t7$factor, 10)
  expect_equal(t7$sibling_frame, 214)
  expect_gt(6096 - 10 * 609, 0.5 * 11)   # premise: rounding alone would refuse it
  expect_false(any(key(excl) %in% key(rbind(a[, c("film_roll", "flying_height",
                                                  "focal_length", "scale_n")],
                                            b[, c("film_roll", "flying_height",
                                                  "focal_length", "scale_n")]))))
})


test_that("a sibling-tabled frame is sized from the sibling's height, ahead of #54", {
  skip_if_no_terra()
  rf <- roll_fixture()[c(1, 1, 1, 1), ]
  rf$film_roll <- c("bc5596", "bc5596", "bcb98013", "bcb98013")
  rf$scale <- c("1:12000", "1:12000", "1:40000", "1:40000")
  rf$focal_length <- 153
  # The second and fourth differ from a tabled key by one metre, so only #54 reaches them.
  rf$flying_height <- c(26212, 26213, 97924, 97925)
  dem <- roll_dem(800)
  fp <- suppressWarnings(fly_footprint(rf, dem = dem))
  expect_identical(fp$height_source, c("corrected_roll_table", "corrected_unit_slip",
                                       "corrected_roll_table", "corrected_unit_slip"))
  expect_equal(fp$height_agl, c(2621 - 800, 26213 / fly_height_slip_factor() - 800,
                                7924 - 800, 97925 / fly_height_slip_factor() - 800))
  expect_identical(fp$flying_height, rf$flying_height)
})


test_that("a factor below 1 is applied ahead of #54's slip, and only where it is tabled", {
  skip_if_no_terra()
  # fly#71: a 1978 roll #54 divides by 10.764 whose logbook says 10 — bc78065 is
  # catalogued at 4,115 m where the crew wrote 1,350 ft. A factor below 1 must reach the
  # table exactly as one above it does; the gate once accepted only `factor > 1`, which
  # handed these frames to #54's repair and drew them 7.6-9.9% narrow.
  testthat::local_mocked_bindings(
    fly_height_roll_table = function() {
      data.frame(
        film_roll = "bc78065", flying_height = 4115L, focal_length = 153L, scale_n = 2000L,
        factor = 0.1, height_m = 411.5, stringsAsFactors = FALSE
      )
    }
  )
  rf <- roll_fixture()[c(1, 1), ]
  rf$film_roll <- c("bc78065", "bc78066")     # the second shares everything but the roll
  rf$scale <- "1:2000"
  rf$focal_length <- 153
  rf$flying_height <- 4115
  dem <- roll_dem(50)
  # Premise: both readings land in the band here, so nothing but the table separates them.
  band <- fly_height_ratio_band()
  nominal <- 2000 * 0.153
  expect_true(all(c(411.5 - 50, 4115 / fly_height_slip_factor() - 50) / nominal >= band[1] &
                    c(411.5 - 50, 4115 / fly_height_slip_factor() - 50) / nominal <= band[2]))
  fp <- suppressWarnings(fly_footprint(rf, dem = dem))
  expect_identical(fp$height_source, c("corrected_roll_table", "corrected_unit_slip"))
  expect_equal(fp$height_agl[1], 411.5 - 50)
  expect_equal(fp$height_agl[2], 4115 / fly_height_slip_factor() - 50)
  expect_identical(fp$flying_height, rf$flying_height)
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


# fly#72: the r ~ 2 mass. bc5509 is catalogued at 6,553 m, 153 mm, 1:16000, and its logbook
# reads 21,500 ft (6,553.2 m) — its camera line names no focal length, so the spacing is what
# accepted it: the height is right and the scale is half its true denominator. bc78051 sits in the same mass and its logbook writes a 12" lens, so it is the
# other half — a lens catalogued wrong, which nominal scale already sizes.
near_fixture <- function() {
  rf <- roll_fixture()[c(1, 1), ]
  rf$film_roll <- c("bc5509", "bc78051")
  rf$scale <- c("1:16000", "1:20000")
  rf$focal_length <- 153
  rf$flying_height <- c(6553, 6858)
  rf
}

test_that("a near_upper frame with a wrong scale is drawn from its height (fly#72)", {
  skip_if_no_terra()
  tab <- fly_height_roll_table()
  excl <- utils::read.csv(system.file("extdata/flying_height_rolls_excluded.csv",
                                      package = "fly"))
  key <- function(roll, h, f, s) paste(roll, h, f, s)
  k <- key(c("bc5509", "bc78051"), c(6553, 6858), 153, c(16000, 20000))
  # Premise: one real table row and one real exclusion for a different lens, both ABOVE the
  # band here, where #54's repair cannot reach them (r / 10.764 is far under it).
  expect_identical(k %in% key(tab$film_roll, tab$flying_height, tab$focal_length, tab$scale_n),
                   c(TRUE, FALSE))
  ex <- excl[key(excl$film_roll, excl$flying_height, excl$focal_length, excl$scale_n) == k[2], ]
  expect_match(ex$reason, "different lens", fixed = TRUE)
  nominal <- c(16000, 20000) * 0.153
  r <- (c(6553, 6858) - 300) / nominal
  band <- fly_height_ratio_band()
  expect_true(all(r > band[2]))
  expect_true(all(r / fly_height_slip_factor() < band[1]))

  fp <- suppressWarnings(fly_footprint(near_fixture(), dem = roll_dem()))
  expect_identical(fp$height_source, c("corrected_roll_table", "implausible"))
  expect_equal(fp$height_agl[1], 21500 * 0.3048 - 300)
  # Drawn at the width its height implies — about 2.6 times what the fallback drew.
  w <- roll_width(fp)
  expect_equal(w[1], 9 * 0.0254 * (21500 * 0.3048 - 300) / 0.153, tolerance = 1e-3)
  flat <- fly_footprint(near_fixture())
  expect_gt(w[1] / roll_width(flat)[1], 2.5)
  # The lens roll keeps the nominal-scale footprint exactly.
  expect_equal(w[2], roll_width(flat)[2])
  expect_identical(fp$flying_height, near_fixture()$flying_height)
})


test_that("without its table row a near_upper frame falls back to nominal scale", {
  skip_if_no_terra()
  # The defect fly#72 repairs, restored: the same frame, with the table emptied of it.
  tab <- fly_height_roll_table()
  testthat::local_mocked_bindings(
    fly_height_roll_table = function() tab[tab$tail != "near_upper", ]
  )
  fp <- suppressWarnings(fly_footprint(near_fixture()[1, ], dem = roll_dem()))
  expect_identical(fp$height_source, "implausible")
  expect_equal(roll_width(fp), roll_width(fly_footprint(near_fixture()[1, ])))
})


test_that("the infrared roll-heights are sized from the logbook height (fly#91)", {
  skip_if_no_terra()
  # Keyed to the three IR rows, plus a control on bc5312 that differs only in scale. Over
  # ground at 1,000 m every frame is out of band as catalogued: bc5312 and bci12 below it
  # only through the ground (r 0.51, 0.55), bci9 above it (r 2.03).
  ir <- sf::st_sf(
    airp_id = 1:4,
    film_roll = c("bc5312", "bci12", "bci9", "bc5312"),
    scale = c("1:30000", "1:15840", "1:8000", "1:31680"),
    media = c("Film - BW IR", "Film - Colour IR", "Film - Colour IR", "Film - BW IR"),
    focal_length = c(153, 305, 305, 153),
    flying_height = c(3353, 3682, 5944, 3353),
    geometry = sf::st_sfc(
      lapply(seq(-126.60, by = 0.05, length.out = 4), function(x) sf::st_point(c(x, 54.40))),
      crs = 4326
    )
  )
  bb <- sf::st_bbox(sf::st_transform(ir, 3005))
  dem <- terra::rast(xmin = bb[["xmin"]] - 30000, xmax = bb[["xmax"]] + 30000,
                     ymin = bb[["ymin"]] - 30000, ymax = bb[["ymax"]] + 30000,
                     resolution = 100, crs = "EPSG:3005")
  terra::values(dem) <- 1000
  scale_n <- as.numeric(sub("^1:", "", ir$scale))
  r <- (ir$flying_height - 1000) / (scale_n * ir$focal_length / 1000)
  band <- fly_height_ratio_band()
  expect_true(all(r < band[1] | r > band[2]))   # premise: each reaches the table

  fp <- suppressWarnings(fly_footprint(ir, dem = dem))
  expect_identical(fp$height_source,
                   c(rep("corrected_roll_table", 3), "implausible"))
  tab <- fly_height_roll_table()
  h <- tab$height_m[match(paste(ir$film_roll, ir$flying_height, ir$focal_length, scale_n)[1:3],
                          paste(tab$film_roll, tab$flying_height, tab$focal_length, tab$scale_n))]
  expect_false(anyNA(h))
  expect_equal(fp$height_agl[1:3], h - 1000)
  # Drawn at the width the height implies, not the nominal width: about half of nominal on
  # bc5312 and bci12, about twice on bci9.
  w <- roll_width(fp)
  expect_equal(w[1:3], 9 * 0.0254 * (h - 1000) / (ir$focal_length[1:3] / 1000), tolerance = 1e-3)
  w_nominal <- 9 * 0.0254 * scale_n
  expect_true(all(w[1:2] < 0.6 * w_nominal[1:2]))
  expect_gt(w[3], 1.9 * w_nominal[3])
  # The control is untouched by the table: nominal scale, as before.
  expect_equal(w[4], w_nominal[4], tolerance = 1e-3)
})
