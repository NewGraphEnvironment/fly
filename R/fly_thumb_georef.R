#' Georeference downloaded thumbnails to footprint polygons
#'
#' Warps thumbnail images to their estimated ground footprint using GCPs
#' (ground control points) derived from [fly_footprint()]. Produces
#' georeferenced GeoTIFFs in BC Albers (EPSG:3005).
#'
#' @param fetch_result A tibble returned by [fly_fetch()], with columns
#'   `airp_id`, `dest`, and `success`.
#' @param photos_sf The same sf object passed to `fly_fetch()`, with a
#'   `scale` column for footprint estimation.
#' @param dest_dir Directory for output GeoTIFFs. Created if it does not
#'   exist.
#' @param overwrite If `FALSE` (default), skip files that already exist.
#' @return A tibble with columns `airp_id`, `source`, `dest`, and `success`.
#'
#' @details
#' Each thumbnail's four corners are mapped to the corresponding footprint
#' polygon corners computed by [fly_footprint()] in BC Albers. GDAL
#' translates the image with GCPs then warps to the target CRS using
#' bilinear resampling.
#'
#' **Nodata handling:** Band count is read from each file header. RGB
#' thumbnails (3+ bands) get an alpha band (`-dstalpha`) for clean masking
#' in mosaics. Grayscale thumbnails (1 band) use nodata=0 — some shadow
#' detail is lost but black borders are eliminated.
#'
#' **Accuracy:** footprints assume flat terrain and nadir camera angle.
#' The georeferenced thumbnails are approximate — useful for visual context,
#' not survey-grade positioning. See [fly_footprint()] for details on
#' limitations.
#'
#' @examples
#' centroids <- sf::st_read(system.file("testdata/photo_centroids.gpkg", package = "fly"))
#'
#' # Fetch and georeference first 2 thumbnails
#' fetched <- fly_fetch(centroids[1:2, ], type = "thumbnail",
#'                      dest_dir = tempdir())
#' georef <- fly_thumb_georef(fetched, centroids[1:2, ],
#'                            dest_dir = tempdir())
#' georef
#'
#' @export
fly_thumb_georef <- function(fetch_result, photos_sf,
                             dest_dir = "georef", overwrite = FALSE) {
  if (!all(c("airp_id", "dest", "success") %in% names(fetch_result))) {
    stop("`fetch_result` must be output from `fly_fetch()`.", call. = FALSE)
  }

  dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)

  # Build footprints in BC Albers
  footprints <- fly_footprint(photos_sf) |> sf::st_transform(3005)

  # Match fetch results to photos by airp_id
  ids <- fetch_result$airp_id

  results <- dplyr::tibble(
    airp_id = ids,
    source  = fetch_result$dest,
    dest    = NA_character_,
    success = FALSE
  )

  for (i in seq_len(nrow(results))) {
    if (!fetch_result$success[i]) next
    src <- results$source[i]
    if (is.na(src) || !file.exists(src)) next

    out_file <- file.path(dest_dir,
                          sub("\\.[^.]+$", ".tif", basename(src)))
    results$dest[i] <- out_file

    if (!overwrite && file.exists(out_file)) {
      results$success[i] <- TRUE
      next
    }

    # Find matching footprint
    fp_idx <- which(photos_sf[["airp_id"]] == results$airp_id[i])
    if (length(fp_idx) == 0) next
    fp <- footprints[fp_idx[1], ]

    results$success[i] <- tryCatch(
      georef_one(src, fp, out_file),
      error = function(e) {
        message("Failed to georef ", basename(src), ": ", e$message)
        FALSE
      }
    )
  }

  n_ok <- sum(results$success)
  message("Georeferenced ", n_ok, " of ", nrow(results), " thumbnails")
  results
}

#' Georeference a single thumbnail to a footprint polygon
#' @noRd
georef_one <- function(src, fp, out_file) {
  # Get footprint corner coordinates
  # fly_footprint builds: BL, BR, TR, TL, BL (closing)
  coords <- sf::st_coordinates(fp)[1:4, , drop = FALSE]

  # Read image dimensions and band count via GDAL
  info <- sf::gdal_utils("info", source = src, quiet = TRUE)
  dims <- regmatches(info, regexpr("Size is \\d+, \\d+", info))
  if (length(dims) == 0) return(FALSE)
  px <- as.integer(strsplit(sub("Size is ", "", dims), ", ")[[1]])
  ncol_px <- px[1]
  nrow_px <- px[2]

  # Count bands from "Band N" lines
  n_bands <- length(gregexpr("Band \\d+", info)[[1]])
  is_rgb <- n_bands >= 3

  # Map pixel corners to footprint corners
  # Pixel: TL=(0,0), TR=(ncol,0), BR=(ncol,nrow), BL=(0,nrow)
  # Footprint coords: [1]=BL, [2]=BR, [3]=TR, [4]=TL
  gcp_args <- c(
    "-gcp", 0,       0,       coords[4, 1], coords[4, 2],
    "-gcp", ncol_px, 0,       coords[3, 1], coords[3, 2],
    "-gcp", ncol_px, nrow_px, coords[2, 1], coords[2, 2],
    "-gcp", 0,       nrow_px, coords[1, 1], coords[1, 2]
  )

  # Step 1: translate with GCPs
  tmp_file <- tempfile(fileext = ".tif")
  on.exit(unlink(tmp_file), add = TRUE)

  sf::gdal_utils("translate",
    source = src,
    destination = tmp_file,
    options = c("-a_srs", "EPSG:3005", gcp_args)
  )

  # Step 2: warp to target CRS with nodata handling
  # RGB: add alpha band (-dstalpha) for clean masking in mosaics
  # Grayscale: set nodata=0 (losing some shadow detail is acceptable)
  warp_opts <- c("-t_srs", "EPSG:3005", "-r", "bilinear")
  if (is_rgb) {
    warp_opts <- c(warp_opts, "-dstalpha")
  } else {
    warp_opts <- c(warp_opts, "-dstnodata", "0")
  }

  sf::gdal_utils("warp",
    source = tmp_file,
    destination = out_file,
    options = warp_opts
  )

  file.exists(out_file) && file.size(out_file) > 0
}
