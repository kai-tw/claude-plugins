# Style guide — core rules

**Severity.** Severity is set by the review procedure; a rule that needs a minimum states it
in its `Check:`.

## Precedence

Three levels; the higher prevails.

| Level | Contains | May |
|---|---|---|
| Core rules | the `S<N>` in this file: principles that hold in every language and every project | the only place a core rule may be added |
| Language rules | that language's concrete tests, each under one `S<N>` | only **make a core rule concrete** |
| Project rules | that project's facts (its own helper names, canonical entry point, paths) | only **tighten** or **supply facts** |

**Conflict test.** Two rules conflict when they **cannot be satisfied at the same time**;
otherwise both apply.

**No exemption clauses.** A conflict has exactly three outcomes: narrow the core rule (add a
condition, or move it down to the language rules) · delete the core rule · change the
project's code.

**Conflict during review.** Report that rule as **`inconclusive`**, name who must change
which level's rule, and propose the rule change separately. It is not `passed`, nor a
`critical` that punishes the author.

**Burden of proof.** Whoever claims a conflict must **quote both rules and explain why they
cannot both be satisfied**. "This rule is awkward here" is inconvenience, not conflict — apply
the higher rule this time and propose the rule change separately.

## Core rules

**An empty lower level does not mean that language or project has no rules** — the core
rules still apply. No rule text, no finding.

## S1 — Layer ownership

**Principle:** Which layer a piece of logic belongs to is decided by the knowledge it depends
on, not by the directory it sits in.

- **S1.1 Directories do not confer ownership** — Check: a file the diff adds or moves whose
  content depends on knowledge outside its layer (wire formats, HTTP status codes, DB column
  names or UI vocabulary inside `domain/`) violates this rule; move it or rewrite it. Example:
  a use case in `domain/` translating HTTP status codes.
- **S1.3 Orchestration only at the composition root** — Check: cross-repository ordering,
  retries and fallbacks anywhere but the composition root the project declares violate this
  rule. A use case may contain only one domain decision. Example: a use case calls two
  repositories in order and switches to the other path on failure.
- **S1.4 Declarations must not execute** — Check: a line in a wiring file (registration,
  configuration, route table) that actually starts something — an initial scan, a warm-up,
  opening a subscription — violates this rule: execution belongs to the startup flow or to the
  constructor of whatever owns the work.
- **S1.6 User-visible copy must not enter the state layer** — Check: state carrying finished
  sentences of copy violates this rule, even when it also carries an error code / enum: such copy cannot be
  re-localized. The state layer emits codes; the presentation layer turns them into text.

## S2 — A name must still reveal its owner, kind and category once it leaves its declaration

**Principle:** A name is only ever read after it leaves its declaration — call sites, grep
results and stack traces have no context and no type to go by. A type name consists of
owner, concept and type suffix: the owner answers "whose", the concept "which one", the
suffix "what sort of thing"; a type that belongs under a category must carry that category
in its name. **Violations of this rule are always proposed CRITICAL.**

- **S2.1 A name that fits anywhere is as good as unnamed** — Check: a name whose referent
  would not change if it moved under another module, screen or feature identifies nothing
  specific and violates this rule; add its owner. Example: two features each have a
  `PendingConflict`, and call sites cannot tell whose it is.
- **S2.2 A name must say what it is, not why it matters** — Check: the name alone must tell
  whether it is a flag, a count, a collection or an object; a name that states the value's
  purpose or reason violates this rule. Example: `attention` holds a badge widget; its name
  states why the badge appears, not what the value is.
- **S2.3 Actions take verbs, values take nouns; follow verbs the framework has fixed** —
  Check: a member that performs an action (method, function, function-typed field) with a
  noun name violates this rule; only members that hold or compute a value take nouns. Where
  the platform or framework has fixed a verb for the operation, use it. Names the framework
  dictates (constructors, serialization, entry points, operators) are not chosen and are
  outside this rule. Example: a function-typed field named `count`, which every call site
  reads as a number.
- **S2.4 One suffix maps to one structural level** — Check: one suffix shared by two levels
  in a batch of names violates this rule; one level must change its word. Example: a
  container and its five children share one suffix.
