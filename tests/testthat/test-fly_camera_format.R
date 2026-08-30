# Sizing digital frames from the camera format table (#32).

test_that("digital frames resolve from their calibration url", {
  fp <- suppressWarnings(fly_footprint(digital_fixture()))

  # Rows 1-4 carry a calibration; row 5 falls back to focal length; row 6 has a
  # calibration but no ground sample distance.
  expect_equal(fp$width_source[1:2], rep("121201_2011", 2))
  expect_equal(fp$width_source[3:4], rep("20814295_2018", 2))
  expect_equal(fp$footprint_basis[1:4], rep("Digital - Colour", 4))
  expect_equal(fp$footprint_basis[5], "inferred_format")
  expect_match(fp$width_source[5], "^focal_length=100")
})


test_that("a digital footprint is the pixel count times the ground sample distance", {
  # The measurement this whole issue rests on. GROUND_SAMPLE_DISTANCE is centimetres, so
  # a Leica DMC II at GSD 20 covers 15552 px x 0.20 m = 3110.4 m across-track and
  # 14144 px x 0.20 m = 2828.8 m along-track.
  fp <- suppressWarnings(fly_footprint(digital_fixture()))
  g <- sf::st_transform(fp[1, ], 3005)

  expect_equal(as.numeric(sf::st_area(g)), 15552 * 0.20 * 14144 * 0.20, tolerance = 1e-6)
  # Sized from the sensor, not from `scale`: the scale route would give
  # 87.0912 mm x 20000 = 1742 m, and the area would be off by a factor of 3.2.
  expect_gt(as.numeric(sf::st_area(g)), 5 * (87.0912e-3 * 20000)^2 / 5)
})


test_that("scale is never used to size a frame fly resolved itself", {
  # Two frames identical but for `scale`. If `scale` reached the digital route at all,
  # their footprints would differ.
  a <- digital_fixture()
  b <- a
  b$scale <- "1:99999"
  fa <- suppressWarnings(fly_footprint(a))
  fb <- suppressWarnings(fly_footprint(b))

  area <- function(x) as.numeric(sf::st_area(sf::st_transform(x[1:5, ], 3005)))
  expect_equal(area(fa), area(fb))
})


test_that("a resolved digital frame keeps its footprint when a dem is supplied", {
  # The precedence rule. Every downstream consumer forwards `dem`, so if the DEM route
  # overwrote a frame already sized from its ground sample distance, passing `dem`
  # would silently change the answer on the ordinary path rather than in an edge case.
  skip_if_no_terra()
  photos <- digital_fixture()
  no_dem <- suppressWarnings(fly_footprint(photos))
  with_dem <- suppressWarnings(fly_footprint(photos, dem = testdata_path("dem.tif")))

  sized <- !sf::st_is_empty(sf::st_geometry(no_dem))
  expect_gt(sum(sized), 0)
  expect_equal(
    as.numeric(sf::st_area(sf::st_transform(with_dem[sized, ], 3005))),
    as.numeric(sf::st_area(sf::st_transform(no_dem[sized, ], 3005)))
  )
})


test_that("a gsd-sized frame does not claim a terrain treatment it did not get", {
  # `nominal_scale` is documented as "sized from the reported scale", which is the one
  # thing this route deliberately never does. Claiming it would be a false affirmative
  # about the frame's provenance.
  fp <- suppressWarnings(fly_footprint(digital_fixture()))
  expect_equal(fp$footprint_terrain[1:4], rep("gsd_scaled", 4))

  # And with a DEM supplied, the sampled coverage describes a window that had no
  # bearing on the returned geometry, so it is not reported for those frames.
  skip_if_no_terra()
  with_dem <- suppressWarnings(
    fly_footprint(digital_fixture(), dem = testdata_path("dem.tif"))
  )
  expect_equal(with_dem$footprint_terrain[1:4], rep("gsd_scaled", 4))
  expect_true(all(is.na(with_dem$dem_coverage[1:4])))
  expect_true(all(is.na(with_dem$height_agl[1:4])))
})


