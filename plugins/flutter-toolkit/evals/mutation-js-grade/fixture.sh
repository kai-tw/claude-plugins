#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# A repo with no pubspec and a JS package in web/. `feat` changes three source
# files under web/src/, plus files the diff must not take: a .d.ts, a test, a
# build script outside src/, and a script in no package. The fake stryker records
# its arguments and writes a canned report: good.ts 4 Killed + 1 Timeout,
# weak.ts 1 Killed + 3 Survived + 1 NoCoverage + 1 CompileError, empty.ts absent.
set -euo pipefail
g() { git -c user.name=e -c user.email=e@e "$@"; }
git init -q -b main
mkdir -p web/src web/scripts web/node_modules/.bin web/node_modules/@stryker-mutator/core
printf '{"devDependencies":{"@stryker-mutator/core":"^10.0.0"}}\n' > web/package.json
printf '{"name":"@stryker-mutator/core","version":"10.0.0"}\n' > web/node_modules/@stryker-mutator/core/package.json
cat > web/node_modules/.bin/stryker <<'FAKE'
#!/usr/bin/env bash
echo "$*" > ../stryker-args.txt
mkdir -p reports/mutation
m() { printf '{"id":"%s","mutatorName":"%s","replacement":"x","status":"%s","location":{"start":{"line":%s,"column":1},"end":{"line":%s,"column":2}}}' "$1" "$2" "$3" "$4" "$4"; }
cat > reports/mutation/mutation.json <<JSON
{"schemaVersion":"2","thresholds":{"high":80,"low":60},"files":{
 "src/good.ts":{"language":"typescript","source":"","mutants":[$(m 1 BlockStatement Killed 1),$(m 2 EqualityOperator Killed 2),$(m 3 BooleanLiteral Killed 3),$(m 4 ConditionalExpression Killed 4),$(m 5 BlockStatement Timeout 5)]},
 "src/weak.ts":{"language":"typescript","source":"","mutants":[$(m 6 BlockStatement Killed 1),$(m 7 EqualityOperator Survived 2),$(m 8 EqualityOperator Survived 3),$(m 9 StringLiteral Survived 4),$(m 10 ConditionalExpression NoCoverage 5),$(m 11 ArithmeticOperator CompileError 6)]}}}
JSON
FAKE
chmod +x web/node_modules/.bin/stryker
printf 'node_modules/\n' > web/.gitignore
printf 'stryker-args.txt\n' >> .git/info/exclude
touch web/src/.keep
g add -A && g commit -qm base
git checkout -q -b feat
for f in good weak empty; do printf 'export const %s = 1;\n' "$f" > "web/src/$f.ts"; done
printf 'export type T = number;\n' > web/src/types.d.ts
printf 'test("x", () => {});\n' > web/src/good.test.ts
printf 'console.log(1);\n' > web/scripts/build.js
printf 'console.log(1);\n' > loose.js
g add -A && g commit -qm change
