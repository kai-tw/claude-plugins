#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# Four repos, each with web/src/a.ts: nodep/ whose package.json lacks Stryker,
# noinst/ that declares it with nothing installed, and typo/ and loose/ with a
# fake Stryker installed that records being run.
set -euo pipefail
g() { git -c user.name=e -c user.email=e@e "$@"; }
for p in nodep noinst typo loose; do
  mkdir -p "$p/web/src" "$p/tools"
  printf 'export const a = 1;\n' > "$p/web/src/a.ts"
  printf 'console.log(1);\n' > "$p/tools/x.js"
  case $p in
    nodep) printf '{"devDependencies":{"jest":"^30.0.0"}}\n' > "$p/web/package.json" ;;
    *)     printf '{"devDependencies":{"@stryker-mutator/core":"^10.0.0"}}\n' > "$p/web/package.json" ;;
  esac
  case $p in
    typo|loose)
      mkdir -p "$p/web/node_modules/.bin" "$p/web/node_modules/@stryker-mutator/core"
      printf '{"version":"10.0.0"}\n' > "$p/web/node_modules/@stryker-mutator/core/package.json"
      printf '#!/usr/bin/env bash\ntouch ../stryker-ran\n' > "$p/web/node_modules/.bin/stryker"
      chmod +x "$p/web/node_modules/.bin/stryker" ;;
  esac
  (cd "$p" && git init -q && g add -A && g commit -qm init)
done