test_that("a zero ground sample distance yields an empty geometry, not a degenerate one", {
  # `is.finite(0)` is TRUE, so without an explicit guard a zero builds a rectangle with
  # five identical vertices: `st_is_empty()` reports FALSE, `fly_warn_unsized()` never
  # mentions it, and it covers nothing downstream while looking like a real footprint.
  # Reachable — GSD is 0 on every frame of the dmc100039 rolls.
  photos <- digital_fixture()
  expect_equal(photos$ground_sample_distance[6], 0)

  # And it is reported: a frame whose format resolved but which could not be sized is
  # otherwise silent — `footprint_basis` names a real format and `width_source` names a
  # calibration, so nothing about the row says the geometry is empty.
  expect_warning(fp <- fly_footprint(photos), "no way to size it")
  expect_true(sf::st_is_empty(sf::st_geometry(fp)[6]))
})


test_that("film is sized and shaped exactly as before", {
  # The regression net. Explicit assertions rather than a snapshot, which skips on CRAN
  # and therefore in CI — the run where it would matter.
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  fp <- fly_footprint(centroids)

  expect_true(all(fp$footprint_basis == "Film - BW"))
  expect_true(all(is.na(fp$width_source)))

  side <- 9 * as.numeric(sub("1:", "", centroids$scale)) * 0.0254
  expect_equal(as.numeric(sf::st_area(sf::st_transform(fp, 3005))), side^2,
               tolerance = 1e-6)

  # Square, so unrotated: every footprint's bounding box is as wide as it is tall.
  bb <- vapply(sf::st_geometry(sf::st_transform(fp, 3005)), function(g) {
    b <- sf::st_bbox(g)
    unname((b["xmax"] - b["xmin"]) / (b["ymax"] - b["ymin"]))
  }, numeric(1))
  expect_equal(bb, rep(1, nrow(fp)), tolerance = 1e-8)
})


test_that("a non-square footprint puts its long axis ACROSS the flight line", {
  # The assertion that actually discriminates. Area is invariant under every rotation
  # and a 90-degree bbox swap only tests the mechanism, so both a transposed long axis
  # and a sign-flipped azimuth would pass those. This measures the angle itself.
  #
  # Frames 1-4 of the fixture run west to east, so bearing is ~90 degrees and the long
  # (cross-track) axis must point NORTH-SOUTH.
  photos <- digital_fixture()
  fp <- sf::st_transform(suppressWarnings(fly_footprint(photos)), 3005)
  bearing <- fly_bearing(photos)$bearing
  expect_equal(bearing[1], 90, tolerance = 1)

  ring <- sf::st_coordinates(sf::st_geometry(fp)[[1]])[1:4, 1:2]
  # Edge 1->2 is the cross-track edge; edge 2->3 the along-track one.
  edge <- function(a, b) sqrt(sum((ring[b, ] - ring[a, ])^2))
  cross_len <- edge(1, 2)
  along_len <- edge(2, 3)
  expect_gt(cross_len, along_len)          # DMC II is 87.1 x 79.2 mm

  # The along-track edge must point ALONG the heading, and the modulus here is
  # load-bearing: taken mod 180 this assertion passes under a sign-flipped rotation
  # (269.5 becomes 89.5), which is the single error it exists to catch. Verified by
  # restoring that defect and watching this go red — mod 180 it stayed green.
  v <- ring[3, ] - ring[2, ]
  az <- unname((atan2(v[1], v[2]) * 180 / pi) %% 360)
  expect_equal(az, 90, tolerance = 1)
})


