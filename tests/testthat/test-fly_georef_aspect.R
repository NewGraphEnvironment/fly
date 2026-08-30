# The aspect invariant: the half of the corner mapping that geometry settles.
#
# `georef_one()` hands GDAL four corner correspondences and lets it fit the transform.
# Nothing downstream checks that the fit is isotropic, so a mapping that sends the
# image's long axis onto the footprint's short edge produces a valid, wrongly-squashed
# GeoTIFF. That is the failure this file exists to make impossible.
#
# It cannot settle everything. Rotations 90 and 270 differ by 180 degrees about the
# footprint centre and a rectangle is symmetric under that, so no geometric assertion
# distinguishes them — see `inst/notes/georeferencing.md`.

# Delivered image orientation, measured 2026-08-30 against the live thumbnails at
# openmaps.gov.bc.ca. Both digital cameras in the bundled fixture deliver PORTRAIT
# images whose long axis is the image height:
#
#   Leica DMC II       bcd13304_778_rgb_thumb.jpg   884 x 972 px
#   UltraCam Eagle M3  bcd19503_348_thumb.jpg      1063 x 1654 px
#
# The DMC II thumbnail's EXIF carries its source TIFF as width=14144, height=15552, so
# the full-resolution frame is portrait too and the thumbnail is not rotated relative to
# it. Image width is therefore the along-track pixel count and image height the
# across-track one.
image_dims <- function(fmt) {
  list(ncol_px = fmt$px_along, nrow_px = fmt$px_cross)
}

# Metres per pixel along the image's width axis, divided by metres per pixel along its
# height axis. An isotropic mapping gives 1; anything else is a squash of that factor.
gcp_anisotropy <- function(ncol_px, nrow_px, ring, rot) {
  g <- fly_georef_gcps(ncol_px, nrow_px, ring, rot)[, c("ground_x", "ground_y")]
  w <- sqrt(sum((g[2, ] - g[1, ])^2)) / ncol_px
  h <- sqrt(sum((g[3, ] - g[2, ])^2)) / nrow_px
  w / h
}

digital_rings <- function() {
  photos <- sf::st_read(testdata_path("photo_centroids_digital.gpkg"), quiet = TRUE)
  fp <- sf::st_transform(suppressWarnings(fly_footprint(photos)), 3005)
  fmt <- fly_camera_format(photos)
  lapply(seq_len(nrow(fp)), function(i) {
    list(
      ring    = sf::st_coordinates(sf::st_geometry(fp)[[i]])[1:4, 1:2, drop = FALSE],
      dims    = image_dims(fmt[i, ]),
      camera  = fmt$camera[i]
    )
  })
}


test_that("the shipped sensor aspect matches the delivered thumbnail aspect", {
  # The premise the invariant below rests on, asserted beside it. If a regenerated
  # `camera_formats.csv` ever disagrees with the images the catalogue actually serves,
  # this fails naming the cause instead of the behaviour test failing and blaming the
  # corner mapping.
  photos <- sf::st_read(testdata_path("photo_centroids_digital.gpkg"), quiet = TRUE)
  fmt <- fly_camera_format(photos)

  measured <- c("Leica DMC II" = 972 / 884, "UltraCam Eagle M3" = 1654 / 1063)
  shipped <- tapply(fmt$px_cross / fmt$px_along, fmt$camera, function(x) x[1])

  expect_setequal(names(shipped), c("DMC II", "UltraCam Eagle M3"))
  expect_equal(unname(shipped[["DMC II"]]), unname(measured[["Leica DMC II"]]),
               tolerance = 1e-3)
  expect_equal(unname(shipped[["UltraCam Eagle M3"]]),
               unname(measured[["UltraCam Eagle M3"]]), tolerance = 1e-3)
})


test_that("rotations 90 and 270 map a digital frame isotropically", {
  cases <- digital_rings()
  expect_gt(length(cases), 0)

  for (rot in c(90, 270)) {
    aniso <- vapply(cases, function(c_) {
      gcp_anisotropy(c_$dims$ncol_px, c_$dims$nrow_px, c_$ring, rot)
    }, numeric(1))
    expect_equal(aniso, rep(1, length(cases)), tolerance = 1e-6,
                 info = paste("rotation =", rot))
  }
})


test_that("rotations 0 and 180 squash a digital frame, and by how much", {
  # The negative half. Without it the test above passes for an implementation that
  # returns an isotropic mapping for every rotation, which is the one thing it must not
  # do — see the restore-the-bug check in `test-fly_georef.R`.
  #
  # The distortion is the footprint's aspect ratio squared, so it is uneven across the
  # bundled cameras and the numbers are pinned rather than left to a threshold:
  #   DMC II            1.100^2 = 1.21   <- weak; would survive a loose tolerance
  #   UltraCam Eagle M3 1.556^2 = 2.42   <- the case that makes this discriminating
  # A fixture change that drops the UltraCam frames fails here.
  cases <- digital_rings()
  by_cam <- split(cases, vapply(cases, function(c_) c_$camera, character(1)))
  expect_setequal(names(by_cam), c("DMC II", "UltraCam Eagle M3"))

  expected <- c("DMC II" = 1.21, "UltraCam Eagle M3" = 2.42)
  for (cam in names(by_cam)) {
    for (rot in c(0, 180)) {
      aniso <- vapply(by_cam[[cam]], function(c_) {
        gcp_anisotropy(c_$dims$ncol_px, c_$dims$nrow_px, c_$ring, rot)
      }, numeric(1))
      expect_equal(aniso, rep(expected[[cam]], length(aniso)), tolerance = 0.01,
                   info = paste(cam, "rotation =", rot))
    }
  }
})


test_that("square film is isotropic at every rotation, so the invariant is vacuous there", {
  # Stated rather than assumed. A square footprint with a square scan cannot distinguish
  # any of the four rotations, which is exactly why the film mapping needed calibrating
  # against imagery and why this file cannot finish the job for digital either.
  photos <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  fp <- sf::st_transform(suppressWarnings(fly_footprint(photos[1, ])), 3005)
  ring <- sf::st_coordinates(sf::st_geometry(fp)[[1]])[1:4, 1:2, drop = FALSE]

  for (rot in c(0, 90, 180, 270)) {
    expect_equal(gcp_anisotropy(1250L, 1250L, ring, rot), 1, tolerance = 1e-6,
                 info = paste("rotation =", rot))
  }
})
