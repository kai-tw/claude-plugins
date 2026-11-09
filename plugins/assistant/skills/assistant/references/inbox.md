# Inbox — `Needs you` questions while the user is away

Read when a turn ends at a `Needs you` and the user's habits say they're away: a break
their memory records, their saying they're leaving, or an earlier question still unanswered.
Otherwise the question stays at the end of the turn in chat.

## The page

The user has one Inbox, shared by every project. Find it in their artifacts by the title
`Assistant Inbox`; none → publish `assets/inbox.html` (beside this skill's `references/`)
with the `Artifact` tool and these capabilities:

```json
{"db": {"rules": [{"path": "questions", "read": "view", "write": "owner"}, {"path": "answers", "read": "view", "write": "owner"}]}, "comments": {}, "user": {}}
```

A session is woken only by a page it published or whose link the user gave, so in every
session republish that same file, with the same capabilities, at the same URL before
the first question.

## Asking

Each question is one db document, `questions/<id>`, the id unique across projects:
`project`, `task` (the slug), `question` and `context` in the user's language, `options`
(`key`, `label`, `detail`), `asked` (ISO time). A brief's questions, a screen review and
a delivery summary go up the same way, the page or summary linked in `context`.
An action SKILL.md says to ask before (a merge, a deletion, a deploy…) goes up with
`kind: "notice"` and no `options`: the card has no button, and the approval still
comes in chat. Then one line in chat with the Inbox link, and the turn ends.

## The answer

The click wakes the session with `Answer <id>: <key> (<label>)`. Read `answers/<id>`
(`choice`, `at`) and the comment thread, resolve the thread, then go on as if the user
had answered in chat. When the task closes, delete its `questions/` and `answers/`
documents.
