---
name: plugin-release
description: Release a plugin from this marketplace repo — pick the semver level, bump plugin.json, commit, push, reinstall locally, and verify the installed copy actually matches source. Use when a plugin's files have changed and the change needs to reach anyone, or when asked to bump, release, tag or publish a plugin here.
---

# Releasing a plugin

A plugin change that does not move `version` **never reaches anyone**, silently.
Installs are cached per version under
`~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`, so the installer
compares versions, sees no difference, and keeps serving the copy it already
has. A *directory* marketplace behaves exactly the same — having the files open
in front of you does not mean they are installed.

That is not hypothetical: `dart-lsp` once shipped without its skill for a whole
session because the skill was added at 1.0.0 without a bump.

The script does the mechanics. Your job is the one judgment it cannot make.

## Your job: pick the level

Ask what an existing user experiences when they upgrade.

| Level | When | Example here |
| --- | --- | --- |
| `major` | Something breaks for existing users | rename the plugin, stop claiming an extension, remove a skill, require a newer SDK |
| `minor` | New capability, old behaviour unchanged | add a skill, add a hook, support another file extension |
| `patch` | Fix only, nothing new | correct a README, fix a wrong path, adjust a timeout |

Left digit increments, everything right of it resets: 1.1.3 plus a feature is
1.2.0, not 1.1.4.

If a change is purely repo infrastructure — `.github/`, this skill, the root
README — **no plugin was released**; do not bump anything.

## Run it

```bash
node .claude/skills/plugin-release/scripts/release.mjs <plugin> <major|minor|patch>
```

Dry run by default: it prints the version transition, the tag it would create,
and every file changed since that plugin's last tag. **Read that file list back
to the user and confirm the level fits it** before releasing. An empty list
means there is nothing to release — say so rather than cutting a version.

Then, once agreed:

```bash
node .claude/skills/plugin-release/scripts/release.mjs <plugin> <level> --commit
```

It refuses to run on a dirty working tree, so a release never sweeps up
unrelated edits. Commit or stash those first.

## What it does, and why the order is fixed

0. **Evals** — `run-evals.mjs <plugin>`, the same check CI runs on every PR.
   Fails when the plugin's evals fail, grade nothing, or are missing while the
   plugin carries code. Before the bump, so a failure leaves nothing to revert.
1. **Bump** `plugin.json`.
2. **`validate.mjs`** — structural checks, before anything is published. On
   failure it reverts the bump and stops, leaving the tree as it found it.
3. **Commit.**
4. **`check-version-bump.mjs`.** This one reads *git history*, so it cannot run
   with the others in step 2 — at that point the bump exists only in the working
   tree, and the check would compare the still-unbumped `HEAD` and fail every
   release by construction.
5. **Push.**
6. **Refresh the marketplace index, then update every install** in
   `~/.claude/plugins/installed_plugins.json`, each from its own `projectPath`
   and scope (`consumers.mjs`). The refresh is not optional: `claude plugin
   update` compares against the index it already holds, so without it the update
   truthfully reports "already at the latest version" with the OLD number. If the
   marketplace points somewhere other than this repo, the script says so and
   stops at a clean success rather than failing a check that could not have passed.
7. **Verify** every install's recorded version, and that the cache holds every
   file the release commit has for the plugin.
8. **Verify it loads** in each install's project. `claude plugin update` does
   not install newly declared `dependencies`, so a complete cache can still fail
   to load everywhere.

Step 4 is downstream of the commit because anything that inspects committed
history has to wait for the commit.

**This script does not tag.** The tag belongs to
`.github/workflows/plugin-tag.yml`, which tags whatever version arrives on
`main`. Tagging here would satisfy that workflow, so it would find nothing to do
and the version would ship untagged.

Steps 7–8 are the ones that matter **when they run**. Every earlier step succeeded
during the dart-lsp incident; the failure was visible only by looking inside the
cache. If either fails, the release did not land — do not report
success. **Two ways steps 6–8 correctly do not run**, and both end with the
release pushed and installed nowhere — report that, never "installed and
verified": the marketplace points somewhere other than this repo, or **HEAD is
not the repo's default branch**. The second is the ordinary case here, since one
bump per PR at close-out means the release commit lands on the PR branch while
the marketplace serves `main`; the script says so and names the script below.

## After the merge

Once the PR is ready, start this with the Bash tool's `run_in_background: true`:

```bash
node .claude/skills/plugin-release/scripts/after-merge.mjs <pr>
```

It asks GitHub every minute until the PR merges, then runs steps 6–8 for every
plugin the PR changed, syncs the main checkout and removes the PR's worktree and
branch. Its exit wakes the session, so a merge needs no one to report it — the
app's PR monitor wakes a session on CI failures, conflicts and review comments,
never on a merge. Exit 1 (closed unmerged, 24 h without a merge, or a failed
check) prints why; report it as it stands.

LSP servers, hooks and scripts from the updated plugin take effect on the **next
session**, not this one — tell the user which running sessions need a restart.
