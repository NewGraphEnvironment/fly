# height_calibrate-lower_tail_rolls.R — settle the lower tail of `FLYING_HEIGHT` roll by
# roll (fly#60), with instruments that do not read the three fields in dispute.
#
# fly#54 left 1,962 film frames reading under half the height their `SCALE x FOCAL_LENGTH`
# implies, because x10.764, x10 and x2 each brought a comparable share into the band. Pooled,
# that is undecidable. Per roll it is not: the 1,962 sit on 42 rolls, and nearly every roll
# carries ONE `flying_height`, so each roll is one measurement with many witnesses.
#
# fly#71 reads the same logbooks against #54's slipped frames, which #54 divides by 10.764
# and which a divisor of 10 lands in the band just as well. Both tails go through one
# function, `settle()`, and into the same two tables, with a `tail` column saying which.
#
# Everything here is public. It reads what `height_calibrate-flying_height_slip.R` cached
# (`data-raw/.cache/centroids/`, every frame's x/y/frame_number) and shipped
# (`inst/extdata/flying_height_sweep.csv`, terrain under the sampled frames) — run that
# first. The logbook stage fetches `flight_log_url` pages into the gitignored
# `data-raw/.cache/logbooks/`.
#
# Usage, from the repo root:
#   Rscript data-raw/height_calibrate-lower_tail_rolls.R
#
# See `inst/notes/terrain-correction.md` before changing anything here.

pkgload::load_all(quiet = TRUE)
suppressMessages({
  library(bcdata)
  library(dplyr)
})

CACHE_DIR <- "data-raw/.cache/centroids"
LOG_DIR   <- "data-raw/.cache/logbooks"
SWEEP     <- "inst/extdata/flying_height_sweep.csv"
LAYER     <- "WHSE_IMAGERY_AND_BASE_MAPS.AIMG_PHOTO_CENTROIDS_SP"
FT        <- 0.3048
FORMAT_M  <- 9 * 0.0254      # the film negative, as `fly_footprint()` assumes it
K         <- fly_height_slip_factor()
band      <- fly_height_ratio_band()
in_band   <- function(r) is.finite(r) & r >= band[1] & r <= band[2]

stopifnot(dir.exists(CACHE_DIR), file.exists(SWEEP))

# ---------------------------------------------------------------------------
# Stage 1 — the frames, and the air base between adjacent ones
# ---------------------------------------------------------------------------

frames <- do.call(rbind, lapply(list.files(CACHE_DIR, "\\.rds$", full.names = TRUE), readRDS))
frames <- frames[!is.na(frames$film_roll) & is.finite(frames$frame_number), ]
message(sprintf("cache: %d frames on %d rolls", nrow(frames), length(unique(frames$film_roll))))

# Air base: distance to the frame numbered one away on the same roll — the same adjacency
# rule `fly_bearing()` applies, for the same reason: frames further apart by number may be
# on another leg. Keyed on (roll, frame) rather than on row order, so a duplicated frame
# number cannot pair a frame with itself.
frames <- frames[order(frames$film_roll, frames$frame_number), ]
key <- paste(frames$film_roll, frames$frame_number)
dup <- key %in% key[duplicated(key)]
message(sprintf("frames sharing a (roll, frame) key, excluded from spacing: %d", sum(dup)))
f1 <- frames[!dup, ]
nxt <- match(paste(f1$film_roll, f1$frame_number + 1), paste(f1$film_roll, f1$frame_number))
prv <- match(paste(f1$film_roll, f1$frame_number - 1), paste(f1$film_roll, f1$frame_number))
d_next <- sqrt((f1$x[nxt] - f1$x)^2 + (f1$y[nxt] - f1$y)^2)
d_prev <- sqrt((f1$x[prv] - f1$x)^2 + (f1$y[prv] - f1$y)^2)
# The smaller of the two: a frame at the end of a leg has one neighbour across the turn,
# and the across-turn distance is never the shorter one.
f1$base <- suppressWarnings(pmin(d_next, d_prev, na.rm = TRUE))
f1$base[!is.finite(f1$base) | f1$base == 0] <- NA_real_
base <- f1[, c("airp_id", "base")]

# ---------------------------------------------------------------------------
# Stage 2 — the sampled frames, each with the width every reading implies
# ---------------------------------------------------------------------------

