import SwiftUI

struct CaptureView: View {
    @EnvironmentObject private var services: AppServices
    @State private var typedCapture = ""
    @State private var isShowingInterpretation = false

    let showTaskDetail: () -> Void
    let showDecisionSheet: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DLSpacing.xl) {
                VStack(spacing: DLSpacing.md) {
                    Button(action: {}) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 112, height: 112)
                            .background(DLColor.primary, in: Circle())
                    }
                    .accessibilityLabel("Start voice capture")

                    Text("Capture something before it slips.")
                        .font(.headline)
                        .foregroundStyle(DLColor.textPrimary)

                    Text(services.parser.modeLabel)
                        .font(.caption)
                        .foregroundStyle(DLColor.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, DLSpacing.xl)

                VStack(alignment: .leading, spacing: DLSpacing.sm) {
                    Text("Text Capture")
                        .font(.headline)
                    TextField("Type a task, note, or reminder", text: $typedCapture, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3, reservesSpace: true)
                    DLPrimaryButton("Interpret", systemImage: "wand.and.stars") {
                        isShowingInterpretation = true
                    }
                    .disabled(typedCapture.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                VStack(alignment: .leading, spacing: DLSpacing.md) {
                    HStack {
                        Text("Recent Captures")
                            .font(.headline)
                        Spacer()
                        Button("Decision Sheet", action: showDecisionSheet)
                            .font(.caption.weight(.semibold))
                    }

                    ForEach(services.localStore.recentCaptures) { capture in
                        Button(action: { isShowingInterpretation = true }) {
                            HStack(spacing: DLSpacing.md) {
                                Image(systemName: capture.source == "Voice" ? "mic" : "text.cursor")
                                    .foregroundStyle(DLColor.primary)
                                VStack(alignment: .leading, spacing: DLSpacing.xs) {
                                    Text(capture.title)
                                        .font(.headline)
                                        .foregroundStyle(DLColor.textPrimary)
                                    Text(capture.detail)
                                        .font(.callout)
                                        .foregroundStyle(DLColor.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(DLColor.textTertiary)
                            }
                            .padding(DLSpacing.md)
                            .background(DLColor.surface, in: RoundedRectangle(cornerRadius: DLRadius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: DLRadius.md)
                                    .stroke(DLColor.divider, lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(DLSpacing.lg)
        }
        .background(DLColor.background)
        .navigationTitle("Capture")
        .sheet(isPresented: $isShowingInterpretation) {
            InterpretationPreviewView(showTaskDetail: showTaskDetail)
                .presentationDetents([.large])
        }
    }
}
