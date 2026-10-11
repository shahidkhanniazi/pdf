#!/usr/bin/env bash
# Installs the APK on the emulator, taps through onboarding, and fails if the
# app crashes. Prints the crash log so it shows in the Actions output.
set -u
APK="$1"
PKG=com.somethinghistoric.app
mkdir -p smoke
adb install -r "$APK"
adb logcat -c
adb shell am start -W -n "$PKG/.MainActivity"
sleep 15
adb exec-out screencap -p > smoke/1-start.png

SIZE=$(adb shell wm size | grep -o '[0-9]*x[0-9]*' | tail -1)
W=${SIZE%x*}; H=${SIZE#*x}
# "Next" / "Get started" button, bottom end of the onboarding screen.
for i in 1 2 3 4; do
  adb shell input tap $((W * 85 / 100)) $((H * 91 / 100))
  sleep 2
done
sleep 25
adb exec-out screencap -p > smoke/2-after-onboarding.png
adb shell input swipe $((W / 2)) $((H * 3 / 4)) $((W / 2)) $((H / 4)) 400
sleep 5
adb exec-out screencap -p > smoke/3-scrolled.png

adb logcat -d > smoke/logcat.txt
echo "===== Crash / Flutter log lines ====="
grep -E "FATAL EXCEPTION|AndroidRuntime|E/flutter|I/flutter|Exception|Error" smoke/logcat.txt | grep -v -E "GoogleApiManager|chromium|FirebaseInstanceId" | head -200
echo "===== end ====="

if adb shell pidof "$PKG" > /dev/null; then
  echo "App is still running: OK"
else
  echo "App is NOT running: it crashed or closed"
  grep -A 40 "FATAL EXCEPTION" smoke/logcat.txt | head -120
  exit 1
fi
if grep -q "FATAL EXCEPTION" smoke/logcat.txt; then
  grep -A 40 "FATAL EXCEPTION" smoke/logcat.txt | head -120
  exit 1
fi