s <- read.csv(SWEEP)
s <- merge(s, base, by = "airp_id", all.x = TRUE)
s$f_m <- s$focal_length / 1000
s$nominal_agl <- s$scale_n * s$f_m
s$r <- (s$flying_height - s$elev) / s$nominal_agl
# Forward overlap the frame WOULD have were its along-track side this long. Designed to
# about 60%: a reading that implies 5% or 95% is not the one the aircraft flew.
overlap <- function(side) 1 - s$base / side
s$p_nominal  <- overlap(FORMAT_M * s$scale_n)
s$p_reported <- overlap(FORMAT_M * (s$flying_height - s$elev) / s$f_m)
for (k in c(2, 10, K)) {
  s[[sprintf("p_x%s", format(round(k, 3)))]] <-
    overlap(FORMAT_M * (s$flying_height * k - s$elev) / s$f_m)
}
s$p_div <- overlap(FORMAT_M * (s$flying_height / K - s$elev) / s$f_m)

q <- function(x) sprintf("%.2f [%.2f-%.2f] n=%d", median(x, na.rm = TRUE),
                         quantile(x, .1, na.rm = TRUE), quantile(x, .9, na.rm = TRUE),
                         sum(is.finite(x)))

# --- Controls, before anything is read from the lower tail -------------------
# The instrument is believed only if it returns the known answers first.
message("\n== spacing controls: implied forward overlap, median [10-90%] ==")
rnd <- s[s$set == "random" & in_band(s$r), ]
message("random, in band, as reported:        ", q(rnd$p_reported))
message("random, in band, nominal scale:      ", q(rnd$p_nominal))
slp <- s[s$set == "upper_tail" & in_band((s$flying_height / K - s$elev) / s$nominal_agl), ]
message("#54 slipped, divided by 10.764:      ", q(slp$p_div))
message("#54 slipped, as reported:            ", q(slp$p_reported))
ctl_ok <- abs(median(rnd$p_reported, na.rm = TRUE) - 0.6) < 0.1 &&
  abs(median(slp$p_div, na.rm = TRUE) - 0.6) < 0.1 &&
  median(slp$p_reported, na.rm = TRUE) > 0.9
if (!ctl_ok) stop("spacing controls do not return the known answers; the instrument is not trusted")

# What "the aircraft flew this" looks like, taken from the ordinary frames rather than chosen:
# the central 95% of per-FRAME overlap on in-band random frames. A roll is judged on its
# median, which scatters far less than one frame does, so this window is generous.
p_window <- unname(quantile(rnd$p_reported, c(.025, .975), na.rm = TRUE))
fits <- function(p) is.finite(p) & p >= p_window[1] & p <= p_window[2]
message(sprintf("overlap window (random, 2.5-97.5%%): %.3f to %.3f", p_window[1], p_window[2]))

# --- Not a control: the note's claim about the r ~ 2 mass --------------------
# `terrain-correction.md` said the mass beyond r 1.8 is a 305 mm lens catalogued as 153, so
# nominal scale is right there. That was a hypothesis, and the spacing splits it in two: on
# some rolls nominal gives the designed overlap (the lens reading), on others the REPORTED
# height does and nominal implies ~20% (a scale recorded at half its true denominator). The
# second group is drawn at half width by the fallback. Printed per roll; fly#60 reports it.
mis <- s[s$set == "near_upper" & s$r > 1.8 & s$focal_length == 153, ]
mis_rolls <- mis |>
  group_by(film_roll, photo_year, scale_n, flying_height) |>
  summarise(n = n(), r = round(median(r), 2),
            p_nominal = round(median(p_nominal, na.rm = TRUE), 2),
            p_reported = round(median(p_reported, na.rm = TRUE), 2), .groups = "drop") |>
  mutate(fits = case_when(fits(p_nominal) & !fits(p_reported) ~ "nominal",
                          fits(p_reported) & !fits(p_nominal) ~ "reported",
                          TRUE ~ "neither")) |>
  as.data.frame()
message("\n== near_upper r > 1.8 at 153 mm, per roll-height: which reading gives ~60% ==")
print(mis_rolls[order(-mis_rolls$n), ], row.names = FALSE)
message(sprintf("frames: nominal fits %d, reported fits %d, neither %d",
                sum(mis_rolls$n[mis_rolls$fits == "nominal"]),
                sum(mis_rolls$n[mis_rolls$fits == "reported"]),
                sum(mis_rolls$n[mis_rolls$fits == "neither"])))

