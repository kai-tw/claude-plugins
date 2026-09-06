# Mid-flow escalation

`Read` this file when this skill is invoked from another skill
mid-flow — `/plan` Phase 4 routing for fresh engineering plans,
`/bug-investigate` Phase 6 mechanism-change routing into
engineering, the PM role plan rev whose scope shifts engineering
trade-offs, the designer role spec rev that changes the implementation
surface, or main-agent triage of a `/qa` finding
that surfaces an engineering question.

## Protocol

1. **Read the source skill's escalation message verbatim** —
   bug ID, conflicting plan / spec section, designer's open
   question, etc. Do not paraphrase.
2. **Decide the resolution shape** — fresh engineering plan,
   plan amendment (existing plan needs a rev), or engineering
   ruling (decision memo without a full plan rev). Default to
   plan amendment if any architectural decision changes;
   default to ruling for one-line trade-off questions.
3. **Produce the artifact** (the content — the Notion write is step 5):
   - **Fresh plan** — full Phase 1–10 cycle, authored as the
     feature's Notion Engineering Plan DB row.
   - **Plan amendment** — a revision-history entry + the affected
     section edits for the existing plan (the feature's Notion
     Engineering Plan DB row body), plus the matching TaskCreate
     task-list update per Phase 11.
   - **Engineering ruling** — short revision-history entry
     plus a one-line ruling for the parent flow to consume
     verbatim. No full plan rev needed.
4. **Re-audit the amendment** (Phase 9 of engineer/SKILL.md) — run
   `scripts/plan_lint.sh`, then spawn `engineer-plan-reviewer` against the new /
   amended plan (player ≠ referee, 禁自審); escalations are exactly the moments
   engineering anti-patterns surface, so this must run before handback.
5. **Re-upload to Notion (the launcher's Iron Law 6).** You have no Notion MCP —
   invoke the `archivist` skill to write / update the **Engineering Plan row
   body** (and any Status / revision-history change). An amendment that
   lives only in chat or a local note has not landed.
6. **Hand back to the parent flow** with: `(a)` the Notion
   **Engineering Plan row** URL (written via the `archivist`),
   `(b)` the verbatim ruling, `(c)` the re-audit result (plan lint +
   the engineer-plan review's verdict). Do not paraphrase.

## Routing upstream

Sometimes an escalation into the engineer role reveals the problem
isn't engineering's to solve — it's a scope shift
(the PM role), a layout shift (the designer role), or a new attack surface
(the `security-privacy-reviewer`). When that happens:

- **Product scope changed** — the implementation requires a
  surface the product plan didn't authorize. Stop the
  engineering work, name the gap, route the user to the PM role for
  a plan rev. Engineering rejoins after the plan rev approves.
- **UI changed** — the implementation requires a layout / token
  / state the design spec didn't cover. Stop, route to
  the designer role. Engineering rejoins after the spec rev.
- **New attack surface** — the implementation introduces a
  network call / platform-channel / IPC / persisted schema the
  threat model didn't cover. Route to the `security-privacy-reviewer` for risk
  assessment; engineering continues in parallel where possible
  but does not ship the surfaced behavior until the security
  gate clears.

Routing upstream is **not** failure — it's the audit catching
the artifact misalignment before code reaches the diff.

## Verbatim handback

The parent flow expects the ruling forwarded **verbatim**, not
paraphrased — paraphrase has shipped bugs before. Forwarding a
ruling verbatim is your output. If the ruling needs context the
parent flow lacks, embed it in the ruling itself; do not
restate it in a cover note.

Format for the verbatim ruling:

```
Engineering ruling (escalation from /<parent-skill>):

<one-paragraph ruling — names the decision, the rationale, and
the file path / class / use-case the implementer applies it
to>

Plan amendment: the feature's Notion Engineering Plan DB row (rev N)
Task list update: <TaskUpdate N: <subject>> / no change

Re-audit: <plan_lint PASS> · <engineer-plan-reviewer proceed | N critical 已修> (Phase 9)
```