- **S2.5 Adjectives must not be module names** — Check: a module name that describes a
  quality instead of the work the module performs violates this rule. Example: `SmartSync`
  draws no boundary around any work.
- **S2.6 The identity a name claims must be true** — Check: a name that borrows an existing
  concept or type's name (`Cache`, `Queue`, `Repository`, a framework component name) for a
  unit that does not inherit it, compose it or be it directly violates this rule; rename it
  to something it can live up to.
- **S2.7 A type name must end in a type suffix** — Check: a type name (`enum`s included) from
  which you cannot tell what kind of thing it is (domain entity, failure, state, state
  holder, data access, UI component) violates this rule. The lower levels set the list of
  suffixes. Example: `Connection` cannot be told apart as a connection entity, connection
  state or connection failure.
- **S2.8 A subtype's name must inherit its parent's category** — Check: a member of a closed
  family, or an implementation of one abstraction, that does not keep the parent type's
  category name and type suffix in full, adding only its own distinguishing word, violates
  this rule. Example: `ConnectionFailure`'s subtype is `ConnectionTimeoutFailure`, not
  `TimeoutFailure`.
- **S2.9 One kind of type has exactly one type suffix** — Check: one kind of type named with
  two or more suffixes violates this rule. Example: failure types using both `Failure` and
  `Exception`.
- **S2.10 Name a constant for reuse, configuration or a finite set; inline the rest** —
  Check: a value must be a named constant when it is read at more than one site, when it is
  a configuration value placed at the top of its file so it is easy to find, or when it is a
  member of a finite set (path, key, identifier), since the compiler will not catch a typo in
  a bare literal or follow a rename; anything else is inlined at its use site with its
  explanation. Either departure violates this rule. A constant declared in one file and used
  in another, multi-line data tables, or enumerations another unit reads may stay named with
  one use site. A store's S4.2 codes are outside this rule: they are written once, in the
  mapping, and not following a rename is their purpose.

## S3 — Every collapse must be justified at each use site

**Principle:** In this rule, **collapsing** means reducing a value with more than two states
to a binary one. A collapse is a **claim**: the states folded away are the same thing as the
state they merge into. Whether the claim holds is a property of the **question**, not of the
value — the same collapse can hold for one question and fail for another. A test or a
comment does not justify a collapse.

- **S3.1 Equivalence must hold separately at each use site** — Check: a collapse violates
  this rule unless, at **every** place that reads the value, the collapsed state was checked
  and found equivalent to the one it merged into. Example: collapsing "not yet fetched" into
  "not offline" holds at a passive display (which claims nothing), but not where the value
  drives a write.
- **S3.2 A collapse's validity does not extend to its complement** — Check: where the value's
  negation is also read, the negation must be re-verified on its own; borrowing another use
  site's conclusion violates this rule. Example: reading "not offline" as "connected" asserts
  to the user a fact nobody could have found out.
- **S3.3 What is stored or passed across layers must be the uncollapsed original** — Check:
  storing or passing across layers a binary value some use site collapsed, instead of the
  original value, violates this rule — the next use site can no longer ask a different
  question.
- **S3.4 Distinct user-facing causes must not be collapsed into one sentence** — Check:
  several distinct failure causes sharing one sentence of copy violate this rule. Example:
  "offline" and "no such data" share one sentence. Copy must not be reused verbatim from
  elsewhere either: that sentence describes a different failure.
- **S3.5 Two states take a flag; three or more take an enum** — Check: a value with two
  states takes a flag; do not switch to an enum because "there might be more later". Three
  or more states expressed with flags violate this rule: either a state is missing or it is
  assembled from several flags, and flags admit combinations that are not real states. An
  enum makes impossible states unwritable.

## S4 — A persisted value's meaning must not depend on position or manual upkeep

**Principle:** A persisted value is reinterpreted only after the current run ends, and
reinterpretation **does not fail** — no compile error, no exception, no test turns red; old
data just comes to mean something else.

- **S4.1 A persisted value must not be a sequence position** — Check: writing an index, an
  ordinal or any "the Nth" as a persisted value violates this rule, always proposed CRITICAL.
  Store a key unrelated to position (for a set member, its S4.2 code) and map it back to
  position on read. Whether anyone will reorder it is not the test.
