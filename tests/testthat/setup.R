# Helper to locate test data in inst/testdata/
testdata_path <- function(...) {
  system.file("testdata", ..., package = "fly", mustWork = TRUE)
}


# Synthesized mixed film/digital fixture, where the digital frames CANNOT be resolved.
#
# The bundled centroids are 100% `Film - BW`, so a digital frame has to be constructed
# rather than sampled.
#
# Focal length 53 is deliberate and is not an arbitrary number: it is the catalogue
# focal of the PhaseOne rolls, whose calibration report is an image-only PDF and which
# `camera_formats_excluded.csv` therefore records as unresolvable. So it is a real
# unresolvable case rather than one invented to dodge the format table — and because
# no frame at focal 53 lacks a calibration, there is no focal-length fallback row for
# it either.
#
# That premise is asserted in the tests that depend on it (`test-fly_footprint.R`),
# so a future table that starts shipping focal 53 fails naming the real cause rather
# than failing on the behaviour under test.
#
# GROUND_SAMPLE_DISTANCE is CENTIMETRES in the catalogue — see `fly_gsd_m()`.
mixed_media_fixture <- function() {
  sf::st_sf(
    airp_id = 1:4,
    scale = c("1:12000", "1:12000", "1:15000", "1:15000"),
    media = c("Film - BW", "Film - Colour", "Digital - Colour", "Digital - Colour"),
    focal_length = c(153, 305, 53, 53),
    ground_sample_distance = c(NA, NA, 10, 10),
    geometry = sf::st_sfc(
      sf::st_point(c(-126.60, 54.40)),
      sf::st_point(c(-126.58, 54.40)),
      sf::st_point(c(-126.56, 54.40)),
      sf::st_point(c(-126.54, 54.40)),
      crs = 4326
    )
  )
}


