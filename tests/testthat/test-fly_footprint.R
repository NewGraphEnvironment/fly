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
  # The bundled DEM is buffered past the corner of the widest footprint, so
  # every frame is essentially fully described — the shortfall below is real
  # missing cells left by reprojection, not a counting artifact, and is four
  # hundredths of a percent at worst. This asserts the guard stays quiet on
  # good data; the AOI-clipped test below is what proves it can fire at all.
  expect_gt(min(terr$dem_coverage), 0.99)
  expect_silent(fly_footprint(centroids, dem = testdata_path("dem.tif")))

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

test_that("fly_footprint iterates the sampling window, not just the elevation", {
  skip_if_no_terra()
  # The window the DEM is averaged over is itself what the correction changes,
  # so the second pass measures over the corrected rectangle. Collapsing it to
  # one pass left the whole suite green, which made the iteration untested
  # rather than merely small. It IS small — under 0.5% of area against the
  # correction's own 14% — so assert it on elevation, where it is legible.
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  dem <- terra::rast(testdata_path("dem.tif"))
  fp <- fly_footprint(centroids, dem = dem)

  # Reproduce pass one alone: the mean under the NOMINAL rectangle.
  nominal_half <- 9 * as.numeric(sub("1:", "", centroids$scale)) * 0.0254 / 2
  pts <- sf::st_transform(centroids, 3005)
  one_pass <- vapply(seq_len(nrow(centroids)), function(i) {
    rect <- sf::st_buffer(pts[i, ], nominal_half[i], endCapStyle = "SQUARE")
    mean(terra::extract(dem, terra::vect(rect))[, 2], na.rm = TRUE)
  }, numeric(1))

  two_pass_elev <- centroids$flying_height - fp$height_agl
  expect_false(isTRUE(all.equal(two_pass_elev, one_pass)))
  expect_gt(max(abs(two_pass_elev - one_pass)), 5)
})

test_that("fly_footprint rejects a DEM with no CRS", {
  skip_if_no_terra()
  # Without this the failure surfaces from inside sf as "invalid crs:", naming
  # neither the argument nor the package.
  dem <- terra::rast(testdata_path("dem.tif"))
  terra::crs(dem) <- ""
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)[1, ]
  expect_error(fly_footprint(centroids, dem = dem), "no CRS")
})

test_that("fly_footprint reports full coverage on a DEM that is entirely valid", {
  skip_if_no_terra()
  # The measurement has to be right on its own terms before missing data enters
  # the picture. A DEM with no NA cell anywhere and room well beyond every
  # footprint must report coverage of exactly 1 and warn about nothing.
  #
  # Counting the footprint's area in cell units against a count of cell centres
  # compares two different measurements, and fails here rather than on anything
  # to do with coverage: it reported 91% on the coarse grid below and warned
  # that 3 of 3 frames were under-covered, on a raster with nothing missing.
  #
  # Two resolutions because the error scales as 2/k for a footprint k cells
  # wide — a fine grid hides it, which is why the shipped 30 m fixture could
  # not reach this.
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)[1:3, ]
  bb <- sf::st_bbox(sf::st_transform(centroids, 3005))

  for (cell in c(30, 900)) {
    r <- terra::rast(
      xmin = bb[["xmin"]] - 30000, xmax = bb[["xmax"]] + 30000,
      ymin = bb[["ymin"]] - 30000, ymax = bb[["ymax"]] + 30000,
      resolution = cell, crs = "EPSG:3005"
    )
    terra::values(r) <- 700
    expect_equal(as.numeric(terra::global(r, function(x) sum(is.na(x)))[1, 1]), 0)

    fp <- fly_footprint(centroids, dem = r)
    expect_equal(fp$dem_coverage, rep(1, 3), info = paste("cell size", cell))
    expect_silent(fly_footprint(centroids, dem = r))
  }
})

