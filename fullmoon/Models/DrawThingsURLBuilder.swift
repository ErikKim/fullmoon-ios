//
//  DrawThingsURLBuilder.swift
//  fullmoon
//
//  Created by fullmoon-builder on 2026/04/15.
//

import Foundation
#if os(iOS) || os(visionOS)
import UIKit
#endif

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

    /// Generate URL for Draw Things
    static func generateURL(positive: String, negative: String, config: DrawThingsConfig) -> URL? {
        guard let encoded = buildSettingsJSON(positive: positive, negative: negative, config: config) else { return nil }
        return URL(string: "draw-things://generate?output=canvas&settings=\(encoded)")
    }

    /// Generate URL with x-callback-url (returns to fullmoon after generation)
    static func generateURLWithCallback(positive: String, negative: String, config: DrawThingsConfig) -> URL? {
        guard let encoded = buildSettingsJSON(positive: positive, negative: negative, config: config) else { return nil }
        guard let successURL = "fullmoon://callback?status=success".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "draw-things://x-callback-url/generate?output=canvas&settings=\(encoded)&x-success=\(successURL)")
    }

    /// Prompt-only URL (uses Draw Things' current settings)
    static func promptOnlyURL(positive: String, negative: String) -> URL? {
        let settings: [String: Any] = [
            "prompts": [
                ["positive": positive, "negative": negative]
            ]
        ]
        guard let encoded = encodeSettings(settings) else { return nil }
        return URL(string: "draw-things://generate?settings=\(encoded)")
    }

    /// Check if Draw Things is installed
    #if os(iOS) || os(visionOS)
    static func isDrawThingsInstalled() -> Bool {
        guard let url = URL(string: "draw-things://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
    #endif

    // MARK: - Private

    private static func buildSettingsJSON(positive: String, negative: String, config: DrawThingsConfig) -> String? {
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
                    "initial_seed": config.seed
                ]
            ]
        ]
        return encodeSettings(settings)
    }

    private static func encodeSettings(_ settings: [String: Any]) -> String? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: settings),
              let jsonString = String(data: jsonData, encoding: .utf8),
              let encoded = jsonString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return encoded
    }
}
