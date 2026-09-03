test_that("fly_georef returns expected columns", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  dest_fetch <- file.path(tempdir(), "fly_georef_test_fetch")
  unlink(dest_fetch, recursive = TRUE)

  fetched <- fly_fetch(centroids[1, ], type = "thumbnail",
                       dest_dir = dest_fetch)
  dest_georef <- file.path(tempdir(), "fly_georef_test_out")
  unlink(dest_georef, recursive = TRUE)

  result <- suppressWarnings(fly_georef(fetched, centroids[1, ],
                       dest_dir = dest_georef))
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

  result <- suppressWarnings(fly_georef(fetched, centroids[1, ],
                       dest_dir = dest_georef))
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
  result <- suppressWarnings(fly_georef(fake_fetch, centroids[1, ],
                       dest_dir = tempdir()))
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
  suppressWarnings(fly_georef(fetched, centroids[1, ], dest_dir = dest_georef))
  f <- list.files(dest_georef, full.names = TRUE)[1]
  mtime1 <- file.mtime(f)
  Sys.sleep(1)

  # Second run without overwrite
  suppressWarnings(fly_georef(fetched, centroids[1, ],
             dest_dir = dest_georef, overwrite = FALSE))
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

  result <- suppressWarnings(fly_georef(fetched, centroids[1, ],
                       dest_dir = dest_georef))

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
    result <- suppressWarnings(fly_georef(fetched, centroids[1, ],
                         dest_dir = dest_georef, rotation = rot))
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
               "one of")
})

test_that("fly_georef auto rotation uses bearing", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  dest_fetch <- file.path(tempdir(), "fly_georef_auto_fetch")
  unlink(dest_fetch, recursive = TRUE)

  fetched <- fly_fetch(centroids[1, ], type = "thumbnail",
                       dest_dir = dest_fetch)
  dest_georef <- file.path(tempdir(), "fly_georef_auto_out")
  unlink(dest_georef, recursive = TRUE)

  # Default is "auto" — should work with film_roll + frame_number
  result <- suppressWarnings(fly_georef(fetched, centroids[1, ],
                       dest_dir = dest_georef))
  expect_true(result$success[1])
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
  result <- suppressWarnings(fly_georef(fetched, centroids[1, ],
                       dest_dir = dest_georef))
  expect_true(result$success[1])
})


test_that("a frame with no flight bearing is georeferenced due north, and says so", {
  # Every other test in this file georeferences `centroids[1, ]`, which has no adjacent
  # neighbour and so no bearing. That is the ordinary result of georeferencing one frame
  # on its own, it is not free — the footprint is drawn axis-aligned when the real one
  # is rotated — and it is warned about. Asserted once here so the `suppressWarnings()`
  # at those call sites is a recorded expectation rather than a silenced signal.
  skip_if_offline()
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  one <- centroids[1, ]

  expect_true(is.na(fly_footprint(one)$footprint_bearing))          # premise
  fetched <- fly_fetch(one, type = "thumbnail", dest_dir = withr::local_tempdir())
  skip_if_not(all(fetched$success), "thumbnail not reachable")

  expect_warning(
    fly_georef(fetched, one, dest_dir = withr::local_tempdir()),
    "no flight bearing"
  )
})


test_that("a rotated film frame is refused rather than georeferenced on a guess", {
  # fly#26. Film footprints are rotated onto the flight bearing now, and the image's
  # corner mapping is a per-roll property — measured 0 for bc5282 (1968) against 90 for
  # bc83062 (1983), so there is no constant to apply. A wrong mapping here produces a
  # valid GeoTIFF over the right ground with the picture a quarter turn out, which
  # nothing downstream would report, so the frame is skipped instead.
  skip_if_offline()
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)

  # bc5282 231/232 are the one adjacent pair in the bundled sample, and they fly 230 —
  # so this fixture reaches the rotated-square branch at all. Without the premise a
  # future fixture change would make the test vacuous rather than red.
  pair <- centroids[centroids$film_roll == "bc5282" &
                      centroids$frame_number %in% c(231, 232), ]
  expect_equal(nrow(pair), 2)
  fp <- fly_footprint(pair)
  expect_true(all(is.finite(fp$footprint_bearing)))
  expect_true(all(fly_is_square(fp)))

  fetched <- fly_fetch(pair, type = "thumbnail", dest_dir = withr::local_tempdir())
  skip_if_not(all(fetched$success), "thumbnails not reachable")

  dest <- withr::local_tempdir()
  # One warning per refused frame, so both are collected rather than letting
  # `expect_warning()` absorb the first and leak the second.
  warns <- character(0)
  res <- withCallingHandlers(
    fly_georef(fetched, pair, dest_dir = dest),
    warning = function(w) { warns <<- c(warns, conditionMessage(w)); invokeRestart("muffleWarning") }
  )
  expect_equal(sum(grepl("per-roll property", warns)), 2)
  expect_false(any(res$success))
  expect_equal(length(list.files(dest, pattern = "\\.tif$")), 0)

  # And the documented escape hatch still works: supply the roll's measured rotation and
  # the same frames georeference. This is the remedy the warning names, so it is run
  # rather than merely described — a guard whose advice nobody executes is a guard whose
  # advice can be wrong.
  pair$rotation <- 0L
  res2 <- fly_georef(fetched, pair, dest_dir = withr::local_tempdir())
  expect_true(all(res2$success))
})
