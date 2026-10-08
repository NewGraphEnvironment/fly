#!/usr/bin/env bash
# fly#101: build the third blind reader's directory (Amendment A1). The five pages of bc77087,
# each whole plus a 3 x 3 grid of crops enlarged 2x (Lanczos). Each crop is 40% of the page's
# width and height, placed at 0, 30% and 60%, so neighbours overlap by 10% of the page and no line
# is cut at a boundary. At 2x a crop is about 800 x 964 px (0.77 MP), under the size at which the
# model's image input is downsampled, so the enlargement reaches the reader. The crops are the same
# for every page, so no line is singled out. bc77070 is withheld: its pages name the same project
# and place (bc77070_4 at a clear height; bc77070_3 struck over).
# Usage: make_reader_dir.sh <repo root> <output dir>
set -euo pipefail
repo="$1"; out="$2"
src="$repo/data-raw/.cache/logbooks"
mkdir -p "$out"
for n in 1 2 3 4 5; do
  p="bc77087__bc77087_$n"
  f="$src/$p.jpg"
  [ -f "$f" ] || { echo "missing $f" >&2; exit 1; }
  cp "$f" "$out/$p.jpg"
  w=$(magick identify -format '%w' "$f"); h=$(magick identify -format '%h' "$f")
  cw=$(( w * 40 / 100 )); ch=$(( h * 40 / 100 ))
  r=0
  for yo in 0 $(( h * 30 / 100 )) $(( h * 60 / 100 )); do
    r=$((r + 1)); c=0
    for xo in 0 $(( w * 30 / 100 )) $(( w * 60 / 100 )); do
      c=$((c + 1))
      magick "$f" -crop "${cw}x${ch}+${xo}+${yo}" +repage -filter Lanczos -resize 200% \
        "$out/${p}__row${r}_col${c}_x2.png"
    done
  done
done
ls "$out" | wc -l
