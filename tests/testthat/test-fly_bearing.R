test_that("fly_bearing adds bearing column", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  result <- fly_bearing(centroids)
  expect_true("bearing" %in% names(result))
  expect_equal(nrow(result), nrow(centroids))
})

test_that("fly_bearing computes valid azimuths", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  result <- fly_bearing(centroids)

  # All non-NA bearings should be 0-360
  bearings <- result$bearing[!is.na(result$bearing)]
  expect_true(all(bearings >= 0 & bearings < 360))
})

test_that("fly_bearing handles single-frame rolls", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)

  # bc5300 and bc5301 have only 1 frame each in test data
  single <- centroids[centroids$film_roll == "bc5300", ]
  expect_equal(nrow(single), 1)

  result <- fly_bearing(single)
  expect_true(is.na(result$bearing[1]))
})

test_that("fly_bearing is consistent within flight legs", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  result <- fly_bearing(centroids)

  # bc5282 has 10 frames — consecutive frames on same leg should

  # have similar bearings (within 30 degrees)
  roll <- result[result$film_roll == "bc5282", ]
  roll <- roll[order(roll$frame_number), ]
  bearings <- roll$bearing

  # Check that at least some consecutive pairs are similar
  diffs <- abs(diff(bearings))
  # Normalize to 0-180
  diffs <- pmin(diffs, 360 - diffs)
  # Back-and-forth legs produce ~180 differences, same-leg pairs < 30
  expect_true(any(diffs < 30))
})

test_that("fly_bearing rejects missing columns", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  centroids$film_roll <- NULL
  expect_error(fly_bearing(centroids), "film_roll")
})

test_that("a line's last frame takes the line's bearing, not the turn's (fly#87)", {
  # Two lines joined by a turn, the way the catalogue numbers them: frames 1-5 fly 309
  # degrees at 1 km, frame 6 starts the next line 13 km away, which then flies 129.
  b1 <- 309 * pi / 180
  b2 <- 129 * pi / 180
  line1 <- t(vapply(0:4, function(i) c(1200000, 1000000) + i * 1000 * c(sin(b1), cos(b1)),
                    numeric(2)))
  start2 <- line1[5, ] + c(9000, 9000)
  line2 <- t(vapply(0:4, function(i) start2 + i * 1000 * c(sin(b2), cos(b2)), numeric(2)))
  xy <- rbind(line1, line2)
  pts <- sf::st_sf(film_roll = "bcx", frame_number = 1:10,
                   geometry = sf::st_sfc(lapply(seq_len(10), function(i) sf::st_point(xy[i, ])),
                                         crs = 3005))
  b <- fly_bearing(pts)$bearing
  expect_equal(b[1:5], rep(309, 5), tolerance = 1e-9)
  expect_equal(b[6:10], rep(129, 5), tolerance = 1e-9)

  # Restore the old rule (forward whenever a forward neighbour exists) and frame 5 takes the
  # turn: this is the assertion that pins the fix rather than the fixture.
  turn <- (atan2(xy[6, 1] - xy[5, 1], xy[6, 2] - xy[5, 2]) * 180 / pi) %% 360
  expect_gt(abs(((turn - 309 + 180) %% 360) - 180), 10)
})

test_that("a zero-length forward step does not invent a bearing of 0", {
  xy <- rbind(c(0, 0), c(700, 700), c(1400, 1400), c(1400, 1400))
  pts <- sf::st_sf(film_roll = "bcx", frame_number = 1:4,
                   geometry = sf::st_sfc(lapply(1:4, function(i) sf::st_point(xy[i, ] + 1e6)),
                                         crs = 3005))
  b <- fly_bearing(pts)$bearing
  expect_equal(b[3], 45, tolerance = 1e-9)
  # Frame 4's only step has zero length: no heading, so NA rather than 0.
  expect_true(is.na(b[4]))
})

test_that("a frame sharing its predecessor's point keeps its forward bearing", {
  # code-check, fly#87: a zero backward step must not make every forward step "long".
  xy <- rbind(c(0, 0), c(700, 700), c(700, 700), c(1400, 1400), c(2100, 2100))
  pts <- sf::st_sf(film_roll = "bcx", frame_number = 1:5,
                   geometry = sf::st_sfc(lapply(1:5, function(i) sf::st_point(xy[i, ] + 1e6)),
                                         crs = 3005))
  b <- fly_bearing(pts)$bearing
  expect_equal(b[c(1, 3, 4, 5)], rep(45, 4), tolerance = 1e-9)

  # The same at frame 2, where there is no earlier step to check the backward one against,
  # so only the zero-length guard itself can keep the forward bearing.
  xy <- rbind(c(0, 0), c(0, 0), c(700, 700), c(1400, 1400))
  pts <- sf::st_sf(film_roll = "bcx", frame_number = 1:4,
                   geometry = sf::st_sfc(lapply(1:4, function(i) sf::st_point(xy[i, ] + 1e6)),
                                         crs = 3005))
  expect_equal(fly_bearing(pts)$bearing[2], 45, tolerance = 1e-9)
})

test_that("a short, off-line backward step does not capture a frame on the line", {
  # Frames 1-3 fly 45 at 1 km, frame 4 is catalogued 300 m off to the side, and 4 -> 5 ->
  # 6 continue at 45. The forward step from 4 is long against the short odd backward one,
  # but the backward step does not continue the line, so 4 keeps its forward bearing.
  b45 <- 45 * pi / 180
  on <- function(k) c(1e6, 1e6) + k * 1000 * c(sin(b45), cos(b45))
  xy <- rbind(on(0), on(1), on(2), on(2) + c(300, -300), on(3) + c(300, -300),
              on(4) + c(300, -300))
  pts <- sf::st_sf(film_roll = "bcx", frame_number = 1:6,
                   geometry = sf::st_sfc(lapply(1:6, function(i) sf::st_point(xy[i, ])),
                                         crs = 3005))
  b <- fly_bearing(pts)$bearing
  expect_equal(b[4], 45, tolerance = 1e-9)
})

test_that("an empty point leaves its neighbours' bearings alone rather than aborting", {
  pts <- sf::st_sf(film_roll = "bcx", frame_number = 1:4,
                   geometry = sf::st_sfc(sf::st_point(c(1e6, 1e6)), sf::st_point(),
                                         sf::st_point(c(1e6 + 1400, 1e6 + 1400)),
                                         sf::st_point(c(1e6 + 2100, 1e6 + 2100)), crs = 3005))
  expect_no_error(b <- fly_bearing(pts)$bearing)
  expect_equal(b[4], 45, tolerance = 1e-9)
})

test_that("a step with no heading is not used to judge whether the line continues", {
  # Frames 1 and 2 share a point, frame 3 is 1 km on at 45, frame 4 starts the next line
  # 13 km away. The step before frame 3's backward step has no heading (`atan2(0, 0)` is
  # north), so it must not veto frame 3 taking its line's bearing (code-check, fly#87).
  b45 <- 45 * pi / 180
  xy <- rbind(c(0, 0), c(0, 0), 1000 * c(sin(b45), cos(b45)), c(9000, -9000))
  pts <- sf::st_sf(film_roll = "bcx", frame_number = 1:4,
                   geometry = sf::st_sfc(lapply(1:4, function(i) sf::st_point(xy[i, ] + 1e6)),
                                         crs = 3005))
  expect_equal(fly_bearing(pts)$bearing[3], 45, tolerance = 1e-9)
})
