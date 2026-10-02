# format_measure-infrared_film.R — is infrared film the 9-inch negative? (fly#89)
#
# `fly_film_media()` sized `Film - BW` and `Film - Colour` from `negative_size` and refused
# everything else, so the catalogue's 3,825 infrared frames (`Film - BW IR`, `Film - Colour
# IR`) drew empty footprints. fly#30 refuses an unknown format rather than guessing, because
# a 9-inch negative applied to a different format still draws a plausible rectangle. This
# script establishes the format with three witnesses before the media values are added:
#
#   W1  adjacent-frame spacing against the ~60% designed forward overlap, fly#60's instrument,
#       at 9 inches and — to show the test discriminates — at 5 inches and 70 mm
#   W2  thumbnail aspect and frame-collar fraction against the BW/colour sweep (fly#23)
#   W3  the camera the logbook page names, transcribed by hand into
#       `data-raw/infrared_film_logbooks.csv` (an input, never regenerated)
#
# The rule was fixed and committed before any of these was read:
# `planning/archive/*issue-89*/findings.md`, "Pre-registered rule". As registered, W1 blocked
# both media values on four rolls whose spacing no candidate format fits; amendment 1, written
# after those numbers were read and approved by the user, is what W1 implements below. It is
# not restated here; the constants below are its constants.
#
# Everything is public: the centroid cache `height_calibrate-flying_height_slip.R` builds,
# the catalogue via bcdata, NRCan's MRDEM-30, and thumbnails from openmaps.gov.bc.ca.
#
# Stages:
#   0. the IR frames, and the air base of every cached frame
#   1. pull each IR roll (thumbnail and logbook URLs)
#   2. MRDEM under each IR frame's nominal square (PSOCK, cached)
#   3. W1: window, controls, per-roll spacing verdicts
#   4. W2: thumbnails, aspect and collar
#   5. W3: logbook transcription
#   6. the decision, per media value, and the shipped CSVs
#
# Writes:
#   inst/extdata/infrared_film_frames.csv     every IR frame: base, elevation, r
#   inst/extdata/infrared_film_window.csv     air base of the sweep's random frames (the window)
#   inst/extdata/infrared_film_thumbnails.csv every IR thumbnail measured
#   inst/extdata/infrared_film_pages.csv      the logbook transcription fields W3 reads
#   inst/extdata/infrared_film_rolls.csv      one row per roll: the three verdicts
#
# Env: FLY_IRFILM_SMOKE=1 runs every stage on two rolls into a separate cache and writes
# nothing.
#
# Usage, from the repo root:
#   Rscript data-raw/format_measure-infrared_film.R

suppressMessages(pkgload::load_all(quiet = TRUE))
sf::sf_use_s2(FALSE)

SMOKE     <- identical(Sys.getenv("FLY_IRFILM_SMOKE"), "1")
CENTROIDS <- "data-raw/.cache/centroids"
WORK      <- if (SMOKE) "data-raw/.cache/infrared_film_smoke" else "data-raw/.cache/infrared_film"
ROLLS_DIR <- file.path(WORK, "rolls")
IMG_DIR   <- file.path(WORK, "img")
ROT_ROLLS <- "data-raw/.cache/film_rotations/rolls"   # fly#53's pulls: read, never written
SWEEP     <- "inst/extdata/flying_height_sweep.csv"
MASK_REF  <- "inst/extdata/mask_border_sweep.csv"
LOGBOOKS  <- "data-raw/infrared_film_logbooks.csv"
LAYER     <- "WHSE_IMAGERY_AND_BASE_MAPS.AIMG_PHOTO_CENTROIDS_SP"
MRDEM     <- "/vsicurl/https://canelevation-dem.s3.ca-central-1.amazonaws.com/mrdem-30/mrdem-30-dtm.tif"
IR_MEDIA  <- c("Film - BW IR", "Film - Colour IR")
# The format sizes compared, in metres. 70 mm film exposes a ~56 mm frame.
FORMATS   <- c(in9 = 9 * 0.0254, in5 = 5 * 0.0254, mm70 = 0.056)
MIN_FRAMES <- 5L
OUT <- c(frames = "inst/extdata/infrared_film_frames.csv",
         window = "inst/extdata/infrared_film_window.csv",
         thumbs = "inst/extdata/infrared_film_thumbnails.csv",
         pages  = "inst/extdata/infrared_film_pages.csv",
         rolls  = "inst/extdata/infrared_film_rolls.csv")

