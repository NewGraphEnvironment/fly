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
