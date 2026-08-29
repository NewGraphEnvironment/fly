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


# --- Terrain-adjusted footprints (#9) ------------------------------------

test_that("fly_footprint with dem = NULL is unchanged", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  flat <- fly_footprint(centroids)
  explicit_null <- fly_footprint(centroids, dem = NULL)

  expect_equal(sf::st_geometry(flat), sf::st_geometry(explicit_null))
  expect_equal(flat$footprint_basis, explicit_null$footprint_basis)
  # The terrain columns exist either way, so a caller's column handling does not
  # change depending on whether a DEM was supplied.
  expect_equal(flat$footprint_terrain, rep("nominal_scale", nrow(centroids)))
  expect_true(all(is.na(flat$height_agl)))
})

test_that("fly_footprint terrain correction enlarges footprints as measured", {
  skip_if_no_terra()
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  flat <- fly_footprint(centroids)
  terr <- fly_footprint(centroids, dem = testdata_path("dem.tif"))

  pct <- 100 * (as.numeric(sf::st_area(sf::st_transform(terr, 3005))) /
                  as.numeric(sf::st_area(sf::st_transform(flat, 3005))) - 1)

  # Every frame grows. Reported scale on this AOI is referenced to an elevation
  # above the real valley floor, so the bias is one-directional — a correction
  # that shrank a footprint here would mean the sampling is wrong.
  expect_true(all(pct > 0))
  expect_gt(stats::median(pct), 10)
  expect_lt(max(pct), 30)

  expect_equal(terr$footprint_terrain, rep("dem_agl", nrow(centroids)))
  expect_true(all(terr$height_agl > 0))
  # h_agl is flying height above ground, so strictly below flying height ASL.
  expect_true(all(terr$height_agl < centroids$flying_height))
})

test_that("fly_footprint samples the footprint mean, not just the centroid", {
  skip_if_no_terra()
  # The two-pass iteration is load-bearing, not cosmetic: centroid and
  # footprint-mean elevation differ by up to 130 m on the wide 1:31680 frames.
  # If this ever collapses to centroid-only sampling, the areas move.
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  dem <- terra::rast(testdata_path("dem.tif"))
  terr <- fly_footprint(centroids, dem = dem)

  pts <- terra::extract(dem, terra::vect(sf::st_transform(centroids, 3005)))[, 2]
  centroid_only_agl <- centroids$flying_height - pts

  expect_false(isTRUE(all.equal(terr$height_agl, centroid_only_agl)))
  expect_gt(max(abs(terr$height_agl - centroid_only_agl)), 20)
})

test_that("fly_footprint accepts a dem as path or SpatRaster", {
  skip_if_no_terra()
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  by_path <- fly_footprint(centroids, dem = testdata_path("dem.tif"))
  by_rast <- fly_footprint(centroids, dem = terra::rast(testdata_path("dem.tif")))
  expect_equal(sf::st_geometry(by_path), sf::st_geometry(by_rast))
})

test_that("fly_footprint leaves unsized frames empty rather than sampling them", {
  skip_if_no_terra()
  photos <- terrain_fixture()
  fp <- suppressWarnings(fly_footprint(photos, dem = testdata_path("dem.tif")))

  unknown <- fp[fp$footprint_basis == "unknown_format", ]
  expect_equal(nrow(unknown), 1)
  expect_true(sf::st_is_empty(sf::st_geometry(unknown)))
  # No footprint means no terrain treatment to report — not a claim that one
  # was applied, and not a number a caller could mistake for a real height.
  expect_true(is.na(unknown$footprint_terrain))
  expect_true(is.na(unknown$height_agl))

  film <- fp[fp$footprint_basis == "Film - BW", ]
  expect_equal(film$footprint_terrain, rep("dem_agl", 2))
})

test_that("fly_footprint errors when a dem is given without the fields it needs", {
  skip_if_no_terra()
  photos <- terrain_fixture()

  no_height <- photos
  no_height$flying_height <- NULL
  expect_error(fly_footprint(no_height, dem = testdata_path("dem.tif")),
               "flying_height")

  no_focal <- photos
  no_focal$focal_length <- NULL
  expect_error(fly_footprint(no_focal, dem = testdata_path("dem.tif")),
               "focal_length")
})

