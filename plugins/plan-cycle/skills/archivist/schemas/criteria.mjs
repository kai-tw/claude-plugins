// Blueprint-reviewer criteria registry.
// SSOT for criterion numbers + labels used across all plan schemas, AND for
// which gate owns each one (`where`) — the split lives here once, and both
// reviewers cite it rather than restating it.
//
//   where: 'plan' — graded before code by `blueprint-reviewer`, because getting
//                   it wrong is expensive to reverse once code exists (layering,
//                   ownership, migration strategy, dependency choice).
//                   Full rubric: blueprint-reviewer.md §Criterion N.
//   where: 'diff'  — graded on real code by `code-reviewer`, against the
//                   `.claude/rules/` file that owns it. Sharper there: a catch
//                   block is inspectable, a predicted one is not. `code-reviewer`
//                   declares each in its `coverage:` line, so the move is
//                   auditable instead of becoming a silent gap.
//
// Numbers are stable across the split — a shipped plan citing "criterion 7"
// still resolves, it just resolves to the other gate.
//
// Keys follow `c<N>` convention; referenced in plan body section `criteria` arrays.
// Run: notion-payload criteria <db>  to see the routing table.
export const CRITERIA = {
  c1:  { n: 1,  label: 'Time complexity',               where: 'diff' },
  c2:  { n: 2,  label: 'Space complexity',              where: 'diff' },
  c3:  { n: 3,  label: 'Scalability',                   where: 'diff' },
  c4:  { n: 4,  label: 'Extendability',                 where: 'diff' },
  c5:  { n: 5,  label: 'Low coupling',                  where: 'plan' },
  c6:  { n: 6,  label: 'Design correctness',            where: 'plan' },
  c7:  { n: 7,  label: 'Runtime error handling',        where: 'diff' },
  c8:  { n: 8,  label: 'Package usage',                 where: 'plan' },
  c9:  { n: 9,  label: 'Testability',                   where: 'diff' },
  c10: { n: 10, label: 'Abstraction, reuse & ownership', where: 'plan' },
  c11: { n: 11, label: 'Migration & back-compat',       where: 'plan' },
  c12: { n: 12, label: 'Startup & initialization order', where: 'diff' },
};
