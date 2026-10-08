# Code-check round 3: fly#101 branch diff (main...HEAD, at 5f09e58)

## Verified (no issue)

- Real reader, re-scored: `unsettled (Stage B undecided)`, gate 211/203 (0.962), tally 3=1 5=0. The
  reader directory's 50 md5s match `pages_q.md5`, and `rows.csv` is still `c6e6b65d...`.
- The reader's transcript (`subagents/agent-acc9ad1c382002783.jsonl`): 157 lines, **0 unparsable**, 60
  tool calls, 58 Reads in `pages_q`. `audit.py` on it gives PASS, 50/50 images.
- New test: 10 PASS (file 218/0/0/0). Its assertions together imply `unsettled` under both commit paths:
  the target is `uncertain`, which rules out path (a), and the decision is `undecided`, which rules out
  path (b). I found no way for it to pass while its claim is false.
- `glyphs.csv` ref_ids are unique. The real target's alternatives are `3/5`. So none of the findings below
  can move the shipped verdict.
- File line 656 is the `bc77087_1` row, and only its note changed. The NEWS figures check against their
  producers (1000 x 1205, the gate and audit results, 3/5 leaning 3, 7 not listed). So does 2.6% off x2.

## Mechanism

The scorer does not test the rule's predicates on what the reader wrote. It tests them on a normalised or
derived form of the cells:
- alternatives with the non-digits stripped;
- finals sorted with NA last;
- figure-bearing rows defined by membership in a list of labels;
- support counted in rows rather than in distinct references.

Each normalisation maps a malformed or absent value onto a value the next predicate accepts. So "not in
the format the rule reads" shares an encoding with a compliant answer, and fails toward settled. This is
fly#53's "an absent measurement never shares an encoding with a real one", and code-check.md's "never
rebuild structure by splitting a joined string". Rounds 1 and 2 fixed three instances. Four more remain
in score.R, and the auditor carries the same mechanism (a skipped line read as compliant).

## Findings

All were reproduced on scratch copies of the reader directory under the scratchpad (`r3/`). The real data
reaches none of them.

- **[fragile]** `planning/active/transcription/score.R:77-83`: a target row is selected only if its
  label is in a fixed list.
  - "Figure-bearing" is implemented as `leading_digit_confidence %in% c(clear, uncertain, illegible)`. A
    line 1 whose height is a figure but whose label is anything else (`unclear`, `probable`) is silently
    dropped from target selection. The next labelled row becomes line 1.
  - The round-2 fix (`:82`) covers only an unparsable first final, not an unrecognised label.
  - Scratch T1: line 1 labelled `unclear` and the line-2 ditto relabelled `clear` `3.8` gives
    `target: frames 5-26 ... VERDICT: settled 3.8`.
  - This differs from the accepted `ditto` case. A line 1 written as a figure is still figure-bearing by
    the rule's definition, so only the code's proxy drops it.
  - Fix: if any row on the target page has a non-blank `height_digits` or a figure in
    `height_as_written`, and a label outside the three, report no commitment.
- **[fragile]** `score.R:83`: a tie at the lowest first final is broken silently by CSV order.
  - The rule ("the row with the lowest first final") does not say what happens on a tie. `order()` is
    stable, so the earlier row in the file wins.
  - Scratch T2: a `clear` `7.8` row with `frame_from` 1, placed before the real `uncertain` line 1, gives
    `settled 7.8`. Swapping the order gives the other outcome.
  - Fix: if more than one figure-bearing row shares the minimum first final, report no commitment.
