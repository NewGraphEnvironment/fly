# fly#52 — an R-CMD-check workflow, and what it found on day one

**Outcome:** `R CMD check` runs on ubuntu, macOS and Windows at R release for every push
to `main` and every PR, gating at `error-on: "warning"`. Merged as
[PR #67](https://github.com/NewGraphEnvironment/fly/pull/67), released as 0.14.1.

Before this, `.github/workflows/` held only `pkgdown.yaml`, so a green PR check meant the
docs site built. The package had never been checked anywhere but the author's machine.

## Measurement

| | |
|---|---|
| before the fix | 0 errors, **1 warning**, 1 note, 243 s |
| after, under the env vars the r-lib action forces | **0 / 0 / 0**, 203 s |
| suite | FAIL 0, PASS 2144 locally; 2143 on ubuntu/macOS, 2142 on Windows |
| slowest CI job | Windows 7m39s (ubuntu 6m17s, macOS 4m50s) |

The gate was demonstrated on a runner rather than asserted: the commits are ordered
workflow-first, so run
[35680424973](https://github.com/NewGraphEnvironment/fly/actions/runs/35680424973) is red
on the real pre-existing WARNING and
[35681274310](https://github.com/NewGraphEnvironment/fly/actions/runs/35681274310) is green
after the one-character fix.

**The first run found two pre-existing defects, neither reachable from this machine** —
which is the argument for the three-platform matrix made by the matrix rather than by
anyone's reasoning. A BLAS-dependent anti-vacuity premise (342 of 720 bearings here, 0 of
720 on every runner) and a Windows band count contradicting a documented invariant, plus a
second Windows-only symptom from the same root where GDAL silently shifts source zeros to
1 in the warped output.

Before any of that, a concurrent plan review found the blocker: seven blocks in
`test-fly_georef.R` asserted on **unguarded** live downloads, so a BC Data Catalogue
outage would have reddened three runners on any diff. Measured at **FAIL 11** with HTTP
blackholed and FAIL 0 / SKIP 9 with the guards.

**Six of twenty-six claims made along the way were wrong**, across three populations
enumerated by count. The most expensive: a GDAL floor of `>= 3.7` taken from this repo's
own conventions, where upstream says 3.8 — a guard that would have passed on a build with
no `-alg` flag at all.

## Evidence

- `findings.md` — every measurement, including the wrong predictions kept as wrong
- `review-plan.md` — the concurrent plan review and the disposition of each finding
- `review-round1.md`, `review-round2.md`, `review-round3.md` — the `/code-check` rounds.
  Round 1 found a defect *inside* a fix, so the loop ended on an enumeration rather than
  on a quiet round
- Runs `35680424973` (red, by design) and `35681274310` (green)

## Filed, not fixed here

- [#66](https://github.com/NewGraphEnvironment/fly/issues/66) — `^\.git$` missing from
  `.Rbuildignore`. Argued for by the review; scoped out at the plan gate, so filed rather
  than slipped in
- [#68](https://github.com/NewGraphEnvironment/fly/issues/68) — the Windows band count and
  the zero-shift, both found by this workflow
- [soul#255](https://github.com/NewGraphEnvironment/soul/issues/255) — the GDAL 3.7/3.8
  error in a shared convention that reaches every repo
