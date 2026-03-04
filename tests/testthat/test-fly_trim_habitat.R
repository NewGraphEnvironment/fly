test_that("fly_trim_habitat returns sf POLYGON", {
  streams <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  floodplain <- sf::st_read(testdata_path("floodplain.gpkg"), quiet = TRUE)
  result <- fly_trim_habitat(floodplain, streams, photo_buffer = 0)
  expect_s3_class(result, "sf")
})

test_that("fly_trim_habitat output is smaller than input floodplain", {
  streams <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  floodplain <- sf::st_read(testdata_path("floodplain.gpkg"), quiet = TRUE)
  result <- fly_trim_habitat(floodplain, streams, photo_buffer = 0)

  area_orig <- as.numeric(sf::st_area(sf::st_transform(sf::st_union(floodplain), 3005)))
  area_trimmed <- as.numeric(sum(sf::st_area(sf::st_transform(result, 3005))))
  expect_lt(area_trimmed, area_orig)
})

test_that("fly_trim_habitat photo buffer increases area", {
  streams <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  floodplain <- sf::st_read(testdata_path("floodplain.gpkg"), quiet = TRUE)
  no_buf <- fly_trim_habitat(floodplain, streams, photo_buffer = 0)
  with_buf <- fly_trim_habitat(floodplain, streams, photo_buffer = 1000)

  area_no <- as.numeric(sum(sf::st_area(sf::st_transform(no_buf, 3005))))
  area_with <- as.numeric(sum(sf::st_area(sf::st_transform(with_buf, 3005))))
  expect_gt(area_with, area_no)
})

test_that("fly_trim_habitat works with lakes", {
  streams <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  floodplain <- sf::st_read(testdata_path("floodplain.gpkg"), quiet = TRUE)
  lakes <- sf::st_read(testdata_path("lakes.gpkg"), quiet = TRUE)
  result <- fly_trim_habitat(floodplain, streams, lakes_sf = lakes, photo_buffer = 0)
  expect_s3_class(result, "sf")
})
