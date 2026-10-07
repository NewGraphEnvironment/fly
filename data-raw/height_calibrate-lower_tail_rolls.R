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
# fly#72 adds a third set: the `near_upper` frames beyond the band, the r ~ 2 mass the note
# once called a 305 mm lens catalogued as 153. Spacing says that is true of about half; on
# the other half the catalogued height is the one flown and `scale` is the wrong field. The
# logbooks are read against it the same way, with 1 the only factor named.
#
# fly#91 adds the infrared frames fly#89 brought into the band check. The sweep holds none,
# so they come from the IR census `format_measure-infrared_film.R` ships. `bci9` falls in
# #72's stratum and joins it. `bc5312` and `bci12` are in band above sea level and leave it
# only through terrain, which no stratum above holds, so they are a fourth tail, `terrain`,
# under the near_upper rule unchanged. Run that script first as well.
#
# fly#93 adds the BW/colour frames of that kind, from the census
# `height_measure-terrain_tail.R` ships (run it first too), to the same `terrain` tail under
# the same rule. Amendment A2, fixed before any of their pages was read, evaluates the rule's
# spacing condition first: a roll-height for which it cannot hold whatever a logbook says is
# excluded with that reason, and only the rest have their pages fetched and transcribed.
#
# fly#95 asks of two groups fly#93 left whether the catalogued height is a height ABOVE GROUND
# recorded as above sea level: the frames under terrain at or above the aircraft, which the
# census ships separately, and the roll-heights A2 found nominal scale fits. Spacing is read
# first (Stage 3c), the logbooks after (Stage 6), by a rule fixed before either was computed.
# It writes `inst/extdata/flying_height_above_ground.csv`, one row per roll-height, and stops
# rather than tabling one, since how a tabled row would be encoded is not yet decided.
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
# fly#72 was opened on this split, and the verdict below is read against it: the spacing must
# still divide these 209 frames the way the issue reports before any logbook is consulted.
split_n <- tapply(mis_rolls$n, mis_rolls$fits, sum)
if (!identical(as.integer(split_n[c("nominal", "reported", "neither")]), c(90L, 105L, 14L))) {
  stop("near_upper spacing split no longer reproduces fly#72's 90 / 105 / 14")
}

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
# Stage 3b — the infrared census (fly#91)
# ---------------------------------------------------------------------------
#
# fly#89 sized infrared film as the 9-inch negative, and the sweep above is pinned to the
# BW/colour set it was measured over, so no IR frame is in any of its strata. The IR frames
# outside the band come instead from `infrared_film_frames.csv`, a census of every IR frame
# whose `elev` is the sweep's own measure (the mean under the nominal 9-inch square). Each
# goes to the stratum its ratio above sea level puts it in, by the rule fixed before the
# logbooks were read (archived findings of fly#91):
#   near_upper  2 < ratio <= 3 and beyond the band — #72's stratum, settled alongside its
#               sample (rbind into the same set), not drawn into it;
#   terrain     ratio above sea level inside the band and above ground outside it: out of
#               band only because of the ground under it, which no other tail holds.
# Anything else stops the script: a frame no rule was fixed for is not assigned to one.
irf <- read.csv("inst/extdata/infrared_film_frames.csv")
irf <- irf[irf$height_class == "outside_band", ]
# The census's air base and this script's must be the same measurement.
ir_base <- base$base[match(irf$airp_id, base$airp_id)]
stopifnot(identical(is.finite(ir_base), is.finite(irf$base)),
          all(abs(ir_base - irf$base) <= 0.1, na.rm = TRUE))
# A census frame with the widths every reading implies, by Stage 2's arithmetic, from the
# census's own `elev` and this script's `base`. Shared by the IR census and fly#93's.
widths <- function(d) {
  d$f_m <- d$focal_length / 1000
  d$nominal_agl <- d$scale_n * d$f_m
  d$r <- (d$flying_height - d$elev) / d$nominal_agl
  ov <- function(side) 1 - d$base / side
  d$p_nominal  <- ov(FORMAT_M * d$scale_n)
  d$p_reported <- ov(FORMAT_M * (d$flying_height - d$elev) / d$f_m)
  for (k in c(2, 10, K)) {
    d[[sprintf("p_x%s", format(round(k, 3)))]] <-
      ov(FORMAT_M * (d$flying_height * k - d$elev) / d$f_m)
  }
  d$p_div <- ov(FORMAT_M * (d$flying_height / K - d$elev) / d$f_m)
  stopifnot(setequal(names(d), names(s)))
  d[, names(s)]
}
census_frames <- function(cf, b) {
  widths(data.frame(airp_id = cf$airp_id, photo_year = cf$photo_year, film_roll = cf$film_roll,
                    scale_n = cf$scale_n, focal_length = cf$focal_length,
                    flying_height = cf$flying_height, elev = cf$elev, set = NA_character_,
                    base = b))
}
irs <- census_frames(irf, ir_base)
ratio_asl <- irs$flying_height / irs$nominal_agl
irs$set[ratio_asl > 2 & ratio_asl <= 3 & irs$r > band[2]] <- "near_upper"
irs$set[in_band(ratio_asl) & !in_band(irs$r) & irs$r > 0] <- "terrain"
if (anyNA(irs$set)) {
  stop("IR frames outside the band in no stratum fly#91 fixed a rule for: ",
       paste(unique(irs$film_roll[is.na(irs$set)]), collapse = ", "))
}
ir_near <- irs[irs$set == "near_upper", ]
terr <- irs[irs$set == "terrain", ]
message(sprintf("\n== infrared census outside the band: %d frames; near_upper %d (%s), terrain %d (%s) ==",
                nrow(irs), nrow(ir_near), paste(unique(ir_near$film_roll), collapse = ", "),
                nrow(terr), paste(unique(terr$film_roll), collapse = ", ")))

# --- fly#93: the BW/colour frames out of band only through terrain -------------------
# A census, `height_measure-terrain_tail.R`: every usable BW/colour frame in band above sea
# level whose `r` under the sweep's own elevation measure is below the band (none is above it,
# and frames under terrain at or above the aircraft are counted there and left untailed, since
# `fly_footprint()` applies no factor-1 row to them). They join fly#91's IR terrain frames.
bwf <- read.csv("inst/extdata/flying_height_terrain_frames.csv")
bw_base <- base$base[match(bwf$airp_id, base$airp_id)]
stopifnot(identical(is.finite(bw_base), is.finite(bwf$base)),
          all(abs(bw_base - bwf$base) <= 0.1, na.rm = TRUE))
