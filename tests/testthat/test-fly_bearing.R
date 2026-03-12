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
