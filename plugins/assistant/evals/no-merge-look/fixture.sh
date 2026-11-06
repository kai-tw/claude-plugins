#!/usr/bin/env bash
# stub/gh answers `pr view` with an OPEN PR.
set -euo pipefail
mkdir -p stub
cat > stub/gh <<'SH'
#!/usr/bin/env bash
case "$1 $2" in
  "pr view") echo '{"state":"OPEN","mergeCommit":null,"headRefName":"task/x","url":"https://example.test/pr/7"}' ;;
  *) exit 1 ;;
esac
SH
chmod +x stub/gh
