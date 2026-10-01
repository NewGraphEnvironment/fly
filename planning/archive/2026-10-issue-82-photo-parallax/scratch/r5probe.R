# Probe the two round-5 fixes on constructed SYN tables: restore-the-bug check
mk <- function(status, slope) data.frame(set = "plain", case = rep(c("flat_C0","flat_C1","dtm_C0","dtm_C1"), each = 3), displaced_m = 0,
  kappa = rep(c(0,1,0,1), each = 3), status = status, slope = slope, stringsAsFactors = FALSE)
eval_ok <- function(SYN) {
  refused <- grepl("^gated", SYN$status) | SYN$status %in% c("no_global", "no_registration", "no_dem")
  SYN$pass <- NA; pl <- SYN$set == "plain" & SYN$displaced_m == 0 & !refused
  SYN$pass[pl] <- with(SYN[pl, ], ifelse(status != "ok" | !is.finite(slope), FALSE, ifelse(kappa == 0, abs(slope) <= 0.10, abs(slope - 1) <= 0.25)))
  pu <- SYN$set == "plain" & SYN$displaced_m == 0
  new <- all(vapply(split(SYN[pu, ], factor(SYN$case[pu], levels = c("flat_C0","flat_C1","dtm_C0","dtm_C1"))), function(z) sum(z$pass %in% TRUE) >= 2 && !any(z$pass %in% FALSE), logical(1)))
  old <- all(vapply(split(SYN[pl, ], SYN$case[pl]), function(z) sum(z$pass %in% TRUE) >= 2 && !any(z$pass %in% FALSE), logical(1)))
  c(new = new, old = old)
}
good <- mk("ok", rep(c(0, 1, 0, 1), each = 3))
cat("all good          :", eval_ok(good), "\n")
s <- good; s$status[10:12] <- "gated_registration_bound"; cat("dtm_C1 all refused:", eval_ok(s), "\n")
s <- good; s$status[] <- "no_global"; cat("all refused       :", eval_ok(s), "\n")
s <- good; s$status[10] <- "gated_model_r2"; cat("one refused       :", eval_ok(s), "\n")
s <- good; s$slope[11] <- 1.4; cat("one wrong         :", eval_ok(s), "\n")
f <- c("failed: [crop] too few values for writing: 0 < 1234", "failed: [crop] too few values for writing: 0 < 5678")
cat("grouped new:", max(table(gsub("[0-9]+", "#", f))), " old:", max(table(f)), "\n")
