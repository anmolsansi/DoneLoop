import SwiftUI

struct CaptureDetailView: View {
    let capture: DLCapture

    var body: some View {
        List {
            Section("Capture") {
                labeledValue("Source", capture.source.displayName)
                labeledValue("Status", capture.processingStatus.displayName)
                labeledValue("Created", capture.createdAt.formatted(date: .abbreviated, time: .shortened))
            }

            Section("Text") {
                Text(capture.transcript ?? capture.rawText)
                    .foregroundStyle(DLColor.textPrimary)
                    .textSelection(.enabled)
            }

            if let aiOutputJSON = capture.aiOutputJSON {
                Section("Structured Output") {
                    Text(aiOutputJSON)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(DLColor.textSecondary)
                        .textSelection(.enabled)
                }
            } else {
                Section("Structured Output") {
                    Text("No interpretation has been saved yet.")
                        .foregroundStyle(DLColor.textSecondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(DLColor.background)
        .navigationTitle("Capture Detail")
    }

    private func labeledValue(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(DLColor.textSecondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(DLColor.textPrimary)
        }
    }
}

private extension DLCaptureSource {
    var displayName: String {
        switch self {
        case .voice: "Voice"
        case .text: "Text"
        }
    }
}
