#!/usr/bin/env bash
# Self-check of the exit status of the QA scripts (docs/qa.md). Needs no emulator, no Flutter and no network:
#
#   tool/qa/selftest.sh
#
# It copies tool/qa into a temporary tree, puts a fake adb / flutter / U02 script in it and runs the REAL
# run_android.sh and release_check.sh for every combination of "battery passes/fails" x "U02 passes/fails".
# The exit status must be 0 only when both pass. This is what regressed once: a failing battery followed by a
# U02 run ended with exit 0. Run it after touching anything in tool/qa/*.sh.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SB="$(mktemp -d)"
trap 'rm -rf "${SB:?}"' EXIT

mkdir -p "$SB/tool" "$SB/app/android" "$SB/build" "$SB/sdk/platform-tools" "$SB/sdk/emulator" "$SB/bin" "$SB/device"
cp -r "$HERE" "$SB/tool/qa"
rm -f "$SB/tool/qa/selftest.sh"

# The background screenshot and permission loops are unrelated to the
# status and ownership checks. Leave the real device selection and cleanup.
cat >>"$SB/tool/qa/common.sh" <<'EOF'
qa_grant_notifications_start() { :; }
qa_shots_start() { :; }
sleep() { :; }
EOF

# Fake SDK and lock. Record even read-only adb calls so a rejected target can
# never silently reach logcat, a screenshot, or a destructive command.
cat >"$SB/sdk/platform-tools/fixture.sh" <<'EOF'
qa_fixture_adb() {
  local -a args=("$@")
  printf '%s\n' "$*" >>"$QA_FIXTURE_STATE/adb"
  [ "${1:-}" = "-s" ] && args=("${@:3}")
  case "${args[0]:-}" in
    devices)
      printf 'List of devices attached\nfixture-phone\tdevice\n'
      [ -f "$QA_FIXTURE_STATE/online" ] && printf 'emulator-5580\tdevice\n'
      ;;
    emu)
      case "${args[1]}" in
        avd) echo "${FIXTURE_AVD:-Cuadrante_QA}" ;;
        kill) rm -f "$QA_FIXTURE_STATE/online" ;;
      esac
      ;;
    exec-out)
      case "${args[1]}" in
        cat) echo fixture ;;
        screencap) printf '\211PNG' ;;
      esac
      ;;
    install) echo Success ;;
    shell)
      case "${args[1]} ${args[2]:-}" in
        'getprop sys.boot_completed') echo 1 ;;
        'getprop ro.build.version.sdk') echo 36 ;;
        'getprop ro.product.model') echo fixture ;;
        'dumpsys package') printf 'versionName=fixture\nfirstInstallTime=first\n' ;;
        'test -e') return 1 ;;
      esac
      ;;
  esac
  return 0
}
EOF
cat >"$SB/sdk/platform-tools/adb" <<'EOF'
#!/usr/bin/env bash
source "${BASH_SOURCE[0]%/*}/fixture.sh"
qa_fixture_adb "$@"
EOF
cat "$SB/sdk/platform-tools/fixture.sh" >>"$SB/tool/qa/common.sh"
cat >>"$SB/tool/qa/common.sh" <<'EOF'
# Use the same fake SDK in-process for the many UI calls. Device selection
# and the lock still run through the real common.sh helpers.
qa_adb() { qa_fixture_adb -s "$QA_SERIAL" "$@"; }
EOF
cat >"$SB/sdk/emulator/emulator" <<'EOF'
#!/usr/bin/env bash
touch "$QA_FIXTURE_STATE/online"
while [ -f "$QA_FIXTURE_STATE/online" ]; do /usr/bin/sleep 0.1; done
EOF
cat >"$SB/bin/device-lock.sh" <<'EOF'
#!/bin/sh
printf '%s\n' "$1 $2" >>"$QA_FIXTURE_STATE/lock"
for owner; do :; done
case "$1" in
  who) [ ! -f "$QA_FIXTURE_STATE/owner" ] ;;
  take)
    if [ "${FIXTURE_LOCK_BUSY:-0}" = 1 ]; then
      rm -f "$QA_FIXTURE_STATE/online"
      exit 3
    fi
    printf '%s\n' "$owner" >"$QA_FIXTURE_STATE/owner"
    ;;
  mine) [ "$owner" = "$(cat "$QA_FIXTURE_STATE/owner" 2>/dev/null)" ] ;;
  release) rm -f "$QA_FIXTURE_STATE/owner" ;;
