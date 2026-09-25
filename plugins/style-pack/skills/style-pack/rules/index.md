# Style code — charter

This charter covers style judgments that mechanical checks cannot decide and that must be
made by judgment.

**Severity.** This charter **defines no severity levels of its own** — the severity of a
violation is set by the review procedure. A rule that needs a severity floor states it in its
`Check:` (e.g. `violations of this rule are always proposed CRITICAL`).

## Precedence

Three ranks; the higher prevails. **This section is the only version of the precedence
rules**; lower layers and the procedure file cite it.

| Rank | Contains | Authority |
|---|---|---|
| Constitution | this charter's `S<N>`: principles that hold in every language and every project | the only place a base rule may be enacted |
| Statute | language layer: that language's concrete tests, each under one `S<N>` | may only **concretize** a base rule |
| Regulation | project layer: that project's facts (its own helper names, canonical entry point, paths) | may only **tighten** or **supply facts** |

**Conflict test.** Can the two rules **be satisfied at the same time**? If so, they stack
lawfully; if not, they conflict.

**No exemption clauses.** A conflict has exactly three outcomes, all amendments: narrow the
base rule (add a condition, or move it down to the statute layer) · repeal the base rule ·
change the project's code. A self-granted exception is the standard way a valid claim dies
before it is ever raised.

**Conflict during review.** Grade that rule **`undeterminable`**, name who must
amend it at which rank, and raise the amendment separately. It is not `passed`, nor a
`critical` that punishes the author.

**Burden of proof.** Whoever claims a conflict must **quote both rules and explain why they
cannot both be satisfied**. "This rule is awkward here" is inconvenience, not conflict — grade
by the higher rule this time and raise the amendment separately.

## Base rules

**An empty lower layer does not mean that language or project has no rules** — the base
rules still apply. Conversely, a reviewer **must not invent a finding** from a style
preference this charter does not legislate: no rule text does not mean free discretion.

## S1 — Layer ownership

**Principle:** Which layer a piece of logic belongs to is decided by the knowledge it depends
on, not by the directory it sits in — a linter can audit import direction, not ownership.

- **S1.1 Directories do not confer ownership** — Check: for files the diff adds or moves,
  does the knowledge their content depends on match their layer (no wire formats, HTTP status
  codes, DB column names or UI vocabulary inside `domain/`)? If not, move it or rewrite it; a
  comment must not substitute (S6.4). Example: a use case in `domain/` translating HTTP status
  codes.
- **S1.3 Orchestration only at the composition point** — Check: do cross-repository ordering,
  retries and fallbacks appear only at the composition point the project declares (**where
  that point is, is a project fact in the regulation layer**)? A use case may contain only one
  domain decision. Example: a use case calls two repositories in order and switches to the
  other path on failure.
- **S1.4 Declarations must not execute** — Check: does any line in this wiring file
  (registration, configuration, route table) actually start something — an initial scan, a
  warm-up, opening a subscription? If so, it violates this rule: wiring declares what exists;
  execution belongs to the startup flow or to the constructor of whatever owns the work.
- **S1.6 User-visible copy must not enter the state layer** — Check: does the state carry an
  error code / enum, or finished sentences of copy? If the latter, it violates this rule: copy
  baked into state cannot be re-localized when the language setting changes, and it pins the
  copy to the wrong layer. The state layer emits codes; the presentation layer turns them into
  text.

## S2 — A name must still reveal its owner, kind and category once it leaves its declaration

**Principle:** A name is only ever read after it leaves its declaration — call sites, grep
results and stack traces have no context and no type to go by. A linter can audit casing and
suffix lists, not whether the name identifies anything specific. A type name consists of
owner, concept and kind: the owner answers "whose", the concept "which one", the kind "what
sort of thing"; a type that belongs under a category must carry that category in its name.
**Violations of this rule are always proposed CRITICAL**: one rename costs far less than one
cross-feature collision or one type error that surfaces only at runtime.

- **S2.1 A name that fits anywhere is as good as unnamed** — Check: move the name under
  another module, screen or feature — does what it refers to change? If not, it identifies
  nothing specific; add its owner. Example: two features each have a `PendingConflict`, and
  call sites cannot tell whose it is.
- **S2.2 A name must say what it is, not why it matters** — Check: from the name alone, can
  you tell whether it is a flag, a count, a collection or an object? A name that states the
  value's purpose or reason violates this rule. Example: `attention` holds a badge widget; its
  name states why the badge appears, not what the value is.
