test_that("fly_select minimal mode returns sf with selection columns", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)
  result <- fly_select(centroids, aoi, mode = "minimal", target_coverage = 0.50)
  expect_s3_class(result, "sf")
  expect_true("selection_order" %in% names(result))
  expect_true("cumulative_coverage_pct" %in% names(result))
})

test_that("fly_select minimal mode selects fewer photos than input", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)
  result <- fly_select(centroids, aoi, mode = "minimal", target_coverage = 0.50)
  expect_lt(nrow(result), nrow(centroids))
})

test_that("fly_select minimal coverage increases monotonically", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)
  result <- fly_select(centroids, aoi, mode = "minimal", target_coverage = 0.50)
  if (nrow(result) > 1) {
    diffs <- diff(result$cumulative_coverage_pct)
    expect_true(all(diffs >= 0))
  }
})

test_that("fly_select defaults to minimal mode", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)
  result_default <- fly_select(centroids, aoi, target_coverage = 0.50)
  result_explicit <- fly_select(centroids, aoi, mode = "minimal", target_coverage = 0.50)
  expect_equal(nrow(result_default), nrow(result_explicit))
  expect_equal(result_default$selection_order, result_explicit$selection_order)
})

test_that("fly_select all mode returns every photo touching AOI", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)
  result <- fly_select(centroids, aoi, mode = "all")
  expect_s3_class(result, "sf")
  # all mode should return at least as many as minimal
  result_min <- fly_select(centroids, aoi, mode = "minimal", target_coverage = 0.99)
  expect_gte(nrow(result), nrow(result_min))
})

test_that("fly_select all mode does not add selection columns", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)
  result <- fly_select(centroids, aoi, mode = "all")
  expect_false("selection_order" %in% names(result))
  expect_false("cumulative_coverage_pct" %in% names(result))
})

test_that("fly_select all mode only returns photos intersecting AOI", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)
  result <- fly_select(centroids, aoi, mode = "all")
  # verify every selected photo footprint actually intersects the AOI
  fp <- fly_footprint(result)
  aoi_t <- sf::st_transform(aoi, sf::st_crs(fp))
  touches <- sf::st_intersects(fp, aoi_t, sparse = FALSE)[, 1]
  expect_true(all(touches))
})

test_that("fly_select all on single scale returns subset", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)
  photos_12k <- centroids[centroids$scale == "1:12000", ]
  result <- fly_select(photos_12k, aoi, mode = "all")
  expect_s3_class(result, "sf")
  expect_lte(nrow(result), nrow(photos_12k))
  expect_true(all(result$scale == "1:12000"))
})

test_that("fly_select rejects invalid mode", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)
  expect_error(fly_select(centroids, aoi, mode = "bogus"))
})

test_that("fly_select minimal handles full coverage without error", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)
  # target 1.0 forces the algorithm to exhaust all photos or hit 100%
  result <- fly_select(centroids, aoi, mode = "minimal", target_coverage = 1.0)
  expect_s3_class(result, "sf")
  expect_gt(nrow(result), 0)
  # coverage should be scalar, not length 0
  expect_length(result$cumulative_coverage_pct, nrow(result))
})
