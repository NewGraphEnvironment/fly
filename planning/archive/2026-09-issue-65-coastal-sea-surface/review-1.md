# Plan review 1 — fly#65 (Plan agent, 2026-09-29)

Returned as reply text (Plan agents have no Write tool); recorded here by the parent.
Findings verified against the code before acting — see findings.md "Amendment 2".

| id | class | finding | verified / action |
|---|---|---|---|
| A1 | Assumption | W is right for total length/area (exact in 1D, Jensen residual ~w(1−w)e² in 2D); L is right for the **land edge**. Which matters depends on the consumer: `fly_coverage`/`fly_overlap` (area) vs `fly_filter`/`fly_select` on a land AOI (edge) | Analytic, accepted. Rule now scores both metrics |
| A2 | Assumption | Datum, tides (≤0.29% width at the lowest AGL admitted), rounded heights: none makes L right. MRDEM is a DTM, so "the surface the camera sees" is loose on canopy — note must not claim it | Accepted; wording in the note |
| A3 | Assumption | Tilt (#10) moves an edge 2–7% of half-width — noise for any empirical per-frame witness, not for a simulation | Accepted |
| B1 | Blocker | Spacing measures how exposures were timed (intervalometer at planned datum, or an overlap regulator tracking nadir texture — none over water), not footprint geometry; biased toward L over sea | Accepted as a stated risk; spacing demoted to secondary, bias predicted in advance |
| B2 | Blocker | Fixed +0.2 threshold assumes full adaptation α=1; control 2 admits 0.5–1.5 and is judged on a point estimate | Moot once spacing is secondary; reported with α̂ |
| B3 | Blocker (code) | `take_runs()` cut runs from a pool already filtered to coastal-in-stratum frames, so runs skip frame numbers and frames at gaps lose their bearing | **Confirmed by reading lines 224–248.** Run stopped in Stage 2 before any frame was measured; runs now drawn from the whole roll around a coastal centre frame |
| R1 | Resolution | per-frame 2σ ≈ 21% width; predicted signal ~2.5–3.3%; slope needs within-run spread in d, near zero on shore-parallel lines | Accepted |
| R2 | Gap | shared term, within-roll design changes, camera off over water, interpolated centroids, admission gated on W's r | Recorded as spacing caveats |
| W1 | Recommendation | Deterministic ray-cast reference per frame, scoring W, L (and per-side sizing) on area and land-edge metrics, with flat and step synthetic controls | **Adopted as primary** |
| W2–W5 | Witnesses | thumbnails (pooled only), PAT-B (digital never DEM-sized), GSD and r are planning witnesses | Not used |
| G1 | Gap | materiality gate on d at 1% width | Adopted |
| G2 | Acceptance | Phase 4 needs an unresolved / docs-only branch | Adopted |
| G3 | Gap | `dem_elev_sd` is not blind: half-sea against 500 m land gives sd ≈ 250 m; script drops it | **Confirmed**; kept and published by sea fraction |
| G4 | Gap | LidarBC plausibly nodata over water → package would do L on LidarBC, W on MRDEM | One coastal probe added |
| G5 | Gap | verdict code ≠ rule text | Superseded by Amendment 2, conditions written before the run |
| G6 | Assumption | only one land/water witness survives the probe | Accepted; text updated |
| G7 | Gap | `land_border` hole at Point Roberts / Boundary Bay | Tightened |
| G8 | Gap | population count not fly#58's eligibility; header cites a path that does not exist yet | Fixed |
| S1 | Scope | per-side sizing is a remedy outside the issue's list | Scored in the ray-cast, not shipped |
| S2 | Scope | an L change couples into the #54 ratio band and roll tables | Named in the L branch |
| S3 | Scope | digital DEM-route population is ~6 frames | Dropped explicitly |
| AC1–3 | Acceptance | verdict per downstream function; fixture should pin `dem_elev_sd`; bootstrap reproducible | Adopted |