- **S2.3 Actions take verbs, values take nouns; follow verbs the framework has fixed** —
  Check: does the member perform an action (method, function, function-typed field)? If so
  and it has a noun name, it violates this rule; only members that hold or compute a value
  take nouns. Where the platform or framework has fixed a verb for the operation, use it — a
  synonym both reads as a different operation and cannot be found by searching the
  framework's name. Names the framework dictates (constructors, serialization, entry points,
  operators) are not chosen and are outside this rule. Example: a function-typed field named
  `count`, which every call site reads as a number.
- **S2.4 One suffix maps to one structural level** — Check: in this batch of names, is one
  suffix shared by two levels? If so, one level must change its word: distinguishing is the
  suffix's only reason to exist, and spanning two levels it no longer distinguishes. Example:
  a container and its five children share one suffix.
- **S2.5 Adjectives must not be module names** — Check: does the module's name state the work
  it performs, or describe a quality? If the latter, it violates this rule — an adjective
  draws no boundary around the work; anything with a similar quality can claim to belong, and
  the boundary cannot be held.
- **S2.6 The identity a name claims must be true** — Check: does the name borrow the name of
  an existing concept or type (`Cache`, `Queue`, `Repository`, a framework component name)? If
  so, is the unit really that — inheriting it, composing it, or being it directly? If not, it
  violates this rule: the contract a name makes is redeemed by readers at the call site, this
  one cannot be redeemed, and the failure comes at runtime. Rename it to something it can
  live up to.
- **S2.7 A type name must end in a kind word** — Check: from the type name alone (`enum`s
  included), can you tell what kind of thing it is (domain entity, failure, state, state
  holder, data access, UI component)? If not, it violates this rule. The kind-word vocabulary
  is set by lower layers. Example: `Connection` cannot be told apart as a connection entity,
  connection state or connection failure.
- **S2.8 A subtype's name must inherit its parent's category** — Check: do members of a
  closed family, or implementations of one abstraction, keep the parent type's category word
  and kind word in full, adding only their own distinguishing word? If not, it violates this
  rule — a call site seeing the subtype name must know its family without looking up the
  declaration, and a search for the parent's category word must find the whole family.
  Example: `ConnectionFailure`'s subtype is `ConnectionTimeoutFailure`, not `TimeoutFailure`.
- **S2.9 One kind has exactly one kind word** — Check: is one kind of thing called by two or
  more words? If so, it violates this rule — readers will assume the two are different kinds,
  and a search for one will not find them all. This rule is the converse of S2.4. Example:
  failure types using both `Failure` and `Exception`.

## S3 — Every collapse must be justified at each consumption point

**Principle:** In this rule, **collapsing** means reducing a value with more than two states
to a binary one. A collapse is a **claim**: the states folded away are the same thing as the
state they merge into. Whether the claim holds is a property of the **question**, not of the
value — the same collapse can hold for one question and fail for another. Adding a test does
not cure it (a test only freezes the current decision); a comment describing the collapse is
a statement, not a justification (S6.4). Where the states genuinely differ in meaning, they
must not be collapsed: a third state is not noise but a real state.

- **S3.1 Equivalence must hold separately at each consumption point** — Check: at **every**
  place that reads the value, is the collapsed state equivalent to the one it merged into? If
  you cannot say, or did not check each point, it violates this rule. Example: collapsing "not
  yet fetched" into "not offline" holds at a passive display (which claims nothing), but not
  where the value drives a write.
- **S3.2 A collapse's validity does not extend to its complement** — Check: is the value's
  negation also read? If so, the negation must be re-verified on its own and must not borrow
  an existing consumption point's conclusion. Example: reading "not offline" as "connected"
  asserts to the user a fact nobody could have found out.
- **S3.3 What is stored or passed across layers must be the uncollapsed original** — Check: is
  what is stored or passed across layers the original value, or a binary one some consumption
  point collapsed? If the latter, it violates this rule — the next consumption point can no
  longer ask a different question.
- **S3.4 Distinct user-facing causes must not be collapsed into one sentence** — Check: do
  several distinct failure causes share one sentence of copy? If so, it violates this rule —
  users are entitled to know what happened, and one generic sentence makes "offline" and "no
  such data" the same thing. Copy must not be reused verbatim from elsewhere either: that
  sentence describes a different failure.