esac
EOF
# Fake flutter: prints the scenario lines of the real runner and exits with FAKE_BATTERY_RC
# (FAKE_FAIL_LINE=1: a FAIL line but exit 0; FAKE_NO_SCENARIOS=1: no lines at all).
cat >"$SB/bin/flutter" <<'EOF'
#!/usr/bin/env bash
[ "${FAKE_NO_SCENARIOS:-0}" = 1 ] && exit 0
echo "QA_START|Q01|Uno"
if [ "${FAKE_BATTERY_RC:-0}" != 0 ] || [ "${FAKE_FAIL_LINE:-0}" = 1 ]; then echo "QA_RESULT|Q01|FAIL|10|boom"; else echo "QA_RESULT|Q01|PASS|10|"; fi
exit "${FAKE_BATTERY_RC:-0}"
EOF
# Fake U02.
cat >"$SB/tool/qa/upgrade_android.sh" <<'EOF'
#!/usr/bin/env bash
exit "${FAKE_U02_RC:-0}"
EOF
# Fake release APK check.
cat >"$SB/tool/qa/release_apk_check.sh" <<'EOF'
#!/usr/bin/env bash
exit "${FAKE_APK_RC:-0}"
EOF
chmod +x "$SB/sdk/platform-tools/adb" "$SB/sdk/emulator/emulator" "$SB/bin/"* "$SB/tool/qa/"*.sh

fails=0
# check <expected-nonzero 0|1> <script> <battery rc> <u02 rc> [extra env...]
check() {
  local want="$1" script="$2" brc="$3" urc="$4"
  shift 4
  rm -f "$SB/device/"*
  env PATH="$SB/bin:$PATH" ANDROID_HOME="$SB/sdk" QA_DEVICE= QA_OUT="$SB/out" QA_FIXTURE_STATE="$SB/device" \
    QA_AVD=Cuadrante_QA QA_EMULATOR_PORT=5580 \
    FAKE_BATTERY_RC="$brc" FAKE_U02_RC="$urc" "$@" \
    timeout 90 bash ${SELFTEST_TRACE:+-x} "$SB/tool/qa/$script" >"$SB/last.log" 2>&1
  local rc=$?
  local ok=0
  if [ "$want" = 0 ] && [ "$rc" -eq 0 ]; then ok=1; fi
  if [ "$want" = 1 ] && [ "$rc" -ne 0 ]; then ok=1; fi
  if [ "$ok" = 1 ]; then
    echo "ok   $script battery=$brc u02=$urc $* -> exit $rc"
  else
    echo "FAIL $script battery=$brc u02=$urc $* -> exit $rc (wanted $([ "$want" = 0 ] && echo 0 || echo non-zero))"
    sed 's/^/     | /' "$SB/last.log" | tail -n "${SELFTEST_TAIL:-15}"
    fails=$((fails + 1))
  fi
}

# run_android.sh without U02: only the battery counts.
check 0 run_android.sh 0 0
check 1 run_android.sh 1 0
# With U02 (what release_check.sh does): any failure fails the run.
check 0 run_android.sh 0 0 QA_UPGRADE=1
check 1 run_android.sh 1 0 QA_UPGRADE=1
check 1 run_android.sh 0 1 QA_UPGRADE=1
check 1 run_android.sh 1 1 QA_UPGRADE=1
check 0 release_check.sh 0 0
check 1 release_check.sh 1 0
check 1 release_check.sh 0 1
check 1 release_check.sh 1 1
# flutter test exits 0 but a scenario reported FAIL (the report must still turn the run red).
check 1 release_check.sh 0 0 FAKE_FAIL_LINE=1
# flutter test exits 0 but no scenario ran (e.g. the app never started): not green.
check 1 release_check.sh 0 0 FAKE_NO_SCENARIOS=1
# The release APK check (a keep-listed resource missing) fails the release check.
check 1 release_check.sh 0 0 FAKE_APK_RC=1

