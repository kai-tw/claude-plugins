---
name: plugin-release
description: Release a plugin from this marketplace repo — pick the semver level, bump plugin.json, commit, tag, push, reinstall locally, and verify the installed copy actually matches source. Use when a plugin's files have changed and the change needs to reach anyone, or when asked to bump, release, tag or publish a plugin here.
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

1. **Bump** `plugin.json`.
2. **Run both repo checks** — before anything is published. On failure it
   reverts the bump and stops, leaving the tree as it found it.
3. **Commit.**
4. **Tag and push.** The tag must come after the commit it points at, which is
   why this cannot be a pre-commit gate. `claude plugin tag` also validates that
   `plugin.json` and the marketplace entry agree — a plain `git tag` does not.
5. **Update the local install.**
6. **Verify** the installed cache contains every file that exists in source.

Step 6 is the one that matters. Steps 1–5 all succeeded during the dart-lsp
incident; the failure was only visible by looking inside the cache. If it
reports missing files, the release did not land — do not report success.

## After a release

Nothing else is required. LSP servers and hooks from the updated plugin take
effect on the **next session**, not this one — if the user expects to see the
change immediately, tell them to restart.
