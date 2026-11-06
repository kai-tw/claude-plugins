# Style rules — C# language rules

## S3

- **S3.1-csharp A `struct`'s `default` bypasses the constructor** — Check: a value expressed
  as a `struct` (`record struct` included) whose all-zero `default` is not a valid state
  violates core rule S3.5: `default(T)`, `new T[n]`, unassigned fields and deserialization all
  bypass the checks the constructor enforces, and the zero value reads just like a real one.
  Express it as a reference type instead, or make `default` a named valid state.

## S4

- **S4.1-csharp Persist an `enum` with a hand-written code** — Check: an enum written out in
  `System.Text.Json`'s default form, the underlying number (`Phase.Payout` is written as `2`),
  violates core rule S4.1 (sequence position). Casting to `(int)` or `ToString("D")` violates
  it too. `JsonStringEnumConverter`, `ToString()` and `nameof` write the member name and
  violate core rule S4.2. The S4.2 mapping is one `switch` expression with an arm per member
  and no discard arm, so a missing member raises CS8509; for `System.Text.Json` it lives in a
  `JsonConverter<T>`; decode walks `Enum.GetValues<T>()` through that `switch` and falls back
  on an unknown code. Adopting codes: a store that already holds member names takes codes
  equal to them, so nothing migrates; a store that held numbers needs a frozen number→member
  table (core rule S4.5) and a migration (core rule S4.4).
- **S4.2-csharp Persist instants as `DateTimeOffset`** — Check: an instant written out as a
  `DateTime` violates this rule: `Kind` is not written with the value and always reads back as
  `Unspecified`, so any later time-zone conversion uses the reader's local zone — the same
  record reads as different instants on different devices, with no error.

## S6

- **S6.1-csharp `!` must state who upholds its guarantee** — Check: a `= null!`, `default!` or
  `!` suppression that does not state who fills the value and when (a framework hook, the
  serializer, call order) violates core rule S6.5: `!` turns off the compiler's check, and
  where the guarantee comes from cannot be read from this repo's types. If the constructor can
  fill it, switch to constructor injection.

## S7

- **S7.1-csharp Changing type at the boundary must reattach the original stack trace** —
  Check: when translating an exception inside `catch`, the original stack trace must be
  attached to the new exception with `ExceptionDispatchInfo.SetRemoteStackTrace` before it is
  thrown. Carrying an `InnerException` via `throw new XFailure(msg, ex)` instead violates core
  rule S7.5: the new exception's stack starts at the translation line.

## S8

- **S8.1-csharp Async critical sections must be serialized with `SemaphoreSlim(1, 1)`** —
  Check: a critical section spanning an `await` that is guarded by `lock` plus a `bool`
  instead of a `SemaphoreSlim` violates core rule S8.1: `lock` cannot span an `await` (the
  compiler rejects that line), so the rewrite usually protects only the half before the
  `await`, which had no contention to begin with.

## S9

- **S9.1-csharp An `event`'s subscriber list is unbounded** — Check: a `+=` on an event with
  no matching `-=` that can be named violates this rule: a C# event holds strong references to
  its subscribers, so when the publisher outlives a subscriber, the subscriber is never
  collected and its callbacks are still delivered after it has been torn down. Example: a
  short-lived subscriber subscribes to a long-lived singleton's event on creation, and nobody
  unsubscribes on teardown.

## S10

- **S10.1-csharp An `enum`'s range is its underlying integer's entire range** — Check: an enum
  read back from storage, the network or `Enum.Parse` that is not checked at the boundary with
  `Enum.IsDefined` or an exhaustive `switch` expression violates core rule S10.1:
  `(Phase)99` is legal, `JsonSerializer.Deserialize<Phase>("99")` accepts it as is, and a
  `switch` statement that misses it just runs through silently — a `switch` expression is
  caught by the compiler's CS8524; a statement has no such protection.

## S15

- **S15.1-csharp `?.` is an unnamed guard** — Check: a `?.` or `??` whose guarded `null` has
  no nameable source path violates core rule S15.1: the whole expression silently evaluates to
  `null` or does not run at all, and that unexplained `null` is the defect.

## S16

- **S16.1-csharp An exposed read-only collection must really be read-only** — Check: an
  object behind a return value declared `IReadOnlyList<T>` that is the owner's own `List<T>`
  violates core rule S16.4: the interface is only a view, and a single `as List<T>` gives the
  caller the owner's internal collection. `AsReadOnly()` blocks that cast; if the caller needs
  a snapshot of the current state, return a copy.