bws <- census_frames(bwf, bw_base)
bws$set <- "terrain"
stopifnot(all(in_band(bws$flying_height / bws$nominal_agl)), all(bws$r > 0 & bws$r < band[1]),
          !any(bws$airp_id %in% irs$airp_id))
# The census must hold every sweep frame of its stratum: the random draw's share, which the
# issue's estimate was made from, is a sample of it.
rnd_all <- s[s$set == "random", ]
rnd_terr <- in_band(rnd_all$flying_height / rnd_all$nominal_agl) & !in_band(rnd_all$r) &
  is.finite(rnd_all$r) & rnd_all$r > 0
stopifnot(all(rnd_all$airp_id[rnd_terr] %in% bws$airp_id))
terr <- rbind(terr, bws)
message(sprintf("BW/colour terrain census: %d frames on %d rolls; the random draw's %d of %d are all in it",
                nrow(bws), length(unique(bws$film_roll)), sum(rnd_terr), nrow(rnd_all)))

# Numbers formatted as `fly_footprint()` formats them, so the two keys cannot spell one
# value two ways (100000L is "100000" to `paste()`, 100000 is "1e+05").
num <- function(x) formatC(as.numeric(x), format = "f", digits = 3)
key4 <- function(roll, h, f, sc) paste(roll, num(h), num(f), num(sc))

# Amendment A2 (fly#93, fixed before any of these pages was read): the rule's spacing
# condition, examined before the logbook, from quantities no logbook can change.
#   (a) `p_nominal` is the median over every frame of the roll-height; if it fits the window,
#       condition 3 fails whatever is read.
#   (b) under factor 1 the shipped height is within 2% of the catalogue's, and `p_corrected`
#       is a median over the frames whose logbook agrees. Overlap rises with height, so each
#       frame's value lies in [p(0.98 h), p(1.02 h)], and a median of any subset lies within
#       its members' range: if [min p(0.98 h), max p(1.02 h)] misses the window, or no frame
#       has an air base, condition 3 fails whatever is read. That holds only while every
#       frame's ground is below 0.98 h: where one's is not, a logbook height under its ground
#       gives an overlap above 1 and a subset median can be lifted into the window from below,
#       so such a roll-height has no bound and goes to the logbook (code-check round 1).
# So A2 excludes only roll-heights the unamended rule could never accept; their pages are
# not fetched, and the reason says which half fired.
p_at <- function(d, k) {
  side <- d$flying_height * k - d$elev
  ifelse(side > 0, 1 - d$base / (FORMAT_M * side / d$f_m), -Inf)
}
A2_NOMINAL <- "spacing fits nominal scale, which no logbook height changes; nominal scale still applies"
A2_CANNOT  <- "spacing cannot fit the catalogued height within 2%, whatever the logbook reads"
terr_groups <- split(terr, list(terr$film_roll, terr$flying_height, terr$focal_length, terr$scale_n),
                     drop = TRUE)
a2 <- do.call(rbind, lapply(terr_groups, function(d) {
  ok <- is.finite(d$base)
  lo <- if (any(ok)) min(p_at(d[ok, ], 0.98)) else NA_real_
  hi <- if (any(ok)) max(p_at(d[ok, ], 1.02)) else NA_real_
  unbounded <- any(ok & d$flying_height * 0.98 <= d$elev)
  can <- any(ok) && (unbounded || (hi >= p_window[1] && lo <= p_window[2]))
  reason <- if (fits(median(d$p_nominal, na.rm = TRUE))) A2_NOMINAL else if (!can) A2_CANNOT else NA
  data.frame(key = key4(d$film_roll[1], d$flying_height[1], d$focal_length[1], d$scale_n[1]),
             film_roll = d$film_roll[1], n = nrow(d), a2_reason = as.character(reason))
}))
message(sprintf(paste0("A2: of %d terrain roll-heights, %d fit nominal (%d frames), %d cannot fit the ",
                       "catalogued height (%d), %d go to the logbook (%d frames, %d rolls)"),
                nrow(a2), sum(a2$a2_reason %in% A2_NOMINAL), sum(a2$n[a2$a2_reason %in% A2_NOMINAL]),
                sum(a2$a2_reason %in% A2_CANNOT), sum(a2$n[a2$a2_reason %in% A2_CANNOT]),
                sum(is.na(a2$a2_reason)), sum(a2$n[is.na(a2$a2_reason)]),
                length(unique(a2$film_roll[is.na(a2$a2_reason)]))))

# ---------------------------------------------------------------------------
# Stage 3c — fly#95: is the catalogued height above ground? Spacing, before any page
# ---------------------------------------------------------------------------
#
# The rule, fixed before any per-roll-height number existed (archived findings of fly#95,
# "Pre-registered rule"). Read as a height above ground, the catalogued height gives each frame
# an along-track side of FORMAT_M x flying_height / f; nominal scale gives FORMAT_M x scale.
# Neither depends on terrain, so a roll-height mixing frames under the aircraft and frames
# under the ground is judged on one quantity, and the two sides are exactly `ratio_asl` apart.
#   supports   the height read as above ground fits the window and nominal does not
#   undecided  both fit: the two cannot be told apart, and differ by |ratio_asl - 1|
#   refutes    the height read as above ground does not fit
#   no_base    no frame has an air base
# Only `supports` can table, so only its rolls go to the logbook (as A2 does for fly#93).
npf <- read.csv("inst/extdata/flying_height_terrain_nonpositive.csv")
np_base <- base$base[match(npf$airp_id, base$airp_id)]
stopifnot(identical(is.finite(np_base), is.finite(npf$base)),
          all(abs(np_base - npf$base) <= 0.1, na.rm = TRUE))
nps <- census_frames(npf, np_base)
nps$set <- "nonpositive"
stopifnot(all(in_band(nps$flying_height / nps$nominal_agl)), all(nps$flying_height <= nps$elev),
          !any(nps$airp_id %in% terr$airp_id))
pool <- rbind(terr, nps)
pool_key <- key4(pool$film_roll, pool$flying_height, pool$focal_length, pool$scale_n)
agl_keys <- union(key4(nps$film_roll, nps$flying_height, nps$focal_length, nps$scale_n),
                  a2$key[a2$a2_reason %in% A2_NOMINAL])
