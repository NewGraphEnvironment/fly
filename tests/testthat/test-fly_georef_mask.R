# Wiring the frame-border mask into `fly_georef()`.
#
# The option vector is tested as a pure function, offline, for the same reason
# `fly_georef_gcps()` is: it can be wrong while everything around it looks healthy, and a
# warped GeoTIFF does not show you which flags produced it. See `inst/notes/border-masking.md`.

# The exact vector `fly_georef()` emitted before v0.11.0. Hardcoded rather than derived —
# it is a contract this package chose, and a parity assertion computed from the code it is
# meant to pin could never fail. Since v0.19.0 (fly#56) it holds for RGB only: grayscale
# fill moved from `-dstnodata 0` to `-dstalpha`, deliberately.
warp_opts_v0_10_0 <- function(n_bands, srcnodata = "0") {
  is_rgb <- n_bands >= 3
  o <- c("-t_srs", "EPSG:3005", "-r", "bilinear")
  src_val <- if (is_rgb) paste(rep(srcnodata, n_bands), collapse = " ") else srcnodata
  o <- c(o, "-srcnodata", src_val)
  if (is_rgb) c(o, "-dstalpha") else c(o, "-dstnodata", "0")
}


test_that("mask = \"none\" reproduces the pre-0.11.0 option vector for RGB, and grayscale differs only in its fill", {
  # The backward-compatibility proof for RGB. If this drifts, every caller who opted out
  # of masking silently got a different warp.
  expect_identical(fly_georef_warp_opts(3L, "0", masked = FALSE), warp_opts_v0_10_0(3L))
  expect_identical(fly_georef_warp_opts(4L, "0", masked = FALSE), warp_opts_v0_10_0(4L))

  # Grayscale differs from v0.10.0 in exactly the last arm and nowhere else.
  old  <- warp_opts_v0_10_0(1L)
  new  <- fly_georef_warp_opts(1L, "0", masked = FALSE)
  expect_identical(new, c(old[seq_len(length(old) - 2L)], "-dstalpha"))

  # Spelled out once, so a reader can see what the contract is without evaluating it.
  expect_identical(
    fly_georef_warp_opts(3L, "0", masked = FALSE),
    c("-t_srs", "EPSG:3005", "-r", "bilinear", "-srcnodata", "0 0 0", "-dstalpha")
  )
  expect_identical(
    fly_georef_warp_opts(1L, "0", masked = FALSE),
    c("-t_srs", "EPSG:3005", "-r", "bilinear", "-srcnodata", "0", "-dstalpha")
  )
})


test_that("a masked source is read through -srcalpha and never through -srcnodata", {
  for (nb in c(1L, 3L, 4L)) {
    o <- fly_georef_warp_opts(nb, NULL, masked = TRUE)
    expect_true("-srcalpha" %in% o)
    expect_false("-srcnodata" %in% o)
  }
})


test_that("srcnodata is the fallback: live exactly where the mask did not run", {
  # The four rows fly#69 measured, pinned. `fly_georef()` now accepts `mask = "border"`
  # with `srcnodata`, and that is only safe because this is an either/or: GDAL given both
  # applies both, and `-srcnodata` then deletes the interior black the mask kept.
  for (nb in c(1L, 3L)) {
    both <- fly_georef_warp_opts(nb, "0", masked = TRUE)
    expect_true("-srcalpha" %in% both)
    expect_false("-srcnodata" %in% both)

    expect_identical(fly_georef_warp_opts(nb, "0", masked = TRUE),
                     fly_georef_warp_opts(nb, NULL, masked = TRUE))

    declined <- fly_georef_warp_opts(nb, "0", masked = FALSE)
    expect_true("-srcnodata" %in% declined)
    expect_false("-srcalpha" %in% declined)

    neither <- fly_georef_warp_opts(nb, NULL, masked = FALSE)
    expect_false(any(c("-srcnodata", "-srcalpha") %in% neither))
  }
})


test_that("every output carries a real alpha band and nothing is marked by value", {
  # fly#56. `-dstnodata 0` on grayscale made a genuine 0 inside the frame indistinguishable
  # from fill, so GDAL rewrote real zeros as 1 (measured on 3.8.5; printed on the Windows
  # runner in fly#68), or deleted them where `-srcnodata 0` was also given.
  # Alpha is the only fill marker, for every band count, masked or not.
  for (nb in c(1L, 2L, 3L, 4L)) {
    for (masked in c(TRUE, FALSE)) {
      for (snd in list(NULL, "0")) {
        o <- fly_georef_warp_opts(nb, snd, masked = masked)
        expect_true("-dstalpha" %in% o)
        expect_false("-dstnodata" %in% o)
      }
    }
  }
})