- **S4.2 A persisted member is written through a custom member→string mapping** — Check: a
  member of a closed set persisted or sent outside the process (local storage, synced files,
  a wire protocol, analytics parameters) must be written through a mapping that gives each
  member a hand-written string, its code; writing the member's identifier violates this rule:
  a rename of the member or its type silently becomes a data migration. A member missing
  from the mapping must be caught by some check (a compile error, a test over every member,
  or another; the language layer decides which), or it is written out and read back as
  another member. Decode reads the same mapping and must fall back on an unknown code
  (corruption, or data a newer version wrote) rather than throw. Adding a member means adding
  its code.
- **S4.3 A transient failure must not be written as a definite result** — Check: writing a
  negative result (absent / failed / empty) to long-lived storage anywhere but the
  definite-failure branch, such as one write shared by all kinds of failure, violates this
  rule. Example: one flaky connection flips a record to "none", and the recovery path that
  could fix it is blocked by that very record.
- **S4.4 A persisted format must declare a version; a mismatch is resolved by step-by-step
  migration** — Check: a persisted format without a version field violates this rule; a
  version mismatch that falls back to a default instead of being converted version by
  version violates it too, always proposed CRITICAL. Two exceptions must each be stated at the version check:
  the data can be rebuilt from an authoritative source, or the version encountered is
  **newer** (an older reader must leave it as is, not overwrite it).
- **S4.5 A shipped migration step is frozen** — Check: a migration step that imports today's
  types or routes through a shared helper violates this rule: its job is to turn an old
  format into **that year's** next version, and today's types and helpers change under it.

## S5 — Silently aborting a flow must state the trigger and the flow skipped

**Principle:** Code that silently aborts the normal flow looks exactly like "nothing to do
here"; readers cannot tell a decision from an omission.

- **S5.1 A non-terminal `return` / `break` / `continue` must state the condition and the flow
  it skips** — Check: an early exit with no line above it stating what triggers it and what
  it skips violates this rule. A terminal `return value;` is outside this rule.
- **S5.2 Fire-and-forget must state who observes its failure** — Check: an async call whose
  result is not awaited, where you cannot say who observes its failure and why no one waits,
  violates this rule; await it.
- **S5.3 A catch branch that swallows an exception must state what guarantee the caller still
  has** — Check: a catch branch that neither rethrows, nor updates observable state, nor
  recovers (logging only, or an empty branch) violates this rule unless it states what
  guarantee the caller still has; if none can be stated, rethrow, update state, or delete the
  branch so the exception propagates.
- **S5.4 A normal result must not replace a failure** — Check: a catch branch that returns an
  empty collection, `null` or a default object violates this rule — neither the caller nor
  the user can tell a failure happened. When a user-initiated operation fails, the user must
  see it; logging alone does not count.

## S6 — Comments answer WHY and attach to the nearest declaration

**Principle:** Identifiers already state WHAT, so a comment restating WHAT is a second copy
that will drift. A comment holds what **cannot be inferred from this repo and, if missed,
leads to a wrong change**.

- **S6.1 If it still reads after deletion, delete it** — Check: a comment whose deletion
  leaves readers able to get the same thing from identifiers and types violates this rule;
  delete it. **This rule applies sentence by sentence**: within one comment, any sentence
  whose deletion leaves the answer unchanged must be deleted; decorative dividers and block
  comments restating file structure fall under this rule.
- **S6.2 No reference to the current task, no record of past changes** — Check: a comment
  with references like "used by X" / "fixes #123", or archaeology like "was A, now B" /
  "removed after v2" / "added this workaround for C back then", violates this rule. A
  constraint that still holds today must be stated in the present tense as the constraint
  itself, without its origin. Tags whitelisted under S6.7 are outside this rule.
- **S6.3 One comment answers one question and attaches to the nearest declaration** — Check:
  a comment that says something other than about the declaration it sits on violates this
  rule. Contracts attach to types, behavior to methods, reasons to fields. Length is a
  symptom, not the test.
