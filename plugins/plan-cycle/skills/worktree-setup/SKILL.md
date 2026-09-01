---
name: worktree-setup
description: >-
  Build a project's worktree bootstrap — the `.worktreeinclude` file plus the
  init step that makes a fresh worktree compile, lint and test without a full
  regeneration. Derives both from what the project actually generates rather
  than copying another project's answer.
  TRIGGER — setting a repo up for worktree isolation, or fixing a worktree that
  starts broken: worktree is missing generated files · worktree won't build ·
  set up .worktreeinclude · what should a new worktree copy · worktree init
  script · why does my worktree need a full codegen · 新 worktree 建不起來 ·
  worktree 缺生成檔 · 設定 worktree 初始化
  NOT for: deciding WHEN to use a worktree (that is the project's CLAUDE.md),
  or worktree lifecycle traps like submodule removal and sub-agent cwd (those
  are `git-ops`).
---

# Worktree bootstrap — deriving it, not copying it

A worktree is a **fresh checkout of tracked files only**. Everything gitignored
is absent: build outputs, dependency trees, local env files. A project whose
compile depends on generated code therefore starts broken in every new worktree
until something puts that state back.

Two mechanisms put it back, and the whole job is deciding which one each artifact
belongs to.

## The one question that decides everything

For each gitignored thing a build needs:

> **Is it valid at a different absolute path?**

- **Yes** → copy it. Put the pattern in `.worktreeinclude`. Free and instant.
- **No** → regenerate it. Put the command in the init step. Costs time, but a
  copy would be actively wrong.

Getting this backwards is not a slow build, it is a silent miscompile. The
canonical trap: Dart's `.dart_tool/package_config.json` stores **absolute**
paths to every package. Copy it into a worktree and imports resolve back to the
main tree — you edit the worktree and build the main checkout's sources, with no
error anywhere. Node's `node_modules` has the same shape (absolute paths in
`.bin` symlinks, platform-specific binaries), as does any lockfile-derived cache
keyed by location.

Ask it per artifact. A project usually has both kinds.

## What `.worktreeinclude` actually does

Project root, `.gitignore` syntax. A file is copied only when it **matches a
pattern AND is itself gitignored** — tracked files are never duplicated, so an
over-broad pattern cannot corrupt the checkout.

It applies to worktrees Claude Code creates with git: `--worktree`,
`EnterWorktree`, subagent worktrees, and desktop parallel sessions. Two cases
skip it, and both are silent:

- `git worktree add` run by hand — the plain git command knows nothing about it.
- A project with a `WorktreeCreate` hook — the hook **replaces** creation
  entirely, so copying must move inside the hook script.

Also add `.claude/worktrees/` to `.gitignore`, or every worktree's contents show
up as untracked files in the main tree.

## Deriving the two lists

1. **Find what the build generates.** Read `.gitignore` for build outputs, then
   confirm against reality — the ignore file lists intent, the filesystem holds
   the truth:

   ```bash
   git status --ignored --porcelain | grep '^!!' | head -50
   ```

   Cross-check with the project's own docs (`CLAUDE.md` "Commands" sections name
   the codegen step) and count what you find, so the `.worktreeinclude` pattern
   can be verified to match it later.

2. **Split by the path question above.** Path-independent outputs — generated
   source files, compiled assets — go to `.worktreeinclude`. Anything holding
   absolute paths, symlinks, or platform binaries goes to the init step.

3. **Find the regeneration commands.** These are the project's existing setup
   commands, not new ones. Prefer the cheapest that restores a working tree; the
   copied files mean the expensive full codegen is usually **not** needed.

4. **Write the init script** to the project's own convention (`tool/`,
   `scripts/`, `bin/` — follow what is there). It must be re-runnable, and it
   should default to the cheap path with a flag for the expensive one, because
   the common case is a ticket that touches no annotated source.

5. **Verify by creating a real worktree**, not by reading the config. See below —
   this step is not optional, because every failure mode here is silent.

## Verification

Config that looks right and behaves wrong is the norm in this area, so prove it:

```bash
# 1. Patterns match real files, and those files are genuinely gitignored
#    (a pattern matching only tracked files copies nothing).
git check-ignore -q <one-matched-file> && echo "eligible"

# 2. Create a worktree and look inside it.
claude --worktree wt-probe    # or EnterWorktree
#    In the worktree: are the generated files present?
find . -name '<generated-pattern>' | wc -l

# 3. Run the init script, then the project's own build/analyze/test.
#    A green analyze in the MAIN tree proves nothing about the worktree.
```

If step 2 finds nothing, the usual cause is a pattern matching tracked files
only, or a `WorktreeCreate` hook silently bypassing `.worktreeinclude`.

## Worked example — Flutter with build_runner

Generated `.g.dart` / `.freezed.dart` are plain source files: valid anywhere, so
they copy. `.dart_tool/` holds absolute paths, so it cannot.

```text
# .worktreeinclude
**/*.freezed.dart
**/*.g.dart
```

```bash
# tool/worktree-init.sh
flutter pub get                       # rebuilds .dart_tool for THIS path
[ "$1" = "--regen" ] && dart run build_runner build
```

Codegen is skipped by default — `.worktreeinclude` already carried the outputs
across, and re-running it costs ~25s to reproduce files that are already
correct. `--regen` covers the case the copy cannot: a ticket that edits an
annotated source, where the copied outputs are stale.

The same reasoning transfers, not the file list. A Node project copies `.env`
and regenerates `node_modules`; a Rust project regenerates `target/`. Derive it
from step 1 rather than adapting this example.

## Anti-patterns

- **Copying another project's `.worktreeinclude`.** The patterns encode that
  project's build, and a pattern that matches nothing fails silently.
- **Copying a dependency tree** (`.dart_tool/`, `node_modules/`, `vendor/`) to
  save time. This is the silent-miscompile trap, not an optimization.
- **Running full codegen in the init step by default** when
  `.worktreeinclude` already carried the outputs. Every worktree pays for it.
- **Declaring it done from config review.** Create a worktree and build in it.
- **Putting the "when to use a worktree" policy here.** That is a project
  decision and belongs in its `CLAUDE.md`, which is also the only place
  `EnterWorktree` accepts standing instructions from.
