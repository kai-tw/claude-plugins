# Mid-flow escalation

Read this file when this skill is invoked from another skill mid-flow:
`/bug-investigate` Phase 6 styling routing, the PM role plan rev that
introduces UI surface, or main-agent triage of a `/qa`
finding that surfaces a UX question.

## Protocol

1. Read the source skill's escalation message verbatim — bug ID,
   conflicting spec section, plan delta, etc.
2. Decide whether the resolution is a **design amendment** (the widget or its
   contract needs a rev) or a **design ruling** (decision memo, no widget
   delta). Default to amendment if visible surface changes.
3. Produce the artifact — usually the widget + contract edit itself, plus a
   one-line ruling for the parent flow to consume verbatim.
4. Pass the same gates the main flow has (Phase 8 of `SKILL.md` — this
   role has no checklist gate — no agent walks a checklist over a design
   spec): re-run `design-lint` on every widget the amendment
   touches and fix to all-green; when the amendment changes visible
   surface, re-render and spawn `design-plan-reviewer` against the renders
   (player ≠ referee; no self-audit — escalations are exactly when
   anti-patterns surface; loop to all-passed, cap 3). A copy-only or
   decision-memo ruling with no widget delta records
   `design-lint: n/a (no widget change)` in the hand-back.
5. **Republish the contact sheet (the launcher's Iron Law 6)** to the same url,
   so what the founder approved against shows the amendment. An amendment that
   lives only in chat or a local note has not landed. A decision-memo ruling with
   no visible delta records `contact sheet: n/a (no visible change)`.
6. Hand back to the parent flow with: `(a)` the contact-sheet url, `(b)` the
   verbatim ruling, `(c)` the gate results (`design-lint` ·
   `design-plan-reviewer`, or their `n/a` lines). Do not paraphrase.

The parent flow expects the ruling forwarded **verbatim**, not
paraphrased — paraphrase has shipped bugs before. Forwarding a
ruling verbatim is your output.
