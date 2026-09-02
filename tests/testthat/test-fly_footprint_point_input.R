# Guard against a function that estimates ground coverage *from* a centroid being
# handed a footprint instead.
#
# `sf::st_coordinates()` returns one row per feature for POINT and one row per
# *vertex* for anything else, so a non-POINT input silently multiplies the
# coordinate rows the sizing code indexes. #37 reported the visible half of that;
# the two quieter halves are pinned below.

test_that("the bundled centroids are points and size one footprint per frame", {
  # Premise for everything else in this file. If the fixture ever stops being
  # POINT, the rejection tests below would pass for the wrong reason.
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  expect_true(all(as.character(sf::st_geometry_type(centroids)) == "POINT"))

  fp <- fly_footprint(centroids)
  expect_equal(nrow(fp), nrow(centroids))
})

test_that("fly_footprint refuses its own output", {
  # The reproduction from #37: without the guard this returns 100 rows from 20,
  # recycling each frame's attributes across five geometries.
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  fp <- fly_footprint(centroids)
  expect_equal(nrow(fp), nrow(centroids))
  expect_error(fly_footprint(fp), "must be points")
})

test_that("fly_footprint refuses every non-point geometry", {
  for (nm in names(non_point_cases())) {
    expect_error(fly_footprint(non_point_cases()[[nm]]), "must be points",
                 info = nm)
  }
})

test_that("fly_bearing refuses every non-point geometry", {
  # The worse of the two defects, and the reason this file covers more than
  # fly_footprint(): handed polygons, fly_bearing() returned the RIGHT number of
  # rows with bearings up to 272 degrees wrong, because it indexes a 5n-row
  # coordinate matrix with a permutation of 1:n. A wrong row count is detectable;
  # a wrong value at the right row count is not.
  for (nm in names(non_point_cases())) {
    expect_error(fly_bearing(non_point_cases()[[nm]]), "must be points", info = nm)
  }
})

test_that("fly_filter refuses non-point geometry under both methods", {
  # The centroid method is the only path in the package that reads photo geometry
  # without going through fly_footprint(), so it is the one place the guard has to
  # be repeated rather than inherited. Handed footprints it silently became a
  # footprint filter: 20 rows selected where points gave 7.
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)
  cases <- non_point_cases()
  for (nm in names(cases)) {
    for (method in c("footprint", "centroid")) {
      expect_error(fly_filter(cases[[nm]], aoi, method = method), "must be points",
                   info = paste(nm, method))
    }
  }
})

test_that("every export that consumes centroids refuses non-point geometry", {
  # The global invariant, rather than more examples of one. These four reach the
  # guard through their own fly_footprint() call; asserting it here is what stops
  # a future direct st_coordinates() in any of them from reopening the hole
  # silently.
  sf::sf_use_s2(FALSE)
  on.exit(sf::sf_use_s2(TRUE), add = TRUE)

  poly <- non_point_cases()$POLYGON
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)
  dest <- file.path(tempdir(), "fly37_georef_out")
  unlink(dest, recursive = TRUE)
  on.exit(unlink(dest, recursive = TRUE), add = TRUE)

  # A fetch_result is validated on its column names alone, so this reaches the
  # geometry guard without any network.
  fake_fetch <- dplyr::tibble(
    airp_id = poly$airp_id[1], dest = NA_character_, success = FALSE
  )

  expect_error(fly_coverage(poly, aoi), "must be points")
  expect_error(fly_overlap(poly), "must be points")
  expect_error(fly_select(poly, aoi), "must be points")
  expect_error(fly_georef(fake_fetch, poly, dest_dir = dest), "must be points")
})

test_that("zero-row input is still accepted", {
  # `all()` of an empty vector is TRUE, so an empty sf passes the guard vacuously.
  # That is correct rather than a hole — footprint_cases() carries an "empty
  # input" case and fly_footprint() is documented to handle it — and it is
  # asserted here so nobody "fixes" the vacuous pass into a refusal.
  empty <- digital_fixture()[0, ]
  expect_equal(nrow(empty), 0L)
  expect_no_error(fp <- fly_footprint(empty))
  expect_equal(nrow(fp), 0L)
})

test_that("points still pass through unchanged", {
  # The guard must refuse footprints without refusing legitimate input. Pinned
  # against values, not merely against the absence of an error.
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  expect_no_error(b <- fly_bearing(centroids))
  expect_equal(nrow(b), nrow(centroids))
  expect_true(any(!is.na(b$bearing)))

  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)
  sf::sf_use_s2(FALSE)
  on.exit(sf::sf_use_s2(TRUE), add = TRUE)
  expect_no_error(fly_filter(centroids, aoi, method = "centroid"))
})
