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
    de <- diff(east[i]); dn <- diff(north[i])
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
  message(sprintf(
    "%s  n=%d  compass bins=%d\n  rigid     median %8.2f  within +/-5: %5.1f%%\n  reflected median %8.2f  within +/-5: %5.1f%%",
    label, sum(ok), length(unique(round(heading[ok] / 30) * 30 %% 360)),
    median(d), tight(d), median(s), tight(s)))
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

georef_at <- function(idx, tag, rot) {
  th <- fly_fetch(photos[idx, ], type = "thumbnail",
                  dest_dir = file.path(work, tag, "thumb"))
  stopifnot(all(th$success))
  d <- file.path(work, tag, paste0("r", rot))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  vapply(seq_along(idx), function(k) {
    o <- file.path(d, paste0(k, ".tif"))
    ok <- georef_one(th$dest[k], fp[idx[k], ], o, srcnodata = "0", rotation = rot)
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
  ga <- grey(a); gb <- grey(b)
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
lakes <- st_transform(
  bcdata::collect(bcdata::filter(
    bcdata::bcdc_query_geodata("WHSE_BASEMAPPING.FWA_LAKES_POLY"),
    BBOX(!!as.numeric(bb), crs = "EPSG:3005"))), 3005)
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
