#!/usr/bin/env Rscript
#
# make_camera_formats.R
#
# Build inst/extdata/camera_formats.csv — the recording-format dimensions for every
# digital camera in the BC air photo catalogue, read out of the camera calibration
# reports the catalogue itself links to.
#
# Why this exists: `AIMG_PHOTO_CENTROIDS_SP` carries no sensor size, so #30 refused to
# size digital frames rather than invent one. `CAMERA_CALIBRATION_URL` is populated for
# ~80% of them and its basename identifies the calibration exactly, so the number is
# recoverable — see fly#32.
#
# The numbers are PARSED, never typed. A transcription error is invisible to any test
# that reads the CSV the error produced, so the human reviews a parse rather than a
# keyboard entry, and the QA section below constrains every field with at least two
# checks drawn from different sources.
#
# Network: BC WFS (openmaps.gov.bc.ca) for the frame attributes, and the same host for
# the calibration zips (~25 MB, cached under data-raw/.cache/).
#
# Run from fly repo root: Rscript data-raw/make_camera_formats.R

pkgload::load_all(quiet = TRUE)   # source tree, never the installed package

library(dplyr)

CACHE   <- "data-raw/.cache"
OUT     <- "inst/extdata/camera_formats.csv"
WFS     <- "https://openmaps.gov.bc.ca/geo/pub/wfs"
LAYER   <- "pub:WHSE_IMAGERY_AND_BASE_MAPS.AIMG_PHOTO_CENTROIDS_SP"
RETRIEVED <- "2026-08-30"   # the snapshot date these rows describe

fs::dir_create(fs::path(CACHE, "zip"))
fs::dir_create(fs::path(CACHE, "pdf"))
fs::dir_create("inst/extdata")


# --- WFS helpers ------------------------------------------------------------------

# One page of the layer as a CSV data frame. `count` is capped server-side at 10000,
# which is not reported as an error — reconcile against resultType=hits, never assume a
# short page means the end.
wfs_page <- function(cql, props, count = 10000, start = 0) {
  q <- c(
    service = "WFS", version = "2.0.0", request = "GetFeature",
    typeNames = LAYER, CQL_FILTER = cql, propertyName = props,
    sortBy = "AIRP_ID", count = count, startIndex = start,
    outputFormat = "csv"
  )
  url <- paste0(WFS, "?", paste0(names(q), "=",
                                 vapply(q, utils::URLencode, character(1),
                                        reserved = TRUE),
                                 collapse = "&"))
  f <- tempfile(fileext = ".csv")
  on.exit(unlink(f), add = TRUE)
  utils::download.file(url, f, mode = "wb", quiet = TRUE)
  utils::read.csv(f, stringsAsFactors = FALSE, colClasses = c(SCALE = "character"))
}

wfs_hits <- function(cql) {
  q <- c(service = "WFS", version = "2.0.0", request = "GetFeature",
         typeNames = LAYER, CQL_FILTER = cql, resultType = "hits")
  url <- paste0(WFS, "?", paste0(names(q), "=",
                                 vapply(q, utils::URLencode, character(1),
                                        reserved = TRUE),
                                 collapse = "&"))
  as.integer(sub('.*numberMatched="([0-9]+)".*', "\\1",
                 paste(readLines(url, warn = FALSE), collapse = " ")))
}

wfs_all <- function(cql, props) {
  n <- wfs_hits(cql)
  message("  ", format(n, big.mark = ","), " frames to page")
  out <- lapply(seq(0, n, by = 10000), function(s) wfs_page(cql, props, 10000, s))
  d <- dplyr::bind_rows(out)
  # Reconcile: a silently short page is the failure mode this guards.
  stopifnot(nrow(d) == n, !anyDuplicated(d$FID))
  d
}


# --- 1. Discover every digital frame and its calibration --------------------------

message("Querying the catalogue for digital frames ...")
DIGITAL <- "MEDIA LIKE 'Digital%'"
props <- paste("PHOTO_YEAR", "FOCAL_LENGTH", "GROUND_SAMPLE_DISTANCE", "SCALE",
               "FLYING_HEIGHT", "CAMERA_CALIBRATION_URL", sep = ",")
frames <- wfs_all(DIGITAL, props)

