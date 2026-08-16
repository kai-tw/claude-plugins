# Mid-flow escalation

Read this file when this skill is invoked from another skill mid-flow:
`/bug-investigate` Phase 6 mechanism-change routing, the designer role
spec-vs-plan conflict, or main-agent triage of a `/qa`
finding that surfaces a scope question.

## Protocol

1. Read the source skill's escalation message verbatim — bug ID,
   conflicting plan section, designer's open question, etc.
2. Decide whether the resolution is a **plan amendment** (existing
   plan needs a rev) or a **scope ruling** (decision memo without a
   full plan). Default to amendment if scope changes.
3. Produce the artifact — usually a short revision-history entry
   appended to the existing **Product Plan row body**, plus a
   one-line ruling for the parent flow to consume verbatim.
4. Re-run the rules audit gate (Phase 6 of `SKILL.md`) on the amended plan —
   escalations are exactly the moments rules get violated; 違規當場修、
   禁 deferred & dismiss。
5. **Re-upload to Notion (the launcher's Iron Law 6).** You have no Notion MCP —
   invoke the `archivist` skill to write the amended **Product Plan row
   body**. An amendment that lives only in chat or a local note has
   not landed.
6. Hand back to the parent flow with: `(a)` the Notion **Product Plan
   row** URL (re-uploaded via the `archivist`), `(b)` the verbatim
   ruling, `(c)` the rules audit result (all passed / N 違規已修). Do not paraphrase.

The parent flow expects the ruling forwarded **verbatim**, not
paraphrased — paraphrase has shipped bugs before. Forwarding a
ruling verbatim is your output.
