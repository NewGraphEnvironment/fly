# height_measure-terrain_tail.R — census the BW/colour frames that leave the `flying_height`
# band only through the ground under them (fly#93).
#
# `height_calibrate-lower_tail_rolls.R` cuts its strata on the ratio ABOVE SEA LEVEL, so a
# frame whose catalogued height is in band against `scale x focal_length` there, and out of it
# once terrain is subtracted, sits in none of them: with a DEM, #54 sends it to nominal scale
# whatever caused it. fly#91 settled the infrared ones as the `terrain` tail from #89's IR
# census. This is the same census for BW and colour, which the generator reads the same way.
#
# Finding them needs the DEM under every candidate, and 1.39 million frames are in band above
# sea level. So:
#   1. a coarse picture of MRDEM (`gdal_translate -outsize`, overviews averaged, ~250 m) gives
#      every frame a box mean in four summed-area-table lookups;
#   2. a margin M, twice the worst coarse error over every frame whose exact mean is known,
#      decides which frames could be out of band, and only those are read exactly;
#   3. the exact read is the sweep's own (`height_calibrate-flying_height_slip.R`, Stage 3): the
#      mean of MRDEM-30 under the nominal 9-inch square, axis-aligned, on a PSOCK cluster.
# M is then held to every frame read: the loop widens it until the frames it admits no longer
# raise it. Three controls must pass before anything is written: the worker reproduces the
# sweep's shipped `elev`, every sweep frame in the stratum is found, and a draw from just past
# the prefilter's edge holds no frame out of band. A frame above the band through terrain
# stops the script; one under terrain at or above the aircraft is counted and left untailed
# (amendment A3). The rule and the margin were fixed before the exact read:
# `planning/archive/*issue-93*/findings.md`, "Pre-registered rule".
#
# Everything is public: the centroid cache `height_calibrate-flying_height_slip.R` builds (run
# it first) and NRCan's MRDEM-30, unauthenticated.
#
# Writes:
#   inst/extdata/flying_height_terrain_frames.csv      every frame out of band only through
#                                                      terrain: base, elevation
#   inst/extdata/flying_height_terrain_population.csv  the count at each step, and M
#
# Env: FLY_TERRAIN_SMOKE=1 reads a 1,000-frame draw of the candidates into a separate cache
# and writes nothing.
#
# Usage, from the repo root:
#   Rscript data-raw/height_measure-terrain_tail.R
#
# See `inst/notes/terrain-correction.md` before changing anything here.

suppressMessages(pkgload::load_all(quiet = TRUE))
sf::sf_use_s2(FALSE)

SMOKE     <- identical(Sys.getenv("FLY_TERRAIN_SMOKE"), "1")
CENTROIDS <- "data-raw/.cache/centroids"
WORK      <- if (SMOKE) "data-raw/.cache/terrain_tail_smoke" else "data-raw/.cache/terrain_tail"
SWEEP     <- "inst/extdata/flying_height_sweep.csv"
MRDEM     <- "/vsicurl/https://canelevation-dem.s3.ca-central-1.amazonaws.com/mrdem-30/mrdem-30-dtm.tif"
FORMAT_M  <- 9 * 0.0254
OUT <- c(frames     = "inst/extdata/flying_height_terrain_frames.csv",
         population = "inst/extdata/flying_height_terrain_population.csv")

dir.create(WORK, recursive = TRUE, showWarnings = FALSE)
pub <- function(fmt, ...) message(sprintf(fmt, ...))
save_atomic <- function(x, path) {
  tmp <- paste0(path, ".part")
  saveRDS(x, tmp)
  stopifnot(file.rename(tmp, path))
}
band    <- fly_height_ratio_band()
in_band <- function(r) is.finite(r) & r >= band[1] & r <= band[2]

# ---------------------------------------------------------------------------
# Stage 0 — the DEM's version, the frames, and the air base between adjacent ones
# ---------------------------------------------------------------------------

# Every cache below is keyed on MRDEM's ETag: a cache built against another version of the
# DEM is not this measurement (MRDEM was regenerated on 2026-06-22, fly#80).
`%||%` <- function(a, b) if (is.null(a)) b else a
head_resp <- curl::curl_fetch_memory(sub("^/vsicurl/", "", MRDEM),
                                     handle = curl::new_handle(nobody = TRUE, timeout = 60))