frames$calib_url <- ifelse(
  is.na(frames$CAMERA_CALIBRATION_URL) | !nzchar(frames$CAMERA_CALIBRATION_URL),
  NA_character_, frames$CAMERA_CALIBRATION_URL
)
frames$key <- ifelse(is.na(frames$calib_url), NA_character_,
                     sub("\\.zip$", "", basename(frames$calib_url)))

urls <- sort(unique(stats::na.omit(frames$calib_url)))
# The cache, and `frames$key`, are keyed on the basename rather than the full URL. Two
# calibrations in different directories sharing a basename would silently merge into
# one camera, so the assumption is asserted rather than left implicit.
stopifnot(!anyDuplicated(basename(urls)))
message("  ", nrow(frames), " digital frames, ",
        sum(!is.na(frames$key)), " with a calibration, ",
        length(urls), " distinct calibration files")


# --- 2. Fetch and unpack the calibration reports ----------------------------------

message("Fetching calibration reports (cached) ...")
for (u in urls) {
  z <- fs::path(CACHE, "zip", basename(u))
  # Guard on non-empty, not existence: `download.file` truncates its target before it
  # runs, so a failed fetch leaves a 0-byte file that an existence check blesses forever.
  if (!fs::file_exists(z) || fs::file_size(z) == 0) {
    tmp <- paste0(z, ".part")
    utils::download.file(u, tmp, mode = "wb", quiet = TRUE)
    if (fs::file_size(tmp) == 0) stop("empty download: ", u, call. = FALSE)
    fs::file_move(tmp, z)
  }
  # Same guard-on-existence trap as the zip above, one level down: `unzip()` WARNS
  # rather than errors on a bad archive, so a gate on `dir_exists()` caches an empty
  # directory forever. The key then lands in the excluded file carrying the specific
  # claim "present only as a scanned image", which is false and permanent. Extract to a
  # scratch directory and only publish it once it actually holds a PDF.
  d <- fs::path(CACHE, "pdf", sub("\\.zip$", "", basename(u)))
  if (!fs::dir_exists(d) || !length(fs::dir_ls(d, regexp = "\\.pdf$", recurse = TRUE))) {
    part <- paste0(d, ".part")
    if (fs::dir_exists(part)) fs::dir_delete(part)
    fs::dir_create(part)
    utils::unzip(z, exdir = part)
    if (!length(fs::dir_ls(part, regexp = "\\.pdf$", recurse = TRUE))) {
      fs::dir_delete(part)
      stop("no PDF extracted from ", basename(z), call. = FALSE)
    }
    if (fs::dir_exists(d)) fs::dir_delete(d)
    fs::file_move(part, d)
  }
}


# --- 3. Parsers -------------------------------------------------------------------

pdf_lines <- function(path) unlist(lapply(pdftools::pdf_text(path), function(p) strsplit(p, "\n")[[1]]))

num <- function(x) as.numeric(gsub("[^0-9.]", "", x))

# Poppler renders a zero as a capital O in some of the older Vexcel reports — the 2013
# UltraCam Eagle certificate reads `2001Opixel` where it means 20010.
#
# Note what happens without this: `num()` strips non-digits, so an unrepaired `2001O`
# becomes 2001 rather than failing. A silently-wrong pixel count is far worse than no
# row, so the substitution is made explicitly and check B — `px * pitch == the stated
# millimetres`, two numbers that did not pass through this — is what proves it right.
unglyph <- function(s) gsub("(?<=[0-9])[Oo]", "0", s, perl = TRUE)