test_that("fly_footprint falls back to nominal scale outside DEM coverage", {
  skip_if_no_terra()
  photos <- terrain_fixture()
  # Move one frame far outside the bundled DEM's extent. Falling back with a
  # warning is the chosen failure direction: a frame we cannot correct is still
  # a frame, and dropping it would be indistinguishable from an unsized one.
  far <- photos[1:2, ]
  sf::st_geometry(far)[2] <- sf::st_sfc(sf::st_point(c(-120.0, 50.0)), crs = 4326)

  w <- character()
  fp <- withCallingHandlers(
    fly_footprint(far, dem = testdata_path("dem.tif")),
    warning = function(x) {
      w <<- c(w, conditionMessage(x))
      invokeRestart("muffleWarning")
    }
  )
  expect_gt(length(w), 0)
  expect_match(w, "coverage", all = FALSE)

  expect_equal(fp$footprint_terrain, c("dem_agl", "no_dem_coverage"))
  expect_true(is.na(fp$height_agl[2]))
  expect_false(sf::st_is_empty(sf::st_geometry(fp)[2]))

  # The fallback frame is sized exactly as the flat path would size it.
  flat <- fly_footprint(far)
  expect_equal(
    as.numeric(sf::st_area(sf::st_transform(fp[2, ], 3005))),
    as.numeric(sf::st_area(sf::st_transform(flat[2, ], 3005)))
  )
})

test_that("fly_footprint falls back when terrain sits above the aircraft", {
  skip_if_no_terra()
  photos <- terrain_fixture()[1:2, ]
  # Terrain here is ~600 m. A flying height below that is bad data — most
  # likely feet recorded as metres — and yields a non-positive height above
  # ground, which would otherwise produce a zero or inverted footprint.
  photos$flying_height <- c(2591, 100)

  w <- character()
  fp <- withCallingHandlers(
    fly_footprint(photos, dem = testdata_path("dem.tif")),
    warning = function(x) {
      w <<- c(w, conditionMessage(x))
      invokeRestart("muffleWarning")
    }
  )
  expect_gt(length(w), 0)
  expect_match(w, "above", all = FALSE)

  expect_equal(fp$footprint_terrain, c("dem_agl", "nominal_scale"))
  expect_false(sf::st_is_empty(sf::st_geometry(fp)[2]))
})

test_that("fly_footprint falls back on unusable height or focal metadata", {
  skip_if_no_terra()
  # An NA focal length or flying height makes the corrected half-side
  # non-finite. Left unchecked that becomes an empty geometry, which is
  # indistinguishable from an unresolved recording format — so the frame would
  # disappear under a warning pointing at `format_size` rather than at its own
  # metadata. Every such frame must keep its nominal-scale footprint.
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)[1:3, ]
  centroids$focal_length[2] <- NA
  centroids$flying_height[3] <- NA

  w <- character()
  fp <- withCallingHandlers(
    fly_footprint(centroids, dem = testdata_path("dem.tif")),
    warning = function(x) {
      w <<- c(w, conditionMessage(x))
      invokeRestart("muffleWarning")
    }
  )
  expect_gt(length(w), 0)
  expect_match(w, "focal_length", all = FALSE)

  expect_equal(sum(sf::st_is_empty(sf::st_geometry(fp))), 0)
  expect_equal(fp$footprint_terrain, c("dem_agl", "nominal_scale", "nominal_scale"))
  expect_true(all(is.na(fp$height_agl[2:3])))

  flat <- fly_footprint(centroids)
  expect_equal(
    as.numeric(sf::st_area(sf::st_transform(fp[2:3, ], 3005))),
    as.numeric(sf::st_area(sf::st_transform(flat[2:3, ], 3005)))
  )
})

test_that("fly_footprint falls back on a zero focal length", {
  skip_if_no_terra()
  # Zero divides rather than propagating NA, so it reaches the half-side as Inf
  # and needs the same finite check.
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)[1:2, ]
  centroids$focal_length[2] <- 0
  fp <- suppressWarnings(fly_footprint(centroids, dem = testdata_path("dem.tif")))
  expect_equal(sum(sf::st_is_empty(sf::st_geometry(fp))), 0)
  expect_equal(fp$footprint_terrain, c("dem_agl", "nominal_scale"))
})

