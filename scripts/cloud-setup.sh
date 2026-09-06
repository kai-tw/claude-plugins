#!/bin/bash
# Cloud-environment setup for a Claude Code session — project-agnostic.
#
# Paste into the environment's "Setup script" field (claude.ai → Settings →
# Claude Code → the environment). It provisions the three things a fresh
# container lacks: the Flutter toolchain, this marketplace's Claude plugins
# (seeded for every session — see the plugin block for why a seed and not an
# install), and the `ntn` CLI the archivist reaches Notion through.
# One file rather than several, because that field takes exactly one script and
# a two-paste instruction is how half of it silently never gets pasted.
#
# Reusable across every project because it bootstraps whatever the environment
# actually cloned and whatever that project's settings declare, instead of
# naming a repo or a plugin list; adding a repo needs no edit here.
#
# Why the Setup script field and not a SessionStart hook: this field's
# filesystem result is SNAPSHOTTED, so the ~1.5 GB SDK download is paid once per
# cache generation instead of once per session. The snapshot rebuilds when this
# script changes, when the allowed hosts change, or after ~7 days.
#
# Three constraints it is written around:
#   * A non-zero exit makes the SESSION FAIL TO START, so every step is
#     advisory and the script ends `exit 0`. A transient registry blip must
#     never cost a session.
#   * It has to finish in ~5 min or the snapshot never builds — which is why
#     codegen is deliberately NOT here (see the closing note).
#   * Installs need registries: the environment must be on Trusted network
#     access, not None.
set -uo pipefail

# Pin rather than track `stable`: an unpinned "latest" re-downloads whenever
# Google ships, and lets a session silently disagree with the version CI
# resolved. Bump this one line when CI's stable moves.
FLUTTER_VERSION="3.47.2"
FLUTTER_HOME="${FLUTTER_HOME:-$HOME/flutter}"   # basename must stay `flutter`:
                                               # that is what the archive unpacks to
WORKSPACE="${WORKSPACE:-/home/user}"   # where cloud sessions clone source repos

log() { printf 'flutter-setup: %s\n' "$1"; }

install_flutter() {
  # bin/cache/flutter.version.json is the SDK's own version marker. `version` at
  # the SDK root is NOT it — that file holds a revision hash, not a semver.
  local marker="$FLUTTER_HOME/bin/cache/flutter.version.json"
  if [ "$(jq -r '.frameworkVersion // empty' "$marker" 2>/dev/null)" = "$FLUTTER_VERSION" ]; then
    log "flutter $FLUTTER_VERSION already present"
    return 0
  fi
  log "installing flutter $FLUTTER_VERSION"
  # Streamed straight into tar: the 1.5 GB archive is never written to disk.
  # Measured 1m21s, against ~4 min for download-then-extract — which is most of
  # the difference between fitting the 5 min budget and not.
  if curl -fsSL --retry 3 --max-time 900 \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
      | tar -xJ -C "$(dirname "$FLUTTER_HOME")"; then
    log "flutter $FLUTTER_VERSION installed"
  else
    log "WARNING: install failed — no flutter/dart in this environment"
    return 1
  fi
}

persist_env() {
  # /etc/profile.d is how this image already puts node, java, gradle and rbenv
  # on PATH, and it survives into the snapshot — so every later session finds
  # flutter with no hook involved.
  #
  # BOT=true silences the SDK's run-as-root banner, which would otherwise
  # prefix the stderr of every flutter and dart call. It is the right knob and
  # CI=true is not: flutter honours both, but CI=true also changes how
  # `flutter test`, npm and several dart reporters behave.
  cat > /etc/profile.d/flutter.sh <<EOF
export PATH=$FLUTTER_HOME/bin:\$PATH
export BOT=true
EOF
  # And into THIS shell: profile.d is only read by later login shells, so
  # without this the bootstrap below cannot find the SDK it just installed.
  export PATH="$FLUTTER_HOME/bin:$PATH"
  export BOT=true
  # The SDK reads its own version out of git; without this every invocation
  # dies on "detected dubious ownership" once ownership stops matching.
  git config --global --add safe.directory "$FLUTTER_HOME" 2>/dev/null || true
}

