test_that("fly_filter footprint method returns more photos than centroid", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)

  fp_result <- fly_filter(centroids, aoi, method = "footprint")
  ct_result <- fly_filter(centroids, aoi, method = "centroid")

  expect_s3_class(fp_result, "sf")
  expect_s3_class(ct_result, "sf")
  expect_gte(nrow(fp_result), nrow(ct_result))
})

test_that("fly_filter buffer increases results", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)

  no_buf <- fly_filter(centroids, aoi, method = "centroid", buffer = 0)
  with_buf <- fly_filter(centroids, aoi, method = "centroid", buffer = 5000)

  expect_gte(nrow(with_buf), nrow(no_buf))
})

test_that("fly_filter returns zero-row sf when no intersection", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  # AOI far away from test data
  far_aoi <- sf::st_sf(geometry = sf::st_sfc(
    sf::st_polygon(list(matrix(c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE))),
    crs = 4326
  ))

  result <- fly_filter(centroids, far_aoi, method = "centroid")
  expect_equal(nrow(result), 0)
  expect_equal(names(result), names(centroids))
})

test_that("fly_filter warns when frames have no footprint (#30)", {
  photos <- mixed_media_fixture()
  aoi <- sf::st_as_sfc(sf::st_bbox(
    c(xmin = -126.62, ymin = 54.38, xmax = -126.52, ymax = 54.42),
    crs = 4326
  )) |> sf::st_sf(geometry = _)

  w <- character(0)
  withCallingHandlers(
    fly_filter(photos, aoi, method = "footprint"),
    warning = function(x) {
      w <<- c(w, conditionMessage(x))
      invokeRestart("muffleWarning")
    }
  )
  expect_gt(length(w), 0)
  expect_match(w, "excluded from this filter", all = FALSE)
})

test_that("fly_filter does not admit digital frames on a phantom footprint", {
  photos <- mixed_media_fixture()
  # AOI placed away from the film centroids but where a spurious 9-inch
  # rectangle around the digital frames would still reach.
  aoi <- sf::st_as_sfc(sf::st_bbox(
    c(xmin = -126.552, ymin = 54.415, xmax = -126.548, ymax = 54.418),
    crs = 4326
  )) |> sf::st_sf(geometry = _)

  kept <- suppressWarnings(fly_filter(photos, aoi, method = "footprint"))
  expect_false(any(kept$media == "Digital - Colour"))
})
