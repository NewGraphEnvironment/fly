# fly#101: score the third blind read against the rule fixed in findings.md (Amendment A1), before the
# read exists.
# Usage (from the repo root):
#   Rscript planning/active/transcription/score.R <reader dir>             # gate and verdict
#   Rscript planning/active/transcription/score.R <rows.csv> --gate-only   # gate alone, any reader's rows
# The reader dir holds rows.csv, glyphs.csv and verdict.csv, written verbatim from the reader's replies.
# Any error, missing file or missing column is reported as `unsettled (scoring error: ...)`, never as a
# crash: an absent measurement must not read as a verdict.
args <- commandArgs(trailingOnly = TRUE)
gate_only <- "--gate-only" %in% args
src <- args[1]
source("planning/archive/2026-10-issue-93-bw-colour-terrain-tail/transcription/consolidate.R")

control_files <- sprintf("bc77087__bc77087_%d.jpg", 2:5)
target_file <- "bc77087__bc77087_1.jpg"

rd_csv <- function(f) {
  d <- read.csv(f, colClasses = "character", na.strings = character(), check.names = FALSE)
  d[] <- lapply(d, trimws)
  d
}
low <- function(x) tolower(trimws(x))
int <- function(x) suppressWarnings(as.integer(x))
num <- function(x) suppressWarnings(as.numeric(gsub(",", "", x)))
need <- function(d, cols, what) {
  miss <- setdiff(cols, names(d))
  if (length(miss)) stop(what, " lacks column(s): ", paste(miss, collapse = ", "))
}

# Every (file, final) a row with an integer range and a numeric height covers, and that height. A row
# whose finals or height do not parse covers nothing.
expand <- function(d) {
  ff <- int(d$frame_from); ft <- int(d$frame_to); h <- num(d$height_ft_interpreted)
  ok <- !is.na(ff) & !is.na(ft) & !is.na(h) & ft >= ff
  if (!any(ok)) return(data.frame(file = character(), frame = integer(), h = numeric()))
  do.call(rbind, lapply(which(ok), function(i) data.frame(file = d$file[i], frame = seq(ff[i], ft[i]), h = h[i])))
}

gate <- function(rd) {
  ex <- rd_csv("data-raw/flying_height_logbooks.csv")
  want <- expand(ex[ex$file %in% control_files, ])
  # Consolidation needs integer finals and a focal on every line; the reader's blank focal on a ditto
  # line takes the page's single written focal, so ST and END lines at one height merge as fly#93's did.
  r <- rd[rd$file %in% control_files, ]
  r$frame_from[is.na(int(r$frame_from))] <- ""
  r$frame_to[is.na(int(r$frame_to))] <- ""
  for (f in unique(r$file)) {
    fo <- unique(r$focal_mm[r$file == f & nzchar(r$focal_mm)])
    if (length(fo) == 1) r$focal_mm[r$file == f & !nzchar(r$focal_mm)] <- fo
  }
  r$height_ft_interpreted <- ifelse(is.na(num(r$height_ft_interpreted)), "",
                                    format(num(r$height_ft_interpreted), scientific = FALSE, trim = TRUE))
  got <- expand(consolidate(r))
  key <- paste(got$file, got$frame)
  conflict <- unique(key[vapply(key, function(k) length(unique(got$h[key == k])) > 1, logical(1))])
  got <- got[!duplicated(key), ]
  m <- merge(want, got, by = c("file", "frame"), all.x = TRUE, suffixes = c("_ex", "_rd"))
  covered <- !is.na(m$h_rd)
  mismatch <- covered & (m$h_rd != m$h_ex | paste(m$file, m$frame) %in% conflict)
  pass <- sum(mismatch) == 0 && mean(covered) >= 0.9
  cat(sprintf("control gate: %d control frames on %d pages; reader covers %d (%.3f); %d mismatch -> %s\n",
              nrow(m), length(unique(m$file)), sum(covered), mean(covered), sum(mismatch),
              if (pass) "PASS" else "FAIL"))
  if (any(mismatch)) print(aggregate(frame ~ file + h_ex + h_rd, m[mismatch, ],
                                     function(x) paste(range(x), collapse = "-")))
  pass
}