# Vexcel UltraCam calibration report.
#
# The panchromatic and multispectral blocks are formatted identically and the
# multispectral one sits directly below, so anchoring on the heading is load-bearing —
# taking the wrong block is the one parse error the numeric QA cannot see.
parse_vexcel <- function(lines) {
  anchor <- grep("Large Format Panchromatic Output Image", lines)
  if (!length(anchor)) return(NULL)
  blk <- lines[anchor[1]:min(length(lines), anchor[1] + 25)]
  # stop before the multispectral block if it follows within the window
  stop_at <- grep("Multispectral", blk)
  if (length(stop_at)) blk <- blk[seq_len(stop_at[1] - 1)]

  lt <- unglyph(grep("long track", blk, value = TRUE)[1])
  ct <- unglyph(grep("cross track", blk, value = TRUE)[1])
  ps <- grep("Pixel Size", blk, value = TRUE)[1]
  fl <- grep("Focal Length|ck\\s*=", blk, value = TRUE)[1]
  if (any(is.na(c(lt, ct, ps)))) return(NULL)

  g <- function(s, pat) regmatches(s, regexpr(pat, s, perl = TRUE))
  list(
    height_mm = num(g(lt, "[0-9.]+\\s*mm")),
    px_along  = num(g(lt, "[0-9,]+\\s*pixel")),
    width_mm  = num(g(ct, "[0-9.]+\\s*mm")),
    px_cross  = num(g(ct, "[0-9,]+\\s*pixel")),
    # Take the first number on the Pixel Size line rather than matching a unit. These
    # reports write the micron sign three different ways and the 2013 one loses it
    # altogether — `Pixel Size  5.200 m*5.200 m`, which reads as metres. Anchoring on
    # the label and letting check B (px * pitch == the stated millimetres) and the
    # plausibility bound settle the unit is safer than trusting the glyph.
    pitch_um  = num(g(ps, "[0-9.]+")),
    focal_mm  = if (!is.na(fl)) num(g(fl, "[0-9.]+\\s*mm")) else NA_real_,
    # The report states millimetres independently of pixels and pitch, so check B is a
    # real constraint on this row rather than a restatement of its own arithmetic.
    stated_mm = TRUE
  )
}

# QSI boresight report — a specifications table, used where the Vexcel appendix is
# abridged and carries no image-format block.
parse_qsi <- function(lines) {
  txt <- paste(lines, collapse = " | ")
  if (!grepl("Array Size", txt)) return(NULL)
  gr <- function(pat) {
    m <- regmatches(txt, regexpr(pat, txt, perl = TRUE))
    if (!length(m)) NA_character_ else m
  }
  arr <- gr("Array Size\\s*\\|?\\s*\\|?\\s*([0-9,]+)\\s*x\\s*([0-9,]+)")
  ps  <- gr("CCD Pixel Size[^0-9]*([0-9.]+)")
  fl  <- gr("Focal Length[^0-9]*([0-9.]+)")
  if (is.na(arr)) return(NULL)
  dims <- as.numeric(gsub(",", "", regmatches(arr, gregexpr("[0-9,]{4,}", arr))[[1]]))
  pitch <- num(sub(".*?([0-9.]+)\\s*$", "\\1", ps))
  list(
    px_cross = max(dims), px_along = min(dims), pitch_um = pitch,
    width_mm  = max(dims) * pitch / 1000,
    height_mm = min(dims) * pitch / 1000,
    focal_mm  = num(sub("Focal Length[^0-9]*", "", fl)),
    # This report gives array size and pitch but no image size, so the millimetres are
    # DERIVED. Check B is vacuous here and the tests must not pretend otherwise.
    stated_mm = FALSE
  )
}

# Leica DMC II / DMC III calibration certificate. States pixel count, pixel size and
# image size independently, which is what makes check B a real constraint here.
#
# The micron sign in these reports is U+F06D — a Private Use Area codepoint from a
# Symbol font, not `µ` (U+00B5). So the pixel-size label reads as `Pixel Size [<PUA>m]`,
# which a literal `\[m\]` misses and a human reading the extracted text sees as `[m]`
# and takes for METRES. Match the unit permissively and record it as microns.
UNIT_MICRON <- "\\[.{0,3}m\\]"

parse_leica <- function(lines) {
  rc <- grep("Number of rows/columns \\[pixels\\]", lines, value = TRUE)[1]
  ps <- grep(paste0("Pixel Size\\s*", UNIT_MICRON), lines, value = TRUE)[1]
  im <- grep("Image Size \\[mm\\]", lines, value = TRUE)[1]
  fl <- grep("Focal Length \\[mm\\]", lines, value = TRUE)[1]
  if (any(is.na(c(rc, ps, im)))) return(NULL)
  pair <- function(s) as.numeric(regmatches(s, gregexpr("[0-9]+\\.?[0-9]*", s))[[1]])
  d <- pair(sub(".*\\[pixels\\]", "", rc))
  p <- pair(sub(paste0(".*", UNIT_MICRON), "", ps))
  i <- pair(sub(".*\\[mm\\]", "", im))
  list(
    px_cross = max(d), px_along = min(d), pitch_um = p[1],
    width_mm = max(i), height_mm = min(i),
    focal_mm = if (!is.na(fl)) pair(sub(".*\\[mm\\]", "", fl))[1] else NA_real_,
    stated_mm = TRUE
  )
}

