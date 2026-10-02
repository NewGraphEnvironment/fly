# The film rotation calibrator (fly#53). The rule it applies was pre-registered before any
# thumbnail was read — `planning/archive/*issue-53*/findings.md` — and these tests pin each
# clause of it, so a change to the rule has to disagree with a test rather than drift.

# A synthetic roll in BC Albers: legs joined by leg-change jumps, the way the catalogue
# interpolates centroids along a pre-1990s line.
synthetic_roll <- function(legs, roll = "bcx001", start = c(1200000, 1000000),
                           spacing = 1000, jump = 12000) {
  xy <- matrix(numeric(0), ncol = 2)
  here <- start
  for (k in seq_along(legs)) {
    b <- legs[[k]]$bearing * pi / 180
    n <- legs[[k]]$n
    step <- c(sin(b), cos(b)) * spacing
    pts <- t(vapply(0:(n - 1), function(i) here + i * step, numeric(2)))
    xy <- rbind(xy, pts)
    here <- pts[n, ] + c(jump, jump / 3)
  }
  data.frame(film_roll = roll, frame_number = seq_len(nrow(xy)), x = xy[, 1], y = xy[, 2])
}

test_that("legs split on the leg-change jump, and runs of 6+ qualify on any bearing", {
  r <- synthetic_roll(list(list(bearing = 45, n = 8), list(bearing = 225, n = 8),
                           list(bearing = 2, n = 8), list(bearing = 130, n = 4)))
  legs <- fly_rotation_legs(r$film_roll, r$frame_number, r$x, r$y)

  long <- legs[legs$n_frames >= 6, ]
  expect_equal(long$first_frame, c(1, 9, 17))
  expect_equal(long$last_frame,  c(8, 16, 24))
  expect_equal(round(long$bearing), c(45, 225, 2))
  # Cardinal legs qualify (fly#53 amendment 1): measured, they decide or abstain, never wrong.
  expect_equal(long$qualifying, c(TRUE, TRUE, TRUE))
  # The 4-frame leg is found and does not qualify, rather than being merged into a neighbour.
  short <- legs[legs$first_frame == 25, ]
  expect_equal(short$n_frames, 4)
  expect_false(short$qualifying)
})

test_that("a gap in frame numbers ends a leg even on a straight line", {
  r <- synthetic_roll(list(list(bearing = 60, n = 14)))
  r <- r[r$frame_number != 7, ]
  legs <- fly_rotation_legs(r$film_roll, r$frame_number, r$x, r$y)
  expect_equal(legs$first_frame, c(1, 8))
  expect_equal(legs$last_frame,  c(6, 14))
  expect_equal(legs$qualifying, c(TRUE, TRUE))
})

test_that("a spacing jump on an unchanged bearing still ends the leg", {
  # Two parallel lines flown the same way, joined by a step along the line: bearing alone
  # cannot separate them.
  r <- synthetic_roll(list(list(bearing = 60, n = 8), list(bearing = 60, n = 8)), jump = 0)
  b <- 60 * pi / 180
  r$x[9:16] <- r$x[9:16] + sin(b) * 9000
  r$y[9:16] <- r$y[9:16] + cos(b) * 9000
  legs <- fly_rotation_legs(r$film_roll, r$frame_number, r$x, r$y)
  long <- legs[legs$n_frames >= 6, ]
  expect_equal(long$first_frame, c(1, 9))
})

test_that("frames catalogued at one point do not make a leg pointing north", {
  # `atan2(0, 0)` is 0 (code-check round 4): five coincident frames inside a line would
  # otherwise be a 5-step "leg" at bearing 0.
  r <- synthetic_roll(list(list(bearing = 60, n = 8)))
  r <- rbind(r, data.frame(film_roll = "bcx001", frame_number = 9:15, x = r$x[8], y = r$y[8]))
  legs <- fly_rotation_legs(r$film_roll, r$frame_number, r$x, r$y)
  expect_equal(legs$first_frame, 1)
  expect_equal(legs$last_frame, 8)
})

test_that("rolls are separated even when their frame numbers continue", {
  a <- synthetic_roll(list(list(bearing = 45, n = 7)), roll = "bcx001")
  b <- synthetic_roll(list(list(bearing = 45, n = 7)), roll = "bcx002")
  b$frame_number <- b$frame_number + 7
  r <- rbind(a, b)
  legs <- fly_rotation_legs(r$film_roll, r$frame_number, r$x, r$y)
  expect_equal(legs$film_roll, c("bcx001", "bcx002"))
  expect_equal(legs$n_frames, c(7, 7))
})

