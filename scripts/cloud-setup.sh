#!/bin/bash
# Cloud-environment setup for a Claude Code session — project-agnostic.
#
# Paste into the environment's "Setup script" field (claude.ai → Settings →
# Claude Code → the environment). It provisions the two things a fresh container
# lacks: the Flutter toolchain, and the Claude plugins the project declares.
# One file rather than two, because that field takes exactly one script and a
# two-paste instruction is how half of it silently never gets pasted.
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

# Install the plugins the cloned projects declare, so the plan cycle is actually
# there. A container starts with NO marketplace configured: the registration
# lives in ~/.claude/settings.json → extraKnownMarketplaces, which is user scope
# and per-container, not in any repo. So a project's `enabledPlugins` resolves to
# nothing until the marketplace is added back — and the failure is silent, the
# skills simply are not offered. Both the registration and the plugin cache sit
# under $HOME, so this snapshots like everything else.
MARKETPLACE_NAME="kai-tw"
MARKETPLACE_REPO="kai-tw/claude-plugins"

install_plugins() {
  command -v claude >/dev/null 2>&1 || { log "claude CLI absent — skipping plugins"; return 0; }

  # Take the list from what each project ENABLES rather than hardcoding one:
  # a hardcoded list is a second copy of the project's own declaration, and the
  # copy is what goes stale.
  local wanted
  wanted="$(find "$WORKSPACE" -maxdepth 3 -path '*/.claude/settings.json' -print0 2>/dev/null \
    | xargs -0 -r jq -r '(.enabledPlugins // {}) | keys[]' 2>/dev/null \
    | grep -- "@${MARKETPLACE_NAME}\$" | sort -u)"
  if [ -z "$wanted" ]; then
    log "no @${MARKETPLACE_NAME} plugins declared by any cloned project"
    return 0
  fi

  claude plugin marketplace add "$MARKETPLACE_REPO" >/dev/null 2>&1 \
    || { log "WARNING: could not register the ${MARKETPLACE_NAME} marketplace"; return 0; }

  # --scope user, never project: project scope writes enabledPlugins back into
  # the repo's tracked .claude/settings.json, so every session would open on a
  # modified file it did not touch.
  local p
  for p in $wanted; do
    if claude plugin install "$p" --scope user -y >/dev/null 2>&1; then
      log "installed $p"
    else
      log "WARNING: install failed: $p"
    fi
  done
}

install_flutter && persist_env && bootstrap_projects
install_plugins

# Deliberately NOT here: `flutter gen-l10n`, `build_runner`, and any asset
# bundle build. Their output is gitignored, so the snapshot would restore
# whatever the LAST session's branch generated — stale against the branch the
# next session checks out. They belong in a per-session SessionStart hook.
log "done"
exit 0
