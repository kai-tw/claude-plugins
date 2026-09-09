# Co-creation — the one founder turn per round

> 每個撰寫階段都照本檔跑：五步，而 founder 只出現一次。
> 兩條互動規則綁 launcher **和**每個撰寫階段（PM / designer / engineer）。

#### Co-creation round (per authoring phase; PM + designer share one)

The main thread runs each authoring phase in-thread, so it can ask the user
directly. A round has five steps, and **the founder appears exactly once**:

1. **Draft.** Run the authoring role (`pm` / `designer` / `engineer`) in-context
   by invoking its skill **via the Skill tool**. **Read
   `${CLAUDE_PLUGIN_ROOT}/skills/plan/founder-corrections.md` §Engineering taste
   before proposing a solution or sizing what to build** — it carries the
   measured corrections (minimal mechanism, parallel markers, gate distrust) the
   questionnaires ask about but cannot teach. Read the file; it is not a skill
   and there is nothing to invoke. Do everything that does
   **not** need the user, and collect the open questions (each: the question,
   options, your recommendation, what it blocks) — don't surface them yet.
   *In the merged PM + designer round, draft both artifacts here, back-to-back.*
2. **① Sanity gate (旁觀, player ≠ referee).** For a **pm** artifact,
   spawn `pm-plan-reviewer` as an **isolated sub-agent**
   over `skills/pm/references/rules.md`. **The author never audits itself.** Any
   `violation` → fix it **in place** — **no deferred, no dismiss** — and
   re-spawn. Loop to green, **cap 3 rounds**; escalate earlier once the finding
   turns from error into judgment (§Gate loop policy). For a **designer**
   artifact this cell is `design-lint <presentation-dir>` and for an **engineer**
   plan `plan-lint <draft>` — both scripts, so neither loops: clear every HARD
   failure, eyeball every ADVISORY. Cheap either way, so it runs
   before the founder's time is spent.
3. **Resolve — the one founder round.** Put **every** open question and every
   load-bearing fork to the user in one `AskUserQuestion` pass. (This is also
   where the user grants the approval the three principles require.) **This is
   the step that must precede the expensive gates** — a founder decision arriving
   after the battery invalidates a clean pass and forces the whole battery to
   re-run.
4. **② Adversarial gate.** Now the scope is settled, spawn the Adversarial tier
   for this stage (matrix column ②). **One pass**, then one verification pass
   scoped to the fixes — never loop-to-green (§Gate loop policy). Resolve every
   `critical`; take a `warning` back to the founder only when it would change a
   decision, else note it at the affected line as an accepted trade-off. If a
   finding *does* reopen a fork, that is a short second Resolve — bounded, and
   still far cheaper than having run the battery twice.
5. **Finalize + confirm.** Fold everything in, write the final plan, **invoke the
   `archivist` skill to upload it** (Iron Law 6), and **confirm the upload
   landed** before advancing — a plan not in Notion does not exist. Re-run the
   gates per §Re-audit every plan change (the audit is per-change, not
   per-draft).

Never fabricate a user answer inside a sub-agent. If a `learning` surfaces that
the rules don't cover, the role's rules `CONVENTIONS.md` learning-update method
applies (find a similar rule → merge; else add a sub-check or a new principle;
stale rules may be deleted).

#### Two interaction rules — decisions ask, problems search-first

These bind this launcher **and** every authoring phase (PM / designer /
engineer), on top of the co-creation round above. They are the SSOT each role's
runtime block points back to.

1. **Every decision goes to the user — with your best answer attached.** The
   moment a genuine decision surfaces (which approach, which scope, which
   trade-off, what to defer), put it to the user via `AskUserQuestion` — don't
   bank a unilateral pick, and don't silently hold it for the phase-end batch.
   Make the option you'd pick the **first** choice, label it `(Recommended)`,
   and give the one-line why. A *decision* is a fork with more than one
   defensible answer where the user's preference matters — this is exactly what
   to ask, and it is distinct from a *problem* (rule 2).
   - **Trivial-decision carve-out — decide, but log it.** A low-stakes decision
     with one clearly-right or near-indifferent answer you MAY resolve yourself
     without asking — but every such autonomous call is **annotated `〔自行裁定〕`
     where it was decided** in the plan being authored this phase (§Plan
     integrity `I4`), so the user can scan and
     override it when they review that plan. Deciding without asking is
     allowed; **not** recording it is not. (User-made / co-created decisions use
     the same note marked `〔使用者〕`; cross-feature or likely-to-resurface ones
     promote to the Decision Log DB at close-out, as today — the list is the
     per-cycle log, the Decision Log DB its curated subset.)
   - **Scope-matching carve-out — don't inflate a detail adjustment.** When the
     user adjusts ONE detail of something that already exists, the narrow reading
     **is** the default pick — do **not** make a broader rebuild the
     `(Recommended)` option; surface the wider scope only as an explicitly
     non-recommended aside ("the card also covers X/Y/Z — those too, or just
     this?"). The `(Recommended)` label carries weight; pointing it at the big
     build manufactures scope the user never asked for. (Founder corrected this
     twice — a one-icon tweak framed as「全組 polish（建議）」as the recommended
     first option.)
2. **Every problem is researched before it's escalated.** When you hit a blocker
   or an unknown (how does X work, why does this fail, what's the existing
   pattern), find the answer first — the Notion KB → the codebase →
   project docs → the web — and only bring it to the user when that search comes
   up empty. Found → proceed, citing the source; empty → ask. Never guess
   silently, and never spend the user's time on something the record already
   answers.

**Plan writes are milestone-batched, never per-decision.** The living draft
accumulates in-thread and reaches Notion only at the existing upload milestones
(finalize → rev; Iron Law 8 / Step 5) — **not** one Notion write per decision.

**Which write mechanism to use** (`I1` says a rev edits the body — this is how):

- **Purely adding** (new §Conformance rows, a new section, nothing existing
  changes) → have the `archivist` append via
  `notion_payload.mjs append <page-id>` (block-level). Cheapest, and it cannot
  desync what it doesn't touch.
- **Anything existing changes** (a ruling rewritten, prose corrected, a section
  restructured) → a **full-body replace** via `bodyFile` (`update` treats the
  file as the source of truth). Re-emitting the whole body is the *point* here —
  it is what forces the stale occurrences elsewhere in the body to be swept
  (§Re-audit every plan change), which an append can never do.

A body kept honest stays small, so full-replace stays bounded.

