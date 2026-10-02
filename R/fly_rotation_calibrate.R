#' Measure a film roll's corner mapping from its own overlapping frames
#'
#' A film footprint is a square rotated onto its flight line, and which corner of the
#' scanned image belongs on which corner of that square is a property of the **roll**,
#' not of film: fly#26 measured 0 on bc5282 (1968) and 90 on bc83062 (1983). So
#' [fly_georef()] refuses a rotated film frame unless the roll's rotation is known, either
#' from the measured table it ships or from a `rotation` column. This function produces
#' that column for a roll the table does not cover, by the same measurement and the same
#' rule that built the table.
#'
#' @param photos_sf Catalogue centroids for one or more film rolls, as POINT geometry with
#'   the columns [fly_footprint()] needs plus `film_roll`, `frame_number` and
#'   `thumbnail_image_url`. Pass whole rolls, or at least whole flight lines: legs are
#'   found from frames adjacent by `frame_number`, so a sample of a roll finds none.
#' @param dest_dir Directory the thumbnails and the trial GeoTIFFs are written to.
#' @param max_legs Most legs scored per roll, chosen as the longest. Every leg found is
#'   still reported.
#' @param mask,mask_threshold Passed to the warp exactly as [fly_georef()] uses them, so the
#'   verdict is for the output a caller actually gets.
#' @return A tibble with one row per roll: `film_roll`; `rotation`, the measured value or
#'   `NA`; `state`, why; `legs_found` and `legs_qualifying`; `legs`, a list-column with
#'   one row per qualifying leg carrying its frames, bearing, segment, status, verdict,
#'   margin, number of scored pairs and the mean overlap correlation at each rotation; and
#'   `pairs`, a list-column with every scored pair, from which each verdict can be
#'   recomputed.
#'
#' @details
#' **What is measured.** Consecutive frames on a line overlap by about 60%, so at the
#' correct rotation their common ground must agree. Each leg is georeferenced at all four
#' rotations and every adjacent pair is scored by the correlation of their common ground
#' at 25 m. No reference imagery is needed: the frames check each other. This is the
#' measurement that decided the digital mapping in fly#38.
#'
#' **What counts as a leg.** Frames joined by steps adjacent by `frame_number` whose
#' bearing stays within 10 degrees of the leg's first step and whose spacing stays within
#' a factor 1.5 of the leg's median. It **qualifies** with at least 6 frames, on any
#' bearing. A leg longer than 11 frames is scored on its central 11.
#'
#' **When a leg is decisive.** The winning rotation must beat **each** other rotation on
#' enough pairs that a one-sided sign test gives p <= 0.05: 5 of 5, 6 of 6, 7 of 7, 7 of
#' 8, 8 of 9, 9 of 10. A rotation the stretch guard refuses does not compete.
#'
#' **When a roll gets a rotation.** At least two decisive legs, all of them agreeing, two
#' of them on bearings at least 90 degrees apart. Ninety, because a roll whose scans came
#' off in a fixed *geographic* orientation would also agree with itself on two legs closer
#' than that, and the shipped value is applied on every bearing the roll flies. A reverse
#' leg counts. The states, first match wins:
#'
#' | `state` | meaning |
#' | --- | --- |
#' | `legs_disagree` | two decisive legs name different rotations |
#' | `shipped` | the rule above is met; `rotation` is set |
#' | `single_direction` | decisive legs agree, but all within 90 degrees |
#' | `one_decisive_leg` | one leg decided, which the rule does not accept alone |
#' | `no_decisive_leg` | legs were scored and none decided |
#' | `thumbnails_unavailable` | no leg scored, and at least one for want of its images |
#' | `legs_unscorable` | no leg scored for another reason (see the leg `status`) |
#' | `no_qualifying_leg` | nothing in the input meets the leg definition |
#'
#' Each leg's `status` says which: `scored` (it could have decided), `not_rotated`,
#' `thumbnails_unavailable`, `refused`, `warp_failed`, `too_little_overlap` (pairs share
#' under 500 cells at 25 m, as at 1:3000) or `not_scored`. Its `segment` is the scale and flying height
#' along it, so legs from different missions on one roll can be told apart.
#'
#' The rule was fixed before the campaign that built [fly_georef()]'s table read a single
#' thumbnail, and this function applies it unchanged. See `inst/notes/georeferencing.md`.
#'
#' **What it cannot tell you.** The verdict is for the image measured — the public
#' **thumbnail**. A full-resolution scan delivered in another orientation is not covered.
#' Nor is a scan **mirrored** about the flight line: both frames' centres sit on that axis,
#' so a mirrored pair agrees with itself exactly and overlap cannot see it.
#'
#' @seealso [fly_georef()], which consults the shipped table of measured rolls.
#'
#' @examplesIf interactive()
#' # One leg of bc5282 and one of its reverse, pulled from the catalogue.
#' roll <- bcdata::bcdc_query_geodata("WHSE_IMAGERY_AND_BASE_MAPS.AIMG_PHOTO_CENTROIDS_SP") |>
#'   bcdata::filter(FILM_ROLL == "bc5282") |>
#'   bcdata::collect()
#' names(roll) <- tolower(names(roll))
#' cal <- fly_rotation_calibrate(roll, max_legs = 2)
#' cal[, c("film_roll", "rotation", "state")]
#'
#' # Join it on, and fly_georef() uses it.
#' roll$rotation <- cal$rotation[match(roll$film_roll, cal$film_roll)]
#'
#' @export
fly_rotation_calibrate <- function(photos_sf, dest_dir = tempfile("fly_rotation_"),
                                   max_legs = 6, mask = c("border", "none"),
                                   mask_threshold = fly_mask_threshold()) {
  rlang::check_installed("terra", "to score the overlap between frames.")
  mask <- match.arg(mask)
  fly_check_points(photos_sf, "photos_sf")
  need <- c("film_roll", "frame_number")
  if (!all(need %in% names(photos_sf))) {
    stop("`photos_sf` must have `film_roll` and `frame_number` columns.", call. = FALSE)
  }

  # Film only. A non-square footprint is a digital frame, which has a measured constant
  # (`fly_digital_rotation()`) and never reaches the refusal this exists to resolve.
  fp_all <- suppressWarnings(fly_footprint(photos_sf))
  drawn <- !sf::st_is_empty(sf::st_geometry(fp_all))
  if (any(drawn & !fly_is_square(fp_all))) {
    stop("`fly_rotation_calibrate()` measures film. ",
         sum(drawn & !fly_is_square(fp_all)), " of ", nrow(photos_sf), " frames have a ",
         "non-square (digital) footprint, which `fly_georef()` maps with a measured ",
         "constant. Pass film rolls only.", call. = FALSE)
  }
  if (!"thumbnail_image_url" %in% names(photos_sf)) {
    stop("`photos_sf` must have a `thumbnail_image_url` column: the measurement is made ",
         "on the frames' own thumbnails.", call. = FALSE)
  }

  xy <- sf::st_coordinates(sf::st_transform(sf::st_geometry(photos_sf), 3005))
  frames <- suppressWarnings(as.numeric(photos_sf$frame_number))
  rolls_in <- as.character(photos_sf$film_roll)
  legs <- fly_rotation_legs(rolls_in, frames, xy[, 1], xy[, 2])

  rolls <- sort(unique(stats::na.omit(rolls_in)))
  out <- lapply(rolls, function(roll) {
    rl <- legs[legs$film_roll == roll & legs$n_frames >= fly_rotation_min_frames(), ]
    q <- rl[rl$qualifying, ]
    q <- q[order(-q$n_frames, q$first_frame), ]
    scored <- lapply(seq_len(nrow(q)), function(k) {
      row <- q[k, ]
      leg_idx <- which(rolls_in == roll & frames >= row$first_frame &
                         frames <= row$last_frame)
      res <- if (k <= max_legs) {
        keep <- fly_rotation_central(row$first_frame, row$last_frame)
        idx <- which(rolls_in == roll & frames %in% keep)
        leg_dir <- file.path(dest_dir, paste0(roll, "_", row$first_frame))
        fly_rotation_score_leg(photos_sf[idx, ], dest_dir = leg_dir, mask = mask,
                               mask_threshold = mask_threshold)
      } else {
        list(status = "not_scored", scores = NULL, warnings = 0L)
      }
      list(leg = fly_rotation_leg_row(row, res, fly_rotation_segment(photos_sf[leg_idx, ])),
           pairs = fly_rotation_pair_rows(row, res))
    })
    leg_df <- if (length(scored)) {
      do.call(rbind, lapply(scored, `[[`, "leg"))
    } else {
      fly_rotation_leg_template()
    }
    pair_df <- do.call(rbind, c(list(fly_rotation_pair_template()),
                                lapply(scored, `[[`, "pairs")))
    st <- fly_rotation_roll_state(leg_df)
    dplyr::tibble(film_roll = roll, rotation = st$rotation, state = st$state,
                  legs_found = nrow(rl), legs_qualifying = nrow(q), legs = list(leg_df),
                  pairs = list(pair_df))
  })
  # Typed even when nothing came back, so the documented join cannot silently assign NULL.
  dplyr::bind_rows(c(list(dplyr::tibble(
    film_roll = character(0), rotation = integer(0), state = character(0),
    legs_found = integer(0), legs_qualifying = integer(0), legs = list(), pairs = list()
  )), out))
}