test_that("legs come back in input-independent order", {
  r <- synthetic_roll(list(list(bearing = 45, n = 8), list(bearing = 225, n = 8)))
  s <- r[rev(seq_len(nrow(r))), ]
  expect_equal(fly_rotation_legs(r$film_roll, r$frame_number, r$x, r$y),
               fly_rotation_legs(s$film_roll, s$frame_number, s$x, s$y))
})


# Leg verdict ---------------------------------------------------------------------------

scores_with_wins <- function(n, wins, best = 2L) {
  # n pairs; the `best` column beats every other column on exactly `wins` pairs and by a
  # wide margin on average.
  m <- matrix(0.1, n, 4, dimnames = list(NULL, c("0", "90", "180", "270")))
  m[, best] <- 0.6
  if (wins < n) m[seq_len(n - wins), best] <- 0.05
  m
}

test_that("a leg is decisive only when the sign test clears 0.05 against every rival", {
  # The thresholds written into the pre-registration.
  need <- c(`5` = 5, `6` = 6, `7` = 7, `8` = 7, `9` = 8, `10` = 9)
  for (n in names(need)) {
    k <- need[[n]]
    n <- as.integer(n)
    expect_true(fly_rotation_verdict(scores_with_wins(n, k))$decisive, info = paste(n, k))
    expect_false(fly_rotation_verdict(scores_with_wins(n, k - 1))$decisive,
                 info = paste(n, k - 1))
  }
  # Under five pairs nothing is decisive, however clean.
  expect_false(fly_rotation_verdict(scores_with_wins(4, 4))$decisive)
})

test_that("the verdict is the best mean, and the margin is best minus runner-up", {
  v <- fly_rotation_verdict(scores_with_wins(10, 10, best = 4L))
  expect_equal(v$rotation, 270L)
  expect_equal(v$margin, 0.5)
})

test_that("a refused rotation does not compete, and is not a rival", {
  m <- scores_with_wins(10, 10, best = 1L)
  m[, 2] <- NA                      # stretch guard refused 90
  v <- fly_rotation_verdict(m, refused = c(FALSE, TRUE, FALSE, FALSE))
  expect_equal(v$rotation, 0L)
  expect_true(v$decisive)
  expect_equal(v$margin, 0.5)
})

test_that("a rotation that warped but scored no pair is a rival, not a refusal", {
  # The same all-NA column, not refused: a rival the winner was never tested against, so
  # the leg cannot be decisive (code-check round 3 — it shipped before this).
  m <- scores_with_wins(10, 10, best = 1L)
  m[, 3:4] <- NA
  expect_false(fly_rotation_verdict(m)$decisive)
  expect_true(fly_rotation_verdict(m, refused = c(FALSE, FALSE, TRUE, TRUE))$decisive)
})

test_that("a leg is scorable only if some rotation shares 5 pairs with every rival", {
  full <- scores_with_wins(10, 10, best = 1L)
  none <- rep(FALSE, 4)
  expect_true(fly_rotation_could_decide(full, none))
  # (a) a competing rotation with only 3 finite pairs: nothing can be tested against it.
  a <- full
  a[4:10, 3] <- NA
  expect_false(fly_rotation_could_decide(a, none))
  expect_true(fly_rotation_could_decide(a, c(FALSE, FALSE, TRUE, FALSE)))
  # (b) two rotations with 5 finite pairs each, sharing 4.
  b <- matrix(NA_real_, 10, 4)
  b[1:5, 1] <- 0.6
  b[2:6, 2] <- 0.1
  expect_false(fly_rotation_could_decide(b, c(FALSE, FALSE, TRUE, TRUE)))
  # One competing rotation is nothing to decide between.
  expect_false(fly_rotation_could_decide(full, c(FALSE, TRUE, TRUE, TRUE)))
})

test_that("a pair NA under the winner or a rival does not count either way", {
  m <- scores_with_wins(10, 10, best = 1L)
  m[1:6, 3] <- NA                   # 180 has only 4 finite pairs beside the winner
  expect_false(fly_rotation_verdict(m)$decisive)
})

