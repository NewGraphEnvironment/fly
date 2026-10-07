# What the frames under the terrain covered, from the overlap their own photos show (fly#97). Every
# gate, tau and every verdict is recomputed from what `data-raw/height_measure-image_overlap.R`
# shipped, so none is trusted: only the per-pair shifts (`dr`, `dc`) and the catalogue's centroid
# step are taken as measured. The rule is in `inst/notes/terrain-correction.md`, "What the frames
# under the terrain covered (fly#97)".

extdata <- function(f) {
  utils::read.csv(system.file("extdata", f, package = "fly", mustWork = TRUE),
                  stringsAsFactors = FALSE, na.strings = "")
}
format_m <- 9 * 0.0254
p_of <- function(dr, dc, nr, nc) 1 - sqrt(dr^2 + dc^2) / ifelse(abs(dr) >= abs(dc), nr, nc)
D_of <- function(p_img, p_reading) log((1 - p_img) / (1 - p_reading))

io_pairs <- function() {
  p <- extdata("flying_height_image_overlap_pairs.csv")
  # A matched shift over 0.95 overlap is fixed pattern, not ground (Amendment A2).
  p$p_calc <- ifelse(p$status == "matched", p_of(p$dr, p$dc, p$nr, p$nc), NA_real_)
  p
}
io_keys <- function(p) {
  do.call(rbind, lapply(split(p, p$key), function(d) {
    use <- d$status == "matched" & !d$line_break
    data.frame(key = d$key[1], pairs = nrow(d), pairs_break = sum(d$line_break),
               pairs_matched = sum(d$status == "matched"), pairs_used = sum(use),
               p_img = if (any(use)) stats::median(d$p_calc[use]) else NA_real_,
               p_nominal = if (any(use)) stats::median(d$p_nominal[use]) else NA_real_,
               p_agl = if (any(use)) stats::median(d$p_agl[use]) else NA_real_)
  }))
}
io_tau <- function(p) {
  k <- io_keys(p[p$set == "negative", ])
  k <- k[k$pairs_used >= 3, ]
  d <- D_of(k$p_img, k$p_nominal)
  list(n = nrow(k), median = stats::median(d), tau = unname(stats::quantile(abs(d), 0.95)))
}

test_that("every pair's overlap and both readings come from its shift and its step", {
  p <- io_pairs()
  m <- p$status == "matched"
  expect_true(all(p$status %in% c("matched", "no_match", "no_thumbnail", "fixed_pattern")))
  expect_lt(max(abs(p$p_img[m] - p$p_calc[m])), 1e-4)
  expect_true(all(is.na(p$p_img[!m])))
  expect_false(any(p$p_calc[m] > 0.95))
  # The two readings are the catalogue step against the two sides.
  k <- strsplit(p$key[!is.na(p$key)], " ")
  h <- as.numeric(vapply(k, `[`, "", 2))
  f <- as.numeric(vapply(k, `[`, "", 3)) / 1000
  s <- as.numeric(vapply(k, `[`, "", 4))
  q <- p[!is.na(p$key), ]
  expect_lt(max(abs(q$p_nominal - (1 - q$step / (format_m * s)))), 1e-4)
  expect_lt(max(abs(q$p_agl - (1 - q$step / (format_m * h / f)))), 1e-4)
  # A line break is a step over 3x its key's median step.
  for (kk in unique(q$key)) {
    d <- q[q$key == kk, ]
    expect_identical(d$line_break, d$step > 3 * stats::median(d$step), info = kk)
  }
})

