---
name: fullmoon-orchestrator
description: "Fullmoon iPad 포크 앱의 설계→구현→QA 파이프라인을 자동 조율하는 오케스트레이터. 'fullmoon 만들어', 'fullmoon 기능 추가', 'Draw Things 연동 구현해', 'fullmoon 빌드' 요청 시 트리거. fullmoon-reserved 프로젝트의 모든 빌드 요청에 이 스킬을 사용할 것."
---

# Fullmoon Orchestrator

iPad 전용 Fullmoon 포크 앱의 기능 구현을 3단계 파이프라인으로 자동 조율한다.

## 파이프라인

```
Phase 1: 설계 (fullmoon-architect)
    ↓ _workspace/architecture.md
Phase 2: 구현 (fullmoon-builder)
    ↓ 소스 코드 + _workspace/build_report.md
Phase 3: 검증 (fullmoon-qa)
    ↓ _workspace/qa_report.md
```

## 실행 모드

**서브 에이전트** — 순차 의존이 강한 파이프라인이므로 서브 에이전트 모드 사용.

## 실행 절차

### Phase 1: 설계

```
Agent(
  description: "Fullmoon 아키텍처 설계",
  subagent_type: "fullmoon-architect",
  model: "opus",
  prompt: """
  [사용자 요구사항]
  {user_request}
  
  fullmoon-architecture 스킬을 참조하여 설계서를 작성하라.
  산출물: _workspace/architecture.md
  """
)
```

설계 완료 후 `_workspace/architecture.md` 존재 확인.

### Phase 2: 구현

```
Agent(
  description: "Fullmoon 코드 구현",
  subagent_type: "fullmoon-builder",
  model: "opus",
  prompt: """
  _workspace/architecture.md 설계서를 읽고 코드를 구현하라.
  fullmoon-build 스킬을 참조하라.
  산출물: 소스 코드 수정 + _workspace/build_report.md
  """
)
```

빌드 보고서 확인. CRITICAL 이슈가 있으면 builder 재실행.

### Phase 3: 검증

```
Agent(
  description: "Fullmoon QA 검증",
  subagent_type: "fullmoon-qa",
  model: "opus",
  prompt: """
  _workspace/architecture.md와 _workspace/build_report.md를 읽고
  구현된 코드를 검증하라.
  xcodebuild로 컴파일 테스트를 수행하라.
  산출물: _workspace/qa_report.md
  """
)
```

### Phase 4: 수정 (조건부)

QA에서 CRITICAL 이슈 발견 시:
1. builder를 재호출하여 이슈 수정
2. 수정 후 QA 재실행
3. 최대 2회 반복, 그 이상이면 사용자에게 보고

## 데이터 전달

| 단계 | 산출물 | 경로 |
|------|--------|------|
| 설계 | 아키텍처 문서 | `_workspace/architecture.md` |
| 구현 | 빌드 보고서 | `_workspace/build_report.md` |
| 검증 | QA 보고서 | `_workspace/qa_report.md` |

모든 중간 산출물은 `_workspace/` 하위에 보존한다.

## 에러 핸들링

| 상황 | 대응 |
|------|------|
| architect 실패 | 에러 메시지와 함께 사용자에게 요구사항 명확화 요청 |
| builder 컴파일 에러 | builder에 에러 로그 전달하여 재시도 (1회) |
| QA CRITICAL | builder 재호출 → QA 재실행 (최대 2회) |
| QA WARNING만 | 보고서와 함께 사용자에게 결과 전달 |

## 테스트 시나리오

### 정상 흐름
1. "Draw Things에 프롬프트 보내는 기능 추가해" 요청
2. architect: ChatView에 전송 버튼 추가 + DrawThingsService 설계
3. builder: SwiftUI 뷰 + URL scheme 코드 구현
4. qa: 빌드 성공, URL 포맷 정확성 확인 → PASS

### 에러 흐름
1. builder가 SwiftData 모델 등록 누락
2. qa: xcodebuild 실패 → CRITICAL 리포트
3. builder 재호출: modelContainer에 새 모델 추가
4. qa 재실행: 빌드 성공 → PASS
