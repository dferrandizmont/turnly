#!/usr/bin/env bash
# B01-B03: what the Android system backup (Auto Backup) takes out of the phone
# (docs/copia-de-seguridad.md, section 10; question 30 of docs/preguntas.md).
# Run it from the repo root, in Git Bash:
#
#   tool/qa/backup_android.sh                         # boots Cuadrante_QA on port 5580
#   QA_BACKUP_APK=ruta.apk tool/qa/backup_android.sh  # skips the debug build
#   QA_BACKUP_CASE=B01 tool/qa/backup_android.sh      # a single case
#
# Since 4-nov-2026 the rules only let files/ out to the cloud backup when the
# transport reports REAL client-side (end-to-end) encryption, which only the
# Google transport does, and only when the phone has a screen lock. A test
# cannot drive the Google transport, so this one uses the AOSP local transport:
#
# B01 Unencrypted cloud backup (local transport as it is): `bmgr backupnow`,
#     uninstall, install again: the install-time restore brings back neither
#     cuadrante.sqlite nor a marker file in files/attachments/.
# B02 Local transport with its "fake_encryption_flag": that parameter sets a
#     FAKE test flag on purpose (FLAG_FAKE_CLIENT_SIDE_ENCRYPTION_ENABLED), not
#     the real one, so the rules must not let anything out either.
# B03 Resources: allow_system_backup is false in values/ (Android 7-8) and true
#     in values-v28/, read from the APK with aapt2.
#
# Control done on 4-nov-2026: with the old rules (include everything, no
# encryption required) B01 and B02 both brought the database and the attachment
# back, so these cases do see the difference.
# NOT covered here (needs a real phone with a screen lock and a Google account):
# that the Google backup DOES carry Turnly when it is end-to-end encrypted
# (docs/copia-de-seguridad.md, "Cómo probarlo").
#
# Each case runs on a freshly booted emulator (-no-snapshot-save): on one boot,
# only the first uninstall/install restore works, whatever the rules. With
# QA_DEVICE the device is used as it is, so run one case per boot yourself.
# WARNING: the app is uninstalled (its data on that device is lost). At the end
# the backup transport and its parameters are put back, and the emulator is
# stopped ONLY if this run started it. Output in build/qa/backup/. Exit code 0
# only if every case passes.
set -u
export MSYS_NO_PATHCONV=1
QA_AVD="${QA_AVD:-Cuadrante_QA}"
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

BQ_OUT="$QA_OUT/backup"
BQ_APK="${QA_BACKUP_APK:-$QA_APP/build/app/outputs/flutter-apk/app-debug.apk}"
BQ_LOCAL="com.android.localtransport/.LocalTransport"
BQ_GOOGLE="com.google.android.gms/.backup.BackupTransportService"
mkdir -p "$BQ_OUT"
[ -f "$QA_ROOT/build/.gitignore" ] || echo '*' >"$QA_ROOT/build/.gitignore"

# --- parent: build, B03, then one child per case ----------------------------------
if [ -z "${QA_BACKUP_CASE:-}" ]; then
  BQ_LOG="$BQ_OUT/backup.log"
  : >"$BQ_LOG"
  bq_log() { qa_log "$*"; echo "$*" >>"$BQ_LOG"; }
  if [ -z "${QA_BACKUP_APK:-}" ]; then
    bq_log "building the debug APK"
    (cd "$QA_APP" && flutter build apk --debug >"$BQ_OUT/build.log" 2>&1) || {
      bq_log "build failed (see $BQ_OUT/build.log)"; exit 2; }
  fi
  [ -f "$BQ_APK" ] || { bq_log "no APK at $BQ_APK"; exit 2; }
  apk_arg="$BQ_APK"
  qa_is_windows && apk_arg="$(cygpath -w "$BQ_APK")"   # MSYS_NO_PATHCONV: aapt2.exe needs a Windows path
  failed=0
  AAPT2="$(ls -d "$ANDROID_HOME"/build-tools/*/ 2>/dev/null | sort -V | tail -n 1)aapt2"
  [ -x "$AAPT2" ] || AAPT2="${AAPT2}.exe"
  res="$("$AAPT2" dump resources "$apk_arg" 2>/dev/null | tr -d '\r' | grep -A3 'bool/allow_system_backup')"
  echo "$res" >>"$BQ_LOG"
  if echo "$res" | grep -q '() false' && echo "$res" | grep -q 'v28) true'; then
    bq_log "QA_RESULT B03 PASS allow_system_backup false by default, true from v28"
  else
    bq_log "QA_RESULT B03 FAIL unexpected allow_system_backup values (or no aapt2)"; failed=1
  fi
  for c in B01 B02; do
    QA_BACKUP_CASE="$c" QA_BACKUP_APK="$BQ_APK" bash "${BASH_SOURCE[0]}" || failed=1
    grep -h "QA_RESULT" "$BQ_OUT/backup-$c.log" >>"$BQ_LOG" 2>/dev/null
  done
  grep "QA_RESULT" "$BQ_LOG"
  [ "$failed" = 0 ] && bq_log "all passed" || bq_log "some checks failed"
  exit "$failed"
