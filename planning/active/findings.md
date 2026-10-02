# Findings — Infrared film (Film - BW IR, Film - Colour IR) is sized as an unknown format (#89)

## Issue context

## Problem

`fly_film_media()` (`R/fly_footprint.R`) lists `"Film - BW"` and `"Film - Colour"` only, so the catalogue's infrared film — **`Film - BW IR` (771 frames) and `Film - Colour IR` (3,054 frames)**, counted over the cached catalogue in `data-raw/.cache/centroids` — is treated as an unknown recording format: `footprint_basis = "unknown_format"`, an empty geometry, and no coverage, selection or georeferencing.

Found in fly#53's film rotation campaign, where every drawn roll of the `bci` and `bcf` series, and three `bcc` rolls from 1965-69, came back `legs_unscorable`: e.g. `bcc23`, `bcc7`, `bcc8` and `bcf07060` are all `Film - Colour IR` at focal 305, and 73/73, 87/87, 87/87 and 247/247 of their footprints are empty.

## The question

#30 refuses an unknown format rather than guessing, and that is right until someone establishes the format. IR aerial film was flown in the same mapping cameras on the same 9-inch rolls as panchromatic and colour, so it is probably `negative_size` — but that is reasoning, and #30's whole point is that a 9-inch negative applied to a different format still draws a plausible rectangle. Establish it before adding the media values:

- Thumbnail aspect and the collar geometry `fly_mask()` measures (#23) against the BW/colour population.
- Adjacent-frame spacing against designed overlap at the stated scale and focal, as #60 used for heights.

Once sized, the IR rolls in `inst/extdata/film_rotations_excluded.csv` (state `legs_unscorable`, or unmeasured) can be calibrated with `fly_rotation_calibrate()`.


## Errors Encountered

| Error | Resolution |
|-------|------------|
