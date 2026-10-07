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