agl <- pool[pool_key %in% agl_keys, ]
agl$p_agl <- 1 - agl$base / (FORMAT_M * agl$flying_height / agl$f_m)
agl_s <- do.call(rbind, lapply(split(agl, list(agl$film_roll, agl$flying_height, agl$focal_length,
                                               agl$scale_n), drop = TRUE), function(d) {
  p_agl <- median(d$p_agl, na.rm = TRUE)
  p_nom <- median(d$p_nominal, na.rm = TRUE)
  data.frame(key = key4(d$film_roll[1], d$flying_height[1], d$focal_length[1], d$scale_n[1]),
             film_roll = d$film_roll[1], photo_year = d$photo_year[1],
             flying_height = d$flying_height[1], focal_length = d$focal_length[1],
             scale_n = d$scale_n[1], n = nrow(d), n_nonpositive = sum(d$set == "nonpositive"),
             ratio_asl = d$flying_height[1] / d$nominal_agl[1], n_base = sum(is.finite(d$base)),
             p_agl = p_agl, p_nominal = p_nom,
             spacing = if (!any(is.finite(d$base))) "no_base" else if (!fits(p_agl)) "refutes"
                       else if (fits(p_nom)) "undecided" else "supports")
}))
stopifnot(setequal(agl_s$key, agl_keys), sum(agl_s$n) == nrow(agl))
message(sprintf(paste0("\n== fly#95 above ground, spacing: %d roll-heights (%d frames, %d under the ",
                       "aircraft); supports %d, undecided %d, refutes %d, no_base %d =="),
                nrow(agl_s), nrow(agl), sum(agl_s$n_nonpositive), sum(agl_s$spacing == "supports"),
                sum(agl_s$spacing == "undecided"), sum(agl_s$spacing == "refutes"),
                sum(agl_s$spacing == "no_base")))
agl_rolls <- unique(agl_s$film_roll[agl_s$spacing == "supports"])

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
# Fetched for every roll with no page in the cache: the lower tail (fly#60), #54's slipped
# frames (fly#71), the near_upper frames beyond the band (fly#72), the infrared census
# outside it (fly#91), the BW/colour terrain roll-heights A2 leaves to the logbook (fly#93) and the
# roll-heights spacing supports reading above ground (fly#95).
# A roll the catalogue
# links no page for is queried again on each run, which costs one request and changes
# nothing. Delete the directory to refetch everything.
want <- unique(c(rolls$film_roll, s$film_roll[s$set == "upper_tail"],
                 s$film_roll[s$set == "near_upper" & is.finite(s$r) & s$r > band[2]],
                 irs$film_roll, a2$film_roll[is.na(a2$a2_reason)], agl_rolls))
cached <- if (dir.exists(LOG_DIR)) unique(sub("__.*", "", list.files(LOG_DIR))) else character()
if (length(setdiff(want, cached))) fetch_logbooks(setdiff(want, cached))

logs <- read.csv("data-raw/flying_height_logbooks.csv", colClasses = "character")
# Every cached page of a terrain roll A2 leaves to the logbook must have been read (fly#93). The
# set of those rolls moves whenever A2 or the census does, and the pages are fetched here but
# read by hand, so a page fetched and never transcribed would otherwise reach `settle()` as "no
# logbook page covers these frames": an absent reading reported as an absent page (code-check
# round 2, where six pages on two rolls a fix had just sent to the logbook were exactly that).
# The pages are the ones the CATALOGUE links, not the ones in the cache: a fetch that failed
# leaves a page uncached without stopping, and a roll with any cached page is not fetched
# again, so a cache listing would miss it (code-check round 3).
# fly#95's `supports` rolls are held to the same guard: only they can table, so only their
# pages are read, and an unread one must not reach the rule as an absent one.
terr_rolls <- unique(c(a2$film_roll[is.na(a2$a2_reason)], agl_rolls))
linked <- bcdc_query_geodata(LAYER) |>
  filter(FILM_ROLL %in% !!terr_rolls) |>
  select(FILM_ROLL, FLIGHT_LOG_URL) |>
  collect() |>
  sf::st_drop_geometry() |>
  distinct(FILM_ROLL, FLIGHT_LOG_URL) |>
  filter(!is.na(FLIGHT_LOG_URL))
linked_pages <- paste0(linked$FILM_ROLL, "__", basename(linked$FLIGHT_LOG_URL))
cached_pages <- if (dir.exists(LOG_DIR)) list.files(LOG_DIR) else character()
uncached <- setdiff(linked_pages, cached_pages)
if (length(uncached)) {
  stop(length(uncached), " logbook pages the catalogue links for terrain or above-ground rolls sent to the ",
       "logbook are not in ", LOG_DIR, ": ", paste(uncached, collapse = ", "))
}
unread <- union(linked_pages, cached_pages[sub("__.*", "", cached_pages) %in% terr_rolls])
unread <- unread[!unread %in% logs$file]
if (length(unread)) {
  stop(length(unread), " logbook pages of terrain or above-ground rolls sent to the logbook are not transcribed in ",
       "data-raw/flying_height_logbooks.csv: ", paste(unread, collapse = ", "))
}
message(sprintf("terrain and above-ground rolls sent to the logbook: %d; pages the catalogue links %d, all cached and transcribed",
                length(terr_rolls), length(linked_pages)))
logs$frame_from <- as.integer(logs$frame_from)
logs$frame_to <- as.integer(logs$frame_to)
logs$log_ft <- as.numeric(logs$height_ft_interpreted)
logs$log_focal <- as.numeric(logs$focal_mm)
# A page's photo scale, read only where the field STARTS with it ("1:15,000 (project line)",
# "SCALE: 1:52,000 (title)", "(1:15,000) in project line"): a scale quoted inside a remark
# ("not requested at 1:40,000") is not the one flown, and would veto a row by accident.
# One thousands style per figure — commas, spaces, or none, in groups of three — and no digit
# may follow it, however spaced: "1:15,000 123" or "1:15840 12 frames" is read as no scale
# at all rather than swallowed into 15,000,123 or cut short. A missed scale only withholds a
# veto; a misread one could fire it.
#
# Either "1:" or "1/" (fly#91, amendment A1, written before the infrared pages were read):
# those pages write "Scale 1/15,840", which a colon-only pattern reads as no scale at all,
# silently withholding the veto. No BW/colour row writes a slash, so no verdict moves.
scale_pat <- paste0(
  "^\\s*\\(?\\s*(?:scale\\s*:?\\s*)?1\\s*[:/]\\s*",
  "([0-9]{1,3}(?:,[0-9]{3})+|[0-9]{1,3}(?: [0-9]{3})+|[0-9]+)",
  "(?![0-9]|,[0-9]|\\s+[0-9])"
)
scale_hit <- regmatches(logs$scale_as_written,
                        regexec(scale_pat, logs$scale_as_written, perl = TRUE, ignore.case = TRUE))