# Intergraph DMC — reports a "virtual" image, the resampled composite the frames are
# actually delivered as. The high-resolution (panchromatic) block is the first one.
parse_dmc <- function(lines) {
  a <- grep("Virtual Focal Length", lines)
  if (!length(a)) return(NULL)
  blk <- lines[a[1]:min(length(lines), a[1] + 4)]
  fl <- grep("Virtual Focal Length", blk, value = TRUE)[1]
  sz <- grep("Virtual Sensor Size", blk, value = TRUE)[1]
  ps <- grep("Virtual Pixel Size", blk, value = TRUE)[1]
  if (any(is.na(c(fl, sz, ps)))) return(NULL)
  d <- as.numeric(regmatches(sz, gregexpr("[0-9]+", sz))[[1]])
  pitch <- num(sub(paste0(".*", UNIT_MICRON), "", ps))
  list(
    px_cross = max(d), px_along = min(d), pitch_um = pitch,
    width_mm = max(d) * pitch / 1000, height_mm = min(d) * pitch / 1000,
    focal_mm = num(sub(".*\\[m\\]", "", fl)) * 1000,
    stated_mm = FALSE   # derived, as parse_qsi
  )
}

# The serial the report gives itself, which is not always the one the catalogue's URL
# basename implies: the 2018 UltraCam report is `UC-EpII-1-22814295-f80` where the
# catalogue files it under 20814295. Recorded so that mismatch stays visible.
report_serial <- function(lines) {
  txt <- paste(lines, collapse = " ")
  m <- regmatches(txt, regexpr("UC-[A-Za-z0-9]+-[0-9]+-[0-9]+(-f[0-9]+)?", txt))
  if (length(m)) return(m[1])
  m <- regmatches(txt, regexpr("(DMC ?I{0,3}|DMC0?[0-9]+) ?-? ?[0-9]{4,8}", txt))
  if (length(m)) m[1] else NA_character_
}

camera_name <- function(lines) {
  txt <- paste(lines, collapse = " ")
  pats <- c("UltraCam Eagle Prime II", "UltraCam Eagle-M3", "UltraCam Eagle M3",
            "UltraCam Falcon M2", "UltraCamXp", "UltraCam Xp", "UltraCam Eagle",
            "UltraCamEagle", "UltraCam X", "DMC III", "DMC II", "DMC")
  for (p in pats) if (grepl(p, txt, fixed = TRUE)) return(p)
  NA_character_
}

# --- 4. Parse every report ---------------------------------------------------------

NUMERIC_FIELDS <- c("width_mm", "height_mm", "px_cross", "px_along", "pitch_um", "focal_mm")

parse_one <- function(k) {
  dir <- fs::path(CACHE, "pdf", k)
  pdfs <- fs::dir_ls(dir, regexp = "\\.pdf$", recurse = TRUE, type = "file")
  # A boresight report restates specs loosely; prefer a real calibration certificate,
  # but fall back to one rather than losing the row.
  pdfs <- c(pdfs[!grepl("oresight", pdfs)], pdfs[grepl("oresight", pdfs)])
  for (p in pdfs) {
    lines <- tryCatch(pdf_lines(p), error = function(e) character(0))
    if (!length(lines)) next          # image-only PDF: 0 extractable characters
    for (fn in list(parse_vexcel, parse_leica, parse_dmc, parse_qsi)) {
      r <- tryCatch(fn(lines), error = function(e) NULL)
      if (is.null(r)) next
      if (!all(vapply(r[NUMERIC_FIELDS], function(x) length(x) == 1 && is.finite(x),
                      logical(1)))) next
      return(data.frame(
        key = k, camera = camera_name(lines), report_serial = report_serial(lines),
        source_pdf = fs::path_file(p), width_mm = r$width_mm, height_mm = r$height_mm,
        px_cross = r$px_cross, px_along = r$px_along, pitch_um = r$pitch_um,
        focal_mm = r$focal_mm, stated_mm = r$stated_mm, stringsAsFactors = FALSE
      ))
    }
  }
  NULL
}