- **S3.5 Two states take a flag; three or more take an enum** — Check: how many states does it
  have? With two, a flag is correct; do not switch to an enum because "there might be more
  later". Three or more expressed with flags violates this rule: either a state is missing or
  it is assembled from several flags — and the Cartesian product of N flags is always larger
  than the real state set; the extra combinations are impossible states, the type will not
  stop them, and readers cannot tell which combinations are real. An enum makes impossible
  states unwritable.

## S4 — A persisted value's meaning must not depend on position or manual upkeep

**Principle:** A persisted value is reinterpreted only after the current run ends, and
reinterpretation **does not fail** — no compile error, no exception, no test turns red; old
data just comes to mean something else. And the symptoms appear only on devices that already
stored data; the developer's local data is empty and everything runs fine.

- **S4.1 A persisted value must not be a sequence position** — Check: is the value to be
  written an index, an ordinal or any "the Nth"? If so, it violates this rule, always proposed
  CRITICAL. Store an identifier unrelated to position and map it back to position on read. The
  test is not "will anyone change the sequence" but **whether anything will make noise when it
  changes**; before shipping, changing the format costs one file, after shipping a data
  migration, so the moment review catches it is the cheapest it will ever be.
- **S4.2 Persisted strings must derive from the member, not a separate lookup table** —
  Check: is the string derived from the member itself, or from a hand-written lookup table?
  If hand-written, it violates this rule: the table is a second copy of the member list, and
  because the reader must have a wildcard branch to "fall back on unknown values rather than
  throw", a missing entry is not a compile error but a value that is written out and reads
  back as a different member. State the cost; do not pretend it is not there — when tied to
  identifiers, a rename is a data migration.
- **S4.3 A transient failure must not be written as a definite result** — Check: is the
  negative result written to long-lived storage (absent / failed / empty) written only on the
  definite-failure branch? If all kinds of failure share one write, it violates this rule.
  Example: one flaky connection flips a record to "none", and the recovery path that could fix
  it is blocked by that very record.
- **S4.4 A persisted format must declare a version; a mismatch is resolved by step-by-step
  migration** — Check: does the persisted format have a version field? On mismatch, is it
  converted version by version, or does it fall back to a default? Treating "wrong version" as
  "absent" violates this rule, always proposed CRITICAL: on upgrade it destroys user data that
  cannot be rebuilt, and to the next maintainer it reads as "already handled". Two exceptions
  must each be stated at the version check: the data can be rebuilt from an authoritative
  source, or the version encountered is **newer** (an older reader must leave it as is, not
  overwrite it).
- **S4.5 A shipped migration step is frozen** — Check: does the migration step import today's
  types or route through a shared helper? If so, it violates this rule: its job is to turn a
  two-year-old format into **that year's** next version, and today's types have long since
  gained and lost fields; routing through a shared helper makes the step silently change
  behavior the day the helper changes — that is not refactoring, it is rewriting history.

## S5 — Silently aborting a flow must state the trigger and the flow skipped

**Principle:** Code that silently aborts the normal flow looks exactly like "nothing to do
here"; readers cannot tell a decision from an omission. Stating which condition triggers it
and which flow is skipped is the only way to tell them apart.

- **S5.1 A non-terminal `return` / `break` / `continue` must state the condition and the flow
  it skips** — Check: is there a line above the early exit stating what triggers it and what
  it skips? If not, it violates this rule. A terminal `return value;` is outside this rule — no
  flow follows it to skip.
- **S5.2 Fire-and-forget must state who observes its failure** — Check: for this async call
  whose result is not awaited, can you say who observes its failure and why no one waits? If
  not, await it.
- **S5.3 A catch branch that swallows an exception must state what guarantee the caller still
  has** — Check: does the catch branch neither rethrow, nor update observable state, nor
  recover (logging only counts, so does an empty branch)? If so and it does not state what
  guarantee the caller still has once the exception is swallowed, it violates this rule; if
  none can be stated, rethrow, update state, or delete the branch so the exception
  propagates.
- **S5.4 A normal result must not replace a failure** — Check: does the catch branch return
  an empty collection, `null` or a default object? If so, it violates this rule — neither the
  caller nor the user can tell a failure happened. When a user-initiated operation fails, the
  user must see it; logging alone does not count.

## S6 — Comments answer WHY and attach to the nearest declaration

