#' Trim floodplain to areas alongside target streams
#'
#' Uses flat-cap buffer to extend perpendicular to streams without extending
#' past stream endpoints. Optionally includes lake polygons to fill gaps where
#' lakes interrupt the stream network. Optionally adds a photo capture buffer.
#'
#' @param floodplain_sf An sf polygon — the floodplain or lateral habitat boundary.
#' @param streams_sf An sf linestring — pre-filtered streams (from
#'   [fly_query_habitat()] or any source).
#' @param lakes_sf An sf polygon — lake polygons to include (from
#'   [fly_query_lakes()] or any source). Fills gaps where lakes interrupt
#'   stream networks. `NULL` to skip.
#' @param floodplain_width Buffer distance (m) perpendicular to streams.
#'   Should capture the full floodplain width. Uses flat end caps.
#' @param photo_buffer Buffer (m) around trimmed floodplain for photo centroid
#'   capture. Set to 0 to return the trimmed floodplain only.
#' @return An sf polygon in WGS84 (EPSG:4326).
#'
#' @examples
#' streams <- sf::st_read(system.file("testdata/streams.gpkg", package = "fly"))
#' floodplain <- sf::st_read(system.file("testdata/floodplain.gpkg", package = "fly"))
#' trimmed <- fly_trim_habitat(floodplain, streams, photo_buffer = 0)
#' plot(sf::st_geometry(trimmed))
#'
#' @export
fly_trim_habitat <- function(
    floodplain_sf,
    streams_sf,
    lakes_sf = NULL,
    floodplain_width = 2000,
    photo_buffer = 1800
) {
  sf::sf_use_s2(FALSE)
  on.exit(sf::sf_use_s2(TRUE))

  streams_albers <- sf::st_transform(streams_sf, 3005)
  floodplain_albers <- sf::st_transform(floodplain_sf, 3005) |>
    sf::st_union() |>
    sf::st_make_valid()

  message("Buffering streams by ", floodplain_width, "m (flat cap)...")
  streams_buffered <- sf::st_buffer(streams_albers, dist = floodplain_width,
                                    endCapStyle = "FLAT") |>
    sf::st_union() |>
    sf::st_make_valid()

  if (!is.null(lakes_sf) && nrow(lakes_sf) > 0) {
    lakes_albers <- sf::st_transform(lakes_sf, 3005) |>
      sf::st_union() |>
      sf::st_make_valid()
    message("Including ", nrow(lakes_sf), " lake polygons...")
    streams_buffered <- sf::st_union(streams_buffered, lakes_albers) |>
      sf::st_make_valid()
  }

  message("Intersecting with floodplain...")
  trimmed <- sf::st_intersection(streams_buffered, floodplain_albers) |>
    sf::st_make_valid()

  if (photo_buffer > 0) {
    message("Adding ", photo_buffer, "m photo capture buffer...")
    result <- sf::st_buffer(trimmed, dist = photo_buffer) |>
      sf::st_make_valid()
  } else {
    result <- trimmed
  }

  result <- result |> sf::st_transform(4326)

  area_orig <- as.numeric(sf::st_area(floodplain_albers)) / 1e6
  area_trimmed <- as.numeric(sf::st_area(trimmed)) / 1e6
  area_final <- as.numeric(sum(sf::st_area(result))) / 1e6
  message("Original floodplain:  ", round(area_orig, 1), " km2")
  message("Trimmed floodplain:   ", round(area_trimmed, 1), " km2 (",
          round((1 - area_trimmed / area_orig) * 100), "% reduction)")
  if (photo_buffer > 0) {
    message("Photo capture zone:   ", round(area_final, 1), " km2")
  }

  sf::st_sf(geometry = sf::st_geometry(result))
}
