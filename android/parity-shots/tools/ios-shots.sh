#!/bin/zsh
# The iOS side: a private simulator (UDID in $IOS_UDID or the scratchpad's ios-sim.txt) and a
# DEBUG build of Advent Praise.app ($IOS_APP). Same states as android-shots.sh, iOS launch arguments.
#   ONLY="numpad about" ./ios-shots.sh
set -u
HERE=${0:A:h}; OUT=${OUT:-$HERE/../ios}; mkdir -p $OUT
UDID=${IOS_UDID:?set IOS_UDID}; APP=${IOS_APP:?set IOS_APP to the Debug-iphonesimulator Advent Praise.app}
BID=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Info.plist")
[[ ${SKIP_INSTALL:-0} == 1 ]] || xcrun simctl install $UDID "$APP"
xcrun simctl status_bar $UDID override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
COMMON=(-whatsNew.lastSeenVersion 7.0 -tourSeen YES -uiDebugNoSplash YES -uiDebugHymn 1 -reader.hymnal english -uiDebugControlsAppearance light)
want() { [[ -z ${ONLY:-} ]] && return 0; for o in ${=ONLY}; do [[ $1 == $o* ]] && return 0; done; return 1 }
launch() { name=$1; shift; want $name || return 0; xcrun simctl terminate $UDID $BID >/dev/null 2>&1; xcrun simctl launch $UDID $BID "$@" >/dev/null; sleep ${WAIT:-6}; xcrun simctl io $UDID screenshot $OUT/$name.png >/dev/null 2>&1 && echo "$name ok"; }
shot() { name=$1; shift; launch $name $COMMON "$@"; }
for mode in ${=${MODES:-light dark}}; do
  xcrun simctl ui $UDID appearance $mode
  shot list-$mode -uiDebugLectern library
  shot reader-$mode
  shot globe-bar-$mode -uiDebugMenu translation
  shot sheet-page-$mode -uiDebugPro YES -uiDebugSheet sheetMusic -sheetMusic.viewMode page
  shot sheet-system-$mode -uiDebugPro YES -uiDebugSheet sheetMusic -sheetMusic.viewMode system
  WAIT=9 shot paywall-$mode -uiDebugPaywall YES -uiDebugFree YES
  shot more-$mode -uiDebugMore YES -uiDebugFree YES
  shot church-$mode -uiDebugPro YES -uiDebugChurch YES -uiDebugChurchControls YES
  shot numpad-$mode -uiDebugDigits 100
  shot about-hymn-$mode -uiDebugSheet about
  shot memorise-$mode -uiDebugSheet memory -uiDebugPro YES
  shot collections-$mode -uiDebugSheet collections
  shot support-$mode -uiDebugSheet support
  shot terms-$mode -uiDebugSheet terms
  shot pitch-$mode -uiDebugSheet pitch -uiDebugPro YES
  shot hymn-tray-$mode -uiDebugLectern hymn
  shot tour-1-$mode -uiDebugTour step-1
  launch whats-new-$mode -whatsNew.lastSeenVersion 6.0 -tourSeen YES -uiDebugNoSplash YES -uiDebugHymn 1 -reader.hymnal english
  WAIT=${SPLASH_WAIT:-14} launch splash-$mode -whatsNew.lastSeenVersion 7.0 -tourSeen YES -uiDebugHymn 1 -reader.hymnal english -uiDebugSplashSpeed 0.05
done
