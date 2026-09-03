# georef_calibrate-corner_mapping.R — establish the pixel-to-ground corner mapping
# for a footprint already rotated onto its flight line (fly#38).
#
# Everything here is public: BC Data Catalogue metadata, the airphoto thumbnails at
# openmaps.gov.bc.ca, the exterior-orientation files the catalogue links through
# `patb_georef_url`, and FWA lakes. No licence-restricted imagery is used or needed.
#
# Three independent measurements, run in this order. Read `inst/notes/georeferencing.md`
# before changing any of them — the second and third are the ones that decide, and the
# first is the one that looks most authoritative while being the weakest.
#
# Usage: source interactively. Writes nothing to the package.

library(sf)
library(terra)
devtools::load_all()

sf::sf_use_s2(FALSE)
work <- file.path(tempdir(), "fly38")
dir.create(work, recursive = TRUE, showWarnings = FALSE)

photos <- st_read(system.file("testdata/photo_centroids_digital.gpkg", package = "fly"),
                  quiet = TRUE)
fp <- st_transform(suppressWarnings(fly_footprint(photos)), 3005)

deg  <- function(r) r * 180 / pi
az   <- function(e, n) deg(atan2(e, n)) %% 360          # clockwise from north
wrap <- function(x) ((x + 180) %% 360) - 180

# ---------------------------------------------------------------------------
# 1. Exterior orientation, from the PATB files the catalogue publishes per project
# ---------------------------------------------------------------------------
# Answers: does the camera's image x-axis track the flight line, and at what offset?
#
# The control that matters is `sum` versus `difference`. A rigid mount gives a constant
# `image_x_azimuth - heading`; a ground frame read with its axes swapped gives a constant
# `image_x_azimuth + heading` instead. The two are indistinguishable unless the project
# flies more than one heading — which is why the offset is only established on projects
# whose legs span the compass, and why the bundled DMC II project on its own cannot
# settle anything.

heading_per_frame <- function(roll, frame, east, north) {
  out <- rep(NA_real_, length(roll))
  for (r in unique(roll)) {
    i <- which(roll == r)
    i <- i[order(frame[i])]
    if (length(i) < 2) next
    de <- diff(east[i])
    dn <- diff(north[i])
    step <- sqrt(de^2 + dn^2)
    a <- az(de, dn)
    a[step < 100 | step > 5000] <- NA          # turns and roll breaks
    out[i] <- c(a, a[length(a)])
  }
  out
}

report_offset <- function(label, image_x_az, heading) {
  ok <- is.finite(image_x_az) & is.finite(heading)
  d <- wrap(image_x_az[ok] - heading[ok])
  s <- (image_x_az[ok] + heading[ok]) %% 360
  tight <- function(v) 100 * mean(abs(wrap(v - median(v))) <= 5)
  message(sprintf("%s  n=%d  compass bins=%d", label, sum(ok),
                  length(unique(round(heading[ok] / 30) * 30 %% 360))))
  message(sprintf("  rigid     median %8.2f  within +/-5: %5.1f%%", median(d), tight(d)))
  message(sprintf("  reflected median %8.2f  within +/-5: %5.1f%%", median(s), tight(s)))
}

read_patb <- function(url) {
  dest <- file.path(work, basename(url))
  if (!file.exists(dest)) utils::download.file(url, dest, quiet = TRUE)
  if (grepl("\\.zip$", url)) {
    utils::unzip(dest, exdir = file.path(work, tools::file_path_sans_ext(basename(url))))
    f <- list.files(file.path(work, tools::file_path_sans_ext(basename(url))),
                    pattern = "georef\\.(csv|txt)$", full.names = TRUE)
    utils::read.csv(f[1])
  } else {
    utils::read.csv(dest)
  }
}

# UltraCam Eagle M3. `eop_x` holds the NORTHING and `eop_y` the easting despite the
# names, and kappa is nevertheless referenced to a standard (easting, northing) frame —
# which is why the column names cannot be trusted as a statement of convention and the
# sum/difference control has to do the work.
eagle <- read_patb("https://openmaps.gov.bc.ca/thumbs/patb_files/d_005_emn_19_georef.zip")
rf <- strsplit(eagle$roll_frame, "_", fixed = TRUE)
eagle$roll  <- vapply(rf, `[`, "", 1)
eagle$frame <- as.integer(vapply(rf, `[`, "", 2))
eagle$head  <- heading_per_frame(eagle$roll, eagle$frame, eagle$eop_y, eagle$eop_x)
report_offset("UltraCam Eagle M3", (90 - eagle$kappa) %% 360, eagle$head)