logs$log_scale <- vapply(scale_hit, function(m) {
  if (length(m) < 2) NA_real_ else as.numeric(gsub("[, ]", "", m[2]))
}, numeric(1))

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
  lt$log_scale <- NA_real_
  # What the logbook says about each frame, as one of four states — never folded into "no
  # height", which is how an earlier version reported frames under a conflict or an unread
  # row as frames no logbook page covered (code-check round 3):
  #   read           one covering row with a height, or several that agree
  #   conflict       covering rows with heights that disagree; left unread, not guessed
  #   uninterpreted  covered only by rows whose height was not read, or on a roll with a
  #                  row whose frame range could not be parsed ("169-20?")
  #   unspanned      the roll has transcribed rows, and none reaches this frame: a page that
  #                  ends before it, or lines the consolidation declined to span (fly#93,
  #                  code-check round 3, where this was reported as "no logbook page")
  #   none           no transcribed row on any page of the roll
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
      # The photo scale where the page writes one ("1:15,840", "SCALE: 1:31,680"): the one
      # field that states the value fly#72 disputes. Read as the digits after "1:".
      sc <- unique(logs$log_scale[hit][is.finite(logs$log_scale[hit])])
      if (length(sc) == 1) lt$log_scale[i] <- sc
    } else if (length(hit)) {
      lt$log_state[i] <- "conflict"
    } else if (length(cover) || lt$film_roll[i] %in% unparsed_roll) {
      lt$log_state[i] <- "uninterpreted"
    }
  }
  lt$log_state[lt$log_state == "none" & lt$film_roll %in% logs$film_roll] <- "unspanned"
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
      n_unspanned = sum(d$log_state == "unspanned"),
      factor = named[fi], n_agree = sum(agree),
      log_ft = if (any(agree)) median(d$log_ft[agree]) else NA_real_,
      height_m = round(h_true, 1),
      focal_logbook = paste(sort(unique(d$log_focal[is.finite(d$log_focal)])), collapse = "/"),
      # Only a LEGIBLE focal length that differs counts against the row; a blank or unread
      # one says nothing either way.
      n_focal_conflict = sum(is.finite(d$log_focal) & !d$focal_agrees),
      # A legible logbook scale, against the catalogue's and against twice it (fly#72).
      n_scale_read = sum(is.finite(d$log_scale)),
      n_scale_same = sum(is.finite(d$log_scale) & abs(d$log_scale / d$scale_n - 1) <= 0.02),
      n_scale_double = sum(is.finite(d$log_scale) & abs(d$log_scale / (2 * d$scale_n) - 1) <= 0.02),
      p_nominal = median(d$p_nominal, na.rm = TRUE),
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

# The near_upper frames beyond the band (fly#72): the r ~ 2 mass the note called a 305 mm lens
# catalogued as 153, which spacing splits in two. Only a factor of 1 is named: the question is
# whether the crew flew the catalogued height, in which case the SCALE is the wrong field and
# the nominal fallback draws the frame at half width. A logbook naming a 12" lens is the other
# half, and condition 2 below already excludes it as a different defect. The sweep holds a
# 600-frame SAMPLE of this stratum (2 < r above sea level <= 3), not a census, so a roll-height
# no sampled frame sits on is unmeasured here.
near <- s[s$set == "near_upper" & is.finite(s$r) & s$r > band[2], ]
message(sprintf("\n== near_upper beyond the band: %d frames on %d rolls ==", nrow(near),
                length(unique(near$film_roll))))

lower_v <- settle(lower, named = c(1, 10, 100), tail = "lower")
upper_v <- settle(upper, named = c(1 / 10, 1 / K), tail = "upper")
# fly#91: the infrared near_upper frames join #72's sample under the same rule; the terrain
# frames are their own tail, under the same rule again (see Stage 5).
near <- rbind(near, ir_near[, names(near)])
near_v <- settle(near, named = 1, tail = "near_upper")
terr_v <- settle(terr, named = 1, tail = "terrain")
saveRDS(list(verdict = lower_v$verdict, frames = lower_v$frames),
        "data-raw/.cache/lower_tail_verdict.rds")
saveRDS(upper_v, "data-raw/.cache/upper_tail_verdict.rds")
saveRDS(near_v, "data-raw/.cache/near_upper_verdict.rds")
saveRDS(terr_v, "data-raw/.cache/terrain_verdict.rds")

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
#
# The near_upper frames (fly#72) go through the same rule unchanged, with 1 the only factor
# named. There condition 3 is the discriminating witness rather than a sanity check: the two
# readings on offer, the catalogued height and nominal scale, are a factor of ~2 apart, which
# spacing separates. A factor-1 row there is the upper-side mirror of the lower tail's
# `scale_wrong`: the same cause, from the other side of the band.
#
# The terrain frames (fly#91) go through the near_upper rule unchanged, fixed before their
# logbooks were read: their ratio above sea level is inside the band and only the ground
# takes them out of it, so the two readings on offer are again the catalogued height and
# nominal scale, ~2x apart, and spacing must fit the one and reject the other.

v <- rbind(lower_v$verdict, upper_v$verdict, near_v$verdict, terr_v$verdict)
v$covered <- v$n_logbook / v$n
v$agreeing <- ifelse(v$n_logbook > 0, v$n_agree / v$n_logbook, 0)
v$focal_conflict <- v$n_focal_conflict > 0
v$spacing_ok <- fits(v$p_corrected)
# near_upper (fly#72): the logbook height cannot tell the two readings apart — a 305 mm lens
# catalogued as 153 ALSO flew the catalogued height — so factor 1 agrees on lens rolls too.
# What separates them is the spacing, and there it must do both halves: fit the reported
# height AND reject nominal scale, the same test the issue's split was made with. Fitting
# alone is not enough: on a lens roll the reported height implies ~0.80 overlap, and the
# window's top is 0.78. And a legible logbook scale equal to the catalogue's vetoes the row,
# since `scale` is the field the row says is wrong.
nu_row <- v$tail %in% c("near_upper", "terrain")
v$spacing_ok[nu_row] <- v$spacing_ok[nu_row] & !fits(v$p_nominal[nu_row])
v$scale_veto <- nu_row & v$n_scale_same > 0
is_f <- function(f) is.finite(v$factor) & abs(v$factor - f) < 1e-9
# A slipped roll-height whose logbook names 1/10.764 is not tabled: #54's repair already
# sizes it from the same height, and tabling it would relabel frames without moving them.
v$confirms_54 <- v$tail == "upper" & is_f(1 / K)
# A2 (fly#93): redundant with `spacing_ok` by construction, and held anyway, because the
# pages of a roll are transcribed whole and an A2 roll-height can carry covering rows.
v$a2_reason <- NA_character_
it <- v$tail == "terrain"
v$a2_reason[it] <- a2$a2_reason[match(key4(v$film_roll, v$flying_height, v$focal_length,
                                           v$scale_n)[it], a2$key)]
