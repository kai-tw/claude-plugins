# Testing Forensics

Background notes for investigating `flutter test` memory or
timing regressions. Not day-to-day rules — consult only when
the `/qa` skill §Running the suite flags a regression sign and
you need to measure for real.

## Accurate peak RSS measurement

`ps -axo rss` sums across processes and double-counts shared
memory; it also picks up unrelated Dart processes (e.g. Android
Studio's Dart language-server, ~250 MB resident). Past "9+ GB"
reports in this repo were this artifact, not real RSS.

Use the **pgid sampler** for the full process tree:

```bash
flutter test &
FT_PID=$!
sleep 2
PGID=$(ps -o pgid= -p $FT_PID | tr -d ' ')
max=0
while kill -0 $FT_PID 2>/dev/null; do
  current=$(ps -axo pgid,rss | awk -v p=$PGID '$1 == p {sum += $2} END {print sum+0}')
  mb=$((current / 1024))
  [ "$mb" -gt "$max" ] && max=$mb
  sleep 2
done
echo "peak=${max}MB"
wait $FT_PID
```

`/usr/bin/time -l` is a quick parent-process-only sanity check
but does **not** include `frontend_server` / `flutter_tester`
subprocess RSS. Use the pgid sampler for real verification.

## Known non-issues (do not chase)

- **Flutter SDK cold-start (~1 GB shared libraries + Dart VM)**
  is tooling cost, not app-side. Baseline RSS ≈ 1 GB at test
  start is normal.
- **`pub deps` running 3× per invocation**
  ([flutter/flutter#168268](https://github.com/flutter/flutter/issues/168268))
  adds a few seconds of cold-start. Not a memory issue.