message("Parsing reports ...")
keys <- sort(unique(stats::na.omit(frames$key)))
parsed <- dplyr::bind_rows(lapply(keys, parse_one))
unparsed <- setdiff(keys, parsed$key)
message("  parsed ", nrow(parsed), " of ", length(keys), " calibration files")


# --- 5. QA ------------------------------------------------------------------------
#
# These gate the write. A row that cannot be corroborated is withheld rather than
# shipped: a footprint we know fails its own consistency check is exactly the mystery
# error this section exists to prevent.

fail <- character(0)
note <- function(...) message("  ", ...)

## B — px * pitch reproduces the image size the report states, both axes.
## Only meaningful where the report states millimetres independently; where the parser
## derived them the check is vacuous and is skipped rather than counted as a pass.
b <- parsed[parsed$stated_mm, ]
b_cross <- abs(b$px_cross * b$pitch_um / 1000 - b$width_mm) / b$width_mm
b_along <- abs(b$px_along * b$pitch_um / 1000 - b$height_mm) / b$height_mm
note("B  px*pitch == stated mm: ", nrow(b), " of ", nrow(parsed), " rows constrainable, ",
     "max rel. err ", format(max(c(b_cross, b_along)), digits = 3))
if (any(c(b_cross, b_along) > 1e-6)) {
  fail <- c(fail, paste("B failed:", paste(b$key[b_cross > 1e-6 | b_along > 1e-6],
                                           collapse = ", ")))
}

## C — the report's focal length against the catalogue's, which is an independent field.
cat_focal <- tapply(frames$FOCAL_LENGTH, frames$key, function(x) median(x, na.rm = TRUE))
parsed$focal_catalogue <- as.numeric(cat_focal[parsed$key])
# `focal_catalogue` is NA when a key's frames all carry a missing FOCAL_LENGTH, and
# `any(NA)` is NA rather than FALSE — which errors in an `if`. Absence of a catalogue
# focal is not a disagreement, so it resolves to FALSE.
parsed$focal_disagrees <- !is.na(parsed$focal_catalogue) &
  abs(parsed$focal_mm - parsed$focal_catalogue) > 1
note("C  report focal vs catalogue: ", sum(!parsed$focal_disagrees), " of ", nrow(parsed),
     " agree within 1 mm",
     if (any(parsed$focal_disagrees))
       paste0(" (disagree: ", paste(parsed$key[parsed$focal_disagrees], collapse = ", "), ")")
     else "")

## D — plausibility bounds. Catches a unit slip (m / mm / um), which is the error class
## that survives B by being internally self-consistent.
parsed$aspect <- parsed$width_mm / parsed$height_mm
## The width bound is 30-200 mm, not the 80-170 mm the large-format cameras occupy.
## A tighter bound would reject a medium-format sensor as implausible — the two the
## catalogue actually holds are ~53 mm wide — and a guard that refuses valid data is
## worse than the unit slip it is trying to catch. 30-200 mm still separates a
## micrometre read as a millimetre (~5 mm) or a metre read as one (~0.0001 mm), which
## is what D exists for.
## `focal_mm` is bounded here too. It was previously the only shipped number with no
## gating check at all: D did not cover it, C reports a disagreement without failing the
## build (there is a known legitimate one), and F is skipped for any key whose frames
## carry no GSD. A focal that fell out of a missed unit anchor would have shipped.
bad_d <- with(parsed, width_mm < 30 | width_mm > 200 | aspect < 1 | aspect > 2 |
                pitch_um < 3 | pitch_um > 13 | focal_mm < 40 | focal_mm > 300)
note("D  plausibility bounds: ", sum(!bad_d), " of ", nrow(parsed), " within range")
if (any(bad_d)) fail <- c(fail, paste("D failed:", paste(parsed$key[bad_d], collapse = ", ")))

## F — implied ground elevation. Invert for the ground the aircraft was over:
## terrain = flying_height - (GSD / pitch) * focal. Nothing here comes from the table
## except pitch and focal; FLYING_HEIGHT and GROUND_SAMPLE_DISTANCE are the catalogue's
## own. The result must be a plausible BC elevation.
##
## GROUND_SAMPLE_DISTANCE is in CENTIMETRES — see gsd_m() in R/fly_footprint.R. Getting
## that wrong is a factor of 100, so it is asserted rather than assumed.
f <- merge(frames[!is.na(frames$key), ], parsed[, c("key", "pitch_um", "focal_mm")], by = "key")
f <- f[!is.na(f$GROUND_SAMPLE_DISTANCE) & f$GROUND_SAMPLE_DISTANCE > 0 &
         !is.na(f$FLYING_HEIGHT), ]
