# Reading the camera identity out of a frame's PAT-B georeferencing file.
#
# The BC Data Catalogue publishes per-frame exterior orientation through
# `patb_georef_url`, and those files name the camera that flew the frame. For the ~41,000
# digital frames carrying no `camera_calibration_url`, that name is the only route to a
# recording format, and `fly_camera_format()` turns it into one. See fly#50 and
# `inst/notes/camera-formats.md`.
#
# Three schemas, measured 2026-09-06 over every archive those frames reference. They are
# NOT identified by file extension — the `.txt` inside one zip is a CSV, the `.csv`
# inside another is a different schema, and a bare `.csv` is a third. Dispatch on the
# columns present.
FLY_PATB_SCHEMAS <- list(
  # `gr_*` / `ccre_*`. Inside a zip beside one or more `.ori` files.
  gr = list(
    require = "frm_roll_frame",
    key = "frm_roll_frame", serial = "ccre_lens_number", camera = "ccre_camera_type",
    gsd = "seg_gsd", airp_id = NA_character_
  ),
  # `eop_*`, carrying a serial and no camera string.
  eop = list(
    require = c("roll_frame", "cam_s_no"),
    key = "roll_frame", serial = "cam_s_no", camera = NA_character_,
    gsd = NA_character_, airp_id = NA_character_
  ),
  # Bare CSV. The only schema carrying `airp_id`, and the only one whose camera identity
  # is a model string rather than a serial — `lens_no` is 0 on every row of both 2012
  # archives.
  bare = list(
    require = c("roll_frame", "camera"),
    key = "roll_frame", serial = "lens_no", camera = "camera",
    gsd = "gsd", airp_id = "airp_id"
  )
)

fly_patb_schema <- function(d) {
  for (nm in names(FLY_PATB_SCHEMAS)) {
    if (all(FLY_PATB_SCHEMAS[[nm]]$require %in% names(d))) return(FLY_PATB_SCHEMAS[[nm]])
  }
  NULL
}

# `bcd13300_001` -> roll `bcd13300`, frame 1.
#
# Split rather than pad. Every archive read used three digits and frame numbers running
# to 990, so three is what was observed and not a guarantee; comparing integers has no
# width to get wrong, and it is the form `data-raw/georef_calibrate-corner_mapping.R`
# already uses. Case is normalised on both sides — the values are lowercase inside a file
# named `D_005_EMN_19_georef.csv`, which is not enough to conclude they always will be.
fly_patb_key <- function(roll, frame) {
  r <- tolower(trimws(as.character(roll)))
  f <- suppressWarnings(as.integer(frame))
  # `paste0()` stringifies NA, so an unusable roll or frame would become the literal key
  # `"bcd12001_NA"` — and match the archive row whose own frame suffix did not parse. The
  # `is.na()` guard on the id join cannot see that, because by the time `match()` runs the
  # value is three characters rather than NA. The stronger form is a roll numbering its
  # frames `012A`: every frame on both sides collapses onto one key.
  out <- paste0(r, "_", f)
  out[is.na(r) | is.na(f)] <- NA_character_
  out
}

