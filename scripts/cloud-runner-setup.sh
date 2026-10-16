#!/bin/bash
# The runner half of the cloud environment that runs self-hosted Actions jobs.
# Run by scripts/cloud-runner-setup-field.sh after scripts/cloud-setup.sh, in
# that one environment only.
#
# It unpacks the GitHub Actions runner into /opt/actions-runner, unconfigured.
# Each repo's routine runs scripts/cloud-ci-runner.sh, downloaded from main at
# run time, so that script isn't part of the snapshot. Registration is NOT
# here: this filesystem is snapshotted and shared by every container, and one
# registered runner identity can't be online in two containers.
# cloud-ci-runner registers a just-in-time runner per job instead.
#
# Advisory like cloud-setup.sh: a failure is reported into ~/.claude/CLAUDE.md
# and the script still exits 0, so the session starts and says what's missing.
set -uo pipefail

# Pinned, like Flutter: a runner too old for GitHub is refused at registration,
# so bump this when GitHub deprecates it.
RUNNER_VERSION="2.338.0"
RUNNER_HOME=/opt/actions-runner

report() {
  mkdir -p ~/.claude
  printf '\n## This environment is INCOMPLETE\n\n%s\n' "$1" >> ~/.claude/CLAUDE.md
}

if [ "$(cat "$RUNNER_HOME/.version" 2>/dev/null)" = "$RUNNER_VERSION" ]; then
  echo "runner-setup: actions runner $RUNNER_VERSION already present"
else
  rm -rf "$RUNNER_HOME" && mkdir -p "$RUNNER_HOME"
  if curl -fsSL --retry 3 \
      "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" \
      | tar -xz -C "$RUNNER_HOME" && "$RUNNER_HOME/bin/installdependencies.sh" >/dev/null 2>&1; then
    echo "$RUNNER_VERSION" > "$RUNNER_HOME/.version"
    echo "runner-setup: actions runner $RUNNER_VERSION installed"
  else
    report "The GitHub Actions runner $RUNNER_VERSION would not install into $RUNNER_HOME, so \`cloud-ci-runner\` can't take any job. Say so; the PR checks stay queued."
  fi
fi
exit 0
