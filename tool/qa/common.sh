#!/usr/bin/env bash
# Shared helpers of the QA battery (sourced by run_android.sh). Docs: docs/qa.md.
#
# Rules that never bend:
#  - an emulator is killed ONLY if this script started it (QA_EMULATOR_STARTED=1);
#  - an emulator or device somebody else runs is never touched, unless the
#    caller names it with QA_DEVICE (and even then it is never killed).
# Builds without a Gradle daemon, so a run never leaves one behind.
export GRADLE_OPTS="${GRADLE_OPTS:--Dorg.gradle.daemon=false}"

set -u

QA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
QA_APP="$QA_ROOT/app"
QA_OUT="${QA_OUT:-$QA_ROOT/build/qa}"
QA_PACKAGE="es.turnly.app"

export ANDROID_HOME="${ANDROID_HOME:-$HOME/AppData/Local/Android/Sdk}"
ADB="$ANDROID_HOME/platform-tools/adb"
EMULATOR="$ANDROID_HOME/emulator/emulator"
[ -x "$ADB" ] || ADB="$ANDROID_HOME/platform-tools/adb.exe"
[ -x "$EMULATOR" ] || EMULATOR="$ANDROID_HOME/emulator/emulator.exe"

QA_AVD="${QA_AVD:-Cuadrante_QA}"
# Fixed console port of the emulator this script starts, away from the 5554-5560
# that other sessions use. Must be even.
QA_EMULATOR_PORT="${QA_EMULATOR_PORT:-5580}"
QA_BOOT_TIMEOUT="${QA_BOOT_TIMEOUT:-420}"

QA_SERIAL=""                 # serial the tests run on
QA_EMULATOR_STARTED=0        # 1 = this script started it (and will kill it)
QA_EMULATOR_PID=""
QA_BG_PIDS=()                # helper loops (screenshot collector, permission grant)
QA_DEVICE_LOCK_PID=""
QA_DEVICE_RESERVED=0        # 1 = this run holds the reservation and must release it

qa_log() { echo "[qa] $*"; }

qa_is_windows() { case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) return 0 ;; *) return 1 ;; esac; }

# adb for one device (never the "only device" default: other sessions have theirs).
qa_adb() { "$ADB" -s "$QA_SERIAL" "$@"; }

qa_kill_tree() {
  local pid="$1"
  [ -n "$pid" ] || return 0
  if qa_is_windows; then
    local winpid
    winpid="$(cat "/proc/$pid/winpid" 2>/dev/null || echo "$pid")"
    taskkill //PID "$winpid" //F //T >/dev/null 2>&1 || true
  else
    pkill -P "$pid" 2>/dev/null || true
    kill "$pid" 2>/dev/null || true
  fi
}

# AVD name of a running emulator serial (empty if unknown).
qa_avd_of() {
  "$ADB" -s "$1" emu avd name 2>/dev/null | tr -d '\r' | head -n 1
}

qa_online() {
  "$ADB" devices 2>/dev/null | tr -d '\r' | awk -v s="$1" '$1==s && $2=="device" {found=1} END {exit !found}'
}

# Give each run its own lock identity, even inside a shared Claude session.
qa_lock_pid() {
  local pid="$1" winpid
  if [ -r "/proc/$pid/winpid" ] && read -r winpid <"/proc/$pid/winpid"; then
    pid="$winpid"
  fi
  printf '%s\n' "$pid"
}

qa_device_lock() {
  local lock
  lock="$(command -v device-lock.sh)" || lock="$HOME/.agents/scripts/device-lock.sh"
  PATH="${ADB%/*}:$PATH" env -u CLAUDE_CODE_HOST_SESSION_ID -u CLAUDE_CODE_SESSION_ID \
    sh "$lock" "$@" --owner-pid "$QA_DEVICE_LOCK_PID"
}

qa_is_u02_avd() {
  [[ "$1" =~ ^emulator-[0-9]+$ ]] &&
    qa_online "$1" && [ "$(qa_avd_of "$1")" = Cuadrante_QA ]
}

qa_owned_device_ready() {
  [ -n "$QA_DEVICE_LOCK_PID" ] && qa_is_u02_avd "$QA_SERIAL" &&
    qa_device_lock mine "$QA_SERIAL"
}

# Only the battery that holds the lock can pass its running AVD to U02.
qa_borrow_parent_device() {
  QA_DEVICE_LOCK_PID="$(qa_lock_pid "$PPID")"
  QA_SERIAL="${QA_DEVICE:-}"
  if ! qa_owned_device_ready; then
    QA_SERIAL=""
    qa_log "U02 necesita un Cuadrante_QA reservado por el proceso padre"
    return 2
  fi
  qa_log "using the battery's reserved Cuadrante_QA ($QA_SERIAL)"
}