- **[fragile]** `score.R:88-89`: alternatives are reduced to digits before being split.
  - `gsub("[^0-9/]", "", ...)` turns `3/5 / not 7` into `3/5//7`, so `alts = {3, 5, 7}`. The A1.6/case-17
    check "the decision is among the Stage A alternatives" then admits a digit Stage A explicitly ruled out.
  - Scratch T4: alternatives `3/5 / not 7`, decision 7 citing two same-hand `yes` 7s gives `settled 7.8`.
    The control with alternatives `3/5` gives `unsettled (decided a digit Stage A did not list ...)`.
  - The same strip turns `3 or 7` into the single token `37`, which happens to fail safe.
  - Fix: require the cell to match `^[0-9](/[0-9])*$` after trimming, and otherwise report no commitment.
- **[fragile]** `score.R:114-118,128`: `sup()` counts rows, not distinct references.
  - A1.6 says "more same-hand `yes` references than every other candidate". A `glyphs.csv` that repeats a
    `ref_id` counts that reference once per row.
  - Scratch T3: alternatives `3/7`, r14 set to candidate 7 `same` `yes` and duplicated, decision 7 citing
    r14. The tally reads 3=1 7=2 and the verdict is `settled 7.8`. One distinct reference each way is a tie.
  - The control without the duplicate gives `unsettled (a competing digit has as much support)`.
  - Fix: count `unique(ref_id)`, or report a scoring error on duplicate ref_ids.
- **[fragile]** `planning/active/transcription/audit.py:14-17`: an unparsable transcript line is skipped,
  not failed.
  - `except json.JSONDecodeError: continue` drops any line it cannot read. A non-compliant tool call on a
    truncated or corrupt line therefore never enters `calls`. Unreadable is read as compliant.
  - Scratch: the real transcript plus one truncated line holding a `Bash` `tool_use` still gives
    `tool calls: 60 ... AUDIT: PASS`.
  - The real transcript has 0 such lines, so this run's PASS stands.
  - Fix: count undecodable lines and FAIL if any exist.
- **[published claim]** `planning/active/findings.md:296-314` ("Code-check round 2", the enumeration). The
  two assignment sites and the single settled expression are right, but the closing claim is not.
  - "Every condition in A1 items 5-7 is in that list, and the list is all the code does" overstates.
    - The list omits target selection by label set and by CSV order on ties.
    - It states three conditions in the rule's terms that the code implements on proxies: "decision among
      the Stage A alternatives" is tested on digit-stripped text, "more same-hand `yes` references" is a
      row count, and "a target row identified by a parsed first final" covers only labelled rows.
  - So the enumeration does not end the class, as the four findings above show.
- **[published claim, minor]** `inst/notes/terrain-correction.md:1040` and `findings.md:247`: "The one
  feature all three readers name is a flat top; they part on what is below it."
  - fly#93's producer (file line 656's note, `batch4_rows.csv`) says only "flat top, read as 3 not 7". It
    names no lower part.
  - fly#97 ("single descending stroke with a hooked foot") and fly#101 ("a curve below") are the two that
    describe one. "They part on what is below it" is stated over three readers where two producers support it.
- **[published claim, minor]** `CLAUDE.md:461`: "fly#101's rule forbids it" (a fourth subagent read).
  - The producer is A1.9, which makes this read's verdict final and allows no re-spawn within fly#101. It
    says nothing about a read under a later issue.
  - "A fourth draw from the same instrument" is the supported reason. "The rule forbids it" widens the
    rule's scope.
- **[published claim]** `planning/active/province_request_draft.md:19-20`: "read ... by three readers at
  the published size".
  - All three are Claude subagents of one model family, and findings.md's own limitation says they "are
    not three independent human reads".
  - A provincial recipient will read "three readers" as three people. This is the one outward-facing
    document, and it states the read's independence more strongly than its producer does. (Unsent, so the
    user decides. Flagged so the wording is chosen deliberately.)
- **[published claim, minor]** `planning/active/findings.md:35`: "**The province serves no larger copy.**"
  - The producer is four constructed sibling URLs (404) and a directory listing that answers 403. That
    shows none at the paths guessed, not none served.
  - The note's wording, "no larger copy was found beside it", is the supported form. The bolded heading in
    the archived record is wider than its body.

No security issues.
