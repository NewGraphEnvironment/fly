# Wiring the frame-border mask into `fly_georef()`.
#
# The option vector is tested as a pure function, offline, for the same reason
# `fly_georef_gcps()` is: it can be wrong while everything around it looks healthy, and a
# warped GeoTIFF does not show you which flags produced it. See `inst/notes/border-masking.md`.

# The exact vector `fly_georef()` emitted before v0.11.0. Hardcoded rather than derived —
# it is a contract this package chose, and a parity assertion computed from the code it is
# meant to pin could never fail.
warp_opts_v0_10_0 <- function(n_bands, srcnodata = "0") {
  is_rgb <- n_bands >= 3
  o <- c("-t_srs", "EPSG:3005", "-r", "bilinear")
  src_val <- if (is_rgb) paste(rep(srcnodata, n_bands), collapse = " ") else srcnodata
  o <- c(o, "-srcnodata", src_val)
  if (is_rgb) c(o, "-dstalpha") else c(o, "-dstnodata", "0")
}


test_that("mask = \"none\" reproduces the pre-0.11.0 option vector exactly", {
  # The backward-compatibility proof, and it is free. If this drifts, every caller who
  # opted out of masking silently got a different warp.
  expect_identical(fly_georef_warp_opts(3L, "0", masked = FALSE), warp_opts_v0_10_0(3L))
  expect_identical(fly_georef_warp_opts(1L, "0", masked = FALSE), warp_opts_v0_10_0(1L))
  expect_identical(fly_georef_warp_opts(4L, "0", masked = FALSE), warp_opts_v0_10_0(4L))

  # Spelled out once, so a reader can see what the contract is without evaluating it.
  expect_identical(
    fly_georef_warp_opts(3L, "0", masked = FALSE),
    c("-t_srs", "EPSG:3005", "-r", "bilinear", "-srcnodata", "0 0 0", "-dstalpha")
  )
  expect_identical(
    fly_georef_warp_opts(1L, "0", masked = FALSE),
    c("-t_srs", "EPSG:3005", "-r", "bilinear", "-srcnodata", "0", "-dstnodata", "0")
  )
})


test_that("a masked source is read through -srcalpha and never through -srcnodata", {
  for (nb in c(1L, 3L, 4L)) {
    o <- fly_georef_warp_opts(nb, NULL, masked = TRUE)
    expect_true("-srcalpha" %in% o)
    expect_false("-srcnodata" %in% o)
  }

  # And the two are never emitted together even if a caller reached this helper directly.
  # `fly_georef()` refuses the combination at its boundary; this must not paper over it by
  # emitting both, because GDAL applies both and the mask loses.
  o <- fly_georef_warp_opts(3L, "0", masked = TRUE)
  expect_true("-srcalpha" %in% o)
  expect_false("-srcnodata" %in% o)
})


test_that("warp fill is unchanged, so output band counts do not move", {
  # -dstalpha for RGB, -dstnodata 0 for grayscale, masked or not. This is what keeps the
  # stac_airphoto_bc COG pipeline reading the same shape it always has.
  for (masked in c(TRUE, FALSE)) {
    rgb  <- fly_georef_warp_opts(3L, if (masked) NULL else "0", masked = masked)
    gray <- fly_georef_warp_opts(1L, if (masked) NULL else "0", masked = masked)
    expect_true("-dstalpha" %in% rgb)
    expect_false("-dstalpha" %in% gray)
    expect_true(all(c("-dstnodata", "0") %in% gray))
    expect_false("-dstnodata" %in% rgb)
  }
})


test_that("no options are emitted when there is neither a mask nor a srcnodata", {
  expect_identical(
    fly_georef_warp_opts(3L, NULL, masked = FALSE),
    c("-t_srs", "EPSG:3005", "-r", "bilinear", "-dstalpha")
  )
})


test_that("srcnodata alongside mask = \"border\" is refused, naming both and the remedy", {
  centroids <- sf::st_read(system.file("testdata/photo_centroids.gpkg", package = "fly"),
                           quiet = TRUE)
  fetched <- dplyr::tibble(airp_id = centroids$airp_id[1], dest = NA_character_,
                           success = FALSE)

  # GDAL accepts the combination and then deletes the interior black the mask exists to
  # keep — measured, exactly the 121 true-black pixels of a synthetic test frame. Silent,
  # so the package raises what GDAL will not.
  err <- tryCatch(
    fly_georef(fetched, centroids[1, ], dest_dir = tempfile(), srcnodata = "0"),
    error = function(e) conditionMessage(e)
  )
  expect_match(err, "srcnodata")
  expect_match(err, "mask")
  expect_match(err, "mask = \"none\"", fixed = TRUE)

  # ...and it is legal with the mask off, which is the documented escape hatch.
  expect_no_error(
    suppressWarnings(suppressMessages(
      fly_georef(fetched, centroids[1, ], dest_dir = tempfile(),
                 mask = "none", srcnodata = "0")
    ))
  )
})


