#' Download airphoto files from BC Data Catalogue URLs
#'
#' Downloads thumbnail images, flight logs, camera calibration reports, or
#' geo-referencing files for selected airphotos. The URL columns must be
#' present in the input data (available from the full BC Data Catalogue
#' centroid layer).
#'
#' @param photos_sf An sf object with airphoto metadata, typically output
#'   from [fly_select()] or [fly_filter()]. Must contain the relevant URL
#'   column for the requested `type`.
#' @param type File type to download. One of `"thumbnail"`,
#'   `"flight_log"`, `"calibration"`, or `"georef"`.
#' @param dest_dir Directory to save downloaded files. Created if it does
#'   not exist.
#' @param overwrite If `FALSE` (default), skip files that already exist
#'   in `dest_dir`.
#' @return A tibble with columns `airp_id`, `url`, `dest`, and `success`.
#'
#' @details
#' URL column mapping:
#' \itemize{
#'   \item `"thumbnail"` → `thumbnail_image_url`
#'   \item `"flight_log"` → `flight_log_url`
#'   \item `"calibration"` → `camera_calibration_url`
#'   \item `"georef"` → `patb_georef_url`
#' }
#'
#' Photos with missing (`NA` or empty) URLs are skipped and reported as
#' `success = FALSE` in the output.
#'
#' @examples
#' centroids <- sf::st_read(system.file("testdata/photo_centroids.gpkg", package = "fly"))
#'
#' # Download thumbnails for first 2 photos
#' result <- fly_fetch(centroids[1:2, ], type = "thumbnail",
#'                     dest_dir = tempdir())
#' result
#'
#' @export
fly_fetch <- function(photos_sf, type = "thumbnail",
                         dest_dir = "photos", overwrite = FALSE) {
  type <- match.arg(type, c("thumbnail", "flight_log", "calibration", "georef"))

  url_col <- switch(type,
    thumbnail   = "thumbnail_image_url",
    flight_log  = "flight_log_url",
    calibration = "camera_calibration_url",
    georef      = "patb_georef_url"
  )

  if (!url_col %in% names(photos_sf)) {
    stop("Column `", url_col, "` not found in input data. ",
         "Use full BC Data Catalogue centroid data to get URL columns.",
         call. = FALSE)
  }

  dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)

  urls <- photos_sf[[url_col]]
  ids <- if ("airp_id" %in% names(photos_sf)) {
    photos_sf[["airp_id"]]
  } else {
    seq_len(nrow(photos_sf))
  }

  results <- dplyr::tibble(
    airp_id = ids,
    url     = urls,
    dest    = NA_character_,
    success = FALSE
  )

  for (i in seq_len(nrow(results))) {
    u <- results$url[i]
    if (is.na(u) || u == "") next

    dest_file <- file.path(dest_dir, basename(u))
    results$dest[i] <- dest_file

    if (!overwrite && file.exists(dest_file)) {
      results$success[i] <- TRUE
      next
    }

    results$success[i] <- tryCatch({
      utils::download.file(u, dest_file, mode = "wb", quiet = TRUE)
      file.exists(dest_file) && file.size(dest_file) > 0
    }, error = function(e) FALSE)
  }

  n_ok <- sum(results$success)
  n_skip <- sum(is.na(results$url) | results$url == "")
  message("Downloaded ", n_ok, " of ", nrow(results), " files",
          if (n_skip > 0) paste0(" (", n_skip, " skipped, no URL)") else "")

  results
}
