# Helper to locate test data in inst/testdata/
testdata_path <- function(...) {
  system.file("testdata", ..., package = "fly", mustWork = TRUE)
}