# ---------------------------------------------------------------------------
# Stage 3 — the lower tail, per roll
# ---------------------------------------------------------------------------

lower <- s[s$set == "lower_tail", ]
lower$k <- (lower$nominal_agl + lower$elev) / lower$flying_height
# How far a height sits from a round number of feet, in feet: the catalogue's heights are
# planned altitudes in feet converted to metres (609 m = 2,000 ft), so a correct reading of
# the recorded value, multiplied back out, should land on a round figure again.
off_round <- function(m, step = 100) {
  ft <- m / FT
  abs(ft - round(ft / step) * step)
}
rolls <- do.call(rbind, lapply(split(lower, list(lower$film_roll, lower$flying_height),
                                     drop = TRUE), function(d) {
  h <- d$flying_height[1]
  data.frame(
    film_roll = d$film_roll[1], photo_year = d$photo_year[1],
    flying_height = h, h_ft = round(h / FT),
    n = nrow(d), focal_length = paste(sort(unique(d$focal_length)), collapse = "/"),
    scale_n = paste(sort(unique(d$scale_n)), collapse = "/"),
    k_med = round(median(d$k), 3), k_spread = round(IQR(d$k) / median(d$k), 3),
    round_x1 = round(off_round(h)), round_x10 = round(off_round(h * 10)),
    round_xK = round(off_round(h * K)),
    n_base = sum(is.finite(d$base)),
    p_nominal = round(median(d$p_nominal, na.rm = TRUE), 3),
    p_reported = round(median(d$p_reported, na.rm = TRUE), 3),
    p_x2 = round(median(d$p_x2, na.rm = TRUE), 3),
    p_x10 = round(median(d$p_x10, na.rm = TRUE), 3),
    p_xK = round(median(d[[sprintf("p_x%s", format(round(K, 3)))]], na.rm = TRUE), 3),
    in_x2 = mean(in_band((h * 2 - d$elev) / d$nominal_agl)),
    in_x10 = mean(in_band((h * 10 - d$elev) / d$nominal_agl)),
    in_xK = mean(in_band((h * K - d$elev) / d$nominal_agl))
  )
}))
rolls <- rolls[order(-rolls$n), ]
# Which readings the spacing accepts, per roll-height. More than one can fit: every reading
# whose r lands in the band implies nearly the nominal width, so spacing separates readings a
# factor of ~1.6 apart and no closer. x10 and x10.764 are 7.6% apart and always fit together.
rolls$spacing_fits <- apply(
  cbind(reported = fits(rolls$p_reported), nominal = fits(rolls$p_nominal),
        x2 = fits(rolls$p_x2), x10 = fits(rolls$p_x10), xK = fits(rolls$p_xK)), 1,
  function(v) paste(c("reported", "nominal", "x2", "x10", "x10.764")[v], collapse = "+"))
rolls$spacing_fits[rolls$n_base == 0] <- "no_adjacent_frames"
stopifnot(sum(rolls$n) == nrow(lower))
message(sprintf("\n== lower tail: %d frames on %d roll-heights (%d rolls) ==",
                nrow(lower), nrow(rolls), length(unique(rolls$film_roll))))
print(rolls, row.names = FALSE)
saveRDS(rolls, "data-raw/.cache/lower_tail_rolls.rds")

# ---------------------------------------------------------------------------
# Stage 4 — the logbooks: what height and lens the crew wrote down
# ---------------------------------------------------------------------------
#
# `flight_log_url` points at scanned logbook pages. Their TRUE HEIGHT column is thousands of
# feet above mean sea level ("20.0" is 20,000 ft). The pages were transcribed by reading every
# image, with the catalogue values for the CONTROL_ rolls withheld from the reader, into
# `data-raw/flying_height_logbooks.csv` — a hand transcription, so it is an input here and is
# not regenerated. Fetching the pages again is the first half of this stage; reading them is
# not something a script can do.

