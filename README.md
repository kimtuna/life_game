# auto-loop

`claude` CLI 헤드리스 세션을 매 바퀴 "새로" 열어서 문서(파일) 기반으로 이어가는 자율 개발 루프.
대화를 이어 붙이지 않는다 — 기억은 `docs/` 아래 파일들이 대신한다.

## 구조

```
auto-loop/
  loop/
    loop.sh                 루프 본체 (무한 반복, STOP 파일 감지)
    env.sh                  설정 (모델 / 예산 / 시간 / 대기 / 최대 바퀴 / 권한 모드)
    PROMPT.md                매 바퀴 세션에 그대로 전달되는 지시서 (6절 틀)
    ctl.sh                   제어 스크립트 (install/start/stop/graceful-stop/status/uninstall)
    STOP                     (평소엔 없음) 생기면 현재 바퀴를 마치고 멈춤
    launchd/
      com.kdw240.autoloop.plist   launchd 등록용 원본
  docs/
    DESIGN.md                무엇을 만드는가 (초기 기획서, 거의 안 고침)
    STATUS.md                어디까지 했고 다음은 뭔가 (매 바퀴 갱신)
    feedback/
      INBOX.md                내가 던지는 지시 (루프가 가장 먼저 읽음)
  logs/
    loop-events.log          시작/종료/STOP 감지 등 이벤트 로그
    YYYY-MM-DD.log           그날 실행된 각 바퀴의 claude 세션 출력
    launchd.out.log / .err.log   launchd로 띄웠을 때의 표준출력/에러 (자동 생성)
```

## 채워야 할 것 (아직 전부 빈 틀)

1. `docs/DESIGN.md` — 무엇을 만들지, 왜, 범위, 완성 기준
2. `loop/PROMPT.md`의 ①(합격 기준)과 ③(규칙과 근거)
3. 필요하면 `docs/feedback/INBOX.md`에 첫 지시 추가

이 세 가지가 비어 있는 동안 루프는 (시험해본 결과) 임의로 프로젝트를 지어내지 않고
"아직 정의된 작업 없음"을 `STATUS.md`에 기록만 하고 다음 바퀴로 넘어간다.

## 설정 (`loop/env.sh`)

| 변수 | 의미 | 기본값 |
|---|---|---|
| `MODEL` | 사용할 모델 (alias 가능: sonnet/opus/fable/haiku) | `sonnet` |
| `MAX_BUDGET_USD_PER_LAP` | 한 바퀴 최대 예산(달러) | `2.00` |
| `LAP_TIMEOUT_SECONDS` | 한 바퀴 최대 실행 시간(초) | `1800` |
| `WAIT_BETWEEN_LAPS` | 바퀴 사이 대기(초) | `60` |
| `MAX_LAPS` | 최대 바퀴 수 (0=무제한) | `0` |
| `PERMISSION_MODE` | 권한 모드 | `bypassPermissions` |

> **왜 "최대 턴 수" 설정이 없나:** `claude` CLI에는 턴 수를 직접 제한하는 옵션이 없다.
> 대신 예산(`MAX_BUDGET_USD_PER_LAP`)과 시간(`LAP_TIMEOUT_SECONDS`)으로 한 바퀴의 크기를 제한한다.

> **왜 기본 권한 모드가 `bypassPermissions`인가:** 헤드리스로 도는 루프는 승인을 기다릴
> 사람이 없다. 두 바퀴 시험 실행(권한 모드를 일부러 `acceptEdits`로 낮춰서 진행) 결과,
> `acceptEdits`에서는 `git add`/`git commit` 같은 Bash 명령이 승인 대기 상태로 막혀
> **그 바퀴의 작업이 전혀 커밋되지 못했다.** 즉 `acceptEdits`로는 ⑤ 커밋 규칙 자체가
> 지켜지지 않는다. 무인 실행에서 실제로 커밋까지 되게 하려면 `bypassPermissions`가 필요하다.
> 대신 `loop/PROMPT.md` ③에 "이 폴더 밖은 건드리지 않는다", "원격 push는 하지 않는다" 같은
> 안전 규칙을 반드시 채워 넣을 것.

## 2바퀴 시험 실행 결과 (등록 전 확인용)

`env.sh`를 임시로 예산 $0.50 / 시간 180초 / `acceptEdits`로 낮춰 두 바퀴를 실행해봤다.

- 바퀴마다 완전히 새 헤드리스 세션이 열렸다 (대화 이어붙임 없음 — 의도대로 동작).
- `docs/DESIGN.md`와 `docs/feedback/INBOX.md`가 빈 템플릿인 것을 보고, 두 바퀴 모두
  **임의로 프로젝트를 지어내지 않고** "정의된 작업 없음"을 판단해 `docs/STATUS.md`에만
  기록하고 멈췄다.
- 다만 권한 모드를 `acceptEdits`로 낮췄더니 `git` 명령이 전부 승인 대기로 막혀
  커밋이 되지 않는 문제를 발견했다 (위 표의 `PERMISSION_MODE` 설명 참고).
- 시험 중 만들어진 로그(`logs/*.log`)와 `STATUS.md`의 시험 내용은 정리하고,
  `env.sh`는 프로덕션 기본값(`bypassPermissions` 등)으로 되돌려 두었다.

## 켜기 / 끄기 / 상태 보기

```bash
# 로그인 시 자동 시작되도록 launchd에 등록 + 즉시 시작
loop/ctl.sh start

# 등록만 하고 아직 켜지 않기 (RunAtLoad는 다음 로그인부터 적용됨)
loop/ctl.sh install

# 즉시 강제 정지 (진행 중인 바퀴도 바로 중단)
loop/ctl.sh stop

# 현재 바퀴가 끝나면 스스로 멈추게 하기 (STOP 파일 생성)
loop/ctl.sh graceful-stop

# 상태 확인 (launchd 등록 상태 + 최근 이벤트 로그)
loop/ctl.sh status

# launchd 등록 자체를 해제 + plist 삭제
loop/ctl.sh uninstall
```

동작 방식:

- **로그인하면 시작**: `RunAtLoad = true`
- **비정상 종료면 재시작, 정상 종료면 그대로 둠**: `KeepAlive.SuccessfulExit = false`
  - 정상 종료 = `loop/STOP` 파일이 있거나 `MAX_LAPS`에 도달해 `loop.sh`가 `exit 0`으로 끝난 경우
  - 비정상 종료 = 그 외 크래시/예외 종료 (`exit != 0`) → launchd가 자동 재시작
- **PATH 명시**: `loop/launchd/com.kdw240.autoloop.plist`의 `EnvironmentVariables.PATH`에
  `claude`, `git`, `timeout`이 있는 경로를 전부 명시해뒀다. 자동 실행은 터미널의 PATH를
  물려받지 않으므로, 여기 빠지면 명령을 못 찾고 조용히 죽는다. 개발에 다른 도구
  (node, python 등)가 더 필요해지면 이 PATH에 해당 디렉터리를 추가할 것.

## 지금 상태

- launchd에 **아직 등록/시작하지 않았다** (요청대로 뼈대만 구성, 실제 가동은 보류).
- `loop/ctl.sh start`를 실행하면 그때부터 로그인 시 자동 시작 + 무인 개발 루프가 돈다.
