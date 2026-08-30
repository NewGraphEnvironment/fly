# Recording-format dimensions for the digital cameras in the BC air photo catalogue.
#
# `AIMG_PHOTO_CENTROIDS_SP` carries no sensor size, which is why #30 refused to size
# digital frames rather than invent one. The number is recoverable from the calibration
# report each frame links to through `camera_calibration_url`, and
# `data-raw/make_camera_formats.R` parses it out of those reports into
# `inst/extdata/camera_formats.csv`. See fly#32.
#
# Two key types share one table so one lookup reads both:
#
#   `calib_file`   — keyed on the calibration file the frame names. Exact: the report
#                    gives the array size and pixel pitch, and the millimetres are
#                    checked against them.
#   `focal_length` — keyed on the catalogue's `focal_length`, for the ~20% of digital
#                    frames carrying no calibration URL. Inferred, and carrying
#                    `width_spread_pct` so the room for error travels with the number.

fly_camera_cache <- new.env(parent = emptyenv())

fly_camera_read <- function(file) {
  if (is.null(fly_camera_cache[[file]])) {
    path <- system.file("extdata", file, package = "fly")
    if (!nzchar(path)) {
      stop("`", file, "` is missing from the installed package.", call. = FALSE)
    }
    # `key` must stay character: the fallback keys are focal lengths, and read.csv would
    # type them numeric, so `"80"` and `80` would stop matching between the two halves
    # of the same table.
    fly_camera_cache[[file]] <- utils::read.csv(
      path, stringsAsFactors = FALSE, colClasses = c(key = "character")
    )
  }
  fly_camera_cache[[file]]
}

# The shipped format table.
fly_camera_table <- function() fly_camera_read("camera_formats.csv")

# Calibrations the catalogue offers that are deliberately not shipped, each with the
# reason. Kept beside the table rather than dropped, so "we have not looked at this"
# and "we looked and could not use it" stay distinguishable.
fly_camera_excluded <- function() fly_camera_read("camera_formats_excluded.csv")


# `GROUND_SAMPLE_DISTANCE` is recorded in CENTIMETRES.
#
# Worth a named function rather than a bare `/ 100`, because getting it wrong is a
# factor of 100 in every digital footprint and the field name says nothing about units.
# Confirmed against the catalogue's own arithmetic: an UltraCam Eagle frame at GSD 30
# gives 20010 px x 0.30 m = 6003 m across, which agrees with sizing the same frame from
# `104.052 mm x (height above ground / focal length)`. In metres it would be 100x.
fly_gsd_m <- function(gsd) gsd / 100


# Resolve each row to a recording format.
#
# Keyed on `camera_calibration_url`, not on `media` or `focal_length`. `media` is a
# single value (`Digital - Colour`) across all 14 cameras in the record, and focal
# length is ambiguous — catalogue focal 92 spans an 87.1 mm DMC II and a 100.3 mm
# DMC III, a 15% difference. The calibration file is exact, and it is the only key that
# separates the two cameras the catalogue files under serial 20814295: an UltraCam
# Eagle through 2017 and a different body in 2018, whose own report numbers it 22814295.
#
# Where no calibration URL is present — about a fifth of digital frames — the catalogue
# focal length is the only remaining discriminator, so it is used and the row is marked
# inferred. That direction is defensible for WIDTH, which spreads 1-3% at a given focal,
# and not for PIXEL COUNT, which spreads 32-83%; the fallback rows carry no pixel counts
# for exactly that reason, which keeps them off the `px * GSD` route by construction.
#
# Returns one row per input row, all-NA where nothing resolved.
fly_camera_format <- function(centroids_sf) {
  n <- nrow(centroids_sf)
  none <- data.frame(
    width_mm = rep(NA_real_, n), height_mm = rep(NA_real_, n),
    px_cross = rep(NA_real_, n), px_along = rep(NA_real_, n),
    camera = rep(NA_character_, n), width_source = rep(NA_character_, n),
    # `resolved` and `inferred` are separate on purpose. A row that resolved to nothing
    # is also `inferred = FALSE`, so `!inferred` — the natural filter for "trustworthy"
    # — would sweep up every unresolved frame as well.
    resolved = rep(FALSE, n), inferred = rep(FALSE, n), stringsAsFactors = FALSE
  )
  if (n == 0 || !"media" %in% names(centroids_sf)) {
    return(none)
  }

  media <- as.character(centroids_sf$media)
  # Film is sized from `negative_size`; this table describes sensors only. Restricting
  # to digital also stops a fallback row keyed on focal length from quietly resolving a
  # film frame that happens to share the focal length.
  digital <- !is.na(media) & !(media %in% fly_film_media())
  if (!any(digital)) {
    return(none)
  }

  out <- none
  tbl <- fly_camera_table()
  calib <- tbl[tbl$key_type == "calib_file", ]
  fb <- tbl[tbl$key_type == "focal_length", ]

  take <- function(rows, src, from, inferred) {
    out$width_mm[rows]     <<- from$width_mm
    out$height_mm[rows]    <<- from$height_mm
    out$px_cross[rows]     <<- from$px_cross
    out$px_along[rows]     <<- from$px_along
    out$camera[rows]       <<- from$camera
    out$width_source[rows] <<- src
    out$resolved[rows]     <<- TRUE
    out$inferred[rows]     <<- inferred
  }

  matched <- rep(FALSE, n)
  if ("camera_calibration_url" %in% names(centroids_sf)) {
    u <- as.character(centroids_sf$camera_calibration_url)
    has_url <- digital & !is.na(u) & nzchar(u)
    key <- rep(NA_character_, n)
    # `basename(character(0))` is character(0), so guard rather than assign into a
    # zero-length subscript.
    if (any(has_url)) {
      key[has_url] <- sub("\\.zip$", "", basename(u[has_url]))
    }
    m <- match(key, calib$key)
    matched <- !is.na(m)
    if (any(matched)) {
      take(matched, key[matched], calib[m[matched], ], FALSE)
    }

    # A frame whose calibration was deliberately withheld must not fall through to
    # focal-length inference. The two withheld medium-format cameras are about 53 mm
    # wide against the ~104 mm large-format bodies that share their focal neighbourhood,
    # so inferring one would be ~1.95x too wide and 3.8x too much ground area. Today
    # they happen to return NA because no fallback row exists at their focal lengths —
    # that is safety by coincidence of the current table, and this makes it structural.
    ex <- fly_camera_excluded()
    refused <- !is.na(key) & key %in% ex$key[ex$key_type == "calib_file"]
    out$width_source[refused] <- paste0("withheld:", key[refused])
    matched <- matched | refused
  }

  if ("focal_length" %in% names(centroids_sf) && nrow(fb)) {
    # Match numerically rather than on a formatted string: `as.character(100)` and
    # `as.character(100L)` agree, but a double that prints as "1e+02" would not.
    m <- match(as.numeric(centroids_sf$focal_length), as.numeric(fb$key))
    use <- digital & !matched & !is.na(m)
    if (any(use)) {
      take(use, paste0("focal_length=", fb$key[m[use]]), fb[m[use], ], TRUE)
    }
  }

  out
}