**Principle:** Identifiers already state WHAT, so a comment restating WHAT is a second copy
that will drift. A comment holds what **cannot be inferred from this repo and, if missed,
leads to a wrong change**: the actual behavior of external systems, spec or protocol
requirements, platform limits, business rules, non-obvious invariants. Past states are
excluded — something no longer true today gives readers nothing to judge today's change by.

- **S6.1 If it still reads after deletion, delete it** — Check: delete the comment — can
  readers still get the same thing from identifiers and types? If so, delete it. **This rule
  applies sentence by sentence**: within one comment, any sentence whose deletion leaves the
  answer unchanged must be deleted; decorative dividers and block comments restating file
  structure fall under this rule.
- **S6.2 No reference to the current task, no record of past changes** — Check: does the
  comment contain references like "used by X" / "fixes #123", or archaeology like "was A, now
  B" / "removed after v2" / "added this workaround for C back then"? If so, it violates this
  rule — the former belongs in the PR description, the latter in git history, and both rot
  while the code is still correct. A constraint that still holds today must be stated in the
  present tense as the constraint itself, without its origin. Tags whitelisted under S6.7 are
  outside this rule.
- **S6.3 One comment answers one question and attaches to the nearest declaration** — Check:
  is what the comment says about the declaration it sits on? Contracts attach to types,
  behavior to methods, reasons to fields. Length is a symptom, not the test.
- **S6.4 A comment does not cure a code defect** — Check: does the comment **justify** a
  decision, or merely **describe** an existing violation (S1 wrong ownership, S2 bad name, S3
  unjustified collapse)? If the latter, it violates this rule, and each other rule it breaks
  is graded separately: what must change is the code, not an added line of explanation.
- **S6.5 Omitting an out-of-repo fact is a violation** — Check: can the fact this code depends
  on be read from this repo's code and types? If not (its source is an external API's actual
  behavior, a protocol or spec clause, a platform limit, a business rule) and no comment
  states it, it violates this rule — readers lack the context, and the cost is a
  plausible-looking but wrong change. A diff that deletes such a comment while the fact still
  holds today violates it too.
- **S6.6 A comment not attached to a declaration attaches to the block after it** — Check:
  does the comment sit directly before the block it describes, and answer what readers cannot
  get from that block's identifiers (which stage of the flow this is, what it deliberately
  does not do)? If readers can get it, delete it per S6.1.
- **S6.7 Tags must be whitelisted, each with a scanner** — Check: is the comment tag
  (`// <tag>:` and the like) on a lower layer's whitelist, and does that whitelist name a scanner
  that pulls every instance of the tag across the repo in one pass? If not listed, grade it
  under S6.2; listed without a scanner violates this rule — a tag nobody can count accumulates
  unseen, which is the same as no tag.

## S7 — Failure handling must match the kind of failure

**Principle:** Failures come in three kinds, each handled differently: **predictable** ones
(external state with a queryable predicate) are handled with control flow;
**environmental** ones (permission denied, disk error, file lock, disconnect) are caught and
recovered; **programming errors** (corrupted internal data, type errors, logic defects)
propagate to the top-level handler. Using catch in place of a predicate makes the normal path
pay for a throw and a catch to get an answer the predicate gives cheaply; swallowing a
programming error in a catch keeps the defect from ever surfacing. This rule governs **which
handling is correct**; handling that is silent is graded separately under S5.

- **S7.1 Predictable states must be checked with a predicate** — Check: for the state this
  exception corresponds to, does the runtime offer a predicate (exists, is empty, has key, is
  complete)? If so and catch is used instead, it violates this rule. Example: catching a "file
  not found" exception instead of checking existence first.
- **S7.2 One failure mode has exactly one handler** — Check: does the same failure mode have
  both an upfront predicate and a downstream catch? If so, it violates this rule — readers
  cannot tell which one actually takes effect.
- **S7.3 A catch must not be wider than its recovery covers** — Check: for **every** subtype
  the caught type can resolve to, is the recovery correct? If not, it violates this rule;
  narrow the catch and let the rest propagate. This rule governs **concrete parent types that
  can actually be thrown** — any other subtypes a wide catch covers that are real defects get
  swallowed with it.
- **S7.4 Exceptions change type at the boundary** — Check: are transport- and platform-layer
  exceptions converted to domain exceptions at the repository boundary? Letting them
  propagate directly violates this rule: callers must be able to tell "the network broke" from
  "this record does not exist" by type, and platform exception types cannot answer that.
