---
name: reclaim-space
description: >-
  Developer-disk space reclamation for the Flutter projects on this machine —
  the close-out step that stops a shipped cycle's build output and machine-wide
  tool caches from accumulating until they block the next build. Two tiers:
  PROJECT (`flutter clean` — `build/` + `.dart_tool/`) and GLOBAL (Xcode derived
  data, the Dart analysis cache, simulator scratch, superseded Gradle version
  caches). Everything it touches regenerates. Body carries the measurement
  discipline (`df` delta, never `du` totals — `du` double-counts APFS clones),
  the fail-closed Gradle version scan, the busy-build refusal, and what is
  deliberately never touched.
  TRIGGER: reclaim space · free disk space · free up space · clean up disk ·
  disk is full · running out of space · clean caches · clear DerivedData ·
  clear the dart cache · clean xcode caches · stale gradle cache · gradle cache
  is huge · clean the build folder · flutter clean everything · delete
  unavailable simulators · how much space can I get back · 清理空間 ·
  釋放空間 · 硬碟快滿了 · 磁碟空間不足 · 空間不夠 · 清快取 · 清掉快取 ·
  清 DerivedData · 清 gradle 快取 · gradle 快取太大 · 清 build 資料夾 ·
  清掉模擬器 · 可以清出多少空間 · 收尾清空間
  NOT for: deleting anything non-regenerable — Xcode Archives, source, git
  history, signing assets (this skill never touches them and must not grow to);
  emptying the macOS Trash (TCC-protected, the human presses ⌘⇧⌫); the Gradle
  cache RETENTION policy, which is `~/.gradle/init.d/cache-cleanup.gradle` and
  is a different mechanism (per-entry LRU during builds, not a sweep).
---

# reclaim-space

A shipped cycle leaves gigabytes behind and nothing else in the flow removes
it. This is the sweep. It runs at **Phase 13 Stage 1** — see
`engineer/references/closeout.md §Stage 1`, which owns the *when* and is not
restated here.

```bash
reclaim-space                        # DRY RUN — list targets, delete nothing
reclaim-space --yes                  # reclaim (project tier = cwd, + global tier)
reclaim-space --yes --all-projects   # every Flutter project under the scan root
reclaim-space --yes --global-only    # skip flutter clean
```

The command is on PATH whenever this plugin is enabled. `RECLAIM_SCAN_ROOT`
overrides where sibling projects are looked for (default `$HOME/GitHub`).

## Believe the delta, not the estimate

The per-target sizes in the listing are `du` output, and **`du` counts an APFS
copy-on-write clone once per clone**. Measured 2026-08-07: XCTest device clones
read 8.0G under `du` and freed exactly zero bytes when deleted, every block
being shared with the real device set. Only the change in free space is real, so
that is the number the live run prints and the only one worth reporting to
anyone. A target whose estimate dwarfs the delta is a clone, not a leak — do not
go hunting for the "missing" space.

## Worktrees are in the project tier

`--all-projects` sweeps each repo **and each of its `.claude/worktrees/*`**. A
worktree is a full checkout: measured 2026-09-01, six of them held **12.7G**, of
which `build/` was about three quarters — more than the machine had free. None
of it needs deleting to reclaim: `build/` regenerates, so every branch, every
unmerged commit and every uncommitted file survives the sweep.

This matters beyond tidiness. `/System/Volumes/VM`, where macOS writes swap,
shares an APFS container with these checkouts (same `/dev/disk3s6`, same free
pool). **Free disk is swap headroom**, and on a 16G machine swap is what stands
between several concurrent test suites and a watchdog reboot. The
`resource-gate` hook refuses a new worktree below a free-space floor for that
reason, and points here.

## What it refuses, and why it fails closed

Deleting a Gradle cache under a live daemon, derived data under a running
`xcodebuild`, or a project's `.dart_tool/` and `build/` under a **running test
suite**, corrupts the work in progress. All are cheap to detect, so a live run
refuses outright rather than racing.

The Gradle tier derives the live version set by scanning every project's
`gradle-wrapper.properties`; a hardcoded version goes stale silently and then
deletes a cache someone is mid-build against. **If the scan finds no project at
all it skips the tier entirely** — an empty scan means "cannot know", never
"nothing is in use".

## Deliberate omissions

Two things it will not clean, both because the cost lands on the next build
rather than on disk:

- **`~/Library/Caches/org.swift.swiftpm`** — the shared SPM download cache that
  `build/ios/SourcePackages` is populated from. Clearing it turns the next iOS
  build into a network re-download, for well under a gigabyte.
- **`flutter pub get` after the clean** — a closed-out feature line does not
  need a resolved project, so the next session that opens it does the pub get.
  Note the reason is workflow, **not** space: pub-get does re-populate
  `build/ios/SourcePackages`, but that directory is largely an APFS clone of
  `~/Library/Caches/org.swift.swiftpm`, so its 1.3–1.7G `du` size costs only
  ~0.1G of real disk on a warm cache. Do not defend this choice with the `du`
  figure — it is the same clone illusion described above.

It deletes with `rm -rf` rather than `trash` because a trash on the same APFS
volume frees nothing until the bin is emptied, and emptying it is TCC-protected.
The guards that make that safe are dry-run-by-default, a `$HOME/`-prefix
assertion before every delete, and literal path lists.
