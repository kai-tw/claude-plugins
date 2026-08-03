# When (not) to widget-test

`Read` this file when deciding whether a widget test is the right
layer for a given assertion. Most test authoring here is unit-
level; widget tests of `MaterialApp + ScaffoldMessenger +
BlocProvider + builder` harnesses are the most expensive cell of the
pyramid in agent-budget terms — `pumpAndSettle` timeouts run ten
minutes when one inherited-widget detail is off, and the failure
mode rarely points at the actual bug.

## Skip the widget test when

- The behavior is observable through the state holder's emitted state or
  the service's emitted stream — write a unit test that asserts
  the emit, and trust the framework to render.
- The widget under test is a Material/Cupertino primitive
  (`SnackBar`, `Dialog`, `BottomSheet`) wrapped in your own glue.
  Test the glue (which payload was passed, with what duration,
  what action callback) at the unit level; the framework owns
  the rendering.
- The test requires a router, a `MaterialApp`, a
  `ScaffoldMessenger`, and a state holder just to assert "the SnackBar
  appears." The harness cost vs. the assertion value is
  upside-down.

## A widget test earns its place when

- The widget itself has non-trivial layout or render logic
  (`CustomPainter`, `LayoutBuilder` branching, complex `Slivers`).
- An interaction (gesture, keyboard, focus) crosses widget
  boundaries and a holder-level test cannot observe it.
- A theming / `colorScheme` regression is plausible and a golden
  test would over-fixate on pixels.

When in doubt, the cheaper test is the right test.
