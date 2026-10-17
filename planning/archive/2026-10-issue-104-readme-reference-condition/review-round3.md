# Code-check round 3: branch 104-readme-describe-terrain-aware-footprints (fly#104)

Reviewer: one subagent. It made no edits to the repo apart from this file. Probes ran from the
scratchpad under `pkgload::load_all()`, plus `curl` and `bcdata` reads of public sources.

## Mechanism

All seven earlier findings come from one assumption. A sentence was written from the typical or
intended case (a film frame, the bundled 1968 set, what the algorithm aims for) and then stated
about the whole set its noun names: every photo, every scan, every record, the minimum. The code
routes each frame separately, by media, roll, GSD, DEM coverage and the height band, and it
declines some members of every set it handles. So a noun with no scope takes on a universal the
code cannot support. Changing one quantifier word ("each" to a plural) kept the same set, which
is why round 2 found the same defect inside round 1's fix.

This round shows a second form of the same assumption. A plain word was chosen for a code
concept, and the word names a different set from the one the code handles:

- "scans" for what the code downloads, which are the catalogue's **thumbnails**.
- "at McKilligan Road" for a 2 km box whose nearest point to that road is 625 m away.

The plain-language rewrite changed the set while it simplified the wording.

## Findings

- **[bug: misleading published claim]** README.md:12-13 ("can download the scans"), README.md:63
  ("`fly_fetch()` downloads the scans"), README.md:96-98 ("with the scans ... the records link
  to"), DESCRIPTION `Description` ("download scans and flight metadata from the BC Data
  Catalogue") and so `man/fly-package.Rd`.
  - **What the code downloads.** `fly_fetch()` downloads thumbnails, flight logs, calibration
    reports or georef files (R/fly_fetch.R:3-4, 11-12, 24-29). The only image URL a catalogue
    record carries is `thumbnail_image_url` (bundled gpkg columns), so no record links to a scan.
  - **Measured.** `bc5282_176_thumb.jpg` is a 1250 x 1250 JPEG. At 1:12000 that is about
    2.2 m per pixel, roughly a tenth of a 9-inch scan's linear resolution.
  - **The package's own text says so.** `inst/notes/georeferencing.md:316`: "Only thumbnails
    are public". The vignette's section is "Thumbnail retrieval and georeferencing". The figure
    script calls them thumbnails.
  - **Why it matters.** A stranger reading "download the scans" expects the scanned
    photographs. The full-resolution scans are not public, and the province sells them.
  - **History.** The old DESCRIPTION already said "fetch scans". This branch rewrote that
    sentence, republished it, and carried the word into three README sentences. The old README
    said "Download thumbnails".
  - **Fix.** Use "thumbnails" (or "low-resolution scans") in these five places.
  - **Where "scans" is true.** README.md:74 and :102 and the pkgdown Georeference desc stay as
    they are. `fly_georef()` "Works with thumbnails and full-resolution scans"
    (R/fly_georef.R:5), and fly masks and warps whatever image it is given.

- **[low: misleading caption]** README.md:24, "The upper Bulkley River (Neexdzii Kwa) at
  McKilligan Road".
  - **The road is not in the figure.** In the Digital Road Atlas, McKilligan Rd's nearest point
    is 625 m west of the figure's box (`964426-966426, 1049182-1051182`, EPSG:3005). It is
    1.75 km from the box centre.
  - **What is in the box.** The roads that intersect it are Hwy 16 E and Knockholt Loop Rd.
    FWA confirms the Bulkley River is in the box.
  - **The same text** is in the comment at data-raw/readme_figure.R:5.
  - **Fix.** "near McKilligan Road", or drop the road name.

- **[low, judgment call] README.md:11, "fly works that out".** The antecedent is "the ground [each
  photo] shows", which is the round-1 shape over a smaller set.
  - **Film always holds.** All four film media are sized.
  - **Digital frames with no footprint.**
    - The 41,249 digital frames that link a PAT-B file and no calibration report get **no
      footprint without a DEM** unless the caller first runs `fly_camera_patb()`. They are
      `inferred_format`, which is sized only through a DEM (R/fly_footprint.R:651-654).
    - After `fly_camera_patb()`, 18,883 of them still have none (inst/notes/camera-formats.md:119).
    - Withheld calibrations and unknown or ambiguous serials are always empty.
  - **Scale.** About 1-2.5% of 1.67 M frames, refused by design.
  - **Fix, if wanted.** "fly works that out for most photos". It is defensible to leave it as a
    plain summary.