# qa_device_select: sets QA_SERIAL (and QA_EMULATOR_STARTED) or exits.
#  QA_DEVICE=<serial>  use that device as it is, never kill it.
#  otherwise           boot QA_AVD on QA_EMULATOR_PORT unless this script's emulator is up.
#  owned               boot Cuadrante_QA and take a device-lock reservation (U02).
qa_device_select() {
  local mode="${1:-}"
  if [ "$mode" = owned ]; then
    if [ -n "${QA_DEVICE:-}" ] || [ "$QA_AVD" != Cuadrante_QA ]; then
      qa_log "U02 arranca su propio Cuadrante_QA; deja QA_DEVICE vacío y usa QA_AVD=Cuadrante_QA"
      return 2
    fi
    QA_DEVICE_LOCK_PID="$(qa_lock_pid "$$")"
  fi
  if [ -n "${QA_DEVICE:-}" ]; then
    QA_SERIAL="$QA_DEVICE"
    qa_online "$QA_SERIAL" || { qa_log "device $QA_SERIAL is not online"; return 2; }
    qa_log "using $QA_SERIAL as given (it will not be stopped)"
    return 0
  fi

  local serial="emulator-$QA_EMULATOR_PORT"
  if qa_online "$serial"; then
    local name
    name="$(qa_avd_of "$serial")"
    if [ "$name" = "$QA_AVD" ] && [ "$mode" != owned ]; then
      QA_SERIAL="$serial"
      qa_log "$QA_AVD already running on $serial: reusing it (not started by this run, will not be stopped)"
      return 0
    fi
    qa_log "port $QA_EMULATOR_PORT is already in use by '$name'"
    return 2
  fi

  # The same AVD cannot run twice: if somebody else runs it, do not touch it.
  local other name
  for other in $("$ADB" devices 2>/dev/null | tr -d '\r' | awk '$1 ~ /^emulator-/ {print $1}'); do
    if [ "$mode" = owned ] && [ "$other" = "$serial" ]; then
      qa_log "port $QA_EMULATOR_PORT is already in use by $other"
      return 2
    fi
    name="$(qa_avd_of "$other")"
    if [ "$name" = "$QA_AVD" ]; then
      qa_log "$QA_AVD is already running as $other and it is not ours."
      if [ "$mode" != owned ]; then
        qa_log "Use QA_DEVICE=$other to run on it deliberately, or QA_AVD=<another avd>."
      fi
      return 2
    fi
  done

  if [ "$mode" = owned ]; then
    qa_device_lock who avd-Cuadrante_QA || return 2
  fi
  qa_log "booting $QA_AVD on port $QA_EMULATOR_PORT"
  local args=(-avd "$QA_AVD" -port "$QA_EMULATOR_PORT" -no-snapshot-save -no-boot-anim -no-audio)
  if [ "${QA_WINDOW:-0}" != 1 ]; then
    args+=(-no-window -gpu swiftshader_indirect)
  fi
  mkdir -p "$QA_OUT"
  "$EMULATOR" "${args[@]}" >"$QA_OUT/emulator.log" 2>&1 &
  QA_EMULATOR_PID=$!
  QA_EMULATOR_STARTED=1
  QA_SERIAL="$serial"

  local waited=0
  until qa_online "$serial"; do
    if [ "$mode" = owned ] && ! kill -0 "$QA_EMULATOR_PID" 2>/dev/null; then
      qa_log "the emulator process exited before connecting (see $QA_OUT/emulator.log)"
      return 2
    fi
    sleep 2
    waited=$((waited + 2))
    if [ "$waited" -ge 120 ]; then
      qa_log "emulator did not appear in adb after ${waited}s (see $QA_OUT/emulator.log)"
      return 2
    fi
  done
  if [ "$mode" = owned ]; then
    kill -0 "$QA_EMULATOR_PID" 2>/dev/null && qa_is_u02_avd "$serial" &&
      qa_device_lock take "$serial" --purpose "Turnly QA U02" || return 2
    QA_DEVICE_RESERVED=1
  fi
  waited=0
  until [ "$(qa_adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do
    sleep 3
    waited=$((waited + 3))
    if [ "$waited" -ge "$QA_BOOT_TIMEOUT" ]; then
      qa_log "emulator did not finish booting in ${QA_BOOT_TIMEOUT}s"
      return 2
    fi
  done
  qa_log "boot completed after ~${waited}s"
  # Wake and unlock; give the package manager a moment.
  qa_adb shell input keyevent 82 >/dev/null 2>&1 || true
  sleep 3
  return 0
}

# Background loop: grants POST_NOTIFICATIONS as soon as the app is installed and
# again if `flutter test` reinstalls it (Android 13+; harmless before).
qa_grant_notifications_start() {
  (
    while true; do
      "$ADB" -s "$QA_SERIAL" shell pm grant "$QA_PACKAGE" android.permission.POST_NOTIFICATIONS >/dev/null 2>&1
      # The calendar of the phone (Q70-Q74, docs/importar.md): the scenarios
      # cannot answer the system question, so the permission is given here.
      "$ADB" -s "$QA_SERIAL" shell pm grant "$QA_PACKAGE" android.permission.READ_CALENDAR >/dev/null 2>&1
      "$ADB" -s "$QA_SERIAL" shell pm grant "$QA_PACKAGE" android.permission.WRITE_CALENDAR >/dev/null 2>&1
      sleep 2
    done
  ) &
  QA_BG_PIDS+=($!)
}

# Background loop: every `QA_SHOT|<id>|<name>` line of the log means the test
# wrote qa_shots/<name>.png in the app's cache; pull it into build/qa/shots/.
qa_shots_start() {
  local log="$1"
  mkdir -p "$QA_OUT/shots"
  (
    local seen=0 total line name
    while true; do
      if [ -f "$log" ]; then
        total="$(grep -ac 'QA_SHOT|' "$log" 2>/dev/null | tr -dc '0-9')"
        total="${total:-0}"
        if [ "$total" -gt "$seen" ]; then
          grep -a 'QA_SHOT|' "$log" | tail -n +$((seen + 1)) | while IFS= read -r line; do
            name="${line#*QA_SHOT|}"
            name="${name#*|}"
            name="$(echo "$name" | tr -d '\r' | awk '{print $1}')"
            [ -n "$name" ] && qa_pull_shot "$name"
          done
          seen="$total"
        fi
      fi
      sleep 1
    done
  ) &
  QA_BG_PIDS+=($!)
}

qa_pull_shot() {
  local name="$1" tmp
  tmp="$QA_OUT/shots/.$name.png.part"
  "$ADB" -s "$QA_SERIAL" exec-out run-as "$QA_PACKAGE" cat "cache/qa_shots/$name.png" >"$tmp" 2>/dev/null
  # A real PNG starts with 0x89 'PNG' (run-as prints its errors on stdout).
  if [ -s "$tmp" ] && [ "$(head -c 4 "$tmp" | tail -c 3)" = "PNG" ]; then
    mv -f "$tmp" "$QA_OUT/shots/$name.png"
    # Tells the test the file is safe (it waits for it to disappear).
    "$ADB" -s "$QA_SERIAL" shell run-as "$QA_PACKAGE" rm -f "cache/qa_shots/$name.png" >/dev/null 2>&1
  else
    rm -f "$tmp"
  fi
}

# Pulls every screenshot still on the device (the watcher may have missed the last ones).
qa_shots_sweep() {
  local f
  for f in $("$ADB" -s "$QA_SERIAL" shell run-as "$QA_PACKAGE" ls cache/qa_shots 2>/dev/null | tr -d '\r'); do
    case "$f" in *.png) [ -s "$QA_OUT/shots/$f" ] || qa_pull_shot "${f%.png}" ;; esac
  done
}

