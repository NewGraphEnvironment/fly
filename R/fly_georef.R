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
#'   Geometry must be POINT — the ground footprint is estimated *from* a
#'   centroid, so passing footprints back in is refused rather than coerced.
#' @param dest_dir Directory for output GeoTIFFs. Created if it does not
#'   exist.
#' @param overwrite If `FALSE` (default), skip files that already exist.
#' @param srcnodata Source nodata value passed to GDAL warp. Black pixels
#'   matching this value are treated as transparent (alpha=0 for RGB,
#'   nodata for grayscale). Default `"0"` masks camera frame borders and
#'   film holder edges at the cost of losing real black pixels — acceptable
#'   for thumbnails but may need adjustment for full-resolution scans.
#'   Set to `NULL` to disable source nodata detection entirely.
#' @param dem Optional elevation raster passed to [fly_footprint()], sizing each
#'   frame from its height above ground instead of the reported scale. See the
#'   **Terrain** section of [fly_footprint()].
#' @param rotation Image rotation in degrees clockwise. One of `"auto"`,
#'   `0`, `90`, `180`, or `270`. Applies to frames with a **square**
#'   footprint only. `"auto"` (default) computes flight line bearing from
#'   consecutive centroids and derives rotation per-photo — requires
#'   `film_roll` and `frame_number` columns. Fixed values apply the same
#'   rotation to every square-footprint photo. A non-square footprint
#'   ignores this argument and uses the measured digital mapping (see
#'   **Rotation**); a `rotation` column in `photos_sf` still overrides
#'   per-photo, for both. Carrying a film-era `rotation` column into a
#'   batch of digital frames therefore overrides the correct mapping with
#'   the wrong one — drop the column, or set it to `NA` for those rows.
#' @return A tibble with columns `airp_id`, `source`, `dest`, and `success`.
#'
#' @details
#' Each image's four corners are mapped to the corresponding footprint
#' polygon corners computed by [fly_footprint()] in BC Albers. GDAL
#' translates the image with GCPs then warps to the target CRS using
#' bilinear resampling.
#'
#' **Rotation:** the corner mapping depends on the footprint's shape, because
#' [fly_footprint()] builds the two shapes differently.
#'
#' A **square** footprint is axis-aligned, so the mapping carries the rotation.
#' The `rotation` parameter rotates it:
#' \itemize{
#'   \item `0` — top of image maps to north edge of footprint
#'   \item `90` — top of image maps to east edge (90° clockwise)
#'   \item `180` — top of image maps to south edge (correct for most BC film)
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
#'   .default = NA  # non-square footprints fall through to the digital mapping;
#'                  # square ones to `rotation`, which is 180 under "auto" —
#'                  # NOT back to the per-photo bearing
#' )
#' ```
#'
#' Every non-`NA` value in that column must be 0, 90, 180 or 270; anything else
#' is an error naming the value, rather than a rotation silently applied as
#' something other than what was written.
#'
#' A **non-square** footprint — every digital frame — is already rotated onto
#' its flight line by [fly_footprint()], so the ring carries the bearing and
#' applying it again would count it twice. Those frames use a fixed mapping
#' instead: the top-left pixel maps to the ring's rear-left corner, equivalently
#' image columns run in the flight direction and image rows run flight-right.
#' That was measured in fly#38 on both bundled cameras by three independent
#' routes and is the same for each; see `inst/notes/georeferencing.md`.
#'
#' A frame whose delivered image aspect disagrees with its footprint's by more
#' than 8% is **skipped with a warning** rather than written stretched — the
#' failure a wrong mapping produces is a valid GeoTIFF over the right ground,
#' squashed by the aspect ratio squared, which nothing downstream would report.
#' The threshold sits between the largest disagreement a legitimate frame
#' produces (a full-resolution 9-inch scan carrying the negative's rebate, about
#' 6.7%) and the smallest that must be caught (a Leica DMC II frame sized through
#' `format_size` onto a square footprint, 9.95%). It applies to square footprints
#' too: a square one has no pairing to get wrong, but a digital frame sized
#' through `format_size` lands on one, and that is the unknown-camera case — so
#' gating on shape would switch the check off exactly where it is needed.
#'
#' A non-square footprint built without a flight bearing is drawn axis-aligned
#' and is therefore georeferenced as though the flight line ran due north.
#' [fly_bearing()] needs a neighbouring frame, so this is the ordinary result of
#' georeferencing a single frame on its own, and it is warned about.
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
#' **Accuracy:** footprints assume a nadir camera angle, and without `dem`
#' they also assume flat terrain. Passing `dem` sizes each frame from its
#' height above ground, which on steep ground is the larger of the two error
#' terms — but the images stay approximate either way, useful for visual
#' context rather than survey-grade positioning. See the **Terrain** section
#' of [fly_footprint()].
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
                       srcnodata = "0", rotation = "auto", dem = NULL) {
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

  # Before dir.create(), so a rejected input does not leave an empty output
  # directory behind. Guarded here as well as inside fly_footprint() so the
  # message names the argument this caller actually typed. See fly#37.
  fly_check_points(photos_sf, "photos_sf")

  dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)

  # Build footprints in BC Albers
  footprints <- fly_footprint(photos_sf, dem = dem) |> sf::st_transform(3005)
  fly_warn_unsized(footprints, "georeferencing")

  # Classify every footprint once, before any per-row work, and three ways rather than
  # two. `fly_is_square()` reports an EMPTY geometry as square — defensible, since a
  # shapeless thing has no unequal sides — so squareness alone cannot stand in for
  # "has ground control". Keeping empty separate means neither branch below inherits the
  # other's answer, and `georef_one()` is never handed a ring it cannot index.
  empty_fp   <- sf::st_is_empty(sf::st_geometry(footprints))
  non_square <- !empty_fp & !fly_is_square(footprints)

  # A non-square footprint that never got a bearing is drawn axis-aligned, so it is
  # georeferenced as though the aircraft flew due north. `fly_bearing()` needs a
  # neighbour, so this is the ordinary result of georeferencing one frame on its own —
  # not an exotic case. Named rather than left to be discovered from a rotated image.
  if ("width_source" %in% names(footprints)) {
    no_bearing <- non_square & grepl("axis_aligned_no_bearing", footprints$width_source)
    if (any(no_bearing)) {
      warning(
        sum(no_bearing), " of ", nrow(footprints), " frames have a non-square footprint ",
        "but no flight bearing, so they are drawn and georeferenced as though the ",
        "flight line ran due north. Pass neighbouring frames from the same roll so ",
        "`fly_bearing()` can compute an azimuth.",
        call. = FALSE
      )
    }
  }

  # Match fetch results to photos by airp_id
  ids <- fetch_result$airp_id

  # Per-photo rotation: column overrides auto/default

  # `has_rotation_col` is set again by the auto path below, after which nothing can tell
  # a user-supplied column from a bearing-derived one. Capture the distinction here,
  # while it still exists: a user value overrides the measured digital rotation, a
  # bearing-derived one must not.
  user_rotation_col <- "rotation" %in% names(photos_sf)
  has_rotation_col <- user_rotation_col

  # The argument is checked above; the column never was, and this function now makes it
  # the highest-precedence input for a digital frame. `rotation %/% 90` turns 360 into a
  # five-element shift and `fly_georef_gcps()` then indexes out of bounds — swallowed by
  # the per-frame `tryCatch` below into a message naming neither the column nor the
  # value. 45 and -90 are worse: they shift by zero and georeference silently wrong.
  # Normalised once, here, and read from this vector everywhere below. `as.character()`
  # first because `as.integer()` on a factor returns its level code — a `rotation` column
  # read from a CSV as a factor would otherwise validate as 180 and then be *applied* as
  # 1. Converting in two places is how those come apart.
  user_rot <- NULL
  if (user_rotation_col) {
    raw <- as.character(photos_sf[["rotation"]])
    user_rot <- suppressWarnings(as.integer(raw))
    # A value that was supplied but did not parse must be refused, not quietly turned
    # into NA. `is.na(user_rot) & !is.na(raw)` is that case; excluding it from `bad`
    # would let "ninety" through as "no preference", which is a different instruction.
    bad <- (!is.na(user_rot) & !user_rot %in% c(0L, 90L, 180L, 270L)) |
      (is.na(user_rot) & !is.na(raw))
    if (any(bad)) {
      stop("`photos_sf$rotation` must be NA or one of 0, 90, 180, 270. Got: ",
           paste(unique(raw[bad]), collapse = ", "), ".", call. = FALSE)
    }
    # Written back so there is exactly ONE parse. Leaving the raw column in place and
    # converting again at the read sites is how a factor validates as 180 and is then
    # applied as its level code — the read below is not the only one.
    photos_sf[["rotation"]] <- user_rot
  }

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
    j <- fp_idx[1]

    # No footprint means no ground control to warp onto; leave success = FALSE rather
    # than writing a GeoTIFF positioned by a format we could not resolve. Checked before
    # anything reads the ring.
    if (empty_fp[j]) next
    fp <- footprints[j, ]

    # A user-supplied `rotation` column overrides everything, square or not — the
    # documented escape hatch. Everything else depends on the footprint's shape:
    # a non-square ring already carries its bearing (see `fly_rectangles()`), so
    # applying `bearing_to_rotation()` on top would count it twice.
    user_val <- if (user_rotation_col) user_rot[j] else NA_integer_
    rot <- if (!is.na(user_val)) {
      user_val
    } else if (non_square[j]) {
      fly_digital_rotation()
    } else if (has_rotation_col) {
      val <- as.integer(photos_sf[["rotation"]][j])
      if (is.na(val)) {
        if (auto_rotation) 180L else rotation
      } else {
        val
      }
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
  # Footprint ring, in the order `fly_rectangles()` guarantees: rows 1-4 are BL, BR, TR,
  # TL **in the rectangle's own frame**. For a rotated (non-square) footprint that frame
  # is the flight line's, so they are rear-left, rear-right, front-right, front-left.
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

  # Build GCP args from the pixel-to-ground correspondence.
  gcp <- fly_georef_gcps(ncol_px, nrow_px, coords, rotation)
  # Refuse a mapping that pairs the image's axes with the wrong footprint edges. It
  # would still produce a valid GeoTIFF, in the right CRS, over the right ground — just
  # squashed by the aspect ratio squared, which nothing downstream would report. Catches
  # a camera delivering an orientation this was not measured on, and a frame sized from
  # an inferred format that does not match the camera that actually took it.
  #
  # The tolerance is what makes this safe on film, and it is set from measurements
  # rather than picked. A square footprint has no pairing to get wrong, but a scan
  # carrying the negative's rebate is genuinely a few percent off square, and a gate on
  # shape would switch the check off for a digital frame sized through `format_size`
  # into a square footprint — exactly the unknown-camera case this exists to catch.
  #
  #   |log| off isotropic     what it is
  #   0.0000                  bundled film thumbnails, 1250 x 1250
  #   0.0645                  a full-resolution 9-inch scan at 9600 x 9000
  #   0.0770                  this tolerance
  #   0.0949                  the TIGHTEST case that must be caught — a Leica DMC II
  #                           frame sized through `format_size` onto a square footprint
  #   0.1898                  the tightest mispairing on a frame's own footprint,
  #                           the same DMC II at 1.0995 squared
  #   0.4421                  a portrait UltraCam frame on a square footprint
  #
  # The admissible band is narrow — (1.0667, 1.0995) — because a square-footprint DMC II
  # frame is only slightly more eccentric than a badly rebated film scan. Checked against
  # every row of `camera_formats.csv`, fallback rows included, not just the two cameras
  # the bundled fixture happens to carry.
  aniso <- fly_gcp_anisotropy(gcp, ncol_px, nrow_px)
  if (!is.finite(aniso) || abs(log(aniso)) > log(fly_gcp_stretch_max())) {
    warning(basename(src), ": image is ", round(ncol_px / nrow_px, 3),
            ":1 but the corner mapping would stretch it by ", round(aniso, 3),
            "x. Skipped rather than written squashed. ",
            "See `inst/notes/georeferencing.md`.",
            call. = FALSE)
    return(FALSE)
  }

  # `unname()` matters: the ring arrives from `sf::st_coordinates()` carrying X/Y
  # dimnames, and without it the option vector handed to GDAL is named. Harmless to
  # GDAL, but it makes the args unequal to a plain character vector under `identical()`,
  # which is what the parity test compares.
  gcp_args <- character(0)
  for (j in seq_len(nrow(gcp))) {
    gcp_args <- c(gcp_args, "-gcp", as.character(unname(gcp[j, ])))
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

#' Map image pixel corners onto footprint ground corners
#'
#' The pure half of [georef_one()] — no GDAL, no file I/O, no `sf`. Split out
#' because it is the part that can be wrong, and a GCP correspondence is
#' checkable offline in a way a warped GeoTIFF is not.
#'
#' `coords` is the footprint's ring as [fly_footprint()] builds it, whose vertex
#' order is a contract: rows 1-4 are BL, BR, TR, TL **in the rectangle's own
#' frame**. For a non-square footprint that frame is the flight line's, so those
#' are rear-left, rear-right, front-right, front-left — the same meaning whether
#' or not the ring was rotated onto a bearing. See `fly_rectangles()`.
#'
#' @param ncol_px,nrow_px Image dimensions in pixels.
#' @param coords A 4-row matrix of footprint ring coordinates, x in column 1
#'   and y in column 2.
#' @param rotation Image rotation, one of 0, 90, 180, 270. Cyclically shifts
#'   which ground corner the top-left pixel maps to.
#' @return A 4-row numeric matrix with columns `pixel_x`, `pixel_y`,
#'   `ground_x`, `ground_y`, one row per corner in the order TL, TR, BR, BL.
#' @noRd
fly_georef_gcps <- function(ncol_px, nrow_px, coords, rotation) {
  # Pixel corners: TL, TR, BR, BL
  pixel <- matrix(
    c(0, 0,
      ncol_px, 0,
      ncol_px, nrow_px,
      0, nrow_px),
    ncol = 2, byrow = TRUE
  )

  # Footprint corners in the same order: TL, TR, BR, BL
  ground <- coords[c(4, 3, 2, 1), 1:2, drop = FALSE]

  # Rotation shifts the footprint corner mapping:
  #   0   pixel TL → footprint TL (north-up on a square; front-left on a rectangle)
  #   90  pixel TL → footprint TR
  #   180 pixel TL → footprint BR
  #   270 pixel TL → footprint BL
  n_shifts <- rotation %/% 90
  if (n_shifts > 0) {
    ground <- ground[c((n_shifts + 1):4, 1:n_shifts), , drop = FALSE]
  }

  out <- cbind(pixel, ground)
  dimnames(out) <- list(NULL, c("pixel_x", "pixel_y", "ground_x", "ground_y"))
  out
}

#' The rotation a digital frame's corner mapping needs
#'
#' 270 degrees: the top-left pixel maps to the footprint ring's rear-left corner, or
#' equivalently image columns run in the flight direction and image rows run
#' flight-right. Measured in fly#38 on both bundled cameras by three independent routes
#' — published exterior orientation, adjacent-frame overlap correlation, and FWA lake
#' darkness. They agree, so this is one constant rather than a per-camera column.
#'
#' Do not re-derive it by reasoning. See `inst/notes/georeferencing.md`, and
#' `data-raw/georef_calibrate-corner_mapping.R` to reproduce the measurement.
#' @noRd
fly_digital_rotation <- function() 270L

#' How far a corner mapping may stretch an image before it is refused
#'
#' Set between the largest stretch a legitimate frame produces and the smallest a wrong
#' corner mapping can. A full-resolution 9-inch film scan carrying the negative's rebate
#' runs about 6.7% off square; the tightest case that must be caught is a Leica DMC II
#' frame sized through `format_size` onto a square footprint, at 9.95%. The admissible
#' band is therefore (1.0667, 1.0995) and this sits near the middle of it. Checked
#' against every row of `camera_formats.csv`. See `georef_one()` for the full table.
#' @noRd
fly_gcp_stretch_max <- function() 1.08

#' How far a corner mapping stretches an image
#'
#' Metres per pixel along the image's width axis, divided by metres per pixel along its
#' height axis. An isotropic mapping gives 1; a mapping that pairs the image's long axis
#' with the footprint's short edge gives the footprint's aspect ratio squared.
#'
#' Computed from the correspondence itself rather than from the footprint, so it measures
#' what GDAL will actually be asked to do.
#' @param gcp A matrix from [fly_georef_gcps()].
#' @param ncol_px,nrow_px Image dimensions in pixels.
#' @return A single numeric ratio, or `NA_real_` if either dimension is degenerate.
#' @noRd
fly_gcp_anisotropy <- function(gcp, ncol_px, nrow_px) {
  if (!is.finite(ncol_px) || !is.finite(nrow_px) || ncol_px <= 0 || nrow_px <= 0) {
    return(NA_real_)
  }
  g <- gcp[, c("ground_x", "ground_y"), drop = FALSE]
  w <- sqrt(sum((g[2, ] - g[1, ])^2)) / ncol_px
  h <- sqrt(sum((g[3, ] - g[2, ])^2)) / nrow_px
  if (!is.finite(w) || !is.finite(h) || h == 0) return(NA_real_)
  w / h
}
