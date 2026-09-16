# Plan-lite — one page, machine-checkable, never read by the founder

The builder's contract with itself and the verifiers. Sections and cell forms are
the plan-cycle engineering-plan questionnaire's, cut to what the verifiers read:

```
## Goal            <one line, from the 任務書>
## Boundary        <in / out, one line each>
## Decisions       <the brief's rulings, verbatim ids>
## Classes         | Class | Layer | File (NEW/MOD/DEL) | 職責 | 為何要新增 |   ← NEW rows must answer 為何要新增
## Data flow       mermaid; node names match §Classes verbatim
## Conformance     | Requirement | 實作於 (Class.method) | 驗證 |
## Risks           | Risk | Mitigation |   ← no `monitor` / `TBD`
## Debt            <cap residue, one line each, each with a Deferred task>
```

Lint: the project's `plan-lint <file>` when present; otherwise the builder checks
by hand that every `(MOD)`/`(DEL)` file exists, every NEW row answers 為何要新增,
every Data-flow node is a §Classes row, every Conformance row names a method that
exists. Three red runs → stop (`asst-budget`).
