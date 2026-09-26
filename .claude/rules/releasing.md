# Shipping rules

- **Changes go on a branch + draft PR, never a direct commit to `main`.** A plugin change
  carries an eval case that fails on the old version; run `gh pr ready` only after CI's
  `Evals` (`.github/scripts/run-evals.mjs`) is green and the version is bumped — the draft
  state is what stops a merge while the agent is still working. Right after `gh pr ready`,
  start `node .claude/skills/plugin-release/scripts/after-merge.mjs <pr>` with
  `run_in_background: true`: it waits for the merge and does everything after it, and its
  exit wakes the session, so nobody has to report the merge.

- **Changing anything under `plugins/<plugin>/` means bumping `version` in `plugin.json`.**
  Consumers install into `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/` — **a
  real directory named after the version**. When one version number holds two different
  contents, nobody outside can tell whether an update landed, and the user is told
  "already at the latest version". A bug fix is a patch (0.4.0 → 0.4.1); adding or changing
  behaviour is a minor.
- **Pushed is not live, and "updated" is not live either.** The marketplace reads
  `kai-tw/claude-plugins`' default branch on GitHub; `after-merge.mjs` (or `release.mjs` run
  on the default branch) refreshes the index and updates and verifies every install in
  `~/.claude/plugins/installed_plugins.json`. But **which version PATH points at cannot be
  predicted from outside**: it changes
  during a session and does not follow installs — one session's transcript shows `0.15.1` →
  `0.17.0` → `0.19.0` in turn (no restart, no `update`, and `0.18.0` skipped), and it still
  resolved to `0.19.0` after `0.19.1` was in the cache. What triggers the refresh is
  unknown and invisible from inside the session.
  It happens because each `bin/` wrapper is `exec "$here/../skills/…"`, where `$here` is
  **its own install directory**, not any working directory — whichever version directory it
  resolves to is the implementation that runs, **scripts, schemas, skill text and
  frontmatter alike**; no half of it is live.
  Neither inference works: an install record does not mean a given session sees it, and
  `ListAgents`' "started N minutes ago" is the **reconnect** time, not the session start
  (measured: `ListAgents` said 25 minutes, the transcript's `birth` was 17 hours earlier).
  A cache directory's mtime is not an install record either — installing a new version
  touches the mtime of existing version directories.
  Worst of all, the wrapper almost never changes: two versions' `bin/<name>` share an md5
  while the scripts under them differ, so `cmp` on the wrapper always looks fine. **So always
  check, and check the implementation** (`type -a <name>` for the version directory it
  resolves to, or the version the output reports about itself). For certainty, restart the
  session.
- **On a PR branch, `release.mjs` skips steps 6–8 by itself.** The marketplace serves the
  default branch, so a new version on a branch cannot be installed anywhere until it merges.
  When HEAD is not the default branch the script stops after step 5, prints
  `✔ … committed and pushed on <branch> — install after merge` and names `after-merge.mjs`
  — **that is success, not failure**.
- **A version that adds `dependencies` needs the consumer to install them first.** `update`
  does not install newly declared dependencies, and one missing plugin fails the load in
  every scope; `after-merge.mjs` and `release.mjs` report it as `FAILS TO LOAD`.
- **Call your own scripts by bare name.** A plugin's `bin/` is on PATH once it is enabled;
  the install path cannot be derived from the project and changes with every bump. Write
  `asst-budget`, not `bash .claude/hooks/…` — the latter fails with a single
  `No such file or directory` line that looks just like "nothing to do this time".
- **Tags are not made by hand; do not try.** Once a version reaches `main`, the
  `plugin-tag` workflow creates `<plugin>--v<version>` from `plugin.json` and pushes it.
  Cloud sessions' GitHub credentials refuse tag pushes anyway (403), and **tagging locally
  first is worse**: the workflow finds the tag already there and does nothing, so the
  version is never really tagged.
- **Bump a PR's version once, at close-out.** The tag is made only when the version reaches
  `main` (previous rule) — bumps in the middle of a PR are never tagged or seen by any
  consumer; they only leave a trail of versions in `git log` that never existed. Run
  `release.mjs` once, when the change has settled and the PR is really going out. While a
  plugin still has an unmerged PR, add later changes to that PR: a second PR stacked on it
  bumps again, adding a version and another round of consumer updates.
