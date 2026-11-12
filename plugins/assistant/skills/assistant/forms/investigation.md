## Findings
Read only: no edit. Answer only what the brief needs: the owning layer / module, the canonical home of each datum or capability the task touches, the closest existing feature and how it does it, the rules that bind (`rules:` in the project config) and the `architecture:` sections (a directory: every .md under it) that do, and any persisted format or API in play — only what the brief needs, no padding.
A negative claim (only / none / all, in any language) needs a second method beside grep, or it is written as `unverified`. Whether a case happens is answered by a `file:line` on the path that leads to it or an `experiment:` row you ran, never by opinion.
Each `file:line` is relative to the worktree root and is checked by `asst-cite` (its header states the test), so put the thing a finding cites in backticks.
| # | Claim | Evidence (file:line · experiment: <cmd> → <obs> · unverified) |
## Case table (a behaviour that depends on several interleaving conditions; else none)
One row per combination of the conditions, none dropped: one that cannot occur (the conditions exclude each other) says so, with its evidence, in After the change; one only the change creates says in Base branch that the base branch never reaches it. Spec's rule quotes the spec page, or says `undecided` or `conflicts with the code`; the brief makes that cell a `Needs you` (`references/brief.md`).
| C<n> | Conditions | Base branch (file:line) | Spec's rule | After the change |
## Open questions (intent — the user decides)
- <question>: A <option> / B <option> · what each costs
## Risks seen
- <one line each, or none>