f$terrain <- f$FLYING_HEIGHT - (f$GROUND_SAMPLE_DISTANCE / 100) / (f$pitch_um * 1e-6) *
  (f$focal_mm / 1000)
terr <- tapply(f$terrain, f$key, median)
parsed$terrain_implied <- round(as.numeric(terr[parsed$key]))
parsed$terrain_ok <- is.na(parsed$terrain_implied) |
  (parsed$terrain_implied > -50 & parsed$terrain_implied < 2800)
note("F  implied ground elevation plausible: ", sum(parsed$terrain_ok), " of ", nrow(parsed),
     if (any(!parsed$terrain_ok))
       paste0(" (implausible: ", paste(parsed$key[!parsed$terrain_ok], collapse = ", "), ")")
     else "")

if (length(fail)) stop("QA failed, CSV not written:\n  ", paste(fail, collapse = "\n  "),
                       call. = FALSE)

## Withhold anything F rejects. A frame with no footprint is honest; a frame with a
## footprint contradicted by its own metadata is not.
parsed$ship <- parsed$terrain_ok


# --- 6. Focal-length fallback rows -------------------------------------------------
#
# ~20% of digital frames carry no calibration URL. Focal length is the only other
# discriminator, and it is a weak one — so the rows are DERIVED by rule here rather than
# chosen by hand, and each records how many calibrated cameras stand behind it and how
# far apart they are. Consumers mark frames sized this way as inferred.

shipped <- parsed[parsed$ship, ]
by_key <- as.data.frame(table(frames$key), stringsAsFactors = FALSE)
names(by_key) <- c("key", "frames")
shipped <- merge(shipped, by_key, by = "key", all.x = TRUE)

# Which catalogue focal lengths need a fallback: those on frames with no calibration.
# Extrapolation is OPT-IN, per catalogue focal length, with a reason.
#
# The first version of this was a refusal list, which encoded the one instance that had
# been measured rather than the property it stood for — so a focal length nobody had
# looked at yet got a row by default. Worse, the obvious generalisation does not work:
# extrapolation *distance* does not predict the error. The refused focal-83 row reached
# across a 3.6% focal gap and was 93% wrong, while focal 120 reaches across a larger
# 5.5% gap and is right. Only camera identity separates them, and the generator cannot
# see that.
#
# So the safe default is no row, and each exception is named here with the argument for
# it. A focal length absent from this list and absent from the calibrated set simply
# gets no fallback, and is recorded in the excluded file.
FALLBACK_EXTRAPOLATE <- c(
  "120" = paste("no calibrated camera at focal 120; the 11,984 frames are 2011 and the",
                "only large-format 120 mm body in the record is the Z/I DMC, whose own",
                "report gives a virtual focal of exactly 120 mm - so its 165.888 mm",
                "format is used. Marked extrapolated: this rests on camera identity,",
                "not on the catalogue focal being close to 127")
)

need <- sort(unique(frames$FOCAL_LENGTH[is.na(frames$key) & !is.na(frames$FOCAL_LENGTH)]))

shipped <- parsed[parsed$ship, ]
by_key <- as.data.frame(table(frames$key), stringsAsFactors = FALSE)
names(by_key) <- c("key", "frames")
shipped <- merge(shipped, by_key, by = "key", all.x = TRUE)

# Ground truth: what widths do calibrated frames at each catalogue focal actually have?
gt <- merge(frames[!is.na(frames$key), c("key", "FOCAL_LENGTH")],
            shipped[, c("key", "width_mm", "height_mm")], by = "key")

has_exact <- vapply(need, function(fl) any(gt$FOCAL_LENGTH == fl), logical(1))
allowed <- as.character(need) %in% names(FALLBACK_EXTRAPOLATE)
build <- need[has_exact | allowed]
no_fallback <- need[!has_exact & !allowed]

