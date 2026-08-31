# Review — `b98b863` "Keep CLAUDE.md off the pkgdown site (#42)"

Reviewer: code-review subagent. Date: 2026-08-31.
Scope: `.github/workflows/pkgdown.yaml` (the only file the commit touches, and the only
workflow in the repo that deploys to `gh-pages`).

Verdict: **the change is correct and does what it claims.** Two low-probability
false-pass paths in the allowlist gate, both verified by executing the shipped script.
One factual claim in the commit message / issue body is wrong in a way that does not
affect the remedy.

---

## Findings

- **[fragile]** `.github/workflows/pkgdown.yaml:78-81` — `case " $allowed " in *" $b "*)`
  is a **substring** test, not a token test, so a page whose name is a contiguous
  multi-word substring of the allowlist passes silently.

  Verified by running the gate script extracted verbatim from the YAML:

  | `docs/` contents | expected | actual |
  |---|---|---|
  | `index.html`, `authors index.html` | fail | **`rc=0`, "Root pages are all declared."** |
  | `index.html`, `404 authors.md` | fail | **`rc=0`, "Root pages are all declared."** |

  `allowed` is `"404 authors index LICENSE LICENSE-text"`, so `" authors index "` and
  `" 404 authors "` are both substrings of `" $allowed "`. This is exactly the
  escape-hatch class CLAUDE.md warns about ("A guard's escape hatches are where it goes
  to die") and it fails toward **pass**, which is the dangerous direction.

  Exploitability here is low: reaching it needs a `docs/` root page whose filename
  contains a space, which in this repo can only come from a root `.md` with a space in
  its name — and `R CMD check` rejects those outright ("checking for portable file
  names"). So this is not a live leak, it is a guard that is weaker than it reads.

  Fix is one line, and it also removes the `${b%.html}`/`${b%.md}` interaction below:

  ```sh
  ok=0
  for a in $allowed; do [ "$a" = "$b" ] && { ok=1; break; }; done
  [ "$ok" = 1 ] || case " $unexpected " in *" $b "*) ;; *) unexpected="$unexpected $b" ;; esac
  ```

  (Note the same substring shape is used for the `$unexpected` de-duplication on
  line 80. There it only affects whether a name is *repeated* in the message, so it is
  cosmetic — but it is the same construct and should be changed with it.)

- **[fragile]** `.github/workflows/pkgdown.yaml:77` — the two suffix strips are applied
  unconditionally in sequence (`b="${b%.html}"; b="${b%.md}"`), so `index.md.html`
  reduces to `index` and passes. Verified: `docs/index.md.html` present ⇒ `rc=0`.
  Strictly more contrived than the finding above (pkgdown produces no such name), and
  the token-comparison fix does not remove it — strip only one suffix, matched to which
  glob produced the file, if it is worth closing at all.

### Not findings, but worth recording

- **Factual error in the commit message and issue #42 body.** Both state the second copy
  is "a verbatim copy of the source, served as-is". It is not. `gh-pages:CLAUDE.md` is a
  pandoc-regenerated markdown twin — pkgdown 2.2 emits an `.md` alongside every root
  `.html` for `llms.txt`, and the published file is re-wrapped, not byte-identical to
  the source:

  ```
  source : "...Estimate ground footprints from airphoto centroids and scale,"   (~110 col)
  gh-pages: "...Estimate ground\nfootprints from airphoto centroids and scale,"  (~72 col)
  ```

  The content is still fully published, so the remedy (`rm` before build) is unchanged
  and the "three copies" count is right. Per the "issue bodies get edited, not appended"
  convention, the #42 body is worth a one-word correction; the commit message is
  immutable history and stays as is.

- **`clean: true` changes what a degraded build costs.** With `clean: false` a build that
  silently produced fewer pages left the old ones published; now it deletes them. The
  gate's population check is only `[ -f docs/index.html ]`, so it does not catch a
  partial site. This is the tradeoff CLAUDE.md's pkgdown convention explicitly endorses
  (auditability), the loss is recoverable from `gh-pages` history and from the next good
  build, and pkgdown errors rather than half-building — so it is context, not a defect.

- **Gate scope is root pages only.** `docs/articles/`, `docs/reference/`,
  `docs/search.json` and `docs/llms.txt` are not inspected. That is the right scope
  (the mechanism being closed is `package_mds()`), and because the gate runs *before* the
  deploy step, a failure blocks publication of the index and `llms.txt` too — nothing
  half-publishes.

---

## Verification performed

Everything below was measured, not reasoned.

**1. The gate's shell, run verbatim from the YAML.** All six of the committer's-plus-mine
cases behaved as documented:

| case | result |
|---|---|
| real gh-pages root set minus CLAUDE (`404/authors/index/LICENSE/LICENSE-text`, `.html`+`.md`) | pass, `rc=0` |
| + `CLAUDE.html` and `CLAUDE.md` | fail, `rc=1`, "CLAUDE" named **once** |
| empty `docs/` | fail, `rc=1`, "the build produced no site" |
| non-page assets only (`llms.txt`, `sitemap.xml`, `pkgdown.yml`, `search.json`, `logo.png`, `katex-auto.js`, `lightswitch.js`, `link.svg`) | pass — correctly outside the `docs/*.html docs/*.md` globs |
| subdirectory content (`docs/reference/foo.html`) | pass — correctly outside the top-level glob |
| filename containing a newline (`LICENSE\nevil.md`) | fail, `rc=1` |

Other shell properties checked and found sound:
- Unmatched globs are handled (`[ -e "$f" ] || continue`); no `nullglob` dependency.
- Glob metacharacters in a filename are **not** re-interpreted — `" $b "` is a quoted
  portion of the `case` pattern, so it is literal. `docs/foo*.html` is correctly
  reported as unexpected rather than matching anything.
- `set -eu`: every variable (`allowed`, `unexpected`, `f`, `b`) is assigned before use;
  `basename` failing aborts the step (fails toward abort, correct for a guard).
- BSD/GNU portability is not in play — this runs on `ubuntu-latest` bash only — and the
  script uses no `sed`/`grep` extensions regardless.
- No `ls` parsing, no `2>/dev/null` on a mutating command, no `;`-chained mutations.
- The empty-population trap CLAUDE.md names ("a loop over nothing exits 0") is explicitly
  closed by the `docs/index.html` precondition, and the failing case was demonstrated.

**2. The `allowed` list is exactly right for this repo — neither too broad nor too
narrow.** Currently published root files on `gh-pages`:

```
404.html 404.md  authors.html authors.md  index.html index.md
LICENSE.html LICENSE.md  LICENSE-text.html LICENSE-text.md
CLAUDE.html CLAUDE.md                        <- the leak
.nojekyll  katex-auto.js  lightswitch.js  link.svg  llms.txt
logo.png  pkgdown.js  pkgdown.yml  search.json  sitemap.xml
articles/ deps/ news/ reference/
```

`allowed = "404 authors index LICENSE LICENSE-text"` covers every `.html`/`.md` root page
except `CLAUDE`, and no more. Every file listed in the review brief (`llms.txt`,
`sitemap.xml`, `logo.png`, `search.json`, `pkgdown.yml`, `katex-auto.js`,
`lightswitch.js`, `link.svg`) falls outside the `docs/*.html docs/*.md` globs and is
correctly out of scope — confirmed by execution, not by reading. `404.md` is a real
published file and is covered.

**3. `pkgdown:::package_mds()` returns `CLAUDE.md` and nothing else** for this repo.
Verified directly against the working tree with pkgdown 2.2.0. Root `.md` files are
`CLAUDE.md`, `LICENSE.md`, `NEWS.md`, `README.md`; the latter three are pkgdown's
hardcoded exclusions. There is no `.github/CODE_OF_CONDUCT.md` or `SUPPORT.md`, and no
`CITATION.cff` / `inst/CITATION`, so no additional root page is generated.

**4. `clean: true` is safe.**
- **No `CNAME` on `gh-pages`** (confirmed by API listing, count 0). Independently
  corroborated at the source: `pkgdown:::build_github_pages()` writes a `CNAME` only when
  `cname_url(url)` is non-`NULL`, and `_pkgdown.yml`'s `url` is
  `https://newgraphenvironment.github.io/fly/` — a `github.io` URL, which yields `NULL`.
  The `www.newgraphenvironment.com/fly/` address is the org site's apex domain serving
  the project site as a subpath, so nothing on this branch owns it.
- **No `dev/`** (count 0). `_pkgdown.yml` sets no `development: mode:`.
- **`.nojekyll` is regenerated by the build** — `build_github_pages()` calls
  `write_if_different(pkg, "", ".nojekyll")` unconditionally. So `clean: true` cannot
  strand the site behind Jekyll processing.
- **`docs/` is untracked**: `.gitignore:6` lists `docs`, `git check-ignore -v docs`
  confirms, and `git ls-files docs` returns nothing. Nothing in the deployed tree is
  hand-added, so everything `clean` could delete is CI-regenerable. The commit's claim
  holds.
- The only file `clean: true` will remove that the build no longer produces is
  `pkgdown.js` (superseded by `deps/`), plus the two `CLAUDE.*` copies — which is the
  point.

**5. `rm -f CLAUDE.md` runs on every triggering event.** The step carries no `if:`, so it
executes for `push` to main/master, `pull_request`, `release: published` and
`workflow_dispatch` alike. It is placed immediately after `actions/checkout@v4` and
before `setup-r-dependencies` (`local::.`) and `Build site`, so neither the install nor
the build ever sees the file. Nothing else references it: no hit for `CLAUDE` in
`README.Rmd`, `README.md`, `_pkgdown.yml`, or `vignettes/`, and `.Rbuildignore` already
excluded it from `R CMD build`. `rm -f` cannot fail the step if the file is renamed or
absent — that silent no-op is exactly what the allowlist gate exists to backstop, so the
two steps are correctly layered rather than redundant.

**6. Ordering is right.** `Build site` -> gate -> `Deploy`. A gate failure aborts the job
before `github-pages-deploy-action` runs, so there is no path to a half-published site.
The gate also runs on `pull_request` builds, where deploy is skipped — so an offending
root page reddens the PR rather than only being caught at merge.

**7. `search.json` claim spot-checked**: 227 occurrences of `CLAUDE` in the currently
published index. Matches the issue body exactly.
