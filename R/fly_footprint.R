# Catalogue `media` values recorded on film, and so sized by `negative_size`.
# Digital media are deliberately absent: a sensor's width is not in the centroid
# metadata, so those frames are left unresolved rather than guessed. See fly#30.
fly_film_media <- function() {
  c("Film - BW", "Film - Colour")
}

# Report frames excluded from an operation because they have no footprint.
#
# An empty geometry fails every sf predicate quietly: st_intersects() returns
# FALSE and st_area() returns 0. The arithmetic is right, since an unsized frame
# genuinely covers nothing we can claim — but without this the exclusion is
# invisible, which is how a fifth of a query disappears from a coverage number
# with nothing to show it happened.
fly_warn_unsized <- function(footprints, operation) {
  unsized <- sf::st_is_empty(sf::st_geometry(footprints))
  if (any(unsized)) {
    warning(
      sum(unsized), " of ", length(unsized),
      " frames have no footprint and are excluded from ", operation,
      ". See `footprint_basis`, and `format_size` in ?fly_footprint.",
      call. = FALSE
    )
  }
  invisible(footprints)
}

# Sample ground elevation beneath each frame from a DEM.
#
# Two passes. The first samples at the centroid to get a provisional footprint;
# the second takes the mean elevation under that rectangle. The iteration is
# load-bearing rather than cosmetic — on a 7.2 km 1:31680 frame the centroid and
# the footprint mean differ by up to 130 m, which moves the area correction by
# several percent.
#
# Returns elevation in metres, NA where the DEM does not cover the frame.
fly_dem_elevation <- function(dem, pts_3005, half_side) {
  dem_crs <- sf::st_crs(terra::crs(dem))
  sample_at <- function(geom) {
    v <- terra::vect(sf::st_transform(geom, dem_crs))
    terra::extract(dem, v, fun = mean, na.rm = TRUE)[, 2]
  }
  elev <- sample_at(pts_3005)

  coords <- sf::st_coordinates(pts_3005)
  provisional <- fly_rectangles(coords, half_side)
  ok <- !is.na(elev) & !sf::st_is_empty(provisional)
  if (any(ok)) {
    elev[ok] <- sample_at(sf::st_sf(geometry = provisional[ok]))
  }
  elev
}

