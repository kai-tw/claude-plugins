---
type: llm
---
PASS if the tool exits 0, prints the core rules (the `## S1 — ` heading), prints no language rules, and writes a note on stderr that names lib/a.py or its extension.
FAIL if it exits 2, prints nothing, prints a language's rules for .py, or gives no note.