# Leg-definition constants, named so the shipped rule and the tests read the same values.
fly_rotation_min_frames <- function() 6L
# Pairs finite under both the winner and a rival before the sign test is run: 5 of 5 is the
# smallest sample that clears p <= 0.05. Read by the verdict and by the `scored` gate, so
# the two cannot come apart (code-check round 4).
fly_rotation_min_pairs <- function() 5L
fly_rotation_max_frames <- function() 11L

# The central `fly_rotation_max_frames()` frame numbers of a leg.
fly_rotation_central <- function(first, last) {
  n <- last - first + 1
  m <- fly_rotation_max_frames()
  if (n <= m) return(first:last)
  off <- (n - m) %/% 2
  (first + off):(first + off + m - 1)
}

# Smallest circular difference between two bearings, in degrees.
fly_bearing_diff <- function(a, b) abs(((a - b + 180) %% 360) - 180)

# Flight legs in a set of catalogue centroids.
#
# Pre-1990s centroids are interpolated along each line — the same step bearing and
# spacing repeated — and a leg change arrives as a step that is adjacent by frame number
# with a wild bearing and a spacing many times the leg's. Adjacency alone therefore cannot
# find a leg (`fly_bearing()` is right not to try); bearing and spacing together can.
#
# A cardinal leg qualifies. #26 excluded it as degenerate without measuring it; measured on
# the two known-answer rolls, every decisive cardinal leg agreed with its roll (fly#53). What a
# cardinal leg cannot do alone is separate flight-relative from geographic, and the roll
# rule's 90-degree separation is what does that.
#
# One row per run of adjacent-by-number steps, including the two-frame runs a leg change
# leaves behind, so a caller filtering on `n_frames` decides what counts. Ordered by roll
# and first frame whatever the input order.
fly_rotation_legs <- function(film_roll, frame_number, x, y,
                              max_turn = 10, max_spacing_ratio = 1.5) {
  empty <- data.frame(film_roll = character(0), first_frame = numeric(0),
                      last_frame = numeric(0), n_frames = integer(0),
                      bearing = numeric(0), spacing = numeric(0),
                      qualifying = logical(0))
  ok <- !is.na(film_roll) & is.finite(frame_number) & is.finite(x) & is.finite(y)
  if (!any(ok)) return(empty)
  d <- data.frame(roll = as.character(film_roll[ok]), f = frame_number[ok], x = x[ok],
                  y = y[ok])
  d <- d[order(d$roll, d$f), ]
  out <- list()
  # `split()` once rather than `d[d$roll == roll, ]` per roll: over the catalogue's 1.45 M
  # film frames and 6,716 rolls the per-roll scan is quadratic and never finishes.
  for (r in split(d, d$roll)) {
    roll <- r$roll[1]
    n <- nrow(r)
    if (n < 2) next
    # A step of zero length is two frames catalogued at one point: `atan2(0, 0)` would call
    # it north, so it joins nothing (code-check round 4; as `fly_bearing()` does, fly#87).
    b <- (atan2(diff(r$x), diff(r$y)) * 180 / pi) %% 360
    s <- sqrt(diff(r$x)^2 + diff(r$y)^2)
    adj <- diff(r$f) == 1 & s > 0
    i <- 1
    while (i <= n - 1) {
      if (!adj[i]) {
        i <- i + 1
        next
      }
      e <- i
      continues <- function(k) {
        med <- stats::median(s[i:e])
        adj[k] && fly_bearing_diff(b[k], b[i]) <= max_turn &&
          s[k] <= max_spacing_ratio * med && s[k] >= med / max_spacing_ratio
      }
      while (e + 1 <= n - 1 && continues(e + 1)) {
        e <- e + 1
      }
      # Mean of the steps' offsets from the first, so a leg straddling north does not
      # average 359 and 1 into 180.
      off <- ((b[i:e] - b[i] + 180) %% 360) - 180
      bear <- (b[i] + stats::median(off)) %% 360
      out[[length(out) + 1]] <- data.frame(
        film_roll = roll, first_frame = r$f[i], last_frame = r$f[e + 1],
        n_frames = as.integer(e - i + 2), bearing = bear,
        spacing = stats::median(s[i:e]),
        qualifying = (e - i + 2) >= fly_rotation_min_frames()
      )
      i <- e + 1
    }
  }
  if (!length(out)) return(empty)
  res <- do.call(rbind, out)
  rownames(res) <- NULL
  res
}

