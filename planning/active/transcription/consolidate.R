# Consolidate a literal transcription into covering ranges, page by page: lines sorted by their
# first final, and consecutive lines at the same height and lens merged, so the finals between
# a strip's ST and END lines (which these forms log as separate lines) are covered by the height
# both carry. Lines at different heights, or with no height or no range, are never merged, and
# no run crosses a line with no height, so the frames between them stay uncovered rather than
# guessed.
consolidate <- function(d) {
  d$ff <- suppressWarnings(as.integer(d$frame_from)); d$ft <- suppressWarnings(as.integer(d$frame_to))
  out <- list()
  for (f in unique(d$file)) {
    p <- d[d$file == f, ]
    # Every line with a range takes part in the ordering, with or without a height, so a run
    # can never merge across a line whose height was not read (code-check round 1: the first
    # version dropped those lines before ordering, and merged straight across them).
    ranged <- !is.na(p$ff) & !is.na(p$ft)
    keep <- p[!ranged, ]
    m <- p[ranged, ]
    m <- m[order(m$ff, m$ft), ]
    has_h <- nzchar(m$height_ft_interpreted)
    i <- 1
    while (i <= nrow(m)) {
      j <- i
      while (has_h[i] && j < nrow(m) && has_h[j + 1] &&
             m$height_ft_interpreted[j + 1] == m$height_ft_interpreted[i] &&
             m$focal_mm[j + 1] == m$focal_mm[i] && m$ff[j + 1] > m$ft[j]) j <- j + 1
      r <- m[i, ]
      if (j > i) {
        r$ft <- max(m$ft[i:j])
        r$frame_to <- as.character(r$ft)
        r$frames_final <- paste0(r$ff, "-", r$ft)
        r$legibility <- if (all(m$legibility[i:j] == "clear")) "clear" else "partial"
        r$note <- paste0("Consolidated from ", j - i + 1, " lines at one height (finals ",
                         paste(m$frames_final[i:j], collapse = ", "), "). ", m$note[i])
      }
      out[[length(out) + 1]] <- r
      i <- j + 1
    }
    if (nrow(keep)) out[[length(out) + 1]] <- keep
  }
  res <- do.call(rbind, out)
  res[, setdiff(names(res), c("ff", "ft"))]
}
