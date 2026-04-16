//
//  PromptBuilderView.swift
//  fullmoon
//
//  Created by fullmoon-builder on 2026/04/15.
//

import SwiftData
import SwiftUI

struct PromptBuilderView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.modelContext) var modelContext
    @Environment(LLMEvaluator.self) var llm
    @Binding var currentPrompt: ImagePrompt?

    @State private var userInput = ""
    @State private var positivePrompt = ""
    @State private var negativePrompt = ""
    @State private var showDrawThingsSettings = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // user input section
                    userInputSection

                    Divider()

                    // generated prompt display/edit
                    promptResultSection

                    Divider()

                    // settings preview
                    settingsPreview

                    // action bar
                    actionBar
                }
                .padding()
            }
            .navigationTitle("Prompt Builder")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .sheet(isPresented: $showDrawThingsSettings) {
                NavigationStack {
                    DrawThingsSettingsView()
                        .environmentObject(appManager)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showDrawThingsSettings = false }
                            }
                        }
                }
            }
            .alert("Draw Things", isPresented: $showAlert) {
                Button("OK") {}
            } message: {
                Text(alertMessage)
            }
            .onChange(of: currentPrompt) {
                if let prompt = currentPrompt {
                    userInput = prompt.userDescription
                    positivePrompt = prompt.positive
                    negativePrompt = prompt.negative
                } else {
                    userInput = ""
                    positivePrompt = ""
                    negativePrompt = ""
                }
            }
        }
    }

    // MARK: - Sections

    private var userInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Describe your image")
                .font(.headline)

            TextField("A cat sitting on a crescent moon, ghibli style...", text: $userInput, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)

            Button(action: generatePrompt) {
                HStack {
                    if llm.running {
                        ProgressView()
                            .controlSize(.small)
                        Text("Generating...")
                    } else {
                        Image(systemName: "sparkles")
                        Text("Generate Prompt")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || llm.running)
        }
    }

    private var promptResultSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Positive")
                    .font(.headline)
                    .foregroundStyle(.green)
                TextEditor(text: $positivePrompt)
                    .frame(minHeight: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.secondary.opacity(0.3), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Negative")
                    .font(.headline)
                    .foregroundStyle(.red)
                TextEditor(text: $negativePrompt)
                    .frame(minHeight: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.secondary.opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }

    private var settingsPreview: some View {
        HStack {
            Label("\(appManager.dtWidth)x\(appManager.dtHeight)", systemImage: "aspectratio")
            Spacer()
            Label("\(appManager.dtSteps) steps", systemImage: "slider.horizontal.3")
            Spacer()
            Label(String(format: "%.1f", appManager.dtScale), systemImage: "dial.low")
            Spacer()
            Button {
                showDrawThingsSettings = true
            } label: {
                Image(systemName: "gear")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button(action: savePrompt) {
                Label("Save", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(positivePrompt.isEmpty)

            Button(action: sendToDrawThings) {
                Label("Send to DT", systemImage: "paintbrush.pointed")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(positivePrompt.isEmpty)

            Button(action: sendToDrawThingsWithCallback) {
                Label("DT+", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(.bordered)
            .disabled(positivePrompt.isEmpty)
        }
    }

    // MARK: - Actions

    private func generatePrompt() {
        guard let modelName = appManager.currentModelName else {
            alertMessage = "No model loaded. Please select a model first."
            showAlert = true
            return
        }

        // Create a temporary thread for LLM generation
        let tempThread = Thread()
        let userMessage = Message(role: .user, content: userInput, thread: tempThread)
        tempThread.messages = [userMessage]

        Task {
            let result = await llm.generate(
                modelName: modelName,
                thread: tempThread,
                systemPrompt: ImagePromptGenerator.systemPrompt
            )

            let parsed = ImagePromptGenerator.parsePromptOutput(result)
            positivePrompt = parsed.positive
            negativePrompt = parsed.negative
        }
    }

    private func savePrompt() {
        let prompt = ImagePrompt(
            userDescription: userInput,
            positive: positivePrompt,
            negative: negativePrompt
        )
        modelContext.insert(prompt)
        try? modelContext.save()
        currentPrompt = prompt
    }

    private func sendToDrawThings() {
        let config = DrawThingsConfig.from(appManager)
        guard let url = DrawThingsURLBuilder.generateURL(
            positive: positivePrompt,
            negative: negativePrompt,
            config: config
        ) else {
            alertMessage = "Failed to build Draw Things URL."
            showAlert = true
            return
        }
        #if os(iOS) || os(visionOS)
        UIApplication.shared.open(url)
        #endif
    }

    private func sendToDrawThingsWithCallback() {
        let config = DrawThingsConfig.from(appManager)
        guard let url = DrawThingsURLBuilder.generateURLWithCallback(
            positive: positivePrompt,
            negative: negativePrompt,
            config: config
        ) else {
            alertMessage = "Failed to build Draw Things URL."
            showAlert = true
            return
        }
        #if os(iOS) || os(visionOS)
        UIApplication.shared.open(url)
        #endif
    }
}