# Verdict for one leg from its pair-by-rotation score matrix (columns 0, 90, 180, 270) and
# `refused`, which rotations the stretch guard refused.
#
# `refused` is passed rather than read off the NAs, because an all-NA column means two
# things: a rotation the guard refused, which the rule says does not compete, and one that
# warped and shared too little ground to score, which DOES compete and must block a verdict
# it could not be tested against (code-check round 3). Inferring one from the other is how
# three review rounds each found a measurement gap reported as a measurement.
#
# Decisive only when the winner beats EACH competing rival on enough pairs that a one-sided
# sign test gives p <= 0.05. A margin has no scale until a null gives it one; the sign test
# is that null. Adjacent pairs share a frame, so they are not independent and the nominal p
# flatters a leg — the two-leg roll rule is what absorbs that.
fly_rotation_verdict <- function(scores, refused = rep(FALSE, ncol(scores)), alpha = 0.05) {
  rots <- c(0L, 90L, 180L, 270L)
  if (is.null(refused)) refused <- rep(FALSE, ncol(scores))
  means <- colMeans(scores, na.rm = TRUE)
  means[!is.finite(means) | refused] <- NA
  res <- list(rotation = NA_integer_, decisive = FALSE, margin = NA_real_, pairs = 0L,
              means = stats::setNames(means, rots))
  if (all(is.na(means))) return(res)
  w <- which.max(means)
  rivals <- setdiff(which(!refused), w)
  finite_rivals <- intersect(rivals, which(!is.na(means)))
  res$rotation <- rots[w]
  res$margin <- if (length(finite_rivals)) unname(means[w] - max(means[finite_rivals])) else NA_real_
  res$pairs <- sum(is.finite(scores[, w]))
  res$decisive <- length(rivals) > 0 && all(vapply(rivals, function(k) {
    both <- is.finite(scores[, w]) & is.finite(scores[, k])
    n <- sum(both)
    if (n < fly_rotation_min_pairs()) return(FALSE)
    wins <- sum(scores[both, w] > scores[both, k])
    stats::pbinom(wins - 1, n, 0.5, lower.tail = FALSE) <= alpha
  }, logical(1)))
  res
}

