#' Check photo coverage of an AOI by group
#'
#' Builds footprint polygons for each photo, intersects with the AOI, and
#' reports percent coverage grouped by a column.
#'
#' @param photos_sf An sf point object with a `scale` column.
#' @param aoi_sf An sf polygon to check coverage against.
#' @param by Column name to group by (default `"photo_year"`).
#' @return A tibble with the grouping column, `n_photos`, `covered_km2`,
#'   and `coverage_pct`.
#'
#' @examples
#' centroids <- sf::st_read(system.file("testdata/photo_centroids.gpkg", package = "fly"))
#' aoi <- sf::st_read(system.file("testdata/aoi.gpkg", package = "fly"))
#' fly_coverage(centroids, aoi, by = "scale")
#'
#' @export
fly_coverage <- function(photos_sf, aoi_sf, by = "photo_year") {
  sf::sf_use_s2(FALSE)
  on.exit(sf::sf_use_s2(TRUE))

  aoi_albers <- sf::st_transform(aoi_sf, 3005) |>
    sf::st_union() |>
    sf::st_make_valid()
  aoi_area <- as.numeric(sf::st_area(aoi_albers))

  photos_with_fp <- photos_sf
  photos_with_fp$footprint_geom <- sf::st_geometry(
    fly_footprint(photos_sf) |> sf::st_transform(3005)
  )

  groups <- sort(unique(photos_with_fp[[by]]))

  results <- purrr::map_dfr(groups, function(grp) {
    grp_data <- photos_with_fp[photos_with_fp[[by]] == grp, ]
    fp_union <- tryCatch(
      sf::st_union(grp_data$footprint_geom) |>
        sf::st_buffer(0) |>
        sf::st_make_valid(),
      error = function(e) {
        grp_data$footprint_geom |>
          sf::st_buffer(0.1) |>
          sf::st_union() |>
          sf::st_buffer(-0.1) |>
          sf::st_make_valid()
      }
    )
    covered <- tryCatch(
      sf::st_intersection(fp_union, aoi_albers) |> sf::st_make_valid(),
      error = function(e) {
        sf::st_intersection(sf::st_buffer(fp_union, 0),
                            sf::st_buffer(aoi_albers, 0)) |>
          sf::st_make_valid()
      }
    )
    covered_area <- as.numeric(sf::st_area(covered))
    dplyr::tibble(
      !!by := grp,
      n_photos = nrow(grp_data),
      covered_km2 = round(covered_area / 1e6, 1),
      coverage_pct = round(covered_area / aoi_area * 100, 1)
    )
  })

  results
}