# Always runs (trap EXIT). Never changes the exit code of the script.
qa_cleanup() {
  local rc=$?
  trap - EXIT INT TERM
  local pid
  for pid in "${QA_BG_PIDS[@]:-}"; do
    [ -n "$pid" ] && qa_kill_tree "$pid"
  done

  if [ "$QA_EMULATOR_STARTED" = 1 ] && [ -n "$QA_SERIAL" ]; then
    if [ -z "$QA_DEVICE_LOCK_PID" ] ||
        { [ "$QA_DEVICE_RESERVED" = 1 ] && qa_owned_device_ready; }; then
      qa_log "stopping the emulator this run started ($QA_SERIAL)"
      "$ADB" -s "$QA_SERIAL" emu kill >/dev/null 2>&1 || true
      local i
      for i in $(seq 1 20); do
        qa_online "$QA_SERIAL" || break
        sleep 1
      done
      qa_online "$QA_SERIAL" && qa_kill_tree "$QA_EMULATOR_PID"
    else
      qa_kill_tree "$QA_EMULATOR_PID"
    fi
  fi
  if [ "$QA_DEVICE_RESERVED" = 1 ] && qa_device_lock mine avd-Cuadrante_QA; then
    qa_device_lock release avd-Cuadrante_QA || true
  fi

  # No `gradlew --stop`: it stops the daemons of every session on the machine.
  # The builds run without a daemon (GRADLE_OPTS above), so nothing is left.
  exit "$rc"
}
