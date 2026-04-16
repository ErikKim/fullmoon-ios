//
//  PromptHistoryListView.swift
//  fullmoon
//
//  Created by fullmoon-builder on 2026/04/15.
//

import SwiftData
import SwiftUI

struct PromptHistoryListView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.modelContext) var modelContext
    @Query(sort: \ImagePrompt.timestamp, order: .reverse) var prompts: [ImagePrompt]
    @Binding var currentPrompt: ImagePrompt?
    @State var search = ""
    @State var selection: ImagePrompt?

    var body: some View {
        NavigationStack {
            ZStack {
                List(selection: $selection) {
                    ForEach(filteredPrompts, id: \.id) { prompt in
                        VStack(alignment: .leading) {
                            Text(prompt.userDescription)
                                .lineLimit(1)
                                .foregroundStyle(.primary)
                                .font(.headline)
                            Text(prompt.positive)
                                .lineLimit(2)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(prompt.timestamp.formatted())
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .tag(prompt)
                    }
                    .onDelete(perform: deletePrompts)
                }
                .onChange(of: selection) {
                    currentPrompt = selection
                }
                #if os(iOS)
                .listStyle(.insetGrouped)
                #elseif os(macOS) || os(visionOS)
                .listStyle(.sidebar)
                #endif

                if filteredPrompts.isEmpty {
                    ContentUnavailableView {
                        Label(prompts.isEmpty ? "no prompts yet" : "no results", systemImage: "paintbrush")
                    }
                }
            }
            .navigationTitle("prompts")
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "search")
            #elseif os(macOS)
            .searchable(text: $search, placement: .sidebar, prompt: "search")
            #endif
            .toolbar {
                #if os(iOS) || os(visionOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        selection = nil
                        currentPrompt = nil
                    }) {
                        Image(systemName: "plus")
                    }
                    .keyboardShortcut("N", modifiers: [.command])
                }
                #elseif os(macOS)
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        selection = nil
                        currentPrompt = nil
                    }) {
                        Label("new", systemImage: "plus")
                    }
                    .keyboardShortcut("N", modifiers: [.command])
                }
                #endif
            }
        }
        #if !os(visionOS)
        .tint(appManager.appTintColor.getColor())
        #endif
        .environment(\.dynamicTypeSize, appManager.appFontSize.getFontSize())
    }

    var filteredPrompts: [ImagePrompt] {
        prompts.filter { prompt in
            search.isEmpty ||
            prompt.userDescription.localizedCaseInsensitiveContains(search) ||
            prompt.positive.localizedCaseInsensitiveContains(search)
        }
    }

    private func deletePrompts(at offsets: IndexSet) {
        for offset in offsets {
            let prompt = prompts[offset]
            if let currentPrompt = currentPrompt, currentPrompt.id == prompt.id {
                self.currentPrompt = nil
            }
            modelContext.delete(prompt)
        }
    }
}
