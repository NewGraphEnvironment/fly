test_that("fly_fetch returns expected columns", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  result <- fly_fetch(centroids[1, ], type = "thumbnail",
                         dest_dir = tempdir())
  expect_s3_class(result, "tbl_df")
  expect_true(all(c("airp_id", "url", "dest", "success") %in% names(result)))
})

test_that("fly_fetch downloads thumbnail files", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  dest <- file.path(tempdir(), "fly_test_thumbs")
  unlink(dest, recursive = TRUE)

  result <- fly_fetch(centroids[1:2, ], type = "thumbnail",
                         dest_dir = dest)
  expect_equal(nrow(result), 2)
  # Files should exist on disk
  downloaded <- result[result$success, ]
  expect_true(all(file.exists(downloaded$dest)))
})

test_that("fly_fetch skips existing files when overwrite is FALSE", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  dest <- file.path(tempdir(), "fly_test_nooverwrite")
  unlink(dest, recursive = TRUE)

  # Download once
  fly_fetch(centroids[1, ], type = "thumbnail", dest_dir = dest)
  # Get file modification time
  f <- list.files(dest, full.names = TRUE)[1]
  mtime1 <- file.mtime(f)
  Sys.sleep(1)

  # Download again without overwrite
  fly_fetch(centroids[1, ], type = "thumbnail",
               dest_dir = dest, overwrite = FALSE)
  mtime2 <- file.mtime(f)
  expect_equal(mtime1, mtime2)
})

test_that("fly_fetch handles missing URL column", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  centroids$thumbnail_image_url <- NULL
  expect_error(fly_fetch(centroids, type = "thumbnail"),
               "not found in input data")
})

test_that("fly_fetch handles NA URLs gracefully", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  centroids$thumbnail_image_url[1] <- NA
  result <- fly_fetch(centroids[1, ], type = "thumbnail",
                         dest_dir = tempdir())
  expect_false(result$success[1])
})

test_that("fly_fetch rejects invalid type", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  expect_error(fly_fetch(centroids, type = "bogus"))
})

test_that("fly_fetch maps type to correct URL column", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  dest <- file.path(tempdir(), "fly_test_flight_log")
  unlink(dest, recursive = TRUE)

  result <- fly_fetch(centroids[1, ], type = "flight_log",
                         dest_dir = dest)
  expect_s3_class(result, "tbl_df")
  # Should use flight_log_url column
  expect_equal(result$url, centroids$flight_log_url[1])
})
