#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# A Flutter project. fake/adb knows three serials: `locked` (keyguard showing),
# `asleep` (screen off) and `awake` (unlocked); any other serial is not an adb
# device. fake/flutter stands in for the test runner.
set -euo pipefail
printf 'name: app\ndependencies:\n  flutter:\n    sdk: flutter\n' > pubspec.yaml
mkdir -p fake
cat > fake/adb <<'ADB'
#!/usr/bin/env bash
[ "$1" = -s ] || exit 1
dev=$2; shift 2
case "$dev" in locked|asleep|awake) ;; *) echo "error: device '$dev' not found" >&2; exit 1 ;; esac
case "$*" in
  get-state) echo device ;;
  "shell dumpsys window")
    k=false; [ "$dev" = locked ] && k=true
    printf '    mDreamingLockscreen=false mShowingDream=false isKeyguardShowing=%s\r\n' "$k" ;;
  "shell dumpsys power")
    w=Awake; [ "$dev" = asleep ] && w=Asleep
    printf '  mWakefulness=%s\r\n' "$w" ;;
esac
ADB
printf '#!/usr/bin/env bash\necho "flutter ran: $*"\n' > fake/flutter
chmod +x fake/adb fake/flutter