- **S7.5 Changing type must not lose the origin** — Check: does the translation preserve the
  original stack trace? If not, it violates this rule — the top-level handler will point at the
  translation line, not the frame that actually failed. A domain exception still must not
  carry the original inner exception; only the stack trace is preserved.
- **S7.6 Log level is decided by "should this be tracked as its own fault", not by
  recoverability** — Check: is the level chosen by whether it needs its own category in crash
  reporting, or by whether it is recoverable? If the latter, it violates this rule —
  downgrading because it is recoverable buries real anomalies where no one looks; recoverable
  and reportable are two different things.

## S8 — Coordination must not rest on "usually right"

**Principle:** A critical section made from a `bool` flag and waiting a fixed duration for
async completion are two faces of one disease: an approximation that **usually holds** in
place of a mechanism that **holds by construction**. The approximation is always true on the
developer's machine — it fails on other people's devices, networks and timings, so its
failure never shows up in the run where it was written. This rule governs which mechanism to
use.

- **S8.1 Critical sections must be serialized by a mechanism that queues** — Check: is this
  async critical section (re-entrant sync, single-writer file or network mutation) guarded by
  a queuing mutex, or by a hand-rolled `bool` flag? If the latter, it violates this rule — a
  flag has no queue; contenders are dropped or race rather than waiting their turn. A state
  flag that only drives display is not a critical-section guard and is outside this rule.
- **S8.2 Waiting for completion must be tied to a real signal** — Check: is the **primary**
  path for waiting on async completion or an animation's end a real signal (callback,
  completer, stream event, awaitable value), or a fixed-duration timer? If the latter, it
  violates this rule — real durations vary with device, content and network; a fixed duration
  races real completion. A safety-net timer may be added, but its duration must be clearly
  longer than expected, its name must state its timeout role, and it must act only when the
  real signal is lost.
- **S8.3 Slow or unbounded I/O must not block the UI thread** — Check: does heavy reading or
  writing, a network call or a large decode on this path run blocking on the thread that
  drives the screen? If so, it violates this rule. Cheap metadata probes are outside this rule
  — their synchronous form is correct.
- **S8.4 Serialization granularity must match the granularity of shared state** — Check: does
  the serialization mechanism queue per **key** (same key in order, different keys in
  parallel), or per **operation kind**? Per kind violates this rule: it blocks only same kind
  against same kind (upload vs. upload) and leaves every cross-kind race wide open; the
  symptoms are last-write-wins, exceptions stuck mid-way, and a final state overwritten after
  the fact by a slow operation. The patch must not go into the queue's catch or into ad-hoc
  caches in front of each writer.
- **S8.5 One change, one notification** — Check: is the change notification sent once after a
  write lands, or per item? Per item violates this rule — consumers treat one write as N
  rereads, and the reads in between see a half-written collection. Notify **after** the write
  lands, so whoever reads on notification sees the new state.
- **S8.6 A side-effect-only unit must not depend on being read to start** — Check: is all of
  the unit's work side effects (driving navigation, opening subscriptions, watching a source),
  with no one reading it? If so and it is registered with lazy construction, it violates this
  rule, always proposed CRITICAL: if nobody resolves it, construction never runs and the
  feature is 100% dead on device — while unit tests are all green, because they call its entry
  point directly and **structurally cannot express "this app never calls it"**. The tell is
  "no consumer can be found".

## S9 — Resources must be bounded, and the bound stated when written

**Principle:** An unbounded resource does not fail in the run where it was written — it fails
after the data grows, on the user's device, as slowness or exhaustion rather than a traceable
error. So the bound must be stated when the code is written, not after it shows.

- **S9.1 Every cache must have a named eviction policy** — Check: what is the cache's eviction
  policy? If you cannot say, it violates this rule. An unbounded map keyed by user data is a
  leak.
- **S9.2 Every external call must have a timeout** — Check: does the external call have a
  timeout? If not, it violates this rule — a wait without a timeout has its bound set by the
  other side.
- **S9.3 Hot-path complexity must be derivable and bounded** — Check: can the time complexity
  of this path (screen update, list scroll, sync, any loop over user-scale data) be derived?
  O(N²) or N+1 reads over persisted state violate this rule.
- **S9.4 Large data must be streamed or chunked, not held whole** — Check: is the large data
  (binary content, image buffers, long lists) loaded whole and kept resident in memory? If so,
  it violates this rule.
