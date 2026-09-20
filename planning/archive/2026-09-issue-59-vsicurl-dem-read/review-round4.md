# Review round 4 — LOST, not clean

Scope was the claims written by 29ffc37 — the fix for round 3's findings, which the mechanism
round 3 named predicts is where the next defect sits.

**This round produced no findings.** It ran for roughly twenty minutes, wrote this stub, and
then stopped writing at a 1.47 MB transcript — the same size at which the first round-1 agent
died. It was stopped rather than waited on.

Recorded as **lost, not clean**, because from the calling side an agent that had nothing to say
and an agent that died are indistinguishable (`conventions/planning.md`). Nothing here should be
read as a round that swept these claims and found them sound.

What stands in its place, and why the loop was closed anyway:

- Round 3 terminated the loop on its own terms — it named the mechanism and enumerated all 63
  factual claims, which is the criterion `/code-check` sets for stopping once a round has found
  a defect inside a fix.
- The claims 29ffc37 added were then enumerated by hand against their measurements, and that
  pass found two further instances of the same mechanism: NEWS still described the regression
  test as "40 small frames ... with a premise asserting the fixture can still reach the defect"
  (both halves superseded by the rewrite), and the PR body and this README still carried "nine
  shapes", "under 3 cells across" and "dem_coverage unaffected". All corrected.
- Every number published in the change was cross-checked across all seven documents that state
  one, and the end-to-end remote timing was re-run against the final tree (4.3 s, identical
  coverage and height_agl).
