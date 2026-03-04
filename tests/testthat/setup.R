# Helper to locate test data in inst/testdata/
testdata_path <- function(...) {
  system.file("testdata", ..., package = "fly", mustWork = TRUE)
}

# Skip helper for database-dependent tests
skip_if_no_db <- function() {
  testthat::skip_if_not(
    tryCatch({
      conn <- DBI::dbConnect(RPostgres::Postgres(),
        host = "localhost", port = 63333,
        dbname = "bcfishpass", user = "newgraph")
      DBI::dbDisconnect(conn)
      TRUE
    }, error = function(e) FALSE),
    "bcfishpass DB not available"
  )
}
