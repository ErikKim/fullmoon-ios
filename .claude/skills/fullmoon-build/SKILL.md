---
name: fullmoon-build
description: "iPad Fullmoon 포크 앱의 Swift/SwiftUI 코드를 구현하는 빌드 스킬. 설계서 기반으로 SwiftUI 뷰, SwiftData 모델, Draw Things URL scheme 연동 코드를 작성한다. fullmoon-builder 에이전트가 사용한다. 'fullmoon 구현', '빌드', '코드 작성' 요청 시 트리거."
---

# Fullmoon Build Skill

architect가 작성한 `_workspace/architecture.md` 설계서를 기반으로 Swift/SwiftUI 코드를 구현한다.

## 구현 워크플로우

### 1. 설계서 읽기
- `_workspace/architecture.md`를 Read하여 변경 명세 파악
- 수정 대상 파일을 모두 Read하여 현재 상태 확인

### 2. 데이터 모델 구현
- SwiftData @Model 생성/수정
- 기존 Thread/Message 모델은 가급적 건드리지 않고, 새 모델로 확장
- modelContainer 등록: `fullmoonApp.swift`에서 `.modelContainer(for:)` 배열에 추가

### 3. 비즈니스 로직 구현
- Draw Things URL 생성 유틸리티 (`references/draw-things-api.md` 참조)
- LLM 시스템 프롬프트 구성 (이미지 프롬프트 생성 전문화)
- 프롬프트 템플릿 관리 로직

### 4. UI 구현
- SwiftUI 뷰 파일 생성
- 기존 ContentView/ChatView 최소 수정으로 새 기능 진입점 추가
- iPad NavigationSplitView 레이아웃에 맞춤
- `.sheet()`, `.toolbar()` 등 기존 패턴 따르기

### 5. 빌드 검증
```bash
xcodebuild -project fullmoon.xcodeproj \
  -scheme fullmoon \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' \
  build 2>&1 | tail -20
```
컴파일 에러 있으면 즉시 수정.

### 6. 보고서 작성
`_workspace/build_report.md`에 변경 파일 목록과 주요 결정사항 기록.

## 코딩 규칙

### 네이밍
- 기존 fullmoon 스타일 따르기: camelCase, 뷰는 ~View 접미사
- 새 파일은 기존 디렉토리 구조에 배치 (Views/DrawThings/, Models/ 등)

### SwiftUI 패턴
```swift
// 환경 객체 접근
@EnvironmentObject var appManager: AppManager
@Environment(LLMEvaluator.self) var llm

// SwiftData 쿼리
@Query(sort: \PromptTemplate.timestamp, order: .reverse) var templates: [PromptTemplate]
```

### Draw Things 연동
- URL scheme 호출은 `UIApplication.shared.open(url)` 사용
- settings JSON은 `Codable` struct로 타입 안전하게 구성
- iPad에서 `canOpenURL` 체크 후 미설치 시 App Store로 안내

### 에러 처리
- Draw Things 미설치: Alert로 App Store 링크 제공
- LLM 미로딩: 기존 fullmoon의 온보딩 흐름 재사용
- URL 인코딩 실패: 사용자에게 프롬프트가 너무 길다고 안내
