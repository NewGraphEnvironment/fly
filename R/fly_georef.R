#' Georeference airphoto images to footprint polygons
#'
#' Warps images to their estimated ground footprint using GCPs (ground control
#' points) derived from [fly_footprint()]. Produces georeferenced GeoTIFFs in
#' BC Albers (EPSG:3005). Works with thumbnails and full-resolution scans.
#'
#' @param fetch_result A tibble returned by [fly_fetch()], with columns
#'   `airp_id`, `dest`, and `success`.
#' @param photos_sf The same sf object passed to `fly_fetch()`, with a
#'   `scale` column for footprint estimation. If a `rotation` column is
#'   present, per-photo rotation values are used (see **Rotation** below).
#' @param dest_dir Directory for output GeoTIFFs. Created if it does not
#'   exist.
#' @param overwrite If `FALSE` (default), skip files that already exist.
#' @param srcnodata Source nodata value passed to GDAL warp. Black pixels
#'   matching this value are treated as transparent (alpha=0 for RGB,
#'   nodata for grayscale). Default `"0"` masks camera frame borders and
#'   film holder edges at the cost of losing real black pixels — acceptable
#'   for thumbnails but may need adjustment for full-resolution scans.
#'   Set to `NULL` to disable source nodata detection entirely.
#' @param rotation Image rotation in degrees clockwise. One of `"auto"`,
#'   `0`, `90`, `180`, or `270`. `"auto"` (default) computes flight line
#'   bearing from consecutive centroids and derives rotation per-photo —
#'   requires `film_roll` and `frame_number` columns. Fixed values apply
#'   the same rotation to all photos. Overridden per-photo if `photos_sf`
#'   contains a `rotation` column.
#' @return A tibble with columns `airp_id`, `source`, `dest`, and `success`.
#'
#' @details
#' Each image's four corners are mapped to the corresponding footprint
#' polygon corners computed by [fly_footprint()] in BC Albers. GDAL
#' translates the image with GCPs then warps to the target CRS using
#' bilinear resampling.
#'
#' **Rotation:** Aerial photos may appear rotated in their footprints
#' because the camera orientation relative to north varies by flight
#' direction, camera mounting, and scanner orientation. The `rotation`
#' parameter rotates the GCP corner mapping:
#' \itemize{
#'   \item `0` — top of image maps to north edge of footprint (original behavior)
#'   \item `90` — top of image maps to east edge (90° clockwise)
#'   \item `180` — top of image maps to south edge (default, correct for most BC photos)
#'   \item `270` — top of image maps to west edge
#' }
#'
#' When `rotation = "auto"`, the bearing-to-rotation formula is:
#' `floor((bearing + 91) / 90) * 90 %% 360`. This was calibrated on
#' BC aerial photos spanning 1968–2019 across multiple camera systems
#' and scanners. Photos on diagonal flight lines (~45° off cardinal)
#' may be imperfect — check visually and override with a `rotation`
#' column if needed.
#'
#' Within a film roll, consecutive flight legs alternate direction
#' (back-and-forth pattern), so different frames on the same roll may
#' need different rotations. This is why `"auto"` computes per-photo,
#' not per-roll. To override, add a `rotation` column to `photos_sf`:
#' ```
#' photos$rotation <- dplyr::case_when(
#'   photos$film_roll == "bc5282" ~ 270,
#'   .default = NA  # fall through to auto
#' )
#' ```
#'
#' **Nodata handling:** Two sources of unwanted black pixels are masked:
#'
#' 1. **Warp fill** — GDAL creates black pixels outside the rotated source
#'    frame. RGB images get an alpha band (`-dstalpha`); grayscale use
#'    `dstnodata=0`.
#' 2. **Camera frame borders** — film holder edges, fiducial marks, and
#'    scanning artifacts produce black (value 0) pixels within the source
#'    image. The `srcnodata` parameter (default `"0"`) tells GDAL to treat
#'    these as transparent before warping.
#'
#' **Tradeoff:** `srcnodata = "0"` also masks real black pixels (deep
#' shadows). At thumbnail resolution (~1250x1250) this is acceptable —
#' shadow detail is minimal. For full-resolution scans where shadow
#' detail matters, set `srcnodata = NULL` and handle frame masking
#' downstream (e.g., circle detection).
#'
#' **Accuracy:** footprints assume flat terrain and nadir camera angle.
#' The georeferenced images are approximate — useful for visual context,
#' not survey-grade positioning. See [fly_footprint()] for details on
#' limitations.
#'
#' @examples
#' centroids <- sf::st_read(system.file("testdata/photo_centroids.gpkg", package = "fly"))
#'
#' # Fetch and georeference with auto rotation (uses bearing from centroids)
#' fetched <- fly_fetch(centroids[1:2, ], type = "thumbnail",
#'                      dest_dir = tempdir())
#' georef <- fly_georef(fetched, centroids[1:2, ],
#'                      dest_dir = tempdir())
#' georef
#'
#' @export
fly_georef <- function(fetch_result, photos_sf,
                       dest_dir = "georef", overwrite = FALSE,
                       srcnodata = "0", rotation = "auto") {
  if (!all(c("airp_id", "dest", "success") %in% names(fetch_result))) {
    stop("`fetch_result` must be output from `fly_fetch()`.", call. = FALSE)
  }

  auto_rotation <- identical(rotation, "auto")
  if (!auto_rotation) {
    rotation <- as.integer(rotation)
    if (!rotation %in% c(0L, 90L, 180L, 270L)) {
      stop("`rotation` must be one of \"auto\", 0, 90, 180, 270.", call. = FALSE)
    }
  }

  dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)

  # Build footprints in BC Albers
  footprints <- fly_footprint(photos_sf) |> sf::st_transform(3005)

  # Match fetch results to photos by airp_id
  ids <- fetch_result$airp_id

  # Per-photo rotation: column overrides auto/default

  has_rotation_col <- "rotation" %in% names(photos_sf)

  # Auto-compute bearing → rotation when needed
  if (auto_rotation && !has_rotation_col) {
    if (all(c("film_roll", "frame_number") %in% names(photos_sf))) {
      photos_sf <- fly_bearing(photos_sf)
      photos_sf$rotation <- bearing_to_rotation(photos_sf$bearing)
      has_rotation_col <- TRUE
    } else {
      message("No film_roll/frame_number columns for auto rotation, using 180")
      rotation <- 180L
      auto_rotation <- FALSE
    }
  }

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

    # Per-photo rotation from column, or default
    rot <- if (has_rotation_col) {
      val <- as.integer(photos_sf[["rotation"]][fp_idx[1]])
      if (is.na(val)) {
        if (auto_rotation) 180L else rotation
      } else val
    } else {
      rotation
    }

    results$success[i] <- tryCatch(
      georef_one(src, fp, out_file, srcnodata = srcnodata, rotation = rot),
      error = function(e) {
        message("Failed to georef ", basename(src), ": ", e$message)
        FALSE
      }
    )
  }

  n_ok <- sum(results$success)
  message("Georeferenced ", n_ok, " of ", nrow(results), " images")
  results
}

