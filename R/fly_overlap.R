#' Compute pairwise overlap between photo footprints
#'
#' For each pair of photos whose footprints intersect, computes the overlap
#' area and the percentage of each photo's footprint that overlaps.
#' Most useful on same-scale photos from the same flight.
#'
#' Overlap percentages are estimates based on flat-terrain footprints from
#' [fly_footprint()]. See that function for details on terrain limitations.
#'
#' @param photos_sf An sf point object with a `scale` column.
#' @return A tibble with columns `photo_a`, `photo_b`, `overlap_km2`,
#'   `pct_of_a`, and `pct_of_b`. Only pairs with non-zero overlap are returned.
#'
#' @examples
#' centroids <- sf::st_read(system.file("testdata/photo_centroids.gpkg", package = "fly"))
#' aoi <- sf::st_read(system.file("testdata/aoi.gpkg", package = "fly"))
#' photos_12k <- centroids[centroids$scale == "1:12000", ]
#' selected <- fly_select(photos_12k, aoi, mode = "all")
#' fly_overlap(selected)
#'
#' @export
fly_overlap <- function(photos_sf) {
  sf::sf_use_s2(FALSE)
  on.exit(sf::sf_use_s2(TRUE))

  footprints <- fly_footprint(photos_sf) |> sf::st_transform(3005)
  n <- nrow(footprints)

  if (n < 2) {
    return(dplyr::tibble(
      photo_a = integer(0), photo_b = integer(0),
      overlap_km2 = numeric(0), pct_of_a = numeric(0), pct_of_b = numeric(0)
    ))
  }

  fp_areas <- as.numeric(sf::st_area(footprints))
  pairs <- sf::st_intersects(footprints)

  ids <- if ("airp_id" %in% names(footprints)) {
    footprints$airp_id
  } else {
    seq_len(n)
  }

  results <- list()
  for (i in seq_len(n)) {
    neighbors <- pairs[[i]]
    neighbors <- neighbors[neighbors > i]
    if (length(neighbors) == 0) next

    for (j in neighbors) {
      overlap_geom <- tryCatch(
        sf::st_intersection(sf::st_geometry(footprints[i, ]),
                            sf::st_geometry(footprints[j, ])) |>
          sf::st_make_valid(),
        error = function(e) NULL
      )
      if (is.null(overlap_geom) || length(overlap_geom) == 0) next

      overlap_area <- as.numeric(sf::st_area(overlap_geom))
      if (overlap_area <= 0) next

      results <- c(results, list(dplyr::tibble(
        photo_a = ids[i],
        photo_b = ids[j],
        overlap_km2 = round(overlap_area / 1e6, 3),
        pct_of_a = round(overlap_area / fp_areas[i] * 100, 1),
        pct_of_b = round(overlap_area / fp_areas[j] * 100, 1)
      )))
    }
  }

  if (length(results) == 0) {
    return(dplyr::tibble(
      photo_a = integer(0), photo_b = integer(0),
      overlap_km2 = numeric(0), pct_of_a = numeric(0), pct_of_b = numeric(0)
    ))
  }

  dplyr::bind_rows(results)
}