test_that("a leg with every rotation refused has no verdict", {
  m <- matrix(NA_real_, 10, 4, dimnames = list(NULL, c("0", "90", "180", "270")))
  v <- fly_rotation_verdict(m)
  expect_true(is.na(v$rotation))
  expect_false(v$decisive)
})


# Roll state ----------------------------------------------------------------------------

leg_rows <- function(status = "scored", decisive = TRUE, rotation = 90L, bearing = 45) {
  n <- max(length(status), length(decisive), length(rotation), length(bearing))
  data.frame(status = rep_len(status, n), decisive = rep_len(decisive, n),
             rotation = rep_len(as.integer(rotation), n), bearing = rep_len(bearing, n))
}

test_that("every roll state is reachable, each by its own route", {
  st <- function(l) fly_rotation_roll_state(l)$state
  expect_equal(st(leg_rows(bearing = c(45, 225))), "shipped")
  expect_equal(st(leg_rows(rotation = c(90, 0), bearing = c(45, 225))), "legs_disagree")
  expect_equal(st(leg_rows(bearing = c(45, 120))), "single_direction")
  expect_equal(st(leg_rows(decisive = c(TRUE, FALSE), bearing = c(45, 225))),
               "one_decisive_leg")
  expect_equal(st(leg_rows(decisive = FALSE, bearing = c(45, 225))), "no_decisive_leg")
  expect_equal(st(leg_rows(status = "thumbnails_unavailable", decisive = FALSE,
                           rotation = NA, bearing = c(45, 225))), "thumbnails_unavailable")
  expect_equal(st(leg_rows()[0, ]), "no_qualifying_leg")
  for (s in c("not_rotated", "refused", "warp_failed", "too_little_overlap", "not_scored")) {
    expect_equal(st(leg_rows(status = s, decisive = FALSE, rotation = NA,
                             bearing = c(45, 225))), "legs_unscorable", info = s)
  }
  # Thumbnails outrank the other unscorable reasons; a scored leg outranks both.
  expect_equal(st(leg_rows(status = c("thumbnails_unavailable", "not_rotated"),
                           decisive = FALSE, rotation = NA, bearing = c(45, 225))),
               "thumbnails_unavailable")
  expect_equal(st(leg_rows(status = c("scored", "warp_failed"), decisive = FALSE,
                           bearing = c(45, 225))), "no_decisive_leg")
})

test_that("only a shipped roll carries a rotation", {
  expect_equal(fly_rotation_roll_state(leg_rows(bearing = c(45, 225)))$rotation, 90L)
  expect_true(is.na(fly_rotation_roll_state(leg_rows(bearing = c(45, 120)))$rotation))
  disagree <- leg_rows(rotation = c(90, 0), bearing = c(45, 225))
  expect_true(is.na(fly_rotation_roll_state(disagree)$rotation))
})

test_that("disagreement outranks agreement, whatever else agrees", {
  # Three decisive legs agree on two bearings 180 apart; one more disagrees. Shipping the
  # majority would ship a value the roll has itself contradicted.
  l <- leg_rows(rotation = c(90, 90, 90, 0), bearing = c(45, 225, 50, 230))
  expect_equal(fly_rotation_roll_state(l)$state, "legs_disagree")
})

test_that("separation is 90 degrees, measured circularly", {
  st <- function(b) fly_rotation_roll_state(leg_rows(bearing = b))$state
  expect_equal(st(c(350, 80)), "shipped")          # 90 apart across north
  expect_equal(st(c(350, 79)), "single_direction")
  expect_equal(st(c(10, 190)), "shipped")          # a reverse leg
  # 30 apart is not enough: a geographic roll agrees with itself there two times in three.
  expect_equal(st(c(45, 75)), "single_direction")
})

test_that("a leg that was not decisive does not count toward the spread", {
  l <- leg_rows(decisive = c(TRUE, TRUE, FALSE), bearing = c(45, 100, 225))
  expect_equal(fly_rotation_roll_state(l)$state, "single_direction")
})


# End to end, scorer mocked ---------------------------------------------------------------

# Catalogue-shaped film rows for a synthetic roll, in lon/lat like the catalogue.
synthetic_catalogue <- function(r) {
  pts <- sf::st_as_sf(r, coords = c("x", "y"), crs = 3005)
  pts <- sf::st_transform(pts, 4326)
  pts$airp_id <- seq_len(nrow(pts))
  pts$scale <- "1:12000"
  pts$media <- "Film - BW"
  pts$focal_length <- 153
  pts$photo_year <- 1975L
  pts$thumbnail_image_url <- paste0("https://example.invalid/", pts$airp_id, ".jpg")
  pts
}

