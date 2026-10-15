#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# runners/ holds two registered runners, as config.sh leaves them: one for
# o/app, whose run.sh starts a fake Runner.Listener that logs it ran and
# waits, and one for o/other. app/ and stray/ are clones of o/app and o/stray.
# fake/gh answers `run list` with the count in pending.txt, one less on
# every call, so the repo looks busy for a few polls and then idle.
set -euo pipefail
for r in app other; do
  mkdir -p "runners/$r/bin"
  printf '{"gitHubUrl":"https://github.com/o/%s","agentName":"mac-%s"}' "$r" "$r" > "runners/$r/.runner"
  cat > "runners/$r/bin/Runner.Listener" <<'L'
#!/usr/bin/env bash
echo "listener up" >> "$EVAL_WS/listener.log"
trap 'echo "listener down" >> "$EVAL_WS/listener.log"; exit 0' INT TERM
while :; do sleep 1; done
L
  printf '#!/usr/bin/env bash\nexec "$(dirname "$0")/bin/Runner.Listener"\n' > "runners/$r/run.sh"
  chmod +x "runners/$r/run.sh" "runners/$r/bin/Runner.Listener"
done
for c in app stray; do
  mkdir -p "$c" && (cd "$c" && git init -q && git remote add origin "https://github.com/o/$c.git")
done
mkdir -p fake
cat > fake/gh <<'G'
#!/usr/bin/env bash
case "$1 $2" in
  "run list")
    n=$(cat "$EVAL_WS/pending.txt"); echo "$n"
    [ "$n" -gt 0 ] && echo $((n - 1)) > "$EVAL_WS/pending.txt"; exit 0 ;;
esac
exit 1
G
chmod +x fake/gh
echo 4 > pending.txt