- **S9.5 Whatever reacts to change must declare the fields it reads** — Check: does the
  trigger for this recompute or redraw list, one by one, the fields it actually reads? If not
  declared (or written as the tautology "recompute on any change"), it violates this rule —
  any unrelated field change in the state triggers a full recompute, so its bound becomes the
  change rate of the whole state, not of what this piece really depends on.
- **S9.6 Input with a rate bound must state its bound** — Check: does external work (query,
  write, send) triggered per keystroke or per user action have a bound? If not, it violates
  this rule — its rate is bounded by the user's fingers, not by the program, so the work is
  always fast enough on the developer's machine.

## S10 — A set recorded at compile time must not be bypassed by runtime lookup

**Principle:** Once the type system records a finite set (enum, closed type, named
constants), accessing it through string keys, `map` lookups or "skip unless X" guards trades
the compiler's exhaustiveness check for a runtime query. The cost does not show when the code
is written but **when someone later adds a member**: the compiler would have pointed at every
place to update; once swapped out, nothing speaks up.

- **S10.1 Every member must have its branch** — Check: in branching over the finite set, does
  every member have its own branch? Replacing that with a "return unless X" guard violates
  this rule: that one line creates two silent failures — no feedback on the normal path, and
  members added later pass silently. A member deliberately left without action must map to a
  sentinel checked at the side effect, so the decision not to act stays visible in the branch
  table.
- **S10.2 Several branches sharing one body discard the type's distinction** — Check: are the
  bodies of several branches identical? If so, it violates this rule; merge those branches or
  extract a shared function, and do not disguise them as distinct by listing them side by
  side.
- **S10.3 Key lookup must not replace named dispatch** — Check: where the path is decided by
  set member, is it dispatched by exhaustive branches, or looked up by key in a `map`? The
  latter violates this rule — lookup gives up both exhaustiveness and the non-null guarantee,
  to save a few lines. Where multiplicity is itself data (route tables, migration lists), it is
  outside this rule: this rule forbids **looking up a dependency by key**, not genuine list
  parameters.
- **S10.4 Members of a finite set must not be referred to by bare literals** — Check: is the
  path, key name or identifier a named constant or a bare string? A bare string violates this
  rule: the compiler will not catch a typo, and it will not follow a rename.
- **S10.5 Parameters crossing a boundary must be typed, not free-form maps** — Check: is the
  parameter crossing this boundary (route, message, job) a named type or a map? A map violates
  this rule — a shape mismatch is deferred to a runtime cast at the destination, while the
  mistake is at the origin.
- **S10.6 A variant's entry point must not accept another variant's fields** — Check: do the
  unit's few forms each have their own entry point that accepts only that form's fields (named
  constructor, named factory), or share one entry point that takes a config object? The latter
  violates this rule: callers can pass fields the form has no place for, and the type will not
  stop it — an error construction should have caught becomes an ignored field nobody will ever
  read.

## S11 — A piece of state has exactly one write path

**Principle:** When two places can write the same state, each is correct on its own and what
breaks is their **interleaving** — so the failure is not caused by any single change, and
reproducing it depends on timing. The number of paths must be countable by reading the
source, not measured while debugging.

- **S11.1 Subscribe to your own source, not someone else's lifecycle** — Check: does the state
  holder subscribe to "the data I present changed", or to "someone started / is doing
  something"? The latter violates this rule: a lifecycle subscription opens a second write
  path that collides with the holder's own re-entry guard. If the screen really must show
  someone else's in-progress state, model that fact as a field **on your own side**, so there
  is still only one subscription source.
- **S11.2 No global mutable state** — Check: are there global variables or static mutable
  fields? If so, it violates this rule — it outlives every holder, cannot be reset between
  tests, and is a hidden write path nobody dismantles.
- **S11.3 A state holder must not hold another state holder** — Check: does the holder have
  another state holder among its fields? If so, it violates this rule: two lifecycles and two
  state machines get bound together, and neither can be tested alone. Where both need the same
  fact, each subscribes to the source that carries it.
- **S11.4 An optimistic write carries its own rollback** — Check: where the expected result is
  written before the write completes, does the failure path restore the original value (or
  reread)? If not, it violates this rule — the screen keeps showing a change that never
  happened, and nothing will ever correct it. The rollback must be in the same method as the
  bet.

## S12 — A unit does one thing, and its control must not be passed in by the caller