# A PAT-B file, or a reason it is not one.
#
# Two of the seven archives these frames reference are 404s answered with a 196-byte HTML
# body under a `.csv` name. `utils::download.file()` sets FAILONERROR and so raises rather
# than writing it — measured, it leaves no file at all — which is why `fly_fetch()` already
# reports those as failures. But FAILONERROR is a property of one client: anything that
# does not set it, or a copy already sitting in `dest_dir` from a tool that does not, hands
# the HTML straight to the parser. So absence is read from the content too. See
# `code-check-r.md`, "`download.file(quiet = TRUE)` never tells you the HTTP status".
# Returns the table, or a STRING saying why there is none. Five outcomes are
# distinguishable at the point they are met and need different responses: an HTML body is
# the province's 404, a read error is this machine, and a file that parses cleanly into an
# unrecognised schema is a province-side change worth naming on its own. Collapsing them
# to NULL reports all five as "the catalogue published nothing usable".
fly_patb_read_one <- function(path) {
  # `warning` as well as `error`: with no extension filter this is offered every member of
  # an archive, and `readLines()` WARNS rather than errors on embedded nulls, so a binary
  # member would otherwise raise a warning out of a function whose job is to say "not this
  # one". A directory entry errors and is caught here too.
  head_bytes <- tryCatch(readLines(path, n = 1L, warn = FALSE),
                         error = function(e) structure("", msg = conditionMessage(e)),
                         warning = function(w) structure("", msg = conditionMessage(w)))
  if (!is.null(attr(head_bytes, "msg"))) {
    return(paste0("could not be read (", attr(head_bytes, "msg"), ")"))
  }
  if (!length(head_bytes) || !nzchar(head_bytes[1])) return("is empty")
  # `useBytes` because F5 removed the extension filter, so this now sees every member of
  # an archive and a first "line" of binary warns `input string 1 is invalid` otherwise -
  # a package warning the caller can do nothing with, and fatal under `options(warn = 2)`.
  if (grepl("^\\s*<", head_bytes[1], useBytes = TRUE)) {
    return("is an HTML page, not a PAT-B table (a 404 body)")
  }
  # `suppressWarnings`, NOT a `warning =` handler. A handler returns instead of the value,
  # so it DISCARDS a table that parsed perfectly: `read.table` warns "incomplete final
  # line found by readTableHeader" whenever a small file has no trailing newline, and
  # measured, a 1-4 row archive was then refused as "could not be parsed". Two states -
  # parsed with a cosmetic warning, and genuinely unparseable - collapsed into one, with
  # the fact that separates them (`d` IS a data.frame) thrown away by the handler. A
  # binary member that warns about embedded nulls still returns a garbage frame, which
  # fails schema dispatch one line down and is reported as such.
  d <- tryCatch(suppressWarnings(utils::read.csv(path, stringsAsFactors = FALSE)),
                error = function(e) structure(list(), msg = conditionMessage(e)))
  if (!is.data.frame(d)) {
    return(paste0("could not be parsed (", attr(d, "msg"), ")"))
  }
  if (!nrow(d)) return("parsed to zero rows")
  if (is.null(fly_patb_schema(d))) {
    return(paste0("parsed, but its columns match no PAT-B schema this version knows (",
                  paste(utils::head(names(d), 6), collapse = ", "), ")"))
  }
  d
}

# Every table an archive holds, whether it is a bare file or a zip.
#
# EVERY member is parsed, not the first: a `list.files()[1]` silently loses the rest, and
# nothing establishes that an archive holds one georef table. `.ori` / `.ORI` members
# carry full exterior orientation and no camera identity at all, and are skipped by
# failing to dispatch rather than by matching their name.
# Returns the tables, or a string naming why there are none. Those are different facts:
# "the province published nothing usable" and "this machine could not read it" both leave
# a frame unresolved, and reporting the first for the second sends the operator to the
# catalogue when the problem is a full disk or an unwritable cache.
#
# Extracted under `tempfile()` rather than beside the archive: a persistent `dest_dir`
# would otherwise accumulate a hidden tree per archive forever, and the extraction would
# inherit that directory's writability.
#
# EVERY member is offered to `fly_patb_read_one()`, with no extension filter. An `.ori`
# is excluded by failing to dispatch — it is fixed-width text and matches no schema — and
# that has to be the operative guard rather than a comment above an allowlist, because
# the whole point of dispatching on columns is that the province has already used two
# different extensions for two different schemas. A filter here would drop a georef table
# published under a third one, which dispatches perfectly well.
fly_patb_tables <- function(path) {
  if (!grepl("\\.zip$", path, ignore.case = TRUE)) {
    d <- fly_patb_read_one(path)
    if (is.data.frame(d)) return(list(d))
    return(structure(list(), error = d))
  }
  ex <- tempfile("fly_patb_zip")
  if (!dir.create(ex, recursive = TRUE)) {
    return(structure(list(), error = paste0("could not be unpacked: no scratch directory (",
                                            ex, ")")))
  }
  on.exit(unlink(ex, recursive = TRUE), add = TRUE)
  members <- tryCatch(utils::unzip(path, exdir = ex),
                      error = function(e) structure(character(0), msg = conditionMessage(e)),
                      warning = function(w) structure(character(0), msg = conditionMessage(w)))
  if (!length(members)) {
    # Not `%||%`: that is base R only from 4.4.0 and DESCRIPTION allows 4.1.
    why <- attr(members, "msg")
    if (is.null(why)) why <- "no members"
    return(structure(list(), error = paste0("could not be unpacked (", why, ")")))
  }
  read <- lapply(members, fly_patb_read_one)
  ok <- vapply(read, is.data.frame, logical(1))
  # One reason per member, aligned with `read`. NOT `unlist(read)`: that flattens the
  # successful members' data frames into hundreds of elements, so the vector stops lining
  # up with `ok` and every comparison recycles.
  why <- vapply(read, function(x) if (is.data.frame(x)) "" else as.character(x)[1],
                character(1))
  if (!any(ok)) {
    return(structure(list(), error = paste0(
      "holds ", length(members), " member(s), none of them a PAT-B table: ",
      paste(paste0(basename(members), " ", why), collapse = "; ")
    )))
  }
  # A member that failed while another succeeded is reported only when it failed for a
  # reason on THIS machine. Everything else - failing to dispatch, parsing to garbage,
  # being empty - is the ordinary `.ori` case and is correctly silent, and gating on the
  # dispatch message alone was not enough: an `.ori` is fixed-width text, so it reaches
  # `read.csv` and fails there in several different ways. Without any of this, a second
  # georef table lost to a disk error is dropped with no message at all and its frames
  # come back NA under a cheerful "N of M resolved" line - F2's collapse, one level up.
  lost <- !ok & grepl("could not be read", why)
  if (any(lost)) {
    warning("In ", basename(path), ", ", sum(lost), " member(s) could not be read: ",
            paste(paste0(basename(members[lost]), " ", why[lost]), collapse = "; "),
            call. = FALSE)
  }
  read[ok]
}