stopifnot(head_resp$status_code == 200)
etag <- gsub('"', "", curl::parse_headers_list(head_resp$headers)[["etag"]] %||% "")
stopifnot(nzchar(etag))
vtmp <- tempfile()
writeLines(etag, vtmp)
VKEY <- substr(unname(tools::md5sum(vtmp)), 1, 8)
unlink(vtmp)
pub("Stage 0: MRDEM-30 DTM etag %s, cache key %s", etag, VKEY)

yrs <- list.files(CENTROIDS, pattern = "^[0-9]{4}\\.rds$", full.names = TRUE)
if (length(yrs) < 100) {
  stop("The centroid cache is missing or partial: run Stage 1 of ",
       "data-raw/height_calibrate-flying_height_slip.R first.")
}
frames <- do.call(rbind, lapply(yrs, function(p) as.data.frame(readRDS(p))))
stopifnot(!anyDuplicated(frames$airp_id))

# Air base exactly as `height_calibrate-lower_tail_rolls.R` computes it (fly#60): distance to
# the frame numbered one away on the same roll, the smaller of the two, keyed on (roll, frame)
# so a duplicated number cannot pair a frame with itself. The generator recomputes it and
# asserts equality, as it does for the IR census.
fb <- frames[!is.na(frames$film_roll) & is.finite(frames$frame_number), ]
fb <- fb[order(fb$film_roll, fb$frame_number), ]
key <- paste(fb$film_roll, fb$frame_number)
dup <- key %in% key[duplicated(key)]
f1  <- fb[!dup, ]
k1  <- paste(f1$film_roll, f1$frame_number)
nxt <- match(paste(f1$film_roll, f1$frame_number + 1), k1)
prv <- match(paste(f1$film_roll, f1$frame_number - 1), k1)
d_next <- sqrt((f1$x[nxt] - f1$x)^2 + (f1$y[nxt] - f1$y)^2)
d_prev <- sqrt((f1$x[prv] - f1$x)^2 + (f1$y[prv] - f1$y)^2)
f1$base <- suppressWarnings(pmin(d_next, d_prev, na.rm = TRUE))
f1$base[!is.finite(f1$base) | f1$base == 0] <- NA_real_
dup_ids <- fb$airp_id[dup]
rm(fb, key, dup, k1, nxt, prv, d_next, d_prev)

# ---------------------------------------------------------------------------
# Stage 1 — the frames in band above sea level
# ---------------------------------------------------------------------------

# The film set the sweep measured, spelled out rather than read from `fly_film_media()`:
# fly#89 added infrared film to that, and the IR frames are #89's census, not this one.
scale_n <- suppressWarnings(as.numeric(sub("^1:", "", frames$scale)))
usable <- frames$media %in% c("Film - BW", "Film - Colour") &
  is.finite(scale_n) & scale_n > 0 &
  is.finite(frames$focal_length) & frames$focal_length > 0 &
  is.finite(frames$flying_height) & frames$flying_height > 0
film <- frames[usable, c("airp_id", "photo_year", "film_roll", "frame_number", "media",
                         "focal_length", "flying_height", "x", "y")]
film$scale_n <- scale_n[usable]
rm(frames, scale_n)
film$nominal_agl <- film$scale_n * film$focal_length / 1000
film$ratio_asl <- film$flying_height / film$nominal_agl
cand <- film[in_band(film$ratio_asl), ]
pub("Stage 1: %d usable BW/colour film frames, %d in band above sea level", nrow(film), nrow(cand))

# ---------------------------------------------------------------------------
# Stage 2 — a coarse picture of MRDEM, and how wrong it is
# ---------------------------------------------------------------------------

