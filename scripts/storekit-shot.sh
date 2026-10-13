#!/bin/zsh
# The Pro paywall, opened by Play with the free plays used up, priced by
# StoreKit/AdventPraise.storekit, into build/shots/storekit/.
#
#   scripts/storekit-shot.sh "iPhone 17 Pro"
#
# The app can't load a .storekit file when launched with simctl, so the shot
# comes from the hosted unit test PurchaseStoreTests.paywallFromPlayForTheScreenshot,
# which opens a StoreKit test session, taps Play and holds the paywall up.
# This script runs that test and captures the simulator while it holds.
set -euo pipefail
cd "${0:A:h}/.."
device="${1:-iPhone 17 Pro}"
out=build/shots/storekit
mkdir -p "$out"
rm -f "$out/.paywall-ready"

(
  for _ in {1..600}; do
    if [[ -f "$out/.paywall-ready" ]]; then
      sleep 2
      xcrun simctl io booted screenshot "$out/paywall-from-play.png" >/dev/null
      exit 0
    fi
    sleep 0.5
  done
) &
watcher=$!

TEST_RUNNER_AP_SHOTS=1 xcodebuild test -project AdventPraise.xcodeproj -scheme AdventPraise \
  -destination "platform=iOS Simulator,name=$device" -derivedDataPath build/DD \
  -only-testing:AdventPraiseTests/PurchaseStoreTests/"paywallFromPlayForTheScreenshot()" \
  | grep -E "error:|warning:|Test (Suite|Case)|TEST (SUCCEEDED|FAILED)|✔|✘" || true
wait $watcher
ls -l "$out/paywall-from-play.png"