test_that("rotation is skipped, and recorded, when no bearing can be computed", {
  photos <- digital_fixture()
  photos$film_roll <- NULL
  photos$frame_number <- NULL
  fp <- suppressWarnings(fly_footprint(photos))

  expect_match(fp$width_source[1], "axis_aligned_no_bearing")
  bb <- sf::st_bbox(sf::st_geometry(sf::st_transform(fp, 3005))[[1]])
  # Axis-aligned: the bounding box is the sensor's own shape, 15552 x 14144 px at 0.20 m
  expect_equal(unname(bb["xmax"] - bb["xmin"]), 15552 * 0.20, tolerance = 1e-6)
  expect_equal(unname(bb["ymax"] - bb["ymin"]), 14144 * 0.20, tolerance = 1e-6)
})


test_that("the unknown-format contract still holds for a format nothing resolves", {
  # Premise first, so a future table that starts shipping focal 53 fails here naming the
  # real cause rather than failing on the behaviour under test.
  photos <- mixed_media_fixture()
  expect_equal(unique(photos$focal_length[photos$media == "Digital - Colour"]), 53)

  tbl <- fly_camera_table()
  expect_false("53" %in% tbl$key[tbl$key_type == "focal_length"])
  ex <- fly_camera_excluded()
  expect_true(any(grepl("12335326", ex$key)))   # the focal-53 camera, unresolvable

  fp <- suppressWarnings(fly_footprint(photos))
  expect_equal(fp$footprint_basis[3:4], rep("unknown_format", 2))
  expect_true(all(sf::st_is_empty(sf::st_geometry(fp)[3:4])))
})


test_that("width_source survives every class shape a caller can supply", {
  # #35 shipped through two releases because `st_sf()` silently drops trailing columns
  # when its first argument is a tibble, which is what `bcdata::collect()` returns.
  # The sweep is only worth running on a fixture where the new column actually varies.
  mm <- digital_fixture()
  shapes <- list(plain = mm, tbl = sf::st_as_sf(dplyr::as_tibble(mm)))
  stopifnot(!inherits(shapes$plain, "tbl_df"), inherits(shapes$tbl, "tbl_df"))

  out <- lapply(shapes, function(x) suppressWarnings(fly_footprint(x)))
  for (nm in names(out)) {
    expect_true("width_source" %in% names(out[[nm]]), info = nm)
    expect_equal(out[[nm]]$width_source, out$plain$width_source, info = nm)
  }
})


test_that("reporting columns keep their types on empty input", {
  # `ifelse(logical(0), ...)` returns `logical(0)`, so a query that matched no frames
  # would report a character column as logical and fail to bind to a populated result.
  fp <- fly_footprint(digital_fixture()[0, ])

  expect_equal(nrow(fp), 0L)
  expect_type(fp$width_source, "character")
  expect_type(fp$footprint_basis, "character")
  expect_type(fp$footprint_terrain, "character")
})


test_that("check G: the two independent sizing routes agree on real frames", {
  # The issue's own acceptance criterion. `px x GSD` and `width x AGL/focal` share no
  # arithmetic — the first uses the pixel count and the catalogue's ground sample
  # distance, the second the millimetre width, `flying_height` and a DEM — so a
  # mis-keyed camera breaks the agreement.
  #
  # What this can and cannot catch, measured rather than assumed. GROUND_SAMPLE_DISTANCE
  # is stored as INTEGER centimetres, so at GSD 12 one unit is 8% and the quantization
  # alone bounds the agreement at about +/-4%; at GSD 30 it is 1.7%. Measured on the
  # bundled frames: DMC II (GSD 30) agrees to 1.4%, UltraCam Eagle M3 (GSD 12) to 7.5%.
  # So this guards against a camera keyed to the wrong row — the widths in the table run
  # from 87.1 to 165.9 mm, up to 90% apart — and NOT against a small width error.
  # Check B is what guards precision.
  skip_if_no_terra()
  p <- sf::st_read(testdata_path("photo_centroids_digital.gpkg"), quiet = TRUE)
  fmt <- fly_camera_format(p)
  expect_true(all(fmt$resolved))                       # premise

  route_gsd <- fmt$px_cross * fly_gsd_m(p$ground_sample_distance)

  # Mean elevation under the footprint actually returned, not a centroid reading — the
  # two differ by up to 140 m on a frame this wide.
  fp <- fly_footprint(p)
  dem <- terra::rast(testdata_path("dem.tif"))
  samp <- fly_dem_sample(dem, sf::st_geometry(sf::st_transform(fp, 3005)))
  route_dem <- (fmt$width_mm / 1000) *
    (p$flying_height - samp$elev) / (p$focal_length / 1000)

  ok <- !is.na(route_dem) & samp$covered > 0.95
  expect_gt(sum(ok), 15)                               # premise: enough covered frames

  ratio <- route_dem[ok] / route_gsd[ok]
  expect_lt(max(abs(ratio - 1)), 0.15)

  # The camera whose GSD is least quantized must agree much more closely. Without this
  # the 15% bound above would pass a genuinely mis-sized frame.
  fine <- ok & p$ground_sample_distance >= 25
  expect_gt(sum(fine), 5)
  fine_ratio <- route_dem[fine] / route_gsd[fine]
  expect_lt(abs(median(fine_ratio) - 1), 0.03)
})


