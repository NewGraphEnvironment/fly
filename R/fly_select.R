#' Select minimum photo set to cover an AOI (greedy set cover)
#'
#' Iteratively picks the photo whose footprint covers the most uncovered
#' area until the target coverage is reached.
#'
#' @param photos_sf An sf point object with a `scale` column
#'   (pre-filtered to target year/scale).
#' @param aoi_sf An sf polygon to cover.
#' @param target_coverage Stop when this fraction is reached (default 0.95).
#' @return An sf object (subset of `photos_sf`) with added columns
#'   `selection_order` and `cumulative_coverage_pct`.
#'
#' @examples
#' centroids <- sf::st_read(system.file("testdata/photo_centroids.gpkg", package = "fly"))
#' aoi <- sf::st_read(system.file("testdata/aoi.gpkg", package = "fly"))
#' selected <- fly_select(centroids, aoi, target_coverage = 0.80)
#' selected[, c("airp_id", "scale", "selection_order", "cumulative_coverage_pct")]
#'
#' @export
fly_select <- function(photos_sf, aoi_sf, target_coverage = 0.95) {
  sf::sf_use_s2(FALSE)
  on.exit(sf::sf_use_s2(TRUE))

  aoi_albers <- sf::st_transform(aoi_sf, 3005) |>
    sf::st_union() |>
    sf::st_make_valid()
  aoi_area <- as.numeric(sf::st_area(aoi_albers))

  footprints <- fly_footprint(photos_sf) |> sf::st_transform(3005)
  footprints$photo_idx <- seq_len(nrow(footprints))

  uncovered <- aoi_albers
  selected_idx <- integer(0)
  coverage_pcts <- numeric(0)
  covered_so_far <- sf::st_sfc(sf::st_polygon(), crs = 3005)

  message("Selecting photos (target: ", target_coverage * 100, "% coverage)...")

  while (TRUE) {
    remaining <- footprints[!footprints$photo_idx %in% selected_idx, ]
    if (nrow(remaining) == 0) break

    gains <- vapply(seq_len(nrow(remaining)), function(i) {
      fp <- sf::st_geometry(remaining[i, ])
      tryCatch({
        result <- sf::st_intersection(fp, uncovered) |> sf::st_make_valid()
        if (length(result) == 0) return(0)
        as.numeric(sf::st_area(sf::st_union(result)))
      }, error = function(e) 0)
    }, numeric(1))

    best <- which.max(gains)
    if (gains[best] <= 0) break

    best_idx <- remaining$photo_idx[best]
    selected_idx <- c(selected_idx, best_idx)

    best_fp <- sf::st_geometry(remaining[best, ])
    covered_so_far <- sf::st_union(covered_so_far, best_fp) |> sf::st_make_valid()
    covered_in_aoi <- tryCatch(
      sf::st_intersection(covered_so_far, aoi_albers) |> sf::st_make_valid(),
      error = function(e) covered_so_far
    )
    uncovered <- tryCatch(
      sf::st_difference(aoi_albers, covered_so_far) |> sf::st_make_valid(),
      error = function(e) aoi_albers
    )

    pct <- as.numeric(sf::st_area(covered_in_aoi)) / aoi_area
    coverage_pcts <- c(coverage_pcts, pct)

    if (length(selected_idx) %% 10 == 0 || pct >= target_coverage) {
      message("  ", length(selected_idx), " photos -> ", round(pct * 100, 1), "% coverage")
    }

    if (pct >= target_coverage) break
  }

  message("Selected ", length(selected_idx), " of ", nrow(photos_sf),
          " photos for ", round(coverage_pcts[length(coverage_pcts)] * 100, 1), "% coverage")

  result <- photos_sf[selected_idx, ]
  result$selection_order <- seq_along(selected_idx)
  result$cumulative_coverage_pct <- round(coverage_pcts * 100, 1)
  result
}
