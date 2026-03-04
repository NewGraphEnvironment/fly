test_that("fly_summary returns expected columns", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  result <- fly_summary(centroids)
  expect_s3_class(result, "tbl_df")
  expect_named(result, c("scale", "photos", "footprint_m", "half_m", "year_min", "year_max"))
})

test_that("fly_summary footprint_m correct for known scale", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  result <- fly_summary(centroids)
  row_31 <- result[result$scale == "1:31680", ]
  expected <- round(31680 * 0.0254 * 9)
  expect_equal(row_31$footprint_m, expected)
})

test_that("fly_summary groups by scale correctly", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  result <- fly_summary(centroids)
  n_scales <- length(unique(centroids$scale))
  expect_equal(nrow(result), n_scales)
})

test_that("fly_summary respects negative_size parameter", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  r9 <- fly_summary(centroids, negative_size = 9)
  r4 <- fly_summary(centroids, negative_size = 4)
  # Footprint should scale linearly with negative_size
  scale_31_9 <- r9$footprint_m[r9$scale == "1:31680"]
  scale_31_4 <- r4$footprint_m[r4$scale == "1:31680"]
  expect_equal(scale_31_4 / scale_31_9, 4 / 9, tolerance = 0.02)
})