v$accept <- is.finite(v$factor) & v$covered >= 0.5 & v$agreeing >= 0.9 &
  !v$focal_conflict & v$spacing_ok & !v$confirms_54 & !v$scale_veto & is.na(v$a2_reason)
# Where the logbook read under half the frames, the reason names an unread state that actually
# fired, by precedence: conflict, then uninterpreted (each where any frame is in it), then — only
# where no frame was read at all — unspanned, then none. So "not read" can be named on a
# roll-height whose unread frames are mostly unspanned (bc78033 at 1,676 m: 4 uninterpreted, 26
# unspanned); it is still true there, and no verdict depends on which is named.
unread_state <- ifelse(v$n_conflict >= v$n_uninterpreted & v$n_conflict > 0, "conflict",
                       ifelse(v$n_uninterpreted > 0, "uninterpreted", "none"))
v$reason <- dplyr::case_when(
  v$accept ~ NA_character_,
  !is.na(v$a2_reason) ~ v$a2_reason,
  v$confirms_54 & v$covered >= 0.5 & v$agreeing >= 0.9 ~ "logbook confirms #54's 10.764",
  v$covered < 0.5 & unread_state == "conflict" ~ "logbook rows covering these frames disagree",
  v$covered < 0.5 & unread_state == "uninterpreted" ~ "logbook height or frame range not read",
  # A roll-height on a roll with transcribed rows that reach none of its frames is not one
  # with no page: the two states are kept apart (fly#93, code-check round 3).
  v$n_logbook == 0 & v$n_unspanned > 0 ~ "transcribed logbook rows reach none of these frames",
  v$n_logbook == 0 ~ "no logbook page covers these frames",
  v$covered < 0.5 ~ "logbook covers under half the frames",
  !is.finite(v$factor) | v$agreeing < 0.9 ~ "logbook height is not a named multiple of the catalogue's",
  v$focal_conflict & nu_row & fits(v$p_corrected) & !fits(v$p_nominal) ~
    "logbook names a different lens and spacing fits the reported height; the two disagree",
  v$focal_conflict ~ "logbook names a different lens; nominal scale already sizes it",
  v$scale_veto ~ "logbook writes the catalogue's scale",
  nu_row & fits(v$p_corrected) & fits(v$p_nominal) ~
    "spacing fits both the reported height and nominal scale",
  v$n_base == 0 ~ "no adjacent frames to measure spacing on",
  TRUE ~ "spacing rejects the logbook's height"
)
# ---------------------------------------------------------------------------
# Stage 5b — a third witness: the same roll's adjacent frames (fly#74)
# ---------------------------------------------------------------------------
#
# Some roll-heights no logbook settles are one digit away from the frame beside them: bc5596
# 204-211 read 26,212 m where frame 203 reads 2,621, and bcb98013 frame 52 reads 97,924 where
# frames 51 and 53 read 7,924. The rule, fixed before it was run over the population, and run
# over EVERY roll-height the logbook rule left excluded, in both tails:
#   1. adjacent: a frame numbered one away from a frame of the roll-height, on the same roll,
#      lens and scale, at a different height — the adjacency `fly_bearing()` demands;
#   2. that neighbour's height is itself in the band, against this roll-height's own median
#      terrain (neighbours are not sampled, so this is a proxy; `fly_footprint()` holds each
#      frame to the band again);
#   3. the catalogue height stands in an EXACT named relation to it: upper tail x10, x10.764
#      or one leading digit added; lower tail /10, /100 or the leading digit dropped. x10.764
#      is named for the reason the logbook names it: a neighbour confirming #54 must be able
#      to contradict one naming x10, and a roll-height every neighbour puts at x10.764 is left
#      to #54's repair, which already sizes it from the same height. Exact means within
#      what the catalogue's storage of a converted figure can move it: it keeps whole
#      metres, sometimes ROUNDED and sometimes TRUNCATED (2,000 ft = 609.6 m is stored as
#      609 on bc5449, whose logbook this table already reads). So with the larger height
#      `big`, the smaller `small`, and each off its true value by a in [-0.5, 1),
#      big - k small lies in [-(1 + k/2), k + 1/2]; and string identity for the digits.
#      That covers figures converted at 0.3048 m/ft. Some were converted at 3.28 ft/m and
#      rounded (20,000 ft is 6,098 on 2,677 frames), which can put a genuine relation
#      outside the bound: such a pair is REFUSED, never wrongly accepted, and no pair in
#      today's data sits between the bound and twice its width (code-check round 4);
#      Not the logbook's 2%: bc5596 204-211 sit between 2,621 m (x10 to 2 m) and 2,438 m
#      (x10.764 to 30 m, 0.12%), and 2% lets both name a relation;
#   4. every in-band neighbour that names a relation names the same one, at one height, and
#      at least one does. A neighbour naming nothing is a new leg, not a contradiction;
#   5. a logbook that named a factor for these frames named this one. A logbook that names
#      none vetoes nothing — it is evidence for no repair, #54's included;
#   6. spacing under the sibling's height inside the window, as for the logbook.
# The height shipped is the sibling's catalogued height.

frames$scale_n <- suppressWarnings(as.numeric(sub("^1:", "", frames$scale)))
cat_key <- key4(frames$film_roll, frames$flying_height, frames$focal_length, frames$scale_n)
cols_lt <- c("film_roll", "flying_height", "focal_length", "scale_n", "frame_number", "elev",
             "base", "f_m", "nominal_agl")
lt_all <- rbind(lower_v$frames[, cols_lt], upper_v$frames[, cols_lt])
lt_key <- key4(lt_all$film_roll, lt_all$flying_height, lt_all$focal_length, lt_all$scale_n)
digits <- function(x) formatC(x, format = "d", big.mark = "")