# Read through the COG's overviews, averaged, as `dem_measure-canopy_height.R` reads its
# census (fly#80): cropping the full-resolution raster and aggregating it does not finish.
COARSE <- file.path(WORK, sprintf("dtm_coarse_%s_7000.tif", VKEY))
if (!file.exists(COARSE)) {
  bb <- sf::st_bbox(sf::st_transform(sf::st_as_sfc(sf::st_bbox(
    c(xmin = 150000, ymin = 330000, xmax = 1900000, ymax = 1800000), crs = 3005)),
    terra::crs(terra::rast(MRDEM))))
  tmp <- paste0(COARSE, ".part")
  sf::gdal_utils("translate", MRDEM, tmp, options = c(
    "-projwin", as.character(bb[1]), as.character(bb[4]), as.character(bb[3]), as.character(bb[2]),
    "-outsize", "7000", "0", "-r", "average",
    # Named: GDAL cannot guess a driver from a `.part` suffix.
    "-of", "GTiff"))
  stopifnot(file.rename(tmp, COARSE))
}
coarse <- terra::rast(COARSE)
res_c <- terra::res(coarse)[1]
cm <- terra::as.matrix(coarse, wide = TRUE)
ok <- is.finite(cm)
cm[!ok] <- 0
sat <- function(m) {
  s <- apply(m, 2, cumsum)
  t(apply(s, 1, cumsum))
}
S <- sat(cm)
K <- sat(ok * 1)
rm(cm, ok)
box <- function(tab, r0, r1, c0, c1) {
  g <- function(r, c) ifelse(r < 1 | c < 1, 0, tab[cbind(pmax(r, 1), pmax(c, 1))])
  g(r1, c1) - g(r0 - 1, c1) - g(r1, c0 - 1) + g(r0 - 1, c0 - 1)
}
# Mean of the coarse cells whose centres fall inside the nominal square; NA where none is
# valid. The square's half-side is taken in the DEM's metres, which is what makes this
# approximate — and why the margin below is measured, not assumed.
coarse_mean <- function(x, y, scale_n) {
  xy <- sf::st_coordinates(sf::st_transform(
    sf::st_as_sf(data.frame(x = x, y = y), coords = c("x", "y"), crs = 3005), terra::crs(coarse)))
  col <- (xy[, 1] - terra::xmin(coarse)) / res_c + 0.5
  row <- (terra::ymax(coarse) - xy[, 2]) / res_c + 0.5
  half <- FORMAT_M * scale_n / 2 / res_c
  r0 <- pmax(1, round(row - half))
  r1 <- pmin(nrow(S), round(row + half))
  c0 <- pmax(1, round(col - half))
  c1 <- pmin(ncol(S), round(col + half))
  inside <- r1 >= r0 & c1 >= c0
  n <- ifelse(inside, box(K, r0, r1, c0, c1), 0)
  ifelse(n > 0, box(S, r0, r1, c0, c1) / pmax(n, 1), NA_real_)
}
cand$coarse <- coarse_mean(cand$x, cand$y, cand$scale_n)

# The margin starts from every sweep frame whose coarse and exact means are both finite, and
# is then held to every frame this script reads exactly (Stage 3): the sweep over-represents
# large footprints, and the error grows on small ones over steep ground, which is where this
# stratum lives.
sw <- utils::read.csv(SWEEP)
sw <- merge(sw, film[, c("airp_id", "x", "y")], by = "airp_id")
sw$coarse <- coarse_mean(sw$x, sw$y, sw$scale_n)
err_sw <- abs(sw$coarse - sw$elev)
err_sw <- err_sw[is.finite(err_sw)]
pub(paste0("Stage 2: coarse DTM %d x %d at %.0f m; against the sweep's exact elev over %d ",
           "frames, |error| median %.1f m, 99.9%% %.1f m, max %.1f m"),
    nrow(coarse), ncol(coarse), res_c, length(err_sw), median(err_sw), quantile(err_sw, .999),
    max(err_sw))

# ---------------------------------------------------------------------------
# Stage 3 — the exact read, under every frame that could be out of band
# ---------------------------------------------------------------------------

# `need_low`: the terrain that puts r exactly on the band's lower edge. `need_high`: the same
# for the upper edge, which only ground below sea level reaches.
cand$need_low  <- cand$flying_height - band[1] * cand$nominal_agl
cand$need_high <- cand$flying_height - band[2] * cand$nominal_agl
# A frame with no valid coarse cell is read, never excluded: no number is not a small number.
prefilter <- function(M) {
  !is.finite(cand$coarse) | cand$coarse > cand$need_low - M | cand$coarse < cand$need_high + M
}

elev_path <- file.path(WORK, sprintf("elev_%s.rds", VKEY))
elev <- if (file.exists(elev_path)) readRDS(elev_path) else
  data.frame(airp_id = integer(0), elev = numeric(0))
