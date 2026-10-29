# Building a task

You work the task yourself in its worktree, one phase at a time; read the phase's
section before you start it. When you pick up a task earlier work began, start
from `git log` and `git status` in its worktree, and the reports filed for it
(`asst-report latest <slug> <kind>`).

## Phases

- **scout** — read only: no edit, no design yet. Answer only what the brief needs
  to be written: the owning layer / module, the canonical home of each datum or
  capability the task touches, the nearest sibling feature and how it does it,
  the rules that bind (`rules:` in the adapter), and any persisted format or API
  in play — at most 10 fact rows. Each `file:line` is relative to the worktree
  root and is checked by `asst-cite` (its header states the test), so put the
  thing a row cites in backticks. An absence claim (only / none / all, in any
  language) needs a second method beside grep, or it is written as `unread`.
  Whether a case happens is answered by a `file:line` on the path that reaches it
  or an `experiment:` row you ran, never by opinion.
- **ui** — the screens as real widgets, every state (empty / loading / error /
  populated), no data wiring. Run the adapter's `render`, which writes one image
  per screen × state × locale into one directory, named
  `<screen>-<state>-<locale>.png` or `<screen>__<state…>__<theme>__<locale>.png`.
  Beside them write `labels.json` — `{"lang", "title", "summary", "screens":
  {key: name}, "states": {key: name}, "locales": {code: name}}` in the founder's
  language, every key named the way the founder would say it and listed in the
  order the page should show it; then `asst-screens <slug> <that directory>`
  builds the page and prints its path. Never combine the images into one, and
  never write a page of your own. Strings are real from here on, in every locale
  — the founder reads the screens in the locale they ship in, not in a
  placeholder.
- **wire** — data wiring, until the tester's tests pass: remove the `until wired`
  marker from each one your wiring makes pass, and never edit a test otherwise —
  one you think wrong goes back to the tester with why. Checkpoint each module
  you finish (git: commit, the hook runs `gate`, then `asst-pr open <slug>
  <worktree>` — it pushes and keeps the task's PR a draft; svn: run `gate`, save
  `svn diff` under `.claude/.assistant/tasks/<slug>/`, commit nothing).
- **fix** — apply the findings in the verifier reports (or a better fix of your
  own), except those about a test, which are the tester's; a finding you decline
  goes on the report's `declined:` line, and into the code only as an S6.5
  comment when its reason is a fact the code cannot show. Then checkpoint, as in
  wire.

From `ui` on, the brief's rulings are binding. A fork the brief did not settle is a
`Needs you` when it changes what the user sees, otherwise a `Decided` line on the
report's `forks:`. A fork with an option that changes code outside the task
statement's boundary is marked `outside boundary`, with whether the base branch
already behaves that way (`file:line` on it, or `unread`); never change such code
unless the brief names it.

Before writing a flow, a calculation or a mapping, search the project for the unit
that already owns it, and use that unit's entry point (style-pack S16.2); a
difference this task needs becomes a named option of that unit, not a second
implementation beside it (S16.6). A second implementation is never yours to write:
if reuse looks wrong, it is a fork.

## Rules before code

In `ui`, `wire` and `fix`, before your first edit run `style-pack --paths <the
files you'll touch>` and read all of it; run it again for a file you add later.
The verifier grades against it, comments are its S6, and the report's `rules:`
line names that run — `asst-report` won't file a build report without it.
Touching any string under the adapter's `ui_strings:` means also reading
`ui-text-pack --paths <those files>`: every locale in `locales:` gets its value in
the same pass, each authored in that locale rather than translated from the source
one (U3), and none of them is approved by you. Before writing a value, read the
shipped strings: the `ui_strings:` files on the default branch (svn: the last
committed revision), never this task's own values. A shipped value with the same
meaning and UI role is reused word for word (U4.4); a new one matches the length,
set phrases and terms its shipped siblings in that role use. A concept the OS or
app store owns takes the platform's own term (U4.5). Then run `asst-strings
examples <role> <locale>` for each role and locale you write, and read every pair:
the founder's rewrites of earlier drafts. Write the way the finals are written, and
never make a choice a draft there made (U3.8).

A tone-sensitive string (error, guidance, confirmation, empty state) gets 2–3
side-by-side options per locale, listed in the report with a one-line trade-off
(charter U3.3) — each locale's options written in that locale, not fixed in one and
translated, and one of them the shortest that states only the fact. The file gets
the one you think best; the founder picks at ②. A string first created in the
`wire` phase follows the same rule, listed in that phase's report.

Never wait on anything with a `sleep` or `until` loop: a full coverage or mutation
run goes in the background (`run_in_background: true`). `gate: green` means the
whole gate ran to its end and passed; a gate that couldn't run is `gate: not run —
<why>`, and that checkpoint is unfinished, never green.

## Reports

File one report per phase with `asst-report put <slug> <kind>` (`scout`, or
`build-<phase>`, the bare kind — it numbers rounds itself), its text on stdin from
a heredoc or a file named after the slug and kind, never a shared name like
`report.md` that an agent may have written. The verifier and ③ read them. Scout:

```
## Facts
| # | Claim | Evidence (file:line · experiment: <cmd> → <obs> · unread) |
## Forks (intent — the founder decides)
- <fork>: A <option> / B <option> · what each costs
## Risks seen
- <one line each, or none>
```

Every other phase:

```
phase: <name> · checkpoints: <sha … | diff path> · gate: <green|n red|not run — why>
rules: style-pack --paths <the files>   (and ui-text-pack --paths <files>, when strings changed)
screens: <ui: the path asst-screens printed; other phases: none>
forks: <none, or one line each>
debt: <none, or one line each>
declined: <none, or one line each: [<block>.<n>] file:line — reason>
strings: <none, or one block each>
  <key> · <role> · <where it renders> · <available width>
  - <locale> <value written>
  - options <locale>: <A> ｜ <B> ｜ <C> — <one-line trade-off>   (tone-sensitive only)
```
