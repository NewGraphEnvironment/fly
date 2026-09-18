# height_calibrate-flying_height_slip.R — measure the catalogue's `FLYING_HEIGHT` unit
# slip (fly#54) and the two constants `fly_footprint(dem = )` guards against it with.
#
# Everything here is public: the airphoto centroid layer of the BC Data Catalogue and
# NRCan's MRDEM-30, both unauthenticated.
#
# Usage, from the repo root:
#   Rscript data-raw/height_calibrate-flying_height_slip.R
#
# Stage 1 pulls every centroid's sizing attributes, one year at a time, into
# `data-raw/.cache/centroids/` (gitignored, ~1.67 million rows, resumable — a year already
# on disk is not fetched again). Stage 2 finds the slipped frames without a DEM. Stage 3
# samples MRDEM under the slipped frames and under a control set of legitimate ones chosen
# for the least favourable cases. Stage 4 writes `inst/extdata/flying_height_sweep.csv` (the
# sampled frames) and `flying_height_population.csv` (every film frame, binned), which the
# test suite reads so that the constants are checked against the data rather than trusted.
# See `inst/notes/terrain-correction.md` before changing anything here.

# `pkgload::load_all()` unconditionally, never `requireNamespace()`: a generation script
# operates on the source tree by definition.
pkgload::load_all(quiet = TRUE)
suppressMessages({
  library(bcdata)
  library(dplyr)
  library(sf)
})
sf::sf_use_s2(FALSE)

LAYER     <- "WHSE_IMAGERY_AND_BASE_MAPS.AIMG_PHOTO_CENTROIDS_SP"
CACHE_DIR <- "data-raw/.cache/centroids"
OUT_CSV   <- "inst/extdata/flying_height_sweep.csv"
OUT_POP   <- "inst/extdata/flying_height_population.csv"
MRDEM     <- "/vsicurl/https://canelevation-dem.s3.ca-central-1.amazonaws.com/mrdem-30/mrdem-30-dtm.tif"
YEARS     <- 1900:as.integer(format(Sys.Date(), "%Y"))

dir.create(CACHE_DIR, recursive = TRUE, showWarnings = FALSE)

# ---------------------------------------------------------------------------
# Stage 1 — pull
# ---------------------------------------------------------------------------

# The catalogue's own count, from a WFS `resultType=hits` request rather than from
# bcdata, so the reconciliation below compares two independent sources.
catalogue_total <- function() {
  url <- paste0(
    "https://openmaps.gov.bc.ca/geo/pub/wfs?service=WFS&version=2.0.0&request=GetFeature",
    "&typeName=pub:", LAYER, "&resultType=hits"
  )
  resp <- curl::curl_fetch_memory(url, handle = curl::new_handle(timeout = 120))
  stopifnot(resp$status_code == 200)
  n <- regmatches(rawToChar(resp$content),
                  regexpr('numberMatched="[0-9]+"', rawToChar(resp$content)))
  stopifnot(length(n) == 1)
  as.numeric(gsub("[^0-9]", "", n))
}

year_path <- function(y) file.path(CACHE_DIR, sprintf("%d.rds", y))

pull_year <- function(y) {
  path <- year_path(y)
  if (file.exists(path)) {
    return(invisible(path))
  }
  d <- bcdc_query_geodata(LAYER) |>
    filter(PHOTO_YEAR == !!y) |>
    select(AIRP_ID, PHOTO_YEAR, SCALE, FILM_ROLL, FRAME_NUMBER, MEDIA, FOCAL_LENGTH,
           FLYING_HEIGHT, GROUND_SAMPLE_DISTANCE) |>
    collect()
  names(d) <- tolower(names(d))
  xy <- sf::st_coordinates(sf::st_transform(sf::st_geometry(d), 3005))
  out <- sf::st_drop_geometry(d)[, intersect(
    c("airp_id", "photo_year", "scale", "film_roll", "frame_number", "media",
      "focal_length", "flying_height", "ground_sample_distance"), names(d)
  )]
  out <- as.data.frame(out)
  out$x <- if (nrow(out)) xy[, 1] else numeric(0)
  out$y <- if (nrow(out)) xy[, 2] else numeric(0)
  # Written to a temp name and renamed, so an interrupted pull never leaves a year that
  # reads as complete.
  tmp <- paste0(path, ".part")
  saveRDS(out, tmp)
  stopifnot(file.rename(tmp, path))
  message(sprintf("  %d: %d frames", y, nrow(out)))
  invisible(path)
}