test_that("the controls pass on the shipped measurements, and tau is what they set", {
  p <- io_pairs()

  syn <- extdata("flying_height_image_overlap_synthetic.csv")
  g <- syn$p_true >= 0.35
  expect_identical(sum(g), 50L)
  expect_true(all(syn$matched[g]))
  expect_lt(max(abs(syn$p_img[g] - syn$p_true[g])), 0.02)
  # The floor: nothing at 0.20, everything at 0.25 (Amendment A1).
  expect_identical(sum(syn$matched[abs(syn$p_true - 0.2) < 1e-3]), 0L)
  expect_identical(sum(syn$matched[abs(syn$p_true - 0.25) < 0.005]), 10L)

  tt <- io_tau(p)
  expect_gte(tt$n, 30L)
  expect_lte(abs(tt$median), 0.05)
  expect_lte(tt$tau, log(1.25))
  expect_identical(sprintf("%.3f", tt$tau), "0.220")  # 0.2199 in the script; the CSV rounds p to 4 dp

  u <- p[p$set == "unrelated", ]
  expect_identical(nrow(u), 38L)
  expect_lte(mean(u$status == "matched"), 0.05)
  expect_identical(sum(u$status == "matched"), 0L)

  w <- extdata("flying_height_image_overlap_written.csv")
  wp <- p[p$set == "written", ]
  wk <- do.call(rbind, lapply(split(wp, wp$film_roll), function(d) {
    use <- d$status == "matched"
    data.frame(film_roll = d$film_roll[1], used = sum(use), p_img = stats::median(d$p_calc[use]))
  }))
  wk <- merge(wk, w, by = "film_roll")
  wg <- wk[wk$gated & wk$used >= 3, ]
  expect_gte(nrow(wg), 6L)
  expect_lte(abs(stats::median(wg$p_img - wg$written)), 0.08)

  pos <- p[p$set == "positive", ]
  expect_identical(nrow(pos), 1L)
  expect_identical(pos$status, "matched")
  expect_gt(abs(D_of(pos$p_calc, pos$p_nominal)), tt$tau)
})

test_that("every key's verdicts follow from its pairs, tau and the generator's logbook join", {
  p <- io_pairs()
  tau <- io_tau(p)$tau
  kp <- p[p$set == "key", ]
  sk <- extdata("flying_height_image_overlap_keys.csv")
  sk$key <- paste(sk$film_roll, sk$flying_height, sk$focal_length, sk$scale_n)
  k <- io_keys(kp)
  k <- k[match(sk$key, k$key), ]
  expect_identical(k$key, sk$key)
  for (v in c("pairs", "pairs_break", "pairs_matched", "pairs_used")) {
    expect_identical(as.integer(k[[v]]), as.integer(sk[[v]]), info = v)
  }
  dn <- D_of(k$p_img, k$p_nominal)
  da <- D_of(k$p_img, k$p_agl)
  gap <- abs(log((1 - k$p_nominal) / (1 - k$p_agl)))
  w1 <- dplyr::case_when(
    k$pairs_used < 3 ~ "too_few_pairs",
    k$pairs_matched < k$pairs / 2 ~ "no_overlap",
    gap <= 2 * tau & (abs(dn) <= tau | abs(da) <= tau) ~ "indistinguishable",
    abs(dn) <= tau ~ "consistent_nominal",
    abs(da) <= tau ~ "consistent_agl",
    da < -tau & dn < -tau ~ "step_overstated",
    TRUE ~ "disagrees"
  )
  expect_identical(w1, sk$w1)

  ag <- extdata("flying_height_above_ground.csv")
  ag <- ag[match(sk$key, paste(ag$film_roll, ag$flying_height, ag$focal_length, ag$scale_n)), ]
  expect_identical(sk$frames_nonpositive, ag$frames_nonpositive)
  ground <- ag$frames_ground_plus + ag$frames_ground_header
  cov <- ag$frames_logbook >= ag$frames / 2
  w2 <- dplyr::case_when(
    cov & ag$frames_catalogue >= 0.9 * ag$frames_logbook ~ "msl_catalogue",
    cov & ground >= 0.9 * ag$frames_logbook ~ "ground",
    cov ~ "read_other",
    TRUE ~ "not_read"
  )
  expect_identical(w2, sk$w2_height)

  size <- dplyr::case_when(
    w1 %in% c("too_few_pairs", "no_overlap") ~ w1,
    w1 == "consistent_nominal" ~ "nominal_consistent",
    w1 == "consistent_agl" & w2 != "msl_catalogue" ~ "agl_supported",
    w1 == "step_overstated" & w2 == "msl_catalogue" ~ "nominal_unrefuted",
    TRUE ~ "unsettled"
  )
  location <- dplyr::case_when(
    w2 == "msl_catalogue" & w1 %in% c("consistent_nominal", "step_overstated", "disagrees") ~
      "misplaced",
    w1 == "consistent_agl" | w2 == "ground" ~ "datum_question",
    TRUE ~ "not_tested"
  )
  expect_identical(size, sk$size)
  expect_identical(location, sk$location)
  # Nothing reached the package: no key supports reading the height as above ground, and no page
  # names the ground (either would have stopped for a decision on shape).
  expect_false(any(size == "agl_supported" | w2 == "ground"))
  # The headings are tallied from the strips file.
  st <- extdata("flying_height_image_overlap_strips.csv")
  for (v in c("agree", "reverse", "differ")) {
    n <- vapply(sk$key, function(kk) sum(st$dir[st$key == kk] == v, na.rm = TRUE), integer(1))
    expect_identical(unname(n), as.integer(sk[[paste0("dir_", v)]]), info = v)
  }
})

