# Whether a BW/colour frame's catalogued height is a height ABOVE GROUND recorded as above sea
# level (fly#95). The spacing columns are recomputed from what `data-raw/height_measure-terrain_tail.R`
# and `data-raw/height_calibrate-lower_tail_rolls.R` shipped, so the spacing verdict is never trusted.
# The logbook columns are checked for consistency only: the per-frame join is not shipped.
# The rule is in `inst/notes/terrain-correction.md`, "Is the catalogued height above ground? Not with
# these instruments (fly#95)".

extdata <- function(f) {
  utils::read.csv(system.file("extdata", f, package = "fly", mustWork = TRUE),
                  stringsAsFactors = FALSE, na.strings = "")
}

band    <- fly_height_ratio_band()
in_band <- function(r) is.finite(r) & r >= band[1] & r <= band[2]
format_m <- 9 * 0.0254
key <- function(d) paste(d$film_roll, d$flying_height, d$focal_length, d$scale_n)

# The window, as the generator draws it: central 95% of in-band random frames' overlap at the
# reported height, with the air base #89 shipped for those frames.
agl_window <- function() {
  sw <- extdata("flying_height_sweep.csv")
  w <- extdata("infrared_film_window.csv")
  rnd <- merge(sw[sw$set == "random", ], w, by = "airp_id")
  side <- (rnd$flying_height - rnd$elev) / (rnd$focal_length / 1000)
  rnd <- rnd[in_band(side / rnd$scale_n), ]
  unname(stats::quantile(1 - rnd$base / (format_m * (rnd$flying_height - rnd$elev) /
                                           (rnd$focal_length / 1000)),
                         c(.025, .975), na.rm = TRUE))
}

# Every frame of the population: both census files, on the keys an `r <= 0` frame reaches or
# fly#93's A2 found nominal fits.
agl_frames <- function() {
  cf <- extdata("flying_height_terrain_frames.csv")
  np <- extdata("flying_height_terrain_nonpositive.csv")
  ir <- extdata("infrared_film_frames.csv")
  ir <- ir[ir$height_class == "outside_band", ]
  nominal <- ir$scale_n * ir$focal_length / 1000
  ir <- ir[in_band(ir$flying_height / nominal) & !in_band((ir$flying_height - ir$elev) / nominal), ]
  cols <- c("airp_id", "film_roll", "flying_height", "focal_length", "scale_n", "elev", "base")
  pool <- rbind(cbind(cf[, cols], nonpositive = FALSE), cbind(ir[, cols], nonpositive = FALSE),
                cbind(np[, cols], nonpositive = TRUE))
  excl <- extdata("flying_height_rolls_excluded.csv")
  a2a <- excl[excl$tail == "terrain" &
                startsWith(excl$reason, "spacing fits nominal scale, which no logbook"), ]
  pool[key(pool) %in% union(key(np), key(a2a)), ]
}

agl_a2a <- function() {
  excl <- extdata("flying_height_rolls_excluded.csv")
  excl[excl$tail == "terrain" &
         startsWith(excl$reason, "spacing fits nominal scale, which no logbook"), ]
}

test_that("the window is the generator's", {
  expect_equal(round(agl_window(), 3), c(0.557, 0.780))
})