message("Stage 1 — pulling centroids by year into ", CACHE_DIR)
for (y in YEARS) {
  ok <- FALSE
  for (attempt in 1:3) {
    ok <- tryCatch({
      pull_year(y)
      TRUE
    }, error = function(e) {
      message(sprintf("  %d: attempt %d failed — %s", y, attempt, conditionMessage(e)))
      FALSE
    })
    if (ok) break
  }
  if (!ok) stop("could not pull ", y, " after 3 attempts")
}

# An empty year comes back with no attribute columns at all, which `rbind()` refuses.
per_year <- lapply(YEARS, function(y) readRDS(year_path(y)))
frames <- do.call(rbind, per_year[vapply(per_year, nrow, integer(1)) > 0])
n_catalogue <- catalogue_total()
message(sprintf("pulled %d frames; the catalogue reports %d", nrow(frames), n_catalogue))

# ---------------------------------------------------------------------------
# Stage 2 — the sweep that needs no DEM
# ---------------------------------------------------------------------------

# Reconcile before measuring anything. A year loop silently misses a frame whose
# `PHOTO_YEAR` is NULL, so the tolerance is stated rather than assumed to be zero, and the
# catalogue is live, so an exact match is not the right test either.
stopifnot(abs(nrow(frames) - n_catalogue) / n_catalogue < 0.001)
stopifnot(!anyDuplicated(frames$airp_id))

scale_n <- suppressWarnings(as.numeric(sub("^1:", "", frames$scale)))
is_film <- frames$media %in% fly_film_media()
usable  <- is_film & is.finite(scale_n) & scale_n > 0 &
  is.finite(frames$focal_length) & frames$focal_length > 0 &
  is.finite(frames$flying_height) & frames$flying_height > 0

film <- frames[usable, ]
film$scale_n <- scale_n[usable]
# Height above ground the reported scale implies: scale x focal length.
film$nominal_agl <- film$scale_n * film$focal_length / 1000
# `flying_height` is metres above SEA LEVEL, so this is an upper bound on the ratio the
# DEM route will see — terrain only ever lowers it. That is what lets the upper tail be
# found without a DEM, and it is why the lower tail cannot be.
film$ratio_asl <- film$flying_height / film$nominal_agl

message(sprintf("film frames %d, usable %d; everything else %d",
                sum(is_film), nrow(film), sum(!is_film)))
print(table(cut(film$ratio_asl, c(0, .25, .5, .75, .9, 1.5, 2, 3, 4, 5, 7, 9, 12, 20, Inf))))

# ---------------------------------------------------------------------------
# Stage 3 — terrain under the frames that decide the constants
# ---------------------------------------------------------------------------

set.seed(54)
take <- function(d, n) d[sample(nrow(d), min(n, nrow(d))), ]

sets <- rbind(
  # Every frame the upper check could fire on, slipped or not.
  cbind(film[film$ratio_asl > 3, ], set = "upper_tail"),
  # The least favourable legitimate frames for the upper bound, computed rather than
  # remembered: low flights over high ground, where terrain is a large share of the
  # reported height and `ratio_asl` runs high for a frame with nothing wrong with it.
  cbind(take(film[film$ratio_asl > 2 & film$ratio_asl <= 3, ], 600), set = "near_upper"),
  # What an ordinary frame looks like. Drawn before the lower tail was added below and
  # from a population that includes it, so it stays a sample of everything at or under 2.
  cbind(take(film[film$ratio_asl <= 2, ], 2500), set = "random")
)
# Every frame whose reported height is under half what its scale implies. `r <= ratio_asl`,
# so all of these are outside any band without a DEM; terrain is sampled under them only
# to test whether the slip also runs the other way (stored = true metres / 3.28084^2).
lower <- film[film$ratio_asl <= 0.5 & !film$airp_id %in% sets$airp_id, ]
sets <- rbind(sets, cbind(lower, set = "lower_tail"))
message(sprintf("DEM sampling %d frames: %s", nrow(sets),
                paste(names(table(sets$set)), table(sets$set), collapse = ", ")))

