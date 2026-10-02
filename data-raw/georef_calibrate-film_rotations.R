# georef_calibrate-film_rotations.R — measure the film corner mapping roll by roll (fly#53)
#
# fly#26 found the film mapping flight-relative but not constant: bc5282 (1968) 0, bc83062
# (1983) 90. So `fly_georef()` refuses a rotated film frame unless the roll's rotation is
# known. This script measures a stratified sample of rolls with `fly_rotation_calibrate()` —
# the same function a caller runs on their own roll, so the shipped table and a user's
# calibration cannot come apart — and writes a state for EVERY film roll in the catalogue, so
# an unlisted roll can only mean one added after the snapshot.
#
# The rule (leg, sign-test verdict, roll states, sample) was fixed and committed before any
# thumbnail was read, then amended after the plan review and the control thumbnails and before
# any campaign thumbnail: `planning/archive/*issue-53*/findings.md`, "Pre-registered rule" and
# "Amendments". It is implemented in `R/fly_rotation_calibrate.R` and is not restated here.
#
# Stages:
#   0. read the centroid cache `height_calibrate-flying_height_slip.R` builds (1.67 M rows)
#   1. legs for every film roll from the cache alone; eligibility; the stratified draw
#   2. controls — digital must return 270 decisive, #26's legs must reproduce their direction
#   3. pull each drawn roll from the catalogue and calibrate it (PSOCK, resumable)
#   4. write the three CSVs
#
# Writes:
#   inst/extdata/film_rotations.csv           rolls that ship, with provenance
#   inst/extdata/film_rotations_excluded.csv  every other film roll, with its state
#   inst/extdata/film_rotations_legs.csv      every leg found in a measured roll, with verdict
#   inst/extdata/film_rotations_pairs.csv     every scored pair, so the test recomputes verdicts
#   inst/extdata/film_rotations_population.csv  rolls per series x bin: all, eligible, drawn
#
# Env: FLY_FILMROT_SMOKE=1 runs Stage 2 and two drawn rolls into a separate cache and writes
# nothing. FLY_FILMROT_WORKERS sets the PSOCK workers (default 6).
#
# Usage: Rscript data-raw/georef_calibrate-film_rotations.R   (from the repo root)

suppressMessages(pkgload::load_all(quiet = TRUE))
sf::sf_use_s2(FALSE)

REPO      <- normalizePath(".")
SMOKE     <- identical(Sys.getenv("FLY_FILMROT_SMOKE"), "1")
WORKERS   <- as.integer(Sys.getenv("FLY_FILMROT_WORKERS", "6"))
CENTROIDS <- "data-raw/.cache/centroids"
WORK      <- if (SMOKE) "data-raw/.cache/film_rotations_smoke" else "data-raw/.cache/film_rotations"
ROLLS_DIR <- file.path(WORK, "rolls")      # catalogue pulls, one rds per roll
CAL_DIR   <- file.path(WORK, "cal")        # calibrate results, one rds per roll
IMG_DIR   <- file.path(WORK, "img")        # thumbnails and trial warps
LAYER     <- "WHSE_IMAGERY_AND_BASE_MAPS.AIMG_PHOTO_CENTROIDS_SP"
K_PER     <- 4L    # measurable rolls wanted per stratum
MAX_TRY   <- 12L   # rolls examined per stratum at most (amendment 7)
SEED      <- 53L
FORCED    <- c("bc5282", "bc83062")
OUT       <- "inst/extdata/film_rotations.csv"
OUT_EXCL  <- "inst/extdata/film_rotations_excluded.csv"
OUT_LEGS  <- "inst/extdata/film_rotations_legs.csv"
OUT_PAIRS <- "inst/extdata/film_rotations_pairs.csv"
OUT_POP   <- "inst/extdata/film_rotations_population.csv"
SEPARATION <- 90   # the roll rule's, so eligibility asks the question the rule will

