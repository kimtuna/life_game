# STATUS.md — 어디까지 했고 다음은 뭔가

> 이 문서는 매 바퀴 끝에 갱신됩니다. 사람이 아니라 다음 바퀴(나 자신)를 위해 씁니다.
> "다음에 할 것"이 비어 있으면 다음 바퀴는 이어받을 자리를 모릅니다 — 반드시 채우고 끝내세요.

## 마지막 갱신

바퀴 83 / 2026-09-03 (**INBOX #55 완료 — #54의 곡괭이낫 "들고 있는"/"채광하는"/
"채집하는" 세 모션을 blue/red로 확장, world.gd 코드 변경 없이 에셋만 추가, 4방향×2색×3
상태 인게임 스크린샷으로 검증 후 커밋. BUILD/DESIGN 완료 카운터가 5에 도달해 INBOX #56
(QA 전체 스윕)을 큐에 추가.**
1) 세션 시작 시 잔액 재확인: SpriteCook 1828크레딧(넉넉함), PixelLab 여전히 $0 —
   SpriteCook만으로 진행.
2) **바퀴 82가 남긴 "색상별 실루엣 동일, 프롬프트 튜닝 없이 재사용" 패턴을 그대로
   적용**했고 실제로 통했다 — 바퀴 82의 곡괭이낫 idle/mining/gathering 프롬프트 원문을
   색상 언급 없이 그대로 재사용해 blue를 먼저 전체(3방향×3상태) 생성 후 콘택트시트로
   직접 검수했고, 합격 수준이 나와 재검증 없이 red도 바로 동일 절차로 진행했다. 다만
   "바퀴 82의 north gathering처럼 항상 같은 variation이 최선이라 가정하지 말 것"이라는
   경고에 따라 blue/red 둘 다 각 세트를 실제로 콘택트시트로 눈으로 확인했다(결과: 이번엔
   두 색 모두 mining/gathering 구분이 뚜렷해 north에서도 문제 없었다 — 82의 특이
   variation 선택이 필요했던 것은 green 고유의 우연이었던 것으로 보인다).
3) **API 응답 스키마를 이번에 실측 재확인**: `generate-sync` 응답은 STATUS.md에 문서화된
   `output.assets`/`output.variations` 구조가 아니라 **최상위 `assets` 배열**
   (`{"job_id","status","assets":[{"id","url","width","height",...}],"output":null,...}`)
   이었다 — 이전 바퀴들의 노트에 이 필드 경로가 정확히 적혀있지 않아 스키마 탐색용
   테스트 호출(12크레딧, "add a small hat" 프롬프트로 blue_south.png 편집)을 한 번 더
   써서 확인했다. **다음 바퀴는 `result["assets"]`(리스트, 각 원소가 `id`/`url`/`width`/
   `height`)를 바로 쓸 것 — `output` 키는 이 엔드포인트에서 항상 null이다.**
4) `variations:3`으로 받아 68x68 정확히 일치하는 후보만 채택하는 절차(바퀴 81/82가
   확립)를 그대로 적용했고, red north mining 1건만 첫 후보가 66x68로 어긋나 두 번째
   후보(68x68)를 채택 — 재시도 콜 없이 후보 중에서 골라 해결했다(완전 실패로 재시도가
   필요했던 세트는 없었음). 총 18회 generate-sync 호출(2색×3방향×3상태) × variations 3
   × 12크레딧 = 648크레딧 소모. west는 재생성 없이 east(idle/mining/gathering 전부)를
   `ImageOps.mirror()`로 좌우반전.
5) 코드 변경 없음 — `world.gd`의 `_build_player_sprite_frames()`가 이미
   `ResourceLoader.exists()` 가드로 색상별 파일 유무를 확인하는 구조라(#54가 만듦),
   `game/assets/sprites/character/pickaxe/{blue,red}_{south,north,east,west}_
   {idle,mining,gathering}.png` 24개 파일만 올바른 경로에 추가하면 자동으로 동작했다.
6) **새로 발견한 버그(검증 스크립트 자체의 함정, 다음 바퀴가 참고할 것)**: 헤드리스가
   아닌 실제 렌더러로 여러 상태를 순차 캡처하는 autoload 스크립트를 짤 때, `_process()`의
   "시작 시 3프레임 대기" 게이트와 각 스텝의 "캡처 전 3프레임 대기"(await 체인)에
   **같은 변수(`_wait_frames`)를 재사용하면 두 메커니즘이 경합해서 `_next_step()`이
   이중으로 호출되어 마지막 플랜 항목 하나가 캡처되지 않고 스킵된다** — 실제로 24개 계획
   중 23개만 캡처되는 것으로 처음 발견했다(100초/150초 타임아웃 둘 다 동일하게 23개에서
   멈춰 타임아웃 문제가 아님을 확인). 시작 게이트용 변수와 스텝별 대기를 분리하니(스텝별
   대기는 `await get_tree().process_frame`만으로 충분, 별도 변수 불필요) 24개 전부
   정상 캡처됐다. **다음에 이런 순차 캡처 스크립트를 짤 때는 반복용 대기 변수를 절대
   재사용하지 말 것.**
7) **4방향×2색×3상태(idle/mining/gathering) 인게임 스크린샷 검증**: 바퀴 82와 동일한
   `[autoload]` 임시 추가 + 일반 실행(`godot --path .`) 방법을 재사용해 24장을 캡처,
   색상별 콘택트시트 2장으로 묶어 직접 눈으로 봤다 — 두 색 모두 4방향 전부 손과
   곡괭이낫이 자연스럽게 붙어 있고, mining(하향 내리찍기+흙먼지)과 gathering(수평
   스윙)이 뚜렷이 구분되며, west는 east의 완전한 좌우반전으로 정상 렌더링됨을 확인했다.
   green(#54)과 동일한 품질, 스타듀밸리/코어키퍼 대비 손색없는 수준으로 판단해 합격.
8) 검증에 쓴 `scripts/_verify_pickaxe55.gd`와 `project.godot`의 `[autoload]` 임시 항목은
   커밋 전 원상복구(삭제/되돌리기)했다 — `git status`에는 새
   `game/assets/sprites/character/pickaxe/{blue,red}_*.png`(및 `.import`) 24개
   파일만 남았다(임시 스크립트/스크린샷은 `/tmp/pickaxe55/`에서 실행해 레포에 남기지
   않음).
9) **BUILD/DESIGN 완료 카운터가 이번 바퀴로 5가 되어(#51~#55) INBOX #56(QA 전체 스윕)을
   큐에 추가하고 카운터를 0으로 리셋했다.**
**다음 바퀴가 참고할 것**: 다음 미완료 항목은 INBOX #56(`[QA] 전체 스윕`)이다 — 이 항목은
`[DESIGN]` 하네스가 아니라 `[QA]` 하네스(`PROMPT_QA.md`)가 처리해야 한다. 만약 다음
세션이 이 DESIGN 하네스로 열렸는데 남은 `[DESIGN]` 항목이 없다면(현재 그렇다), 정상
동작이다 — loop.sh가 태그에 맞는 하네스를 선택해서 열 것이다.

바퀴 82 / 2026-09-03 (**INBOX #54 완료 — 곡괭이낫을 든 캐릭터의 "들고 있는"/"채광하는"/
"채집하는" 세 모션을 SpriteCook `generate-sync`(`edit_asset_id` 연쇄 편집)로 green
4방향 전부 새로 만들어 캐릭터 애니메이션 프레임에 통합, 4방향×3상태 인게임 스크린샷으로
검증 후 커밋.**
1) 세션 시작 시 잔액 재확인: SpriteCook 2152크레딧(넉넉함), PixelLab 여전히 $0 —
   SpriteCook만으로 진행.
2) **#52/#53이 정립한 레시피(`generate-sync`+`edit_asset_id`+`smart_crop=false`,
   idle을 만든 뒤 그 asset_id를 다시 `edit_asset_id`로 연쇄 편집)를 그대로 재사용**,
   `variations:3`으로 처음부터 넉넉히 받아 그중 입력과 정확히 같은 크기(68x68)로 나온
   것만 채택했다(#53이 남긴 "출력 크기 불일치" 함정을 처음부터 회피 — 실제로 south
   mining/gathering 세트에서 각각 1개씩 66x68로 어긋난 후보가 나왔지만 나머지 2개가
   68x68이라 재시도 없이 바로 그중에서 골랐다).
3) 곡괭이낫은 기존 `tools/pickaxe.png` 아이콘(마톡 형태 — 한쪽은 뾰족한 곡괭이촉, 반대쪽은
   넓은 날)을 참고해 프롬프트에 "wooden handle + gray metal head with a pointed pick on
   one end and a flat wide blade on the other end, NOT a simple straight axe"로
   구체적으로 서술했다 — 총(#52)/도끼 때와 같은 패턴("재질/구성요소 구체 서술 +
   NOT 문구"가 품질을 가른다는 기존 결론 재확인).
4) idle 3방향(south/north/east) 생성 후, 각 idle의 채택된 asset_id를 `edit_asset_id`로
   다시 넣어 mining(곡괭이촉으로 아래로 내리찍는 자세, 땅/바위에 흙먼지)과 gathering(날
   부분으로 낮게 수평으로 휘두르는 자세)을 연쇄 편집으로 생성했다 — 총 9회 generate-sync
   호출(idle 3 + mining 3 + gathering 3) × variations 3 × 12크레딧 = 324크레딧 소모.
   west는 재생성 없이 east(idle/mining/gathering 전부)를 `ImageOps.mirror()`로 좌우반전.
5) **mining과 gathering을 시각적으로 구분하는 것이 이번 항목의 핵심 품질 기준이었다**
   (DESIGN.md "도구 동작 표현" — 같은 도구라도 두 동작이 서로 다른 그림이어야 함). south/
   east는 mining=하향 내리찍기(흙먼지/바위 이펙트 동반), gathering=몸 앞쪽 수평 스윙(이펙트
   없음)으로 자연스럽게 구분됐다. **north(후면)는 첫 두 variation이 mining과 거의
   구분 안 되는 포즈로 나와서, 세 번째 variation(양손을 벌려 곡괭이낫 전체 길이 — 곡괭이촉과
   날 양쪽 다 — 가 수평으로 다 보이는 넓은 스윙 자세)을 대신 채택했다** — 다소 독특한
   포즈(양팔을 좌우로 크게 벌림)지만 mining과의 구분이 확실하고 손-도구 연결도 자연스러워
   합격으로 판정했다.
6) 코드: `world.gd`의 `_build_player_sprite_frames()`에 총(#52)과 동일한
   `ResourceLoader.exists()` 가드 패턴으로 `pickaxe_idle_<dir>`/`pickaxe_mining_<dir>`/
   `pickaxe_gathering_<dir>`을 추가했고, `_current_animation_name()`에
   `_held_tool == "pickaxe"` 분기(`_pickaxe_use_kind`로 mining/gathering 중 선택)를
   되살렸다. `play_pickaxe_use()`/`resource_point.gd`의 호출부는 자산 초기화 이전부터
   이미 그대로 남아있어 수정이 필요 없었다.
7) **새로 확인된 함정: `godot --path . --script <파일>.gd`(비-헤드리스, `--script`로
   직접 실행) 방식은 `project.godot`의 `[autoload]` 싱글턴(`InventoryData` 등)을 전혀
   초기화하지 않는다** — `world.gd`/`farm_plot.gd` 등이 `Identifier not found:
   InventoryData` 컴파일 에러로 전부 실패했다(스크립트를 `res://` 안에 둬도 동일). 바퀴
   80/81이 이 방식을 썼다고 기록했었는데, 이번엔 재현되지 않았다 — 아마 그 바퀴들이
   실제로는 다른 방법을 썼거나 기록이 부정확했을 가능성이 있다. **해결책(다음 바퀴가
   재사용할 것)**: 검증용 스크립트를 `Node`로 작성해 `project.godot`의 `[autoload]`
   섹션에 마지막 줄로 임시 추가한 뒤, 일반 실행(`godot --path .`, `--script` 없이)으로
   게임을 정상 부팅시켜 그 스크립트의 `_ready()`에서 world 씬을 인스턴스화(부모가 아직
   자식 설정 중이라 `add_child.call_deferred()` 필요)하고 상태를 강제 설정 →
   `get_tree().root.get_texture().get_image()`로 캡처 → `get_tree().quit()`. 검증이
   끝나면 `project.godot`와 임시 스크립트 파일을 원래대로 되돌리고 커밋에 포함하지
   않는다.
8) **4방향×3상태(idle/mining/gathering) 인게임 스크린샷 검증**: 위 방법으로 캡처한 12장을
   콘택트시트로 묶어 직접 눈으로 봤다 — 4방향 전부 손과 곡괭이낫이 자연스럽게 붙어 있고,
   mining은 하향 내리찍기+흙먼지, gathering은 수평 스윙으로 뚜렷이 구분되며, idle과도
   명확히 다른 자세임을 확인했다. west는 east의 완전한 좌우반전으로 정상 렌더링됨을
   재확인. 스타듀밸리/코어키퍼 대비 손색없는 수준으로 판단해 합격.
9) `git status`에는 새 `game/assets/sprites/character/pickaxe/green_*.png`(및 `.import`)
   12개 파일과 `world.gd` 수정만 남았다(`project.godot`/임시 검증 스크립트는 커밋 전
   원상복구, 임시 스크립트/스크린샷은 `/tmp/pickaxe54/`에서 실행해 레포에 남기지 않음).
**다음 바퀴가 참고할 것**: 다음 미완료 `[DESIGN]` 항목은 INBOX #55(#54의 곡괭이낫 모션을
blue/red로 확장)다. #51(걷기)/#53(총)이 확인한 "색상별 실루엣이 사실상 동일하니 프롬프트
튜닝 없이 재사용 가능, 1건만 먼저 검증 후 나머지 일괄 진행" 패턴을 그대로 시도해볼 것 —
다만 north의 gathering처럼 variation 선택에 특히 신경 써야 하는 방향이 있었으니, 색상별로도
같은 variation 인덱스가 항상 최선이라고 가정하지 말고 최소 1색은 전체 세트를 직접 검수할
것을 권장. BUILD/DESIGN 완료 카운터는 이번 바퀴로 4가 됨(5가 되면 QA 스윕 추가, 아래
"다음에 할 것" 참고).

바퀴 81 / 2026-09-03 (**INBOX #53 완료 — #52의 총 "들고 있는"/"발사하는" 모션을 blue/red로
확장, world.gd 코드 변경 없이 에셋만 추가, 4방향×2색×2상태 인게임 스크린샷으로 검증 후
커밋.**
1) 세션 시작 시 잔액 재확인: SpriteCook 2548크레딧(넉넉함), PixelLab 여전히 $0 —
   SpriteCook만으로 진행.
2) **바퀴 80이 정립한 레시피(`generate-sync`+`edit_asset_id`+`smart_crop=false`)를 그대로
   재사용**, south/north/east를 각 색상별로 `variations` 파라미터로 여러 후보를 받아
   8배 확대 비교 후 채택, west는 east를 `ImageOps.mirror()`로 좌우반전(재생성 안 함) —
   총 6회(3방향×2색) 업로드+idle 생성, 6회 fire 생성(idle 결과를 `edit_asset_id`로 연쇄
   편집), 약 400크레딧 소모.
3) **새로 확인된 함정(다음 바퀴가 참고할 것): `smart_crop=false`를 줘도 출력 크기가
   요청한 `width`/`height`와 정확히 일치하지 않을 때가 있다** — blue east idle의 첫
   variations 2개 중 하나는 68x68, 다른 하나는 66x68로 나왔고, 그걸 그대로 채택한 fire는
   66x66/75x71까지 벌어졌다(바퀴 80은 이 문제를 문서에 남기지 않았는데, 아마 우연히 항상
   정확한 크기가 나왔던 것으로 보인다). 크기가 어긋난 프레임을 그대로 쓰면 idle↔fire
   전환 시 캐릭터가 몇 픽셀 튀어 보일 위험이 있다(AnimatedSprite2D가 기본적으로 프레임을
   중심 정렬하므로). **해결책**: `variations`를 2~3으로 넉넉히 받아서 그중 입력과 정확히
   같은 크기(68x68)로 나온 것만 채택하고, 정확한 크기가 하나도 없으면 그 asset_id를
   `edit_asset_id`로 다시 호출해 재시도할 것 — 실제로 blue east는 이 방식으로 재시도해
   3개 다 68x68로 나온 결과 중 하나를 채택했다. **다음 바퀴부터는 처음부터 `variations:3`
   이상으로 요청해 이 문제를 줄일 것을 권장.**
4) 색상별 프롬프트는 바퀴 80의 green 프롬프트를 그대로 재사용(south/north/east idle 및
   fire 프롬프트 원문은 바로 아래 "SpriteCook API 실측 조사 > 바퀴 80 추가 조사" 절 참고,
   이번 바퀴는 새 프롬프트를 만들지 않았다) — 셔츠 색만 바뀔 뿐 실루엣이 동일해 튜닝
   없이도 즉시 합격 수준이 나왔다(걷기 애니메이션 확장(#51) 때와 같은 패턴 재확인).
5) `world.gd`는 전혀 수정하지 않았다 — 바퀴 80이 만든 `ResourceLoader.exists()` 가드
   패턴(파일이 있는 색상만 gun_idle/gun_fire 애니메이션을 추가)이 이미 색상 확장을
   전제로 설계되어 있어, `game/assets/sprites/character/gun/{blue,red}_*.png` 8×2=16개
   파일만 올바른 경로에 추가하면 자동으로 동작했다.
6) **4방향×2색×2상태(idle/fire) 인게임 스크린샷 검증**: 바퀴 80과 동일한 방법
   (`--headless --path . --import`로 재임포트 후 `godot --path .`(실제 렌더러)로 world
   씬을 띄우고 `set_physics_process(false)` → `_variant`/`_facing`/`_held_tool="gun"`/
   `_tool_use_flash_timer`를 강제 설정 → `_update_player_animation()` → 3프레임 대기 →
   `img.get_size()` 기준으로 캡처 크롭)를 재사용해 16장을 콘택트시트 2장(색상별)으로
   묶어 직접 눈으로 봤다 — 두 색 모두 4방향 전부 손과 총이 자연스럽게 붙어 있고,
   south/north는 조준 방향으로 뚜렷이 기울어져 있으며, 발사 시 머즐 플래시가 총구
   위치에 정확히 나타났다. green과 동일한 품질, idle↔fire 전환 시 캐릭터 위치 점프도
   없음을 확인, 스타듀밸리/코어키퍼 대비 손색없는 수준으로 판단해 합격.
7) `git status`에는 새 `game/assets/sprites/character/gun/{blue,red}_*.png`(및 `.import`)
   16개 파일만 남았다(임시 스크립트/스크린샷은 `/tmp/gun53/`에서 실행해 레포에 남기지
   않음).
**다음 바퀴가 참고할 것**: 다음 미완료 `[DESIGN]` 항목은 INBOX #54(곡괭이낫 모션,
green 기준)다 — 이번 바퀴가 남긴 "출력 크기 불일치" 함정(위 3번)을 처음부터
`variations:3`으로 완화하며 진행할 것. BUILD/DESIGN 완료 카운터는 이번 바퀴로 3이 됨
(자세한 것은 아래 "다음에 할 것" 참고).

바퀴 80 / 2026-09-03 (**INBOX #52 완료 — 총을 든 캐릭터의 "들고 있는"/"발사하는" 모션을
SpriteCook `generate-sync`의 `edit_asset_id`(이미지 편집/인페인트) 기능으로 green 4방향
전부 새로 만들어 캐릭터 애니메이션 프레임에 직접 통합, 4방향×2상태 인게임 스크린샷으로
검증 후 커밋.**
1) 세션 시작 시 잔액 재확인: SpriteCook 2728크레딧(바퀴 79가 남긴 수치와 거의 동일,
   충분), PixelLab 여전히 $0 — SpriteCook만으로 진행.
2) **핵심 발견(다음 DESIGN 바퀴가 반드시 참고할 것): `animate-sync`가 아니라
   `POST /v1/api/generate-sync`의 `edit_asset_id` 파라미터가 "기존 캐릭터 그림에 새
   요소(도구)를 추가로 그려 넣는" 이번 문제에 정확히 맞는 기능이다.** `animate-sync`는
   "기존 그림 1장을 여러 프레임으로 움직이는" 용도(걷기 등)라 이 문제엔 안 맞고, 무효화된
   #48이 시도했던 "PIL 합성 + PixelLab `/inpaint`" 우회법(PixelLab 잔액 $0으로 이제 불가능)
   대신 쓸 수 있는 SpriteCook 자체 대안이다. 이미지 1장당 기본 12크레딧(1K, 기본 모델
   `gemini-3.1-flash-image`), `variations` 파라미터로 한 번에 여러 후보를 받을 수 있다
   (variations=N이면 credits_used = 12×N).
3) **`reference_asset_id`와 `edit_asset_id`는 동시에 쓸 수 없다**(`invalid_request`
   에러: "Cannot use both..."). 총 모양을 참고시키려고 기존 `tools/gun.png` 아이콘을
   `reference_asset_id`로 같이 넣으려 했으나 막혀서, 대신 프롬프트에 총의 생김새(갈색
   나무 개머리판 + 회색 금속 총열의 라이플, 얇은 선/칼 아님, 캐릭터 키의 최소 절반
   길이)를 아주 구체적으로 서술하는 것만으로 충분히 좋은 결과가 나왔다.
4) **`smart_crop=false` + 업로드 때와 같은 `width`/`height`를 주면, 출력 캔버스가
   입력과 동일한 크기·위치로 나온다 — 별도 정렬(bbox 매칭) 작업이 전혀 필요 없다.**
   (기본값 `smart_crop=true`였던 첫 시도는 콘텐츠 bbox로 꽉 크롭된 48x48을 반환해서
   기존 68x68 idle과 위치를 맞추려면 수작업 정렬이 필요했다 — 이번에 `smart_crop=false`로
   바꾸자 68x68 그대로, 머리/발 y좌표가 원본과 정확히 일치하는 결과가 나왔다. 걷기
   애니메이션 때 매번 하던 "NEAREST 다운스케일 + 알파 bbox 정렬" 후처리가 이 방식에는
   불필요하다.) 소스 이미지를 미리 업스케일할 필요도 없었다(68px 그대로 업로드해도
   동일하게 동작 — 두 번째 호출부터는 업스케일 없이 68px로 바로 진행).