# Leica DMC II. `gr_omega/gr_phi/gr_kappa` are zero in every row; the rotation is
# delivered as a 3x3 matrix, and `c2` is corrupt (`"00000000000"`) throughout. Only the
# first column is needed. The bundled frames' own project flies east-west only, so four
# further DMC II projects are pooled to get compass coverage.
dmc_urls <- c(
  "https://openmaps.gov.bc.ca/thumbs/patb_files/d_003_fi_13_georef.zip",   # the bundled one
  "https://openmaps.gov.bc.ca/thumbs/patb_files/d_003_fi_14_georef.zip",
  "https://openmaps.gov.bc.ca/thumbs/patb_files/d_003_fi_15_georef.zip",
  "https://openmaps.gov.bc.ca/thumbs/patb_files/d_003_fi_16_georef.zip"
)
for (u in dmc_urls) {
  d <- read_patb(u)
  rf <- strsplit(d$frm_roll_frame, "_", fixed = TRUE)
  d$roll  <- vapply(rf, `[`, "", 1)
  d$frame <- as.integer(vapply(rf, `[`, "", 2))
  d$head  <- heading_per_frame(d$roll, d$frame, d$gr_easting, d$gr_northing)
  x <- az(suppressWarnings(as.numeric(d$a1)), suppressWarnings(as.numeric(d$b1)))
  report_offset(paste("Leica DMC II —", basename(u)), x, d$head)
}

# ---------------------------------------------------------------------------
# 2. Adjacent-frame overlap — the measurement that decides
# ---------------------------------------------------------------------------
# Consecutive frames on a line overlap heavily, so at the correct rotation their common
# ground must agree. A 180-degree error reflects each frame about its OWN centre, and
# because the centres differ the overlap then shows different ground. Needs no reference
# imagery of any kind: the frames check each other.

# `pts` / `polys` are passed rather than closed over, so the film section below reuses
# this rather than carrying a second copy that could drift from it.
georef_at <- function(idx, tag, rot, pts = photos, polys = fp) {
  th <- fly_fetch(pts[idx, ], type = "thumbnail",
                  dest_dir = file.path(work, tag, "thumb"))
  stopifnot(all(th$success))
  d <- file.path(work, tag, paste0("r", rot))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  vapply(seq_along(idx), function(k) {
    o <- file.path(d, paste0(k, ".tif"))
    ok <- georef_one(th$dest[k], polys[idx[k], ], o, srcnodata = "0", rotation = rot)
    if (isTRUE(ok)) o else NA_character_
  }, character(1))
}

grey <- function(path) {
  r <- rast(path)
  g <- if (nlyr(r) >= 3) mean(r[[1:3]]) else r[[1]]
  g[g <= 0] <- NA
  g
}

pair_r <- function(a, b, res = 25) {
  ga <- grey(a)
  gb <- grey(b)
  inter <- terra::intersect(ext(ga), ext(gb))
  if (is.null(inter)) return(NA_real_)
  tmpl <- rast(inter, resolution = res, crs = crs(ga))
  va <- values(resample(ga, tmpl, method = "average"))[, 1]
  vb <- values(resample(gb, tmpl, method = "average"))[, 1]
  ok <- is.finite(va) & is.finite(vb)
  if (sum(ok) < 500) return(NA_real_)
  suppressWarnings(stats::cor(va[ok], vb[ok]))
}

for (case in list(list(i = 19:24, tag = "eagle", cam = "UltraCam Eagle M3"),
                  list(i =  1:6,  tag = "dmc",   cam = "Leica DMC II"))) {
  message("\n", case$cam, " — adjacent-frame overlap correlation")
  for (rot in c(0, 90, 180, 270)) {
    o <- georef_at(case$i, case$tag, rot)
    rs <- vapply(seq_len(length(o) - 1), function(k) pair_r(o[k], o[k + 1]), numeric(1))
    message(sprintf("  rotation %3d : mean r = %+.3f   [%s]",
                    rot, mean(rs, na.rm = TRUE), paste(sprintf("%+.2f", rs), collapse = " ")))
  }
}

