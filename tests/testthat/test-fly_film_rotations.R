# The shipped film rotation table and its ledger (fly#53), held to the rule that produced
# them. Both are written by `data-raw/georef_calibrate-film_rotations.R`; nothing here
# trusts them — every shipped verdict and state is recomputed from the shipped pair scores.

# `refused` as character: a column whose only values are single rotations ("90") would
# otherwise be typed integer, and an all-empty one logical (code-check round 4).
extdata <- function(f) {
  path <- system.file("extdata", f, package = "fly", mustWork = TRUE)
  if (f == "film_rotations_legs.csv") {
    return(utils::read.csv(path, stringsAsFactors = FALSE,
                           colClasses = c(refused = "character")))
  }
  utils::read.csv(path, stringsAsFactors = FALSE)
}

parse_refused <- function(r) {
  if (is.na(r) || !nzchar(r)) return(rep(FALSE, 4))
  c(0, 90, 180, 270) %in% as.numeric(strsplit(r, ";")[[1]])
}

test_that("the shipped table is keyed once per roll and carries only quarter turns", {
  tab <- fly_film_rotation_table()
  expect_gt(nrow(tab), 0)
  expect_false(anyDuplicated(tab$film_roll) > 0)
  expect_true(all(tab$rotation %in% c(0L, 90L, 180L, 270L)))
  expect_true(all(tab$legs >= 2))
  expect_true(all(nzchar(tab$bearings) & nzchar(tab$frames) & nzchar(tab$measured)))
})

test_that("every film roll in the snapshot is in exactly one of the two tables", {
  tab <- fly_film_rotation_table()
  led <- fly_film_rotation_ledger()
  pop <- extdata("film_rotations_population.csv")
  expect_false(anyDuplicated(led$film_roll) > 0)
  expect_length(intersect(tab$film_roll, led$film_roll), 0)
  # Coverage, against counts taken from the cache when the ledger was built.
  expect_equal(nrow(tab) + nrow(led), sum(pop$rolls))
  expect_equal(nrow(tab) + sum(led$measured), sum(pop$drawn))
  expect_true(all(sub("[0-9].*$", "", c(tab$film_roll, led$film_roll)) %in% pop$series))
})

test_that("every ledger state is one the refusal warning can explain", {
  led <- fly_film_rotation_ledger()
  expect_true(all(led$state %in% names(fly_film_rotation_states())))
  # An unmeasured roll never carries a state only measurement can reach, and vice versa.
  from_cache <- c("no_qualifying_leg", "one_qualifying_leg", "single_direction", "not_sampled")
  expect_true(all(led$state[!led$measured] %in% from_cache))
  expect_false(any(led$state[led$measured] %in% c("one_qualifying_leg", "not_sampled")))
})

test_that("every leg verdict is recomputed from the shipped pair scores", {
  legs <- extdata("film_rotations_legs.csv")
  pairs <- extdata("film_rotations_pairs.csv")
  cols <- c("score_0", "score_90", "score_180", "score_270")
  scored <- legs[legs$status == "scored", ]
  expect_gt(nrow(scored), 0)
  for (i in seq_len(nrow(scored))) {
    p <- pairs[pairs$film_roll == scored$film_roll[i] &
                 pairs$first_frame == scored$first_frame[i], cols]
    v <- fly_rotation_verdict(as.matrix(p), parse_refused(scored$refused[i]))
    lab <- paste(scored$film_roll[i], scored$first_frame[i])
    expect_equal(v$rotation, scored$rotation[i], info = lab)
    expect_equal(v$decisive, scored$decisive[i], info = lab)
    expect_equal(v$margin, scored$margin[i], tolerance = 1e-9, info = lab)
  }
  # Pairs ship for exactly the legs that were warped and scored.
  warped <- legs[legs$status %in% c("scored", "too_little_overlap"), ]
  expect_setequal(unique(paste(pairs$film_roll, pairs$first_frame)),
                  paste(warped$film_roll, warped$first_frame))
})

test_that("the split between `scored` and `too_little_overlap` is recomputed, not trusted", {
  # A decisive leg wrongly gated out could turn `legs_disagree` into `shipped`.
  legs <- extdata("film_rotations_legs.csv")
  pairs <- extdata("film_rotations_pairs.csv")
  cols <- c("score_0", "score_90", "score_180", "score_270")
  warped <- legs[legs$status %in% c("scored", "too_little_overlap"), ]
  for (i in seq_len(nrow(warped))) {
    p <- pairs[pairs$film_roll == warped$film_roll[i] &
                 pairs$first_frame == warped$first_frame[i], cols]
    expect_equal(fly_rotation_could_decide(as.matrix(p), parse_refused(warped$refused[i])),
                 warped$status[i] == "scored",
                 info = paste(warped$film_roll[i], warped$first_frame[i]))
  }
})

test_that("every measured roll's state is recomputed from its legs", {
  legs <- extdata("film_rotations_legs.csv")
  tab <- fly_film_rotation_table()
  led <- fly_film_rotation_ledger()
  measured <- c(tab$film_roll, led$film_roll[led$measured])
  for (r in measured) {
    l <- legs[legs$film_roll == r, ]
    st <- fly_rotation_roll_state(l)
    if (r %in% tab$film_roll) {
      expect_equal(st$state, "shipped", info = r)
      expect_equal(st$rotation, tab$rotation[tab$film_roll == r], info = r)
    } else {
      expect_equal(st$state, led$state[led$film_roll == r], info = r)
    }
  }
})

test_that("a shipped row's provenance matches its decisive legs", {
  legs <- extdata("film_rotations_legs.csv")
  tab <- fly_film_rotation_table()
  for (i in seq_len(nrow(tab))) {
    l <- legs[legs$film_roll == tab$film_roll[i] & legs$status == "scored" & legs$decisive, ]
    expect_equal(nrow(l), tab$legs[i], info = tab$film_roll[i])
    expect_equal(paste(l$first_frame, l$last_frame, sep = "-", collapse = ";"),
                 tab$frames[i], info = tab$film_roll[i])
    expect_true(all(l$rotation == tab$rotation[i]), info = tab$film_roll[i])
  }
})