# The sweep's worker, copied: in `height_calibrate-flying_height_slip.R` it is an anonymous
# closure, so it cannot be pulled with `fns_from()`. Control 1 is what proves the copy is the
# same instrument. PSOCK, never `mclapply()`: GDAL's curl handles do not survive a fork on
# macOS, and the wrapper exits 0 while every fork aborts.
worker <- function(d, mrdem) {
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
}
# Reads every frame of `d` not already cached, in batches each saved before the next starts,
# so an interrupted run resumes rather than repeating an hour of reads.
read_exact <- function(d) {
  todo <- d[!d$airp_id %in% elev$airp_id, c("airp_id", "x", "y", "scale_n")]
  if (!nrow(todo)) return(invisible())
  chunks <- split(todo, ceiling(seq_len(nrow(todo)) / 50))
  batches <- split(seq_along(chunks), ceiling(seq_along(chunks) / 60))
  cl <- parallel::makePSOCKcluster(6)
  on.exit(parallel::stopCluster(cl))
  for (b in seq_along(batches)) {
    got <- parallel::parLapply(cl, chunks[batches[[b]]], worker, mrdem = MRDEM)
    failed <- vapply(got, function(g) !is.data.frame(g), logical(1))
    if (any(failed)) {
      stop(sum(failed), " of ", length(got), " DEM chunks failed in batch ", b,
           " (", unlist(got[failed])[1], "); run again — finished batches are kept")
    }
    elev <<- rbind(elev, do.call(rbind, got))
    save_atomic(elev, elev_path)
    pub("  batch %d of %d: %d frames in the cache", b, length(batches), nrow(elev))
  }
  stopifnot(all(d$airp_id %in% elev$airp_id))
}

set.seed(93)
smoke_ids <- cand$airp_id[0]
# M is twice the worst coarse error over every frame whose exact mean is known: the sweep's,
# then every frame read here. Reading more frames can only raise it, so the loop widens the
# prefilter until the frames it reads no longer move M. It stops on the first pass whose
# reads leave M where it was.
M <- 2 * max(err_sw)
pass <- 0
repeat {
  pass <- pass + 1
  pre <- prefilter(M)
  take <- cand[pre, ]
  if (SMOKE) {
    smoke_ids <- union(smoke_ids, take$airp_id[sample.int(nrow(take), min(1000, nrow(take)))])
    take <- take[take$airp_id %in% smoke_ids, ]
  }
  pub("Stage 3, pass %d: M = %.1f m, %d frames to read (%d by the lower edge, %d by the upper, %d with no coarse cell)",
      pass, M, nrow(take), sum(is.finite(cand$coarse) & cand$coarse > cand$need_low - M),
      sum(is.finite(cand$coarse) & cand$coarse < cand$need_high + M), sum(!is.finite(cand$coarse)))
  read_exact(take)
  e_take <- elev$elev[match(take$airp_id, elev$airp_id)]
  err_rd <- abs(take$coarse - e_take)
  err_rd <- err_rd[is.finite(err_rd)]
  M_new <- 2 * max(c(err_sw, err_rd))
  pub("  |coarse - exact| over %d frames read: median %.1f m, 99.9%% %.1f m, max %.1f m",
      length(err_rd), median(err_rd), quantile(err_rd, .999), max(err_rd))
  if (M_new <= M) break
  M <- M_new
}
err <- c(err_sw, err_rd)

# Control 1: the instrument is the sweep's. Every sweep frame the prefilter took, and a seeded
# draw of 100 more, so the worker is held to the sweep's numbers even where it took few.
sw_in <- sw$airp_id[sw$airp_id %in% take$airp_id]
sw_other <- setdiff(sw$airp_id, sw_in)
sw_ctl <- c(sw_in, sw_other[sample.int(length(sw_other), 100)])
read_exact(film[film$airp_id %in% sw_ctl, ])
ctl <- merge(sw[sw$airp_id %in% sw_ctl, c("airp_id", "elev")],
             stats::setNames(elev, c("airp_id", "elev_here")), by = "airp_id")
d_ctl <- abs(ctl$elev - ctl$elev_here)
pub("Control 1: %d sweep frames read again; max |difference| %.3f m (%d inside the prefilter)",
    nrow(ctl), max(d_ctl, na.rm = TRUE), length(sw_in))