# The REAL release_apk_check.sh against a fake aapt2: present -> ok, missing -> fail.
mkdir -p "$SB/real/tool/qa" "$SB/real/app/android/app/src/main/res/raw" "$SB/real/sdk/build-tools/1.0.0"
cp "$HERE/release_apk_check.sh" "$SB/real/tool/qa/"
cp "$HERE/../../app/android/app/src/main/res/raw/keep.xml" "$SB/real/app/android/app/src/main/res/raw/"
echo apk >"$SB/real/fake.apk"
cat >"$SB/real/sdk/build-tools/1.0.0/aapt2" <<'EOF'
#!/usr/bin/env bash
echo "    resource 0x7f080001 drawable/widget_bg"
[ "${FAKE_HAS_ICON:-1}" = 1 ] && echo "    resource 0x7f080002 drawable/ic_stat_alarm"
exit 0
EOF
chmod +x "$SB/real/sdk/build-tools/1.0.0/aapt2" "$SB/real/tool/qa/release_apk_check.sh"
apk_check() {
  local want="$1"; shift
  env ANDROID_HOME="$SB/real/sdk" "$@" "$SB/real/tool/qa/release_apk_check.sh" "$SB/real/fake.apk" >"$SB/last.log" 2>&1
  local rc=$?
  if { [ "$want" = 0 ] && [ "$rc" -eq 0 ]; } || { [ "$want" = 1 ] && [ "$rc" -ne 0 ]; }; then
    echo "ok   release_apk_check.sh $* -> exit $rc"
  else
    echo "FAIL release_apk_check.sh $* -> exit $rc"; sed 's/^/     | /' "$SB/last.log"; fails=$((fails + 1))
  fi
}
apk_check 0 FAKE_HAS_ICON=1
apk_check 1 FAKE_HAS_ICON=0

# Exercise the real U02 and common.sh. The UI stub returns a stable fake
# month and can stop specific steps in either picker or the restoration.
cp "$HERE/upgrade_android.sh" "$SB/tool/qa/"
mkdir -p "$SB/sdk/build-tools/1.0.0" "$SB/out"
cat >"$SB/sdk/build-tools/1.0.0/aapt2" <<'EOF'
#!/usr/bin/env bash
case "$(cat "$3")" in
  bad) echo "invalid APK" >&2; exit 1 ;;
  *) printf "package: name='%s' versionCode='1'\r\n" "$(cat "$3")" ;;
esac
EOF
cat >>"$SB/tool/qa/common.sh" <<'EOF'
dart() {
  if [[ "$1" != */ui.dart ]]; then
    command dart "$@"
    return
  fi
  case "$2" in
    backup-name)
      [ "${FIXTURE_BLOCK:-}" = backup-name ] && return 1
      echo turnly-2026-11-24.turnly
      ;;
    week) echo '1 2 3 4' ;;
    paintable-day) echo '1 2|día 8' ;;
    scroll) echo '1 2 3 4' ;;
    days)
      for i in {1..21}; do
        if [ "$i" -le 7 ]; then echo "node|día $i, Tarde"
        elif [ "$i" = 8 ] && [[ "$3" = *_written.xml || "$3" = *_final.xml ]]; then
          echo "node|día $i, Mañana"
        else echo "node|día $i, Sin turno"
        fi
      done
      ;;
    node)
      case "$4" in
        '^Importar archivo\b') touch "$QA_FIXTURE_STATE/importing" ;;
        '^Downloads$'|'^Descargas$')
          if [ -f "$QA_FIXTURE_STATE/importing" ]; then
            [ "${FIXTURE_BLOCK:-}" = import-downloads ] && return 1
          else
            [ "${FIXTURE_BLOCK:-}" = save-downloads ] && return 1
          fi
          ;;
        '^Guardar$'|'^Save$') [ "${FIXTURE_BLOCK:-}" = save-button ] && return 1 ;;
        '^Sustituir lo que tengo$') [ "${FIXTURE_BLOCK:-}" = restore ] && return 1 ;;
      esac
      echo '1 2'
      ;;
  esac
  return 0
}
EOF
chmod +x "$SB/sdk/build-tools/1.0.0/aapt2"