- **[low, judgment call] README.md:19-20, "and it corrects known errors in the catalogue's flying
  heights".**
  - **The earlier wording.** The approved round-2 sentence said "repairs the errors it can
    identify, and keeps the scale where it cannot". The plainer rewrite dropped the second half.
  - **How it now reads.** As "the known errors".
  - **Known errors fly does not correct.**
    - Lower-tail frames that fly#60, #71 and #74 left unsettled. ×10.764, ×10 and ×2 fit
      equally, and the frame falls back to nominal scale (`implausible`, R/fly_footprint.R:1278).
    - The r ≈ 2 mass.
    - fly#93's 374 frames at r <= 0.
  - **Fix, if wanted.** "corrects the errors it can identify in the catalogue's flying
    heights". That adds no technical terms.

- **[low] README.md:50-60, the pasted output omits messages a fresh session prints.**
  - **Where they come from.** `fly_coverage()` and `fly_select()` call `sf::sf_use_s2(FALSE)`
    and `on.exit(sf::sf_use_s2(TRUE))` (R/fly_coverage.R:27-28, R/fly_select.R:61-62 and
    114-115). With sf's default (s2 on), each call prints "Spherical geometry (s2) switched
    off" before its output and "... switched on" after it.
  - **Measured.** My re-run of the example printed all four lines. Every other number matched
    the README exactly.
  - **Why it matters.** The README convention asks for "the output it really prints". These
    lines are harmless, so either add them or accept the omission.

## Mechanical checks (all pass)

- **Links.** All 23 distinct URLs in README.md return 200, including both STAC items, the
  `inst/notes` tree, MRDEM and every ecosystem site.
- **Exports.** Every function the README names is exported: `fly_coverage`, `fly_select`,
  `fly_fetch` and `fly_georef`.
- **pkgdown.** `pkgdown::check_pkgdown()` reports "No problems found". All 12 exports are in
  the reference index.
- **NEWS.** `tools:::.build_news_db_from_package_NEWS_md()` parses the new `# fly x.y.z (date)`
  headings with 0 NA versions.
- **The example.** It reproduces exactly: 59.5 / 100, then 3 photos for 81.6%. The selected
  frames are bc5306 89, 60 and 23. Their bearings are NA in the subset, so the frames are
  axis-aligned, `fly_georef()` refuses none of them, and "writes each one" holds.
- **Tags.** Tags `v0.24.0` and earlier exist, so the `@vX.Y.Z` pin form works.
- **Title and About.** GitHub About equals the DESCRIPTION `Title`.
- **STAC items.** Items 1400364 and 790359 are dated 1971-07-17 and 1981-07-13 and were
  processed by fly 0.19.0. Both have shift 0 and `placement_source` none, so "sits on its own
  estimated footprint" holds. The 1981 item's `rotation_source` is `disputed`. The figure shows
  the highway on the same SW-NE line in both panels, so the 90 degree rotation looks right
  there.

## Outside the diff (not counted, for the parent to route)

- **`fly_select()`'s own roxygen still says "fewest".** R/fly_select.R:3 and :12 say "picks
  the fewest photos to reach target coverage". That is round 2's false claim, still published
  on the reference page the README links to.