test_that("the population is every key an r <= 0 frame reaches, and every A2(a) key", {
  ag <- extdata("flying_height_above_ground.csv")
  fr <- agl_frames()
  np <- extdata("flying_height_terrain_nonpositive.csv")
  expect_false(anyDuplicated(key(ag)) > 0)
  expect_setequal(key(ag), unique(key(fr)))
  expect_identical(nrow(ag), 188L)
  expect_identical(sum(ag$frames), nrow(fr))
  expect_identical(sum(ag$frames_nonpositive), nrow(np))
  # 374 frames under the aircraft, on 15 rolls and 16 roll-heights (`bc77072` flies two).
  expect_identical(sum(ag$frames_nonpositive > 0), 16L)
  expect_identical(length(unique(ag$film_roll[ag$frames_nonpositive > 0])), 15L)
  n <- table(key(fr))
  expect_identical(as.integer(n[key(ag)]), ag$frames)
  # The population is every census frame on the keys, not just the two groups: 2,535 on the
  # A2(a) keys, the 219 `r <= 0` frames elsewhere, and 202 above the ground on eight of the other
  # twelve keys, which neither group holds.
  a2a <- key(ag) %in% key(agl_a2a())
  expect_identical(sum(ag$frames[a2a]), 2535L)
  expect_identical(sum(ag$frames_nonpositive[!a2a]), 219L)
  above <- ag$frames[!a2a] - ag$frames_nonpositive[!a2a]
  expect_identical(c(sum(above), sum(above > 0)), c(202L, 8L))
  n_np <- table(factor(key(np), levels = key(ag)))
  expect_identical(as.integer(n_np[key(ag)]), ag$frames_nonpositive)
  expect_true(all(ag$frames_outside >= 0))
})

test_that("the spacing verdict is recomputed from the frames and the window", {
  ag <- extdata("flying_height_above_ground.csv")
  fr <- agl_frames()
  win <- agl_window()
  fits <- function(p) is.finite(p) & p >= win[1] & p <= win[2]
  got <- do.call(rbind, lapply(split(fr, key(fr)), function(d) {
    p_agl <- stats::median(1 - d$base / (format_m * d$flying_height / (d$focal_length / 1000)),
                           na.rm = TRUE)
    p_nom <- stats::median(1 - d$base / (format_m * d$scale_n), na.rm = TRUE)
    data.frame(key = key(d)[1], p_agl = p_agl, p_nom = p_nom,
               n_base = sum(is.finite(d$base)),
               spacing = if (!any(is.finite(d$base))) "no_base" else if (!fits(p_agl)) "refutes"
                         else if (fits(p_nom)) "undecided" else "supports")
  }))
  m <- match(key(ag), got$key)
  expect_false(anyNA(m))
  expect_identical(ag$spacing, got$spacing[m])
  # The shipped air base is rounded to 0.1 m, the generator's is not, so the third decimal of
  # an overlap can differ by one.
  expect_true(all(abs(ag$overlap_agl - got$p_agl[m]) <= 0.0015))
  expect_true(all(abs(ag$overlap_nominal - got$p_nom[m]) <= 0.0015))
  expect_identical(ag$frames_base, got$n_base[m])
  # The two predicted sides are exactly `ratio_asl` apart, so S is a function of the median
  # nominal overlap and that ratio: the identity behind "the instrument cannot settle it".
  r <- ag$flying_height / (ag$scale_n * ag$focal_length / 1000)
  expect_equal(ag$ratio_asl, round(r, 3))
  expect_equal(1 - (1 - got$p_nom[m]) / r, got$p_agl[m], tolerance = 1e-9)
  expect_identical(as.integer(table(factor(ag$spacing, c("supports", "undecided", "refutes",
                                                         "no_base")))),
                   c(1L, 126L, 61L, 0L))
  # Adding the r <= 0 frames moves no A2(a) verdict: nominal still fits on all 176.
  excl <- extdata("flying_height_rolls_excluded.csv")
  a2a <- excl[excl$tail == "terrain" &
                startsWith(excl$reason, "spacing fits nominal scale, which no logbook"), ]
  expect_identical(nrow(a2a), 176L)
  expect_true(all(fits(got$p_nom[match(key(a2a), got$key)])))
})