fetch_logbooks <- function(rolls) {
  dir.create(LOG_DIR, recursive = TRUE, showWarnings = FALSE)
  u <- bcdc_query_geodata(LAYER) |>
    filter(FILM_ROLL %in% !!rolls) |>
    select(FILM_ROLL, FLIGHT_LOG_URL) |>
    collect() |>
    sf::st_drop_geometry() |>
    distinct(FILM_ROLL, FLIGHT_LOG_URL) |>
    filter(!is.na(FLIGHT_LOG_URL))
  h <- curl::new_handle(timeout = 60)
  status <- vapply(seq_len(nrow(u)), function(i) {
    dest <- file.path(LOG_DIR, paste0(u$FILM_ROLL[i], "__", basename(u$FLIGHT_LOG_URL[i])))
    if (file.exists(dest)) return(200L)
    resp <- tryCatch(curl::curl_fetch_disk(u$FLIGHT_LOG_URL[i], dest, handle = h),
                     error = function(e) NULL)
    if (is.null(resp)) return(NA_integer_)
    if (resp$status_code != 200) unlink(dest)
    resp$status_code
  }, integer(1))
  message(sprintf("logbook pages for %d rolls: %d fetched or cached, %d failed",
                  length(rolls), sum(status %in% 200L), sum(!status %in% 200L)))
  invisible(u)
}
# Fetched only when the cache is absent; the fly#71 pages were added by the same function
# for the slipped rolls. Delete the directory to refetch everything.
if (!dir.exists(LOG_DIR)) {
  fetch_logbooks(unique(c(rolls$film_roll, s$film_roll[s$set == "upper_tail"])))
}

logs <- read.csv("data-raw/flying_height_logbooks.csv", colClasses = "character")
logs$frame_from <- as.integer(logs$frame_from)
logs$frame_to <- as.integer(logs$frame_to)
logs$log_ft <- as.numeric(logs$height_ft_interpreted)
logs$log_focal <- as.numeric(logs$focal_mm)

# --- Controls: rolls whose answer is known, read blind -------------------------
# The two clean rolls must read back exactly as catalogued. bc78065 is a #54 slipped roll.
ctl <- logs[logs$control == "TRUE", c("film_roll", "frames_final", "log_ft", "log_focal")]
message("\n== logbook controls (catalogue values withheld from the reader) ==")
print(ctl, row.names = FALSE)
clean <- list(bcc228 = c(3856, 4267), bc7349 = 6096)
for (roll in names(clean)) {
  got <- round(ctl$log_ft[ctl$film_roll == roll] * FT)
  if (!all(vapply(clean[[roll]], function(m) any(abs(got - m) <= 2), logical(1)))) {
    stop("logbook control ", roll, " does not read back its catalogued height")
  }
}

# --- The two sets the logbooks are read against --------------------------------
# The lower tail (fly#60), and #54's slipped frames (fly#71): the upper tail brought into the
# band by dividing by 10.764. #54 could not tell x10 from x10.764 there, because both land
# every frame in the band and spacing cannot separate readings 7.6% apart. The logbook can.
upper <- s[s$set == "upper_tail", ]
upper <- upper[in_band((upper$flying_height / K - upper$elev) / upper$nominal_agl), ]
message(sprintf("\n== #54 slipped: %d frames on %d rolls ==", nrow(upper),
                length(unique(upper$film_roll))))
# Round feet as a witness that gates nothing: planned altitudes are round numbers, so the
# right reading of a planned-altitude roll lands on one. The 2003 rolls carry measured
# per-frame heights and cannot speak here.
rf <- aggregate(airp_id ~ film_roll + photo_year + flying_height, upper, length)
rf$off_x10 <- round(off_round(rf$flying_height / 10))
rf$off_xK <- round(off_round(rf$flying_height / K))
print(rf[rf$photo_year < 2003, ], row.names = FALSE)

fn <- f1[, c("airp_id", "frame_number")]

