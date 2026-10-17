# Progress — README: describe terrain-aware footprints and per-roll calibration (#104)

## Session 2026-10-16

- Plan-mode exploration; phases approved by the user, then amended by them before the baseline
  (simple language, real airphotos, no diggs, the ecosystem table)
- Created branch `104-readme-describe-terrain-aware-footprints` off main
- Scaffolded the PWF baseline from issue #104 with the amended phases
- Next: start Phase 1
- Phase 1: claims checked against the code (findings.md table). The height check and roll-table
  repairs run only with `dem`, so the README ties them to an elevation model
- Phase 2: `data-raw/readme_figure.R` → `man/figures/readme-history.png`; a 1-99% stretch per scan
  because the 1971 scan rendered washed out. The two photos are offset by a few hundred metres,
  each on its own estimated footprint, and the caption says so
- Phase 3: README rewritten in the `readme.md` order. The example's output comes from a real run
  on the bundled data, with sf's s2 on/off messages left out. Links (23) all 200; functions named
  are all exported; no mention of diggs. DESCRIPTION `Description` rewritten to match the opening