5) **품질 판정 핵심**: 첫 시도(프롬프트가 막연함, "a small handgun held with both
   hands")는 총이 가랑이 사이의 얇고 애매한 막대/칼처럼 나와 불합격이었다. 총의 재질/
   구성 요소(나무 개머리판, 금속 총열)와 "NOT a thin line, NOT a knife"를 명시하고
   `variations=3`으로 여러 후보를 한 번에 받아 비교하니 즉시 합격 수준(라이플 실루엣이
   뚜렷하고 두 손으로 쥔 모습)이 나왔다 — 다음에도 막연한 서술 대신 재질/구성요소를
   구체적으로 쓰고 variations로 후보를 여러 개 뽑아 고를 것을 권장.
6) south/north는 "발사 방향(아래/위)으로 대각선으로 기울어진 라이플"을 명시해 무효화된
   #48의 핵심 결함(총이 조준 방향과 무관하게 수평으로 걸쳐 있음)을 해결했다 — south는
   총구가 화면 아래쪽으로, north는 총구가 화면 위쪽으로 또렷이 기울어짐을 스크린샷으로
   확인. east는 옆모습이라 자연스럽게 오른쪽으로 곧게 뻗은 조준 자세가 첫 시도부터 나왔다.
   발사(fire) 프레임은 idle 프레임을 `edit_asset_id`로 다시 편집해 "총구에 노란/흰
   머즐 플래시 추가 + 살짝 반동" 프롬프트로 만들었다 — idle에서 이어서 편집하니 총
   모양/각도가 자연스럽게 유지됐다. west는 새로 생성하지 않고 east(idle/fire 둘 다)를
   `ImageOps.mirror()`로 좌우반전(기존 west가 east의 반전이었던 패턴 재확인, 머즐
   플래시도 반전으로 방향이 자동으로 맞음).
7) 코드: `world.gd`의 `_build_player_sprite_frames(variant)`에 방향별
   `gun_idle_<dir>`/`gun_fire_<dir>`(각 1프레임)을 추가했다. **파일이 없는 색상(현재
   blue/red)은 `ResourceLoader.exists()`로 건너뛴다** — `_current_animation_name()`도
   `_held_tool=="gun"`이고 해당 방향 애니메이션이 실제로 SpriteFrames에 있을 때만
   gun_idle/gun_fire를 반환하고, 없으면 조용히 맨손 idle/walk로 대체한다(blue/red가
   #53 전까지도 깨지지 않도록 하는 안전장치 — 이전 걷기(#50/#51) 때는 이런 가드가 없었지만
   걷기는 항상 idle/walk가 존재해서 문제가 없었던 것뿐, 도구는 색상별로 자산이 부분적으로만
   있을 수 있어 새로 추가한 패턴이다. **다음 바퀴(#53 이후 다른 도구 확장 때도) 이 가드
   패턴을 재사용할 것.**).
8) **4방향×2상태(idle/fire) 인게임 스크린샷 검증**: `--headless --path . --import`로
   강제 재임포트 후, `world.gd`의 `_build_player_sprite_frames`가 실제로 만드는
   SpriteFrames를 `godot --path .`(헤드리스 아님, 실제 렌더러)로 world 씬을 띄워
   `set_physics_process(false)` → `_held_tool="gun"` → `_facing`/`_tool_use_flash_timer`를
   방향×상태별로 강제 설정 → `_update_player_animation()` → 대기 → 캡처를 반복했다.
   **새로 발견한 함정**: 이 프로젝트는 콘텐츠 배율(디스플레이 스케일) 때문에
   `get_root().get_visible_rect().size`(1280x720, 논리 좌표)와 실제
   `get_root().get_texture().get_image()`의 실제 픽셀 크기(1920x1080)가 다르다 —
   논리 크기로 크롭 중심을 계산하면 캐릭터가 없는 잔디밭만 찍힌다. **해결책**: 크롭
   중심은 항상 `img.get_size()`(캡처된 이미지 자신의 실제 크기)를 기준으로 계산할 것,
   `get_visible_rect()`를 쓰지 말 것. 8장 전부 콘택트시트로 만들어 직접 눈으로
   확인했다 — 4방향 모두 손과 총이 자연스럽게 붙어 있고, south/north는 조준 방향으로
   뚜렷이 기울어져 있으며, 발사 시 머즐 플래시가 총구(바라보는 쪽 끝) 위치에 정확히
   나타났다. 스타듀밸리/코어키퍼 대비 손색없는 수준으로 판단, 합격.
9) `git status`에는 `world.gd` 수정과 새 `game/assets/sprites/character/gun/`
   디렉터리(green 8장 + .import)만 남았다(임시 검증 스크립트/스크린샷은 `/tmp/gun52/`에서
   실행해 레포에 남기지 않음).
**다음 바퀴가 참고할 것**: #53(blue/red로 확장)을 진행할 때 이번 바퀴가 정립한
`generate-sync`+`edit_asset_id`+`smart_crop=false` 레시피(위 "SpriteCook API 실측 조사"
절에 상세 기록)를 그대로 재사용할 것 — 정렬 후처리가 필요 없어 걷기 때보다 훨씬 빠르다.
색상별 재검증은 걷기 때처럼 1건만 먼저 확인 후 나머지 일괄 진행하는 방식을 시도해볼 만하다
(다만 총은 새 포즈라 이번 green 프롬프트가 blue/red에도 그대로 통하는지는 아직 미검증).

바퀴 79 / 2026-09-03 (**INBOX #51 완료 — #50의 green 걷기 애니메이션을 blue/red로 확장,
world.gd 코드 변경 없이 에셋만 추가, 4방향×2색 인게임 스크린샷으로 검증 후 커밋.**
1) 세션 시작 시 잔액 재확인: SpriteCook 2868크레딧(바퀴 78이 남긴 수치와 거의 동일,
   사람 개입 없이도 충분), PixelLab 여전히 $0 — SpriteCook만으로 전량 진행.
2) 바퀴 78이 "바퀴 78 추가 조사"에 프롬프트 전문을 남기겠다고 예고했지만 실제로는
   그 섹션을 STATUS.md에 쓰지 않았고 `/tmp`의 제출 스크립트도 남아있지 않아 정확한
   원문은 복구 불가능했다 — 대신 "마지막 갱신"이 서술한 방법(south/north: 4프레임 +
   "과장된 행진" 계열 프롬프트, east: 8프레임 기본/발-접지 프롬프트, west: east
   좌우반전)을 그대로 재구성해 사용했다. **다음 바퀴를 위해 이번에 실제로 쓴 프롬프트
   원문을 아래 "SpriteCook API 실측 조사" 절에 그대로 남겨둔다** — 같은 복구 작업을
   반복하지 않도록.
3) **핵심 확인 사항(다음 바퀴에 특히 중요)**: blue/red idle 스프라이트는 green과
   실루엣이 사실상 동일(셔츠 색만 다름, PIL로 알파 bbox 비교해 확인)하다는 점에
   착안해, 색상별로 프롬프트를 따로 튜닝하지 않고 green에서 검증된 프롬프트를 그대로
   재사용했다 — blue_south 1건을 먼저 시험해 다리 위치가 프레임마다 뚜렷이 달라지는
   것을 확인한 뒤(크롭+5배 확대 비교), 나머지 5건(blue north/east, red south/north/east)은
   재검증 없이 같은 프롬프트로 바로 진행했고 전부 한 번에 합격 수준이 나왔다. 총
   6콜(south/north/east × 2색) × 20크레딧 = 120크레딧 소모(실수로 blue south를 한 번
   더 호출한 것 포함 시 140), west는 AI 생성 없이 east 프레임을 `ImageOps.mirror()`로
   재사용(바퀴 78과 동일 패턴, west 좌우반전이 기존 idle과 일치함을 재확인).
4) 소스 이미지(68px)를 256px로 NEAREST 업스케일 후 SpriteCook에 업로드하고,
   결과 프레임은 다시 68px 캔버스로 NEAREST 다운스케일 + 알파 bbox 기준
   바닥/가로중심 정렬(바퀴 78과 동일 알고리즘)로 처리했다.
5) **4방향×2색 인게임 스크린샷 검증**: `--headless --path . --import`로 강제
   재임포트 후, `world.gd`의 `_build_player_sprite_frames(color)`를 스크립트에서
   직접 호출해 `_variant`를 blue/red로 전환하며 48프레임(2색×(4+4+8+8))을 실제
   렌더러로 캡처했다. 화면 중앙을 크롭해 방향별 콘택트시트로 만들어 직접
   확인했고, 두 색 모두 다리가 프레임마다 뚜렷이 다른 위치로 움직이고 캐릭터
   정체성(옷 색, 헤어 색조)이 idle과 일관되게 유지됨을 확인했다 — ①(스타듀밸리/
   코어키퍼 대비) 기준 통과로 판정.
6) `world.gd`는 변경하지 않았다 — `_build_player_sprite_frames(variant)`와
   `WALK_FRAME_COUNTS`가 이미 색상 파라미터화되어 있어 새 PNG 파일만 올바른 경로
   (`walk/{color}_{direction}_walk_{i}.png`)에 넣으면 자동으로 동작했다.
7) `git status`에는 `game/assets/sprites/character/walk/{blue,red}_*_walk_*.png`(및
   `.import`) 신규 파일만 남았다(임시 스크립트/스크린샷은 `/tmp/w51/`에서 실행해
   레포에 남기지 않음).
**다음 바퀴가 참고할 것**: #52(총 들기/발사 모션, green 기준)를 시작하기 전에 이번
바퀴가 확인한 "색상별 재검증 불필요" 원칙을 재사용할 수 있는지 판단할 것 — 다만 #52는
새로운 포즈(총을 든 팔)라서 걷기와 달리 SpriteCook에 처음 시도하는 유형이니 green으로
먼저 품질 검증한 뒤에 #53에서 blue/red로 확장하는 흐름은 그대로 유지. SpriteCook 잔액은
이번 바퀴 종료 시점 약 2728크레딧(2868에서 140 사용) — 충분함. BUILD/DESIGN 완료
카운터(아래 "다음에 할 것" 참고)를 1로 갱신함(이전에 추적되지 않아 이번이 첫 기록).

바퀴 78 / 2026-09-03 (**INBOX #50 완료 — SpriteCook animate-sync로 green 4방향 walk 애니메이션 완성, world.gd에 통합, 4방향 인게임 스크린샷으로 검증 후 커밋.**
1) 세션 시작 시 잔액을 재확인한 결과 **SpriteCook이 28 → 3028크레딧으로 회복(사람이
   "adventurer" 티어로 업그레이드한 것으로 보임)**, PixelLab은 여전히 $0. 예산 문제가
   해소되어 바퀴 69/76이 막혔던 지점부터 재개했다.
2) **공식 `character-workflows`(`POST /characters/{id}/animations`)를 실제로 뚫어본
   결과, 우리 기존 스프라이트로는 쓸 수 없다는 게 확정됐다** — 자세한 내용은 아래
   "SpriteCook API 실측 조사 > 바퀴 78 추가 조사" 참고. 요약: 이 엔드포인트는 우리
   asset_id를 character_id로 바로 써도 동작은 하지만(문서화 안 된 동작, 이번에 새로
   발견), walk/idle_back 등 front가 아닌 모든 애니메이션이 필요로 하는 "prep" 단계가
   `degraded_resolution` 에러로 항상 실패한다(원본 68px, 3배(204px), 256px 업스케일
   모두 동일하게 실패 — 즉 진짜 원인은 표면적 해상도가 아니라 이 저디테일 chibi
   캐릭터 자체가 prep 품질 기준을 못 넘는 것으로 보인다). 실패한 아이템은 크레딧이
   자동 환불된다(122 예약 → 20만 실제 차감, 102 환불).
3) 그래서 `animate-sync`로 돌아갔다 — 이번엔 **문서(https://spritecook.ai/api-docs)를
   제대로 읽고** 바퀴 69/76이 몰랐던 것을 새로 알아냈다: `output_frames` 기본값은
   8이고(바퀴 69/76은 4로 줄여서 썼었다), `negative_prompt` 파라미터가 있다. 이 조합으로
   south를 재시도했지만 **바퀴 69/76과 완전히 동일한 실패(다리가 거의 안 움직임)가
   또 재현**됐다(output_frames를 8로 올려도 해결 안 됨 — 4번째 독립 재현).
4) **결정적 발견: 이 실패는 SpriteCook 자체의 한계가 아니라 정면/후면(south/north,
   대칭적인 저해상도 chibi 실루엣) 시점에서만 나타난다.** 같은 방식으로 east(측면)를
   시험하자 **첫 시도부터 자연스럽게 교차하는 걸음걸이가 나왔다** — 실제 게임 렌더링
   기준으로도 스타듀밸리 수준. north도 처음엔 east와 같은 약한 프롬프트로 south와
   똑같이 실패했다.
5) south/north는 프롬프트를 "과장된 행진(exaggerated marching, 무릎을 높이 들고
   다리를 넓게 벌림)"으로 바꾸고 `output_frames`를 8→4로 줄였더니(4프레임이 한
   프레임당 차지하는 "차별화 여력"이 커지는 것으로 추정) 완전한 해결은 아니지만
   확실히 프레임마다 다리 위치가 달라지는 수준까지 좋아졌다(자세한 프롬프트는 아래
   "바퀴 78 추가 조사" 참고, 재사용 가능). 다리를 크롭+확대해서 직접 비교하고, 최종적으로
   실제 게임(AnimatedSprite2D) 렌더링으로도 4프레임 전부 스크린샷을 찍어 다리 위치가
   실제로 바뀌는 것을 확인한 뒤에만 통합했다.
6) 생성된 스프라이트시트(south/north 204px대, east 212px대 — 소스를 68→256px로
   업스케일해서 넣었기 때문에 출력도 그만큼 큼)를 68x68 캔버스로 되돌리는 과정에서
   **`Image.LANCZOS`로 다운스케일하면 원본의 크리스피한 픽셀 경계가 뭉개져 기존
   idle 이미지와 스타일이 어긋나 보인다는 걸 발견**했다 — `Image.NEAREST`로
   다운스케일해야 원본과 같은 "덩어리진" 픽셀아트 느낌이 유지된다(둘을 나란히 놓고
   비교해서 확인). 정렬은 알파 채널 bbox의 바닥/가로중심을 기존 idle 이미지의 bbox와
   맞추는 방식(바퀴 76과 동일)을 그대로 재사용했다.
7) west는 새로 생성하지 않고 **east 프레임을 `ImageOps.mirror()`로 좌우반전**해서
   재사용했다 — 기존 `green_west.png`가 이미 `green_east.png`의 완전한 좌우반전이라는
   것을 픽셀 비교로 재확인했고(바퀴 18 결정과 같은 패턴), east가 이미 고품질이라 서쪽만
   따로 AI 생성에 크레딧/위험을 쓸 이유가 없었다.
8) `world.gd`의 `_build_player_sprite_frames()`에 `WALK_FRAME_COUNTS`(south/north=4,
   east/west=8) 기반으로 `walk_<방향>` 애니메이션을 추가했고, `_current_animation_name()`은
   `_is_moving` 여부로 idle/walk를 분기하도록 바꿨다(도구별 분기는 아직 없음, #52~#54가
   나중에 추가).
9) **4방향 인게임 스크린샷 검증**: `--headless --path . --import`로 강제 재임포트 후,
   `--path .`(헤드리스 아님, 실제 렌더러)로 `SceneTree` 서브클래스 스크립트를 실행해
   `_facing`/`_is_moving`을 직접 설정하고 `AnimatedSprite2D.frame`을 강제 지정해가며
   캡처했다. east/west는 스타듀밸리 수준으로 또렷한 교차보행, south/north는 프레임마다
   다리 위치가 눈에 띄게 달라지는 것을 확인했다(east/west보다는 약하지만 "멈춰 있다"는
   느낌은 사라짐 — 다섯 번의 독립 재시도 끝에 이게 이 캐릭터/해상도에서 SpriteCook로
   낼 수 있는 현실적 상한으로 판단했다). ①(스타듀밸리/코어키퍼 대비) 기준을 통과한다고
   판단해 커밋했다.
10) `git status`에는 `world.gd` 수정과 새 `game/assets/sprites/character/walk/` 디렉터리만
    남았다(임시 검증 스크립트는 `/tmp`에서 실행해 레포에 남기지 않음).
**다음 바퀴가 참고할 것**: #51(blue/red로 확장)을 진행할 때 이번 바퀴가 남긴 프롬프트
템플릿(아래 "바퀴 78 추가 조사")과 `output_frames`/방향별 규칙을 그대로 재사용할 것 —
south/north는 4프레임+과장된 마칭 프롬프트, east/west는 8프레임 기본 프롬프트(west는
east 좌우반전, 재생성 불필요). SpriteCook 잔액은 이번 바퀴 종료 시점 약 2868크레딧
남음(3028에서 시작해 이번 세션에서 여러 실험 포함 약 160 사용, 실패분은 환불됨) —
#51은 걱정 없이 진행 가능. PixelLab은 여전히 $0으로 미확인 상태.)

바퀴 77 / 2026-09-03 (**INBOX #50 착수 보류 — `EXTERNAL_TOOL_BLOCKED` 발행, 루프 중단.**
세션 시작 시 `GET /v1/api/credits`(SpriteCook)와 `/v1/balance`(PixelLab)를 재확인한 결과
`{"total":28,"subscription_credits":0,"topup_credits":28}` / `{"type":"usd","usd":0.0}` —
바퀴 76이 종료 시점에 이미 기록해둔 수치(SpriteCook 28, PixelLab $0)와 정확히 동일했다
(자연 회복 없음). 이 상태에서 진행 가능한 경로를 다시 따져보면: (a) PixelLab
`/animate-with-text`(유일하게 성공 전례가 있는 방식)는 잔액 $0이라 불가, (b) 공식
`character-workflows`(topdown)는 방향당 최소 32크레딧(20+12prep) 필요한데 28밖에 없어
불가, (c) `animate-sync`(20크레딧, 잔액상 가능)는 바퀴 69·76이 서로 다른 프롬프트로 2회
독립 재현한 구조적 결함(4프레임 중 3프레임이 near-duplicate) 때문에 STATUS.md
"다음에 할 것"이 이미 "프롬프트만 바꿔서 재시도하지 말 것"이라고 명시해뒀다 — 즉 잔액은
있지만 이 경로 자체가 재시도 대상에서 제외돼 있다. 세 경로 모두 막혀 있고, 이 사실은
바로 이전 바퀴(76)가 이미 기록해둔 것과 같은(동일한) 잔액 상태이므로,
PROMPT_DESIGN.md ③의 절차대로 세 번째 "확인만 하고 넘기기"를 반복하지 않고 표준출력에
`EXTERNAL_TOOL_BLOCKED` 한 줄을 출력한 뒤 세션을 마친다. 게임 코드/에셋은 전혀
건드리지 않았다(`git status` 변경 없음, 이 문서 갱신만 커밋). INBOX #50은 `- [ ]`로
그대로 둔다.
**다음 바퀴가 참고할 것**: 사람이 개입해 SpriteCook에 최소 4크레딧을 더 충전하거나(32
이상) PixelLab 잔액을 회복시켜주기 전까지는 이 항목을 재시도해도 같은 결과가 나올
가능성이 높다. 잔액이 바뀌었다면 위 (a)(b) 순서로 시도할 것 — PixelLab이 살아있으면
그쪽을 최우선(바퀴 44/INBOX #41 성공 레시피 재사용), 아니면 SpriteCook
`character-workflows`(front 방향부터 저렴하게 시험, 위 "SpriteCook API 실측 조사" 절
참고)를 시도할 것. `animate-sync`는 크레딧이 얼마가 되든 이 캐릭터 스케일에서는 구조적
한계로 보이므로 더 이상 추천하지 않는다.

바퀴 76 / 2026-09-03 ([DESIGN] **INBOX #50(캐릭터 idle/walk, SpriteCook, green 기준)
재착수 — 잔액이 8→48로 회복된 것을 확인해 south 방향 걷기를 다시 시도했으나, 바퀴 69와
동일한 실패 패턴이 재현되어 커밋하지 않고 보류.**
1) 세션 시작 시 `GET /v1/api/credits`(48 = 구독 8 + 충전 40)와 PixelLab `/v1/balance`
   (여전히 $0)를 재확인 — SpriteCook만으로 진행 가능하다고 판단해 착수했다.
2) 바퀴 69가 남긴 권장 경로(②`animate-sync`, 프레임별 발 위치를 프롬프트에 명시)를
   그대로 따라 이번엔 훨씬 구체적인 프롬프트("frame 1: 오른발 앞 contact, frame 2: 중립
   passing, frame 3: 왼발 앞 contact(프레임1의 좌우 반전), frame 4: 중립 passing, 4프레임이
   뚜렷이 달라야 한다"는 문구까지 명시)로 `green_south.png` 걷기 1콜을 호출했다(20크레딧
   소모, 잔여 28).
3) **새로 확인된 사실: `animate-sync`는 이름과 달리 즉시 결과를 반환하지 않는다.**
   `job_id`/`poll_url`만 큐잉해서 반환하고(응답의 `output`은 `null`), `GET
   /v1/api/jobs/{job_id}`를 폴링해야 결과가 나온다 — 이번 호출은 완료까지 약 75초
   걸렸다(바퀴 69 기록에는 이 사실이 없었다, 아마 그땐 짧게 걸렸거나 기록을 안 남긴 것으로
   보인다).
4) 결과(4프레임 스프라이트시트)를 실제로 `world.gd`(`_build_player_sprite_frames`/
   `_current_animation_name`)에 임시로 통합하고, 헤드리스로 실제 게임 렌더링 스크린샷을
   8장(walk_south 루프 2회분) 찍어 직접 눈으로 봤다 — **프레임0(다리를 벌리고 선 자세,
   사실상 기존 idle과 거의 동일)만 뚜렷이 다르고, 프레임1·2·3은 서로 거의 구분되지 않는
   "상체를 살짝 숙이고 다리를 모은" 자세로 수렴했다.** 프롬프트에 "각 프레임이 명확히
   다른 다리 위치를 보여야 한다"를 명시했는데도 바퀴 69와 완전히 동일한 실패 패턴(1개
   특이 프레임 + 3개 near-duplicate)이 재현됐다 — **서로 다른 프롬프트로 독립적으로 2회
   재현**된 것이므로 이제 "프롬프트 문제"가 아니라 `animate-sync`(기본 모델, prep 없는
   저가 경로) 자체가 이 캐릭터 스케일(56x56, 다리 폭 20px 안팎)에서 진짜 교차 보행을
   만들어내지 못하는 구조적 한계라고 판단한다. 스타듀밸리/코어키퍼 기준(①) 미달로
   커밋하지 않았다.
5) 통합했던 코드는 `git checkout -- game/scenes/world/world.gd`로 되돌리고, 새로 만든
   `game/assets/sprites/character/walk/`와 임시 검증 스크립트도 삭제했다 — `git status`는
   다시 깨끗하다. INBOX #50은 `- [ ]`로 그대로 둔다.
6) **헤드리스 검증 관련 새 함정 발견(아래 "헤드리스 CLI 검증" 절에도 추가)**: `godot
   --headless --path . --script <검증스크립트>.gd`로 화면 캡처를 시도하면(기존 노트가
   "null을 반환한다"고만 적었던 것과 달리) 이번엔 에러 없이 약 3분간 응답이 없다가 결국
   `get_texture()` null 에러로 끝났다 — 시간 손실이 컸다. 화면 캡처가 필요하면 처음부터
   `--headless`를 빼고 `godot --path . --script ...`(실제 OpenGL/Metal 렌더링 드라이버)로
   띄울 것.
