#!/bin/sh
# Runs an XCUITest scheme of clients/kmp/iosApp on the iOS simulator: one
# `xcodebuild build-for-testing`, then `test-without-building` on the same
# products, with parallel testing.
#
# Usage: ios-ui-test.sh ui           the iosApp scheme's default test plan
#                                    (make ios-ui-test); skipped when nothing
#                                    it depends on changed since the last pass
#        ios-ui-test.sh acceptance   the iosAppAcceptance scheme (acceptance/ios,
#                                    make acceptance-ios); always runs, result
#                                    bundle in test-results/acceptance/ios.xcresult
#
# Environment: FORCE=1 runs `ui` even when unchanged. IOS_TEST_DEVICE names the
# simulator (default "iPhone 17"). IOS_TEST_WORKERS is the parallel-testing
# worker count (default 2; XCTest parallelises by test class). Every test
# runner gets UITestDisableAnimations=YES (xcodebuild hands TEST_RUNNER_<name>
# to the runner as <name>); a test forwards it to the app it launches.
#
# Output follows scripts/quiet.sh: "ok: <label>" or the failure.
set -eu
cd "$(dirname "$0")/.."
root=$(pwd -P)

mode=${1:-}
case $mode in
  ui) scheme=iosApp label=ios-ui-test ;;
  acceptance) scheme=iosAppAcceptance label=acceptance-ios ;;
  *) echo "usage: $0 ui|acceptance" >&2; exit 2 ;;
esac

device=${IOS_TEST_DEVICE:-iPhone 17}
workers=${IOS_TEST_WORKERS:-2}
kmp=$root/clients/kmp
derived=$kmp/build/DerivedDataUITests
log=$kmp/build/$label.log
Q="sh $root/scripts/quiet.sh"

# The unchanged-skip key: the tree of everything the `ui` run depends on
# (tracked, staged, unstaged and untracked-but-not-ignored files), hashed
# through a scratch index so the real one is never touched, plus the Xcode
# version and the run's parameters. Written only after a passing run.
state=$root/.cache/ios-ui-test
inputs="clients/kmp/iosApp clients/kmp/sharedLogic acceptance/ios clients/kmp/build-logic
  clients/kmp/gradle clients/kmp/build.gradle.kts clients/kmp/settings.gradle.kts
  clients/kmp/gradle.properties scripts/ios-ui-test.sh"
key=""
if [ "$mode" = ui ]; then
  existing=""
  for p in $inputs; do
    [ -e "$p" ] && existing="$existing $p"
  done
  tmpdir=$(mktemp -d)
  # $existing is split into its paths on purpose.
  tree=$(GIT_INDEX_FILE="$tmpdir/index" git add -A -- $existing >/dev/null 2>&1 \
    && GIT_INDEX_FILE="$tmpdir/index" git write-tree)
  rm -rf "$tmpdir"
  key=$(printf '%s\n' "$tree" "$(xcodebuild -version)" "$device" "$workers" | shasum -a 256 | cut -d' ' -f1)
  if [ "${FORCE:-0}" != 1 ] && [ -f "$state/passed" ] && [ "$(cat "$state/passed")" = "$key" ]; then
    echo "ok: $label (skipped: unchanged)"
    exit 0
  fi
fi

mkdir -p "$kmp/build"
destination="platform=iOS Simulator,name=$device"

$Q "$label:build" sh -c 'cd "$1" && xcodebuild build-for-testing -project iosApp/iosApp.xcodeproj \
  -scheme "$2" -destination "$3" -derivedDataPath "$4" CODE_SIGNING_ALLOWED=NO >"$5" 2>&1 \
  || { tail -n 80 "$5"; exit 1; }' sh "$kmp" "$scheme" "$destination" "$derived" "$log"

result_args=""
if [ "$mode" = acceptance ]; then
  mkdir -p "$root/test-results/acceptance"
  rm -rf "$root/test-results/acceptance/ios.xcresult"
  result_args="-resultBundlePath $root/test-results/acceptance/ios.xcresult"
fi

# $result_args is empty or two words, split on purpose.
TEST_RUNNER_UITestDisableAnimations=YES $Q "$label:test" sh -c 'cd "$1" && shift && xcodebuild test-without-building \
  -project iosApp/iosApp.xcodeproj "$@" >"$0" 2>&1 \
  || { grep -E "error:|failed|Failing tests:|^	|TEST EXECUTE" "$0" | tail -n 80; exit 1; }' \
  "$log" "$kmp" -scheme "$scheme" -destination "$destination" -derivedDataPath "$derived" \
  -parallel-testing-enabled YES -parallel-testing-worker-count "$workers" $result_args

if [ "$mode" = ui ]; then
  mkdir -p "$state"
  printf '%s\n' "$key" >"$state/passed"
fi