test_that("nothing tables, and every reason is the first condition that fired", {
  ag <- extdata("flying_height_above_ground.csv")
  expect_false(any(ag$tabled))
  rel <- ag$frames_catalogue + ag$frames_ground_plus + ag$frames_ambiguous +
    ag$frames_ground_header + ag$frames_other
  expect_identical(rel, ag$frames_logbook)
  expect_true(all(ag$frames_logbook <= ag$frames))
  expect_identical(ag$reason[ag$spacing == "refutes"],
                   rep("spacing rejects the catalogued height read as above ground",
                       sum(ag$spacing == "refutes")))
  expect_identical(ag$reason[ag$spacing == "undecided"],
                   rep("spacing fits both the catalogued height read as above ground and nominal scale",
                       sum(ag$spacing == "undecided")))
  # The one roll-height spacing supports: its logbook writes the catalogue's own 4,000 ft
  # (1,219 m) on every frame, under an M.S.L. header, so the ground is never under it.
  s <- ag[ag$spacing == "supports", ]
  expect_identical(key(s), "bc5602 1219 153 6000")
  expect_identical(s$frames_logbook, s$frames)
  expect_identical(s$frames_catalogue, s$frames)
  expect_identical(s$logbook_ft, "4000")
  expect_identical(s$reason, "logbook does not put the ground under the catalogued height")
  # Of the frames a transcribed page reads, none has the ground put under the catalogued height.
  expect_identical(sum(ag$frames_ground_plus) + sum(ag$frames_ground_header), 0L)
})

test_that("the frames no reading fits are the nine roll-heights the note names", {
  ag <- extdata("flying_height_above_ground.csv")
  win <- agl_window()
  fits <- function(p) is.finite(p) & p >= win[1] & p <= win[2]
  nf <- ag[ag$spacing == "refutes" & !fits(ag$overlap_nominal), ]
  expect_setequal(key(nf), c("bc5715 732 153 4800", "bc77026 2042 305 6000",
                             "bc77070 1158 153 5000", "bc77072 1829 153 10000",
                             "bc77072 1981 153 10000", "bc77087 1158 153 5000",
                             "bc7718 1524 305 5000", "bc80117 1372 153 8000",
                             "bcc325 396 153 2000"))
  expect_identical(sum(nf$frames_nonpositive), 157L)
})

