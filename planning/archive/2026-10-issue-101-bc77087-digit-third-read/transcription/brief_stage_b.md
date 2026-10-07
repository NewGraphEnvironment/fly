Thank you. A second task on the same images. Use only the Read tool, only on the same image files. Do not
change your rows: they are recorded.

For EVERY row you wrote whose `leading_digit_confidence` is `uncertain` or `illegible`, compare that glyph
with the same digits written elsewhere on these pages:

1. For each candidate digit in that row's `leading_digit_alternatives`, find every instance of that digit
   written by hand on these pages that is unambiguous: in dates, roll numbers, frame numbers, headings,
   other heights, anywhere. Use as many as you can find, at least three per candidate where they exist.
2. For each reference, judge whether it is written by the same hand as the disputed glyph (`same`,
   `different`, `unsure`), from the handwriting around it.
3. Compare the disputed glyph's form with each reference: the top stroke, the junctions, the lower part,
   the stroke direction where visible.

If no row of yours is `uncertain` or `illegible`, say so in one line and stop.

Otherwise reply with two fenced code blocks, RFC 4180, every string double-quoted, header row first.

The first starts with the line "```csv glyphs.csv": one row per reference, columns

| column | meaning |
|---|---|
| ref_id | `r1`, `r2`, ... unique |
| disputed_file | `file` of the disputed row |
| disputed_frames | `frames_final` of the disputed row, exactly as in your rows |
| candidate | the candidate digit this reference is an instance of |
| ref_file | the page image the reference is on |
| ref_where | where on that page: which field, which line, what the reference is part of (e.g. "date, top right") |
| ref_text | the full text the reference digit is part of, as written |
| same_hand | `same`, `different` or `unsure` |
| resembles_disputed | `yes`, `no` or `partly`, then what in the form decides it |

The second starts with the line "```csv verdict.csv": one row per disputed row, columns

| column | meaning |
|---|---|
| disputed_file | as above |
| disputed_frames | as above |
| decision | the digit, or `undecided`. Decide a digit ONLY if the same-hand references support it over every other candidate. A digit you only lean towards is `undecided` |
| lean | where `decision` is `undecided`: the digit you lean towards, or blank. Blank where you decided |
| ref_ids | the `ref_id`s that decided it, separated by `;` (blank if undecided) |
| reasoning | one or two sentences |

Nothing after the second block.
