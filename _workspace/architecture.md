# Fullmoon - Draw Things 이미지 프롬프트 빌더 아키텍처 설계서

## 1. 설계 원칙

- **최소 침습**: 기존 Chat 기능 코드는 거의 수정하지 않음. 새 파일 추가 위주
- **기존 패턴 존중**: AppManager(@AppStorage), SwiftData(@Model), LLMEvaluator 재사용
- **iPad 우선**: NavigationSplitView 사이드바에 모드 탭(Chats/Prompts) 추가

---

## 2. 수정 대상 파일 목록

### 2-1. `fullmoon/Models/Data.swift`
**변경 내용**: 새 SwiftData 모델 추가 + AppManager 확장

```swift
// === 추가할 SwiftData 모델 ===

@Model
final class ImagePrompt {
    @Attribute(.unique) var id: UUID
    var userDescription: String      // 사용자가 입력한 자연어 설명
    var positive: String             // 생성된 positive 프롬프트
    var negative: String             // 생성된 negative 프롬프트
    var timestamp: Date
    var isFavorite: Bool

    init(userDescription: String, positive: String, negative: String) {
        self.id = UUID()
        self.userDescription = userDescription
        self.positive = positive
        self.negative = negative
        self.timestamp = Date()
        self.isFavorite = false
    }
}

// === AppManager에 추가할 프로퍼티 ===

// Draw Things 기본 설정
@AppStorage("dtWidth") var dtWidth: Int = 768
@AppStorage("dtHeight") var dtHeight: Int = 768
@AppStorage("dtSteps") var dtSteps: Int = 30
@AppStorage("dtScale") var dtScale: Double = 7.5
@AppStorage("dtSampler") var dtSampler: String = "DPM++ 2M Karras"
@AppStorage("dtSeed") var dtSeed: Int = -1  // -1 = random

// 현재 모드
@AppStorage("appMode") var appMode: AppMode = .chat

// === 추가할 열거형 ===
enum AppMode: String, CaseIterable {
    case chat       // 기존 채팅 모드
    case prompt     // 이미지 프롬프트 빌더 모드
}
```

### 2-2. `fullmoon/fullmoonApp.swift`
**변경 내용**: SwiftData modelContainer에 `ImagePrompt.self` 추가

```swift
// 기존:
.modelContainer(for: [Thread.self, Message.self])

// 변경:
.modelContainer(for: [Thread.self, Message.self, ImagePrompt.self])
```

URL scheme 핸들러 추가 (x-callback-url 수신):
```swift
.onOpenURL { url in
    // draw-things://x-callback-url 결과 수신 처리
    handleIncomingURL(url)
}
```

### 2-3. `fullmoon/ContentView.swift`
**변경 내용**: iPad NavigationSplitView 사이드바에 모드 전환 추가

```swift
// 기존 사이드바:
ChatsListView(...)

// 변경 - 사이드바에 Picker 상단 추가:
NavigationSplitView {
    VStack(spacing: 0) {
        // 모드 전환 Picker
        Picker("Mode", selection: $appManager.appMode) {
            Label("Chats", systemImage: "message").tag(AppMode.chat)
            Label("Prompts", systemImage: "paintbrush").tag(AppMode.prompt)
        }
        .pickerStyle(.segmented)
        .padding()

        // 모드에 따른 사이드바 내용
        if appManager.appMode == .chat {
            ChatsListView(currentThread: $currentThread, isPromptFocused: $isPromptFocused)
        } else {
            PromptHistoryListView(currentPrompt: $currentPrompt)
        }
    }
} detail: {
    if appManager.appMode == .chat {
        ChatView(...)
    } else {
        PromptBuilderView(currentPrompt: $currentPrompt)
    }
}
```

새 @State 추가:
```swift
@State var currentPrompt: ImagePrompt?
```

### 2-4. `fullmoon/Views/Settings/SettingsView.swift`
**변경 내용**: Draw Things 설정 네비게이션 링크 1개 추가

```swift
// Section 내부에 추가:
NavigationLink(destination: DrawThingsSettingsView()) {
    Label("Draw Things", systemImage: "paintbrush.pointed")
}
```

