## Outcome

Rewrote the README to say, in plain words, what fly does and what a historic photo gives a site:
a reference condition for restoration and a baseline for monitoring change. It now shows two real
airphotos of the upper Bulkley near McKilligan Road (1971, 1981) made by
`data-raw/readme_figure.R`, uses the ecosystem table shared with the sibling packages, and follows
soul's `readme.md` section order. diggs is left out by decision, so #7 stays open. Two structural
defects surfaced while exploring and were fixed: the published changelog showed all 37 releases as
one "development version" section (headings promoted to `# fly x.y.z (date)`), and the reference
index was an ungrouped list (now four groups). The lasting lesson is about the text, not the code.
Each review round found a sentence written from the typical case (a film frame, the bundled set,
the algorithm's aim) and stated of every member of the set its noun names. Round 2 found that
round 1's fix (turning "each" into a plural) restated the same claim, so the loop was closed by
round 3's enumeration of all 54 published sentences rather than by a quiet round.

## Measurement

- Changelog sections on the built site: 1 before, 37 after. R's NEWS parser reads 37 versions,
  0 NA.
- Code-check: round 1 found 3 findings, round 2 found 5 (2 inside round 1's fixes), and round 3
  enumerated 54 rows and found 9 not true. All were fixed, except the omission of sf's s2
  messages from the example output, which was accepted.
- Notable false claims removed: fly downloads thumbnails, not scans (DESCRIPTION said "scans" on
  main too); selection is greedy, so "fewest" is not guaranteed; the DEM route and the height
  check do not reach digital frames sized from GSD.
- Tests: 5765 pass, 0 fail (no R code changed).

Closed by: PR for #104 (v0.24.1)