for (d in c(ROLLS_DIR, CAL_DIR, IMG_DIR)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
pub <- function(fmt, ...) message(sprintf(fmt, ...))
series_of <- function(roll) sub("[0-9].*$", "", roll)
save_atomic <- function(x, path) {
  tmp <- paste0(path, ".part")
  saveRDS(x, tmp)
  stopifnot(file.rename(tmp, path))
}

# ---------------------------------------------------------------------------
# Stage 0 — the centroid cache
# ---------------------------------------------------------------------------
yrs <- list.files(CENTROIDS, pattern = "^[0-9]{4}\\.rds$", full.names = TRUE)
if (length(yrs) < 100) {
  stop("The centroid cache is missing or partial: run Stage 1 of ",
       "data-raw/height_calibrate-flying_height_slip.R first.")
}
SNAPSHOT <- format(max(file.mtime(yrs)), "%Y-%m-%d")
per_year <- lapply(yrs, readRDS)
per_year <- per_year[vapply(per_year, nrow, integer(1)) > 0]
cat_all <- do.call(rbind, lapply(per_year, function(d) {
  as.data.frame(d)[, c("photo_year", "film_roll", "frame_number", "media", "focal_length", "x", "y")]
}))
film <- cat_all[grepl("^Film", cat_all$media) & !is.na(cat_all$film_roll), ]
pub("Stage 0: %d film frames on %d rolls (cache of %s)", nrow(film),
    length(unique(film$film_roll)), SNAPSHOT)

# One row per film roll: the population the ledger must cover, every roll exactly once.
mode_of <- function(v) {
  v <- v[!is.na(v)]
  if (!length(v)) return(NA)
  names(sort(table(v), decreasing = TRUE))[1]
}
roll_meta <- do.call(rbind, lapply(split(film, film$film_roll), function(d) {
  data.frame(film_roll = d$film_roll[1], photo_year = min(d$photo_year),
             series = series_of(d$film_roll[1]), focal_length = mode_of(d$focal_length),
             media = mode_of(d$media), frames = nrow(d))
}))
rownames(roll_meta) <- NULL

# ---------------------------------------------------------------------------
# Stage 1 — legs from the cache, eligibility, the draw
# ---------------------------------------------------------------------------
legs_path <- file.path(WORK, "cache_legs.rds")
if (file.exists(legs_path)) {
  cache_legs <- readRDS(legs_path)
} else {
  cache_legs <- fly_rotation_legs(film$film_roll, film$frame_number, film$x, film$y)
  save_atomic(cache_legs, legs_path)
}
# Split once; a per-roll `==` scan over every leg is quadratic in the catalogue.
q_by <- split(cache_legs$bearing[cache_legs$qualifying],
              cache_legs$film_roll[cache_legs$qualifying])
found_by <- table(cache_legs$film_roll[cache_legs$n_frames >= fly_rotation_min_frames()])
elig <- do.call(rbind, lapply(roll_meta$film_roll, function(r) {
  b <- if (is.null(q_by[[r]])) numeric(0) else q_by[[r]]
  spread <- if (length(b) >= 2) max(outer(b, b, fly_bearing_diff)) else 0
  data.frame(film_roll = r,
             legs_found = if (is.na(found_by[r])) 0L else as.integer(found_by[r]),
             legs_qualifying = length(b), eligible = length(b) >= 2 && spread >= SEPARATION,
             cache_state = if (length(b) == 0) "no_qualifying_leg"
                           else if (length(b) == 1) "one_qualifying_leg"
                           else if (spread < SEPARATION) "single_direction"
                           else "not_sampled")
}))
roll_meta <- merge(roll_meta, elig, by = "film_roll")
roll_meta$bin <- floor(roll_meta$photo_year / 5) * 5
roll_meta$stratum <- paste(roll_meta$series, roll_meta$bin)

# The draw ORDER, fixed here: each stratum's eligible rolls in a seeded random permutation.
# Which of them are examined depends on thumbnail availability (Stage 1b), which the cache
# does not carry; it never depends on a verdict.
set.seed(SEED)
draw_order <- lapply(split(roll_meta, roll_meta$stratum), function(s) {
  e <- sort(s$film_roll[s$eligible])
  e[sample.int(length(e))]
})
pub("Stage 1: %d eligible of %d rolls across %d strata",
    sum(roll_meta$eligible), nrow(roll_meta), length(unique(roll_meta$stratum)))
print(table(roll_meta$series[roll_meta$eligible], roll_meta$bin[roll_meta$eligible]))

pull_roll <- function(roll) {
  path <- file.path(ROLLS_DIR, paste0(roll, ".rds"))
  if (file.exists(path)) return(readRDS(path))
  r <- bcdata::collect(bcdata::filter(bcdata::bcdc_query_geodata(LAYER), FILM_ROLL == !!roll))
  names(r) <- tolower(names(r))
  save_atomic(r, path)
  r
}

# ---------------------------------------------------------------------------
# Stage 1b — examine rolls in draw order until K_PER per stratum have thumbnails
# ---------------------------------------------------------------------------
# Amendment 7: the smoke run drew bc4196 and bc4200 (1963), neither with a single thumbnail
# URL. A roll counts toward K_PER when at least half its frames carry one. Every roll
# examined is calibrated and recorded — one with no images lands in `thumbnails_unavailable`
# without touching the network — so `drawn` is everything looked at, not only what counted.
has_thumbs <- function(r) mean(!is.na(r$thumbnail_image_url) & nzchar(r$thumbnail_image_url)) >= 0.5
avail <- list()
drawn <- character(0)
for (st in names(draw_order)) {
  got <- 0L
  for (roll in head(draw_order[[st]], MAX_TRY)) {
    if (SMOKE && got >= 1) break
    ok <- has_thumbs(pull_roll(roll))
    avail[[roll]] <- ok
    drawn <- c(drawn, roll)
    got <- got + ok
    if (got >= K_PER) break
  }
  if (SMOKE && length(drawn) >= 3) break
}
for (roll in FORCED) avail[[roll]] <- has_thumbs(pull_roll(roll))
drawn <- sort(union(drawn, FORCED))
pub("Stage 1b: %d rolls examined, %d with thumbnails", length(drawn),
    sum(unlist(avail[drawn])))

# ---------------------------------------------------------------------------
# Stage 2 — controls. Either failing stops the run.
# ---------------------------------------------------------------------------

dig <- sf::st_read(system.file("testdata/photo_centroids_digital.gpkg", package = "fly"),
                   quiet = TRUE)
dig <- dig[order(dig$film_roll, dig$frame_number), ][19:24, ]
dres <- fly_rotation_score_leg(dig, file.path(IMG_DIR, "control_digital"), "border",
                               fly_mask_threshold())
dv <- fly_rotation_verdict(dres$scores, dres$refused)
pub("Stage 2: digital control %s, decisive %s, margin %.3f", dv$rotation, dv$decisive, dv$margin)
if (!identical(dv$rotation, 270L) || !dv$decisive) stop("digital control failed")

# #26's legs as it recorded them. 108:118 is not a leg in today's catalogue and 152:162 flies
# 251 rather than the 62 #26 wrote (amendment 3); each that exists must reproduce its winner.
controls26 <- list(list("bc5282", 226:236, 0L), list("bc83062", 63:73, 90L),
                   list("bc83062", 108:118, 90L), list("bc83062", 152:162, 90L))
for (cs in controls26) {
  r <- pull_roll(cs[[1]])
  res <- fly_rotation_score_leg(r[r$frame_number %in% cs[[2]], ],
                                file.path(IMG_DIR, paste0("control_", cs[[1]], "_", cs[[2]][1])),
                                "border", fly_mask_threshold())
  if (res$status != "scored") {
    pub("  %s %d-%d: %s (not a leg in today's catalogue)", cs[[1]], min(cs[[2]]),
        max(cs[[2]]), res$status)
    next
  }
  v <- fly_rotation_verdict(res$scores, res$refused)
  pub("  %s %d-%d: %d (decisive %s, margin %.3f); #26 measured %d", cs[[1]], min(cs[[2]]),
      max(cs[[2]]), v$rotation, v$decisive, v$margin, cs[[3]])
  if (!identical(v$rotation, cs[[3]])) stop("#26 control did not reproduce its direction")
}

# ---------------------------------------------------------------------------
# Stage 3 — calibrate each drawn roll
# ---------------------------------------------------------------------------
todo <- if (SMOKE) setdiff(drawn, FORCED) else drawn
one <- function(roll) {
  out <- file.path(CAL_DIR, paste0(roll, ".rds"))
  if (file.exists(out)) return("cached")
  res <- tryCatch({
    r <- pull_roll(roll)
    list(ok = TRUE, cal = fly_rotation_calibrate(r, dest_dir = file.path(IMG_DIR, roll)))
  }, error = function(e) list(ok = FALSE, msg = conditionMessage(e)))
  # A failure is not cached, so a second run retries it.
  if (!res$ok) return(paste("failed:", res$msg))
  # The date travels with the measurement, so a re-run that calibrates a few rolls does not
  # restamp every other one with the day it happened to run (fly#89).
  res$cal$measured_on <- format(Sys.Date(), "%Y-%m-%d")
  save_atomic(res$cal, out)
  "measured"
}
if (WORKERS > 1 && length(todo) > 1) {
  cl <- parallel::makePSOCKcluster(WORKERS)
  parallel::clusterExport(cl, c("REPO", "ROLLS_DIR", "CAL_DIR", "IMG_DIR", "LAYER",
                                "pull_roll", "save_atomic"))
  parallel::clusterEvalQ(cl, {
    setwd(REPO)
    suppressMessages(pkgload::load_all(REPO, quiet = TRUE))
    sf::sf_use_s2(FALSE)
    NULL
  })
  st <- unlist(parallel::parLapplyLB(cl, todo, one))
  parallel::stopCluster(cl)
} else {
  st <- vapply(todo, one, character(1))
}
names(st) <- todo
pub("Stage 3: %s", paste(names(table(st)), table(st), sep = " ", collapse = ", "))
fails <- st[grepl("^failed:", st)]
if (length(fails)) {
  print(fails)
  stop(length(fails), " rolls failed; failures are not cached, run again")
}
cal <- dplyr::bind_rows(lapply(todo, function(r) readRDS(file.path(CAL_DIR, paste0(r, ".rds")))))
print(table(cal$state))
# Leg statuses, so a systematic failure (every warp failing one way) is seen before anything is
# written rather than arriving as a ledger full of `legs_unscorable`.
leg_status <- unlist(lapply(cal$legs, function(l) l$status))
print(table(leg_status))
if (sum(leg_status == "warp_failed") > 2) {
  stop(sum(leg_status == "warp_failed"), " legs failed to warp; investigate before writing")
}

if (SMOKE) {
  print(cal[, c("film_roll", "rotation", "state", "legs_found", "legs_qualifying")])
  pub("Smoke run: nothing written.")
  quit(save = "no")
}

# ---------------------------------------------------------------------------
# Stage 4 — write
# ---------------------------------------------------------------------------
stopifnot(setequal(cal$film_roll, drawn), !anyDuplicated(cal$film_roll))
# Each roll's own measurement date. A cal file written before fly#89 carries none; its date is
# the one the shipped tables already record for it, and a roll that has neither stops the run
# rather than being stamped with today.
if (!"measured_on" %in% names(cal)) cal$measured_on <- NA_character_
legacy <- is.na(cal$measured_on)
if (any(legacy)) {
  prev_ship <- utils::read.csv(OUT, stringsAsFactors = FALSE)
  prev_excl <- utils::read.csv(OUT_EXCL, stringsAsFactors = FALSE)
  prev_excl <- prev_excl[prev_excl$measured, ]
  prev <- data.frame(film_roll = c(prev_ship$film_roll, prev_excl$film_roll),
                     measured = c(prev_ship$measured, prev_excl$retrieved))
  cal$measured_on[legacy] <- prev$measured[match(cal$film_roll[legacy], prev$film_roll)]
  undated <- cal$film_roll[is.na(cal$measured_on)]
  if (length(undated)) {
    stop("no measurement date for ", paste(undated, collapse = ", "),
         ": its cal file predates fly#89 and the shipped tables do not list it as measured")
  }
}

legs <- dplyr::bind_rows(lapply(seq_len(nrow(cal)), function(i) {
  l <- cal$legs[[i]]
  if (!nrow(l)) return(NULL)
  cbind(film_roll = cal$film_roll[i], l)
}))
pairs <- dplyr::bind_rows(lapply(seq_len(nrow(cal)), function(i) {
  p <- cal$pairs[[i]]
  if (!nrow(p)) return(NULL)
  cbind(film_roll = cal$film_roll[i], p)
}))

ship <- cal[cal$state == "shipped", ]
shipped <- do.call(rbind, lapply(seq_len(nrow(ship)), function(i) {
  l <- ship$legs[[i]]
  l <- l[l$status == "scored" & l$decisive, ]
  m <- roll_meta[roll_meta$film_roll == ship$film_roll[i], ]
  data.frame(film_roll = ship$film_roll[i], rotation = ship$rotation[i],
             photo_year = m$photo_year, series = m$series, focal_length = m$focal_length,
             media = m$media, legs = nrow(l),
             bearings = paste(round(l$bearing, 1), collapse = ";"),
             frames = paste(l$first_frame, l$last_frame, sep = "-", collapse = ";"),
             margins = paste(sprintf("%.3f", l$margin), collapse = ";"),
             method = "overlap_r25_signtest", measured = ship$measured_on[i])
}))

excl <- roll_meta[!roll_meta$film_roll %in% shipped$film_roll, ]
m_idx <- match(excl$film_roll, cal$film_roll)
measured <- !is.na(m_idx)
excl$state <- ifelse(measured, cal$state[m_idx], excl$cache_state)
excl$measured <- measured
excl$legs_found[measured] <- cal$legs_found[m_idx[measured]]
excl$legs_qualifying[measured] <- cal$legs_qualifying[m_idx[measured]]
excl$retrieved <- ifelse(measured, cal$measured_on[m_idx], SNAPSHOT)
excluded <- excl[order(excl$film_roll), c("film_roll", "measured", "state", "retrieved")]

# Every film roll in the snapshot appears exactly once across the two tables.
stopifnot(!anyDuplicated(c(shipped$film_roll, excluded$film_roll)),
          setequal(c(shipped$film_roll, excluded$film_roll), roll_meta$film_roll))

utils::write.csv(shipped[order(shipped$film_roll), ], OUT, row.names = FALSE, na = "")
utils::write.csv(excluded, OUT_EXCL, row.names = FALSE, na = "")
utils::write.csv(legs, OUT_LEGS, row.names = FALSE, na = "")
utils::write.csv(pairs, OUT_PAIRS, row.names = FALSE, na = "")
pop_row <- function(s) {
  data.frame(series = s$series[1], bin = s$bin[1], rolls = nrow(s), eligible = sum(s$eligible),
             drawn = sum(s$film_roll %in% drawn))
}
pop <- do.call(rbind, lapply(split(roll_meta, list(roll_meta$series, roll_meta$bin), drop = TRUE),
                             pop_row))
pop <- pop[order(pop$series, pop$bin), ]
utils::write.csv(pop, OUT_POP, row.names = FALSE, na = "")
pub("Stage 4: %d shipped, %d excluded (%d measured), %d legs, %d pairs", nrow(shipped),
    nrow(excluded), sum(excluded$measured), nrow(legs), nrow(pairs))

# The stratum tabulation the note reports: does any stratum hold one value throughout?
cal_m <- merge(cal[, c("film_roll", "rotation", "state")], roll_meta, by = "film_roll")
print(with(cal_m, table(paste(series, bin), ifelse(is.na(rotation), state, rotation))))
print(with(cal_m[!is.na(cal_m$rotation), ], table(focal_length, rotation)))
print(with(cal_m[!is.na(cal_m$rotation), ], table(media, rotation)))

# One roll, several missions: do decisive legs on different segments of a roll agree?
seg <- legs[legs$status == "scored" & legs$decisive, ]
seg_rolls <- split(seg, seg$film_roll)
multi <- Filter(function(d) length(unique(d$segment)) > 1, seg_rolls)
pub("Rolls with decisive legs on more than one segment: %d; of those, rotation differs across segments: %d",
    length(multi), sum(vapply(multi, function(d) length(unique(d$rotation)) > 1, logical(1))))
