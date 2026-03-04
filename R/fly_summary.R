#' Summarize photo footprint sizes and date ranges by scale
#'
#' @param photos_sf An sf point object with `scale` and `photo_year` columns.
#' @param negative_size Negative dimension in inches (default 9).
#' @return A tibble with columns: `scale`, `photos`, `footprint_m`, `half_m`,
#'   `year_min`, `year_max`.
#'
#' @examples
#' centroids <- sf::st_read(system.file("testdata/photo_centroids.gpkg", package = "fly"))
#' fly_summary(centroids)
#'
#' @export
fly_summary <- function(photos_sf, negative_size = 9) {
  photos_sf |>
    sf::st_drop_geometry() |>
    dplyr::mutate(
      scale_num = as.numeric(gsub(".*:", "", .data$scale)),
      footprint_m = round(.data$scale_num * 0.0254 * negative_size),
      half_m = round(.data$footprint_m / 2)
    ) |>
    dplyr::group_by(.data$scale) |>
    dplyr::summarise(
      photos = dplyr::n(),
      footprint_m = dplyr::first(.data$footprint_m),
      half_m = dplyr::first(.data$half_m),
      year_min = min(.data$photo_year, na.rm = TRUE),
      year_max = max(.data$photo_year, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::arrange(.data$footprint_m)
}
