#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# Two JS packages. web/ has stryker.config.json with mutate
# ["src/**", "!src/index.js"]; app/ has stryker.config.mjs with mutate
# ["lib/**/*.ts", "!lib/skip.ts"]. `feat` changes lines 3-4 and 8 of
# web/src/a.ts, adds the 3-line web/src/b.ts, changes web/src/index.js,
# only deletes a line of web/src/c.ts, and changes line 2 of app/lib/m.ts and
# app/lib/skip.ts. The fake stryker records "<package>: <args>" and reports five
# Killed mutants for each file its --mutate names.
set -euo pipefail
g() { git -c user.name=e -c user.email=e@e "$@"; }
git init -q -b main
for p in web app; do
  mkdir -p $p/node_modules/.bin $p/node_modules/@stryker-mutator/core
  printf '{"devDependencies":{"@stryker-mutator/core":"^10.0.0"}}\n' > $p/package.json
  printf '{"name":"@stryker-mutator/core","version":"10.0.0"}\n' > $p/node_modules/@stryker-mutator/core/package.json
  cat > $p/node_modules/.bin/stryker <<'FAKE'
#!/usr/bin/env bash
m=""; prev=""; for a in "$@"; do [ "$prev" = --mutate ] && m=$a; prev=$a; done
echo "$(basename "$PWD"): $*" >> ../stryker-args.txt
mkdir -p reports/mutation
files=$(printf '%s\n' "$m" | tr , '\n' | sed -E 's/:[0-9]+-[0-9]+$//' | sort -u \
  | awk '{ printf "%s\"%s\":{\"language\":\"typescript\",\"source\":\"\",\"mutants\":[", (NR > 1 ? "," : ""), $0
           for (i = 1; i <= 5; i++) printf "%s{\"id\":\"%d-%d\",\"mutatorName\":\"BlockStatement\",\"replacement\":\"x\",\"status\":\"Killed\",\"location\":{\"start\":{\"line\":%d,\"column\":1},\"end\":{\"line\":%d,\"column\":2}}}", (i > 1 ? "," : ""), NR, i, i, i
           printf "]}" }')
printf '{"schemaVersion":"2","thresholds":{"high":80,"low":60},"files":{%s}}\n' "$files" > reports/mutation/mutation.json
FAKE
  chmod +x $p/node_modules/.bin/stryker
  printf 'node_modules/\n' > $p/.gitignore
done
printf '{"mutate":["src/**","!src/index.js"]}\n' > web/stryker.config.json
printf 'export default { mutate: ["lib/**/*.ts", "!lib/skip.ts"] };\n' > app/stryker.config.mjs
printf 'stryker-args.txt\n' >> .git/info/exclude
mkdir -p web/src app/lib
seq 1 10 | awk '{ print "export const v" $0 " = 1;" }' > web/src/a.ts
printf 'export const c1 = 1;\nexport const c2 = 2;\n' > web/src/c.ts
printf 'module.exports = 1;\n' > web/src/index.js
for f in m skip; do printf 'export const x = 1;\nexport const y = 1;\n' > app/lib/$f.ts; done
g add -A && g commit -qm base
git checkout -q -b feat
awk 'NR == 3 || NR == 4 || NR == 8 { sub(/= 1/, "= 2") } { print }' web/src/a.ts > a.tmp && mv a.tmp web/src/a.ts
printf 'export const b1 = 1;\nexport const b2 = 2;\nexport const b3 = 3;\n' > web/src/b.ts
printf 'export const c1 = 1;\n' > web/src/c.ts
printf 'module.exports = 2;\n' > web/src/index.js
for f in m skip; do printf 'export const x = 1;\nexport const y = 2;\n' > app/lib/$f.ts; done
g add -A && g commit -qm change