# ---------------------------------------------------------------------------
# 3. Water darkness against FWA lakes — an outside opinion
# ---------------------------------------------------------------------------
# Independent of both measurements above: lakes are dark, and FWA knows exactly where
# they are. Only discriminating when the water sits off-centre, since a 180-degree error
# rotates about the footprint centre — so the offset is reported beside the result rather
# than assumed.

bb <- st_bbox(st_union(st_geometry(fp)))
lakes_query <- bcdata::bcdc_query_geodata("WHSE_BASEMAPPING.FWA_LAKES_POLY")
lakes <- st_transform(
  bcdata::collect(bcdata::filter(lakes_query, BBOX(!!as.numeric(bb), crs = "EPSG:3005"))),
  3005
)
water <- st_union(lakes)

for (i in c(1, 2)) {
  g <- st_geometry(fp)[i]
  w <- st_intersection(water, g)
  if (length(w) == 0) next
  off <- as.numeric(st_distance(st_centroid(st_union(w)), st_centroid(g)))
  message(sprintf("\nframe %d (%s_%s) — water %.0f m off the footprint centre",
                  i, photos$film_roll[i], photos$frame_number[i], off))
  th <- fly_fetch(photos[i, ], type = "thumbnail", dest_dir = file.path(work, "water"))
  for (rot in c(0, 90, 180, 270)) {
    o <- file.path(work, "water", sprintf("w%d_%d.tif", rot, i))
    if (!isTRUE(georef_one(th$dest[1], fp[i, ], o, srcnodata = "0", rotation = rot))) next
    lum <- grey(o)
    inw <- terra::extract(lum, vect(st_as_sf(st_sfc(w, crs = 3005))), ID = FALSE)[[1]]
    all <- values(lum)[, 1]
    message(sprintf("  rotation %3d : water %6.1f   frame %6.1f   difference %+7.1f",
                    rot, mean(inw, na.rm = TRUE), mean(all, na.rm = TRUE),
                    mean(inw, na.rm = TRUE) - mean(all, na.rm = TRUE)))
  }
}


# ---------------------------------------------------------------------------
# 4. Film — the same measurement, and it does NOT yield a constant (fly#26)
# ---------------------------------------------------------------------------
# Until fly#26 film was drawn axis-aligned, so `fly_georef()` could only shuffle corners
# by a 90-degree-quantized bearing and a diagonal flight line had no correct answer.
# Film is now rotated onto its bearing like everything else, which needs its own corner
# mapping. The digital constant cannot be assumed to carry over: it was measured on
# digital sensors, and a scanned negative is a different system.
#
# WHY THIS CANNOT BE SETTLED FROM THE GEOMETRY, and it is worse than the digital case.
# The aspect invariant rejects a mapping that pairs the image's long axis with the
# footprint's short edge. A square footprint has no long axis, so the invariant is
# vacuous against ALL FOUR rotations rather than merely unable to separate two of them.
# Nothing in the test suite can catch a wrong film mapping. Only this can.
#
# On a square the answer is also not free-standing: with `hc == ha` nothing
# distinguishes the along-track axis from the cross-track one, so rotating by `b` and
# mapping with shift `r` is indistinguishable from rotating by `b ± 90` and mapping with
# `r ∓ 90`. What is measured is a COMPOSITE of the mapping and `fly_rectangles()`'s
# vertex order and rotation sign. `test-fly_camera_format.R` pins that convention as
# "ring vertex 1 sits at bearing + 225 from the centroid". If that assertion is ever
# changed, everything below is void and must be re-run.
#
# The quantity to read off is the TOP-EDGE AZIMUTH, `bearing + rotation`, derived from
# `fly_georef_gcps()` rather than reasoned about. It is where the top of the image
# points on the ground.
#
# RESULT, and it is a negative one. Four legs, two rolls, two eras:
#
#   roll      year  bearing   best rot   margin   top-edge azimuth
#   bc5282    1968    230        0        0.089        230
#   bc83062   1983    150       90        0.135        240
#   bc83062   1983     93       90        0.196        183
#   bc83062   1983     62       90        0.152        152
#
# Two things follow, and they point opposite ways:
#
# 1. The mapping IS flight-relative. bc83062 returns 90 at three widely separated
#    bearings, which a geographic convention could not do. This is what justifies
#    rotating the footprint onto the bearing at all.
# 2. It is NOT a constant. bc5282 returns 0 where bc83062 returns 90 — a whole quarter
#    turn apart, on the two eras the issue itself named. There is no `fly_film_rotation()`
#    to be written, and pooling these into one number would be averaging a real
#    difference into a wrong answer for both rolls.
#
# A fixed-geographic alternative was tested and FALSIFIED rather than left as a loose
# end: the first two rows above agree to within 10 degrees of azimuth (230, 240), which
# looked like a scanner delivering a constant orientation. It predicts 180 for the
# 93- and 62-degree legs. Both measured 90.
#
# So `fly_georef()` refuses a rotated square footprint unless the caller supplies the
# roll's rotation, rather than georeferencing it against a guess. See fly#26.
#
# POSITIVE CONTROL. Run this first and confirm it before believing anything above — a
# harness that cannot reproduce a known answer is not evidence. Digital, where #38
# measured 270: this returns 270 at +0.713 against 90 at +0.425. Rotations 0 and 180 do
# not appear because the stretch guard REFUSES them on a non-square footprint, which is
# a refusal rather than a low score and must not compete for `which.max()`.
#
# Detrending was tried (subtract a 9-cell local mean before correlating) and is NOT used:
# it collapses the digital control to +0.091 against +0.005. `fly`'s footprints are
# estimates, so fine detail does not align between frames and a high-pass filter removes
# the broad tone that carries the whole signal. #38 correlated raw at 25 m for the same
# reason.