test_that("the note's above-ground tables are the shipped tables, row by row (fly#95)", {
  np <- system.file("notes/terrain-correction.md", package = "fly")
  skip_if(!nzchar(np), "notes not installed")
  note <- readLines(np, warn = FALSE)
  from <- grep("^## Is the catalogued height above ground\\?", note)
  expect_length(from, 1)
  to <- from + grep("^## ", note[(from + 1):length(note)])[1]
  sec <- note[from:to]
  rows <- function(first) {
    i <- grep(first, sec, fixed = TRUE)
    expect_length(i, 1)
    j <- i + 2
    while (j <= length(sec) && grepl("^\\|", sec[j])) j <- j + 1
    cells <- strsplit(sub("^\\|\\s*", "", sub("\\s*\\|\\s*$", "", sec[(i + 2):(j - 1)])), "\\s*\\|\\s*")
    lapply(cells, function(x) c(x[1], gsub("[^0-9]", "", x[-1])))
  }
  ag <- extdata("flying_height_above_ground.csv")

  sp <- rows("| spacing | roll-heights | frames | of them `r <= 0` |")
  for (r in sp) {
    d <- ag[ag$spacing == r[1], ]
    expect_identical(as.numeric(r[-1]), c(nrow(d), sum(d$frames), sum(d$frames_nonpositive)) + 0,
                     info = r[1])
  }
  expect_identical(vapply(sp, `[`, "", 1), c("supports", "undecided", "refutes"))
  expect_identical(sum(ag$spacing == "no_base"), 0L)

  lb <- rows("| logbook relation | frames |")
  expect_identical(as.numeric(vapply(lb, `[`, "", 2)),
                   c(sum(ag$frames_catalogue), sum(ag$frames_ambiguous), sum(ag$frames_other),
                     sum(ag$frames_ground_plus) + sum(ag$frames_ground_header)) + 0)
  # "the 32 roll-heights with a frame the logbook reads", and the 576 frames it reads.
  expect_identical(sum(ag$frames_logbook > 0), 32L)
  expect_identical(sum(ag$frames_logbook), 576L)
  # `ambiguous` frames carry the catalogue's figure too (ground near sea level).
  expect_identical(sum(ag$frames_catalogue) + sum(ag$frames_ambiguous), 558L)

  win <- agl_window()
  fits <- function(p) is.finite(p) & p >= win[1] & p <= win[2]
  g1 <- rows("| `r <= 0` frames on roll-heights where | frames |")
  nom <- fits(ag$overlap_nominal)
  expect_identical(as.numeric(vapply(g1, `[`, "", 2)),
                   c(sum(ag$frames_nonpositive[ag$spacing == "undecided"]),
                     sum(ag$frames_nonpositive[ag$spacing == "refutes" & nom]),
                     sum(ag$frames_nonpositive[ag$spacing == "supports"]),
                     sum(ag$frames_nonpositive[ag$spacing == "refutes" & !nom])) + 0)
  expect_identical(sum(ag$frames_nonpositive), 374L)

  # The prose figures: the undecided bound and how marginal the refutations are.
  und <- ag[ag$spacing == "undecided", ]
  d <- abs(und$ratio_asl - 1)
  expect_identical(sprintf("%.3f", c(stats::median(d), stats::quantile(d, .9, names = FALSE), max(d))),
                   c("0.120", "0.352", "0.494"))
  expect_identical(sum(und$frames[d > 0.2]), 494L)
  rf <- ag[ag$spacing == "refutes" & nom, ]
  out <- ifelse(rf$overlap_agl > win[2], rf$overlap_agl - win[2], win[1] - rf$overlap_agl)
  expect_identical(nrow(rf), 52L)
  expect_identical(sprintf("%.3f", stats::median(out)), "0.028")
  expect_identical(sum(out < 0.02), 23L)
  # ... and the prose says those same figures.
  prose <- paste(sec, collapse = " ")
  for (s in c("a median 0.120, 0.352 at the 90th percentile and at most 0.494",
              "494 of their 1,562 frames", "a median 0.028 outside the window",
              "23 of them by under 0.02", "On the 52 refuted roll-heights",
              "Over the 32 roll-heights with a frame the logbook reads",
              "Pages are transcribed for 26 of the population's 154 rolls",
              "(2.00 to 2.58, median 2.16), and 51 of them are within 2% of x2",
              "188 roll-heights, judged on every frame either census file holds on them, 2,956",
              "the two groups (2,754 frames) plus 202 above the ground on eight keys",
              "it writes the catalogue's height on 558 of the 576 frames it reads")) {
    expect_true(grepl(s, prose, fixed = TRUE), info = s)
  }
})

test_that("the note's logbook scope is the transcription's, and its x2 figures are the census's", {
  # The transcription is a data-raw input, not installed, so this runs only from the source tree.
  lb_path <- testthat::test_path("..", "..", "data-raw", "flying_height_logbooks.csv")
  skip_if(!file.exists(lb_path), "logbook transcription not reachable from an installed package")
  lb <- utils::read.csv(lb_path, stringsAsFactors = FALSE)
  ag <- extdata("flying_height_above_ground.csv")
  rolls <- unique(ag$film_roll)
  expect_identical(length(rolls), 154L)
  expect_identical(sum(rolls %in% lb$film_roll), 26L)
  # Every roll with a read frame is a transcribed one.
  expect_true(all(ag$film_roll[ag$frames_logbook > 0] %in% lb$film_roll))
  # No transcribed header names the ground.
  hdr <- lb$height_header
  ground <- grepl("ground|A\\.?G\\.?L|terrain|clearance", hdr, ignore.case = TRUE) &
    !grepl("M\\.?S\\.?L", hdr, ignore.case = TRUE)
  expect_false(any(ground))

  np <- extdata("flying_height_terrain_nonpositive.csv")
  q <- 1 + np$elev / np$flying_height
  expect_identical(sprintf("%.2f", c(min(q), max(q), stats::median(q))), c("2.00", "2.58", "2.16"))
  expect_identical(sum(abs(q / 2 - 1) <= 0.02), 51L)
})