# Resolve dependencies for every Flutter project the environment cloned.
bootstrap_projects() {
  local pubspec proj pkg
  while IFS= read -r pubspec; do
    proj="$(dirname "$pubspec")"
    log "bootstrapping ${proj#"$WORKSPACE"/}"

    # Submodules first: a JS side-build resolving imports out of one (foliate-js
    # in NovelGlide's renderer/) fails with a wall of resolver noise otherwise.
    ( cd "$proj" && git submodule update --init --recursive ) >/dev/null 2>&1 \
      || log "WARNING: submodule checkout failed in $proj"

    # A sibling JS build (webpack renderer, tooling) resolves from its own
    # lockfile. `install`, not `ci`: the warm ~/.npm cache is the point here,
    # and this runs where determinism is CI's job, not the container's.
    for pkg in "$proj"/*/package.json; do
      [ -f "$pkg" ] || continue
      ( cd "$(dirname "$pkg")" && npm install --no-audit --no-fund ) >/dev/null 2>&1 \
        || log "WARNING: npm install failed in $(dirname "$pkg")"
    done

    ( cd "$proj" && flutter pub get ) >/dev/null 2>&1 \
      || log "WARNING: flutter pub get failed in $proj"
  done < <(find "$WORKSPACE" -maxdepth 2 -name pubspec.yaml -not -path '*/packages/*' -print 2>/dev/null)
}

# Install this marketplace's plugins and SEED them for every session in the
# environment. Three facts, each measured in a cloud container, shape the block:
#   * The snapshot is built by whichever repo's session first runs this script,
#     then reused for every repo. Reading the plugin list from the cloned
#     project installed nothing when the cache was rebuilt from a session on the
#     marketplace repo itself, and every NovelGlide session inherited that empty
#     snapshot. So: every plugin the marketplace lists, whatever was cloned.
#     The reverse trap remains, and the snapshot FOLLOWS THE REPOSITORY (a
#     seed built by a session on the marketplace repo never reached NovelGlide):
#     while this script runs, GitHub answers only for repositories attached to
#     the session, so the consuming repo's rebuild must run in a session that
#     has the marketplace repo attached as a second repository. Any other
#     rebuild reports UNREACHABLE (below) with that fix spelled out.
#   * A project's own `extraKnownMarketplaces` + `enabledPlugins` installs
#     NOTHING at session start. The CLI registers the marketplace and copies the
#     plugins into cache, then refuses to load them ("not cached — run /plugin to
#     refresh") because no install record exists; only `claude plugin install`
#     writes one. Silently: a skill that never loaded cannot announce itself.
#   * A plugin seed dir (CLAUDE_CODE_PLUGIN_SEED_DIR) needs no install record
#     and no workspace trust: the CLI resolves the project's `enabledPlugins`
#     against the seed's cache and puts their bin/ on PATH. It lives outside
#     $HOME, so it survives whatever the launcher does to ~/.claude.
#
# The seed variable must reach the CLI PROCESS. Measured: the environment's
# Environment variables field works, `env` in user settings works, `env` in the
# repo's .claude/settings.json does not (trusted or not). This script writes the
# user-settings copy; ALSO add it to the environment dialog (claude.ai →
# Settings → Claude Code → the environment → Environment variables), the copy
# that does not depend on ~/.claude surviving the snapshot:
#   CLAUDE_CODE_PLUGIN_SEED_DIR=/opt/claude-plugin-seed
# A session that loaded the seed resolves `type -a plan-lint` under $SEED_DIR.
MARKETPLACE_NAME="kai-tw"
MARKETPLACE_REPO="kai-tw/claude-plugins"
SEED_DIR="/opt/claude-plugin-seed"

# Where a failed bootstrap gets to speak. The setup log is written once, into a
# settings pane nobody reopens; user-scope CLAUDE.md is loaded into EVERY
# session in this container — the only channel left when the thing that failed
# to install is the tooling itself. Appended under a marker and removed by it,
# so this never eats a CLAUDE.md the environment put there for its own reasons.
REPORT="$HOME/.claude/CLAUDE.md"
REPORT_HEAD="## Claude plugins are MISSING from this environment"

clear_report() {
  [ -f "$REPORT" ] || return 0
  # Not `sed -i`: its in-place flag takes an argument on BSD and none on GNU,
  # and this file is edited on a mac while it runs on linux.
  sed "/^${REPORT_HEAD}\$/,\$d" "$REPORT" > "$REPORT.keep" 2>/dev/null \
    && mv "$REPORT.keep" "$REPORT"
}

report() {
  mkdir -p "$(dirname "$REPORT")"
  clear_report
  printf '%s\n\n%s\n' "$REPORT_HEAD" "$1" >> "$REPORT"
  log "!! PLUGINS UNAVAILABLE — recorded in $REPORT"
}

# Register the marketplace. A checkout the session cloned is the only path that
# works in an Anthropic-hosted environment: while the setup script runs, GitHub
# answers only for repositories attached to the session (documented under the
# GitHub proxy's repository scope, and measured as a failed ls-remote), so this
# private repo is reachable only when it is attached, which also clones it. The
# github path stays for environments that do carry a credential.
register_marketplace() {
  local mp dir
  while IFS= read -r mp; do
    [ "$(jq -r '.name // empty' "$mp" 2>/dev/null)" = "$MARKETPLACE_NAME" ] || continue
    dir="$(cd "$(dirname "$mp")/.." && pwd)"
    if claude plugin marketplace add "$dir" >/dev/null 2>&1; then
      log "marketplace $MARKETPLACE_NAME registered from $dir"
      return 0
    fi
  done < <(find "$WORKSPACE" -maxdepth 8 -path '*/.claude-plugin/marketplace.json' 2>/dev/null)

  # Probe before adding, because `marketplace add` failing and `marketplace add`
  # having nothing to do look identical from here — and a 401 on a private repo
  # is the exact failure this block exists to make visible.
  if ! git ls-remote "https://github.com/$MARKETPLACE_REPO" HEAD >/dev/null 2>&1; then
    report "\`https://github.com/$MARKETPLACE_REPO\` is UNREACHABLE from this container, so
every \`@$MARKETPLACE_NAME\` plugin is absent — the plan cycle, its gates and
every \`plan-*\` command included. Work without them and say so; do not
improvise a substitute for a gate.

Expected whenever the snapshot was rebuilt by a session that did not have
\`$MARKETPLACE_REPO\` attached: while the setup script runs, GitHub is reachable
only for the repositories attached to the session, so this private repo is
reachable only as a local checkout. The snapshot follows the repository, so a
rebuild from the marketplace repo's own session does not help here. To fix: edit
the Setup script (any edit forces a rebuild), then start the next session on
THIS repository with \`$MARKETPLACE_REPO\` added as a second repository
(claude.ai/code?repositories=<this owner/repo>,$MARKETPLACE_REPO). That
session's clone gets installed and seeded."
    return 1
  fi

  claude plugin marketplace add "$MARKETPLACE_REPO" >/dev/null 2>&1 && return 0
  report "\`$MARKETPLACE_REPO\` is reachable but would not register as a marketplace, so
every \`@$MARKETPLACE_NAME\` plugin is absent. Work without
them and say so; do not improvise a substitute for a gate."
  return 1
}

# Copy what `claude plugin install` produced into the seed. The seed mirrors
# ~/.claude/plugins (known_marketplaces.json, marketplaces/, cache/) and is read
# by every session whose process carries CLAUDE_CODE_PLUGIN_SEED_DIR. Built
# beside the target and swapped in, so a failed copy leaves the old seed intact.
seed_plugins() {
  local src="$HOME/.claude/plugins" new="$SEED_DIR.new" loc
  loc="$(jq -r --arg n "$MARKETPLACE_NAME" '.[$n].installLocation // empty' \
    "$src/known_marketplaces.json" 2>/dev/null)"
  rm -rf "$new"
  if [ -z "$loc" ] || ! mkdir -p "$new/marketplaces" "$new/cache" \
     || ! cp -a "$loc" "$new/marketplaces/$MARKETPLACE_NAME" \
     || ! cp -a "$src/cache/$MARKETPLACE_NAME" "$new/cache/" \
     || ! jq -n --arg n "$MARKETPLACE_NAME" --arg repo "$MARKETPLACE_REPO" \
            --arg loc "$SEED_DIR/marketplaces/$MARKETPLACE_NAME" \
            '{($n): {source: {source: "github", repo: $repo}, installLocation: $loc,
                     lastUpdated: (now | todate)}}' > "$new/known_marketplaces.json"; then
    rm -rf "$new"
    log "WARNING: seed not built at $SEED_DIR"
    return 1
  fi
  rm -rf "$SEED_DIR" && mv "$new" "$SEED_DIR" || return 1

  # The user-settings copy of the variable (the environment dialog carries the
  # other). Merged, not overwritten: `claude plugin install` writes this file.
  local us="$HOME/.claude/settings.json"
  mkdir -p "$(dirname "$us")"
  [ -s "$us" ] || printf '{}\n' > "$us"
  jq --arg d "$SEED_DIR" '.env = ((.env // {}) + {CLAUDE_CODE_PLUGIN_SEED_DIR: $d})' \
    "$us" > "$us.new" && mv "$us.new" "$us"
  log "seeded $SEED_DIR"
}

install_plugins() {
  clear_report
  if ! command -v claude >/dev/null 2>&1; then
    report "The \`claude\` CLI was not on PATH while this environment was provisioned, so
nothing could be installed and every \`@$MARKETPLACE_NAME\` plugin is absent.
Work without them and say so; do not improvise a substitute for a gate."
    return 0
  fi

  register_marketplace || return 0

  # Every plugin the marketplace lists. What a project ENABLES is still its own
  # `enabledPlugins`; this only decides what is on disk for it to enable.
  local wanted
  wanted="$(jq -r --arg n "$MARKETPLACE_NAME" '.[$n].installLocation // empty' \
      "$HOME/.claude/plugins/known_marketplaces.json" 2>/dev/null \
    | xargs -r -I{} jq -r '.plugins[].name' {}/.claude-plugin/marketplace.json 2>/dev/null)"
  if [ -z "$wanted" ]; then
    report "\`$MARKETPLACE_REPO\` registered but its marketplace.json lists no plugins, so
every \`@$MARKETPLACE_NAME\` plugin is absent. Work without them and say so; do
not improvise a substitute for a gate."
    return 0
  fi

  # --scope user, never project: project scope writes enabledPlugins back into
  # the repo's tracked .claude/settings.json, so every session would open on a
  # modified file it did not touch.
  local p missing=""
  for p in $wanted; do
    claude plugin install "$p@$MARKETPLACE_NAME" --scope user -y >/dev/null 2>&1
    # Ask the registry, not the exit status: `install` prints `already
    # installed` and exits 0 having done nothing, so its status cannot tell an
    # install from a no-op — and an install that reported success while leaving
    # nothing loadable is the whole reason this script exists.
    if jq -e --arg p "$p@$MARKETPLACE_NAME" '(.plugins // {}) | has($p)' \
         "$HOME/.claude/plugins/installed_plugins.json" >/dev/null 2>&1; then
      log "installed $p@$MARKETPLACE_NAME"
    else
      log "WARNING: not installed: $p@$MARKETPLACE_NAME"
      missing="${missing} $p@$MARKETPLACE_NAME"
    fi
  done

  seed_plugins || report "The plugins installed but the seed at \`$SEED_DIR\` was not built, so a
session whose ~/.claude did not survive the snapshot has no \`@$MARKETPLACE_NAME\`
plugin. Check with \`type -a plan-lint\`; if absent, work without them and say so."

  [ -z "$missing" ] && return 0
  report "These plugins did NOT install:$missing

Their skills, hooks and commands are absent. Work without them and say so; do
not improvise a substitute for a gate."
}

# The archivist's transport to Notion. A fresh container has neither the binary
# nor the ~/.config/notion that `ntn login` writes — and login is interactive
# OAuth, so it cannot run here. Both halves come from the environment's
# Environment variables field instead:
#   NOTION_API_TOKEN=<integration token>  — takes precedence over the keychain.
#   NOTION_WORKSPACE_ID=<workspace uuid>  — locally this lives in
#     ~/.config/notion/config.json (`defaultWorkspaceIds`), which the container
#     has not got; without it ntn stops at `No workspace selected` even when
#     the token is perfectly good.
# ENVIRONMENT variables, not exports here: every later `ntn` call in the session
# needs them, and this script's exports do not outlive it.
install_ntn() {
  # npm, not the ntn.dev installer: that one lands the binary wherever
  # NTN_INSTALL_DIR says and needs that variable exported to be found again,
  # which this script cannot do. npm's global bin is already on PATH — the last
  # place notion-payload's own resolver looks.
  if ! npm install --global ntn >/dev/null 2>&1; then
    log "WARNING: ntn install failed — the archivist cannot reach Notion"
    return 0
  fi
  # Advisory, like every other step — a bad token must never cost the session.
  # Checked here rather than left to discovery because the first `ntn` call of a
  # cycle is usually the close-out archive: the most expensive moment to learn
  # the token was never set.
  if ntn whoami >/dev/null 2>&1; then
    log "ntn authenticated"
  else
    log "WARNING: ntn installed but NOT authenticated — set NOTION_API_TOKEN and"
    log "         NOTION_WORKSPACE_ID in the environment's Environment variables"
  fi
}

install_flutter && persist_env && bootstrap_projects
install_plugins
install_ntn

# Deliberately NOT here: `flutter gen-l10n`, `build_runner`, and any asset
# bundle build. Their output is gitignored, so the snapshot would restore
# whatever the LAST session's branch generated — stale against the branch the
# next session checks out. They belong in a per-session SessionStart hook.
log "done"
exit 0
