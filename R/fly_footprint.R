#' Estimate photo footprint polygons from centroids and scale
#'
#' Creates rectangular polygons representing the estimated ground coverage
#' of each airphoto, based on film negative dimensions and the reported scale.
#'
#' @param centroids_sf An sf point object with a `scale` column (e.g. "1:31680").
#'   A `media` column (e.g. `"Film - BW"`, `"Digital - Colour"`) selects the
#'   recording format per frame when present.
#' @param negative_size Negative dimension in inches (default 9 for standard
#'   9" x 9"). Applies to film frames, and to every frame when there is no
#'   `media` column. It never sizes a digital frame — see `format_size`.
#' @param format_size Named numeric vector of recording-format widths in inches,
#'   keyed by `media` value, merged over the shipped film defaults. Supply this
#'   to size frames whose format `fly` does not know — see Details.
#' @return An sf polygon object in the same CRS as input, with footprint
#'   rectangles and a `footprint_basis` column recording how each was sized.
#'   Frames whose format could not be resolved get an empty geometry.
#'
#' @details
#' Ground coverage is computed as `negative_size * scale_number * 0.0254` metres
#' per side. Rectangles are constructed in BC Albers (EPSG:3005) for accurate
#' metric distances, then transformed back to the input CRS.
#'
#' The scale denominator is parsed from the `scale` column string (e.g.
#' `"1:12000"` becomes `12000`).
#'
#' **Film and digital are not the same measurement.** The 9-inch default
#' reflects the standard 228 mm negative used by BC aerial survey cameras
#' (e.g. Wild RC-10, Zeiss RMK). A digital frame has no negative, and the
#' catalogue mixes the two in one layer — roughly a fifth of frames in a
#' sampled area are `Digital - Colour`. Ground width scales with the recording
#' format, so applying a negative dimension to a sensor produces a rectangle
#' that is wrong by an unknown factor while still drawing, still overlapping
#' neighbours, and still yielding a coverage percentage.
#'
#' Each row is therefore sized from its `media` value, and `footprint_basis`
#' records the outcome:
#'
#' \describe{
#'   \item{the `media` value}{format resolved from the format table}
#'   \item{`"assumed_default"`}{no `media` column; `negative_size` applied}
#'   \item{`"unknown_format"`}{`media` present but unknown; empty geometry}
#' }
#'
#' Shipped defaults cover film only. Digital frames resolve to
#' `"unknown_format"` rather than an invented number, because the sensor width
#' they would need is not in the centroid metadata — and neither is the pixel
#' count that would let `ground_sample_distance` stand in for it. Supply
#' `format_size` if you know the camera:
#'
#' ```r
#' fly_footprint(photos, format_size = c("Digital - Colour" = 3.54))
#' ```
#'
#' Filter on `footprint_basis` to keep only frames sized from a known format.
#'
#' **Focal length and flying height are available.** `FOCAL_LENGTH`,
#' `FLYING_HEIGHT` and `SCALE` are fully populated in
#' `WHSE_IMAGERY_AND_BASE_MAPS.AIMG_PHOTO_CENTROIDS_SP` and carried through to
#' the bundled test data. Note the field is `SCALE`, not `PHOTO_SCALE` — the
#' latter returns all `NULL`, which reads as missing data rather than a wrong
#' field name.
#'
#' **Flat-terrain assumption:** footprints are estimated assuming flat ground
#' beneath the aircraft. In reality terrain slope changes the actual ground
#' coverage — downhill slopes increase the true footprint (ground falls away
#' from the camera), while uphill slopes reduce it. In steep terrain typical
#' of BC valleys, true footprints may differ meaningfully from these estimates.
#' Coverage and overlap calculations downstream (e.g. [fly_coverage()],
#' [fly_overlap()]) inherit this limitation.
#'
#' @examples
#' centroids <- sf::st_read(system.file("testdata/photo_centroids.gpkg", package = "fly"))
#' footprints <- fly_footprint(centroids)
#' plot(sf::st_geometry(footprints))
#'
#' # How each footprint was sized
#' table(footprints$footprint_basis)
#'
#' # Keep only frames sized from a known recording format
#' sized <- footprints[footprints$footprint_basis != "unknown_format", ]
#' nrow(sized)
#'
#' @export
# Catalogue `media` values recorded on film, and so sized by `negative_size`.
# Digital media are deliberately absent: a sensor's width is not in the centroid
# metadata, so those frames are left unresolved rather than guessed. See fly#30.
fly_film_media <- function() {
  c("Film - BW", "Film - Colour")
}

fly_footprint <- function(centroids_sf, negative_size = 9, format_size = NULL) {
  if (!inherits(centroids_sf, "sf")) {
    stop("`centroids_sf` must be an sf object.", call. = FALSE)
  }
  if (!"scale" %in% names(centroids_sf)) {
    stop("`centroids_sf` must have a `scale` column (e.g. '1:31680').", call. = FALSE)
  }

  if (!is.null(format_size)) {
    if (!is.numeric(format_size) || is.null(names(format_size))) {
      stop("`format_size` must be a named numeric vector of widths in inches.",
           call. = FALSE)
    }
  }

  input_crs <- sf::st_crs(centroids_sf)
  pts_3005 <- sf::st_transform(centroids_sf, 3005)
  coords <- sf::st_coordinates(pts_3005)
  scale_num <- as.numeric(stringr::str_remove(centroids_sf$scale, "1:"))

  n <- nrow(centroids_sf)
  film <- fly_film_media()
  formats <- rep(negative_size, length(film))
  names(formats) <- film
  formats[names(format_size)] <- format_size

  if (!"media" %in% names(centroids_sf)) {
    width_in <- rep(negative_size, n)
    basis <- rep("assumed_default", n)
  } else {
    media <- as.character(centroids_sf$media)
    width_in <- unname(formats[media])
    basis <- ifelse(is.na(width_in), "unknown_format", media)
  }

  unresolved <- is.na(width_in)
  if (any(unresolved)) {
    unknown <- sort(unique(as.character(centroids_sf$media)[unresolved]))
    warning(
      sum(unresolved), " of ", n, " frames have no known recording format (",
      paste(unknown, collapse = ", "), "). ",
      "Ground width scales with format, so no footprint was estimated for them",
      " \u2014 see the `format_size` argument. Filter on `footprint_basis`.",
      call. = FALSE
    )
  }

  half_side <- width_in * scale_num * 0.0254 / 2

  polys <- lapply(seq_len(nrow(coords)), function(i) {
    w <- half_side[i]
    if (is.na(w)) {
      return(sf::st_polygon())
    }
    cx <- coords[i, 1]
    cy <- coords[i, 2]
    corners <- matrix(c(
      cx - w, cy - w,
      cx + w, cy - w,
      cx + w, cy + w,
      cx - w, cy + w,
      cx - w, cy - w
    ), ncol = 2, byrow = TRUE)
    sf::st_polygon(list(corners))
  })

  result <- sf::st_sf(
    sf::st_drop_geometry(pts_3005),
    footprint_basis = basis,
    geometry = sf::st_sfc(polys, crs = 3005)
  )

  sf::st_transform(result, input_crs)
}
