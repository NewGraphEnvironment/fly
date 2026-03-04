#' Query bcfishpass for habitat streams
#'
#' Queries the `bcfishpass.streams_vw` table for stream segments with modelled
#' habitat (rearing or spawning) for a given species and watershed group.
#'
#' @param conn A DBI connection to a bcfishpass database.
#' @param wsgroup Watershed group code (e.g. `"BULK"`, `"LNIC"`).
#' @param habitat_type `"rearing"` or `"spawning"`.
#' @param species_code Species code: `"co"`, `"ch"`, `"sk"`, `"bt"`, `"st"`,
#'   `"wct"`, `"cm"`, `"pk"`.
#' @param blue_line_keys Numeric vector of FWA blue_line_key values
#'   (preferred — unique per stream).
#' @param stream_names Character vector of GNIS stream names
#'   (convenience — scoped to wsgroup).
#' @param min_stream_order Minimum Strahler order (applied in addition to
#'   blk/name filters).
#' @return An sf linestring object in WGS84 (EPSG:4326).
#'
#' @export
fly_query_habitat <- function(
    conn,
    wsgroup,
    habitat_type = "rearing",
    species_code = "co",
    blue_line_keys = NULL,
    stream_names = NULL,
    min_stream_order = NULL
) {
  if (!requireNamespace("DBI", quietly = TRUE)) {
    stop("Package 'DBI' is required for fly_query_habitat().", call. = FALSE)
  }

  habitat_col <- paste0(habitat_type, "_", species_code)

  valid_cols <- DBI::dbGetQuery(conn,
    "SELECT column_name FROM information_schema.columns
     WHERE table_schema = 'bcfishpass' AND table_name = 'streams_vw'")$column_name
  if (!habitat_col %in% valid_cols) {
    stop("Column '", habitat_col, "' not found in bcfishpass.streams_vw. ",
         "Valid habitat columns: ",
         paste(grep("^(rearing|spawning)_", valid_cols, value = TRUE), collapse = ", "))
  }

  clauses <- c(
    glue::glue("watershed_group_code = '{wsgroup}'"),
    glue::glue("{habitat_col} = 1")
  )

  if (!is.null(blue_line_keys)) {
    blk_list <- paste(blue_line_keys, collapse = ", ")
    clauses <- c(clauses, glue::glue("blue_line_key IN ({blk_list})"))
    message("Querying ", habitat_col, " streams by blue_line_key (",
            length(blue_line_keys), " streams)...")
  } else if (!is.null(stream_names)) {
    names_list <- paste0("'", stream_names, "'", collapse = ", ")
    clauses <- c(clauses, glue::glue("gnis_name IN ({names_list})"))
    message("Querying ", habitat_col, " streams by name: ",
            paste(stream_names, collapse = ", "), "...")
  } else {
    message("Querying all ", habitat_col, " streams in ", wsgroup, "...")
  }

  if (!is.null(min_stream_order)) {
    clauses <- c(clauses, glue::glue("stream_order >= {min_stream_order}"))
  }

  where <- paste(clauses, collapse = "\n      AND ")

  sql <- glue::glue("
    SELECT segmented_stream_id, blue_line_key, waterbody_key,
           downstream_route_measure, gnis_name,
           stream_order, channel_width, {habitat_col}, access_{species_code},
           ST_Transform(geom, 4326) as geom
    FROM bcfishpass.streams_vw
    WHERE {where}
  ")

  result <- sf::st_read(conn, query = sql) |>
    sf::st_zm(drop = TRUE)
  message("  ", nrow(result), " stream segments")
  result
}
