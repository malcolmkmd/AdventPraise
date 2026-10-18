#!/bin/zsh
# Captures the Android side of the parity shots on a running emulator (Pixel_8),
# the same states as the iOS script (ios-shots.sh), with the iOS launch argument names.
#   ./android-shots.sh            every shot, light and dark
#   ONLY="reader paywall" ./android-shots.sh   just those (prefix match)
set -u
HERE=${0:A:h}; OUT=${OUT:-$HERE/../android}; mkdir -p $OUT
ADB=${ADB:-$HOME/Library/Android/sdk/platform-tools/adb}   # with more than one device attached, export ANDROID_SERIAL
APK=${APK:-$HERE/../../app/build/outputs/apk/debug/app-debug.apk}
PKG=com.mDev.AdventPraise
[[ ${SKIP_INSTALL:-0} == 1 ]] || $ADB install -r $APK >/dev/null
# Status bar: 09:41, full battery, full signal, no notifications.
$ADB shell settings put global sysui_demo_allowed 1
$ADB shell am broadcast -a com.android.systemui.demo -e command enter >/dev/null
$ADB shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0941 >/dev/null
$ADB shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false >/dev/null
$ADB shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4 >/dev/null
$ADB shell am broadcast -a com.android.systemui.demo -e command network -e mobile show -e datatype none -e level 4 >/dev/null
$ADB shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false >/dev/null
# No system prompts over the shots: immersive mode's first-time notice, the notification permission.
$ADB shell settings put secure immersive_mode_confirmations confirmed
$ADB shell pm grant $PKG android.permission.POST_NOTIFICATIONS 2>/dev/null
# A loaded machine makes the launcher ANR; its dialog would sit over the shot.
$ADB shell settings put global hide_error_dialogs 1
COMMON=(--es whatsNew.lastSeenVersion 7.0 --es tourSeen YES --es uiDebugNoSplash YES --ei uiDebugHymn 1 --es reader.hymnal english)
want() { [[ -z ${ONLY:-} ]] && return 0; for o in ${=ONLY}; do [[ $1 == $o* ]] && return 0; done; return 1 }
shot() {
  local name=$1; shift
  want $name || return 0
  $ADB shell am force-stop $PKG
  $ADB shell am start -W -n $PKG/.MainActivity $COMMON "$@" >/dev/null
  # A launcher ANR's dialog would sit over the shot: restart the launcher instead.
  $ADB shell dumpsys window | grep -q "Application Not Responding" && $ADB shell am force-stop com.google.android.apps.nexuslauncher
  # Under load the window can take a while: wait (up to 30 s) until the app has focus.
  for i in {1..30}; do $ADB shell dumpsys window | grep -q "mCurrentFocus=.*$PKG" && break; sleep 1; done
  sleep ${WAIT:-6}
  $ADB exec-out screencap -p > $OUT/$name.png && sips -Z 1400 $OUT/$name.png >/dev/null && echo "$name ok"
}
for mode in ${=${MODES:-light dark}}; do
  [[ $mode == dark ]] && $ADB shell cmd uimode night yes >/dev/null || $ADB shell cmd uimode night no >/dev/null
  sleep 1
  shot list-$mode --es uiDebugLectern library
  shot reader-$mode
  shot globe-bar-$mode --es uiDebugMenu translation
  WAIT=9 shot sheet-page-$mode --es uiDebugPro YES --es uiDebugSheet sheetMusic --es sheetMusic.viewMode page
  WAIT=9 shot sheet-system-$mode --es uiDebugPro YES --es uiDebugSheet sheetMusic --es sheetMusic.viewMode system
  WAIT=9 shot paywall-$mode --es uiDebugPaywall YES --es uiDebugFree YES
  shot more-$mode --es uiDebugMore YES --es uiDebugFree YES
  shot church-$mode --es uiDebugPro YES --es uiDebugChurch YES --es uiDebugChurchControls YES
  # Extras
  shot numpad-$mode --es uiDebugDigits 100
  shot search-$mode --es uiDebugLectern search
  shot about-hymn-$mode --es uiDebugSheet about
  shot memorise-$mode --es uiDebugSheet memory --es uiDebugPro YES
  shot collections-$mode --es uiDebugSheet collections
  shot support-$mode --es uiDebugSheet support
  shot terms-$mode --es uiDebugSheet terms
  shot pitch-$mode --es uiDebugSheet pitch --es uiDebugPro YES
  shot hymn-tray-$mode --es uiDebugLectern hymn
  shot tour-1-$mode --es uiDebugTour step-1
  # What's New: an older version seen (the later extra wins over COMMON's 7.0).
  shot whats-new-$mode --es whatsNew.lastSeenVersion 6.0 --es tourSeen YES
  # The splash, slowed to a twentieth, caught part-way.
  WAIT=${SPLASH_WAIT:-14} shot splash-$mode --es uiDebugNoSplash NO --es uiDebugSplashSpeed 0.05
done
$ADB shell cmd uimode night no >/dev/null