# Every frame of `set`, joined to the logbook row covering its frame number, and judged
# per roll-height against the factors `named` — the catalogue's height times the factor is
# the crew's. The rule is fly#60's, fixed before any roll was classified by it; see Stage 5.
settle <- function(set, named, tail) {
  lt <- merge(set, fn, by = "airp_id")
  stopifnot(nrow(lt) == nrow(set))
  lt$log_ft <- NA_real_
  lt$log_focal <- NA_real_
  # What the logbook says about each frame, as one of four states — never folded into "no
  # height", which is how an earlier version reported frames under a conflict or an unread
  # row as frames no logbook page covered (code-check round 3):
  #   read           one covering row with a height, or several that agree
  #   conflict       covering rows with heights that disagree; left unread, not guessed
  #   uninterpreted  covered only by rows whose height was not read, or on a roll with a
  #                  row whose frame range could not be parsed ("169-20?")
  #   none           no row on any page reaches this frame
  lt$log_state <- "none"
  unparsed_roll <- unique(logs$film_roll[is.na(logs$frame_from) & nzchar(logs$frames_final)])
  for (i in seq_len(nrow(lt))) {
    cover <- which(logs$film_roll == lt$film_roll[i] & !is.na(logs$frame_from) &
                     lt$frame_number[i] >= logs$frame_from & lt$frame_number[i] <= logs$frame_to)
    hit <- cover[is.finite(logs$log_ft[cover])]
    if (length(hit) && length(unique(logs$log_ft[hit])) == 1) {
      lt$log_state[i] <- "read"
      lt$log_ft[i] <- logs$log_ft[hit[1]]
      foc <- unique(logs$log_focal[hit][is.finite(logs$log_focal[hit])])
      if (length(foc) == 1) lt$log_focal[i] <- foc
    } else if (length(hit)) {
      lt$log_state[i] <- "conflict"
    } else if (length(cover) || lt$film_roll[i] %in% unparsed_roll) {
      lt$log_state[i] <- "uninterpreted"
    }
  }
  stopifnot(identical(lt$log_state == "read", is.finite(lt$log_ft)))
  # The factor the logbook implies, accepted only where it is one of the named slips to
  # within 2%. The catalogue stores whole metres, so a round figure of feet comes back a
  # fraction off. Held as an INDEX into `named`, so 1/10.764 is never compared as a
  # decimal string. The named factors of a set are at least 7.6% apart, so 2% cannot
  # reach two of them.
  ratio <- lt$log_ft * FT / lt$flying_height
  lt$log_factor_i <- vapply(ratio, function(q) {
    hit <- which(is.finite(q) & abs(q / named - 1) <= 0.02)
    if (length(hit) == 1) hit else NA_integer_
  }, integer(1))
  # A 6" lens is written as 152-153 mm and a 12" one anywhere from 304 to 305.
  lt$focal_agrees <- is.finite(lt$log_focal) & abs(lt$log_focal - lt$focal_length) <= 3

  # Grouped on the same four fields the shipped key carries, so a row can never describe
  # frames its key does not reach, or reach frames it does not describe.
  verdict <- do.call(rbind, lapply(split(lt, list(lt$film_roll, lt$flying_height,
                                                  lt$focal_length, lt$scale_n), drop = TRUE),
                                   function(d) {
    read <- !is.na(d$log_factor_i)
    fi <- if (any(read)) as.integer(names(which.max(table(d$log_factor_i[read])))) else NA_integer_
    agree <- read & d$log_factor_i %in% fi
    # The height the table ships is the LOGBOOK's, converted — never the catalogue's times
    # the factor. The catalogue stores whole metres of a converted figure, so bc7280's
    # 20,000 ft is catalogued as 60 m, and 60 x 100 is 6,000 m against the 6,096 the crew
    # wrote down.
    h_true <- if (any(agree)) median(d$log_ft[agree]) * FT else NA_real_
    data.frame(
      tail = tail,
      film_roll = d$film_roll[1], photo_year = d$photo_year[1],
      flying_height = d$flying_height[1],
      focal_length = d$focal_length[1], scale_n = d$scale_n[1], n = nrow(d),
      n_logbook = sum(is.finite(d$log_ft)), n_named = sum(read),
      n_conflict = sum(d$log_state == "conflict"),
      n_uninterpreted = sum(d$log_state == "uninterpreted"),
      factor = named[fi], n_agree = sum(agree),
      log_ft = if (any(agree)) median(d$log_ft[agree]) else NA_real_,
      height_m = round(h_true, 1),
      focal_logbook = paste(sort(unique(d$log_focal[is.finite(d$log_focal)])), collapse = "/"),
      # Only a LEGIBLE focal length that differs counts against the row; a blank or unread
      # one says nothing either way.
      n_focal_conflict = sum(is.finite(d$log_focal) & !d$focal_agrees),
      n_base = sum(is.finite(d$base[agree])),
      p_corrected = if (any(agree)) median(1 - d$base[agree] / (FORMAT_M * (h_true - d$elev[agree]) /
                                                                d$f_m[agree]), na.rm = TRUE) else NA_real_,
      r_corrected = if (any(agree)) median((h_true - d$elev[agree]) / d$nominal_agl[agree]) else NA_real_
    )
  }))
  verdict <- verdict[order(-verdict$n), ]
  stopifnot(sum(verdict$n) == nrow(set))
  message(sprintf("\n== %s tail against the logbooks, per roll-height ==", tail))
  print(verdict[verdict$n_logbook > 0 | verdict$photo_year < 2003, ], row.names = FALSE)
  list(verdict = verdict, frames = lt)
}

