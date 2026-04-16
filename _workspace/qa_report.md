# Fullmoon QA Report

Date: 2026-04-15
QA Agent: fullmoon-qa
Target: /Users/lovecielmac/workspace/ciel-harness/fullmoon-reserved/

---

## 총평

**결론: PASS (조건부)**

- 설계서 ↔ 구현 정합성: 전부 일치
- 빌드: Swift 컴파일 성공 / 최종 링크는 **프리-이그지스팅** AppIntents 메타데이터 오류(RequestLLMIntent.swift:90)로 실패 — 빌더가 보고한 범위 외 이슈이며 본 작업 산출물과 무관
- 기존 기능 보존: Chat/Onboarding/LLMEvaluator 전부 무수정 (git diff empty)
- 새 코드에 force-unwrap, try!, as! 사용 없음
- Draw Things JSON 스키마와 공식 API 레퍼런스 간에 **키 네이밍 불일치 1건** (`seed` vs `initial_seed`) — WARNING

---

## 1. 경계면 교차 비교 (설계서 ↔ 구현)

### 1-1. ImagePrompt SwiftData 모델 — **PASS**

| 설계서 필드 | Data.swift:283-300 | 상태 |
|---|---|---|
| `id: UUID (@Attribute(.unique))` | 285행 `@Attribute(.unique) var id: UUID` | PASS |
| `userDescription: String` | 286행 | PASS |
| `positive: String` | 287행 | PASS |
| `negative: String` | 288행 | PASS |
| `timestamp: Date` | 289행 | PASS |
| `isFavorite: Bool` | 290행 | PASS |
| `init(userDescription:positive:negative:)` | 292-299행 (id=UUID(), timestamp=Date(), isFavorite=false 기본값 설정) | PASS |

파일: `/Users/lovecielmac/workspace/ciel-harness/fullmoon-reserved/fullmoon/Models/Data.swift`

### 1-2. AppManager Draw Things 설정 ↔ View Binding — **PASS**

| AppStorage (Data.swift:28-36) | DrawThingsSettingsView Binding | PromptBuilderView 프리뷰 |
|---|---|---|
| `dtWidth: Int = 768` | `$appManager.dtWidth` Stepper | `appManager.dtWidth` 표시 |
| `dtHeight: Int = 768` | `$appManager.dtHeight` Stepper | `appManager.dtHeight` 표시 |
| `dtSteps: Int = 30` | `$appManager.dtSteps` Stepper | `appManager.dtSteps` 표시 |
| `dtScale: Double = 7.5` | `$appManager.dtScale` Slider | `appManager.dtScale` 표시 |
| `dtSampler: String = "DPM++ 2M Karras"` | `$appManager.dtSampler` Picker | (DrawThingsConfig 내부) |
| `dtSeed: Int = -1` | `$appManager.dtSeed` Stepper | (DrawThingsConfig 내부) |
| `appMode: AppMode = .chat` | ContentView `Picker("Mode")` | — |

양방향 바인딩 전부 정상 연결.

### 1-3. DrawThingsURLBuilder JSON ↔ Draw Things API 스펙 — **WARNING**

**생성 JSON 구조 (DrawThingsURLBuilder.swift:70-83):**
```json
{
  "prompts": [{"positive": "...", "negative": "..."}],
  "config": [{"scale": 7.5, "steps": 30, "size": "768x768", "sampler": "DPM++ 2M Karras", "seed": -1}]
}
```

| 항목 | 설계서 예시 | 실제 구현 | API 레퍼런스 (draw-things-api.md) | 평가 |
|---|---|---|---|---|
| 최상위 구조 | `prompts: [{}], config: [{}]` | 일치 | 일치 | PASS |
| `prompts[0].positive/negative` | 일치 | 일치 | 일치 | PASS |
| `config[0].scale` | 있음 | 있음 | 있음 | PASS |
| `config[0].steps` | 있음 | 있음 | 있음 | PASS |
| `config[0].size` | "768x768" | `"\(w)x\(h)"` | "768x768" | PASS |
| `config[0].sampler` | 있음 | 있음 | 있음 | PASS |
| **seed 키** | `"seed": -1` | `"seed": config.seed` | **`"initial_seed": 42`** | **WARNING** |

**WARNING (draw-things-api.md line 32 vs DrawThingsURLBuilder.swift:80)**: 공식 Draw Things API 레퍼런스에는 seed 필드가 `"initial_seed"`로 문서화되어 있으나, 설계서와 구현은 `"seed"`를 사용. Draw Things 앱은 두 키를 모두 허용할 가능성은 있으나, **공식 키 이름은 `initial_seed`**. 설계서가 이 부분을 잘못 지정했고 빌더가 설계서를 따름. 실행 시 Draw Things에서 seed가 무시되고 랜덤으로 생성될 위험이 있음.

