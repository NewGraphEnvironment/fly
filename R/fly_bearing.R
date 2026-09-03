#' Compute flight line bearing from consecutive airphoto centroids
#'
#' Estimates the flight direction for each photo by computing the azimuth
#' between consecutive centroids on the same film roll, sorted by frame
#' number. Useful for diagnosing image rotation issues in [fly_georef()].
#'
#' @param photos_sf An sf point object with `film_roll` and `frame_number`
#'   columns. Projected to BC Albers (EPSG:3005) internally for metric
#'   bearing computation.
#'   Geometry must be POINT. Handed footprints this returned the right *number*
#'   of bearings with the wrong values, so it is refused rather than coerced.
#' @return The input sf object with an added `bearing` column (degrees
#'   clockwise from north, 0–360). Photos with no **adjacent** frame on the
#'   same roll get `NA` — a single-frame roll, and any frame whose
#'   neighbours in the supplied object are more than one frame number away.
#'
#' @details
#' Within each roll, frames are sorted by `frame_number`. The bearing for each
#' frame is the azimuth to the next frame on the same roll, and the last frame
#' of an adjacent run takes the bearing from the previous one.
#'
#' **The neighbour must be adjacent by frame number.** Aerial survey flights
#' follow back-and-forth patterns, so a roll holds several legs; two frames that
#' merely sit next to each other in a *sample* of a roll may be on different
#' legs, and the azimuth between those is a cross-leg artefact rather than a
#' heading. In the bundled test data, bc5282 frames 179 and 199 are 20 apart and
#' 3.3 footprint-sides apart, and pairing them gives 59.8° on a roll that flies
#' about 230°.
#'
#' So a gap of more than one frame yields `NA`. This is deliberately strict:
#' adjacency is demonstrable, whereas "close enough to be on the same line"
#' needs a threshold in footprint-sides that this function cannot measure. Since
#' [fly_footprint()] rotates a footprint onto this bearing, an `NA` costs an
#' axis-aligned rectangle while a wrong azimuth costs a rectangle confidently
#' rotated onto ground the frame does not cover.
#'
#' To keep bearings across a subset, call `fly_bearing()` on the contiguous roll
#' first and carry the column: subsetting removes neighbours, and a frame whose
#' neighbour was dropped has no adjacent one left.
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
  # Handed footprints this returned the right NUMBER of bearings with the wrong
  # values - it indexes a 5n-row coordinate matrix with a permutation of 1:n - so
  # nothing downstream could tell. See fly#37.
  fly_check_points(photos_sf, "photos_sf")

  # Project to BC Albers for metric bearing
  proj <- sf::st_transform(photos_sf, 3005)
  coords <- sf::st_coordinates(proj)

  # Sort index by roll + frame

  ord <- order(photos_sf$film_roll, photos_sf$frame_number)

  # `isTRUE()` on the roll comparisons below, rather than a bare `==`: an NA in
  # `film_roll` makes the comparison NA, which aborts an `if` with "missing value where
  # TRUE/FALSE needed". A frame with no roll simply has no neighbour to take a bearing
  # from, which is what NA already means here.
  bearing <- rep(NA_real_, nrow(photos_sf))

  rolls <- photos_sf$film_roll[ord]
  frames <- suppressWarnings(as.numeric(photos_sf$frame_number))[ord]
  x <- coords[ord, 1]
  y <- coords[ord, 2]

  # A neighbour is only usable if its frame number is ADJACENT. Two frames that merely
  # sit next to each other in the supplied object may be on different legs of the same
  # roll, and the azimuth between those is a cross-leg artefact, not a heading. In the
  # bundled sample bc5282 frames 179 and 199 are 20 apart and 3.3 footprint-sides apart,
  # and pairing them yields 59.8 degrees on a roll that flies about 230.
  #
  # This used to be harmless: nothing consumed `bearing` until #32, and #32 applied it
  # only to digital frames. fly#26 rotates film onto it too, so a wrong azimuth now
  # rotates a footprint bodily. Refusing is the same choice #30 made for an unknown
  # recording format — an NA that reports itself beats a plausible number that does not.
  #
  # Adjacency is *demonstrable*; "close enough to be on one line" would need a threshold
  # in footprint-sides that nothing here can measure. So a gap of more than one frame
  # yields NA, and the frame is drawn axis-aligned exactly as before.
  adjacent <- function(a, b) isTRUE(rolls[a] == rolls[b]) &&
    isTRUE(abs(frames[b] - frames[a]) == 1)

  for (i in seq_along(ord)) {
    if (i < length(ord) && adjacent(i, i + 1)) {
      # Forward bearing to next frame on same roll
      dx <- x[i + 1] - x[i]
      dy <- y[i + 1] - y[i]
      bearing[ord[i]] <- (atan2(dx, dy) * 180 / pi) %% 360
    } else if (i > 1 && adjacent(i, i - 1)) {
      # Last frame of an adjacent run: use the bearing from the previous frame
      dx <- x[i] - x[i - 1]
      dy <- y[i] - y[i - 1]
      bearing[ord[i]] <- (atan2(dx, dy) * 180 / pi) %% 360
    }
    # else: no adjacent neighbour on this roll, stays NA
  }

  photos_sf$bearing <- bearing
  photos_sf
}