# Digital frames that DO resolve, one per key type and with two very different sensor
# shapes.
#
# Rows 1-2 are a Leica DMC II (87.1 x 79.2 mm, aspect 1.10) and rows 3-4 an UltraCam
# Eagle (105.8 x 68.0 mm, aspect 1.56), both keyed by their real calibration file. Two
# aspect ratios that far apart are what lets a test tell a correctly-shaped footprint
# from a square one — a fixture carrying a single shape cannot.
#
# Row 5 has no calibration URL and focal 100, so it takes the focal-length fallback and
# is marked inferred. Row 6 has a calibration but GSD 0, which is the state that would
# build a degenerate five-identical-vertex polygon if the zero guard were removed.
#
# `film_roll` and `frame_number` are present so `fly_bearing()` can resolve a flight
# line; frames 1-4 run west to east.
digital_fixture <- function() {
  url <- function(k) paste0("https://openmaps.gov.bc.ca/thumbs/calib_report_zips/", k, ".zip")
  sf::st_sf(
    airp_id = 1:6,
    scale = c("1:20000", "1:20000", "1:20000", "1:20000", "1:20000", "1:20000"),
    media = rep("Digital - Colour", 6),
    film_roll = c("a", "a", "a", "a", "b", "c"),
    frame_number = c(1, 2, 3, 4, 1, 1),
    focal_length = c(92, 92, 80, 80, 100, 120),
    flying_height = rep(3000, 6),
    ground_sample_distance = c(20, 20, 15, 15, 25, 0),
    camera_calibration_url = c(
      url("121201_2011"), url("121201_2011"),
      url("20814295_2018"), url("20814295_2018"),
      NA, url("dmc100039_2006")
    ),
    geometry = sf::st_sfc(
      sf::st_point(c(-126.62, 54.40)),
      sf::st_point(c(-126.58, 54.40)),
      sf::st_point(c(-126.54, 54.40)),
      sf::st_point(c(-126.50, 54.40)),
      sf::st_point(c(-126.46, 54.40)),
      sf::st_point(c(-126.42, 54.40)),
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


# Every input shape `fly_footprint()` can be handed AND sizes, for the invariant
# sweep in test-fly_footprint_invariants.R. Non-POINT geometry is refused rather
# than sized, so those shapes live in `non_point_cases()` below and belong in
# test-fly_footprint_point_input.R — adding one here makes the sweep error.
#
# Lives here rather than in the test file so its dependencies — the other
# fixtures and `testdata_path()` — are defined alongside it.
footprint_cases <- function() {
  dem <- testdata_path("dem.tif")
  film <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  digital <- sf::st_read(testdata_path("photo_centroids_digital.gpkg"), quiet = TRUE)
  no_gsd <- digital
  no_gsd$ground_sample_distance <- NA
  list(
    "film, no dem"              = list(x = film, dem = NULL),
    "film, dem"                 = list(x = film, dem = dem),
    "digital, no dem"           = list(x = digital, dem = NULL),
    "digital, dem"              = list(x = digital, dem = dem),
    "digital, no gsd, dem"      = list(x = no_gsd, dem = dem),
    "digital, no gsd, no dem"   = list(x = no_gsd, dem = NULL),
    "unknown format"            = list(x = mixed_media_fixture(), dem = NULL),
    "mixed resolvability"       = list(x = digital_fixture(), dem = NULL),
    "mixed resolvability + dem" = list(x = digital_fixture(), dem = dem),
    "terrain fixture"           = list(x = terrain_fixture(), dem = dem),
    "no media column"           = list(x = film[, setdiff(names(film), "media")], dem = NULL),
    "empty input"               = list(x = digital_fixture()[0, ], dem = NULL)
  )
}


# Non-POINT inputs, for the geometry guard in test-fly_footprint_point_input.R.
#
# The suite is otherwise points-only, so nothing else in it can reach the guard —
# the same fixture blind spot as #35 on a different axis.
#
# All three shapes are built from the bundled centroids and keep every attribute
# column, `film_roll` and `frame_number` included. That matters: `fly_bearing()`
# checks for those columns BEFORE it touches geometry, so a fixture without them
# would error on the column check and the test would pass for the wrong reason.
#
# MULTIPOINT is the load-bearing case rather than a third example of the same
# thing. #37's suggested fix was `%in% c("POINT", "MULTIPOINT")`, and
# `st_coordinates()` expands a MULTIPOINT one row per constituent point exactly
# as it expands a POLYGON — so that guard reintroduces the bug it was written to
# stop. A fixture carrying only POLYGON passes against both the correct guard and
# the wrong one, and cannot tell them apart.
#
# `st_cast()` from the footprint polygons is what makes each case genuinely
# expanding (5 vertices per closed rectangle) rather than nominally non-POINT: a
# MULTIPOINT built by casting the centroids themselves holds one point each and
# would not multiply any rows.
non_point_cases <- function() {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  polygon <- suppressWarnings(fly_footprint(centroids))
  cases <- list(
    POLYGON    = polygon,
    # `st_cast()` warns that it repeats attributes across sub-geometries. That is
    # exactly what is wanted here — one non-POINT feature per original row — so
    # the warning is noise rather than signal.
    MULTIPOINT = suppressWarnings(sf::st_cast(polygon, "MULTIPOINT")),
    LINESTRING = suppressWarnings(sf::st_cast(polygon, "LINESTRING"))
  )
  # Premise, asserted rather than assumed: every case must actually expand, or it
  # is not reaching the failure the guard exists to prevent. Checked here so a
  # future sf that changes a cast fails naming the real cause.
  for (nm in names(cases)) {
    x <- cases[[nm]]
    stopifnot(
      nrow(x) == nrow(centroids),
      all(as.character(sf::st_geometry_type(x)) == nm),
      nrow(sf::st_coordinates(x)) > nrow(x),
      all(c("scale", "film_roll", "frame_number") %in% names(x))
    )
  }
  cases
}
