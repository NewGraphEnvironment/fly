test_that("fly_coverage returns expected columns", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)
  result <- fly_coverage(centroids, aoi, by = "scale")
  expect_s3_class(result, "tbl_df")
  expect_true(all(c("scale", "n_photos", "covered_km2", "coverage_pct") %in% names(result)))
})

test_that("fly_coverage values are in valid range", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)
  result <- fly_coverage(centroids, aoi, by = "scale")
  expect_true(all(result$coverage_pct >= 0))
  expect_true(all(result$covered_km2 >= 0))
})

test_that("fly_coverage groups correctly", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)
  result <- fly_coverage(centroids, aoi, by = "scale")
  n_scales <- length(unique(centroids$scale))
  expect_equal(nrow(result), n_scales)
})
