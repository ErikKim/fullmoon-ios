//
//  DrawThingsSettingsView.swift
//  fullmoon
//
//  Created by fullmoon-builder on 2026/04/15.
//

import SwiftUI

struct DrawThingsSettingsView: View {
    @EnvironmentObject var appManager: AppManager

    let samplers = ["DPM++ 2M Karras", "Euler a", "DDIM", "UniPC", "LCM"]

    var body: some View {
        Form {
            Section(header: Text("Image Size")) {
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
                Stepper(
                    "Seed: \(appManager.dtSeed == -1 ? "Random" : "\(appManager.dtSeed)")",
                    value: $appManager.dtSeed,
                    in: -1...999999999
                )
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Draw Things")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview {
    NavigationStack {
        DrawThingsSettingsView()
            .environmentObject(AppManager())
    }
}