test_that("an invalid mask_threshold is refused before any file is touched", {
  centroids <- sf::st_read(system.file("testdata/photo_centroids.gpkg", package = "fly"),
                           quiet = TRUE)
  fetched <- dplyr::tibble(airp_id = centroids$airp_id[1], dest = NA_character_,
                           success = FALSE)
  dd <- tempfile()
  expect_error(
    fly_georef(fetched, centroids[1, ], dest_dir = dd, mask_threshold = 16.7),
    "whole number"
  )
  # The guard sits ahead of `dir.create()`, so a rejected call leaves no output directory.
  expect_false(dir.exists(dd))
})


test_that("the mask is measured on the SOURCE, before any GCP or warp step", {
  skip_if_no_terra()

  # This is the assertion that pins the ordering. Measuring the mask on the warped output
  # would count GDAL's fill outside the rotated frame — nearly half the output at a
  # 45-degree bearing — so the fraction would depend on the flight line rather than on the
  # photograph. A spy on the argument is what separates the two; the fraction alone cannot.
  src <- tempfile(fileext = ".tif")
  terra::writeRaster(terra::rast(nrows = 120, ncols = 100, vals = 200L), src,
                     datatype = "INT1U", overwrite = TRUE, NAflag = NA)

  seen <- character(0)
  real <- fly:::fly_mask_one
  testthat::local_mocked_bindings(
    fly_mask_one = function(src, out, threshold, ...) {
      seen <<- c(seen, src)
      real(src, out, threshold, ...)
    },
    .package = "fly",
    .env = parent.frame()
  )

  ring <- sf::st_sf(geometry = sf::st_sfc(sf::st_polygon(list(matrix(
    c(-500, -600, 500, -600, 500, 600, -500, 600, -500, -600),
    ncol = 2, byrow = TRUE
  ) + rep(c(1.2e6, 9e5), each = 5))), crs = 3005))

  out <- tempfile(fileext = ".tif")
  suppressWarnings(georef_one(src, ring, out, rotation = 0))

  expect_length(seen, 1L)
  expect_identical(normalizePath(seen[[1]]), normalizePath(src))
})


test_that("end to end, masking removes the collar and leaves the band count alone", {
  skip_if_no_terra()

  # A frame with a collar the old exact-zero path could not see: 3-12, never 0.
  build <- function(path, bands) {
    n <- 120L
    m <- matrix(200L, n, n)
    vals <- rep(seq.int(3L, 12L), length.out = n)
    for (k in seq_len(10L)) {
      m[k, ] <- vals
      m[n - k + 1L, ] <- vals
      m[, k] <- vals
      m[, n - k + 1L] <- vals
    }
    r <- terra::rast(nrows = n, ncols = n, nlyrs = bands, vals = 0L)
    for (b in seq_len(bands)) terra::values(r[[b]]) <- as.integer(t(m))
    terra::writeRaster(r, path, datatype = "INT1U", overwrite = TRUE, NAflag = NA)
    path
  }

  ring <- sf::st_sf(geometry = sf::st_sfc(sf::st_polygon(list(matrix(
    c(-600, -600, 600, -600, 600, 600, -600, 600, -600, -600),
    ncol = 2, byrow = TRUE
  ) + rep(c(1.2e6, 9e5), each = 5))), crs = 3005))

  opaque <- function(path) {
    a <- terra::as.array(suppressWarnings(terra::rast(path)))
    sum(a[, , dim(a)[3]] == 255)
  }

  for (bands in c(1L, 3L)) {
    src <- build(tempfile(fileext = ".tif"), bands)

    on_file  <- tempfile(fileext = ".tif")
    off_file <- tempfile(fileext = ".tif")
    expect_true(suppressWarnings(georef_one(src, ring, on_file, rotation = 270)))
    expect_true(suppressWarnings(
      georef_one(src, ring, off_file, rotation = 270, mask = "none", srcnodata = "0")
    ))

    # The band count is what stac_airphoto_bc consumes, and it must not move.
    expect_equal(fly_gdal_bands(fly_gdal_info(on_file)),
                 fly_gdal_bands(fly_gdal_info(off_file)))
    expect_equal(fly_gdal_bands(fly_gdal_info(on_file)), if (bands >= 3L) 4L else 1L)

    # RGB carries an alpha band, so the collar's removal is directly countable. Grayscale
    # expresses it as nodata rather than alpha and has no alpha band to count, which is
    # the weaker contract recorded in the note.
    if (bands >= 3L) {
      expect_lt(opaque(on_file), opaque(off_file))
      # ...and by roughly the collar's share of the frame, not by a rounding error.
      expect_gt((opaque(off_file) - opaque(on_file)) / opaque(off_file), 0.1)
    }
  }
})