fi

# --- child: one case on one boot -------------------------------------------------------
BQ_CASE="$QA_BACKUP_CASE"
BQ_LOG="$BQ_OUT/backup-$BQ_CASE.log"
: >"$BQ_LOG"
BQ_OLD_TRANSPORT=""
BQ_OLD_PARAMS=""
BQ_OLD_ENABLED=""
BQ_TOUCHED=0
BQ_FAILED=0
BQ_APK_ARG="$BQ_APK"
qa_is_windows && BQ_APK_ARG="$(cygpath -w "$BQ_APK")"   # adb.exe needs a Windows path

bq_log() { qa_log "$*"; echo "$*" >>"$BQ_LOG"; }
bq_result() { bq_log "QA_RESULT $1 $2 $3"; [ "$2" = PASS ] || BQ_FAILED=1; }

bq_restore_device() {
  [ "$BQ_TOUCHED" = 1 ] || return 0
  bq_log "putting the backup transport back ($BQ_OLD_TRANSPORT)"
  if [ -z "$BQ_OLD_PARAMS" ] || [ "$BQ_OLD_PARAMS" = null ]; then
    qa_adb shell settings delete secure backup_local_transport_parameters >/dev/null 2>&1 || true
  else
    qa_adb shell settings put secure backup_local_transport_parameters "$BQ_OLD_PARAMS" >/dev/null 2>&1 || true
  fi
  [ -n "$BQ_OLD_TRANSPORT" ] && qa_adb shell bmgr transport "$BQ_OLD_TRANSPORT" >/dev/null 2>&1 || true
  case "$BQ_OLD_ENABLED" in *disabled*) qa_adb shell bmgr enable false >/dev/null 2>&1 || true ;; esac
}
bq_cleanup() { local rc=$?; bq_restore_device; (exit "$rc"); qa_cleanup; }
trap bq_cleanup EXIT INT TERM

[ -f "$BQ_APK" ] || { bq_log "no APK at $BQ_APK"; exit 2; }
qa_device_select || exit 2
# A real phone loses Turnly and its local copies here (uninstall, backup wipe):
# only emulators unless asked for on purpose.
case "$QA_SERIAL" in
  emulator-*) ;;
  *) [ "${QA_BACKUP_ALLOW_DEVICE:-0}" = 1 ] || { bq_log "real device $QA_SERIAL: set QA_BACKUP_ALLOW_DEVICE=1 (Turnly will be uninstalled)"; exit 2; } ;;
esac
bq_log "case $BQ_CASE on $QA_SERIAL, API $(qa_adb shell getprop ro.build.version.sdk | tr -d '\r')"