#' Georeference a single image to a footprint polygon
#' @noRd
georef_one <- function(src, fp, out_file, srcnodata = "0", rotation = 180) {
  # Get footprint corner coordinates
  # fly_footprint builds: BL, BR, TR, TL, BL (closing)
  coords <- sf::st_coordinates(fp)[1:4, , drop = FALSE]
  # coords: [1]=BL, [2]=BR, [3]=TR, [4]=TL

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

  # Pixel corners: TL, TR, BR, BL
  pixel_corners <- list(
    c(0, 0),              # TL
    c(ncol_px, 0),        # TR
    c(ncol_px, nrow_px),  # BR
    c(0, nrow_px)         # BL
  )

  # Footprint corners in same order: TL, TR, BR, BL
  fp_corners <- list(
    coords[4, 1:2],  # TL
    coords[3, 1:2],  # TR
    coords[2, 1:2],  # BR
    coords[1, 1:2]   # BL
  )

  # Rotation: shift the footprint corner mapping

  # rotation=0:   pixel TL → footprint TL (north-up, original behavior)
  # rotation=90:  pixel TL → footprint TR (top of image = east)
  # rotation=180: pixel TL → footprint BR (top of image = south)
  # rotation=270: pixel TL → footprint BL (top of image = west)
  n_shifts <- rotation %/% 90
  if (n_shifts > 0) {
    fp_corners <- c(
      fp_corners[(n_shifts + 1):4],
      fp_corners[1:n_shifts]
    )
  }

  # Build GCP args mapping pixel corners to (rotated) footprint corners
  gcp_args <- character(0)
  for (j in seq_along(pixel_corners)) {
    gcp_args <- c(gcp_args,
      "-gcp", pixel_corners[[j]][1], pixel_corners[[j]][2],
      fp_corners[[j]][1], fp_corners[[j]][2]
    )
  }

  # Step 1: translate with GCPs
  tmp_file <- tempfile(fileext = ".tif")
  on.exit(unlink(tmp_file), add = TRUE)

  sf::gdal_utils("translate",
    source = src,
    destination = tmp_file,
    options = c("-a_srs", "EPSG:3005", gcp_args)
  )

  # Step 2: warp to target CRS with nodata handling
  # srcnodata: masks black source pixels (camera frame borders)
  # RGB: alpha band (-dstalpha) for transparent fill in mosaics
  # Grayscale: dstnodata=0 for nodata metadata
  warp_opts <- c("-t_srs", "EPSG:3005", "-r", "bilinear")
  if (!is.null(srcnodata)) {
    src_val <- if (is_rgb) {
      paste(rep(srcnodata, n_bands), collapse = " ")
    } else {
      srcnodata
    }
    warp_opts <- c(warp_opts, "-srcnodata", src_val)
  }
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

#' Convert flight bearing to GCP rotation
#'
#' Formula calibrated on BC aerial photos (1968–2019).
#' @param bearing Numeric vector of bearings (degrees, 0–360).
#' @return Integer vector of rotations (0, 90, 180, or 270). NA bearings
#'   return 180 (most common default).
#' @noRd
bearing_to_rotation <- function(bearing) {
  rot <- (floor((bearing + 91) / 90) * 90L) %% 360L
  rot[is.na(rot)] <- 180L
  as.integer(rot)
}
