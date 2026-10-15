#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# runners/ holds two registered runners, as config.sh leaves them: one for
# o/app and one for o/other. Like the real one, run.sh starts run-helper.sh,
# which starts bin/Runner.Listener by its physical path, so the listener is
# run.sh's grandchild; this fake one logs when it starts and stops, and
# waits. app/ and stray/ are clones of o/app and o/stray.
# fake/gh stands in for GitHub. The runner is never busy. Run 101 is in
# progress the whole time, on GitHub-hosted runners: none of its jobs ask for
# a self-hosted one. Run 102 is queued with as many self-hosted jobs waiting
# as selfq.txt says, one fewer each time its jobs are listed, so the runner
# has work for a few polls and then none.
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
  printf '#!/usr/bin/env bash\nDIR=$(cd -P "$(dirname "$0")" && pwd)\n"$DIR/run-helper.sh"\n' > "runners/$r/run.sh"
  printf '#!/usr/bin/env bash\nDIR=$(cd -P "$(dirname "$0")" && pwd)\n"$DIR/bin/Runner.Listener"\n' > "runners/$r/run-helper.sh"
  chmod +x "runners/$r/run.sh" "runners/$r/run-helper.sh" "runners/$r/bin/Runner.Listener"
done
for c in app stray; do
  mkdir -p "$c" && (cd "$c" && git init -q && git remote add origin "https://github.com/o/$c.git")
done
mkdir -p fake
cat > fake/gh <<'G'
#!/usr/bin/env bash
n=$(cat "$EVAL_WS/selfq.txt")
case "$*" in
  "api repos/o/app/actions/runners "*) echo false ;;
  "run list"*"--status queued"*) [ "$n" -gt 0 ] && echo 102 ;;
  "run list"*"--status in_progress"*) echo 101 ;;
  "api repos/o/app/actions/runs/101/jobs "*) echo 0 ;;
  "api repos/o/app/actions/runs/102/jobs "*)
    echo "$n"; [ "$n" -gt 0 ] && echo $((n - 1)) > "$EVAL_WS/selfq.txt" ;;
  *) exit 1 ;;
esac
exit 0
G
chmod +x fake/gh
echo 4 > selfq.txt
