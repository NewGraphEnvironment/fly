test_that("fly_query_habitat requires DBI", {
  skip_if_no_db()

  conn <- DBI::dbConnect(RPostgres::Postgres(),
    host = "localhost", port = 63333,
    dbname = "bcfishpass", user = "newgraph")
  on.exit(DBI::dbDisconnect(conn))

  result <- fly_query_habitat(conn, wsgroup = "BULK",
    habitat_type = "rearing", species_code = "co",
    min_stream_order = 6)

  expect_s3_class(result, "sf")
  expect_true(nrow(result) > 0)
  expect_true("blue_line_key" %in% names(result))
})
