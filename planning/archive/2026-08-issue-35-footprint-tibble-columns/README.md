# #35 — fly_footprint() dropped its reporting columns on tibble input

**Outcome:** fixed and released as v0.5.1 in [PR #36](https://github.com/NewGraphEnvironment/fly/pull/36), which also closed #31.

`sf::st_sf()` keeps only its first argument when that argument is a tibble, so the four
reporting columns `fly_footprint()` attaches as trailing arguments were discarded for
every `bcdata::collect()` caller — which is to say for the package's own documented data
source. Nothing errored: geometry and every downstream number stayed correct and only the
audit trail went missing, which is how it survived two releases. The fix assigns the
columns onto the attribute frame before `st_sf()` sees it.

The durable lesson is the fixture one, and it is the seventh instance in this package
(see `inst/notes/terrain-correction.md` for the six from #9): **every fixture here reads
back as plain `sf, data.frame`, so no case added along the existing axis could have found
this.** The tests now sweep the input-class axis instead. Two further defects fell out of
review — a colliding `footprint_basis` column that was never overwritten, so the
documented filter read the caller's column instead of fly's answer; and `logical` columns
on zero-row input, which broke binding an empty result to a populated one.

Two claims of mine were falsified by review and corrected before merge: that the input
class is *preserved* (the set survives, the order does not — `st_transform()` moves `sf`
to the front), and that the overwrite change made `fly_footprint()` idempotent (it does
not; a plain 20-row sf returns 100 rows silently).

**Closing commits:** `a566074` (sweep), `ae628bc` (fix), `28c4f85` (#31 retitle), `3d902fa` (release).
**Verified:** suite 225 → 338, `R CMD check` Status OK, and end to end against the live
catalogue — 1405 real centroids, all four columns present, 151 frames excluded by the
documented filter that were invisible before.