test_that("fly_footprint reports how much of each footprint the DEM covered", {
  skip_if_no_terra()
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  terr <- fly_footprint(centroids, dem = testdata_path("dem.tif"))

  expect_true(all(terr$dem_coverage > 0 & terr$dem_coverage <= 1))
  # The bundled DEM is buffered past the widest footprint, so nothing here is
  # materially short — but reprojection leaves NA slivers, so it is not all 1
  # either. Both halves matter: a guard that saw only 1s could not fire, and
  # one that warned on anything below 1 would fire on data that is fine.
  expect_lt(min(terr$dem_coverage), 1)
  expect_gt(min(terr$dem_coverage), 0.95)

  flat <- fly_footprint(centroids)
  expect_true(all(is.na(flat$dem_coverage)))
})

test_that("fly_footprint warns when a footprint is materially off the DEM", {
  skip_if_no_terra()
  dem <- terra::rast(testdata_path("dem.tif"))

  # Put a wide frame on the westernmost cell that still carries data: the
  # centroid samples fine, so this is NOT the no_dem_coverage path — half the
  # footprint simply hangs over ground the DEM does not describe, and the mean
  # comes from the covered half alone.
  with_data <- which(!is.na(terra::values(dem)))
  xy <- terra::xyFromCell(dem, with_data)
  edge <- sf::st_sfc(sf::st_point(xy[which.min(xy[, 1]), ]), crs = 3005)

  photos <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)[1, ]
  photos$scale <- "1:31680"
  sf::st_geometry(photos) <- sf::st_transform(edge, 4326)

  w <- character()
  fp <- withCallingHandlers(
    fly_footprint(photos, dem = dem),
    warning = function(x) {
      w <<- c(w, conditionMessage(x))
      invokeRestart("muffleWarning")
    }
  )
  expect_gt(length(w), 0)
  expect_match(w, "covered by the DEM", all = FALSE)

  # Still corrected — the partial mean is the best estimate available, and
  # discarding a frame over it would lose more than it protects.
  expect_equal(fp$footprint_terrain, "dem_agl")
  expect_false(sf::st_is_empty(sf::st_geometry(fp)))
  expect_lt(fp$dem_coverage, 0.95)
})

test_that("fly_footprint reports no terrain treatment for an unparseable scale", {
  skip_if_no_terra()
  # A resolvable `media` with a `scale` that will not parse still leaves a frame
  # with no footprint. Keying the terrain column off the recording format alone
  # labelled it "nominal_scale", claiming a treatment for a frame that has no
  # geometry to treat.
  photos <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)[1:2, ]
  photos$scale[2] <- "not-a-scale"
  fp <- suppressWarnings(fly_footprint(photos))

  expect_true(sf::st_is_empty(sf::st_geometry(fp)[2]))
  expect_true(is.na(fp$footprint_terrain[2]))
  expect_false(is.na(fp$footprint_terrain[1]))
})

test_that("fly_footprint tolerates a centroid on a DEM hole", {
  skip_if_no_terra()
  # The mean is taken over the whole footprint, so a single missing cell beneath
  # the centroid says nothing about whether the frame can be corrected. Punch a
  # hole at one centroid and the frame must still come back corrected.
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)[1, ]
  dem <- terra::rast(testdata_path("dem.tif"))
  cell <- terra::cellFromXY(dem, sf::st_coordinates(sf::st_transform(centroids, 3005)))
  dem[cell] <- NA
  expect_true(is.na(terra::extract(dem,
    terra::vect(sf::st_transform(centroids, 3005)))[, 2]))

  fp <- fly_footprint(centroids, dem = dem)
  expect_equal(fp$footprint_terrain, "dem_agl")
  expect_gt(fp$height_agl, 0)
})