test_that("the note's table and every figure in its prose are the shipped measurement's", {
  note <- system.file("notes", "terrain-correction.md", package = "fly", mustWork = TRUE)
  txt <- readLines(note)
  i <- grep("^## What the frames under the terrain covered", txt)
  expect_length(i, 1)
  j <- i + grep("^## ", txt[(i + 1):length(txt)])[1]
  sec <- txt[i:(j - 1)]
  prose <- gsub("\\s+", " ", paste(sec, collapse = " "))

  p <- io_pairs()
  tt <- io_tau(p)
  sk <- extdata("flying_height_image_overlap_keys.csv")
  # Medians recomputed from the pairs' steps, which carry four decimals of a metre: the shipped
  # four-decimal overlaps would round twice (0.84348 to 0.8435 to 0.844).
  kq <- p[p$set == "key", ]
  kq$p_nominal <- 1 - kq$step / (format_m * as.numeric(sub(".* ", "", kq$key)))
  kk4 <- strsplit(kq$key, " ")
  kq$p_agl <- 1 - kq$step / (format_m * as.numeric(vapply(kk4, `[`, "", 2)) /
                               (as.numeric(vapply(kk4, `[`, "", 3)) / 1000))
  rk <- io_keys(kq)
  rk <- rk[match(paste(sk$film_roll, sk$flying_height, sk$focal_length, sk$scale_n), rk$key), ]
  sk$p_img <- rk$p_img
  sk$p_nominal <- rk$p_nominal
  sk$D_agl <- D_of(rk$p_img, rk$p_agl)
  f3 <- function(x) sprintf("%.3f", x)

  # The table: one row per key, in the shipped order.
  h <- grep("| roll-height | pairs (matched) |", sec, fixed = TRUE)
  expect_length(h, 1)
  rows <- sec[(h + 2):(h + 1 + nrow(sk))]
  cells <- strsplit(sub("^\\|\\s*", "", sub("\\s*\\|\\s*$", "", rows)), "\\s*\\|\\s*")
  sk_o <- sk[order(sk$w1 == "too_few_pairs", sk$w1 == "indistinguishable"), ]
  verdict <- c(step_overstated = "step overstated", indistinguishable = "indistinguishable",
               too_few_pairs = "too few pairs")
  for (r in seq_along(cells)) {
    x <- cells[[r]]
    k <- sk_o[r, ]
    expect_identical(x[1], sprintf("`%s` %d", k$film_roll, k$flying_height))
    expect_identical(x[2], sprintf("%d (%d)", k$pairs, k$pairs_matched))
    if (k$pairs_used >= 3) {
      expect_identical(x[3:4], f3(c(k$p_img, k$p_nominal)), info = k$film_roll)
    }
    expect_identical(x[5], unname(verdict[k$w1]), info = k$film_roll)
    expect_identical(x[6], as.character(k$frames_nonpositive), info = k$film_roll)
  }

  so <- sk[sk$w1 == "step_overstated", ]
  ind <- sk[sk$w1 == "indistinguishable", ]
  mis <- sk$location == "misplaced"
  n70 <- p[p$set == "key" & p$film_roll == "bc77070" & p$frame %in% 268:271, ]
  neg <- p[p$set == "negative", ]
  wr <- p[p$set == "written", ]
  w <- extdata("flying_height_image_overlap_written.csv")
  wk <- merge(aggregate(p_calc ~ film_roll, wr[wr$status == "matched", ], stats::median), w,
              by = "film_roll")
  pos <- p[p$set == "positive", ]
  syn <- extdata("flying_height_image_overlap_synthetic.csv")
  # Pairs of the five, and the strip each reaches (`place` is empty where no strip holds both frames).
  ks5 <- paste(so$film_roll, so$flying_height, so$focal_length, so$scale_n)
  st_all <- extdata("flying_height_image_overlap_strips.csv")
  p5 <- p[p$set == "key" & p$key %in% ks5, ]
  st5 <- st_all[st_all$key %in% ks5, ]
  expect_identical(paste(st5$key, st5$frame), paste(p5$key, p5$frame))
  sm <- p5$status == "matched" & !p5$line_break
  claims <- c(
    sprintf("overlap %s to %s,", sprintf("%.2f", min(so$p_img)), sprintf("%.2f", max(so$p_img))),
    sprintf("implies %s to %s at nominal", sprintf("%.2f", min(so$p_nominal)),
            sprintf("%.2f", max(so$p_nominal))),
    sprintf("%.1f to %.1f times the air base", min(so$k), max(so$k)),
    sprintf("%d%% to %d%% of their pairs match", round(100 * min(so$pairs_matched / so$pairs)),
            round(100 * max(so$pairs_matched / so$pairs))),
    sprintf("on 112 frames"),
    sprintf("%d of the %d matched pairs whose strip writes a legible heading (%d matched; a strip reaches %d)",
            sum(so$dir_agree), sum(so$dir_agree + so$dir_reverse + so$dir_differ),
            sum(sm), sum(sm & !is.na(st5$place))),
    sprintf("x%.2f to x%.2f the air base (`exp(-D_agl)`)", min(exp(-so$D_agl)), max(exp(-so$D_agl))),
    sprintf("by at least x%.2f to x%.2f under any height", min(exp(-so$D_agl)), max(exp(-so$D_agl))),
    sprintf("passes by %.3f.** Its `D_agl` is %s against tau %s",
            -so$D_agl[so$film_roll == "bc77070"] - tt$tau, f3(so$D_agl[so$film_roll == "bc77070"]),
            f3(tt$tau)),
    sprintf("The images read %s and %s, and the catalogue step gives %s and %s", f3(ind$p_img[1]),
            f3(ind$p_img[2]), f3(ind$p_nominal[1]), f3(ind$p_nominal[2])),
    sprintf("%s and %s apart in D, against 2 tau = %s", f3(ind$gap[1]), f3(ind$gap[2]),
            sprintf("%.2f", 2 * tt$tau)),
    sprintf("median D %s; tau, the 95th percentile of \\|D\\|, %s", f3(tt$median), f3(tt$tau)),
    sprintf("Of %d ordinary pairs, %d of the %d compared did not match, and %d had no thumbnail",
            nrow(neg), sum(neg$status == "no_match"), sum(neg$status != "no_thumbnail"),
            sum(neg$status == "no_thumbnail")),
    sprintf("| %d of %d compared matched (%d drawn, %d with no thumbnail) |",
            sum(p$set == "unrelated" & p$status == "matched"),
            sum(p$set == "unrelated" & p$status != "no_thumbnail"), sum(p$set == "unrelated"),
            sum(p$set == "unrelated" & p$status == "no_thumbnail")),
    sprintf("median %s above what the page writes", f3(stats::median(wk$p_calc[wk$gated] - wk$written[wk$gated]))),
    sprintf("flagged, \\|D\\| %s", f3(abs(D_of(pos$p_calc, pos$p_nominal)))),
    sprintf("| %d of %d matched, error under 1e-4 |", sum(syn$matched & syn$p_true >= 0.35),
            sum(syn$p_true >= 0.35)),
    sprintf("the images read %s.", f3(sk$p_img[sk$film_roll == "bc77026"])),
    sprintf("the images read %s.", f3(sk$p_img[sk$film_roll == "bc80117"])),
    sprintf("The images read %s on that pair and %s to %s on its neighbours", f3(n70$p_calc[n70$frame == 271]),
            sprintf("%.2f", min(n70$p_calc[n70$frame < 271])), sprintf("%.2f", max(n70$p_calc[n70$frame < 271]))),
    sprintf("The catalogue step is %d to %d m on all of them", round(min(n70$step)),
            round(max(n70$step))),
    sprintf("\"TAHSIS\", %d km", round(sk$km_to_place[sk$film_roll == "bc7718"])),
    sprintf("\"YALE BLUFF\" is %d km", round(sk$km_to_place[sk$film_roll == "bc80117"])),
    sprintf("are %d to %d km from their places", round(min(sk$km_to_place[mis])),
            round(max(sk$km_to_place[mis])))
  )
  for (s in claims) expect_true(grepl(s, prose, fixed = TRUE), info = s)
  expect_identical(sum(sk$frames_nonpositive[mis]), 112L)
})

