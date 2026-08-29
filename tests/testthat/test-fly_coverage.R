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

test_that("fly_coverage warns rather than silently scoring unsized frames (#30)", {
  photos <- mixed_media_fixture()
  photos$photo_year <- c(1968L, 1968L, 2018L, 2018L)
  aoi <- sf::st_as_sfc(sf::st_bbox(
    c(xmin = -126.62, ymin = 54.38, xmax = -126.52, ymax = 54.42),
    crs = 4326
  )) |> sf::st_sf(geometry = _)

  w <- character(0)
  res <- withCallingHandlers(
    fly_coverage(photos, aoi, by = "photo_year"),
    warning = function(x) {
      w <<- c(w, conditionMessage(x))
      invokeRestart("muffleWarning")
    }
  )
  expect_gt(length(w), 0)
  expect_match(w, "excluded from coverage", all = FALSE)

  # The digital-only group must not report coverage it cannot support.
  digital_row <- res[res$photo_year == 2018, ]
  expect_equal(as.numeric(digital_row$coverage_pct), 0)
})