# The relation `h` stands in to sibling height `sib`, named as the factor that takes the
# catalogue to the truth (the table's `factor`), or NA. Heights are whole metres.
relation <- function(h, sib, tail) {
  exact <- function(big, small, k) {
    r <- big - k * small
    r >= -(1 + k / 2) && r <= k + 1 / 2
  }
  hd <- digits(h)
  sd <- digits(sib)
  if (tail == "upper") {
    named <- c(x10 = exact(h, sib, 10), xK = exact(h, sib, K),
               digit = nchar(hd) == nchar(sd) + 1 && substring(hd, 2) == sd)
  } else {
    named <- c(d10 = exact(sib, h, 10), d100 = exact(sib, h, 100),
               digit = nchar(sd) == nchar(hd) + 1 && substring(sd, 2) == hd)
  }
  names(named)[named]
}
rel_factor <- function(rel, h, sib) {
  switch(rel, x10 = 1 / 10, xK = 1 / K, d10 = 10, d100 = 100, digit = round(sib / h, 6))
}

sibling <- function(i) {
  out <- list(ok = FALSE, reason = NA_character_, factor = NA_real_, height = NA_real_,
              rel = NA_character_, frame = NA_real_, p = NA_real_, r = NA_real_)
  k <- key4(v$film_roll[i], v$flying_height[i], v$focal_length[i], v$scale_n[i])
  own <- frames[cat_key == k, ]
  d <- lt_all[lt_key == k, ]
  nb <- frames[frames$film_roll == v$film_roll[i] &
                 frames$focal_length == v$focal_length[i] &
                 frames$scale_n %in% v$scale_n[i] &
                 frames$flying_height != v$flying_height[i] &
                 frames$frame_number %in% c(own$frame_number - 1, own$frame_number + 1), ]
  if (!nrow(nb)) return(modifyList(out, list(reason = "no adjacent frame at another height")))
  nominal <- v$scale_n[i] * v$focal_length[i] / 1000
  nb <- nb[in_band((nb$flying_height - median(d$elev)) / nominal), ]
  if (!nrow(nb)) return(modifyList(out, list(reason = "no adjacent frame in band")))
  rels <- lapply(nb$flying_height, function(sib) relation(v$flying_height[i], sib, v$tail[i]))
  naming <- lengths(rels) > 0
  if (!any(naming)) {
    return(modifyList(out, list(reason = "no adjacent frame in an exact named relation")))
  }
  named <- unlist(rels[naming])
  sib_h <- unique(nb$flying_height[naming])
  if (any(lengths(rels) > 1) || length(unique(named)) > 1 || length(sib_h) > 1) {
    return(modifyList(out, list(reason = "adjacent frames name different relations")))
  }
  if (named[1] == "xK") {
    return(modifyList(out, list(reason = "adjacent frames confirm #54's 10.764")))
  }
  f <- rel_factor(named[1], v$flying_height[i], sib_h)
  if (is.finite(v$log_factor[i]) && abs(v$log_factor[i] - f) > 1e-9) {
    return(modifyList(out, list(reason = "logbook names a different factor")))
  }
  base_ok <- is.finite(d$base)
  p <- NA_real_
  if (any(base_ok)) {
    p <- median(1 - d$base[base_ok] / (FORMAT_M * (sib_h - d$elev[base_ok]) / d$f_m[base_ok]))
  }
  out <- modifyList(out, list(factor = f, height = sib_h, rel = named[1],
                              frame = min(nb$frame_number[naming]), p = p,
                              r = median((sib_h - d$elev) / d$nominal_agl)))
  if (!any(base_ok)) return(modifyList(out, list(reason = "no adjacent frames to measure spacing on")))
  if (!fits(p)) return(modifyList(out, list(reason = "spacing rejects the sibling's height")))
  modifyList(out, list(ok = TRUE))
}

v$log_factor <- v$factor
v$witness <- ifelse(v$accept, "logbook", NA_character_)
v$sibling_frame <- NA_real_
v$sibling_reason <- NA_character_
v$sibling_rel <- NA_character_
for (i in which(!v$accept)) {
  # A near_upper or terrain roll-height's height is not what is in dispute — its scale is — so there is
  # no relation between heights for a neighbour to name.
  if (v$tail[i] %in% c("near_upper", "terrain")) {
    v$sibling_reason[i] <- "not applied: the scale is disputed, not the height"
    next
  }
  sb <- sibling(i)
  v$sibling_reason[i] <- sb$reason
  if (!sb$ok) next
  v$accept[i] <- TRUE
  v$witness[i] <- "sibling"
  v$reason[i] <- NA_character_
  v$factor[i] <- sb$factor
  v$height_m[i] <- sb$height
  v$sibling_frame[i] <- sb$frame
  v$sibling_rel[i] <- sb$rel
  v$log_ft[i] <- NA_real_
  v$n_agree[i] <- NA_integer_
  v$p_corrected[i] <- sb$p
  v$r_corrected[i] <- sb$r
}
sib <- v[which(v$witness == "sibling"), ]
message(sprintf("\n== sibling witness: %d roll-heights settled (%d frames) of %d the logbook left ==",
                nrow(sib), sum(sib$n), sum(!is.na(v$sibling_reason)) + nrow(sib)))
print(sib[, c("tail", "film_roll", "flying_height", "focal_length", "scale_n", "n",
              "sibling_rel", "sibling_frame", "height_m", "p_corrected", "r_corrected")],
      row.names = FALSE)
print(table(v$tail, v$sibling_reason))
print(tapply(v$n, list(v$tail, v$sibling_reason), sum))

# Controls: the two cases fly#74 was opened on must return what their neighbours say, and
# bc5596's other neighbour (2,438 m, frame 212, which 10.764 reaches to 0.12%) must name
# nothing under the rounding tolerance.
ctl_sib <- function(roll, h) v[v$film_roll == roll & v$flying_height == h, ]
c1 <- ctl_sib("bc5596", 26212)
c2 <- ctl_sib("bcb98013", 97924)
c1_ok <- nrow(c1) == 1 && identical(c1$witness, "sibling") && c1$height_m == 2621 &&
  c1$sibling_frame == 203 && isTRUE(all.equal(c1$factor, 0.1)) &&
  length(relation(26212, 2438, "upper")) == 0
if (!c1_ok) {
  stop("sibling control bc5596 does not settle at x10 from frame 203")
}
c2_ok <- nrow(c2) == 1 && identical(c2$witness, "sibling") && c2$height_m == 7924 &&
  identical(c2$sibling_rel, "digit")
