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
#
# `calib_file` rows are reached a second way since fly#50: by the camera serial or model
# the province publishes in a frame's PAT-B georeferencing file, which is how a frame with
# no calibration URL gets an exact format rather than an inference. Same rows, a different
# key — see "Resolving a camera the province named" below, and `fly_camera_patb()`.

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


# --- Resolving a camera the province named, rather than one this package inferred -----
#
# The catalogue publishes per-frame exterior orientation through `patb_georef_url`, and
# those files name the camera. `fly_camera_patb()` reads them; this half turns the name
# into a format. See fly#50 and `inst/notes/camera-formats.md`.

# Digit tokens in a serial, longest run first.
#
# TOKENISED, not concatenated. `gsub("[^0-9]", "", "UC-Fp-1-20114172-f70")` is
# `12011417270`, which matches nothing — the value is body-index / serial / focal length,
# so the runs have to stay separate. The longest run is the serial in every shipped
# value; ties keep both rather than picking one.
fly_serial_tokens <- function(x) {
  if (is.na(x)) return(character(0))
  runs <- regmatches(x, gregexpr("[0-9]+", x))[[1]]
  if (!length(runs)) return(character(0))
  runs[nchar(runs) == max(nchar(runs))]
}

# Serial -> format index, in two passes.
#
# Built from `calib_file` rows ONLY. The `focal_length` keys are bare numbers (`"80"`,
# `"92"`, `"100"`, `"120"`, `"127"`), so pooling them lets a short serial resolve to a
# fallback row — which carries `width_mm` but no pixel count by deliberate design, and so
# would produce a confident `footprint_basis` and no footprint at all. Worse than the
# `inferred_format` it replaced.
#
# The two passes are not one union, and the difference decides 14,717 frames. Serial
# `20814295` reaches five rows: four UltraCam Eagle calibrations, and the 2018 row, which
# the catalogue FILES under `20814295` while the camera's own report numbers it
# `22814295` and its format differs (26460 x 17004 against 20010 x 13080). A union calls
# that ambiguous and refuses all five. Reading `report_serial` first gives the four that
# agree; `22814295` reaches the 2018 row on its own.
#
# The key pass is still needed, and not only for rows whose report gave no serial: the
# Intergraph DMC reports itself `DMC01 - 0039`, whose longest run is `0039`, while a
# PAT-B lens number for that body is `100039` — which only the key `dmc100039_2006`
# carries. Report-first-then-key resolves both; report-only would lose the DMC.
#
# The `_YYYY` suffix is stripped before tokenising the key. Left on, token `2014` reaches
# `20814295_2014` and `50311261_2014`, which AGREE on their format — so the ambiguity
# guard stays silent and any four-digit identity equal to 2014 resolves confidently to an
# UltraCam Eagle.
#
# Deliberately NOT memoised, unlike the table it reads. It is twelve rows, it is built
# once per `fly_camera_format()` call rather than once per frame, and a cached index
# would silently outlive a test that swaps the table underneath it — which is the only
# way to reach the ambiguity guard, since the shipped table has no colliding token.
fly_camera_serial_index <- function() {
  calib <- fly_camera_table()
  calib <- calib[calib$key_type == "calib_file", ]

  build <- function(values) {
    out <- list()
    for (i in seq_len(nrow(calib))) {
      for (tok in fly_serial_tokens(values[i])) {
        out[[tok]] <- c(out[[tok]], i)
      }
    }
    out
  }
  list(
    rows   = calib,
    report = build(calib$report_serial),
    key    = build(sub("_[0-9]{4}$", "", calib$key))
  )
}

# A camera label reduced to something two sources can be compared on.
#
# The manufacturer prefix is dropped because the PAT-B files carry it (`Vexcel Ultracam
# XP`) and the calibration reports do not (`UltraCamXp`). Everything else is compared on
# alphanumerics only, and EXACTLY: a prefix match would resolve the published
# `DMC II 230` from the shipped `DMC II` row, and a DMC II 250 (17216 x 14656) or 140
# (12096 x 11200) from that same row, silently and with `inferred = FALSE`. An
# unrecognised string refuses instead.
fly_camera_label <- function(x) {
  x <- tolower(trimws(as.character(x)))
  x <- sub("^(vexcel|microsoft|zeiss|intergraph|leica|z/i imaging|z/i|wehrli)\\s+", "", x)
  gsub("[^a-z0-9]", "", x)
}

