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
#' @param workers Number of parallel download workers. `1` (default) runs
#'   sequentially. Values greater than 1 use [furrr::future_map_dfr()] with
#'   [future::multisession] — requires `furrr` and `future` packages.
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
#' When `workers > 1`, a [future::multisession] plan is set for the
#' duration of the call and restored on exit. Each download is independent
#' so parallelism is safe.
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
                      dest_dir = "photos", overwrite = FALSE,
                      workers = 1) {
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

  rows <- lapply(seq_along(urls), function(i) {
    list(airp_id = ids[i], url = urls[i])
  })

  # Self-contained download function that workers can serialize
  dl_fn <- function(row) {
    airp_id <- row$airp_id
    u <- row$url

    if (is.na(u) || u == "") {
      return(dplyr::tibble(
        airp_id = airp_id, url = u,
        dest = NA_character_, success = FALSE
      ))
    }

    dest_file <- file.path(dest_dir, basename(u))

    if (!overwrite && file.exists(dest_file)) {
      return(dplyr::tibble(
        airp_id = airp_id, url = u,
        dest = dest_file, success = TRUE
      ))
    }

    ok <- tryCatch({
      utils::download.file(u, dest_file, mode = "wb", quiet = TRUE)
      file.exists(dest_file) && file.size(dest_file) > 0
    }, error = function(e) FALSE)

    dplyr::tibble(
      airp_id = airp_id, url = u,
      dest = dest_file, success = ok
    )
  }

  if (workers > 1) {
    rlang::check_installed(c("furrr", "future"),
                           reason = "for parallel downloads (workers > 1)")
    old_plan <- future::plan(future::multisession, workers = workers)
    on.exit(future::plan(old_plan), add = TRUE)
    results <- furrr::future_map_dfr(rows, dl_fn,
      .options = furrr::furrr_options(packages = "dplyr"))
  } else {
    results <- purrr::map_dfr(rows, dl_fn)
  }

  n_ok <- sum(results$success)
  n_skip <- sum(is.na(results$url) | results$url == "")
  message("Downloaded ", n_ok, " of ", nrow(results), " files",
          if (n_skip > 0) paste0(" (", n_skip, " skipped, no URL)") else "")

  results
}
