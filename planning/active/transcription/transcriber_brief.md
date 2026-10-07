# Logbook transcription brief

You are transcribing scanned aerial-photography flight logbook pages (British Columbia, 1970s) into a CSV.
The images are in the directory named in your task. Each page is there whole (`<page>.jpg`) and as four
overlapping quadrant crops enlarged 2x (`<page>__quadrant<n>_x2.png`: 1 top-left, 2 top-right,
3 bottom-left, 4 bottom-right). The crops add no information that is not on the page; they are there so
small handwriting is easier to see. Read EVERY image file in that directory with the Read tool.

Rules — these matter:
- Use ONLY the images. Do not open any other file, repository, issue, note, or website, and do not search for the
  rolls. Do not spawn subagents. Do not use the Bash tool.
- Transcribe what is written. Where you infer something that is not written, say so in `note` ("Inference, not
  written: ...").
- Do not guess a digit. If a value cannot be read, leave the interpreted field blank and set `legibility` to
  `partial` or `illegible`, describing the doubt in `note`.
- There is no expected answer. Nothing you are told elsewhere about these rolls exists; read the pages.

## Stage A: rows.csv

Write a CSV (RFC 4180, double-quoted strings, header row) to `<your directory>/rows.csv` with exactly these columns:

| column | meaning |
|---|---|
| file | the page's image file name (`<page>.jpg`), exactly, even where you read the line on a crop |
| film_roll | the part of the file name before `__` (e.g. `bc5285`) |
| page_rolls | the roll identifier(s) as written on the page header |
| frames_final | the FINAL exposure numbers this line covers, as a range `a-b` or a single number `a`. Final numbers are the ones assigned to the processed film (often a separate "FINAL" or red-ink column); field/exposure counter numbers are NOT finals. Blank if the line has no final numbers |
| frame_from | integer first final number of the line (blank if none) |
| frame_to | integer last final number of the line (blank if none) |
| height_as_written | the flying-height entry for this line exactly as written ("18.0", "ditto", "16.5 MSL", ...) |
| height_header | the column header of that height field exactly as printed/written (e.g. "TRUE HEIGHT (M'/M.S.L.)") |
| height_ft_interpreted | the height in FEET as a plain number, ONLY where the unit is established by the header or entry. These forms usually give thousands of feet above mean sea level, so "18.0" under an M'/M.S.L. header is 18000. Resolve "ditto"/" marks to the value they repeat. Blank if the unit cannot be established or the value is unreadable |
| leading_digit_confidence | for EVERY line whose height is written as a figure (not a ditto): `clear` if the first digit of the height can be read as only one digit; `uncertain` if it could be more than one; `illegible` if it cannot be read. For a ditto line, `ditto` |
| leading_digit_alternatives | where `leading_digit_confidence` is `uncertain` or `illegible`, every digit it could be, separated by `/` (e.g. `1/7`), most likely first only if one is more likely; blank otherwise |
| focal_as_written | the lens focal length as written on the page (e.g. `6"`, `152.4`, `12"`), blank if none |
| focal_mm | focal length in mm (6" = 153, 12" = 305, 3.5" = 88; otherwise as written in mm), blank if none written. Do NOT infer it from a camera model |
| scale_as_written | any photo scale written on the page, verbatim, with where it is written if it is not on the line (e.g. "1:15,840 (title)"). Blank if none |
| legibility | `clear`, `partial` or `illegible` for this line |
| note | anything that affects reading: sheet n of m, camera, strips, overwritten numbers, reflights, cancelled lines, your doubts |

One row per logbook line that carries a final frame range or a height. If a page has no such lines (cover sheet,
index, blank), write one row for it with only `file`, `film_roll`, `page_rolls`, `legibility` and a `note`
saying what the page is.

Do not start Stage B until `rows.csv` is written. Do not change `rows.csv` after Stage B begins.

## Stage B: glyphs.csv and verdict.md

For EVERY row of `rows.csv` whose `leading_digit_confidence` is `uncertain` or `illegible`, compare that
glyph with the same digits written elsewhere on these pages, as follows.

1. For each candidate digit in `leading_digit_alternatives`, find every instance of that digit that is
   written by hand on these pages and is unambiguous: in dates, roll numbers, frame numbers, headings,
   other heights, anywhere. Use as many as you can find, at least three per candidate where they exist.
2. For each reference, judge whether it is written by the same hand as the disputed glyph (`same`,
   `different`, `unsure`), from the handwriting around it.
3. Compare the disputed glyph's form with each reference: the top stroke, the junctions, the lower part,
   the stroke direction where visible.

Write `<your directory>/glyphs.csv` (RFC 4180, double-quoted strings, header row), one row per reference:

| column | meaning |
|---|---|
| disputed_file | `file` of the disputed row |
| disputed_frames | `frames_final` of the disputed row |
| candidate | the candidate digit this reference is an instance of |
| ref_file | the page image the reference is on |
| ref_where | where on that page: which field, which line, what the reference is part of (e.g. "date '13/8/..', top right") |
| ref_text | the full text the reference digit is part of, as written |
| same_hand | `same`, `different` or `unsure` |
| resembles_disputed | `yes`, `no` or `partly`, and what in the form decides it |

Then write `<your directory>/verdict.md`, with one section per disputed row:

- the row (`file`, `frames_final`, `height_as_written`);
- your decision: the digit, or `undecided`. Decide a digit ONLY if the same-hand references support it
  over every other candidate; otherwise write `undecided`. A digit you only lean towards is `undecided`
  (say which way you lean and why, separately);
- the references (by `ref_file` and `ref_where`) that decided it.

When finished, reply with ONLY: the paths of rows.csv, glyphs.csv and verdict.md, the number of rows in
each csv, and the number of images read.