**다음 바퀴가 참고할 것**: 잔여 크레딧 28(구독 0 + 충전분 28 — 이번 바퀴 시작 시 8이던
구독분이 40 충전되어 48이 됐다가 20을 써서 28로 줄었다; 자연 회복 폭/주기는 불명).
`animate-sync` 재시도(프롬프트만 바꾸는 시도)는 이제 추천하지 않는다 — 아래 "SpriteCook
API 실측 조사" 절의 "바퀴 76 추가 조사"를 먼저 읽고 다른 경로를 검토할 것: (a) 공식
`character-workflows`(topdown, 방향당 20+12prep=32크레딧, 28크레딧으로는 이번 회차도
빠듯), (b) **PixelLab 잔액이 회복되면 `/animate-with-text`를 "walk" 한 단어 + 기본
guidance로 쓰는 것** — 바퀴 44(INBOX #41)가 green 4방향 걷기에서 이 방식으로 실제 성공한
전례가 있다(위 "끝난 것" INBOX #41 항목 참고) — 지금까지 시도한 것 중 유일하게 자연스러운
좌우 교차 걸음을 만들어낸 방식이다. SpriteCook의 `animate-sync`보다 PixelLab이 이 특정
작업(걷기 교차 보행)에는 더 적합하다는 근거가 쌓이고 있다.)

바퀴 70~75 / 2026-09-03 (**INBOX #50 착수 보류 재확인 (6회, 매번 동일 결과).**
`GET /v1/api/credits` 재호출 결과 매 바퀴 `{"total":8,"subscription_credits":8,
"topup_credits":0,"tier":"free"}` — 바퀴 69 종료 시점과 정확히 동일(자연 회복 없음).
`GET /v1/balance`(PixelLab)도 매번 `{"type":"usd","usd":0.0}`로 동일 — 두 도구 모두
막혀 있다. 관측된 생성 호출 최소 비용(20크레딧)보다 적어 `animate-sync`든 무엇이든
어떤 생성 호출도 못 한다. 바퀴 69가 이미 남긴 "SpriteCook API 실측 조사" 절(아래)이
충분히 상세해서 여섯 바퀴 모두 재조사 없이 잔액 확인만 하고 바로 기록·종료했다
(PixelLab 잔액이 $0이었을 때 바퀴 58~68이 썼던 것과 같은 패턴). 게임 코드/에셋은 여섯
바퀴 모두 전혀 건드리지 않았다(`git status` 변경 없음). INBOX #50은 `- [ ]`로 그대로
둔다.
**다음 바퀴가 참고할 것**: 잔액이 회복됐는지 `GET /v1/api/credits`로 먼저 확인하고,
8~19 사이라면 여전히 생성 불가이니 이 문단처럼 짧게 기록만 하고 종료할 것. 20 이상으로
회복되면 아래 "SpriteCook API 실측 조사" 절의 권장 경로(② `animate-sync`, south부터
한 방향씩, 프레임별 발 위치 명시, 즉시 크롭+확대 검사)를 그대로 따라 진행할 것. 원인
분석/가격표 상세는 바로 아래 바퀴 69 항목 참고.

바퀴 69 / 2026-09-03 ([DESIGN] **INBOX #50(캐릭터 idle/walk를 SpriteCook으로, green 기준)
착수 — SpriteCook API를 실제 curl로 조사하고 시험 생성까지 했으나, 결과물이 합격 기준①을
통과하지 못해 커밋하지 않고 보류.** 자산 초기화(바퀴 64c1e6f/89646b4) 이후 이 하네스의
첫 SpriteCook 실사용 바퀴라 아래 "SpriteCook API 실측 조사" 절에 다음 바퀴가 반드시
참고해야 할 가격표/엔드포인트/함정을 상세히 남긴다. 요약:
1) `GET /v1/api/character-workflows`로 공식 캐릭터 워크플로우(perspective=topdown 포함)
   전체를 조회했다 — idle/walk를 방향별로 만드는 공식 기능이 실제로 존재한다(DESIGN.md
   "그래픽 파이프라인"이 기대한 대로). 하지만 애니메이션 1개당 20크레딧 + 기준
   시점("front")이 아닌 방향은 12크레딧 준비 비용이 추가로 붙어서, green 한 색만
   idle+walk 4방향을 다 만들어도 못해도 180크레딧 이상 필요하다 — 무료 티어 총량(40)을
   훨씬 초과한다. 이 공식 워크플로우 엔드포인트는 이번 바퀴에 실제로 호출해보지 않았다
   (비용 조회만 하고 실행 전에 예산 문제를 먼저 확인함).
2) 대신 더 싼 범용 `POST /v1/api/animate-sync`(기존 정적 이미지 1장 + 프롬프트로 애니메이션
   생성, prep 비용 없음)로 시도했다 — `game/assets/sprites/character/green_south.png`를
   `/v1/api/assets/import`(무료)로 업로드하고 4프레임 걷기를 요청, 20크레딧 소모.
3) 그런데 이 과정에서 **API 스키마 안전성을 확인하려던 탐색용 호출이 실수로 진짜 유료
   작업을 실행시켜 12크레딧을 낭비했다**(아래 "함정" 절 참고) — 남은 크레딧이 8까지
   줄어 이번 바퀴 안에 재시도가 불가능해졌다.
4) 받은 결과(south 방향 4프레임 걷기, `/tmp/walk_south_sheet.png`)를 확대해서 직접
   눈으로 검사한 결과, 캐릭터 정체성/색/의상은 원본과 일관됐지만(합격) **다리 동작이
   자연스러운 좌우 교차 걸음이 아니라, 1번 프레임(다리 벌린 자세)과 거의 똑같은
   2~4번 프레임(다리 꼬인 자세) 3장으로 구성돼 있어 루프로 재생하면 부드러운 걸음이
   아니라 "멈췄다 튀는" 것처럼 보일 위험이 크다** — 스타듀밸리/코어키퍼 기준 미달로
   판정, 게임에 통합하지 않았다(`git status` 깨끗함, 코드/에셋 변경 없음).
5) 게임 코드/자산은 전혀 건드리지 않았다 — 이번 바퀴는 조사+시험 생성+판정까지만 하고
   커밋 없이 이 문서 갱신만 한다. INBOX #50은 `- [ ]`로 그대로 둔다.
**다음 바퀴가 참고할 것**: 아래 "SpriteCook API 실측 조사" 절을 먼저 전부 읽고, 세션
시작 시 `GET /v1/api/credits`로 잔액이 회복됐는지(구독/충전 등) 확인할 것 — 8크레딧으로는
어떤 생성 호출도(관측된 최소 비용 20) 못한다.)