# A fresh emulator has the backup manager off, and then it lists no transports.
BQ_OLD_ENABLED="$(qa_adb shell bmgr enabled 2>&1 | tr -d '\r')"
BQ_OLD_PARAMS="$(qa_adb shell settings get secure backup_local_transport_parameters | tr -d '\r')"
BQ_TOUCHED=1
qa_adb shell bmgr enable true >>"$BQ_LOG" 2>&1
sleep 3
transports="$(qa_adb shell bmgr list transports 2>&1 | tr -d '\r')"
echo "$transports" >>"$BQ_LOG"
echo "$transports" | grep -q "$BQ_LOCAL" || { bq_log "the local transport is not available on this image"; exit 2; }
sel="$(qa_adb shell bmgr transport "$BQ_LOCAL" 2>&1 | tr -d '\r')"
echo "$sel" >>"$BQ_LOG"
# "Selected transport X (formerly Y)": Y is put back at the end. A run that died
# before doing it leaves the local transport selected: then Google's.
BQ_OLD_TRANSPORT="$(echo "$sel" | sed -n 's/.*(formerly \(.*\)).*/\1/p')"
[ "$BQ_OLD_TRANSPORT" = "$BQ_LOCAL" ] && BQ_OLD_TRANSPORT="$BQ_GOOGLE"

bq_has() { qa_adb shell run-as "$QA_PACKAGE" ls "$1" >/dev/null 2>&1; }

case "$BQ_CASE" in
  B01) qa_adb shell settings put secure backup_local_transport_parameters "fake_encryption_flag=false" ;;
  B02) qa_adb shell settings put secure backup_local_transport_parameters "fake_encryption_flag=true" ;;
  *) bq_log "unknown case $BQ_CASE"; exit 2 ;;
esac
sleep 2
qa_adb shell bmgr wipe "$BQ_LOCAL" "$QA_PACKAGE" >>"$BQ_LOG" 2>&1

# Fresh install, first launch to create the database, and an attachment marker.
qa_adb uninstall "$QA_PACKAGE" >/dev/null 2>&1 || true
qa_adb install -r "$BQ_APK_ARG" >>"$BQ_LOG" 2>&1 || { bq_result "$BQ_CASE" FAIL "install failed"; exit 1; }
qa_adb shell monkey -p "$QA_PACKAGE" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
for i in $(seq 1 40); do bq_has files/cuadrante.sqlite && break; sleep 2; done
bq_has files/cuadrante.sqlite || { bq_result "$BQ_CASE" FAIL "the app did not create files/cuadrante.sqlite"; exit 1; }
sleep 3
# Not am force-stop: a force-stopped app is not eligible for backup.
qa_adb shell input keyevent KEYCODE_HOME
qa_adb shell run-as "$QA_PACKAGE" sh -c "'mkdir -p files/attachments && echo qa > files/attachments/qa-marker'"
bq_has files/attachments/qa-marker || { bq_result "$BQ_CASE" FAIL "could not write the attachment marker"; exit 1; }

bq_log "transport parameters: $(qa_adb shell settings get secure backup_local_transport_parameters | tr -d '\r')"
qa_adb logcat -c >/dev/null 2>&1 || true
qa_adb shell bmgr backupnow "$QA_PACKAGE" 2>&1 | tr -d '\r' | tee -a "$BQ_LOG" >/dev/null
sleep 2
qa_adb logcat -d 2>/dev/null | tr -d '\r' | grep -E 'PFTBT|KeyValueBackupTask|BackupManagerService' \
  >"$BQ_OUT/logcat-$BQ_CASE.txt" || true

qa_adb uninstall "$QA_PACKAGE" >>"$BQ_LOG" 2>&1
qa_adb install "$BQ_APK_ARG" >>"$BQ_LOG" 2>&1
sleep 8
db=0; att=0
bq_has files/cuadrante.sqlite && db=1
bq_has files/attachments/qa-marker && att=1
bq_log "after the install-time restore: database=$db attachment=$att"
if [ "$db" = 0 ] && [ "$att" = 0 ]; then
  bq_result "$BQ_CASE" PASS "nothing left the phone without real end-to-end encryption"
else
  bq_result "$BQ_CASE" FAIL "data left the phone without real encryption (database=$db attachment=$att)"
fi

qa_adb shell bmgr wipe "$BQ_LOCAL" "$QA_PACKAGE" >>"$BQ_LOG" 2>&1
qa_adb uninstall "$QA_PACKAGE" >/dev/null 2>&1 || true
exit "$BQ_FAILED"
