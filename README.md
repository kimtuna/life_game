# auto-loop

`claude` CLI 헤드리스 세션을 매 바퀴 "새로" 열어서 문서(파일) 기반으로 이어가는 자율 개발 루프.
대화를 이어 붙이지 않는다 — 기억은 `docs/` 아래 파일들이 대신한다.

## 구조

```
auto-loop/
  loop/
    loop.sh                 루프 본체 (INBOX 큐 소진 시 종료, STOP 파일 감지)
    env.sh                  설정 (모델 / 예산 / 시간 / 대기 / 최대 바퀴 / 권한 모드)
    PROMPT.md                매 바퀴 세션에 그대로 전달되는 지시서 (6절 틀)
    ctl.sh                   제어 스크립트 (install/start/stop/graceful-stop/status/uninstall)
    STOP                     (평소엔 없음) 생기면 현재 바퀴를 마치고 멈춤
    launchd/
      com.kdw240.autoloop.plist   launchd 등록용 원본
  docs/
    DESIGN.md                무엇을 만드는가 (초기 기획서, 거의 안 고침)
    STATUS.md                어디까지 했고 다음은 뭔가 (매 바퀴 갱신)
    index.html               진행 상황 대시보드 (loop.sh가 매 바퀴 자동 생성/커밋)
    feedback/
      INBOX.md                작업 큐 (체크박스 `- [ ] #N`, 번호가 작은 순서대로 한 바퀴에 하나씩 처리)
  logs/
    loop-events.log          시작/종료/STOP/큐 소진/push 등 이벤트 로그
    YYYY-MM-DD.log           그날 실행된 각 바퀴의 claude 세션 출력
    launchd.out.log / .err.log   launchd로 띄웠을 때의 표준출력/에러 (자동 생성)
```

## 작업 큐 (`docs/feedback/INBOX.md`)

- "처리 대기"에 `- [ ] #N 내용`을 추가하면 루프가 번호가 작은 순서대로 **한 바퀴에 하나씩** 처리한다.
- **큐가 비면(미완료 항목 0개) `loop.sh`는 claude 세션을 아예 열지 않고 그 자리에서 스스로 종료한다.**
  무한 반복 대신 "할 일이 없으면 멈춘다"로 바꿔서, 시킨 적 없는데 토큰만 계속 나가는 상황을 막는다.
  (launchd로 띄워둔 상태여도 `exit 0`은 "정상 종료"라 재시작되지 않는다 — 아래 동작 방식 참고.)
- 완료된 항목은 세션이 직접 `- [x]`로 바꾸고 완료 날짜를 붙인다 (지우지 않음).
- 즉, **새 작업을 시키려면 INBOX.md에 항목을 추가하고 `loop/ctl.sh start`(또는 이미 켜져 있으면 다음 바퀴 대기 중 자동으로)로 다시 돌리면 된다.**

## 진행 상황 보기

매 바퀴가 끝날 때마다 `docs/index.html`을 다시 그려서 커밋 + push하고, GitHub Pages로 공개해뒀다:

**https://kimtuna.github.io/life_game/**

남은 항목 수, 완료된 항목 수, 지금(또는 다음으로) 처리 중인 INBOX 항목, 마지막 작업 커밋을 보여준다.
60초마다 자동 새로고침된다. (이 페이지 자체는 `loop.sh`가 기계적으로 만드는 것이라 별도 토큰 비용이 없다.)

## 채워야 할 것 (아직 전부 빈 틀)

1. `docs/DESIGN.md` — 무엇을 만들지, 왜, 범위, 완성 기준
2. `loop/PROMPT.md`의 ①(합격 기준) — ③(규칙과 근거)은 큐/커밋 규칙을 채워뒀다
3. `docs/feedback/INBOX.md`에 처리할 작업을 `- [ ] #1 ...` 형식으로 추가 (필수 — 없으면 루프가 바로 종료함)

DESIGN.md가 비어 있는 동안에도 루프는 (시험해본 결과) 임의로 프로젝트를 지어내지 않고,
INBOX 항목 내용에 없는 범위는 추측하지 않는다.

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
> `loop/PROMPT.md` ③에 이미 "세션 안에서 직접 push하지 않는다"를 넣어뒀다 (push는
> `loop.sh`가 바퀴 종료 후 대시보드 커밋과 함께 처리). 필요하면 "이 폴더 밖은 건드리지
> 않는다" 같은 규칙을 더 추가할 것.

## 커밋 메시지 형식

`loop/PROMPT.md` ⑤에 고정해둔 형식. 매 바퀴 세션이 이 형식으로 커밋한다.

- **제목**: `[INBOX #N] <이번 바퀴에서 실제로 한 일 한 줄>`
- **본문**: 아래 4개 소제목 고정 순서 (해당 없으면 "없음"이라고 적음, 절 자체는 생략하지 않음)
  1. 전체 요약 1~2문장
  2. 스스로 판단해서 고친 부분 (지시와 다르게, 더 낫다고 판단해 바꾼 것 — 예: "총기 디자인이 시대상과 안 맞아 다시 만듦")
  3. 지시받지 않았지만 추가한 개선
  4. 어려움 / 에러와 해결

`docs/index.html` 갱신은 `loop.sh`가 별도로 "상태 페이지 갱신 (바퀴 N, 남은 K개)" 커밋으로
분리해서 남긴다 — 에이전트의 작업 커밋 메시지를 기계적인 내용으로 오염시키지 않기 위해서다.

## 원격 저장소

`origin` = `https://github.com/kimtuna/life_game.git` (사용자 소유, `gh auth status`로 확인됨).
`loop.sh`가 매 바퀴 후 `git push origin HEAD:main`을 자동 실행한다. push 실패(네트워크/인증
문제 등)는 `logs/loop-events.log`에 기록만 하고 루프는 계속 진행한다(다음 바퀴에서 다시 push 시도).

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
- `origin`이 `https://github.com/kimtuna/life_game.git`로 연결되어 있고, 지금까지의 커밋은
  이미 push되어 있다. GitHub Pages(`https://kimtuna.github.io/life_game/`)도 켜뒀다.
- `docs/feedback/INBOX.md`의 "처리 대기"가 비어 있으므로, 지금 `loop/ctl.sh start`를 해도
  세션 없이 바로 종료한다. **INBOX.md에 `- [ ] #1 ...` 형식으로 작업을 추가한 뒤** 켤 것.
