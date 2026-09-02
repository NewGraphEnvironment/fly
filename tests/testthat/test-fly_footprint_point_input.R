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
  expect_error(fly_footprint(fp), "`centroids_sf` must be points")
})

test_that("fly_footprint refuses every non-point geometry", {
  for (nm in names(non_point_cases())) {
    expect_error(fly_footprint(non_point_cases()[[nm]]),
                 "`centroids_sf` must be points", info = nm)
  }
})

test_that("fly_bearing refuses every non-point geometry", {
  # The worse of the two defects, and the reason this file covers more than
  # fly_footprint(): handed polygons, fly_bearing() returned the RIGHT number of
  # rows with bearings up to 272 degrees wrong, because it indexes a 5n-row
  # coordinate matrix with a permutation of 1:n. A wrong row count is detectable;
  # a wrong value at the right row count is not.
  for (nm in names(non_point_cases())) {
    expect_error(fly_bearing(non_point_cases()[[nm]]),
                 "`photos_sf` must be points", info = nm)
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
      expect_error(fly_filter(cases[[nm]], aoi, method = method),
                   "`photos_sf` must be points", info = paste(nm, method))
    }
  }
})

test_that("every export that consumes centroids refuses non-point geometry", {
  # The global invariant, rather than more examples of one. These four could have
  # reached the guard through their own fly_footprint() call, but the error would
  # then have named `centroids_sf` — an argument none of them has. Each is
  # asserted against the name the caller actually typed, so a guard that reports
  # the wrong parameter cannot ship green.
  #
  # Handed footprints, three of these four were silently WRONG rather than
  # wrong-sized before the guard: fly_overlap() reported pairs over the corrupted
  # set, and fly_select() in both modes indexed a 20-row frame with a length-100
  # logical. Only fly_coverage() errored, and only by accident of how it assigns.
  sf::sf_use_s2(FALSE)
  on.exit(sf::sf_use_s2(TRUE), add = TRUE)

  poly <- non_point_cases()$POLYGON
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)

  expect_error(fly_coverage(poly, aoi), "`photos_sf` must be points")
  expect_error(fly_overlap(poly), "`photos_sf` must be points")
  expect_error(fly_select(poly, aoi), "`photos_sf` must be points")
  expect_error(fly_select(poly, aoi, mode = "all"), "`photos_sf` must be points")
  expect_error(fly_footprint(poly), "`centroids_sf` must be points")
})

test_that("fly_georef refuses non-point geometry without creating its output dir", {
  # The guard sits above dir.create() in fly_georef(), so a rejected input leaves
  # nothing behind. Asserting the directory's absence is what pins that ordering:
  # moved below dir.create(), the refusal still happens and only this fails.
  poly <- non_point_cases()$POLYGON
  dest <- file.path(tempdir(), "fly37_georef_out")
  unlink(dest, recursive = TRUE)
  on.exit(unlink(dest, recursive = TRUE), add = TRUE)
  expect_false(dir.exists(dest))

  fake_fetch <- dplyr::tibble(
    airp_id = poly$airp_id[1], dest = NA_character_, success = FALSE
  )

  expect_error(fly_georef(fake_fetch, poly, dest_dir = dest),
               "`photos_sf` must be points")
  expect_false(dir.exists(dest))
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


test_that("a mixed-geometry column is refused even when every feature is a point", {
  # st_coordinates() has no sfc_GEOMETRY method. Without this the guard passes on
  # the per-feature types — all POINT — and the caller sees
  # `Not compatible with STRSXP: [type=NULL]` several layers down, naming neither
  # the argument nor the package. Measured, not predicted.
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  gg <- sf::st_cast(centroids, "GEOMETRY")

  # Premises: the column really is GEOMETRY, and every feature in it really is a
  # POINT — so this is the case the per-feature test alone would wave through.
  expect_true(inherits(sf::st_geometry(gg), "sfc_GEOMETRY"))
  expect_true(all(as.character(sf::st_geometry_type(gg)) == "POINT"))
  expect_error(sf::st_coordinates(gg), "sfc_GEOMETRY")

  expect_error(fly_footprint(gg), "`centroids_sf` stores its points in a mixed-geometry")
  expect_error(fly_bearing(gg), "`photos_sf` stores its points in a mixed-geometry")
})

test_that("a zero-row sf with a GEOMETRY column is still accepted", {
  # `st_sf(geometry = st_sfc())` carries an sfc_GEOMETRY column, so the clause
  # above has to be nrow-aware or an empty query — a documented input — starts
  # erroring. This is the premise that makes the `nrow(x) > 0` guard load-bearing
  # rather than defensive noise.
  z <- sf::st_sf(scale = character(0), geometry = sf::st_sfc(crs = 4326))
  expect_true(inherits(sf::st_geometry(z), "sfc_GEOMETRY"))
  expect_equal(nrow(z), 0L)
  expect_no_error(fp <- fly_footprint(z))
  expect_equal(nrow(fp), 0L)
})

test_that("a GEOMETRY column holding polygons is refused as polygons, not as GEOMETRY", {
  # Ordering test, and the only thing that distinguishes the two arrangements of
  # fly_check_points()'s two clauses.
  #
  # With the GEOMETRY clause checked FIRST, this input was told to
  # `st_cast(x, "POINT")` — which takes a polygon's FIRST VERTEX, not its
  # centroid. Measured on this exact fixture: 20 rows in, 20 rows out, the guard
  # then ACCEPTED the result, and ten frames had moved 1,940 m. Following the
  # guard's own advice reintroduced the silent corruption #37 is about.
  #
  # So the per-feature type test must run first, and this asserts the message the
  # caller gets names POLYGON — whose advice leads with `st_filter()`.
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  c3005 <- sf::st_transform(centroids, 3005)
  fp <- sf::st_transform(fly_footprint(centroids), 3005)

  mixed <- c3005
  sf::st_geometry(mixed) <- c(sf::st_geometry(fp)[1:10],
                              sf::st_geometry(c3005)[11:20])

  # Premises: the column really is GEOMETRY, and it really does hold both types —
  # so it is reachable by BOTH clauses and the order decides which one answers.
  expect_true(inherits(sf::st_geometry(mixed), "sfc_GEOMETRY"))
  expect_setequal(as.character(sf::st_geometry_type(mixed)), c("POINT", "POLYGON"))

  expect_error(fly_footprint(mixed), "must be points, not POLYGON")

  # And the remedy the other message would have offered really is destructive,
  # so this is pinned as a fact rather than left as an assertion about wording.
  recast <- suppressWarnings(sf::st_cast(mixed, "POINT"))
  moved <- as.numeric(sf::st_distance(sf::st_geometry(recast),
                                      sf::st_geometry(c3005), by_element = TRUE))
  expect_equal(nrow(recast), nrow(mixed))
  expect_gt(max(moved), 1000)
})
