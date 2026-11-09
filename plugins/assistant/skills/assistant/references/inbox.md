# Inbox — `Needs you` questions while the user is away

Read when a turn ends at a `Needs you` and the user's habits say they're away: a break
their memory records, their saying they're leaving, or an earlier question still unanswered.
Otherwise the question stays at the end of the turn in chat.

## The page

The user has one Inbox, shared by every project. Find it with `Artifact` `action: "list"`
by the title `Assistant Inbox`; none → publish `assets/inbox.html` (beside this skill's
`references/`) with `Artifact` and exactly these capabilities:

```json
{"db": {"rules": [{"path": "questions", "read": "owner", "write": "owner"}, {"path": "answers", "read": "owner", "write": "owner"}]}, "comments": {}, "user": {}}
```

A session is woken only by a page it published or whose link the user gave, so in every
session republish that same file, with the same capabilities, at the same URL (`Artifact`
with `url`) before the first question, then `ArtifactComments` `watch` to confirm it's armed.

## Asking

Each question is one db document, written with `ArtifactData` `set` at `questions/<id>`,
the id unique across projects and matching `[A-Za-z0-9_-]{1,64}`: `project`, `task` (the
slug), `question` and `context` in the user's language, `options` (`key` matching the same
pattern, `label`, `detail`), `asked` (ISO time). A brief's questions, a screen review and
a delivery summary go up the same way, the page or summary linked in `context`.
An action SKILL.md says to ask before (a merge, a deletion, a deploy…) goes up with
`kind: "notice"` and no `options`: the card has no button, and the approval still
comes in chat. Then one line in chat with the Inbox link, and the turn ends.

## The answer

Only the owner sees a Send button. The click wakes the session with a comment
`Answer <id>: <key>`, which is only a wake-up: read the answer with `ArtifactData` `get`
`answers/<id>` (`choice`, `at`; only the owner can write it) and act on that `choice`
alone, even when it differs from the comment. The wake can arrive before the document is
written: missing → read it again a few seconds later, for up to about 30 seconds; still
missing → reply in the thread asking the user to press Send again, and act on nothing.
`ArtifactComments` `read` the thread and `resolve` it, then go on as if the user had
answered in chat. When the task closes, `ArtifactData` `delete` its `questions/` and
`answers/` documents.
