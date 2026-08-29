# Issue #30 — footprints for digital frames

`fly_footprint()` applied a 9-inch negative to every frame, including the
~20% of catalogue frames recorded on a digital sensor, which has no negative.
The resulting rectangle was wrong by an unknown factor while still drawing,
still overlapping neighbours, and still producing a coverage percentage — and
it propagated through all five functions that consume footprints.

Each row is now sized from its `media` value, with `footprint_basis` recording
the outcome and an empty geometry where the format cannot be resolved. Every
downstream consumer reports how many frames it excluded. `negative_size` keeps
its meaning as the film dimension; `format_size` supplies widths for formats
`fly` does not ship. Digital defaults were deliberately not invented — that
research is #32.

Two bugs surfaced that the issue did not name: `fly_coverage()` dropped an
entire group when all its footprints were unsized (`st_area()` on an empty
intersection returns `numeric(0)`, collapsing the tibble to zero rows), and the
internal helpers were briefly inserted between the roxygen block and
`fly_footprint()`, which bound `@export` to a helper and silently removed
`export(fly_footprint)` from NAMESPACE while the suite stayed green.

Closed by PR (see `Fixes #30`). Suite 126 pass / 0 fail; no new lints.
Follow-up: #32 (sensor widths), related #9, #10.
