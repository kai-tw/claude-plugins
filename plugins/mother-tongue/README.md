# mother-tongue

Writing rules for the agent's own prose, per locale. Rules loaded once at
session start fade as the conversation grows; this plugin keeps them next to
the latest prompt and blocks what a word list can catch.

| Hook | Does |
| --- | --- |
| `UserPromptSubmit` | Detects the prompt's locale and attaches that locale's `rules.md` to it |
| `Stop` | Detects the reply's locale; if it uses a term from that locale's `banned.tsv`, blocks and asks for the sentences to be rewritten |
| `PreToolUse` (Bash) | Same check on the text of `git commit` and `gh pr\|issue create\|edit\|comment` |

Detection is by script (`hooks/detect.sh`): Hangul → `ko`, kana → `ja`, other
Han → `$MOTHER_TONGUE_ZH` (default `zh-TW`), mostly Latin → `en`. A prompt too
short to tell keeps the session's previous locale. Code blocks and
`backtick spans` are ignored, which is also how a banned term is quoted on
purpose.

## Adding a locale

Create `locales/<tag>/` with either file:

- `rules.md` — attached to every prompt in that locale, verbatim. Keep it to a
  screenful; it is paid for on every turn.
- `banned.tsv` — `wrong<TAB>right` per line. Only terms with no legitimate use
  in that locale belong here (`水平` and `程序` are correct Taiwanese in other
  senses, so they are rules, not entries).

## Settings

| Variable | Default | Effect |
| --- | --- | --- |
| `MOTHER_TONGUE` | `on` | `off` disables every hook |
| `MOTHER_TONGUE_ZH` | `zh-TW` | Locale that Chinese text maps to |
