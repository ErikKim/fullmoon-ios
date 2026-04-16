# Draw Things API Reference

Draw Things 앱과 연동하기 위한 URL scheme 스펙.

## URL Scheme

`draw-things://` URI scheme 사용. x-callback-url도 지원:
- `draw-things://generate?...`
- `draw-things://x-callback-url/generate?...`

## 주요 엔드포인트

### /generate — 이미지 생성

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| preset | string | 기존 프리셋 이름 |
| input | string | "none", "clipboard", "data" |
| image_data | string | Base64 인코딩 이미지 (img2img) |
| count | int | 생성 수 (1-100, 0=연속) |
| output | string | "canvas", "clipboard", "export", "url" (+로 조합 가능) |
| settings | JSON | prompts, config, additives 포함 |

**settings JSON 구조:**
```json
{
  "prompts": [{"positive": "a cat in space", "negative": "blurry, low quality"}],
  "config": [{
    "model": "model_filename",
    "sampler": "DPM++ 2M Karras",
    "scale": 7.5,
    "steps": 30,
    "size": "768x768",
    "initial_seed": 42
  }],
  "additives": [{
    "lora": [{"model": "lora.ckpt", "weight": 0.5}]
  }]
}
```

### /prompts — 프롬프트 조작

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| set | string | "positive" 또는 "negative" |
| prompt_text | string | 주입할 텍스트 |
| operation | string | "replace"(기본), "prepend", "append" |
| get | string | "both", "positive", "negative" |

### x-callback-url 파라미터

| 파라미터 | 설명 |
|---------|------|
| x-success | 완료 시 리다이렉트 URL |
| x-cancel | 취소 시 URL |
| x-error | 실패 시 URL |

## config 주요 키

| 키 | 타입 | 범위 | 설명 |
|----|------|------|------|
| model | string | 파일명 | 모델 |
| sampler | string | DDIM 등 | 샘플러 |
| scale | number | 0-25 | CFG 스케일 |
| steps | integer | 5-150 | 추론 스텝 |
| strength | number | 0.1-1 | img2img 강도 |
| size | string | "768x768" | 출력 크기 |
| clip_skip | integer | 1-23 | CLIP 레이어 스킵 |
| hires_fix | boolean | | 고해상도 보정 |

## Swift에서 호출 예시

```swift
import UIKit

func sendToDrawThings(positive: String, negative: String) {
    let settings: [String: Any] = [
        "prompts": [["positive": positive, "negative": negative]],
        "config": [["scale": 7.5, "steps": 30, "size": "768x768"]]
    ]
    
    guard let settingsData = try? JSONSerialization.data(withJSONObject: settings),
          let settingsStr = String(data: settingsData, encoding: .utf8),
          let encoded = settingsStr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
          let url = URL(string: "draw-things://generate?output=canvas&settings=\(encoded)") else {
        return
    }
    
    UIApplication.shared.open(url)
}
```