# Whether a leg's scores could support a decisive verdict at all: some competing rotation
# shares 5 finite pairs with every other competing one. The verdict's own precondition,
# stated once so the `scored` gate cannot drift from it (code-check round 3).
fly_rotation_could_decide <- function(scores, refused) {
  comp <- which(!refused)
  if (length(comp) < 2) return(FALSE)
  any(vapply(comp, function(w) {
    all(vapply(setdiff(comp, w), function(k) {
      sum(is.finite(scores[, w]) & is.finite(scores[, k])) >= fly_rotation_min_pairs()
    }, logical(1)))
  }, logical(1)))
}

# The `legs` list-column's shape with no rows, for a roll with no qualifying leg.
# Built directly rather than by handing `fly_rotation_leg_row()` a zero-row leg:
# `data.frame()` refuses to recycle its length-1 verdict fields against zero-length ones.
fly_rotation_leg_template <- function() {
  data.frame(first_frame = numeric(0), last_frame = numeric(0), n_frames = integer(0),
             bearing = numeric(0), segment = character(0), status = character(0),
             refused = character(0),
             rotation = integer(0), decisive = logical(0), margin = numeric(0),
             pairs = integer(0), score_0 = numeric(0), score_90 = numeric(0),
             score_180 = numeric(0), score_270 = numeric(0), warnings = integer(0))
}