바퀴 68 / 2026-09-03 (**INBOX #48 착수 보류 재확인 (12바퀴 연속 — 57~68 전부 동일 결과).**
`GET https://api.pixellab.ai/v1/balance`를 다시 호출한 결과 여전히
`{"type":"usd","usd":0.0}`. 이전 바퀴가 남긴 지시대로 재조사 없이 확인 한 번만 하고 바로
기록·종료한다. 게임 코드/에셋은 전혀 건드리지 않았다(변경 파일 없음). INBOX #48은
`- [ ]`로 그대로 둔다.
**다음 바퀴가 참고할 것**: 잔액이 계속 0이면 매번 전체 문서를 재조사하지 말고 잔액 확인
한 번 + 이 문단 갱신만 하고 빠르게 세션을 마칠 것. (아래 바퀴 62~67 개별 기록은 전부 이
바퀴와 동일한 결과라 이번에 한 줄로 압축했다 — 문서가 무한히 늘어나는 것을 막기 위함.)

바퀴 62~67 / 2026-09-03 (**INBOX #48 착수 보류 재확인 (6회, 매번 동일 결과).**
`GET /v1/balance`를 매 바퀴 재호출했지만 항상 `{"type":"usd","usd":0.0}` — 새로운 정보
없음. 게임 코드/에셋은 여섯 바퀴 모두 건드리지 않았다.)

바퀴 58~61 / 2026-09-03 (**INBOX #48 착수 보류 재확인 (4회, 매번 동일 결과).**
`GET /v1/balance`를 각 바퀴마다 재호출했지만 매번 `{"type":"usd","usd":0.0}` — 새로운
정보 없음. 게임 코드/에셋은 네 바퀴 모두 건드리지 않았다. 원인 분석 상세는 바로 아래
바퀴 58 항목 참고.)

바퀴 58 / 2026-09-03 (**INBOX #48 착수 보류 — PixelLab 잔액 재확인 결과 여전히 $0.00.**
`GET /v1/balance` 호출로 재확인(`{"type":"usd","usd":0.0}`) — 바퀴 57이 남긴 "다음에 할
것" 지시를 그대로 따라, 잔액이 0이면 무리하게 진행하지 말고 STATUS.md에 막힘을 기록한
뒤 INBOX #48을 완료 처리하지 않기로 했다. #48은 `gun_idle_south`/`gun_fire_south`/
`gun_idle_north`/`gun_fire_north`(3색, 12장)에서 **총의 몸체 형태 자체가 조준 방향(위/
아래)으로 기울어지게 다시 그려야 하는 작업**이다 — #47(총구 불꽃 위치)처럼 이미 있는
그림 안에서 작은 요소(스파크)의 좌표만 옮기는 문제가 아니라, 총이라는 물체의 형태·각도
자체를 바꿔야 한다. 순수 PIL로 픽셀 아트를 임의 각도로 회전시키면(nearest-neighbor는
계단현상, 보간은 흐림) 도트 그래픽 외곽선이 뭉개져 합격 기준(①)을 통과하기 어렵다고
판단했다 — 실제로 이와 매우 비슷한 사례(INBOX #37 이전, 총 들기 자세를 오프셋/각도
조정만으로 고치려던 시도)가 DESIGN.md "캐릭터 애니메이션" 절에 기록된 대로 사용자에게
"여전히 이상하다"고 기각된 전례가 있다(바퀴 38 결정 로그 참고). 그림을 손으로(코드로
직접 좌표를 찍어) 그리는 것도 PROMPT.md ③/DESIGN.md "그래픽 파이프라인" 규칙으로
금지돼 있다. 결론: 이번 항목은 PixelLab 없이는 품질 기준을 통과할 방법을 찾지 못했다 —
게임 코드/에셋을 전혀 건드리지 않았고(변경 파일 없음), 이 문서(STATUS.md) 갱신만
했다. INBOX #48은 `- [ ]`로 그대로 둔다.)

바퀴 57 / 2026-09-03 (**INBOX #47(동/서 총구 불꽃 위치 결함) 완료.**
**PixelLab 잔액이 $0.00임을 확인** (`/v1/balance` 호출로 재확인) — 이번 바퀴는 새 이미지
생성 없이 순수 PIL 픽셀 편집만으로 고쳤다. 먼저 3색(green/blue/red) × east/west
`gun_fire` 이미지를 8배/14배로 확대해 직접 눈으로 비교한 결과 **blue는 이미 불꽃이
총구(주먹) 쪽에 정상적으로 붙어 있었고, green과 red만 실제로 불꽃이 몸 쪽(반대편)에
있는 결함이 있었다** — INBOX #47 원문은 "3색"이라 썼지만 실제로는 2색(green/red)만
문제였다. 색상 임계값(밝은 노랑/흰색 스파크)으로 전체 캔버스를 스캔하는 방식은
머리카락 색(어두운 갈색)이나 피부톤과 혼동되어 여러 번 실패했다(스파크가 몸통 위에
겹쳐 나타나거나 옛 불꽃 잔여물이 안 지워짐) — **최종적으로 성공한 방법**: 불꽃이 위치한
좌표 범위를 그리드 오버레이 스크린샷(`ImageDraw`로 8px 간격 눈금 표시)으로 먼저 육안
확인해 몸통/팔과 겹치지 않는 안전한 사각 범위를 정하고, 그 범위 안에서만 "idle
이미지에 없던 새 픽셀 OR 밝은 스파크색"을 불꽃으로 판정해 투명 처리(지우기) +
좌표 이동(오프셋) 후 재합성했다. 범위를 전체 캔버스로 넓히면 반동 자세(fire pose)가
idle 대비 다리/팔 위치 자체가 크게 달라 그 차이 전체를 "새 픽셀"로 오판했다(다리까지
지워지는 사고 직전까지 감) — 좁은 국소 범위 제한이 핵심이었다. 수정 후 원본과의
diff를 시각화(변경 픽셀을 마젠타로 칠한 이미지)해 머리카락/옷 등 다른 부분이 전혀
손상되지 않았음을 확인했다. 최종적으로
`game/assets/sprites/character/gun/{green,red}_{east,west}_fire.png`(4장)만 교체,
blue는 건드리지 않았다.
검증: `godot --headless --path . --import`로 강제 재임포트 후
`game/_verify_gun_flash_fix.gd`(커밋 전 삭제)로 world 씬을 실제 렌더링 드라이버로 띄우고
`set_physics_process(false)` → `_variant`/`_facing`/`_held_tool="gun"`/
`_tool_use_flash_timer`를 강제 설정 → `_update_player_animation()` → 4프레임 대기 →
전체 화면 캡처(뷰포트가 카메라 줌으로 1920x1080이라 플레이어 주변을 크롭)를
green/red × east/west 4가지 상태로 반복해 실제 게임 렌더링 스크린샷을 찍었다 — 4방향
전부 불꽃이 총구(캐릭터가 바라보는 쪽) 근처에 자연스럽게 나타나고 몸 쪽 잔여물이 없음을
눈으로 확인, 합격 기준(①) 통과로 판단했다.
이전(바퀴 56 이전 어느 시점, STATUS에 기록 없음) 세션이 `/tmp/gun_gen2/`에 이 문제와
무관한 완전히 다른 화풍(초록 셔츠 캐릭터)의 총 재설계 실험을 미완성 상태로 남겨뒀었다 —
검토 후 기존 게임 캐릭터 화풍과 맞지 않아 재사용하지 않고 폐기(참고만 하고 실제 수정에는
쓰지 않음).

바퀴 56 / 2026-09-03 (**INBOX #45(낚싯대 통합, 재오픈분) 완료.** 세션 시작 시
`git status`가 깨끗했다(바퀴 55가 이미 미커밋 폐기물을 정리해둠). 먼저 `/tmp/rod_gen/`에
남아있던 이전(폐기된) 세션의 생성물을 처음부터 다시 만들지 않고 검수부터 했다 —
`verify_south_fishing.png` 등 실제 게임 내 스크린샷을 Read로 열어보니 STATUS.md가 기록한
대로 "낚시하는" 모션에서 낚싯대가 손에서 완전히 분리되어 발밑에 막대기가 떨어진 것처럼
보이는 결함을 4방향 전부에서 재확인했다(idle은 정상이라 그대로 재사용). **근본 원인을
`build_rod.py`의 합성 좌표에서 찾았다**: idle은 `composite(base, fishing_rod.png, size=24,
pos=(35,8))`로 손 위치에 맞게 합성했는데, fishing 동작은 `composite(base,
fishing_rod_fishing.png, size=26, pos=(30,34))`를 써서 손잡이 끝이 캔버스 y=60(발 근처)에
찍혔다 — 두 아이콘(`fishing_rod.png`/`fishing_rod_fishing.png`)이 32x32 안에서 손잡이가
같은 위치(대각선 좌하단)에 있는데도 다른 pos를 줘서 어긋난 것이었다. **해결**: fishing
합성도 idle과 동일한 `pos=(35,8), size=24`로 다시 합성(`/tmp/rod_gen2/build`)했더니 원본
composite 단계(인페인트 전)부터 손잡이가 손 위치에 정확히 겹치는 것을 확인했다 — PIL
합성 직후 단계에서 먼저 확대 검수(STATUS.md "다음에 할 것"이 당부한 절차)를 거친 뒤에야
비용이 드는 PixelLab 인페인트를 호출했다. green/blue/red 각각 south를 PixelLab
`/inpaint`(mask_idle2.png 재사용, "손잡이를 쥔 주먹" 프롬프트)로 손 연결부만 다듬고,
`/rotate`(south→east/north)로 나머지 방향을 만든 뒤 west는 east를 PIL로 좌우반전했다 —
총(#42)/도끼(#43)/곡괭이낫(#44)과 동일한 레시피. idle 24장(3색×4방향, 기존 자산 재사용)과
새로 만든 fishing 24장(3색×4방향)을 `game/assets/sprites/character/fishing_rod/`에
모아 48개 파일(+.import)로 확정했다.
코드: `world.gd`의 `_build_player_sprite_frames()`에 `fishing_rod_idle_<dir>`/
`fishing_rod_fishing_<dir>` 애니메이션을 추가했고, `_current_animation_name()`에
곡괭이낫과 같은 패턴의 분기를 넣었다. `_unhandled_input`의 낚싯대 좌클릭 분기는
`_play_tool_swing()` 호출 대신 도끼처럼 `_tool_use_flash_timer = AXE_CHOP_FLASH_DURATION`을
직접 설정하도록 바꿨다. **낚싯대가 마지막 도구였으므로 INBOX #45 원문 지시대로
`_held_item_sprite`/`HELD_ITEM_OFFSETS`/`HELD_ITEM_BEHIND_FACINGS`/`TOOL_USE_ICONS`/
`_build_held_item_sprite()`/`_update_held_item_transform()`/`_play_tool_swing()`을
전부 제거**했다 — `_select_hotbar()`도 "TOOL_KEYS의 모든 도구가 이미 애니메이션
프레임에 통합돼 있다"는 전제로 단순화했다(더 이상 옆 아이콘 오버레이 분기가 필요 없음).
grep으로 이 심볼들이 world.gd 밖(resource_point.gd 등)에서 쓰이지 않는 것을 먼저
확인한 뒤 삭제했다.
검증: `godot --headless --path . --import`로 강제 재임포트 후
`game/_verify_rod_motion.gd`(커밋 전 삭제)로 world 씬을 실제 렌더링 드라이버로 띄우고
`set_physics_process(false)` → `_facing`/`_held_tool="fishing_rod"`/`_tool_use_flash_timer`를
강제 설정 → `_update_player_animation()` → 4프레임 대기 → 캡처를 8가지 상태
(south/east/north/west × idle/fishing, green)에 대해 반복해 스크린샷을 찍고 크롭한
콘택트시트를 직접 눈으로 봤다 — 4방향 전부 손과 낚싯대가 자연스럽게 붙어 있고, idle은
곧게 어깨에 걸친 자세, fishing은 줄이 늘어지며 낚싯대가 살짝 휜 자세로 뚜렷이 구분됐다
— 이전 폐기 사유였던 분리 결함이 사라졌음을 확인, 합격 기준(①) 통과로 판단했다.
콘솔에 `anim=fishing_rod_idle_south` 등으로 애니메이션 전환도 코드대로 동작함을
확인했다.)

## 끝난 것 (지금까지의 스냅샷 — 바퀴별 상세 이력은 git 커밋 메시지 `[INBOX #N] ...`에 있음)

- INBOX #45 완료 (바퀴 56, 재오픈분 재작업): 위 "마지막 갱신" 참고. 이 항목을 끝으로
  총/도끼/곡괭이낫/낚싯대 4개 도구 전부가 캐릭터 애니메이션 프레임에 통합됐고, 옛
  옆 아이콘 오버레이 코드(`_held_item_sprite` 등)를 완전히 제거했다.
- INBOX #46 완료 (바퀴 55, QA 관찰): 총을 든 캐릭터 4방향(idle/발사) 스크린샷을
  `_verify_gun_motion.gd`(커밋 전 삭제)로 찍어 직접 눈으로 검수했다. 결함 2건 발견 —
  (1) 동/서 발사 시 총구 불꽃이 총구(바라보는 쪽 끝)가 아니라 반대쪽(몸에 가까운 쪽)에서
  나타남 → INBOX #47로 등록, (2) 남/북에서 총이 조준 방향(위/아래)과 무관하게 완전히
  좌우 수평으로 몸에 걸쳐 들려 있음 → INBOX #48로 등록. DESIGN.md "QA 관찰 항목" 형식대로
  #47/#48 뒤에 동일 내용의 "QA 재확인" 항목 #49를 추가해 재검증 루프를 이어지게 했다.
  이 항목 자체에서는 그림/코드를 고치지 않았다(관찰·티켓 발행까지만). 부수적으로 세션
  시작 시 INBOX #45가 실제로는 미완료(코드 미커밋 + 낚시 모션 합성 결함)였음을 발견해
  재오픈했다(별도 커밋 692b0a4로 먼저 처리) — 이후 바퀴 56이 #45를 재작업해 완료함(위
  "마지막 갱신" 참고). 총 idle/발사 모션 4방향을
  실제 스크린샷으로 검수해 결함 2건(동/서 발사 시 총구 불꽃 위치 반대, 남/북에서 총이
  조준 방향과 무관하게 수평으로 들림)을 발견하고 #47/#48/#49로 티켓 발행. 부수적으로
  INBOX #45가 실제로는 미완료(코드 미커밋 + 낚시 모션 합성 결함)였음을 발견해 재오픈함
  (별도 커밋 692b0a4로 먼저 처리).
- INBOX #44 완료 (바퀴 53): 곡괭이낫의 "들고 있는"/"채광하는"/"채집하는" 세 모션을
  `_held_item_sprite` 오버레이 대신 캐릭터 애니메이션 프레임(`pickaxe_idle_<dir>`/
  `pickaxe_mining_<dir>`/`pickaxe_gathering_<dir>`)에 통합했다(총(#42)/도끼(#43)와 동일한
  패턴). 이전(미커밋 상태로 죽은) 세션이 `/tmp/pickaxe_gen/pl.py`/`build_remaining.py`로
  이미 레시피(기존 검증된 도구 아이콘 `pickaxe.png`/`pickaxe_mining.png`/
  `pickaxe_gathering.png`을 PIL로 캐릭터 베이스에 합성 → 손 연결부만 PixelLab
  `/inpaint`로 다듬음 → `/rotate`로 south→east/north → west는 PIL 좌우반전)을 정립해뒀고,
  green/blue는 이미 36장 중 24장이 끝나 있었다 — red만 south 인페인트+회전을 이어서
  완료해 36장(3색×4방향×3모션)을 채웠다. 코드: `play_pickaxe_use(kind)`가 더 이상
  `_play_tool_swing()`으로 옆 아이콘을 바꾸지 않고 `_pickaxe_use_kind`를 기록한 뒤
  `_tool_use_flash_timer`만 설정하도록 바꿨고, `_current_animation_name()`에 pickaxe
  분기(마이닝/채집/idle 셋 중 고름)를 추가했다. `_select_hotbar()`/`_physics_process()`의
  텍스처 리셋 조건에 `"pickaxe"`를 총/도끼와 같은 예외로 추가했다. 이제 안 쓰이는
  `PICKAXE_USE_ICONS` 상수(옆 아이콘용 mining/gathering 텍스처)는 제거했다 — `TOOL_ICONS`의
  `"pickaxe"`(핫바 아이콘)는 그대로 유지.
  - 검증: green/blue 콘택트시트(합성 결과 PNG 직접 확대)로 눈으로 확인 — 도끼 때와 동등한
    수준(손-도구 연결이 자연스럽고 채광/채집 모션이 서로 다른 그림으로 뚜렷이 구분됨).
    강제 재임포트(`godot --headless --path . --import`) 후 `game/_verify_pickaxe_motion.gd`
    (커밋 전 삭제)로 world 씬을 실제 렌더링 드라이버로 띄우고
    `set_physics_process(false)` → `_facing`/`_held_tool="pickaxe"`/`_pickaxe_use_kind`/
    `_tool_use_flash_timer`를 강제 설정 → `_update_player_animation()` → 4프레임 대기 →
    캡처를 12가지 상태(south/east/north/west × idle/mining/gathering, green)에 대해
    반복했다 — 콘솔에 `anim=pickaxe_idle_south` 등으로 애니메이션 전환이 코드대로 동작함을
    확인했고, 크롭한 콘택트시트를 직접 눈으로 봤을 때도 자연스러웠다. 예산 문제로 blue/red는
    게임 내 스크린샷 대신 PNG 확대 검수로만 확인했다(#42/#43과 같은 방식).
  - 변경 파일: `game/scenes/world/world.gd`,
    `game/assets/sprites/character/pickaxe/*.png`(+`.import`, 신규 72개 파일).
- INBOX #43 완료 (바퀴 52): 도끼의 "들고 있는"/"패는" 모션을 `_held_item_sprite` 오버레이
  대신 캐릭터 애니메이션 프레임(`axe_idle_<dir>`/`axe_chop_<dir>`)에 통합했다(총(#42)과
  동일한 패턴). **작업 자체는 이전 바퀴(51 이후, STATUS에 기록되지 않은 세션)가 이미
  east/west `/rotate` 결함을 풀고 24장(3색×4방향×idle/chop)을
  `game/assets/sprites/character/axe/`에 복사 + `world.gd` 통합까지 끝내놓았으나, 커밋/
  문서 갱신 전에 예산 초과로 죽어서 미커밋 상태로 남아 있었다** — 이번 바퀴는 이 상태를
  검수만 하고 커밋했다(그림을 새로 만들지 않음). 검수 내용: (1) 24장 PNG를 확대해 직접
  검사 — south/north는 물론 이전에 결함(다리 겹침)이 있었던 east/west chop도 자연스러운
  옆모습 내려찍기 자세였다(3색 전부), (2) `world.gd` diff가 `_build_player_sprite_frames`/
  `_current_animation_name`/`_select_hotbar`/`_unhandled_input`/`TOOL_USE_ICONS`를 총(#42)
  패턴 그대로 따르고 있음을 확인, (3) `game/_verify_axe_motion.gd`(커밋 전 삭제)로 world
  씬을 실제 렌더링 드라이버로 띄우고 `set_physics_process(false)` 후 `_facing`/
  `_held_tool="axe"`/`_tool_use_flash_timer`를 강제 설정 → `_update_player_animation()` →
  4프레임 대기 → 캡처를 8가지 상태(south/east/north/west × idle/chop, green)에 대해
  반복해 실제 게임 렌더링으로 재확인 — 콘솔에 찍힌 `anim=axe_idle_south` 등으로 애니메이션
  전환도 코드대로 동작함을 확인했다. 8장을 크롭해 콘택트시트로 합쳐 직접 눈으로 봤을 때
  전부 자연스러웠다 — 합격 기준(①) 통과로 판단. blue/red는 게임 내 스크린샷 대신 PNG
  확대 검수로만 확인했다(예산 절약, #42/#47 때와 같은 방식).
  - 변경 파일: `game/scenes/world/world.gd`,
    `game/assets/sprites/character/axe/*.png`(+`.import`, 신규 48개 파일, 이전 세션 생성).
- INBOX #42 완료 (바퀴 47): 총의 "들고 있는"/"발사하는" 모션을 `_held_item_sprite` 옆
  아이콘 오버레이 대신 캐릭터 애니메이션 프레임 자체(`gun_idle_<dir>`/`gun_fire_<dir>`,
  DESIGN.md "캐릭터 애니메이션")로 통합했다. **바퀴 46이 `/tmp/gun_gen/`에 남겨둔 생성물이
  이 머신에서 세션이 지나도 지워지지 않는다는 것을 다시 확인했다** — 그 디렉터리에 이미
  green(전 방향 idle/fire, inpaint+rotate 결과) 전체와 blue/red의 south/east/north까지
  생성돼 있었다. west만 빠져 있어서 PIL로 east를 좌우반전해 만들고(캐릭터 west 텍스처를
  만들 때 쓰던 것과 같은 방식), blue/red 콘택트시트를 새로 만들어 직접 눈으로 검수했다 —
  둘 다 green과 같은 수준으로 자연스러웠고(총과 손이 자연스럽게 붙어 있음, 발사 시 총구
  불꽃 뚜렷), red의 대머리(짧은 스포츠머리)도 기존 `red_south.png` 베이스 캐릭터와
  일치해 이질감이 없었다. 최종 24장(3색×4방향×idle/fire)을
  `game/assets/sprites/character/gun/{variant}_{dir}_{idle,fire}.png`로 복사하고
  `godot --headless --path . --import`로 강제 재임포트했다.
  - 코드: `world.gd`의 `_build_player_sprite_frames()`에 방향별
    `gun_idle_<dir>`/`gun_fire_<dir>` 애니메이션(각 1프레임)을 추가했고,
    `_current_animation_name()`이 `_held_tool == "gun"`이면 `_tool_use_flash_timer`
    값(발사 직후 0.12초 동안 >0)에 따라 이 둘 중 하나를 반환하도록 바꿨다.
    `_select_hotbar()`는 총을 선택했을 때 `_held_item_sprite`를 아예 숨기도록(총 전용
    분기) 바꾸고, `_fire()`에서 옆 아이콘 텍스처를 바꾸던 코드를 지우고 타이머만 설정하게
    했다. `TOOL_USE_ICONS`에서 `"gun"` 항목(구 `gun_firing.png` 참조)을 제거했다 —
    INBOX #42 원문이 명시한 "총에 한해 제거" 범위를 지켰다(도끼/곡괭이낫/낚싯대는 여전히
    `_held_item_sprite` 오버레이 방식 그대로, #43~#45 몫).
  - **걷는 동안 총을 든 상태 처리(바퀴 46이 결론 못 낸 부분)는 옵션A로 결정해 구현했다**:
    걷기 전용 총 프레임(walk_gun, 그림 24장 추가 필요)은 만들지 않고, 이동 중에도
    `gun_idle_<dir>` 프레임을 그대로 쓴다(다리 애니메이션은 멈추지만 총은 계속 보임).
    근거: DESIGN.md "도구 동작 표현"이 총에 대해 "들고 있기/발사" 두 상태만 명시하고
    walk-with-gun은 언급이 없어 임의로 확장하지 않았고, 최소한 이전 오버레이 방식(이동
    중에도 총이 계속 보이던 것)과 같은 수준을 유지해 회귀를 막는 것을 우선했다. 나중에
    지시가 오면 walk_gun 프레임을 추가로 그려 넣는 방향으로 확장할 수 있다(아래 "다음에
    할 것"에 #43~#45용 레시피로 재사용 가능하다고 남김).
  - 검증: `game/_verify_gun_motion.gd`(커밋 전 삭제)로 world 씬을 실제 렌더링 드라이버로
    띄운 뒤 `set_physics_process(false)`로 마우스 추종을 끄고 `_facing`/`_held_tool`/
    `_tool_use_flash_timer`을 직접 설정 → `_update_player_animation()` 호출 → 3프레임
    대기 → 캡처를 green 기준 4방향×{idle,fire} 8장에 대해 반복했다. 콘솔에 찍힌
    `anim=gun_idle_south`/`gun_fire_south` 등으로 애니메이션 이름 전환이 코드대로
    동작하는 것도 함께 확인했다. 스크린샷을 크롭해 콘택트시트로 합쳐 직접 눈으로 봤을 때
    4방향 모두 총과 손이 자연스럽게 붙어 있고, 발사 프레임에서 총구 불꽃이 뚜렷했다 —
    합격 기준(①) 통과로 판단했다. 예산 문제로 blue/red는 게임 내 스크린샷 대신 위
    콘택트시트(PixelLab 원본 이미지 직접 비교)로만 검수했다.
  - 변경 파일: `game/scenes/world/world.gd`,
    `game/assets/sprites/character/gun/*.png`(+`.import`, 신규 48개 파일).
- INBOX #41 완료 (바퀴 44): 로컬 플레이어(`world.tscn`의 `Player` 노드)를 `Sprite2D`에서
  `AnimatedSprite2D`로 바꿨다. `world.gd`에 `_build_player_sprite_frames(variant)`를
  추가해 방향별(south/north/east/west) idle(기존 정지 이미지 1프레임 재사용)과
  walk(신규 4프레임) 애니메이션을 담은 `SpriteFrames`를 런타임에 조립한다. walk
  프레임은 PixelLab `/animate-with-text`로 blue/green/red 3색 x 4방향 = 12세트를
  생성했다(`assets/sprites/character/walk/`). **바퀴 43이 실패했던 이유(남/북에서 다리가
  안 움직이거나 옆모습으로 돌아섬)는 프롬프트를 복잡하게 줄수록 오히려 나빠지는
  경우였다 — `action` 필드를 길게 지시문을 쓰는 대신 단순히 `"walk"` 한 단어만 주고
  `image_guidance_scale`/`text_guidance_scale`도 기본값(오버라이드 없음)으로 두니
  4방향 전부 캐릭터 정체성 유지 + 뚜렷한 다리 교차가 한 번에 나왔다.** (참고:
  API가 `description` 필드를 필수로 요구한다는 것도 이번에 새로 확인 — 바퀴 43
  메모에는 없던 사실, 안 주면 422.) 12세트 중 `green_east`만 첫 생성에서 완전히
  다른(흰색/일그러진) 캐릭터로 실패해 같은 파라미터로 1회 재생성해 통과시켰다 —
  나머지 11세트는 첫 생성에서 바로 합격 수준이었다.
  - 검증: `world.tscn`을 실제 렌더링 드라이버로 띄운 뒤 `set_physics_process(false)`로
    마우스 추종을 끄고 `_facing`/`_is_moving`을 스크립트에서 직접 설정 →
    `_update_player_animation()` 호출 → 몇 프레임 대기 → 캡처를 idle_south,
    walk_south(2프레임), walk_east(2프레임)에 대해 반복해 스크린샷 5장을 찍었다.
    walk 두 프레임 사이에 다리 위치가 뚜렷이 달라지는 것을 직접 눈으로 확인해
    합격 기준(①) 통과로 판단했다. 예산이 매우 빠듯해(바퀴 43이 이미 세션 예산의
    대부분을 시행착오로 소진해 이번 바퀴도 $2 중 대부분을 이 검증까지 쓴 상태)
    12세트 전체(3색x4방향)를 스크린샷으로 개별 검증하지는 못하고, PixelLab이
    반환한 프레임 이미지 자체를 grid로 합쳐 직접 눈으로 훑어보는 것으로
    나머지의 품질을 판단했다(위 green_east 실패도 이 방식으로 발견).
  - 이번 항목 범위(도구 없는 맨몸)를 지켰다: 총 아이콘은 여전히 기존
    `_held_item_sprite` 오프셋 방식으로 옆에 떠 있다(스크린샷에서도 보임) —
    DESIGN.md/INBOX #41 원문대로 도구 통합은 #42~#45 몫으로 남겨뒀다.
  - 변경 파일: `game/scenes/world/world.tscn`(Player 노드 타입),
    `game/scenes/world/world.gd`(`_build_player_sprite_frames`,
    `_update_player_animation`, `_current_animation_name`, `_update_texture` 제거),
    `game/assets/sprites/character/walk/*.png`(+`.import`, 신규 48개 파일).
- INBOX #40 완료: 낚싯대의 "낚시하는 모션"을 별도 그림으로 분리(들고 있는 모션은 기존
  `fishing_rod.png` 그대로 재사용 — #37/#38/#39와 같은 패턴). PixelLab
  (`/generate-image-pixflux`, 32x32, no_background, 기존 `fishing_rod.png`을
  `color_image`로 줘서 팔레트/각도 통일)로 `fishing_rod_fishing.png`(낚싯대가 휘어지고
  줄이 팽팽하게 늘어져 바늘이 매달린 그림)을 생성했다. 첫 시도는 프롬프트가 막연해서
  "낚싯대를 든 작은 사람 전체"가 그려져 나왔다(다른 도구 아이콘들은 전부 "도구 자체만"
  그려져 있어 스타일 불일치) — 프롬프트에 "no person, no hand, item icon only, 기존
  구도와 동일한 대각선"을 명시해서 재생성해 통일했다. `world.gd`의 `TOOL_USE_ICONS`
  딕셔너리에 `"fishing_rod"` 키만 추가했고, 기존 `_unhandled_input`의 axe/fishing_rod
  공용 분기가 이미 `_play_tool_swing()`을 호출하고 있어 이 이상 코드 변경은 필요 없었다
  (STATUS.md 이전 메모가 예측한 대로 가장 단순한 케이스였음).
  - 검증: `game/_verify_fishing_motion.gd`(커밋 전 삭제)로 world 씬을 실제 렌더링
    드라이버로 띄운 뒤 south/east/north/west 4방향 × holding/fishing 2상태로 강제
    전환하며 스크린샷 8장을 찍어 직접 확인했다. **처음 시도에서 `set_physics_process
    (false)`를 빼먹어서 4방향이 전부 같은(마우스 추종에 의해 덮어써진) 옆모습으로
    찍히는 문제를 겪었다** — world.gd의 `_physics_process`가 매 프레임 마우스 방향으로
    `_facing`을 다시 계산해 덮어쓰기 때문(바퀴 37 결정 로그에 이미 있던 주의사항인데
    이번에 빠뜨렸다가 재확인). `set_physics_process(false)`를 추가하고 나서 4방향이
    정상적으로 구분되어 찍혔고, 들고 있기(직선 낚싯대)와 낚시(휜 낚싯대+바늘)이 뚜렷이
    다른 그림으로 보이며 도끼/곡괭이낫과 비슷한 수준으로 자연스러웠다 — 합격 기준(①)
    통과로 판단.
  - 변경 파일: `game/scenes/world/world.gd`,
    `game/assets/sprites/tools/fishing_rod_fishing.png`(+`.import`).

## 다음에 할 것

- **(바퀴 83 갱신, 최우선) 다음 미완료 항목은 INBOX #56(`[QA] 전체 스윕`)이다 — 이번
  DESIGN 하네스가 처리할 항목이 아니라 `[QA]` 하네스(`PROMPT_QA.md`) 몫이다.** DESIGN
  하네스가 다음에 열렸는데 남은 `[DESIGN]` 항목이 없다면 정상 상황이다. 세션 시작 시
  잔액 확인은 여전히 습관적으로 할 것 — 바퀴 83 종료 시점 SpriteCook 약 1180크레딧대
  (1828에서 648 소모), PixelLab 여전히 $0.
- **헤드리스가 아닌 실제 렌더러로 게임 상태를 강제 조작해 스크린샷을 찍어야 할 때는
  `--script` 단독 실행이 아니라 `project.godot`의 `[autoload]`에 검증용 스크립트를
  임시로 추가하고 일반 실행(`godot --path .`)하는 방법을 쓸 것(바퀴 82가 새로 확인 —
  `--script` 단독 실행은 autoload 싱글턴이 초기화되지 않아 `InventoryData` 등을 쓰는
  씬 스크립트가 컴파일 에러로 전부 실패한다). 검증 후 `project.godot`/임시 스크립트는
  반드시 원상복구하고 커밋에 포함하지 말 것. **여러 상태를 순차 캡처하는 스크립트를 짤
  때는 "시작 대기"와 "스텝별 대기"에 같은 카운터 변수를 재사용하지 말 것**(바퀴 83이
  실제로 이 실수로 마지막 캡처 1개를 놓쳤다 — 아래 바퀴 83 항목 7번 참고).
- **BUILD/DESIGN 완료 카운터: 바퀴 83(#55)으로 5에 도달해 INBOX #56(QA 전체 스윕)을
  큐에 추가하고 0으로 리셋했다.** 다음 BUILD/DESIGN 5개 완료 시 다시 QA 스윕을 추가할 것
  (PROMPT_BUILD.md ③ / PROMPT_DESIGN.md ③과 동일 규칙).
- 다음 지시가 들어오면 참고할 만한 백로그(강제 사항 아님, 아래 "막힌 것/보류"·"오래된
  메모" 참고):
  - 멀티플레이 실제 두 클라이언트 접속/동기화를 실기기로 아직 검증 못함.
  - 농사 성장 시간(60초)이 여전히 실시간 초 단위(게임 내 날짜 기준 아님).
  - 목장 개체 수 제한/재포획(다시 꺼내기) 기능 없음.
  - 총을 든 채 이동할 때 다리 걷기 애니메이션이 멈춘다(옵션A, 도끼도 동일하게 적용됨) —
    지시가 오면 walk_gun/walk_axe 프레임(그림 추가)을 그려서 옵션B로 확장할 수 있다.
  - 스크립트로 world.gd의 `_facing`을 강제 조작하며 검증할 때는 **반드시
    `world_node.set_physics_process(false)`를 먼저 호출할 것** — 안 하면 마우스 추종
    로직이 매 프레임 `_facing`을 덮어써서 4방향 스크린샷이 전부 같은 방향으로 찍힌다.
- **아직 남아 있는 오래된 메모(여전히 유효)**:
  - 멀티플레이 실제 두 클라이언트 간 연결/동기화를 실기기(스크린샷 등)로 아직 검증하지
    못했다(바퀴 17부터 이월 — 아래 "막힌 것/보류", "헤드리스 CLI 검증" 참고).
  - 농사(farm_plot)의 성장 시간(60초)은 여전히 게임 내 날짜 기준이 아니라 실시간 초
    단위다 — DESIGN.md에 기준이 명시되어 있지 않아 임의로 바꾸지 않고 있다. 다음 지시가
    오면 그때 정할 것.
  - 목장은 여전히 개체 수 제한이나 "다시 꺼내기" 기능이 없다.
  - 곡괭이낫/낚싯대는 좌클릭 시 최소 스윙 애니메이션만 있고 실제 결과물(채광·채집은
    있음, 낚시는 없음)이 없다(DESIGN.md "범위 밖"에 명시돼 있어 의도된 상태).
  - **새 배경/바닥용 스프라이트를 world.tscn에 추가할 때는 `Ground`(z_index=-2)보다는
    위, `Player`(기본값 0)보다는 아래인 `z_index=-1`을 기본으로 줄 것.**
  - **낮/밤에 따라 화면 밝기가 바뀌는 게 정상 동작이다** — 스크린샷 QA에서 화면이 어둡게
    나와도 렌더링 버그가 아니라 `TimeData.is_day`/`is_raining` 상태일 수 있으니 먼저
    확인할 것.
  - **스프라이트 PNG 파일을 교체할 때는 반드시 `godot --headless --path . --import`로
    강제 재임포트한 뒤 스크린샷으로 재검증할 것.**
  - **F키 상호작용 방식은 사용자가 명시적으로 거부했다 — 새 상호작용 오브젝트도
    좌클릭+`get_held_tool()`/`get_held_item()` 패턴을 쓸 것, F키로 되돌리지 말 것.**
  - **세션이 예산 초과로 죽으면 미커밋 변경이 작업 디렉터리에 그대로 남을 수 있다
    (바퀴 3, 바퀴 51→52, 바퀴 54→55 세 차례 확인).** 새 세션을 시작할 때 `git status`로
    이미 완료된 작업이 미커밋 상태로 남아있지 않은지 먼저 확인하고, 있다면 처음부터
    다시 만들지 말고 **먼저 실행해서 눈으로 검수**한 뒤에만 재활용할 것 — 검수 없이
    그대로 커밋하지 말 것(바퀴 54→55에서 실제로 검수 결과 불합격 판정이 나온 사례 있음,
    위 "마지막 갱신" 참고).
  - **(바퀴 55 신규) INBOX.md의 완료 체크박스(`- [x]`)와 그 항목의 실제 코드/에셋
    커밋이 서로 다른 git 커밋으로 분리되어, 문서는 "완료"인데 코드는 없는 상태가 생길
    수 있다.** 바퀴 54가 낚싯대 통합 코드를 작업 디렉터리에 미커밋 상태로 남긴 채
    죽었는데, `#45 완료` 체크박스와 `#46` 신규 등록은 INBOX.md만 건드리는 별도의 작은
    커밋(65d303e)으로 먼저 들어가 있었다 — 아마 그 세션이 "문서 갱신 먼저, 코드 커밋은
    나중에"로 커밋을 나눴다가 코드 커밋 전에 죽은 것으로 보인다. **다음 바퀴가 주의할
    점**: INBOX.md가 어떤 항목을 완료로 표시하고 있다는 사실만으로 그 작업이 실제로
    존재/커밋됐다고 믿지 말 것 — 항상 관련 코드/에셋 파일이 실제로 있는지(`git log`로
    해당 파일이 커밋됐는지, `git status`로 미커밋 상태가 아닌지)까지 함께 확인할 것.

## SpriteCook API 실측 조사 (바퀴 69 신규 — 다음 DESIGN 바퀴 필독)

DESIGN.md가 "캐릭터/동물 애니메이션 전담 도구"로 지정한 SpriteCook을 이번 바퀴에서
처음으로 실제 호출했다. 문서화된 `/api-docs` 페이지에는 `generate`/`animate` 파라미터만
상세히 나와 있고, 캐릭터 전용 신규 엔드포인트(`characters`, `characters/{id}/animations`,
`character-workflows`, `character-animation-runs`)는 이름만 나열돼 있어(문서 미완성),
실제 스펙은 API를 직접 두드려서 알아냈다. 아래 내용을 재조사하지 말고 그대로 재사용할 것.

- **인증/베이스**: `https://api.spritecook.ai`, 헤더 `Authorization: Bearer $SPRITECOOK_API_KEY`.
- **잔액 확인(무료)**: `GET /v1/api/credits` → `{"total":N,"subscription_credits":N,"topup_credits":N,"tier":"free","concurrent_jobs":1}`. 이번 바퀴 시작 시 40이었고, 끝날 때 8이었다.
- **모델별 단가 조회(무료)**: `GET /v1/api/models` — `generate`류 호출의 이미지 1장당 비용을 모델/해상도/품질별로 보여준다. 기본 모델(`gemini-3.1-flash-image`, "Nano Banana 2")은 1K 기준 12크레딧/장.
- **자산 무료 업로드**: `POST /v1/api/assets/import` `{"image": "data:image/png;base64,<...>"}` → **크레딧 소모 없음**. 기존 레포 PNG(`green_south.png` 등)를 SpriteCook 쪽 `asset_id`로 등록할 때 이걸로 충분하다. 응답의 `id`가 `asset_id`.
- **캐릭터 베이스 생성**: `POST /v1/api/characters` `{"prompt": "...", "perspective": "topdown"|"platformer"|"isometric"}` → 비동기 job(`job_id`, `poll_url`)을 큐에 넣고 **12크레딧**(`base_character_credit_cost`) 소모. `GET /v1/api/jobs/{job_id}`로 폴링하면 완료 시 `character_id`와 `assets[0].url`(서명된 다운로드 URL, 1시간 유효)을 준다. **이 엔드포인트는 우리 게임처럼 이미 확정된 정지 이미지가 있는 경우엔 쓸 이유가 없다** — 애니메이션 전용 워크플로우(`characters/{id}/animations`)에 넣을 "기준 캐릭터"가 아직 없을 때만 필요.
- **공식 캐릭터 워크플로우 카탈로그(무료 조회)**: `GET /v1/api/character-workflows` → `perspective`별(`platformer`/`isometric`/`topdown`) 사용 가능한 애니메이션 목록과 가격을 전부 준다. **`topdown` 워크플로우가 정확히 우리가 원하는 것**(`idle`, `idle_back`, `idle_right`, `idle_left`, `walk_up`, `walk_down`, `walk_right`, `walk_left`, 그 외 run/attack/hurt/death)이지만:
  - 애니메이션 1개당 기본 20크레딧(`credit_costs.basic`).
  - 기준 시점(`front`)이 아닌 소스뷰(`back_*`/`right_*`/`left_*`)를 처음 쓰는 애니메이션마다 **`prep_credit_cost` 12크레딧이 추가**로 붙는다(그 방향의 "포즈 준비" 단계가 먼저 필요하기 때문으로 보임).
  - 즉 green 한 색만 idle+walk 4방향(정면 제외 3방향에 prep 필요)을 채우려면 최소 `20(idle_front) + 32×3(idle_back/right/left) + 32×3(walk_up/right/left, walk_down도 prep 필요하면 32)` 식으로 **180크레딧 안팎**이 든다 — 무료 티어 총량(40)의 4배 이상이라 이 경로는 지금 예산으로 불가능하다고 판단, 실제 호출은 하지 않았다(가격 조회만).
  - `POST /v1/api/characters/{character_id}/animations`의 필수 바디 필드는 `perspective`뿐이라는 것만 확인했다(빈 `{}` → `perspective` 필수 에러, `{"perspective":"topdown"}`만 → `asset_not_found`로 다음 단계 진행). 나머지 필드(어떤 `animation_ids`를 요청하는지 등)는 예산 문제로 실제 성공 호출까지 가보지 못해 스키마를 다 확인하지 못했다 — 다음에 이 경로를 쓴다면 여기서부터 이어서 조사할 것.
- **범용 애니메이트(더 저렴한 대안)**: `POST /v1/api/animate-sync` `{"asset_id": "...", "prompt": "...", "output_frames": 4, "output_format": "spritesheet", "pixel": true}` — 기존 자산 1장을 애니메이션으로 변환, **prep 비용 없이 20크레딧 고정**(이번 바퀴 실측: `output_frames=4`에서도 20크레딧, 프레임 수가 가격에 영향을 주는지는 미확인이나 최소 20 이하로는 안 내려가는 듯). 응답은 `output.spritesheet_url`(가로로 이어붙인 프레임 시트 PNG, 배경 알파 정상 투명)과 `output.url`(webp 애니메이션), `output.metadata.frame_count/fps/frame_width/frame_height`. **무료 티어로 4방향×걷기만 채우려면 이 경로가 현실적** — idle은 기존 정지 이미지를 그대로 쓰고(#50 원문이 허용), walk만 방향당 1콜(20크레딧)씩 총 80크레딧이면 되지만 그래도 이번 바퀴 잔여 8크레딧으로는 부족하다.
- **⚠️ 함정 — 스키마 탐색용 호출이 실제 유료 작업을 실행시킴**: `POST /v1/api/characters`에 필수 필드(`prompt`, `perspective`)를 전부 채운 채 "혹시 모르는 필드를 넣으면 거부하나?"를 확인하려고 `totally_bogus_field`를 얹어서 보냈더니, SpriteCook은 **알 수 없는 필드를 그냥 무시하고 요청을 정상 실행**했다(pydantic이 extra field를 forbid하지 않음) — 그 결과 프롬프트 `"test"`로 진짜 캐릭터 생성 job이 돌아 12크레딧을 낭비했다(다행히 결과물 자체는 초록 조끼를 입은 캐릭터라 이번 바퀴 개념 검증에 재활용은 했다). **다음에 스키마를 탐색할 때는 필수 필드 중 최소 하나를 일부러 빼서 422를 유도할 것** — 모든 필수 필드를 채운 "완전한" 요청은 절대 탐색 목적으로 보내지 말 것(그대로 과금된다).
- 이 세션이 만든 SpriteCook 자산(재사용 가능, 서명 URL은 발급 후 1시간 뒤 만료되니 재다운로드 필요할 수 있음):
  - `character_id=9e05e047-4b7b-4d91-9433-6fdce67696f3`(prompt="test", perspective=topdown) — 초록 조끼 캐릭터, 88×88. `/tmp/sc_test_char.png`에 저장돼 있다.
  - `asset_id=9b40d298-4c59-444e-8895-b89432d630bb` — 우리 게임의 `green_south.png`를 그대로 임포트한 자산(68×68).
  - south 방향 4프레임 걷기 시험 결과(`animate-sync`, 20크레딧) — `/tmp/walk_south_sheet.png`(224×56, 56×56 프레임 4장)와 4배 확대본 `/tmp/walk_south_sheet_big.png`.
- **품질 판정(이번 바퀴가 south 시험 결과를 직접 눈으로 본 결론)**: 캐릭터 정체성/색/의상은 원본(`green_south.png`)과 일관되게 유지됐다(합격). 하지만 다리 부분만 잘라 4배 확대해서 비교한 결과, 1번 프레임은 "다리를 벌린" 뚜렷이 다른 자세인데 2~3~4번 프레임은 서로 거의 구분이 안 되는 "다리를 꼰" 자세라, 애니메이션으로 재생하면 좌우로 번갈아 딛는 자연스러운 걸음이 아니라 "한 번 튀었다가 멈춰 있는" 것처럼 보일 위험이 크다고 판단했다 — 스타듀밸리/코어키퍼의 또렷한 4단계 보행(왼발 착지-중립-오른발 착지-중립)과 다르다. 이 결론을 근거로 게임에 통합하지 않았다. **다음에 재시도할 때**: 프롬프트에 프레임별 발 위치를 명시적으로 지정(예: "frame 1: right foot forward contact, frame 2: passing neutral pose, frame 3: left foot forward contact, frame 4: passing neutral pose")하고, 받은 즉시 다리 부분만 크롭+확대해서(이번 바퀴가 쓴 방법: PIL로 프레임 분할 → 하반신만 크롭 → 4~6배 nearest 확대 → 가로로 이어붙여 한 이미지로 비교) 4프레임이 실제로 다른 자세인지부터 확인한 뒤, 다른 방향에 크레딧을 쓸지 결정할 것.
- **셸 관련 잡음(사소하지만 재현됨)**: 이 환경에서 `source loop/secrets.env`로 환경변수를 로드한 직후 같은 Bash 호출 안에서 `curl ... | tail`처럼 파이프를 쓰거나 `for` 루프 안에서 `curl`을 여러 번 부르면 간헐적으로 `command not found: curl`/`tail` 에러가 났다(원인 불명 — PATH는 정상이었음). 매번 `.sh` 파일에 스크립트를 써서 `bash file.sh`로 실행하면 안정적으로 동작했다 — 다음 바퀴도 curl 다중 호출은 임시 스크립트 파일 방식을 쓸 것.

### 바퀴 79 추가 조사 (INBOX #51 — blue/red 확장에 실제로 쓴 프롬프트 원문, 재사용 가능)

바퀴 78이 "다음 바퀴가 참고할 것"에서 프롬프트 전문을 별도 절에 남기겠다고 예고했지만
실제로는 쓰지 않았고 `/tmp` 스크립트도 남지 않아 원문을 복구하지 못했다(교훈: 예고만
하고 절을 비워두면 다음 바퀴가 그대로 헛수고를 반복한다 — 반드시 실제로 적어둘 것).
이번 바퀴가 새로 만들어 검증까지 마친 프롬프트를 아래에 그대로 남긴다.

- **공통 절차**: 소스 68px PNG를 PIL `Image.NEAREST`로 256px로 업스케일 → `POST
  /v1/api/assets/import`로 업로드(무료) → `POST /v1/api/animate-sync`에 아래 프롬프트로
  호출 → 결과 스프라이트시트를 68px 캔버스로 다시 `NEAREST` 다운스케일 + 알파 bbox
  바닥/가로중심을 기존 idle PNG의 bbox에 맞춰 정렬.
- **south(정면, `output_frames=4`)**: `"exaggerated marching walk cycle, front facing
  view, knees raised very high, legs spread wide apart between frames, strong dynamic
  weight shift, 4 clearly distinct walking poses, pixel art game character"`
- **north(후면, `output_frames=4`)**: south와 동일하되 `"front facing view"`를 `"back
  facing view"`로만 바꾼다.
- **east(측면, `output_frames` 생략 → API 기본값 8)**: `"natural side-view walking
  cycle, alternating legs, frame 1: right foot forward contact pose, frame 2: passing
  neutral pose, frame 3: left foot forward contact pose, frame 4: passing neutral pose,
  smooth walk animation, pixel art game character"` — 이 프롬프트는 바퀴 69/76이
  south에 썼다가 실패했던 것과 거의 같은 문구인데, **east(측면)에서는 첫 시도부터
  자연스럽게 성공**했다(바퀴 78의 발견을 이번에 blue/red에서도 재현). 즉 이 실패
  패턴은 프롬프트 문제가 아니라 정면/후면(대칭 실루엣)에서만 나타나는 시점 고유의
  한계로 보인다는 결론이 다시 한 번 뒷받침됐다.
- **west**: AI 생성하지 않는다. east 결과 프레임을 `PIL.ImageOps.mirror()`로 좌우반전한
  뒤, west idle PNG의 알파 bbox에 맞춰 재정렬한다(green_west가 green_east의 완전한
  반전이었던 것과 같은 패턴이 blue/red에도 그대로 적용됨을 픽셀 bbox 비교로 재확인).
- **색상 간 재사용 확인**: blue/red idle 스프라이트는 green과 실루엣이 사실상 동일(셔츠
  색만 다름)하므로, 위 프롬프트를 색상별 튜닝 없이 그대로 재사용해도 된다 — blue에서
  1건만 먼저 검증하고 나머지 5건(blue 나머지 2방향 + red 3방향)은 재검증 없이 바로
  진행했는데 전부 한 번에 합격 수준이 나왔다. **다음에 새 색상(예: 향후 코스튬 색 추가)을
  확장할 때도 이 순서(1건 검증 → 나머지 일괄 진행)를 재사용할 것.**
- 이 세션이 만든 SpriteCook 자산은 재사용 필요 없음(이미 게임에 통합·커밋 완료) —
  `/tmp/w51/`에 원본 시트/정렬 결과/인게임 스크린샷이 남아있으나 세션 종료 후 지워질
  수 있는 임시 디렉터리다.

### 바퀴 80 추가 조사 (INBOX #52 — generate-sync `edit_asset_id`로 총 든 모션 만들기, #53이 재사용할 프롬프트 원문)

- **엔드포인트**: `POST /v1/api/generate-sync`. 관련 파라미터: `prompt`(필수),
  `edit_asset_id`(수정할 기존 asset id), `width`/`height`(업로드 때와 같은 값을 줄 것),
  `pixel: true`, `bg_mode: "transparent"`, `smart_crop: false`(★ 아래 이유),
  `variations`(1~4, 개수만큼 12크레딧씩 곱해서 과금).
- **`smart_crop: false`가 핵심**: 기본값(`true`)은 결과를 콘텐츠 알파 bbox로 꽉
  크롭해버려서(예: 68x68 입력 → 48x48 출력) 기존 idle 이미지와 위치를 맞추려면 수작업
  정렬이 필요하다. `smart_crop: false`로 주면 입력과 같은 캔버스 크기·같은 캐릭터
  위치로 결과가 나온다(직접 확인: 원본 bbox 상단 y=9, 결과도 y=9~10 — 오차 1px
  이내). **입력 이미지를 업스케일할 필요도 없다** — 68px 원본을 그대로
  `/v1/api/assets/import`로 올려도 동일하게 잘 작동했다(걷기 애니메이션 때 하던 4배
  업스케일+NEAREST 다운스케일 후처리가 이 방식엔 불필요).
- **`reference_asset_id`와 `edit_asset_id`는 동시 사용 불가**(400 에러). 총의 생김새를
  참고 이미지로 주고 싶으면 못 쓴다 — 대신 프롬프트에 재질/구성요소를 구체적으로
  서술할 것(아래 프롬프트 참고).
- **south(정면) idle 프롬프트** (idle_south.png를 68px 그대로 업로드해 edit):
  `"Edit this pixel art character (front view, facing the viewer) to hold a rifle: a
  long gun with a brown wooden stock/handle and a dark gray metal barrel, similar to a
  hunting rifle. The character grips it with both hands raised in front of the chest,
  and the gun is held diagonally so the barrel end points clearly DOWNWARD and slightly
  forward, at roughly a 45-degree angle toward the bottom of the frame -- like aiming
  down at the ground just ahead of the character. The gun must be a clearly recognizable
  rifle silhouette (long barrel, wider stock at one end), at least half the height of the
  character, NOT a thin line, NOT a knife, and must NOT be held flat/horizontal across
  the chest. Keep the character's exact identity, face, hair, outfit colors, body
  proportions, position within the frame, and pixel art style unchanged from the
  reference image -- do not move, resize, or recenter the character. Transparent
  background, crisp pixel art, no anti-aliasing blur, no extra text or UI."`
  (처음 이 프롬프트 없이 막연하게 "a small handgun held with both hands"로 시도했을 땐
  총이 가랑이 사이 얇은 막대/칼처럼 나와 불합격이었다 — "재질 서술 + NOT a thin
  line/knife" 문구가 품질을 갈랐다.)
- **north(후면) idle**: 위 south 프롬프트에서 "front facing view"→"back facing view",
  "DOWNWARD"→"UPWARD"(그리고 "toward the bottom"→"toward the top", "aiming down at
  the ground just ahead"→"aiming up and away into the distance ahead")로 바꾼 버전.
- **east(측면) idle**: `"Edit this pixel art character (side view, facing right) to hold
  a rifle: a long gun with a brown wooden stock/handle and a dark gray metal barrel,
  similar to a hunting rifle. The character grips it with both hands raised in front of
  the chest, aiming toward the right edge of the frame (the direction the character
  faces), barrel extended forward to the right, stock tucked near the shoulder/chest.
  The gun must be a clearly recognizable rifle silhouette (long barrel, wider stock at
  one end), at least half the height of the character, NOT a thin line, NOT a knife.
  Keep the character's exact identity, face, hair, outfit colors, body proportions, and
  position within the frame unchanged from the reference image -- do not move, resize,
  or recenter the character. Transparent background, crisp pixel art, no anti-aliasing
  blur."`
- **west**: 생성하지 않는다. east idle/fire 결과를 `PIL.ImageOps.mirror()`로
  좌우반전(기존 west가 east의 반전이었던 패턴, 걷기 때와 동일).
- **fire(발사) 프레임**: 새로 처음부터 만들지 않고, 방금 만든 idle 결과의 asset id를
  다시 `edit_asset_id`로 넣어 연쇄 편집한다(idle에서 이어서 편집하면 총 모양/각도가
  자연스럽게 유지됨). 프롬프트 예(south): `"Edit this pixel art character (already
  holding a rifle aimed downward toward the bottom of the frame) to show it FIRING the
  gun: add a small bright yellow/white muzzle flash burst at the barrel tip (the far end
  of the barrel, at the bottom of the frame), and give the character a slight recoil
  pose -- shoulders pushed back a tiny bit, gun kicked back slightly upward from its
  aiming angle. Keep the rifle the same recognizable shape and roughly the same angle
  (pointed down and forward), keep the character's exact identity, face, hair, outfit
  colors, body proportions, and position within the frame unchanged. Do not move or
  resize the character. Transparent background, crisp pixel art, no anti-aliasing
  blur."` — 다른 방향은 "pointed down and forward"/"bottom of the frame" 부분만 그
  방향에 맞게(위/오른쪽 등) 바꾸면 된다.
- **variations로 후보 여러 개를 한 번에 뽑아 고를 것을 권장**: `variations: 2~3`으로
  받은 뒤 8배 확대 콘택트시트를 만들어 직접 보고 가장 자연스러운 것을 선택하는 방식이
  1회 생성보다 훨씬 안정적으로 합격 수준이 나왔다(south는 variations:3 중 1개 선택,
  east/north는 variations:2 중 1개 선택).
- 이 세션이 만든 SpriteCook 자산은 전부 게임에 통합·커밋 완료라 재사용 불필요.
  `/tmp/gun52/`에 원본 응답 JSON/이미지/인게임 스크린샷이 남아있으나 임시 디렉터리다.

### 바퀴 82 추가 조사 (INBOX #54 — 곡괭이낫 idle/mining/gathering 프롬프트 원문, #55가 재사용할 것)

- 색상 언급이 전혀 없는 프롬프트라 blue/red에도 그대로 재사용 가능(#51/#53의 "색상별
  실루엣 동일" 전제와 같음).
- **south(정면) idle**: `"Edit this pixel art character (front view, facing the
  viewer) to hold a mattock-style pickaxe: a tool with a light brown wooden handle and
  a gray metal head that has a pointed pick on one end and a flat wide blade on the
  other end (like a real mining pickaxe/mattock, NOT a simple straight axe, NOT a thin
  line). The character grips the wooden handle with both hands, holding the tool
  diagonally in front of the body with the metal head near shoulder height, at rest
  (not swinging). The tool must be a clearly recognizable pickaxe silhouette, at least
  half the height of the character, with a visible wood-to-metal color transition.
  Keep the character's exact identity, face, hair, outfit colors, body proportions,
  position within the frame, and pixel art style unchanged from the reference image --
  do not move, resize, or recenter the character. Transparent background, crisp pixel
  art, no anti-aliasing blur, no extra text or UI."`
- **north(후면) idle**: 위에서 `"front view, facing the viewer"`→`"back view, facing
  away from the viewer"`, `"in front of the body"`→`"behind/beside the body"`로 바꾼
  버전(얼굴 관련 문구는 제거).
- **east(측면) idle**: `"Edit this pixel art character (side view, facing right) to
  hold a mattock-style pickaxe: ... (재질 서술 동일) ... The character grips the
  wooden handle with both hands, holding the tool diagonally across the body with the
  metal head near the right shoulder, pick tip pointing up and to the right, at rest
  (not swinging). ..."` (나머지는 south와 동일한 틀).
- **west**: 생성하지 않음. east(idle/mining/gathering 전부)를 `PIL.ImageOps.mirror()`로
  좌우반전.
- **mining(방향 공통, `{view_desc}`만 방향별로 치환)**: `"Edit this pixel art character
  (already holding a mattock-style pickaxe, {view_desc}) to show it MID-SWING mining
  downward into rock: the pickaxe is raised up and swung down so the pointed pick end
  strikes toward the ground in front of the character, arms extended downward and
  forward, body leaning into the swing with knees slightly bent for impact. Keep the
  pickaxe the same recognizable shape (wooden handle, pick point on one end, flat blade
  on the other end), keep the character's exact identity, hair, outfit colors, body
  proportions, and position within the frame unchanged. Do not move or resize the
  character. Transparent background, crisp pixel art, no anti-aliasing blur."` —
  idle의 채택된 asset_id를 `edit_asset_id`로 연쇄 편집해서 생성(새로 업로드하지 않음).
- **gathering(방향 공통)**: `"Edit this pixel art character (already holding a
  mattock-style pickaxe, {view_desc}) to show it MID-SWING gathering/harvesting crops:
  the pickaxe is swung low and to the side so the flat blade edge sweeps across low in
  front of the character at around knee height (like cutting/reaping low plants with a
  hoe), arms extended forward and to one side, body leaning into the swing, torso
  twisted slightly. This pose must look clearly different from a downward mining strike
  -- it is a horizontal sweeping motion, not a vertical chop. Keep the pickaxe the same
  recognizable shape (wooden handle, pick point on one end, flat blade on the other
  end), keep the character's exact identity, hair, outfit colors, body proportions, and
  position within the frame unchanged. Do not move or resize the character. Transparent
  background, crisp pixel art, no anti-aliasing blur."` — 이것도 idle의 asset_id에서
  연쇄 편집.
- **`view_desc` 매핑**: south="front view, facing the viewer", north="back view,
  facing away from the viewer", east="side view, facing right".
- **variations:3으로 받았는데도 세트마다 1개꼴로 66x68 등 어긋난 크기가 섞여 나왔다**
  (south mining/gathering 각 1개씩) — 68x68인 나머지 후보 중에서 고르는 것으로 충분히
  해결됐다(재시도 불필요). 완전히 실패(3개 다 어긋남)하는 경우는 이번엔 없었다.
- **mining과 gathering의 시각적 구분이 품질의 핵심이었다**: south/east는 variation들이
  대체로 잘 구분됐지만, north는 처음 골랐던 gathering 후보 2개가 mining과 거의 같은
  포즈였다 — 세 번째 후보(양팔을 벌려 곡괭이낫 전체 길이가 수평으로 다 보이는 넓은 스윙
  자세)를 대신 채택해서 해결했다. **다음에도 각 세트마다 mining과 gathering을 나란히
  놓고 비교해서, 너무 비슷하면 다른 variation을 시도할 것.**
- 이 세션이 만든 SpriteCook 자산은 전부 게임에 통합·커밋 완료라 재사용 불필요.
  `/tmp/pickaxe54/`에 원본 응답 JSON/이미지/인게임 스크린샷이 남아있으나 임시
  디렉터리다.

### 바퀴 76 추가 조사 (animate-sync 2회차 시도, 결론: 이 경로는 walk에 부적합해 보임)

- **`animate-sync`는 이름과 무관하게 비동기다.** 응답에 `output: null`, `job_id`,
  `poll_url`, `credits_used: 20`, `credits_remaining`이 바로 오고, 실제 결과는
  `GET /v1/api/jobs/{job_id}`를 폴링해야 나온다(이번엔 `status: "queued"`가 약 24회,
  3초 간격 폴링 기준 약 72초 지속되다 `"succeeded"`로 바뀜). 바퀴 69 노트에는 이
  비동기 동작이 기록돼 있지 않았다 — 다음에 이 엔드포인트를 쓸 때는 폴링 루프를 먼저
  준비할 것(`status in ["succeeded","failed"]`까지 반복, 실패 상태 문자열은 이번엔
  나오지 않아 미확인).
- **프롬프트를 극도로 구체적으로 써도(프레임별 발 위치 명시 + "4프레임이 뚜렷이
  달라야 한다" 강조) 바퀴 69와 동일한 실패 패턴이 재현됐다**: 프레임0만 이질적(다리
  벌린 정지 자세, 사실상 원본 idle과 거의 동일)이고 프레임1·2·3은 서로 거의 구분 안
  되는 "상체를 살짝 숙이고 다리를 모은" 자세로 수렴. 바운딩박스로 확인한 수치도 이를
  뒷받침한다 — 원본 idle(68 캔버스) bbox `(23,9,45,56)`, 생성된 4프레임(56 캔버스)
  bbox는 각각 `(17,9,39,56)`/`(19,5,37,55)`/`(19,7,37,54)`/`(19,7,37,55)`: 프레임0만
  캔버스 바닥(y=56)에 발이 닿고 나머지 셋은 전부 1~2px 위로 뜬 채 서로 거의 같은
  높이·폭이다.
- 실제 게임(`AnimatedSprite2D`, `walk_south` 애니메이션, 6fps)에 넣어 헤드리스로
  8프레임(루프 2회분) 스크린샷을 찍어 직접 눈으로 봐도 결론은 같았다 — PNG를 단순히
  확대해서 보는 것보다 실제 게임 렌더링에서 훨씬 명확하게 "1번만 튀고 나머진 거의
  정지"인 게 보였다.
- **결론/권장**: 프롬프트 튜닝으로는 이 문제가 해결되지 않는 것으로 보인다(서로 다른
  프롬프트로 2회 독립 재현). 다음에 SpriteCook으로 이 문제를 다시 풀려면 `animate-sync`
  대신 공식 `character-workflows`(topdown, `walk_down` 등 목적에 맞게 설계된 유료
  워크플로우, 방향당 20+12prep크레딧)를 시도해볼 가치가 있다 — 다만 이번 세션은
  예산(28크레딧)이 부족해 실제 호출까지 가보지 못했다. 그보다 먼저, **PixelLab 잔액이
  회복되면 `/animate-with-text`(바퀴 44/INBOX #41이 green 4방향 걷기에 실제로 성공시킨
  방식 — "walk" 한 단어 프롬프트 + 기본 guidance)를 우선 시도할 것을 권장한다** — 지금까지
  시도한 모든 방식 중 유일하게 자연스러운 좌우 교차 걸음을 만들어냈다.
- 이 세션이 만든 신규 SpriteCook 자산(재사용 가능, 서명 URL은 1시간 후 만료):
  - `asset_id=fe4996aa-6096-4b47-8891-0a036b3339e9` — `green_south.png` 재임포트본.
  - south 걷기 2차 시험 결과(job `959dac6b-ad5b-4151-8973-14c235b10e66`, 20크레딧) —
    `/tmp/walk50/walk_south_sheet.png`(원본 스프라이트시트), `/tmp/walk50/aligned/`(68x68
    캔버스로 정렬한 개별 프레임 4장), `/tmp/walk50/ingame_contact_sheet.png`(실제 게임
    렌더링 8프레임 대조표 — 다음 바퀴가 재판정 없이 바로 참고 가능).

## 헤드리스 CLI 검증 시 추가로 확인된 점 (다음 바퀴 참고)

- **(바퀴 16이 정정) 이전 바퀴 노트("오토로드는 `_init()` 대신 `_initialize()`에서 쓰면
  된다")는 부정확했다.** 실제로 확인해보니 `godot --script <script>.gd`로 실행하는
  스크립트에서는 오토로드 이름(`TimeData`, `CharacterData` 등)을 스크립트 어디서 정적
  식별자로 참조하든(`_initialize()` 안이든, 그 안에서 호출하는 별도 함수든) 컴파일 단계
  자체에서 "Identifier not found" 에러가 난다 — `--script` 모드는 일반 게임 실행과 달리
  오토로드를 컴파일러의 전역 식별자 목록에 등록해주지 않는 것으로 보인다. **해결책**:
  정적 식별자로 쓰지 말고 `get_root().get_node("TimeData")`처럼 문자열 경로로 동적
  조회할 것 — 이 방식은 `_initialize()`/`_ready()`류 어디서든 정상 동작한다(오토로드는
  씬 트리 루트의 자식 노드로 이미 추가돼 있으므로).
  - **(바퀴 82 추가) 이 노트를 놓치고 다시 같은 함정을 밟았다** — 검증 스크립트가 아니라
    `world.gd`/`farm_plot.gd` 등 **게임 자체의 스크립트**가 `InventoryData` 등을 정적
    식별자로 참조하고 있어서, 검증 스크립트만 동적 조회로 우회해도 게임 스크립트 쪽
    컴파일이 여전히 실패한다(위 해결책은 "검증 스크립트 자신이" 오토로드를 참조할 때만
    통하고, 이번처럼 로드하려는 씬의 기존 스크립트가 참조하는 경우엔 안 통한다). 이번
    바퀴는 대신 `project.godot`의 `[autoload]`에 검증용 스크립트를 임시로 추가해 일반
    실행(`godot --path .`, `--script` 없이)으로 오토로드를 정상 초기화시키고, 검증
    후 `project.godot`를 원상복구하는 방식으로 우회했다(위 "바퀴 82" 마지막 갱신 항목
    참고) — 씬 자체가 오토로드를 참조하는 경우엔 이 방법을 쓸 것.
- GDScript 람다(`func(x): ...`)는 바깥 함수의 지역변수를 **값으로 캡처**한다 — 람다 안에서
  그 변수에 대입해도 바깥 스코프에는 반영되지 않는다. 신호 콜백에서 "신호가 발생했는지"를
  기록하려면 `bool`/`int` 같은 값 타입 대신 `Array`/`Dictionary`(참조 타입)에 `append`하는
  식으로 우회할 것 — 이번 바퀴 검증 스크립트에서 `var ok := false` + 람다 안에서
  `ok = true`가 항상 `false`로 남는 것을 발견하고 `Array` 방식으로 바꿔 해결했다.
- `_initialize()`에서 씬을 `add_child`해도 `@onready` 변수는 그 즉시 채워지지 않는다
  (NOTIFICATION_READY가 다음 프레임에 전달됨). `_process(delta)`를 오버라이드해서 최소
  1~2프레임 지난 뒤에 값을 읽을 것.
- `queue_free()`로 예약된 노드는 실제 엔진 메인루프가 프레임을 처리해야 해제되므로,
  스크립트에서 직접 `_physics_process()`를 반복 호출하는 식의 "가짜 프레임 진행"으로는
  `is_instance_valid()`가 절대 false가 되지 않는다. 대신 `is_queued_for_deletion()`으로
  "해제가 예약됐는지"만 확인할 것.
- `--headless`로 실행하면 더미 렌더러가 붙어서 `get_texture()`가 null을 반환한다(화면
  캡처 불가). 화면을 실제로 캡처해야 하면 `--headless`를 빼고(`godot --path . --script
  ...`) 실제 렌더링 드라이버(OpenGL/Metal)로 띄운 채 실행할 것 — 바퀴 2 결정 로그의
  스크린샷 방식과 같은 원리이지만 `--headless` 유무가 갈린다는 점이 이번에 새로 확인됨.
  - **(바퀴 76 추가) `--headless`로 캡처를 시도하면 곧바로 null 에러가 나는 게 아니라
    먼저 약 3분간 아무 출력 없이 멈춘 것처럼 보이다가 결국 null 에러로 끝났다** —
    처음 보면 프로세스가 무한 행(hang)인지 그냥 느린 건지 구분이 안 돼서 시간을
    허비하기 쉽다. 화면 캡처 스크립트는 처음부터(재시도 없이) `--headless` 없는
    커맨드로 시작할 것.

- **(바퀴 38 신규) `--script <검증스크립트>.gd`의 최상단에서 `const X := preload("res://scenes/...tscn")`로
  씬을 미리 로드하면, 그 씬이 의존하는 스크립트들(예: world.tscn이 물고 있는 world.gd,
  farm_plot.gd 등)의 파싱이 검증 스크립트 자체의 컴파일 단계에서 함께 일어난다.** 이
  시점은 오토로드가 아직 전역 식별자로 등록되기 전이라, 그 스크립트들이 `CharacterData`/
  `InventoryData` 같은 오토로드를 정적 식별자로 참조만 해도(호출하지 않아도) "Identifier
  not found" 컴파일 에러가 나서 씬 전체가 로드 실패한다. **해결책**: 검증하려는 씬은
  최상단에서 `preload()`하지 말고, `_process()` 안에서 몇 프레임 지난 뒤
  `load("res://scenes/....tscn")`로 지연 로드할 것 — 이렇게 하면 오토로드가 이미
  등록된 뒤라 정상 컴파일된다. (바퀴 16 노트의 "오토로드를 정적 식별자로 못 쓴다"는
  검증 스크립트 자신에게만 해당하는 줄 알았는데, 이번에 그 씬이 물고 있는 다른 스크립트들의
  eager 파싱에도 똑같이 적용된다는 게 새로 확인됨.)

- **(바퀴 17 신규) `godot --script <script>.gd`(커스텀 SceneTree 메인루프) 안에서는
  `root`와 이미 트리에 들어가 있는 오토로드 노드들의 `multiplayer` 프로퍼티가 null이다.**
  정상 부팅(메인 씬을 로드하는 일반 실행)에서는 SceneTree가 root에 기본 SceneMultiplayer를
  붙여주지만, `--script`로 메인루프를 통째로 교체하면 이 단계가 빠진다. `_initialize()`
  안에서 `set_multiplayer(SceneMultiplayer.new())`(self가 SceneTree)를 호출해도 이미
  트리에 들어간 노드들의 `data.multiplayer` 캐시는 갱신되지 않는다(입장 시점에 캐시되고
  이후 재전파되지 않는 것으로 보임) — 즉 `--script` 모드로는 `multiplayer.*` API(peer 연결,
  RPC)를 다루는 코드를 안정적으로 자동 테스트할 방법을 이번 바퀴에서 찾지 못했다. 다음
  바퀴가 멀티플레이 코드를 헤드리스로 검증하려면 `--script`를 쓰지 말고, `godot --headless
  --path .`로 실제 main_scene을 정상 부팅시킨 프로세스를 (필요하면 두 개) 띄워서 확인할 것.

- **(바퀴 26 신규) `--script` 헤드리스 검증 스크립트를 반복 실행하면 `InventoryData`가
  이전 실행의 `user://inventory.save`를 그대로 이어받아 인벤토리가 뒤섞인 채로
  시작한다.** macOS 기준 `~/Library/Application Support/Godot/app_userdata/life_game/
  inventory.save`. 매번 깨끗한 상태에서 검증하려면 스크립트 실행 전에 이 파일을 지울
  것 — 실제 게임에서는 이 저장/불러오기가 의도된 동작(재시작해도 인벤토리 유지)이라
  코드를 고칠 문제가 아니라, 검증 스크립트를 실행하는 쪽에서 매번 정리해야 하는
  절차다.

- **(바퀴 40 신규) 스크린샷 검증 스크립트에서 "상태를 스크립트로 강제 설정 → 그 즉시
  같은 `_process` 호출 안에서 `get_root().get_texture().get_image()`로 캡처"하면, 찍히는
  이미지는 방금 설정한 상태가 아니라 그 직전 상태다.** 뷰포트 렌더링이 스크립트의
  `_process` 실행보다 한 프레임 늦게 반영되는 것으로 보인다 — 도끼 4방향 검증에서 "south"로
  설정했는데 "east"(옆모습)가 찍히는 식으로 결과가 한 단계씩 밀려 나오는 것으로 발견했다.
  **해결책**: 상태를 설정한 뒤 바로 캡처하지 말고, 최소 2~3프레임(`_wait` 카운터 등으로)
  기다린 다음에 캡처할 것 — "설정 → 대기 → 캡처" 순서를 지키면 밀림이 사라진다.
- **(바퀴 36 신규) `_initialize()`에서 `get_root().get_node("InventoryData")`로 오토로드
  참조를 얻은 그 즉시 `add_item()`을 호출하면 아이템이 조용히 사라진다.** `InventoryData`의
  `_general_slots` 배열은 자신의 `_ready()`에서 `resize(18)`이 호출돼야 실제 칸이 생기는데,
  다른 오토로드/노드와 마찬가지로 이 `_ready()`도 트리에 들어간 첫 프레임 이후에나
  실행된다(위 "`_initialize()`에서 씬을 add_child해도 @onready 변수는 즉시 채워지지
  않는다" 노트와 같은 원인). `add_item()`은 빈 배열(size 0)에 대해 두 for 루프를 그냥
  통과해버려서 에러 없이 조용히 실패한다. **해결책**: 오토로드에 값을 넣는 호출은 최소
  1프레임 이상 지난 뒤(`_process()`에서 프레임 카운터로 지연) 실행할 것.

- **(바퀴 80 신규) `get_root().get_visible_rect().size`(논리 좌표, 이 프로젝트에선
  1280x720)와 `get_root().get_texture().get_image().get_size()`(실제 캡처 픽셀 크기,
  이 환경에선 1920x1080 — 디스플레이 콘텐츠 배율 때문)가 다르다.** 스크린샷 크롭
  중심을 논리 크기 기준으로 계산하면 실제 캐릭터 위치와 어긋나서(이번엔 화면 중앙을
  잘랐는데 잔디밭만 찍힘) 캐릭터가 하나도 안 보이는 빈 크롭이 나온다. **해결책**:
  크롭 중심/범위는 항상 캡처한 `Image` 자신의 `get_size()`를 기준으로 계산할 것 —
  `get_visible_rect()`를 좌표 기준으로 쓰지 말 것.

## 막힌 것 / 보류

(진행하다 막힌 것, 판단을 미룬 것. 왜 미뤘는지도 함께)

- (바퀴 17) 다른 접속자가 쏜 총알이나 다른 접속자에 대한 사슴 도주 반응은 아직 로컬
  플레이어 기준으로만 동작한다(멀티플레이 상태 동기화는 위치/방향/외형만). INBOX #14
  원문이 "서로를 보고 움직이는 것까지"만 요구해서 이번 범위에 넣지 않았다 — 전투/AI를
  진짜 여러 명이 함께 겪게 하려면 서버 권위(누가 데미지/도주 판정의 기준인가) 설계가
  필요한데 DESIGN.md에 명시가 없다. 다음 지시가 오면 그때 정할 것.
- (바퀴 17) 실제 두 클라이언트 간 접속/이동 동기화를 실기기(스크린샷)로 검증하지 못했다
  (위 "끝난 것"과 "헤드리스 CLI 검증" 참고, `--script` 테스트 하네스 한계 + 예산 소진).
- (바퀴 55, 관찰만) 이번 바퀴 작업 도중 `git log`에서 이 세션이 만들지 않은 커밋
  (`7e0d581`, DESIGN.md에 "색상별로 쪼개기" 규칙 추가)이 내 첫 커밋(692b0a4)과 마지막
  커밋(08ffab2) 사이 시각(08:55:59)에 끼어든 것을 발견했다 — 커밋 메시지의
  `Claude-Session` ID가 앞서 있던 `65d303e`(바퀴 54가 남긴 것)와 같아서, 죽은 줄
  알았던 이전 세션이 실제로는 이 세션과 겹치는 시간에 계속 문서 커밋을 하고 있었던
  것으로 보인다. 파일이 겹치지 않아(내 커밋은 STATUS.md/INBOX.md만, 저쪽은 DESIGN.md만)
  이번엔 충돌이나 손실 없이 넘어갔지만, **같은 저장소에 두 세션이 동시에 커밋할 수
  있다는 뜻이므로 다음 바퀴가 이상한 git 히스토리(내가 안 만든 커밋)를 보면 당황하지
  말고 `git log`의 `Claude-Session` URL로 출처를 먼저 확인할 것.** 판단을 미룬 이유:
  이번엔 실질적 피해가 없어서 이 관찰 기록 이상의 조치가 필요한지 불확실 — 다음에
  실제로 파일이 겹쳐 충돌이 나면 그때 loop.sh의 동시 실행 방지 로직을 점검할 것.

## 결정 로그

(바퀴 중 내린 크고 작은 결정과 이유. 다음 바퀴가 되돌리지 않도록)

- 바퀴 76: south 방향 걷기 2차 시험(프레임별 발 위치를 명시한 구체적 프롬프트) 결과도
  게임에 통합하지 않고 폐기함. 근거: 바퀴 69와 완전히 다른 프롬프트를 썼는데도 똑같은
  실패 패턴(프레임0만 다르고 1·2·3은 near-duplicate)이 재현돼, 프롬프트 문제가 아니라
  `animate-sync`(prep 없는 저가 경로) 자체의 구조적 한계로 판단함 — 더 이상 프롬프트만
  바꿔서 재시도하는 건 크레딧 낭비라고 결론. 자세한 근거는 위 "SpriteCook API 실측
  조사 > 바퀴 76 추가 조사" 참고.
- 바퀴 76: 걷기 애니메이션은 PixelLab `/animate-with-text`(바퀴 44/INBOX #41이 실제
  성공시킨 방식)를 SpriteCook의 `animate-sync`보다 우선 권장하기로 함(강제 규칙은
  아님, 다음 바퀴가 참고할 근거). 근거: PixelLab은 잔액만 회복되면 이미 검증된 성공
  레시피가 있는데, SpriteCook은 서로 다른 프롬프트로 2회 시도해도 같은 결함이 반복돼
  이 특정 작업(4프레임 좌우 교차 보행)에는 덜 적합해 보임. DESIGN.md의 "SpriteCook이
  주 도구" 지정 자체를 바꾸지는 않았다 — 이건 PixelLab 잔액이 $0이라는 전제로 내려진
  결정이라, 잔액이 회복되면 그때 다시 판단할 문제라고 보고 STATUS.md에만 기록함.
- 바퀴 69: INBOX #50의 공식 SpriteCook `topdown` 캐릭터 워크플로우(`characters/{id}/animations`)
  사용을 이번 바퀴에서 보류하고, 대신 더 저렴한 범용 `animate-sync`로 시도하기로 함.
  근거: 공식 워크플로우는 애니메이션 1개당 20크레딧 + 방향 전환마다 12크레딧 prep이
  추가로 붙어 green 한 색의 idle+walk 4방향만 채워도 180크레딧 안팎이 필요한데, 무료
  티어 총량이 40크레딧이라 애초에 못 끝낸다(위 "SpriteCook API 실측 조사" 참고).
  `animate-sync`는 prep 없이 20크레딧 고정이라 상대적으로 저렴하다.
- 바퀴 69: south 방향 걷기 시험 결과(20크레딧 소모)를 게임에 통합하지 않고 폐기하기로
  함. 근거: 4프레임 중 3프레임이 사실상 같은 자세라 애니메이션이 부드러운 좌우 보행이
  아니라 "튀었다 멈추는" 것처럼 보일 위험이 크다고 판단 — 스타듀밸리/코어키퍼 기준(①)
  미달. 크레딧이 이미 8까지 줄어 재시도 없이 STATUS.md에 실패 원인과 다음 시도 방향
  (프레임별 발 위치를 프롬프트에 명시)을 기록하는 것으로 이번 바퀴를 마쳤다.
- 바퀴 69: 인벤토리 항목(캐릭터 워크플로우 스키마)을 조사하다가 "미확인 필드를 추가로
  보내면 거부하는지" 확인하려던 탐색성 호출이 필수 필드를 전부 채운 상태였던 탓에 진짜
  캐릭터 생성 job을 실행시켜 12크레딧을 낭비했다. 근거/교훈: SpriteCook은 알 수 없는
  필드를 조용히 무시하고 요청을 그대로 실행한다 — 앞으로 스키마 탐색 목적의 호출은
  반드시 필수 필드 중 하나를 의도적으로 빼서 422 에러로만 정보를 얻을 것, "완전한"
  요청을 탐색 목적으로 보내지 않을 것.
- 바퀴 56: 낚싯대 "낚시하는" 모션의 분리 결함을 새로 그리지 않고, 기존 아이콘
  (`fishing_rod_fishing.png`)을 idle과 동일한 합성 좌표(`pos=(35,8), size=24`)로
  다시 합성하는 것으로 고쳤다. 근거: 문제를 재현해보니 그림 자체(`fishing_rod_fishing.png`)는
  문제가 없었고, 이전 세션이 그 아이콘을 캐릭터 위에 붙이는 PIL 합성 단계에서 손이 아닌
  발 근처 좌표(`pos=(30,34)`)를 잘못 줬을 뿐이었다 — 원인이 좌표 하나였는데 그림을 다시
  생성하면 PixelLab 호출을 낭비하게 된다. **다음 바퀴가 참고할 점**: 도구 애니메이션
  합성 결함을 고칠 때는 먼저 PIL 합성 직후(인페인트/회전 전) 단계를 확대해서 눈으로
  검사해 "그림이 나쁜지" "합성 좌표가 나쁜지"부터 구분할 것 — 후자면 PixelLab을 다시
  부르지 않고 좌표만 바꿔서 훨씬 싸게 고칠 수 있다.
- 바퀴 56: 낚싯대를 마지막으로 총/도끼/곡괭이낫/낚싯대(TOOL_KEYS 전부)가 캐릭터
  애니메이션 프레임에 통합됐으므로, INBOX #45 원문 지시대로 옛 옆 아이콘 오버레이 코드
  (`_held_item_sprite`, `HELD_ITEM_OFFSETS`, `HELD_ITEM_BEHIND_FACINGS`, `TOOL_USE_ICONS`,
  `_build_held_item_sprite()`, `_update_held_item_transform()`, `_play_tool_swing()`)를
  전부 삭제하고 `_select_hotbar()`도 단순화했다. 근거: grep으로 world.gd 밖에서 이
  심볼들을 쓰는 곳이 없음을 먼저 확인했고, `_select_hotbar()`의 "도구가 gun/axe/pickaxe면
  오버레이를 숨기고 아니면 보여준다" 분기가 이제는 항상 앞 조건만 타므로(TOOL_ICONS의
  모든 항목이 애니메이션 통합 도구) 죽은 코드를 남겨두는 것보다 지우는 게 다음 바퀴가
  읽기 쉽다.
- 바퀴 55: 미커밋 상태로 남아있던 INBOX #45(낚싯대 통합) 코드를 검수 결과 불합격
  판정하고 커밋하지 않은 채 폐기, INBOX.md의 완료 체크박스도 다시 `- [ ]`로 되돌렸다.
  근거: PROMPT.md ①(합격 기준)은 "빌드가 되고 기능이 동작해도" 통과 못 하면 커밋하지
  않는다고 명시하는데, 실제 스크린샷에서 "낚시하는" 모션이 손에서 완전히 분리되어
  보이는 결함을 확인했다 — 이미 문서(INBOX.md)에는 완료로 적혀 있었지만, 그 표시가
  실제 코드 품질을 보증하지 않는다는 걸 이번에 직접 확인했다(위 "헤드리스 CLI 검증"
  절의 바퀴 55 신규 노트 참고). 완료 표시를 정정하지 않고 그대로 두면 다음 바퀴가
  #45를 다시 열어보지 않아 결함이 영구히 묻힐 위험이 있어, "완료된 항목은 지우지
  않는다"는 원칙과는 별개로 "완료가 아닌 것을 완료로 잘못 표시한 경우 정정한다"는
  판단을 내렸다. **다음 바퀴가 참고할 점**: 이런 정정은 항목 번호를 새로 만들지 않고
  기존 번호의 체크박스만 되돌리는 것으로 충분하다 — 새 버그 티켓 번호를 따로 만들
  필요는 없다(원본 지시 내용이 아직 완료되지 않았다는 사실을 그대로 반영하는 것뿐이므로).
- 바퀴 55: INBOX #46(QA 관찰)의 좁은 범위(총만) 지시를 그대로 지켜, 조사 중 발견한
  #45(낚싯대)의 결함은 #46 범위 안에서 함께 고치지 않고 #45를 재오픈하는 것으로만
  처리했다. 근거: PROMPT.md ③"이번 바퀴는 INBOX 항목 정확히 1개만 처리한다"는 규칙과
  DESIGN.md "QA 관찰 항목" 형식(그림/코드를 새로 만들지 않고 관찰·티켓 발행까지만)이
  범위를 명확히 좁히고 있다 — 우연히 발견한 인접 결함이라도 그 자리에서 고치면 두
  항목을 한 바퀴에 처리하는 셈이 되어 예산/추적성 원칙과 충돌한다.

- 바퀴 47: 총을 든 채 이동할 때는 걷기 전용 프레임(walk_gun)을 만들지 않고 `gun_idle_<dir>`
  정적 프레임을 그대로 쓰기로 함(옵션A, STATUS.md "다음에 할 것" 참고). 근거: DESIGN.md
  "도구 동작 표현"이 총에 대해 "들고 있기/발사" 두 상태만 명시하고 이동 중 상태는
  언급이 없어 임의로 확장하지 않았다 — 다리가 안 움직이는 것은 아쉽지만, 최소한 이전
  오버레이 방식(이동 중에도 총이 계속 보이던 것)과 같은 수준은 유지해 회귀를 막는 것을
  우선했다. #43~#45(도끼/곡괭이낫/낚싯대)도 같은 옵션A로 통일해서 도구마다 처리가
  갈리지 않게 할 것.

- 바퀴 1: Godot 프로젝트를 저장소 루트가 아니라 `game/` 하위 디렉터리에
  만들었다. 근거: repo 루트에는 이미 `docs/`, `loop/`, `logs/`가 있어서
  Godot 프로젝트 파일들과 섞이면 지저분해지고, 나중에 서버 코드가 별도로
  생기더라도(멀티플레이 세션 서버) 구분하기 쉽다.
- 바퀴 1: `config/name`(프로젝트 이름)은 DESIGN.md에 게임 제목이 정해져
  있지 않아서, 이미 존재하는 GitHub 저장소 이름 `life_game`을 그대로 썼다.
  임의로 새 제목을 지어내지 않기 위한 선택. 나중에 정식 제목이 정해지면
  `game/project.godot`의 `config/name`과 메인 메뉴 타이틀 라벨
  (`main_menu.tscn`의 `Title` 노드)만 바꾸면 된다.
- 바퀴 1: 메인 메뉴 버튼에 기본 Godot 테마 대신 커스텀 StyleBoxFlat 테마를
  적용했다. 근거: PROMPT.md ①의 "다른 사람이 봤을 때도 퀄리티가 떨어지지
  않는가" 기준을 기본 회색 버튼으로는 통과하기 어렵다고 판단했다. 이건 도트
  그래픽(그림)이 아니라 UI 스타일 리소스라서 "그림은 PixelLab로" 규칙과는
  무관하다고 판단했다 — 이후 바퀴에서 실제 게임 스프라이트(캐릭터/동물/
  타일 등)는 반드시 PixelLab로 생성해야 한다.
- 바퀴 1: `window/stretch/mode = canvas_items`, `aspect = keep`을 project.godot에
  미리 설정해뒀다 (해상도 옵션 UI 자체는 아직 없음, INBOX #5 몫). 근거:
  DESIGN.md의 "해상도를 높여도 시야가 넓어지면 안 된다" 규칙과 궁합이 맞는
  기본값이라 미리 깔아뒀다 — INBOX #5에서 실제 해상도 선택 UI와 카메라 zoom
  로직을 구현할 때 이 설정을 뒤집지 말고 그대로 이어받을 것.
- 바퀴 2: 캐릭터 슬롯 화면의 카드 스타일(StyleBoxFlat)은 전역 테마
  (`main_theme.tres`)를 고치지 않고 `character_slots.tscn` 안에 씬 전용
  sub_resource로 따로 만들었다. 근거: 메인 메뉴/뒤로가기 버튼처럼 계속 재사용될
  일반 버튼과 "카드형 슬롯 선택" 버튼은 크기와 용도가 달라서(220x0 pill 버튼 vs
  200x260 카드), 전역 테마에 합치면 나중에 다른 화면에서 일반 버튼을 만들 때마다
  실수로 카드 스타일이 적용될 위험이 있다고 판단했다.
- 바퀴 2: 슬롯 3개는 항상 빈 상태로만 렌더링한다 (저장된 캐릭터를 표시하는 로직 없음).
  근거: 캐릭터 저장/불러오기 형식 자체가 아직 정해지지 않았고(INBOX #3에서 다룰 몫),
  #2 지시문도 "빈 슬롯을 고르면 ..."까지만 요구했다. 저장 포맷을 이번 바퀴에서
  임의로 지어내면 #3에서 다른 형식으로 다시 만들 때 이번 작업을 되돌릴 위험이 있다.
- 바퀴 2: macOS `screencapture` 명령이 이 실행 환경에서 "could not create image from
  display" 오류로 실패했다(화면 기록 권한 문제로 추정). 대신 Godot을
  `godot --path . --script <script>.gd`로 실행해 스크립트 안에서 씬을 불러온 뒤
  `root.get_texture().get_image().save_png(path)`로 엔진 내부 렌더 결과를 직접
  PNG로 저장하는 방식으로 스크린샷을 찍었다. 이 방법이 더 안정적이므로(OS 권한에
  의존하지 않음) 다음 바퀴부터 화면 검수 시 기본으로 쓸 것.
- 바퀴 3(예산 초과로 중단, exit=1) → 바퀴 4: 바퀴 3이 INBOX #3 코드를 이미 다 만들어
  놓고도 자기 세션 안에서 커밋/STATUS 갱신을 마치지 못한 채 USD 예산 초과로 죽었다.
  이후 loop.sh의 대시보드 커밋이 작업 디렉터리에 남아있던 미커밋 변경분을 함께
  쓸어담아 `상태 페이지 갱신 (바퀴 3, ...)` 커밋 안에 실제 기능 코드가 섞여 들어갔다
  (INBOX.md/STATUS.md는 여전히 #3을 미완료로 표시). 바퀴 4는 이 코드를 처음부터 다시
  만들지 않고, 내용을 읽고 실행/스크린샷으로 검수한 뒤 문서만 정합화했다. 근거: 코드
  품질이 이미 합격 기준을 통과했고, 처음부터 다시 만들면 예산과 시간을 이중으로 쓰게
  된다. **다음 바퀴를 위한 교훈**: 세션이 예산 초과로 강제 종료될 조짐이 보이면(작업이
  오래 걸리고 있다면) 문서(STATUS.md/INBOX.md) 갱신과 커밋을 더 일찍, 더 잘게 나눠서
  먼저 끝내두는 것이 안전하다 — PROMPT.md ⑤ "작게 자주 커밋"이 이 경우를 막기 위한
  규칙이었는데 바퀴 3에서는 커밋 타이밍을 너무 늦게 잡아서 최종 커밋 자체를 못 했다.
- 바퀴 5: DESIGN.md "조작" 절의 "시야/조준 방향: 마우스로 회전"을 문자 그대로(캐릭터
  스프라이트 자체를 Node2D.rotation으로 돌리는 것)로 처음 구현했으나, 실제 실행 스크린샷을
  보니 정면 도트 그림이 통째로 돌아가면서 머리/다리가 뒤바뀐 것처럼 보여 품질 기준에
  미달했다. 그래서 이미 있는 4방향(north/south/east/west) 스프라이트를 마우스 각도에 따라
  갈아끼우는 방식으로 바꿨다. 근거: 이 캐릭터 스프라이트들은 각 방향에서 본 "정면 뷰"로
  그려진 그림이라(3D 모델을 위에서 내려다보며 회전시키는 게 아니라 방향별로 별도로 그린
  2D 그림), 이미지 자체를 회전시키면 실제로 캐릭터가 도는 것처럼 보이지 않고 그림이
  기울어지는 것처럼 보인다 — 스타듀밸리·코어키퍼 같은 참고 게임들도 모두 이 방식(4~8방향
  스프라이트 전환)을 쓴다. DESIGN.md의 "회전"이라는 단어는 "마우스를 따라 캐릭터가 방향을
  튼다"는 동작 자체를 뜻하는 것으로 해석하고, 그 구현 수단은 품질이 나오는 4방향 전환으로
  선택했다. **다음 바퀴가 주의할 점**: 총기 반동/조준선 등 더 정밀한 조준 표현이 필요해지면
  (INBOX로 지시가 오기 전까지는) 이 4방향 전환 방식을 뒤집지 말고, 필요하면 별도의 조준선
  UI 오버레이(회전 가능한 단순 도형/스프라이트)를 얹는 방향을 먼저 검토할 것 — 캐릭터 몸통
  스프라이트 자체의 회전은 이번 바퀴에서 품질 문제로 이미 기각됐다.
- 바퀴 6: 해상도 선택 옵션 목록을 16:9 종횡비(1280x720/1600x900/1920x1080/2560x1440)로만
  구성했다. 근거: 프로젝트 기준 뷰포트가 1280x720(16:9)이고 `aspect=keep`이 설정돼 있어서,
  종횡비가 다른 해상도를 넣으면 레터박스(검은 띠)가 생겨 해상도마다 실제 렌더링 영역
  비율이 달라 보인다 — DESIGN.md가 요구하는 "해상도는 화면 비율에만 영향을 줘야 한다"는
  표현을 "선택 가능한 해상도들은 종횡비를 하나로 고정하고 그 안에서만 고른다"는 뜻으로
  해석했다. 다음 바퀴가 해상도 목록을 넓히려면(예: 21:9 지원) 별도로 letterbox 처리를
  어떻게 할지부터 결정하고 시작할 것 — 지금 구현은 그 경우를 다루지 않는다.
- 바퀴 6: 해상도 선택을 실제 창 크기(`get_window().size`)만 바꾸는 방식으로 구현하고
  `project.godot`의 기준 뷰포트 해상도나 `Camera2D.zoom`은 손대지 않았다. 근거: 바퀴 1의
  결정(`window/stretch/mode=canvas_items`, `aspect=keep`)을 그대로 살리는 방식이 DESIGN.md
  요구사항을 가장 단순하게 만족시킨다 — `canvas_items` 스트레치 모드는 항상 기준 해상도로
  렌더링한 화면을 창 크기에 맞춰 확대/축소해서 보여주므로, 창을 키워도 같은 월드 범위가
  더 크게(또는 더 선명하게) 보일 뿐 더 넓게 보이지 않는다.
- 바퀴 7: 일시정지 메뉴는 별도 씬(scene)으로 분리하지 않고 `world.tscn` 안에 숨겨진
  `Control`(`UI/PauseMenu`)로 구현했다. 근거: 별도 씬으로 만들면 인스턴스화/오버레이
  타이밍을 신경 써야 하고, 월드 상태(플레이어 위치 등)를 유지한 채 그 위에 떠야 하므로
  같은 씬 트리 안에 두고 visible만 토글하는 쪽이 가장 단순하다.
- 바퀴 7: ESC는 `InputMap`의 기본 액션(`ui_cancel`)이 아니라 `_unhandled_input`에서
  `event.keycode == KEY_ESCAPE`로 직접 감지했다. 근거: 이 프로젝트의 이동 입력(WASD)도
  이미 `Input.is_physical_key_pressed(KEY_*)`로 액션맵을 거치지 않고 물리 키를 직접
  읽는 방식을 쓰고 있어서(`world.gd` `_physics_process`), 같은 스타일을 유지하는 게
  일관성이 있다고 판단했다.
- 바퀴 7: 설정 화면의 "뒤로" 버튼 목적지를 `SettingsData.return_scene_path`(오토로드
  전역 변수)로 관리하기로 했다. 근거: 설정 화면이 메인 메뉴와 월드(일시정지 메뉴) 두
  곳에서 열릴 수 있게 되면서, 하드코딩된 메인 메뉴 복귀만으로는 플레이 중 설정을 열었을
  때 게임이 강제 종료되는 것처럼 느껴지는 문제가 생겼다. `CharacterData.
  active_slot_index`와 동일한 패턴이라 새로운 개념을 추가한 게 아니다. **다음 바퀴가
  주의할 점**: 설정 화면을 여는 새 진입점을 추가할 때는 반드시 `SettingsData.
  return_scene_path`를 먼저 지정하고 나서 `change_scene_to_file`을 호출할 것 — 안 하면
  직전에 남아있던 값(다른 화면에서 설정한 값)으로 잘못 돌아간다.
- 바퀴 8: INBOX #7 조사 결과, 코드를 고치지 않고 "코드 결함 아님"으로 완료 처리했다.
  근거: `SettingsData.set_resolution` → `get_window().size` 경로가 에디터 임베딩을
  우회한 실행에서 정확히 동작함을 직접 확인했고, 버그 리포트가 의심한 "에디터 임베디드
  게임 창 설정과 프로젝트의 실제 해상도 설정이 꼬여 있다"는 가설은
  `ProjectSettings.has_setting("run/window_placement/game_embed_mode")`가 `false`를
  반환하는 것으로 반증됐다 — 애초에 그 둘을 이어주는 프로젝트 설정 키 자체가 없다(에디터
  전역 설정과 프로젝트 설정은 서로 다른 저장소라 "꼬일" 수가 없다). **다음 바퀴가 주의할
  점**: 앞으로 "설정에서 뭘 바꿔도 화면에 반영이 안 된다"류의 버그 리포트가 다시 들어오면,
  먼저 Godot 에디터의 Play 버튼(임베디드 Game 패널)으로 확인한 것인지부터 물어볼 것 —
  이 패널은 개발자 편의용 미리보기이고 실제 게임/익스포트 빌드 동작과 다를 수 있다는 게
  이번 바퀴에 확정된 사실이다. 진짜로 검수하려면 `godot --path . --script <script>.gd`로
  에디터를 거치지 않고 직접 실행해서 확인해야 한다.
- 바퀴 11: INBOX #9의 "총알↔사슴 물리 충돌 미검증" 이슈는 새로 코드를 고치지 않고
  검증만 다시 수행해서 해결했다. 근거: 바퀴 10이 남긴 의심(`get_overlapping_areas()`가
  빈 배열을 반환)은 재현되지 않았다 — `add_child`로 씬 트리에 넣은 뒤 물리 프레임을
  몇 번 진행시키면 `area_entered` 신호가 정상적으로 발생했다. 바퀴 10의 검증 스크립트가
  씬 트리에 노드를 추가한 직후(같은 프레임)에 바로 `get_overlapping_areas()`를 호출했을
  가능성이 있어 보인다(Area2D 물리 서버 등록은 최소 한 물리 프레임이 지나야 반영됨) —
  정확한 원인까지는 재현하지 않고, "신호 기반으로 여러 프레임을 진행시키며 관찰"하는
  더 안정적인 방식으로 재검증해 통과를 확인하는 쪽을 택했다. **다음 바퀴가 주의할 점**:
  앞으로 Area2D/RigidBody 등 물리 충돌을 스크립트로 검증할 때는 노드를 추가한 바로 그
  프레임에 겹침 여부를 확인하지 말고, 최소 2~3 물리 프레임을 진행시킨 뒤 신호(`area_entered`
  등) 또는 그 결과(체력 변화 등)로 확인할 것.
- 바퀴 12: 채집 포인트/채광 포인트를 "한 번 캐면 사라지는" 유한 자원이 아니라 "20초
  쿨다운 후 원래대로 돌아오는" 무한 자원으로 만들었다. 근거: DESIGN.md에 자원이
  유한한지 무한한지 명시가 없고, 필드에 각 5개씩만 배치했으므로 유한 소모로 만들면
  플레이 몇 분 안에 캘 게 없어지는 문제가 바로 생긴다 — 농사/목장(#11/#12)이 아직
  없어서 자원을 되돌릴 다른 수단도 없는 시점이라 무한 재생 쪽이 더 안전한 기본값이라고
  판단했다. 다음 바퀴가 자원 희소성을 게임플레이 요소로 넣고 싶다면(예: 채광 포인트가
  N번 캐면 완전히 고갈) 이 쿨다운 상수(`RESPAWN_SECONDS`)를 바꾸는 게 아니라 별도
  "고갈 카운터"를 추가하는 식으로 확장할 것 — 이번 구현을 뒤집을 필요는 없음.
- 바퀴 12: 삽/곡괭이라는 "도구" 개념 자체는 코드에 만들지 않고, 채집 포인트/채광
  포인트가 각각 자기 종류에 맞는 아이템을 자동으로 주는 방식으로 구현했다(도구 인벤토리
  아이템이나 도구 선택 UI 없음). 근거: 바퀴 11이 이미 STATUS.md에 남긴 해석("도구를
  따로 고르는 UI 없이 포인트 종류에 자동 적용")을 그대로 따랐고, INBOX #10 지시문도
  이 해석과 일치했다. 다음 바퀴가 "도구를 인벤토리에 실제로 들고 있어야 채집 가능"
  같은 규칙을 추가하려면 이건 DESIGN.md에 없는 새 제약이므로 임의로 넣지 말고 STATUS.md
  "막힌 것/보류"에 남길 것.
- 바퀴 13: 수확물 아이템 이름을 `rice`로 정했다(씨앗은 이미 `rice_seed`). 근거:
  DESIGN.md에 수확물 내부 이름이 정해져 있지 않았고, `InventoryData`/`ITEM_LABELS`
  패턴상 씨앗과 다른 별도 키가 필요했다 — 가장 단순한 이름을 선택.
- 바퀴 13: 수확 시 벼 2개를 준다(씨앗 1개 소비 대비). 근거: DESIGN.md에 수확량이
  없어서 임의로 정함 — 심고 기다린 노력에 대한 보상으로 "본전(1개)"보다는 많아야
  농사가 매력적이라고 판단했다. 밸런스는 나중에 조정 가능.
- 바퀴 13: 밭은 채집/채광 포인트처럼 필드에 무작위 산개시키지 않고, 플레이어 스폰
  기준 고정 오프셋 3x2 격자로 배치했다. 근거: DESIGN.md가 "밭(정해진 구역)"이라고
  명시했고, 무작위 배치는 "정해진 구역"이라는 표현과 맞지 않는다고 판단.
- 바퀴 13: 밭 타일(Soil) 스프라이트에 `z_index = -1`을 줬다. 근거: 프로그램적으로
  나중에 스폰되는 노드가 씬 트리 순서상 플레이어보다 나중에 그려져 플레이어 다리를
  가리는 렌더링 버그를 스크린샷 QA로 발견해서 고침 — 앞으로 "땅에 붙는" 장식성
  스프라이트(바닥 타일 등)를 새로 추가할 때는 처음부터 z_index를 낮게 주는 것을
  기본으로 고려할 것.
- 바퀴 14: `world.tscn`의 `Ground`(배경 Polygon2D)에 `z_index = -2`를 줬다. 근거:
  바퀴 13이 Soil에 준 `z_index=-1`이 Ground(기본값 0)보다 낮아서 밭/목장 바닥
  스프라이트가 실제로는 항상 Ground에 가려 안 보이고 있었다(스크린샷 QA로 발견).
  Ground를 -2로 내려 Ground < Soil/Pasture < Player 순서를 만들었다 — 다음 바퀴는
  땅바닥 장식 스프라이트에 z_index=-1을 계속 써도 된다(이 고정으로 다시 안전해짐).
- 바퀴 14: 포획된 사슴을 InventoryData의 `captured_deer` 카운트로 관리했다(포획 즉시
  별도 필드 오브젝트나 슬롯 UI를 만들지 않음). 근거: 밭의 씨앗/수확물과 동일한 기존
  패턴이라 새 개념을 추가하지 않고, "몇 마리 포획했는지"만 알면 되는 지금 요구사항에
  가장 단순하게 들어맞는다고 판단.
- 바퀴 14: 목장에 풀어놓은 사슴(`is_ranched=true`)은 `take_hit`을 무시하게 만들어
  다시 사냥/포획할 수 없게 했다. 근거: DESIGN.md에 명시는 없지만, 길들인 가축을 다시
  쏴서 죽이거나 재포획하는 것은 "목장에서 기른다"는 취지와 맞지 않는다고 판단 — 이
  판단이 틀렸다면(예: 목장 사슴도 사냥 가능해야 한다면) `deer.gd`의 `take_hit` 맨
  위 `or is_ranched` 조건만 지우면 된다.
- 바퀴 15: 바퀴 14가 커밋하지 못하고 죽은 코드를 다시 작성하지 않고 검증 후 그대로
  커밋했다(`ac35415`). 근거: 바퀴 3→4 결정 로그와 동일한 상황 — 코드 품질이 이미
  합격 기준을 통과한 것으로 보였고(바퀴 14의 상세한 검증 기록이 STATUS.md에 남아있었음),
  처음부터 다시 만들면 이번 바퀴에 주어진 매우 빠듯한 예산(세션 시작 시 총 $2)을
  이중으로 쓰게 된다. 다만 바퀴 4와 달리 이번엔 Godot을 재실행해 스크린샷을 다시
  찍는 재검증은 하지 않았다(diff 검토 + InventoryData API 존재 확인만 함) — 예산이
  바퀴 4 때보다 더 빠듯했기 때문. **다음 바퀴가 주의할 점**: 만약 실제로 실행해보니
  목장이 시각적으로 문제가 있다면(예: 스프라이트 위치가 어긋남) 이건 바퀴 15가
  재검증을 생략한 데서 온 것일 수 있으니 STATUS.md 탓하지 말고 직접 확인할 것.
- 바퀴 16: 한 달의 일수를 30일(1년=360일)로 임의로 정했다. 근거: DESIGN.md는 월→계절
  매핑(1·2·3월=봄 등)만 정하고 한 달이 며칠인지는 정하지 않았다 — "범위 밖/아직 미정"에도
  없어 STATUS.md에 남기고 넘어갈 수도 있었지만, 날짜/계절 시스템 자체가 이 값 없이는
  전혀 동작할 수 없는 핵심 파라미터라서(달력이 없으면 "계절이 바뀐다"를 구현할 수 없음)
  가장 흔한 관례(30일/월)로 임의로 정하고 진행했다. 나중에 실제 요구(예: 현실 달력처럼
  28~31일 가변)가 오면 `TimeData.DAYS_PER_MONTH` 상수 하나만 바꾸는 게 아니라 월별 일수
  배열로 구조를 바꿔야 한다.
- 바퀴 16: 낮/밤 화면 밝기 전환을 구간 경계에서 뚝 끊기지 않고 매 프레임 연속적으로
  보간되게 만들었다(낮 진행률 0→1에서 밝음→어두움, 밤 진행률 0→1에서 어두움→밝음 —
  양쪽 다 "밤색"에서 만나므로 이어붙임). 근거: 지시문이 "정교한 이펙트는 나중에"라고
  했지만 각 구간을 통째로 한 가지 색으로 렌더링하면(하드 컷) 20분에 한 번씩 화면이
  순간적으로 확 바뀌어 오히려 더 눈에 띄고 품질이 떨어져 보인다고 판단 — 보간 자체는
  `Color.lerp` 한 줄이라 추가 비용이 거의 없어 최소 구현 원칙과 크게 충돌하지 않는다고
  봤다.
- 바퀴 16: 비는 화면 전체를 덮는 반투명 파란 `ColorRect` 오버레이 하나로만 표현했다
  (빗방울 파티클, 소리 등은 만들지 않음). 근거: 지시문이 "비 표시 정도로 충분"이라고
  명시했고, 파티클 이펙트는 "정교한 이펙트는 나중에" 범위에 들어간다고 판단.
- 바퀴 16: 농사(60초 성장)를 게임 내 날짜 기준으로 바꾸지 않고 실시간 초 단위로
  그대로 뒀다. 근거: INBOX #13 지시문에 농사 시스템을 건드리라는 요구가 없었고,
  DESIGN.md에도 성장 시간을 날짜 기준으로 해야 한다는 명시가 없어서, 지시받지 않은
  기존 시스템을 임의로 바꾸는 것은 ③의 "임의로 지어내지 않는다" 원칙과 맞지 않는다고
  판단했다.
- 바퀴 17: 방 코드를 실제 매치메이킹 서버 없이 호스트의 LAN IP:포트를 16진수로 그대로
  인코딩한 문자열로 만들었다. 근거: DESIGN.md가 릴레이 서버를 "범위 밖"으로 명시했지만
  코드만으로 접속하는 UX(INBOX #14 "방 코드 입력해서 참가")는 요구했으므로, 서버 없이도
  이 요구를 만족하는 유일한 방법은 코드 자체에 접속 정보를 담는 것이었다. `host_room()`/
  `join_room()` 내부에만 이 방식이 들어 있어서, 나중에 진짜 릴레이 서버가 생기면 이 두
  함수의 구현만 바꾸면 되고 호출부(world.gd 등)는 그대로 둬도 된다.
- 바퀴 17: 로컬 플레이어(`$Player`, 기존 이동/사격/HUD 로직)는 그대로 두고, 다른
  접속자는 별도의 가벼운 `Sprite2D`(RemotePlayers 아래)로 위치/방향/외형만 RPC로 받아
  표시하는 방식을 택했다(MultiplayerSpawner/MultiplayerSynchronizer로 전체 Player 씬을
  복제하는 방식은 쓰지 않음). 근거: INBOX #14가 "서로를 보고 움직이는 것까지"만 요구했고,
  기존 world.gd의 로컬 플레이어 로직(사격/HUD/일시정지 등)을 건드리지 않고 그 위에 얹을
  수 있어 회귀 위험이 가장 작았다. 다음 바퀴가 다른 접속자의 총알/상호작용까지 동기화하려면
  이 구조를 MultiplayerSpawner 기반으로 다시 설계해야 할 수 있다.
- 바퀴 18: 사슴을 PixelLab `template_id="horse"`로 재생성했다. 근거: 사용 가능한 quadruped
  템플릿이 `bear/cat/dog/horse/lion`뿐이라(API가 422 에러로 확인시켜줌, "deer"는 없음),
  그중 몸통 비율(긴 목/다리)이 사슴과 가장 가까운 `horse`를 선택했다. 뿔은 프롬프트에서
  "뿔 없음"으로 명시했다(성별/나이 개념이 코드에 없으므로 뿔 유무를 아예 통일해서 다시
  헷갈릴 여지를 없앰). 다음 바퀴가 "뿔 달린 수사슴"을 게임 요소로 넣고 싶다면(새 개념),
  이건 DESIGN.md에 없는 새 제안이므로 임의로 넣지 말고 STATUS.md에 남길 것.
- 바퀴 18: PixelLab가 함께 생성해준 west 방향 이미지를 쓰지 않고 버렸다. 근거: INBOX #15
  지시문이 "west는 기존처럼 east 좌우반전 유지"라고 명시했다 — `deer.gd`의 로직을 바꾸지
  않는 게 이번 항목의 범위를 최소로 지키는 선택이었다.
- 바퀴 18: 스프라이트 PNG 파일 내용만 바꾸고 `--quit-after` 헤드리스 스모크 테스트만
  돌리면 실제 반영 여부를 오판할 수 있다는 것을 발견했다(위 "끝난 것" 참고 — `.godot/
  imported/*.ctex` 캐시가 갱신되지 않아 예전 이미지가 계속 로드됨). **다음 바퀴가 스프라이트
  PNG 교체 작업을 할 때는 반드시 `godot --headless --path . --import`로 강제 재임포트한
  뒤 스크린샷으로 재검증할 것** — PROMPT.md ⑥의 "같은 지적이 두 번 나오면 규칙으로
  올린다" 기준에 따라, 이 절차를 앞으로 스프라이트 교체 시 기본 체크리스트로 삼는다.
- 바퀴 19: 사슴의 `Hurtbox`(CircleShape2D radius=34) 등 충돌/상호작용 반경 상수는 Sprite
  scale을 절반으로 줄일 때 같이 줄이지 않았다. 근거: 이 반경들은 Sprite의 자식이 아니라
  Deer/포인트 노드 자체의 자식이라 스프라이트 scale에 자동으로 영향받지 않는 별도
  하드코딩 값이고, INBOX #16 지시문이 명시적으로 "Sprite scale"만 지목했다 — 스크린샷상
  명백히 어긋나 보이지도 않아 범위를 넘겨 손대지 않았다. 다음 바퀴가 실제 플레이에서
  "빈 공간에서 맞는 것 같다"는 느낌을 받으면 그때 반경도 같이 줄이는 걸 검토할 것.
- 바퀴 19: 멀티플레이 원격 플레이어 스프라이트(`world.gd`의 `_ensure_remote_sprite()`)에
  하드코딩돼 있던 `Vector2(3, 3)`도 로컬 플레이어와 함께 1.5로 줄였다. 근거: INBOX #16
  원문은 이 코드를 언급하지 않았지만, 로컬 플레이어만 줄이면 "내 캐릭터와 다른 접속자
  캐릭터 크기가 다르게 보이는" 새 불일치가 생겨 오히려 품질이 떨어지므로 같이 고쳤다.
- 바퀴 20: 밭의 `Crop` 노드에 `z_index = -1`을 줘서 `Soil`과 같은 값으로 맞췄다(새 값을
  만들지 않음). 근거: 바퀴 13/14가 이미 Ground(-2) < 바닥 장식(-1) < Player(0) 체계를
  정해뒀고, `Crop`이 이 체계에서 빠져 있던 게 INBOX #17 버그의 원인이었다 — 기존 체계를
  그대로 따르는 것이 "다음에 할 것"에 남아있던 규칙("새 바닥 장식은 z_index=-1")과도
  일치한다.
- 바퀴 21: 사슴의 경계 탈출 방식으로 "방향 후보를 통째로 바꿔치기(회전)"가 아니라
  "막힌 축 성분만 0으로 누르는" 벡터 마스킹 방식을 선택했다. 근거: 먼저 시도한
  회전 후보 방식은 매 프레임 "지금 이 방향이 막혔는가"를 새로 판정해서 조금만
  움직여도 다시 안 막힌 것으로 오판해 원래(막힌) 방향으로 돌아가버리는 진동이
  생겼다(검증 스크립트로 2초에 2.4유닛만 이동하는 것을 확인). 성분 마스킹 방식은
  사슴이 여전히 경계 근처(margin 이내)에 머무는 한 같은 판정을 안정적으로 유지해서
  진동 없이 벽을 타고 미끄러진다. 다음 바퀴가 다른 AI(예: 다른 동물)에도 비슷한
  "경계에 막혀 멈춤" 문제가 생기면, 회전 후보 방식보다 이 성분 마스킹 방식을 먼저
  고려할 것 — `FLEE_WALL_MARGIN`(80) 상수도 그대로 재사용 가능.
- 바퀴 21: `FLEE_WALL_MARGIN`(80)은 임의로 정한 값이다. 근거: 한 프레임에 이동하는
  거리(FLEE_SPEED*delta ≈ 3.3유닛/프레임, 60fps 기준)보다 충분히 커야 여러 프레임에
  걸쳐 판정이 안정적으로 유지되는데(위 결정 참고), DESIGN.md/INBOX #18에 구체적인
  수치 요구가 없어서 "한 프레임 이동량의 20배 이상"이라는 대략적인 여유를 기준으로
  잡았다. 실제 플레이에서 사슴이 벽 근처에서 부자연스럽게 오래 붙어 있는 것처럼
  보이면 이 값을 줄이는 것을 고려할 것.
- 바퀴 22: 체력바를 `TextureProgressBar` 같은 리소스 기반 위젯이 아니라 `ColorRect`
  두 개(배경/전경)로 직접 만들었다. 근거: 도트 그래픽 리소스가 아니라 순수 UI
  요소라서(바퀴 1이 메뉴 버튼 테마에 대해 남긴 결정과 같은 근거) PixelLab로 만들 필요가
  없고, `ColorRect`만으로 요구사항(체력 비율/색 변화)을 가장 단순하게 만족시킨다.
- 바퀴 22: 체력바를 만피일 때는 숨기고 데미지를 입어야 보이게 했다(항상 표시하지
  않음). 근거: INBOX #19 지시문은 "표시한다"고만 했지 상시 표시를 요구하지 않았고,
  코어키퍼/스타듀밸리류 참고 게임들도 보통 피격 시에만 체력바를 보여준다 — 모든
  사슴 위에 항상 만피 바가 떠 있으면 화면이 어수선해져 오히려 품질 기준(①)에서
  불리하다고 판단했다. 다음 바퀴가 "항상 보여야 한다"는 새 요구를 받으면
  `_update_health_bar()`의 `visible = health < MAX_HEALTH` 줄만 `true`로 바꾸면 된다.
- 바퀴 23: `world.tscn`의 바닥을 `Polygon2D`(단색)에서 `Sprite2D`(region 반복 타일링)로
  바꿨다. `TileMap`/`TileMapLayer`로 수천 개 셀을 채우는 대신 `region_rect`를 텍스처보다
  훨씬 크게 잡고 `texture_repeat=ENABLED`를 켜는 방식을 택했다. 근거: 씬 파일이
  깨끗하게 유지되고(TileMap로 하면 셀 데이터가 .tscn에 대량으로 박히거나 별도 생성
  스크립트가 필요함), 드로우콜도 하나뿐이라 가장 단순하다 — 나중에 지형 경계(언덕,
  물가 등 여러 타일 종류)가 필요해지면 이 방식을 버리고 `TileMapLayer` 기반으로
  바꿔야 한다(Sprite2D 반복 방식은 텍스처 하나만 반복할 수 있어 여러 타일을 섞어 깔
  수 없음).
- 바퀴 23: PixelLab `/create-image-pixflux`(단발 이미지 생성)로 "seamless tileable"이라고
  프롬프트에 써도 실제로는 이음매가 생긴다는 것을 확인했다. 근거: 4x4 미리보기에서
  타일 경계마다 테두리 패턴이 뚜렷하게 보였다 — 이 모델은 타일링을 구조적으로
  보장하지 않는다. **다음 바퀴가 주의할 점**: 반복 타일링이 필요한 텍스처(바닥,
  벽지 등)는 pixflux가 아니라 `/create-tileset`(Wang 타일셋 전용 엔드포인트)을 쓸 것 —
  `lower_description`과 `upper_description`을 같은 문구로 주면 지형 경계 없는 균일한
  타일(네 모서리가 전부 "lower"인 것, 이번 바퀴 기준 이름은 `wang_0`이었지만 매 생성마다
  타일 이름 순서가 달라질 수 있으니 `corners`가 전부 "lower"인 타일을 찾아 골라야 한다)을
  하나 얻을 수 있고, 이건 애초에 서로 이어붙여지도록 설계된 타일이라 이음매가 없다.
  이 엔드포인트는 비동기라 `POST /create-tileset` 후 `GET /tilesets/{id}`로 폴링해야
  하고(60~100초 소요), `color_image`로 팔레트를 강제하려는 시도는 이번엔 원인 불명으로
  실패했다(작은 스와치 이미지가 원인이었을 수 있음, 텍스트 설명만 구체화하는 것으로
  우회 성공).
- 바퀴 24: INBOX #21(슬롯 인벤토리) 코드가 세션 시작 전부터 이미 미커밋 상태로 완성돼
  있어서, 새로 작성하지 않고 검증 후 그대로 커밋했다(`1aa96d3`). 근거: 바퀴 3→4,
  14→15와 같은 패턴 — 이전 세션이 예산/시간 초과로 커밋 전에 죽은 것으로 보였고,
  코드를 실제로 실행해 스크린샷까지 확인한 결과 품질 기준을 통과했다. 처음부터
  다시 만들면 예산을 이중으로 쓰게 된다. **다음 바퀴가 참고할 점**: 세션 시작 시
  `git status`/`git diff`에 이미 관련 있어 보이는 미커밋 변경이 있으면, 그걸 무시하고
  덮어쓰기 전에 먼저 내용을 읽고 실행해서 품질을 판단할 것 — 무조건 새로 만드는 것도,
  무조건 그대로 커밋하는 것도 아니라 매번 검증이 먼저다.
- 바퀴 24: `InventoryData`의 기존 카운트 기반 API(`get_count`/`add_item`/`remove_item`/
  `has_item`/`all_counts`)를 슬롯 구조로 바꾼 뒤에도 시그니처를 그대로 유지했다. 근거:
  사냥/채집/채광/농사/목장 등 이미 완성된 여러 씬이 이 API로만 인벤토리를 다루고
  있어서, 슬롯 UI를 추가한다고 그 호출부들까지 슬롯 인덱스를 알아야 하게 만들면
  INBOX #21 범위(슬롯/UI/데이터 구조)를 넘어서는 불필요한 리팩터가 된다.
- 바퀴 29: `get_held_tool()`을 고쳐 쓰지 않고 별도로 `get_held_item()`을 새로 추가했다.
  근거: `get_held_tool()`은 "손에 든 게 유효한 도구인가"(총 발사, 채집/채광/목장
  상호작용, 스윙 애니메이션)를 확인하는 여러 호출부가 이미 의존하고 있어서, 이 함수의
  반환값 의미를 "도구 또는 임의의 아이템"으로 넓히면 그 호출부들이 씨앗 등 도구가
  아닌 아이템을 들고 있을 때도 실수로 동작하게 될 위험이 있다. 새 함수를 분리하면
  기존 동작을 전혀 건드리지 않고 "지금 선택된 아이템이 특정 소모품인가"라는 새 질문에
  답할 수 있다.
- 바퀴 35: 총 탄창/재장전 상태(`_ammo_in_magazine`/`_is_reloading`/`_reload_timer`)를
  총별이 아니라 `world.gd`의 전역 변수로 뒀다. 근거: 지금 총이 "기본 소총" 하나뿐이라
  총별 상태를 구분할 필요가 없고, 미리 딕셔너리 등으로 구조화하면 아직 없는 요구를
  위해 복잡도만 늘어난다. 총 종류가 늘어나면(DESIGN.md "범위 밖: 총기 추가 종류") 그때
  아이템별 탄창 상태로 리팩터링할 것.
- 바퀴 36: 목장 풀어놓기 조건을 `REQUIRED_TOOL` 상수 비교(`get_held_tool() == ""`)에서
  `get_held_item() == CAPTURED_ITEM` 직접 비교로 바꾸면서 `REQUIRED_TOOL` 상수 자체를
  지웠다. 근거: "빈손"이라는 조건 자체가 폐기됐고(#34), 이제는 다른 상호작용(farm_plot의
  씨앗 심기)과 완전히 같은 패턴(`get_held_item() == 특정_아이템`)이라 이름만 다른 빈
  상수를 남겨둘 이유가 없었다.
- 바퀴 37: 헤드리스에 가까운 이 실행 환경에서는 `Input.warp_mouse()`가 실제로 OS
  마우스 커서를 옮기지 못한다는 것을 확인했다(직접 검증: 워프 후에도 조준 방향 계산
  결과가 항상 west로 고정됨). 4방향 스크린샷 같은 "마우스 조준 방향을 강제로 바꿔야
  하는" 검증이 필요하면, 마우스를 옮기려 하지 말고 대상 씬의 `set_physics_process(false)`
  로 마우스 추종 로직 자체를 멈춘 뒤 `_facing`/텍스처 갱신 함수를 스크립트에서 직접
  호출하는 방식을 쓸 것 — 이번 바퀴에 시행착오 끝에 확인한 방법이라 다음에 같은 종류의
  검증이 필요하면 바로 이 방법을 쓸 것(플레이어 위치만 옮기는 방식은 카메라가 매 프레임
  플레이어를 따라가서 상대 방향이 그대로 유지돼 실패했다).
- 바퀴 37: 도구를 든 자세를 방향별로 다시 그리지 않고(총 그림 하나만 계속 재사용),
  offset 위치와 `show_behind_parent`(후면일 때만 몸 뒤로) 조정만으로 4방향 자연스러움
  문제를 해결했다. 근거: 그림 자체는 이미 PixelLab로 만든 것이고 방향별 재생성은 이번
  지시(INBOX #35, "z_index나 위치/각도를 조정")의 범위를 넘는다 — 최소 변경으로 합격
  기준(①)을 통과할 수 있는지 먼저 스크린샷으로 확인했고, 통과했다고 판단해 그림 재생성
  없이 마무리했다. 다음 바퀴가 "총을 방향별로 다시 그려달라"는 새 지시를 받으면 그때
  `HELD_ITEM_OFFSETS`/`HELD_ITEM_BEHIND_FACINGS`를 뒤집을 필요 없이 텍스처만 방향별로
  분기하면 된다. **(바퀴 38 정정) 이 판단은 사용자에게 기각됐다** — INBOX #37이 "여전히
  이상하다"며 같은 문제를 재지적했고, DESIGN.md에 "도구 동작 표현" 규칙이 새로 추가되어
  아이콘 오프셋 조정만으로는 부족하고 실제 방향별/동작별(들기 vs 사용) 그림을 PixelLab로
  그려야 한다고 명시됐다.
- 바퀴 38: 기본탄/마취탄 탄창(`_ammo_in_magazine`)을 단일 `int`에서 탄종별 `Dictionary`로
  바꿨다. 근거: DESIGN.md가 "하나의 탄약 수를 공유하면 안 됨"이라고 명시했고, 총 종류가
  아직 하나뿐이라(바퀴 35 결정 로그 참고) 총별이 아니라 탄종별로만 분리하면 충분하다고
  판단했다 — 총이 여러 종류가 되면(범위 밖) 그때 `{총키: {탄종: 발수}}`처럼 한 단계 더
  중첩해야 한다.
- 바퀴 40: 총 전용이던 `TOOL_FIRING_ICONS`/`_firing_flash_timer`를 `TOOL_USE_ICONS`/
  `_tool_use_flash_timer`로 이름을 일반화하고 도끼도 같은 딕셔너리/타이머를 공유하게 했다.
  근거: 총과 도끼 둘 다 "손에 든 도구가 하나뿐이고, 쓰는 순간 잠깐 다른 텍스처로 바뀌었다가
  자동으로 되돌아온다"는 완전히 같은 패턴이라, 도구별로 별도 타이머를 두면(예:
  `_gun_flash_timer`, `_axe_flash_timer`) 다음 도구(#39 곡괭이낫, #40 낚싯대)가 늘어날
  때마다 변수가 계속 늘어난다 — 어차피 한 번에 하나의 도구만 손에 들 수 있으므로 공용
  타이머 하나로 충분하다. **다음 바퀴가 주의할 점**: #39(곡괭이낫)는 채광/채집 두 가지
  "사용 모션"이 필요해서 이 공용 타이머 하나로는 "지금 어떤 사용 모션이 재생 중인지"까지
  구분해야 할 수 있다 — 필요하면 타이머는 그대로 두고 `TOOL_USE_ICONS["pickaxe"]`를
  단일 텍스처가 아니라 상황별 텍스처를 담는 값으로 바꾸는 것을 검토할 것.
- 바퀴 40: 도끼 패는 모션 지속 시간을 총 발사열(0.12초)보다 긴 0.25초(`AXE_CHOP_FLASH_DURATION`)로
  정했다. 근거: DESIGN.md에 구체적 수치가 없고, 총의 "발사 순간"은 찰나여야 자연스럽지만
  도끼로 "패는" 동작은 총보다 느린 동작이라는 일반적인 직관(무기 vs 도구, 원거리 순간
  vs 근접 스윙)을 반영해 임의로 정했다 — 스크린샷 검증에서 이 값이 너무 짧거나 길어
  부자연스러워 보이지 않았다.
- 바퀴 41: 곡괭이낫의 채광/채집 두 "쓰는 모션"을 `TOOL_USE_ICONS`(도구 키 하나에 텍스처
  하나)에 그대로 넣지 않고, 별도 `PICKAXE_USE_ICONS`(kind→텍스처) 딕셔너리와 공개 함수
  `play_pickaxe_use(kind)`를 새로 만들었다. 근거: `TOOL_USE_ICONS`는 "도구 키 → 텍스처
  하나"라는 1:1 가정으로 설계돼 있어서(총/도끼는 실제로 쓰는 모션이 하나뿐), 곡괭이낫처럼
  한 도구가 상황에 따라 다른 두 모션을 가지는 경우를 억지로 끼워넣으면 `TOOL_USE_ICONS`의
  값 타입이 도구마다 달라져(어떤 건 Texture2D, 어떤 건 Dictionary) 읽는 쪽 코드가 매번
  타입을 분기해야 했다 — 새 도구를 계속 늘릴 것을 감안해 "1:1 도구"와 "1:N 도구"를 코드
  레벨에서 분리해뒀다. `_play_tool_swing()`은 `override_texture` 선택 인자를 받게 넓혀서
  두 함수가 같은 tween/타이머 로직을 공유하게 했다(중복 없음). **다음 바퀴가 참고할 점**:
  `resource_point.gd`처럼 별도 포인트 스크립트를 거치는 도구만 이 패턴이 필요하다 — #40
  낚싯대는 `world.gd` 안에서 직접 처리되는 단일 모션이라 기존 `TOOL_USE_ICONS`만으로
  충분하다(위 "다음에 할 것" 참고).
- 바퀴 41: `resource_point.gd`(gathering_point.tscn/mining_point.tscn 공용 스크립트)에
  `use_kind` export를 추가해 씬 데이터로 "mining"/"gathering"을 지정하게 했다. 근거:
  `item_name`("rice_seed" vs "iron")으로 이미 두 포인트 종류를 씬에서 구분하고 있는
  기존 패턴과 동일하게, 코드에서 씬 이름이나 item_name 문자열을 분기해 추측하는 대신
  씬 파일에 명시적으로 값을 박아두는 쪽이 더 안전하다고 판단했다(나중에 세 번째 종류의
  포인트가 추가돼도 코드 분기를 늘릴 필요 없이 export 값만 지정하면 됨).
- 바퀴 39: INBOX #37(총 들기/발사 모션 분리) 코드와 `gun_firing.png`가 세션 시작 전부터
  이미 미커밋 상태로 완성돼 있어서, 새로 만들지 않고 4방향 스크린샷 검증만 다시 수행해서
  커밋했다. 근거: 바퀴 3→4/14→15/24와 같은 패턴 — 실제로 실행해 8장(4방향 x holding/firing)
  스크린샷을 찍어본 결과 총 그림이 PixelLab 스타일과 일관되고(같은 팔레트/외곽선), 발사
  순간에만 총구에 노란 발사열이 뚜렷이 추가되는 것을 확인해 합격 기준(①)을 통과한다고
  판단했다. **다음 바퀴가 참고할 점**: 스크린샷 검증 스크립트에서 `_physics_process`를
  꺼둔 채(`Input.warp_mouse`가 이 환경에서 동작하지 않는 문제 때문, 바퀴 37 결정 로그
  참고) 여러 방향/상태를 연속 캡처하면, "사용 중" 텍스처가 원래 "들고 있는" 텍스처로
  자동 복귀하는 로직(`_physics_process` 안에 있음)이 돌지 않아 다음 방향의 holding
  캡처에 이전 상태가 그대로 남는다 — holding을 캡처하기 직전에 텍스처를 스크립트에서
  직접 원래 아이콘으로 되돌려줘야 한다(실제 게임 플레이에서는 문제 없음, 검증
  스크립트에만 해당).