test_that("fly_rotation_calibrate() applies the rule per roll and scores only qualifying legs", {
  skip_if_no_terra()
  r <- rbind(
    synthetic_roll(list(list(bearing = 45, n = 8), list(bearing = 225, n = 8),
                        list(bearing = 0, n = 8)), roll = "bcx001"),
    synthetic_roll(list(list(bearing = 45, n = 8), list(bearing = 225, n = 8)),
                   roll = "bcx002", start = c(1300000, 1000000))
  )
  photos <- synthetic_catalogue(r)

  scored <- list()
  local_mocked_bindings(
    fly_rotation_score_leg = function(pts, dest_dir, mask, mask_threshold) {
      scored[[length(scored) + 1]] <<- sort(pts$frame_number)
      # bcx001 agrees on 90, bcx002 disagrees with itself.
      best <- if (pts$film_roll[1] == "bcx002" && min(pts$frame_number) > 8) 1L else 2L
      list(status = "scored", scores = scores_with_wins(nrow(pts) - 1, nrow(pts) - 1, best),
           warnings = 0L, frames = sort(pts$frame_number))
    }
  )
  out <- fly_rotation_calibrate(photos, dest_dir = tempfile())

  expect_equal(out$film_roll, c("bcx001", "bcx002"))
  expect_equal(out$state, c("shipped", "legs_disagree"))
  expect_equal(out$rotation, c(90L, NA))
  # The cardinal leg qualifies and is scored like any other.
  expect_equal(out$legs_found, c(3L, 2L))
  expect_equal(out$legs_qualifying, c(3L, 2L))
  expect_length(scored, 5)
  expect_equal(scored[[1]], 1:8)
  expect_equal(out$legs[[1]]$segment, rep("1:12000 / NA", 3))
  # Every scored pair is returned, keyed by its leg and frames.
  p <- out$pairs[[1]]
  expect_equal(nrow(p), 3 * 7)
  expect_equal(p$frame_a[p$first_frame == 1], 1:7)
  expect_equal(p$frame_b[p$first_frame == 1], 2:8)
  expect_s3_class(out$legs[[1]], "data.frame")
  expect_true(all(c("first_frame", "last_frame", "bearing", "status", "rotation",
                    "decisive", "margin", "pairs", "score_0", "score_90", "score_180",
                    "score_270") %in% names(out$legs[[1]])))
})

test_that("a roll with no qualifying leg is reported, not dropped", {
  skip_if_no_terra()
  r <- synthetic_roll(list(list(bearing = 45, n = 5), list(bearing = 225, n = 5)))
  local_mocked_bindings(fly_rotation_score_leg = function(...) stop("must not be called"))
  out <- fly_rotation_calibrate(synthetic_catalogue(r), dest_dir = tempfile())
  expect_equal(out$state, "no_qualifying_leg")
  expect_true(is.na(out$rotation))
})

test_that("a long leg is scored on its central 11 frames and legs are capped per roll", {
  skip_if_no_terra()
  r <- synthetic_roll(list(list(bearing = 45, n = 20), list(bearing = 225, n = 7),
                           list(bearing = 135, n = 9)))
  scored <- list()
  local_mocked_bindings(
    fly_rotation_score_leg = function(pts, ...) {
      scored[[length(scored) + 1]] <<- sort(pts$frame_number)
      list(status = "scored", scores = scores_with_wins(nrow(pts) - 1, nrow(pts) - 1),
           warnings = 0L, frames = sort(pts$frame_number))
    }
  )
  out <- fly_rotation_calibrate(synthetic_catalogue(r), dest_dir = tempfile(), max_legs = 2)
  # The two LONGEST legs, the 20-frame one cut to its middle 11.
  expect_equal(scored[[1]], 5:15)
  expect_equal(scored[[2]], 28:36)
  expect_equal(out$legs_qualifying, 3L)
  # The leg left unscored is still listed, so nothing found is silently dropped.
  expect_equal(out$legs[[1]]$status, c("scored", "scored", "not_scored"))
})

