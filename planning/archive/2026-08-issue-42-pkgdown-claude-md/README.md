# fly#42 — keep CLAUDE.md off the pkgdown site

No PWF: one workflow file. Kept for the review, because the interesting part is that the
guard shipped in a weaker form than it read.

`rm -f CLAUDE.md` alone would not have worked — the deploy ran `clean: false`, so the
action never deletes and the published copies would have stayed put while the change
claimed to have removed them. Three parts were needed: pre-build removal, an allowlist
gate, and `clean: true`.

The gate went through two rounds. The first draft looped over `docs/*.html` and exited 0
on an empty `docs/` — an affirmative claim of success about a build that produced nothing.
The second used `case " $allowed " in *" $b "*)`, which is a **substring** test rather
than a token test, so a page named `authors index` passed. Both fail toward pass. Neither
was visible by reading; both were found by running the script against inputs that should
have failed it.

Final gate tested against nine cases, extracted verbatim from the YAML that ships rather
than retyped: clean site, `CLAUDE.html`, `CLAUDE.md`, both, empty `docs/`, the substring
bypass, a double suffix, a glob metacharacter in a filename, and a plausible future root
page.