test_that("fly_footprint handles anisotropic DEM cells", {
  skip_if_no_terra()
  # Non-square cells are ordinary in a geographic CRS away from the equator.
  # The coverage denominator must account for both dimensions, not assume a
  # square cell.
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)[1:2, ]
  bb <- sf::st_bbox(sf::st_transform(centroids, 3005))
  r <- terra::rast(
    xmin = bb[["xmin"]] - 20000, xmax = bb[["xmax"]] + 20000,
    ymin = bb[["ymin"]] - 20000, ymax = bb[["ymax"]] + 20000,
    resolution = c(120, 904), crs = "EPSG:3005"
  )
  terra::values(r) <- 700
  fp <- fly_footprint(centroids, dem = r)
  expect_equal(fp$dem_coverage, rep(1, 2))
})

test_that("fly_footprint does not size its coverage grid to the span of the photo set", {
  skip_if_no_terra()
  # Counting the coverage denominator on one grid spanning every frame sizes it
  # to the GAP between frames, not to the frames. Two photos 700 km apart made
  # that 243 million cells where the same two counted separately need 16
  # thousand — a 4 GB allocation for a correct answer.
  #
  # Asserted on the grid itself, not on elapsed time. The first version of this
  # test used `expect_lt(elapsed, 10)`, and the defect runs in 1.0 s against the
  # fix's 0.18 s — so it passed with a tenfold margin on the very thing it was
  # written to catch, and no threshold separates them without being CI jitter.
  # Every other assertion in it passed too, because the union grid produces the
  # *right* number; it just allocates absurdly to get there.
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)[1:2, ]
  sf::st_geometry(centroids)[2] <- sf::st_sfc(sf::st_point(c(-120, 50)), crs = 4326)
  dem <- terra::rast(testdata_path("dem.tif"))

  # The fixture must be able to expose the defect: the grid spanning both
  # frames is enormous, so a union-sized allocation would stand out at once.
  # Measured before the mock is installed, or this call records itself.
  flat <- fly_footprint(centroids)
  union_cells <- prod(dim(fly_dem_grid(
    dem, sf::st_transform(flat, sf::st_crs(terra::crs(dem)))
  ))[1:2])
  expect_gt(union_cells, 1e8)

  # Record every grid the real call asks for.
  sizes <- c()
  real_grid <- fly_dem_grid
  testthat::local_mocked_bindings(
    fly_dem_grid = function(dem, geom) {
      g <- real_grid(dem, geom)
      sizes <<- c(sizes, prod(dim(g)[1:2]))
      g
    }
  )
  fp <- suppressWarnings(fly_footprint(centroids, dem = dem))

  # No grid built during the call may approach it. Each is one footprint.
  expect_gt(length(sizes), 0)
  expect_lt(max(sizes), 1e6)
  expect_lt(max(sizes), union_cells / 100)

  expect_equal(fp$footprint_terrain, c("dem_agl", "no_dem_coverage"))
  expect_equal(fp$dem_coverage, c(1, 0))
})

test_that("fly_footprint reports coverage of the footprint it actually returns", {
  skip_if_no_terra()
  # Terrain above the aircraft gives a negative height above ground, so the
  # second pass measures over a square sized from that — much smaller than the
  # nominal footprint the frame falls back to. Reading the second pass's
  # coverage there describes a rectangle the caller never receives: measured
  # 100% for a footprint that was 30% covered, which is precisely the frame the
  # documented `dem_coverage` filter exists to exclude.
  dem <- terra::rast(testdata_path("dem.tif"))
  with_data <- which(!is.na(terra::values(dem)))
  xy <- terra::xyFromCell(dem, with_data)
  west <- which.min(xy[, 1])
  # Far enough inside that the small second-pass square is fully covered, close
  # enough that the nominal footprint is not.
  pt <- sf::st_sfc(sf::st_point(c(xy[west, 1] + 1200, xy[west, 2])), crs = 3005)

  photos <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)[1, ]
  photos$scale <- "1:31680"
  photos$flying_height <- 100          # below the terrain -> unusable
  sf::st_geometry(photos) <- sf::st_transform(pt, 4326)

  fp <- suppressWarnings(fly_footprint(photos, dem = dem))
  expect_equal(fp$footprint_terrain, "nominal_scale")

  # Ground truth measured against the geometry that was returned.
  g <- sf::st_transform(fp, sf::st_crs(terra::crs(dem)))
  vals <- terra::extract(dem, terra::vect(g))[, 2]
  tmpl <- terra::rast(terra::align(terra::ext(terra::vect(g)), dem),
                      resolution = terra::res(dem), crs = terra::crs(dem))
  terra::values(tmpl) <- 1L
  truth <- sum(!is.na(vals)) /
    sum(!is.na(terra::extract(tmpl, terra::vect(g))[, 2]))

  expect_lt(truth, 0.95)               # the fixture must reach the failure mode
  expect_equal(fp$dem_coverage, truth, tolerance = 1e-6)
})