- **CITATION.cff still carries the old abstract** ("select minimum photo sets using greedy
  set-cover"). The `update-citation-cff` workflow regenerates it on the merge push, because
  DESCRIPTION changed, so no action is needed. Its cffr default also leaves New Graph out of
  the authors (soul#40). That is not this branch's change.
- **The s2 toggle overrides the caller's setting.** `on.exit(sf::sf_use_s2(TRUE))` turns s2
  on whatever the caller had set before. This is pre-existing.

## Enumeration

Every declarative sentence or clause in the changed published text. "Accepted" means the
parent's brief lists it as an accepted tradeoff.

| # | Text | Set it quantifies over | Code path / evidence | Verdict |
|---|---|---|---|---|
| 1 | README:8 tagline "Footprints, selection and georeferencing for British Columbia's historic airphotos." | package capabilities | `fly_footprint`, `fly_filter`/`fly_select`, `fly_georef` | true |
| 2 | README:10 "fly helps you find and use British Columbia's historic airphotos." | generic | `fly_filter`, `fly_select`, `fly_fetch`, `fly_georef` | true |
| 3 | README:10-11 "The province's catalogue records where each photo was taken," | every catalogue record | POINT centroid per record (AIMG_PHOTO_CENTROIDS_SP); empty POINT in fly#47 is synthetic | true |
| 4 | README:11 "but not the ground it shows." | every record | record fields: no footprint (bundled gpkg columns) | true |
| 5 | README:11 "fly works that out," | each photo (antecedent) | film R/fly_footprint.R:1001,1055; digital px×GSD :1074-1087; `unknown_format` empty :1001; `inferred_format` needs DEM :651-654 | misleading (low, judgment): finding 3 |
| 6 | README:11-12 "finds the photos over your study area," | input photos over the AOI | `fly_filter()` | true |
| 7 | README:12 "picks a small set that covers as much of it as you need," | target coverage | `fly_select_minimal()` stops at target (R/fly_select.R:169,207) or when gains are 0 (:184) | true (an unreachable target is an omission, not a false claim) |
| 8 | README:12-13 "and can download the scans" | the scans | `fly_fetch()` downloads thumbnails only (R/fly_fetch.R:3-4,24-29) | **misleading: finding 1** |
| 9 | README:13 "and place them on a map." | "can", capability | `fly_georef()`; unmeasured rotated film needs a caller `rotation` (R/fly_georef.R:369-374) | true (capability) |
| 10 | README:15 "Older photos often show a site before roads, farming and logging changed it." | domain | not a code claim | true |
| 11 | README:15-16 "That makes them a reference for what to restore toward, and a baseline for measuring change." | domain | not a code claim | true |
| 12 | README:18 "With an elevation model, fly allows for the height of the land under the aircraft," | frames on the DEM route | `dem_eligible` :1180; mean elevation under the footprint | true (does not say every frame; GSD frames are not claimed) |
| 13 | README:18-19 "which makes the footprints of film photos more accurate," | film photos with a DEM | `dem_agl`; fallbacks keep nominal (:1384) and are no worse; median 14% area bias removed (roxygen Terrain) | true |
| 14 | README:19-20 "and it corrects known errors in the catalogue's flying heights." | known height errors | slip :1272, roll table :1270-1271; unsettled frames `implausible` and nominal :1278 | misleading (low, judgment): finding 4 |
| 15 | Alt text: "Two black-and-white airphotos side by side of the same 2 km square of the upper Bulkley River valley, labelled 1971 and 1981." | figure | readme_figure.R box 2000 m; `nlyr == 2` grayscale; PNG viewed | true |
| 16 | Alt text: "A meandering river crosses each from left to right beside a highway, with forest and open meadow on the valley floor and forest on the slopes." | figure | PNG viewed; Hwy 16 E intersects the box (DRA) | true |
| 17 | Caption "The upper Bulkley River (Neexdzii Kwa)" | figure box | FWA: Bulkley River segments in the box | true |
| 18 | Caption "at McKilligan Road" | figure box | DRA: McKilligan Rd 625 m outside the box | **misleading (low): finding 2** |
| 19 | Caption "near Houston, BC, in 1971 and 1981," | the two items | STAC datetimes 1971-07-17, 1981-07-13 | true |
| 20 | Caption "placed on the map by fly." | the two items | `processing:software` fly 0.19.0; shift 0 | true (accepted) |
| 21 | Caption "Each photo sits on its own estimated footprint, so features line up approximately rather than exactly." | the two photos | shift 0, `placement_source` none | true (accepted) |
| 22 | README:36 "Functions still change between releases (NEWS)," | releases | NEWS.md | true |
| 23 | README:37 "so pin a version for repeatable work: `@vX.Y.Z`" | tags | `v0.24.0` etc. exist | true |
| 24 | README:41 "Twenty 1968 photos of the Upper Bulkley River floodplain near Houston, BC, ship with the package." | photo_centroids.gpkg | 20 rows, all `Film - BW`, 1968 (24 digital frames also ship; the text does not say "only") | true |
| 25 | README:42 "How much of the floodplain each scale covers, and the fewest photos that cover 80% of it:" | bundled data | reproduced; brute-force minimal (round 2) | true |
| 26 | README:50-55 `fly_coverage` output | one run | reproduced; omits two s2 message lines | true, minor omission: finding 5 |
| 27 | README:57-60 `fly_select` output | one run | reproduced; omits two s2 message lines | true, minor omission: finding 5 |
| 28 | README:63 "From there, `fly_fetch()` downloads the scans" | the 3 selected | thumbnails | **misleading: finding 1** |
| 29 | README:63-64 "and `fly_georef()` writes each one as a GeoTIFF on its footprint." | the 3 selected | bc5306 89/60/23 have NA bearing in the subset, so they are axis-aligned and none is refused | true |
| 30 | README:68-69 vignette: "footprints, coverage, selection and georeferencing on the bundled floodplain." | vignette | sections at Rmd:34,152,161,319 | true |
| 31 | README:70-71 "photos georeferenced with fly, to browse and download by place and date." | stac_airphoto_bc | landing page: "Queryable by location and time via rstac and QGIS" | true |
| 32 | README:72-74 Method notes: "how footprints are sized from the terrain, how the catalogue's heights and camera formats are checked, and how scans are masked and placed." | inst/notes | terrain-correction, camera-formats, border-masking, georeferencing .md | true |
| 33 | README:75 Function reference | link | 200 | true |
| 34 | README:89 fly row "Estimate airphoto footprints and select photos that cover a study area (this package)" | capabilities | `fly_footprint`, `fly_select` | true |
| 35 | README:90 "STAC catalogue of historic BC airphotos georeferenced with fly" | stac_airphoto_bc | landing page | true |
| 36 | README:81-88 other ecosystem rows | — | copied verbatim from flooded | accepted, not reviewed |
| 37 | README:92 "Historic airphotos: fly (footprints, selection, georeferencing) → stac_airphoto_bc (published)" | pipeline | stac pipeline 01/02 use fly | true |
| 38a | README:96-97 "The province's airphoto centroids in the BC Data Catalogue," | source | `bcdata` layer | true |
| 38b | README:97-98 "with the scans, flight logbooks, camera calibration reports and camera files the records link to." | record URL columns | `thumbnail_image_url`, `flight_log_url`, `camera_calibration_url`, `patb_georef_url`; "camera files" (PAT-B) is loose but fly reads camera identity from them | **"scans" misleading: finding 1**; rest true |
| 39 | README:99-100 "NRCan's MRDEM-30 elevation model, the one the height checks were measured against." | height-check constants | #54 sweep samples MRDEM (`flying_height_sweep.csv`) | true |
| 40 | README:101-102 "GDAL, through sf, for warping and masking the scans." | `fly_georef`, `fly_mask` | `sf::gdal_utils` warp and nearblack | true |
| 41 | README:106 "Cite fly with `citation(\"fly\")`, or from CITATION.cff." | files | inst/CITATION, CITATION.cff exist (cff abstract stale until CI) | true |
| 42 | README "MIT © New Graph Environment Ltd." | LICENSE | "COPYRIGHT HOLDER: New Graph Environment Ltd." | true |
| 43 | DESCRIPTION Title "Historic Airphoto Footprints, Selection and Georeferencing for British Columbia" | capabilities | as row 1; equals GitHub About | true |
| 44 | Description "Estimate the ground a historic British Columbia airphoto covers from its catalogue record;" | a photo (capability) | `fly_footprint`; refusals as row 5 | true (capability, indefinite article) |
| 45 | "given an elevation model, a film photo can be sized from the aircraft's height above the ground," | film, DEM | `dem_agl` | true |
| 46 | "with the catalogued flying height checked against the photo scale." | film on the DEM route | `comparable` :1232 | true |
| 47 | "Select a small set of photos covering an area of interest," | target coverage | `fly_select` | true |
| 48 | "download scans and flight metadata from the BC Data Catalogue," | `fly_fetch` | thumbnails; logs, calibrations and PAT-B are metadata | **"scans" misleading: finding 1** |
| 49 | "and georeference scans onto their estimated footprints." | capability | `fly_georef` works with thumbnails and full-resolution scans | true |
| 50 | man/fly-package.Rd title and description | — | identical to rows 43-49; author lines generated from Authors@R | same verdicts as 43-49 |
| 51 | _pkgdown "Estimate footprints": "The ground a photo covers, from its catalogue record, optionally with an elevation model." | group | `fly_footprint` | true |
| 52 | _pkgdown "Choose photos for an area": "Which photos cover an area of interest, how much, and a small set that covers it." | group | `fly_filter`, `fly_coverage`, `fly_select` | true |
| 53 | _pkgdown "Download" (no desc) | — | — | n/a |
| 54 | _pkgdown "Georeference": "Warp a scan onto its estimated footprint, with the black border masked." | group, capability | `fly_georef` default `mask = "border"`; `fly_mask` declined 0 of 10,105 | true |
