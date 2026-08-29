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