# The `pairs` list-column's shape with no rows.
fly_rotation_pair_template <- function() {
  data.frame(first_frame = numeric(0), frame_a = numeric(0), frame_b = numeric(0),
             score_0 = numeric(0), score_90 = numeric(0), score_180 = numeric(0),
             score_270 = numeric(0))
}

# Which mission a leg belongs to: its scale and flying height when they are constant along
# it, `"mixed"` otherwise. Recorded, not used by the rule — it is what lets the campaign ask
# whether one roll's missions agree with each other.
fly_rotation_segment <- function(pts) {
  part <- function(col) {
    if (!col %in% names(pts)) return(NA_character_)
    v <- unique(as.character(pts[[col]]))
    if (length(v) == 1) v else "mixed"
  }
  paste(part("scale"), part("flying_height"), sep = " / ")
}

# One leg's row in the `legs` list-column.
fly_rotation_leg_row <- function(leg, res, segment = NA_character_) {
  v <- if (identical(res$status, "scored")) {
    fly_rotation_verdict(res$scores, res$refused)
  } else {
    list(rotation = NA_integer_, decisive = FALSE, margin = NA_real_, pairs = 0L,
         means = stats::setNames(rep(NA_real_, 4), c(0, 90, 180, 270)))
  }
  data.frame(
    first_frame = leg$first_frame, last_frame = leg$last_frame,
    n_frames = leg$n_frames, bearing = leg$bearing, segment = segment,
    status = res$status,
    # Which rotations the stretch guard refused, e.g. "0;180", so a verdict can be
    # recomputed from the shipped pair scores without guessing it from their NAs.
    refused = if (is.null(res$refused)) NA_character_ else
      paste(c(0, 90, 180, 270)[res$refused], collapse = ";"),
    rotation = v$rotation, decisive = v$decisive,
    margin = unname(v$margin), pairs = v$pairs, score_0 = unname(v$means[1]),
    score_90 = unname(v$means[2]), score_180 = unname(v$means[3]),
    score_270 = unname(v$means[4]),
    warnings = if (is.null(res$warnings)) 0L else as.integer(res$warnings)
  )
}