- **S6.4 A comment does not cure a code defect** — Check: a comment that merely **describes**
  an existing violation (S1 wrong ownership, S2 bad name, S3 unjustified collapse) instead of
  **justifying** a decision violates this rule, and each other rule it breaks is reported
  separately: what must change is the code, not an added line of explanation.
- **S6.5 Omitting an out-of-repo fact is a violation** — Check: code that depends on a fact
  this repo's code and types cannot show (an external API's actual behavior, a protocol or
  spec clause, a platform limit, a business rule) with no comment stating it violates this
  rule. A diff that deletes such a comment while the fact still holds today violates it too.
- **S6.6 A comment not attached to a declaration attaches to the block after it** — Check:
  such a comment must sit directly before the block it describes and answer what readers
  cannot get from that block's identifiers (which stage of the flow this is, what it
  deliberately does not do); one whose content readers can get is deleted per S6.1.
- **S6.7 Tags must be whitelisted, each with a scanner** — Check: a comment tag
  (`// <tag>:` and the like) missing from a lower layer's whitelist is reported under S6.2; a
  listed tag whose whitelist names no scanner that pulls every instance of it across the
  repo in one pass violates this rule.

## S7 — Failure handling must match the kind of failure

**Principle:** Failures come in three kinds, each handled differently: **predictable** ones
(external state with a queryable predicate) are handled with control flow;
**environmental** ones (permission denied, disk error, file lock, disconnect) are caught and
recovered; **programming errors** (corrupted internal data, type errors, logic defects)
propagate to the top-level handler. This rule governs **which handling is correct**;
handling that is silent is checked separately under S5.

- **S7.1 Predictable states must be checked with a predicate** — Check: a catch for a state
  the runtime offers a predicate for (exists, is empty, has key, is complete) violates this
  rule. Example: catching a "file not found" exception instead of checking existence first.
- **S7.2 One failure mode has exactly one handler** — Check: one failure mode with both an
  upfront predicate and a downstream catch violates this rule — readers cannot tell which one
  actually takes effect.
- **S7.3 A catch must not be wider than its recovery covers** — Check: a catch whose caught
  type can resolve to a subtype the recovery does not handle correctly violates this rule;
  narrow the catch and let the rest propagate. This rule covers only concrete parent types
  that can actually be thrown.
- **S7.4 Exceptions change type at the boundary** — Check: transport- and platform-layer
  exceptions propagating past the repository boundary without conversion to domain
  exceptions violate this rule: callers must be able to tell "the network broke" from "this
  record does not exist" by type.
- **S7.5 Changing type must not lose the origin** — Check: a translation that loses the
  original stack trace violates this rule — the top-level handler will point at the
  translation line, not the frame that actually failed. A domain exception still must not
  carry the original inner exception; only the stack trace is preserved.
- **S7.6 Log level is decided by "should this be tracked as its own fault", not by
  recoverability** — Check: a level chosen by whether the failure is recoverable, instead of
  by whether it needs its own category in crash reporting, violates this rule.

## S8 — Coordination must not rest on "usually right"

**Principle:** A critical section made from a `bool` flag and waiting a fixed duration for
async completion are two faces of one disease: an approximation that **usually holds** in
place of a mechanism that **holds by construction**.

- **S8.1 Critical sections must be serialized by a mechanism that queues** — Check: an async
  critical section (re-entrant sync, single-writer file or network mutation) guarded by a
  hand-rolled `bool` flag instead of a queuing mutex violates this rule. A state flag that
  only drives display is not a critical-section guard and is outside this rule.
- **S8.2 Waiting for completion must be tied to a real signal** — Check: a fixed-duration
  timer as the **primary** path for waiting on async completion or an animation's end,
  instead of a real signal (callback, completer, stream event, awaitable value), violates
  this rule. A safety-net timer may be added, but its duration must be clearly longer than
  expected, its name must state its timeout role, and it must act only when the real signal
  is lost.
- **S8.3 Slow or unbounded I/O must not block the UI thread** — Check: heavy reading or
  writing, a network call or a large decode running blocking on the thread that drives the
  screen violates this rule. Cheap metadata probes are outside this rule — their synchronous
  form is correct.