message("\n\n=== 4. FILM ===")

film_leg <- function(roll, frames) {
  r <- bcdata::collect(bcdata::filter(
    bcdata::bcdc_query_geodata("WHSE_IMAGERY_AND_BASE_MAPS.AIMG_PHOTO_CENTROIDS_SP"),
    FILM_ROLL == roll
  ))
  names(r) <- tolower(names(r))
  r <- r[order(r$frame_number), ]
  r[r$frame_number %in% frames, ]
}

# The bundled fixture is a SAMPLE of two rolls, and after fly#26's adjacency guard only
# one true frame-to-frame diagonal pair survives in it (bc5282 231->232). One pair is not
# a measurement, so contiguous legs are pulled from the catalogue. All of it is public.
film_cases <- list(
  list(label = "bc5282  1968 b=230", roll = "bc5282",  frames = 226:236),
  list(label = "bc83062 1983 b=150", roll = "bc83062", frames =  63:73),
  list(label = "bc83062 1983 b=93",  roll = "bc83062", frames = 108:118),
  list(label = "bc83062 1983 b=62",  roll = "bc83062", frames = 152:162)
)

for (case in film_cases) {
  pts <- film_leg(case$roll, case$frames)
  fpf <- st_transform(suppressWarnings(fly_footprint(pts)), 3005)
  b <- fpf$footprint_bearing
  # Premises. A leg with a bearingless frame is measuring something else, and a cardinal
  # leg cannot discriminate at all — every rotation is a quarter turn of the same square,
  # so it would report a winner drawn from noise.
  if (!all(is.finite(b))) { message(case$label, ": not every frame rotated, skipped"); next }
  if (median(abs(((b + 45) %% 90) - 45)) < 15) { message(case$label, ": cardinal, skipped"); next }

  tag <- gsub("[^a-z0-9]", "", tolower(case$label))
  sc <- vapply(c(0, 90, 180, 270), function(rot) {
    o <- suppressWarnings(georef_at(seq_len(nrow(pts)), tag, rot, pts = pts, polys = fpf))
    if (any(is.na(o))) return(NaN)          # refused by the stretch guard, not a score
    mean(vapply(seq_len(length(o) - 1), function(k) pair_r(o[k], o[k + 1]), numeric(1)),
         na.rm = TRUE)
  }, numeric(1))

  ok <- is.finite(sc)
  w <- which.max(replace(sc, !ok, -Inf))
  rest <- sc[-w][is.finite(sc[-w])]
  message(sprintf("%-20s b=%5.1f  0:%s 90:%s 180:%s 270:%s  best %3d  margin %s  top-az %5.1f",
                  case$label, median(b),
                  ifelse(ok[1], sprintf("%+.3f", sc[1]), "  skip"),
                  ifelse(ok[2], sprintf("%+.3f", sc[2]), "  skip"),
                  ifelse(ok[3], sprintf("%+.3f", sc[3]), "  skip"),
                  ifelse(ok[4], sprintf("%+.3f", sc[4]), "  skip"),
                  c(0, 90, 180, 270)[w],
                  if (length(rest)) sprintf("%.3f", sc[w] - max(rest)) else "n/a",
                  (median(b) + c(0, 90, 180, 270)[w]) %% 360))
}
