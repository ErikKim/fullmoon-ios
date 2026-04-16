//
//  ImagePromptGenerator.swift
//  fullmoon
//
//  Created by fullmoon-builder on 2026/04/15.
//

import Foundation

@MainActor
class ImagePromptGenerator {

    /// System prompt for image prompt generation
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

    /// Parse LLM output into positive/negative prompts
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

        // fallback: if parsing fails, use entire output as positive
        if positive.isEmpty && negative.isEmpty {
            positive = output.trimmingCharacters(in: .whitespacesAndNewlines)
            negative = "lowres, bad anatomy, bad hands, text, error, worst quality, low quality, jpeg artifacts, watermark, blurry"
        }

        return (positive, negative)
    }
}
