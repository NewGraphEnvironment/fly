# What rotation each frame actually receives, observed at the boundary rather than
# inferred from the output. `georef_one()` is mocked so these need no network and no
# GDAL — the question is which rotation was chosen and why, not what GDAL did with it.

# Record the rotation `georef_one()` is called with, per source file.
# `.env` is the environment the mock is CLEANED UP with, not the one it is installed
# in — `.package` names the target. Passing `asNamespace("fly")` to `.env` installs the
# mock correctly and then never removes it, because a namespace does not exit: every
# later test in the run keeps the stub. That leaks silently in the direction that reads
# as success, since the stub returns TRUE.
capture_rotations <- function(expr) {
  seen <- list()
  testthat::local_mocked_bindings(
    georef_one = function(src, fp, out_file, srcnodata = "0", rotation = 180) {
      seen[[basename(src)]] <<- rotation
      TRUE
    },
    .package = "fly",
    .env = parent.frame()     # unwinds with the calling test, not with this helper
  )
  force(expr)
  seen
}

fake_fetch <- function(photos) {
  files <- file.path(tempdir(), paste0("f", photos$airp_id, ".jpg"))
  for (f in files) if (!file.exists(f)) writeLines("x", f)
  dplyr::tibble(airp_id = photos$airp_id, dest = files, success = TRUE)
}

digital_photos <- function(i = 19:24) {
  sf::st_read(testdata_path("photo_centroids_digital.gpkg"), quiet = TRUE)[i, ]
}


test_that("a non-square footprint gets the measured digital rotation, not the bearing", {
  photos <- digital_photos()
  # The premise: without this the test would pass for a bearing rule that happened to
  # agree. These frames fly ~343 degrees, which `bearing_to_rotation()` maps to 0.
  expect_equal(mean(fly_bearing(photos)$bearing, na.rm = TRUE), 343, tolerance = 1)
  expect_false(all(bearing_to_rotation(fly_bearing(photos)$bearing) == fly_digital_rotation()))

  seen <- capture_rotations(
    suppressWarnings(fly_georef(fake_fetch(photos), photos, dest_dir = tempfile()))
  )
  expect_length(seen, nrow(photos))
  expect_equal(unique(unlist(seen)), fly_digital_rotation())
})


test_that("a mixed batch rotates film by bearing and digital by the constant", {
  film <- sf::st_transform(sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE), 3005)
  dig  <- sf::st_transform(digital_photos(), 3005)
  cols <- intersect(names(film), names(dig))
  mix  <- rbind(film[1:4, cols], dig[1:3, cols])

  fp <- suppressWarnings(fly_footprint(mix))
  expect_equal(fly_is_square(fp), c(rep(TRUE, 4), rep(FALSE, 3)))   # premise

  seen <- capture_rotations(
    suppressWarnings(fly_georef(fake_fetch(mix), mix, dest_dir = tempfile()))
  )
  got <- unlist(seen)[paste0("f", mix$airp_id, ".jpg")]

  expect_equal(unname(got[5:7]), rep(fly_digital_rotation(), 3))
  # Film keeps the pre-existing rule exactly, whatever it returns for these bearings.
  expect_equal(unname(got[1:4]), bearing_to_rotation(fly_bearing(mix)$bearing[1:4]))
})


test_that("a user rotation column overrides the digital constant", {
  photos <- digital_photos()
  photos$rotation <- 180L
  seen <- capture_rotations(
    suppressWarnings(fly_georef(fake_fetch(photos), photos, dest_dir = tempfile()))
  )
  expect_equal(unique(unlist(seen)), 180L)

  # NA in the column falls through to the constant rather than to the film default.
  photos$rotation <- NA_integer_
  seen <- capture_rotations(
    suppressWarnings(fly_georef(fake_fetch(photos), photos, dest_dir = tempfile()))
  )
  expect_equal(unique(unlist(seen)), fly_digital_rotation())
})


test_that("the `rotation` argument does not silently override a digital frame", {
  # It is documented as applying to square footprints only. Asserted so that a future
  # change making it apply everywhere has to disagree with a test.
  photos <- digital_photos()
  seen <- capture_rotations(
    suppressWarnings(fly_georef(fake_fetch(photos), photos, dest_dir = tempfile(),
                                rotation = 0))
  )
  expect_equal(unique(unlist(seen)), fly_digital_rotation())
})