**Principle:** The two violations look different but end the same: a unit that does two
things will later be called for only half of it; a unit that lets a parameter decide "when to
stop" has moved the caller's condition into itself, so what it does depends on who calls it.
Both make "what this unit does" impossible to know from reading the unit alone.

- **S12.1 A name that needs "and" is two units** — Check: does saying what the unit does
  require "and"? If so, it violates this rule; split it in two — the name is the test.
- **S12.2 Control must not be passed as a parameter** — Check: is any parameter a flag or
  predicate that decides **when the operation stops** or **which path it takes**? If so, it
  violates this rule: that condition belongs to the caller. Two ways out — the unit owns the
  decision itself, or it exposes a lever (cancellable, abortable) that the caller pulls when it
  decides.
- **S12.3 An operation's results travel one channel** — Check: do progress, completion and
  failure all flow through the same channel? Separate parallel `onSuccess` / `onError` /
  `onProgress` callbacks violate this rule — nothing guarantees ordering or completeness
  between the return value and the callbacks, and readers must follow both to know what
  happened. Values that must be returned (identifiers and the like) must be embedded in that
  channel's events.
- **S12.5 A unit that changes state does not also answer questions** — Check: can the caller
  get what the state-changing unit's return value reports on its own, through existing queries
  before and after the operation (success or not, hit or not, already empty or not)? If so, it
  violates this rule, and the unit must return nothing — failure is thrown as a type per S7,
  state is read back through queries, and neither may be silenced as a result (S5.3).
  Expressing that return value as a named enum does not make it lawful: the test is what it
  reports, not its type. **Outside this rule** are values the caller cannot get otherwise,
  produced by that operation: a newly created entity's identifier, the element an atomic
  operation took. Example: `clear…()` returning "whether anything was cleared".
- **S12.6 Optional parameters must not replace the caller's thinking** — Check: does the
  parameter's default let callers skip a question they ought to answer? If so, it violates
  this rule, and the parameter must be required — the default answers for the situation of
  whoever wrote it, not for this call.

## S13 — Assertions must not exceed the evidence the test actually has

**Principle:** Tests run on stand-ins — stand-in fonts, stand-in clocks, stand-in networks.
Any number measured off a stand-in measures the stand-in, not the product. What makes such an
assertion most dangerous is that it **passes**: it freezes a fictional value, so every later
real shift is blocked as "the test broke".

- **S13.1 Values measured off a stand-in base are not facts** — Check: does the assertion
  rest on a fact the test itself owns (something happened, which branch ran, a relative order
  holds), or on a value measured from the stand-in environment (line breaks, sizes,
  appearance, timing)? The latter violates this rule. A claim about what users see needs a
  real render; otherwise it is inference, and inference must be labeled as inference.
