#!/usr/bin/env bash
# 자율 개발 루프 본체.
# 바퀴마다 claude 헤드리스 세션을 "새로" 연다 — 대화를 이어 붙이지 않는다.
# loop/STOP 파일이 있으면 현재 바퀴를 마치고 멈춘다.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
STOP_FILE="$SCRIPT_DIR/STOP"
PROMPT_FILE="$SCRIPT_DIR/PROMPT.md"
EVENT_LOG="$ROOT_DIR/logs/loop-events.log"

if [ ! -f "$SCRIPT_DIR/env.sh" ]; then
  echo "$(date '+%F %T') env.sh 없음 - 종료" >>"$EVENT_LOG" 2>/dev/null
  exit 1
fi
# shellcheck source=env.sh
source "$SCRIPT_DIR/env.sh"

mkdir -p "$ROOT_DIR/logs"

log_event() {
  echo "$(date '+%F %T') $*" >>"$EVENT_LOG"
}

log_event "loop.sh 시작 (pid $$)"

lap=0
while true; do
  lap=$((lap + 1))

  if [ -f "$STOP_FILE" ]; then
    log_event "STOP 파일 발견 (바퀴 ${lap} 시작 전) - 종료"
    break
  fi

  if [ "${MAX_LAPS:-0}" -gt 0 ] && [ "$lap" -gt "$MAX_LAPS" ]; then
    log_event "MAX_LAPS(${MAX_LAPS}) 도달 - 종료"
    break
  fi

  day_log="$ROOT_DIR/logs/$(date '+%Y-%m-%d').log"
  {
    echo ""
    echo "===== 바퀴 ${lap} 시작: $(date '+%F %T') ====="
  } >>"$day_log"

  cd "$ROOT_DIR" || { log_event "ROOT_DIR 이동 실패 - 종료"; exit 1; }

  timeout "${LAP_TIMEOUT_SECONDS}" claude -p "$(cat "$PROMPT_FILE")" \
    --model "$MODEL" \
    --permission-mode "$PERMISSION_MODE" \
    --max-budget-usd "$MAX_BUDGET_USD_PER_LAP" \
    --no-session-persistence \
    >>"$day_log" 2>&1
  exit_code=$?

  {
    echo "===== 바퀴 ${lap} 종료: $(date '+%F %T') (exit=${exit_code}) ====="
  } >>"$day_log"
  log_event "바퀴 ${lap} 종료 (exit=${exit_code})"

  if [ -f "$STOP_FILE" ]; then
    log_event "STOP 파일 발견 (바퀴 ${lap} 종료 후) - 종료"
    break
  fi

  sleep "${WAIT_BETWEEN_LAPS}"
done

log_event "loop.sh 정상 종료"
exit 0