score <- function(dir) {
  rd <- rd_csv(file.path(dir, "rows.csv"))
  need(rd, c("file", "frame_from", "frame_to", "frames_final", "height_as_written", "height_digits",
             "height_ft_interpreted", "leading_digit_confidence", "leading_digit_alternatives", "focal_mm"),
       "rows.csv")
  gate_pass <- gate(rd)

  # Target: the figure-bearing row on bc77087_1 with the lowest first final (its line 1).
  conf <- low(rd$leading_digit_confidence)
  p1 <- rd[rd$file == target_file & conf %in% c("clear", "uncertain", "illegible"), ]
  if (!nrow(p1)) stop("no figure-bearing height on ", target_file)
  # Line 1 is identified by its first final, so every figure-bearing row on the page must have one that
  # parses; otherwise which row is line 1 is not known, and nothing is scored (round 2).
  if (any(is.na(int(p1$frame_from)))) stop("a figure-bearing row on ", target_file, " has no integer first final")
  p1 <- p1[order(int(p1$frame_from)), ]
  cat(sprintf("figure-bearing rows on %s: %d (%s)\n", target_file, nrow(p1),
              paste(p1$frames_final, p1$height_digits, sep = ": ", collapse = "; ")))
  t <- p1[1, ]
  tconf <- low(t$leading_digit_confidence)
  alts <- strsplit(gsub("[^0-9/]", "", t$leading_digit_alternatives), "/")[[1]]
  alts <- alts[nzchar(alts)]
  cat(sprintf("target: frames %s, written '%s', digits '%s', leading digit %s, alternatives '%s'\n",
              t$frames_final, t$height_as_written, t$height_digits, tconf, t$leading_digit_alternatives))
  digits <- gsub("\\s", "", t$height_digits)
  lead <- substr(digits, 1, 1)
  rest <- substring(digits, 2)

  committed <- NA_character_; basis <- ""
  if (tconf == "clear") {
    if (nzchar(trimws(t$leading_digit_alternatives))) basis <- "marked clear but lists alternatives: no commitment"
    else if (grepl("^[0-9]$", lead)) { committed <- lead; basis <- "read clear in Stage A" }
    else basis <- "marked clear but no digit written: no commitment"
  } else if (file.exists(file.path(dir, "verdict.csv"))) {
    v <- rd_csv(file.path(dir, "verdict.csv"))
    need(v, c("disputed_file", "disputed_frames", "decision", "lean", "ref_ids"), "verdict.csv")
    g <- rd_csv(file.path(dir, "glyphs.csv"))
    need(g, c("ref_id", "disputed_file", "disputed_frames", "candidate", "same_hand", "resembles_disputed"),
         "glyphs.csv")
    v <- v[v$disputed_file == target_file & v$disputed_frames == t$frames_final, ]
    if (nrow(v) != 1) stop(nrow(v), " verdict rows for the target")
    dec <- low(v$decision)
    g <- g[g$disputed_file == target_file & g$disputed_frames == t$frames_final, ]
    # Same-hand references that resemble the glyph, for digit d; restricted to the ids in `only` when given
    # (A1.6: the decision needs at least one such reference among those it cites, and more of them overall
    # than any other candidate has).
    sup <- function(d, only = NULL) sum(trimws(g$candidate) == d & low(g$same_hand) == "same" &
                                          grepl("^yes", low(g$resembles_disputed)) &
                                          (is.null(only) | g$ref_id %in% only))
    cands <- unique(c(alts, trimws(g$candidate)))
    tally <- vapply(cands, sup, integer(1))
    refs <- trimws(strsplit(v$ref_ids, "[;, ]+")[[1]]); refs <- refs[nzchar(refs)]
    cat(sprintf("Stage B decision '%s' (lean '%s'); same-hand 'yes' references per candidate: %s; cited refs %s\n",
                v$decision, v$lean, paste(names(tally), tally, sep = "=", collapse = " "),
                paste(refs, collapse = ",")))
    if (grepl("^[0-9]$", dec)) {
      others <- tally[names(tally) != dec]
      if (!dec %in% alts) basis <- "decided a digit Stage A did not list as an alternative: no commitment"
      else if (!length(refs) || !all(refs %in% g$ref_id)) basis <- "cited references missing from glyphs.csv: no commitment"
      else if (sup(dec, refs) < 1) basis <- "no cited same-hand reference supports the decision: no commitment"
      else if (length(others) && sup(dec) <= max(others)) basis <- "a competing digit has as much support: no commitment"
      else { committed <- dec; basis <- sprintf("Stage B, %d same-hand reference(s)", sup(dec)) }
    } else basis <- "Stage B undecided"
  } else basis <- "no verdict.csv"

  verdict <- if (!gate_pass) "unsettled (control gate failed)" else
    if (is.na(committed)) sprintf("unsettled (%s)", basis) else
    if (!identical(rest, ".8")) sprintf("unsettled (rest of the figure read as '%s', not '.8')", rest) else
    if (committed == "3") "settled 3.8" else
    if (committed == "7") "settled 7.8" else
    sprintf("unsettled (committed to %s, neither 3 nor 7)", committed)
  cat(sprintf("committed digit: %s (%s)\n", committed, basis))
  verdict
}

verdict <- tryCatch(
  if (gate_only) { if (gate(rd_csv(src))) "gate PASS" else "gate FAIL" } else score(src),
  error = function(e) sprintf("unsettled (scoring error: %s)", conditionMessage(e)))
cat("VERDICT:", verdict, "\n")