- **S13.2 Where tests cannot reach, a green run is not counter-evidence** — Check: is the fact
  one that tests structurally cannot express ("this app never calls it", "what happens after
  the screen is unmounted")? If so and "unit tests all green" is offered as proof it is
  correct, it violates this rule — verify with a real flow instead, and name that
  verification.

## S14 — Following a precedent is valid only while its preconditions still hold

**Principle:** Copying a precedent copies its unstated premises too, and "the shape looks
right" is exactly what hides that the premise has changed. So before following a precedent,
name the premises it depends on and verify them in the new place. Diverging from an existing
mechanism is a violation; copying it into a situation it never assumed is the flip side of the
same violation.

- **S14.1 The reason is a precondition, not an explanation** — Check: does the reason attached
  to the precedent (a table row, an existing pattern) still hold here? Following it unverified
  violates this rule. Example: the reason "stateless, so create a new one each time" fails for
  a unit that keeps state across calls, and copying it gives the second access point a new
  instance whose state is silently disconnected — no compile error, no red test.
- **S14.2 Unpaid debt must not serve as precedent for new code** — Check: was the existing
  pattern being followed forced (legacy data, an external format, shipped compatibility), or
  correct from the start? If the former, it violates this rule — that it cannot be changed
  today does not make it an allowed shape. Copy instead the precedent in the same place that
  is that way because it is **correct**.

## S15 — A guard must name the state it guards against; the number of guards is a design symptom

**Principle:** Guards come in three kinds that look alike, and only one is a defect.
**Precondition guards** (empty collection, not logged in) express a real domain state and are
normal control flow. **Lifecycle guards** (closed, unmounted) exist because the runtime really
does deliver callbacks after teardown, and are necessary. The third is the **defensive guard
added "after it broke once"** — it trades a crash that speaks for a silent nothing-happened,
taking away the finger that pointed at the cause. One question tells them apart: **can you
say which state it guards against, and why that state is reachable.**

- **S15.1 A guard must name the state it guards against and how that state is reached** —
  Check: which state does the guard guard against? By which path is that state reached?
  Answering "what" but not "why reachable" violates this rule — the guard is covering an
  unknown, and the unknown is the defect. Find the path; if it is confirmed unreachable,
  delete the guard and let it break.
- **S15.2 Guarding the same state repeatedly in one flow is a sign of too many entry points** —
  Check: how many times is the same state guarded in this flow? If more than once, first count
  the flow's entry points and continuation points, and eliminate guards by **reducing entry
  points**; do not eliminate the symptom by adding guards. The guard count measures how many
  ways into the flow there are, not how thorough the protection is.
- **S15.3 Lifecycle guards are not subject to minimization** — Check: does the guard protect
  against a callback the runtime really does deliver after teardown? If so, S15.2's
  minimization does not apply — the guard is necessary, and its count is set by the number of
  async continuation points; reduce continuation points per S15.2, and do not delete the
  guards.

## S16 — An object owns one capability, and its interface is the only boundary

**Principle:** An object is a boundary. A capability belongs to one owner, which exposes only
the operations it promises and keeps its internal representation inside; whoever uses the
capability goes through its interface, never building a second one or reaching around it.
Drawing, keeping and removing a boundary are all bound by this rule.

- **S16.1 A boundary must be justified by existing complexity it removes** — Check: what
  complexity that exists today (existing duplication, impossible states that are already
  expressible, existing divergence) does the new layer or wrapper remove? If you cannot say, or
  what it removes is a situation that does not exist yet, it violates this rule. If, once the
  unit is inlined, readers need to know the same things, it is a redirection rather than an
  abstraction and falls under this rule; so does an extracted unit re-checking a condition the
  caller already checked.
- **S16.2 A capability must be used through the entry point its owner declares** — Check:
  does this code use the existing mechanism's entry point, or a hand-written simplified
  version? Rebuilding a mechanism the framework or this project already provides violates this
  rule — the differences between the rebuild and the original (edge cases, accessibility,
  integration behavior) show up only on other people's devices. Obtaining something from
  another boundary through an implicit channel, when that boundary has a named entry point,
  violates it too.
- **S16.3 A fact or a derivation has exactly one declaration site** — Check: does the value,
  collection or derivation have a second copy elsewhere? Re-deriving at a call site a value the
  owner already provides violates this rule; two collections that differ by only a member or
  two, where the difference is only renaming, are one collection, and keeping them separate
  violates this rule. Example: a mapping switch between two enums where every branch is a
  rename.
- **S16.4 Internal representation stays inside; other units' internals must not be reached
  into** — Check: does the unit expose the operations it promises, or its internal
  representation (field shapes, collection types, intermediate states)? Exposing internals,
  or reaching into another unit's internals, violates this rule. So does a shared unit that
  knows any of its users' types, state or entities — it is not shared, it belongs to that
  user; the data and actions it needs must go in and out through parameters.
- **S16.5 Across a system boundary, each side owns its own concepts** — Check: does what
  crosses the boundary use your own types, or the external system's shapes, codes or errors
  (fields one-to-one with an external payload, or fields like raw / json / code, count as
  such)? The latter violates this rule — once an external concept crosses, its changes
  propagate to every place inside, and both types are legal, so the linter stays green.
- **S16.6 A fix lands in the unit that is wrong; a removal takes its guards along** — Check: if
  the unit this code calls behaved correctly, would this code still need to exist? If not, it
  is a fix of that unit, and placing it outside that unit violates this rule — call sites
  without it stay exposed, and every later adopter must re-derive it. When the unit's source is
  under this project's owner, in any repository, the fix lands there; when it is not, it lands
  once, in the single adapter this project calls the unit through. Consumer-side differences
  must be encoded as a named option of that unit, not a sibling unit. When a unit is removed,
  every guard inside it (precondition, idempotency short-circuit, dedup, rate limit) must have
  somewhere to go; if the answer is "nowhere", the removal is not yet valid — deletion is
  silent, and the lost guarantee shows up only when the guarded edge case happens. Example:
  every caller checks an input's size before handing it to a decoder, because the decoder
  itself sets no limit.