# Mean terrain under the NOMINAL footprint — the window `fly_footprint()`'s first pass
# averages over, so `r` here is the number the guard will actually compute. Axis-aligned:
# a sample carries no adjacent frame to take a bearing from, and the mean under a square
# moves little under rotation.
elev_path <- "data-raw/.cache/flying_height_elev.rds"
if (file.exists(elev_path)) {
  elev <- readRDS(elev_path)
} else {
  elev <- data.frame(airp_id = integer(0), elev = numeric(0))
}
todo <- sets[!sets$airp_id %in% elev$airp_id, ]
if (nrow(todo)) {
  chunks <- split(todo, ceiling(seq_len(nrow(todo)) / 50))
  # A PSOCK cluster, not `mclapply()`: GDAL's curl handles do not survive a fork on macOS,
  # and every one of 104 forked chunks aborted with "An irrecoverable exception occurred"
  # while the wrapper still exited 0.
  cl <- parallel::makeCluster(6)
  got <- tryCatch(
    parallel::parLapply(cl, chunks, function(d, mrdem) {
      tryCatch({
        dem <- terra::rast(mrdem)
        half <- 9 * 0.0254 * d$scale_n / 2
        polys <- lapply(seq_len(nrow(d)), function(i) {
          x <- d$x[i]; y <- d$y[i]; h <- half[i]
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
  if (any(failed)) stop(sum(failed), " of ", length(got), " DEM chunks failed")
  elev <- rbind(elev, do.call(rbind, got))
  saveRDS(elev, elev_path)
}
sets$elev <- elev$elev[match(sets$airp_id, elev$airp_id)]
message(sprintf("frames with no terrain under them: %d", sum(!is.finite(sets$elev))))

# ---------------------------------------------------------------------------
# Stage 4 — what the constants rest on, and the sweep the suite re-reads
# ---------------------------------------------------------------------------

k    <- fly_height_slip_factor()
band <- fly_height_ratio_band()
in_band <- function(r) is.finite(r) & r >= band[1] & r <= band[2]

sets$r     <- (sets$flying_height - sets$elev) / sets$nominal_agl
sets$r_fix <- (sets$flying_height / k - sets$elev) / sets$nominal_agl

q <- c(0, .005, .025, .5, .975, .995, 1)
message("\nrandom frames, r:");            print(round(quantile(sets$r[sets$set == "random"], q), 3))
message("random frames inside the band: ",
        sprintf("%.1f%%", 100 * mean(in_band(sets$r[sets$set == "random"]))))
message("near_upper frames, r:");          print(round(quantile(sets$r[sets$set == "near_upper"], q), 3))

# The slipped population, identified by ROLL and by a ratio no terrain can explain — not by
# the rule under test, or the check below could only agree with itself.
slipped <- sets$set == "upper_tail" & sets$ratio_asl > 9
message(sprintf("\nslipped: %d frames on %d rolls", sum(slipped),
                length(unique(sets$film_roll[slipped]))))
print(as.data.frame(
  sets[slipped, ] |>
    group_by(photo_year, film_roll, scale, focal_length) |>
    summarise(n = n(), fh_min = min(flying_height), fh_max = max(flying_height),
              r = round(median(r), 2), r_fix = round(median(r_fix), 2), .groups = "drop")
))
message("slipped, raw r:");      print(round(quantile(sets$r[slipped], q), 2))
message("slipped, repaired r:"); print(round(quantile(sets$r_fix[slipped], q), 3))
stopifnot(all(in_band(sets$r_fix[slipped])), !any(in_band(sets$r[slipped])))

# Frames on a slipped roll that are NOT slipped would mean the rule has to work per frame
# rather than per roll. It does work per frame; this says whether it needs to.
partial <- film[film$film_roll %in% unique(sets$film_roll[slipped]) & film$ratio_asl <= 9, ]
message(sprintf("frames on a slipped roll that are not themselves slipped: %d", nrow(partial)))

# A repair that fires on a frame outside the slipped population would be the rule
# inventing a height. Every sampled frame outside the band, slipped ones aside:
other <- !slipped & !in_band(sets$r)
message(sprintf("\noutside the band and not slipped: %d sampled frames; repair would fire on %d",
                sum(other), sum(in_band(sets$r_fix[other]))))
message("the empty stretch between the two populations, in r: ",
        sprintf("%.2f to %.2f", max(sets$r[!slipped]), min(sets$r[slipped])))

# The other way round. Multiplying by the same factor brings some of the lower tail into
# the band too — and so does multiplying by ten (a dropped digit in a height in feet), and
# for a different set of rolls so does doubling (a 305 mm lens recorded for a 153). Three
# remedies, none separable from the others by the terrain, so none is applied.
lower <- sets[sets$set == "lower_tail", ]
alt <- function(f) sum(in_band((lower$flying_height * f - lower$elev) / lower$nominal_agl))
message(sprintf("\nlower tail %d frames; into the band under x%.2f: %d, under x10: %d, under x2: %d",
                nrow(lower), k, alt(k), alt(10), alt(2)))

# The ceiling: highest height on a frame with nothing wrong with it, film and digital.
# `Digital`, by name: `!is_film` would sweep in the infrared film stocks, which fly does not
# size at all and whose heights run higher.
digital <- frames[grepl("^Digital", frames$media) & is.finite(frames$flying_height), ]
message(sprintf("\nhighest legitimate film flying_height (ratio_asl <= 3): %d m; digital: %d m; ceiling %d m",
                max(film$flying_height[film$ratio_asl <= 3]), max(digital$flying_height),
                fly_flying_height_max()))
message(sprintf("digital frames above the ceiling: %d of %d",
                sum(digital$flying_height > fly_flying_height_max()), nrow(digital)))

# --- the population, binned: what the sampled sets stand for ------------------
edges <- c(0, .25, .5, .75, .9, 1.5, 2, 3, 4, 5, 7, 9, 12, 20, Inf)
bin <- cut(film$ratio_asl, edges)
population <- data.frame(
  media = "film",
  ratio_asl_from = head(edges, -1),
  ratio_asl_to = tail(edges, -1),
  n = as.integer(table(bin)),
  flying_height_max = as.integer(tapply(film$flying_height, bin, max)[levels(bin)])
)
population <- rbind(population, data.frame(
  media = "digital", ratio_asl_from = NA, ratio_asl_to = NA,
  n = nrow(digital), flying_height_max = as.integer(max(digital$flying_height))
))

sweep <- sets[order(sets$set, sets$airp_id),
              c("airp_id", "photo_year", "film_roll", "scale_n", "focal_length",
                "flying_height", "elev", "set")]
sweep$elev <- round(sweep$elev, 1)

# Rewritten only when the content moved, so re-running the script against an unchanged
# catalogue leaves `git status` clean.
write_if_changed <- function(d, path) {
  tmp <- tempfile(fileext = ".csv")
  utils::write.csv(d, tmp, row.names = FALSE)
  if (!file.exists(path) || tools::md5sum(tmp) != tools::md5sum(path)) {
    file.copy(tmp, path, overwrite = TRUE) || stop("could not write ", path)
    message("wrote ", path, " (", nrow(d), " rows)")
  } else {
    message(path, " unchanged")
  }
}
write_if_changed(sweep, OUT_CSV)
write_if_changed(population, OUT_POP)
message("ALL DONE")
