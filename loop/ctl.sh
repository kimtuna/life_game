#!/usr/bin/env bash
# 자율 루프 제어 스크립트: 등록 / 시작 / 정지 / 상태 확인을 한 곳에서.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

LABEL="com.kdw240.autoloop"
PLIST_SRC="$SCRIPT_DIR/launchd/${LABEL}.plist"
PLIST_DST="$HOME/Library/LaunchAgents/${LABEL}.plist"
STOP_FILE="$SCRIPT_DIR/STOP"
UID_NUM="$(id -u)"
DOMAIN="gui/${UID_NUM}"

usage() {
  cat <<EOF
사용법: $0 <명령>

  install         launchd에 등록만 한다 (아직 켜지지 않음)
  start           등록 + 즉시 시작 (로그인 시 자동 시작되도록 launchd에 올림)
  stop            즉시 강제 정지 (진행 중인 바퀴도 바로 중단)
  graceful-stop   STOP 파일을 만들어 현재 바퀴가 끝나면 스스로 멈추게 한다
  restart         stop 후 start
  status          launchd 등록 상태 + 최근 이벤트 로그 확인
  uninstall       launchd 등록 해제 + plist 삭제
EOF
  exit 1
}

install_plist() {
  mkdir -p "$HOME/Library/LaunchAgents"
  cp "$PLIST_SRC" "$PLIST_DST"
  echo "등록됨: $PLIST_DST"
}

do_start() {
  [ -f "$STOP_FILE" ] && rm -f "$STOP_FILE" && echo "이전 STOP 파일 제거"
  install_plist
  launchctl bootstrap "$DOMAIN" "$PLIST_DST" 2>/dev/null \
    || launchctl load "$PLIST_DST" 2>/dev/null \
    || true
  launchctl kickstart -k "${DOMAIN}/${LABEL}" 2>/dev/null || true
  echo "시작됨: $LABEL"
}

do_stop() {
  launchctl bootout "${DOMAIN}/${LABEL}" 2>/dev/null \
    || launchctl unload "$PLIST_DST" 2>/dev/null \
    || true
  echo "정지됨: $LABEL"
}

do_graceful_stop() {
  touch "$STOP_FILE"
  echo "STOP 파일 생성함: 현재 바퀴가 끝나면 멈춥니다 ($STOP_FILE)"
}

do_status() {
  echo "--- launchd ---"
  launchctl print "${DOMAIN}/${LABEL}" 2>/dev/null | head -20 || echo "등록되어 있지 않거나 실행 중이 아님"
  echo ""
  echo "--- STOP 파일 ---"
  if [ -f "$STOP_FILE" ]; then
    echo "있음 ($STOP_FILE) - 현재 바퀴 종료 후 멈춤 예정"
  else
    echo "없음"
  fi
  echo ""
  echo "--- 최근 이벤트 ---"
  tail -n 10 "$ROOT_DIR/logs/loop-events.log" 2>/dev/null || echo "(로그 없음)"
}

do_uninstall() {
  do_stop
  rm -f "$PLIST_DST"
  echo "등록 해제 및 plist 삭제 완료"
}

case "${1:-}" in
  install) install_plist ;;
  start) do_start ;;
  stop) do_stop ;;
  graceful-stop) do_graceful_stop ;;
  restart) do_stop; sleep 1; do_start ;;
  status) do_status ;;
  uninstall) do_uninstall ;;
  *) usage ;;
esac
