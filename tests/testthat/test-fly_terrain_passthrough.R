# A `dem` argument that is accepted but never reaches fly_footprint() would be
# invisible: every one of these functions returns perfectly plausible numbers
# either way.
#
# Asserting that the numbers move is only a real check where they demonstrably
# do. On the bundled data fly_filter() keeps 20 of 20 and fly_select() picks the
# same frames with or without a DEM, so `expect_gte`/`expect_lte` there hold
# for both implementations and detect nothing. Those two therefore also strip
# `flying_height`, which makes fly_footprint() error — something it can only do
# if `dem` actually arrived.
#
# Verified by patching fly_footprint() to discard `dem`: every test below then
# fails.

test_that("fly_coverage passes dem through to the footprints", {
  skip_if_no_terra()
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)

  flat <- fly_coverage(centroids, aoi, by = "scale")
  terr <- fly_coverage(centroids, aoi, by = "scale", dem = testdata_path("dem.tif"))

  expect_equal(terr$scale, flat$scale)
  expect_true(all(terr$covered_km2 >= flat$covered_km2))
  expect_true(any(terr$covered_km2 > flat$covered_km2))
})

test_that("fly_overlap passes dem through to the footprints", {
  skip_if_no_terra()
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  photos <- centroids[centroids$scale == "1:12000", ]

  flat <- fly_overlap(photos)
  terr <- fly_overlap(photos, dem = testdata_path("dem.tif"))

  # Larger footprints overlap more, and can bring new pairs into contact.
  expect_gte(nrow(terr), nrow(flat))
  expect_gt(sum(terr$overlap_km2), sum(flat$overlap_km2))
})

test_that("fly_filter passes dem through to the footprints", {
  skip_if_no_terra()
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)

  flat <- fly_filter(centroids, aoi, method = "footprint")
  terr <- fly_filter(centroids, aoi, method = "footprint",
                     dem = testdata_path("dem.tif"))
  # Terrain sizing only grows footprints here, so the kept set cannot shrink.
  expect_gte(nrow(terr), nrow(flat))
  expect_true(all(flat$airp_id %in% terr$airp_id))

  # The centroid method never builds a footprint, so a dem must not change it.
  expect_equal(
    fly_filter(centroids, aoi, method = "centroid")$airp_id,
    fly_filter(centroids, aoi, method = "centroid",
               dem = testdata_path("dem.tif"))$airp_id
  )

  # The comparison above cannot fail on this data — every frame is kept either
  # way — so it does not establish that `dem` arrived. This does.
  no_height <- centroids
  no_height$flying_height <- NULL
  expect_error(
    fly_filter(no_height, aoi, method = "footprint", dem = testdata_path("dem.tif")),
    "flying_height"
  )
})

test_that("fly_select passes dem through in both modes", {
  skip_if_no_terra()
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)
  photos <- centroids[centroids$scale == "1:12000", ]
  dem <- testdata_path("dem.tif")

  # mode = "all" routes through fly_select_all()
  all_flat <- fly_select(photos, aoi, mode = "all")
  all_terr <- fly_select(photos, aoi, mode = "all", dem = dem)
  expect_gte(nrow(all_terr), nrow(all_flat))

  # mode = "minimal" routes through fly_select_minimal() — a separate call site,
  # so passing in one mode proves nothing about the other.
  min_flat <- fly_select(photos, aoi, mode = "minimal", target_coverage = 0.95)
  min_terr <- fly_select(photos, aoi, mode = "minimal", target_coverage = 0.95,
                         dem = dem)
  expect_lte(nrow(min_terr), nrow(min_flat))

  # Neither comparison above can fail on this data — the same frames are chosen
  # with or without a DEM. Assert arrival directly, once per internal call site,
  # since fly_select_all() and fly_select_minimal() are separate.
  no_height <- photos
  no_height$flying_height <- NULL
  expect_error(fly_select(no_height, aoi, mode = "all", dem = dem), "flying_height")
  expect_error(fly_select(no_height, aoi, mode = "minimal",
                          target_coverage = 0.95, dem = dem), "flying_height")
})

test_that("fly_georef passes dem through to the GCP footprints", {
  skip_if_no_terra()
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)[1:2, ]
  # No images to warp, so this exercises the argument path and the footprint
  # build rather than GDAL. A dem that never reached fly_footprint() would
  # produce identical GCPs, which is exactly what cannot be seen from outside.
  fetch_result <- dplyr::tibble(
    airp_id = centroids$airp_id,
    dest = file.path(tempdir(), paste0(centroids$airp_id, ".jpg")),
    success = c(FALSE, FALSE)
  )
  # `suppressWarnings` as well as `suppressMessages`: these two centroids are not
  # adjacent frames, so neither gets a bearing and `fly_georef()` correctly says it is
  # georeferencing them as though the flight line ran due north. That warning is
  # asserted in test-fly_georef.R; this test is about `dem` arriving.
  res <- suppressWarnings(suppressMessages(
    fly_georef(fetch_result, centroids,
               dest_dir = file.path(tempdir(), "georef-dem"),
               dem = testdata_path("dem.tif"))
  ))
  expect_equal(nrow(res), 2)

  # The assertion above tolerates the argument; it does not prove it arrived,
  # because with no images to warp the GCPs are never observable. Strip the
  # column the DEM path requires: fly_footprint() then errors, and it can only
  # do so if `dem` actually reached it.
  no_height <- centroids
  no_height$flying_height <- NULL
  expect_error(
    suppressMessages(
      fly_georef(fetch_result, no_height,
                 dest_dir = file.path(tempdir(), "georef-dem2"),
                 dem = testdata_path("dem.tif"))
    ),
    "flying_height"
  )
})
