# fly#101: score the third blind read against the rule fixed in findings.md, before the read exists.
# Usage (from the repo root):
#   Rscript planning/active/transcription/score.R <reader dir> [<decided digit from verdict.md>]
# The decided digit is copied by hand from verdict.md's section for the target row, or omitted
# (or "undecided") when the reader decided none. Everything else is computed here.
args <- commandArgs(trailingOnly = TRUE)
dir <- args[1]
decided <- if (length(args) >= 2) args[2] else "undecided"
source("planning/archive/2026-10-issue-93-bw-colour-terrain-tail/transcription/consolidate.R")

rd_csv <- function(f) read.csv(f, colClasses = "character", na.strings = character(), check.names = FALSE)
rd <- rd_csv(file.path(dir, "rows.csv"))
ex <- rd_csv("data-raw/flying_height_logbooks.csv")

control_files <- c(sprintf("bc77087__bc77087_%d.jpg", 2:5), sprintf("bc77070__bc77070_%d.jpg", 1:3))
target_file <- "bc77087__bc77087_1.jpg"

# Every (file, final) a row with a range and a height covers, and the height it carries there.
expand <- function(d) {
  d <- d[nzchar(d$frame_from) & nzchar(d$frame_to) & nzchar(d$height_ft_interpreted), ]
  if (!nrow(d)) return(data.frame(file = character(), frame = integer(), h = character()))
  do.call(rbind, lapply(seq_len(nrow(d)), function(i) {
    fr <- seq(as.integer(d$frame_from[i]), as.integer(d$frame_to[i]))
    data.frame(file = d$file[i], frame = fr, h = d$height_ft_interpreted[i])
  }))
}

# ---- Control gate ---------------------------------------------------------------------------
want <- expand(ex[ex$file %in% control_files, ])
got <- expand(consolidate(rd[rd$file %in% control_files, ]))
# A frame the reader gives two different heights is a conflict, and counts as a mismatch.
got_key <- paste(got$file, got$frame)
conflict <- unique(got_key[duplicated(got_key)][vapply(
  got_key[duplicated(got_key)], function(k) length(unique(got$h[got_key == k])) > 1, logical(1))])
got <- got[!duplicated(got_key), ]
m <- merge(want, got, by = c("file", "frame"), all.x = TRUE, suffixes = c("_ex", "_rd"))
covered <- !is.na(m$h_rd)
mismatch <- covered & (m$h_rd != m$h_ex | paste(m$file, m$frame) %in% conflict)
cover_frac <- mean(covered)
gate_pass <- sum(mismatch) == 0 && cover_frac >= 0.9
cat(sprintf("control gate: %d control frames on %d pages; reader covers %d (%.3f); %d mismatch -> %s\n",
            nrow(m), length(unique(m$file)), sum(covered), cover_frac, sum(mismatch),
            if (gate_pass) "PASS" else "FAIL"))
if (any(mismatch)) print(aggregate(frame ~ file + h_ex + h_rd, m[mismatch, ], function(x) paste(range(x), collapse = "-")))

# ---- Target ---------------------------------------------------------------------------------
# The figure-bearing row on bc77087_1 with the lowest first final (its line 1).
p1 <- rd[rd$file == target_file & rd$leading_digit_confidence %in% c("clear", "uncertain", "illegible"), ]
p1 <- p1[order(suppressWarnings(as.integer(p1$frame_from))), ]
if (!nrow(p1)) stop("the reader wrote no figure-bearing height on ", target_file)
cat(sprintf("figure-bearing rows on %s: %d (%s)\n", target_file, nrow(p1),
            paste(p1$frames_final, p1$height_as_written, sep = ": ", collapse = "; ")))
t <- p1[1, ]
cat(sprintf("target: frames %s, written '%s', leading digit %s, alternatives '%s'\n",
            t$frames_final, t$height_as_written, t$leading_digit_confidence, t$leading_digit_alternatives))

# The rest of the figure after its leading digit, as the reader wrote it.
fig <- regmatches(t$height_as_written, regexpr("[0-9?]\\.?[0-9]*", t$height_as_written))
rest <- if (length(fig)) substring(fig, 2) else NA_character_

g <- if (file.exists(file.path(dir, "glyphs.csv"))) rd_csv(file.path(dir, "glyphs.csv")) else NULL
committed <- NA_character_
basis <- ""
if (t$leading_digit_confidence == "clear") {
  committed <- substr(fig, 1, 1); basis <- "read clear in Stage A"
} else if (decided %in% as.character(0:9)) {
  sup <- if (is.null(g)) 0L else sum(g$disputed_file == target_file & g$candidate == decided &
                                       g$same_hand == "same" & grepl("^yes", g$resembles_disputed))
  cat(sprintf("Stage B decided %s; same-hand references resembling it: %d\n", decided, sup))
  if (sup >= 1) { committed <- decided; basis <- sprintf("Stage B, %d same-hand reference(s)", sup) }
}

verdict <- if (!gate_pass) "unsettled (control gate failed)" else
  if (is.na(committed)) "unsettled (no commitment)" else
  if (!identical(rest, ".8")) sprintf("unsettled (rest of the figure read as '%s', not '.8')", rest) else
  if (committed == "3") "settled 3.8" else
  if (committed == "7") "settled 7.8" else
  sprintf("unsettled (committed to %s, neither 3 nor 7)", committed)
cat(sprintf("committed digit: %s (%s)\nVERDICT: %s\n", committed, basis, verdict))
