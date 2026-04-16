# fullmoon-reserved Worklog

## 2026-04-16 — 프로젝트 시작 + Draw Things 연동 기능 구현

### 프로젝트 개요
- iPad 전용 Fullmoon 포크. 로컬 LLM(MLX)으로 이미지 프롬프트를 생성하고 Draw Things 앱에 전달
- 베이스: `mainframecomputer/fullmoon-ios` → fork: `ErikKim/fullmoon-ios`
- macOS 타겟 제외 (Mac은 Ollama + ComfyUI 조합으로 별도 해결)

### 환경 셋업
- Xcode 26.4 설치 및 활성화 (`xcode-select -s /Applications/Xcode.app/Contents/Developer`)
- Fork 생성 및 `fullmoon-reserved/` 에 clone, upstream 연결
- `.claude/` 하네스 구성 (agents 3개 + skills 3개 + orchestrator)

### 구현 기능

#### 1. 이미지 프롬프트 빌더 모드
- `AppMode` enum 추가 (chat / prompt)
- iPad 사이드바에 Segmented Picker로 모드 전환
- LLM 재사용: `ImagePromptGenerator.systemPrompt` 로 "SD 프롬프트 전문가" 역할 부여
- LLM 출력에서 `POSITIVE: ...` / `NEGATIVE: ...` 파싱
- 실패 시 fallback negative 프롬프트 자동 주입

#### 2. Draw Things URL Scheme 연동
- `DrawThingsURLBuilder` 유틸리티 — 3가지 모드
  - `generateURL()`: 풀 설정 포함
  - `generateURLWithCallback()`: x-callback-url 포함 (생성 후 fullmoon 복귀)
  - `promptOnlyURL()`: 프롬프트만 주입 (Draw Things 현재 설정 유지)
- `Info.plist`:
  - `CFBundleURLTypes`: `fullmoon://` 등록 (callback 수신)
  - `LSApplicationQueriesSchemes`: `draw-things` 추가
- `fullmoonApp.swift`: `.onOpenURL` 핸들러

#### 3. Draw Things 설정 화면
- Width/Height (Stepper, 256-2048, 64 step)
- Steps (1-150), CFG Scale (Slider, 1-30), Sampler (Picker)
- Seed (-1 = random)
- `AppManager` `@AppStorage` 로 영속화

#### 4. 프롬프트 히스토리
- `ImagePrompt` SwiftData @Model 추가 (id, userDescription, positive, negative, timestamp, isFavorite)
- `PromptHistoryListView`: 사이드바 목록, 검색, 삭제

### 파일 변경 통계

| 구분 | 파일 |
|------|------|
| 신규 | `Models/DrawThingsURLBuilder.swift`, `Models/ImagePromptGenerator.swift`, `Views/PromptBuilder/PromptBuilderView.swift`, `Views/PromptBuilder/PromptHistoryListView.swift`, `Views/Settings/DrawThingsSettingsView.swift` |
| 수정 | `Models/Data.swift`, `fullmoonApp.swift`, `ContentView.swift`, `Views/Settings/SettingsView.swift`, `Info.plist` |
| 프로젝트 설정 | `fullmoon.xcodeproj/project.pbxproj` — `mlx-swift-examples` main 브랜치에서 `2.29.1` 고정 (main에서 MLXLLM/MLXLMCommon 제거 중), `swift-transformers` `1.0.0..<1.1.0` 업데이트 |
| 미변경 (보존) | `Views/Chat/*`, `Models/LLMEvaluator.swift`, `Models/Models.swift`, `Models/DeviceStat.swift`, `Onboarding/*` |

### QA 결과
- 설계↔구현 정합성: PASS
- 기존 채팅 기능 0 diff 보존 확인
- Swift 코드 품질: force-unwrap 0건, @MainActor / import 전부 정상
- **WARNING 1건 수정**: `DrawThingsURLBuilder.swift:80` `seed` → `initial_seed` (Draw Things API 공식 키)
- 빌드: 신규/수정 Swift 파일 전부 컴파일 통과

### 미해결 이슈 (별도 티켓)
- `Models/RequestLLMIntent.swift:90` — AppShortcut utterance 에 `\(.applicationName)` 누락. 포크 원본부터 존재하는 버그로, 빌드 최종 링크 실패 원인. 본 작업 범위 밖

### 다음 할 일
- [ ] `RequestLLMIntent` AppShortcut 버그 수정 (빌드 통과 조건)
- [ ] iPad 실기 테스트 (Apple ID 무료 프로비저닝, 7일 재빌드 감수)
- [ ] 실사용 UX 피드백 기반 버튼 배치 / 모드 전환 다듬기
- [ ] 장르별 시스템 프롬프트 분리 (애니 / 실사 / 풍경)
- [ ] x-callback-url 복귀 시 생성된 이미지 미리보기 기능
