#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# tools/ holds only what the launchers need besides node, so PATH has no node —
# the shell of a session whose nvm default points at a deleted version. A fake
# node sits where nvm installs one.
set -euo pipefail
mkdir -p tools home/.nvm/versions/node/v9.9.9/bin
for t in bash dirname basename ls sort cat; do ln -s "$(command -v "$t")" "tools/$t"; done
printf '#!/bin/sh\necho "fake-node $*"\n' > home/.nvm/versions/node/v9.9.9/bin/node
chmod +x home/.nvm/versions/node/v9.9.9/bin/node