- **S8.4 Serialization granularity must match the granularity of shared state** — Check: a
  serialization mechanism that queues per **operation kind** instead of per **key** (same key
  in order, different keys in parallel) violates this rule: it leaves every cross-kind race
  open. The patch must not go into the queue's catch or into ad-hoc caches in front of each
  writer.
- **S8.5 One change, one notification** — Check: a change notification sent per item instead
  of once violates this rule. Notify **after** the write lands, so whoever reads on
  notification sees the new state.
- **S8.6 A side-effect-only unit must not depend on being read to start** — Check: a unit
  whose work is all side effects (driving navigation, opening subscriptions, watching a
  source), with no one reading it, registered with lazy construction violates this rule,
  always proposed CRITICAL: if nobody resolves it, construction never runs and the feature is
  dead on device while unit tests stay green (S13.2). The tell is "no consumer can be found".

## S9 — Resources must be bounded, and the bound stated when written

**Principle:** An unbounded resource does not fail in the run where it was written — it fails
after the data grows, on the user's device, as slowness or exhaustion rather than a traceable
error.

- **S9.1 Every cache must have a named eviction policy** — Check: a cache whose eviction
  policy you cannot name violates this rule. An unbounded map keyed by user data is a leak.
- **S9.2 Every external call must have a timeout** — Check: an external call without a
  timeout violates this rule — a wait without a timeout has its bound set by the other side.
- **S9.3 Hot-path complexity must be derivable and bounded** — Check: a hot path (screen
  update, list scroll, sync, any loop over user-scale data) whose time complexity cannot be
  derived violates this rule, and so do O(N²) or N+1 reads over persisted state.
- **S9.4 Large data must be streamed or chunked, not held whole** — Check: large data (binary
  content, image buffers, long lists) loaded whole and kept resident in memory violates this
  rule.
- **S9.5 Whatever reacts to change must declare the fields it reads** — Check: a recompute or
  redraw trigger that does not list, one by one, the fields it actually reads (or is written
  as the tautology "recompute on any change") violates this rule.
- **S9.6 Input with a rate bound must state its bound** — Check: external work (query, write,
  send) triggered per keystroke or per user action without a bound violates this rule — its
  rate is otherwise bounded by the user's fingers, not by the program.

## S10 — A set recorded at compile time must not be bypassed by runtime lookup

**Principle:** Once the type system records a finite set (enum, closed type, named
constants), accessing it through string keys, `map` lookups or "skip unless X" guards trades
the compiler's exhaustiveness check for a runtime query: a later member then gets no compiler
pointer to the sites to update.

- **S10.1 Every member must have its branch** — Check: branching over the finite set must give
  every member its own branch; a "return unless X" guard in their place violates this rule. A
  member deliberately left without action must map to a sentinel checked at the side effect,
  so the decision not to act stays visible in the branch table.
- **S10.2 Several branches sharing one body discard the type's distinction** — Check: several
  branches with identical bodies violate this rule; merge those branches or extract a shared
  function, and do not disguise them as distinct by listing them side by side.
- **S10.3 Key lookup must not replace named dispatch** — Check: where the path is decided by
  set member, looking it up by key in a `map` instead of dispatching by exhaustive branches
  violates this rule. Where multiplicity is itself data (route tables, migration lists, a
  store's S4.2 mapping), it is outside this rule: this rule forbids **looking up a dependency
  by key**, not genuine list parameters.
- **S10.5 Parameters crossing a boundary must be typed, not free-form maps** — Check: a
  parameter crossing a boundary (route, message, job) as a map instead of a named type
  violates this rule — a shape mismatch is deferred to a runtime cast at the destination,
  while the mistake is at the origin.
- **S10.6 A variant's entry point must not accept another variant's fields** — Check: a unit
  whose few forms share one entry point that takes a config object, instead of each having
  its own entry point that accepts only that form's fields (named constructor, named
  factory), violates this rule: callers can pass fields the form has no place for, and the
  type will not stop it.

## S11 — A piece of state has exactly one write path

**Principle:** When two places can write the same state, each is correct on its own and what
breaks is their **interleaving**. The number of paths must be countable by reading the
source, not measured while debugging.