# Resolve one identity to a row of the format table, or say why not.
#
# Returns `row` (an index into the index's `rows`, or NA), `note` (the refusal tag, or
# NA) and `via` (which identity answered). Both `row` and `note` NA means there was no
# identity to resolve in the first place.
#
# `via` is RETURNED rather than re-derived by the caller. A caller deciding "was this a
# serial or a name?" by re-testing the serial has to reproduce the filter below exactly,
# and the first version did not: a `camera_serial` of `"0"` has a digit token, so it
# reported `patb_serial=0` on a row the name had resolved.
fly_camera_resolve_identity <- function(serial, name, idx = fly_camera_serial_index()) {
  agree <- function(rows) {
    length(unique(paste(idx$rows$px_cross[rows], idx$rows$px_along[rows],
                        idx$rows$width_mm[rows], idx$rows$height_mm[rows]))) == 1L
  }

  # A serial is the strong identity and it is CONCLUSIVE: where one is present, the
  # camera name is never consulted, not even to fill in an unknown serial. Measured —
  # `d_001_fi_16_georef.txt` labels both its cameras `UltraCam XP` and one of them is
  # serial 70912643, a `UC-SX` UltraCam X. Falling through from an unknown serial to that
  # string sizes those frames 20% wide.
  s <- if (is.na(serial)) character(0) else fly_serial_tokens(as.character(serial))
  # A lens number of 0 is how the 2012 archives spell "not recorded", and a one- or
  # two-digit token cannot identify a camera body.
  s <- s[nchar(s) >= 3 & !grepl("^0+$", s)]
  if (length(s)) {
    # EVERY longest-equal token is resolved, not just the first. `fly_serial_tokens()`
    # keeps ties on purpose, and reading `s[1]` would pick by position in arbitrary
    # provincial text: measured, `"100039-327542"` gives a 13824 px DMC and
    # `"327542-100039"` a 25728 px DMC III — the same identity, two sensors, decided by
    # digit order. That is exactly what `ambiguous_serial:` exists to refuse.
    #
    # A token that matches nothing is ignored rather than fatal; what refuses is two
    # tokens reaching formats that disagree. With one token — every real value measured —
    # this is the single-token behaviour unchanged.
    rows <- integer(0)
    for (tok in s) {
      for (pass in c("report", "key")) {
        hit <- idx[[pass]][[tok]]
        if (is.null(hit)) next
        rows <- c(rows, hit)
        break
      }
    }
    if (length(rows)) {
      if (agree(rows)) return(list(row = rows[1], note = NA_character_, via = "serial"))
      return(list(row = NA_integer_,
                  note = paste0("ambiguous_serial:", paste(s, collapse = "/")),
                  via = "serial"))
    }
    return(list(row = NA_integer_, note = paste0("unknown_serial:", s[1]), via = "serial"))
  }

  if (!is.na(name) && nzchar(as.character(name))) {
    lab <- fly_camera_label(name)
    rows <- which(fly_camera_label(idx$rows$camera) == lab)
    if (length(rows)) {
      if (agree(rows)) return(list(row = rows[1], note = NA_character_, via = "camera"))
      return(list(row = NA_integer_, note = paste0("ambiguous_camera:", name), via = "camera"))
    }
    return(list(row = NA_integer_, note = paste0("unknown_camera:", name), via = "camera"))
  }

  list(row = NA_integer_, note = NA_character_, via = NA_character_)
}

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

  # A camera the province named, from the frame's PAT-B file. See `fly_camera_patb()`,
  # which is what puts these columns on the centroids.
  #
  # Gated on `matched`, which already carries the withheld refusals — NOT on `resolved`
  # or on `is.na(width_mm)`. A withheld calibration is unresolved by construction, so a
  # freshly computed predicate would let those frames through this route and start
  # shipping numbers the generator deliberately refuses to produce.
  #
  # Placed between the calibration URL and the focal-length fallback: a calibration is
  # exact and always wins, and an inference must never pre-empt a named camera.
  patb_note <- rep(NA_character_, n)
  if (any(c("camera_serial", "camera_name") %in% names(centroids_sf))) {
    serial <- if ("camera_serial" %in% names(centroids_sf)) {
      as.character(centroids_sf$camera_serial)
    } else {
      rep(NA_character_, n)
    }
    cam <- if ("camera_name" %in% names(centroids_sf)) {
      as.character(centroids_sf$camera_name)
    } else {
      rep(NA_character_, n)
    }

    eligible <- which(digital & !matched & !(is.na(serial) & is.na(cam)))
    if (length(eligible)) {
      idx <- fly_camera_serial_index()
      for (i in eligible) {
        r <- fly_camera_resolve_identity(serial[i], cam[i], idx)
        if (!is.na(r$row)) {
          src <- if (identical(r$via, "serial")) {
            paste0("patb_serial=", serial[i])
          } else {
            paste0("patb_camera=", cam[i])
          }
          take(i, src, idx$rows[r$row, ], FALSE)
          matched[i] <- TRUE
        } else if (!is.na(r$note)) {
          # A refusal here does NOT block the focal-length fallback, unlike a withheld
          # calibration. Withholding says the sensor is medium-format and an inference
          # would be ~2x wrong; an unrecognised serial says nothing about sensor size, so
          # the fallback is exactly as defensible as it was before this route existed and
          # removing it would cost 13,616 measured frames their DEM footprint. The note
          # is carried alongside instead, so the refusal is still on the record.
          patb_note[i] <- r$note
        }
      }
    }
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

  # Carry every PAT-B refusal into `width_source`, whether or not something else went on
  # to resolve the row. `paste0()` on an NA gives the string "NA", so the two cases are
  # assembled rather than pasted blindly.
  keep <- !is.na(patb_note)
  if (any(keep)) {
    out$width_source[keep] <- ifelse(
      is.na(out$width_source[keep]),
      patb_note[keep],
      paste0(out$width_source[keep], "; ", patb_note[keep])
    )
  }

  out
}
