# mother-tongue

Writing rules for the agent's own prose, per locale. Rules loaded once at
session start fade as the conversation grows; this plugin keeps them next to
the latest prompt and blocks what a word list can catch.

| Hook | Does |
| --- | --- |
| `UserPromptSubmit` | Detects the prompt's locale and attaches that locale's `rules.md` to it |
| `Stop` | Blocks a reply written in English when the conversation is not, and asks for it in the conversation's locale; otherwise detects the reply's locale and, if it uses a term from that locale's `banned.tsv`, blocks and asks for the sentences to be rewritten |
| `PreToolUse` (Bash) | Same check on the text of `git commit` and `gh pr\|issue create\|edit\|comment` |

Sub-agents never see `UserPromptSubmit`, so `bin/mother-tongue-rules [locale]`
prints the same `rules.md` (default `$MOTHER_TONGUE_ZH`) for an agent to read
before it writes; an unknown locale exits 1.

Detection is by script (`hooks/detect.sh`): Hangul → `ko`, kana → `ja`, other
Han → `$MOTHER_TONGUE_ZH` (default `zh-TW`), mostly Latin → `en`. A prompt too
short to tell keeps the session's previous locale. Code blocks, `backtick
spans`, URLs and paths are ignored (`hooks/strip.sh`); backticks are also how a
banned term is quoted on purpose. The commit check judges only the message:
quoted strings, heredoc bodies and `-F`/`--body-file` files, minus `…-by:`
trailers.

## Adding a locale

Create `locales/<tag>/` with either file:

- `rules.md` — attached to every prompt in that locale, verbatim. Keep it to a
  screenful; it is paid for on every turn.
- `banned.tsv` — `wrong<TAB>right[<TAB>exceptions]` per line. Exceptions are
  `、`-separated strings that contain `wrong` across a word boundary (`內存在`
  in `體內存在`); a match inside one does not count. Longer terms match first.
  Only terms with no legitimate use in that locale belong here (`數據`, `代碼`
  and `當前` are correct Taiwanese in other senses; judging those is left to
  `rules.md`), and a term earns an entry only after a scan of real zh-TW text
  finds no false hits.

## Settings

| Variable | Default | Effect |
| --- | --- | --- |
| `MOTHER_TONGUE` | `on` | `off` disables every hook |
| `MOTHER_TONGUE_ZH` | `zh-TW` | Locale that Chinese text maps to |