for (d in c(ROLLS_DIR, IMG_DIR)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
pub <- function(fmt, ...) message(sprintf(fmt, ...))
save_atomic <- function(x, path) {
  tmp <- paste0(path, ".part")
  saveRDS(x, tmp)
  stopifnot(file.rename(tmp, path))
}
band    <- fly_height_ratio_band()
in_band <- function(r) is.finite(r) & r >= band[1] & r <= band[2]

# ---------------------------------------------------------------------------
# Stage 0 — the frames, and the air base between adjacent ones
# ---------------------------------------------------------------------------
yrs <- list.files(CENTROIDS, pattern = "^[0-9]{4}\\.rds$", full.names = TRUE)
if (length(yrs) < 100) {
  stop("The centroid cache is missing or partial: run Stage 1 of ",
       "data-raw/height_calibrate-flying_height_slip.R first.")
}
SNAPSHOT <- format(max(file.mtime(yrs)), "%Y-%m-%d")
frames <- do.call(rbind, lapply(yrs, function(p) as.data.frame(readRDS(p))))
frames <- frames[!is.na(frames$film_roll) & is.finite(frames$frame_number), ]

# Air base exactly as `height_calibrate-lower_tail_rolls.R` computes it (fly#60): the
# distance to the frame numbered one away on the same roll, the smaller of the two, keyed on
# (roll, frame) so a duplicated number cannot pair a frame with itself. Computed over the
# whole cache, because the window's random frames sit on other rolls.
frames <- frames[order(frames$film_roll, frames$frame_number), ]
key <- paste(frames$film_roll, frames$frame_number)
dup <- key %in% key[duplicated(key)]
f1  <- frames[!dup, ]
k1  <- paste(f1$film_roll, f1$frame_number)
nxt <- match(paste(f1$film_roll, f1$frame_number + 1), k1)
prv <- match(paste(f1$film_roll, f1$frame_number - 1), k1)
d_next <- sqrt((f1$x[nxt] - f1$x)^2 + (f1$y[nxt] - f1$y)^2)
d_prev <- sqrt((f1$x[prv] - f1$x)^2 + (f1$y[prv] - f1$y)^2)
f1$base <- suppressWarnings(pmin(d_next, d_prev, na.rm = TRUE))
f1$base[!is.finite(f1$base) | f1$base == 0] <- NA_real_

ir <- frames[frames$media %in% IR_MEDIA, ]
ir$base <- f1$base[match(paste(ir$film_roll, ir$frame_number), k1)]
ir$dup_key <- paste(ir$film_roll, ir$frame_number) %in% key[dup]
roll_media <- tapply(ir$media, ir$film_roll, function(m) length(unique(m)))
# Each IR roll carries one media value, and none carries frames of another medium — so the
# decision can be per media value and the base never pairs an IR frame with a non-IR one.
other <- frames$film_roll %in% ir$film_roll & !frames$media %in% IR_MEDIA
stopifnot(all(roll_media == 1), !any(other))
pub("Stage 0: %d IR frames on %d rolls (%s); %d share a (roll, frame) key; cache of %s",
    nrow(ir), length(unique(ir$film_roll)),
    paste(names(table(ir$media)), table(ir$media), sep = " ", collapse = ", "),
    sum(ir$dup_key), SNAPSHOT)

rolls <- sort(unique(ir$film_roll))
if (SMOKE) rolls <- c("bcc23", "bci93044")
ir <- ir[ir$film_roll %in% rolls, ]

# ---------------------------------------------------------------------------
# Stage 1 — pull each roll
# ---------------------------------------------------------------------------
pull_roll <- function(roll) {
  path <- file.path(ROLLS_DIR, paste0(roll, ".rds"))
  if (file.exists(path)) return(readRDS(path))
  rot <- file.path(ROT_ROLLS, paste0(roll, ".rds"))
  r <- if (file.exists(rot)) {
    readRDS(rot)
  } else {
    x <- bcdata::collect(bcdata::filter(bcdata::bcdc_query_geodata(LAYER), FILM_ROLL == !!roll))
    names(x) <- tolower(names(x))
    x
  }
  save_atomic(r, path)
  r
}
pulled <- lapply(stats::setNames(rolls, rolls), pull_roll)
for (r in rolls) {
  # A roll the catalogue now holds differently from the cache would make the two halves of
  # this script describe different frames.
  if (!setequal(pulled[[r]]$airp_id, ir$airp_id[ir$film_roll == r])) {
    stop(r, ": the catalogue pull and the centroid cache hold different frames")
  }
}
has_url <- function(u) !is.na(u) & nzchar(u)
pub("Stage 1: %d rolls pulled; %d frames with a thumbnail URL on %d rolls; %d rolls with a logbook page",
    length(pulled),
    sum(vapply(pulled, function(r) sum(has_url(r$thumbnail_image_url)), integer(1))),
    sum(vapply(pulled, function(r) any(has_url(r$thumbnail_image_url)), logical(1))),
    sum(vapply(pulled, function(r) any(has_url(r$flight_log_url)), logical(1))))

# ---------------------------------------------------------------------------
# Stage 2 — terrain under each IR frame
# ---------------------------------------------------------------------------
# The mean under the nominal 9-inch square, as `height_calibrate-flying_height_slip.R`
# samples the sweep, so `r` here is the number `fly_footprint()`'s first pass computes and
# the window's frames were measured the same way. The window's size presupposes 9 inches;
# the mean under a square moves little with its size, and it enters only `p_reported`.
ir$scale_n <- suppressWarnings(as.numeric(sub("1:", "", ir$scale)))
elev_path <- file.path(WORK, "elev.rds")
elev <- if (file.exists(elev_path)) readRDS(elev_path) else
  data.frame(airp_id = integer(0), elev = numeric(0))
todo <- ir[!ir$airp_id %in% elev$airp_id & is.finite(ir$scale_n), ]
if (nrow(todo)) {
  chunks <- split(todo, ceiling(seq_len(nrow(todo)) / 50))
  # PSOCK, never `mclapply()`: GDAL's curl handles do not survive a fork on macOS.
  cl <- parallel::makePSOCKcluster(6)
  got <- tryCatch(
    parallel::parLapply(cl, chunks, function(d, mrdem) {
      tryCatch({
        dem <- terra::rast(mrdem)
        half <- 9 * 0.0254 * d$scale_n / 2
        polys <- lapply(seq_len(nrow(d)), function(i) {
          x <- d$x[i]
          y <- d$y[i]
          h <- half[i]
          sf::st_polygon(list(rbind(c(x - h, y - h), c(x + h, y - h), c(x + h, y + h),
                                    c(x - h, y + h), c(x - h, y - h))))
        })
        v <- terra::vect(sf::st_transform(sf::st_sfc(polys, crs = 3005), terra::crs(dem)))
        e <- terra::extract(dem, v, fun = mean, na.rm = TRUE)[, 2]
        data.frame(airp_id = d$airp_id, elev = e)
      }, error = function(e) conditionMessage(e))
    }, mrdem = MRDEM),
    finally = parallel::stopCluster(cl)
  )
  failed <- vapply(got, function(g) !is.data.frame(g), logical(1))
  if (any(failed)) stop(sum(failed), " of ", length(got), " DEM chunks failed; run again")
  elev <- rbind(elev, do.call(rbind, got))
  save_atomic(elev, elev_path)
}
ir$elev <- elev$elev[match(ir$airp_id, elev$airp_id)]
ir$r <- (ir$flying_height - ir$elev) / (ir$scale_n * ir$focal_length / 1000)
pub("Stage 2: %d IR frames with no terrain under them", sum(!is.finite(ir$elev)))

# ---------------------------------------------------------------------------
# Stage 3 — W1, spacing
# ---------------------------------------------------------------------------
overlap <- function(base, side) 1 - base / side
sw <- utils::read.csv(SWEEP)
rnd <- sw[sw$set == "random", ]
rnd$base <- f1$base[match(rnd$airp_id, f1$airp_id)]
rnd$r <- (rnd$flying_height - rnd$elev) / (rnd$scale_n * rnd$focal_length / 1000)
rnd <- rnd[in_band(rnd$r), ]
rnd_side <- (rnd$flying_height - rnd$elev) / (rnd$focal_length / 1000)
p_rnd9 <- overlap(rnd$base, FORMATS[["in9"]] * rnd_side)
p_rnd5 <- overlap(rnd$base, FORMATS[["in5"]] * rnd_side)
window <- unname(stats::quantile(p_rnd9, c(.025, .975), na.rm = TRUE))
fits <- function(p) is.finite(p) & p >= window[1] & p <= window[2]
pub("Stage 3: window (random in-band, 2.5-97.5%%, n=%d): %.3f to %.3f",
    sum(is.finite(p_rnd9)), window[1], window[2])
pub("  control (a): random in-band median at 9 in %.3f (must be within 0.1 of 0.60)",
    stats::median(p_rnd9, na.rm = TRUE))
pub("  control (b): random in-band median at 5 in %.3f (must be outside the window)",
    stats::median(p_rnd5, na.rm = TRUE))
if (abs(stats::median(p_rnd9, na.rm = TRUE) - 0.6) >= 0.1) stop("control (a) failed")
if (fits(stats::median(p_rnd5, na.rm = TRUE))) stop("control (b) failed")

roll_spacing <- do.call(rbind, lapply(split(ir, ir$film_roll), function(d) {
  ok_r <- in_band(d$r)
  side_nom <- d$scale_n
  side_rep <- ifelse(ok_r, (d$flying_height - d$elev) / (d$focal_length / 1000), NA_real_)
  med <- function(fmt, side) {
    p <- overlap(d$base, FORMATS[[fmt]] * side)
    if (sum(is.finite(p)) >= MIN_FRAMES) stats::median(p, na.rm = TRUE) else NA_real_
  }
  out <- data.frame(film_roll = d$film_roll[1], media = d$media[1],
                    frames = nrow(d), n_base = sum(is.finite(d$base)),
                    n_in_band = sum(ok_r), n_reported = sum(is.finite(d$base) & ok_r),
                    r_median = stats::median(d$r, na.rm = TRUE))
  for (fmt in names(FORMATS)) {
    out[[paste0("p_nominal_", fmt)]]  <- med(fmt, side_nom)
    out[[paste0("p_reported_", fmt)]] <- med(fmt, side_rep)
  }
  out
}))
# The W1 outcome, as amended (amendment 1). A candidate format is "in" when its median lies in
# the window under some measurable reading. Below the window, a smaller format only fits worse,
# so a roll no candidate fits is `fits_no_format` — evidence about how it was flown, not about
# its format — and only a roll an ALTERNATIVE fits while 9 inches does not `contradicts`.
fmt_in <- function(fmt) {
  fits(roll_spacing[[paste0("p_nominal_", fmt)]]) | fits(roll_spacing[[paste0("p_reported_", fmt)]])
}
measurable <- is.finite(roll_spacing$p_nominal_in9) | is.finite(roll_spacing$p_reported_in9)
in9  <- fmt_in("in9")
alt  <- fmt_in("in5") | fmt_in("mm70")
roll_spacing$w1 <- ifelse(!measurable, "unmeasurable",
                   ifelse(in9 & !alt, "pass",
                   ifelse(in9 & alt, "ambiguous",
                   ifelse(alt, "contradicts", "fits_no_format"))))
pub("  W1 per roll: %s", paste(names(table(roll_spacing$w1)), table(roll_spacing$w1),
                               collapse = ", "))

# Control (c), reported: how often a roll fly already sizes at 9 inches lands outside the
# window on the nominal reading alone — the base rate the IR rolls are read against.
bw <- f1[f1$media %in% c("Film - BW", "Film - Colour"), ]
bw$p <- overlap(bw$base, FORMATS[["in9"]] *
                  suppressWarnings(as.numeric(sub("1:", "", bw$scale))))
bw_n   <- tapply(is.finite(bw$p), bw$film_roll, sum)
bw_med <- tapply(bw$p, bw$film_roll, stats::median, na.rm = TRUE)[bw_n >= MIN_FRAMES]
bw_yr  <- tapply(bw$photo_year, bw$film_roll, min)[names(bw_med)]
pub("  control (c): %d BW/colour rolls; nominal median outside the window %.2f%% (below %.2f%%, above %.2f%%); at or below 0.30: %d, flown %d-%d",
    length(bw_med), 100 * mean(!fits(bw_med)), 100 * mean(bw_med < window[1]),
    100 * mean(bw_med > window[2]), sum(bw_med <= 0.30),
    min(bw_yr[bw_med <= 0.30]), max(bw_yr[bw_med <= 0.30]))
print(roll_spacing[, c("film_roll", "media", "frames", "n_base", "n_reported", "r_median",
                       "p_nominal_in9", "p_reported_in9", "p_nominal_in5", "p_reported_in5",
                       "w1")],
      row.names = FALSE, digits = 3)

# fly#82 refused catalogue spacing as a per-pair air base, because before the 1990s centroids
# are plotted evenly along a line. A roll median is a different reading of it; printed so the
# note's comparison of the two eras has a producer.
cv <- tapply(ir$base, ir$film_roll, function(b) stats::sd(b, na.rm = TRUE) / mean(b, na.rm = TRUE))
pre <- tapply(ir$photo_year, ir$film_roll, min)[names(cv)] < 1990
pub("  base scatter (median per-roll CV): before 1990 %.4f on %d rolls, from 1990 %.4f on %d rolls",
    stats::median(cv[pre]), sum(pre), stats::median(cv[!pre]), sum(!pre))

# Reported, not a gate: how the #54 check will treat these frames once they count as film.
k <- fly_height_slip_factor()
r_rep <- (ir$flying_height / k - ir$elev) / (ir$scale_n * ir$focal_length / 1000)
ir$height_class <- ifelse(!is.finite(ir$r), "no_ratio",
                          ifelse(in_band(ir$r), "reported",
                                 ifelse(in_band(r_rep), "slip_repairable", "outside_band")))
pub("  #54 band on IR frames: %s", paste(names(table(ir$height_class)), table(ir$height_class),
                                         collapse = ", "))
# Every roll-height carrying an out-of-band frame, with what spacing says of its two readings
# and its ratio above sea level, the quantity the fly#60 and fly#72 strata are cut on.
ob <- ir[ir$height_class == "outside_band", ]
if (nrow(ob)) {
  for (g in split(ob, paste(ob$film_roll, ob$scale_n, ob$flying_height, ob$focal_length))) {
    side_rep <- (g$flying_height - g$elev) / (g$focal_length / 1000)
    pub("    %s 1:%d, %d m, %d mm: %d frames, ratio asl %.3f, r %.2f, overlap nominal %.3f, reported %.3f",
        g$film_roll[1], g$scale_n[1], g$flying_height[1], g$focal_length[1], nrow(g),
        g$flying_height[1] / (g$scale_n[1] * g$focal_length[1] / 1000),
        stats::median(g$r), stats::median(overlap(g$base, FORMATS[["in9"]] * g$scale_n), na.rm = TRUE),
        stats::median(overlap(g$base, FORMATS[["in9"]] * side_rep), na.rm = TRUE))
  }
}

# ---------------------------------------------------------------------------
# Stage 4 — W2, thumbnails
# ---------------------------------------------------------------------------
mref <- utils::read.csv(MASK_REF)
mref <- mref[mref$threshold == fly_mask_threshold(), ]
mref$aspect <- pmax(mref$nc, mref$nr) / pmin(mref$nc, mref$nr)
mref <- mref[mref$aspect < 1.5, ]                 # the 10 at 912 x 1608 are digital
ASPECT_MAX <- max(mref$aspect)
COLLAR_MAX <- max(mref$frac_total)
pub("Stage 4: reference — %d film frames, aspect max %.4f, collar max %.4f",
    nrow(mref), ASPECT_MAX, COLLAR_MAX)

thumbs <- do.call(rbind, lapply(rolls, function(roll) {
  r <- pulled[[roll]]
  r <- r[has_url(r$thumbnail_image_url), ]
  if (!nrow(r)) return(NULL)
  dir <- file.path(IMG_DIR, roll)
  got <- fly_fetch(r, type = "thumbnail", dest_dir = dir, workers = 4)
  got <- got[got$success, ]
  if (!nrow(got)) return(NULL)
  dm <- t(vapply(got$dest, function(p) {
    d <- fly_gdal_dim(fly_gdal_info(p))
    if (is.null(d)) c(NA_integer_, NA_integer_) else d
  }, integer(2)))
  # `overwrite = TRUE`: a kept masked copy comes back with NA fractions (fly_mask() will not
  # report a threshold it did not apply), so a second run would measure nothing.
  mk <- suppressWarnings(fly_mask(got$dest, dest_dir = file.path(dir, "masked"),
                                  overwrite = TRUE))
  m <- match(got$airp_id, r$airp_id)
  data.frame(airp_id = got$airp_id, film_roll = roll, frame_number = r$frame_number[m],
             media = r$media[m], nc = dm[, 1], nr = dm[, 2],
             mask_fraction = round(mk$mask_fraction, 6),
             mask_fraction_interior = round(mk$mask_fraction_interior, 6),
             masked = mk$masked, reason = ifelse(is.na(mk$reason), "", mk$reason))
}))
if (is.null(thumbs)) {
  thumbs <- data.frame(airp_id = integer(0), film_roll = character(0),
                       frame_number = integer(0), media = character(0), nc = integer(0),
                       nr = integer(0), mask_fraction = numeric(0),
                       mask_fraction_interior = numeric(0), masked = logical(0),
                       reason = character(0))
}
w2 <- do.call(rbind, lapply(rolls, function(roll) {
  t <- thumbs[thumbs$film_roll == roll, ]
  ok <- t[t$masked, ]
  asp <- if (nrow(ok)) stats::median(pmax(ok$nc, ok$nr) / pmin(ok$nc, ok$nr)) else NA_real_
  col <- if (nrow(ok)) stats::median(ok$mask_fraction) else NA_real_
  data.frame(film_roll = roll, thumbnails = nrow(t), declined = sum(!t$masked),
             aspect_median = asp, collar_median = col,
             w2 = if (!nrow(ok)) "no_thumbnails"
                  else if (asp <= ASPECT_MAX && col <= COLLAR_MAX) "pass" else "contradicts")
}))
pub("  W2 per roll: %s; %d thumbnails measured, %d declined (%s)",
    paste(names(table(w2$w2)), table(w2$w2), collapse = ", "), nrow(thumbs),
    sum(!thumbs$masked),
    paste(unique(thumbs$reason[!thumbs$masked]), collapse = "; "))
print(w2[w2$thumbnails > 0, ], row.names = FALSE, digits = 4)

# ---------------------------------------------------------------------------
# Stage 5 — W3, logbooks
# ---------------------------------------------------------------------------
# `camera_format` is filled by hand under the pre-registered classes; the note column says
# what on the page put it there.
FORMAT_CLASSES <- c("23cm", "other_format", "unrecognised", "not_stated", "illegible")
if (file.exists(LOGBOOKS)) {
  pages <- utils::read.csv(LOGBOOKS, stringsAsFactors = FALSE, na.strings = "")
  stopifnot(all(pages$camera_format %in% FORMAT_CLASSES))
  pages <- pages[pages$film_roll %in% rolls, ]
} else {
  if (!SMOKE) stop(LOGBOOKS, " is missing; it is transcribed by hand (Phase 3 of fly#89)")
  pages <- data.frame(file = character(0), film_roll = character(0),
                      camera_as_written = character(0), camera_format = character(0))
}
w3 <- do.call(rbind, lapply(rolls, function(roll) {
  p <- pages[pages$film_roll == roll, ]
  urls <- unique(pulled[[roll]]$flight_log_url)
  data.frame(film_roll = roll, log_pages = sum(has_url(urls)), pages_read = nrow(p),
             pages_23cm = sum(p$camera_format == "23cm"),
             pages_other = sum(p$camera_format == "other_format"),
             w3 = if (!nrow(p)) "no_page"
                  else if (any(p$camera_format == "other_format")) "contradicts"
                  else if (any(p$camera_format == "23cm")) "pass"
                  else if (any(p$camera_format == "unrecognised")) "unrecognised"
                  else "not_stated")
}))
pub("Stage 5: W3 per roll: %s", paste(names(table(w3$w3)), table(w3$w3), collapse = ", "))
# Every page the catalogue links must be transcribed, and every transcription must be a page
# the catalogue links — per roll, both directions. Counting rolls with zero pages read would let
# one untranscribed page, the one that names another format, pass as `pass`.
if (!SMOKE) {
  bad <- Filter(function(roll) {
    urls <- unique(pulled[[roll]]$flight_log_url)
    urls <- urls[has_url(urls)]
    # `paste0()` over zero URLs is length one ("roll__"), not zero, so guard the empty case.
    want <- if (length(urls)) paste0(roll, "__", basename(urls)) else character(0)
    !setequal(want, pages$file[pages$film_roll == roll])
  }, rolls)
  if (length(bad)) stop("logbook pages and transcription disagree for: ",
                        paste(bad, collapse = ", "))
}

# ---------------------------------------------------------------------------
# Stage 6 — the decision, and the CSVs
# ---------------------------------------------------------------------------
res <- merge(merge(roll_spacing, w2, by = "film_roll"), w3, by = "film_roll")
decision <- do.call(rbind, lapply(IR_MEDIA, function(m) {
  d <- res[res$media == m, ]
  data.frame(media = m, rolls = nrow(d), w1_pass = sum(d$w1 == "pass"),
             w1_ambiguous = sum(d$w1 == "ambiguous"),
             w1_fits_no_format = sum(d$w1 == "fits_no_format"),
             w1_contradicts = sum(d$w1 == "contradicts"),
             w1_unmeasurable = sum(d$w1 == "unmeasurable"),
             w2_pass = sum(d$w2 == "pass"), w2_contradicts = sum(d$w2 == "contradicts"),
             w3_pass = sum(d$w3 == "pass"), w3_contradicts = sum(d$w3 == "contradicts"),
             add = nrow(d) > 0 && !any(d$w1 == "contradicts") && any(d$w1 == "pass") &&
               !any(d$w2 == "contradicts") && !any(d$w3 == "contradicts"))
}))
pub("Stage 6: decision")
print(decision, row.names = FALSE)

if (SMOKE) {
  pub("Smoke run: nothing written.")
  quit(save = "no")
}

num <- function(x, d = 4) round(x, d)
frames_out <- ir[order(ir$film_roll, ir$frame_number),
                 c("airp_id", "film_roll", "frame_number", "media", "photo_year", "scale_n",
                   "focal_length", "flying_height", "elev", "base", "dup_key", "height_class")]
frames_out$elev <- num(frames_out$elev, 1)
frames_out$base <- num(frames_out$base, 1)
window_out <- data.frame(airp_id = rnd$airp_id, base = num(rnd$base, 1))
rolls_out <- res[order(res$film_roll), ]
for (col in names(rolls_out)) if (is.double(rolls_out[[col]])) rolls_out[[col]] <- num(rolls_out[[col]])
pages_out <- pages[order(pages$film_roll, pages$file),
                   c("file", "film_roll", "camera_as_written", "format_as_written", "camera_format",
                     "same_camera_bw_colour")]

write_csv <- function(d, path) utils::write.csv(d, path, row.names = FALSE, na = "")
write_csv(frames_out, OUT[["frames"]])
write_csv(window_out, OUT[["window"]])
write_csv(thumbs[order(thumbs$film_roll, thumbs$frame_number), ], OUT[["thumbs"]])
write_csv(pages_out, OUT[["pages"]])
write_csv(rolls_out, OUT[["rolls"]])
pub("Wrote %s", paste(OUT, collapse = ", "))