if (nrow(ctl) != length(sw_ctl) || !identical(is.finite(ctl$elev), is.finite(ctl$elev_here)) ||
    any(d_ctl > 0.1, na.rm = TRUE)) {
  stop("the exact read does not reproduce the sweep's elev: a different instrument or a ",
       "different MRDEM, and its frames would not be comparable with the sweep's")
}

# Control 3: the rejected region. A seeded draw of up to 1,000 frames the prefilter turned away,
# from the 500 m just past its lower edge, read exactly. Not one may be out of band.
rej <- which(!pre & is.finite(cand$coarse) & cand$coarse > cand$need_low - M - 500)
rej <- cand[rej[sample.int(length(rej), min(1000, length(rej)))], ]
read_exact(rej)
rej_r <- (rej$flying_height - round(elev$elev[match(rej$airp_id, elev$airp_id)], 1)) / rej$nominal_agl
pub("Control 3: %d frames from the 500 m past the prefilter, read exactly: %d out of band",
    nrow(rej), sum(is.finite(rej_r) & !in_band(rej_r)))
if (any(is.finite(rej_r) & !in_band(rej_r))) stop("the prefilter turned away a frame out of band")

# ---------------------------------------------------------------------------
# Stage 4 — the census
# ---------------------------------------------------------------------------

read <- take
# Classified on `elev` as it ships, to 0.1 m, so the suite recomputing `r` from the shipped
# column draws exactly this census rather than one that differs at the band edge.
read$elev <- round(elev$elev[match(read$airp_id, elev$airp_id)], 1)
read$r <- (read$flying_height - read$elev) / read$nominal_agl
out <- is.finite(read$r) & !in_band(read$r)
below <- out & read$r < band[1] & read$r > 0
above <- out & read$r > band[2]
# Terrain at or above the aircraft (amendment A3, written after the smoke run found 11 in
# 1,074). `fly_footprint()` keeps these in its own terrain-above-aircraft case and applies a
# factor-1 row only where `r_reported > 0`, so the `terrain` tail cannot move them. They are
# counted and shipped in the population table, never assigned to a tail.
nonpos <- out & read$r <= 0
pub("Stage 4: %d read; %d with no terrain under them; out of band %d (below %d, above %d, r <= 0 %d on %d rolls)",
    nrow(read), sum(!is.finite(read$elev)), sum(out), sum(below), sum(above), sum(nonpos),
    length(unique(read$film_roll[nonpos])))
if (any(above)) {
  stop("frames above the band through terrain, for which no rule was fixed: ",
       paste(unique(read$film_roll[above]), collapse = ", "))
}

# How close the margin came to binding: for each census frame, how far its coarse mean sat
# inside the prefilter. A frame the margin only just admitted means M was nearly too small.
terr <- read[below, ]
slack <- terr$coarse - (terr$need_low - M)
pub("  margin: smallest slack among census frames %.1f m of M = %.1f m (coarse NA on %d)",
    min(slack, na.rm = TRUE), M, sum(!is.finite(terr$coarse)))
pub("  census frames the coarse mean put more than max |error| (%.1f m) inside the band: %d",
    max(err), sum(is.finite(terr$coarse) & terr$coarse < terr$need_low - max(err)))

# --- Control 2: completeness ----------------------------------------------------
rnd <- sw[sw$set == "random", ]
rnd$nominal_agl <- rnd$scale_n * rnd$focal_length / 1000
rnd$r <- (rnd$flying_height - rnd$elev) / rnd$nominal_agl
rnd_terr <- rnd$airp_id[in_band(rnd$flying_height / rnd$nominal_agl) & !in_band(rnd$r) &
                          is.finite(rnd$r) & rnd$r > 0]
pub("Control 2: sweep random frames out of band only through terrain %d; in the census %d",
    length(rnd_terr), sum(rnd_terr %in% terr$airp_id))
# A smoke run reads a draw, so it reports this rather than stopping on it.
if (!SMOKE && !all(rnd_terr %in% terr$airp_id)) {
  stop("the census misses sweep frames in its own stratum")
}

terr$base <- f1$base[match(terr$airp_id, f1$airp_id)]
terr$dup_key <- terr$airp_id %in% dup_ids
rh <- unique(terr[, c("film_roll", "flying_height", "focal_length", "scale_n")])
pub("  census: %d frames on %d roll-heights, %d rolls; %d share a (roll, frame) key",
    nrow(terr), nrow(rh), length(unique(terr$film_roll)), sum(terr$dup_key))