lower_v <- settle(lower, named = c(1, 10, 100), tail = "lower")
upper_v <- settle(upper, named = c(1 / 10, 1 / K), tail = "upper")
saveRDS(list(verdict = lower_v$verdict, frames = lower_v$frames),
        "data-raw/.cache/lower_tail_verdict.rds")
saveRDS(upper_v, "data-raw/.cache/upper_tail_verdict.rds")

# The control fly#60 read blind must now settle as a slipped roll, at x0.1.
ctl78 <- upper_v$verdict[upper_v$verdict$film_roll == "bc78065", ]
if (!(nrow(ctl78) == 1 && isTRUE(all.equal(ctl78$factor, 0.1)))) {
  stop("logbook control bc78065 does not settle at 1/10")
}

# ---------------------------------------------------------------------------
# Stage 5 — the verdict, and the two shipped tables
# ---------------------------------------------------------------------------
#
# The rule, fixed before any roll was classified by it. A roll-height is corrected only where
#   1. the logbook covers at least half its frames, and at least 90% of the covered frames
#      name the same factor (1, 10 or 100 in the lower tail; 1/10 or 1/10.764 among #54's
#      slipped frames);
#   2. no legible logbook focal length contradicts the catalogue's — a different lens is a
#      different defect, and nominal scale is already right for it;
#   3. spacing under the corrected height is inside the window the random frames set.
# Two instruments, independent of each other and of the three fields in dispute. A factor
# of 1 means the logbook confirms the catalogued height and the spacing accepts it: the
# SCALE is the wrong field, and the fallback to nominal scale is what draws those frames
# wrong. Among the slipped frames, spacing cannot tell 1/10 from 1/10.764 (7.6% apart), so
# there condition 3 is a sanity check and the logbook alone decides the factor.

v <- rbind(lower_v$verdict, upper_v$verdict)
v$covered <- v$n_logbook / v$n
v$agreeing <- ifelse(v$n_logbook > 0, v$n_agree / v$n_logbook, 0)
v$focal_conflict <- v$n_focal_conflict > 0
v$spacing_ok <- fits(v$p_corrected)
is_f <- function(f) is.finite(v$factor) & abs(v$factor - f) < 1e-9
# A slipped roll-height whose logbook names 1/10.764 is not tabled: #54's repair already
# sizes it from the same height, and tabling it would relabel frames without moving them.
v$confirms_54 <- v$tail == "upper" & is_f(1 / K)
v$accept <- is.finite(v$factor) & v$covered >= 0.5 & v$agreeing >= 0.9 &
  !v$focal_conflict & v$spacing_ok & !v$confirms_54
# Where the logbook read under half the frames, the reason names the state most of the
# unread frames are in — the predicate that actually fired, not the one next to it.
unread_state <- ifelse(v$n_conflict >= v$n_uninterpreted & v$n_conflict > 0, "conflict",
                       ifelse(v$n_uninterpreted > 0, "uninterpreted", "none"))
