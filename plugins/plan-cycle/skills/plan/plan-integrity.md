# Plan integrity — constraints on the plan body itself

> `I1`–`I4` 綁**每一份** plan body，不論哪個角色寫的——它們約束的是產物，不是角色的領域，所以住這裡一份而不是每個角色的 checklist 各一份。

#### Plan integrity (I1 · I2 · I3 · I4 — every plan, every role)

These constraints bind **every** plan body regardless of which role authored it —
they govern the artifact, not the role's domain — so they live here once instead
of as a copy in each role's checklist. They are **drafting constraints
first**: honour them while writing. `engineer-plan-reviewer` grades them by id on
every plan — inside the checklist walk for pm / designer, as a
cross-cutting check on the engineer plan — and `plan_lint.sh` catches their
mechanical tells. `design-plan-reviewer` catches the provenance half again at ②.

- **I1 — A rev edits the body; it never stacks a layer on top of it.** After any
  revision the body must state only what is true *now*: no two places may give
  different rulings on the same thing. Rewrite the affected prose in place and
  update the decision note there (`I4`) — never append
  a `## Rev` section that contradicts text left standing above it.
  **Reference by name, never by ordinal or count.** "The two gating metrics
  above", "the third constraint" and "§4" all decay silently the moment the thing
  they point at is edited — the prose stays grammatical and becomes false, which
  is the one kind of staleness a reader cannot see. Name what you mean instead
  ("the gating metric on log level") — "the two items above" survives a rev that
  merges them into one, and a reviewer spends a pass on it.
- **I2 — Downstream cites upstream; it does not re-derive it, and does not
  promote what upstream never ruled.** When a plan depends on a ruling made
  upstream, cite it (`per <upstream> §<section>`) and stop — do not restate its
  reasoning at equal or greater
  length. The same applies within one document: a fact is stated in full in the
  section that owns it, and referenced elsewhere.
  **Only a ruling can be cited as one.** §Proposed approach / §Acceptance
  criteria / §Success metric / §Non-goals and any decision note (`I4`) are authorized;
  a number, default, threshold or ordering that appears under §Product-level
  risk or arrives via "for instance" / "candidate" / "could" is **input**, not
  a ruling — own the call in your own voice (naming the principle it serves)
  or escalate for an explicit one. Nor may a plan answer *downstream's*
  question in its own body: a spec that settles a routing or state-reconciliation
  mechanism has banked an unverified engineering decision as settled design.
  Record the observable behaviour and defer the mechanism, with an owner. The
  classic tell is a spec importing an "e.g." threshold from a risk section as
  binding, against a principle the same spec states.
- **I3 — Point-form, one claim per line; the reader gets the plan in a minute.**
  Bullets and tables carry the body; prose only where a bullet cannot hold the
  thought. **Every line must answer "which ruling or fact do I carry" — if it
  answers nothing, delete it.** Rejected alternatives, resolved open questions,
  the wreckage of a superseded passage, and rationale restated from upstream all
  fail that test. Rationale that survives is compressed into the same line as the
  ruling, never given its own paragraph. The opening section must land four
  things on their own: what is being built, why, the goal, and the execution
  direction — a reader who stops there has the plan. Length is an outcome of this
  rule, never a target to hit: a section is as short as saying it once allows,
  and no shorter.
- **I4 — A decision is annotated where it was decided; there is no decision
  section.** Directly under the ruled line, one line:
  `〔使用者〕「<逐字原話>」 → <本輪怎麼落地>` or `〔自行裁定〕<裁示理由>`.
  `使用者` = co-created or founder-ruled; `自行裁定` = you decided unasked (the
  trivial carve-out) — every one of those **must** carry a note, so the founder
  can scan `〔自行裁定〕` and overturn any of them; deciding without asking is
  allowed, deciding without recording is not. **The quoted half is the founder's
  own words — never paraphrased, summarised, or replaced by your reconstruction
  of their reasoning**: a quote can be diffed against what was actually said, a
  paraphrase cannot, and each rewrite is another chance to drop the distinction
  the ruling turned on. Quote the sentence that ruled; your reading of it goes
  after the arrow, where it sits beside the words it claims to implement — as do
  rejected options, when "why not X" is what makes the ruling legible. A
  deliberate deferral is a decision — note it with its owner and trigger. When
  the ruling changes, **overwrite in place** (`I1`): the half after the arrow
  freely, the quoted half only by replacing it with the founder's new verbatim
  words; no numbered log, no superseded entries left standing. Purely mechanical
  choices with no fork are not decisions. Cross-feature decisions are promoted to
  the Decision Log DB at close-out, not maintained twice.

#### When the shape changes under an approved plan

The questionnaire's sections move over time. **A plan approved under an earlier
shape does not get retro-fitted** — three rules, and they are permanent rather
than transitional: the shape will change again, and each time it does these are
the answers.

- **A section the schema dropped, holding rulings, stays** — `freeformBody`
  permits it. Old `## Decision history` entries that are founder rulings are
  load-bearing: move each to an inline `〔使用者〕` note at the line it rules
  (`I4`) as you touch that prose, and leave the rest until you do. Do not delete
  a ruling to satisfy a shape. Quote whatever surviving wording is most original
  (`I4`) — if the founder's actual sentence is no longer recoverable, quote the
  old entry verbatim rather than re-summarising it; the point is that nothing
  gets re-authored on the way in.
- **A role boundary that moved does not move the work already done.** The
  worked example is the designer-ships-widgets hand-off: a cycle whose design
  predates it has no widgets, no renders, and nothing for `design-lint` to
  read. That cycle keeps
  the boundary it was approved under: the engineer builds the presentation as
  before, and those three are `n/a` with the reason stated. Re-running the
  designer phase to produce artefacts the approved plan never promised is new
  work, not a migration — if it looks worth doing, that is the founder's call to
  make explicitly.
- **The new shape binds the next rev's *content*, not its history.** Write the
  amended prose to the current questionnaire's cells; don't rewrite settled
  sections just to change their headings.