**수정 제안 (DrawThingsURLBuilder.swift:80)**:
```swift
// 현재:
"seed": config.seed
// 제안:
"initial_seed": config.seed
```
또한 `seed: -1`(random) 동작도 API 스펙상 명시되지 않음. Draw Things가 -1을 random으로 해석하지 않으면 잘못된 값이 됨. 실제 동작 테스트 필요.

**URL 인코딩 (DrawThingsURLBuilder.swift:90)** — **PASS**
`JSONSerialization.data` → `String(data:encoding:.utf8)` → `addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)` 순서로 정확. 설계서의 `try!`/`!` 강제 언래핑 대신 `guard let`으로 안전하게 `nil` 반환 (builder 결정사항 #5 준수).

### 1-4. modelContainer ↔ ImagePrompt 사용처 — **PASS**

- `fullmoonApp.swift:29`: `.modelContainer(for: [Thread.self, Message.self, ImagePrompt.self])` ✓
- `PromptHistoryListView.swift:14`: `@Query(sort: \ImagePrompt.timestamp, ...)` ✓
- `PromptBuilderView.swift:212`: `modelContext.insert(prompt)` ✓

### 1-5. ContentView AppMode 분기 ↔ AppMode enum — **PASS**

- `Data.swift:11-14`: `enum AppMode: String, CaseIterable { case chat; case prompt }`
- `ContentView.swift:29-30`:
  - `.tag(AppMode.chat)` ✓
  - `.tag(AppMode.prompt)` ✓
- `ContentView.swift:35, 45`: `if appManager.appMode == .chat` 분기 일관성 ✓

---

## 2. Swift 코드 품질

### 2-1. Force-unwrap — **PASS**

`grep -E "try!|!\.addingPercentEncoding|as!"` → **0 건**. 새로 작성된 모든 코드에서 강제 언래핑 제거됨 (builder 결정사항 #5 준수).

### 2-2. @MainActor / Observable 패턴 — **PASS**

- `ImagePromptGenerator.swift:10`: `@MainActor class ImagePromptGenerator` (설계서 준수)
- `DrawThingsURLBuilder`: 순수 static 함수, 스레드 안전
- `PromptBuilderView.generatePrompt()` (181행): `Task { await llm.generate(...) }` — LLMEvaluator가 `@MainActor`이므로 안전
- `PromptHistoryListView`: SwiftUI View는 기본적으로 MainActor, 문제 없음

### 2-3. SwiftUI @State/@Binding/@Environment — **PASS**

- `PromptBuilderView`: `@EnvironmentObject appManager`, `@Environment(\.modelContext)`, `@Environment(LLMEvaluator.self)`, `@Binding currentPrompt`, `@State userInput/positive/negative` — 올바른 사용
- `PromptHistoryListView`: `@Query`, `@Binding currentPrompt`, `@State search/selection` — 올바름
- `DrawThingsSettingsView`: `@EnvironmentObject appManager` + `$appManager.dt*` 바인딩 — 올바름

### 2-4. import 누락 — **PASS**

- `PromptBuilderView.swift`: `import SwiftData`, `import SwiftUI` 모두 존재
- `PromptHistoryListView.swift`: 동일
- `DrawThingsURLBuilder.swift`: `import Foundation` + `#if os(iOS)/visionOS` 아래 `import UIKit` (플랫폼 가드)
- `DrawThingsSettingsView.swift`: `import SwiftUI`
- `ImagePromptGenerator.swift`: `import Foundation`

### 2-5. 기타 — **INFO**

**INFO (PromptHistoryListView.swift:17-18, 41-43)**: `@State var selection`과 `@Binding var currentPrompt` 이중 상태. `onChange(of: selection)`으로 `currentPrompt = selection` 동기화. ChatsListView가 같은 패턴을 쓰고 있어 일관성은 OK이나, 단순화하려면 `List(selection: $currentPrompt)`로 직접 바인딩 가능.

**INFO (PromptBuilderView.swift:194-203)**: `llm.generate()`의 반환값을 `result` 변수에 받아 파싱하고, `positivePrompt`/`negativePrompt`를 `@State` 변수에 할당. `Task` 내부에서 MainActor 변수 업데이트 — LLMEvaluator가 `@MainActor`이므로 암묵적으로 MainActor 컨텍스트. 정상 동작.

---

## 3. iPad UX — **PASS**

- `ContentView.swift:24`: `.pad/.mac/.vision` 공통 `NavigationSplitView` 레이아웃
- 사이드바: `VStack { Picker(segmented) + (ChatsListView | PromptHistoryListView) }` — 설계서와 일치
- 디테일: `if appMode == .chat { ChatView } else { PromptBuilderView }` — 설계서와 일치
- `PromptBuilderView` 내부: `ScrollView` 감싸서 가로/세로 모드 모두 컨텐츠 오버플로 방지
- 플랫폼 가드: `#if os(iOS)` 블록으로 `navigationBarTitleDisplayMode` 분리, macOS 빌드도 깨지지 않음

**PromptBuilderView 액션바 (155-176행)**: `Save / Send to DT / DT+` 3버튼이 `HStack` + `frame(maxWidth: .infinity)`로 iPad 가로모드에서도 가로로 펼쳐짐. 좁은 폭에서 "Send to DT" 레이블이 잘릴 가능성이 있으나 깨지진 않음.

---

## 4. 빌드 검증

**명령**:
```bash
xcodebuild -project fullmoon.xcodeproj -scheme fullmoon \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  -derivedDataPath /tmp/fullmoon-qa CODE_SIGNING_ALLOWED=NO build
```

(지시된 M4 디바이스는 시뮬레이터에 부재, 사용 가능한 iPad Pro 13-inch M5로 대체)

**Swift 컴파일 결과**: 본 작업이 추가·수정한 **모든 파일** (Data.swift, DrawThingsURLBuilder.swift, ImagePromptGenerator.swift, PromptBuilderView.swift, PromptHistoryListView.swift, DrawThingsSettingsView.swift, ContentView.swift, SettingsView.swift, fullmoonApp.swift, Info.plist) → **컴파일 에러 0건 / 경고 0건**.

**최종 링크 결과**: `** BUILD FAILED **`

**실패 원인 (본 작업 범위 밖)**:
```
/Users/lovecielmac/workspace/ciel-harness/fullmoon-reserved/fullmoon/Models/RequestLLMIntent.swift:90:
error: Invalid Utterance. Every App Shortcut utterance should have one '${applicationName}' in it.
```
- **파일**: `fullmoon/Models/RequestLLMIntent.swift:90-98`
- **원인**: `NewChatShortcut.appShortcuts`의 첫 번째 phrase `"Start a new chat"`에 `\(.applicationName)`이 없음. App Shortcuts 검증기가 모든 발화에 appName 포함 강제.
- **분류**: **프리-이그지스팅 이슈**. `git diff fullmoon/Models/RequestLLMIntent.swift` → 0 diff. 빌드 보고서에서도 "설계서 범위 밖"으로 명시됨.
- **심각도**: CRITICAL for app-wide build, but **out-of-scope** for this QA. 본 작업 산출물과 무관.

**수정 제안 (선택사항, 범위 외)**:
```swift
// RequestLLMIntent.swift:94
"Start a new chat",  →  "Start a new \(.applicationName) chat",
```

---

## 5. 기존 기능 보존 — **PASS**

`git diff`로 확인:

| 파일/디렉토리 | diff 상태 |
|---|---|
| `fullmoon/Views/Chat/` (ChatView, ConversationView, ChatsListView, ChatInputView 등) | **0 diff** PASS |
| `fullmoon/Models/LLMEvaluator.swift` | **0 diff** PASS |
| `fullmoon/Models/Models.swift` | **0 diff** PASS |
| `fullmoon/Views/Onboarding/` | **0 diff** PASS |
| `fullmoon/Models/DeviceStat.swift` | **0 diff** PASS |
| `fullmoon/Models/RequestLLMIntent.swift` | **0 diff** PASS |

**수정된 파일**:
- ContentView.swift: iPad 블록에 사이드바 Picker/분기만 추가. iPhone 분기 및 기존 sheet/onboarding 로직 전부 유지
- Data.swift: 신규 ImagePrompt/AppMode + AppManager AppStorage 프로퍼티 추가. 기존 Thread/Message/AppTint/AppFont 무수정
- fullmoonApp.swift: `modelContainer`에 `ImagePrompt.self` 추가 + `.onOpenURL`만 추가. 기존 macOS AppDelegate 등 무수정
- SettingsView.swift: Draw Things 링크 1줄 추가만
- Info.plist: CFBundleURLTypes / LSApplicationQueriesSchemes 2 블록 추가만

기존 채팅 흐름 보존됨.

---

## 6. Info.plist — **PASS**

`/Users/lovecielmac/workspace/ciel-harness/fullmoon-reserved/fullmoon/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array><string>fullmoon</string></array>
        <key>CFBundleURLName</key>
        <string>com.fullmoon.app</string>
    </dict>
</array>
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>draw-things</string>
</array>
```

- `CFBundleURLTypes` → `fullmoon` scheme 등록 ✓ (x-callback-url 수신 가능)
- `LSApplicationQueriesSchemes` → `draw-things` 등록 ✓ (`canOpenURL` 쿼리 가능)
- 설계서와 정확히 일치

---

## 7. 발견된 이슈 총정리

| # | 심각도 | 파일:줄 | 내용 | 수정 제안 |
|---|---|---|---|---|
| 1 | **WARNING** | `DrawThingsURLBuilder.swift:80` | `"seed"` 키가 Draw Things API 공식 문서상 `"initial_seed"`. 설계서도 동일 오류. Draw Things 앱이 `"seed"`를 무시하고 random seed로 생성할 가능성 | `"seed": config.seed` → `"initial_seed": config.seed`. 또한 `-1 = random` 규약이 공식 스펙에 없으므로, `-1`일 때 `initial_seed` 키를 아예 생략하는 로직 추가 권장 |
| 2 | CRITICAL (out-of-scope) | `RequestLLMIntent.swift:90` | AppIntents 메타데이터 빌드 실패. 본 작업 범위 밖 / 프리-이그지스팅 | `"Start a new chat"` → `"Start a new \(.applicationName) chat"` |
| 3 | INFO | `PromptBuilderView.swift:155-176` | 3버튼 액션바에서 "Send to DT" 레이블이 좁은 Split View 가로모드에서 잘릴 수 있음 | 아이콘+라벨 중 라벨 축약(`"Send"`) 또는 VStack 2행 레이아웃 검토 |
| 4 | INFO | `PromptHistoryListView.swift:17-43` | `@State selection`과 `@Binding currentPrompt` 이중화 + onChange 동기화. ChatsListView 패턴 차용이라 일관성은 OK | 단순화 원하면 `List(selection: $currentPrompt)`로 직접 바인딩 |
| 5 | INFO | `DrawThingsSettingsView.swift:38` | `Seed` Stepper 범위 `-1...999999999`. -1 외 임의 수동 입력 UX 부재 (Stepper로 큰 수까지 클릭 불가) | TextField + "Random" 토글 조합 고려 |
| 6 | INFO | `ImagePromptGenerator.swift:10` | `@MainActor class`인데 인스턴스 메서드 없이 `static`만 사용. `enum` 또는 `@MainActor` 제거 가능 | `enum ImagePromptGenerator { static let ... static func ... }` |

---

## 8. 항목별 PASS/FAIL 요약

| 검증 항목 | 상태 |
|---|---|
| 1-1 ImagePrompt @Model 스키마 | **PASS** |
| 1-2 AppManager Draw Things 설정 바인딩 | **PASS** |
| 1-3 Draw Things URL JSON 구조 | **WARNING** (seed 키 이름) |
| 1-4 modelContainer 등록 | **PASS** |
| 1-5 AppMode enum 분기 | **PASS** |
| 2-1 Force-unwrap 미사용 | **PASS** |
| 2-2 @MainActor 적절성 | **PASS** |
| 2-3 SwiftUI 상태 관리 | **PASS** |
| 2-4 import 누락 없음 | **PASS** |
| 3 iPad NavigationSplitView UX | **PASS** |
| 4 Swift 컴파일 | **PASS** (본 작업 코드 에러 0건) |
| 4 최종 링크 | **FAIL** (범위 외 AppIntents 이슈) |
| 5 기존 Chat/LLMEvaluator 보존 | **PASS** |
| 6 Info.plist URL scheme 등록 | **PASS** |

---

## 9. 최종 판정

**설계서와 구현의 정합성, 코드 품질, 기존 기능 보존 모두 PASS**.

- WARNING 1건 (`seed` 키 이름)은 설계서의 오류를 빌더가 그대로 따른 결과이므로 **설계서 + 빌더 코드 양쪽을 수정**하거나, Draw Things 앱이 실제로 `"seed"` 키를 허용하는지 실기기에서 검증 필요
- 빌드 최종 실패는 **범위 외 프리-이그지스팅 이슈** (RequestLLMIntent.swift, 작업 전부터 존재)
- Swift 컴파일 단위로는 본 작업 코드가 전부 무오류로 컴파일됨

**Ship 가능 여부**: 이슈 #1 검증 후 / 또는 이슈 #2 함께 수정 후 머지 권장.
