---
name: fullmoon-architecture
description: "iPad 전용 Fullmoon 포크 앱의 기능 설계 스킬. Draw Things 연동, 프롬프트 빌더 UI, 데이터 모델 확장을 설계한다. fullmoon-architect 에이전트가 사용한다. 'fullmoon 설계', '아키텍처', 'Draw Things 연동 설계' 요청 시 트리거."
---

# Fullmoon Architecture Skill

iPad에서 로컬 LLM으로 이미지 프롬프트를 생성하고 Draw Things 앱으로 전달하는 기능을 설계한다.

## 기존 코드베이스 구조

```
fullmoon/
├── fullmoonApp.swift          — @main, SwiftData container, Environment 주입
├── ContentView.swift           — 온보딩/메인 분기, NavigationSplitView
├── Models/
│   ├── Data.swift              — AppManager(@Observable), Thread/Message(@Model), 열거형들
│   ├── LLMEvaluator.swift      — MLX 모델 로딩/추론, 스트리밍 생성
│   ├── Models.swift            — ModelConfiguration 목록 (Llama, DeepSeek, Qwen)
│   ├── DeviceStat.swift        — GPU 메모리 모니터링
│   └── RequestLLMIntent.swift  — Siri Shortcuts 연동
├── Views/
│   ├── Chat/                   — ChatView, ConversationView, ChatsListView
│   ├── Settings/               — 설정 화면들
│   └── Onboarding/             — 모델 다운로드 온보딩
```

## 핵심 패턴

- **상태 관리**: AppManager(@Observable, @AppStorage), LLMEvaluator(@Observable, @MainActor)
- **데이터**: SwiftData — Thread ↔ Message 1:N 관계
- **추론**: MLX `LLMModelFactory.shared.loadContainer()` → `generate()` 스트리밍
- **UI**: SwiftUI, NavigationSplitView(iPad), 모달 시트

## 설계 워크플로우

### 1. 요구사항 분석
- 사용자 요청에서 기능 범위 파악
- 기존 코드 중 수정이 필요한 부분 식별
- Draw Things API 스펙 확인 (references/ 하위 draw-things-api.md 참조)

### 2. 데이터 모델 설계
- 새 SwiftData @Model이 필요한지, 기존 Thread/Message 확장으로 충분한지 판단
- 프롬프트 템플릿 저장 구조 설계
- Draw Things 설정(모델, sampler, scale 등) 저장 방식 결정

### 3. UI 흐름 설계
- iPad 화면 구성: 좌측 사이드바(채팅 목록 + 프롬프트 목록), 우측 메인 영역
- Draw Things 전송 버튼 위치, 프롬프트 편집 UI
- 기존 ChatView 수정 범위 최소화 (별도 뷰 추가 선호)

### 4. Draw Things 연동 설계
- URL scheme: `draw-things://generate?settings={JSON}`
- 프롬프트 전달: `/prompts` 엔드포인트 또는 `/generate` settings.prompts
- x-callback-url로 결과 수신 가능 여부 검토

### 5. 산출물 작성
`_workspace/architecture.md`에 다음을 포함:
- 수정 대상 파일 목록 (파일별 변경 내용)
- 새로 생성할 파일 목록
- 데이터 모델 스키마
- UI 화면 흐름
- Draw Things URL 구성 예시