- **S11.1 Subscribe to your own source, not someone else's lifecycle** — Check: a state
  holder that subscribes to "someone started / is doing something" instead of "the data I
  present changed" violates this rule: a lifecycle subscription opens a second write path. If
  the screen really must show someone else's in-progress state, model that fact as a field
  **on your own side**, so there is still only one subscription source.
- **S11.2 No global mutable state** — Check: global variables or static mutable fields
  violate this rule.
- **S11.3 A state holder must not hold another state holder** — Check: a state holder with
  another state holder among its fields violates this rule: two lifecycles and two state
  machines get bound together, and neither can be tested alone. Where both need the same
  fact, each subscribes to the source that carries it.
- **S11.4 An optimistic write carries its own rollback** — Check: an optimistic write (the
  expected result written before the write completes) whose failure path does not restore
  the original value (or reread) violates this rule. The rollback must be in the same method
  as the optimistic update.

## S12 — A unit does one thing, and its control must not be passed in by the caller

**Principle:** A unit that does two things will later be called for only half of it; a unit
that lets a parameter decide "when to stop" has moved the caller's condition into itself. Both
make "what this unit does" impossible to know from reading the unit alone.

- **S12.1 A name that needs "and" is two units** — Check: a unit whose description requires
  "and" violates this rule; split it in two — the name is the test.
- **S12.2 Control must not be passed as a parameter** — Check: a parameter that is a flag or
  predicate deciding **when the operation stops** or **which path it takes** violates this
  rule: that condition belongs to the caller. Two ways out — the unit owns the decision
  itself, or it exposes a cancellation handle that the caller uses when it decides.
- **S12.3 An operation's results travel one channel** — Check: progress, completion and
  failure split across parallel `onSuccess` / `onError` / `onProgress` callbacks instead of
  one channel violate this rule. Values that must be returned (identifiers and the like) must
  be embedded in that channel's events.
- **S12.5 A unit that changes state does not also answer questions** — Check: a
  state-changing unit whose return value reports what the caller can get through existing
  queries before and after the operation (success or not, hit or not, already empty or not)
  violates this rule; the unit returns nothing — failure is thrown as a type per S7, state is
  read back through queries, and neither may be silenced as a result (S5.3). The test is what
  the value reports, not its type: a named enum does not make it acceptable. **Outside this
  rule** are values the caller cannot get otherwise, produced by that operation: a newly
  created entity's identifier, the element an atomic operation took. Example: `clear…()`
  returning "whether anything was cleared".
- **S12.6 Optional parameters must not replace the caller's thinking** — Check: a parameter
  whose default lets callers skip a question they ought to answer violates this rule; make
  the parameter required — the default answers for the situation of whoever wrote it, not for
  this call.

## S13 — Assertions must not exceed the evidence the test actually has

**Principle:** Tests run on fakes — fake fonts, fake clocks, fake networks. Any number
measured off a fake measures the fake, not the product, and an assertion on it **passes**,
so every later real shift is blocked as "the test broke".

- **S13.1 Values measured in a test environment are not facts** — Check: an assertion resting
  on a value measured from the test environment's fakes (line breaks, sizes, appearance,
  timing), rather than on a fact the test itself owns (something happened, which branch ran,
  a relative order holds), violates this rule. A claim about what users see needs a real
  render; otherwise it is inference, and inference must be labeled as inference.