test_that("the location verdict's logbook reaches 107 of its 112 frames, and the note names the other 5", {
  # The transcription is a data-raw input, not installed, so this runs only from the source tree.
  lb_path <- testthat::test_path("..", "..", "data-raw", "flying_height_logbooks.csv")
  skip_if(!file.exists(lb_path), "logbook transcription not reachable from an installed package")
  lb <- utils::read.csv(lb_path, stringsAsFactors = FALSE)
  sk <- extdata("flying_height_image_overlap_keys.csv")
  mis <- sk[sk$location == "misplaced", ]
  np <- extdata("flying_height_terrain_nonpositive.csv")
  np <- np[paste(np$film_roll, np$flying_height, np$focal_length, np$scale_n) %in%
             paste(mis$film_roll, mis$flying_height, mis$focal_length, mis$scale_n), ]
  expect_identical(nrow(np), 112L)
  reached <- vapply(seq_len(nrow(np)), function(i) {
    any(lb$film_roll == np$film_roll[i] & !is.na(lb$frame_from) & !is.na(lb$height_ft_interpreted) &
          np$frame_number[i] >= lb$frame_from & np$frame_number[i] <= lb$frame_to)
  }, logical(1))
  expect_identical(sum(reached), 107L)
  expect_identical(paste(np$film_roll[!reached], np$frame_number[!reached]),
                   c("bc77026 221", "bc77026 222", "bc77026 237", "bc77026 247", "bc77072 225"))
  note <- system.file("notes", "terrain-correction.md", package = "fly", mustWork = TRUE)
  prose <- gsub("\\s+", " ", paste(readLines(note), collapse = " "))
  expect_true(grepl("107 of the 112 frames at `r <= 0` are not over the", prose, fixed = TRUE))
  expect_true(grepl("(`bc77026` 221, 222, 237 and 247", prose, fixed = TRUE))
})