if (!c2_ok) {
  stop("sibling control bcb98013 does not settle at its neighbours' 7,924 m")
}

# An excluded slipped roll-height is not refused: #54's repair still sizes it. Say so, so
# the table is not read as a list of frames drawn at nominal scale.
up <- v$tail == "upper" & !v$accept & v$reason != "logbook confirms #54's 10.764"
v$reason[up] <- paste0(v$reason[up], "; #54's 10.764 still applies")
# Likewise a near_upper or terrain roll-height left out is drawn at nominal scale, as before.
nu <- v$tail %in% c("near_upper", "terrain") & !v$accept & !grepl("nominal scale", v$reason, fixed = TRUE)
v$reason[nu] <- paste0(v$reason[nu], "; nominal scale still applies")
v$cause <- dplyr::case_when(
  !v$accept ~ NA_character_,
  is_f(1) ~ "scale_wrong",
  is_f(10) ~ "height_digit_dropped",
  is_f(100) ~ "height_two_digits_dropped",
  is_f(1 / 10) ~ "height_decimal_dropped",
  v$sibling_rel %in% "digit" & v$tail == "upper" ~ "height_leading_digit_added",
  v$sibling_rel %in% "digit" & v$tail == "lower" ~ "height_leading_digit_dropped"
)
stopifnot(!anyNA(v$cause[v$accept]))

rolls_out <- data.frame(
  tail = v$tail,
  film_roll = v$film_roll, flying_height = v$flying_height, focal_length = v$focal_length,
  scale_n = v$scale_n, factor = v$factor, cause = v$cause, witness = v$witness,
  logbook_ft = v$log_ft, sibling_frame = v$sibling_frame, height_m = v$height_m,
  frames_measured = v$n, frames_logbook = v$n_agree,
  overlap_corrected = round(v$p_corrected, 3), r_corrected = round(v$r_corrected, 3)
)[v$accept, ]
rolls_out <- rolls_out[order(rolls_out$tail, rolls_out$film_roll, rolls_out$flying_height), ]
excluded_out <- data.frame(
  tail = v$tail,
  film_roll = v$film_roll, flying_height = v$flying_height, focal_length = v$focal_length,
  scale_n = v$scale_n, frames_measured = v$n, reason = v$reason,
  sibling_reason = v$sibling_reason
)[!v$accept, ]
excluded_out <- excluded_out[order(excluded_out$tail, excluded_out$film_roll,
                                   excluded_out$flying_height), ]
stopifnot(nrow(rolls_out) + nrow(excluded_out) == nrow(v),
          sum(rolls_out$frames_measured) + sum(excluded_out$frames_measured) ==
            nrow(lower) + nrow(upper) + nrow(near) + nrow(terr))

message(sprintf("\n== verdict: %d roll-heights corrected (%d frames), %d excluded (%d frames) ==",
                nrow(rolls_out), sum(rolls_out$frames_measured),
                nrow(excluded_out), sum(excluded_out$frames_measured)))
print(table(rolls_out$tail, rolls_out$cause))
print(tapply(rolls_out$frames_measured, list(rolls_out$tail, rolls_out$cause), sum))
print(table(excluded_out$tail, excluded_out$reason))
print(tapply(excluded_out$frames_measured, list(excluded_out$tail, excluded_out$reason), sum))
print(rolls_out, row.names = FALSE)

# The key reaches only the roll-heights it was measured on: count what each row would touch
# across the whole catalogue, on the same four fields `fly_footprint()` matches. near_upper,
# measured on a sample, reaches more than it measured; so does terrain, whose roll-heights
# also hold frames in band, which `fly_footprint()` never hands to the table.
key_all <- key4(frames$film_roll, frames$flying_height, frames$focal_length,
                suppressWarnings(as.numeric(sub("^1:", "", frames$scale))))
reach <- vapply(seq_len(nrow(rolls_out)), function(i) {
  sum(key_all == key4(rolls_out$film_roll[i], rolls_out$flying_height[i],
                      rolls_out$focal_length[i], rolls_out$scale_n[i]))
}, integer(1))
stopifnot(all(reach >= rolls_out$frames_measured))
message(sprintf("frames the corrections reach in the whole catalogue: %d (measured: %d)",
                sum(reach), sum(rolls_out$frames_measured)))
print(rbind(reach = tapply(reach, rolls_out$tail, sum),
            measured = tapply(rolls_out$frames_measured, rolls_out$tail, sum)))
# The tails cannot share a key: a height cannot be both under and over the band, a
# near_upper roll-height (2 < r above sea level <= 3) cannot be a slipped one (> 3), and a
# terrain one is inside the band above sea level, where every other tail is outside it.
stopifnot(!anyDuplicated(key4(v$film_roll, v$flying_height, v$focal_length, v$scale_n)))

write.csv(rolls_out, "inst/extdata/flying_height_rolls.csv", row.names = FALSE, na = "")
write.csv(excluded_out, "inst/extdata/flying_height_rolls_excluded.csv", row.names = FALSE,
          na = "")

# ---------------------------------------------------------------------------
# Stage 6 — fly#95: the logbook, and the verdict on reading the height as above ground
# ---------------------------------------------------------------------------
#
# Per frame, through `settle()`'s own join and states. A read frame's logbook height `h_lb`
# (feet x 0.3048) is
#   catalogue      within 2% of the catalogued height: the crew's figure is the catalogue's
#   ground_plus    the median over the roll-height's frames read at that height of
#                  (h_lb - elev) is within 10% of the catalogued height: the crew flew
#                  the catalogued height ABOVE the ground MRDEM puts under the frames
#   ambiguous      both: ground near sea level, where the two readings coincide
#   ground_header  `catalogue` under a TRUE HEIGHT header that names the ground, not M.S.L.
#   other          none of these
# A roll-height is tabled only where spacing `supports`, the logbook reads at least half its
# frames with at least 90% of those `ground_plus` or `ground_header`, no legible logbook lens
# contradicts the catalogue's, and no frame of the key falls outside the two censuses (in
# band as catalogued, or with no terrain under it). The reason is the first that fires.
agl_lt <- settle(agl, named = 1, tail = "above_ground")$frames
ground_header <- function(h) {
  grepl("ground|A\\.?G\\.?L|terrain|clearance", h, ignore.case = TRUE) &
    !grepl("M\\.?S\\.?L", h, ignore.case = TRUE)
}
agl_lt$hdr_ground <- vapply(seq_len(nrow(agl_lt)), function(i) {
  if (agl_lt$log_state[i] != "read") return(FALSE)
  cover <- which(logs$film_roll == agl_lt$film_roll[i] & !is.na(logs$frame_from) &
                   agl_lt$frame_number[i] >= logs$frame_from &
                   agl_lt$frame_number[i] <= logs$frame_to & is.finite(logs$log_ft))
  length(cover) > 0 && all(ground_header(logs$height_header[cover]))
}, logical(1))
agl_lt$key <- key4(agl_lt$film_roll, agl_lt$flying_height, agl_lt$focal_length, agl_lt$scale_n)
rd <- agl_lt$log_state == "read"
agl_lt$h_lb <- agl_lt$log_ft * FT
agl_lt$rel_catalogue <- rd & abs(agl_lt$h_lb / agl_lt$flying_height - 1) <= 0.02
gp <- tapply(agl_lt$h_lb[rd] - agl_lt$elev[rd], paste(agl_lt$key, agl_lt$log_ft)[rd], median)
# `tapply()` returns a 1-d array, which `case_when()` refuses, so it is flattened here.
agl_lt$rel_ground_plus <- rd &
  abs(as.vector(gp[paste(agl_lt$key, agl_lt$log_ft)]) / agl_lt$flying_height - 1) <= 0.10