test_that("calibration joins straight onto a rotation column", {
  skip_if_no_terra()
  r <- synthetic_roll(list(list(bearing = 45, n = 8), list(bearing = 225, n = 8)))
  photos <- synthetic_catalogue(r)
  local_mocked_bindings(
    fly_rotation_score_leg = function(pts, ...) {
      list(status = "scored", scores = scores_with_wins(nrow(pts) - 1, nrow(pts) - 1, 3L),
           warnings = 0L, frames = sort(pts$frame_number))
    }
  )
  cal <- fly_rotation_calibrate(photos, dest_dir = tempfile())
  photos$rotation <- cal$rotation[match(photos$film_roll, cal$film_roll)]
  expect_equal(unique(photos$rotation), 180L)
})

test_that("digital frames are refused, since they have a measured constant", {
  skip_if_no_terra()
  d <- digital_fixture()
  d$thumbnail_image_url <- paste0("https://example.invalid/", d$airp_id, ".jpg")
  local_mocked_bindings(fly_rotation_score_leg = function(...) stop("must not be called"))
  expect_error(fly_rotation_calibrate(d, dest_dir = tempfile()), "film")
})

test_that("non-POINT input is refused by name", {
  skip_if_no_terra()
  r <- synthetic_catalogue(synthetic_roll(list(list(bearing = 45, n = 8))))
  polys <- sf::st_buffer(sf::st_transform(r, 3005), 10)
  expect_error(fly_rotation_calibrate(polys, dest_dir = tempfile()), "photos_sf")
})

test_that("missing columns are named", {
  skip_if_no_terra()
  r <- synthetic_catalogue(synthetic_roll(list(list(bearing = 45, n = 8))))
  r$thumbnail_image_url <- NULL
  expect_error(fly_rotation_calibrate(r, dest_dir = tempfile()), "thumbnail_image_url")
})

test_that("a missing terra is named rather than failing inside a warp", {
  r <- synthetic_catalogue(synthetic_roll(list(list(bearing = 45, n = 8))))
  local_mocked_bindings(check_installed = function(pkg, ...) stop("needs ", pkg),
                        .package = "rlang")
  expect_error(fly_rotation_calibrate(r, dest_dir = tempfile()), "needs terra")
})

test_that("input whose rolls are all NA returns typed columns, not a 0 x 0 tibble", {
  skip_if_no_terra()
  r <- synthetic_catalogue(synthetic_roll(list(list(bearing = 45, n = 8))))
  r$film_roll <- NA_character_
  out <- fly_rotation_calibrate(r, dest_dir = tempfile())
  expect_equal(nrow(out), 0)
  expect_type(out$rotation, "integer")
  expect_type(out$state, "character")
})

test_that("every caller shape gives the same answer, the catalogue's tibble included", {
  skip_if_no_terra()
  plain <- synthetic_catalogue(synthetic_roll(list(list(bearing = 45, n = 8),
                                                   list(bearing = 225, n = 8))))
  tbl <- sf::st_as_sf(dplyr::as_tibble(plain))
  bcdc <- tbl
  class(bcdc) <- c("bcdc_sf", class(bcdc))
  shapes <- list(plain = plain, tbl = tbl, grouped = dplyr::group_by(tbl, .data$scale),
                 bcdc = bcdc)
  local_mocked_bindings(
    fly_rotation_score_leg = function(pts, ...) {
      list(status = "scored", scores = scores_with_wins(nrow(pts) - 1, nrow(pts) - 1, 4L),
           warnings = 0L, frames = sort(pts$frame_number))
    }
  )
  got <- lapply(shapes, function(x) fly_rotation_calibrate(x, dest_dir = tempfile()))
  for (nm in names(got)) {
    expect_equal(got[[nm]]$rotation, 270L, info = nm)
    expect_equal(got[[nm]]$legs[[1]], got$plain$legs[[1]], info = nm)
  }
})


# The leg scorer, with GDAL and the network mocked ---------------------------------------

score_fixture <- function() {
  r <- synthetic_catalogue(synthetic_roll(list(list(bearing = 45, n = 6))))
  thumbs <- file.path(tempdir(), paste0("score_", r$airp_id, ".jpg"))
  for (f in thumbs) writeLines("x", f)
  list(pts = r, thumbs = thumbs)
}

