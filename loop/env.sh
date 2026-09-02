#!/usr/bin/env bash
# 루프 설정. 값만 바꿔서 조정하세요. loop.sh 가 source 해서 씁니다.

# 사용할 모델. alias 가능: sonnet / opus / fable / haiku, 또는 정식 모델명.
MODEL="sonnet"

# 한 바퀴 최대 예산(달러).
# 참고: claude CLI에는 "최대 턴 수"를 직접 제한하는 옵션이 없습니다.
# 대신 예산(MAX_BUDGET_USD_PER_LAP)과 시간(LAP_TIMEOUT_SECONDS) 두 가지로
# 한 바퀴의 크기를 제한합니다.
MAX_BUDGET_USD_PER_LAP="2.00"

# 한 바퀴 최대 실행 시간(초). 이 시간을 넘기면 해당 바퀴를 강제 종료하고 다음 바퀴로 넘어갑니다.
LAP_TIMEOUT_SECONDS=1800

# 바퀴 사이 대기 시간(초).
WAIT_BETWEEN_LAPS=60

# 최대 바퀴 수. 0이면 무제한.
MAX_LAPS=0

# 권한 모드: acceptEdits / bypassPermissions / auto / dontAsk / manual / plan
# 이 루프는 헤드리스(-p)로 돌기 때문에 승인을 기다릴 사람이 없습니다.
# manual/plan/dontAsk 등 승인이 필요한 모드를 쓰면 그 자리에서 멈춰버립니다.
# 기본값은 bypassPermissions(무인 실행)이며, 이는 파일 수정·명령 실행을
# 확인 없이 전부 허용한다는 뜻입니다. 반드시 loop/PROMPT.md ③에 안전 규칙
# (예: 이 폴더 밖 파일을 건드리지 않는다, 원격 push는 하지 않는다 등)을
# 채워 넣은 뒤에 돌리세요.
PERMISSION_MODE="bypassPermissions"
