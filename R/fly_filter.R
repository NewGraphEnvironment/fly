#' Filter photos by spatial relationship with an AOI
#'
#' Subsets photos whose footprint or centroid intersects the area of interest.
#' The footprint method catches photos whose centroid falls outside the AOI
#' but whose ground coverage overlaps it.
#'
#' @param photos_sf An sf point object with a `scale` column.
#' @param aoi_sf An sf polygon defining the area of interest.
#' @param method One of `"footprint"` (default) or `"centroid"`.
#' @param buffer Buffer distance in metres added to the AOI before testing
#'   intersection (default 0). Applied in BC Albers (EPSG:3005).
#' @return A subset of `photos_sf` that intersects the AOI.
#'
#' @examples
#' centroids <- sf::st_read(system.file("testdata/photo_centroids.gpkg", package = "fly"))
#' aoi <- sf::st_read(system.file("testdata/aoi.gpkg", package = "fly"))
#' # Footprint method finds more photos than centroid method
#' fp_result <- fly_filter(centroids, aoi, method = "footprint")
#' ct_result <- fly_filter(centroids, aoi, method = "centroid")
#' nrow(fp_result) >= nrow(ct_result)
#'
#' @export
fly_filter <- function(photos_sf, aoi_sf, method = c("footprint", "centroid"), buffer = 0) {
  method <- match.arg(method)

  aoi_3005 <- sf::st_transform(aoi_sf, 3005) |>
    sf::st_union() |>
    sf::st_make_valid()

  if (buffer > 0) {
    aoi_3005 <- sf::st_buffer(aoi_3005, buffer) |> sf::st_make_valid()
  }

  aoi_test <- sf::st_transform(aoi_3005, sf::st_crs(photos_sf)) |> sf::st_make_valid()

  if (method == "centroid") {
    hits <- sf::st_intersects(photos_sf, aoi_test, sparse = FALSE)[, 1]
  } else {
    footprints <- fly_footprint(photos_sf)
    hits <- sf::st_intersects(footprints, aoi_test, sparse = FALSE)[, 1]
  }

  photos_sf[hits, ]
}
