# height_measure-image_overlap.R — what did the frames under the terrain cover? (fly#97)
#
# fly#95 left nine roll-heights, 157 frames under terrain at or above the catalogued aircraft
# height (`r <= 0`), where adjacent-frame spacing rejects both nominal scale and the catalogued
# height read as above ground. Spacing asks whether a reading puts the catalogue's centroid step at
# the ~60% forward overlap a flight is designed to; it cannot say whether the step or the reading
# is the thing that is wrong, and on 1970s rolls the centroids are interpolated evenly along each
# line (fly#82), so the step is the weak half.
#
# This script measures the overlap the photos actually have. Two thumbnails adjacent by number
# share ground, and the image shift between them is `(1 - overlap)` of the frame side, whatever
# the scale, the height or the centroids say: no catalogue field enters it. That replaces
# spacing's designed-overlap premise with a measurement, and the logbook — read blind, before any
# image of the nine keys was matched — says whether the crew's height was above sea level.
#
# The rule — every gate, tolerance and verdict — was fixed in fly#97's planning findings
# ("Decision rule"), before any thumbnail was matched. Read it before changing anything here.
#
# Matching is fly#82's: `patch_shifts()` and its acceptance gate (>= 8 confirming 128 px patches
# at step 64 for the seed, then >= 20 at step 32, shift = their median), pulled from
# `dem_measure-photo_parallax.R` with `fns_from()`. Only the seed search differs. fly#82's
# `global_shift()` takes seeds from a circular phase correlation over the 1/4-resolution
# interior, where a shift beyond half the window (~575 px, overlap under ~0.54) wraps to a
# shorter vector of the other sign, and it gates them on a prediction from centroid spacing —
# the quantity under test. Here seeds come from a zero-padded, masked normalised
# cross-correlation, which neither wraps nor reads the centroids.
#
# Everything is public: the BC Data Catalogue's airphoto centroids, thumbnails and logbooks.
#
# Usage, from the repo root, after `height_measure-terrain_tail.R` and
# `height_calibrate-lower_tail_rolls.R` (whose `flying_height_above_ground.csv` carries the
# logbook join this script reads):
#   Rscript data-raw/height_measure-image_overlap.R
#
#   Stage 0  inputs: censuses, centroid cache, the spacing window
#   Stage 1  controls: synthetic known shifts, a negative control that sets tau, bc85054 162/163
#   Stage 2  the nine keys: every pair (n, n+1) on each key
#   Stage 3  the verdicts; write `inst/extdata/flying_height_image_overlap_*.csv`
#
#   FLY_IMGOVL_SMOKE=1 runs two synthetic thumbnails and three control keys into a separate
#   measurement cache (thumbnails and roll metadata are shared) and writes nothing
#   FLY_IMGOVL_STOP=<n> stops after stage n
#   FLY_IMGOVL_WORKERS=<n> PSOCK workers (default 4); forks are not used (CLAUDE.md)

pkgload::load_all(quiet = TRUE)
suppressMessages({
  library(sf)
  library(terra)
})
sf::sf_use_s2(FALSE)
terra::terraOptions(memfrac = 0.05, memmax = 1, progress = 0)

SMOKE      <- nzchar(Sys.getenv("FLY_IMGOVL_SMOKE"))
STOP_AFTER <- as.integer(Sys.getenv("FLY_IMGOVL_STOP", "99"))
WORKERS    <- as.integer(Sys.getenv("FLY_IMGOVL_WORKERS", "4"))
ALG        <- "o1"                  # the algorithm tag every measurement cache carries
CACHE      <- if (SMOKE) "data-raw/.cache/image_overlap_smoke" else "data-raw/.cache/image_overlap"
PAIRS_DIR  <- file.path(CACHE, paste0("pairs_", ALG))
THUMBS     <- "data-raw/.cache/photo_parallax/thumbs"       # shared with fly#82
ROLLS      <- "data-raw/.cache/photo_parallax/rolls"
CENTROIDS  <- "data-raw/.cache/centroids"
SWEEP      <- "inst/extdata/flying_height_sweep.csv"
STRIPS     <- "data-raw/flying_height_logbook_strips.csv"
REPO       <- normalizePath(".")
FORMAT_M   <- 9 * 0.0254
SEED       <- 9701

# The nine roll-heights fly#95 left (`flying_height_above_ground.csv`, spacing rejects both).
KEYS9 <- data.frame(
  film_roll     = c("bc5715", "bc77026", "bc77070", "bc77072", "bc77072", "bc77087", "bc7718",
                    "bc80117", "bcc325"),
  flying_height = c(732, 2042, 1158, 1829, 1981, 1158, 1524, 1372, 396),
  focal_length  = c(153, 305, 153, 153, 153, 153, 305, 153, 153),
  scale_n       = c(4800, 6000, 5000, 10000, 10000, 5000, 5000, 8000, 2000)
)
POSITIVE <- c(film_roll = "bc85054", frame = "162")   # images ~1,360 m against 2,353 m (fly#82)