test_that("frames with no footprint are still skipped, and warned about once", {
  photos <- mixed_media_fixture()
  fp <- suppressWarnings(fly_footprint(photos))
  unsized <- sf::st_is_empty(sf::st_geometry(fp))
  expect_true(any(unsized))                                          # premise

  # Counted, not merely suppressed. The test is named for the warning and previously
  # only checked how many frames reached `georef_one()`, which passes just as happily
  # for zero warnings as for one per frame.
  #
  # `expect_warning()` is the wrong instrument here: this fixture also raises
  # `fly_footprint()`'s unknown-format warning, and testthat re-raises every warning it
  # did not match, so the unmatched one surfaces as a test WARNING. Handling them all
  # and counting the one under test keeps the assertion exact and the run clean.
  n <- 0L
  seen <- withCallingHandlers(
    capture_rotations(fly_georef(fake_fetch(photos), photos, dest_dir = tempfile())),
    warning = function(w) {
      if (grepl("have no footprint", conditionMessage(w))) n <<- n + 1L
      invokeRestart("muffleWarning")
    }
  )
  expect_identical(n, 1L)
  expect_length(seen, sum(!unsized))
})


test_that("a non-square footprint with no bearing is warned about", {
  # `fly_bearing()` needs a neighbour, so one frame on its own is the ordinary way to
  # reach this — not an exotic case.
  one <- digital_photos(19)
  expect_warning(
    capture_rotations(fly_georef(fake_fetch(one), one, dest_dir = tempfile())),
    "no flight bearing"
  )
  # And it does not fire when the bearing is available.
  many <- digital_photos()
  expect_no_warning(
    capture_rotations(fly_georef(fake_fetch(many), many, dest_dir = tempfile()))
  )
})


test_that("a mapping that would stretch the image is refused, not written squashed", {
  skip_if_no_terra()

  # A synthetic portrait image and a footprint of matching aspect. Written locally so
  # this needs no network — the guard is about geometry, not about pixels.
  src <- tempfile(fileext = ".tif")
  r <- terra::rast(nrows = 200, ncols = 100, vals = seq_len(20000))
  terra::writeRaster(r, src, overwrite = TRUE)

  ring <- function(hc, ha) {
    sf::st_sf(geometry = sf::st_sfc(sf::st_polygon(list(matrix(
      c(-hc, -ha, hc, -ha, hc, ha, -hc, ha, -hc, -ha),
      ncol = 2, byrow = TRUE
    ) + rep(c(1e6, 1e6), each = 5))), crs = 3005))
  }

  # 100 x 200 px onto a 1000 x 2000 m footprint: the height axis is the long one on both
  # sides, so rotation 270 pairs them isotropically and the file is written.
  ok <- ring(hc = 1000, ha = 500)
  out <- tempfile(fileext = ".tif")
  expect_true(georef_one(src, ok, out, rotation = fly_digital_rotation()))
  expect_true(file.exists(out))

  # The same image on the same footprint at rotation 0 pairs 100 px with the 2000 m edge
  # and 200 px with the 1000 m one — a 4x stretch. Refused.
  out2 <- tempfile(fileext = ".tif")
  expect_warning(res <- georef_one(src, ok, out2, rotation = 0), "Skipped rather than")
  expect_false(res)
  expect_false(file.exists(out2))

  # A square footprint is NOT exempt. It has no pairing to get wrong, but a gross
  # mismatch between image and footprint still means they disagree about the frame —
  # and exempting it by shape would switch the guard off for a digital frame sized
  # through `format_size` into a square footprint, which is the unknown-camera case the
  # guard exists for. 100 x 200 px on a 2000 x 2000 m footprint is a 2x stretch.
  sq <- ring(hc = 1000, ha = 1000)
  out3 <- tempfile(fileext = ".tif")
  expect_warning(res3 <- georef_one(src, sq, out3, rotation = 0), "Skipped rather than")
  expect_false(res3)
  expect_false(file.exists(out3))

  # A square image on that square footprint is consistent, and is written.
  square_image <- tempfile(fileext = ".tif")
  terra::writeRaster(terra::rast(nrows = 100, ncols = 100, vals = seq_len(10000)),
                     square_image, overwrite = TRUE)
  out4 <- tempfile(fileext = ".tif")
  expect_no_warning(res4 <- georef_one(square_image, sq, out4, rotation = 0))
  expect_true(res4)
})


