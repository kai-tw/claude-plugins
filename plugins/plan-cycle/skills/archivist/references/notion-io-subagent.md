# Archivist — when to delegate heavy Notion I/O to a disposable subagent

With the `ntn` CLI, most KB ops are cheap and stay **inline** in the archivist's
own context:

- **Reads** are a single `ntn datasources query <ds> --filter '<json>' --json`
  (server-side filter + sort) that returns only the matching rows' **properties**
  — no page-body fan-out. Build the filter with
  `notion-payload filter <db> Prop=Val …`.
- **Writes** run through `notion-payload
  <create|update> <manifest> --commit`, which drives `ntn` per row and prints only
  the distilled result (✓ lines + a `[{title,id,url}]` JSON) — the page bodies
  never re-enter context.

So do not delegate inventory sweeps or ordinary writes. **Delegate only the
one case that pulls bulk into context:** reading **many full page bodies**
for synthesis (e.g. archiving a feature → reading every plan's body), since
`ntn pages get` returns the whole Markdown body. Run that in a disposable
subagent so the bodies are born and die there and only your distilled notes
return.

## The contract (when you do delegate)

- The subagent's final message returns **ONLY the distilled result** — the notes /
  rows / URLs + verdict. It **never** pastes a raw page body back. Echoing the page
  defeats the point.
- **Pass by reference.** For a write, hand the subagent a **manifest file PATH**,
  never the body inline.
- **Model:** `haiku` — the work is mechanical (run `ntn`, run the builder, return
  output). Synthesis (turning sources into clean rows / notes) and any judgment
  stay with the caller.
- **The plan-cycle ledger stays with the caller** (`SKILL.md §Plan-cycle ledger`).
  The subagent never touches it.
- **`ntn` resolution:** the binary may not be on a non-interactive `PATH`; call it
  via `"${NTN_INSTALL_DIR:-$HOME/development/ntn}/ntn"` (or rely on the builder,
  which resolves it itself).

## READ-BODIES template — read many page bodies for synthesis

For when you must read the full bodies of several pages (a plan trail, every
source for an archive). Spawn one `general-purpose` subagent (`model: haiku`):

```
You are a disposable Notion READ-BODIES worker. Your only job: fetch the page
bodies, distill them, and let your context (full of raw bodies) be thrown away.
Do NOT paste any raw page body into your final reply.

Pages: <list of page ids / urls, or: query <ds-id> with filter <json> first>.
Distill each into: <e.g. problem · final approach · key decisions · outcome>.

Steps:
1. NTN="${NTN_INSTALL_DIR:-$HOME/development/ntn}/ntn"
2. (If you must discover the set first) one read:
     "$NTN" datasources query <ds-id> --filter '<json>' --json
3. For each page: "$NTN" pages get <id>   (returns frontmatter + Markdown body)
4. Return ONLY the distilled notes per page (title + the requested fields) and a
   one-line coverage note (N pages read). Nothing else — no raw bodies.
```

## WRITE template — only for a LARGE batch you want off-context

Ordinary writes run inline via the builder's `--commit`. Delegate only a large
multi-row batch whose per-row progress you don't want in the caller. The caller
synthesizes the rows and writes the manifest FIRST, then spawns one
`general-purpose` subagent (`model: haiku`):

```
You are a disposable Notion WRITE worker. Your only job: run the builder in commit
mode and return URLs + a verdict. Do NOT echo the row bodies back.

Manifest: <PATH to manifest.json>  (db "<key>", mode <create|update>).

Steps:
1. notion-payload <create|update> <PATH> --commit
   (the builder validates + encodes, then for create: POSTs each page via
   `ntn api v1/pages` + writes the body via `ntn pages edit` + verifies the
   `<!-- archivist-generated -->` marker; for update: PATCHes properties.)
   If it exits non-zero, return its error verbatim and STOP. Never hand-encode.
2. Return ONLY the printed `[{title,id,url}]` result + verdict PASS, or — if any
   row reported `NO-MARKER` / the builder failed — MISMATCH (+ exactly what failed).
```
