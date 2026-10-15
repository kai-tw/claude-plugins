#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# One repo with web/src/a.ts and a fake Stryker that records its arguments,
# so the eval sees where the run keeps what it finished.
set -euo pipefail
g() { git -c user.name=e -c user.email=e@e "$@"; }
mkdir -p r/web/src r/web/node_modules/.bin r/web/node_modules/@stryker-mutator/core
cd r
printf '{"devDependencies":{"@stryker-mutator/core":"^10.0.0"}}\n' > web/package.json
printf '{"version":"10.0.0"}\n' > web/node_modules/@stryker-mutator/core/package.json
printf '#!/usr/bin/env bash\necho "stryker $*" > ../stryker-args\n' > web/node_modules/.bin/stryker
chmod +x web/node_modules/.bin/stryker
printf 'node_modules/\n' > .gitignore
printf 'export const a = 1;\n' > web/src/a.ts
git init -q -b main && g add -A && g commit -qm one
