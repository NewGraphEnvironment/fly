#' Select photos covering an AOI
#'
#' Two modes: `"minimal"` picks the fewest photos to reach target coverage
#' (greedy set-cover); `"all"` returns every photo whose footprint intersects
#' the AOI.
#'
#' @param photos_sf An sf point object with a `scale` column
#'   (pre-filtered to target year/scale).
#' @param aoi_sf An sf polygon to cover.
#' @param mode Either `"minimal"` (fewest photos to reach target) or `"all"`
#'   (every photo touching the AOI).
#' @param target_coverage Stop when this fraction is reached (default 0.95).
#'   Only used when `mode = "minimal"`.
#' @param ensure_components If `TRUE` (default `FALSE`), guarantee that every
#'   polygon component of `aoi_sf` is covered by at least one photo before
#'   running the greedy selection. Useful for multi-polygon AOIs (e.g. patchy
#'   floodplain fragments) where small components might otherwise get zero
#'   coverage. Only used when `mode = "minimal"`.
#' @return An sf object (subset of `photos_sf`). For `mode = "minimal"`,
#'   includes `selection_order` and `cumulative_coverage_pct` columns.
#'
#' @examples
#' centroids <- sf::st_read(system.file("testdata/photo_centroids.gpkg", package = "fly"))
#' aoi <- sf::st_read(system.file("testdata/aoi.gpkg", package = "fly"))
#'
#' # Fewest photos to reach 80% coverage
#' fly_select(centroids, aoi, mode = "minimal", target_coverage = 0.80)
#'
#' # Ensure every AOI component gets at least one photo
#' fly_select(centroids, aoi, mode = "minimal", target_coverage = 0.80,
#'            ensure_components = TRUE)
#'
#' # All photos touching the AOI
#' fly_select(centroids, aoi, mode = "all")
#'
#' @export
fly_select <- function(photos_sf, aoi_sf, mode = "minimal",
                       target_coverage = 0.95,
                       ensure_components = FALSE) {
  mode <- match.arg(mode, c("minimal", "all"))

  if (mode == "all") {
    return(fly_select_all(photos_sf, aoi_sf))
  }

  fly_select_minimal(photos_sf, aoi_sf, target_coverage, ensure_components)
}

#' @noRd
fly_select_all <- function(photos_sf, aoi_sf) {
  sf::sf_use_s2(FALSE)
  on.exit(sf::sf_use_s2(TRUE))

  footprints <- fly_footprint(photos_sf)
  aoi_union <- sf::st_transform(aoi_sf, sf::st_crs(footprints)) |>
    sf::st_union() |>
    sf::st_make_valid()

  touches <- sf::st_intersects(footprints, aoi_union, sparse = FALSE)[, 1]
  result <- photos_sf[touches, ]
  message("Selected ", nrow(result), " of ", nrow(photos_sf),
          " photos intersecting the AOI")
  result
}

#' Pick one photo per uncovered AOI component
#'
#' For each polygon component that has no coverage yet, find the photo whose
#' footprint covers the most area of that component.
#' @noRd
ensure_component_coverage <- function(footprints, aoi_albers) {
  components <- sf::st_cast(aoi_albers, "POLYGON")
  must_keep <- integer(0)

  for (k in seq_along(components)) {
    comp <- components[k]
    hits <- sf::st_intersects(footprints, comp, sparse = FALSE)[, 1]
    if (!any(hits)) next

    candidates <- footprints[hits, ]
    areas <- vapply(seq_len(nrow(candidates)), function(i) {
      tryCatch({
        isect <- sf::st_intersection(
          sf::st_geometry(candidates[i, ]), comp
        ) |> sf::st_make_valid()
        if (length(isect) == 0) return(0)
        as.numeric(sf::st_area(isect))
      }, error = function(e) 0)
    }, numeric(1))

    if (max(areas) > 0) {
      best <- candidates$photo_idx[which.max(areas)]
      must_keep <- c(must_keep, best)
    }
  }

  unique(must_keep)
}

#' @noRd
fly_select_minimal <- function(photos_sf, aoi_sf, target_coverage,
                               ensure_components) {
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

  # Seed with must-keep photos for component coverage
  if (ensure_components) {
    seed_idx <- ensure_component_coverage(footprints, aoi_albers)
    if (length(seed_idx) > 0) {
      message("Seeding ", length(seed_idx),
              " photos for component coverage...")
      for (idx in seed_idx) {
        selected_idx <- c(selected_idx, idx)
        fp <- sf::st_geometry(footprints[footprints$photo_idx == idx, ])
        covered_so_far <- sf::st_union(covered_so_far, fp) |>
          sf::st_make_valid()
        covered_in_aoi <- tryCatch(
          sf::st_intersection(covered_so_far, aoi_albers) |>
            sf::st_make_valid(),
          error = function(e) covered_so_far
        )
        uncovered <- tryCatch(
          sf::st_difference(aoi_albers, covered_so_far) |>
            sf::st_make_valid(),
          error = function(e) aoi_albers
        )
        pct <- sum(as.numeric(sf::st_area(covered_in_aoi))) / aoi_area
        coverage_pcts <- c(coverage_pcts, pct)
      }
      message("  ", length(selected_idx), " seed photos -> ",
              round(coverage_pcts[length(coverage_pcts)] * 100, 1),
              "% coverage")
    }
  }

  message("Selecting photos (target: ", target_coverage * 100, "% coverage)...")

  while (TRUE) {
    cur_pct <- if (length(coverage_pcts) > 0) {
      coverage_pcts[length(coverage_pcts)]
    } else {
      0
    }
    if (cur_pct >= target_coverage) break

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

    pct <- sum(as.numeric(sf::st_area(covered_in_aoi))) / aoi_area
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