# One leg's pair scores, so a verdict — and, for a leg with too little overlap, the gate
# that kept it from one — can be recomputed from what was shipped.
fly_rotation_pair_rows <- function(leg, res) {
  if (!res$status %in% c("scored", "too_little_overlap")) {
    return(fly_rotation_pair_template())
  }
  sc <- res$scores
  data.frame(first_frame = leg$first_frame, frame_a = res$frames[-length(res$frames)],
             frame_b = res$frames[-1], score_0 = sc[, 1], score_90 = sc[, 2],
             score_180 = sc[, 3], score_270 = sc[, 4])
}

# A roll's state from its legs. First match wins, and the serious states come first: a
# roll that has contradicted itself is never shipped on a majority.
#
# Separation is 90 degrees because under a GEOGRAPHIC truth a leg's winner is
# round90(T - bearing): two legs closer than 90 apart can then agree by chance (two in three
# at 30), and only 90 or more guarantees a geographic roll contradicts itself.
fly_rotation_roll_state <- function(legs) {
  none <- function(state) list(state = state, rotation = NA_integer_)
  if (!nrow(legs)) return(none("no_qualifying_leg"))
  dec <- legs[legs$status == "scored" & legs$decisive, ]
  if (length(unique(dec$rotation)) > 1) return(none("legs_disagree"))
  if (nrow(dec) >= 2) {
    spread <- max(outer(dec$bearing, dec$bearing, fly_bearing_diff))
    if (spread >= 90) return(list(state = "shipped", rotation = as.integer(dec$rotation[1])))
    return(none("single_direction"))
  }
  if (nrow(dec) == 1) return(none("one_decisive_leg"))
  if (any(legs$status == "scored")) return(none("no_decisive_leg"))
  if (any(legs$status == "thumbnails_unavailable")) return(none("thumbnails_unavailable"))
  # Legs exist and none could be scored for another reason: drawn unrotated, every rotation
  # refused, a warp that failed, too little overlap, or over `max_legs`. Not "scored and
  # undecided".
  none("legs_unscorable")
}

