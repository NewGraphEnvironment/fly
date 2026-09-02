# Catalogue `media` values recorded on film, and so sized by `negative_size`.
# Digital media are deliberately absent: a sensor's width is not in the centroid
# metadata, so those frames are left unresolved rather than guessed. See fly#30.
fly_film_media <- function() {
  c("Film - BW", "Film - Colour")
}

# Refuse anything that is not one point per frame.
#
# Every function that sizes ground coverage reads centroid positions with
# `sf::st_coordinates()`, which returns one row per feature for POINT and one row
# per *vertex* for everything else. Handed its own output, `fly_footprint()`
# therefore built five geometries per closed rectangle and `st_sf()` recycled the
# attribute frame up to match — 20 frames in, 100 rows out, no warning, and 80 of
# them carrying another photo's attributes (fly#37). Three of the functions that
# call it were quietly wrong rather than merely wrong-sized: `fly_overlap()`
# reported pairs over the corrupted set, and `fly_select()` and
# `fly_filter(method = "footprint")` indexed a 20-row frame with a length-100
# logical. Only `fly_coverage()` errored, and only by accident of how it assigns.
#
# POINT is not a proxy for "one coordinate row per feature", it is exactly
# equivalent to it: sf keeps an ALIGNED NA row for an empty POINT, so n features
# always yield n rows and no separate row-count assertion is needed behind this
# one. (Measured. The empty geometries `fly_footprint()` itself emits are empty
# POLYGONs and are refused on type, so they are not an instance of this — an
# earlier draft of this comment claimed they were.)
#
# An empty POINT is therefore ACCEPTED here and then fails further down with
# `!anyNA(x) is not TRUE`, from `st_polygon()` on the all-NA ring. That is
# pre-existing and deliberately left alone: this guard is about geometry *shape*,
# and refusing the whole batch for one unlocatable frame would contradict the
# per-frame reporting #30 established, where an unsizeable frame gets an empty
# footprint and a `footprint_basis` rather than aborting its neighbours. Tracked
# as fly#47; do not "fix" it by widening this guard.
#
# MULTIPOINT is excluded deliberately, against the suggestion in fly#37: it
# expands one row per constituent point exactly as a POLYGON does, so admitting
# it would reintroduce the bug. This is knowingly *stronger* than the invariant —
# a MULTIPOINT holding one point each would be harmless — because a cardinality
# check would admit a shape nothing downstream expects. Do not relax it to one.
#
# The type test is per *feature* rather than on the sfc's class, because a
# GEOMETRY-typed column can hold a mix and only the per-feature view sees it. An
# XYZ point passes and should — `st_coordinates()` gains a Z column but not a
# row, and only columns 1:2 are ever read.
#
# A `sfc_GEOMETRY` column is refused even when every feature in it is a POINT,
# because nothing downstream can read one. WHERE it fails depends on its
# contents, which is why this is checked here rather than left to surface:
#
#   all-POINT GEOMETRY   st_transform()   -> Not compatible with STRSXP: [type=NULL]
#   mixed GEOMETRY       st_transform()   -> works, then
#                        st_coordinates() -> not implemented for class sfc_GEOMETRY
#
# Neither message names the argument, the function or the package. An earlier
# draft of this comment blamed `st_coordinates()` alone; that is the *second*
# failure and the all-POINT case never reaches it. Both facts were individually
# true and the causal claim joining them was not — do not relax this clause on
# the strength of sf gaining an `st_coordinates.sfc_GEOMETRY` method, because
# `st_transform()` independently requires it.
#
# ORDER MATTERS, and this is the second bug in this clause rather than a style
# point. Checked BEFORE the per-feature test, it also swallowed a GEOMETRY column
# holding polygons, and told that caller to `st_cast(x, "POINT")` — which takes a
# polygon's FIRST VERTEX, not its centroid. Measured on a half-footprint,
# half-centroid column: 20 rows in, 20 rows out, guard then ACCEPTED, and ten
# frames relocated 1,940 m. Following this guard's own advice reintroduced
# exactly the silent corruption it exists to stop. The type test runs first so a
# mixed column is told it "must be points, not POLYGON" instead.
#
# The `nrow()` clause keeps zero-row input legal: `st_sf(geometry = st_sfc())`
# also carries an `sfc_GEOMETRY` column, and an empty query is a documented
# input. `st_coordinates.sfc` returns early on length 0, so it is genuinely
# readable.
#
# An error rather than an `st_centroid()` coercion, because taking the centroid
# of an estimated footprint and re-estimating from it is not a meaningful
# operation; doing it quietly would hide the caller's real mistake. The message
# names the offending types and the one-line fix, because this also guards an
# assumption about the upstream catalogue — `bcdata::collect()` returns POINT
# today, and if that ever changes the error should be ten seconds to resolve
# rather than a wall.
fly_check_points <- function(x, arg) {
  if (!inherits(x, "sf")) {
    stop("`", arg, "` must be an sf object.", call. = FALSE)
  }
  got <- as.character(sf::st_geometry_type(x))
  if (!all(got == "POINT")) {
    # `st_cast(x, "POINT")` is offered ONLY where it provably keeps one row per
    # feature, and this condition is the whole point of the clause rather than
    # defensive noise. The guard tests *shape*, and `st_cast()` always produces
    # the right shape — so recommending it unconditionally hands the caller a
    # remedy that walks straight back through the guard. Measured on the bundled
    # footprints: 20 rows in, `st_cast()`, 100 rows out, guard ACCEPTS, 80
    # duplicated `airp_id`. That is fly#37 verbatim, reproduced by following the
    # message written to prevent it. On a mixed column it instead moves each
    # polygon to its first ring vertex — 1,940 m — with the row count unchanged.
    #
    # The property wanted is PER FEATURE — each feature holds exactly one
    # coordinate — and the coordinate count alone tests it in aggregate, so it is
    # blind to any redistribution that conserves the total. An earlier draft
    # asserted the two were equivalent ("safe exactly when the counts match");
    # they are not, and the counterexample is reachable: a MULTIPOINT column
    # where one frame was digitised twice and one frame has no location recorded
    # sums to n coordinates over n features, so the cast was offered, and taking
    # it shifted every frame's geometry one place against its attributes — 18 of
    # 19 wrong by up to 20.4 km, row count preserved, no duplicated `airp_id`,
    # and the guard ACCEPTED the result. Both ingredients are in this package's
    # own record: MULTIPOINT is what fly#37 proposed admitting, and an empty
    # geometry is fly#47, seen from a GeoPackage round trip.
    #
    # The emptiness clause closes it by construction rather than by enumeration:
    # a non-empty feature contributes at least one coordinate, so "no empties"
    # plus "total equals the feature count" forces exactly one each.
    #
    # `st_coordinates()` throws on a column it cannot read, which is a "no"
    # rather than an error to propagate — we are already on the error path, and
    # every such throw means the cast cannot be reasoned about.
    cast_keeps_rows <- isTRUE(tryCatch(
      nrow(sf::st_coordinates(x)) == nrow(x) &&
        !any(sf::st_is_empty(sf::st_geometry(x))),
      error = function(e) FALSE
    ))
    stop(
      "`", arg, "` must be points, not ",
      paste(unique(got[got != "POINT"]), collapse = "/"),
      ". Ground coverage is estimated *from* a centroid; passing footprints ",
      "back in silently multiplies the rows by the vertex count. If you meant ",
      "to filter footprints against an area, use `sf::st_filter()`.",
      if (cast_keeps_rows) {
        paste0(" If these really are centroids in another form, `sf::st_cast(",
               arg, ", \"POINT\")`.")
      },
      call. = FALSE
    )
  }
  if (nrow(x) > 0 && inherits(sf::st_geometry(x), "sfc_GEOMETRY")) {
    stop(
      "`", arg, "` stores its points in a mixed-geometry (GEOMETRY) column, ",
      "which sf cannot read even though every feature in it is a point. ",
      "Use `sf::st_cast(", arg, ", \"POINT\")`.",
      call. = FALSE
    )
  }
  invisible(x)
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

# Coverage below which a footprint's mean elevation stops being trustworthy.
#
# Reprojecting a DEM leaves NA slivers along its edges, so a frame near the
# margin is routinely a percent or two short through no fault of the caller —
# warning on any missing cell at all would fire on a bundled frame that is
# 99.96% covered, and a guard that noisy stops being read. A frame missing more
# than a twentieth of its footprint is a different thing: that is enough for the
# covered part to sit systematically higher or lower than the whole.
fly_dem_coverage_min <- function() 0.95

# The DEM-aligned grid a single footprint is counted against.
#
# Named and separate so the "one frame at a time" invariant can be asserted
# rather than merely intended: the size of this grid is the whole difference
# between a bounded allocation and one scaled to the distance between photos.
fly_dem_grid <- function(dem, geom) {
  terra::rast(
    terra::align(terra::ext(terra::vect(geom)), dem),
    resolution = terra::res(dem),
    crs = terra::crs(dem)
  )
}

# Mean ground elevation under each rectangle, with the fraction of the
# rectangle the DEM actually described.
#
# `covered` matters because averaging with na.rm = TRUE cannot tell a
# fully-sampled frame from one hanging half off the edge of the data — both
# yield a number, and only one of them means what it appears to.
fly_dem_sample <- function(dem, rects) {
  elev <- rep(NA_real_, length(rects))
  covered <- rep(NA_real_, length(rects))
  ok <- !sf::st_is_empty(rects)
  if (!any(ok)) {
    return(list(elev = elev, covered = covered))
  }
  in_dem <- sf::st_transform(sf::st_sf(geometry = rects[ok]),
                             sf::st_crs(terra::crs(dem)))
  v <- terra::vect(in_dem)

  cells <- terra::extract(dem, v)
  # split() keys on the ID column, whose values are 1..n in ascending order, so
  # the results come back aligned with `rects[ok]`.
  per_frame <- split(cells[, 2], cells[, 1])
  elev[ok] <- vapply(per_frame, function(x) mean(x, na.rm = TRUE), numeric(1))
  got <- vapply(per_frame, function(x) sum(!is.na(x)), numeric(1))

  # The denominator has to be counted the way the numerator is. extract() takes
  # a cell when its *centre* falls inside the polygon, so dividing by the
  # footprint's area in cell units compares two different measurements and runs
  # about 2/k low for a footprint k cells wide — on a DEM with nothing missing
  # that reported 91% coverage and warned.
  #
  # So count cells on a grid aligned to the DEM's own, per frame. align() snaps
  # to the DEM's cell boundaries, which is what puts both counts on the same
  # centres.
  #
  # Per frame, not once over their union: the union's bounding box spans the
  # whole photo set, and one frame away from the rest sizes the template to the
  # gap between them. On a fixture in this package's own suite that is 243
  # million cells against 16 thousand for the same two frames counted
  # separately. Each frame's own template is bounded by one footprint.
  expected <- vapply(seq_len(nrow(in_dem)), function(i) {
    vi <- terra::vect(in_dem[i, ])
    tmpl <- fly_dem_grid(dem, in_dem[i, ])
    terra::values(tmpl) <- 1L
    sum(!is.na(terra::extract(tmpl, vi)[, 2]))
  }, numeric(1))

  covered[ok] <- ifelse(expected > 0, pmin(1, got / expected), 0)

  elev[is.nan(elev)] <- NA_real_
  list(elev = elev, covered = covered)
}

# Build rectangles of `half_cross` by `half_along` metres about each coordinate pair.
#
# `half_cross` spans the across-flight axis and `half_along` the along-flight one. Film
# is square, so the two are equal and the distinction costs nothing; a digital sensor is
# not — the Leica DMC III is 100.3 x 56.9 mm — and drawing it square would be 76% too
# deep. Defaulting `half_along` to `half_cross` keeps every film caller unchanged.
#
# A half-dimension that is NA, non-finite **or zero** yields an empty polygon. Zero
# matters as much as the others and is easy to miss: `is.finite(0)` is TRUE, so a zero
# would build a rectangle with five identical vertices, which `st_is_empty()` reports as
# FALSE and `fly_warn_unsized()` therefore never mentions, while it silently covers
# nothing downstream. That is strictly worse than the empty geometry #30 chose, and it
# is reachable — `ground_sample_distance` is 0 on every frame of some digital rolls.
#
# `bearing` rotates the rectangle to the flight line, and is applied only where the two
# half-dimensions differ. A square is unchanged by rotation up to vertex order, so
# leaving film alone keeps its output identical rather than merely equivalent.
#
# Vertex order is preserved as BL, BR, TR, TL, BL in the rectangle's own frame, because
# `fly_georef()` maps image corners onto footprint corners positionally and that order
# is its contract.
fly_rectangles <- function(coords, half_cross, half_along = half_cross, bearing = NULL) {
  sf::st_sfc(lapply(seq_len(nrow(coords)), function(i) {
    hc <- half_cross[i]
    ha <- half_along[i]
    if (!is.finite(hc) || !is.finite(ha) || hc <= 0 || ha <= 0) {
      return(sf::st_polygon())
    }
    cx <- coords[i, 1]
    cy <- coords[i, 2]
    xy <- matrix(
      c(-hc, -ha, hc, -ha, hc, ha, -hc, ha, -hc, -ha),
      ncol = 2, byrow = TRUE
    )

    b <- if (is.null(bearing)) NA_real_ else bearing[i]
    if (!isTRUE(all.equal(hc, ha)) && is.finite(b)) {
      # `bearing` is degrees clockwise from north, so the along-track axis is the local
      # +y. Rotating (x, y) by b clockwise sends (0, 1) to (sin b, cos b) — the heading
      # itself — which is what puts the long axis across the flight line rather than
      # along it.
      rad <- b * pi / 180
      rot <- matrix(c(cos(rad), sin(rad), -sin(rad), cos(rad)), nrow = 2)
      xy <- xy %*% rot
    }

    sf::st_polygon(list(cbind(xy[, 1] + cx, xy[, 2] + cy)))
  }), crs = 3005)
}

# Which footprints are squares.
#
# This is the predicate `fly_georef()` needs, and "is it axis-aligned" is not — that is
# a proxy for "was it rotated", and a flight line running exactly north or east produces
# a rotated footprint whose edges are still axis-parallel, so the proxy misses it.
#
# Squareness is the property that actually matters. `georef_one()` maps image corners
# onto footprint corners positionally and then shifts that mapping by a
# 90-degree-quantized bearing, a scheme calibrated against north-up 9x9 negatives. With
# a square footprint a wrong-by-90 shift is harmless; with a 1.76:1 rectangle it maps a
# landscape image onto a portrait quad. And only non-square footprints are rotated, so
# this catches the double-rotation case too.
fly_is_square <- function(footprints) {
  g <- sf::st_geometry(sf::st_transform(footprints, 3005))
  vapply(seq_along(g), function(i) {
    if (sf::st_is_empty(g[i])) return(TRUE)
    xy <- sf::st_coordinates(g[[i]])[, 1:2, drop = FALSE]
    d <- sqrt(rowSums(diff(xy)^2))
    isTRUE(all.equal(max(d), min(d)))
  }, logical(1))
}

#' Estimate photo footprint polygons from centroids and scale
#'
#' Creates rectangular polygons representing the estimated ground coverage
#' of each airphoto, based on film negative dimensions and the reported scale.
#'
#' @param centroids_sf An sf point object with a `scale` column (e.g. "1:31680").
#'   A `media` column (e.g. `"Film - BW"`, `"Digital - Colour"`) selects the
#'   recording format per frame when present.
#'   Geometry must be POINT. `sf::st_coordinates()` returns one row per *vertex*
#'   for anything else, so a POLYGON input silently multiplies the rows by the
#'   vertex count; this is refused rather than coerced, because re-estimating a
#'   footprint from the centroid of an estimated footprint is not meaningful.
#' @param negative_size Negative dimension in inches (default 9 for standard
#'   9" x 9"). Applies to film frames, and to every frame when there is no
#'   `media` column. It never sizes a digital frame — see `format_size`.
#' @param format_size Named numeric vector of recording-format widths in inches,
#'   keyed by `media` value, merged over the shipped film defaults. Frames it names are
#'   sized from the reported `scale`, as film is, and it takes precedence over the
#'   shipped camera table — it is the escape hatch for a camera `fly` does not know.
#'   See Details.
#' @param dem Optional elevation raster used to size each frame from its true
#'   height above ground rather than the reported scale. A `terra::SpatRaster`,
#'   a file path, or a `/vsicurl/` URL. Requires `flying_height` and
#'   `focal_length` columns, and the `terra` package. `NULL` (default) keeps the
#'   flat-terrain behaviour — see **Terrain** below.
#' @return An sf polygon object in the same CRS as input, with footprint
#'   rectangles, a `footprint_basis` column recording how each was sized, a
#'   `footprint_terrain` column recording which terrain treatment was applied,
#'   `height_agl` giving the metres above ground each footprint was sized from,
#'   and `dem_coverage` giving the fraction of each footprint the DEM actually
#'   covered (`0` where it covered none, `NA` only where there is no footprint).
#'   Frames whose format could not be resolved get an empty geometry. Every
#'   class the input carries is carried through, so a tibble-backed sf — which
#'   is what `bcdata::collect()` returns — comes back tibble-backed. The order
#'   is not preserved: `sf::st_transform()` moves `sf` to the front, so a
#'   `bcdc_sf` input returns `sf, bcdc_sf, ...`, as it always has.
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
#'   \item{`"inferred_format"`}{digital frame with no calibration, sized from a
#'     format inferred from its `focal_length`}
#'   \item{`"assumed_default"`}{no `media` column; `negative_size` applied}
#'   \item{`"unknown_format"`}{`media` present but unknown; empty geometry}
#' }
#'
#' @section Digital frames:
#'
#' A digital frame has no negative, and the catalogue mixes film and digital in one
#' layer — 223,667 of 1,670,471 frames province-wide are `Digital - Colour`. Sensor
#' dimensions are not in the centroid metadata, but they are recoverable from the
#' calibration report each frame links to through `camera_calibration_url`, and `fly`
#' ships them (`inst/extdata/camera_formats.csv`, built by
#' `data-raw/make_camera_formats.R`).
#'
#' Digital frames are sized as `pixel count x ground_sample_distance`, which needs
#' neither `scale` nor a DEM. **`scale` is never used for a digital frame `fly` sized
#' itself.** That field is not the true image scale for digital: measured against
#' terrain on 40 UltraCam Eagle frames it gives 34% of true width, because it is a
#' derived nominal figure — the pixel pitch it implies is about 12.5 um for every
#' camera regardless of model, against real pitches of 3.9 to 12 um.
#' `ground_sample_distance` is in centimetres.
#'
#' Where a frame carries no `camera_calibration_url` — about a fifth of digital frames —
#' the format is inferred from `focal_length` and `footprint_basis` records
#' `"inferred_format"`. Sensor width spreads only 1-3% at a given focal length, but
#' pixel count spreads 32-83%, so an inferred frame can only be sized through a DEM
#' (`width x height above ground / focal length`) and never from its GSD.
#'
#' `width_source` names the calibration file or fallback rule per row, so every
#' footprint traces back to a source. Calibrations that could not be corroborated are
#' listed in `inst/extdata/camera_formats_excluded.csv` with the reason, and frames
#' naming one are refused rather than inferred.
#'
#' **Digital footprints are not square** — sensors run from 1.10:1 (Leica DMC II) to
#' 1.80:1 (Intergraph DMC) — so they are rotated onto the flight line using
#' [fly_bearing()]. Where no bearing can be computed the rectangle stays axis-aligned
#' and `width_source` says so. Film stays square and is unaffected.
#'
#' Supply `format_size` to size a frame `fly` cannot, or to override it:
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
#' **understates footprint area by a median 14%, ranging to 26%** — and always in
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
#' Elevation is the **mean under the whole footprint**, not a reading at the
#' centroid — on a 7.2 km wide 1:31680 frame the two differ by up to 140 m.
#' That is measured in two passes, because the footprint being averaged over is
#' itself what the correction changes: the first pass averages over the
#' nominal-scale rectangle, the second over the rectangle the first produced.
#' The second pass is a refinement rather than the substance — it moves area by
#' at most 0.5% against the correction's own 14% — and a third moves it by
#' 0.03%, so two is where this settles.
#'
#' `footprint_terrain` records what happened to each frame:
#'
#' \describe{
#'   \item{`"nominal_scale"`}{sized from the reported scale (no `dem`, or a
#'     fallback — see below)}
#'   \item{`"gsd_scaled"`}{digital frame sized from its pixel count and ground
#'     sample distance; used neither the reported scale nor a DEM, so `height_agl`
#'     and `dem_coverage` are `NA`}
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
#'     `stac-elevation-bc` STAC catalogue and pass an item's COG URL.
#'   \item **BC TRIM** — 25 m provincial DEM via the `bcdata` CLI
#'     (`bcdata get-dem`).
#'  }
#'
#' Resolution matters less here than extent. A 30 m DEM resolves a 2.7 km
#' footprint's mean elevation perfectly well; a DEM that stops short of the
#' frame edges does not, and this is the ordinary failure rather than an exotic
#' one — a DEM cropped to an AOI simply stops. `no_dem_coverage` is reached only
#' when a footprint finds no elevation at all. A footprint that is merely
#' truncated is still corrected, from the mean of the part the DEM described,
#' and warns once that falls below 95%. `dem_coverage` reports the fraction per
#' frame — measured against the cells the footprint should have covered, not the
#' cells that came back — so a truncated footprint can be filtered rather than
#' merely noticed.
#'
#' Buffer past the **corner** of the widest footprint, not its half-side: the
#' far point of a square is `half_side * sqrt(2)`, which at 1:31680 is 5.1 km
#' rather than 3.6 km. Allow more again for the correction itself, which
#' enlarges footprints before the second pass samples them.
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
#' # terra is Suggests-only, so the DEM path is guarded here.
#' if (requireNamespace("terra", quietly = TRUE)) {
#'   terrain <- fly_footprint(
#'     centroids,
#'     dem = system.file("testdata/dem.tif", package = "fly")
#'   )
#'   print(round(100 * (as.numeric(sf::st_area(sf::st_transform(terrain, 3005))) /
#'     as.numeric(sf::st_area(sf::st_transform(footprints, 3005))) - 1), 1))
#'   print(table(terrain$footprint_terrain))
#' }
#'
#' @export
fly_footprint <- function(centroids_sf, negative_size = 9, format_size = NULL,
                          dem = NULL) {
  if (!inherits(centroids_sf, "sf")) {
    stop("`centroids_sf` must be an sf object.", call. = FALSE)
  }
  fly_check_points(centroids_sf, "centroids_sf")
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
    if (!nzchar(terra::crs(dem))) {
      stop(
        "`dem` has no CRS, so its cells cannot be located against the photo ",
        "centroids. Set one with `terra::crs(dem) <- \"EPSG:3005\"` (or ",
        "whichever it is) before passing it.",
        call. = FALSE
      )
    }
  }

  input_crs <- sf::st_crs(centroids_sf)
  pts_3005 <- sf::st_transform(centroids_sf, 3005)
  coords <- sf::st_coordinates(pts_3005)
  # An unparseable `scale` is an expected input, not an exception: it yields NA, the
  # frame gets no footprint, and that is reported by name below. Base R's
  # "NAs introduced by coercion" would arrive alongside that as a second, vaguer warning
  # pointing at no column in particular.
  scale_num <- suppressWarnings(
    as.numeric(stringr::str_remove(centroids_sf$scale, "1:"))
  )

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
    # `as.character()` is load-bearing on empty input: `ifelse(logical(0), ...)`
    # returns `logical(0)`, so a query that matched no frames would report its
    # basis as a logical column. Binding that to a populated result — the
    # per-AOI ledger this reporting surface exists for — fails on the type
    # rather than yielding an empty block of rows.
    basis <- as.character(ifelse(is.na(width_in), "unknown_format", media))
  }

  # Sensor dimensions for digital frames, from the shipped camera table. Consulted only
  # where `formats` did not already resolve the row, so a caller's own `format_size`
  # still wins \u2014 it is the documented escape hatch for a camera `fly` does not know.
  fmt <- fly_camera_format(centroids_sf)
  from_table <- is.na(width_in) & !is.na(fmt$width_mm)

  width_source <- rep(NA_character_, n)
  width_source[from_table] <- fmt$width_source[from_table]
  # A frame naming a withheld calibration is not `from_table` — it resolved to nothing —
  # so without this the refusal is computed and then dropped, and the frame is
  # indistinguishable from one whose media was simply unknown.
  withheld <- is.na(width_in) & !is.na(fmt$width_source) &
    startsWith(fmt$width_source, "withheld:")
  width_source[withheld] <- fmt$width_source[withheld]
  basis[from_table] <- ifelse(fmt$inferred[from_table], "inferred_format",
                              as.character(centroids_sf$media)[from_table])

  unresolved <- is.na(width_in) & !from_table
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

  # Film, and anything `format_size` names: ground width is the format width times the
  # reported scale, and the negative is square.
  half_cross <- width_in * scale_num * 0.0254 / 2
  half_along <- half_cross

  # Digital: ground width is the pixel count times the ground sample distance. This uses
  # neither `scale` nor a DEM.
  #
  # `scale` is deliberately not used. Measured against terrain on 40 UltraCam Eagle
  # frames, sizing a digital frame from the catalogue's `SCALE` gives 34% of its true
  # width, because that field is a derived nominal figure rather than the image scale \u2014
  # the pixel pitch it implies is ~12.5 um for every camera regardless of model, against
  # real pitches of 3.9 to 12 um. A third-size footprint would still draw, still overlap
  # its neighbours and still yield a coverage percentage, which is the failure #30 was
  # written to prevent.
  gsd_m <- rep(NA_real_, n)
  if ("ground_sample_distance" %in% names(centroids_sf)) {
    gsd_m <- fly_gsd_m(as.numeric(centroids_sf$ground_sample_distance))
  }
  by_gsd <- from_table & !is.na(fmt$px_cross) & !is.na(fmt$px_along) &
    !is.na(gsd_m) & gsd_m > 0
  half_cross[by_gsd] <- fmt$px_cross[by_gsd] * gsd_m[by_gsd] / 2
  half_along[by_gsd] <- fmt$px_along[by_gsd] * gsd_m[by_gsd] / 2

  # Flight-line azimuth, for rotating a non-square footprint onto the flight line.
  #
  # Decided from the FORMAT's aspect ratio, not from the half-dimensions. The
  # half-dimensions are NA for every camera-table row until a sizing route fills them,
  # and the DEM route fills them *after* this point — so keying on them would leave
  # `non_square` FALSE for exactly the frames the DEM exists to size, drawing them
  # axis-aligned while `fly_bearing()` had a perfectly good azimuth for them. It would
  # also make the answer depend on what else was in the batch. The aspect ratio is known
  # before any route runs, which is what makes it the right thing to key on.
  #
  # This is the same NA-by-construction fact that has now bitten three separate
  # conditions in this function; a value that only some routes populate is not a safe
  # thing to branch on.
  fmt_aspect_cross <- ifelse(is.na(width_in), fmt$width_mm, width_in * 25.4)
  fmt_aspect_along <- ifelse(is.na(width_in), fmt$height_mm, width_in * 25.4)
  non_square <- !is.na(fmt_aspect_cross) & !is.na(fmt_aspect_along) &
    abs(fmt_aspect_cross - fmt_aspect_along) >
      sqrt(.Machine$double.eps) * pmax(fmt_aspect_cross, fmt_aspect_along)

  # `fly_bearing()` stops rather than returning NA when its columns are absent, and
  # `fly_footprint()` requires only `scale`, so the guard belongs here.
  bearing <- rep(NA_real_, n)
  if (any(non_square) && all(c("film_roll", "frame_number") %in% names(centroids_sf))) {
    bearing <- fly_bearing(centroids_sf)$bearing
  }
  if (any(non_square & !is.finite(bearing))) {
    width_source[non_square & !is.finite(bearing)] <- paste0(
      width_source[non_square & !is.finite(bearing)], "; axis_aligned_no_bearing"
    )
  }

  # Keyed on the half-dimensions, not on width_in: an unparseable `scale` also leaves a
  # frame with no footprint, and a frame with no footprint has had no terrain treatment
  # to report.
  #
  # A frame sized from its ground sample distance did not come from the reported scale
  # and did not come from a DEM, so it gets its own value rather than borrowing
  # `nominal_scale` \u2014 which is documented as "sized from the reported scale" and would
  # be a false claim about the one route that deliberately avoids it.
  terrain <- as.character(ifelse(is.na(half_cross), NA_character_, "nominal_scale"))
  terrain[by_gsd] <- "gsd_scaled"
  height_agl <- rep(NA_real_, n)
  dem_coverage <- rep(NA_real_, n)

  if (!is.null(dem)) {
    focal_m <- centroids_sf$focal_length / 1000

    # Format width in metres, whichever way the row was resolved: `negative_size` is
    # inches, the camera table is millimetres.
    fmt_cross_m <- ifelse(is.na(width_in), fmt$width_mm / 1000, width_in * 0.0254)
    fmt_along_m <- ifelse(is.na(width_in), fmt$height_mm / 1000, width_in * 0.0254)

    resize <- function(e) {
      k <- (centroids_sf$flying_height - e) / focal_m
      list(cross = fmt_cross_m * k / 2, along = fmt_along_m * k / 2)
    }

    # Two passes. The first averages the DEM over the nominal-scale rectangle,
    # which yields a height above ground and so a better rectangle; the second
    # averages over that one, since the window being averaged is itself what
    # the correction changes.
    #
    # Keep the size of this in proportion. The correction as a whole moves area
    # by a median 14%; the second pass moves it by at most a further 0.53%, and
    # a third by 0.03%. It is worth one more extract, not the emphasis a bare
    # "iterates until it converges" would imply.
    # The sampling windows are built exactly as the returned footprint is — same two
    # half-dimensions, same rotation. Sampling an unrotated rectangle and returning a
    # rotated one would make `dem_coverage` and the mean elevation describe a shape the
    # caller never receives, which is the returned-versus-measured mismatch this
    # function already guards against elsewhere.
    # Which frames the DEM route may size.
    #
    # NOT `!is.na(half_cross)`. That is the nominal-scale half-side, and it is NA for
    # every row resolved from the camera table — `width_in` is NA there by definition —
    # so keying on it makes the DEM route unreachable for exactly the frames it exists
    # to serve. An inferred-format frame carries no pixel count and so has no GSD route
    # at all; the DEM is its only route, and it would have come back empty with a DEM
    # supplied and no warning.
    dem_eligible <- !by_gsd & (!is.na(half_cross) | from_table)

    # A camera-table frame has no nominal rectangle to sample the first pass over, so
    # seed one from the whole flying height — terrain at sea level, which is the largest
    # plausible window and therefore certain to contain the true footprint. The second
    # pass then averages over the rectangle the first produced, as it does for film.
    seed_cross <- half_cross
    seed_along <- half_along
    need_seed <- dem_eligible & is.na(seed_cross)
    if (any(need_seed)) {
      at_sea_level <- resize(0)
      seed_cross[need_seed] <- at_sea_level$cross[need_seed]
      seed_along[need_seed] <- at_sea_level$along[need_seed]
    }

    first <- fly_dem_sample(dem, fly_rectangles(coords, seed_cross, seed_along, bearing))
    r1 <- resize(first$elev)
    second <- fly_dem_sample(dem, fly_rectangles(coords, r1$cross, r1$along, bearing))

    # Keep the first pass wherever the second could not improve on it, so a
    # frame is never lost to the resize alone.
    elev <- ifelse(is.na(second$elev), first$elev, second$elev)
    agl <- centroids_sf$flying_height - elev
    candidate <- resize(elev)

    # Classify on the half-side we would actually use, not on the inputs that
    # feed it. An NA or zero `focal_length`, or an NA `flying_height`, yields a
    # non-finite half-side that would otherwise become an empty geometry — and
    # an empty geometry here is indistinguishable from one whose recording
    # format was never resolved, so the frame would vanish under a warning
    # pointing at `format_size` rather than at its own metadata.
    #
    # `!by_gsd` is what keeps the DEM from overwriting a frame already sized from its
    # ground sample distance. Without it, passing `dem` would silently switch a digital
    # frame onto a different route — and every downstream consumer forwards `dem`, so
    # that is the ordinary path rather than an edge case. The two routes agree to about
    # 1%, but agreeing is not the same as being interchangeable: the GSD route is the
    # measurement and the DEM route is the estimate.
    corrected <- dem_eligible & is.finite(candidate$cross) & candidate$cross > 0 &
      is.finite(candidate$along) & candidate$along > 0
    uncovered <- dem_eligible & !corrected & is.na(elev)
    unusable <- dem_eligible & !corrected & !uncovered

    # Coverage has to describe the footprint that is actually returned. A
    # corrected frame ships the second pass's rectangle, so it takes the second
    # pass's coverage; a frame that fell back ships the nominal one, so it takes
    # the first pass's. Reading the second pass for a fallback frame is not a
    # rounding difference — terrain above the aircraft gives a negative
    # half-side, which draws a mirrored rectangle somewhere else entirely, and
    # that measured 100% coverage for a footprint only 30% covered.
    covered <- ifelse(corrected, second$covered, first$covered)

    # Every fallback keeps the frame at nominal scale rather than dropping it:
    # a frame we cannot correct is still a frame.
    if (any(uncovered)) {
      warning(
        sum(uncovered), " of ", sum(dem_eligible), " frames fall outside the DEM's ",
        "coverage and were sized from nominal scale instead. See ",
        "`footprint_terrain`.",
        call. = FALSE
      )
    }
    if (any(unusable)) {
      warning(
        sum(unusable), " of ", sum(dem_eligible), " frames have `flying_height` or ",
        "`focal_length` values that give no usable height above ground \u2014 ",
        "missing, zero, or terrain at or above the aircraft. Check that ",
        "`flying_height` is metres above sea level. Sized from nominal scale ",
        "instead. See `footprint_terrain`.",
        call. = FALSE
      )
    }

    # A footprint hanging off the edge of the DEM still yields a mean, taken
    # from whichever part had data. That is the best estimate available and is
    # kept — but it is not the full-frame mean it would otherwise be taken for,
    # so it is reported rather than passed off silently.
    partial <- corrected & !is.na(covered) & covered < fly_dem_coverage_min()
    if (any(partial)) {
      warning(
        sum(partial), " of ", sum(corrected), " corrected frames are less than ",
        round(100 * fly_dem_coverage_min()), "% covered by the DEM (as little ",
        "as ", round(100 * min(covered[partial])), "% of one footprint). Their ",
        "ground elevation is the mean of the covered part, which need not ",
        "represent the whole. Buffer the DEM past the corner of the widest ",
        "footprint \u2014 half its width times sqrt(2), not half its width. ",
        "See `dem_coverage`.",
        call. = FALSE
      )
    }

    half_cross[corrected] <- candidate$cross[corrected]
    half_along[corrected] <- candidate$along[corrected]
    height_agl[corrected] <- agl[corrected]
    # Reported for every frame that had a footprint to sample, not only the
    # corrected ones: `no_dem_coverage` is a measured zero, and leaving it NA
    # makes the documented "filter on dem_coverage" workflow impossible.
    #
    # Excluding `by_gsd`, though. A DEM was sampled under those frames, but the number
    # describes a window that had no bearing on the geometry returned — the footprint
    # came from the pixel count and the ground sample distance. Reporting it would be a
    # coverage figure for a shape the caller never receives.
    dem_coverage[dem_eligible] <- covered[dem_eligible]
    terrain[dem_eligible] <- "nominal_scale"
    terrain[corrected] <- "dem_agl"
    terrain[uncovered] <- "no_dem_coverage"
    terrain[unusable] <- "nominal_scale"
  }

  # A frame with no rectangle has had no terrain treatment to report, whichever route
  # failed to produce one. Keeping the invariant "footprint_terrain is NA exactly where
  # the geometry is empty" is what lets a caller read the column at all.
  no_geom <- is.na(half_cross) | is.na(half_along) | half_cross <= 0 | half_along <= 0
  terrain[no_geom] <- NA_character_
  height_agl[no_geom] <- NA_real_
  dem_coverage[no_geom] <- NA_real_

  # A frame whose format resolved but which could not be sized is the quiet case: its
  # `footprint_basis` names a real format and `width_source` names a calibration, so
  # nothing about the row says the geometry is empty. It is not covered by the
  # unknown-format warning above, and with no `dem` it is covered by none of the terrain
  # warnings either.
  # Split by cause: a film frame reaches this state through an unparseable `scale`, and
  # telling its owner to supply a ground sample distance points at the wrong column.
  unsized_digital <- from_table & no_geom
  unsized_film <- !is.na(width_in) & no_geom
  if (any(unsized_digital)) {
    warning(
      sum(unsized_digital), " of ", n, " frames have a known recording format but no ",
      "way to size it, so they have no footprint. A digital frame needs either a ",
      "`ground_sample_distance` and a calibrated pixel count, or `dem` together with ",
      "`flying_height` and `focal_length`. See `footprint_basis` and `width_source`.",
      call. = FALSE
    )
  }
  if (any(unsized_film)) {
    warning(
      sum(unsized_film), " of ", n, " frames have a known recording format but no ",
      "usable `scale`, so they have no footprint. Expected a value like \"1:12000\".",
      call. = FALSE
    )
  }

  # Assign the reporting columns onto the attribute frame rather than passing
  # them to `st_sf()` as trailing arguments. `st_sf()` builds its attribute
  # frame with `else if (inherits(x[[1]], c("tbl_df", "tbl"))) x[[1]]`, so a
  # tibble first argument means every trailing named column is silently
  # discarded — and `bcdata::collect()` returns a tibble, which is to say the
  # package's own documented data source (#35). Inside `x[[1]]` they survive,
  # and the caller keeps the class they passed in.
  attrs <- sf::st_drop_geometry(pts_3005)
  attrs$footprint_basis <- basis
  attrs$footprint_terrain <- terrain
  attrs$width_source <- width_source
  attrs$height_agl <- height_agl
  attrs$dem_coverage <- dem_coverage

  result <- sf::st_sf(
    attrs,
    geometry = fly_rectangles(coords, half_cross, half_along, bearing)
  )

  sf::st_transform(result, input_crs)
}