#' Read the camera a frame's PAT-B file names
#'
#' Downloads and parses the per-frame georeferencing files the BC Data Catalogue
#' publishes through `patb_georef_url`, and attaches the camera identity they
#' carry to the photo centroids. [fly_footprint()] then sizes those frames from
#' the named camera instead of refusing them, which needs no DEM.
#'
#' @param photos_sf An sf object with airphoto metadata, typically from the BC
#'   Data Catalogue centroid layer. Must contain `patb_georef_url`, and
#'   `film_roll` and `frame_number` or `airp_id` to join on.
#' @param dest_dir Directory to cache the downloaded archives in. Defaults to a
#'   session temporary directory; give it a real path to keep them between runs.
#' @param overwrite If `FALSE` (default), archives already in `dest_dir` are
#'   reused rather than re-downloaded.
#' @param quiet Suppress the per-archive progress messages.
#'
#' @return `photos_sf` with four columns added, all `NA` where nothing resolved:
#'   \describe{
#'     \item{`camera_serial`}{the camera or lens serial the file publishes}
#'     \item{`camera_name`}{the model string the file publishes, where it has one}
#'     \item{`patb_gsd`}{ground sample distance in **centimetres**, matching the
#'       catalogue's own units. The catalogue's `ground_sample_distance` is 0 for
#'       whole years of digital imagery, and this is where the number is}
#'     \item{`patb_source`}{the archive each row was resolved from}
#'   }
#'
#' @details
#' This is the only function in the package that reaches the network on the
#' sizing path. [fly_footprint()] takes the columns it produces and never
#' fetches anything itself, so a batch can be resolved once and reused.
#'
#' Three file schemas are in circulation and they are dispatched on the columns
#' present rather than the file extension, because the extension does not
#' identify them. Two of the archives referenced by the frames this exists for
#' are 404s served as HTML under a `.csv` name; those frames are reported as
#' unresolved, by a message naming the archive rather than by an error, so one
#' missing file does not cost a batch its other frames.
#'
#' A serial that the shipped camera table does not recognise is **refused**
#' rather than resolved from the model string beside it. One published archive
#' labels both its cameras `UltraCam XP` while one of them is an UltraCam X, a
#' 20% difference in ground width — so the model string is read only where the
#' file carries no serial at all. See `inst/notes/camera-formats.md`.
#'
#' @examples
#' centroids <- sf::st_read(system.file("testdata/photo_centroids_digital.gpkg",
#'                                      package = "fly"), quiet = TRUE)
#'
#' # Copy the bundled archives into a scratch directory, so this runs offline and
#' # writes nothing into the installed package
#' cache <- file.path(tempdir(), "patb")
#' dir.create(cache, showWarnings = FALSE)
#' file.copy(list.files(system.file("testdata", "patb", package = "fly"),
#'                      full.names = TRUE), cache)
#'
#' resolved <- fly_camera_patb(centroids, dest_dir = cache)
#' table(resolved$camera_serial, useNA = "ifany")
#'
#' # `fly_footprint()` picks the columns up from here. These frames also carry a
#' # calibration report, which wins; drop it and the PAT-B serial sizes them.
#' resolved$camera_calibration_url <- NA_character_
#' fp <- fly_footprint(resolved)
#' unique(fp$width_source)
#'
#' @export
fly_camera_patb <- function(photos_sf, dest_dir = tempfile("fly_patb"),
                            overwrite = FALSE, quiet = FALSE) {
  # Deliberately no `fly_check_points()`. That guard exists because
  # `sf::st_coordinates()` returns one row per vertex for anything but a POINT, and this
  # function never reads a coordinate — it joins on attributes and attaches columns. A
  # guard whose stated reason does not apply is worse than none.
  if (!"patb_georef_url" %in% names(photos_sf)) {
    stop("Column `patb_georef_url` not found in `photos_sf`. Use full BC Data ",
         "Catalogue centroid data to get URL columns.", call. = FALSE)
  }
  has_roll <- all(c("film_roll", "frame_number") %in% names(photos_sf))
  if (!has_roll && !"airp_id" %in% names(photos_sf)) {
    stop("`photos_sf` needs `film_roll` and `frame_number`, or `airp_id`, to join a ",
         "PAT-B row to a frame.", call. = FALSE)
  }

  n <- nrow(photos_sf)
  serial <- rep(NA_character_, n)
  camera <- rep(NA_character_, n)
  gsd    <- rep(NA_real_, n)
  source <- rep(NA_character_, n)

  urls <- as.character(photos_sf$patb_georef_url)
  # One archive serves thousands of frames, so fetch each once. Passing the frames
  # straight to `fly_fetch()` would issue one row per frame and, with `workers > 1`, race
  # several writers onto one `dest` path that `download.file()` truncates before writing.
  want <- unique(urls[!is.na(urls) & nzchar(urls)])
  if (!length(want)) {
    return(fly_patb_attach(photos_sf, serial, camera, gsd, source))
  }
  # `fly_fetch()` and the cache are keyed on the basename, so two archives in different
  # directories sharing one would silently merge. Assert it rather than leave it implicit.
  if (anyDuplicated(basename(want))) {
    stop("Two `patb_georef_url` values share a basename, which the download cache ",
         "cannot distinguish: ",
         paste(basename(want)[duplicated(basename(want))], collapse = ", "),
         call. = FALSE)
  }

  dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
  fetched <- fly_fetch(
    sf::st_sf(
      airp_id = seq_along(want), patb_georef_url = want,
      geometry = sf::st_sfc(lapply(want, function(u) sf::st_point(c(0, 0))), crs = 4326)
    ),
    type = "georef", dest_dir = dest_dir, overwrite = overwrite
  )

  key_frame <- if (has_roll) {
    fly_patb_key(photos_sf$film_roll, photos_sf$frame_number)
  } else {
    rep(NA_character_, n)
  }
  id_frame <- if ("airp_id" %in% names(photos_sf)) {
    as.character(photos_sf$airp_id)
  } else {
    rep(NA_character_, n)
  }

  for (i in seq_along(want)) {
    u <- want[i]
    rows <- which(urls == u)
    j <- match(u, fetched$url)
    # `fly_fetch()` returns `dest` whether or not the download worked, and a `success`
    # column beside it. Reading only the path reports a failed fetch as "the province
    # published nothing", which is the wrong half of the world to send the operator to.
    if (!isTRUE(fetched$success[j])) {
      if (!quiet) {
        message("Could not download ", basename(u), " - ", length(rows),
                " frame(s) left unresolved.")
      }
      next
    }
    tables <- fly_patb_tables(fetched$dest[j])
    if (!length(tables)) {
      why <- attr(tables, "error")
      if (is.null(why)) why <- "holds no camera identity"
      if (!quiet) {
        message("No PAT-B table in ", basename(u), " - it ", why, ". ",
                length(rows), " frame(s) left unresolved.")
      }
      next
    }

    # ONE table over every member, not one pass per member. Written per member, a second
    # member naming the same frame silently overwrote the first and which one won was
    # decided by `unzip()`'s member order - the same "decided by position in arbitrary
    # provincial text" the tie handling in `fly_camera_format()` refuses, and it can be
    # the same 20%-wrong sensor. Pooled, the duplicate-key guard below sees it.
    tab <- do.call(rbind, lapply(tables, function(d) {
      sch <- fly_patb_schema(d)
      pull <- function(col) {
        if (is.na(col) || !col %in% names(d)) rep(NA, nrow(d)) else d[[col]]
      }
      data.frame(
        key = fly_patb_key(sub("_[^_]*$", "", d[[sch$key]]), sub(".*_", "", d[[sch$key]])),
        id  = as.character(pull(sch$airp_id)),
        serial = as.character(pull(sch$serial)),
        camera = as.character(pull(sch$camera)),
        gsd = suppressWarnings(as.numeric(pull(sch$gsd))),
        stringsAsFactors = FALSE
      )
    }))

    # `match()` semantics, never a join. A duplicated key would make a `left_join()`
    # return more rows than it was given, with every frame's attributes shifted against
    # its geometry - fly#37's failure, one function over. Duplicates that disagree about
    # the camera are reported; duplicates that agree are harmless and the first is taken.
    dup <- duplicated(tab$key)
    if (any(dup)) {
      by_key <- split(paste(tab$serial, tab$camera), tab$key)
      conflict <- names(by_key)[vapply(by_key, function(v) length(unique(v)) > 1L, logical(1))]
      # NOT gated on `quiet`, which is documented as suppressing progress. This is a
      # statement about the DATA - an archive published two cameras for one frame and an
      # arbitrary one was taken.
      if (length(conflict)) {
        warning(basename(u), " gives more than one camera for ", length(conflict),
                " frame key(s), e.g. ", conflict[1], ". The first is used.",
                call. = FALSE)
      }
      tab <- tab[!dup, , drop = FALSE]
    }

    # Both sides guarded, on BOTH keys. `match()` treats NA as a matchable value, so an
    # unusable roll/frame on the photo matches an unusable one in the archive — the same
    # collapse `fly_patb_key()` stops turning into the literal string `"NA"`, arriving one
    # step later as a genuine NA on each side.
    m <- match(key_frame[rows], tab$key)
    m[is.na(key_frame[rows])] <- NA_integer_
    if (any(!is.na(tab$id))) {
      # `match()` treats NA as a matchable VALUE - `match(NA, c("1", NA))` is 2 - and both
      # sides can be NA here: a caller may carry no `airp_id` at all (roll and frame are
      # the documented alternative), and a published archive may leave the column blank.
      # Left alone, every frame whose roll/frame key missed the archive is handed that
      # blank row's camera, with `inferred = FALSE`.
      m2 <- match(id_frame[rows], tab$id)
      m2[is.na(id_frame[rows]) | is.na(tab$id[m2])] <- NA_integer_
      m[is.na(m)] <- m2[is.na(m)]
    }
    hit <- rows[!is.na(m)]
    if (length(hit)) {
      mi <- m[!is.na(m)]
      serial[hit] <- tab$serial[mi]
      camera[hit] <- tab$camera[mi]
      gsd[hit]    <- tab$gsd[mi]
      source[hit] <- basename(u)
    }

    if (!quiet) {
      message(basename(u), ": ", length(hit), " of ", length(rows), " frames resolved")
    }
  }

  fly_patb_attach(photos_sf, serial, camera, gsd, source)
}


# Attach the four columns without going through `sf::st_sf()`.
#
# `st_sf(x, a = , b = , geometry = )` keeps ONLY its first argument when that argument is
# a tibble, so every trailing column is dropped - silently, with the geometry and every
# number still correct. `bcdata::collect()` returns a tibble, so that is the shape a real
# caller has, and it is how fly#35 shipped through two releases. `$<-` has no such
# branch and preserves the caller's class exactly.
fly_patb_attach <- function(x, serial, camera, gsd, source) {
  x$camera_serial <- serial
  x$camera_name <- camera
  x$patb_gsd <- gsd
  x$patb_source <- source
  x
}