# A declared exception that never fires is a stale decision nobody is told about.
unused <- setdiff(names(FALLBACK_EXTRAPOLATE), as.character(need[!has_exact]))
if (length(unused)) {
  stop("FALLBACK_EXTRAPOLATE declares focal ", paste(unused, collapse = ", "),
       " but nothing needs extrapolating there any more.", call. = FALSE)
}

fallback <- dplyr::bind_rows(lapply(build, function(fl) {
  at <- gt[gt$FOCAL_LENGTH == fl, ]
  exact <- nrow(at) > 0
  if (!exact) {
    near <- gt$FOCAL_LENGTH[which.min(abs(gt$FOCAL_LENGTH - fl))]
    at <- gt[gt$FOCAL_LENGTH == near, ]
  }
  if (!nrow(at)) return(NULL)
  # Modal width by frame count. Selected by INDEX, not by reparsing the name back out
  # of `table()`: `as.numeric(as.character(100.3392))` does not round-trip exactly, and
  # comparing the reparsed value with `==` would silently match nothing and leave the
  # paired height NA.
  tw <- table(at$width_mm)
  w <- at$width_mm[at$width_mm %in% as.numeric(names(tw)[which.max(tw)])][1]
  if (is.na(w)) w <- at$width_mm[which.max(tabulate(match(at$width_mm, at$width_mm)))]
  h <- at$height_mm[match(w, at$width_mm)]
  data.frame(
    key = as.character(fl), key_type = "focal_length",
    camera = if (exact) "inferred from focal length" else "extrapolated from nearest focal",
    report_serial = NA_character_, source_pdf = NA_character_,
    width_mm = w, height_mm = h,
    # Pixel counts are NOT carried: at a given focal they spread 32-83% where width
    # spreads 1-3%, so a fallback frame can be sized by width x AGL/focal but never by
    # px x GSD. Leaving them NA is what stops that route being taken.
    px_cross = NA_real_, px_along = NA_real_,
    pitch_um = NA_real_, focal_mm = fl, mm_stated = NA,
    n_cameras = length(unique(at$width_mm)),
    # Spread is dispersion among the SOURCE cameras, so a single-source row is
    # structurally 0 however wrong the inference. Reporting 0 on an extrapolated row
    # would give the least-supported rows in the file the most confident label, so an
    # extrapolated row reports NA instead — unknown, which is the truth.
    width_spread_pct = if (exact) round(100 * (max(at$width_mm) / min(at$width_mm) - 1), 1) else NA_real_,
    extrapolated = !exact,
    note = if (exact) "modal width among calibrated cameras at this catalogue focal"
           else FALLBACK_EXTRAPOLATE[[as.character(fl)]],
    stringsAsFactors = FALSE
  )
}))


# --- 7. Write ----------------------------------------------------------------------

calib_rows <- data.frame(
  key = shipped$key, key_type = "calib_file", camera = shipped$camera,
  report_serial = shipped$report_serial, source_pdf = shipped$source_pdf,
  width_mm = shipped$width_mm, height_mm = shipped$height_mm,
  px_cross = shipped$px_cross, px_along = shipped$px_along,
  pitch_um = shipped$pitch_um, focal_mm = shipped$focal_mm,
  # Whether the report stated the millimetres itself. Where it did not, `width_mm` is
  # px * pitch and check B on that row compares the arithmetic with itself — the tests
  # must skip it rather than count a vacuous pass.
  mm_stated = shipped$stated_mm,
  n_cameras = 1L, width_spread_pct = 0, extrapolated = FALSE,
  note = ifelse(shipped$focal_disagrees,
                paste0("catalogue records focal ", shipped$focal_catalogue,
                       "; the report says ", shipped$focal_mm, " - report preferred"),
                NA_character_),
  stringsAsFactors = FALSE
)

out <- rbind(calib_rows, fallback)
out$retrieved <- RETRIEVED
out <- out[order(out$key_type, out$key), ]
utils::write.csv(out, OUT, row.names = FALSE, na = "")

