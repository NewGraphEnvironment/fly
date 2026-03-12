#' Compute flight line bearing from consecutive airphoto centroids
#'
#' Estimates the flight direction for each photo by computing the azimuth
#' between consecutive centroids on the same film roll, sorted by frame
#' number. Useful for diagnosing image rotation issues in [fly_georef()].
#'
#' @param photos_sf An sf object with `film_roll` and `frame_number`
#'   columns. Projected to BC Albers (EPSG:3005) internally for metric
#'   bearing computation.
#' @return The input sf object with an added `bearing` column (degrees
#'   clockwise from north, 0–360). Photos with no computable bearing
#'   (single-frame rolls) get `NA`.
#'
#' @details
#' Within each roll, frames are sorted by `frame_number`. The bearing
#' for each frame is the azimuth to the next frame on the same roll.
#' The last frame on each roll gets the bearing from the previous frame.
#'
#' Aerial survey flights follow back-and-forth patterns, so bearings
#' alternate between ~opposite directions (e.g., 90° and 270°) on
#' consecutive legs. Large frame number gaps may indicate a new flight
#' line within the same roll.
#'
#' @examples
#' centroids <- sf::st_read(system.file("testdata/photo_centroids.gpkg", package = "fly"))
#' with_bearing <- fly_bearing(centroids)
#' with_bearing[, c("film_roll", "frame_number", "bearing")]
#'
#' @export
fly_bearing <- function(photos_sf) {
  if (!all(c("film_roll", "frame_number") %in% names(photos_sf))) {
    stop("`photos_sf` must have `film_roll` and `frame_number` columns.",
         call. = FALSE)
  }

  # Project to BC Albers for metric bearing
  proj <- sf::st_transform(photos_sf, 3005)
  coords <- sf::st_coordinates(proj)

  # Sort index by roll + frame

  ord <- order(photos_sf$film_roll, photos_sf$frame_number)

  bearing <- rep(NA_real_, nrow(photos_sf))

  rolls <- photos_sf$film_roll[ord]
  x <- coords[ord, 1]
  y <- coords[ord, 2]

  for (i in seq_along(ord)) {
    if (i < length(ord) && rolls[i] == rolls[i + 1]) {
      # Forward bearing to next frame on same roll
      dx <- x[i + 1] - x[i]
      dy <- y[i + 1] - y[i]
      bearing[ord[i]] <- (atan2(dx, dy) * 180 / pi) %% 360
    } else if (i > 1 && rolls[i] == rolls[i - 1]) {
      # Last frame on roll: use bearing from previous
      dx <- x[i] - x[i - 1]
      dy <- y[i] - y[i - 1]
      bearing[ord[i]] <- (atan2(dx, dy) * 180 / pi) %% 360
    }
    # else: single-frame roll, stays NA
  }

  photos_sf$bearing <- bearing
  photos_sf
}
