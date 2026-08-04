// Blueprint-reviewer criteria registry.
// SSOT for criterion numbers + labels used across all plan schemas.
// Full scoring rubrics (1–10 anchors, specific questions) live in
// blueprint-reviewer.md §Criterion N — this registry is the routing layer only.
//
// Keys follow `c<N>` convention; referenced in plan body section `criteria` arrays.
// Run: node .claude/skills/archivist/scripts/notion_payload.mjs criteria <db>  to see the routing table.
export const CRITERIA = {
  c1:  { n: 1,  label: 'Time complexity' },
  c2:  { n: 2,  label: 'Space complexity' },
  c3:  { n: 3,  label: 'Scalability' },
  c4:  { n: 4,  label: 'Extendability' },
  c5:  { n: 5,  label: 'Low coupling' },
  c6:  { n: 6,  label: 'Design correctness' },
  c7:  { n: 7,  label: 'Runtime error handling' },
  c8:  { n: 8,  label: 'Package usage' },
  c9:  { n: 9,  label: 'Testability' },
  c10: { n: 10, label: 'Abstraction, reuse & ownership' },
  c11: { n: 11, label: 'Migration & back-compat' },
  c12: { n: 12, label: 'Startup & initialization order' },
};