# Every discovered key must land in exactly one of the two files, each with a reason.
# A guard that lets an entry sit in neither is how drift becomes invisible.
# Each block is guarded on a non-empty key vector. `paste0()` returns length 1 for a
# zero-length argument, so an unguarded `data.frame(key = character(0), reason = ...)`
# aborts with "arguments imply differing number of rows: 0, 1" — and the second block
# fires in the HEALTHY case, the moment check F rejects nothing. That would kill the run
# after every download and all the QA, with camera_formats.csv already on disk and the
# excluded file and manifest not: exactly the inconsistent state the manifest guard
# exists to detect.
# `excl()` is what makes each block safe on an empty key vector. `paste0()` returns
# length 1 for a zero-length argument, so `data.frame(key = character(0), reason = ...)`
# aborts at CONSTRUCTION with "arguments imply differing number of rows: 0, 1" —
# subsetting afterwards is too late. The withheld block fires in the HEALTHY case, the
# moment check F rejects nothing, which would kill the run after every download and all
# the QA with camera_formats.csv already on disk and the excluded file and manifest not:
# exactly the inconsistent state the manifest guard exists to detect.
excl <- function(key, key_type, reason) {
  if (!length(key)) {
    return(data.frame(key = character(0), key_type = character(0),
                      reason = character(0), stringsAsFactors = FALSE))
  }
  data.frame(key = key, key_type = key_type, reason = reason, stringsAsFactors = FALSE)
}

excluded <- rbind(
  # These carry their calibration only as a scanned image, so no text pass can reach it.
  # An independent visual reading (fly#32, check E) recovered the specs and they are
  # recorded here so the knowledge is not lost — but they are NOT shipped, because a row
  # this generator cannot reproduce would break the guarantee that re-running it
  # reproduces the table. Two of the three are medium-format bodies roughly half the
  # width of everything else in the record, which is also why no fallback may reach for
  # their focal lengths.
  excl(unparsed, "calib_file", paste0(
    "calibration present only as a scanned image, not machine-readable",
    ifelse(unparsed == "10210206_2015",
           "; visually read as UltraCam Eagle 20010x13080 @ 5.2um = 104.052x68.016mm f100.5", ""),
    ifelse(unparsed == "11937933_2009",
           "; visually read as AIC Pro (P65+) 8984x6732 @ 6.0um = 53.904x40.392mm f60.68", ""),
    ifelse(unparsed == "12335326_2017",
           "; visually read as PhaseOne IXU-RS-1000 11608x8708 @ 4.6um = 53.4x40.1mm f51.56", "")
  )),
  excl(parsed$key[!parsed$ship], "calib_file",
       paste0("catalogue GSD/FLYING_HEIGHT contradict the report: implied ground ",
              "elevation ", parsed$terrain_implied[!parsed$ship], " m")),
  # Focal lengths deliberately left without a fallback row, in the same file so every
  # refusal carries its reason rather than living only in a code comment.
  excl(as.character(no_fallback), "focal_length",
       paste0("no fallback row: no calibrated camera at focal ", no_fallback,
              ", and extrapolating from a different focal is not warranted without ",
              "knowing the camera - focal distance does not predict the error"))
)
excluded$frames <- as.integer(by_key$frames[match(excluded$key, by_key$key)])
excluded$retrieved <- RETRIEVED
utils::write.csv(excluded[order(excluded$key), ],
                 "inst/extdata/camera_formats_excluded.csv", row.names = FALSE, na = "")

# The keys the catalogue actually offered at RETRIEVED, written independently of the
# two dispositions above. Committing it lets the test suite re-check offline that every
# discovered key is still dispositioned — including after a hand-edit to either file,
# which is the drift a self-referential check cannot see.
utils::write.csv(data.frame(key = keys, retrieved = RETRIEVED),
                 "inst/extdata/camera_formats_manifest.csv", row.names = FALSE)

stopifnot(setequal(
  keys,
  c(out$key[out$key_type == "calib_file"],
    excluded$key[excluded$key_type == "calib_file"])
))
stopifnot(setequal(as.character(need),
                   c(out$key[out$key_type == "focal_length"], as.character(no_fallback))))

message("\nWrote ", OUT, ": ", sum(out$key_type == "calib_file"), " calibration rows + ",
        sum(out$key_type == "focal_length"), " fallback rows")
message("Wrote inst/extdata/camera_formats_excluded.csv: ", nrow(excluded), " keys (",
        format(sum(excluded$frames, na.rm = TRUE), big.mark = ","), " frames)")
message("Coverage: ",
        format(sum(shipped$frames, na.rm = TRUE), big.mark = ","), " of ",
        format(nrow(frames), big.mark = ","), " digital frames resolvable by calibration")