# Georeference one leg's thumbnails at all four rotations and score every adjacent pair.
#
# Footprints are drawn from the leg's own frames, so the end frames take their bearing
# from inside the leg rather than from the leg-change step beside it. Squareness is checked
# by the caller, not here, so the digital positive control can run through this same code.
#
# Status: `scored`; `not_rotated` (a frame drew no rotated footprint); `thumbnails_unavailable`;
# `refused` (the stretch guard refused every rotation); `warp_failed` (a warp failed for any
# other reason — an error is not a refusal, and must not read as a measured non-decision);
# `too_little_overlap` (fewer than two rotations with 5 finite pairs, so no verdict could be
# decisive). Each is a way the leg produced no evidence, and none may read as `scored`.
fly_rotation_score_leg <- function(pts, dest_dir, mask, mask_threshold) {
  pts <- pts[order(as.numeric(pts$frame_number)), ]
  fail <- function(status) list(status = status, scores = NULL, warnings = 0L)
  fp <- sf::st_transform(suppressWarnings(fly_footprint(pts)), 3005)
  if (any(sf::st_is_empty(sf::st_geometry(fp))) || !all(is.finite(fp$footprint_bearing))) {
    return(fail("not_rotated"))
  }
  th <- fly_fetch(pts, type = "thumbnail", dest_dir = file.path(dest_dir, "thumb"))
  if (!all(th$success)) return(fail("thumbnails_unavailable"))
  n_warn <- 0L
  rots <- c(0L, 90L, 180L, 270L)
  refused <- stats::setNames(rep(FALSE, 4), rots)
  scores <- matrix(NA_real_, nrow(pts) - 1, 4, dimnames = list(NULL, rots))
  for (k in seq_along(rots)) {
    d <- file.path(dest_dir, paste0("r", rots[k]))
    dir.create(d, recursive = TRUE, showWarnings = FALSE)
    one <- vapply(seq_len(nrow(pts)), function(j) {
      o <- file.path(d, paste0(pts$frame_number[j], ".tif"))
      # gdalwarp writes INTO an existing destination, keeping its grid, so a rerun into a
      # persistent directory would score frames clipped to a stale footprint.
      unlink(o)
      stretched <- FALSE
      ok <- withCallingHandlers(
        tryCatch(georef_one(th$dest[j], fp[j, ], o, rotation = rots[k], mask = mask,
                            mask_threshold = mask_threshold),
                 error = function(e) FALSE),
        warning = function(w) {
          if (grepl("would stretch it by", conditionMessage(w), fixed = TRUE)) {
            stretched <<- TRUE
          }
          n_warn <<- n_warn + 1L
          invokeRestart("muffleWarning")
        }
      )
      if (isTRUE(ok)) o else if (stretched) "refused" else "failed"
    }, character(1))
    if (any(one == "failed")) return(fail("warp_failed"))
    # A rotation the stretch guard refused on any frame does not compete at all.
    if (any(one == "refused")) {
      refused[k] <- TRUE
      next
    }
    scores[, k] <- vapply(seq_len(nrow(pts) - 1), function(j) {
      fly_rotation_pair_r(one[j], one[j + 1])
    }, numeric(1))
  }
  if (all(refused)) {
    return(list(status = "refused", scores = NULL, warnings = n_warn))
  }
  # `scored` means the leg COULD have been decisive — the verdict's own precondition, read
  # from the same function. A pair is NA when the frames share under 500 cells at 25 m
  # (every pair of a 1:3000 frame, whose 60% overlap is ~450 cells), and a leg without
  # enough usable pairs is an absence of evidence, not a measured non-decision.
  if (!fly_rotation_could_decide(scores, refused)) {
    # Scores kept, so the gate can be recomputed from what is shipped.
    return(list(status = "too_little_overlap", scores = scores, warnings = n_warn,
                refused = refused, frames = as.numeric(pts$frame_number)))
  }
  list(status = "scored", scores = scores, warnings = n_warn, refused = refused,
       frames = as.numeric(pts$frame_number))
}

# Luminance of a georef output with its alpha honoured. Every output carries one alpha
# band as its last (fly#56): Gray + Alpha, or RGB + Alpha. Built from `terra::` calls
# only — `mean()` on a SpatRaster dispatches to terra's method only when terra is
# ATTACHED, and here it is merely loaded, so it would return NA.
fly_rotation_luminance <- function(path) {
  r <- terra::rast(path)
  nl <- terra::nlyr(r)
  data_bands <- if (nl %in% c(2, 4)) seq_len(nl - 1) else seq_len(min(nl, 3))
  g <- terra::app(terra::subset(r, data_bands), fun = base::mean)
  if (nl %in% c(2, 4)) {
    g <- terra::mask(g, terra::subset(r, nl), maskvalues = 0)
  }
  g
}

# Correlation of two georeferenced frames over their common ground at 25 m.
fly_rotation_pair_r <- function(a, b, res = 25, min_cells = 500) {
  ga <- fly_rotation_luminance(a)
  gb <- fly_rotation_luminance(b)
  inter <- terra::intersect(terra::ext(ga), terra::ext(gb))
  if (is.null(inter)) return(NA_real_)
  tmpl <- terra::rast(inter, resolution = res, crs = terra::crs(ga))
  va <- terra::values(terra::resample(ga, tmpl, method = "average"))[, 1]
  vb <- terra::values(terra::resample(gb, tmpl, method = "average"))[, 1]
  ok <- is.finite(va) & is.finite(vb)
  if (sum(ok) < min_cells) return(NA_real_)
  suppressWarnings(stats::cor(va[ok], vb[ok]))
}
