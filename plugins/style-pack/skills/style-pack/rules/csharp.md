# Style rules — C# statute layer

Loaded when: the diff contains `.cs`. Each rule must hang under an existing charter `S<N>`;
if it cannot, amend the charter first (`CONVENTIONS.md`).

## S3 — Every collapse must be justified at each consumption point

- **S3.1-csharp A `struct`'s `default` bypasses the constructor** — Check: for a value
  expressed as a `struct` (`record struct` included), is its all-zero `default` a valid
  state? If not, it violates charter S3.5: `default(T)`, `new T[n]`, unassigned fields and
  deserialization all bypass the checks the constructor enforces, the type will not stop
  them, and the zero value reads just like a real one. Express it as a reference type
  instead, or make `default` a named valid state.

## S4 — A persisted value's meaning must not depend on position or manual upkeep

- **S4.1-csharp Persist an `enum` as its member name** — Check: what form does the enum write
  out? `System.Text.Json`'s default form is the underlying number (`Phase.Payout` is written
  as `2`); writing it out without `JsonStringEnumConverter` violates charter S4.1 (sequence
  position): inserting a new member between existing ones shifts every existing save by one,
  and reading back is silent. Casting to `(int)` or `ToString("D")` violates it too. Per
  charter S4.2 the cost is stated at the enum's declaration: renaming a member is a data
  migration.
- **S4.2-csharp Persist instants as `DateTimeOffset`** — Check: is the instant written out a
  `DateTime` or a `DateTimeOffset`? If the former, it violates this rule: `Kind` is not written
  with the value and always reads back as `Unspecified`, so any later time-zone conversion uses
  the reader's local zone — the same record reads as different instants on different devices,
  with no error.

## S6 — Comments answer WHY and attach to the nearest declaration

- **S6.1-csharp `!` must state who upholds its guarantee** — Check: where `= null!`,
  `default!` or a `!` suppression is used, is it stated who fills the value and when (a
  framework hook, the serializer, call order)? If not, it violates charter S6.5: `!` turns off
  the compiler's check, the guarantee it buys is now upheld by the reader, and where that
  guarantee comes from cannot be read from this repo's types. If the constructor can fill it,
  switch to constructor injection.

## S7 — Failure handling must match the kind of failure

- **S7.1-csharp Changing type at the boundary must reattach the original stack trace** —
  Check: when translating an exception inside `catch`, is the original stack trace attached
  to the new exception with `ExceptionDispatchInfo.SetRemoteStackTrace` before it is thrown?
  Carrying an `InnerException` via `throw new XFailure(msg, ex)` instead violates charter
  S7.5: the new exception's stack starts at the translation line, and `InnerException` is
  exactly the carrying the charter excludes.

## S8 — Coordination must not rest on "usually right"

- **S8.1-csharp Async critical sections must be serialized with `SemaphoreSlim(1, 1)`** —
  Check: is this critical section spanning an `await` guarded by a `SemaphoreSlim`, or by
  `lock` plus a `bool`? If the latter, it violates charter S8.1: `lock` cannot span an
  `await` (the compiler rejects that line), so the rewrite usually protects only the half
  before the continuation point, which had no contention to begin with.

## S9 — Resources must be bounded, and the bound stated when written

- **S9.1-csharp An `event`'s subscriber list is unbounded** — Check: where is the matching
  `-=` for this `+=`? If you cannot say, it violates this rule: a C# event holds strong
  references to its subscribers, so when the publisher outlives a subscriber, the subscriber
  is never collected, and its callbacks are still delivered after it has been torn down.
  Example: a short-lived subscriber subscribes to a long-lived singleton's event on creation,
  and nobody unsubscribes on teardown.

## S10 — A set recorded at compile time must not be bypassed by runtime lookup

- **S10.1-csharp An `enum`'s range is its underlying integer's entire range** — Check: is an
  enum read back from storage, the network or `Enum.Parse` checked at the boundary with
  `Enum.IsDefined` or an exhaustive `switch` expression? If not, it violates charter S10.1:
  `(Phase)99` is legal, `JsonSerializer.Deserialize<Phase>("99")` accepts it as is, and a
  `switch` statement that misses it just runs through silently — a `switch` expression is
  caught by the compiler's CS8524; a statement has no such protection.

## S15 — A guard must name the state it guards against; the number of guards is a design symptom

- **S15.1-csharp `?.` is an unnamed guard** — Check: which path does the `null` that this
  `?.` or `??` guards against come from? If you cannot say, it violates charter S15.1: the
  whole expression silently evaluates to `null` or does not run at all, with no feedback to
  caller or user, and that unexplained `null` is the defect.

## S16 — An object owns one capability, and its interface is the only boundary

- **S16.1-csharp An exposed read-only collection must really be read-only** — Check: is the
  object behind a return value declared `IReadOnlyList<T>` the owner's own `List<T>`? If so,
  it violates charter S16.4: the interface is only a view, and a single `as List<T>` gives the
  caller the owner's internal collection. `AsReadOnly()` blocks that cast; if the caller needs
  a snapshot of the current state, return a copy.