test_that("no options are emitted when there is neither a mask nor a srcnodata", {
  expect_identical(
    fly_georef_warp_opts(3L, NULL, masked = FALSE),
    c("-t_srs", "EPSG:3005", "-r", "bilinear", "-dstalpha")
  )
  expect_identical(
    fly_georef_warp_opts(1L, NULL, masked = FALSE),
    c("-t_srs", "EPSG:3005", "-r", "bilinear", "-dstalpha")
  )
})


test_that("srcnodata alongside mask = \"border\" is accepted", {
  centroids <- sf::st_read(system.file("testdata/photo_centroids.gpkg", package = "fly"),
                           quiet = TRUE)
  fetched <- dplyr::tibble(airp_id = centroids$airp_id[1], dest = NA_character_,
                           success = FALSE)

  # Refused before v0.19.0 on the grounds that GDAL would apply both. It never did —
  # `fly_georef_warp_opts()` chooses one — so the refusal only made the fallback
  # unreachable from the exported API (fly#69, absorbed into fly#56).
  for (m in c("border", "none")) {
    expect_no_error(
      suppressWarnings(suppressMessages(
        fly_georef(fetched, centroids[1, ], dest_dir = tempfile(), mask = m, srcnodata = "0")
      ))
    )
  }
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


# A frame with a collar the old exact-zero path could not see: 3-12, never 0. `hole` puts
# an 11x11 block of TRUE black in the middle, which is scene content (shadow, dark water)
# that no mask should take and no fill marker should collide with.
collar_frame <- function(path, bands, hole = FALSE, datatype = "INT1U") {
  n <- 120L
  m <- matrix(200L, n, n)
  vals <- rep(seq.int(3L, 12L), length.out = n)
  for (k in seq_len(10L)) {
    m[k, ] <- vals
    m[n - k + 1L, ] <- vals
    m[, k] <- vals
    m[, n - k + 1L] <- vals
  }
  if (hole) m[55:65, 55:65] <- 0L
  r <- terra::rast(nrows = n, ncols = n, nlyrs = bands, vals = 0L)
  for (b in seq_len(bands)) terra::values(r[[b]]) <- as.integer(t(m))
  terra::writeRaster(r, path, datatype = datatype, overwrite = TRUE, NAflag = NA)
  path
}

# Axis-aligned and the same 1200 m on both sides as the 120 px frame, so one source pixel
# is exactly one 10 m output cell and the middle of the frame lands at a known place.
collar_ring <- function() {
  sf::st_sf(geometry = sf::st_sfc(sf::st_polygon(list(matrix(
    c(-600, -600, 600, -600, 600, 600, -600, 600, -600, -600),
    ncol = 2, byrow = TRUE
  ) + rep(c(1.2e6, 9e5), each = 5))), crs = 3005))
}

# Opaque pixels, read from the LAST band, which is alpha on every output since fly#56.
# `full` is the alpha band's opaque value, which GDAL sets to its datatype's maximum: 255
# on Byte, 65535 on a UInt16 output.
opaque <- function(path, full = 255) {
  a <- terra::as.array(suppressWarnings(terra::rast(path)))
  sum(a[, , dim(a)[3]] == full)
}


test_that("end to end, every output carries alpha: grayscale 2 bands, RGB 4, on this platform too", {
  skip_if_no_terra()
  ring <- collar_ring()

  for (bands in c(1L, 3L)) {
    src <- collar_frame(tempfile(fileext = ".tif"), bands)

    on_file  <- tempfile(fileext = ".tif")
    off_file <- tempfile(fileext = ".tif")
    expect_true(suppressWarnings(georef_one(src, ring, on_file, rotation = 270)))
    expect_true(suppressWarnings(
      georef_one(src, ring, off_file, rotation = 270, mask = "none", srcnodata = "0")
    ))

    # The band count is what stac_airphoto_bc consumes. Before fly#56 grayscale was 1 band
    # on ubuntu and macOS and 2 on Windows when masked (fly#68), so the old invariant was
    # platform-conditional and pinned per platform here. With `-dstalpha` everywhere it is
    # one number, and asserted unconditionally: red on any runner that disagrees.
    want <- bands + 1L
    expect_equal(fly_gdal_bands(fly_gdal_info(on_file)), want,
                 label = paste0("bands=", bands, " masked, on ", Sys.info()[["sysname"]]))
    expect_equal(fly_gdal_bands(fly_gdal_info(off_file)), want,
                 label = paste0("bands=", bands, " unmasked, on ", Sys.info()[["sysname"]]))

    # Fill is marked by alpha alone. gdalwarp copies a source nodata to the output unless
    # `-dstalpha` is given; a `NoData Value` here would bring the value collision back.
    for (f in c(on_file, off_file)) {
      expect_false(grepl("NoData Value", fly_gdal_info(f)), label = basename(f))
    }

    # Both shapes now carry an alpha band, so the collar's removal is countable for
    # grayscale too — which it was not while grayscale expressed fill as a value.
    expect_lt(opaque(on_file), opaque(off_file))
    # ...and by roughly the collar's share of the frame, not by a rounding error.
    expect_gt((opaque(off_file) - opaque(on_file)) / opaque(off_file), 0.1)
  }
})


test_that("true black inside a grayscale frame is written as opaque data, not as fill", {
  skip_if_no_terra()

  # The output-side collision fly#56 exists to fix. Under `-dstnodata 0` the 11x11 block
  # of real zeros below came out as 1 — GDAL moving it off the nodata value, silently on
  # 3.8.5 — or as nodata where `-srcnodata 0` was also given. With alpha it keeps value 0
  # and alpha 255.
  src <- collar_frame(tempfile(fileext = ".tif"), 1L, hole = TRUE)
  out <- tempfile(fileext = ".tif")
  # `srcnodata` too: on a frame the mask accepts it must not reach GDAL, or it deletes
  # exactly this block — the reason `fly_georef()` refused the pair before v0.19.0.
  expect_true(suppressWarnings(
    georef_one(src, collar_ring(), out, rotation = 270, srcnodata = "0")
  ))

  r <- suppressWarnings(terra::rast(out))
  expect_equal(terra::nlyr(r), 2L)
  # The block's middle, located by ground coordinate rather than array index, and well
  # clear of the bilinear kernel's reach into the 200s around it: 11 cells of 10 m, so
  # +-20 m of the ring's centre is inside it.
  pts <- expand.grid(x = 1.2e6 + c(-20, 0, 20), y = 9e5 + c(-20, 0, 20))
  v <- terra::extract(r, as.matrix(pts))
  expect_true(all(v[[2]] == 255))
  # Exactly 0: not NA (read as nodata) and not 1 (GDAL's rewrite of a real 0 away from a
  # nodata of 0, what the old default path actually did on 3.8.5 and on the fly#68 runner).
  expect_false(anyNA(v[[1]]))
  expect_true(all(v[[1]] == 0))
})


test_that("a declined mask falls back to srcnodata, and without it the collar is warped in as data", {
  skip_if_no_terra()

  # fly#69's fourth row, reached through the exported semantics. A 16-bit source is
  # declined by `fly_mask_one()` (the threshold is calibrated on 8-bit imagery), so the
  # frame is warped unmasked. The collar here is EXACT 0, the only thing `srcnodata`
  # can see.
  src <- tempfile(fileext = ".tif")
  n <- 120L
  m <- matrix(2000L, n, n)
  m[1:10, ] <- 0L
  m[(n - 9):n, ] <- 0L
  m[, 1:10] <- 0L
  m[, (n - 9):n] <- 0L
  # NAflag must be a value the frame does not hold. `NA` is written as `NoData Value=nan`,
  # which GDAL reads as 0 on an integer band and honours with or without `srcnodata`, so
  # both legs mask the collar and the test cannot tell them apart.
  terra::writeRaster(terra::rast(nrows = n, ncols = n, vals = as.integer(t(m))), src,
                     datatype = "INT2U", overwrite = TRUE, NAflag = 65535)

  with_fallback <- tempfile(fileext = ".tif")
  without       <- tempfile(fileext = ".tif")
  ok1 <- suppressWarnings(
    georef_one(src, collar_ring(), with_fallback, rotation = 270, srcnodata = "0")
  )
  ok2 <- suppressWarnings(georef_one(src, collar_ring(), without, rotation = 270))
  expect_true(ok1)
  expect_true(ok2)

  # With the fallback the collar is transparent; without it, all of it is opaque. The
  # difference is the collar: 120^2 - 100^2 = 4400 source pixels, one output cell each.
  expect_equal(opaque(without, 65535) - opaque(with_fallback, 65535), 4400, tolerance = 0.05)
})


test_that("a declined mask with no fallback is warned about, and a masked or fallen-back frame is not", {
  skip_if_no_terra()

  # Row 4 of fly#69's table: no mask, no srcnodata, collar written as data. The non-Byte
  # decline path in `fly_mask_one()` returns without warning, so `georef_one()` must say it.
  src16 <- tempfile(fileext = ".tif")
  terra::writeRaster(terra::rast(nrows = 60, ncols = 60, vals = 2000L), src16,
                     datatype = "INT2U", overwrite = TRUE, NAflag = 65535)
  expect_warning(georef_one(src16, collar_ring(), tempfile(fileext = ".tif"), rotation = 270),
                 "declined .*band type.*srcnodata")
  expect_no_warning(georef_one(src16, collar_ring(), tempfile(fileext = ".tif"),
                               rotation = 270, srcnodata = "0"))

  src8 <- collar_frame(tempfile(fileext = ".tif"), 1L)
  expect_no_warning(georef_one(src8, collar_ring(), tempfile(fileext = ".tif"), rotation = 270))
})