test_that("real digital frames get non-square footprints in two distinct shapes", {
  # A fixture carrying one sensor shape cannot tell a correctly-shaped footprint from a
  # square one. These are real catalogue frames from two cameras 0.46 apart in aspect.
  p <- sf::st_read(testdata_path("photo_centroids_digital.gpkg"), quiet = TRUE)
  fmt <- fly_camera_format(p)

  aspect <- round(fmt$width_mm / fmt$height_mm, 2)
  expect_setequal(unique(aspect), c(1.10, 1.56))

  fp <- fly_footprint(p)
  expect_false(any(sf::st_is_empty(sf::st_geometry(fp))))
  expect_true(all(fp$footprint_terrain == "gsd_scaled"))

  # Non-square, which is the property `fly_georef()` keys on — a footprint rotated onto
  # a flight line running due east is still axis-aligned, so axis-alignment is a proxy
  # that misses it.
  expect_false(any(fly_is_square(fp)))
})


test_that("an inferred-format frame IS sized when a dem is supplied", {
  # The documentation says a frame carrying no calibration can only be sized through a
  # DEM, because pixel count spreads 32-83% at a given focal length. That route has to
  # actually be reachable: keying eligibility on the nominal-scale half-side made it
  # unreachable for every camera-table row at once — `width_in` is NA there by
  # definition — so these came back empty with a DEM supplied, and silently, because
  # they are excluded from the unknown-format warning too.
  skip_if_no_terra()
  p <- digital_fixture()
  p$camera_calibration_url <- NA        # force the focal-length fallback
  p$ground_sample_distance <- NA        # remove the GSD route entirely

  fp <- suppressWarnings(fly_footprint(p, dem = testdata_path("dem.tif")))

  expect_equal(fp$footprint_basis, rep("inferred_format", nrow(p)))
  expect_false(any(sf::st_is_empty(sf::st_geometry(fp))))
  expect_equal(fp$footprint_terrain, rep("dem_agl", nrow(p)))
  expect_true(all(fp$height_agl > 0))
})


test_that("a calibrated frame with no usable gsd is sized by the dem instead", {
  # `ground_sample_distance` is 0 on every frame of some digital rolls, so this is a
  # real population rather than a constructed one.
  skip_if_no_terra()
  p <- digital_fixture()
  p$ground_sample_distance <- 0

  fp <- suppressWarnings(fly_footprint(p, dem = testdata_path("dem.tif")))
  expect_false(any(sf::st_is_empty(sf::st_geometry(fp))))
  expect_equal(fp$footprint_terrain, rep("dem_agl", nrow(p)))

  # Without a DEM the same frames have no route at all, and must say so.
  expect_warning(fly_footprint(p), "no way to size it")
})


