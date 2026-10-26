#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# A task worktree with a local remote, a fake gh (as in pr-ready-gates), a fake
# flutter whose phones come from ./devices.json, a brief numbering S1 F1 B1, and
# tests for S1 (wired) and F1 (still `until wired`) — B1 has none.
set -euo pipefail
git init -q --bare origin.git
git clone -q origin.git wt 2>/dev/null
cd wt
git config user.email e@e; git config user.name e
mkdir -p .claude integration_test lib
printf 'vcs: git\ncoverage: ci\ndevice_test: echo "ran {device}" >> ../ran.log\ndevices: android ios\nfeatures: integration_test/FEATURES.md\n' > .claude/assistant.md
printf '.claude/.assistant/\n' > .gitignore
echo 'void main() {}' > lib/main.dart
git add -A; git commit -qm base; git push -q origin HEAD:main 2>/dev/null
git remote set-head origin main 2>/dev/null || git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
git switch -qc task/x
cat > integration_test/export_test.dart <<'DART'
void main() {
  testWidgets('[S1] exporting a book saves it', (t) async {});
  testWidgets('[F1] export fails offline', (t) async {
  }, skip: 'until wired');
}
DART
printf -- '- Export a book · integration_test/export_test.dart\n- Share a quote · none — the share sheet is native\n' > integration_test/FEATURES.md
git add -A; git commit -qm 'tests: export'
cd ..
cat > brief.md <<'MD'
# Export — Decision brief
## Scenarios
- S1 Export a book → the file is saved
- F1 Export while offline → a message, nothing saved
- B1 Export an empty book → an empty file
MD
echo main > base; echo 'What shipped.' > body
mkdir -p stub
cat > stub/flutter <<'FL'
#!/usr/bin/env bash
[ "$1 $2" = "devices --machine" ] && { cat "$EVAL_WS/devices.json"; exit 0; }
exit 1
FL
cat > stub/gh <<'GH'
#!/usr/bin/env bash
state="$EVAL_WS/gh.state"
case "$1 $2" in
  "auth status"|"repo view") exit 0 ;;
  "pr view")
    [ -f "$state" ] || exit 1
    read -r kind num < "$state"
    case "$*" in
      *isDraft*) echo "$num $([ "$kind" = draft ] && echo true || echo false) $(cat "$EVAL_WS/base")" ;;
      *body*) cat "$EVAL_WS/body" ;;
      *) echo "https://github.com/o/r/pull/$num" ;;
    esac ;;
  "pr create") echo "draft 7" > "$state"; echo "https://github.com/o/r/pull/7" ;;
  "pr ready")  echo "ready 7" > "$state" ;;
  "pr comment") exit 0 ;;
  *) exit 1 ;;
esac
GH
chmod +x stub/flutter stub/gh
# An Android phone, and an iPhone simulator that must not count as a phone.
echo '[{"name":"Pixel 7","id":"PX7","targetPlatform":"android-arm64","emulator":false},{"name":"iPhone 16 Sim","id":"SIM1","targetPlatform":"ios","emulator":true}]' > devices.json
# What wiring the tests looks like: F1's marker removed, and a test for B1.
mkdir -p wired
sed "s/, skip: 'until wired'//" wt/integration_test/export_test.dart > wired/export_test.dart
printf "void main() {\n  testWidgets('[B1] an empty book exports an empty file', (t) async {});\n}\n" > wired/empty_test.dart
# Both phones connected.
echo '[{"name":"Pixel 7","id":"PX7","targetPlatform":"android-arm64","emulator":false},{"name":"Kai iPhone","id":"IP15","targetPlatform":"ios","emulator":false}]' > devices-both.json