print(table(decade = 10 * (terr$photo_year %/% 10)))

# Spacing per roll-height, previewed here and decided in the generator (amendment A2): the
# window is the generator's, the central 95% of in-band random frames' overlap as reported.
rnd$base <- f1$base[match(rnd$airp_id, f1$airp_id)]
rnd_in <- rnd[in_band(rnd$r), ]
p_win <- unname(quantile(1 - rnd_in$base / (FORMAT_M * (rnd_in$flying_height - rnd_in$elev) /
                                             (rnd_in$focal_length / 1000)),
                         c(.025, .975), na.rm = TRUE))
fits <- function(p) is.finite(p) & p >= p_win[1] & p <= p_win[2]
# Overlap at `k` times the catalogued height. A frame whose ground sits within that height has
# no finite value, and on the low side no bound at all.
p_at <- function(d, k) {
  side <- d$flying_height * k - d$elev
  ifelse(side > 0, 1 - d$base / (FORMAT_M * side / (d$focal_length / 1000)), -Inf)
}
a2 <- do.call(rbind, lapply(split(terr, list(terr$film_roll, terr$flying_height, terr$focal_length,
                                             terr$scale_n), drop = TRUE), function(d) {
  ok <- is.finite(d$base)
  data.frame(n = nrow(d),
             nominal_fits = fits(median(1 - d$base / (FORMAT_M * d$scale_n), na.rm = TRUE)),
             reported_can = any(ok) && max(p_at(d[ok, ], 1.02)) >= p_win[1] &&
               min(p_at(d[ok, ], 0.98)) <= p_win[2])
}))
pub(paste0("  A2 preview (window %.3f-%.3f): spacing fits nominal %d roll-heights (%d frames); ",
           "cannot fit the catalogued height within 2%% %d (%d); to transcribe %d (%d frames)"),
    p_win[1], p_win[2], sum(a2$nominal_fits), sum(a2$n[a2$nominal_fits]),
    sum(!a2$nominal_fits & !a2$reported_can), sum(a2$n[!a2$nominal_fits & !a2$reported_can]),
    sum(!a2$nominal_fits & a2$reported_can), sum(a2$n[!a2$nominal_fits & a2$reported_can]))

if (SMOKE) {
  pub("Smoke run: nothing written.")
  quit(save = "no")
}

# ---------------------------------------------------------------------------
# Stage 5 — the shipped CSVs
# ---------------------------------------------------------------------------

num <- function(x, d) round(x, d)
frames_out <- terr[order(terr$film_roll, terr$frame_number, terr$airp_id),
                   c("airp_id", "film_roll", "frame_number", "media", "photo_year", "scale_n",
                     "focal_length", "flying_height", "elev", "base", "dup_key")]
frames_out$base <- num(frames_out$base, 1)
r_out <- (frames_out$flying_height - frames_out$elev) /
  (frames_out$scale_n * frames_out$focal_length / 1000)
stopifnot(all(r_out < band[1] & r_out > 0))
population <- data.frame(
  step = c("usable_bw_colour", "in_band_asl", "read_exactly", "read_no_terrain",
           "terrain_below", "terrain_above", "terrain_nonpositive", "sweep_random_terrain",
           "roll_heights", "rolls", "rejected_region_read", "rejected_region_out_of_band"),
  n = c(nrow(film), nrow(cand), nrow(read), sum(!is.finite(read$elev)), sum(below), sum(above),
        sum(nonpos), length(rnd_terr), nrow(rh), length(unique(terr$film_roll)), nrow(rej),
        sum(is.finite(rej_r) & !in_band(rej_r))))
population <- rbind(population,
                    data.frame(step = c("coarse_error_max_m", "margin_m"),
                               n = c(num(max(err), 1), num(M, 1))))
write_csv <- function(d, path) utils::write.csv(d, path, row.names = FALSE, na = "")
write_csv(frames_out, OUT[["frames"]])
write_csv(population, OUT[["population"]])
pub("Stage 5: wrote %s (%d rows) and %s", OUT[["frames"]], nrow(frames_out), OUT[["population"]])
