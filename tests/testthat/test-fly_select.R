test_that("fly_select returns sf with selection columns", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)
  result <- fly_select(centroids, aoi, target_coverage = 0.50)
  expect_s3_class(result, "sf")
  expect_true("selection_order" %in% names(result))
  expect_true("cumulative_coverage_pct" %in% names(result))
})

test_that("fly_select selects fewer photos than input", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)
  result <- fly_select(centroids, aoi, target_coverage = 0.50)
  expect_lt(nrow(result), nrow(centroids))
})

test_that("fly_select coverage increases monotonically", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)
  result <- fly_select(centroids, aoi, target_coverage = 0.50)
  if (nrow(result) > 1) {
    diffs <- diff(result$cumulative_coverage_pct)
    expect_true(all(diffs >= 0))
  }
})
