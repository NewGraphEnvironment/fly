# load only definitions from the script (no stages)
pkgload::load_all(quiet = TRUE); suppressMessages({library(sf); library(terra)}); sf_use_s2(FALSE)
ex <- parse("data-raw/dem_measure-photo_parallax.R", keep.source = FALSE)
for (e in ex) {
  if (is.call(e) && identical(e[[1]], as.name("<-")) && is.name(e[[2]])) {
    rhs <- e[[3]]
    fn <- if (is.call(rhs)) deparse(rhs[[1]])[1] else ""
    if (is.atomic(rhs) || fn %in% c("function", "c", "paste0", "data.frame"))
      try(eval(e, globalenv()), silent = TRUE)
  } else if (is.call(e) && deparse(e[[1]])[1] %in% c("local", "fns_from")) eval(e, globalenv())
}
dtm <- terra::rast(MRDEM_DTM); dsm <- terra::rast(MRDEM_DSM)
options(error = NULL)