# Build axis-aligned squares of `half_side` metres about each coordinate pair.
# A NA half-side yields an empty polygon — the #30 contract for a frame whose
# recording format could not be resolved.
fly_rectangles <- function(coords, half_side) {
  sf::st_sfc(lapply(seq_len(nrow(coords)), function(i) {
    w <- half_side[i]
    if (is.na(w)) {
      return(sf::st_polygon())
    }
    cx <- coords[i, 1]
    cy <- coords[i, 2]
    sf::st_polygon(list(matrix(c(
      cx - w, cy - w,
      cx + w, cy - w,
      cx + w, cy + w,
      cx - w, cy + w,
      cx - w, cy - w
    ), ncol = 2, byrow = TRUE)))
  }), crs = 3005)
}

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
#' @param dem Optional elevation raster used to size each frame from its true
#'   height above ground rather than the reported scale. A `terra::SpatRaster`,
#'   a file path, or a `/vsicurl/` URL. Requires `flying_height` and
#'   `focal_length` columns, and the `terra` package. `NULL` (default) keeps the
#'   flat-terrain behaviour — see **Terrain** below.
#' @return An sf polygon object in the same CRS as input, with footprint
#'   rectangles, a `footprint_basis` column recording how each was sized, a
#'   `footprint_terrain` column recording which terrain treatment was applied,
#'   and `height_agl` giving the metres above ground each footprint was sized
#'   from. Frames whose format could not be resolved get an empty geometry.
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
#' @section Terrain:
#'
#' Without `dem`, footprints are sized from the reported scale, which assumes
#' flat ground at whatever elevation the scale was computed for. That assumption
#' costs more than it looks: on the bundled Upper Bulkley AOI the reported scale
#' **understates footprint area by a median 14%, ranging to 27%** — and always in
#' the same direction, because the scale is referenced to an elevation above the
#' valley floor the photos actually cover.
#'
#' Supplying `dem` removes that bias. `FLYING_HEIGHT` is metres above sea level,
#' not height above ground, so subtracting terrain elevation is what turns it
#' into the height ground coverage actually scales with:
#'
#' ```
#' height above ground = flying_height - terrain elevation
#' ground width        = format width * (height above ground / focal length)
#' ```
#'
#' Elevation is sampled in two passes — at the centroid, then as the mean under
#' the resulting rectangle. The second pass matters: on a 7.2 km wide 1:31680
#' frame the two differ by up to 130 m.
#'
#' `footprint_terrain` records what happened to each frame:
#'
#' \describe{
#'   \item{`"nominal_scale"`}{sized from the reported scale (no `dem`, or a
#'     fallback — see below)}
#'   \item{`"dem_agl"`}{sized from height above ground}
#'   \item{`"no_dem_coverage"`}{`dem` supplied but does not cover the frame}
#'   \item{`NA`}{no footprint to place — see `footprint_basis`}
#' }
#'
#' A frame the DEM cannot correct falls back to nominal scale with a warning,
#' rather than being dropped. The same applies where the DEM puts terrain at or
#' above the aircraft, which means `flying_height` is not in metres ASL.
#'
#' **Still assumed, with or without a DEM:** the camera points straight down.
#' The BC catalogue carries no tilt, roll or crab, so footprints stay
#' axis-aligned rectangles and corner rays are not projected individually. On
#' this AOI that per-corner refinement is worth roughly 2%, against the 14% the
#' DEM addresses.
#'
#' **DEM sources.** Any raster `terra` can open works. Three that suit BC:
#'
#' \itemize{
#'   \item **MRDEM-30** — NRCan's 30 m bare-earth DTM, all of Canada, public
#'     and unauthenticated. A good default, and what the bundled `dem.tif` is
#'     cut from:
#'     `/vsicurl/https://canelevation-dem.s3.ca-central-1.amazonaws.com/mrdem-30/mrdem-30-dtm.tif`
#'   \item **LidarBC** — sub-10 m where coverage exists; query the
#'     `stac-dem-bc` STAC catalogue and pass an item's COG URL.
#'   \item **BC TRIM** — 25 m provincial DEM via the `bcdata` CLI
#'     (`bcdata get-dem`).
#'  }
#'
#' Resolution matters less here than extent. A 30 m DEM resolves a 2.7 km
#' footprint's mean elevation perfectly well, but a DEM that stops short of the
#' frame edges sends those frames down the `no_dem_coverage` fallback. Buffer
#' the AOI by at least half the widest footprint.
#'
#' Coverage and overlap downstream (e.g. [fly_coverage()], [fly_overlap()])
#' accept the same `dem` argument and inherit whichever basis you give them.
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
#' # Terrain-adjusted: size each frame from its height above ground instead of
#' # the reported scale. On this AOI every footprint grows, by a median 14%.
#' terrain <- fly_footprint(centroids, dem = system.file("testdata/dem.tif", package = "fly"))
#' round(100 * (as.numeric(sf::st_area(sf::st_transform(terrain, 3005))) /
#'                as.numeric(sf::st_area(sf::st_transform(footprints, 3005))) - 1), 1)
#' table(terrain$footprint_terrain)
#'
#' @export
fly_footprint <- function(centroids_sf, negative_size = 9, format_size = NULL,
                          dem = NULL) {
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

  if (!is.null(dem)) {
    rlang::check_installed("terra", "for terrain-adjusted footprints.")
    missing_cols <- setdiff(c("flying_height", "focal_length"), names(centroids_sf))
    if (length(missing_cols)) {
      stop(
        "`dem` needs ", paste0("`", missing_cols, "`", collapse = " and "),
        " on `centroids_sf`. Ground coverage scales with height above ground, ",
        "which is `flying_height` (metres above sea level) minus terrain ",
        "elevation \u2014 without it there is nothing for the DEM to correct.",
        call. = FALSE
      )
    }
    if (!inherits(dem, "SpatRaster")) {
      dem <- terra::rast(dem)
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

  terrain <- ifelse(is.na(width_in), NA_character_, "nominal_scale")
  height_agl <- rep(NA_real_, n)

  if (!is.null(dem)) {
    elev <- rep(NA_real_, n)
    sized <- !is.na(half_side)
    if (any(sized)) {
      elev[sized] <- fly_dem_elevation(dem, pts_3005[sized, ], half_side[sized])
    }

    agl <- centroids_sf$flying_height - elev
    focal_m <- centroids_sf$focal_length / 1000
    candidate <- width_in * (agl / focal_m) * 0.0254 / 2

    # Classify on the half-side we would actually use, not on the inputs that
    # feed it. An NA or zero `focal_length`, or an NA `flying_height`, yields a
    # non-finite half-side that would otherwise become an empty geometry — and
    # an empty geometry here is indistinguishable from one whose recording
    # format was never resolved, so the frame would vanish under a warning
    # pointing at `format_size` rather than at its own metadata.
    corrected <- sized & is.finite(candidate) & candidate > 0
    uncovered <- sized & !corrected & is.na(elev)
    unusable <- sized & !corrected & !uncovered

    # Every fallback keeps the frame at nominal scale rather than dropping it:
    # a frame we cannot correct is still a frame.
    if (any(uncovered)) {
      warning(
        sum(uncovered), " of ", sum(sized), " frames fall outside the DEM's ",
        "coverage and were sized from nominal scale instead. See ",
        "`footprint_terrain`.",
        call. = FALSE
      )
    }
    if (any(unusable)) {
      warning(
        sum(unusable), " of ", sum(sized), " frames have `flying_height` or ",
        "`focal_length` values that give no usable height above ground \u2014 ",
        "missing, zero, or terrain at or above the aircraft. Check that ",
        "`flying_height` is metres above sea level. Sized from nominal scale ",
        "instead. See `footprint_terrain`.",
        call. = FALSE
      )
    }

    half_side[corrected] <- candidate[corrected]
    height_agl[corrected] <- agl[corrected]
    terrain[sized] <- "nominal_scale"
    terrain[corrected] <- "dem_agl"
    terrain[uncovered] <- "no_dem_coverage"
    terrain[unusable] <- "nominal_scale"
  }

  result <- sf::st_sf(
    sf::st_drop_geometry(pts_3005),
    footprint_basis = basis,
    footprint_terrain = terrain,
    height_agl = height_agl,
    geometry = fly_rectangles(coords, half_side)
  )

  sf::st_transform(result, input_crs)
}