upgrade_check() {
  local name="$1" old="$2" new="$3" want="$4" expected="$5" mode="$6" script="$7" rc
  shift 7
  rm -f "$SB/device/"* "$SB/out/report.md"
  [ "$mode" = existing ] && touch "$SB/device/online"
  printf '%s\n' "$old" >"$SB/out/cuadrante-0.12.0.apk"
  printf '%s\n' "$new" >"$SB/actual.apk"
  env PATH="$SB/bin:$PATH" ANDROID_HOME="$SB/sdk" QA_OUT="$SB/out" QA_DEVICE= \
    QA_AVD=Cuadrante_QA QA_EMULATOR_PORT=5580 QA_OLD_TAG=v0.12.0 QA_U02_USE_PARENT_LOCK=0 \
    QA_CURRENT_APK="$SB/actual.apk" QA_FIXTURE_STATE="$SB/device" "$@" \
    timeout 240 bash "$SB/tool/qa/$script" >"$SB/last.log" 2>&1
  rc=$?
  local access=1
  case "$mode" in
    none) [ ! -e "$SB/device/adb" ] || access=0 ;;
    existing|unreserved)
      if grep -Ev '^(devices|-s emulator-5580 emu avd name)$' "$SB/device/adb" 2>/dev/null | grep -q .; then
        access=0
      fi
      ;;
    owned)
      grep -q -- '^-s emulator-5580 uninstall ' "$SB/device/adb" &&
        [ "$(grep -c '^take ' "$SB/device/lock")" = 1 ] &&
        [ "$(grep -c '^release ' "$SB/device/lock")" = 1 ] &&
        [ "$(grep -c -- '^-s emulator-5580 emu kill$' "$SB/device/adb")" = 1 ] &&
        [ ! -e "$SB/device/online" ] && [ ! -e "$SB/device/owner" ] || access=0
      ;;
  esac
  if [ "$rc" = "$want" ] && [ "$access" = 1 ] && grep -Eq "$expected" "$SB/out/u02.log"; then
    echo "ok   U02 $name -> exit $rc"
  else
    echo "FAIL U02 $name -> exit $rc (wanted $want, target check $access)"
    tail -n 25 "$SB/last.log"
    fails=$((fails + 1))
  fi
}
old=es.cuadrante.app
new=es.turnly.app
upgrade=upgrade_android.sh
upgrade_check 'unknown source APK' es.other.app "$new" 2 'FAIL.*applicationId de origen' none "$upgrade"
upgrade_check 'unknown destination APK' "$old" es.other.app 2 'FAIL.*applicationId de destino' none "$upgrade"
upgrade_check 'unreadable APK' bad "$new" 2 'FAIL.*applicationId' none "$upgrade"
upgrade_check 'phone with same package' "$new" "$new" 2 'FAIL.*reservar' none "$upgrade" QA_DEVICE=fixture-phone
upgrade_check 'phone passed by parent' "$old" "$new" 2 'FAIL.*no está reservado' none "$upgrade" \
  QA_DEVICE=fixture-phone QA_U02_USE_PARENT_LOCK=1
upgrade_check 'unowned QA AVD' "$old" "$new" 2 'FAIL.*reservar' existing "$upgrade"
upgrade_check 'foreign AVD passed by parent' "$old" "$new" 2 'FAIL.*no está reservado' existing "$upgrade" \
  QA_DEVICE=emulator-5580 QA_U02_USE_PARENT_LOCK=1 FIXTURE_AVD=Mochila_Phone
