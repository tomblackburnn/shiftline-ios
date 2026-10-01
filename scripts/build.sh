#!/bin/zsh
# Builds or tests Shiftline on the simulator, printing only errors and failures.
# Usage: scripts/build.sh [build|test] [simulator name] [extra xcodebuild args...]
ACTION=${1:-build}
DEVICE=${2:-iPhone 17 Pro}
shift 2 2>/dev/null
cd "$(dirname "$0")/.."
LOG=$(mktemp)
xcodebuild -project Shiftline.xcodeproj -scheme Shiftline \
    -destination "platform=iOS Simulator,name=$DEVICE,OS=latest" \
    $ACTION -quiet "$@" > "$LOG" 2>&1
STATUS=$?
grep -E "error:|warning: .*/Shiftline|Test Case .*failed|✘|\*\* .* FAILED|Executed|passed after|failed after" "$LOG" | grep -v "^\s*$" | head -80
rm -f "$LOG"
exit $STATUS