test_that("fly_footprint reports the same columns whatever class the input carries", {
  # #35: `sf::st_sf()` keeps only its first argument when that argument is a
  # tibble, so the four reporting columns were discarded for every caller whose
  # input carried `tbl_df` — which is what `bcdata::collect()` returns, and so
  # what the package's own documented data source hands back. Every fixture in
  # the package is plain `sf, data.frame`, so no case added along the existing
  # axis could have found this. Sweep the axis instead.
  shapes <- centroid_shapes()
  reported <- fly_reported_cols()

  out <- lapply(shapes, fly_footprint)

  for (nm in names(out)) {
    expect_true(all(reported %in% names(out[[nm]])), info = nm)
  }

  # The bundled centroids give a constant basis and all-NA terrain columns, so
  # the value comparison below would hold for any implementation that got the
  # names right. Sweep the mixed-media fixture too, where `footprint_basis`
  # varies across rows and reaches `unknown_format`.
  mixed <- lapply(mixed_media_shapes(), function(x) suppressWarnings(fly_footprint(x)))
  expect_gt(length(unique(mixed$plain$footprint_basis)), 1)   # premise
  for (nm in names(mixed)) {
    expect_true(all(reported %in% names(mixed[[nm]])), info = nm)
    expect_identical(mixed[[nm]]$footprint_basis, mixed$plain$footprint_basis,
                     info = nm)
  }

  # Not merely present: identical, column for column, to what the plain shape
  # gets. A fix that supplied the names and lost the values would pass the
  # check above.
  for (nm in names(out)) {
    expect_identical(names(out[[nm]]), names(out$plain), info = nm)
    for (col in reported) {
      expect_identical(out[[nm]][[col]], out$plain[[col]],
                       info = paste(nm, col))
    }
    expect_identical(sf::st_geometry(out[[nm]]), sf::st_geometry(out$plain),
                     info = nm)
  }
})


test_that("fly_footprint reports the same columns on the dem path too", {
  skip_if_no_terra()
  # All four columns are attached by the one `st_sf()` call, so the terrain path
  # fails the same way — and it is `dem_coverage`, documented as the filter for
  # partially-covered frames, that goes missing there.
  dem <- terra::rast(testdata_path("dem.tif"))
  shapes <- centroid_shapes()
  reported <- fly_reported_cols()

  out <- lapply(shapes, function(x) suppressWarnings(fly_footprint(x, dem = dem)))

  # The fixture must reach the terrain code, or this sweep says nothing about it.
  expect_true(any(out$plain$footprint_terrain == "dem_agl", na.rm = TRUE))
  expect_true(any(!is.na(out$plain$dem_coverage)))

  for (nm in names(out)) {
    expect_true(all(reported %in% names(out[[nm]])), info = nm)
    for (col in reported) {
      expect_identical(out[[nm]][[col]], out$plain[[col]],
                       info = paste(nm, col))
    }
  }
})


