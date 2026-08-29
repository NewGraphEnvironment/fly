test_that("fly_footprint returns sf POLYGON with correct rows", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  fp <- fly_footprint(centroids)
  expect_s3_class(fp, "sf")
  expect_equal(nrow(fp), nrow(centroids))
  expect_true(all(sf::st_geometry_type(fp) == "POLYGON"))
})

test_that("fly_footprint preserves input CRS", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  fp <- fly_footprint(centroids)
  expect_equal(sf::st_crs(fp), sf::st_crs(centroids))
})

test_that("fly_footprint dimensions match expected values", {
  # 1:31680 with 9" negative = 31680 * 9 * 0.0254 = 7240.0 m per side
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  fp_31 <- centroids[centroids$scale == "1:31680", ] |> fly_footprint()
  # Check one footprint area in BC Albers (should be ~7240^2 = ~52.4 km2)
  fp_3005 <- sf::st_transform(fp_31[1, ], 3005)
  area_m2 <- as.numeric(sf::st_area(fp_3005))
  expected_side <- 31680 * 9 * 0.0254
  expected_area <- expected_side^2
  expect_equal(area_m2, expected_area, tolerance = 0.01)
})

test_that("fly_footprint respects negative_size parameter", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  fp_9 <- fly_footprint(centroids[1, ], negative_size = 9)
  fp_4 <- fly_footprint(centroids[1, ], negative_size = 4)
  area_9 <- as.numeric(sf::st_area(sf::st_transform(fp_9, 3005)))
  area_4 <- as.numeric(sf::st_area(sf::st_transform(fp_4, 3005)))
  # 4/9 ratio squared
  expect_equal(area_4 / area_9, (4 / 9)^2, tolerance = 0.01)
})

test_that("fly_footprint errors on missing scale column", {
  pt <- sf::st_sf(geometry = sf::st_sfc(sf::st_point(c(-126.5, 54.4)), crs = 4326))
  expect_error(fly_footprint(pt), "scale")
})

test_that("fly_footprint errors on non-sf input", {
  expect_error(fly_footprint(data.frame(x = 1)), "sf object")
})

# --- media-aware format resolution (#30) ---------------------------------

test_that("fly_footprint returns empty geometry for unknown media format", {
  photos <- mixed_media_fixture()
  fp <- suppressWarnings(fly_footprint(photos))
  empty <- sf::st_is_empty(sf::st_geometry(fp))
  expect_equal(empty, c(FALSE, FALSE, TRUE, TRUE))
})

test_that("fly_footprint does not fabricate a 9-inch rectangle for digital", {
  photos <- mixed_media_fixture()
  fp <- suppressWarnings(fly_footprint(photos))
  digital <- fp[fp$media == "Digital - Colour", ]
  areas <- as.numeric(sf::st_area(sf::st_transform(digital, 3005)))
  # A 9" negative at 1:15000 would be 3429 m per side; must not appear.
  expect_true(all(areas == 0))
})

test_that("fly_footprint records the basis for every row", {
  photos <- mixed_media_fixture()
  fp <- suppressWarnings(fly_footprint(photos))
  expect_true("footprint_basis" %in% names(fp))
  expect_equal(
    fp$footprint_basis,
    c("Film - BW", "Film - Colour", "unknown_format", "unknown_format")
  )
})

test_that("fly_footprint warns, catchably, with the unknown count", {
  photos <- mixed_media_fixture()
  w <- character(0)
  withCallingHandlers(
    fly_footprint(photos),
    warning = function(x) {
      w <<- c(w, conditionMessage(x))
      invokeRestart("muffleWarning")
    }
  )
  expect_gt(length(w), 0)
  expect_match(w, "2", all = FALSE)
  expect_match(w, "Digital - Colour", all = FALSE)
})

test_that("fly_footprint format_size override sizes digital frames", {
  photos <- mixed_media_fixture()
  fp <- fly_footprint(photos, format_size = c("Digital - Colour" = 3.54))
  digital <- fp[fp$media == "Digital - Colour", ]
  expect_false(any(sf::st_is_empty(sf::st_geometry(digital))))
  area_m2 <- as.numeric(sf::st_area(sf::st_transform(digital[1, ], 3005)))
  expected_side <- 15000 * 3.54 * 0.0254
  expect_equal(area_m2, expected_side^2, tolerance = 0.01)
  expect_equal(digital$footprint_basis, rep("Digital - Colour", 2))
})

test_that("fly_footprint falls back to negative_size when media is absent", {
  photos <- mixed_media_fixture()
  photos$media <- NULL
  fp <- fly_footprint(photos)
  expect_false(any(sf::st_is_empty(sf::st_geometry(fp))))
  expect_equal(fp$footprint_basis, rep("assumed_default", 4))
  area_m2 <- as.numeric(sf::st_area(sf::st_transform(fp[1, ], 3005)))
  expected_side <- 12000 * 9 * 0.0254
  expect_equal(area_m2, expected_side^2, tolerance = 0.01)
})

test_that("fly_footprint leaves film-only input unchanged", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  expect_silent(fp <- fly_footprint(centroids))
  expect_false(any(sf::st_is_empty(sf::st_geometry(fp))))
  expect_equal(nrow(fp), nrow(centroids))
  area_m2 <- as.numeric(sf::st_area(sf::st_transform(fp[1, ], 3005)))
  expected_side <- as.numeric(sub("1:", "", centroids$scale[1])) * 9 * 0.0254
  expect_equal(area_m2, expected_side^2, tolerance = 0.01)
})
