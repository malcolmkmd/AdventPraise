#!/bin/zsh
set -u
OUT=$HOME/Development/AdventPraise-build/store-shots-raw; mkdir -p $OUT
ADB="$HOME/Library/Android/sdk/platform-tools/adb -s emulator-5570"
PKG=com.mDev.AdventPraise
A() { ${=ADB} "$@" }
A shell settings put global sysui_demo_allowed 1
A shell am broadcast -a com.android.systemui.demo -e command enter >/dev/null
A shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0941 >/dev/null
A shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false >/dev/null
A shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4 >/dev/null
A shell am broadcast -a com.android.systemui.demo -e command network -e mobile show -e datatype none -e level 4 >/dev/null
A shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false >/dev/null
A shell settings put secure immersive_mode_confirmations confirmed
A shell pm grant $PKG android.permission.POST_NOTIFICATIONS 2>/dev/null
COMMON=(--es whatsNew.lastSeenVersion 7.0 --es tourSeen YES --es uiDebugNoSplash YES)
shot() {
  local name=$1; shift
  [[ -n ${ONLY:-} && " $ONLY " != *" $name "* ]] && return 0
  A shell am force-stop $PKG
  A shell am start -W -n $PKG/.MainActivity $COMMON "$@" >/dev/null
  sleep ${WAIT:-7}
  A exec-out screencap -p > $OUT/$name.png && echo "$name ok"
}
mode() { [[ $1 == dark ]] && A shell cmd uimode night yes >/dev/null || A shell cmd uimode night no >/dev/null; sleep 1 }
mode light
shot reader --ei uiDebugHymn 1 --es reader.hymnal english
shot reader-sdah --ei uiDebugHymn 100 --es reader.hymnal sdah
shot picker --ei uiDebugHymn 1 --es reader.hymnal english --es uiDebugMenu translation
WAIT=10 shot sheet --es uiDebugPro YES --ei uiDebugHymn 1 --es reader.hymnal english --es uiDebugSheet sheetMusic --es sheetMusic.viewMode page
WAIT=10 shot sheet-system --es uiDebugPro YES --ei uiDebugHymn 1 --es reader.hymnal english --es uiDebugSheet sheetMusic --es sheetMusic.viewMode system
shot numpad --ei uiDebugHymn 1 --es reader.hymnal english --es uiDebugDigits 100
shot search --ei uiDebugHymn 1 --es reader.hymnal english --es uiDebugLectern search
shot library --ei uiDebugHymn 1 --es reader.hymnal english --es uiDebugLectern library
WAIT=10 shot paywall --ei uiDebugHymn 1 --es reader.hymnal english --es uiDebugPaywall YES --es uiDebugFree YES
shot theme --ei uiDebugHymn 1 --es reader.hymnal english --es uiDebugMenu theme
shot player --es uiDebugPro YES --ei uiDebugHymn 1 --es reader.hymnal english --es uiDebugPlay YES
mode dark
shot church --es uiDebugPro YES --ei uiDebugHymn 1 --es reader.hymnal english --es uiDebugChurch YES --es uiDebugChurchControls YES
shot church-display --es uiDebugPro YES --ei uiDebugHymn 1 --es reader.hymnal english --es uiDebugChurch YES --es uiDebugExternal verse
shot reader-dark --ei uiDebugHymn 1 --es reader.hymnal shona
mode light
