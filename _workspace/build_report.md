# Fullmoon Build Report

Date: 2026-04-15
Builder: fullmoon-builder agent

## 변경 파일 목록

### 신규 생성 (5개)

| 파일 | 역할 |
|------|------|
| `fullmoon/Models/DrawThingsURLBuilder.swift` | Draw Things URL scheme 빌더. `DrawThingsConfig` 구조체 + `generateURL`/`generateURLWithCallback`/`promptOnlyURL` 메서드 + 설치 확인 |
| `fullmoon/Models/ImagePromptGenerator.swift` | LLM 시스템 프롬프트 + positive/negative 파서 (`parsePromptOutput`) |
| `fullmoon/Views/PromptBuilder/PromptBuilderView.swift` | 프롬프트 빌더 메인 UI (자연어 입력 + LLM 생성 + Positive/Negative 편집 + Save/Send/DT+) |
| `fullmoon/Views/PromptBuilder/PromptHistoryListView.swift` | 사이드바 프롬프트 히스토리 (SwiftData `@Query`, 검색, 삭제) |
| `fullmoon/Views/Settings/DrawThingsSettingsView.swift` | Draw Things 생성 파라미터(width/height/steps/CFG/sampler/seed) Form |

### 수정 (5개)

| 파일 | 변경 내용 |
|------|----------|
| `fullmoon/Models/Data.swift` | `AppMode` enum 추가, `AppManager`에 Draw Things 설정 (dtWidth/dtHeight/dtSteps/dtScale/dtSampler/dtSeed) + `appMode` 추가, `ImagePrompt @Model` 추가 |
| `fullmoon/fullmoonApp.swift` | `modelContainer`에 `ImagePrompt.self` 추가, `.onOpenURL`로 `fullmoon://` 콜백 수신 |
| `fullmoon/ContentView.swift` | `@State currentPrompt` 추가, iPad NavigationSplitView 사이드바 상단에 Chats/Prompts Segmented Picker, `appMode`에 따라 `ChatsListView`/`PromptHistoryListView` 및 `ChatView`/`PromptBuilderView` 분기 |
| `fullmoon/Views/Settings/SettingsView.swift` | "Draw Things" 네비게이션 링크 1개 추가 |
| `fullmoon/Info.plist` | `CFBundleURLTypes`(fullmoon scheme) + `LSApplicationQueriesSchemes`(draw-things) 추가 |

### 프로젝트 설정 수정 (1개)

| 파일 | 변경 내용 |
|------|----------|
| `fullmoon.xcodeproj/project.pbxproj` | `mlx-swift-examples`를 `branch: main` → `exactVersion: 2.29.1`로 변경 (main 브랜치가 MLXLLM/MLXLMCommon 프로덕트를 제거하는 리팩터링 진행 중), `swift-transformers`를 `0.1.17 upToNextMajor` → `1.0.0 upToNextMinor`로 업데이트 (mlx-swift-examples 2.29.1이 요구하는 버전) |

## 주요 결정사항

1. **LLMEvaluator 재사용**: 지시대로 LLMEvaluator는 수정하지 않고, `PromptBuilderView.generatePrompt()`에서 임시 `Thread`를 생성하여 `llm.generate(modelName:, thread:, systemPrompt: ImagePromptGenerator.systemPrompt)`를 호출했다. 결과는 `ImagePromptGenerator.parsePromptOutput()`으로 파싱.

2. **플랫폼 가드**: `UIApplication`은 macOS에서 사용 불가하므로 `#if os(iOS) || os(visionOS)`로 감쌌다. `DrawThingsURLBuilder.isDrawThingsInstalled()`도 동일하게 처리.

3. **SwiftData 패턴**: `PromptHistoryListView`는 `ChatsListView` 패턴을 따라 `@Query(sort: \ImagePrompt.timestamp, order: .reverse)`, `List(selection:)`, `.searchable(text:)`, `.onDelete` 삭제, 툴바의 새 항목 추가 버튼을 구현.

4. **iPad NavigationSplitView**: 사이드바 최상단에 `Picker(pickerStyle: .segmented)`로 모드를 전환하고, `if appManager.appMode == .chat`으로 사이드바/디테일 모두 분기. iPhone 레이아웃은 기존 `ChatView` 단일 화면 유지 (설계서에서 iPad 우선 규칙 준수).

5. **URL 빌더 에러 처리**: `try!`를 `guard let`/`return nil`로 변경하여 크래시 대신 `nil` 반환. 호출 측에서 Alert로 사용자에게 고지.

6. **x-callback-url**: `fullmoon://callback?status=success`로 돌아오며, `fullmoonApp.handleIncomingURL`에서 스킴만 검증(현재는 no-op). 향후 확장 가능.

7. **AppManager confirmation**: 기존 `@AppStorage` + `ObservableObject` 패턴 그대로 사용. `AppStorage`가 `Int`/`Double`/`String`은 기본 지원, `AppMode`(RawRepresentable String enum)도 자동으로 직렬화 됨.

## 빌드 결과

```
xcodebuild -project fullmoon.xcodeproj -scheme fullmoon \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  -derivedDataPath /tmp/dd CODE_SIGNING_ALLOWED=NO build
```

- **Swift 컴파일**: 새로 추가/수정한 모든 파일(Data.swift, DrawThingsURLBuilder.swift, ImagePromptGenerator.swift, PromptBuilderView.swift, PromptHistoryListView.swift, DrawThingsSettingsView.swift, ContentView.swift, SettingsView.swift, fullmoonApp.swift) **에러 없이 컴파일 성공**.
- **잔존 에러** (우리 변경과 무관한 프리-이그지스팅 이슈):
  - `RequestLLMIntent.swift:90` - AppShortcut utterance validation 경고 ("Start a new chat"에 `${applicationName}`가 없다). 설계서 범위 밖이라 수정하지 않음.
- **환경 이슈** (해결됨):
  - `mlx-swift-examples`의 main 브랜치가 최근 리팩터링되어 MLXLLM/MLXLMCommon 프로덕트가 제거됨 → 2.29.1 태그로 고정.
  - Metal Toolchain 미설치 → `xcodebuild -downloadComponent MetalToolchain`로 다운로드.
  - 기본 DerivedData 경로에서 git 서브모듈 클론 실패 → `-derivedDataPath /tmp/dd`로 우회.

## 테스트 체크리스트 (수동)

- [ ] iPad 시뮬레이터에서 앱 실행 → 사이드바에 `[Chats] [Prompts]` Segmented Picker 표시 확인
- [ ] Prompts 탭 클릭 → `PromptBuilderView`가 디테일 영역에 표시
- [ ] 자연어 입력 → "Generate Prompt" → LLM이 POSITIVE/NEGATIVE 포맷으로 응답, 파싱되어 각 TextEditor에 표시
- [ ] "Save" → SwiftData에 저장되고 사이드바 히스토리에 추가
- [ ] 히스토리 항목 선택 → userInput/positive/negative 필드에 복원
- [ ] "Send to DT" → `draw-things://` URL로 Draw Things 앱 전환 (iPad에 Draw Things 설치 필요)
- [ ] "DT+" → x-callback-url로 호출, 생성 완료 후 fullmoon 자동 복귀
- [ ] Settings → "Draw Things" → width/height/steps/CFG/sampler/seed 변경 가능