upgrade_check 'QA AVD passed without parent lock' "$old" "$new" 2 'FAIL.*no está reservado' existing "$upgrade" \
  QA_DEVICE=emulator-5580 QA_U02_USE_PARENT_LOCK=1
upgrade_check 'reservation refused' "$old" "$new" 2 'FAIL.*reservar' unreserved "$upgrade" FIXTURE_LOCK_BUSY=1
upgrade_check 'owned in-place update' "$new" "$new" 0 'PASS' owned "$upgrade"
if ! grep -q -- '^-s emulator-5580 install -r ' "$SB/device/adb"; then
  echo "FAIL U02 in-place update did not use install -r"; fails=$((fails + 1))
fi
upgrade_check 'transfer using the battery reservation' "$old" "$new" 0 'PASS' owned run_android.sh QA_UPGRADE=1
if ! grep -q 'copia de fixture restaurada en fixture' "$SB/out/u02.log"; then
  echo "FAIL U02 transfer did not reach restore verification"; fails=$((fails + 1))
fi
upgrade_check 'save picker downloads' "$old" "$new" 3 'SKIP.*selector de guardado' owned "$upgrade" FIXTURE_BLOCK=save-downloads
upgrade_check 'save picker filename' "$old" "$new" 3 'SKIP.*nombre del archivo' owned "$upgrade" FIXTURE_BLOCK=backup-name
upgrade_check 'save picker button' "$old" "$new" 3 'SKIP.*Guardar' owned "$upgrade" FIXTURE_BLOCK=save-button
upgrade_check 'import picker downloads' "$old" "$new" 3 'SKIP.*selector de importación' owned "$upgrade" FIXTURE_BLOCK=import-downloads
upgrade_check 'restore failure' "$old" "$new" 1 'FAIL.*confirmación de restauración' owned "$upgrade" FIXTURE_BLOCK=restore

# Rerunning U02 replaces its verdict, including its failure text, while a
# failing Flutter run or a battery that never ran remains red.
report_check() {
  local name="$1" battery_exit="$2" battery_result="$3" verdict="$4"
  printf '%s\n' "$battery_result" >"$SB/battery.log"
  dart "$HERE/report.dart" --out "$SB/out" --log "$SB/battery.log" \
    --flutter-exit "$battery_exit" >"$SB/last.log" 2>&1
  printf 'QA_START|U02|Traslado\nQA_RESULT|U02|FAIL|10|Falló la copia\n' >"$SB/extra.log"
  dart "$HERE/report.dart" --out "$SB/out" --extra-log "$SB/extra.log" --append 1 >>"$SB/last.log" 2>&1
  printf 'QA_START|U02|Traslado\nQA_RESULT|U02|PASS|10|\n' >"$SB/extra.log"
  dart "$HERE/report.dart" --out "$SB/out" --extra-log "$SB/extra.log" --append 1 >>"$SB/last.log" 2>&1
  if grep -Fq -- "- Resultado: **$verdict**" "$SB/out/report.md" &&
      [ "$(grep -c '^| U02 |' "$SB/out/report.md")" = 1 ] &&
      ! grep -q 'Falló la copia' "$SB/out/report.md"; then
    echo "ok   report U02 rerun: $name"
  else
    echo "FAIL report U02 rerun: $name"; cat "$SB/last.log"; fails=$((fails + 1))
  fi
}
passed_battery=$'QA_START|Q01|Uno\nQA_RESULT|Q01|PASS|10|'
report_check 'only U02 failed' 0 "$passed_battery" 'TODO EN VERDE'
report_check 'Flutter failed too' 2 "$passed_battery" 'HAY FALLOS'
report_check 'another scenario failed' 0 "$passed_battery"$'\nQA_START|Q02|Dos\nQA_RESULT|Q02|FAIL|10|boom' 'HAY FALLOS'
report_check 'battery never ran' 0 '' 'HAY FALLOS'

if [ "$fails" -ne 0 ]; then
  echo "selftest: $fails check(s) failed"
  exit 1
fi
echo "selftest: all exit-status checks passed"
