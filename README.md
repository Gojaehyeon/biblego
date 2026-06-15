# biblego

메뉴바 기반 macOS 성경 구절 삽입 유틸리티. 전역 단축키를 누르면 커서 근처에
검색 창이 떠서, 성경 구절(예: `요 3:16`)이나 본문 키워드를 입력해 후보를 고르면
지금 입력 중이던 앱의 커서 위치에 **붙여넣기처럼** 바로 삽입됩니다.

- 역본: **개역개정 (NKRV)** · 66권 31,077절
- 네이티브 Swift / SwiftUI, 메뉴바 앱(Dock 아이콘 없음)
- 전역 단축키 변경 가능(기본값 **⌥Space**)
- 검색: 한국어 참조 파싱 + FTS5 trigram 본문 부분일치 검색

## 빌드 & 실행

> ⚠️ 이 저장소에는 **개역개정 본문 데이터가 포함되어 있지 않습니다**(저작권).
> 빌드하려면 먼저 절 데이터(`Tools/build_db/source/nkrv.json`)를 직접 준비해야
> 합니다. 형식: `[{ "book": "요", "chapter": 3, "verse": 16, "content": "..." }, ...]`.

```bash
# 1) (최초 1회) 개역개정 DB 생성  — Sources/biblego/Resources/bible.sqlite
#    Tools/build_db/source/nkrv.json 이 먼저 있어야 합니다.
python3 Tools/build_db/build.py

# 2) .app 번들 빌드 + ad-hoc 서명  — build/biblego.app
./scripts/make_app.sh release

# 3) 실행
open build/biblego.app
```

개발 중 빠른 반복은 `swift build && swift run` 도 가능하지만, 메뉴바/권한 동작은
`.app` 번들로 실행하는 것을 권장합니다.

## 최초 설정 (중요)

캐럿 위치 읽기와 붙여넣기 합성에는 **손쉬운 사용(접근성)** 권한이 필요합니다.

1. 앱을 처음 실행하면 권한 요청이 뜹니다.
2. **시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용**에서 `biblego`를 허용.
3. 메뉴바 아이콘 메뉴의 “손쉬운 사용 권한 허용…”으로도 바로 이동할 수 있습니다.

> ad-hoc 서명은 재빌드할 때마다 서명 정체성이 바뀌어 권한을 다시 부여해야 할 수
> 있습니다. 자주 재빌드한다면 자체 서명 인증서(또는 Developer ID)로 서명하세요.

## 사용법

1. 입력 중인 앱에서 단축키(기본 ⌥Space)를 누릅니다.
2. 뜬 창에 입력:
   - 참조: `요 3:16`, `요한복음 3장 16절`, `창1:1-3`, `시 23`, `삼상3:1`, `고전 13:4~7`
   - 내용: `독생자`, `여호와는 나의 목자` 등 (2글자 이상)
3. `↑`/`↓` 로 후보 이동, `Enter` 또는 클릭으로 삽입, `esc` 로 닫기.

## 설정 (메뉴바 → 설정…)

- **단축키**: 검색 창 단축키 변경
- **삽입 방식**: `붙여넣기`(권장, 거의 모든 앱) / `직접 입력`(접근성 API, 지원 앱만)
- **구절 참조 함께 삽입**: 본문 뒤에 `(요한복음 3:16)` 형태로 출처 추가

## 구조

```
Sources/biblego/
  App/        BiblegoApp, AppDelegate, MenuContent     # 진입점 + 메뉴바
  Hotkey/     Shortcuts                                # 전역 단축키 정의
  Capture/    FocusContext, AXCaret                    # frontmost 앱 + 캐럿 위치
  Panel/      SearchPanel, SearchView, SearchViewModel # 검색 패널
  Insert/     TextInserter, Permissions                # 붙여넣기/직접삽입 + 권한
  Data/       BibleStore, ReferenceParser, Models      # DB + 검색 + 참조 파서
  Resources/  bible.sqlite                             # 동봉 개역개정 DB
Tools/build_db/  build.py + source/nkrv.json           # DB 빌더
scripts/         make_app.sh                           # .app 번들링
```

## 데이터 & 저작권

개역개정 본문의 저작권은 **대한성서공회**에 있습니다. 본 저장소/앱은 **개인적
사용** 목적으로만 사용하세요. 본문을 포함한 빌드(.app/.dmg)를 재배포하면 저작권을
침해할 수 있습니다. 데이터 출처: `Tools/build_db/source/nkrv.json` (개역개정 절
데이터, 저장소에 미포함).