test_that("a film scan carrying the negative's rebate still georeferences", {
  skip_if_no_terra()
  # The regression the tolerance is sized for. Every bundled film thumbnail is exactly
  # 1250 x 1250, so the fixture set cannot reach this — a full-resolution 9-inch scan
  # including the rebate is the ordinary case and lands a few percent off square. 1250 x
  # 1172 has the same aspect as the 9600 x 9000 scan that motivated it, at 1/60th the
  # pixels.
  #
  # This is the closest legitimate case to the threshold, which is what makes it worth
  # pinning: 0.064 against a tolerance of 0.095. An earlier draft used 1250 x 1200,
  # which sits at 0.041 and would have passed a 5% tolerance too — a fixture that could
  # not reach the failure it was written for.
  src <- tempfile(fileext = ".tif")
  terra::writeRaster(terra::rast(nrows = 1172, ncols = 1250, vals = seq_len(1465000)),
                     src, overwrite = TRUE)

  sq <- sf::st_sf(geometry = sf::st_sfc(sf::st_polygon(list(matrix(
    c(-2000, -2000, 2000, -2000, 2000, 2000, -2000, 2000, -2000, -2000),
    ncol = 2, byrow = TRUE
  ) + rep(c(1e6, 1e6), each = 5))), crs = 3005))
  expect_true(fly_is_square(sq))                                     # premise

  gcp <- fly_georef_gcps(1250L, 1172L, sf::st_coordinates(sq)[1:4, , drop = FALSE], 0)
  aniso <- fly_gcp_anisotropy(gcp, 1250L, 1172L)
  expect_equal(abs(log(aniso)), 0.0644, tolerance = 1e-3)            # premise
  expect_lt(abs(log(aniso)), log(fly_gcp_stretch_max()))             # premise

  for (rot in c(0, 90, 180, 270)) {
    out <- tempfile(fileext = ".tif")
    expect_no_warning(res <- georef_one(src, sq, out, rotation = rot))
    expect_true(res)
  }
})


test_that("the stretch tolerance clears every shipped camera, not just the bundled two", {
  # The whole argument for the tolerance, computed from the shipped table rather than
  # from remembered numbers. An earlier version asserted the square-footprint case using
  # the UltraCam at 0.442 — the most eccentric camera, which any tolerance clears. The
  # binding case is the LEAST eccentric one, and picking the lenient example is how the
  # tolerance came to be set 0.4% too loose and let a DMC II frame through.
  tol <- log(fly_gcp_stretch_max())
  cf <- utils::read.csv(system.file("extdata/camera_formats.csv", package = "fly"))
  aspect <- ifelse(!is.na(cf$px_cross) & !is.na(cf$px_along),
                   cf$px_cross / cf$px_along, cf$width_mm / cf$height_mm)
  expect_gt(length(aspect), 10)                                        # premise

  # Below: the worst disagreement a legitimate frame produces — a full-resolution
  # 9-inch scan carrying the negative's rebate.
  expect_lt(abs(log(9000 / 9600)), tol)

  # Above: EVERY shipped camera, on a square footprint (the `format_size` route) and
  # mispaired on its own footprint. No row may slip through.
  expect_true(all(abs(log(aspect)) > tol))
  expect_true(all(abs(log(aspect^2)) > tol))

  # And the margin is real on both sides rather than incidental.
  expect_equal(min(abs(log(aspect))), 0.0949, tolerance = 1e-3)        # DMC II
  expect_gt(min(abs(log(aspect))) / tol, 1.15)
  expect_gt(tol / abs(log(9000 / 9600)), 1.15)
})


test_that("an invalid `rotation` column is refused by name, not by GDAL", {
  photos <- digital_photos()

  # 360 shifts by four and indexes past the ring; without this check it surfaces from
  # inside `tryCatch` as "subscript out of bounds", naming neither the column nor the
  # value. 45 and -90 are worse — they shift by zero and georeference silently wrong.
  for (bad in list(360L, 45L, -90L)) {
    photos$rotation <- bad
    expect_error(fly_georef(fake_fetch(photos), photos, dest_dir = tempfile()),
                 "must be NA or one of", info = paste("rotation =", bad))
  }

  # A factor is the realistic way to get an unexpected type here — a `rotation` column
  # read from a CSV. `as.integer()` on it returns the LEVEL CODE, so a naive read both
  # validates 180 as 1 and applies it as 1. The value is normalised once and read from
  # that one place, so the factor is honoured as 180 rather than either erroring or
  # silently becoming rotation 0.
  photos$rotation <- factor("180")
  seen <- capture_rotations(
    suppressWarnings(fly_georef(fake_fetch(photos), photos, dest_dir = tempfile()))
  )
  expect_equal(unique(unlist(seen)), 180L)

  # The level code is 1, so a version that converted in two places would land here.
  expect_false(identical(unique(unlist(seen)), 1L))

  # And the valid values still get through.
  photos$rotation <- 90L
  seen <- capture_rotations(
    suppressWarnings(fly_georef(fake_fetch(photos), photos, dest_dir = tempfile()))
  )
  expect_equal(unique(unlist(seen)), 90L)
})
