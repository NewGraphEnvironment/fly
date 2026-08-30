# Helper to locate test data in inst/testdata/
testdata_path <- function(...) {
  system.file("testdata", ..., package = "fly", mustWork = TRUE)
}


# Synthesized mixed film/digital fixture.
#
# The bundled centroids are 100% `Film - BW`: they come from a 1968 AOI near
# Houston (data-raw/make_testdata.R), which has no digital coverage at all. A
# digital frame therefore has to be constructed rather than sampled.
#
# Focal lengths and GSD mirror the catalogue's two tells for a sensor: 92/100 mm
# against 153/305 mm for film, and a populated GROUND_SAMPLE_DISTANCE.
mixed_media_fixture <- function() {
  sf::st_sf(
    airp_id = 1:4,
    scale = c("1:12000", "1:12000", "1:15000", "1:15000"),
    media = c("Film - BW", "Film - Colour", "Digital - Colour", "Digital - Colour"),
    focal_length = c(153, 305, 92, 100),
    ground_sample_distance = c(NA, NA, 0.10, 0.10),
    geometry = sf::st_sfc(
      sf::st_point(c(-126.60, 54.40)),
      sf::st_point(c(-126.58, 54.40)),
      sf::st_point(c(-126.56, 54.40)),
      sf::st_point(c(-126.54, 54.40)),
      crs = 4326
    )
  )
}


# Skip a terrain test when terra is unavailable.
#
# `terra` is in Suggests, not Imports — the DEM path is optional. A test that
# needs it must skip rather than fail on an install that reasonably lacks it.
skip_if_no_terra <- function() {
  testthat::skip_if_not_installed("terra")
}

# Centroids carrying the two fields the DEM path needs, plus a media value the
# format table cannot resolve — so one frame arrives with an empty geometry and
# the terrain code must leave it alone rather than sample a DEM under it.
terrain_fixture <- function() {
  sf::st_sf(
    airp_id = 1:3,
    scale = c("1:12000", "1:12000", "1:12000"),
    media = c("Film - BW", "Film - BW", "Digital - Colour"),
    focal_length = c(153, 153, 153),
    flying_height = c(2591, 2591, 2591),
    geometry = sf::st_sfc(
      sf::st_point(c(-126.60, 54.40)),
      sf::st_point(c(-126.58, 54.40)),
      sf::st_point(c(-126.56, 54.40)),
      crs = 4326
    )
  )
}


# The same bundled centroids in every class shape a real caller can supply.
#
# `bcdata::collect()` returns `bcdc_sf, sf, tbl_df, tbl, data.frame`, and #35
# measured that `tbl_df` is the discriminating member — stripping the bcdata
# class alone does not change the outcome — so these shapes bound the real
# inputs without fly taking a dependency on bcdata to build a fixture.
#
# Read honestly rather than by overwriting `class()`: `st_read(as_tibble =)`
# produces the tibble-backed sf a caller would actually hold. The premise is
# asserted here so that a future `sf` change fails on the premise, naming the
# real cause, rather than on the behaviour under test.
centroid_shapes <- function() {
  p <- testdata_path("photo_centroids.gpkg")
  plain <- sf::st_read(p, quiet = TRUE)
  tbl <- sf::st_read(p, quiet = TRUE, as_tibble = TRUE)
  grouped <- dplyr::group_by(tbl, .data$scale)
  # `bcdc_sf` is set by hand rather than by querying: bcdata is not a dependency
  # of fly, and #35 measured that `tbl_df` is what selects the failing branch —
  # so this shape exists to pin the *class contract* for the documented caller,
  # not to reach the bug. `st_transform()` moves `sf` to the front of the class
  # vector, so this is the one shape that shows the order is not preserved.
  bcdc <- tbl
  class(bcdc) <- c("bcdc_sf", class(bcdc))
  stopifnot(
    !inherits(plain, "tbl_df"),
    inherits(tbl, "tbl_df"),
    inherits(grouped, "grouped_df"),
    identical(class(bcdc)[1:2], c("bcdc_sf", "sf"))
  )
  list(plain = plain, tbl = tbl, grouped = grouped, bcdc = bcdc)
}


# The bundled centroids are one film stock at one terrain treatment, so with no
# `dem` all four reporting columns are constant or all-`NA` — a value comparison
# across class shapes there is nearly vacuous, and only their *absence* makes it
# fail. The mixed-media fixture varies `footprint_basis` across four rows and
# reaches the `unknown_format` branch, so the sweep compares something.
mixed_media_shapes <- function() {
  mm <- mixed_media_fixture()
  tbl <- sf::st_as_sf(dplyr::as_tibble(mm))
  stopifnot(!inherits(mm, "tbl_df"), inherits(tbl, "tbl_df"))
  list(plain = mm, tbl = tbl)
}

# The columns #30 and #9 added, which #35 found were reaching no tibble caller.
fly_reported_cols <- function() {
  c("footprint_basis", "footprint_terrain", "height_agl", "dem_coverage")
}