stopifnot(dir.exists(CENTROIDS), file.exists(SWEEP))
dir.create(PAIRS_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(THUMBS, recursive = TRUE, showWarnings = FALSE)
dir.create(ROLLS, recursive = TRUE, showWarnings = FALSE)

# Helpers from closed measurements, evaluated rather than copied: a second copy would drift.
# `fns_from()` itself is the one function taken by hand, through the same parse.
local({
  for (e in parse("data-raw/dem_measure-canopy_height.R", keep.source = FALSE)) {
    if (is.call(e) && identical(e[[1]], as.name("<-")) && identical(e[[2]], as.name("fns_from"))) {
      eval(e, envir = globalenv())
    }
  }
})
fns_from("data-raw/dem_measure-canopy_height.R", c("write_if_changed", "save_atomic", "pub", "%||%"))
fns_from("data-raw/dem_measure-photo_parallax.R",
         c("read_gray", "hann2", "down", "pc_surface", "phase_corr", "patch_shifts",
           "roll_meta", "fetch_pair", "write_pgm", "jpeg85"))
# fly#82's two matching constants, read from its source so the gate cannot drift from it.
local({
  for (e in parse("data-raw/dem_measure-photo_parallax.R", keep.source = FALSE)) {
    if (is.call(e) && identical(e[[1]], as.name("<-")) && is.name(e[[2]]) &&
        as.character(e[[2]]) %in% c("MARGIN", "PEAK") && is.numeric(e[[3]])) {
      eval(e, envir = globalenv())
    }
  }
})
stopifnot(exists("MARGIN"), exists("PEAK"))

# ---------------------------------------------------------------------------
# The instrument
# ---------------------------------------------------------------------------

# Correlation of every overlap of `a` and `b` (same size), zero-padded so nothing wraps:
# entry (u, v) compares a[i, j] with b[i + u, j + v]. Masked and normalised per shift
# (Padfield 2012), so a small overlap is not penalised for its size, only refused under
# `min_frac` of the image.
masked_ncc <- function(a, b, min_frac = 0.10) {
  nr <- nrow(a)
  nc <- ncol(a)
  pr <- 2 * nr
  pc <- 2 * nc
  pad <- function(m) {
    out <- matrix(0, pr, pc)
    out[seq_len(nr), seq_len(nc)] <- m
    out
  }
  a <- a - mean(a)
  b <- b - mean(b)
  fa <- stats::fft(pad(a))
  fa2 <- stats::fft(pad(a^2))
  fma <- stats::fft(pad(matrix(1, nr, nc)))
  fb <- stats::fft(pad(b))
  fb2 <- stats::fft(pad(b^2))
  fmb <- fma
  xc <- function(fx, fy) Re(stats::fft(Conj(fx) * fy, inverse = TRUE)) / (pr * pc)
  n   <- round(xc(fma, fmb))
  sa  <- xc(fa, fmb)
  sb  <- xc(fma, fb)
  sab <- xc(fa, fb)
  sa2 <- xc(fa2, fmb)
  sb2 <- xc(fma, fb2)
  num <- sab - sa * sb / pmax(n, 1)
  den <- sqrt(pmax(sa2 - sa^2 / pmax(n, 1), 0) * pmax(sb2 - sb^2 / pmax(n, 1), 0))
  r <- num / pmax(den, 1e-9)
  r[n < min_frac * nr * nc] <- NA
  du <- 0:(pr - 1)
  du[du >= nr] <- du[du >= nr] - pr
  dv <- 0:(pc - 1)
  dv[dv >= nc] <- dv[dv >= nc] - pc
  list(r = r, du = du, dv = dv)
}

# The ten highest local maxima (5 x 5) of the masked correlation, as full-resolution seeds.
ncc_seeds <- function(a, b, k = 4, n_cand = 10) {
  n <- nrow(a)
  m <- ncol(a)
  ia <- down(a[(MARGIN + 1):(n - MARGIN), (MARGIN + 1):(m - MARGIN)], k)
  ib <- down(b[(MARGIN + 1):(n - MARGIN), (MARGIN + 1):(m - MARGIN)], k)
  s <- masked_ncc(ia, ib)
  r <- s$r
  r0 <- r
  r0[is.na(r0)] <- -Inf
  nr <- nrow(r)
  nc <- ncol(r)
  sh <- function(x, i, j) x[((seq_len(nr) - 1 + i) %% nr) + 1, ((seq_len(nc) - 1 + j) %% nc) + 1]
  mx <- r0
  for (i in -2:2) for (j in -2:2) if (i || j) mx <- pmax(mx, sh(r0, i, j))
  cand <- which(is.finite(r0) & r0 == mx)
  cand <- cand[order(r0[cand], decreasing = TRUE)][seq_len(min(n_cand, length(cand)))]
  cbind(row = k * s$du[(cand - 1) %% nr + 1], col = k * s$dv[(cand - 1) %/% nr + 1],
        r = r0[cand])
}

# fly#82's acceptance gate applied to these seeds: the seed most 128 px patches confirm at step 64
# (at least 8) wins, then patches at step 32 seeded from it (at least 20 confirming) give the shift
# as their median. Same constants, same order, as `global_shift()`.
measure_shift <- function(a, b) {
  seeds <- ncc_seeds(a, b)
  best <- NULL
  best_n <- 0
  for (k in seq_len(nrow(seeds))) {
    s0 <- c(row = unname(seeds[k, "row"]), col = unname(seeds[k, "col"]))
    p1 <- patch_shifts(a, b, s0, pass2 = FALSE, step = 64)
    nk <- if (is.null(p1)) 0 else sum(p1$pk >= PEAK, na.rm = TRUE)
    if (nk > best_n) {
      best_n <- nk
      best <- s0
    }
  }
  fail <- c(row = NA, col = NA, peak = 0, n1 = best_n, n_seeds = nrow(seeds))
  if (best_n < 8) return(fail)
  p1 <- patch_shifts(a, b, best, pass2 = FALSE)
  g <- p1[is.finite(p1$dr) & p1$pk >= PEAK, ]
  if (nrow(g) < 20) return(fail)
  c(row = stats::median(g$dr), col = stats::median(g$dc), peak = stats::median(g$pk),
    n1 = nrow(g), n_seeds = nrow(seeds))
}

# Forward overlap from a shift: the side is the thumbnail's along the larger component.
p_of <- function(dr, dc, nr, nc) {
  L <- ifelse(abs(dr) >= abs(dc), nr, nc)
  1 - sqrt(dr^2 + dc^2) / L
}

# Two thumbnails cropped to their common size (adjacent thumbnails can differ by a row, fly#82).
common <- function(a, b) {
  nr <- min(nrow(a), nrow(b))
  nc <- min(ncol(a), ncol(b))
  list(a = a[seq_len(nr), seq_len(nc)], b = b[seq_len(nr), seq_len(nc)])
}

# A pair is A = (film_roll, frame) against B = (roll_b, frame_b). For an adjacent pair B is frame + 1
# of the same roll; for the false-match control it is another roll's frame. Cached per pair under
# this id. Transient fetch failures are not cached, so a second run retries them.
pair_id <- function(film_roll, frame, roll_b, frame_b) {
  ifelse(film_roll == roll_b & frame_b == frame + 1, sprintf("%s_%s", film_roll, frame),
         sprintf("x_%s_%s_%s_%s", film_roll, frame, roll_b, frame_b))
}
# A frame's thumbnail through `fetch_pair()`, which fetches a frame and the next: frame n is
# dest[1] of pair n, or dest[2] of pair n - 1 when n is the last frame of a pair already drawn.
thumb_of <- function(film_roll, frame, second = FALSE) {
  fp <- fetch_pair(film_roll, if (second) frame - 1 else frame)
  if (fp$status != "ok") return(fp)
  list(status = "ok", path = fp$dest[if (second) 2 else 1])
}
measure_pair <- function(film_roll, frame, roll_b = film_roll, frame_b = frame + 1) {
  f <- file.path(PAIRS_DIR, paste0(pair_id(film_roll, frame, roll_b, frame_b), ".rds"))
  if (file.exists(f)) return(readRDS(f))
  get <- function(r, n, second) {
    tryCatch(thumb_of(r, n, second), error = function(e) {
      list(status = paste("transient:", conditionMessage(e)))
    })
  }
  ta <- get(film_roll, frame, FALSE)
  tb <- if (ta$status == "ok") get(roll_b, frame_b, TRUE) else ta
  st <- c(ta$status, tb$status)
  if (any(grepl("^transient", st))) return(list(status = st[grepl("^transient", st)][1]))
  out <- if (any(st != "ok")) {
    list(status = "no_thumbnail", why = st[st != "ok"][1])
  } else {
    ab <- common(read_gray(ta$path), read_gray(tb$path))
    s <- tryCatch(measure_shift(ab$a, ab$b), error = function(e) e)
    if (inherits(s, "error")) {
      list(status = "failed", why = conditionMessage(s))
    } else {
      list(status = if (is.finite(s[["row"]])) "matched" else "no_match",
           dr = s[["row"]], dc = s[["col"]], peak = s[["peak"]], n_patches = s[["n1"]],
           nr = nrow(ab$a), nc = ncol(ab$a))
    }
  }
  out$film_roll <- film_roll
  out$frame <- frame
  save_atomic(out, f)
  out
}

with_b <- function(todo) {
  if (is.null(todo$roll_b)) todo$roll_b <- todo$film_roll
  if (is.null(todo$frame_b)) todo$frame_b <- todo$frame + 1
  todo
}
run_pairs <- function(todo) {
  todo <- with_b(todo)
  one <- function(i) {
    m <- measure_pair(todo$film_roll[i], todo$frame[i], todo$roll_b[i], todo$frame_b[i])
    m$status
  }
  if (WORKERS > 1 && nrow(todo) > 1) {
    cl <- parallel::makePSOCKcluster(WORKERS)
    on.exit(parallel::stopCluster(cl))
    parallel::clusterExport(cl, c("read_gray", "hann2", "down", "pc_surface", "phase_corr",
                                  "patch_shifts", "roll_meta", "fetch_pair", "masked_ncc",
                                  "ncc_seeds", "measure_shift", "common", "measure_pair",
                                  "pair_id", "thumb_of", "save_atomic", "MARGIN", "PEAK",
                                  "THUMBS", "ROLLS", "PAIRS_DIR", "REPO", "todo"),
                            envir = environment())
    parallel::clusterEvalQ(cl, {
      setwd(REPO)
      NULL
    })
    unlist(parallel::parLapplyLB(cl, seq_len(nrow(todo)), one))
  } else {
    vapply(seq_len(nrow(todo)), one, character(1))
  }
}

# Every pair in `todo` measured, or stop: a sample with holes is not reported on, and two or
# more failures with one message are a defect in the code or the service, not a measurement.
# A matched shift implying over 0.95 overlap is fixed pattern (data panel, fiducials), not
# ground, and counts as no match everywhere (Amendment A2).
FIXED_PATTERN <- 0.95
read_pairs <- function(todo) {
  todo <- with_b(todo)
  f <- file.path(PAIRS_DIR, paste0(pair_id(todo$film_roll, todo$frame, todo$roll_b, todo$frame_b),
                                   ".rds"))
  if (any(!file.exists(f))) {
    stop(sum(!file.exists(f)), " pairs not measured (transient failures are retried); run again")
  }
  m <- lapply(f, readRDS)
  st <- vapply(m, `[[`, character(1), "status")
  why <- vapply(m, function(x) x$why %||% "", character(1))
  if (any(st == "failed")) {
    tab <- table(why[st == "failed"])
    if (max(tab) >= 2) stop("pairs failing with one message: ", names(tab)[which.max(tab)])
  }
  num <- function(x, k) if (is.null(x[[k]])) NA_real_ else as.numeric(x[[k]])
  out <- todo
  out$status <- st
  out$dr <- vapply(m, num, numeric(1), "dr")
  out$dc <- vapply(m, num, numeric(1), "dc")
  out$n_patches <- vapply(m, num, numeric(1), "n_patches")
  out$nr <- vapply(m, num, numeric(1), "nr")
  out$nc <- vapply(m, num, numeric(1), "nc")
  p <- ifelse(out$status == "matched", p_of(out$dr, out$dc, out$nr, out$nc), NA_real_)
  out$status[out$status == "matched" & p > FIXED_PATTERN] <- "fixed_pattern"
  out$p_img <- ifelse(out$status == "matched", p, NA_real_)
  out
}

# The log of the step error the images imply against a reading's overlap, the unit every W1
# comparison is made in (Amendment A2): 0 where the images and the catalogue step agree.
D_of <- function(p_img, p_reading) log((1 - p_img) / (1 - p_reading))

# Per key: pairs, how many matched, and the medians over the matched non-break ones.
key_summary <- function(m) {
  do.call(rbind, lapply(split(m, m$key), function(d) {
    use <- d$status == "matched" & !d$line_break
    data.frame(key = d$key[1], film_roll = d$film_roll[1], flying_height = d$flying_height[1],
               focal_length = d$focal_length[1], scale_n = d$scale_n[1],
               pairs = nrow(d), pairs_break = sum(d$line_break),
               pairs_matched = sum(d$status == "matched"), pairs_used = sum(use),
               p_img = if (any(use)) stats::median(d$p_img[use]) else NA_real_,
               p_nominal = if (any(use)) stats::median(d$p_nominal[use]) else NA_real_,
               p_agl = if (any(use)) stats::median(d$p_agl[use]) else NA_real_)
  }))
}

# ---------------------------------------------------------------------------
# Stage 0 — inputs
# ---------------------------------------------------------------------------

frames <- do.call(rbind, lapply(list.files(CENTROIDS, "\\.rds$", full.names = TRUE), readRDS))
frames <- frames[!is.na(frames$film_roll) & is.finite(frames$frame_number), ]
frames$scale_n <- suppressWarnings(as.numeric(sub("^1:", "", frames$scale)))
key4 <- function(r, h, f, s) {
  paste(r, format(h, scientific = FALSE, trim = TRUE), format(f, scientific = FALSE, trim = TRUE),
        format(s, scientific = FALSE, trim = TRUE))
}
frames$key <- key4(frames$film_roll, frames$flying_height, frames$focal_length, frames$scale_n)
# A (roll, frame) carried twice has no single position; it pairs with nothing.
rf <- paste(frames$film_roll, frames$frame_number)
frames <- frames[!rf %in% rf[duplicated(rf)], ]
pub("cache: %d frames on %d rolls", nrow(frames), length(unique(frames$film_roll)))

# Pairs of a key: n and n+1 both on it. `step` is the catalogue distance between their centroids;
# a step over 3x the key's median step is a line break, measured and kept out of every median.
key_pairs <- function(k) {
  d <- frames[frames$key == k, ]
  d <- d[order(d$frame_number), ]
  j <- match(d$frame_number + 1, d$frame_number)
  ok <- !is.na(j)
  if (!any(ok)) return(NULL)
  p <- data.frame(key = k, film_roll = d$film_roll[ok], frame = d$frame_number[ok],
                  frame_next = d$frame_number[j[ok]],
                  step = sqrt((d$x[j[ok]] - d$x[ok])^2 + (d$y[j[ok]] - d$y[ok])^2),
                  bearing = (atan2(d$x[j[ok]] - d$x[ok], d$y[j[ok]] - d$y[ok]) * 180 / pi) %% 360,
                  flying_height = d$flying_height[ok], focal_length = d$focal_length[ok],
                  scale_n = d$scale_n[ok])
  p$line_break <- p$step > 3 * stats::median(p$step)
  p$p_nominal <- 1 - p$step / (FORMAT_M * p$scale_n)
  p$p_agl <- 1 - p$step / (FORMAT_M * p$flying_height / (p$focal_length / 1000))
  p
}

# The window, recomputed as the generator computes it (random in-band sweep frames, overlap as
# reported, f1 air base), and held to the figure fly#95 published.
f1 <- frames[order(frames$film_roll, frames$frame_number), ]
nx <- match(paste(f1$film_roll, f1$frame_number + 1), paste(f1$film_roll, f1$frame_number))
pv <- match(paste(f1$film_roll, f1$frame_number - 1), paste(f1$film_roll, f1$frame_number))
f1$base <- suppressWarnings(pmin(sqrt((f1$x[nx] - f1$x)^2 + (f1$y[nx] - f1$y)^2),
                                 sqrt((f1$x[pv] - f1$x)^2 + (f1$y[pv] - f1$y)^2), na.rm = TRUE))
f1$base[!is.finite(f1$base) | f1$base == 0] <- NA_real_
sw <- read.csv(SWEEP)
sw$base <- f1$base[match(sw$airp_id, f1$airp_id)]
sw$f_m <- sw$focal_length / 1000
sw$r <- (sw$flying_height - sw$elev) / (sw$scale_n * sw$f_m)
band <- fly_height_ratio_band()
rnd <- sw[sw$set == "random" & is.finite(sw$r) & sw$r >= band[1] & sw$r <= band[2], ]
p_rep <- 1 - rnd$base / (FORMAT_M * (rnd$flying_height - rnd$elev) / rnd$f_m)
p_window <- unname(stats::quantile(p_rep, c(.025, .975), na.rm = TRUE))
pub("spacing window (fly#95): %.3f to %.3f", p_window[1], p_window[2])
stopifnot(abs(p_window[1] - 0.557) < 5e-4, abs(p_window[2] - 0.780) < 5e-4)

if (STOP_AFTER < 1) quit(save = "no")


# ---------------------------------------------------------------------------
# Stage 1 — controls
# ---------------------------------------------------------------------------

# Negative control: in-band random sweep frames, film, 1970-1985, 153 or 305 mm, grouped to their
# roll-height; keys whose median f1 spacing at nominal fits the window; 40 drawn, and on each up
# to 5 non-break pairs, consecutive by frame number from a seeded start.
cand <- rnd[rnd$photo_year >= 1970 & rnd$photo_year <= 1985 & rnd$focal_length %in% c(153, 305), ]
cand$key <- key4(cand$film_roll, cand$flying_height, cand$focal_length, cand$scale_n)
ck <- unique(cand$key)
k_nom <- vapply(ck, function(k) {
  d <- f1[f1$key == k, ]
  stats::median(1 - d$base / (FORMAT_M * d$scale_n), na.rm = TRUE)
}, numeric(1))
ck <- ck[is.finite(k_nom) & k_nom >= p_window[1] & k_nom <= p_window[2]]
ck <- setdiff(ck, frames$key[frames$film_roll %in% c(KEYS9$film_roll, POSITIVE[["film_roll"]])])
set.seed(SEED)
ck <- sort(ck)[sample.int(length(ck), min(if (SMOKE) 3L else 40L, length(ck)))]
consecutive <- function(p, n = 5) {
  start <- sample.int(nrow(p), 1)
  p[((start - 1 + 0:(min(n, nrow(p)) - 1)) %% nrow(p)) + 1, ]
}
neg <- do.call(rbind, lapply(seq_along(ck), function(i) {
  p <- key_pairs(ck[i])
  if (is.null(p)) return(NULL)
  p <- p[!p$line_break, ]
  if (!nrow(p)) return(NULL)
  consecutive(p)
}))
neg$set <- "negative"
pub("negative control: %d keys drawn, %d with pairs, %d pairs", length(ck),
    length(unique(neg$key)), nrow(neg))

# Written-overlap control (Amendment A2): strips whose logbook row writes a forward overlap. Pairs
# n, n+1 on one roll-height inside the range, up to 5 from a seeded start (drawn after the
# negative control, so its draw is unchanged). `bc77115`'s 30% is under the floor: reported only.
WRITTEN <- data.frame(
  film_roll = c("bc5598", "bc78065", "bc79027", "bc78153", "bc7454", "bc5561", "bc78016",
                "bc86103", "bcc162", "bc77115"),
  from      = c(1, 62, 190, 145, 1, 1, 11, 154, 1, 67),
  to        = c(25, 270, 204, 193, 123, 17, 31, 179, 110, 116),
  written   = c(0.80, 0.80, 0.80, 0.80, 0.80, 0.80, 0.80, 0.80, 0.65, 0.30),
  gated     = c(rep(TRUE, 9), FALSE)
)
wrt <- do.call(rbind, lapply(seq_len(nrow(WRITTEN)), function(i) {
  w <- WRITTEN[i, ]
  ks <- unique(frames$key[frames$film_roll == w$film_roll & frames$frame_number >= w$from &
                            frames$frame_number <= w$to])
  p <- do.call(rbind, lapply(sort(ks), key_pairs))
  if (is.null(p)) return(NULL)
  p <- p[p$frame >= w$from & p$frame_next <= w$to & !p$line_break, ]
  if (!nrow(p)) return(NULL)
  p <- p[order(p$frame), ]
  p <- consecutive(p)
  p$written <- w$written
  p$gated <- w$gated
  p
}))
wrt$set <- "written"
if (SMOKE) wrt <- wrt[wrt$film_roll %in% unique(wrt$film_roll)[1:2], ]

pos <- frames[frames$film_roll == POSITIVE[["film_roll"]], ]
pos_key <- pos$key[pos$frame_number == as.numeric(POSITIVE[["frame"]])]
stopifnot(length(pos_key) == 1)
posp <- key_pairs(pos_key)
posp <- posp[posp$frame == as.numeric(POSITIVE[["frame"]]), ]
stopifnot(nrow(posp) == 1)
posp$set <- "positive"

cols_pair <- c("film_roll", "frame")
invisible(run_pairs(rbind(neg[, cols_pair], wrt[, cols_pair], posp[, cols_pair])))
neg_m <- read_pairs(neg)
wrt_m <- read_pairs(wrt)
pos_m <- read_pairs(posp)

# False-match control (Amendment A2): frame n of one negative-control key's first pair against
# frame n + 1 of the next key's first pair — different rolls, no shared ground.
first <- neg[!duplicated(neg$key), ]
uno <- data.frame(film_roll = first$film_roll[-nrow(first)], frame = first$frame[-nrow(first)],
                  roll_b = first$film_roll[-1], frame_b = first$frame_next[-1])
uno <- uno[uno$film_roll != uno$roll_b, ]
invisible(run_pairs(uno))
uno_m <- read_pairs(uno)

# Synthetic: a real thumbnail against a copy of itself shifted by a known vector, the uncovered
# strip filled from another thumbnail, through JPEG 85. Five thumbnails (A frames of the first
# negative-control pairs), eight overlaps, both axes. Gated from 0.35 (Amendment A1).
SYN_P <- c(0.20, 0.25, 0.30, 0.35, 0.50, 0.65, 0.80, 0.90)
SYN_GATE <- 0.35
syn_file <- file.path(CACHE, paste0("synthetic_", ALG, ".rds"))
if (!file.exists(syn_file)) {
  pick <- neg_m[neg_m$status != "no_thumbnail", ]
  pick <- pick[!duplicated(pick$film_roll), ][seq_len(if (SMOKE) 2L else 5L), ]
  stopifnot(!anyNA(pick$film_roll))
  thumbs <- lapply(seq_len(nrow(pick)), function(i) {
    read_gray(thumb_of(pick$film_roll[i], pick$frame[i])$path)
  })
  cases <- expand.grid(i = seq_along(thumbs), p_true = SYN_P, axis = c("row", "col"),
                       stringsAsFactors = FALSE)
  syn <- do.call(rbind, lapply(seq_len(nrow(cases)), function(q) {
    ab <- common(thumbs[[cases$i[q]]], thumbs[[(cases$i[q] %% length(thumbs)) + 1]])
    a <- ab$a
    nr <- nrow(a)
    nc <- ncol(a)
    L <- if (cases$axis[q] == "row") nr else nc
    d <- round((1 - cases$p_true[q]) * L)
    b <- ab$b
    if (cases$axis[q] == "row") {
      b[seq_len(nr - d), ] <- a[(d + 1):nr, ]
    } else {
      b[, seq_len(nc - d)] <- a[, (d + 1):nc]
    }
    s <- measure_shift(a, jpeg85(b))
    data.frame(thumb = pick$film_roll[cases$i[q]], frame = pick$frame[cases$i[q]],
               axis = cases$axis[q], p_true = 1 - d / L,
               dr_true = if (cases$axis[q] == "row") -d else 0,
               dc_true = if (cases$axis[q] == "col") -d else 0,
               dr = s[["row"]], dc = s[["col"]], n_patches = s[["n1"]], nr = nr, nc = nc)
  }))
  syn$matched <- is.finite(syn$dr)
  syn$p_img <- ifelse(syn$matched, p_of(syn$dr, syn$dc, syn$nr, syn$nc), NA_real_)
  save_atomic(syn, syn_file)
}
syn <- readRDS(syn_file)

# --- the gates --------------------------------------------------------------
gated <- syn$p_true >= SYN_GATE
syn_ok <- all(syn$matched[gated]) && all(abs(syn$p_img[gated] - syn$p_true[gated]) <= 0.02)
pub("CONTROL synthetic: %d gated cases (p_true >= %.2f), matched %d, max |p_img - p_true| %.4f: %s",
    sum(gated), SYN_GATE, sum(syn$matched[gated]),
    max(abs(syn$p_img[gated] - syn$p_true[gated]), na.rm = TRUE), if (syn_ok) "PASS" else "FAIL")
for (p in sort(unique(syn$p_true[!gated]))) {
  pub("  floor: p_true %.3f matched %d of %d", p, sum(syn$matched[syn$p_true == p]),
      sum(syn$p_true == p))
}

neg_k <- key_summary(neg_m)
neg_k$d <- D_of(neg_k$p_img, neg_k$p_nominal)
neg_ok_k <- neg_k[neg_k$pairs_used >= 3, ]
tau <- unname(stats::quantile(abs(neg_ok_k$d), 0.95))
TAU_MAX <- log(1.25)
neg_ok <- nrow(neg_ok_k) >= (if (SMOKE) 1L else 30L) && abs(stats::median(neg_ok_k$d)) <= 0.05 &&
  tau <= TAU_MAX
pub(paste0("CONTROL negative: %d of %d keys with >= 3 matched pairs; median d %+.4f; ",
           "tau (95th |d|) %.4f (ceiling %.4f), a step error of x%.3f: %s"),
    nrow(neg_ok_k), nrow(neg_k), stats::median(neg_ok_k$d), tau, TAU_MAX, exp(tau),
    if (neg_ok) "PASS" else "FAIL")
pub("  negative pairs: %s", paste(names(table(neg_m$status)), table(neg_m$status), sep = " ",
                                  collapse = ", "))

uno_rate <- mean(uno_m$status == "matched")
uno_ok <- uno_rate <= 0.05
pub("CONTROL false match: %d unrelated pairs, matched %d (%.3f; at most 0.05): %s; %s", nrow(uno_m),
    sum(uno_m$status == "matched"), uno_rate, if (uno_ok) "PASS" else "FAIL",
    paste(names(table(uno_m$status)), table(uno_m$status), sep = " ", collapse = ", "))

wrt_k <- do.call(rbind, lapply(split(wrt_m, wrt_m$film_roll), function(d) {
  use <- d$status == "matched"
  data.frame(film_roll = d$film_roll[1], written = d$written[1], gated = d$gated[1],
             pairs = nrow(d), pairs_used = sum(use),
             p_img = if (any(use)) stats::median(d$p_img[use]) else NA_real_,
             p_nominal = stats::median(d$p_nominal))
}))
wrt_g <- wrt_k[wrt_k$gated & wrt_k$pairs_used >= 3, ]
wrt_dev <- stats::median(wrt_g$p_img - wrt_g$written)
wrt_ok <- nrow(wrt_g) >= (if (SMOKE) 1L else 6L) && abs(wrt_dev) <= 0.08
for (i in seq_len(nrow(wrt_k))) {
  pub("  written %s %.2f%s: %d of %d pairs matched, p_img %.3f, p_nominal %.3f", wrt_k$film_roll[i],
      wrt_k$written[i], if (wrt_k$gated[i]) "" else " (reported only)", wrt_k$pairs_used[i],
      wrt_k$pairs[i], wrt_k$p_img[i], wrt_k$p_nominal[i])
}
pub(paste0("CONTROL written overlap: %d gated rolls with >= 3 matched pairs (need 6); ",
           "median p_img - written %+.4f (within 0.08): %s"),
    nrow(wrt_g), wrt_dev, if (wrt_ok) "PASS" else "FAIL")

pos_d <- D_of(pos_m$p_img, pos_m$p_nominal)
pos_ok <- pos_m$status == "matched" && abs(pos_d) > tau
pub("CONTROL positive: %s %d/%d %s, p_img %.3f, p_nominal %.3f, |D| %.3f against tau %.3f: %s",
    pos_m$film_roll, pos_m$frame, pos_m$frame_next, pos_m$status, pos_m$p_img, pos_m$p_nominal,
    abs(pos_d), tau, if (isTRUE(pos_ok)) "PASS" else "FAIL")
if (!(syn_ok && neg_ok && uno_ok && wrt_ok && isTRUE(pos_ok))) {
  stop("a control failed; the instrument is not trusted and nothing is written")
}

if (STOP_AFTER < 2 || SMOKE) {
  pub("stopping after the controls%s", if (SMOKE) " (smoke: nothing written)" else "")
  quit(save = "no")
}

# ---------------------------------------------------------------------------
# Stage 2 — the nine keys
# ---------------------------------------------------------------------------

# The rule's order puts the blind logbook read first: every page the catalogue links for the
# eight rolls must be in the height transcription or the strips transcription (Amendment A2).
PAGES <- c(sprintf("bc5715__bc5715_%d.jpg", 1:5), sprintf("bc77026__bc77026_%d.jpg", 2:3),
           sprintf("bc77070__bc77070_%d.jpg", 1:4), sprintf("bc77072__bc77072_%d.jpg", 1:4),
           sprintf("bc77087__bc77087_%d.jpg", 1:5), sprintf("bc7718__bc7717_7718_%d.jpg", 4:6),
           sprintf("bc80117__bc80117_%d.jpg", 1:7), sprintf("bcc325__bcc325_%d.jpg", 1:5))
stopifnot(length(PAGES) == 35, file.exists(STRIPS))
lbk <- read.csv("data-raw/flying_height_logbooks.csv", stringsAsFactors = FALSE)
st <- read.csv(STRIPS, stringsAsFactors = FALSE)
unread <- setdiff(PAGES, c(lbk$file, st$file))
if (length(unread)) stop("linked pages not transcribed: ", paste(unread, collapse = ", "))

# Pairs are the census frames' (Amendment A2): n, n+1 on the catalogue key with at least one of
# the two in the census files fly#95 judged.
census <- rbind(read.csv("inst/extdata/flying_height_terrain_frames.csv"),
                read.csv("inst/extdata/flying_height_terrain_nonpositive.csv"))
cen_rf <- paste(census$film_roll, census$frame_number)
k9 <- key4(KEYS9$film_roll, KEYS9$flying_height, KEYS9$focal_length, KEYS9$scale_n)
kp <- do.call(rbind, lapply(k9, key_pairs))
kp <- kp[paste(kp$film_roll, kp$frame) %in% cen_rf | paste(kp$film_roll, kp$frame_next) %in% cen_rf, ]
kp$set <- "key"
invisible(run_pairs(kp[, cols_pair]))
kp_m <- read_pairs(kp)
pub("key pairs: %d on %d keys; %s", nrow(kp_m), length(unique(kp_m$key)),
    paste(names(table(kp_m$status)), table(kp_m$status), sep = " ", collapse = ", "))

if (STOP_AFTER < 3) quit(save = "no")

# ---------------------------------------------------------------------------
# Stage 3 — the verdicts
# ---------------------------------------------------------------------------

kk <- key_summary(kp_m)
kk <- kk[match(k9, kk$key), ]
stopifnot(!anyNA(kk$key))
kk$D_nominal <- D_of(kk$p_img, kk$p_nominal)
kk$D_agl <- D_of(kk$p_img, kk$p_agl)
kk$gap <- abs(log((1 - kk$p_nominal) / (1 - kk$p_agl)))
kk$k <- (1 - kk$p_nominal) / (1 - kk$p_img)
kk$w1 <- dplyr::case_when(
  kk$pairs_used < 3 ~ "too_few_pairs",
  kk$pairs_matched < kk$pairs / 2 ~ "no_overlap",
  kk$gap <= 2 * tau & (abs(kk$D_nominal) <= tau | abs(kk$D_agl) <= tau) ~ "indistinguishable",
  abs(kk$D_nominal) <= tau ~ "consistent_nominal",
  abs(kk$D_agl) <= tau ~ "consistent_agl",
  kk$D_agl < -tau & kk$D_nominal < -tau ~ "step_overstated",
  TRUE ~ "disagrees"
)

# W2, height: the generator's own Stage 6 join, re-run after the blind read.
ag <- read.csv("inst/extdata/flying_height_above_ground.csv")
ag$key <- key4(ag$film_roll, ag$flying_height, ag$focal_length, ag$scale_n)
a9 <- ag[match(kk$key, ag$key), ]
stopifnot(!anyNA(a9$key))
kk$frames <- a9$frames
kk$frames_nonpositive <- a9$frames_nonpositive
kk$frames_logbook <- a9$frames_logbook
kk$frames_catalogue <- a9$frames_catalogue
kk$frames_ground <- a9$frames_ground_plus + a9$frames_ground_header
covered <- kk$frames_logbook >= kk$frames / 2
kk$w2_height <- dplyr::case_when(
  covered & kk$frames_catalogue >= 0.9 * kk$frames_logbook ~ "msl_catalogue",
  covered & kk$frames_ground >= 0.9 * kk$frames_logbook ~ "ground",
  TRUE ~ "not_read"
)

# W2, strips: per matched non-break pair, the page's heading against the catalogue's bearing of the
# step (grid bearing in BC Albers). Reported, not gating.
st <- st[is.finite(st$frame_from) & is.finite(st$frame_to), ]
circ <- function(a, b) abs(((a - b + 180) %% 360) - 180)
kp_m$heading <- NA_real_
kp_m$place <- NA_character_
kp_m$overlap_written <- NA_character_
for (i in seq_len(nrow(kp_m))) {
  s <- st[st$film_roll == kp_m$film_roll[i] &
            kp_m$frame[i] >= pmin(st$frame_from, st$frame_to) &
            kp_m$frame_next[i] <= pmax(st$frame_from, st$frame_to), ]
  if (nrow(s) == 1) {
    kp_m$heading[i] <- s$direction_deg
    kp_m$place[i] <- s$place_as_written
    kp_m$overlap_written[i] <- s$overlap_as_written
  }
}
kp_m$dir <- dplyr::case_when(
  !is.finite(kp_m$heading) | kp_m$status != "matched" | kp_m$line_break ~ NA_character_,
  circ(kp_m$heading, kp_m$bearing) <= 35 ~ "agree",
  circ(kp_m$heading, kp_m$bearing + 180) <= 35 ~ "reverse",
  TRUE ~ "differ"
)
dsum <- function(k, v) sum(kp_m$dir[kp_m$key == k] == v, na.rm = TRUE)
kk$dir_agree <- vapply(kk$key, dsum, integer(1), "agree")
kk$dir_reverse <- vapply(kk$key, dsum, integer(1), "reverse")
kk$dir_differ <- vapply(kk$key, dsum, integer(1), "differ")
uq <- function(x) paste(sort(unique(x[!is.na(x) & nzchar(x)])), collapse = " | ")
kk$places <- vapply(kk$key, function(k) uq(kp_m$place[kp_m$key == k]), character(1))
kk$overlap_written <- vapply(kk$key, function(k) uq(kp_m$overlap_written[kp_m$key == k]),
                             character(1))

# Places the pages name, from the BC Geographical Names service (apps.gov.bc.ca/pub/bcgnws,
# names/search, outputSRS 4326, queried 2026-10-07; where a name recurs across BC, the feature beside
# the other name on the same page). Reported, never gating: the distance from the key's nearest census
# frame centroid to the nearest of its page's places. `bcc325`'s page names an unread creek.
PLACES <- data.frame(
  film_roll = c("bc5715", "bc77026", "bc77070", "bc77070", "bc77072", "bc77072", "bc77087",
                "bc77087", "bc7718", "bc80117"),
  place = c("Horseshoe Bay", "Pemberton", "Swan Lake", "Grindrod", "Spences Bridge", "Savona",
            "Swan Lake", "Grindrod", "Tahsis", "Yale"),
  lon = c(-123.281, -122.808, -119.257, -119.123, -121.344, -120.843, -119.257, -119.123,
          -126.664, -121.431),
  lat = c(49.371, 50.321, 50.320, 50.625, 50.422, 50.753, 50.320, 50.625, 49.916, 49.562)
)
cen_xy <- frames[paste(frames$film_roll, frames$frame_number) %in% cen_rf, ]
pl <- sf::st_transform(sf::st_as_sf(PLACES, coords = c("lon", "lat"), crs = 4326), 3005)
pl_xy <- sf::st_coordinates(pl)
kk$km_to_place <- vapply(seq_len(nrow(kk)), function(i) {
  f <- cen_xy[cen_xy$key == kk$key[i], ]
  j <- which(PLACES$film_roll == kk$film_roll[i])
  if (!nrow(f) || !length(j)) return(NA_real_)
  min(outer(f$x, pl_xy[j, 1], "-")^2 + outer(f$y, pl_xy[j, 2], "-")^2)^0.5 / 1000
}, numeric(1))

# The two outcomes (Amendment A2).
kk$size <- dplyr::case_when(
  kk$w1 %in% c("too_few_pairs", "no_overlap") ~ kk$w1,
  kk$w1 == "consistent_nominal" ~ "nominal_consistent",
  kk$w1 == "consistent_agl" & kk$w2_height != "msl_catalogue" ~ "agl_supported",
  kk$w1 == "step_overstated" & kk$w2_height == "msl_catalogue" ~ "nominal_unrefuted",
  TRUE ~ "unsettled"
)
kk$location <- dplyr::case_when(
  kk$w2_height == "msl_catalogue" &
    kk$w1 %in% c("consistent_nominal", "step_overstated", "disagrees") ~ "misplaced",
  kk$w1 == "consistent_agl" | kk$w2_height == "ground" ~ "datum_question",
  TRUE ~ "not_tested"
)

pub("tau %.4f (step error x%.3f)", tau, exp(tau))
print(kk[, c("key", "pairs", "pairs_break", "pairs_matched", "pairs_used", "p_img", "p_nominal",
             "p_agl", "D_nominal", "D_agl", "gap", "w1", "w2_height", "dir_agree", "dir_reverse",
             "dir_differ", "size", "location", "km_to_place", "frames_nonpositive")], row.names = FALSE)
tally <- function(v) {
  t <- tapply(kk$frames_nonpositive, v, sum)
  paste(names(t), t, collapse = ", ")
}
pub("r <= 0 frames by location: %s", tally(kk$location))
pub("r <= 0 frames by size: %s", tally(kk$size))
if (any(kk$w2_height == "ground" | kk$size == "agl_supported")) {
  pub("STOP FOR THE USER: a key reads ground or agl_supported; the package shape is theirs to decide")
}

# ---------------------------------------------------------------------------
# Write
# ---------------------------------------------------------------------------

r4 <- function(x) round(x, 4)
cols_out <- c("set", "key", "film_roll", "frame", "roll_b", "frame_b", "frame_next", "step",
              "bearing", "line_break", "p_nominal", "p_agl", "status", "dr", "dc", "n_patches",
              "nr", "nc", "p_img")
fill <- function(d) {
  for (v in setdiff(cols_out, names(d))) d[[v]] <- NA
  d[, cols_out]
}
uno_m$set <- "unrelated"
uno_m$key <- NA
pairs_out <- rbind(fill(neg_m), fill(wrt_m), fill(pos_m), fill(uno_m), fill(kp_m))
for (v in c("step", "bearing", "p_nominal", "p_agl", "dr", "dc", "p_img")) {
  pairs_out[[v]] <- r4(pairs_out[[v]])
}
strips_out <- kp_m[, c("key", "film_roll", "frame", "heading", "dir", "place", "overlap_written")]
syn_out <- syn
for (v in c("p_true", "dr", "dc", "p_img")) syn_out[[v]] <- r4(syn_out[[v]])
wrt_out <- WRITTEN
keys_out <- kk[, c("film_roll", "flying_height", "focal_length", "scale_n", "frames",
                   "frames_nonpositive", "pairs", "pairs_break", "pairs_matched", "pairs_used",
                   "p_img", "p_nominal", "p_agl", "D_nominal", "D_agl", "gap", "k", "w1",
                   "frames_logbook", "frames_catalogue", "frames_ground", "w2_height", "dir_agree",
                   "dir_reverse", "dir_differ", "size", "location", "places", "km_to_place",
                   "overlap_written")]
for (v in c("p_img", "p_nominal", "p_agl", "D_nominal", "D_agl", "gap", "k", "km_to_place")) {
  keys_out[[v]] <- r4(keys_out[[v]])
}
write_if_changed(syn_out, "inst/extdata/flying_height_image_overlap_synthetic.csv")
write_if_changed(wrt_out, "inst/extdata/flying_height_image_overlap_written.csv")
write_if_changed(pairs_out, "inst/extdata/flying_height_image_overlap_pairs.csv")
write_if_changed(strips_out, "inst/extdata/flying_height_image_overlap_strips.csv")
write_if_changed(keys_out, "inst/extdata/flying_height_image_overlap_keys.csv")
