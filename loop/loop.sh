#!/usr/bin/env bash
# 자율 개발 루프 본체.
# 바퀴마다 claude 헤드리스 세션을 "새로" 연다 — 대화를 이어 붙이지 않는다.
# docs/feedback/INBOX.md를 큐로 삼아 한 바퀴에 한 항목만 처리한다.
# 큐가 비면(미완료 항목 없음) 세션을 새로 열지 않고 스스로 종료한다 (토큰 절약).
# loop/STOP 파일이 있으면 현재 바퀴를 마치고 멈춘다.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
STOP_FILE="$SCRIPT_DIR/STOP"
PROMPT_FILE="$SCRIPT_DIR/PROMPT.md"
INBOX_FILE="$ROOT_DIR/docs/feedback/INBOX.md"
DASHBOARD_FILE="$ROOT_DIR/docs/index.html"
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

# 미완료 항목 개수: "- [ ] #" 로 시작하는 줄
pending_count() {
  local n
  n=$(grep -c '^- \[ \] #' "$INBOX_FILE" 2>/dev/null)
  echo "${n:-0}"
}

html_escape() {
  sed -e 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
}

# docs/index.html 을 현재 큐 상태로 다시 그린다. (GitHub Pages: main / /docs 로 서빙)
render_dashboard() {
  local pending done_n current_item last_commit ts
  pending=$(pending_count)
  done_n=$(grep -c '^- \[x\] #' "$INBOX_FILE" 2>/dev/null); done_n=${done_n:-0}
  current_item=$(grep -m1 '^- \[ \] #' "$INBOX_FILE" 2>/dev/null | sed -E 's/^- \[ \] //' | html_escape)
  [ -z "$current_item" ] && current_item="(없음 — 큐 비어있음)"
  last_commit=$( (cd "$ROOT_DIR" && git log -1 --pretty='%h %s' -- . ':!docs/index.html' 2>/dev/null) | html_escape)
  [ -z "$last_commit" ] && last_commit="(아직 커밋 없음)"
  ts=$(date '+%Y-%m-%d %H:%M:%S')

  cat >"$DASHBOARD_FILE" <<HTML
<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="refresh" content="60">
<title>auto-loop 진행 상황</title>
<style>
  :root{color-scheme:dark light}
  body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;max-width:640px;margin:40px auto;padding:0 16px;background:#0b0b0c;color:#e8e8ea}
  h1{font-size:1.3rem;margin-bottom:4px}
  .updated{color:#9a9aa2;font-size:.85rem;margin-top:0}
  .row{display:flex;gap:12px;flex-wrap:wrap}
  .card{background:#17181a;border:1px solid #2a2b2e;border-radius:10px;padding:16px;margin:12px 0;flex:1;min-width:140px}
  .num{font-size:2rem;font-weight:700}
  .label{color:#9a9aa2;font-size:.85rem;margin-bottom:6px}
  code{background:#222;padding:2px 6px;border-radius:4px;word-break:break-all}
</style>
</head>
<body>
  <h1>auto-loop 진행 상황</h1>
  <p class="updated">마지막 갱신: ${ts}</p>
  <div class="row">
    <div class="card"><div class="label">남은 항목</div><div class="num">${pending}</div></div>
    <div class="card"><div class="label">완료된 항목</div><div class="num">${done_n}</div></div>
  </div>
  <div class="card">
    <div class="label">지금 처리 중 / 다음으로 처리할 항목</div>
    <div>${current_item}</div>
  </div>
  <div class="card">
    <div class="label">마지막 작업 커밋</div>
    <div><code>${last_commit}</code></div>
  </div>
</body>
</html>
HTML
}

# 대시보드만 별도 커밋 (에이전트의 작업 커밋과 섞지 않는다)
commit_dashboard() {
  cd "$ROOT_DIR" || return
  git add docs/index.html >>"$EVENT_LOG" 2>&1
  if ! git diff --cached --quiet -- docs/index.html 2>/dev/null; then
    git commit -m "상태 페이지 갱신 (바퀴 ${lap:-0}, 남은 $(pending_count)개)" >>"$EVENT_LOG" 2>&1
    log_event "대시보드 커밋 (바퀴 ${lap:-0})"
  fi
}

push_all() {
  cd "$ROOT_DIR" || return
  if git remote get-url origin >/dev/null 2>&1; then
    if git push origin HEAD:main >>"$EVENT_LOG" 2>&1; then
      log_event "git push 완료"
    else
      log_event "git push 실패 (네트워크/인증을 확인할 것)"
    fi
  fi
}

log_event "loop.sh 시작 (pid $$)"
render_dashboard
commit_dashboard
push_all

lap=0
while true; do
  lap=$((lap + 1))

  if [ -f "$STOP_FILE" ]; then
    log_event "STOP 파일 발견 (바퀴 ${lap} 시작 전) - 종료"
    lap=$((lap - 1))
    break
  fi

  if [ "${MAX_LAPS:-0}" -gt 0 ] && [ "$lap" -gt "$MAX_LAPS" ]; then
    log_event "MAX_LAPS(${MAX_LAPS}) 도달 - 종료"
    lap=$((lap - 1))
    break
  fi

  pending="$(pending_count)"
  if [ "$pending" -le 0 ]; then
    log_event "INBOX 큐가 비어있음 - claude 세션을 열지 않고 루프 종료"
    lap=$((lap - 1))
    break
  fi

  day_log="$ROOT_DIR/logs/$(date '+%Y-%m-%d').log"
  {
    echo ""
    echo "===== 바퀴 ${lap} 시작: $(date '+%F %T') (남은 항목 ${pending}개) ====="
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

  render_dashboard
  commit_dashboard
  push_all

  if [ -f "$STOP_FILE" ]; then
    log_event "STOP 파일 발견 (바퀴 ${lap} 종료 후) - 종료"
    break
  fi

  if [ "$(pending_count)" -le 0 ]; then
    log_event "이번 바퀴 이후 INBOX 큐가 비어짐 - 루프 종료"
    break
  fi

  sleep "${WAIT_BETWEEN_LAPS}"
done

log_event "loop.sh 정상 종료 (총 ${lap}바퀴)"
exit 0