test_that("fly_footprint carries every class the input had", {
  # Contract, not the #35 regression guard: the broken code carried the class
  # correctly and dropped the columns. This guards the other direction — a fix
  # that coerced the frame to `data.frame` would hand a bcdata caller back
  # something narrower than they passed in.
  #
  # Set, not sequence. `sf::st_transform()` moves `sf` to the front, so a
  # `bcdc_sf` input comes back `sf, bcdc_sf, ...` — measured, and true of the
  # prior implementation too. An `identical(class(out), class(in))` here would
  # pass on the three shapes the fixture used to have and fail on the one
  # caller the issue was filed about, which is the trap this branch exists to
  # close rather than repeat.
  shapes <- centroid_shapes()
  expect_true("bcdc" %in% names(shapes))          # premise: the shape is present
  for (nm in names(shapes)) {
    out <- fly_footprint(shapes[[nm]])
    expect_true(all(class(shapes[[nm]]) %in% class(out)), info = nm)
    expect_s3_class(out, "sf")
  }
})


test_that("fly_footprint overwrites a colliding reporting column", {
  # Before #35 the trailing-argument form appended `footprint_basis.1` for a
  # data.frame caller and kept the caller's value under the documented name —
  # so `footprints$footprint_basis != "unknown_format"`, the filter the docs
  # prescribe, read the caller's column and fly's real answer sat unread. The
  # computed value must win. Unguarded, a revert to trailing `st_sf()`
  # arguments would reinstate the duplicate with nothing failing.
  shapes <- centroid_shapes()
  for (nm in names(shapes)) {
    x <- shapes[[nm]]
    x$footprint_basis <- "PRE-EXISTING"
    out <- fly_footprint(x)
    expect_equal(sum(grepl("^footprint_basis", names(out))), 1L, info = nm)
    expect_false(any(out$footprint_basis == "PRE-EXISTING"), info = nm)
  }
})


test_that("an empty result binds to a populated one", {
  # `ifelse(logical(0), ...)` returns `logical(0)`, so a query matching no
  # frames reported its basis as a logical column. Assembling a per-AOI ledger
  # across queries — the use the reporting columns exist for — then fails on
  # the type the first time an AOI returns nothing, rather than contributing no
  # rows. Reachable only from the empty input, which no other test supplies.
  shapes <- centroid_shapes()
  for (nm in names(shapes)) {
    empty <- fly_footprint(shapes[[nm]][0, ])
    expect_identical(nrow(empty), 0L, info = nm)
    expect_type(empty$footprint_basis, "character")
    expect_type(empty$footprint_terrain, "character")
    expect_type(empty$height_agl, "double")
    expect_type(empty$dem_coverage, "double")
  }
  full <- fly_footprint(shapes$plain)
  bound <- dplyr::bind_rows(fly_footprint(shapes$plain[0, ]), full)
  expect_identical(nrow(bound), nrow(full))
})


test_that("a tibble-backed footprint still flows through the consumers", {
  # The four columns are new on this path, so check they do not disturb the
  # functions that take a footprint. Numbers come from the plain shape, which
  # the rest of the suite already pins.
  shapes <- centroid_shapes()
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)

  # `by = "scale"` because the fixture is a single photo year — grouping on it
  # gives one group, and a one-row-against-one-row comparison is the weakest
  # available. Premises assert each reference result is non-degenerate, since
  # every comparison below passes when both sides are empty.
  ref_filter <- fly_filter(shapes$plain, aoi)
  ref_cover <- fly_coverage(shapes$plain, aoi, by = "scale")
  ref_overlap <- fly_overlap(shapes$plain)
  ref_select <- suppressMessages(fly_select(shapes$plain, aoi))
  expect_gt(nrow(ref_filter), 0)
  expect_gt(nrow(ref_cover), 1)
  expect_gt(nrow(ref_overlap), 0)
  expect_gt(nrow(ref_select), 0)

  for (nm in names(shapes)) {
    x <- shapes[[nm]]
    expect_equal(nrow(fly_filter(x, aoi)), nrow(ref_filter), info = nm)
    expect_equal(fly_coverage(x, aoi, by = "scale")$covered_km2,
                 ref_cover$covered_km2, info = nm)
    expect_equal(nrow(fly_overlap(x)), nrow(ref_overlap), info = nm)
    expect_equal(nrow(suppressMessages(fly_select(x, aoi))), nrow(ref_select),
                 info = nm)
  }
})