test_that("fly_footprint detects a footprint running past the DEM's extent", {
  skip_if_no_terra()
  # The two ways a footprint can be short are NOT equivalent, and only one of
  # them leaves NA cells to count. Ground beyond the raster's *extent* yields no
  # row from terra::extract() at all, so measuring coverage as the non-NA share
  # of returned cells calls a truncated footprint fully covered — an affirmative
  # claim, and worse than saying nothing.
  #
  # A DEM cropped to an AOI is exactly this shape: no NA interior, it just
  # stops. That is the ordinary way a user obtains one, via fl_dem_aoi() or
  # `bcdata get-dem`, so this is the common case rather than the exotic one.
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  full <- terra::rast(testdata_path("dem.tif"))
  tight <- terra::crop(
    full,
    terra::vect(sf::st_union(sf::st_buffer(sf::st_transform(centroids, 3005), 500))),
    snap = "out"
  )
  # The fixture must actually reach the failure mode, which is ground BEYOND
  # the raster's extent — not NA cells within it. Assert that directly: some
  # footprint must extend past the DEM's extent, or this test is checking the
  # sliver case the previous test already covers and nothing new.
  #
  # (The earlier version of this premise compared `tight` against
  # `terra::crop(full, tight)`, which is `tight` by construction. Both sides
  # were equal for every possible fixture, so it could not fail.)
  fp_flat <- fly_footprint(centroids)
  fp_bbox <- sf::st_bbox(sf::st_transform(fp_flat, 3005))
  dem_ext <- terra::ext(tight)
  expect_true(
    fp_bbox[["xmin"]] < dem_ext[1] || fp_bbox[["xmax"]] > dem_ext[2] ||
      fp_bbox[["ymin"]] < dem_ext[3] || fp_bbox[["ymax"]] > dem_ext[4]
  )

  w <- character()
  fp <- withCallingHandlers(
    fly_footprint(centroids, dem = tight),
    warning = function(x) {
      w <<- c(w, conditionMessage(x))
      invokeRestart("muffleWarning")
    }
  )
  expect_gt(length(w), 0)
  expect_match(w, "covered by the DEM", all = FALSE)
  expect_lt(min(fp$dem_coverage), 0.95)

  # And the well-buffered DEM must NOT warn, or the guard is just noise.
  expect_silent(fly_footprint(centroids, dem = full))
})

test_that("fly_footprint reports zero coverage, not NA, for a frame off the DEM", {
  skip_if_no_terra()
  # NA would mean "not measured". Zero is what was measured, and it is what the
  # documented `dem_coverage` filter needs in order to exclude the frame.
  photos <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)[1, ]
  sf::st_geometry(photos) <- sf::st_sfc(sf::st_point(c(-120, 50)), crs = 4326)
  fp <- suppressWarnings(fly_footprint(photos, dem = testdata_path("dem.tif")))

  expect_equal(fp$footprint_terrain, "no_dem_coverage")
  expect_equal(fp$dem_coverage, 0)
})

test_that("fly_footprint measures coverage correctly on a geographic DEM", {
  skip_if_no_terra()
  # Every other DEM in this suite is EPSG:3005 or a crop of it, so the
  # reprojection branch in fly_dem_sample() is never executed by them and a
  # units error there is invisible. Coverage compares a footprint's area
  # against the DEM's cell size, and both have to be in the DEM's own units:
  # st_area() on a geographic CRS returns geodesic m2 while terra::res()
  # returns degrees, which reported ~1e-10 coverage for fully-covered frames
  # and warned on all of them.
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  geo <- terra::project(terra::rast(testdata_path("dem.tif")), "EPSG:4326")
  expect_true(sf::st_is_longlat(sf::st_crs(terra::crs(geo))))

  fp <- fly_footprint(centroids, dem = geo)
  expect_true(all(fp$dem_coverage > 0.95))
  expect_true(all(fp$dem_coverage <= 1))
  expect_equal(fp$footprint_terrain, rep("dem_agl", nrow(centroids)))

  # And it must agree with the projected DEM it was made from, since the two
  # describe the same ground.
  proj <- fly_footprint(centroids, dem = testdata_path("dem.tif"))
  expect_equal(fp$height_agl, proj$height_agl, tolerance = 0.01)
})