v$reason <- dplyr::case_when(
  v$accept ~ NA_character_,
  v$confirms_54 & v$covered >= 0.5 & v$agreeing >= 0.9 ~ "logbook confirms #54's 10.764",
  v$covered < 0.5 & unread_state == "conflict" ~ "logbook rows covering these frames disagree",
  v$covered < 0.5 & unread_state == "uninterpreted" ~ "logbook height or frame range not read",
  v$n_logbook == 0 ~ "no logbook page covers these frames",
  v$covered < 0.5 ~ "logbook covers under half the frames",
  !is.finite(v$factor) | v$agreeing < 0.9 ~ "logbook height is not a named multiple of the catalogue's",
  v$focal_conflict ~ "logbook names a different lens; nominal scale already sizes it",
  v$n_base == 0 ~ "no adjacent frames to measure spacing on",
  TRUE ~ "spacing rejects the logbook's height"
)
# An excluded slipped roll-height is not refused: #54's repair still sizes it. Say so, so
# the table is not read as a list of frames drawn at nominal scale.
up <- v$tail == "upper" & !v$accept & v$reason != "logbook confirms #54's 10.764"
v$reason[up] <- paste0(v$reason[up], "; #54's 10.764 still applies")
v$cause <- dplyr::case_when(
  !v$accept ~ NA_character_,
  is_f(1) ~ "scale_wrong",
  is_f(10) ~ "height_digit_dropped",
  is_f(100) ~ "height_two_digits_dropped",
  is_f(1 / 10) ~ "height_decimal_dropped"
)
stopifnot(!anyNA(v$cause[v$accept]))

rolls_out <- data.frame(
  tail = v$tail,
  film_roll = v$film_roll, flying_height = v$flying_height, focal_length = v$focal_length,
  scale_n = v$scale_n, factor = v$factor, cause = v$cause, logbook_ft = v$log_ft,
  height_m = v$height_m,
  frames_measured = v$n, frames_logbook = v$n_agree,
  overlap_corrected = round(v$p_corrected, 3), r_corrected = round(v$r_corrected, 3)
)[v$accept, ]
rolls_out <- rolls_out[order(rolls_out$tail, rolls_out$film_roll, rolls_out$flying_height), ]
excluded_out <- data.frame(
  tail = v$tail,
  film_roll = v$film_roll, flying_height = v$flying_height, focal_length = v$focal_length,
  scale_n = v$scale_n, frames_measured = v$n, reason = v$reason
)[!v$accept, ]
excluded_out <- excluded_out[order(excluded_out$tail, excluded_out$film_roll,
                                   excluded_out$flying_height), ]
stopifnot(nrow(rolls_out) + nrow(excluded_out) == nrow(v),
          sum(rolls_out$frames_measured) + sum(excluded_out$frames_measured) ==
            nrow(lower) + nrow(upper))

message(sprintf("\n== verdict: %d roll-heights corrected (%d frames), %d excluded (%d frames) ==",
                nrow(rolls_out), sum(rolls_out$frames_measured),
                nrow(excluded_out), sum(excluded_out$frames_measured)))
print(table(rolls_out$tail, rolls_out$cause))
print(tapply(rolls_out$frames_measured, list(rolls_out$tail, rolls_out$cause), sum))
print(table(excluded_out$tail, excluded_out$reason))
print(tapply(excluded_out$frames_measured, list(excluded_out$tail, excluded_out$reason), sum))
print(rolls_out, row.names = FALSE)

# The key reaches only the frames it was measured on: count what each row would touch
# across the whole catalogue, on the same four fields `fly_footprint()` matches.
# Numbers formatted as `fly_footprint()` formats them, so the two keys cannot spell one
# value two ways (100000L is "100000" to `paste()`, 100000 is "1e+05").
num <- function(x) formatC(as.numeric(x), format = "f", digits = 3)
key4 <- function(roll, h, f, sc) paste(roll, num(h), num(f), num(sc))
key_all <- key4(frames$film_roll, frames$flying_height, frames$focal_length,
                suppressWarnings(as.numeric(sub("^1:", "", frames$scale))))
reach <- vapply(seq_len(nrow(rolls_out)), function(i) {
  sum(key_all == key4(rolls_out$film_roll[i], rolls_out$flying_height[i],
                      rolls_out$focal_length[i], rolls_out$scale_n[i]))
}, integer(1))
stopifnot(all(reach >= rolls_out$frames_measured))
message(sprintf("frames the corrections reach in the whole catalogue: %d (measured: %d)",
                sum(reach), sum(rolls_out$frames_measured)))
# The two tails cannot share a key: a height cannot be both under and over the band.
stopifnot(!anyDuplicated(key4(v$film_roll, v$flying_height, v$focal_length, v$scale_n)))

write.csv(rolls_out, "inst/extdata/flying_height_rolls.csv", row.names = FALSE, na = "")
write.csv(excluded_out, "inst/extdata/flying_height_rolls_excluded.csv", row.names = FALSE,
          na = "")
