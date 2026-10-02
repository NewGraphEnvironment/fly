pkgload::load_all(quiet = TRUE)
suppressMessages({library(sf); library(terra)})
SP <- "/private/tmp/claude-501/-Users-airvine-Projects-repo-fly/0e762a6d-f932-4614-9d5b-0fc1d445cb10/scratchpad/p82"
q <- bcdata::bcdc_query_geodata("WHSE_IMAGERY_AND_BASE_MAPS.AIMG_PHOTO_CENTROIDS_SP")
r <- bcdata::collect(bcdata::filter(q, FILM_ROLL == "bc5282"))
names(r) <- tolower(names(r))
r <- r[order(r$frame_number), ]
saveRDS(r, file.path(SP, "bc5282.rds"))
print(names(r))
leg <- r[r$frame_number %in% 226:236, ]
print(sf::st_drop_geometry(leg)[, c("frame_number","scale","focal_length","flying_height","thumbnail_image_url")])
th <- fly_fetch(leg, type = "thumbnail", dest_dir = file.path(SP, "thumbs"))
print(th)
