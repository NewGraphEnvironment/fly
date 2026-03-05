#' Estimate photo footprint polygons from centroids and scale
#'
#' Creates rectangular polygons representing the estimated ground coverage
#' of each airphoto, based on film negative dimensions and the reported scale.
#'
#' @param centroids_sf An sf point object with a `scale` column (e.g. "1:31680").
#' @param negative_size Negative dimension in inches (default 9 for standard 9" x 9").
#' @return An sf polygon object in the same CRS as input, with footprint rectangles.
#'
#' @details
#' Ground coverage is computed as `negative_size * scale_number * 0.0254` metres
#' per side. Rectangles are constructed in BC Albers (EPSG:3005) for accurate
#' metric distances, then transformed back to the input CRS.
#'
#' The scale denominator is parsed from the `scale` column string (e.g.
#' `"1:12000"` becomes `12000`).
#'
#' **9x9 assumption:** the default `negative_size = 9` (inches) reflects the
#' standard 228 mm format used by BC aerial survey cameras (e.g. Wild RC-10,
#' Zeiss RMK). The BC Air Photo Database records camera focal length per roll
#' (Type 02 field 3.2.2) but this is not available in the simplified centroid
#' data from the catalogue. If working with non-standard format photography,
#' override `negative_size` accordingly.
#'
#' **Flat-terrain assumption:** footprints are estimated assuming flat ground
#' beneath the aircraft. In reality terrain slope changes the actual ground
#' coverage — downhill slopes increase the true footprint (ground falls away
#' from the camera), while uphill slopes reduce it. In steep terrain typical
#' of BC valleys, true footprints may differ meaningfully from these estimates.
#' Coverage and overlap calculations downstream (e.g. [fly_coverage()],
#' [fly_overlap()]) inherit this limitation.
#'
#' @examples
#' centroids <- sf::st_read(system.file("testdata/photo_centroids.gpkg", package = "fly"))
#' footprints <- fly_footprint(centroids)
#' plot(sf::st_geometry(footprints))
#'
#' @export
fly_footprint <- function(centroids_sf, negative_size = 9) {
  if (!inherits(centroids_sf, "sf")) {
    stop("`centroids_sf` must be an sf object.", call. = FALSE)
  }
  if (!"scale" %in% names(centroids_sf)) {
    stop("`centroids_sf` must have a `scale` column (e.g. '1:31680').", call. = FALSE)
  }

  input_crs <- sf::st_crs(centroids_sf)
  pts_3005 <- sf::st_transform(centroids_sf, 3005)
  coords <- sf::st_coordinates(pts_3005)
  scale_num <- as.numeric(stringr::str_remove(centroids_sf$scale, "1:"))
  half_side <- negative_size * scale_num * 0.0254 / 2

  polys <- lapply(seq_len(nrow(coords)), function(i) {
    cx <- coords[i, 1]
    cy <- coords[i, 2]
    w <- half_side[i]
    corners <- matrix(c(
      cx - w, cy - w,
      cx + w, cy - w,
      cx + w, cy + w,
      cx - w, cy + w,
      cx - w, cy - w
    ), ncol = 2, byrow = TRUE)
    sf::st_polygon(list(corners))
  })

  result <- sf::st_sf(
    sf::st_drop_geometry(pts_3005),
    geometry = sf::st_sfc(polys, crs = 3005)
  )

  sf::st_transform(result, input_crs)
}
