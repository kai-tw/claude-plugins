#!/usr/bin/env bash
set -eu
git init -q -b main
mkdir -p lib coverage bsd-bin
printf 'int example = 1;\n' > lib/example.dart
cat > bsd-bin/stat <<'SH'
#!/usr/bin/env bash
if [ "$1" = "-f" ] && [ "$2" = "%m" ]; then
  python3 -c 'import os,sys; print(int(os.stat(sys.argv[1]).st_mtime))' "$3"
  exit $?
fi
exit 1
SH
chmod +x bsd-bin/stat
cat > run_cases.sh <<'SH'
#!/usr/bin/env bash
set -u
original_path="$PATH"
export TEST_QUEUE_DIR="$PWD/s" TEST_QUEUE_WAIT=0 PLAN_QA_REPORT_DIR="$PWD/report"
mkdir -p "$PLAN_QA_REPORT_DIR"
for mode in native bsd; do
  for kind in stale fresh; do
    printf 'SF:lib/example.dart\nDA:1,1\nend_of_record\n' > coverage/lcov.info
    touch -t 200001010000 coverage/lcov.info
    if [ "$kind" = stale ]; then cmd=true; else cmd=./write_lcov.sh; fi
    if [ "$mode" = bsd ]; then export PATH="$PWD/bsd-bin:$original_path"; else export PATH="$original_path"; fi
    result=$(plan-coverage --files lib/example.dart -- "$cmd" 2>&1); rc=$?
    printf '%s-%s rc=%s\n' "$mode" "$kind" "$rc"
    if [[ "$result" == *'integer expression expected'* ]]; then echo "$mode-$kind invalid-integer"; fi
  done
done
SH
cat > write_lcov.sh <<'SH'
#!/usr/bin/env bash
printf 'SF:lib/example.dart\nDA:1,1\nend_of_record\n' > coverage/lcov.info
SH
chmod +x write_lcov.sh