### 2-5. `fullmoon/Info.plist`
**변경 내용**: URL scheme 등록 (fullmoon:// x-callback-url 수신용)

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>fullmoon</string>
        </array>
        <key>CFBundleURLName</key>
        <string>com.fullmoon.app</string>
    </dict>
</array>
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>draw-things</string>
</array>
```

---

## 3. 새로 생성할 파일 목록

### 3-1. `fullmoon/Views/PromptBuilder/PromptBuilderView.swift`
**역할**: 이미지 프롬프트 빌더 메인 UI

구성:
- 상단: 사용자 자연어 입력 영역 ("A cat sitting on a moon" 등)
- 중단: 생성된 positive/negative 프롬프트 표시 (편집 가능)
- 하단: "Send to Draw Things" 버튼 + 설정 프리뷰 (size, steps)

LLMEvaluator를 재사용하여 프롬프트 생성. 시스템 프롬프트만 이미지 전문가용으로 교체.

```swift
struct PromptBuilderView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.modelContext) var modelContext
    @Environment(LLMEvaluator.self) var llm
    @Binding var currentPrompt: ImagePrompt?

    @State private var userInput = ""
    @State private var positivePrompt = ""
    @State private var negativePrompt = ""
    @State private var showDrawThingsSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // 사용자 입력 영역
                userInputSection

                Divider()

                // 생성된 프롬프트 표시/편집
                promptResultSection

                Spacer()

                // 하단 액션 바
                actionBar
            }
            .padding()
            .navigationTitle("Prompt Builder")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // "Generate Prompt" 버튼 → LLM 호출
    func generatePrompt() {
        // 임시 Thread를 만들어 LLMEvaluator.generate() 호출
        // 시스템 프롬프트: imagePromptSystemPrompt (아래 정의)
        // 결과를 파싱하여 positive/negative 분리
    }

    // "Send to Draw Things" 버튼
    func sendToDrawThings() {
        let url = DrawThingsURLBuilder.generateURL(
            positive: positivePrompt,
            negative: negativePrompt,
            config: DrawThingsConfig.from(appManager)
        )
        UIApplication.shared.open(url)
    }

    // 프롬프트 저장
    func savePrompt() {
        let prompt = ImagePrompt(
            userDescription: userInput,
            positive: positivePrompt,
            negative: negativePrompt
        )
        modelContext.insert(prompt)
        try? modelContext.save()
        currentPrompt = prompt
    }
}
```

### 3-2. `fullmoon/Views/PromptBuilder/PromptHistoryListView.swift`
**역할**: 사이드바에 표시되는 프롬프트 히스토리 목록

```swift
struct PromptHistoryListView: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \ImagePrompt.timestamp, order: .reverse) var prompts: [ImagePrompt]
    @Binding var currentPrompt: ImagePrompt?
    @State var search = ""

    var body: some View {
        NavigationStack {
            List(selection: $currentPrompt) {
                ForEach(filteredPrompts) { prompt in
                    VStack(alignment: .leading) {
                        Text(prompt.userDescription).lineLimit(1).font(.headline)
                        Text(prompt.positive).lineLimit(2).font(.caption).foregroundStyle(.secondary)
                        Text(prompt.timestamp.formatted()).font(.caption2).foregroundStyle(.tertiary)
                    }
                    .tag(prompt)
                }
                .onDelete(perform: deletePrompts)
            }
            .navigationTitle("Prompts")
            .searchable(text: $search, prompt: "search")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { currentPrompt = nil }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}
```

### 3-3. `fullmoon/Views/Settings/DrawThingsSettingsView.swift`
**역할**: Draw Things 생성 파라미터 커스터마이즈 화면

```swift
struct DrawThingsSettingsView: View {
    @EnvironmentObject var appManager: AppManager

    let samplers = ["DPM++ 2M Karras", "Euler a", "DDIM", "UniPC", "LCM"]
    let sizes = ["512x512", "768x768", "768x1024", "1024x1024"]

    var body: some View {
        Form {
            Section(header: Text("Image Size")) {
                Picker("Size", selection: $appManager.dtWidth) {
                    // 프리셋 기반 or Stepper로 직접 입력
                }
                // 또는 width/height 개별 Stepper
                Stepper("Width: \(appManager.dtWidth)", value: $appManager.dtWidth, in: 256...2048, step: 64)
                Stepper("Height: \(appManager.dtHeight)", value: $appManager.dtHeight, in: 256...2048, step: 64)
            }

            Section(header: Text("Generation")) {
                Stepper("Steps: \(appManager.dtSteps)", value: $appManager.dtSteps, in: 1...150)
                HStack {
                    Text("CFG Scale: \(appManager.dtScale, specifier: "%.1f")")
                    Slider(value: $appManager.dtScale, in: 1...30, step: 0.5)
                }
                Picker("Sampler", selection: $appManager.dtSampler) {
                    ForEach(samplers, id: \.self) { Text($0) }
                }
            }

            Section(header: Text("Seed")) {
                Stepper("Seed: \(appManager.dtSeed == -1 ? "Random" : "\(appManager.dtSeed)")",
                        value: $appManager.dtSeed, in: -1...Int.max)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Draw Things")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

### 3-4. `fullmoon/Models/DrawThingsURLBuilder.swift`
**역할**: Draw Things URL scheme 생성 유틸리티

```swift
import Foundation

struct DrawThingsConfig {
    var width: Int
    var height: Int
    var steps: Int
    var scale: Double
    var sampler: String
    var seed: Int

    static func from(_ appManager: AppManager) -> DrawThingsConfig {
        DrawThingsConfig(
            width: appManager.dtWidth,
            height: appManager.dtHeight,
            steps: appManager.dtSteps,
            scale: appManager.dtScale,
            sampler: appManager.dtSampler,
            seed: appManager.dtSeed
        )
    }
}

struct DrawThingsURLBuilder {

    /// 기본 generate URL 생성
    static func generateURL(positive: String, negative: String, config: DrawThingsConfig) -> URL {
        let settings: [String: Any] = [
            "prompts": [
                [
                    "positive": positive,
                    "negative": negative
                ]
            ],
            "config": [
                [
                    "scale": config.scale,
                    "steps": config.steps,
                    "size": "\(config.width)x\(config.height)",
                    "sampler": config.sampler,
                    "seed": config.seed
                ]
            ]
        ]

        let jsonData = try! JSONSerialization.data(withJSONObject: settings)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        let encoded = jsonString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!

        return URL(string: "draw-things://generate?output=canvas&settings=\(encoded)")!
    }

    /// x-callback-url 포함 버전 (생성 후 fullmoon으로 복귀)
    static func generateURLWithCallback(positive: String, negative: String, config: DrawThingsConfig) -> URL {
        let settings: [String: Any] = [
            "prompts": [
                ["positive": positive, "negative": negative]
            ],
            "config": [
                [
                    "scale": config.scale,
                    "steps": config.steps,
                    "size": "\(config.width)x\(config.height)",
                    "sampler": config.sampler,
                    "seed": config.seed
                ]
            ]
        ]

        let jsonData = try! JSONSerialization.data(withJSONObject: settings)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        let encoded = jsonString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!

        let successURL = "fullmoon://callback?status=success".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!

        return URL(string: "draw-things://x-callback-url/generate?output=canvas&settings=\(encoded)&x-success=\(successURL)")!
    }

    /// 프롬프트만 주입 (Draw Things의 현재 설정 유지)
    static func promptOnlyURL(positive: String, negative: String) -> URL {
        let settings: [String: Any] = [
            "prompts": [
                ["positive": positive, "negative": negative]
            ]
        ]

        let jsonData = try! JSONSerialization.data(withJSONObject: settings)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        let encoded = jsonString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!

        return URL(string: "draw-things://generate?settings=\(encoded)")!
    }
}
```

### 3-5. `fullmoon/Models/ImagePromptGenerator.swift`
**역할**: LLM을 이용한 이미지 프롬프트 생성 로직 (LLMEvaluator 래퍼)

```swift
import Foundation

@MainActor
class ImagePromptGenerator {

    /// 이미지 프롬프트 전문가용 시스템 프롬프트
    static let systemPrompt = """
    You are an expert Stable Diffusion prompt engineer. The user will describe an image they want to create. Your job is to convert their description into an optimized Stable Diffusion prompt.

    RULES:
    1. Output ONLY in this exact format, nothing else:
    POSITIVE: <comma-separated tags and descriptors>
    NEGATIVE: <comma-separated negative tags>

    2. For POSITIVE prompts:
    - Start with the subject, then style, then details
    - Use parentheses for emphasis: (important detail), ((very important))
    - Include quality boosters: masterpiece, best quality, highly detailed, 8k, sharp focus
    - Add lighting, camera angle, and atmosphere descriptors
    - Use danbooru-style tags mixed with natural language

    3. For NEGATIVE prompts:
    - Always include: lowres, bad anatomy, bad hands, text, error, missing fingers, extra digit, fewer digits, cropped, worst quality, low quality, normal quality, jpeg artifacts, signature, watermark, username, blurry
    - Add context-specific negatives based on the subject

    4. Keep prompts concise but descriptive (under 200 tokens each)
    """

    /// LLM 출력에서 positive/negative를 파싱
    static func parsePromptOutput(_ output: String) -> (positive: String, negative: String) {
        var positive = ""
        var negative = ""

        let lines = output.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.uppercased().hasPrefix("POSITIVE:") {
                positive = String(trimmed.dropFirst("POSITIVE:".count)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.uppercased().hasPrefix("NEGATIVE:") {
                negative = String(trimmed.dropFirst("NEGATIVE:".count)).trimmingCharacters(in: .whitespaces)
            }
        }

        // fallback: 파싱 실패 시 전체를 positive로
        if positive.isEmpty && negative.isEmpty {
            positive = output.trimmingCharacters(in: .whitespacesAndNewlines)
            negative = "lowres, bad anatomy, bad hands, text, error, worst quality, low quality, jpeg artifacts, watermark, blurry"
        }

        return (positive, negative)
    }
}
```

---

## 4. 새 SwiftData @Model 스키마

```
ImagePrompt (@Model)
├── id: UUID (@Attribute(.unique))
├── userDescription: String       // 사용자 원본 설명 ("달 위에 앉은 고양이")
├── positive: String              // SD positive prompt
├── negative: String              // SD negative prompt
├── timestamp: Date               // 생성 시각
└── isFavorite: Bool              // 즐겨찾기 여부
```

기존 Thread/Message 모델은 **수정 없음**. 프롬프트 빌더는 임시 Thread를 생성하여 LLM과 대화 후, 결과만 ImagePrompt에 저장.

---

## 5. UI 화면 흐름

```
[앱 시작]
    │
    ▼
[ContentView] ─── 온보딩 필요? ──→ [OnboardingView] (기존 유지)
    │
    ▼
[NavigationSplitView]
    ┌─────────────────────┬──────────────────────────────────┐
    │   SIDEBAR           │   DETAIL                         │
    │                     │                                  │
    │ ┌─────────────────┐ │                                  │
    │ │[Chat] [Prompts] │ │  ← Segmented Picker             │
    │ └─────────────────┘ │                                  │
    │                     │                                  │
    │ ─── Chat 모드 ───   │  [ChatView] (기존 유지)           │
    │ │ 채팅 목록        │ │                                  │
    │ │ - thread 1      │ │                                  │
    │ │ - thread 2      │ │                                  │
    │                     │                                  │
    │ ─── Prompt 모드 ── │  [PromptBuilderView]             │
    │ │ 프롬프트 히스토리│ │  ┌──────────────────────────┐   │
    │ │ - "cat on moon" │ │  │ 설명 입력                 │   │
    │ │ - "sunset city" │ │  │ [________________________] │   │
    │ │ - "anime girl"  │ │  │                            │   │
    │                     │  │ [Generate Prompt] 버튼     │   │
    │ [+] 새 프롬프트    │  │                            │   │
    │                     │  │ ── Positive ──────────── │   │
    │                     │  │ masterpiece, cat, moon...│   │
    │                     │  │ (편집 가능 TextEditor)    │   │
    │                     │  │                            │   │
    │                     │  │ ── Negative ──────────── │   │
    │                     │  │ lowres, bad anatomy...   │   │
    │                     │  │ (편집 가능 TextEditor)    │   │
    │                     │  │                            │   │
    │                     │  │ ── 미리보기 ────────────  │   │
    │                     │  │ 768x768 | 30 steps | 7.5 │   │
    │                     │  │                            │   │
    │                     │  │ [Save] [Send to DT] [DT+] │   │
    │                     │  └──────────────────────────┘   │
    └─────────────────────┴──────────────────────────────────┘

[설정 화면]
    └─ [Draw Things] ←── 새 메뉴
         ├─ Width / Height (Stepper)
         ├─ Steps (Stepper)
         ├─ CFG Scale (Slider)
         ├─ Sampler (Picker)
         └─ Seed (Stepper / Random)
```

### 버튼 동작 설명

| 버튼 | 동작 |
|------|------|
| **Generate Prompt** | LLM에 시스템 프롬프트 + 사용자 설명 전송 → positive/negative 파싱 → 결과 표시 |
| **Save** | ImagePrompt를 SwiftData에 저장, 사이드바 히스토리에 추가 |
| **Send to DT** | `draw-things://generate?settings={JSON}` URL로 Draw Things 실행 |
| **DT+** (callback) | x-callback-url로 전송, 생성 완료 후 fullmoon으로 자동 복귀 |

---

## 6. Draw Things URL 구성 코드 예시

### 기본 생성 호출

```swift
// 사용 예시
let config = DrawThingsConfig.from(appManager)
let url = DrawThingsURLBuilder.generateURL(
    positive: "masterpiece, best quality, (cat sitting on crescent moon:1.3), starry night sky, studio ghibli style, soft lighting, 8k, highly detailed",
    negative: "lowres, bad anatomy, bad hands, text, error, worst quality, low quality, jpeg artifacts, watermark, blurry, deformed",
    config: config
)

// 생성되는 URL:
// draw-things://generate?output=canvas&settings={"prompts":[{"positive":"masterpiece, best quality, (cat sitting on crescent moon:1.3), starry night sky, studio ghibli style, soft lighting, 8k, highly detailed","negative":"lowres, bad anatomy, bad hands, text, error, worst quality, low quality, jpeg artifacts, watermark, blurry, deformed"}],"config":[{"scale":7.5,"steps":30,"size":"768x768","sampler":"DPM++ 2M Karras","seed":-1}]}

// iPad에서 실행
await UIApplication.shared.open(url)
```

### x-callback-url 포함 호출

```swift
let url = DrawThingsURLBuilder.generateURLWithCallback(
    positive: positivePrompt,
    negative: negativePrompt,
    config: config
)
// draw-things://x-callback-url/generate?output=canvas&settings={...}&x-success=fullmoon://callback?status=success
await UIApplication.shared.open(url)
```

### 프롬프트만 주입 (Draw Things 설정 유지)

```swift
let url = DrawThingsURLBuilder.promptOnlyURL(
    positive: "anime girl, cherry blossom, spring",
    negative: "lowres, bad anatomy"
)
// draw-things://generate?settings={"prompts":[{"positive":"...","negative":"..."}]}
```

### Draw Things 설치 확인

```swift
func isDrawThingsInstalled() -> Bool {
    UIApplication.shared.canOpenURL(URL(string: "draw-things://")!)
}
```

---

## 7. 시스템 프롬프트 예시 (이미지 프롬프트 생성용)

```
You are an expert Stable Diffusion prompt engineer. The user will describe an image they want to create. Your job is to convert their description into an optimized Stable Diffusion prompt.

RULES:
1. Output ONLY in this exact format, nothing else:
POSITIVE: <comma-separated tags and descriptors>
NEGATIVE: <comma-separated negative tags>

2. For POSITIVE prompts:
- Start with the subject, then style, then details
- Use parentheses for emphasis: (important detail), ((very important))
- Include quality boosters: masterpiece, best quality, highly detailed, 8k, sharp focus
- Add lighting, camera angle, and atmosphere descriptors
- Use danbooru-style tags mixed with natural language

3. For NEGATIVE prompts:
- Always include: lowres, bad anatomy, bad hands, text, error, missing fingers, extra digit, fewer digits, cropped, worst quality, low quality, normal quality, jpeg artifacts, signature, watermark, username, blurry
- Add context-specific negatives based on the subject

4. Keep prompts concise but descriptive (under 200 tokens each)
```

### LLM 입출력 예시

**사용자 입력**: "달 위에 앉아 있는 고양이, 지브리 스타일"

**LLM 출력**:
```
POSITIVE: masterpiece, best quality, (cat sitting on crescent moon:1.3), starry night sky, (studio ghibli style:1.2), soft pastel colors, warm lighting, whimsical atmosphere, highly detailed fur, sparkling stars, dreamy background, 8k, sharp focus, illustration
NEGATIVE: lowres, bad anatomy, bad hands, text, error, missing fingers, extra digit, fewer digits, cropped, worst quality, low quality, normal quality, jpeg artifacts, signature, watermark, username, blurry, realistic, photographic, 3d render, deformed cat
```

---

## 8. 파일 구조 요약 (변경 후)

```
fullmoon/
├── fullmoonApp.swift              ← [수정] modelContainer에 ImagePrompt 추가, onOpenURL 핸들러
├── ContentView.swift              ← [수정] 사이드바 모드 전환 Picker, Prompt 모드 분기
├── Info.plist                     ← [수정] URL scheme 등록 (fullmoon://), LSApplicationQueriesSchemes
├── Models/
│   ├── Data.swift                 ← [수정] ImagePrompt @Model, AppManager에 DT 설정/모드 추가
│   ├── LLMEvaluator.swift         ← [유지] 변경 없음 (그대로 재사용)
│   ├── Models.swift               ← [유지] 변경 없음
│   ├── DeviceStat.swift           ← [유지] 변경 없음
│   ├── RequestLLMIntent.swift     ← [유지] 변경 없음
│   ├── DrawThingsURLBuilder.swift ← [신규] Draw Things URL scheme 빌더
│   └── ImagePromptGenerator.swift ← [신규] 시스템 프롬프트 + 결과 파서
├── Views/
│   ├── Chat/                      ← [유지] 모든 파일 변경 없음
│   ├── Settings/
│   │   ├── SettingsView.swift     ← [수정] Draw Things 설정 링크 추가
│   │   ├── DrawThingsSettingsView.swift ← [신규] DT 파라미터 설정 화면
│   │   └── (나머지 유지)
│   ├── PromptBuilder/             ← [신규 디렉토리]
│   │   ├── PromptBuilderView.swift     ← [신규] 프롬프트 빌더 메인 UI
│   │   └── PromptHistoryListView.swift ← [신규] 프롬프트 히스토리 사이드바
│   └── Onboarding/                ← [유지] 변경 없음
```

### 변경 통계

| 구분 | 파일 수 |
|------|---------|
| 수정 | 4개 (Data.swift, fullmoonApp.swift, ContentView.swift, SettingsView.swift) |
| 신규 | 4개 (DrawThingsURLBuilder.swift, ImagePromptGenerator.swift, PromptBuilderView.swift, PromptHistoryListView.swift, DrawThingsSettingsView.swift) |
| 유지 | 나머지 전부 (Chat 뷰 3개, Onboarding 5개, 설정 3개, 모델 3개) |

---

## 9. 데이터 흐름도

```
[사용자]
   │ "달 위의 고양이"
   ▼
[PromptBuilderView] ──→ [LLMEvaluator.generate()]
   │                        │ systemPrompt = ImagePromptGenerator.systemPrompt
   │                        │ 임시 Thread 사용
   │                        ▼
   │                    [MLX 로컬 추론]
   │                        │
   │                        ▼ "POSITIVE: masterpiece... NEGATIVE: lowres..."
   │
   ├──→ [ImagePromptGenerator.parsePromptOutput()] ──→ positive / negative 분리
   │
   ├──→ [Save] ──→ SwiftData(ImagePrompt) ──→ PromptHistoryListView 갱신
   │
   └──→ [Send to DT] ──→ DrawThingsURLBuilder.generateURL()
                              │
                              ▼
                         UIApplication.shared.open(url)
                              │
                              ▼
                         [Draw Things 앱] ──→ 이미지 생성
                              │
                              ▼ (x-callback-url)
                         fullmoon://callback ──→ 앱 복귀
```

---

## 10. 구현 우선순위

| Phase | 내용 | 예상 작업량 |
|-------|------|------------|
| P1 | DrawThingsURLBuilder + ImagePromptGenerator (모델 레이어) | 소 |
| P2 | ImagePrompt SwiftData 모델 + Data.swift 수정 | 소 |
| P3 | PromptBuilderView + PromptHistoryListView (UI) | 중 |
| P4 | ContentView 사이드바 모드 전환 | 소 |
| P5 | DrawThingsSettingsView + SettingsView 링크 | 소 |
| P6 | Info.plist URL scheme + fullmoonApp.swift 콜백 | 소 |