test_that("a rerun never warps into a stale output", {
  # gdalwarp writes INTO an existing destination and keeps its grid (code-check round 1).
  skip_if_no_terra()
  fx <- score_fixture()
  dir <- tempfile()
  stale <- 0L
  local_mocked_bindings(
    fly_fetch = function(photos_sf, ...) {
      dplyr::tibble(airp_id = photos_sf$airp_id, dest = fx$thumbs, success = TRUE)
    },
    georef_one = function(src, fp, out_file, ...) {
      if (file.exists(out_file)) stale <<- stale + 1L
      writeLines("tif", out_file)
      TRUE
    },
    fly_rotation_pair_r = function(a, b, ...) 0.5
  )
  fly_rotation_score_leg(fx$pts, dir, "border", fly_mask_threshold())
  res <- fly_rotation_score_leg(fx$pts, dir, "border", fly_mask_threshold())
  expect_equal(stale, 0L)
  expect_equal(res$status, "scored")
  expect_equal(res$frames, 1:6)
})

test_that("a stretch refusal drops a rotation; any other failure fails the leg", {
  skip_if_no_terra()
  fx <- score_fixture()
  run <- function(georef, pair_r = function(a, b, ...) 0.5) {
    local_mocked_bindings(
      fly_fetch = function(photos_sf, ...) {
        dplyr::tibble(airp_id = photos_sf$airp_id, dest = fx$thumbs, success = TRUE)
      },
      georef_one = georef,
      fly_rotation_pair_r = pair_r
    )
    fly_rotation_score_leg(fx$pts, tempfile(), "border", fly_mask_threshold())
  }
  refuse_odd <- function(src, fp, out_file, rotation, ...) {
    if (rotation %in% c(90L, 270L)) {
      warning("x: image is 1:1 but the corner mapping would stretch it by 1.2x.")
      return(FALSE)
    }
    writeLines("tif", out_file)
    TRUE
  }
  res <- run(refuse_odd)
  expect_equal(res$status, "scored")
  expect_equal(res$refused, c(`0` = FALSE, `90` = TRUE, `180` = FALSE, `270` = TRUE))
  # And the leg row records them, so a verdict can be recomputed from shipped scores.
  leg <- data.frame(first_frame = 1, last_frame = 6, n_frames = 6L, bearing = 45)
  expect_equal(fly_rotation_leg_row(leg, res)$refused, "90;270")

  refuse_all <- function(src, fp, out_file, ...) {
    warning("x: image is 1:1 but the corner mapping would stretch it by 1.2x.")
    FALSE
  }
  expect_equal(run(refuse_all)$status, "refused")

  # Pairs that share too little ground are NA; a leg left without two rotations of 5 finite
  # pairs could never be decisive, so it is not `scored` (code-check round 2).
  ok <- function(src, fp, out_file, ...) {
    writeLines("tif", out_file)
    TRUE
  }
  thin <- run(ok, function(a, b, ...) NA_real_)
  expect_equal(thin$status, "too_little_overlap")
  # Its scores are kept and shipped, so the gate is recomputed rather than trusted.
  leg <- data.frame(first_frame = 1, last_frame = 6, n_frames = 6L, bearing = 45)
  expect_equal(nrow(fly_rotation_pair_rows(leg, thin)), 5)
  expect_false(fly_rotation_could_decide(thin$scores, thin$refused))
  one_na <- function(a, b, ...) if (grepl("/1\\.tif$", a)) NA_real_ else 0.5
  expect_equal(run(ok, one_na)$status, "too_little_overlap")     # 4 of 5 pairs left
  expect_equal(run(ok)$status, "scored")

  # FALSE with no stretch warning, and an error, are failures — not refusals.
  expect_equal(run(function(...) FALSE)$status, "warp_failed")
  expect_equal(run(function(...) stop("GDAL could not open"))$status, "warp_failed")
})

test_that("missing thumbnails and an unrotated frame are their own statuses", {
  skip_if_no_terra()
  fx <- score_fixture()
  local_mocked_bindings(
    fly_fetch = function(photos_sf, ...) {
      dplyr::tibble(airp_id = photos_sf$airp_id, dest = fx$thumbs,
                    success = c(FALSE, rep(TRUE, nrow(photos_sf) - 1)))
    }
  )
  expect_equal(fly_rotation_score_leg(fx$pts, tempfile(), "border",
                                      fly_mask_threshold())$status,
               "thumbnails_unavailable")
  # A lone frame has no adjacent neighbour, so it is drawn unrotated.
  lone <- fx$pts[c(1, 3), ]
  expect_equal(fly_rotation_score_leg(lone, tempfile(), "border",
                                      fly_mask_threshold())$status, "not_rotated")
})
