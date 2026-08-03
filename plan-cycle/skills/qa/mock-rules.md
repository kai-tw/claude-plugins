# Mock-pattern enforcement (test-side detail)

`Read` this file when authoring or reviewing tests that mock a
listenable- or stream-exposing collaborator. The production-side
rules — what shape the seam itself must take so a test does not
need a forbidden mock — live in the project's state-management rule
§"Collaborator Seams" (referenced from
`.claude/rules/testing.md` Rule 3) and bind impl-side too. This
file carries the test-side detail that only matters under
`/qa`: which `Mock implements` targets are forbidden,
the hand-written fake pattern, and the review checklist.

## Forbidden `Mock implements` targets

**Lint-enforced:** `avoid_listenable_mock` flags
`class _Mock<X> extends Mock implements <X>` declarations in `test/`
when `<X>` inherits listenable machinery (Prong A) or exposes a public
`Stream` / `StreamController` / `Sink` member (Prong B).

Do not write any of these in a test file:

- `class MockGoRouter extends Mock implements GoRouter {}`
  (`GoRouter` extends `ChangeNotifier`) — Prong A
- `Mock implements <any ChangeNotifier subclass>` — Prong A
- `Mock implements <any ValueNotifier>` — Prong A
- `Mock implements <any class holding a TickerProvider or other
  Listenable-typed field>` — Prong A
- `Mock implements <any class exposing a Stream getter,
  StreamController field, or Sink>` — Prong B (use a fake)

If the class you need to mock falls into any of these, you must
rewrite the seam (per the project's state-management rule §"Collaborator
Seams") *and/or* replace the mock with a hand-written fake (below).

## Hand-written fake pattern for Stream-exposing interfaces

When the seam is a narrow interface that legitimately exposes a
stream (e.g. a tab-switch signal, an event bus, an observer
port), do not `Mock implements`. Write a small fake:

```dart
class _FakeHomepageNavigator implements HomepageNavigator {
  final StreamController<void> _controller =
      StreamController<void>.broadcast();

  int selectBookshelfCallCount = 0;

  @override
  Stream<void> get bookshelfRequested => _controller.stream;

  @override
  void selectBookshelf() {
    selectBookshelfCallCount++;
    _controller.add(null);
  }

  Future<void> dispose() => _controller.close();
}
```

Dispose it in `tearDown`:

```dart
tearDown(() async {
  await fakeHomepageNavigator.dispose();
});
```

The fake drives real stream events through a real broadcast
controller, so tests assert the state holder's actual subscription
behavior — not the mock's stubbed return values.

## Review checklist

When reviewing a diff that adds tests:

1. Scan for `class Mock\w+ extends Mock implements \w+`.
2. For each hit, classify the implemented class:
   - Extends `ChangeNotifier` / `Listenable` / `Stream` or holds
     listenable-typed fields → **Prong A reject**; require a
     production-side seam rewrite (callbacks / narrow interface).
   - Exposes a `Stream` getter / `StreamController` / `Sink` but
     does not inherit listenable machinery → **Prong B reject**;
     require a hand-written fake backed by a real
     `StreamController`. The seam itself may stay as-is.
3. Scan production changes for new public APIs that take
   `ChangeNotifier` / `Listenable` / concrete notifier types as
   parameters or return types where a test will exercise that
   seam. Push for callbacks or narrow interfaces instead.