test_that("an NA film_roll does not abort fly_footprint", {
  # `fly_bearing()` compared rolls with a bare `==`, so an NA gave NA to an `if` and
  # aborted. Latent until non-square footprints made `fly_footprint()` call it.
  p <- digital_fixture()
  p$film_roll[2] <- NA

  expect_no_error(fp <- suppressWarnings(fly_footprint(p)))
  expect_equal(nrow(fp), nrow(p))
})


test_that("a frame naming a withheld calibration says so", {
  # The refusal is computed in the resolver; without carrying it through, the frame is
  # indistinguishable from one whose media was simply unknown.
  ex <- fly_camera_excluded()
  withheld <- ex$key[ex$key_type == "calib_file"][1]

  p <- digital_fixture()[1, ]
  p$camera_calibration_url <- paste0(
    "https://openmaps.gov.bc.ca/thumbs/calib_report_zips/", withheld, ".zip"
  )
  fp <- suppressWarnings(fly_footprint(p))

  expect_equal(fp$width_source, paste0("withheld:", withheld))
  expect_true(sf::st_is_empty(sf::st_geometry(fp)))
  expect_true(is.na(fp$footprint_terrain))
})


test_that("a DEM-sized footprint is rotated onto the flight line too", {
  # The rotation tests above run without a DEM, so they only reach the GSD route. The
  # DEM route fills the half-dimensions *after* the point where rotation is decided, so
  # keying that decision on them left DEM-sized frames axis-aligned while `fly_bearing()`
  # had a good azimuth for them — a 1.76:1 footprint transposed 90 degrees, with the area
  # unchanged and the ground covered wrong.
  skip_if_no_terra()
  p <- digital_fixture()
  p$ground_sample_distance <- NA                 # force the DEM route
  bearing <- fly_bearing(p)$bearing

  fp <- sf::st_transform(
    suppressWarnings(fly_footprint(p, dem = testdata_path("dem.tif"))), 3005
  )
  expect_equal(fp$footprint_terrain[1:4], rep("dem_agl", 4))

  along_azimuth <- function(i) {
    ring <- sf::st_coordinates(sf::st_geometry(fp)[[i]])[1:4, 1:2]
    v <- ring[3, ] - ring[2, ]
    unname((atan2(v[1], v[2]) * 180 / pi) %% 360)
  }
  for (i in 1:4) expect_equal(along_azimuth(i), bearing[i], tolerance = 0.01)
})


test_that("rotation does not depend on what else is in the batch", {
  # Rotation was decided from a vector only some sizing routes populate, so whether a
  # given row came out rotated depended on whether *other* rows carried a GSD.
  skip_if_no_terra()
  dem <- testdata_path("dem.tif")
  mixed <- digital_fixture()                      # rows 1-5 carry a GSD
  no_gsd <- digital_fixture()
  no_gsd$ground_sample_distance <- NA

  ring1 <- function(p) {
    fp <- sf::st_transform(suppressWarnings(fly_footprint(p, dem = dem)), 3005)
    r <- sf::st_coordinates(sf::st_geometry(fp)[[1]])[1:4, 1:2]
    v <- r[3, ] - r[2, ]
    unname((atan2(v[1], v[2]) * 180 / pi) %% 360)
  }
  expect_equal(ring1(mixed), ring1(no_gsd), tolerance = 0.01)
})


test_that("an unsizable film frame is told about scale, not about GSD", {
  # A film frame reaches "resolved but unsized" through an unparseable `scale`. Telling
  # its owner to supply a ground sample distance points at the wrong column entirely.
  photos <- mixed_media_fixture()[1:2, ]
  photos$scale <- c("not a scale", "1:12000")

  expect_warning(fp <- fly_footprint(photos), "no usable `scale`")
  expect_true(sf::st_is_empty(sf::st_geometry(fp)[1]))
  expect_false(sf::st_is_empty(sf::st_geometry(fp)[2]))
})
