test_that("fly_georef returns expected columns", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  dest_fetch <- file.path(tempdir(), "fly_georef_test_fetch")
  unlink(dest_fetch, recursive = TRUE)

  fetched <- fly_fetch(centroids[1, ], type = "thumbnail",
                       dest_dir = dest_fetch)
  dest_georef <- file.path(tempdir(), "fly_georef_test_out")
  unlink(dest_georef, recursive = TRUE)

  result <- fly_georef(fetched, centroids[1, ],
                       dest_dir = dest_georef)
  expect_s3_class(result, "tbl_df")
  expect_true(all(c("airp_id", "source", "dest", "success") %in% names(result)))
})

test_that("fly_georef produces georeferenced TIFFs", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  dest_fetch <- file.path(tempdir(), "fly_georef_test_tiff_fetch")
  unlink(dest_fetch, recursive = TRUE)

  fetched <- fly_fetch(centroids[1, ], type = "thumbnail",
                       dest_dir = dest_fetch)
  dest_georef <- file.path(tempdir(), "fly_georef_test_tiff_out")
  unlink(dest_georef, recursive = TRUE)

  result <- fly_georef(fetched, centroids[1, ],
                       dest_dir = dest_georef)
  expect_true(result$success[1])
  expect_true(file.exists(result$dest[1]))

  # Verify it has a CRS
  info <- sf::gdal_utils("info", source = result$dest[1], quiet = TRUE)
  expect_true(grepl("3005", info))
})

test_that("fly_georef skips failed fetches", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  fake_fetch <- dplyr::tibble(
    airp_id = centroids$airp_id[1],
    url = "https://example.com/fake.jpg",
    dest = "/nonexistent/fake.jpg",
    success = FALSE
  )
  result <- fly_georef(fake_fetch, centroids[1, ],
                       dest_dir = tempdir())
  expect_false(result$success[1])
})

test_that("fly_georef skips existing when overwrite is FALSE", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  dest_fetch <- file.path(tempdir(), "fly_georef_overwrite_fetch")
  unlink(dest_fetch, recursive = TRUE)

  fetched <- fly_fetch(centroids[1, ], type = "thumbnail",
                       dest_dir = dest_fetch)
  dest_georef <- file.path(tempdir(), "fly_georef_overwrite_out")
  unlink(dest_georef, recursive = TRUE)

  # First run
  fly_georef(fetched, centroids[1, ], dest_dir = dest_georef)
  f <- list.files(dest_georef, full.names = TRUE)[1]
  mtime1 <- file.mtime(f)
  Sys.sleep(1)

  # Second run without overwrite
  fly_georef(fetched, centroids[1, ],
             dest_dir = dest_georef, overwrite = FALSE)
  mtime2 <- file.mtime(f)
  expect_equal(mtime1, mtime2)
})

test_that("fly_georef rejects bad input", {
  expect_error(fly_georef(data.frame(x = 1), data.frame(y = 1)),
               "fly_fetch")
})

test_that("fly_georef extent matches footprint", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  dest_fetch <- file.path(tempdir(), "fly_georef_extent_fetch")
  unlink(dest_fetch, recursive = TRUE)

  fetched <- fly_fetch(centroids[1, ], type = "thumbnail",
                       dest_dir = dest_fetch)
  dest_georef <- file.path(tempdir(), "fly_georef_extent_out")
  unlink(dest_georef, recursive = TRUE)

  result <- fly_georef(fetched, centroids[1, ],
                       dest_dir = dest_georef)

  # Compare georef extent to footprint extent
  fp <- fly_footprint(centroids[1, ]) |> sf::st_transform(3005)
  fp_bbox <- sf::st_bbox(fp)

  info <- sf::gdal_utils("info", source = result$dest[1], quiet = TRUE)
  ul <- regmatches(info, regexpr("Upper Left\\s+\\([^)]+\\)", info))
  lr <- regmatches(info, regexpr("Lower Right\\s+\\([^)]+\\)", info))
  expect_length(ul, 1)
  expect_length(lr, 1)
})

test_that("fly_georef accepts rotation parameter", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  dest_fetch <- file.path(tempdir(), "fly_georef_rot_fetch")
  unlink(dest_fetch, recursive = TRUE)

  fetched <- fly_fetch(centroids[1, ], type = "thumbnail",
                       dest_dir = dest_fetch)

  # Each rotation value should produce a valid georef
  for (rot in c(0, 90, 180, 270)) {
    dest_georef <- file.path(tempdir(), paste0("fly_georef_rot_", rot))
    unlink(dest_georef, recursive = TRUE)
    result <- fly_georef(fetched, centroids[1, ],
                         dest_dir = dest_georef, rotation = rot)
    expect_true(result$success[1], info = paste("rotation =", rot))
  }
})

test_that("fly_georef rejects invalid rotation", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  fake_fetch <- dplyr::tibble(
    airp_id = centroids$airp_id[1],
    dest = tempfile(), success = TRUE
  )
  expect_error(fly_georef(fake_fetch, centroids[1, ], rotation = 45),
               "one of 0, 90, 180, 270")
})

test_that("fly_georef reads rotation from column", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  dest_fetch <- file.path(tempdir(), "fly_georef_rotcol_fetch")
  unlink(dest_fetch, recursive = TRUE)

  fetched <- fly_fetch(centroids[1, ], type = "thumbnail",
                       dest_dir = dest_fetch)
  dest_georef <- file.path(tempdir(), "fly_georef_rotcol_out")
  unlink(dest_georef, recursive = TRUE)

  # Add rotation column
  centroids$rotation <- 90
  result <- fly_georef(fetched, centroids[1, ],
                       dest_dir = dest_georef)
  expect_true(result$success[1])
})