agl_lt$relation <- dplyr::case_when(
  !rd ~ NA_character_,
  agl_lt$rel_catalogue & agl_lt$hdr_ground ~ "ground_header",
  agl_lt$rel_catalogue & agl_lt$rel_ground_plus ~ "ambiguous",
  agl_lt$rel_catalogue ~ "catalogue",
  agl_lt$rel_ground_plus ~ "ground_plus",
  TRUE ~ "other"
)
key_cat <- table(key4(frames$film_roll, frames$flying_height, frames$focal_length,
                      suppressWarnings(as.numeric(sub("^1:", "", frames$scale)))))
agl_l <- do.call(rbind, lapply(split(agl_lt, agl_lt$key), function(d) {
  rel <- d$relation[!is.na(d$relation)]
  data.frame(key = d$key[1], n_logbook = length(rel),
             n_catalogue = sum(rel == "catalogue"), n_ground_plus = sum(rel == "ground_plus"),
             n_ambiguous = sum(rel == "ambiguous"), n_ground_header = sum(rel == "ground_header"),
             n_other = sum(rel == "other"),
             n_unread = sum(d$log_state %in% c("conflict", "uninterpreted")),
             n_unspanned = sum(d$log_state == "unspanned"),
             n_focal_conflict = sum(is.finite(d$log_focal) & !d$focal_agrees),
             logbook_ft = paste(sort(unique(d$log_ft[!is.na(d$relation)])), collapse = "/"))
}))
av <- merge(agl_s, agl_l, by = "key")
stopifnot(nrow(av) == nrow(agl_s))
av$n_outside <- as.integer(key_cat[av$key]) - av$n
stopifnot(all(av$n_outside >= 0))
av$covered <- av$n_logbook / av$n
av$agreeing <- ifelse(av$n_logbook > 0, (av$n_ground_plus + av$n_ground_header) / av$n_logbook, 0)
av$tabled <- av$spacing == "supports" & av$covered >= 0.5 & av$agreeing >= 0.9 &
  av$n_focal_conflict == 0 & av$n_outside == 0
av$reason <- dplyr::case_when(
  av$tabled ~ NA_character_,
  av$spacing == "refutes" ~ "spacing rejects the catalogued height read as above ground",
  av$spacing == "undecided" ~ "spacing fits both the catalogued height read as above ground and nominal scale",
  av$spacing == "no_base" ~ "no adjacent frames to measure spacing on",
  av$n_logbook == 0 & av$n_unread > 0 ~ "logbook height or frame range not read",
  av$n_logbook == 0 & av$n_unspanned > 0 ~ "transcribed logbook rows reach none of these frames",
  av$n_logbook == 0 ~ "no logbook page covers these frames",
  av$covered < 0.5 ~ "logbook covers under half the frames",
  av$agreeing < 0.9 ~ "logbook does not put the ground under the catalogued height",
  av$n_focal_conflict > 0 ~ "logbook names a different lens",
  TRUE ~ "frames on this roll-height are in band as catalogued, or have no terrain under them"
)
av <- av[order(av$film_roll, av$flying_height, av$focal_length, av$scale_n), ]
message(sprintf("\n== fly#95 above ground: %d roll-heights, %d tabled ==", nrow(av), sum(av$tabled)))
print(table(av$spacing, av$reason, useNA = "ifany"))
print(av[av$n_logbook > 0 | av$n_nonpositive > 0 | av$spacing == "supports",
         c("film_roll", "flying_height", "focal_length", "scale_n", "n", "n_nonpositive", "ratio_asl",
           "p_agl", "p_nominal", "spacing", "n_logbook", "n_catalogue", "n_ground_plus", "n_ambiguous",
           "n_other", "logbook_ft")], row.names = FALSE)
und <- av$spacing == "undecided"
message(sprintf("undecided: %d roll-heights (%d frames); |ratio_asl - 1| at most %.3f, median %.3f",
                sum(und), sum(av$n[und]), max(abs(av$ratio_asl[und] - 1)),
                median(abs(av$ratio_asl[und] - 1))))
# Pre-registered: how a tabled row is encoded is a schema decision that goes back to the user.
if (any(av$tabled)) {
  stop(sum(av$tabled), " roll-heights table as above ground; their encoding is not decided, so ",
       "nothing is written")
}
agl_out <- data.frame(
  film_roll = av$film_roll, flying_height = av$flying_height, focal_length = av$focal_length,
  scale_n = av$scale_n, photo_year = av$photo_year, frames = av$n,
  frames_nonpositive = av$n_nonpositive, frames_outside = av$n_outside,
  ratio_asl = round(av$ratio_asl, 3), frames_base = av$n_base,
  overlap_agl = round(av$p_agl, 3), overlap_nominal = round(av$p_nominal, 3), spacing = av$spacing,
  frames_logbook = av$n_logbook, frames_catalogue = av$n_catalogue,
  frames_ground_plus = av$n_ground_plus, frames_ambiguous = av$n_ambiguous,
  frames_ground_header = av$n_ground_header, frames_other = av$n_other,
  frames_focal_conflict = av$n_focal_conflict, logbook_ft = av$logbook_ft,
  tabled = av$tabled, reason = av$reason
)
write.csv(agl_out, "inst/extdata/flying_height_above_ground.csv", row.names = FALSE, na = "")