- **S13.2 Where tests cannot reach, a green run is not counter-evidence** — Check: offering
  "unit tests all green" as proof for a fact tests structurally cannot express ("this app
  never calls it", "what happens after the screen is unmounted") violates this rule — verify
  with a real flow instead, and name that verification.

## S14 — Following a precedent is valid only while its preconditions still hold

**Principle:** Copying a precedent copies its unstated premises too, and "the shape looks
right" is exactly what hides that the premise has changed. So before following a precedent,
name the premises it depends on and verify them in the new place.

- **S14.1 The reason is a precondition, not an explanation** — Check: following a precedent
  (a table row, an existing pattern) without verifying that its attached reason still holds
  here violates this rule. Example: the reason "stateless, so create a new one each time"
  fails for a unit that keeps state across calls; copying it gives the second access point a
  new instance whose state is silently disconnected.
- **S14.2 Unpaid debt must not serve as precedent for new code** — Check: following a pattern
  that was forced (legacy data, an external format, shipped compatibility) rather than
  correct from the start violates this rule — that it cannot be changed today does not make
  it an allowed shape. Copy instead the precedent in the same place that is that way because
  it is **correct**.

## S15 — A guard must name the state it guards against; the number of guards is a design symptom

**Principle:** Guards come in three kinds that look alike, and only one is a defect.
**Precondition guards** (empty collection, not logged in) express a real domain state and are
normal control flow. **Lifecycle guards** (closed, unmounted) exist because the runtime really
does deliver callbacks after teardown, and are necessary. The third is the **defensive guard
added "after it broke once"**. What tells them apart is **naming which state it guards
against, and why that state is reachable**.

- **S15.1 A guard must name the state it guards against and how that state is reached** —
  Check: a guard whose state, or the path by which that state is reached, cannot be named
  violates this rule. Find the path; if it is confirmed unreachable, delete the guard and let
  it break.
- **S15.2 Guarding the same state repeatedly in one flow is a sign of too many entry points** —
  Check: where the same state is guarded more than once in one flow, count the flow's entry
  points and await points and eliminate guards by **reducing entry points**; eliminating the
  symptom by adding guards violates this rule.
- **S15.3 Lifecycle guards are not subject to minimization** — Check: a guard against a
  callback the runtime really does deliver after teardown is outside S15.2's minimization —
  the guard is necessary, and its count is set by the number of await points; reduce await
  points per S15.2, and do not delete the guards.

## S16 — An object owns one capability, and its interface is the only boundary

**Principle:** An object is a boundary. A capability belongs to one owner, which exposes only
the operations it promises and keeps its internal representation inside; whoever uses the
capability goes through its interface, never building a second one or reaching around it.

- **S16.1 A boundary must be justified by existing complexity it removes** — Check: a new
  layer or wrapper violates this rule unless it removes complexity that exists today
  (existing duplication, impossible states that are already expressible, existing
  divergence) that can be named; removing a situation that does not exist yet does not
  count. If, once the unit is inlined, readers need to know the same things, it is an
  indirection rather than an abstraction and falls under this rule; so does an extracted
  unit re-checking a condition the caller already checked.
- **S16.2 A capability must be used through the entry point its owner declares** — Check:
  rebuilding a mechanism the framework or this project already provides, in full or
  simplified, instead of using its entry point violates this rule. Obtaining something from another
  boundary through an implicit channel, when that boundary has a named entry point, violates
  it too.
- **S16.3 A fact or a derivation has exactly one declaration site** — Check: a value,
  collection or derivation with a second copy elsewhere violates this rule. Re-deriving at a
  call site a value the owner already provides violates this rule; two collections that
  differ by only a member or two, where the difference is only renaming, are one collection,
  and keeping them separate violates this rule. Example: a mapping switch between two enums
  where every branch is a rename.
- **S16.4 Internal representation stays inside; other units' internals must not be reached
  into** — Check: a unit that exposes its internal representation (field shapes, collection
  types, intermediate states) instead of the operations it promises, or reaches into another
  unit's internals, violates this rule. So does a shared unit that knows any of its users'
  types, state or entities — it is not shared, it belongs to that user; the data and actions
  it needs must go in and out through parameters.
- **S16.5 Across a system boundary, each side owns its own concepts** — Check: anything that
  crosses the boundary in the external system's shapes, codes or errors (fields one-to-one
  with an external payload, or fields like raw / json / code) instead of your own types
  violates this rule.
- **S16.6 A fix lands in the unit that is wrong; a removal takes its guards along** — Check:
  code that would not need to exist if the unit it calls behaved correctly is a fix of that
  unit, and placing it outside that unit violates this rule. When the unit's source is under
  this project's owner, in any repository, the fix lands there; when it is not, it lands
  once, in the single adapter this project calls the unit through. Consumer-side differences
  must be encoded as a named option of that unit, not a sibling unit. When a unit is removed,
  every guard inside it (precondition, idempotency short-circuit, dedup, rate limit) must
  have somewhere to go; if the answer is "nowhere", the removal is not yet valid. Example:
  every caller checks an input's size before handing it to a decoder, because the decoder
  itself sets no limit.
